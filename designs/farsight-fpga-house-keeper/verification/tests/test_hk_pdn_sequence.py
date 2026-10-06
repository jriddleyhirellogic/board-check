"""The staged power-down: HK-PDN-02, -03, -04 and -05.

Items: VC-HK-0069, VC-HK-0070, VC-HK-0071, VC-HK-0072. Clause: VVP-HK-004.

  HK-PDN-02  On a global power-down request the housekeeper shall deassert
             the regions' enables in reverse boot order, each stage beginning
             only once every source in the following stage is off: its enable
             deasserted, and its PGOOD low or its power-down timeout elapsed.
  HK-PDN-03  All software-controlled regions shall be powered down
             simultaneously at the start of a global power-down.
  HK-PDN-04  Within a region, source enables shall be deasserted in reverse
             of their boot order, each source beginning only once the source
             after it is off: its PGOOD low or its power-down timeout elapsed.
  HK-PDN-05  The global power-down request, once latched, shall remain
             latched until reset.

Each starts from everything up -- the hardware chain, and every software
region that can be up at once (not Stepper Sec, which a booted Stepper Pri
holds down) -- and then drops the EPS eFuse PGOOD, the route to a power-down
that needs no region to fail first (`HK-PDN-01`). `HK-PDN-02` also runs with
LVDT as the only software region up, so that LVDS has nothing else to wait
for.

**The shutdown is traced in full, but only the shutdown.** Every enable and
PGOOD involved is watched from the trigger until the last enable is down,
about 12 us of simulated time. A watched pin costs on every evaluation, so
the same trace over a boot made an earlier module six times slower
(`fsverif.edges`); over this it costs nothing.

**"Off" is PGOOD low for long enough to be believed, or the power-down
timeout.** The device only acts on a PGOOD that has held for 5 us
(`HK-IO-05`), so a source that begins powering down sooner than that after the
previous source's PGOOD fell cannot have been waiting for it. Where PGOOD does
not fall, the source is off only once its power-down timeout has run
(`HK-SRC-11`, at least 2 ms after its enable fell). That is not a corner case:
the LT3065 rails -- Eth1, Eth2, seven FPGA rails, IMX 1V8, LVDS and LVDT --
release their PGOOD, which then reads high, the moment they are disabled
(`fsverif.board`), and the DDR 0V6 rails self-enable from their region's 2V5
and 1V2 (`HK-F-02`). For all of those the timeout is the only thing that can
space the shutdown.

**"Simultaneously" is read as beginning together.** `HK-PDN-03`'s item says
every software region's enables deassert "on the same clock", but
`HK-PDN-04` requires each region's own sources to go one after another. The
two are consistent only if what is simultaneous is each region's *start*:
the first enable of every software region falls on one clock, and all of
them are down before the first hardware stage begins.
"""

from __future__ import annotations

import re

import cocotb
from cocotb.triggers import RisingEdge, with_timeout
from cocotb.utils import get_sim_time

from fsverif import board, boot, sim
from fsverif.clkrst import advance, until
from fsverif.edges import Edges
from fsverif.pins import (CONTROL_INPUTS, HARDWARE_REGIONS, SOFTWARE_REGIONS,
                          boundary, device_enables)

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

TRIGGER = "eps_efuse_pgood"

#: Software regions requested before the power-down.
REQUESTED = ("imx", "lvdt", "eth1", "eth2", "stepper_pri")
SOFTWARE = {r: enables for r, _, enables in SOFTWARE_REGIONS}
CONTROL = {r: ctrl for r, ctrl, _ in SOFTWARE_REGIONS}

#: `HK-PDN-02`: software regions, then LVDS, FPGA, DDR16, DDR8, Step Down --
#: the reverse of `HK-SEQ-02`. Written out rather than reversed from
#: `pins.HARDWARE_REGIONS`, so that the order is stated rather than derived
#: from something that could itself be wrong.
HARDWARE_STAGES = ("lvds", "fpga", "ddr16", "ddr8", "step_down")
HARDWARE = dict(HARDWARE_REGIONS)

#: `HK-SRC-11`: a source being powered down is off after at least this long,
#: whatever its PGOOD. The design's timeout is 2.294 ms.
OFF_TIMEOUT_MS = 2.0

#: `HK-PDN-05`.
HOLD_S = 1.2
POLL_MS = 0.1
REBOOT_TIMEOUT_S = 1.2


