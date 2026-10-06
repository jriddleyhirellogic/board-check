"""Input glitch filtering: HK-IO-05 and HK-IO-06.

Items: VC-HK-0030, VC-HK-0031. Clause: VVP-HK-004.

  HK-IO-05  Every PGOOD, nFAULT and EPS eFuse PGOOD input shall be filtered
            such that a low-to-high or high-to-low transition is propagated
            only once the input has been stable at the new level for
            5 us +/-5 %.
  HK-IO-06  Every input by which the PolarFire commands a software-controlled
            power region shall be filtered the same way.

**`HK-IO-05` reaches inside the design, and says why.** The item asks for
both directions on all 45 inputs, and at the pins two of the six have no
consequence to observe: an nFAULT *rising* changes nothing (latchup is on a
low level, and a latched source ignores nFAULT), and the eFuse PGOOD *rising*
changes nothing (the power-down request it sets is set-only). The one
signal that shows every transition is the filter's own output, so the test
reads `glitch_filter.d_out` -- made addressable for that module alone
(`sim.run_device(internal=...)`), not by opening the whole design, which
costs a factor of ten. Every input has its own instance,
`health_monitor_io_0.glitch_filter_<pin>_sync`; one missing is itself a
failure.

And because the filter does not care what the rest of the design is doing,
all 45 are exercised in the first few milliseconds after reset, before
anything has booted and with no boot needed.

**The pulse widths are exact.** Every change is made on a falling clock
edge and held for a whole number of clocks, so a pulse of 237 clocks
(4.74 us) spans exactly 237 rising edges and one of 263 (5.26 us) exactly
263 -- the two edges of the 5 us +/-5 % band, each just outside it. The
filter must pass the second and not the first, in both directions, and must
pass every input with the same latency. The design's own threshold, 250
clocks, sits in the middle; the band is what is required of it.

**The band was confirmed by avionics hardware on 2026-10-01.** It was
proposed on 2026-09-29 for the "(TBR) 5us" of FAR-PM_FPGA_L4REQ-4, -5 and -14
and the ">= 5 us" of -17.

**`HK-IO-06` is at the pins, and fails.** The six control inputs are
synchronised but not filtered (`HK-F-15`), so a pulse of any width that a
synchroniser samples -- down to one clock -- starts or stops a region. The
test shows that on each of the six, both ways, and at 4.98 us and one clock.
"""

from __future__ import annotations

import cocotb
from cocotb.triggers import FallingEdge, Timer, ValueChange
from cocotb.utils import get_sim_time

from fsverif import board, boot, sim
from fsverif.clkrst import CLK_PERIOD_NS, advance, until
from fsverif.edges import Edges
from fsverif.pins import NFAULT_INPUTS, PGOOD_INPUTS, SOFTWARE_REGIONS, boundary

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

FILTERED = PGOOD_INPUTS + NFAULT_INPUTS
EFUSE = "eps_efuse_pgood"

#: `HK-IO-05`'s band, 5 us +/-5 %: 4.75 us to 5.25 us, or 237.5 to 262.5
#: clocks. Each edge is tested one clock outside the band.
BELOW_BAND = 237             # 4.74 us: must not pass
ABOVE_BAND = 263             # 5.26 us: must pass
#: The control-input test (`HK-IO-06`) pulses one clock short of the filter.
SHORT = PULSE_WIDTH - 1      # 4.98 us
SETTLE = 2 * PULSE_WIDTH     # long enough to see a transition come through

SOFTWARE = {r: enables for r, _, enables in SOFTWARE_REGIONS}
CONTROL = {r: ctrl for r, ctrl, _ in SOFTWARE_REGIONS}


def _now_ns() -> float:
    return get_sim_time("ns")


def _filter_out(dut, pin: str):
    """The filter output for `pin` -- inside the design; see the docstring."""
    io = dut.dut.health_monitor_io_0
    return getattr(getattr(io, "glitch_filter_%s_sync" % pin), "d_out")


class _Watch:
    """Every change of one internal signal, with its time."""

    def __init__(self, handle):
        self.handle, self.events = handle, []
        self._task = cocotb.start_soon(self._run())

    async def _run(self):
        while True:
            await ValueChange(self.handle)
            self.events.append((_now_ns(), int(self.handle.value)))

    def stop(self):
        self._task.cancel()


