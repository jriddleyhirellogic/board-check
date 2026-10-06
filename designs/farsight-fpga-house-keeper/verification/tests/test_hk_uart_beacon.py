"""The failure beacon: HK-UART-05, -07, -08, -09, and HK-LAT-07.

Items: VC-HK-0089, VC-HK-0090, VC-HK-0091, VC-HK-0092, VC-HK-0007.
Clause: VVP-HK-004.

  HK-UART-05  The failure status message at 115,200 baud +/-2 %, 8N1.
  HK-UART-07  It reports the PGOOD and nFAULT snapshot latched at the first
              failure, not the live values.
  HK-UART-08  It repeats every 1 s +/-5 % until reset.
  HK-UART-09  The first is transmitted within 1 s +/-5 % of the failure.
  HK-LAT-07   The housekeeper retains the PGOOD and nFAULT state of every
              hardware-controlled source as sampled at the first failure.

**One failure, watched for five seconds, is the evidence for all five.** The
device boots, DDR16's 1V2 nFAULT is asserted -- a hardware latchup, which
latches the failure and takes the device down -- and the RS-422 line to the
payload bus is decoded through three beacons, a reset, and a second of
silence after it. Each test asserts its own criterion against that record,
and the record is made once per module (`_scenario`); a test run alone makes
it itself.

**The snapshot is only known through the beacon.** `HK-LAT-07`'s retained
state has no pin of its own; the message is where it reaches the boundary
(`uart_ctrl.sv:185-277`). The expected bytes are built from the pin levels
read immediately before the fault, plus the fault itself, laid out as the
message lays them out: `DE AD BE EF`, then FPGA PGOODs, FPGA nFAULT, LVDS
PGOOD, DDR16, DDR8 and step-down, then `BA DD FE ED`.

**After the latch the inputs are changed, deliberately.** Every rail loses
PGOOD as its enable falls, and further faults are asserted on sources in
other regions -- FPGA 1V0 and step-down 2V2 nFAULT, DDR8 2V5 dead. A snapshot
that followed the live inputs would show all of it. What cannot be done is
make the device *declare* a second failure: after a hardware latchup every
region is held in reset and can declare nothing, so `HK-LAT-07`'s "a
subsequent failure does not overwrite it" is exercised as the inputs of a
subsequent failure, and the first-fault-wins guard is by construction
(`health_monitor.sv:631`, `&& !failed`).
"""

from __future__ import annotations

import cocotb
from cocotb.triggers import FallingEdge, with_timeout
from cocotb.utils import get_sim_time

from fsverif import board, boot, sim
from fsverif.bfm.uart import BIT_PS_115200, Receiver
from fsverif.clkrst import advance
from fsverif.pins import boundary

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

LINE = "rs422_ttl_farsight_to_bus_pa3"
IDLE_INPUTS = ("rs422_ttl_farsight_to_bus_pf", "rs422_ttl_bus_to_farsight_pa3")
HEADER = [0xDE, 0xAD, 0xBE, 0xEF]
TRAILER = [0xBA, 0xDD, 0xFE, 0xED]

#: The six snapshot bytes, most significant bit first, as the message lays
#: them out (`uart_ctrl.sv:185-277`). A zero is a padding bit.
SNAPSHOT = (
    ("fpga_pgood_3v3_b5", "fpga_pgood_3v3_b4", "fpga_pgood_2v5a",
     "fpga_pgood_1v8_imx", "fpga_pgood_1v8", "fpga_pgood_1v25a",
     "fpga_pgood_1v0a", "fpga_pgood_1v0"),
    (0, 0, 0, 0, 0, 0, 0, "fpga_nfault_1v0"),
    (0, 0, 0, 0, 0, 0, 0, "lvds_pgood"),
    (0, 0, 0, "ddr16_pgood_0v6", "ddr16_pgood_1v2", "ddr16_pgood_2v5",
     "ddr16_nfault_1v2", "ddr16_nfault_2v5"),
    (0, 0, 0, "ddr8_pgood_0v6", "ddr8_pgood_1v2", "ddr8_pgood_2v5",
     "ddr8_nfault_1v2", "ddr8_nfault_2v5"),
    (0, 0, "step_down_pgood_4v0", "step_down_pgood_3v0", "step_down_pgood_2v2",
     "step_down_nfault_4v0", "step_down_nfault_3v0", "step_down_nfault_2v2"),
)
SNAPSHOT_PINS = tuple(p for byte in SNAPSHOT for p in byte if p)

FAULT_RAIL, FAULT_PIN, FAULT_ENABLE = ("ddr16_pgood_1v2", "ddr16_nfault_1v2",
                                       "ddr16_en_1v2")
