"""Latchup during a boot attempt, its exception, and its hold: HK-SRC-08,
-09 and -10.

Items: VC-HK-0039, VC-HK-0040, VC-HK-0041. Clause: VVP-HK-004.

  HK-SRC-08  A power source shall be declared latched up during a boot
             attempt if its filtered nFAULT input goes low, unless that source
             is configured to ignore nFAULT while booting.
  HK-SRC-09  The step-down 4V0 source shall ignore its nFAULT input while its
             boot attempt is in progress.
  HK-SRC-10  A power source declared latched up shall hold its enable
             deasserted for at least 2 ms before it may be re-enabled.

**"During a boot attempt" is a window the test has to hit.** A source is in
its attempt from its enable rising until its PGOOD rises, which for the
wired-nFAULT rails here is 0.5 to 3 ms (`board/delays.yaml`). So nFAULT is
asserted on the enable's rising edge, and the 5 us filter lands it well
inside the window.

**Latched is the enable falling** within the filter and a few clocks; not
latched is the enable staying up and the source going on to boot.
"""

from __future__ import annotations

import cocotb
from cocotb.triggers import FallingEdge, RisingEdge, SimTimeoutError, with_timeout
from cocotb.utils import get_sim_time

from fsverif import board, boot, sim
from fsverif.clkrst import advance, until
from fsverif.edges import Edges
from fsverif.latchup import LATCH_US, pgood_of
from fsverif.pins import SOFTWARE_REGIONS, boundary

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

CONTROL = {r: ctrl for r, ctrl, _ in SOFTWARE_REGIONS}

#: The one source configured to ignore nFAULT while booting
#: (`pwr_region_step_down_bootseq.sv:133`).
EXEMPT = "step_down_en_4v0"

#: `HK-SRC-08`'s rule, on every wired-nFAULT source that can be reached in
#: its attempt without a boot of its own: DDR8 2V5 is the first hardware
#: source after the exemption, and a latch there is global, so it ends the
#: first boot; the three software sources share the second.
RULE_HARDWARE = "ddr8_en_2v5"
RULE_SOFTWARE = (("imx", "imx_en_1v1"), ("stepper_pri", "stepper_pri_en"),
                 ("stepper_sec", "stepper_sec_en"))

#: How long the exempt source's nFAULT is held low in `HK-SRC-08`: inside its
#: 1.957 ms attempt, and released before its PGOOD rises, so that what
#: follows is an ordinary boot.
PULSE_MS = 0.5

#: `HK-SRC-09`: after the attempt completes, the same nFAULT must latch.
#: The design latches on the first clock of BOOT_SUCCEEDED, because the
#: post-boot ignore window evaluates to zero (`HK-F-09`); the allowance is for
#: that window being fixed, not for the design making up its mind.
AFTER_BOOT_MS = 1.0

#: `HK-SRC-10`. The refused request is the item's; the accepted one is after
#: the realised 2.294 ms hold rather than at 2.1 ms, because the requirement
#: is "at least 2 ms" and a hold that ran to 2.294 ms meets it.
REFUSED_MS = 1.9
ACCEPTED_MS = 3.0
RESPONSE_MS = 0.1


def _now_ms() -> float:
    return get_sim_time("ns") / 1e6


def _high(dut, name: str) -> bool:
    return bool(int(boundary(dut, name).value))


async def _latched(dut, enable: str):
    """Microseconds until `enable` fell, or None if not within LATCH_US."""
    started = _now_ms()
    try:
        await with_timeout(FallingEdge(boundary(dut, enable)),
                           round(LATCH_US * 1000), "ns")
    except SimTimeoutError:
        return None
    return (_now_ms() - started) * 1e3


async def _fault_on_rise(dut, enable: str, timeout_ms: float):
    """Assert `enable`'s nFAULT the moment it rises; return the latch delay."""
    await with_timeout(RisingEdge(boundary(dut, enable)), timeout_ms, "ms")
    board.drive(dut, fault=(pgood_of(enable),))
    return await _latched(dut, enable)


@cocotb.test()
async def test_HK_SRC_08_latchup_during_boot(dut):
    """VC-HK-0039: nFAULT in an attempt latches -- except where exempt."""
    problems = []

    # The exception, then the rule on a hardware source, in one boot.
    board.drive(dut)
    await boot.release(dut)
    await with_timeout(RisingEdge(boundary(dut, EXEMPT)), 1500, "ms")
    board.drive(dut, fault=(pgood_of(EXEMPT),))
    await advance(dut.clk, seconds=PULSE_MS / 1000.0)
    held = _high(dut, EXEMPT)
    board.drive(dut)
    try:
        await with_timeout(RisingEdge(boundary(dut, RULE_HARDWARE)), 20, "ms")
        exempt_booted = _high(dut, EXEMPT)
    except SimTimeoutError:
        exempt_booted = False
    dut._log.info("%s, nFAULT low %.1f ms into its attempt: %s; went on to "
                  "boot: %s", EXEMPT, PULSE_MS, "held" if held else "RELEASED",
                  exempt_booted)
    if not held:
        problems.append("%s latched on nFAULT during its attempt, though it "
                        "is configured to ignore it" % EXEMPT)
    elif not exempt_booted:
        problems.append("%s ignored nFAULT but did not then boot" % EXEMPT)

    board.drive(dut, fault=(pgood_of(RULE_HARDWARE),))
    took = await _latched(dut, RULE_HARDWARE)
    dut._log.info("%s, nFAULT low in its attempt -> %s", RULE_HARDWARE,
                  "latched, %.2f us" % took if took is not None else "NOT LATCHED")
    if took is None:
        problems.append("%s did not latch on nFAULT during its attempt"
                        % RULE_HARDWARE)

    # The rule on the software sources, in a second boot.
    board.drive(dut)
    await boot.hardware(dut)
    for region, enable in RULE_SOFTWARE:
        board.drive(dut)
        boundary(dut, CONTROL[region]).value = 1
        took = await _fault_on_rise(dut, enable, 5.0)
        dut._log.info("%s, nFAULT low in its attempt -> %s", enable,
                      "latched, %.2f us" % took if took is not None
                      else "NOT LATCHED")
        if took is None:
            problems.append("%s did not latch on nFAULT during its attempt"
                            % enable)
        boundary(dut, CONTROL[region]).value = 0
        board.drive(dut)
        await advance(dut.clk, seconds=0.003)

    assert not problems, (
        "nFAULT during a boot attempt was not handled as HK-SRC-08 requires:"
        "\n  " + "\n  ".join(problems))


