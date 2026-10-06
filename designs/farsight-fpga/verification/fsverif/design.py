"""Read the design's own numbers, for analyses.

An analysis is only as good as its inputs, and an input typed into the
analysis is a second definition of something the design already defines: the
day the design changes, the analysis goes on agreeing with itself. So every
input an analysis uses comes through here, read from where the build reads it,
and carries a citation -- the file and line it came from -- into the recorded
calculation.

Each reader returns a `Value`: the number, and where it was found.
"""

from __future__ import annotations

import os
import re
from dataclasses import dataclass
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
#: Where the other repositories and inputs this one reads are found: the
#: housekeeper and flight software checkouts and `board-check/datasheets`. The
#: directory holding this checkout, unless `FSVERIF_WORKSPACE` says otherwise --
#: as CI does, assembling them under its own build directory.
WORKSPACE = Path(os.environ.get("FSVERIF_WORKSPACE") or REPO.parent).resolve()
BOARD = "mpf500ts-fc1152m"
BD = REPO / "bd" / BOARD


@dataclass(frozen=True)
class Value:
    value: object
    source: str                     # `path:line`, relative to the repository

    def __float__(self) -> float:
        return float(self.value)

    def __int__(self) -> int:
        return int(self.value)


def _cite(path: Path, offset: int, text: str) -> str:
    return "%s:%d" % (path.relative_to(REPO), text.count("\n", 0, offset) + 1)


def _number(text: str):
    try:
        return int(text)
    except ValueError:
        return float(text)


def instance_param(tcl: Path, instance: str, name: str) -> Value:
    """A parameter a SmartDesign sets on one of its instances."""
    text = tcl.read_text()
    block = re.search(r"-instance_name \{%s\} -params \{(.*?)\}" % re.escape(instance), text, re.S)
    if not block:
        raise KeyError("%s configures no instance %s" % (tcl.name, instance))
    m = re.search(r'"%s:([^"]*)"' % re.escape(name), block.group(1))
    if not m:
        raise KeyError("%s sets no %s on %s" % (tcl.name, name, instance))
    return Value(_number(m.group(1)), _cite(tcl, block.start(1) + m.start(), text))


def core_param(tcl: Path, name: str) -> Value:
    """A parameter of a configured vendor core (`create_and_configure_core`)."""
    text = tcl.read_text()
    m = re.search(r'"%s:([^"]*)"' % re.escape(name), text)
    if not m:
        raise KeyError("%s sets no %s" % (tcl.name, name))
    raw = m.group(1)
    try:
        value = _number(raw)
    except ValueError:
        value = raw
    return Value(value, _cite(tcl, m.start(), text))


def localparam(src: Path, name: str) -> Value:
    """A Verilog `localparam` (or `parameter` default) with a numeric value."""
    text = src.read_text()
    m = re.search(r"\b(?:localparam|parameter)\b[^;=]*?\b%s\s*=\s*(?:\d+')?[dD]?([0-9_]+)"
                  % re.escape(name), text)
    if not m:
        raise KeyError("%s defines no numeric %s" % (src.name, name))
    return Value(int(m.group(1).replace("_", "")), _cite(src, m.start(), text))


def find(src: Path, pattern: str) -> Value:
    """The first match of a regular expression, with its line: for facts that
    are wiring or code rather than numbers."""
    text = src.read_text()
    m = re.search(pattern, text, re.M)
    if not m:
        raise KeyError("%s has no match for %s" % (src.name, pattern))
    return Value(m.group(1) if m.groups() else m.group(0), _cite(src, m.start(), text))


def firmware(relative: str, pattern: str) -> Value:
    """A constant in flight software, `farsight-avionics-sw/<relative>`."""
    path = WORKSPACE / "farsight-avionics-sw" / relative
    text = path.read_text()
    m = re.search(pattern, text, re.M)
    if not m:
        raise KeyError("%s has no match for %s" % (relative, pattern))
    line = text.count("\n", 0, m.start()) + 1
    return Value(_number(m.group(1)), "farsight-avionics-sw/%s:%d" % (relative, line))


def derived_clock_period_ns(pin_substring: str) -> Value:
    """A generated clock's period, from the newest retained build's derived
    constraints. The build directory is not in the repository, so the
    citation names the build."""
    builds = sorted((REPO / "build").glob("%s_*/constraint/top_derived_constraints.sdc" % BOARD))
    if not builds:
        raise FileNotFoundError("no retained build under build/; run an FPGA build")
    sdc = builds[-1]
    text = sdc.read_text()
    for m in re.finditer(r"^create(?:_generated)?_clock .*$", text, re.M):
        if pin_substring in m.group(0):
            p = re.search(r"-period\s+([0-9.]+)", m.group(0))
            if p:
                return Value(float(p.group(1)), _cite(sdc, m.start(), text))
    raise KeyError("no clock on %s in %s" % (pin_substring, sdc))


class Record:
    """The recorded calculation: inputs with their sources, then the working."""

    def __init__(self, item: str, title: str):
        self.item, self.title = item, title
        self.lines = []

    def input(self, label: str, v: Value, unit: str = "") -> object:
        self.lines.append("- **%s:** %s%s (`%s`)" % (label, v.value, " " + unit if unit else "",
                                                      v.source))
        return v.value

    def given(self, label: str, value, unit: str, source: str) -> object:
        """An input that is not in the design: a requirement's number, an ICD's."""
        self.lines.append("- **%s:** %s%s (%s)" % (label, value, " " + unit if unit else "", source))
        return value

    def step(self, text: str) -> None:
        self.lines.append("- %s" % text)

    def text(self) -> str:
        return "## %s -- %s\n\n%s\n" % (self.item, self.title, "\n".join(self.lines))


STEP_DIR = REPO / "ip" / "focus_mech_ip" / "hw" / "ip" / "stepper_ip" / "src" / "STEP_DIR.sv"


def stepper_cycles(r: Record) -> dict:
    """The stepper's pin timing in clock cycles, as `STEP_DIR.sv` produces it.

    Each counter is reloaded on the edge that changes the pin and acts on the
    edge after it reaches zero, so every interval is its constant plus one:
    the step period is `const_step_min_dt` + 1, the step-high time
    `const_step_fall` + 1, the step-low time their difference, and the
    direction setup at least `const_dir_hold` + 1.
    """
    dt = r.input("`const_step_min_dt`", localparam(STEP_DIR, "const_step_min_dt"), "cycles")
    fall = r.input("`const_step_fall`", localparam(STEP_DIR, "const_step_fall"), "cycles")
    hold = r.input("`const_dir_hold`", localparam(STEP_DIR, "const_dir_hold"), "cycles")
    r.input("Reload on the step edge", find(STEP_DIR, r"(step_min_dt_counter <= const_step_min_dt;\s*dir_setup_counter <= dir_setup_counter;\s*step_fall_counter <= const_step_fall;)"))
    r.input("Step falls the edge after its counter reaches 0", find(STEP_DIR, r"(else if \(step_fall_counter == 0 && o_step == 1\))"))
    r.input("Next step the edge after both counters reach 0", find(STEP_DIR, r"(else if \(step_min_dt_counter == 0 && dir_setup_counter == 0\))"))
    r.input("Direction change reloads the setup counter", find(STEP_DIR, r"(dir_setup_counter <= const_dir_hold;)"))
    out = {"interval": dt + 1, "high": fall + 1, "low": dt - fall, "setup": hold + 1}
    r.step("As built: step period %(interval)d cycles, high %(high)d, low %(low)d, direction "
           "setup at least %(setup)d" % out)
    return out
