"""The design as written: ports, pin assignments and drivers, for inspections.

Inspections (`test/inspect/`) check structural claims -- this output exists,
is on that ball, is driven only from there -- by reading the RTL and the pin
constraints directly, without a simulator. Regular expressions over this
design's own coding style, not a SystemVerilog parser: each helper refuses
rather than guesses when what it finds is not what it expects.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
SRC = REPO / "src"
TOP = SRC / "top.sv"
#: Pin constraints per board variant; FM is the flight board the committed
#: schematic export describes.
PDC = {v: REPO / "constr" / "a3pe3000l-fg484m" / "io" / v / "io_constraints.pdc"
       for v in ("fm", "em")}

_SET_IO = re.compile(r"^set_io\s+\{([\w\[\]]+)\}(.*)$", re.M)
_OPTION = re.compile(r"-(\w+)\s+\"?([^\s\"]+)\"?")


@dataclass
class PinConstraint:
    signal: str
    ball: str
    direction: str
    pull: str
    iostd: str


def pin_constraints(variant: str = "fm") -> dict:
    """Signal -> PinConstraint, from a variant's `set_io` lines. A bus bit is
    keyed as written, `debug[0]`."""
    out = {}
    for signal, rest in _SET_IO.findall(PDC[variant].read_text(encoding="utf-8")):
        opts = dict(_OPTION.findall(rest))
        out[signal] = PinConstraint(signal, opts.get("pinname", ""),
                                    opts.get("direction", ""), opts.get("RES_PULL", ""),
                                    opts.get("iostd", ""))
    return out


_PORT = re.compile(r"^\s*(input|output|inout)\s+(?:wire|logic|reg)?\s*"
                   r"(?:\[\s*(\d+)\s*:\s*(\d+)\s*\]\s*)?(\w+)\s*,?\s*(?://.*)?$", re.M)


def ports(path: Path = TOP) -> dict:
    """Port name -> "input" | "output" | "inout", from a module's port list."""
    return {name: direction for direction, _, _, name in _PORT.findall(path.read_text(encoding="utf-8"))}


def port_widths(path: Path = TOP) -> dict:
    """Port name -> width in bits (1 for a scalar)."""
    return {name: abs(int(hi) - int(lo)) + 1 if hi else 1
            for _, hi, lo, name in _PORT.findall(path.read_text(encoding="utf-8"))}


def port_bits(path: Path = TOP) -> dict:
    """Every bit of every port, as the pin constraints name it -> direction:
    `clk`, `debug[0]` ... `debug[6]`."""
    out = {}
    for direction, hi, lo, name in _PORT.findall(path.read_text(encoding="utf-8")):
        if hi:
            for i in range(min(int(hi), int(lo)), max(int(hi), int(lo)) + 1):
                out[f"{name}[{i}]"] = direction
        else:
            out[name] = direction
    return out


@dataclass
class Driver:
    file: str
    line: int
    statement: str
    block: str          # the whole always block, or the assign statement

    def __str__(self) -> str:
        return f"{self.file}:{self.line}: {self.statement}"


def drivers(signal: str, src: Path = SRC) -> list:
    """Every statement in the RTL that assigns `signal`, with its block.

    Procedural (`signal <= ...`, `signal = ...`) and continuous
    (`assign signal = ...`). A comparison (`==`, `<=` inside an expression) is
    not mistaken for an assignment because only a statement that starts with
    the signal counts.
    """
    stmt = re.compile(r"^\s*(?:if\s*\(.*\)\s*)?(?:assign\s+)?%s\s*(<=|=)(?!=)" % re.escape(signal))
    found = []
    for path in sorted(src.glob("*.sv")):
        lines = path.read_text(encoding="utf-8").splitlines()
        for n, line in enumerate(lines):
            if not stmt.match(line.split("//")[0]):
                continue
            if re.match(r"^\s*assign\b", line):
                block = line.strip()
            else:
                start = next((i for i in range(n, -1, -1)
                              if re.match(r"^\s*always", lines[i])), None)
                if start is None:
                    raise ValueError(f"{path.name}:{n + 1}: assigns {signal} outside any always "
                                     "block or assign statement; this helper cannot place it")
                block = "\n".join(lines[start:_block_end(lines, start) + 1])
            found.append(Driver(path.name, n + 1, line.strip(), block))
    return found


def _block_end(lines: list, start: int) -> int:
    """The line closing the always block that opens at `start`: where its
    begin/end nesting returns to zero."""
    depth, opened = 0, False
    for i in range(start, len(lines)):
        code = lines[i].split("//")[0]
        begins = len(re.findall(r"\bbegin\b", code))
        depth += begins - len(re.findall(r"\bend\b", code))
        opened = opened or begins > 0
        if opened and depth <= 0:
            return i
    raise ValueError("always block at line %d never closes" % (start + 1))


def connected_through(signal: str, src: Path = SRC) -> list:
    """The modules that declare `signal` as an output, and whether each one
    drives it itself or passes it on from an instance (`.signal` or
    `.signal(signal)`). A module that does neither leaves the output floating."""
    out = []
    for path in sorted(src.glob("*.sv")):
        if ports(path).get(signal) != "output":
            continue
        text = path.read_text(encoding="utf-8")
        passes = bool(re.search(r"\.%s\s*(?:\(\s*%s\s*\))?\s*[,)]" % (signal, signal), text))
        drives = any(d.file == path.name for d in drivers(signal, src))
        out.append((path.name, "drives" if drives else "passes on" if passes else "neither"))
    return out


# ---- the board, from the schematic export (an altium_sch_json.Design)

#: Nets that are a supply or ground rather than a signal, as far as a pull
#: resistor is concerned: the I/O supply of the housekeeper's banks, and ground.
SUPPLIES = {"3V3_ASIC": "up", "GND": "down"}


def two_pin(board, net: str, prefix: str = "R") -> list:
    """(designator, the net at its other end) for each two-pin part of this
    kind (resistors by default) with one end on `net`."""
    out = []
    for comp in board.nets[net].components():
        nets = [p.net for p in comp.pins]
        if comp.designator.startswith(prefix) and len(comp.pins) == 2 and net in nets:
            out.append((comp.designator, nets[1] if nets[0] == net else nets[0]))
    return out


def beyond_series(board, net: str) -> list:
    """The nets one series resistor away: resistors to a signal, not a supply."""
    return [far for _, far in two_pin(board, net) if far not in SUPPLIES]


def pulls(board, net: str) -> list:
    """(designator, "up" | "down") for each resistor from `net` to a supply."""
    return [(r, SUPPLIES[far]) for r, far in two_pin(board, net) if far in SUPPLIES]


def signal_nets(board, pad_net: str) -> list:
    """The pad's net and every net one series resistor beyond it: where a
    signal leaving or reaching the FPGA is named and pulled on the board."""
    return [pad_net] + beyond_series(board, pad_net)
