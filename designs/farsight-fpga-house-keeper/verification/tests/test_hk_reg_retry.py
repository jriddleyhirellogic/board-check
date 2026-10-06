"""Region retry behaviour: HK-REG-04, HK-REG-05 and HK-REG-06.

Items: VC-HK-0046, VC-HK-0047, VC-HK-0048. Clause: VVP-HK-004.

  HK-REG-04  Re-attempt the boot sequence when a source in the region is
             declared failed and fewer than three re-attempts have been used.
  HK-REG-05  On beginning a re-attempt, deassert every enable in the region
             and hold them deasserted for 200 ms -1/+2 ms. Its parent says
             "at least 200 ms"; the realised hold is 200.540 ms, inside both
             since HK-F-04 rounded the threshold up.
  HK-REG-06  Make at most four boot attempts before being declared failed.

**All three were unreachable until very recently**, and that is why they are
written together. A region leaves `BOOTING` only on `boot_timeout`
(`pwr_region_sm.sv:99`); the source-level timeout could never fire, so no
source could be declared failed, so `RETRY`, the hold-off and the attempt
limit were all dead code. Their items say `expect: FAIL` for that reason.

Widening the source counter (`pwr_src_bootseq.sv:36`) was aimed at
`HK-SRC-06`, and these three are downstream of it. Whether they now hold is
not something to assume -- the fix made the *entry* to the retry path
reachable, and nothing yet has exercised the path itself.

So all three are written as ordinary tests that assert what the requirement
says. If the retry machinery works they pass, and the gate will report three
stale `expect: FAIL` declarations, which is the signal to update the items and
the requirement statuses. If it does not, they fail and say what is wrong.
Either outcome is information; assuming either would not be.

One rail is held permanently out of regulation throughout. That is the whole
stimulus: the housekeeper enables DDR8's 2V5 source, the board model never
brings it good, and the region is forced down the failure path.
"""

from __future__ import annotations

import cocotb
from cocotb.utils import get_sim_time

from fsverif import board, boot, sim
from fsverif.clkrst import advance
from fsverif.pins import CONTROL_INPUTS, RESET_N, boundary

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

#: The source held down, and the region it belongs to. DDR8's 2V5 rail is the
#: first source of the first region that can fail without taking the
#: housekeeper's own supply with it: the step-down region is upstream of
#: everything, and a failure there begins a shutdown rather than a retry.
SOURCE_ENABLE = "ddr8_en_2v5"
SOURCE_PGOOD = "ddr8_pgood_2v5"
REGION_ENABLES = ("ddr8_en_2v5", "ddr8_en_1v2", "ddr8_en_0v6")

#: `debug[2:0]` = 7 is `ddr8_boot_failed` (`health_monitor.sv:713`). It is on
#: real pins, so the region being declared failed is observable at the
#: boundary rather than only inside the design.
DEBUG_DDR8_BOOT_FAILED = 7

#: `HK-REG-06`: one initial attempt plus three re-attempts.
MAX_ATTEMPTS = 4

#: `HK-REG-05` and its parent disagree, and the bound here is the parent's.
#:
#: FAR-PM_FPGA_L4REQ-18 requires "at least 200 ms". This requirement restates
#: it as 200 ms -1/+2 ms, which accepted the 152-tick, 199.229 ms hold that
#: `HK-F-04` was about. Written to the parent, the test failed by 0.77 ms
#: until the threshold was rounded up to 153 ticks, 200.540 ms.
#:
#: The upper bound is this requirement's, because the parent states none and
#: a hold that ran long would be a different defect worth catching.
HOLD_MIN_MS = 200.0
HOLD_MAX_MS = 202.0

#: One source timeout plus one hold, with margin. A full attempt cycle is
#: about 224 ms, so four attempts take roughly 700 ms.
ATTEMPT_BUDGET_MS = 400.0

#: Sampling. Fine enough to time a 200 ms hold to well inside its 2 ms
#: window, coarse enough not to dominate the run.
POLL_MS = 0.1


class Attempts:
    """When the region's first enable rose and fell, in ms after reset."""

    def __init__(self):
        self.rises, self.falls = [], []
        self._was = 0

    def note(self, dut, at_ms: float) -> None:
        now = int(boundary(dut, SOURCE_ENABLE).value)
        if now and not self._was:
            self.rises.append(at_ms)
        elif self._was and not now:
            self.falls.append(at_ms)
        self._was = now

    @property
    def holds(self) -> list:
        """Each interval the enable spent deasserted between attempts."""
        return [rise - fall for fall, rise in zip(self.falls, self.rises[1:])]


async def _watch_with_rail_dead(dut, for_ms: float) -> Attempts:
    """Boot with the source's rail held down, recording every attempt."""
    rails = board.model()
    dut.rail_fail.value = 1 << board.index(rails)[SOURCE_PGOOD]
    dut.rail_fault.value = 0

    reset_n = getattr(dut, RESET_N)
    reset_n.value = 0
    for name in CONTROL_INPUTS:
        getattr(dut, name).value = 0
    await advance(dut.clk, cycles=boot.FILTER_CYCLES)
    reset_n.value = 1

    released = get_sim_time("ns")
    record = Attempts()
    while (get_sim_time("ns") - released) / 1e6 < for_ms:
        await advance(dut.clk, seconds=POLL_MS / 1000.0)
        record.note(dut, (get_sim_time("ns") - released) / 1e6)
    return record


