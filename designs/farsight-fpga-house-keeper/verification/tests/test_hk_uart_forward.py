"""Forwarding and owning the RS-422 lines: HK-UART-01, -02, -03, -04, -10.

Items: VC-HK-0084, VC-HK-0085, VC-HK-0086, VC-HK-0088, VC-HK-0087.
Clause: VVP-HK-004.

  HK-UART-01  Forward the payload bus's receive line to the PolarFire while
              the FPGA region has booted.
  HK-UART-02  Drive the line to the PolarFire low while it has not.
  HK-UART-03  Forward the PolarFire's transmit line to the payload bus while
              the FPGA region has booted and no failure is latched.
  HK-UART-04  On a latched failure, take control of the line to the bus.
  HK-UART-10  Drive the line to the bus to the UART idle level whenever it is
              neither forwarding the PolarFire nor sending the beacon.

| Direction | In | Out |
| --- | --- | --- |
| bus to PolarFire | `rs422_ttl_bus_to_farsight_pa3` | `rs422_ttl_bus_to_farsight_pf` |
| PolarFire to bus | `rs422_ttl_farsight_to_bus_pf` | `rs422_ttl_farsight_to_bus_pa3` |

One timeline, recorded once per module (`_scenario`) and read by each test:
traffic on both inputs before the FPGA region is up; traffic on both once
it is; a PolarFire transmission with a failure latched part-way through it;
and the line to the bus watched from then until the first beacon is due.
Traffic is real 8N1 at 115,200 baud, and "forwarded" means every transition
of the input appears on the output at the same instant -- bit for bit.

**`HK-UART-02` is tested to its wording: held low.** `HK-F-11` once read the
low as a defect, a UART break where the other direction idles high, and this
test used to require the idle level. It was withdrawn: while the FPGA region
is not booted the PolarFire is unpowered, FAR-PM_FPGA_L4REQ-3 forbids driving
it high, and the line is released to follow the bus -- idling high -- at the
moment the rails come up, before the PolarFire's UART is running. The other
direction faces the bus, which is always powered, so the two are meant to
differ.
"""

from __future__ import annotations

import cocotb
from cocotb.triggers import FallingEdge, with_timeout
from cocotb.utils import get_sim_time

from fsverif import board, boot, sim
from fsverif.bfm.uart import BIT_PS_115200, drive_bytes
from fsverif.clkrst import advance, until
from fsverif.edges import Edges
from fsverif.pins import boundary

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

BUS_IN, PF_OUT = "rs422_ttl_bus_to_farsight_pa3", "rs422_ttl_bus_to_farsight_pf"
PF_IN, BUS_OUT = "rs422_ttl_farsight_to_bus_pf", "rs422_ttl_farsight_to_bus_pa3"
LINES = (BUS_IN, PF_OUT, PF_IN, BUS_OUT)
IDLE = 1

TRAFFIC = [0x55, 0xA3, 0x0F, 0xF0, 0x81]
#: Long enough that the failure lands in the middle of it.
LONG_TRAFFIC = [0x55, 0xAA] * 10
FAULT_RAIL, FAULT_ENABLE = "ddr16_pgood_1v2", "ddr16_en_1v2"
#: Short of the 996 ms at which the first beacon is due.
QUIET_MS = 900.0

_RESULT = {}


def _now_ns() -> float:
    return get_sim_time("ns")


async def _window(dut, send) -> dict:
    """Run `send` -- a list of (line, bytes) -- with every line watched."""
    edges = Edges(dut, LINES, origin_ns=0)
    levels_before = {l: int(boundary(dut, l).value) for l in LINES}
    tasks = [cocotb.start_soon(drive_bytes(boundary(dut, line), data))
             for line, data in send]
    for task in tasks:
        await task
    await advance(dut.clk, seconds=0.0001)
    edges.stop()
    return {"events": {l: list(edges.events[l]) for l in LINES},
            "before": levels_before,
            "after": {l: int(boundary(dut, l).value) for l in LINES}}


