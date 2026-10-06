"""What latches a global power-down, and what does not: HK-PDN-01.

Item: VC-HK-0068. Clause: VVP-HK-004.

  HK-PDN-01  The housekeeper shall latch a global power-down request only
             when the filtered EPS eFuse PGOOD goes low, when the FPGA region
             fails to boot, or when the step-down region fails to boot.

Three routes, each exercised on its own, and "only when" exercised as well:
the failures that must *not* latch it are applied, and the device must carry
on. That half is what excludes a software region, or a non-critical hardware
region, from shutting the payload down, and it is the half a test of the
three routes alone would never reach.

**The request is not a pin.** What it does is. Every software region is held
down by it (`health_monitor.sv:545-550`), and the hardware stages go down in
reverse behind them, so with anything up the observable is enables falling
that nothing else would have dropped. The step-down route has nothing up to
drop: step-down is the first region, and it failing means nothing after it
ever started. There the observable is `debug[4]`, a set-only register of
DDR16's power-down command (`health_monitor.sv:719-720`), which is
`start_pwr_dwn && !fpga_boot_done` and so equals the request while the FPGA
region has not booted. It is on a real pin (`fsverif.pins.DEBUG`).

Order, to save a boot: the negative case first, then the eFuse route on the
same device -- by then it has failed everything it may fail without shutting
down, and is still up. Then the FPGA and step-down routes, a boot each.
"""

from __future__ import annotations

import re

import cocotb

from fsverif import board, boot, sim
from fsverif.clkrst import advance, until
from fsverif.edges import Edges
from fsverif.pins import DEBUG, HARDWARE_REGIONS, boundary, device_enables

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

HARDWARE = dict(HARDWARE_REGIONS)

#: Failures that must not latch a power-down: a non-critical hardware region
#: failing to boot (DDR8, LVDS -- `HK-SEQ-03`), a software region failing to
#: boot (IMX), and a software region latching up (Eth1).
NOT_TRIGGERS = ("ddr8_pgood_1v2", "lvds_pgood", "imx_pgood_3v3")
LATCHED = "eth1"
LATCHED_RAIL = "eth1_pgood_1v0"

#: What must still be up afterwards if nothing latched. Each would be dropped
#: by a power-down request: the software ones at once, the hardware ones in
#: their turn.
SENTINEL_REGIONS = ("step_down", "ddr16", "fpga")
SENTINEL_SOFTWARE = {"eth2": "eth2_ctrl", "lvdt": "lvdt_ctrl",
                     "stepper_pri": "stepper_pri_ctrl"}

#: Four attempts of about 225 ms, for the regions failing to boot.
ATTEMPTS_S = 1.2

#: `debug[4]`: DDR16's power-down command, set-only.
DEBUG_DDR16_PWR_DWN = 1 << 4
#: `debug[2:0]` = 5 is a step-down boot failure (`health_monitor.sv:711`).
DEBUG_STEP_DOWN_BOOT_FAILED = 5

#: A power-down of a fully booted device: a few cycles per source, plus the
#: 2.294 ms source timeout wherever a PGOOD does not follow its enable.
SHUTDOWN_MS = 50.0


def pgood_of(enable: str) -> str:
    return re.sub(r"_en(_|$)", r"_pgood\1", enable)


def _high(dut, name: str) -> bool:
    return bool(int(boundary(dut, name).value))


def _dead(dut, *rails: str) -> None:
    index = board.index(board.model())
    dut.rail_fail.value = sum(1 << index[r] for r in rails)
    dut.rail_fault.value = 0


