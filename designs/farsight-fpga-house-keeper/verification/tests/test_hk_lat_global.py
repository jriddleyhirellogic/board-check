"""Any hardware-region latchup is global: HK-LAT-02.

Item: VC-HK-0003. Clause: VVP-HK-004.

  HK-LAT-02  A latchup in any hardware-controlled region shall latch a global
             critical latchup condition.

**The global condition is not a pin, so what is observed is its reach.** A
latchup contained to its region powers down that region (`HK-REG-09`). A
global one powers down every other region as well, including the ones
upstream of it that the latched region depends on. So the test boots the
hardware chain, latches one region, and asserts that every hardware enable
*outside* that region fell with it. A design that latched locally leaves
them up, which is exactly the difference.

**Every region in turn, from the region list** -- the item says so, and the
requirement says "any". The five are not interchangeable: the condition is an
OR written out by hand (`health_monitor.sv:722`), so a region missing from it
would pass a test that sampled the others. Each gets its own boot, because a
global latch holds until reset (`HK-LAT-04`) and a latched device cannot be
latched again to any purpose.

The stimulus is the first source's PGOOD falling after the region has booted
(`HK-LAT-01`'s first condition). It is the one condition every source has:
LVDS has no nFAULT wired at all.
"""

from __future__ import annotations

import cocotb
from cocotb.triggers import FallingEdge, SimTimeoutError, with_timeout

from fsverif import board, boot, sim
from fsverif.clkrst import advance
from fsverif.pins import HARDWARE_REGIONS, boundary

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

#: How long the rest of the device may take to follow. The latched source's
#: enable falls first; the global latch is a register after it, and the reset
#: it gates reaches every region a cycle or two later. `HK-LAT-08` is the
#: requirement that will bound this, and its value is TBR (`HK-F-26`), so
#: this is an allowance -- wide enough for any correct design, narrow enough
#: that "later, for some other reason" does not pass for "because of it".
FOLLOWS_MS = 0.1

HARDWARE_ENABLES = tuple(e for _, enables in HARDWARE_REGIONS for e in enables)


def _pgood_of(enable: str) -> str:
    import re

    return re.sub(r"_en(_|$)", r"_pgood\1", enable)


@cocotb.test()
async def test_HK_LAT_02_global_latch_from_every_hw_region(dut):
    """VC-HK-0003: a latchup in each hardware region takes the others down."""
    index = board.index(board.model())
    local = []

    for region, enables in HARDWARE_REGIONS:
        dut.rail_fail.value = 0
        dut.rail_fault.value = 0
        await boot.hardware(dut)

        down = [e for e in HARDWARE_ENABLES if not int(boundary(dut, e).value)]
        assert not down, (
            "before latching %s, these hardware enables were not asserted, so "
            "a fall afterwards would prove nothing: %s" % (region, ", ".join(down)))

        source = enables[0]
        dut.rail_fail.value = 1 << index[_pgood_of(source)]
        try:
            await with_timeout(FallingEdge(boundary(dut, source)), 1, "ms")
        except SimTimeoutError:
            raise AssertionError(
                "%s stayed asserted for 1 ms after its rail's PGOOD fell, so "
                "%s never declared a latchup and there is nothing here to "
                "propagate. That is HK-LAT-01's failure." % (source, region)
            ) from None
        await advance(dut.clk, seconds=FOLLOWS_MS / 1000.0)

        others = [e for e in HARDWARE_ENABLES if e not in enables]
        still_up = [e for e in others if int(boundary(dut, e).value)]
        own_up = [e for e in enables if int(boundary(dut, e).value)]
        dut._log.info("latched %s via %s: %d of %d other hardware enables "
                      "fell within %.1f ms", region, _pgood_of(source),
                      len(others) - len(still_up), len(others), FOLLOWS_MS)
        if still_up or own_up:
            local.append("%s: still asserted %.1f ms later: %s" % (
                region, FOLLOWS_MS, ", ".join(own_up + still_up)))

    assert not local, (
        "a latchup in these hardware regions did not take the rest of the "
        "hardware chain down with it, so it did not latch the global "
        "condition:\n  " + "\n  ".join(local))


def test_hk_lat_global():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_lat_global",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
