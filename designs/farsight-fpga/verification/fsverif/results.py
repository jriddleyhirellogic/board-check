"""Everything a run left behind, joined into one picture.

The app (`fsverif.web`) reads this and nothing else, so what it shows can be
tested without a browser, and cannot disagree with the merge gate: verdicts
come from `check_results.classify`, requirement stages from
`evidence.stage`, the same code `make check` and `make coverage` run.

What it joins:

- items (`items.yaml`) and the tests they name;
- requirements, with their wording, status, the findings they cite, and whether
  any value in them is still TBR;
- findings, from the summary table and each finding's own section;
- the last run's JUnit results, and for each test its failure message and the
  values it logged (`fsverif.runlog` keeps the log beside the results) -- or,
  for an analysis, the calculation it recorded (`analysis/conftest.py`);
- the Jama requirements the PolarFire FPGA answers to (`fsverif.jama`), with
  the PF requirements citing each and what their tests found -- the
  functional coverage of each Jama requirement.
"""

from __future__ import annotations

import ast
import re
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path

from fsverif import jama as J
from fsverif import palette
from fsverif.evidence import (ANY_HEADING, FINDINGS, HEADING, ITEMS, REQUIREMENTS,
                              RESULTS, VERIF, by_requirement, by_test, read_findings,
                              read_items, read_requirements, read_results,
                              stage)

sys.path.insert(0, str(VERIF))
from check_results import (BLOCKS, KNOWN, MISSING, PASSED, REGRESSION,  # noqa: E402
                           SKIPPED, STALE, classify)

TESTS = VERIF / "tests"
ANALYSIS = VERIF / "analysis"
#: Where requirement tests live: simulations, and analyses that report like them.
FOLDERS = (TESTS, ANALYSIS)

#: A requirement test with no result in the results directory: the gate's own
#: verdict for it, which blocks a merge.
NOT_RUN = MISSING

#: Verdicts, worst first. The first four are `check_results`'s own: the merge
#: gate's judgement of a result against what its item expects.
VERDICTS = (REGRESSION, STALE, SKIPPED, KNOWN, PASSED, NOT_RUN)
VERDICT_LABEL = {REGRESSION: "Regression", STALE: "Stale", SKIPPED: "Skipped",
                 KNOWN: "Known shortfall", PASSED: "Passing", NOT_RUN: "Not run"}

#: What the apps show first: what the test did. The gate's verdict is shown as
#: a note beside it -- whether a failure was expected, and whether anything
#: blocks a merge -- because "known shortfall" and "stale" describe the item's
#: record, not the test, and read as test results they confuse.
FAILED, NOT_RUN_OUTCOME = "failed", "not run"
OUTCOMES = (FAILED, PASSED, NOT_RUN_OUTCOME)
OUTCOME_LABEL = {FAILED: "Failing", PASSED: "Passing", NOT_RUN_OUTCOME: "Not run"}
_OUTCOME = {REGRESSION: FAILED, KNOWN: FAILED, PASSED: PASSED, STALE: PASSED,
            SKIPPED: NOT_RUN_OUTCOME, NOT_RUN: NOT_RUN_OUTCOME}
#: The gate's verdict, in a word or two, for beside the outcome.
GATE_NOTE = {REGRESSION: "new failure", KNOWN: "expected", STALE: "item expects a failure",
             SKIPPED: "skipped", PASSED: "", NOT_RUN: "no result"}

#: Requirement evidence stages (`evidence.stage`), in the same words.
STAGE_LABEL = {"passing": "passing", "passing, with exceptions": "passing, with exceptions",
               "waived": "waived", "known shortfall": "failing",
               "failing": "failing, not expected", "never run": "not run",
               "not written": "no test yet", "elsewhere": "elsewhere", "no item": "no item"}
#: The order the app lists stages in, best first.
STAGE_DISPLAY = ("passing", "passing, with exceptions", "waived", "known shortfall", "failing",
                 "never run", "not written", "elsewhere", "no item")
