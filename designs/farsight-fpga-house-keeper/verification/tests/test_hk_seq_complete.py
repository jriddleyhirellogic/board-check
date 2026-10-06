"""How long the hardware boot takes to finish: HK-SEQ-10.

Item: VC-HK-0060. Clause: VVP-HK-004.

  HK-SEQ-10  The hardware-controlled boot sequence shall complete within 6 s
             of reset release.

**The bound is pending systems confirmation.** 6 s is the value proposed on
2026-09-29 for FAR-PM_FPGA_L4REQ-8 and -27. If systems answers differently,
revisit the item and this test.

"Complete" means every hardware-controlled region has either booted or been
declared failed, so nothing further will happen to a hardware enable without
an outside event. At the pins that is the last change of any hardware enable:
after it, the enables stay as they are.

**The stimulus is the slowest the board model can produce.** Three regions
that may fail without stopping the chain -- DDR8, DDR16 and LVDS -- each have
their last source held dead, so every attempt runs the earlier sources up
and then times out, four attempts each with a hold between. Step Down and
FPGA must boot, because either failing ends the sequence early with a
shutdown. The analytic worst case, every source taking just under its
timeout on every attempt, is 5.80 s; no board produces it, and the model
cannot, so it is recorded in the requirement rather than claimed here.

Sampled every millisecond rather than watched edge by edge: over three
simulated seconds, eighteen watched pins would cost more than the whole run,
and a millisecond is far finer than the bound.
"""

from __future__ import annotations

import cocotb
from cocotb.utils import get_sim_time

from fsverif import board, boot, sim
from fsverif.clkrst import advance
from fsverif.pins import HARDWARE_REGIONS, boundary

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

#: Pending systems confirmation (2026-09-29).
BOUND_S = 6.0

HARDWARE_ENABLES = tuple(e for _, names in HARDWARE_REGIONS for e in names)

#: The last source of each region that may fail without a shutdown.
DEAD = ("ddr8_pgood_0v6", "ddr16_pgood_0v6", "lvds_pgood")
LAST_REGION_ENABLE = "lvds_en"
ATTEMPTS = 4

POLL_S = 0.001
#: Quiet for longer than a retry hold, so a further attempt would have shown.
QUIET_S = 0.3
GIVE_UP_S = 8.0


def _state(dut) -> tuple:
    return tuple(int(boundary(dut, e).value) for e in HARDWARE_ENABLES)


@cocotb.test()
async def test_HK_SEQ_10_sequence_completes_in_time(dut):
    """VC-HK-0060: the last hardware enable settles within 6 s of reset."""
    board.drive(dut, fail=DEAD)
    await boot.release(dut)
    released = get_sim_time("ns") / 1e9

    state, last_change, lvds_attempts, lvds_was = _state(dut), 0.0, 0, 0
    elapsed = 0.0
    while elapsed < GIVE_UP_S:
        await advance(dut.clk, seconds=POLL_S)
        elapsed = get_sim_time("ns") / 1e9 - released
        now = _state(dut)
        lvds = int(boundary(dut, LAST_REGION_ENABLE).value)
        if lvds and not lvds_was:
            lvds_attempts += 1
        lvds_was = lvds
        if now != state:
            state, last_change = now, elapsed
        if lvds_attempts >= ATTEMPTS and elapsed - last_change > QUIET_S:
            break

    dut._log.info("LVDS made %d attempts; the last hardware enable changed "
                  "%.3f s after reset release", lvds_attempts, last_change)
    assert lvds_attempts >= ATTEMPTS, (
        "LVDS made %d attempts in %.1f s, not %d, so the sequence never "
        "reached the end this test is timing" % (lvds_attempts, elapsed,
                                                  ATTEMPTS))
    assert elapsed - last_change > QUIET_S, (
        "the hardware enables were still changing %.1f s after reset release"
        % elapsed)
    assert last_change <= BOUND_S, (
        "the hardware boot sequence completed %.3f s after reset release, "
        "beyond %g s" % (last_change, BOUND_S))


def test_hk_seq_complete():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_seq_complete",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
