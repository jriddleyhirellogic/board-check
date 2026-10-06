"""A latched region: HK-REG-08 and HK-REG-09.

Items: VC-HK-0049, VC-HK-0050. Clause: VVP-HK-004.

  HK-REG-08  A region shall be declared latched up for as long as any source
             within it is declared latched up.
  HK-REG-09  A region declared latched up shall deassert every enable in the
             region.

**The subject is the IMX region, and it has to be a software region.** A
latchup in any hardware region raises `critical_latchup`
(`health_monitor.sv:722-723`), which holds *every* region in reset. Every enable
on the device then falls regardless of what the latched region does, so a
test of `HK-REG-09` written against DDR8 passes whether or not the region
logic is correct. `HK-LAT-02` and `HK-LAT-03` are about that global response.
This module is about the region's own response, and the IMX region is where
it can be seen on its own: four sources, and a wired nFAULT on the first.

The stimulus is that nFAULT, asserted after the region has fully booted. The
first source is the one that latches, so the three after it are sources that
had booted successfully. Those are the ones `HK-REG-09`'s item names, and
the ones a design that only disabled the failing source would leave on.

**A region's latch is not a pin.** What the board can see is its consequence.
For `HK-REG-09` that is the enables. For `HK-REG-08` it is whether the region
will accept a request: a latched region ignores `imx_ctrl`, and one that has
left the latch boots on the next rising edge of it (`HK-SEQ-05`). So the
test probes the region with requests on either side of the moment the
source's latch ends, and the region's latch is bracketed by which of them it
refuses.

**Only one source can be latched at a time here, and that limits what this
can show.** The criterion's "any source" and "the last such source clears"
describe several sources latched together and clearing apart. That cannot be
produced at the pins: the moment one source latches, the region drives every
other source to power down (`pwr_region_sm.sv:169`), and a source powering
down no longer checks for a latchup. Two sources faulted in the same clock
cycle would latch together, but every source has the same hold
(`LATCHUP_WAIT_TIME`) and they would clear together too. So this verifies the
one-source case exactly and says so; the OR over sources is by construction
(`pwr_region_imx_bootseq.sv:77`) and is not observable beyond it.
"""

from __future__ import annotations

import cocotb
from cocotb.triggers import FallingEdge, with_timeout

from fsverif import board, boot, sim
from fsverif.clkrst import advance, until
from fsverif.edges import Edges
from fsverif.pins import SOFTWARE_REGIONS, boundary

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

REGION = "imx"
CONTROL = "imx_ctrl"
STATUS = "imx_status_to_pf"
ENABLES = dict((name, enables) for name, _, enables in SOFTWARE_REGIONS)[REGION]

#: The source that latches, and the rail whose fault pin is asserted. 1V1 is
#: the only IMX source with its nFAULT wired (configuration table).
FAULTED_ENABLE = "imx_en_1v1"
FAULTED_RAIL = "imx_pgood_1v1"
PGOODS = ("imx_pgood_1v1", "imx_pgood_1v8", "imx_pgood_2v9", "imx_pgood_3v3")

#: How long a source stays latched: 7 ticks of 2^14 clocks = 2.294 ms, from
#: the derived-timing table. The counter is cleared on entry to LATCHUP
#: (`pwr_src_bootseq.sv:114`), prescaler included, so there is no phase to
#: allow for.
SOURCE_HOLD_MS = 7 * (1 << 14) * 20e-6

#: The two probes of `HK-REG-08`, either side of the source's latch ending.
#: Symmetric, and wide enough for the few clock cycles of synchronisation on
#: `imx_ctrl`; narrow enough that a region staying latched even a third of a
#: millisecond past its source would be caught.
PROBE_MARGIN_MS = 0.3

#: How long a request may take to reach the region's first enable, once the
#: region is free to act on it: a synchroniser, an edge detector and two state
#: machines, a handful of cycles.
RESPONSE_MS = 0.1

#: `HK-REG-09` gives no bound -- `HK-LAT-08` is the requirement that will, and
#: its value is TBR (`HK-F-26`). This is an allowance, not that bound: long
#: enough that no correct design fails it, short enough that "eventually,
#: after the latch has cleared" does not pass for "when latched".
REGION_FOLLOWS_MS = 0.1


async def _boot_region(dut) -> Edges:
    """Boot the hardware, request the IMX region, and wait until it is up."""
    dut.rail_fail.value = 0
    dut.rail_fault.value = 0
    await boot.hardware(dut)

    edges = Edges(dut, ENABLES + PGOODS + (STATUS,))
    boundary(dut, CONTROL).value = 1
    await until(
        dut.clk, lambda: int(boundary(dut, STATUS).value) == 1,
        timeout_s=1.0,
        describe=lambda: "the IMX region never reported booted after being "
                         "requested; enables up: %s"
                         % (", ".join(boot.asserted(dut)) or "none"))

    not_good = [p for p in PGOODS if int(boundary(dut, p).value) != 1]
    assert not not_good, (
        "the IMX region reports booted but these rails are not good, so the "
        "sources after the faulted one have not all booted and the test "
        "would not be exercising what the item asks: %s" % ", ".join(not_good))
    return edges


