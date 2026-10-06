"""Generate the simulation wrapper that carries the clock.

cocotb's `Clock` toggles the clock from a Python coroutine, which costs a
callback on every edge. At the flight `WAIT_TIME_MULT_FACTOR` a one-second
wait is fifty million clocks, so the clock alone was the difference between a
four-minute run and a sixteen-minute one: measured at 62,429 cycles/s with the
Python clock against 239,202 with the clock in Verilog, on the same design.

So the clock lives in a wrapper module and Verilator runs it freely. cocotb
drives and observes the wrapper's wires, which are the device's pins, so test
code is unchanged -- `dut.arstn` resolves to the wrapper's wire rather than
the device's port, and means the same thing.

**The wrapper is generated at build time and never committed.** It restates
115 port declarations, and a hand-written copy would drift the first time
somebody adds a port: the design would elaborate against a wrapper that does
not mention the new pin, and the test would be driving a device with one input
permanently undriven. Generating it from `top.sv` on every build makes that
impossible rather than merely detectable.
"""

from __future__ import annotations

import re
from pathlib import Path

#: A port declaration in the device's port list. The design declares all 115
#: uniformly as `input wire` / `output wire`, with an optional packed range.
PORT = re.compile(
    r"^\s*(input|output)\s+wire\s+(\[[^\]]*\]\s*)?(\w+)\s*,?\s*$", re.M)

#: A parameter of the device. The wrapper redeclares each one and passes it
#: down, so that `-G` on the wrapper still reaches the device. Without this the
#: device would silently take its defaults and `VENV-02` -- exercise the design
#: at its synthesis parameter values -- would be unenforceable: a run would
#: look parameterised and not be.
PARAMETER = re.compile(
    r"^\s*parameter\s+(?P<type>[\w\s]*?(?:\[[^\]]*\])?)\s*"
    r"(?P<name>\w+)\s*=\s*(?P<default>[^,)/\n]+)", re.M)

#: The pin the clock arrives on. It is driven by the wrapper rather than
#: connected through, so it is excluded from the generated wire list.
CLOCK = "clk"

#: Name of the wrapper's clock-enable wire. A test drives this low to stop the
#: clock -- `HK-OFFNOM-04` requires every power enable to go inactive on loss
#: of the input clock, which cannot be tested if the clock cannot be stopped.
CLOCK_ENABLE = "clk_enable"


class WrapperError(Exception):
    """The device's port list could not be read."""


def ports(source: str) -> list:
    """Every port of the device, as `(direction, range, name)`."""
    found = PORT.findall(source)
    if not found:
        raise WrapperError(
            "no port declarations found. The wrapper carries the clock and "
            "connects every pin, so a device with no readable ports would "
            "generate a wrapper that compiles and drives nothing.")
    return found


def parameters(source: str) -> list:
    """Every parameter of the device, as `(type, name, default)`."""
    header = source.split(") (")[0] if ") (" in source else source
    return [(m.group("type").strip(), m.group("name"), m.group("default").strip())
            for m in PARAMETER.finditer(header)]


#: The wrapper's fault-injection wires. A bit high in `rail_fail` holds that
#: rail out of regulation; a bit high in `rail_fault` trips its overcurrent
#: fault pin; a bit high in `rail_force` holds its power-good high whatever
#: its enable. Bit order for all three is `fsverif.board.index`.
RAIL_FAIL = "rail_fail"
RAIL_FAULT = "rail_fault"
RAIL_FORCE = "rail_force"