#: `HK-IO-05`: a PGOOD is believed only once it has held for 5 us. A source
#: that begins powering down sooner than this after the previous one's PGOOD
#: fell at the pin cannot have been waiting for it -- the device did not yet
#: know. Without this the check would pass by construction: a modelled PGOOD
#: falls in the same cycle as its enable, so "low at the pin" is true at once
#: whether or not the design waited.
FILTER_MS = 0.005


def pgood_of(enable: str) -> str:
    return re.sub(r"_en(_|$)", r"_pgood\1", enable)


def _now_ms() -> float:
    return get_sim_time("ns") / 1e6


def _high(dut, name: str) -> bool:
    return bool(int(boundary(dut, name).value))


async def _everything_up(dut, requested=REQUESTED) -> None:
    dut.rail_fail.value = 0
    dut.rail_fault.value = 0
    await boot.hardware(dut)
    for region in requested:
        boundary(dut, CONTROL[region]).value = 1
    statuses = ["%s_status_to_pf" % r for r in requested]
    await until(dut.clk, lambda: all(_high(dut, s) for s in statuses),
                timeout_s=1.0, describe=lambda: "not booted: %s" % ", ".join(
                    s for s in statuses if not _high(dut, s)))


def _trigger(dut) -> float:
    dut.rail_fail.value = 1 << board.index(board.model())[TRIGGER]
    return _now_ms()


def _trace_names(requested=REQUESTED) -> tuple:
    enables = tuple(e for r in requested for e in SOFTWARE[r])
    enables += tuple(e for s in HARDWARE_STAGES for e in HARDWARE[s])
    return enables + tuple(pgood_of(e) for e in enables)


async def _power_down(dut, requested=REQUESTED) -> dict:
    """Bring everything up, drop the eFuse PGOOD, and trace the shutdown.

    Every enable and PGOOD involved is watched, but only from the trigger to
    the end of the shutdown -- about 12 us of simulated time. The cost of a
    watched pin is per evaluation, so watching 60 of them over a boot is what
    made an earlier module six times slower, and watching them over this is
    nothing.
    """
    await _everything_up(dut, requested)
    names = _trace_names(requested)
    up = {n for n in names if _high(dut, n)}
    edges = Edges(dut, names, origin_ns=0)
    triggered = _trigger(dut)
    enables = [n for n in names if "_en" in n and "_pgood" not in n]
    # Long enough for a correct shutdown: every LT3065 source waits out its
    # 2.294 ms timeout in turn.
    await until(dut.clk, lambda: not any(_high(dut, e) for e in enables),
                timeout_s=0.5, poll_ms=0.01,
                describe=lambda: "the power-down did not finish; still up: %s"
                % ", ".join(e for e in enables if _high(dut, e)))
    await advance(dut.clk, seconds=0.001)
    edges.stop()

    def fell(name):
        """When `name` first fell after the trigger; -inf if it was never up,
        None if it is still up."""
        if name not in up:
            return float("-inf")
        falls = [t for t in edges.falls(name) if t >= triggered]
        return falls[0] if falls else None

    record = {"triggered": triggered, "fell": fell, "regions": {},
              "requested": tuple(requested)}
    for region in list(requested) + list(HARDWARE_STAGES):
        order = (SOFTWARE.get(region) or HARDWARE[region])[::-1]
        record["regions"][region] = order
        dut._log.info("%-11s %s", region, " -> ".join(
            "%s %.4f" % (e.rsplit("_en", 1)[-1].lstrip("_") or e,
                         (fell(e) or 0) - triggered) for e in order))
    return record


def _off_at(record, enable):
    """When the source behind `enable` is off (`HK-SRC-11`): its PGOOD low
    for long enough to be believed, or its power-down timeout run --
    whichever is first. -inf for a source that was never up."""
    fell = record["fell"]
    went = fell(enable)
    if went == float("-inf"):
        return float("-inf")
    if went is None:
        return None
    rail_fell = fell(pgood_of(enable))
    by_pgood = rail_fell + FILTER_MS if rail_fell is not None and rail_fell != float("-inf") \
        else float("inf")
    return min(by_pgood, went + OFF_TIMEOUT_MS)


def _how(record, enable) -> str:
    rail_fell = record["fell"](pgood_of(enable))
    return ("its PGOOD fell at %.4f ms" % rail_fell) if rail_fell not in (None, float("-inf")) \
        else "its PGOOD never fell"


