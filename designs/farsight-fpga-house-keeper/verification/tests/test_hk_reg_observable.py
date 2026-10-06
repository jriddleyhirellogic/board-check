"""A region's outcome from its own outputs: HK-REG-01.

Item: VC-HK-0043. Clause: VVP-HK-004.

  HK-REG-01  Each power region shall be independently controllable and
             independently observable, such that its boot outcome and its
             fault condition can be determined without reference to any
             other region. For a region that reports on a single status
             bit, a status that has not risen within 1 s of the region
             starting to boot means the region has failed.

**The 1 s rule is pending systems confirmation.** It is the answer proposed on
2026-09-29 to whether "power rail status" in FAR-PM_FPGA_L4REQ-28 must tell a
failed region from one still booting: no, the PolarFire applies a 1 s timeout
instead. It is also an obligation on the PolarFire firmware, which has to
apply it. If systems answers differently, revisit the item and this test.

**LVDS is the subject, because it is the only region where this matters.** It
reports on one bit (`lvds_status_to_pf`), boots after the FPGA region, and
failing does not take the payload down, so a powered PolarFire is left to
decide on its own. Step Down and FPGA also report on one bit, but if either
fails the PolarFire is unpowered. The rule is only sound if two things hold,
and the test checks both:

- a failed LVDS region has made its last attempt within 1 s of the FPGA
  region reporting booted -- otherwise "still low at 1 s" could be a region
  that is about to succeed on its fourth attempt;
- a healthy LVDS region reports booted within that 1 s -- otherwise the rule
  would call a working region failed.

**What this does not count against the design.** Every `*_status_to_pf` is
forced low until the FPGA region has booted (`health_monitor_io.sv:311-321`).
It is not counted, because the only reader is the PolarFire, and the
PolarFire is only powered when the FPGA region has booted. `HK-OFFNOM-02`
requires the gating in any case.
"""

from __future__ import annotations

import cocotb

from fsverif import board, boot, sim
from fsverif.clkrst import advance, until
from fsverif.edges import Edges
from fsverif.pins import (DEBUG, HARDWARE_REGIONS, PF_OUTPUTS,
                          SOFTWARE_REGIONS, boundary)

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

REGION = "lvds"
ENABLE = "lvds_en"
DEAD_RAIL = "lvds_pgood"

#: `HK-REG-06`: one attempt plus three re-attempts, then declared failed.
ATTEMPTS = 4

#: The PolarFire's timeout, from the FPGA region reporting booted. Pending
#: systems confirmation (2026-09-29).
RULE_S = 1.0

#: Long enough after the 1 s that another attempt, if one were coming, would
#: have begun: longer than a retry hold.
AFTERWARDS_S = 0.3

STATUS = "lvds_status_to_pf"
FPGA_STATUS = "pf_status_to_pf"

#: Region names, and the one whose output does not carry its name: the FPGA
#: region powers the PolarFire, and reports on `pf_status_to_pf`
#: (`health_monitor_io.sv:320`).
REGIONS = tuple(name for name, _ in HARDWARE_REGIONS) + tuple(
    name for name, _, _ in SOFTWARE_REGIONS)
UNPREFIXED = {"fpga": ("pf_status_to_pf",)}


def own_outputs(region: str) -> tuple:
    """The outputs towards the PolarFire that belong to one region."""
    return UNPREFIXED.get(region, ()) + tuple(
        name for name, _ in PF_OUTPUTS if name.startswith(region + "_"))


def width(region: str) -> int:
    widths = dict(PF_OUTPUTS)
    return sum(widths[name] for name in own_outputs(region))


def _read(dut, names) -> dict:
    return {name: int(boundary(dut, name).value) for name in names}


@cocotb.test()
async def test_HK_REG_01_independently_controllable(dut):
    """VC-HK-0043: LVDS's single bit, read with a 1 s timeout, is conclusive."""
    outputs = own_outputs(REGION)
    assert outputs, "the %s region drives nothing towards the PolarFire" % REGION

    # --- failed: every attempt over within 1 s of the FPGA region booting
    board.drive(dut, fail=(DEAD_RAIL,))
    await boot.release(dut)
    edges = Edges(dut, (ENABLE, FPGA_STATUS))
    await until(dut.clk, lambda: bool(edges.rises(FPGA_STATUS)), timeout_s=3.0,
                describe=lambda: "the FPGA region never reported booted")
    fpga_up = edges.rises(FPGA_STATUS)[0]
    await advance(dut.clk, seconds=RULE_S)
    at_rule = {"attempts": len(edges.rises(ENABLE)),
               "enabled": int(boundary(dut, ENABLE).value),
               "status": int(boundary(dut, STATUS).value)}
    await advance(dut.clk, seconds=AFTERWARDS_S)
    later = len(edges.rises(ENABLE))
    last_attempt_end = edges.falls(ENABLE)[-1] - fpga_up if edges.falls(ENABLE) else None
    edges.stop()
    dut._log.info("LVDS dead: %d attempts by 1 s after the FPGA region booted, "
                  "the last ending at %.1f ms; %d attempts %.1f s later",
                  at_rule["attempts"], last_attempt_end or float("nan"),
                  later, RULE_S + AFTERWARDS_S)

    problems = []
    if at_rule["attempts"] != ATTEMPTS or at_rule["enabled"]:
        problems.append("a failed LVDS region had made %d attempts, not %d, "
                        "1 s after the FPGA region booted%s, so a status "
                        "still low then is not yet conclusive"
                        % (at_rule["attempts"], ATTEMPTS,
                           " and was still enabled" if at_rule["enabled"] else ""))
    if at_rule["status"]:
        problems.append("a failed LVDS region reported booted")
    if later != at_rule["attempts"]:
        problems.append("LVDS began another attempt after the 1 s had passed")

    # --- healthy: reports booted inside the 1 s
    board.drive(dut)
    await boot.release(dut)
    edges = Edges(dut, (STATUS, FPGA_STATUS))
    await until(dut.clk, lambda: bool(edges.rises(STATUS)), timeout_s=3.0,
                describe=lambda: "a healthy LVDS region never reported booted")
    took = edges.rises(STATUS)[0] - edges.rises(FPGA_STATUS)[0]
    edges.stop()
    dut._log.info("LVDS healthy: reported booted %.3f ms after the FPGA region",
                  took)
    if took > RULE_S * 1000.0:
        problems.append("a healthy LVDS region took %.1f ms to report booted, "
                        "so the 1 s rule would call it failed" % took)

    assert not problems, (
        "the PolarFire cannot determine LVDS's outcome from lvds_status_to_pf "
        "with a 1 s timeout:\n  " + "\n  ".join(problems))


def test_hk_reg_observable():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_reg_observable",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