def board_instance(rail_list: list) -> str:
    """The board model, wired to the pins it drives and the pins it watches.

    Connected by name from the rail list rather than written out, so a rail
    that appears in the schematic cannot be left out of the wrapper: the same
    list generates the model's ports and these connections.
    """
    if not rail_list:
        return ""
    from fsverif.board import UPSTREAM

    # A rail sourced from a constant has no pin to connect -- the EPS e-fuse
    # is upstream of this board, so the model ties it rather than watching an
    # enable. The same filter runs when the model's ports are generated; both
    # read it from the one rail list, so they cannot disagree.
    driven = {rail.pgood for rail in rail_list}
    names = sorted({r.source for r in rail_list} - driven - {UPSTREAM}) \
        + sorted(driven) \
        + sorted(r.nfault for r in rail_list if r.nfault)
    return """
  // The board's power rails. Every power-good and fault input is driven from
  // here, so a test does not set them: it lets the sequence run and, where it
  // is testing a failure, holds a rail down with `%(fail)s`, trips its
  // overcurrent pin with `%(fault)s`, or holds its power-good high with
  // `%(force)s`.
  logic [%(top)d:0] %(fail)s = '0;
  logic [%(top)d:0] %(fault)s = '0;
  logic [%(top)d:0] %(force)s = '0;

  board_model board (.%(clock)s(%(clock)s), .%(fail)s(%(fail)s),
    .%(fault)s(%(fault)s), .%(force)s(%(force)s),
%(conns)s);
""" % {
        "fail": RAIL_FAIL, "fault": RAIL_FAULT, "force": RAIL_FORCE,
        "top": len(rail_list) - 1, "clock": CLOCK,
        "conns": ",\n".join("    .%s(%s)" % (n, n) for n in names),
    }


def generate(source_path: Path, period_ns: int, module: str = "tb_top",
             device: str = "top", board: list | None = None) -> str:
    """The wrapper source for a device, with the clock inside it."""
    source = source_path.read_text(encoding="utf-8")
    params = parameters(source)
    declarations, connections = [], []
    for direction, width, name in ports(source):
        if name == CLOCK:
            continue
        declarations.append("  logic %s%s;" % (width or "", name))
        connections.append(".%s(%s)" % (name, name))

    if not connections:
        raise WrapperError(
            "%s declares only a clock. A wrapper connecting nothing would "
            "elaborate and test nothing." % source_path)

    param_decl = ("#(\n%s\n) " % ",\n".join(
        "    parameter %s %s = %s" % (t, n, d) for t, n, d in params)
        if params else "")
    param_pass = ("#(%s) " % ", ".join(".%s(%s)" % (n, n) for _, n, _ in params)
                  if params else "")

    return """// GENERATED -- do not edit, and do not commit.
//
// Written by fsverif.wrapper on every build, from the device's own port list.
// The clock lives here rather than in cocotb: driving it from Python costs a
// callback per edge, which at the flight timing parameters is the difference
// between a four-minute run and a sixteen-minute one.
//
// Regenerated rather than stored, so it cannot describe a device that has
// gained or lost a pin since it was written.

module %(module)s %(param_decl)s;

  localparam int unsigned PERIOD_NS = %(period)d;

  // Driven low by a test to stop the clock. HK-OFFNOM-04 requires every power
  // enable to go inactive on loss of the input clock, and that cannot be
  // exercised if the clock cannot be stopped.
  logic %(enable)s = 1'b1;
  logic %(clock)s = 1'b0;

  always #(PERIOD_NS / 2) %(clock)s = %(enable)s ? ~%(clock)s : %(clock)s;

%(declarations)s
%(board)s
  %(device)s %(param_pass)sdut (.%(clock)s(%(clock)s), %(connections)s);

endmodule
""" % {
        "module": module,
        "device": device,
        "param_decl": param_decl,
        "param_pass": param_pass,
        "period": period_ns,
        "clock": CLOCK,
        "enable": CLOCK_ENABLE,
        "declarations": "\n".join(declarations),
        "connections": ", ".join(connections),
        "board": board_instance(board or []),
    }


def write(source_path: Path, into: Path, period_ns: int,
          module: str = "tb_top", device: str = "top",
          board: list | None = None) -> Path:
    """Generate the wrapper into `into`, returning the file written."""
    into.mkdir(parents=True, exist_ok=True)
    target = into / ("%s.sv" % module)
    fresh = generate(source_path, period_ns, module, device, board)
    # Written only when it differs. Rewriting an identical file moves its
    # timestamp, which makes the build system recompile the whole device on
    # every run for no change -- under ten seconds for a lean build, and
    # considerably more for a full-visibility one.
    if not target.is_file() or target.read_text(encoding="utf-8") != fresh:
        target.write_text(fresh, encoding="utf-8")
    return target
