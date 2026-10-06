"""What the PolarFire FPGA's own evidence says, read from this repository alone.

Everything needed to answer "where does each requirement stand" is here: the
requirements in `docs/requirements/`, the items in `verification/items.yaml`,
the tests under `verification/tests/`, and the JUnit results a run leaves in
`verification/results/`. No network, no governance repository, no dashboard
server.

That matters because the programme-wide tooling lives in another repository
that an FPGA developer does not own and should not have to check out to see
whether their own tests cover their own requirements.

One parser, two projections. `by_test` is what the merge gate needs -- given a
result, what was claimed about it. `by_requirement` is what a developer needs
-- given a requirement, is there anything behind it. They are the same records
viewed from two ends, so the gate and the view cannot disagree about what the
evidence says.
"""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path

import yaml

from fsverif import dispositions

VERIF = Path(__file__).resolve().parent.parent
REPO = VERIF.parent
ITEMS = VERIF / "items.yaml"
RESULTS = VERIF / "results"
REQUIREMENTS = REPO / "docs" / "requirements" / "pf-fpga-requirements.md"
FINDINGS = REPO / "docs" / "requirements" / "pf-fpga-findings.md"

#: A requirement heading.
#:
#: Two shapes, and the second is easy to miss. Ordinary requirements are
#: `PF-<AREA>-<n>`; derived ones are `DRV-PF-<n>` with no area at all -- a
#: pattern written for the first shape silently misses the derived ones, which
#: are exactly the ones a reader is least likely to notice are absent. Either
#: may be followed by a qualifier, as in `### PF-BUILD-06 *(design constraint)*`.
HEADING = re.compile(r"^### (DRV-PF-\d+|PF-[A-Z]+-\d+)\b[^\n]*$", re.M)

#: Any heading at all. A requirement's text ends at the next one of these, not
#: at the next requirement: the document closes with sections on withdrawn
#: requirements whose own `Status:` lines would otherwise be read as the last
#: requirement's.
ANY_HEADING = re.compile(r"^#{1,3} ", re.M)
STATUS = re.compile(r"^- \*\*Status:\*\*\s*(\w+)", re.M)
FINDING = re.compile(r"PF-F-\d+")
#: A value the requirement states but has not yet had confirmed.
PENDING = re.compile(r"\bTBR\b")
#: A finding's own heading: `## PF-F-07 -- HIGH`.
FINDING_HEAD = re.compile(r"^## (PF-F-\d+) -- (\w+)\s*$", re.M)

#: Artifacts naming something in another repository. Everything else is a path
#: in this one, whatever the method: an INSP item names `test/inspect/build.py`
#: and a SIM item names `verification/tests/test_pf_pps.py`, and both are
#: files that either exist or do not.
ELSEWHERE = "farsight-verification/"


@dataclass
class Item:
    id: str
    verifies: list
    method: str
    artifact: str
    expect_fail: bool
    blocked: bool
    criteria: str = ""

    @property
    def test(self) -> str:
        return self.artifact.partition("::")[2]

    @property
    def module(self) -> str:
        """The module the test lives in, as JUnit reports it.

        cocotb writes the module stem as the `classname` of each testcase.
        """
        return Path(self.artifact.partition("::")[0]).stem

    @property
    def key(self) -> tuple:
        """What identifies a result: the module *and* the test name.

        Not the name alone. A requirement may have a simulation
        item and a hardware item that name the same test in different files.
        Keyed on name only, a simulation result would be credited to the
        hardware item as well, which is a claim that something was observed
        on a rig that nobody has touched.
        """
        return (self.module, self.test)

    @property
    def is_local_test(self) -> bool:
        return "::" in self.artifact and not self.artifact.startswith(ELSEWHERE)

    def written(self, repo: Path = REPO) -> bool:
        """Whether the file this item names exists yet.

        Asked of every method, not only SIM. An inspection item naming
        `test/inspect/build.py` is in exactly the same state as a simulation
        item naming a bench nobody has written: the evidence does not exist.
        Treating those differently made the inspection work look like somebody
        else's problem rather than outstanding work.
        """
        if not self.is_local_test:
            return False
        return (repo / self.artifact.partition("::")[0]).is_file()


