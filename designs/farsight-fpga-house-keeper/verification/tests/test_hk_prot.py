"""The IMX short outputs: HK-PROT-02 and -03.

Items: VC-HK-0094, VC-HK-0095. Clause: VVP-HK-004.

  HK-PROT-02  Both IMX short outputs shall be asserted when a latchup occurs
              in any IMX supply.
  HK-PROT-03  An IMX short output shall be released when the corresponding
              IMX supply enable is next asserted.

`imx_nshort_1v1` and `imx_nshort_1v8` are active low and discharge the IMX
sensor supplies of the same names.

**Both shorts, on a latchup in any of the four supplies.** The intent,
confirmed by avionics hardware on 2026-10-01: the shorts exist to minimise
how long the image sensor's rails are out of their required relationship
(IMX531 power on/off sequencing). A latchup on any sensor rail is an
uncontrolled power-down that cannot be sequenced, so every rail is pulled
down as fast as possible -- both shorts, whichever supply latched, including
2V9 and 3V3, which have no short of their own. The design does this
(`health_monitor.sv:683-686`). FAR-PM_FPGA_L4REQ-6's "with respective
supplies" reads as per supply and is to be reworded in Jama to match.

The test latches each of the four sources in turn and requires both shorts
each time, from a state where neither was asserted.
"""

from __future__ import annotations

import re

import cocotb
from cocotb.triggers import FallingEdge, with_timeout
from cocotb.utils import get_sim_time

from fsverif import board, boot, sim
from fsverif.clkrst import advance, until
from fsverif.edges import Edges
from fsverif.pins import SOFTWARE_REGIONS, boundary

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

IMX = dict((r, enables) for r, _, enables in SOFTWARE_REGIONS)["imx"]
CONTROL = "imx_ctrl"
STATUS = "imx_status_to_pf"
SHORTS = {"imx_en_1v1": "imx_nshort_1v1", "imx_en_1v8": "imx_nshort_1v8"}

#: Both shorts, whichever IMX supply latched.
BOTH = set(SHORTS.values())

#: A short follows the region's latch by a register (`health_monitor.sv:683`).
FOLLOWS_MS = 0.001


def pgood_of(enable: str) -> str:
    return re.sub(r"_en(_|$)", r"_pgood\1", enable)


def _now_ms() -> float:
    return get_sim_time("ns") / 1e6


def _asserted(dut) -> set:
    return {s for s in SHORTS.values() if not int(boundary(dut, s).value)}


async def _imx_up(dut) -> None:
    boundary(dut, CONTROL).value = 0
    await advance(dut.clk, seconds=0.003)
    boundary(dut, CONTROL).value = 1
    await until(dut.clk, lambda: int(boundary(dut, STATUS).value) == 1,
                timeout_s=0.1, poll_ms=0.1,
                describe=lambda: "IMX never booted")


async def _latch(dut, enable: str) -> None:
    board.drive(dut, fail=(pgood_of(enable),))
    await with_timeout(FallingEdge(boundary(dut, enable)), 1, "ms")
    await advance(dut.clk, seconds=FOLLOWS_MS / 1000.0)


@cocotb.test()
async def test_HK_PROT_02_both_shorts_on_imx_latchup(dut):
    """VC-HK-0094: each IMX source latched in turn; both shorts every time."""
    board.drive(dut)
    await boot.hardware(dut)
    problems = []
    for enable in IMX:
        board.drive(dut)
        await _imx_up(dut)
        before = _asserted(dut)
        await _latch(dut, enable)
        got = _asserted(dut)
        dut._log.info("%s latched: shorts asserted %s", enable, sorted(got) or "none")
        if before:
            problems.append("before latching %s, %s were already asserted"
                            % (enable, sorted(before)))
        if got != BOTH:
            problems.append("%s latched: %s asserted, not both shorts"
                            % (enable, sorted(got) or "none"))
    assert not problems, (
        "a latchup in an IMX supply did not assert both IMX short outputs, "
        "so the sensor's rails are left to decay out of their required "
        "relationship:\n  " + "\n  ".join(problems))


@cocotb.test()
async def test_HK_PROT_03_short_released_on_enable(dut):
    """VC-HK-0095: each short releases as its supply is re-enabled.

    IMX latched, so both shorts assert; then requested again. As the region
    boots, 1V1 is enabled first and 1V8 about 1.2 ms later. Each short must
    stay asserted until its own supply's enable rises, and release then --
    so the 1V8 short releasing with the 1V1 enable fails as surely as one
    that never releases.
    """
    board.drive(dut)
    await boot.hardware(dut)
    await _imx_up(dut)
    await _latch(dut, IMX[0])
    assert _asserted(dut) == set(SHORTS.values()), (
        "latching IMX did not assert both shorts, so there is nothing to "
        "release: %s" % sorted(_asserted(dut)))
    board.drive(dut)
    edges = Edges(dut, tuple(SHORTS) + tuple(SHORTS.values()), origin_ns=0)
    await _imx_up(dut)
    await advance(dut.clk, seconds=0.001)
    edges.stop()

    problems = []
    for enable, short in SHORTS.items():
        on = edges.rises(enable)
        released = edges.rises(short)
        dut._log.info("%s asserted at %s; %s released at %s", enable,
                      on[:1] or "never", short, released[:1] or "never")
        if not on:
            problems.append("%s was never re-enabled" % enable)
        elif not released:
            problems.append("%s never released after %s was re-enabled"
                            % (short, enable))
        elif released[0] < on[0]:
            problems.append("%s released at %.4f ms, before %s was re-enabled "
                            "at %.4f ms" % (short, released[0], enable, on[0]))
        elif released[0] - on[0] > FOLLOWS_MS:
            problems.append("%s released %.3f ms after %s was re-enabled, not "
                            "with it" % (short, released[0] - on[0], enable))
    assert not problems, (
        "an IMX short output was not released when its own supply was next "
        "enabled:\n  " + "\n  ".join(problems))


def test_hk_prot():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_prot",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
