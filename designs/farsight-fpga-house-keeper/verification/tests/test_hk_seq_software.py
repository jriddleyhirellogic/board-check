"""Starting a software region: HK-SEQ-05, -06 and -07.

Items: VC-HK-0056, VC-HK-0057, VC-HK-0058. Clause: VVP-HK-004.

  HK-SEQ-05  A software-controlled region shall start booting only on a
             rising edge of its control input, and only while the FPGA region
             has booted successfully.
  HK-SEQ-06  A software-controlled region's start request shall be cleared
             once the region reports done or latchup.
  HK-SEQ-07  All software-controlled regions shall be held powered down while
             the FPGA region has not booted successfully.

`HK-SEQ-05` and `-07` share a stimulus that no nominal boot produces: every
control input driven high from the moment reset releases, so that the
PolarFire is -- impossibly -- asking for everything before it is powered.
`-07` requires every software enable to stay low until the FPGA region
reports booted; `-05` requires that the level already high at that moment
start nothing, and neither does an edge that came before it. Only an edge
after it does.

**`HK-SEQ-06` is observable on one of its two branches.** A request that was
not cleared on *latchup* shows as the region restarting by itself once the
latch ends, with its control input simply held high -- and that is tested.
One not cleared on *done* cannot be told apart at the pins: a region that has
finished leaves that state only by being powered down, which needs its
control input low, and bringing it high again is a fresh rising edge that
sets the request regardless. So the done branch is by construction
(`health_monitor.sv:563-595`), and the test says so rather than implying it
covers it.
"""

from __future__ import annotations

import re

import cocotb
from cocotb.triggers import FallingEdge, RisingEdge, SimTimeoutError, with_timeout
from cocotb.utils import get_sim_time

from fsverif import board, boot, sim
from fsverif.clkrst import advance, until
from fsverif.pins import CONTROL_INPUTS, SOFTWARE_REGIONS, boundary

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

SOFTWARE = {r: enables for r, _, enables in SOFTWARE_REGIONS}
CONTROL = {r: ctrl for r, ctrl, _ in SOFTWARE_REGIONS}
SOFTWARE_ENABLES = tuple(e for enables in SOFTWARE.values() for e in enables)
FPGA_STATUS = "pf_status_to_pf"

POLL_MS = 0.1
QUIET_MS = 100.0


def pgood_of(enable: str) -> str:
    return re.sub(r"_en(_|$)", r"_pgood\1", enable)


def _now_ms() -> float:
    return get_sim_time("ns") / 1e6


def _high(dut, name: str) -> bool:
    return bool(int(boundary(dut, name).value))


async def _asking_for_everything(dut, *, pre_fpga_edge: str = "") -> dict:
    """Reset with every control input high from release; poll every software
    enable until the FPGA region reports booted. Optionally give one control
    a low-high edge half way through, before the FPGA is up."""
    board.drive(dut)
    await boot.release(dut)
    for name in CONTROL_INPUTS:
        boundary(dut, name).value = 1
    start, seen, toggled = _now_ms(), {}, False
    while not _high(dut, FPGA_STATUS):
        await advance(dut.clk, seconds=POLL_MS / 1000.0)
        if pre_fpga_edge and not toggled and _now_ms() - start > 500.0:
            boundary(dut, pre_fpga_edge).value = 0
            await advance(dut.clk, seconds=POLL_MS / 1000.0)
            boundary(dut, pre_fpga_edge).value = 1
            toggled = True
        for e in SOFTWARE_ENABLES:
            if e not in seen and _high(dut, e):
                seen[e] = _now_ms() - start
        if _now_ms() - start > 2500.0:
            raise AssertionError("the FPGA region never reported booted")
    return seen


async def _quiet(dut, names, ms: float) -> dict:
    seen, start = {}, _now_ms()
    while _now_ms() - start < ms:
        await advance(dut.clk, seconds=POLL_MS / 1000.0)
        for e in names:
            if e not in seen and _high(dut, e):
                seen[e] = _now_ms() - start
    return seen