def _follows(window, src: str, dst: str, since_ns: float = 0.0) -> list:
    """Input transitions after `since_ns` that did not appear on the output
    at the same instant."""
    out = {(round(t * 1e6), v) for t, v in window["events"][dst]}
    return [(t, v) for t, v in window["events"][src]
            if t * 1e6 >= since_ns and (round(t * 1e6), v) not in out]


async def _scenario(dut) -> dict:
    if _RESULT:
        return _RESULT
    for line in (BUS_IN, PF_IN):
        boundary(dut, line).value = IDLE
    board.drive(dut)
    await boot.release(dut)
    await advance(dut.clk, seconds=0.010)

    _RESULT["unbooted"] = await _window(dut, [(BUS_IN, TRAFFIC), (PF_IN, TRAFFIC)])
    await until(dut.clk, lambda: int(boundary(dut, "pf_status_to_pf").value) == 1,
                timeout_s=2.0)
    await until(dut.clk,
                lambda: int(boundary(dut, boot.LAST_HARDWARE_STATUS).value) == 1,
                timeout_s=0.5)
    _RESULT["booted"] = await _window(dut, [(BUS_IN, TRAFFIC), (PF_IN, TRAFFIC)])

    # A PolarFire transmission with the failure latched part-way through.
    edges = Edges(dut, LINES, origin_ns=0)
    sender = cocotb.start_soon(drive_bytes(boundary(dut, PF_IN), LONG_TRAFFIC))
    await advance(dut.clk, seconds=len(LONG_TRAFFIC) * 10 * BIT_PS_115200 / 2e12)
    board.drive(dut, fault=(FAULT_RAIL,))
    await with_timeout(FallingEdge(boundary(dut, FAULT_ENABLE)), 1, "ms")
    failed_at = _now_ns()
    await sender
    await advance(dut.clk, seconds=QUIET_MS / 1000.0)
    edges.stop()
    _RESULT["failure"] = {"events": {l: list(edges.events[l]) for l in LINES},
                          "failed_at": failed_at,
                          "after": {l: int(boundary(dut, l).value) for l in LINES}}
    return _RESULT


@cocotb.test()
async def test_HK_UART_01_forward_rx_when_booted(dut):
    """VC-HK-0084: bus to PolarFire, bit for bit, once the FPGA is up."""
    window = (await _scenario(dut))["booted"]
    sent = len(window["events"][BUS_IN])
    missed = _follows(window, BUS_IN, PF_OUT)
    dut._log.info("FPGA up: %d transitions on %s, %d not reproduced on %s",
                  sent, BUS_IN, len(missed), PF_OUT)
    assert sent, "no traffic was sent, so nothing was forwarded"
    assert not missed, (
        "with the FPGA region booted, %d of %d transitions from the bus did "
        "not reach the PolarFire at the same instant" % (len(missed), sent))


@cocotb.test()
async def test_HK_UART_02_drive_low_when_unbooted(dut):
    """VC-HK-0085: before the FPGA is up, not following -- and held low."""
    window = (await _scenario(dut))["unbooted"]
    followed = len(window["events"][BUS_IN]) - len(_follows(window, BUS_IN, PF_OUT))
    moved = window["events"][PF_OUT]
    level = window["after"][PF_OUT]
    dut._log.info("FPGA down: %d bus transitions, %d of them reproduced; line "
                  "to the PolarFire held at %d", len(window["events"][BUS_IN]),
                  followed, level)
    assert window["events"][BUS_IN], (
        "the bus carried no traffic while the FPGA region was down, so there "
        "was nothing for the line to the PolarFire to fail to follow")
    assert not followed and not moved, (
        "with the FPGA region not booted, the line to the PolarFire followed "
        "the bus: %d transitions" % len(moved))
    assert level == 0 and window["before"][PF_OUT] == 0, (
        "with the FPGA region not booted the line to the PolarFire is at %d "
        "(before the traffic %d), not held low. The PolarFire is unpowered "
        "then, and FAR-PM_FPGA_L4REQ-3 forbids driving it high."
        % (level, window["before"][PF_OUT]))


