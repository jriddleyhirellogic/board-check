"""The heartbeat: HK-TLM-07.

Item: VC-HK-0080. Clause: VVP-HK-004.

  HK-TLM-07  The housekeeper shall emit a heartbeat that toggles every 1 s
             +/-5 %.

Measured over at least ten consecutive toggles, as the item asks -- which is
eleven seconds of simulated time at the flight parameters and makes this the
longest module in the suite, alone for that reason. The heartbeat is watched
on its edges, so the length costs simulation and nothing else.

**"While regions are failed" is made as bad as it can be.** DDR8 has a rail
dead from reset, so it fails its fourth attempt about 1.9 s in and the rest
of the chain carries on past it (`HK-SEQ-09`). Then, half way through, DDR16
loses a rail after booting, which is a hardware latchup and takes every
region down and holds it in reset (`HK-LAT-02`, `-03`). A heartbeat that
stopped when the regions did would say the housekeeper was dead while it was
in fact holding the payload safe -- the one moment the PolarFire most needs
to know otherwise.
"""

from __future__ import annotations

import cocotb
from cocotb.utils import get_sim_time

from fsverif import board, boot, sim
from fsverif.clkrst import advance, until
from fsverif.edges import Edges
from fsverif.pins import boundary

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

HEARTBEAT = "heartbeat"
INTERVAL_MS = (950.0, 1050.0)
INTERVALS = 10

#: Half way: several intervals with DDR8 failed, several with everything down.
LATCH_AT_S = 5.5


@cocotb.test()
async def test_HK_TLM_07_heartbeat_1s(dut):
    """VC-HK-0080: ten consecutive intervals inside 950-1050 ms, through
    a failed region and then a global latchup."""
    board.drive(dut, fail=("ddr8_pgood_1v2",))
    await boot.release(dut)
    edges = Edges(dut, (HEARTBEAT,), origin_ns=0)
    released = get_sim_time("ns") / 1e6

    await until(dut.clk, lambda: int(boundary(dut, "pf_status_to_pf").value) == 1,
                timeout_s=4.0, poll_ms=1.0,
                describe=lambda: "the FPGA region never booted past failed DDR8")
    failed_at = get_sim_time("ns") / 1e6 - released
    await advance(dut.clk, seconds=LATCH_AT_S - failed_at / 1000.0)
    board.drive(dut, fail=("ddr8_pgood_1v2", "ddr16_pgood_2v5"))
    latched_at = get_sim_time("ns") / 1e6 - released
    await until(dut.clk, lambda: len(edges.events[HEARTBEAT]) > INTERVALS + 1,
                timeout_s=INTERVALS + 3.0, poll_ms=10.0)
    edges.stop()

    toggles = [t - released for t, _ in edges.events[HEARTBEAT]]
    intervals = [b - a for a, b in zip(toggles, toggles[1:])]
    enables_up = [e for e in boot.HARDWARE_ENABLES if int(boundary(dut, e).value)]
    dut._log.info("DDR8 failed, FPGA up by %.0f ms; global latch at %.0f ms; "
                  "toggles at %s ms; intervals %s ms; %d hardware enables up at "
                  "the end", failed_at, latched_at,
                  ", ".join("%.1f" % t for t in toggles),
                  ", ".join("%.3f" % i for i in intervals), len(enables_up))

    assert not enables_up, (
        "the DDR16 latchup did not take the device down, so the heartbeat was "
        "not exercised with every region failed: %s" % ", ".join(enables_up))
    assert len(intervals) >= INTERVALS, (
        "the heartbeat toggled %d times, too few for %d consecutive intervals"
        % (len(toggles), INTERVALS))
    after = [i for t, i in zip(toggles[1:], intervals) if t > latched_at]
    assert after, "no heartbeat interval completed after the global latch"
    wrong = [(t, i) for t, i in zip(toggles[1:], intervals)
             if not INTERVAL_MS[0] <= i <= INTERVAL_MS[1]]
    assert not wrong, (
        "these heartbeat intervals were outside %.0f-%.0f ms: %s"
        % (INTERVAL_MS + (", ".join("%.3f ms ending at %.1f ms" % (i, t)
                                    for t, i in wrong),)))


def test_hk_tlm_heartbeat():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_tlm_heartbeat",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