def _rail_for(pin: str) -> str:
    if pin in PGOOD_INPUTS:
        return pin
    return next(r.pgood for r in board.model() if r.nfault == pin)


def _drive(dut, pin: str, level: int) -> None:
    """Put `pin` at `level` with the board's rail controls, everything else
    left at rest."""
    rail = _rail_for(pin)
    if pin in NFAULT_INPUTS:
        board.drive(dut, fault=(rail,) if level == 0 else ())
    elif pin == EFUSE:
        # High through `rail_force`, not by releasing `rail_fail`: the model
        # brings a released rail back up through its delay counter, a clock or
        # two late, which would lengthen every low pulse by that much.
        board.drive(dut, fail=(rail,) if level == 0 else (),
                    force=(rail,) if level == 1 else ())
    else:
        # Both levels held explicitly: an LT3065 rail's PGOOD rests HIGH while
        # its enable is low (`fsverif.board`), so releasing it is not "low".
        board.drive(dut, fail=(rail,) if level == 0 else (),
                    force=(rail,) if level == 1 else ())


async def _clocks(dut, n: int) -> None:
    await Timer(n * CLK_PERIOD_NS, unit="ns")


async def _pulse(dut, pin: str, level: int, clocks: int, back: int) -> float:
    """Hold `pin` at `level` for exactly `clocks`, then return it to `back`.
    Returns the time the pulse began."""
    await FallingEdge(dut.clk)
    _drive(dut, pin, level)
    began = _now_ns()
    await _clocks(dut, clocks)
    _drive(dut, pin, back)
    return began


@cocotb.test()
async def test_HK_IO_05_pgood_nfault_5us_filter(dut):
    """VC-HK-0030: 4.74 us does not pass, 5.26 us does, both ways, all 45."""
    board.drive(dut)
    await boot.release(dut)
    await advance(dut.clk, cycles=10)

    problems, latencies = [], {}
    for pin in FILTERED:
        try:
            out = _filter_out(dut, pin)
        except AttributeError:
            problems.append("%s: no glitch_filter instance -- the input is not "
                            "filtered" % pin)
            continue
        rest = int(boundary(dut, pin).value)
        other = 1 - rest
        if int(out.value) != rest:
            problems.append("%s: filter output %d does not match the input at "
                            "rest, %d" % (pin, int(out.value), rest))
            continue
        watch = _Watch(out)
        at_pin = _Watch(boundary(dut, pin))

        # rest -> other, below the band then above it.
        await _pulse(dut, pin, other, BELOW_BAND, rest)
        await _clocks(dut, SETTLE)
        passed_short = list(watch.events)
        began = await _pulse(dut, pin, other, ABOVE_BAND, rest)
        await _clocks(dut, SETTLE)
        after_exact = watch.events[len(passed_short):]

        # Now hold `other`, and pulse back to rest: the opposite direction.
        await FallingEdge(dut.clk)
        _drive(dut, pin, other)
        await _clocks(dut, SETTLE)
        mark = len(watch.events)
        await _pulse(dut, pin, rest, BELOW_BAND, other)
        await _clocks(dut, SETTLE)
        passed_short_back = watch.events[mark:]
        mark = len(watch.events)
        began_back = await _pulse(dut, pin, rest, ABOVE_BAND, other)
        await _clocks(dut, SETTLE)
        after_exact_back = watch.events[mark:]

        await FallingEdge(dut.clk)
        _drive(dut, pin, rest)
        await _clocks(dut, SETTLE)
        watch.stop()
        at_pin.stop()

        # The stimulus, measured where the device sees it: the four pulses,
        # each exactly as long as intended, or the result says nothing.
        widths = [round((b[0] - a[0]) / CLK_PERIOD_NS)
                  for a, b in zip(at_pin.events, at_pin.events[1:])]
        # Transitions: pulse, gap, pulse, gap, the hold at the other level,
        # then pulse, gap, pulse -- so the pulses are widths 0, 2, 5 and 7.
        pulses = [widths[i] for i in (0, 2, 5, 7)] if len(widths) >= 8 else widths
        if pulses != [BELOW_BAND, ABOVE_BAND, BELOW_BAND, ABOVE_BAND]:
            problems.append("%s: the stimulus at the pin was %s clocks, not "
                            "%s -- a test fault, not a design one"
                            % (pin, pulses, [BELOW_BAND, ABOVE_BAND, BELOW_BAND, ABOVE_BAND]))
            continue

        for direction, short, exact, start, to in (
                ("%d->%d" % (rest, other), passed_short, after_exact, began, other),
                ("%d->%d" % (other, rest), passed_short_back, after_exact_back,
                 began_back, rest)):
            if short:
                problems.append("%s %s: a %d-clock pulse passed the filter"
                                % (pin, direction, BELOW_BAND))
            first = [t for t, v in exact if v == to]
            if not first:
                problems.append("%s %s: a %d-clock level did not pass the filter"
                                % (pin, direction, ABOVE_BAND))
            else:
                latencies[(pin, direction)] = round((first[0] - start)
                                                    / CLK_PERIOD_NS)

    spread = sorted(set(latencies.values()))
    dut._log.info("%d inputs, %d directions checked; pin-to-filter latency "
                  "%s clocks", len(FILTERED), len(latencies),
                  " / ".join(str(n) for n in spread))
    if len(spread) > 1:
        odd = [k for k, v in latencies.items() if v != spread[0]]
        problems.append("the filter latency is not the same for every input: "
                        "%s" % ", ".join("%s %s = %d" % (p, d, latencies[(p, d)])
                                         for p, d in odd))
    assert not problems, (
        "the PGOOD, nFAULT and eFuse inputs are not all filtered to 5 us "
        "+/-5 % in both directions:\n  " + "\n  ".join(problems))