#: Worst first, for a summary of the requirements under a Jama requirement.
STAGE_WORST_FIRST = ("failing", "no item", "not written", "never run", "known shortfall",
                     "waived", "elsewhere", "passing, with exceptions", "passing")

#: A Jama requirement, judged by the PF requirements under it: the worst of
#: their stages decides. Worst first. One with no local requirement under it but
#: a `verified_in:` is verified elsewhere -- by the firmware, say -- and says so
#: rather than borrowing a result.
UNTRACED, TRACE_FAILING, TRACE_PARTIAL, TRACE_WAIVED, TRACE_ELSEWHERE, TRACE_PASSING = (
    "no local requirement", "failing", "partly tested", "waived", "verified elsewhere",
    "passing")
TRACE_ORDER = (UNTRACED, TRACE_FAILING, TRACE_PARTIAL, TRACE_WAIVED, TRACE_ELSEWHERE,
               TRACE_PASSING)
_TRACE_OF_STAGE = {"failing": TRACE_FAILING, "known shortfall": TRACE_FAILING,
                   "waived": TRACE_WAIVED, "passing, with exceptions": TRACE_PASSING,
                   "no item": TRACE_PARTIAL, "not written": TRACE_PARTIAL,
                   "never run": TRACE_PARTIAL, "passing": TRACE_PASSING,
                   "elsewhere": TRACE_PASSING}

def vocabulary() -> dict:
    """The stages and roll-ups, in order and with their labels and colours, for
    the app: one definition, here, rather than a copy in the browser."""
    from fsverif.evidence import COVERED
    return {"stages": [{"key": k, "label": STAGE_LABEL[k], "color": palette.STAGE[k]}
                       for k in STAGE_DISPLAY],
            "stagesWorstFirst": list(STAGE_WORST_FIRST), "covered": sorted(COVERED),
            "traces": [{"key": t, "color": palette.TRACE[t]} for t in TRACE_ORDER]}


#: Loggers whose records are the harness talking, not the test.
HARNESS = ("cocotb.regression", "cocotb.scheduler", "cocotb", "py.warnings")
_LINE = re.compile(r"^(\S+) (\w+) (\S+) (.*)$")
_RUNNING = re.compile(r"^running (\w+)\.(\w+) \(")
_FINDING_HEAD = re.compile(r"^## (PF-F-\d+) -- \w+\s*$", re.M)


def group_of(requirement: str) -> str:
    """`PF-UDP-16` -> `UDP`, `DRV-PF-03` -> `DRV`."""
    parts = requirement.split("-")
    return parts[0] if parts[0] == "DRV" else parts[1]


# ---- reading what a run left

def failure_messages(results_dir: Path) -> dict:
    """(module, test) -> the failure or error text, unescaped."""
    out = {}
    for report in sorted(results_dir.glob("*.xml")):
        for case in ET.parse(report).getroot().iter("testcase"):
            bad = case.find("failure")
            if bad is None:
                bad = case.find("error")
            if bad is None:
                continue
            key = (case.get("classname", ""), case.get("name", ""))
            text = (bad.get("message") or "").strip()
            out[key] = text or (bad.text or "").strip()
    return out


def durations(results_dir: Path) -> dict:
    """(module, test) -> wall-clock seconds, as cocotb recorded them."""
    out = {}
    for report in sorted(results_dir.glob("*.xml")):
        for case in ET.parse(report).getroot().iter("testcase"):
            try:
                out[(case.get("classname", ""), case.get("name", ""))] = float(
                    case.get("time", "0"))
            except ValueError:
                pass
    return out


def logged(results_dir: Path) -> dict:
    """(module, test) -> the lines the test itself logged, in order."""
    out = {}
    for log in sorted(results_dir.glob("log-*.txt")):
        current, keep = None, False
        for raw in log.read_text(encoding="utf-8", errors="replace").splitlines():
            if raw.startswith("    "):
                if current and keep:
                    out[current][-1] += "\n" + raw[4:]
                continue
            m = _LINE.match(raw)
            if not m:
                continue
            _, level, name, message = m.groups()
            if name == "cocotb.regression":
                run = _RUNNING.match(message)
                if run:
                    current = run.groups()
                    out.setdefault(current, [])
                keep = False
                continue
            keep = name not in HARNESS and level in ("INFO", "WARNING", "ERROR")
            if current and keep:
                out[current].append(message)
    return out


