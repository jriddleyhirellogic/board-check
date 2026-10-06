"""Withdrawing, interlocking and recovering software regions: HK-SW-05,
-06 and -07.

Items: VC-HK-0065, VC-HK-0066, VC-HK-0067. Clause: VVP-HK-004.

  HK-SW-05  The housekeeper shall power down the secondary stepper motor
            region whenever the primary stepper motor region has booted
            successfully.
  HK-SW-06  A software-controlled region shall power down whenever its
            control input is deasserted.
  HK-SW-07  A software-controlled region that has latched up shall be
            re-enabled only by a low-then-high transition of its control
            input.

**`HK-SW-05` is tested to its parent, as `HK-REG-05` is.** The requirement
is met as worded: once the primary has booted the secondary goes down. But it
is `GAP`, because FAR-PM_FPGA_L4REQ-24 requires the two never to be enabled
at the same time, and the interlock keys on the primary having *booted*
rather than on its enable, so both are up for the primary's whole boot
window (`HK-F-05`). A test of the wording alone would pass, the merge gate
would then report the item's `expect: FAIL` as stale, and that report would
be false. So the test measures both, and fails on the parent's.
"""

from __future__ import annotations

import re

import cocotb
from cocotb.triggers import FallingEdge, RisingEdge, SimTimeoutError, with_timeout
from cocotb.utils import get_sim_time

from fsverif import board, boot, sim
from fsverif.clkrst import advance, until
from fsverif.edges import Edges
from fsverif.pins import SOFTWARE_REGIONS, boundary

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

SOFTWARE = {r: enables for r, _, enables in SOFTWARE_REGIONS}
CONTROL = {r: ctrl for r, ctrl, _ in SOFTWARE_REGIONS}

POLL_MS = 0.1
QUIET_MS = 100.0

#: `HK-SW-05`: how soon the secondary must be down once the primary is
#: declared booted -- its PGOOD rising, the filter, and a few clocks.
INTERLOCK_MS = 0.1


def pgood_of(enable: str) -> str:
    return re.sub(r"_en(_|$)", r"_pgood\1", enable)


def _now_ms() -> float:
    return get_sim_time("ns") / 1e6


def _high(dut, name: str) -> bool:
    return bool(int(boundary(dut, name).value))


async def _up(dut, region: str) -> None:
    boundary(dut, CONTROL[region]).value = 1
    await until(dut.clk, lambda: _high(dut, "%s_status_to_pf" % region),
                timeout_s=0.5, poll_ms=0.1,
                describe=lambda: "%s never reported booted" % region)


@cocotb.test()
async def test_HK_SW_05_secondary_stepper_down_on_primary(dut):
    """VC-HK-0065: primary booted, secondary down -- and never both up."""
    pri, sec = SOFTWARE["stepper_pri"][0], SOFTWARE["stepper_sec"][0]
    board.drive(dut)
    await boot.hardware(dut)
    await _up(dut, "stepper_sec")
    edges = Edges(dut, (pri, sec, pgood_of(pri)), origin_ns=0)
    await _up(dut, "stepper_pri")
    await advance(dut.clk, seconds=0.001)
    edges.stop()

    pri_up = edges.rises(pri)[0]
    booted = edges.rises(pgood_of(pri))[0]
    sec_down = edges.falls(sec)
    overlap = (sec_down[0] if sec_down else _now_ms()) - pri_up
    dut._log.info("secondary booted; primary enabled at %.4f ms, its PGOOD rose "
                  "at %.4f ms; secondary down at %s -- both enabled for %.4f ms",
                  pri_up, booted, sec_down[:1] or "never", overlap)

    problems = []
    if not sec_down:
        problems.append("the primary booted and the secondary was never "
                        "powered down")
    elif sec_down[0] - booted > INTERLOCK_MS:
        problems.append("the secondary went down %.3f ms after the primary's "
                        "PGOOD rose, not once it was declared booted"
                        % (sec_down[0] - booted))
    if overlap > 0:
        problems.append("both stepper regions were enabled together for %.3f "
                        "ms -- from the primary's enable at %.4f ms until the "
                        "secondary went down -- which FAR-PM_FPGA_L4REQ-24 "
                        "forbids. The interlock keys on the primary having "
                        "booted, not on its enable (health_monitor.sv:547). "
                        "HK-F-05." % (overlap, pri_up))
    assert not problems, (
        "the stepper interlock did not keep the two regions apart:\n  "
        + "\n  ".join(problems))


@cocotb.test()
async def test_HK_SW_06_region_down_on_deassert(dut):
    """VC-HK-0066: control low, region down, in reverse boot order.

    Both four-source regions, IMX and Eth1, withdrawn one after the other.
    The order is checked here and nothing more: when each source may begin
    is `HK-PDN-04`, and is `GAP` on `HK-F-28`.
    """
    problems = []
    board.drive(dut)
    await boot.hardware(dut)
    for region in ("imx", "eth1"):
        await _up(dut, region)
    for region in ("imx", "eth1"):
        order = SOFTWARE[region][::-1]
        edges = Edges(dut, order, origin_ns=0)
        boundary(dut, CONTROL[region]).value = 0
        await advance(dut.clk, seconds=0.010)
        edges.stop()
        falls = [(edges.falls(e) or [None])[0] for e in order]
        dut._log.info("%s withdrawn: %s", region, " -> ".join(
            "%s %s" % (e, "%.5f" % t if t is not None else "never")
            for e, t in zip(order, falls)))
        if None in falls:
            problems.append("%s: %s never deasserted" % (
                region, ", ".join(e for e, t in zip(order, falls) if t is None)))
        elif falls != sorted(falls) or len(set(falls)) != len(falls):
            problems.append("%s: its enables did not fall one at a time in "
                            "reverse boot order" % region)
    assert not problems, (
        "withdrawing a control input did not power its region down in order:"
        "\n  " + "\n  ".join(problems))


@cocotb.test()
async def test_HK_SW_07_latched_region_needs_low_high(dut):
    """VC-HK-0067: held high, a latched region stays down; low-high brings it.

    IMX latched by its 1V1 nFAULT, the fault removed at once, the control
    held high for 100 ms well past the 2.294 ms hold. Then low, then high.
    """
    first, control = SOFTWARE["imx"][0], CONTROL["imx"]
    board.drive(dut)
    await boot.hardware(dut)
    await _up(dut, "imx")
    board.drive(dut, fault=(pgood_of(first),))
    await with_timeout(FallingEdge(boundary(dut, first)), 1, "ms")
    board.drive(dut)

    start, seen = _now_ms(), {}
    while _now_ms() - start < QUIET_MS:
        await advance(dut.clk, seconds=POLL_MS / 1000.0)
        for e in SOFTWARE["imx"]:
            if e not in seen and _high(dut, e):
                seen[e] = _now_ms() - start
    dut._log.info("IMX latched, fault removed, control held high: %s in %.0f ms",
                  seen or "nothing re-asserted", QUIET_MS)
    assert not seen, (
        "IMX latched up and, with imx_ctrl merely held high, re-enabled: %s"
        % ", ".join("%s at +%.1f ms" % kv for kv in seen.items()))

    boundary(dut, control).value = 0
    await advance(dut.clk, seconds=POLL_MS / 1000.0)
    boundary(dut, control).value = 1
    try:
        await with_timeout(RisingEdge(boundary(dut, first)), 1, "ms")
    except SimTimeoutError:
        raise AssertionError("a low-high transition of imx_ctrl did not "
                             "re-enable the latched region") from None


def test_hk_sw_down():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_sw_down",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