def _within(record, region) -> list:
    """`HK-PDN-04` for one region: reverse order, each source beginning only
    once the source after it is off."""
    fell, order, problems = record["fell"], record["regions"][region], []
    for before, enable in zip(order, order[1:]):
        t, prev, off = fell(enable), fell(before), _off_at(record, before)
        if t is None:
            problems.append("%s: %s never deasserted" % (region, enable))
        elif prev is None or t <= prev:
            problems.append("%s: %s deasserted at %.4f ms, not after %s"
                            % (region, enable, t, before))
        elif off is not None and t < off:
            problems.append("%s: %s deasserted %.4f ms after %s, before that "
                            "source was off -- %s, and its %g ms timeout had "
                            "not run" % (region, enable, t - prev, before,
                                         _how(record, before), OFF_TIMEOUT_MS))
    return problems


def _stage_gate(record, stage, previous) -> list:
    """`HK-PDN-02` for one stage: it begins only once every source of the
    stage before is off."""
    fell = record["fell"]
    start = fell(record["regions"][stage][0])
    if start is None:
        return ["%s never began" % stage]
    early = []
    for r in previous:
        for e in record["regions"][r]:
            off = _off_at(record, e)
            if off is None or start < off:
                early.append("%s (%s)" % (e, _how(record, e)))
    if early:
        return ["%s began at %.4f ms, before these sources of the stage "
                "before it were off: %s" % (stage, start, ", ".join(early))]
    return []


#: What each hardware stage waits for: the stage that goes down before it.
PREVIOUS = {"lvds": REQUESTED, "fpga": ("lvds",), "ddr16": ("fpga",),
            "ddr8": ("ddr16",), "step_down": ("ddr8",)}


@cocotb.test()
async def test_HK_PDN_02_reverse_boot_order(dut):
    """VC-HK-0069: stage by stage, each after the one before is off.

    Twice: with every software region that can be up at once, and with LVDT
    alone. The first is dominated by Eth1 and Eth2, the slowest to power
    down, so a stage gate that missed any other software region would still
    pass it; LVDT alone is the case in which LVDS has only LVDT to wait for.
    """
    problems = []
    for label, requested in (("every software region", REQUESTED),
                             ("LVDT alone", ("lvdt",))):
        record = await _power_down(dut, requested)
        fell = record["fell"]
        previous = dict(PREVIOUS, lvds=record["requested"])
        found = [p for s in HARDWARE_STAGES
                 for p in _stage_gate(record, s, previous[s])]
        starts = [(s, fell(record["regions"][s][0])) for s in HARDWARE_STAGES]
        for (a, ta), (b, tb) in zip(starts, starts[1:]):
            if ta is not None and tb is not None and tb <= ta:
                found.append("%s began at %.4f ms, not after %s at %.4f ms"
                             % (b, tb, a, ta))
        problems += ["%s: %s" % (label, p) for p in found]
    assert not problems, (
        "the power-down did not go stage by stage in reverse boot order, each "
        "stage after the one before it was off:\n  "
        + "\n  ".join(problems) + "\n" + CAUSE)


@cocotb.test()
async def test_HK_PDN_03_sw_regions_simultaneous(dut):
    """VC-HK-0070: every software region starts down on one clock."""
    record = await _power_down(dut)
    fell = record["fell"]
    starts = {r: fell(record["regions"][r][0]) for r in REQUESTED}
    never = [r for r, t in starts.items() if t is None]
    assert not never, "these software regions never powered down: %s" % (
        ", ".join(never))

    spread_ns = (max(starts.values()) - min(starts.values())) * 1e6
    dut._log.info("software regions began %.4f ms after the trigger, spread "
                  "%.0f ns", min(starts.values()) - record["triggered"],
                  spread_ns)
    assert spread_ns == 0, (
        "the software regions did not begin powering down on the same clock: "
        "%s" % ", ".join("%s at %.6f ms" % kv for kv in sorted(
            starts.items(), key=lambda kv: kv[1])))
    last_software = max(fell(e) for r in REQUESTED for e in record["regions"][r])
    first_hardware = fell(record["regions"]["lvds"][0])
    assert first_hardware is not None and first_hardware > last_software, (
        "the first hardware stage began at %s ms, not after the last software "
        "enable fell at %.4f ms" % (first_hardware, last_software))


@cocotb.test()
async def test_HK_PDN_04_source_reverse_within_region(dut):
    """VC-HK-0071: within each region, last booted first off, one at a time."""
    record = await _power_down(dut)
    problems = [p for r in record["regions"] for p in _within(record, r)]
    assert not problems, (
        "sources did not power down in reverse boot order, each after the "
        "source after it was off:\n  " + "\n  ".join(problems)
        + "\n" + CAUSE)


