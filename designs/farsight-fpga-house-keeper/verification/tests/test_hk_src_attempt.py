"""A source's boot attempt, and its power-down: HK-SRC-03, -04, -05, -11.

Items: VC-HK-0034, VC-HK-0035, VC-HK-0036, VC-HK-0042. Clause: VVP-HK-004.

  HK-SRC-03  A power source enable shall be asserted only after the
             housekeeper has requested that source to boot and no power-down
             is in effect for it.
  HK-SRC-04  A power source enable shall be asserted from the start of its
             boot attempt until the source is powered down, declared failed,
             or declared latched up.
  HK-SRC-05  A power source shall be declared successfully booted only on a
             rising edge of its filtered PGOOD input observed while its
             enable is asserted and its boot attempt is in progress.
  HK-SRC-11  A power source being powered down shall be considered off when
             its filtered PGOOD has gone low, or after at least 2 ms,
             whichever occurs first.

All four are exercised on software regions, whose sources can be requested,
failed, latched and powered down without taking the device with them
(`HK-LAT-05`); what is being tested is the source state machine, which is the
same module for all 33 (`pwr_src_bootseq.sv`).

**Two of these need a PGOOD held high** -- already high when a source is
enabled (`HK-SRC-05`), or high after it is disabled (`HK-SRC-11`). The LT3065
rails do both on their own -- their PGOOD is released, and reads high,
whenever they are disabled (`fsverif.board`) -- but the test holds it with
`rail_force` so that it does not depend on which regulator a rail has.

**"Declared successfully booted" is observed as the next source starting**
(`HK-REG-02`): the region starts each source on its predecessor's success.
"Declared failed" is observed as the enable falling at the 25 ms timeout
(`HK-SRC-06`, 25.231 ms realised), and "considered off" as the region moving
on to the next source in its power-down (`HK-PDN-04`).
"""

from __future__ import annotations

import re

import cocotb
from cocotb.triggers import FallingEdge, RisingEdge, SimTimeoutError, with_timeout
from cocotb.utils import get_sim_time

from fsverif import board, boot, sim
from fsverif.clkrst import advance, until
from fsverif.edges import Edges
from fsverif.pins import SOFTWARE_REGIONS, boundary, device_enables

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

SOFTWARE = {r: enables for r, _, enables in SOFTWARE_REGIONS}
CONTROL = {r: ctrl for r, ctrl, _ in SOFTWARE_REGIONS}

#: `HK-SRC-06`: realised 25.231 ms. A window round it, so that "fell at the
#: timeout" is told apart from "fell for some other reason".
TIMEOUT_MS = (25.0, 25.6)

#: `HK-LAT-01`'s allowance: the 5 us filter, then a few clocks.
REACT_MS = 0.012

#: `HK-IO-05`: the earliest the device can know a PGOOD has changed.
FILTER_MS = 0.005

#: `HK-SRC-11`.
OFF_AFTER_MS = 2.0

STUCK_OFF_MS = (OFF_AFTER_MS, 2.5)


def pgood_of(enable: str) -> str:
    return re.sub(r"_en(_|$)", r"_pgood\1", enable)


def _now_ms() -> float:
    return get_sim_time("ns") / 1e6


def _high(dut, name: str) -> bool:
    return bool(int(boundary(dut, name).value))


async def _up(dut, region: str) -> None:
    boundary(dut, CONTROL[region]).value = 1
    await until(dut.clk, lambda: _high(dut, "%s_status_to_pf" % region),
                timeout_s=0.5, poll_ms=0.1,
                describe=lambda: "%s never reported booted" % region)


async def _watch(dut, names, ms: float, poll_ms: float = 0.5) -> dict:
    """Poll `names` for `ms`; when each was first seen high."""
    seen, start = {}, _now_ms()
    while _now_ms() - start < ms:
        await advance(dut.clk, seconds=poll_ms / 1000.0)
        for n in names:
            if n not in seen and _high(dut, n):
                seen[n] = _now_ms() - start
    return seen


