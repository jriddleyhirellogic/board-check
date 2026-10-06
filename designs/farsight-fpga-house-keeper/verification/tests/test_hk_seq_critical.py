"""Critical predecessors: HK-SEQ-03.

Item: VC-HK-0053. Clause: VVP-HK-004.

  HK-SEQ-03  The DDR8 and LVDS regions shall begin booting only after the
             preceding region has booted successfully.

DDR8 follows step-down and LVDS follows FPGA, and the rule for both is
success -- not merely having finished, which is the rule for DDR16 and FPGA
(`HK-SEQ-09`). The two are told apart only by what happens when the
predecessor *fails*, so each is exercised that way: the predecessor's last
rail held dead, four attempts made and the region declared failed, and the
successor must never assert an enable. And nominally, where it must assert
its first enable only after the predecessor's last rail came good.

A failed step-down or FPGA region also latches a power-down (`HK-PDN-01`),
which by itself would keep DDR8 or LVDS down. So the successor is watched
from the start of the predecessor's attempts, not only after its failure:
if it started during them -- before any power-down existed -- this sees it.
"""

from __future__ import annotations

import re

import cocotb
from cocotb.utils import get_sim_time

from fsverif import board, boot, sim
from fsverif.clkrst import advance, until
from fsverif.edges import Edges
from fsverif.pins import HARDWARE_REGIONS, boundary

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

HARDWARE = dict(HARDWARE_REGIONS)
PAIRS = (("step_down", "ddr8"), ("fpga", "lvds"))

#: Four attempts of about 225 ms, and a margin.
ATTEMPTS_S = 1.2


def pgood_of(enable: str) -> str:
    return re.sub(r"_en(_|$)", r"_pgood\1", enable)


def _now_ms() -> float:
    return get_sim_time("ns") / 1e6


@cocotb.test()
async def test_HK_SEQ_03_ddr8_lvds_need_success(dut):
    """VC-HK-0053: DDR8 and LVDS start on success, and not on failure."""
    problems = []

    # Nominal: each successor starts after its predecessor's last rail.
    board.drive(dut)
    watched = tuple(pgood_of(HARDWARE[p][-1]) for p, _ in PAIRS) + tuple(
        HARDWARE[s][0] for _, s in PAIRS)
    await boot.release(dut)
    edges = Edges(dut, watched, origin_ns=0)
    await until(dut.clk,
                lambda: int(boundary(dut, boot.LAST_HARDWARE_STATUS).value) == 1,
                timeout_s=2.0)
    edges.stop()
    for before, after in PAIRS:
        good = edges.rises(pgood_of(HARDWARE[before][-1]))
        began = edges.rises(HARDWARE[after][0])
        dut._log.info("nominal: %s's last rail good at %s, %s began at %s",
                      before, good, after, began)
        if not good or not began or began[0] <= good[0]:
            problems.append("nominal: %s began at %s ms, not after %s's last "
                            "rail came good at %s ms" % (after, began, before, good))

    # Predecessor failed: its last rail dead, the successor watched throughout.
    for before, after in PAIRS:
        dead = pgood_of(HARDWARE[before][-1])
        board.drive(dut, fail=(dead,))
        await boot.release(dut)
        edges = Edges(dut, (HARDWARE[before][0],) + HARDWARE[after], origin_ns=0)
        await until(dut.clk, lambda: bool(edges.rises(HARDWARE[before][0])),
                    timeout_s=3.0, poll_ms=1.0)
        await advance(dut.clk, seconds=ATTEMPTS_S)
        edges.stop()
        attempts = len(edges.rises(HARDWARE[before][0]))
        started = {e: edges.rises(e) for e in HARDWARE[after] if edges.rises(e)}
        dut._log.info("%s dead: %s made %d attempts; %s asserted %s", dead,
                      before, attempts, after, started or "nothing")
        if attempts != 4:
            problems.append("%s dead: %s made %d attempts, not 4, so it was not "
                            "the failed case that was exercised"
                            % (dead, before, attempts))
        if started:
            problems.append("%s dead: %s never booted, but %s asserted %s"
                            % (dead, before, after, ", ".join(
                                "%s at %.1f ms" % (e, t[0])
                                for e, t in started.items())))

    assert not problems, (
        "DDR8 and LVDS did not begin only after their predecessor succeeded:\n  "
        + "\n  ".join(problems))


def test_hk_seq_critical():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_seq_critical",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