#: What changes after the latch, besides every rail going down.
LATER = {"fault": ("ddr16_pgood_1v2", "fpga_pgood_1v0", "step_down_pgood_2v2"),
         "fail": ("ddr8_pgood_2v5",)}

WATCH_S = 3.2          # three beacons
AFTER_RESET_S = 1.2    # longer than a beacon period
GAP_MS = 10.0          # characters closer than this belong to one message

BAUD = (115_200 * 0.98, 115_200 * 1.02)
PERIOD_MS = (950.0, 1050.0)

_RESULT = {}


def _byte(levels: dict, layout) -> int:
    value = 0
    for bit in layout:
        value = (value << 1) | (levels[bit] if bit else 0)
    return value


def _message(levels: dict) -> list:
    return HEADER + [_byte(levels, b) for b in SNAPSHOT] + TRAILER


def _now_ms() -> float:
    return get_sim_time("ns") / 1e6


async def _scenario(dut) -> dict:
    if _RESULT:
        return _RESULT
    # Both RS-422 inputs at the UART idle level. Left undriven they read 0,
    # and once the device is rebooted the PolarFire's 0 is forwarded to the
    # bus and decoded as a character.
    for line in IDLE_INPUTS:
        boundary(dut, line).value = 1
    board.drive(dut)
    await boot.hardware(dut)
    rx = Receiver(boundary(dut, LINE))

    at_failure = {p: int(boundary(dut, p).value) for p in SNAPSHOT_PINS}
    at_failure[FAULT_PIN] = 0
    board.drive(dut, fault=(FAULT_RAIL,))
    await with_timeout(FallingEdge(boundary(dut, FAULT_ENABLE)), 1, "ms")
    failed_at = _now_ms()
    board.drive(dut, **LATER)
    await advance(dut.clk, seconds=0.010)
    live = {p: int(boundary(dut, p).value) for p in SNAPSHOT_PINS}

    await advance(dut.clk, seconds=WATCH_S)
    reset_at = _now_ms()
    before_reset = list(rx.chars)
    board.drive(dut)
    await boot.release(dut)
    await advance(dut.clk, seconds=AFTER_RESET_S)
    rx.stop()

    messages, current, last = [], [], None
    for char in before_reset:
        if last is not None and char[0] - last > GAP_MS * 1e6:
            messages.append(current)
            current = []
        current.append(char)
        last = char[0]
    if current:
        messages.append(current)

    _RESULT.update(
        failed_at=failed_at, reset_at=reset_at, messages=messages,
        after_reset=[c for c in rx.chars if c[0] / 1e6 > reset_at],
        expected=_message(at_failure), live=_message(live),
        at_failure=at_failure, live_levels=live)
    dut._log.info("failure latched at %.3f ms; %d messages before reset at "
                  "%.3f ms, starting at %s ms; %d characters after reset",
                  failed_at, len(messages), reset_at,
                  ", ".join("%.3f" % (m[0][0] / 1e6) for m in messages),
                  len(_RESULT["after_reset"]))
    for m in messages:
        dut._log.info("message: %s", " ".join("%02X" % c[1] for c in m))
    return _RESULT


def _starts(result) -> list:
    return [m[0][0] / 1e6 for m in result["messages"]]


@cocotb.test()
async def test_HK_UART_05_beacon_framing(dut):
    """VC-HK-0089: 115,200 baud within 2 %, 8 data bits, no parity, one stop.

    The bit period is measured on every character, from the start bit's
    falling edge to its last transition. 8N1 is held to three facts: every
    character decodes to the expected byte with 8 data bits, every stop bit
    is high one bit after the eighth data bit, and consecutive characters of
    a message start ten bits apart -- a parity bit would make it eleven.
    """
    result = await _scenario(dut)
    assert result["messages"], "no failure message was transmitted at all"
    chars = [c for m in result["messages"] for c in m]
    periods = [c[3] for c in chars if c[3]]
    bad_stop = [c for c in chars if not c[2]]
    baud = 1e12 / (sum(periods) / len(periods))
    spacing = sorted({round((b[0] - a[0]) * 1000 / (sum(periods) / len(periods)))
                      for m in result["messages"] for a, b in zip(m, m[1:])})
    dut._log.info("%d characters; measured %.1f baud (%+.2f %%); character "
                  "spacing %s bits; %d stop bits low", len(chars), baud,
                  (baud / 115_200 - 1) * 100, spacing, len(bad_stop))
    assert BAUD[0] <= baud <= BAUD[1], (
        "the beacon was sent at %.1f baud, outside 115,200 +/-2 %%" % baud)
    assert not bad_stop, "%d characters had a low stop bit" % len(bad_stop)
    assert spacing and min(spacing) >= 10 and spacing[0] == 10, (
        "characters within a message start %s bits apart; 8N1 back to back "
        "is 10" % spacing)
    wrong = [m for m in result["messages"]
             if [c[1] for c in m][:4] != HEADER or [c[1] for c in m][-4:] != TRAILER]
    assert not wrong, ("the constant header and trailer did not decode as 8N1: "
                       "%s" % [[("%02X" % c[1]) for c in m] for m in wrong])