@dataclass
class Requirement:
    id: str
    status: str
    items: list = field(default_factory=list)
    statement: str = ""
    findings: tuple = ()
    pending: bool = False
    #: Recorded in `requirement-dispositions.yaml`, approved or proposed.
    waivers: list = field(default_factory=list)
    exceptions: list = field(default_factory=list)

    @property
    def waived(self) -> bool:
        return any(w.approved for w in self.waivers)

    @property
    def excepted(self) -> bool:
        return any(e.approved for e in self.exceptions)


def read_items(path: Path = ITEMS) -> list:
    raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    return [
        Item(
            id=item["id"],
            verifies=item.get("verifies", []),
            method=item.get("method", ""),
            artifact=item.get("artifact", ""),
            expect_fail=item.get("expect", "").strip().upper() == "FAIL",
            blocked=bool(item.get("blocked")),
            criteria=" ".join(str(item.get("criteria", "")).split()),
        )
        for item in raw["items"]
    ]


def read_requirements(path: Path = REQUIREMENTS,
                      disposed: Path = dispositions.DISPOSITIONS) -> dict:
    """Every requirement in the document, with the status recorded for it and
    any waiver or exception recorded against it."""
    text = path.read_text(encoding="utf-8")
    found = {}
    for mark in HEADING.finditer(text):
        following = ANY_HEADING.search(text, mark.end())
        body = text[mark.end():following.start() if following else len(text)]
        status = STATUS.search(body)
        found[mark.group(1)] = Requirement(
            id=mark.group(1), status=status.group(1) if status else "UNSTATED",
            statement=" ".join(body.split("\n- **")[0].split()),
            findings=tuple(dict.fromkeys(FINDING.findall(body))),
            pending=bool(PENDING.search(body)))
    waivers, exceptions = dispositions.load(disposed)
    for w in waivers:
        if w.requirement in found:
            found[w.requirement].waivers.append(w)
    for e in exceptions:
        if e.requirement in found:
            found[e.requirement].exceptions.append(e)
    return found


def read_findings(path: Path = FINDINGS) -> dict:
    """Finding -> (severity, subject), from each finding's heading and claim."""
    text = path.read_text(encoding="utf-8")
    marks = list(FINDING_HEAD.finditer(text))
    out = {}
    for n, mark in enumerate(marks):
        end = marks[n + 1].start() if n + 1 < len(marks) else len(text)
        claim = re.search(r"^- \*\*Claim:\*\*\s*(.+)$", text[mark.end():end], re.M)
        subject = claim.group(1).strip() if claim else ""
        out[mark.group(1)] = (mark.group(2), subject)
    return out


def by_test(items: list) -> dict:
    """(module, test name) -> every item citing it.

    A list, not one item: some tests are cited by two items -- one test
    standing as evidence for two requirements -- and keeping only the last
    would make a verdict depend on the order of the file.
    """
    out = {}
    for item in items:
        if "::" in item.artifact:
            out.setdefault(item.key, []).append(item)
    return out


def by_requirement(items: list, requirements: dict) -> dict:
    """Requirement -> the items that verify it.

    Raises on an item citing a requirement that is not in the document. A
    requirement that does not exist cannot be verified, and an item claiming
    otherwise would inflate every count on the page.
    """
    stray = []
    for item in items:
        for requirement in item.verifies:
            if requirement in requirements:
                requirements[requirement].items.append(item)
            else:
                stray.append("%s verifies %s" % (item.id, requirement))
    if stray:
        raise SystemExit(
            "these items verify requirements that are not in %s, so nothing "
            "can say whether they are met: %s"
            % (REQUIREMENTS.name, "; ".join(stray)))
    return requirements