def finding_sections(path: Path = FINDINGS) -> dict:
    """Finding -> its whole section of the findings document, as markdown."""
    text = path.read_text(encoding="utf-8")
    marks = list(_FINDING_HEAD.finditer(text))
    out = {}
    for n, mark in enumerate(marks):
        end = marks[n + 1].start() if n + 1 < len(marks) else len(text)
        body = text[mark.start():end]
        # A section ends at the next top-level heading that is not a finding.
        body = re.split(r"^## (?!PF-F-)", body, maxsplit=1, flags=re.M)[0]
        out[mark.group(1)] = body.rstrip().rstrip("-").rstrip()
    return out


def requirement_sections(path: Path = REQUIREMENTS) -> dict:
    """Requirement -> its whole entry in the requirements document, as markdown."""
    text = path.read_text(encoding="utf-8")
    out = {}
    for mark in HEADING.finditer(text):
        # An entry ends at the next heading of any level, not only the next
        # entry: the document closes with sections on withdrawn requirements.
        following = ANY_HEADING.search(text, mark.end())
        out[mark.group(1)] = text[mark.start():following.start() if following
                                  else len(text)].rstrip()
    return out


def recorded(results_dir: Path) -> dict:
    """(module, test) -> the calculation an analysis recorded, as markdown."""
    out = {}
    for report in sorted(results_dir.glob("*.xml")):
        for case in ET.parse(report).getroot().iter("testcase"):
            text = (case.findtext("system-out") or "").strip()
            if text:
                out[(case.get("classname", ""), case.get("name", ""))] = text
    return out


def module_path(module: str) -> Path:
    """The file a test module is in: a simulation under `tests/`, or an analysis."""
    for folder in FOLDERS:
        path = folder / ("%s.py" % module)
        if path.is_file():
            return path
    return TESTS / ("%s.py" % module)


def module_arg(module: str) -> str:
    """The module as pytest is given it from `verification/`."""
    return module_path(module).relative_to(VERIF).as_posix()


def test_line(module: str, name: str) -> int:
    """The line a test function is defined on, or 1."""
    path = module_path(module)
    try:
        tree = ast.parse(path.read_text(encoding="utf-8"))
    except (OSError, SyntaxError):
        return 1
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name == name:
            return node.lineno
    return 1


# ---- the joined picture

@dataclass
class Test:
    module: str
    name: str
    items: list
    verdict: str
    message: str = ""
    lines: list = field(default_factory=list)
    seconds: float = 0.0
    record: str = ""            # an analysis's calculation, as markdown

    @property
    def analysis(self) -> bool:
        return self.path.parent == ANALYSIS

    @property
    def key(self) -> tuple:
        return (self.module, self.name)

    @property
    def requirements(self) -> list:
        return list(dict.fromkeys(r for i in self.items for r in i.verifies))

    @property
    def blocks(self) -> bool:
        """Whether this result would stop a merge (`make check`)."""
        return BLOCKS.get(self.verdict, False)

    @property
    def outcome(self) -> str:
        """failed, passed or not run -- what the test itself did."""
        return _OUTCOME[self.verdict]

    @property
    def outcome_label(self) -> str:
        return OUTCOME_LABEL[self.outcome]

    @property
    def gate_note(self) -> str:
        return GATE_NOTE.get(self.verdict, "")

    @property
    def path(self) -> Path:
        return module_path(self.module)


