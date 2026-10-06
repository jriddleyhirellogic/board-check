"""Every register asynchronously reset: DRV-HK-05, in simulation.

Item: VC-HK-0114. Clause: VVP-HK-004.

  DRV-HK-05  Every register in the design shall be asynchronously reset to a
             defined state, unless that register is individually recorded as
             an approved exception.

`HK-CLK-03` shows at the pins that reset does nothing without a clock. This
is the same question asked of every register, which is what the requirement
is about -- a register that drives no pin can still, on a later clock, turn
a rail on (`eth1_ctrl_r1` and its siblings, `HK-F-18`).

**It reaches inside the design, for every register it can name.** The
registers are read from the RTL -- every left-hand side of a non-blocking
assignment in an `always_ff` block, module by module -- and made addressable
for those modules alone (`sim.run_device(internal=...)`). The hierarchy is
then walked, so that every *instance* is reached: 33 source state machines,
11 region state machines, 45 filters and the rest. The vendor UART core is
not ours and is not included.

The comparison is with the device's own reset values, read while reset is
held *with* the clock running. Then the device is booted, so that registers
move away from those values; the clock is stopped; reset is asserted between
edges; and every register is read with no edge having occurred. A register
that is back at its reset value was reset asynchronously, or was already
there -- the second is counted separately, as not exercised, rather than
credited. A register that is not is the failure the requirement exists to
prevent. There is no approved exception list, so every one counts.
"""

from __future__ import annotations

import re
from pathlib import Path

import cocotb
from cocotb.handle import HierarchyArrayObject, HierarchyObject
from cocotb.triggers import Timer

from fsverif import board, boot, sim
from fsverif.clkrst import advance, elapse, until
from fsverif.pins import CLOCK_ENABLE, RESET_N, boundary

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

SRC = Path(__file__).resolve().parents[2] / "src"


def _always_ff_bodies(text: str):
    """The body of every `always_ff` block, by begin/end nesting -- not by
    the next line that starts with `end`, which `endgenerate` also does."""
    for start in re.finditer(r"always_ff\s*@\s*\([^)]*\)\s*begin\b", text):
        depth, pos = 1, start.end()
        for token in re.finditer(r"\b(begin|end)\b", text[pos:]):
            depth += 1 if token.group(1) == "begin" else -1
            if depth == 0:
                yield text[pos:pos + token.start()]
                break


def registers() -> dict:
    """{module: {register: has a reset branch}}, read from the RTL."""
    found = {}
    for path in sorted(SRC.glob("*.sv")):
        text = re.sub(r"//[^\n]*", "", path.read_text(encoding="utf-8"))
        module = re.search(r"^\s*module\s+(\w+)", text, re.M)
        if not module:
            continue
        regs = {}
        for body in _always_ff_bodies(text):
            reset = "!rstn" in body or "!arstn" in body
            for name in re.findall(r"(\w+)\s*(?:\[[^\]]*\])?\s*<=", body):
                regs[name] = regs.get(name, False) or reset
        if regs:
            found[module.group(1)] = regs
    return found


REGISTERS = registers()
INTERNAL = [(m, r) for m, regs in REGISTERS.items() for r in regs]
ALL_NAMES = {r for regs in REGISTERS.values() for r in regs}
UNRESET = {(m, r) for m, regs in REGISTERS.items() for r, has in regs.items()
           if not has}


def _walk(handle, path: str, out: dict) -> None:
    for child in handle:
        name = child._name
        here = "%s.%s" % (path, name)
        if isinstance(child, (HierarchyObject, HierarchyArrayObject)):
            _walk(child, here, out)
        elif name in ALL_NAMES:
            out[here] = child


def _read(handles: dict) -> dict:
    return {p: int(h.value) for p, h in handles.items()}


@cocotb.test()
async def test_DRV_HK_05_reset_without_clock(dut):
    """VC-HK-0114: every register, reset with no clock, and where it ends up."""
    handles = {}
    _walk(dut.dut, "dut", handles)
    assert handles, "no register of the design was reachable"

    reset_n, clock = getattr(dut, RESET_N), getattr(dut, CLOCK_ENABLE)
    board.drive(dut)
    reset_n.value = 0
    await advance(dut.clk, cycles=20)
    reference = _read(handles)

    await boot.hardware(dut)
    boundary(dut, "imx_ctrl").value = 1
    await until(dut.clk, lambda: int(boundary(dut, "imx_status_to_pf").value),
                timeout_s=0.1, poll_ms=0.1)
    before = _read(handles)

    clock.value = 0
    await elapse(cycles=2)
    await Timer(7, unit="ns")
    reset_n.value = 0
    await Timer(1000, unit="ns")
    stopped = _read(handles)
    clock.value = 1
    await advance(dut.clk, cycles=20)
    clocked = _read(handles)
    reset_n.value = 1

    moved = [p for p in handles if before[p] != reference[p]]
    held = [p for p in moved if stopped[p] != reference[p]]
    reached = [p for p in moved if stopped[p] == reference[p]]
    unexercised = len(handles) - len(moved)
    never = [p for p in moved if clocked[p] != reference[p]]
    by_name = {}
    for p in held:
        by_name.setdefault(p.rsplit(".", 1)[1], []).append(p)
    dut._log.info("%d register instances reached; %d moved away from their "
                  "reset value when booted; with the clock stopped and reset "
                  "asserted, %d returned to it and %d did not; %d not moved, so "
                  "not exercised; %d not reset even with the clock", len(handles),
                  len(moved), len(reached), len(held), unexercised, len(never))
    dut._log.info("reset asynchronously: %s", ", ".join(sorted(reached)) or "none")
    assert not held, (
        "with the clock stopped, reset left %d of the %d register instances "
        "that had moved away from their reset value where they were. By "
        "register: %s. Only reset_synchronizer resets asynchronously "
        "(reset_synchronizer.sv:25); everything else is reset inside "
        "always_ff @(posedge clk), and %d registers have no reset at all: %s. "
        "There is no approved exception list. HK-F-18."
        % (len(held), len(moved), ", ".join(
            "%s x%d" % (n, len(ps)) for n, ps in sorted(by_name.items())),
           len(UNRESET), ", ".join("%s.%s" % mr for mr in sorted(UNRESET))))


def test_hk_drv_reset():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_drv_reset",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
        internal=INTERNAL,
    )