@cocotb.test()
async def test_HK_SRC_09_stepdown_ignores_nfault(dut):
    """VC-HK-0040: ignored while booting, acted on once booted.

    nFAULT is asserted as the 4V0 enable rises and simply left low. Ignoring
    it means the enable stays up through the attempt; being connected means
    the same low latches the source the moment the attempt completes. A pin
    that was not connected at all would pass the first half and fail the
    second, which is the distinction the item asks for.
    """
    board.drive(dut)
    await boot.release(dut)
    await with_timeout(RisingEdge(boundary(dut, EXEMPT)), 1500, "ms")
    edges = Edges(dut, (EXEMPT, pgood_of(EXEMPT)), origin_ns=0)
    rose = _now_ms()
    board.drive(dut, fault=(pgood_of(EXEMPT),))
    await advance(dut.clk, seconds=0.010)
    edges.stop()

    good = [t for t in edges.rises(pgood_of(EXEMPT)) if t >= rose]
    fell = [t for t in edges.falls(EXEMPT) if t >= rose]
    dut._log.info("%s rose at 0; PGOOD rose at +%s ms; enable fell at +%s ms",
                  EXEMPT, "%.4f" % (good[0] - rose) if good else "never",
                  "%.4f" % (fell[0] - rose) if fell else "never")
    assert good, ("%s's PGOOD never rose, so its attempt never completed and "
                  "the second half cannot be reached" % EXEMPT)
    assert not fell or fell[0] > good[0], (
        "%s fell at +%.4f ms, before its PGOOD rose at +%.4f ms: it latched "
        "on nFAULT during its attempt, which it is configured to ignore"
        % (EXEMPT, fell[0] - rose, good[0] - rose))
    assert fell and fell[0] - good[0] <= AFTER_BOOT_MS, (
        "%s booted with its nFAULT low and was still asserted %.1f ms after "
        "its PGOOD rose, so nFAULT is not acted on after the attempt either -- "
        "not ignored while booting but not connected at all"
        % (EXEMPT, AFTER_BOOT_MS))


@cocotb.test()
async def test_HK_SRC_10_latchup_holdoff_2ms(dut):
    """VC-HK-0041: latched, the enable stays down for at least 2 ms.

    IMX 1V1 latched by its nFAULT, the fault removed at once so that only
    the hold stands in the way. Then a request at 1.9 ms, which must not
    re-enable it, and one at 3.0 ms, which must.
    """
    enable, control = "imx_en_1v1", CONTROL["imx"]
    board.drive(dut)
    await boot.hardware(dut)
    boundary(dut, control).value = 1
    await until(dut.clk, lambda: _high(dut, "imx_status_to_pf"), timeout_s=0.5,
                poll_ms=0.1)
    edges = Edges(dut, (enable,), origin_ns=0)
    board.drive(dut, fault=(pgood_of(enable),))
    took = await _latched(dut, enable)
    assert took is not None, "%s never latched, so there is no hold" % enable
    latched = _now_ms()
    board.drive(dut)
    boundary(dut, control).value = 0

    async def at(ms):
        remaining = latched + ms - _now_ms()
        if remaining > 0:
            await advance(dut.clk, seconds=remaining / 1000.0)

    await at(REFUSED_MS)
    boundary(dut, control).value = 1
    await at(ACCEPTED_MS - 0.5)
    boundary(dut, control).value = 0
    await at(ACCEPTED_MS)
    boundary(dut, control).value = 1
    await at(ACCEPTED_MS + RESPONSE_MS)
    edges.stop()

    rises = [t - latched for t in edges.rises(enable) if t > latched]
    dut._log.info("%s latched; requests at +%.1f and +%.1f ms; it rose at %s",
                  enable, REFUSED_MS, ACCEPTED_MS,
                  ", ".join("+%.4f ms" % t for t in rises) or "never")
    early = [t for t in rises if t < ACCEPTED_MS]
    assert not early, (
        "%s re-asserted at +%.4f ms after latching -- the request at +%.1f ms "
        "was acted on, inside the 2 ms hold" % (enable, early[0], REFUSED_MS))
    assert rises, (
        "%s did not re-assert on a request %.1f ms after latching, past its "
        "hold, so the hold does not end" % (enable, ACCEPTED_MS))


def test_hk_src_latch():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_src_latch",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