@cocotb.test()
async def test_HK_REG_04_reattempt_under_three(dut):
    """VC-HK-0046: a failed source starts a re-attempt.

    The observable is the region's first enable falling and rising again. An
    enable that merely stays high is a region still in `BOOTING`, which is
    what the unreachable timeout produced and is not a re-attempt.
    """
    # HK-SEQ-01 holds the sequence off for a second; then the first attempt,
    # its timeout and one hold have to fit.
    record = await _watch_with_rail_dead(dut, 1200.0 + ATTEMPT_BUDGET_MS * 2)

    assert record.rises, (
        "%s never asserted at all, so the region never attempted to boot and "
        "nothing here is about re-attempting" % SOURCE_ENABLE)
    assert len(record.rises) >= 2, (
        "%s asserted once, at %.1f ms, and never deasserted or re-asserted "
        "within %.0f ms while its PGOOD was held low throughout. The region "
        "did not re-attempt: it is still in BOOTING, which is what an "
        "unreachable source timeout produces."
        % (SOURCE_ENABLE, record.rises[0], 1200.0 + ATTEMPT_BUDGET_MS * 2))
    dut._log.info("%s attempted %d times: rises at %s ms",
                  SOURCE_ENABLE, len(record.rises),
                  ", ".join("%.1f" % t for t in record.rises))


@cocotb.test()
async def test_HK_REG_05_reattempt_holdoff_200ms(dut):
    """VC-HK-0047: every enable in the region is held down for ~200 ms.

    Both halves: how long the first enable stays deasserted, and that the
    whole region is down for that interval rather than only the source that
    failed. A retry that left a later source energised would begin from a
    partially-energised rail, which is exactly what the hold exists to avoid.
    """
    record = await _watch_with_rail_dead(dut, 1200.0 + ATTEMPT_BUDGET_MS * 2)

    assert record.holds, (
        "%s never completed a deassert-reassert cycle, so there is no "
        "re-attempt hold to measure" % SOURCE_ENABLE)

    hold = record.holds[0]
    dut._log.info("first re-attempt hold measured at %.3f ms (parent "
                  "requires at least %.0f ms)", hold, HOLD_MIN_MS)
    assert HOLD_MIN_MS <= hold <= HOLD_MAX_MS, (
        "the region held its enables deasserted for %.3f ms, outside "
        "%.0f to %.0f ms: at least the parent FAR-PM_FPGA_L4REQ-18's 200 ms, "
        "at most this requirement's +2 ms.\n"
        "The threshold is RETRY_TIME rounded up to whole ticks of "
        "1.31072 ms, 153 ticks = 200.540 ms (pwr_region_sm.sv:38-39, :118, "
        "pwr_region_ddr8_bootseq.sv:44). Truncated, it was 199.229 ms -- "
        "HK-F-04." % (hold, HOLD_MIN_MS, HOLD_MAX_MS))

    # And the rest of the region, not just the source that failed.
    still_up = [name for name in REGION_ENABLES
                if name != SOURCE_ENABLE
                and int(boundary(dut, name).value) == 1]
    assert not still_up, (
        "these enables in the region were still asserted during the "
        "re-attempt hold, so the retry does not begin from the same state as "
        "the first attempt: %s" % ", ".join(still_up))


@cocotb.test()
async def test_HK_REG_06_at_most_four_attempts(dut):
    """VC-HK-0048: four attempts, then the region is declared failed.

    Watches long enough for a fifth attempt to have happened if one were
    coming -- a test that stopped at four would pass whether the limit worked
    or not, which is the shape of check that looks right and cannot fail.
    """
    record = await _watch_with_rail_dead(
        dut, 1200.0 + ATTEMPT_BUDGET_MS * (MAX_ATTEMPTS + 1))

    dut._log.info("%s asserted %d times in %.0f ms; rises at %s ms",
                  SOURCE_ENABLE, len(record.rises),
                  1200.0 + ATTEMPT_BUDGET_MS * (MAX_ATTEMPTS + 1),
                  ", ".join("%.1f" % t for t in record.rises))

    assert len(record.rises) <= MAX_ATTEMPTS, (
        "%s asserted %d times, more than the %d attempts HK-REG-06 allows "
        "(one initial plus three re-attempts, NUM_RETRIES=3 at "
        "pwr_region_sm.sv:37). Rises at %s ms."
        % (SOURCE_ENABLE, len(record.rises), MAX_ATTEMPTS,
           ", ".join("%.1f" % t for t in record.rises)))
    assert len(record.rises) == MAX_ATTEMPTS, (
        "%s asserted only %d times where %d were expected, so the region "
        "stopped attempting early and the limit is not what was exercised"
        % (SOURCE_ENABLE, len(record.rises), MAX_ATTEMPTS))

    # And it says so on a pin. debug[2:0] = 7 is ddr8_boot_failed.
    debug = int(boundary(dut, "debug").value) & 0x7
    assert debug == DEBUG_DDR8_BOOT_FAILED, (
        "the region made its %d attempts but debug[2:0] reads %d rather than "
        "%d, so it was never declared failed and nothing downstream -- the "
        "shutdown, the UART failure broadcast -- can respond"
        % (MAX_ATTEMPTS, debug, DEBUG_DDR8_BOOT_FAILED))


def test_hk_reg_retry():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_reg_retry",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