#: `HK-SRC-03`'s withdrawn-in-retry case: past the first source's 25.231 ms
#: timeout, so the region is in its retry hold; then long enough for the
#: 200.540 ms hold to end and the region to leave it.
IN_RETRY_MS = 30.0
AFTER_RETRY_MS = 260.0

HOLD_MIN_MS = 200.0


@cocotb.test()
async def test_HK_SRC_03_enable_needs_request_and_no_pdn(dut):
    """VC-HK-0034: no request, no enable; a power-down in effect, no enable.

    Four states. Hardware up and no software region requested, where every
    software enable must stay low. Eth1 requested, where its first enable
    must assert. IMX requested with its first rail dead, so that it times out
    and enters its retry hold, then withdrawn during the hold -- a power-down
    in effect for the region -- where none of its enables may assert again,
    including on the way out of the hold; after the hold it must still be
    requestable. Withdrawn and requested again during the hold, it must not
    re-enable the failed rail before the hold ends (HK-F-29's disposition).
    And a global power-down latched, then its cause removed, where a fresh
    request must assert nothing.

    The withdrawn-in-hold case is a pulse, not a level, so it is watched on
    edges: a region leaving its retry hold through BOOTING starts the first
    source before it drives that source's power-down.
    """
    software = tuple(e for enables in SOFTWARE.values() for e in enables)
    board.drive(dut)
    await boot.hardware(dut)
    problems = []

    unasked = await _watch(dut, software, 100.0)
    if unasked:
        problems.append("with no software region requested, these enables "
                        "asserted anyway: %s" % ", ".join(
                            "%s at +%.1f ms" % kv for kv in unasked.items()))

    first = SOFTWARE["eth1"][0]
    boundary(dut, CONTROL["eth1"]).value = 1
    try:
        await with_timeout(RisingEdge(boundary(dut, first)), 1, "ms")
    except SimTimeoutError:
        problems.append("Eth1 was requested and %s did not assert within 1 ms"
                        % first)

    board.drive(dut, fail=(pgood_of(SOFTWARE["imx"][0]),))
    boundary(dut, CONTROL["imx"]).value = 1
    await advance(dut.clk, seconds=IN_RETRY_MS / 1000.0)
    boundary(dut, CONTROL["imx"]).value = 0
    withdrawn = _now_ms()
    edges = Edges(dut, SOFTWARE["imx"], origin_ns=0)
    await advance(dut.clk, seconds=AFTER_RETRY_MS / 1000.0)
    edges.stop()
    board.drive(dut)
    pulses = [(e, t - withdrawn, (next((f for f in edges.falls(e) if f >= t), t)
                                  - t) * 1e6)
              for e in SOFTWARE["imx"] for t in edges.rises(e)]
    dut._log.info("IMX withdrawn in its retry hold: %s", "; ".join(
        "%s asserted at +%.4f ms for %.0f ns" % p for p in pulses)
        or "nothing asserted")
    if pulses:
        problems.append("IMX was withdrawn during its retry hold, and as it "
                        "left the hold these enables asserted with the "
                        "power-down in effect: %s. A region leaving its hold "
                        "with a power-down in effect must go to POWER_OFF, "
                        "not through BOOTING, which starts the first source "
                        "before it drives that source's power-down. HK-F-29."
                        % "; ".join("%s at +%.4f ms, %.0f ns wide" % p
                                    for p in pulses))

    first_imx = SOFTWARE["imx"][0]
    boundary(dut, CONTROL["imx"]).value = 1
    try:
        await with_timeout(RisingEdge(boundary(dut, first_imx)), 1, "ms")
    except SimTimeoutError:
        problems.append("IMX, withdrawn during its retry hold and requested "
                        "again after it, did not assert %s within 1 ms -- the "
                        "region did not return to POWER_OFF" % first_imx)
    boundary(dut, CONTROL["imx"]).value = 0
    await advance(dut.clk, seconds=0.015)

    board.drive(dut, fail=(pgood_of(first_imx),))
    boundary(dut, CONTROL["imx"]).value = 1
    await with_timeout(RisingEdge(boundary(dut, first_imx)), 1, "ms")
    await with_timeout(FallingEdge(boundary(dut, first_imx)), 30, "ms")
    failed_at = _now_ms()
    await advance(dut.clk, seconds=0.005)
    boundary(dut, CONTROL["imx"]).value = 0
    await advance(dut.clk, seconds=0.001)
    boundary(dut, CONTROL["imx"]).value = 1
    try:
        await with_timeout(RisingEdge(boundary(dut, first_imx)),
                           AFTER_RETRY_MS, "ms")
        off_for = _now_ms() - failed_at
        dut._log.info("IMX toggled during its retry hold: %s off for %.3f ms",
                      first_imx, off_for)
        if off_for < HOLD_MIN_MS:
            problems.append("IMX, withdrawn and requested again during its "
                            "retry hold, re-enabled %s %.3f ms after it "
                            "failed -- before the %.0f ms hold had ended"
                            % (first_imx, off_for, HOLD_MIN_MS))
    except SimTimeoutError:
        problems.append("IMX, withdrawn and requested again during its retry "
                        "hold, never re-enabled %s" % first_imx)
    board.drive(dut)
    await advance(dut.clk, seconds=0.020)
    boundary(dut, CONTROL["imx"]).value = 0
    await advance(dut.clk, seconds=0.015)

    board.drive(dut, fail=("eps_efuse_pgood",))
    enables = device_enables()
    await until(dut.clk, lambda: not any(_high(dut, e) for e in enables),
                timeout_s=0.05, poll_ms=0.1,
                describe=lambda: "the power-down did not finish")
    board.drive(dut)
    boundary(dut, CONTROL["imx"]).value = 0
    await advance(dut.clk, seconds=0.001)
    boundary(dut, CONTROL["imx"]).value = 1
    latched = await _watch(dut, SOFTWARE["imx"], 50.0, poll_ms=0.1)
    dut._log.info("requested again under a latched power-down: %s",
                  latched or "nothing in 50 ms")
    if latched:
        problems.append("with a power-down latched -- eFuse PGOOD dropped, "
                        "then restored -- a new request for IMX asserted: %s"
                        % ", ".join("%s at +%.1f ms" % kv
                                    for kv in latched.items()))
    assert not problems, (
        "a source enable asserted without a request, or with a power-down in "
        "effect for it:\n  " + "\n  ".join(problems))