#: What the failures of HK-PDN-02 and -04 have in common, stated once.
CAUSE = (
    "A stage or source that begins early has not waited for the one before "
    "it to be off: its PGOOD low for the 5 us filter, or its power-down "
    "timeout run (HK-SRC-11). Each hardware stage waits on the regions named "
    "in its gate in health_monitor.sv; each source on its successor's "
    "POWERING_DOWN in pwr_src_bootseq.sv. HK-F-28 and HK-F-33 are of this "
    "kind.")



def _fall_times(edges, up, since):
    def fell(name):
        if name not in up:
            return float("-inf")
        falls = [t for t in edges.falls(name) if t >= since]
        return falls[0] if falls else None
    return fell


def _off_when(fell, enable):
    """When a source counts as off for the one below it to begin: its PGOOD
    fallen and held low past the filter, or its timeout run (`HK-SRC-11`). A
    source still booting has no PGOOD to fall -- it never rose -- so only its
    timeout makes it off."""
    went = fell(enable)
    if went in (None, float("-inf")):
        return went
    rail = fell(pgood_of(enable))
    by_pgood = rail + FILTER_MS if rail not in (None, float("-inf")) else float("inf")
    return min(by_pgood, went + OFF_TIMEOUT_MS)


def _reverse_problems(fell, region, order) -> list:
    problems = []
    for before, enable in zip(order, order[1:]):
        t, prev = fell(enable), fell(before)
        if t == float("-inf"):
            continue
        if t is None:
            problems.append("%s: %s never deasserted" % (region, enable))
        elif prev is None or (prev != float("-inf") and t <= prev):
            problems.append("%s: %s deasserted at %.4f ms, not after %s"
                            % (region, enable, t, before))
        else:
            off = _off_when(fell, before)
            if off is not None and t < off:
                problems.append("%s: %s deasserted %.4f ms after %s, before "
                                "that source was off" % (region, enable,
                                                         t - prev, before))
    return problems


@cocotb.test()
async def test_HK_PDN_04_reverse_when_withdrawn_mid_boot(dut):
    """VC-HK-0117: a region powered down part-way through its boot.

    IMX requested with 3V3, its last source, held without PGOOD: 1V1, 1V8
    and 2V9 boot, and 3V3 is left enabled and booting. IMX is then withdrawn.
    Its sources must still go down in reverse, each only once the one after
    it is off -- 3V3 included, which never had a PGOOD to lose and so is off
    only once its timeout has run.
    """
    order = SOFTWARE["imx"][::-1]
    booting = order[0]
    board.drive(dut, fail=(pgood_of(booting),))
    await boot.hardware(dut)
    boundary(dut, CONTROL["imx"]).value = 1
    await with_timeout(RisingEdge(boundary(dut, booting)), 50, "ms")
    await advance(dut.clk, seconds=0.002)

    names = order + tuple(pgood_of(e) for e in order)
    up = {n for n in names if _high(dut, n)}
    edges = Edges(dut, names, origin_ns=0)
    withdrawn = _now_ms()
    boundary(dut, CONTROL["imx"]).value = 0
    await until(dut.clk, lambda: not any(_high(dut, e) for e in order),
                timeout_s=0.05, poll_ms=0.01,
                describe=lambda: "IMX did not power down")
    await advance(dut.clk, seconds=0.001)
    edges.stop()
    board.drive(dut)

    fell = _fall_times(edges, up, withdrawn)
    dut._log.info("IMX withdrawn mid-boot: %s", " -> ".join(
        "%s %.4f" % (e, (fell(e) or 0) - withdrawn) for e in order))
    problems = _reverse_problems(fell, "imx", order)
    assert not problems, (
        "IMX, withdrawn while %s was still booting, did not power down in "
        "reverse order, each source after the one after it was off:\n  " % booting + "\n  ".join(problems) + "\n" + MID_BOOT_CAUSE)


