"""QuestaSim's code coverage, in the form Verilator's report takes.

The modules pinned to QuestaSim (COREFIFO and LSRAM simulate correctly only
there) save a UCDB per run. `vcover` merges them and reports, per source file,
every statement, branch, condition and expression row and toggled bit with its
hit count. This turns that report into what `code_coverage.py` already writes
for Verilator -- an annotated source per file, counts in the margin and coverage
points under each line -- merging with Verilator's annotation where both
simulators reached the same file, so a reader and the app see one picture.

Points from QuestaSim are named for it (`questa statement 2`, `questa
branch 1`), because the two simulators count differently: a merged count says
a line ran, not how many times either simulator would have said it did.
"""

from __future__ import annotations

import re
import shutil
import subprocess
from dataclasses import dataclass, field
from pathlib import Path

#: The QuestaSim fsverif.sim uses; its `vcover` reads the databases.
VENDOR_DIRS = (
    "/usr/local/microchip/Libero_SoC_v2024.1/QuestaSim/bin",
    "/opt/microchip/Libero_SoC_v2024.1/QuestaSim/bin",
    "/opt/microsemi/Libero_SoC_v2024.1/QuestaSim/bin",
)

#: Coverage kinds from the per-file tables, as QuestaSim names their rows.
KINDS = {"Statements": "statement", "Branches": "branch", "Conditions": "condition",
         "Expressions": "expression", "Toggles": "toggle"}

_FILE = re.compile(r"^=== File: (.+?)\s*$")
_TABLE = re.compile(r"^\s+(Statements|Branches|Conditions|Expressions|Toggles)\s+"
                    r"(\d+)\s+(\d+)\s+(\d+)\s+[\d.]+%")
_DETAILS = re.compile(r"^=+(Statement|Branch|Condition|Expression|Toggle) Details=+")
_COUNT = r"(\*\*\*0\*\*\*|\d+)"
_ITEM = re.compile(r"^\s+(\d+)\s+(\d+)\s+" + _COUNT + r"\s*$")
_FOCUS = re.compile(r"^Line\s+(\d+) Item\s+(\d+)\s+(.*)$")
_ROW = re.compile(r"^\s+Row\s+\d+:\s+" + _COUNT + r"\s+(\S+)")
_TOGGLE = re.compile(r"^\s+(\d+)\s+(\S+)\s+(\d+)\s+(\d+)\s+[\d.]+\s*$")

#: Verilator's annotation format, which `fsverif.codecov` reads back.
HEADER = "//      // verilator_coverage annotation"


def _count(text: str) -> int:
    return 0 if text.startswith("*") else int(text)


@dataclass
class FileCov:
    path: str
    kinds: dict = field(default_factory=dict)       # kind -> [hits, bins]
    lines: dict = field(default_factory=dict)       # line -> [(count, kind, comment)]


def vcover() -> str | None:
    """QuestaSim's own first: the PATH often holds Libero's 32-bit ModelSim,
    whose `vcover` cannot run here, as `fsverif.sim` found for `vsim`."""
    for d in VENDOR_DIRS:
        if (Path(d) / "vcover").is_file():
            return str(Path(d) / "vcover")
    return shutil.which("vcover")


def _run(args: list, cwd: Path) -> str:
    done = subprocess.run([str(a) for a in args], capture_output=True, text=True, cwd=cwd)
    if done.returncode != 0:
        raise SystemExit("%s failed:\n%s" % (args[0], (done.stdout + done.stderr).strip()))
    return done.stdout


def report(databases: list, work: Path) -> str:
    """The merged databases' per-file details, as `vcover report` prints them.

    Run from `work`, which holds no sources: `vcover` prints a source's path
    relative to its working directory when the source is under it, and from
    the repository root every file of this design came out relative.
    """
    tool = vcover()
    if not tool:
        raise SystemExit("vcover is not on PATH or in Libero's QuestaSim; the QuestaSim "
                         "coverage in %s cannot be read" % ", ".join(str(d) for d in databases))
    work.mkdir(parents=True, exist_ok=True)
    merged = work / "merged.ucdb"
    _run([tool, "merge", "-out", merged.resolve(), *[Path(d).resolve() for d in databases]], work)
    return _run([tool, "report", "-details", "-code", "sbcet", "-srcfile=*", merged.resolve()], work)


def parse(text: str) -> dict:
    """Source path -> FileCov, from `vcover report -details -srcfile=*`."""
    files, cur, section, focus = {}, None, None, None
    for raw in text.splitlines():
        m = _FILE.match(raw)
        if m:
            cur = files.setdefault(m.group(1), FileCov(m.group(1)))
            section = focus = None
            continue
        if cur is None:
            continue
        m = _DETAILS.match(raw)
        if m:
            section, focus = m.group(1).lower(), None
            continue
        m = _TABLE.match(raw)
        if m:
            kind = KINDS[m.group(1)]
            hits, bins = cur.kinds.get(kind, [0, 0])
            cur.kinds[kind] = [hits + int(m.group(3)), bins + int(m.group(2))]
            continue
        if section in ("statement", "branch"):
            m = _ITEM.match(raw)
            if m:
                cur.lines.setdefault(int(m.group(1)), []).append(
                    (_count(m.group(3)), "line" if section == "statement" else "branch",
                     "questa %s %s" % (section, m.group(2))))
        elif section in ("condition", "expression"):
            m = _FOCUS.match(raw)
            if m:
                focus = int(m.group(1))
                continue
            m = _ROW.match(raw)
            if m and focus is not None:
                cur.lines.setdefault(focus, []).append(
                    (_count(m.group(1)), "expr", "questa %s %s" % (section, m.group(2))))
        elif section == "toggle":
            m = _TOGGLE.match(raw)
            if m:
                line, node = int(m.group(1)), m.group(2)
                cur.lines.setdefault(line, []).extend([
                    (int(m.group(4)), "toggle", "questa %s:0->1" % node),
                    (int(m.group(3)), "toggle", "questa %s:1->0" % node)])
    return files


def merge_annotation(source: Path, existing: Path | None, cov: FileCov) -> str:
    """One annotated source: Verilator's, if it reached the file, with QuestaSim's
    counts added to each line and its points under it.

    A line's QuestaSim count is its most-executed statement, or failing that its
    most-hit point; it is partly covered when any point on it was never hit.
    """
    from fsverif.codecov import annotated

    if existing is not None and existing.is_file():
        lines = annotated(existing.name, existing.parent.parent)
    else:
        from fsverif.codecov import SourceLine
        lines = [SourceLine(n, text, None) for n, text in
                 enumerate(source.read_text(encoding="utf-8", errors="replace").splitlines(), 1)]
    out = [HEADER]
    for line in lines:
        points = [(p.count, p.kind, p.comment, p.hier) for p in line.points]
        q = cov.lines.get(line.number, [])
        points += [(c, k, comment, "") for c, k, comment in q]
        count = line.count
        if q:
            statements = [c for c, k, _ in q if k == "line"]
            qcount = max(statements) if statements else max(c for c, _, _ in q)
            count = (count or 0) + qcount
        if count is None:
            out.append(" " * 8 + line.text)
            continue
        margin = "%" if count == 0 else ("~" if any(c == 0 for c, *_ in points) else " ")
        out.append("%s%06d %s" % (margin, count, line.text))
        for c, kind, comment, hier in points:
            out.append("%s%06d  point: type=%s comment=%s%s"
                       % ("+" if c else "-", c, kind, comment, " hier=%s" % hier if hier else ""))
    return "\n".join(out) + "\n"