@cocotb.test()
async def test_HK_IO_06_control_input_5us_filter(dut):
    """VC-HK-0031: pulses on the six control inputs, and what they do.

    Each region in turn, from down: a high pulse of one clock and of 249
    clocks, each of which must not start it. Then the region requested and
    booted: a low pulse of one clock and of 249, each of which must not
    power it down.
    """
    board.drive(dut)
    await boot.hardware(dut)
    problems = []
    for region, enables in SOFTWARE.items():
        control, status = CONTROL[region], "%s_status_to_pf" % region
        for clocks in (1, SHORT):
            # Watched from before the pulse: a region started by a long
            # pulse is enabled, and withdrawn again, before the pulse ends.
            edges = Edges(dut, (enables[0],), origin_ns=0)
            await FallingEdge(dut.clk)
            boundary(dut, control).value = 1
            await _clocks(dut, clocks)
            boundary(dut, control).value = 0
            await advance(dut.clk, seconds=0.001)
            edges.stop()
            if edges.rises(enables[0]):
                problems.append("%s: a %d-clock high pulse on %s started it"
                                % (region, clocks, control))
            await advance(dut.clk, seconds=0.003)

        boundary(dut, control).value = 1
        await until(dut.clk, lambda: int(boundary(dut, status).value) == 1,
                    timeout_s=0.1, poll_ms=0.1)
        for clocks in (1, SHORT):
            await FallingEdge(dut.clk)
            boundary(dut, control).value = 0
            await _clocks(dut, clocks)
            boundary(dut, control).value = 1
            await advance(dut.clk, seconds=0.0001)
            if not int(boundary(dut, status).value):
                problems.append("%s: a %d-clock low pulse on %s powered it down"
                                % (region, clocks, control))
                await until(dut.clk, lambda: not any(
                    int(boundary(dut, e).value) for e in enables),
                    timeout_s=0.01, poll_ms=0.1)
                boundary(dut, control).value = 0
                await advance(dut.clk, seconds=0.003)
                boundary(dut, control).value = 1
                await until(dut.clk, lambda: int(boundary(dut, status).value) == 1,
                            timeout_s=0.1, poll_ms=0.1)
        boundary(dut, control).value = 0
        await advance(dut.clk, seconds=0.003)

    dut._log.info("control-input pulses that acted: %d of %d", len(problems),
                  len(SOFTWARE) * 4)
    assert not problems, (
        "the control inputs are not filtered -- pulses far shorter than 5 us "
        "started and stopped regions:\n  " + "\n  ".join(problems)
        + "\nThey are synchronised but not filtered (health_monitor_io.sv:334-354). "
        "HK-F-15.")


def test_hk_io_filter():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_io_filter",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
        internal=[("glitch_filter", "d_out")],
    )