def read_results(results_dir: Path = RESULTS) -> dict:
    """Test name -> "passed" | "failed" | "skipped", from every JUnit file.

    One cocotb test can run against several DUTs -- the same check on each
    DDR4 bank -- and so appear in several files. A failure in any of them is
    the result: taking whichever file happened to be read last would let one
    bank's pass hide the other's failure.
    """
    rank = {"skipped": 0, "passed": 1, "failed": 2}
    found = {}
    if not results_dir.is_dir():
        return found
    for report in sorted(results_dir.glob("*.xml")):
        for case in ET.parse(report).getroot().iter("testcase"):
            key = (case.get("classname", ""), case.get("name", ""))
            if case.find("failure") is not None or case.find("error") is not None:
                outcome = "failed"
            elif case.find("skipped") is not None:
                outcome = "skipped"
            else:
                outcome = "passed"
            if rank[outcome] >= rank.get(found.get(key), -1):
                found[key] = outcome
    return found


#: How far a requirement's evidence has got. Ordered: each stage is only
#: reachable once the one before it holds.
#:
#: Deliberately says nothing about *how* a requirement is verified. Method --
#: SIM, INSP, ANA, HW -- is a separate axis, and mixing the two hid outstanding
#: work: an inspection item whose script nobody has written was being reported
#: as "not simulation", which reads like a decision rather than a gap.
#:
#: The distinction the framework insists on is between `never run` and the
#: stages after it. A test that exists and has never run is *no evidence* --
#: it is a promise. Counting it as coverage is the substitution the whole
#: exercise exists to prevent.
STAGES = (
    ("no item", "nothing claims to verify this"),
    ("elsewhere", "discharged by an item in another plan"),
    ("not written", "an item names evidence that does not exist yet"),
    ("never run", "the evidence exists but no result has been collected"),
    ("failing", "ran and did not meet the requirement"),
    ("known shortfall", "failing, and an item declares the requirement unmet"),
    ("waived", "a known shortfall, and an approved waiver accepts it"),
    ("passing, with exceptions", "ran and met the requirement, with approved "
                                 "exceptions it permits"),
    ("passing", "ran and met the requirement"),
)

#: Stages that mean a requirement has evidence behind it today. `known
#: shortfall` is in: the test ran and reported honestly, and the programme has
#: recorded that the requirement is not met. That is evidence -- of a gap.
COVERED = {"passing", "passing, with exceptions", "waived", "known shortfall"}


def methods(requirement: Requirement) -> str:
    """How this requirement is to be verified, as a sorted list."""
    return "/".join(sorted({i.method for i in requirement.items if i.method}))


def stage(requirement: Requirement, results: dict, repo: Path = REPO,
          method: str = "") -> str:
    """How far this requirement's evidence has got.

    The weakest of its items, not the strongest. A requirement with three
    items where one has never been written is not covered -- reporting the
    best of them would be reporting the part somebody already did.

    `method` narrows it to items of one kind, and the narrowing has to reach
    in here rather than only filter the rows afterwards. Where a requirement
    has a simulation item and a hardware item, with the hardware item
    counted a developer asking "how far has the simulation
    got" would be told "not written" about finished work, because the
    weakest item was a rig test nobody has built.
    """
    considered = [i for i in requirement.items
                  if not method or i.method == method.upper()]
    if not considered:
        return "no item"

    reached = []
    for item in considered:
        if not item.is_local_test:
            reached.append("elsewhere")
        elif not item.written(repo):
            reached.append("not written")
        else:
            outcome = results.get(item.key)
            if outcome is None or outcome == "skipped":
                reached.append("never run")
            elif outcome == "failed":
                reached.append("known shortfall" if item.expect_fail else "failing")
            else:
                reached.append("passing")

    order = [name for name, _ in STAGES]
    worst = min(reached, key=order.index)
    # A requirement-wide record, so it applies to the requirement's worst
    # stage rather than to any one item: a waiver accepts a known shortfall
    # and nothing worse, and exceptions qualify a pass and nothing less.
    if worst == "known shortfall" and requirement.waived:
        return "waived"
    if worst == "passing" and requirement.excepted:
        return "passing, with exceptions"
    return worst
