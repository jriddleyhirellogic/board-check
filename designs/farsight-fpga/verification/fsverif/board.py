"""The board around the PolarFire, for inspections of pins and interfaces.

Three sources, each read where its owner keeps it:

- **the avionics schematic**, as exported from the CM-03545 PCB project by
  ts-altium-sch-json's script and committed here as `verification/board/
  CM-03545.json`, so every inspection reads one pinned revision. It is read
  through `altium_sch_json`, the reader that ships with the export script, and
  refused if that reader finds it structurally unsound;
- **the housekeeper's pinout**, the flight-model constraint file of the
  ProASIC3 design (`farsight-fpga-house-keeper`), for the far end of every
  line between the two FPGAs;
- **the retained build's pin report**, for where each port was actually
  placed.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

import pytest
from altium_sch_json import load, problems

from fsverif.design import REPO, WORKSPACE

#: The committed export. A new one replaces this file, keeping the name.
SCHEMATIC = REPO / "verification" / "board" / "CM-03545.json"
HOUSEKEEPER = WORKSPACE / "farsight-fpga-house-keeper"
HK_PINOUT = HOUSEKEEPER / "constr" / "a3pe3000l-fg484m" / "io" / "fm" / "io_constraints.pdc"
PINS = REPO / "constr" / "common" / "pins.tcl"
IO_PDC = REPO / "constr" / "mpf500ts-fc1152m" / "io" / "io_constraints.pdc"

PF = "U1"                       # the PolarFire's reference designator
HK = "U2"                       # the housekeeper's


def _line(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


@dataclass(frozen=True)
class Pin:
    component: str
    number: str
    name: str
    net: str
    sheet: str


class Schematic:
    """The export as the inspections ask of it: pins and nets by designator.

    A view of an `altium_sch_json.Design`, kept as `design` for anything
    richer -- parameters, footprints, the drawing number and revision.
    """

    def __init__(self, path: Path):
        self.path = path
        self.design = load(path)
        found = problems(self.design.raw)
        assert not found, "%s is not usable:\n  %s" % (path, "\n  ".join(found))
        self.parts = {}                 # designator -> (part number, comment)
        self.pins = {}                  # (designator, pin number) -> Pin
        self.nets = {}                  # net -> [Pin]
        self.of = {}                    # designator -> [Pin]
        for c in self.design.components.values():
            self.parts[c.designator] = (c.part_number or "", c.comment or "")
            for q in c.pins:
                p = Pin(c.designator, q.designator, q.name, q.net, q.sheet)
                self.pins[(p.component, p.number)] = p
                self.nets.setdefault(p.net, []).append(p)
                self.of.setdefault(p.component, []).append(p)

    @property
    def name(self) -> str:
        """The file, and the drawing and revision it says it was exported from."""
        d = self.design
        rev = " (%s rev %s)" % (d.drawing_number, d.revision) if d.drawing_number else ""
        return "%s%s" % (self.path.relative_to(REPO), rev)

    def cite(self, pin: Pin) -> str:
        return "%s, sheet %s, %s pin %s" % (self.name, pin.sheet, pin.component, pin.number)

    def pin(self, component: str, number: str) -> Pin | None:
        return self.pins.get((component, number))

    def _passive(self, designator: str) -> bool:
        return designator[:1] == "R" and len(self.of[designator]) == 2

    def reach(self, net: str) -> list:
        """The component pins a net reaches, through series resistors.

        A two-pin resistor is followed to its other net unless that net is a
        rail, so a pull-up or pull-down ends the trace there rather than
        joining every line on the same supply.
        """
        if _rail(net):
            return list(self.nets.get(net, []))
        seen, todo, ends = {net}, [net], []
        while todo:
            for p in self.nets.get(todo.pop(), []):
                if self._passive(p.component):
                    other = next(q for q in self.of[p.component] if q.number != p.number)
                    if other.net not in seen and not _rail(other.net):
                        seen.add(other.net)
                        todo.append(other.net)
                else:
                    ends.append(p)
        return ends


def _rail(net: str) -> bool:
    return bool(re.match(r"^(GND|AGND|DGND|CHAS|\+|VCC|VDD|\d+V\d*|\d+P\d+V)", net, re.I)) \
        or net.upper().startswith(("3V3", "2V5", "1V8", "1V2", "1V0", "5V"))


@lru_cache(maxsize=1)
def schematic() -> Schematic:
    """The committed schematic export, refused if it is not structurally sound."""
    return Schematic(SCHEMATIC)


@lru_cache(maxsize=1)
def housekeeper_pins() -> dict:
    """Housekeeper package pin -> (port, direction, `path:line`)."""
    if not HK_PINOUT.is_file():
        pytest.skip("no housekeeper design at %s" % HOUSEKEEPER)
    text = HK_PINOUT.read_text()
    out = {}
    for m in re.finditer(r'^set_io \{(\S+)\}\s+-pinname "(\w+)".*?-direction "(\w+)"', text, re.M):
        out[m.group(2)] = (m.group(1), m.group(3).upper(),
                           "%s:%d" % (HK_PINOUT.relative_to(WORKSPACE), _line(text, m.start())))
    return out


def pin_map() -> dict:
    """`pins.tcl`: signal -> (package pin, direction attribute, line)."""
    text = PINS.read_text()
    out = {}
    for m in re.finditer(r'^dict set pins \{(\S+)\}\s+\{pin_name "(\w+)"(.*?)\}\s*$', text, re.M):
        d = re.search(r'DIRECTION "(\w+)"', m.group(3))
        out[m.group(1)] = (m.group(2), d.group(1) if d else None, _line(text, m.start()))
    return out


def constrained_ports() -> dict:
    """`io_constraints.pdc`: port -> (the `pins.tcl` signal it takes, line)."""
    text = IO_PDC.read_text()
    out = {}
    for m in re.finditer(r"^lappend ports \[list \{(\S+)\}\s+\{(\S+)\}", text, re.M):
        out[m.group(1)] = (m.group(2), _line(text, m.start()))
    return out


def pin_report(designer: Path) -> dict:
    """The build's pin report: port -> (package pin, direction, state, line)."""
    path = designer / "top_pinrpt_number.rpt"
    lines = path.read_text().splitlines()
    head = next(i for i, l in enumerate(lines) if l.startswith("Number |"))
    starts = [0] + [m.start() + 1 for m in re.finditer(r"\|", lines[head])]
    names = [x.strip() for x in lines[head].split("|")]
    out = {}
    for i, l in enumerate(lines[head + 2:], start=head + 3):
        if not l.strip():
            continue
        cells = [l[a:b].strip() for a, b in zip(starts, starts[1:] + [None])]
        row = dict(zip(names, cells))
        if row.get("Port"):
            out[row["Port"]] = (row["Number"], row["Direction"].upper(), row["State"], i)
    return out