@dataclass
class Run:
    """The last run, and everything it is judged against."""
    tests: list
    requirements: dict
    findings: dict              # id -> (severity, subject)
    finding_text: dict          # id -> markdown section
    requirement_text: dict      # id -> markdown entry
    stages: dict                # requirement -> evidence stage
    results_at: float           # newest results file, seconds since epoch; 0 if none
    unwritten: list             # items naming a test that does not exist yet
    jama: dict = field(default_factory=dict)     # Jama id -> fsverif.jama.JamaReq
    parents: dict = field(default_factory=dict)  # requirement -> Jama ids it cites

    def test(self, module: str, name: str):
        return next((t for t in self.tests if t.key == (module, name)), None)

    def tests_for(self, requirement: str) -> list:
        return [t for t in self.tests if requirement in t.requirements]

    def children(self, jama_id: str) -> list:
        """The PF FPGA requirements citing a Jama requirement as parent."""
        return [r for r, cited in self.parents.items()
                if jama_id in cited and r in self.requirements]

    def trace(self, jama_id: str) -> tuple:
        """(roll-up, {stage: count}) for a Jama requirement."""
        stages = {}
        for r in self.children(jama_id):
            stages[self.stages[r]] = stages.get(self.stages[r], 0) + 1
        if not stages:
            j = self.jama.get(jama_id)
            return (TRACE_ELSEWHERE if j and j.verified_in else UNTRACED), stages
        worst = min((_TRACE_OF_STAGE.get(s, TRACE_PARTIAL) for s in stages),
                    key=TRACE_ORDER.index)
        return worst, stages

    @property
    def uncited_parents(self) -> list:
        """Jama ids a requirement cites that the Jama snapshot does not hold."""
        cited = {j for js in self.parents.values() for j in js}
        return sorted(cited - set(self.jama))

    def requirements_citing(self, finding: str) -> list:
        return sorted(r for r, req in self.requirements.items()
                      if finding in req.findings)

    def counts(self) -> dict:
        """Tests per gate verdict -- what `make check` judges."""
        out = {v: 0 for v in VERDICTS}
        for t in self.tests:
            out[t.verdict] += 1
        return out

    def outcomes(self) -> dict:
        """Tests per outcome -- what the tests did."""
        out = {o: 0 for o in OUTCOMES}
        for t in self.tests:
            out[t.outcome] += 1
        return out

    @property
    def blocking(self) -> list:
        """The results that would stop a merge."""
        return [t for t in self.tests if t.blocks]

    @property
    def pending(self) -> list:
        return sorted(r for r, req in self.requirements.items() if req.pending)


def load(items_path: Path = ITEMS, requirements_path: Path = REQUIREMENTS,
         results_dir: Path = RESULTS, findings_path: Path = FINDINGS,
         jama_path: Path = J.JAMA) -> Run:
    items = read_items(items_path)
    requirements = by_requirement(items, read_requirements(requirements_path))
    cited = by_test(items)
    results = read_results(results_dir)
    messages = failure_messages(results_dir) if results_dir.is_dir() else {}
    logs = logged(results_dir) if results_dir.is_dir() else {}
    seconds = durations(results_dir) if results_dir.is_dir() else {}
    records = recorded(results_dir) if results_dir.is_dir() else {}

    rank = list(VERDICTS)
    verdict = {}
    for key, _, v in classify(cited, results):
        if key not in verdict or rank.index(v) < rank.index(verdict[key]):
            verdict[key] = v

    tests, unwritten = [], []
    for key, citing in sorted(cited.items()):
        local = [i for i in citing if i.is_local_test and
                 i.artifact.startswith(("verification/tests/", "verification/analysis/"))]
        if not local:
            continue
        if not all(i.written() for i in local):
            unwritten.extend(i for i in local if not i.written())
            continue
        tests.append(Test(module=key[0], name=key[1], items=local,
                          verdict=verdict.get(key, NOT_RUN),
                          message=messages.get(key, ""), lines=logs.get(key, []),
                          seconds=seconds.get(key, 0.0), record=records.get(key, "")))

    newest = max((p.stat().st_mtime for p in results_dir.glob("*.xml")), default=0.0) \
        if results_dir.is_dir() else 0.0
    return Run(tests=tests, requirements=requirements,
               findings=read_findings(findings_path),
               finding_text=finding_sections(findings_path),
               requirement_text=requirement_sections(requirements_path),
               stages={r: stage(req, results) for r, req in requirements.items()},
               results_at=newest, unwritten=unwritten,
               jama=J.load(jama_path), parents=J.parents(requirements_path))