@cocotb.test()
async def test_HK_SRC_04_enable_held_through_attempt(dut):
    """VC-HK-0035: the enable is held until whichever ends the attempt.

    Three sources, three endings, in one boot. IMX 3V3 with its rail dead
    ends by being declared failed at the timeout. Stepper Pri with its nFAULT
    asserted as it starts ends by latching. Eth1 1V0, left to boot, ends only
    when Eth1 is powered down. For each the enable must rise once, stay up
    without a gap, and fall at the event that ends it.
    """
    failed, latched, powered = "imx_en_3v3", "stepper_pri_en", "eth1_en_1v0"
    board.drive(dut, fail=(pgood_of(failed),))
    await boot.hardware(dut)
    edges = Edges(dut, (failed, latched, powered), origin_ns=0)

    for region in ("imx", "eth1"):
        boundary(dut, CONTROL[region]).value = 1
    boundary(dut, CONTROL["stepper_pri"]).value = 1
    await with_timeout(RisingEdge(boundary(dut, latched)), 1, "ms")
    board.drive(dut, fail=(pgood_of(failed),), fault=(pgood_of(latched),))
    faulted_at = _now_ms()

    await with_timeout(RisingEdge(boundary(dut, failed)), 50, "ms")
    await advance(dut.clk, seconds=0.030)
    boundary(dut, CONTROL["eth1"]).value = 0
    down_at = _now_ms()
    order = SOFTWARE["eth1"]
    after = len(order) - order.index(powered) - 1
    down_within = after * STUCK_OFF_MS[1] + REACT_MS
    await advance(dut.clk, seconds=(down_within + 1.0) / 1000.0)
    edges.stop()

    problems = []

    def interval(name):
        rises, falls = edges.rises(name), edges.falls(name)
        if not rises or not falls or falls[0] < rises[0]:
            return None
        return rises[0], falls[0]

    for name, ends, check in (
            (failed, "declared failed", lambda r, f: TIMEOUT_MS[0] <= f - r <= TIMEOUT_MS[1]),
            (latched, "declared latched up", lambda r, f: 0 <= f - faulted_at <= REACT_MS),
            (powered, "powered down", lambda r, f: down_at <= f <= down_at + down_within)):
        found = interval(name)
        if found is None:
            problems.append("%s never completed a rise and a fall" % name)
            continue
        rise, fall = found
        dut._log.info("%-15s up %.4f ms, ended by being %s", name, fall - rise, ends)
        if not check(rise, fall):
            problems.append("%s fell %.4f ms after it rose, which is not when "
                            "it was %s" % (name, fall - rise, ends))
    assert not problems, (
        "a source enable was not held for its whole attempt and released at "
        "the event that ended it:\n  " + "\n  ".join(problems))