@cocotb.test()
async def test_HK_PDN_01_latch_conditions(dut):
    """VC-HK-0068: the three routes latch it, and nothing else does."""
    problems = []

    # -- Not a trigger: DDR8, LVDS and IMX failing to boot, Eth1 latching. --
    _dead(dut, *NOT_TRIGGERS)
    await boot.release(dut)
    await until(dut.clk, lambda: _high(dut, "pf_status_to_pf"), timeout_s=3.0,
                describe=lambda: "the FPGA region never booted")
    for control in ("imx_ctrl", "eth1_ctrl", *SENTINEL_SOFTWARE.values()):
        boundary(dut, control).value = 1
    statuses = ["%s_status_to_pf" % r for r in (LATCHED, *SENTINEL_SOFTWARE)]
    await until(dut.clk, lambda: all(_high(dut, s) for s in statuses),
                timeout_s=0.5, describe=lambda: "not booted: %s" % ", ".join(
                    s for s in statuses if not _high(dut, s)))
    _dead(dut, *NOT_TRIGGERS, LATCHED_RAIL)
    await advance(dut.clk, seconds=ATTEMPTS_S)

    sentinels = tuple(e for r in SENTINEL_REGIONS for e in HARDWARE[r])
    sentinels += tuple("%s_status_to_pf" % r for r in SENTINEL_SOFTWARE)
    fell = [s for s in sentinels if not _high(dut, s)]
    dut._log.info("after DDR8, LVDS and IMX failed to boot and Eth1 latched: "
                  "%d of %d sentinels still up", len(sentinels) - len(fell),
                  len(sentinels))
    if fell:
        problems.append(
            "with DDR8, LVDS and IMX failed to boot and Eth1 latched up -- "
            "none of them a trigger -- these went down as a power-down would "
            "take them: %s" % ", ".join(fell))

    # -- eFuse PGOOD, on the same device. --
    enables = device_enables()
    up = [e for e in enables if _high(dut, e)]
    _dead(dut, *NOT_TRIGGERS, "eps_efuse_pgood")
    try:
        await until(dut.clk, lambda: not any(_high(dut, e) for e in enables),
                    timeout_s=SHUTDOWN_MS / 1000.0, poll_ms=0.1)
        dut._log.info("eFuse PGOOD low: all %d enables that were up went down",
                      len(up))
    except TimeoutError:
        problems.append("eFuse PGOOD low: %.0f ms later these were still up: "
                        "%s" % (SHUTDOWN_MS, ", ".join(
                            e for e in enables if _high(dut, e))))

    # -- FPGA region fails to boot. --
    dead = pgood_of(HARDWARE["fpga"][-1])
    _dead(dut, dead)
    await boot.release(dut)
    edges = Edges(dut, (HARDWARE["fpga"][0], HARDWARE["step_down"][0]))
    held = tuple(e for r in ("step_down", "ddr8", "ddr16") for e in HARDWARE[r])
    await until(dut.clk, lambda: bool(edges.falls(HARDWARE["step_down"][0])),
                timeout_s=3.0, poll_ms=1.0)
    attempts = len(edges.rises(HARDWARE["fpga"][0]))
    last_fpga = max(edges.falls(HARDWARE["fpga"][0]) or [0.0])
    down_at = edges.falls(HARDWARE["step_down"][0])[0]
    dut._log.info("%s dead: FPGA made %d attempts, its last ending at %.1f ms; "
                  "step-down went down at %.1f ms", dead, attempts, last_fpga,
                  down_at)
    await advance(dut.clk, seconds=SHUTDOWN_MS / 1000.0)
    still = [e for e in held if _high(dut, e)]
    if attempts != 4 or down_at < last_fpga:
        problems.append("FPGA boot failure: step-down went down at %.1f ms, "
                        "but the FPGA region had made %d attempts, the last "
                        "ending at %.1f ms, so it was not the failure that "
                        "latched it" % (down_at, attempts, last_fpga))
    if still:
        problems.append("FPGA boot failure: the booted regions before it did "
                        "not all go down: %s still up" % ", ".join(still))
    edges.stop()

    # -- Step-down region fails to boot. --
    dead = pgood_of(HARDWARE["step_down"][-1])
    _dead(dut, dead)
    await boot.release(dut)
    edges = Edges(dut, (HARDWARE["step_down"][0],))
    await until(dut.clk, lambda: len(edges.rises(HARDWARE["step_down"][0])) >= 1,
                timeout_s=1.2)
    before = int(boundary(dut, DEBUG).value)
    await advance(dut.clk, seconds=ATTEMPTS_S)
    after = int(boundary(dut, DEBUG).value)
    dut._log.info("%s dead: step-down made %d attempts; debug[4] %d -> %d, "
                  "debug[2:0] = %d", dead, len(edges.rises(HARDWARE["step_down"][0])),
                  bool(before & DEBUG_DDR16_PWR_DWN),
                  bool(after & DEBUG_DDR16_PWR_DWN), after & 0x7)
    if before & DEBUG_DDR16_PWR_DWN:
        problems.append("step-down boot failure: debug[4] was already set "
                        "during the first attempt, before any failure")
    if (after & 0x7) != DEBUG_STEP_DOWN_BOOT_FAILED:
        problems.append("step-down boot failure: debug[2:0] reads %d, not %d, "
                        "so the region was not declared failed"
                        % (after & 0x7, DEBUG_STEP_DOWN_BOOT_FAILED))
    elif not after & DEBUG_DDR16_PWR_DWN:
        problems.append("step-down boot failure: the region was declared "
                        "failed but debug[4] never set, so no power-down "
                        "request latched")

    assert not problems, (
        "the global power-down request did not latch on exactly the three "
        "routes HK-PDN-01 allows:\n  " + "\n  ".join(problems))


def test_hk_pdn_routes():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_pdn_routes",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
