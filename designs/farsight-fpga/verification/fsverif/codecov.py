"""Code coverage as `make code-coverage` left it.

Reads `verification/coverage/`: the raw data (Verilator's `*.dat` and
QuestaSim's `*.ucdb`, one per run measured), the `summary.json`
`code_coverage.py` writes, and
the annotated sources, where every counted line carries its hit count.

A report older than the data is *stale*, and says so, rather than being shown
as the coverage of the data beside it.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path

from fsverif.evidence import REPO, VERIF

COVERAGE = VERIF / "coverage"
ANNOTATED = COVERAGE / "annotated"

#: A counted line: one margin character (`%` if below --annotate-min, which the
#: report sets to 1, so `%` means never reached; `~` if only some of the line's
#: points are), the count, one space, and the source. The count is as wide as it needs to be, six digits at least.
_COUNTED = re.compile(r"^([%~\s])(\d{6,}) (.*)$")
#: A coverage point under the line above it (`--annotate-points`): `+` hit,
#: `-` never hit. A line that ran can still have points nothing hit -- a
#: branch never taken, a bit that never toggled -- which line coverage hides.
_POINT = re.compile(r"^([+-])(\d+)\s+point: type=(\S+) comment=(.*?)(?: hier=(\S+))?\s*$")
#: An uncounted line is the source behind eight columns of blank margin.
_MARGIN = 8
_HEADER = "verilator_coverage annotation"

#: Coverage kinds, in the order worth reading them.
KINDS = ("line", "branch", "expr", "toggle")


@dataclass
class Point:
    count: int
    kind: str                  # line, branch, expr, toggle
    comment: str
    hier: str


@dataclass
class SourceLine:
    number: int
    text: str
    count: int | None          # None: not a coverage point
    points: list = field(default_factory=list)
    margin: str = " "

    @property
    def missed_points(self) -> list:
        return [p for p in self.points if p.count == 0]

    @property
    def partial(self) -> bool:
        """Reached, but with points on it that nothing hit."""
        return bool(self.count) and (self.margin == "~" or bool(self.missed_points))


@dataclass
class FileCoverage:
    name: str
    missed: int
    counted: int
    partly: int = 0
    disposed: int = 0          # never executed, with a disposition saying why

    @property
    def unresolved(self) -> int:
        return self.missed - self.disposed

    @property
    def reached(self) -> int:
        return self.counted - self.missed

    @property
    def percent(self) -> float:
        return 100.0 * self.reached / self.counted if self.counted else 0.0


@dataclass
class Coverage:
    data: list = field(default_factory=list)          # *.dat and *.ucdb paths
    summary: dict = field(default_factory=dict)       # kind -> (percent, hit, total)
    files: list = field(default_factory=list)         # FileCoverage, worst first
    modules: list = field(default_factory=list)       # modules the report covers
    measured_at: float = 0.0                          # newest of them
    reported_at: float = 0.0                          # summary.json
    disposed_at: float = 0.0                          # coverage-dispositions.yaml
    problems: list = field(default_factory=list)      # dispositions not applied, and why

    @property
    def measured(self) -> bool:
        return bool(self.data)

    @property
    def reported(self) -> bool:
        return bool(self.reported_at)

    @property
    def stale(self) -> bool:
        """Data or dispositions newer than the report, or modules measured it
        does not cover."""
        if not self.reported:
            return self.measured
        return (max(self.measured_at, self.disposed_at) > self.reported_at + 1 or
                sorted(p.stem for p in self.data) != sorted(self.modules))


def load(where: Path = COVERAGE, recorded: Path | None = None) -> Coverage:
    cov = Coverage()
    if not where.is_dir():
        return cov
    recorded = recorded or DISPOSITIONS
    cov.disposed_at = recorded.stat().st_mtime if recorded.is_file() else 0.0
    cov.data = sorted(where.glob("*.dat")) + sorted(where.glob("*.ucdb"))
    cov.measured_at = max((p.stat().st_mtime for p in cov.data), default=0.0)
    summary = where / "summary.json"
    if summary.is_file():
        raw = json.loads(summary.read_text(encoding="utf-8"))
        cov.reported_at = summary.stat().st_mtime
        cov.modules = raw.get("modules", [])
        kinds = raw.get("kinds", {})
        cov.summary = {k: tuple(kinds[k]) for k in KINDS if k in kinds}
        cov.summary.update({k: tuple(v) for k, v in kinds.items() if k not in cov.summary})
        cov.files = sorted((FileCoverage(n, *counts) for n, counts in raw.get("files", {}).items()),
                           key=lambda f: (-f.unresolved, -f.partly, f.name))
        cov.problems = raw.get("dispositions", [])
    return cov


def annotated(name: str, where: Path = COVERAGE) -> list:
    """One annotated source, line by line, with its count and its points."""
    path = where / "annotated" / name
    out: list = []
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        m = _POINT.match(raw)
        if m:
            if out:
                out[-1].points.append(Point(int(m.group(2)), m.group(3), m.group(4),
                                            m.group(5) or ""))
            continue
        if not out and _HEADER in raw:
            continue
        m = _COUNTED.match(raw)
        if m:
            out.append(SourceLine(len(out) + 1, m.group(3), int(m.group(2)),
                                  margin=m.group(1)))
        else:
            text = raw[_MARGIN:] if raw[:_MARGIN].strip() == "" else raw
            out.append(SourceLine(len(out) + 1, text, None))
    return out


#: Where this design's own HDL lives. Verilator's annotated output keeps only
#: the file name, so the file is found again by name under these.
DESIGN_DIRS = ("ip", "hdl", "component", "bd")
_HDL = (".v", ".sv", ".vh", ".svh", ".vhd")


@lru_cache(maxsize=1)
def _sources() -> dict:
    out: dict = {}
    for top in DESIGN_DIRS:
        for path in sorted((REPO / top).rglob("*")):
            if path.suffix in _HDL and path.is_file():
                out.setdefault(path.name, path)
    return out


def source(name: str) -> Path | None:
    """The design file an annotated source was made from, or None if it is not ours."""
    return _sources().get(name)


#: Code never executed that is not a gap in the tests, and why.
DISPOSITIONS = VERIF / "coverage-dispositions.yaml"

#: The reasons code can be never executed and not be a gap. Anything else that
#: no test reached is behaviour to test, or a requirement to ask for.
DISPOSITION_KINDS = {
    "illegal-state": "recovery from a state encoding the FSM never assigns; "
                     "reachable only by an upset of its register, or not at all",
    "outside-flight": "reachable only with a parameter or register value the "
                      "flight configuration does not use",
    "unreachable": "no input reaches it",
}

#: Coverage points that mean a line of code ran: a statement, or a branch taken.
#: A line whose only points are toggles is a declaration.
CODE_KINDS = ("line", "branch")


@dataclass
class Disposition:
    file: str
    first: int
    last: int
    at: str                    # text expected on line `first`
    kind: str
    reason: str

    def covers(self, number: int) -> bool:
        return self.first <= number <= self.last

    @property
    def where(self) -> str:
        return "%s:%d-%d" % (self.file, self.first, self.last)


def dispositions(path: Path = DISPOSITIONS) -> list:
    """The recorded dispositions. A malformed one stops the report rather than
    being skipped, which would quietly turn it back into a gap or hide one."""
    if not path.is_file():
        return []
    import yaml
    out = []
    for i, raw in enumerate(yaml.safe_load(path.read_text(encoding="utf-8")) or []):
        try:
            first, _, last = str(raw["lines"]).partition("-")
            d = Disposition(raw["file"], int(first), int(last or first), str(raw["at"]).strip(),
                            raw["kind"], " ".join(str(raw["reason"]).split()))
        except (KeyError, TypeError, ValueError) as e:
            raise ValueError("%s entry %d: needs file, lines (a-b), at, kind and reason (%s)"
                             % (path.name, i + 1, e)) from None
        if d.kind not in DISPOSITION_KINDS:
            raise ValueError("%s %s: kind %r is not one of %s"
                             % (path.name, d.where, d.kind, ", ".join(DISPOSITION_KINDS)))
        if d.last < d.first:
            raise ValueError("%s %s: lines run backwards" % (path.name, d.where))
        out.append(d)
    return out


def never_executed(line: SourceLine) -> bool | None:
    """True if a code line no test executed, False if one that ran, None if not code."""
    code = [p for p in line.points if p.kind in CODE_KINDS]
    if not code:
        return None
    return all(p.count == 0 for p in code)


def disposed(name: str, lines: list, recorded: list) -> tuple:
    """Which of a file's lines the recorded dispositions cover, and the ones that
    cannot be applied.

    Returns ({line number: Disposition}, [problem]). A disposition is not
    applied, and is reported, if the text it names is no longer on its first
    line -- the source moved under it -- or if a line in it was executed: a
    test reached what it says nothing reaches, so either the reason is wrong
    or it is no longer needed.
    """
    applied: dict = {}
    problems: list = []
    for d in (d for d in recorded if d.file == name):
        if d.last > len(lines) or d.at not in lines[d.first - 1].text:
            problems.append({"where": d.where, "problem": "moved",
                             "detail": "line %d no longer reads %r" % (d.first, d.at)})
            continue
        ran = [l.number for l in lines[d.first - 1:d.last] if never_executed(l) is False]
        if ran:
            problems.append({"where": d.where, "problem": "executed",
                             "detail": "line %s ran; the disposition says %s"
                                       % (ran[0], DISPOSITION_KINDS[d.kind])})
            continue
        for n in range(d.first, d.last + 1):
            applied[n] = d
    return applied, problems


#: The headline: this design's own files, each point counted once however many
#: instances or testbenches reached it, and the two simulators merged where they
#: measure the same thing -- a code line ran, a bit toggled. Verilator's own
#: summary counts every instance of every file simulated, testbench and vendor
#: models included, which is not a statement about this design.
MERGED = ("code lines", "toggles")
#: Branches and conditions are counted differently by each simulator, so each
#: keeps its own figure: added together they would compare different things.
BY_SIMULATOR = ("verilator branch", "verilator expr", "questa branch",
                "questa condition", "questa expression")


def tally(names, where: Path = COVERAGE) -> dict:
    """kind -> [percent, hit, total] over the named annotated sources."""
    seen: dict = {}

    def add(kind: str, key: tuple, hit: bool) -> None:
        points = seen.setdefault(kind, {})
        points[key] = points.get(key, False) or hit

    for name in names:
        for line in annotated(name, where):
            ran = never_executed(line)
            if ran is not None:
                add("code lines", (name, line.number), not ran)
            for p in line.points:
                questa = p.comment.startswith("questa ")
                what = p.comment[len("questa "):] if questa else p.comment
                if p.kind == "toggle":
                    add("toggles", (name, line.number, what), p.count > 0)
                elif p.kind in ("branch", "expr"):
                    kind = "questa " + what.split()[0] if questa else "verilator " + p.kind
                    add(kind, (name, line.number, what), p.count > 0)
    out = {}
    for kind in MERGED + BY_SIMULATOR:
        points = seen.get(kind)
        if points:
            hit = sum(points.values())
            out[kind] = [round(100.0 * hit / len(points), 1), hit, len(points)]
    return out