@cocotb.test()
async def test_HK_UART_07_snapshot_not_live(dut):
    """VC-HK-0090: every message carries the at-failure values, not live."""
    result = await _scenario(dut)
    expected, live = result["expected"], result["live"]
    assert expected != live, (
        "the inputs after the latch read the same as at it, so the test cannot "
        "tell a snapshot from live values")
    wrong = [(m[0][0] / 1e6, [c[1] for c in m]) for m in result["messages"]
             if [c[1] for c in m] != expected]
    assert result["messages"], "no failure message was transmitted at all"
    assert not wrong, (
        "the failure message did not carry the snapshot taken at the failure.\n"
        "  expected (at failure): %s\n  live after the latch:  %s\n%s"
        % (" ".join("%02X" % b for b in expected),
           " ".join("%02X" % b for b in live),
           "\n".join("  sent at %.3f ms:       %s" % (t, " ".join("%02X" % b
                                                                  for b in v))
                     for t, v in wrong)))


@cocotb.test()
async def test_HK_UART_08_beacon_repeats_1s(dut):
    """VC-HK-0091: once a second, and until reset -- then not."""
    result = await _scenario(dut)
    starts = _starts(result)
    intervals = [b - a for a, b in zip(starts, starts[1:])]
    dut._log.info("message intervals %s ms; characters after reset: %d",
                  ", ".join("%.3f" % i for i in intervals),
                  len(result["after_reset"]))
    assert len(starts) >= 3, (
        "only %d messages in %.1f s, so it did not keep repeating"
        % (len(starts), WATCH_S))
    wrong = [i for i in intervals if not PERIOD_MS[0] <= i <= PERIOD_MS[1]]
    assert not wrong, ("message intervals outside %.0f-%.0f ms: %s"
                       % (PERIOD_MS + (wrong,)))
    assert not result["after_reset"], (
        "%d characters were sent after reset, which should have ended the "
        "beacon" % len(result["after_reset"]))


@cocotb.test()
async def test_HK_UART_09_first_beacon_within_1s(dut):
    """VC-HK-0092: the first message 950-1050 ms after the failure."""
    result = await _scenario(dut)
    starts = _starts(result)
    assert starts, "no failure message was transmitted at all"
    delay = starts[0] - result["failed_at"]
    dut._log.info("first message %.3f ms after the failure was latched", delay)
    assert PERIOD_MS[0] <= delay <= PERIOD_MS[1], (
        "the first message began %.3f ms after the failure, outside "
        "%.0f-%.0f ms" % ((delay,) + PERIOD_MS))


@cocotb.test()
async def test_HK_LAT_07_first_failure_snapshot_retained(dut):
    """VC-HK-0007: the retained state is every hardware source's at failure.

    Every PGOOD and nFAULT of every hardware source, bit by bit, against the
    level it had at the failure -- through all three messages, with every one
    of those inputs changed since.
    """
    result = await _scenario(dut)
    assert result["messages"], "no failure message, so no retained state to read"
    at, live = result["at_failure"], result["live_levels"]
    changed = [p for p in SNAPSHOT_PINS if at[p] != live[p]]
    wrong = {}
    for m in result["messages"]:
        values = [c[1] for c in m][4:10]
        for layout, value in zip(SNAPSHOT, values):
            for n, pin in enumerate(layout):
                if pin and ((value >> (7 - n)) & 1) != at[pin]:
                    wrong.setdefault(pin, (at[pin], (value >> (7 - n)) & 1))
    dut._log.info("%d of %d retained inputs changed after the failure; %d "
                  "reported wrongly", len(changed), len(SNAPSHOT_PINS), len(wrong))
    assert changed, "no retained input changed after the failure, so retention was not tested"
    assert not wrong, (
        "the retained state did not match the state at the first failure: %s"
        % ", ".join("%s was %d, reported %d" % (p, a, r)
                    for p, (a, r) in wrong.items()))


def test_hk_uart_beacon():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_uart_beacon",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