@cocotb.test()
async def test_HK_UART_03_forward_tx_when_booted(dut):
    """VC-HK-0086: PolarFire to bus while booted and unfailed; not after."""
    result = await _scenario(dut)
    booted, failure = result["booted"], result["failure"]
    missed = _follows(booted, PF_IN, BUS_OUT)
    after = [(t, v) for t, v in failure["events"][PF_IN]
             if t * 1e6 > failure["failed_at"]]
    leaked = len(after) - len(_follows(failure, PF_IN, BUS_OUT,
                                       since_ns=failure["failed_at"]))
    dut._log.info("booted: %d PolarFire transitions, %d missed on the bus; "
                  "after the failure: %d sent, %d reached the bus",
                  len(booted["events"][PF_IN]), len(missed), len(after), leaked)
    assert booted["events"][PF_IN] and not missed, (
        "with the FPGA region booted and no failure, %d PolarFire transitions "
        "did not reach the bus" % len(missed))
    assert after and not leaked, (
        "with a failure latched, %d PolarFire transitions still reached the bus"
        % leaked)


@cocotb.test()
async def test_HK_UART_04_takes_line_on_failure(dut):
    """VC-HK-0088: at the failure the line becomes the housekeeper's.

    The PolarFire was mid-transmission. Up to the latch its traffic is on
    the bus; from the latch it is not, and the line is what the housekeeper
    drives -- idle, until its beacon.
    """
    failure = (await _scenario(dut))["failure"]
    t = failure["failed_at"]
    before = [e for e in failure["events"][PF_IN] if e[0] * 1e6 < t]
    reached = len(before) - len(_follows({"events": {
        PF_IN: before, BUS_OUT: failure["events"][BUS_OUT]}}, PF_IN, BUS_OUT))
    bus_after = [e for e in failure["events"][BUS_OUT] if e[0] * 1e6 > t]
    pf_after = [e for e in failure["events"][PF_IN] if e[0] * 1e6 > t]
    dut._log.info("PolarFire traffic before the latch: %d of %d transitions on "
                  "the bus; after it: %d sent, the bus moved %d times",
                  reached, len(before), len(pf_after), len(bus_after))
    assert before and reached == len(before), (
        "the PolarFire traffic was not being forwarded before the failure, so "
        "there was nothing for the housekeeper to take over")
    assert pf_after, "the PolarFire was not still transmitting at the failure"
    echoed = [e for e in bus_after if (round(e[0] * 1e6), e[1]) in
              {(round(p[0] * 1e6), p[1]) for p in pf_after}]
    assert not echoed, (
        "after the failure latched, %d PolarFire transitions still appeared on "
        "the bus" % len(echoed))


@cocotb.test()
async def test_HK_UART_10_idle_level_when_not_forwarding(dut):
    """VC-HK-0087: not forwarding and not beaconing, the bus line idles high.

    Two such states: the FPGA region not yet booted, with the PolarFire
    input toggling; and a failure latched, between the latch and the first
    beacon 996 ms later.
    """
    result = await _scenario(dut)
    unbooted, failure = result["unbooted"], result["failure"]
    t = failure["failed_at"]
    after = [e for e in failure["events"][BUS_OUT] if e[0] * 1e6 > t]
    problems = []
    if unbooted["events"][BUS_OUT] or unbooted["after"][BUS_OUT] != IDLE:
        problems.append("FPGA region not booted: the line to the bus moved %d "
                        "times and ended at %d" % (
                            len(unbooted["events"][BUS_OUT]),
                            unbooted["after"][BUS_OUT]))
    settled = [e for e in after if e[1] != IDLE]
    if settled or failure["after"][BUS_OUT] != IDLE:
        problems.append("failure latched, before the first beacon: the line to "
                        "the bus went to %s %d times in %.0f ms" % (
                            1 - IDLE, len(settled), QUIET_MS))
    dut._log.info("line to the bus: FPGA down -- %d transitions, at %d; after "
                  "the failure -- %d low-going transitions in %.0f ms, at %d",
                  len(unbooted["events"][BUS_OUT]), unbooted["after"][BUS_OUT],
                  len(settled), QUIET_MS, failure["after"][BUS_OUT])
    assert not problems, (
        "the line to the bus was not at the idle level while neither "
        "forwarding nor beaconing:\n  " + "\n  ".join(problems))


def test_hk_uart_forward():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_uart_forward",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