async def _latch(dut, edges: Edges) -> float:
    """Assert the first source's nFAULT and return when its enable fell."""
    faulted = boundary(dut, FAULTED_ENABLE)
    dut.rail_fault.value = 1 << board.index(board.model())[FAULTED_RAIL]
    try:
        await with_timeout(FallingEdge(faulted), 1, "ms")
    except cocotb.triggers.SimTimeoutError:
        raise AssertionError(
            "%s stayed asserted for 1 ms after its nFAULT was driven low, so "
            "no latchup was declared at all and there is no latched region "
            "to test. That is HK-LAT-01's failure, not this one's."
            % FAULTED_ENABLE) from None
    return edges.now_ms()


@cocotb.test()
async def test_HK_REG_09_latched_region_deasserts_enables(dut):
    """VC-HK-0050: every enable in the latched region falls, booted ones too.

    Both that each of the other three enables falls, and that it falls
    because of the latch rather than later for some other reason -- hence
    the allowance after the faulted source. And that none of them comes
    back while the region is latched.
    """
    edges = await _boot_region(dut)
    latched_at = await _latch(dut, edges)

    await advance(dut.clk, seconds=(SOURCE_HOLD_MS - PROBE_MARGIN_MS) / 1000.0)

    late, never = [], []
    for name in ENABLES:
        falls = [t for t in edges.falls(name) if t >= latched_at - 1e-6]
        if not falls:
            never.append(name)
        elif falls[0] - latched_at > REGION_FOLLOWS_MS:
            late.append("%s (%.3f ms after)" % (name, falls[0] - latched_at))
    dut._log.info("%s fell at %.4f ms; region enables fell at %s", FAULTED_ENABLE,
                  latched_at, ", ".join(
                      "%s +%.0f ns" % (n, (edges.falls(n)[-1] - latched_at) * 1e6)
                      for n in ENABLES if edges.falls(n)))

    assert not never, (
        "the IMX region latched when %s's nFAULT asserted, and these enables "
        "were still asserted %.1f ms later: %s. They are sources that had "
        "booted successfully, which is exactly the case HK-REG-09 names."
        % (FAULTED_ENABLE, SOURCE_HOLD_MS - PROBE_MARGIN_MS, ", ".join(never)))
    assert not late, (
        "these enables fell, but more than %.1f ms after the latch was "
        "declared, so they did not fall because of it: %s"
        % (REGION_FOLLOWS_MS, ", ".join(late)))

    reasserted = [name for name in ENABLES
                  if any(t > latched_at for t in edges.rises(name))]
    assert not reasserted, (
        "these enables re-asserted while the region was still latched: %s"
        % ", ".join(reasserted))


@cocotb.test()
async def test_HK_REG_08_latched_while_any_source_latched(dut):
    """VC-HK-0049: the region is latched exactly while its source is.

    Probed with two requests. The first comes while the source is still
    latched and must be refused; the second comes just after the source's
    latch has ended and must be accepted. The fault itself is removed almost
    at once, so it is the latch -- not a fault still present -- that the
    first request runs into.
    """
    control = boundary(dut, CONTROL)
    edges = await _boot_region(dut)
    latched_at = await _latch(dut, edges)

    dut.rail_fault.value = 0
    control.value = 0

    async def at(ms: float) -> None:
        remaining = ms - (edges.now_ms() - latched_at)
        if remaining > 0:
            await advance(dut.clk, seconds=remaining / 1000.0)

    # Refused: the source is still inside its hold.
    refused_at = SOURCE_HOLD_MS - PROBE_MARGIN_MS
    await at(refused_at)
    control.value = 1
    await at(SOURCE_HOLD_MS + PROBE_MARGIN_MS / 2)
    early = [(n, t - latched_at) for n in ENABLES for t in edges.rises(n)
             if t > latched_at]
    assert not early, (
        "a request %.3f ms after the latch was declared, while the source was "
        "still inside its %.3f ms hold, was acted on: %s. The region stopped "
        "being latched before its source did."
        % (refused_at, SOURCE_HOLD_MS, ", ".join(
            "%s rose at +%.3f ms" % (n, t) for n, t in early)))
    control.value = 0

    # Accepted: the source's hold has ended, so the region must have too.
    accepted_at = SOURCE_HOLD_MS + PROBE_MARGIN_MS
    await at(accepted_at)
    control.value = 1
    await at(accepted_at + RESPONSE_MS)
    # Nothing rose between the two probes, or the refusal check would say so
    # only up to where it stopped looking; the whole interval counts.
    between = [(n, t - latched_at) for n in ENABLES for t in edges.rises(n)
               if latched_at < t < latched_at + accepted_at]
    assert not between, (
        "the region booted on its own between the two requests, with no "
        "rising edge on %s to ask for it: %s" % (CONTROL, ", ".join(
            "%s at +%.3f ms" % (n, t) for n, t in between)))
    rose = [t - latched_at for t in edges.rises(FAULTED_ENABLE)
            if t >= latched_at + accepted_at]
    dut._log.info("request at +%.3f ms refused; request at +%.3f ms %s",
                  refused_at, accepted_at,
                  "accepted, %s rose at +%.3f ms" % (FAULTED_ENABLE, rose[0])
                  if rose else "not acted on")
    assert rose, (
        "a request %.3f ms after the latch was declared -- %.1f ms after the "
        "source's %.3f ms hold ended, with the fault long removed -- was not "
        "acted on within %.1f ms. The region was still reporting latched "
        "after the last latched source had cleared."
        % (accepted_at, PROBE_MARGIN_MS, SOURCE_HOLD_MS, RESPONSE_MS))


def test_hk_reg_latchup():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_reg_latchup",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
