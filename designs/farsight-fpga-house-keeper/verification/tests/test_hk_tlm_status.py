"""Region status to the PolarFire: HK-TLM-01, -02 and -09.

Items: VC-HK-0074, VC-HK-0075, VC-HK-0082. Clause: VVP-HK-004.

  HK-TLM-01  The housekeeper shall report per-region boot status to the
             PolarFire on a dedicated output per region.
  HK-TLM-02  Every region status output shall be driven low while the FPGA
             region has not booted successfully.
  HK-TLM-09  The housekeeper shall report region status such that the
             PolarFire can determine which components are enabled.

**`HK-TLM-01`'s "does not alter another region's output" excludes one
region by design.** Every other status is gated on the FPGA region having
booted (`HK-TLM-02`), so the FPGA region's own status change does move them
all, and must. The PolarFire is only powered once that has happened, so it
never sees the gating act. What is tested is every other status change:
each software region withdrawn and requested in turn, with every other
status watched; and a hardware region that fails while the rest boot, which
is the only way a single hardware region's status can differ from the others
-- a hardware *latchup* is global and takes them all.

**`HK-TLM-09` fails, and its own note says why.** The outputs report *boot
succeeded*, which is enablement and health together. A region powered and
still booting -- or retrying -- reads 0, the same as a region that is off.
The criterion asks for enablement to be determinable "for every combination
of region states the design can reach", and booting is one of them, so the
test finds the pair of states that read the same.
"""

from __future__ import annotations

import cocotb
from cocotb.triggers import RisingEdge, with_timeout
from cocotb.utils import get_sim_time

from fsverif import board, boot, sim
from fsverif.clkrst import advance, until
from fsverif.pins import (HARDWARE_REGIONS, SOFTWARE_REGIONS, STATUS_OUTPUTS,
                          boundary)

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

SOFTWARE = {r: enables for r, _, enables in SOFTWARE_REGIONS}
CONTROL = {r: ctrl for r, ctrl, _ in SOFTWARE_REGIONS}
HARDWARE = dict(HARDWARE_REGIONS)

#: Each region's status output. The FPGA region's is `pf_status_to_pf`
#: (`health_monitor_io.sv:320`); `pa3_status_to_pf` is the housekeeper's
#: own, not a region's.
STATUS = {r: "%s_status_to_pf" % r for r in list(HARDWARE) + list(SOFTWARE)}
STATUS["fpga"] = "pf_status_to_pf"
REGION_STATUSES = tuple(STATUS.values())

POLL_MS = 0.05
SETTLE_MS = 20.0


def _now_ms() -> float:
    return get_sim_time("ns") / 1e6


def _high(dut, name: str) -> bool:
    return bool(int(boundary(dut, name).value))


def _statuses(dut) -> dict:
    return {s: _high(dut, s) for s in REGION_STATUSES}


async def _change(dut, region: str, level: int) -> list:
    """Drive one region's control and watch every other status meanwhile."""
    before = _statuses(dut)
    boundary(dut, CONTROL[region]).value = level
    start, moved = _now_ms(), {}
    while _now_ms() - start < SETTLE_MS:
        await advance(dut.clk, seconds=POLL_MS / 1000.0)
        for s, v in _statuses(dut).items():
            if s != STATUS[region] and v != before[s]:
                moved.setdefault(s, _now_ms() - start)
    problems = []
    if _high(dut, STATUS[region]) != bool(level):
        problems.append("%s %s and its status did not follow" % (
            region, "requested" if level else "withdrawn"))
    if moved:
        problems.append("%s %s changed other regions' statuses: %s" % (
            region, "requested" if level else "withdrawn", ", ".join(moved)))
    return problems