@cocotb.test()
async def test_HK_SEQ_07_sw_regions_down_until_fpga(dut):
    """VC-HK-0058: every software enable low until the FPGA region is up."""
    seen = await _asking_for_everything(dut)
    dut._log.info("every control high from reset release; %d software enables "
                  "asserted before the FPGA region booted", len(seen))
    assert not seen, (
        "with every control input high, these software enables asserted "
        "before the FPGA region had booted: %s" % ", ".join(
            "%s at +%.1f ms" % kv for kv in sorted(seen.items(),
                                                   key=lambda kv: kv[1])))


@cocotb.test()
async def test_HK_SEQ_05_sw_region_rising_edge_only(dut):
    """VC-HK-0056: a level starts nothing, nor an edge before the FPGA."""
    await _asking_for_everything(dut, pre_fpga_edge=CONTROL["imx"])
    level = await _quiet(dut, SOFTWARE_ENABLES, QUIET_MS)
    dut._log.info("every control already high when the FPGA region booted, "
                  "IMX's toggled before it: %s in %.0f ms after",
                  level or "nothing asserted", QUIET_MS)
    assert not level, (
        "control inputs already high when the FPGA region booted -- one of "
        "them given its edge before the FPGA was up -- started these without "
        "a rising edge after it: %s" % ", ".join(
            "%s at +%.1f ms" % kv for kv in level.items()))

    boundary(dut, CONTROL["imx"]).value = 0
    await advance(dut.clk, seconds=POLL_MS / 1000.0)
    boundary(dut, CONTROL["imx"]).value = 1
    try:
        await with_timeout(RisingEdge(boundary(dut, SOFTWARE["imx"][0])), 1, "ms")
    except SimTimeoutError:
        raise AssertionError(
            "a rising edge on imx_ctrl with the FPGA region booted did not "
            "start IMX within 1 ms") from None


@cocotb.test()
async def test_HK_SEQ_06_start_request_cleared(dut):
    """VC-HK-0057: after a latchup the request is gone; it takes a new edge.

    Eth1 is booted, latched by its first rail losing PGOOD, and the rail
    restored at once, with eth1_ctrl held high throughout. Once the latch
    has ended the region is free to boot, and would if its start request
    were still set. It must not; a fresh low-high edge must start it.
    """
    region, first = "eth1", SOFTWARE["eth1"][0]
    board.drive(dut)
    await boot.hardware(dut)
    boundary(dut, CONTROL[region]).value = 1
    await until(dut.clk, lambda: _high(dut, "%s_status_to_pf" % region),
                timeout_s=0.5, poll_ms=0.1)
    board.drive(dut, fail=(pgood_of(first),))
    await with_timeout(FallingEdge(boundary(dut, first)), 1, "ms")
    board.drive(dut)

    again = await _quiet(dut, SOFTWARE[region], QUIET_MS)
    dut._log.info("%s latched, rail restored, control held high: %s in %.0f ms",
                  region, again or "nothing re-asserted", QUIET_MS)
    assert not again, (
        "%s latched up with its control input held high, and once the latch "
        "ended it booted again by itself -- its start request was not "
        "cleared: %s" % (region, ", ".join("%s at +%.1f ms" % kv
                                           for kv in again.items())))

    boundary(dut, CONTROL[region]).value = 0
    await advance(dut.clk, seconds=POLL_MS / 1000.0)
    boundary(dut, CONTROL[region]).value = 1
    try:
        await with_timeout(RisingEdge(boundary(dut, first)), 1, "ms")
    except SimTimeoutError:
        raise AssertionError("a fresh low-high edge did not restart %s, so its "
                             "request was not merely cleared but lost" % region
                             ) from None


def test_hk_seq_software():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_seq_software",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
