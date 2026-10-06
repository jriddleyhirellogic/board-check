"""Requesting a software region: HK-SW-01, -02, -03 and -04.

Items: VC-HK-0061, VC-HK-0062, VC-HK-0063, VC-HK-0064. Clause: VVP-HK-004.

  HK-SW-01  The housekeeper shall enable the IMX sensor power region on
            request from the PolarFire.
  HK-SW-02  The housekeeper shall enable the LVDT power region on request.
  HK-SW-03  The housekeeper shall enable each Ethernet power region
            independently on request.
  HK-SW-04  The housekeeper shall enable either the primary or the secondary
            stepper motor power region on request.

Each is "this request starts this region and no other", and the second half
is the one that can fail: a control input wired to the wrong region, or to
two. So every enable on the device is read before the request and then every
0.05 ms while the region boots, and any change outside the requested region
fails -- a pulse that recovered counts, because a rail that came up briefly
has still been powered.
"""

from __future__ import annotations

import cocotb
from cocotb.utils import get_sim_time

from fsverif import board, boot, sim
from fsverif.clkrst import advance
from fsverif.pins import SOFTWARE_REGIONS, boundary, device_enables

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

SOFTWARE = {r: enables for r, _, enables in SOFTWARE_REGIONS}
CONTROL = {r: ctrl for r, ctrl, _ in SOFTWARE_REGIONS}

#: Four sources of up to 3 ms each, and a margin.
BOOT_MS = 20.0
POLL_MS = 0.05


def _now_ms() -> float:
    return get_sim_time("ns") / 1e6


def _high(dut, name: str) -> bool:
    return bool(int(boundary(dut, name).value))


async def _request(dut, region: str) -> list:
    """Raise one control input; return what went wrong, if anything."""
    enables = device_enables()
    before = {e: _high(dut, e) for e in enables}
    boundary(dut, CONTROL[region]).value = 1
    start, moved = _now_ms(), {}
    while _now_ms() - start < BOOT_MS:
        await advance(dut.clk, seconds=POLL_MS / 1000.0)
        for e in enables:
            if e not in SOFTWARE[region] and e not in moved \
                    and _high(dut, e) != before[e]:
                moved[e] = _now_ms() - start
    down = [e for e in SOFTWARE[region] if not _high(dut, e)]
    booted = _high(dut, "%s_status_to_pf" % region)
    dut._log.info("requested %s: %s; %d other enables unchanged", region,
                  "booted" if booted and not down else "NOT booted",
                  len(enables) - len(SOFTWARE[region]) - len(moved))
    problems = []
    if down or not booted:
        problems.append("%s was requested and did not boot: %s" % (
            region, ", ".join(down) if down else "status never rose"))
    if moved:
        problems.append("requesting %s changed enables outside it: %s" % (
            region, ", ".join("%s at +%.2f ms" % kv for kv in sorted(
                moved.items(), key=lambda kv: kv[1]))))
    return problems


async def _hardware(dut) -> None:
    board.drive(dut)
    await boot.hardware(dut)


def _check(problems) -> None:
    assert not problems, "\n  ".join(["a request did not start exactly its "
                                      "own region:"] + problems)


@cocotb.test()
async def test_HK_SW_01_imx_region_on_request(dut):
    """VC-HK-0061: imx_ctrl starts IMX and nothing else."""
    await _hardware(dut)
    _check(await _request(dut, "imx"))


@cocotb.test()
async def test_HK_SW_02_lvdt_region_on_request(dut):
    """VC-HK-0062: lvdt_ctrl starts LVDT and nothing else."""
    await _hardware(dut)
    _check(await _request(dut, "lvdt"))


@cocotb.test()
async def test_HK_SW_03_ethernet_regions_independent(dut):
    """VC-HK-0063: each Ethernet region on its own input, the other untouched.

    Eth1 first, with Eth2 down; then Eth2, with Eth1 up -- so that "does not
    change the other" is checked with the other in each state.
    """
    await _hardware(dut)
    _check(await _request(dut, "eth1") + await _request(dut, "eth2"))


@cocotb.test()
async def test_HK_SW_04_stepper_primary_or_secondary(dut):
    """VC-HK-0064: each stepper region starts on its own input, from down.

    The primary is requested and boots; then withdrawn and powered down; then
    the secondary is requested from that powered-down state.
    """
    await _hardware(dut)
    problems = await _request(dut, "stepper_pri")
    boundary(dut, CONTROL["stepper_pri"]).value = 0
    await advance(dut.clk, seconds=0.010)
    if _high(dut, SOFTWARE["stepper_pri"][0]):
        problems.append("stepper_pri did not power down when withdrawn, so the "
                        "secondary was not requested from the powered-down "
                        "state")
    problems += await _request(dut, "stepper_sec")
    _check(problems)


def test_hk_sw_request():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_sw_request",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
