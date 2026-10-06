"""HK-SRC-06: a source that never reports good is declared failed at 200% of
its nominal boot time.

Item: VC-HK-0037. Clause: VVP-HK-004.

  A power source shall be declared failed if it has not asserted a PGOOD
  rising edge within 200% of its nominal boot time after its enable is
  asserted, where the nominal boot time is its regulator's datasheet
  start-up time with the soft-start capacitor fitted on the board.

**Expected to fail, and supposed to.** The design gives every source the same
25 ms (`pwr_src_bootseq.sv:36`), and for DDR8's 2V5 source 200% of nominal is
8.28 ms. The requirement is `GAP`, the item declares `expect: FAIL`, and
`HK-F-03` is why. The gate reads the declaration; nothing here is muted.

**The definition of nominal is confirmed in part.** FAR-PM_FPGA_L4REQ-11
says "200% of its nominal boot time" and defines neither. Avionics hardware
confirmed on 2026-10-01 that nominal is the datasheet start-up time; that it
means enable to PGOOD, as the board model computes it, is still pending. The nominal time is read from the
board model (`fsverif.board`), which computes it per rail from the datasheet
equation and the capacitor fitted -- so this test follows the schematic if a
capacitor changes, rather than a number copied here.

The item's criteria has a second half -- a PGOOD rising edge inside the bound
declares success -- and this test establishes that first. "Declared failed
at the bound" is worth nothing from a device that declares every source
failed immediately, and the two halves are kept distinguishable by the
exception they raise: only an `AssertionError` is the requirement not met;
`Unexpected` means the test never got far enough to ask.

The previous bound, 25 ms, is what the design implements, and it was verified
at that value before this change: the timeout fires at 25.231 ms, 77 ticks of
0.32768 ms rounded up so that the quantisation falls late rather than early
(`HK-F-01`).
"""

from __future__ import annotations

import cocotb
from cocotb.triggers import RisingEdge, SimTimeoutError, with_timeout

from fsverif import board, sim
from fsverif.clkrst import advance, until
from fsverif.pins import CONTROL_INPUTS, RESET_N, boundary

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

#: The source under test. DDR8's 2V5 rail is hardware-controlled, so it boots
#: without being asked, and it is the first source of the first region that
#: waits on a rail this test can hold down.
SOURCE_ENABLE = "ddr8_en_2v5"
SOURCE_PGOOD = "ddr8_pgood_2v5"

#: The next source in the DDR8 region. Its enable asserting is the device
#: saying the previous source booted successfully and the sequence moved on.
#: That is the observable for success -- not "the enable is still high", which
#: is also true of a device stuck in `HK-F-01` and would pass without
#: establishing anything.
NEXT_ENABLE = "ddr8_en_1v2"

#: `HK-SRC-06`: 200% of the source's nominal boot time (FAR-PM_FPGA_L4REQ-11).
BOUND_FACTOR = 2.0

#: How far inside the bound the success half places its PGOOD edge, and how
#: far past it the failure half looks: the 5 us input filter, and margin.
MARGIN_MS = 0.1

#: The design's timeout, for the failure message only.
DESIGN_TIMEOUT_MS = 25.231


class Unexpected(Exception):
    """The device never reached the state the requirement is about.

    Kept distinct from `AssertionError` now that this test is an ordinary
    passing one, because the distinction still carries information: an
    assertion here means the device did not meet the requirement, and this
    means the test never got far enough to ask.
    """


def _rail():
    """The rail under test, with the delay the board gives it."""
    rails = board.model()
    bit = board.index(rails)[SOURCE_PGOOD]
    delay = next(r.delay_ms for r in rails if r.pgood == SOURCE_PGOOD)
    return bit, delay


async def _start_with_rail_down(dut):
    """Bring the device up with the source's rail held out of regulation."""
    bit, delay = _rail()
    dut.rail_fail.value = 1 << bit
    dut.rail_fault.value = 0

    reset_n = getattr(dut, RESET_N)
    reset_n.value = 0
    for name in CONTROL_INPUTS:
        getattr(dut, name).value = 0
    await advance(dut.clk, cycles=PULSE_WIDTH)
    reset_n.value = 1

    enable = boundary(dut, SOURCE_ENABLE)
    # One edge trigger rather than polling: the bound is a few milliseconds,
    # and a poll would start the clock up to a poll interval late.
    try:
        await with_timeout(RisingEdge(enable), 3, "sec")
    except SimTimeoutError as exc:
        raise Unexpected(
            "%s never asserted, so its boot timeout never started and this "
            "test cannot say anything about HK-SRC-06: %s"
            % (SOURCE_ENABLE, exc)) from exc
    return bit, delay, enable


@cocotb.test()
async def test_HK_SRC_06_fail_at_200pct_nominal(dut):
    """VC-HK-0037: the boot timeout at 200% of nominal, both halves."""
    # --- the second sentence first: a rising edge inside the bound is success
    bit, nominal, enable = await _start_with_rail_down(dut)
    bound = BOUND_FACTOR * nominal
    dut._log.info("%s: nominal %.3f ms, so the bound is %.3f ms",
                  SOURCE_PGOOD, nominal, bound)

    # Released at once, the board model brings PGOOD up one nominal time
    # later -- half the bound, well inside it.
    dut.rail_fail.value = 0
    following = boundary(dut, NEXT_ENABLE)
    try:
        waited = await until(dut.clk, lambda: int(following.value) == 1,
                             timeout_s=bound / 1000.0 + 0.001, poll_ms=0.05)
    except TimeoutError as exc:
        raise Unexpected(
            "%s never asserted, so %s was not declared booted even though its "
            "PGOOD rose inside the bound: %s"
            % (NEXT_ENABLE, SOURCE_ENABLE, exc)) from exc
    if int(enable.value) != 1:
        raise Unexpected("%s was declared booted but its enable is no longer "
                         "asserted" % SOURCE_ENABLE)
    dut._log.info("%s asserted %.3f ms after the release, so %s was declared "
                  "booted and no failure was declared",
                  NEXT_ENABLE, waited * 1000.0, SOURCE_ENABLE)

    # --- the first sentence: PGOOD held low past the bound declares failure
    _, _, enable = await _start_with_rail_down(dut)
    await advance(dut.clk, seconds=(bound + MARGIN_MS) / 1000.0)
    assert int(enable.value) == 0, (
        "%s was still asserted %.3f ms after it asserted, with its PGOOD held "
        "low throughout, so the source was not declared failed within 200%% "
        "of its %.3f ms nominal boot time. The design gives every source a "
        "flat %.3f ms (pwr_src_bootseq.sv:36). HK-F-03."
        % (SOURCE_ENABLE, bound + MARGIN_MS, nominal, DESIGN_TIMEOUT_MS))


def test_hk_src_06():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_src_06",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
