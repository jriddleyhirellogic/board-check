"""A software-region latchup stays in its region: HK-LAT-05.

Item: VC-HK-0006. Clause: VVP-HK-004.

  HK-LAT-05  A latchup in a software-controlled region shall power down only
             that region.

"Only" is the whole requirement, and the item says so: checking that the
latched region powers down is the obvious half, and checking that *nothing
else moved* is the half that matters. So every enable on the device is read
before the event and then every 0.05 ms through it, and any change outside
the latched region fails -- a glitch that recovered counts, because a rail
that dropped and came back has still been power-cycled.

**All six software regions, one after another, in one boot.** A contained
latch leaves the rest of the device running, so the regions can be latched
in turn without a reset between them; each one is checked against everything
still up, including the regions latched before it, which must *stay* down.
If a software latch were not contained, the first would take the device
down and the second region would find nothing booted -- which the test
reports as such rather than as a pass.

Stepper Sec comes last and is requested only once Stepper Pri is latched,
because a booted Stepper Pri holds it down (`health_monitor.sv:547`).

The stimulus is each region's first source losing PGOOD after boot
(`HK-LAT-01`'s first condition), because Eth1, Eth2 and LVDT have no nFAULT
wired and the test should latch every region the same way.
"""

from __future__ import annotations

import re

import cocotb
from cocotb.triggers import FallingEdge, SimTimeoutError, with_timeout

from fsverif import board, boot, sim
from fsverif.clkrst import advance, until
from fsverif.pins import SOFTWARE_REGIONS, boundary, device_enables

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

#: Long enough to cover the latched source's 2.294 ms hold and the region
#: returning to power-off after it, so a disturbance at either end is inside
#: the window.
WATCH_MS = 3.0
POLL_MS = 0.05

LAST = "stepper_sec"


def _pgood_of(enable: str) -> str:
    return re.sub(r"_en(_|$)", r"_pgood\1", enable)


def _levels(dut, names) -> dict:
    return {n: int(boundary(dut, n).value) for n in names}


async def _request(dut, control: str, status: str) -> None:
    boundary(dut, control).value = 0
    await advance(dut.clk, seconds=POLL_MS / 1000.0)
    boundary(dut, control).value = 1
    await until(dut.clk, lambda: int(boundary(dut, status).value) == 1,
                timeout_s=0.5,
                describe=lambda: "%s never reported booted" % status)


@cocotb.test()
async def test_HK_LAT_05_sw_region_isolated(dut):
    """VC-HK-0006: each software region latches alone."""
    index = board.index(board.model())
    enables = device_enables()
    dut.rail_fail.value = 0
    dut.rail_fault.value = 0
    await boot.hardware(dut)
    for region, control, _ in SOFTWARE_REGIONS:
        if region != LAST:
            boundary(dut, control).value = 1
    await until(
        dut.clk, lambda: all(int(boundary(dut, "%s_status_to_pf" % r).value)
                             for r, _, _ in SOFTWARE_REGIONS if r != LAST),
        timeout_s=1.0, describe=lambda: "software regions did not all boot")

    dead, problems = 0, []
    for region, control, own in SOFTWARE_REGIONS:
        if region == LAST:
            await _request(dut, control, "%s_status_to_pf" % region)

        before = _levels(dut, enables)
        down = [e for e in own if not before[e]]
        assert not down, (
            "before latching %s these of its enables were not asserted, so "
            "their falling would prove nothing: %s" % (region, ", ".join(down)))

        dead |= 1 << index[_pgood_of(own[0])]
        dut.rail_fail.value = dead
        try:
            await with_timeout(FallingEdge(boundary(dut, own[0])), 1, "ms")
        except SimTimeoutError:
            raise AssertionError(
                "%s stayed asserted for 1 ms after its PGOOD fell, so %s "
                "never latched; that is HK-LAT-01's failure" % (own[0], region)
            ) from None

        moved = {}
        waited = 0.0
        while waited < WATCH_MS:
            await advance(dut.clk, seconds=POLL_MS / 1000.0)
            waited += POLL_MS
            for name, level in _levels(dut, enables).items():
                if name not in own and level != before[name]:
                    moved.setdefault(name, waited)

        own_up = [e for e in own if int(boundary(dut, e).value)]
        dut._log.info("latched %s: its %d enables %s; %d others unchanged "
                      "over %.1f ms", region, len(own),
                      "all down" if not own_up else "NOT all down",
                      len(enables) - len(own) - len(moved), WATCH_MS)
        if own_up:
            problems.append("%s: its own enables still asserted: %s"
                            % (region, ", ".join(own_up)))
        if moved:
            problems.append("%s: enables outside it changed: %s" % (
                region, ", ".join("%s (%d -> %d at +%.2f ms)"
                                  % (n, before[n], 1 - before[n], t)
                                  for n, t in sorted(moved.items(),
                                                     key=lambda kv: kv[1]))))

    assert not problems, (
        "a software-region latchup did not power down only that region:\n  "
        + "\n  ".join(problems))


def test_hk_lat_sw_region():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_lat_sw_region",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
