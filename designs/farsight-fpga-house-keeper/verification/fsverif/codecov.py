"""Code coverage as `make code-coverage` left it.

Reads `verification/coverage/`: the raw `*.dat` data (one per module, written
by every run unless `FSVERIF_COVERAGE=0`), the `summary.json` `code_coverage.py` writes, and
the annotated sources, where every counted line carries its hit count.

A report older than the data is *stale*, and says so, rather than being shown
as the coverage of the data beside it.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path

from fsverif.evidence import VERIF

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

    @property
    def reached(self) -> int:
        return self.counted - self.missed

    @property
    def percent(self) -> float:
        return 100.0 * self.reached / self.counted if self.counted else 0.0


@dataclass
class Coverage:
    data: list = field(default_factory=list)          # *.dat paths
    summary: dict = field(default_factory=dict)       # kind -> (percent, hit, total)
    files: list = field(default_factory=list)         # FileCoverage, worst first
    modules: list = field(default_factory=list)       # modules the report covers
    measured_at: float = 0.0                          # newest *.dat
    reported_at: float = 0.0                          # summary.json

    @property
    def measured(self) -> bool:
        return bool(self.data)

    @property
    def reported(self) -> bool:
        return bool(self.reported_at)

    @property
    def stale(self) -> bool:
        """Data newer than the report, or modules measured it does not cover."""
        if not self.reported:
            return self.measured
        return (self.measured_at > self.reported_at + 1 or
                sorted(p.stem for p in self.data) != sorted(self.modules))


def load(where: Path = COVERAGE) -> Coverage:
    cov = Coverage()
    if not where.is_dir():
        return cov
    cov.data = sorted(where.glob("*.dat"))
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
                           key=lambda f: (-f.missed, -f.partly, f.name))
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