@cocotb.test()
async def test_HK_SRC_05_boot_success_on_rising_pgood(dut):
    """VC-HK-0036: a rising edge while enabled, and nothing else, succeeds.

    Three regions at once. IMX 1V8 has its PGOOD forced high before it is
    enabled, so it sees a level and no edge. Eth1 1V0A has its rail dead and
    its PGOOD pulsed high and low while it is still off, so the only edge it
    ever sees is one that came before its enable. Eth2 boots normally, the
    control. The first two must time out as failed, and the source after each
    must never start; Eth2 must boot.
    """
    level, early = "imx_en_1v8", "eth1_en_1v0a"
    board.drive(dut, force=(pgood_of(level),))
    await boot.hardware(dut)
    after = {level: "imx_en_2v9", early: "eth1_en_2v5a"}
    edges = Edges(dut, (level, early, after[level], after[early]), origin_ns=0)

    board.drive(dut, force=(pgood_of(level), pgood_of(early)),
                fail=(pgood_of(early),))
    for region in ("imx", "eth1", "eth2"):
        boundary(dut, CONTROL[region]).value = 1
    await advance(dut.clk, seconds=0.0001)
    early_before = _high(dut, early)
    board.drive(dut, force=(pgood_of(level),), fail=(pgood_of(early),))

    await advance(dut.clk, seconds=0.040)
    edges.stop()
    eth2 = _high(dut, "eth2_status_to_pf")

    problems = []
    if early_before:
        problems.append("%s was already enabled when its PGOOD was pulsed, so "
                        "the pulse was not before the enable" % early)
    for name, how in ((level, "a PGOOD already high when it was enabled"),
                      (early, "a PGOOD edge that came before its enable")):
        rises, falls = edges.rises(name), edges.falls(name)
        started = edges.rises(after[name])
        dut._log.info("%s (%s): enabled %s, released %s; %s started %s",
                      name, how, rises, falls, after[name], started or "never")
        if not rises:
            problems.append("%s was never enabled" % name)
        elif started:
            problems.append("%s was declared booted on %s: %s started at %.4f "
                            "ms" % (name, how, after[name], started[0]))
        elif not falls or not TIMEOUT_MS[0] <= falls[0] - rises[0] <= TIMEOUT_MS[1]:
            problems.append("%s was not declared failed at the timeout" % name)
    if not eth2:
        problems.append("Eth2, booting normally as the control, never reported "
                        "booted")
    assert not problems, (
        "success was declared on something other than a rising PGOOD edge "
        "while the source was enabled:\n  " + "\n  ".join(problems))