@cocotb.test()
async def test_HK_TLM_01_per_region_status_output(dut):
    """VC-HK-0074: one output per region, and each moves alone."""
    problems = []
    outputs = list(STATUS.values())
    if len(set(outputs)) != len(outputs):
        problems.append("two regions share a status output: %s" % outputs)
    missing = [o for o in outputs if o not in STATUS_OUTPUTS]
    if missing:
        problems.append("not status outputs of the device: %s" % missing)

    # Software regions, each withdrawn and requested with the rest watched.
    board.drive(dut)
    await boot.hardware(dut)
    up = [r for r in SOFTWARE if r != "stepper_sec"]
    for r in up:
        boundary(dut, CONTROL[r]).value = 1
    await until(dut.clk, lambda: all(_high(dut, STATUS[r]) for r in up),
                timeout_s=0.5, poll_ms=0.1)
    for r in up:
        problems += await _change(dut, r, 0)
        if r != "stepper_pri":
            problems += await _change(dut, r, 1)
    problems += await _change(dut, "stepper_sec", 1)
    problems += await _change(dut, "stepper_sec", 0)

    # A hardware region failing while the rest boot.
    board.drive(dut, fail=("ddr8_pgood_1v2",))
    await boot.hardware(dut, timeout_s=4.0)
    reading = _statuses(dut)
    dut._log.info("DDR8 failed, the rest booted: %s", {
        s: int(v) for s, v in reading.items() if s in (
            STATUS[r] for r in HARDWARE)})
    wrong = [STATUS[r] for r in HARDWARE if reading[STATUS[r]] != (r != "ddr8")]
    if wrong:
        problems.append("with only DDR8 failed, these hardware statuses read "
                        "wrongly: %s" % ", ".join(wrong))
    assert not problems, (
        "region status was not reported on one dedicated output per region:"
        "\n  " + "\n  ".join(problems))


@cocotb.test()
async def test_HK_TLM_02_status_low_until_fpga(dut):
    """VC-HK-0075: every status low until the FPGA region has booted.

    With the FPGA region's last rail dead it never boots, while step-down,
    DDR8 and DDR16 before it boot successfully -- so there are regions whose
    actual state is "booted" and whose status must still read 0. Watched
    from reset release through all four FPGA attempts and the power-down
    that follows.
    """
    board.drive(dut, fail=("fpga_pgood_3v3_b5",))
    await boot.release(dut)
    start, seen, booted = _now_ms(), {}, set()
    before_fpga = [r for r in ("step_down", "ddr8", "ddr16")]
    while _now_ms() - start < 2200.0:
        await advance(dut.clk, seconds=0.1 / 1000.0)
        for s in REGION_STATUSES:
            if s not in seen and _high(dut, s):
                seen[s] = _now_ms() - start
        for r in before_fpga:
            if all(_high(dut, e) for e in HARDWARE[r]):
                booted.add(r)
    dut._log.info("FPGA never booted; %s were up at some point; statuses high: "
                  "%s", sorted(booted), seen or "none")
    assert booted == set(before_fpga), (
        "only %s were ever fully enabled, so the case of a booted region "
        "behind an unbooted FPGA was not exercised" % sorted(booted))
    assert not seen, (
        "with the FPGA region never booted, these region statuses were driven "
        "high: %s" % ", ".join("%s at +%.1f ms" % kv for kv in seen.items()))


@cocotb.test()
async def test_HK_TLM_09_status_identifies_enabled(dut):
    """VC-HK-0082: two states with different enables, the same statuses.

    IMX unrequested, then IMX requested with its 3V3 rail dead, read 5 ms
    in -- its first three sources powered, the fourth attempting. Enablement
    differs; the status outputs are compared.
    """
    board.drive(dut, fail=("imx_pgood_3v3",))
    await boot.hardware(dut)
    off = _statuses(dut)
    off_enabled = [e for e in SOFTWARE["imx"] if _high(dut, e)]

    boundary(dut, CONTROL["imx"]).value = 1
    await with_timeout(RisingEdge(boundary(dut, SOFTWARE["imx"][0])), 1, "ms")
    await advance(dut.clk, seconds=0.010)
    booting = _statuses(dut)
    booting_enabled = [e for e in SOFTWARE["imx"] if _high(dut, e)]
    dut._log.info("IMX off: enables %s; IMX booting: enables %s; statuses %s",
                  off_enabled or "none", booting_enabled,
                  "identical" if off == booting else "differ")
    assert booting_enabled and not off_enabled, (
        "the two states did not differ in what was enabled, so the comparison "
        "shows nothing")
    assert off != booting, (
        "with IMX off, and with IMX booting and %s enabled, every region "
        "status output read the same, so the PolarFire cannot tell from them "
        "which components are enabled. The outputs report boot succeeded -- "
        "enablement and health together -- and a region powered but still "
        "booting or retrying reads 0. See HK-F-27."
        % ", ".join(booting_enabled))


def test_hk_tlm_status():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_tlm_status",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
