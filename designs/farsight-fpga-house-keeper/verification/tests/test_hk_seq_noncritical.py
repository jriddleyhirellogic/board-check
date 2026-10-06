"""Non-critical predecessors: HK-SEQ-09.

Item: VC-HK-0054. Clause: VVP-HK-004.

  HK-SEQ-09  The DDR16 and FPGA regions shall begin booting once the
             preceding region has finished booting, whether it succeeded or
             failed.

The item says why the failed case is the one that matters: on success this
is indistinguishable from `HK-SEQ-03`. So both DDR banks are made to fail --
the middle rail of each held dead -- in one boot. DDR8 makes its four
attempts and is declared failed; DDR16 must then begin, and not before; DDR16
makes its four and is declared failed; FPGA must then begin, and not before.
"Not before" is checked against the end of the predecessor's fourth attempt,
because a successor that began during the retries would be starting on a
region that had not finished.

The nominal case -- predecessor succeeded -- is `HK-SEQ-02`'s boot order.
"""

from __future__ import annotations

import re

import cocotb

from fsverif import board, boot, sim
from fsverif.clkrst import until
from fsverif.edges import Edges
from fsverif.pins import HARDWARE_REGIONS, boundary

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

HARDWARE = dict(HARDWARE_REGIONS)
PAIRS = (("ddr8", "ddr16"), ("ddr16", "fpga"))
DEAD = ("ddr8_pgood_1v2", "ddr16_pgood_1v2")

#: How soon the successor must follow once the predecessor has finished: the
#: chain is registered (`health_monitor.sv:672-673`), so a few clocks.
FOLLOWS_MS = 0.1

#: "Finished" is observed as the predecessor's first enable falling at the
#: end of its fourth attempt, which trails the declaration itself by a couple
#: of clocks; the successor starts a couple of clocks after the declaration.
#: The two can land either way round, so "before it finished" allows for a
#: microsecond of pipeline -- far short of the 225 ms an attempt takes, which
#: is what a successor starting during the retries would look like.
PIPELINE_MS = 0.001


@cocotb.test()
async def test_HK_SEQ_09_ddr16_fpga_need_finish(dut):
    """VC-HK-0054: DDR16 and FPGA follow a predecessor that failed."""
    board.drive(dut, fail=DEAD)
    await boot.release(dut)
    edges = Edges(dut, tuple(HARDWARE[r][0] for r in ("ddr8", "ddr16", "fpga")),
                  origin_ns=0)
    await until(dut.clk, lambda: int(boundary(dut, "pf_status_to_pf").value) == 1,
                timeout_s=4.0, poll_ms=1.0,
                describe=lambda: "the FPGA region never booted")
    edges.stop()

    problems = []
    for before, after in PAIRS:
        first = HARDWARE[before][0]
        attempts, ended = edges.rises(first), edges.falls(first)
        began = edges.rises(HARDWARE[after][0])
        dut._log.info("%s: %d attempts, the last ending at %s; %s began at %s",
                      before, len(attempts), ended[-1:] or "never", after,
                      began[:1] or "never")
        if len(attempts) != 4 or len(ended) != 4:
            problems.append("%s made %d attempts, not 4, so it was not declared "
                            "failed and the failed case was not exercised"
                            % (before, len(attempts)))
            continue
        if not began:
            problems.append("%s failed after four attempts and %s never began"
                            % (before, after))
        elif began[0] < ended[-1] - PIPELINE_MS:
            problems.append("%s began at %.3f ms, during %s's attempts, before "
                            "it had finished at %.3f ms"
                            % (after, began[0], before, ended[-1]))
        elif began[0] - ended[-1] > FOLLOWS_MS:
            problems.append("%s began %.3f ms after %s finished, not at once"
                            % (after, began[0] - ended[-1], before))
    assert not problems, (
        "DDR16 and FPGA did not begin once their predecessor had finished "
        "booting in failure:\n  " + "\n  ".join(problems))


def test_hk_seq_noncritical():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_seq_noncritical",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