@cocotb.test()
async def test_HK_PDN_02_stage_waits_for_region_mid_boot(dut):
    """VC-HK-0118: a global power-down that arrives while a hardware region
    is booting.

    DDR8 with 1V2 held without PGOOD: 2V5 boots, and 1V2 is left enabled and
    booting. The eFuse PGOOD is then dropped. DDR8 must go down in reverse,
    1V2 off only once its timeout has run, and step-down, the stage after it,
    must begin only once every DDR8 source is off.
    """
    order = HARDWARE["ddr8"][::-1]
    booting = "ddr8_en_1v2"
    after = HARDWARE["step_down"][::-1]
    board.drive(dut, fail=(pgood_of(booting),))
    await boot.release(dut)
    await with_timeout(RisingEdge(boundary(dut, booting)), 1500, "ms")
    await advance(dut.clk, seconds=0.002)

    enables = order + after
    names = enables + tuple(pgood_of(e) for e in enables)
    up = {n for n in names if _high(dut, n)}
    edges = Edges(dut, names, origin_ns=0)
    board.drive(dut, fail=(pgood_of(booting), TRIGGER))
    triggered = _now_ms()
    await until(dut.clk, lambda: not any(_high(dut, e) for e in enables),
                timeout_s=0.05, poll_ms=0.01,
                describe=lambda: "the power-down did not finish")
    await advance(dut.clk, seconds=0.001)
    edges.stop()
    board.drive(dut)

    fell = _fall_times(edges, up, triggered)
    for region, seq in (("ddr8", order), ("step_down", after)):
        dut._log.info("%-9s %s", region, " -> ".join(
            "%s %.4f" % (e, (fell(e) or 0) - triggered) for e in seq))
    problems = _reverse_problems(fell, "ddr8", order)
    problems += _reverse_problems(fell, "step_down", after)
    start = fell(after[0])
    if start is None:
        problems.append("step_down never began")
    else:
        early = [e for e in order
                 if _off_when(fell, e) is None or start < _off_when(fell, e)]
        if early:
            problems.append("step_down began at %.4f ms, before these DDR8 "
                            "sources were off: %s"
                            % (start - triggered, ", ".join(early)))
    assert not problems, (
        "a global power-down arriving while DDR8 was booting did not go "
        "stage by stage, each stage after the one before it was off:\n  "
        + "\n  ".join(problems) + "\n" + MID_BOOT_CAUSE)


MID_BOOT_CAUSE = (
    "A region told to power down while booting must go through "
    "POWERING_DOWN in pwr_region_sm.sv, its sources in reverse; a source "
    "still booting waits out its timeout in pwr_src_bootseq.sv; and each "
    "stage gate in health_monitor.sv waits on the region before it having "
    "every source in POWER_OFF (srcs_off). HK-F-32 was of this kind.")

@cocotb.test()
async def test_HK_PDN_05_latched_until_reset(dut):
    """VC-HK-0072: with the eFuse restored, nothing comes back until reset.

    Nothing coming back is a real test here, not an absence of stimulus:
    the step-down region's start request stays asserted after the first
    boot (`health_monitor.sv:518`), so a power-down request that cleared
    would let it boot again on the next clock.
    """
    await _everything_up(dut)
    _trigger(dut)
    enables = device_enables()
    await until(dut.clk, lambda: not any(_high(dut, e) for e in enables),
                timeout_s=0.1, poll_ms=0.1,
                describe=lambda: "the power-down did not finish; still up: %s"
                % ", ".join(e for e in enables if _high(dut, e)))

    dut.rail_fail.value = 0
    start = _now_ms()
    seen, toggled = {}, []
    for at, level in ((5.0, 0), (10.0, 1), (300.0, 0), (305.0, 1)):
        toggled.append((at, level))
    while _now_ms() - start < HOLD_S * 1000.0:
        while toggled and _now_ms() - start >= toggled[0][0]:
            level = toggled.pop(0)[1]
            for name in CONTROL_INPUTS:
                boundary(dut, name).value = level
        await advance(dut.clk, seconds=POLL_MS / 1000.0)
        for e in enables:
            if _high(dut, e):
                seen.setdefault(e, _now_ms() - start)
    dut._log.info("eFuse PGOOD restored; every control toggled at +5/+10 and "
                  "+300/+305 ms; %d enables asserted in %.1f s", len(seen), HOLD_S)
    assert not seen, (
        "the power-down request did not stay latched: with the eFuse PGOOD "
        "restored, these enables asserted without a reset: %s" % ", ".join(
            "%s at +%.1f ms" % kv for kv in sorted(seen.items(),
                                                   key=lambda kv: kv[1])))

    await boot.release(dut)
    released = _now_ms()
    first = boot.HARDWARE_ENABLES[0]
    try:
        await until(dut.clk, lambda: _high(dut, first), timeout_s=REBOOT_TIMEOUT_S)
    except TimeoutError:
        raise AssertionError("after arstn, %s had not asserted within %.1f s, "
                             "so reset did not clear the power-down request"
                             % (first, REBOOT_TIMEOUT_S)) from None
    dut._log.info("after arstn, %s asserted %.1f ms after release", first,
                  _now_ms() - released)


def test_hk_pdn_sequence():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_pdn_sequence",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