@cocotb.test()
async def test_HK_SRC_11_powered_down_when_pgood_low_or_2ms(dut):
    """VC-HK-0042: off at PGOOD low, or at 2 ms -- whichever is first.

    Both orderings, on IMX. PGOOD stuck high: 3V3's PGOOD is forced high and
    IMX powered down, and 2V9 -- which may begin only once 3V3 is considered
    off -- must not go for at least 2 ms, and must go once the timeout has
    run rather than stall. That is done twice: long after IMX booted, and
    straight after, and the wait must be the same both times -- the timeout
    runs from the power-down, not from the boot (HK-F-28). PGOOD falling:
    IMX re-booted and powered down normally, and 2V9 must go no sooner than
    the filter after 3V3's PGOOD fell, and no later than 2 ms.
    """
    stuck, nxt = "imx_en_3v3", "imx_en_2v9"
    board.drive(dut)
    await boot.hardware(dut)
    results = {}

    cases = (("PGOOD stuck high", 0.010, True),
             ("PGOOD stuck high, just booted", 0.0, True),
             ("PGOOD falling", 0.010, False))
    for case, up_for_s, force in cases:
        board.drive(dut)
        boundary(dut, CONTROL["imx"]).value = 0
        await advance(dut.clk, seconds=0.003)
        await _up(dut, "imx")
        if up_for_s:
            await advance(dut.clk, seconds=up_for_s)
        board.drive(dut, force=(pgood_of(stuck),) if force else ())
        edges = Edges(dut, (stuck, nxt, pgood_of(stuck)), origin_ns=0)
        boundary(dut, CONTROL["imx"]).value = 0
        await advance(dut.clk, seconds=0.005)
        edges.stop()
        results[case] = (edges.falls(stuck), edges.falls(nxt),
                         edges.falls(pgood_of(stuck)))

    problems, stuck_gaps = [], {}
    for case in ("PGOOD stuck high", "PGOOD stuck high, just booted"):
        off, went, _ = results[case]
        if not off or not went:
            problems.append("%s: %s or %s never fell -- a PGOOD stuck high "
                            "stalled the shutdown" % (case, stuck, nxt))
            continue
        gap = stuck_gaps[case] = went[0] - off[0]
        dut._log.info("%s: %s followed %s by %.4f ms", case, nxt, stuck, gap)
        if gap < STUCK_OFF_MS[0]:
            problems.append("%s: %s began powering down %.2f us after %s, "
                            "which was considered off with its PGOOD still "
                            "high and before %.0f ms"
                            % (case, nxt, gap * 1e3, stuck, OFF_AFTER_MS))
        elif gap > STUCK_OFF_MS[1]:
            problems.append("%s: %s waited %.3f ms after %s with its PGOOD "
                            "stuck high, longer than the %.1f ms the timeout "
                            "allows" % (case, nxt, gap, stuck, STUCK_OFF_MS[1]))
    if len(stuck_gaps) == 2:
        long_up, just_up = stuck_gaps.values()
        if abs(long_up - just_up) > 0.01:
            problems.append("PGOOD stuck high: the wait was %.4f ms long after "
                            "boot and %.4f ms straight after it -- the timeout "
                            "depends on how long the source was up"
                            % (long_up, just_up))
    off, went, pg = results["PGOOD falling"]
    if not off or not went or not pg:
        problems.append("PGOOD falling: something never fell")
    else:
        gap = went[0] - pg[0]
        dut._log.info("PGOOD falling: %s followed %s's PGOOD by %.4f ms",
                      nxt, stuck, gap)
        if gap < FILTER_MS:
            problems.append("PGOOD falling: %s began %.2f us after %s fell, "
                            "sooner than the %.0f us filter lets the device "
                            "know" % (nxt, gap * 1e3, pgood_of(stuck),
                                      FILTER_MS * 1e3))
        elif gap > OFF_AFTER_MS:
            problems.append("PGOOD falling: %s waited %.3f ms after %s fell, "
                            "longer than %.0f ms" % (nxt, gap, pgood_of(stuck),
                                                     OFF_AFTER_MS))
    assert not problems, (
        "a source being powered down was not considered off at whichever came "
        "first of its PGOOD going low and 2 ms:\n  " + "\n  ".join(problems)
        + "\nThe power-down timeout must be counted from when the power-down "
        "began, not from when the source booted (pwr_src_bootseq.sv, "
        "BOOT_SUCCEEDED to POWERING_DOWN). HK-F-28.")


def test_hk_src_attempt():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_src_attempt",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
