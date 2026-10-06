"""Clock-source frequency error and the timing that depends on it.

Items: VC-PF-0008 (DRV-PF-04), VC-PF-0009 (DRV-PF-07), VC-PF-0092 (PF-PPS-09),
VC-PF-0036 (PF-TRIG-12), VC-PF-0129 (PF-TRIG-13), VC-PF-0130 (PF-META-10).

The FPGA's clocks are found in the retained build's constraints and followed
to the board through the pin report and the schematic export; each on-board
source's error is read from its datasheet (`fsverif.oscillators`).

Two inputs are not yet defined, and are stated here as owner decisions of
2026-10-02, TBR:

- **mission life, 5 years**;
- **operating temperature, -55 to +125 C**, the rated range of the flight
  parts;

and one is an owner decision: **the Xsis parts (X35T, XD35T) are the flight
fit**. The schematic places an alternate on every oscillator net; those are
recorded, and budgeted, but not flown.
"""

from __future__ import annotations

import math
import re

from fsverif import board
from fsverif.board import PF
from fsverif.build import retained
from fsverif.design import BD, REPO, core_param, find, instance_param, localparam, stepper_cycles
from fsverif.oscillators import (LIFE_YEARS, RANGE_C, assumptions, budget, oscillator,
                                 oscillators_on, sys_clock_budget)

TOP = BD / "top" / "components" / "top.tcl"
SYS_PLL = BD / "top" / "components" / "PF_CCC_SYS_CLK_50MHZ.tcl"
REQUIREMENTS = REPO / "docs" / "requirements" / "pf-fpga-requirements.md"

#: Clocks that enter from off the board, with the bound their own standard puts on them.
EXTERNAL = {
    "pcie_ext_ref_clk_p": (300, "PCI Express Base Specification, Refclk frequency tolerance "
                                "+/-300 ppm; supplied by the PCIe host"),
    "eth1_rgmii_rxc": (100, "IEEE 802.3 clause 40, 1000BASE-T: 125 MHz +/-100 ppm, recovered "
                            "by the PHY from the link partner"),
}
#: Clocks that are not used to time anything the requirements bound.
EXCLUDED = {"jtag_tck": "test access only; no requirement is timed from it"}


def _primary_clocks(b):
    """[(name, port or pin, line)] from the build's derived constraints."""
    sdc = b.root / "constraint" / "top_derived_constraints.sdc"
    text = sdc.read_text()
    out = []
    for m in re.finditer(r"^create_clock -name \{([^}]+)\} -period ([\d.]+) \[ get_(ports|pins) \{ (\S+) \} \]",
                         text, re.M):
        out.append((m.group(1), float(m.group(2)), m.group(3), m.group(4),
                    "%s:%d" % (sdc.relative_to(REPO), text.count("\n", 0, m.start()) + 1)))
    return out


# ---------------------------------------------------------------------------

def test_DRV_PF_04_frequency_error_budget(calc):
    """VC-PF-0008: every FPGA clock source budgeted over life, worse part where alternates exist."""
    r = calc("DRV-PF-04", "frequency-error budget of every FPGA clock source")
    assumptions(r)
    b = retained()
    r.given("Build", b.root.name, "", "commit %s; no design source changed since" % b.commit)
    sch = board.schematic()
    pins = board.pin_report(b.designer)
    problems = []
    for name, period, kind, target, where in _primary_clocks(b):
        if name in EXCLUDED:
            r.step("`%s` (%s): excluded, %s" % (name, where, EXCLUDED[name]))
            continue
        if kind == "ports":
            pin = pins[target][0]
            net, ys = oscillators_on(sch, pin)
            if ys:
                total = budget(r, sch, ys, "`%s` (%.3f MHz, pin %s)" % (name, 1e3 / period, pin))
                worst = max(oscillator(sch.parts[y][0]).total(LIFE_YEARS) or 0 for y in ys)
                r.step("`%s`: flight **+/-%s ppm**; the worse of every fitted option +/-%.0f ppm"
                       % (name, "%.0f" % total if total is not None else "?", worst))
                if total is None:
                    problems.append("%s: the flight part is not budgeted over the range" % name)
            elif name in EXTERNAL:
                ppm, src = EXTERNAL[name]
                r.given("`%s` (pin %s, net %s)" % (name, pin, net), "+/-%d" % ppm, "ppm", src)
            else:
                problems.append("%s (pin %s, net %s): no oscillator on the board and no bound" % (name, pin, net))
                r.step("`%s` (pin %s, net %s): **no source found**" % (name, pin, net))
        elif "/I_XCVR/LANE" in target:
            if "cam_rx" not in " ".join(problems):
                j = [p for p in sch.reach("IMX_OSC_EN") if p.component.startswith("J")]
                r.step("Camera lane clocks (`%s` and the other lanes): recovered from the sensor's "
                       "serial data, so their source is the sensor's oscillator, which is on the "
                       "camera board -- this board only enables it (`IMX_OSC_EN`, to %s). **No "
                       "part number or figure for it is available here**"
                       % (name, ", ".join("%s pin %s" % (p.component, p.number) for p in j) or "a connector"))
                problems.append("cam_rx lane clocks: the sensor's oscillator, on the camera board, is not budgeted")
        elif "PCIe_TX_PLL" in target:
            r.step("`%s`: the PCIe transmit PLL's output, from the PCIe reference clock (above)" % name)
        elif "PF_OSC" in target or "osc_rc" in name:
            r.step("`%s` (%s): the PolarFire's on-die RC oscillator, clocking the transceivers' "
                   "control logic and the PCIe block's divider. **Its tolerance is in the PolarFire "
                   "datasheet, which is not among the datasheets supplied**" % (name, where))
            problems.append("%s: the PolarFire RC oscillator's tolerance is not available" % name)
        else:
            problems.append("%s (%s): source not classified" % (name, target))
    # Oscillators wired to the PolarFire that no port of this build uses.
    used = {v[0] for v in pins.values()}
    for (comp, num), p in sorted(sch.pins.items()):
        if comp == PF and num not in used and p.net and not board._rail(p.net):
            ys = sorted({q.component for q in sch.reach(p.net) if q.component.startswith("Y")})
            if ys:
                r.step("Pin %s (net %s): %s fitted, used by no clock in this build"
                       % (num, p.net, ", ".join("%s %s" % (y, sch.parts[y][0]) for y in ys)))
    for x in problems:
        r.step("**Not budgeted:** " + x)
    assert not problems, "; ".join(problems)


def test_PF_PPS_09_local_pps_accuracy(calc):
    """VC-PF-0092: the local PPS accuracy over the range and life, and its inputs."""
    r = calc("PF-PPS-09", "local PPS frequency accuracy")
    assumptions(r)
    tcl = BD / "pps_hier" / "components" / "pps_hier.tcl"
    mhz = r.input("Generator's `CLOCK_FREQ_MHZ`", instance_param(tcl, "pps_generator_inst", "CLOCK_FREQ_MHZ"), "MHz")
    r.input("Toggle rule", find(REPO / "ip/pps_ip/src/pps_generator.sv", r"if \(counter == PULSE_WIDTH - 1\)"))
    r.step("The generator counts a fixed %d x 10^6 cycles per period, with no correction, so its "
           "frequency error is its clock's, one for one" % mhz)
    ppm = sys_clock_budget(r)
    us_per_s = ppm
    r.step("Local PPS accuracy: **+/-%.0f ppm**, over %d to %+d C and %d years: +/-%.0f us per "
           "second; free-running, +/-%.2f s per 90-minute orbit and +/-%.1f s per day"
           % (ppm, RANGE_C[0], RANGE_C[1], LIFE_YEARS, us_per_s, ppm * 5400e-6, ppm * 86400e-6))
    r.step("Whether that is good enough is the mission's time-correlation need (open question "
           "Q-06), which this figure does not answer")
    assert ppm is not None


# ---------------------------------------------------------------------------
# Clock-derived timing requirements

TIME_BOUND = re.compile(r"\b\d[\d.,]*\s*(ns|us|µs|ms|s|seconds?|Hz)\b")

#: Requirements whose statement carries a time or frequency that is not a
#: bound derived from a clock source.
NOT_CLOCK_DERIVED = {
    "PF-CLK-02": "accepts a clock; states its nominal frequency, not a timing bound",
    "PF-IO-01": "accepts a clock; states its nominal frequency, not a timing bound",
    "PF-IO-02": "accepts a clock; states its nominal frequency, not a timing bound",
    "PF-PPS-09": "states the accuracy itself (its own analysis)",
}


def _statements():
    text = REQUIREMENTS.read_text()
    text = text[:text.index("## Withdrawn")]
    for m in re.finditer(r"^### (\S+)[^\n]*\n(.*?)(?=^- \*\*)", text, re.M | re.S):
        yield m.group(1), " ".join(m.group(2).split()), text.count("\n", 0, m.start()) + 1


def _focus(which):
    def f(r, mhz, ppm):
        return stepper_cycles(r)[which] / mhz, "min"
    return f


def _gap(r, mhz, ppm):
    udp = r.input("UDP clock, system PLL GL1", core_param(SYS_PLL, "GL1_0_OUT_FREQ"), "MHz")
    cycles = r.input("Default gap", localparam(REPO / "ip/udp_ip/src/udp_tx.sv", "FRAME_GAP_DEFAULT"), "cycles")
    return cycles / udp, "min"


def _dmaw(r, mhz, ppm):
    """Both banks; returns the one furthest from 10 ms."""
    worst = None
    for hier, core in (("ddr4_8gb_hier", "PF_DDR4_C2"), ("ddr4_16gb_hier", "PF_DDR4_C0")):
        tcl = BD / hier / "components" / ("dma_write_%s.tcl" % hier)
        inst = "dma_write_%s_inst" % hier.replace("_hier", "")
        want = r.input("%s: DMA's assumed clock" % hier, instance_param(tcl, inst, "CLOCK_FREQ_MHZ"), "MHz")
        usec = r.input("%s: `TIMEOUT_USEC`" % hier, instance_param(tcl, inst, "TIMEOUT_USEC"), "us")
        user = r.input("%s: user clock" % hier, core_param(BD / hier / "components" / ("%s.tcl" % core), "CLOCK_USER"), "MHz")
        value = want * usec / float(user)
        if worst is None or abs(value - 10_000) > abs(worst - 10_000):
            worst = value
    r.input("DDR4 PLL reference: the 50 MHz system net", find(TOP, r'"ddr4_8gb_group_hier_inst:apb_clk"'))
    return worst, "window"


#: requirement -> (bound, unit, kind, how the nominal is read)
CLOCK_DERIVED = {
    "PF-FOCUS-08": (3.0, "us", _focus("interval")),
    "PF-FOCUS-09": (1.5, "us", _focus("low")),
    "PF-FOCUS-10": (0.3, "us", _focus("setup")),
    "DRV-PF-08": (20.0, "us", _gap),
    "PF-DMAW-09": (10_000.0, "us", _dmaw),
}
#: Clock-derived, with the budget applied elsewhere or not applicable, and why.
APPLIED_ELSEWHERE = {
    "PF-PPS-07": "1 Hz with no tolerance stated; its accuracy is PF-PPS-09's, which states it",
    "PF-TRIG-12": "budgeted per source in its own analysis, with this error",
    "PF-TRIG-13": "budgeted in its own analysis, with this error",
    "PF-META-10": "budgeted in its own analysis, with this error",
    "PF-XCVR-07": "bound in cycles of the 50 MHz clock; a frequency error changes the time, not the count",
}


def test_DRV_PF_07_clock_derived_requirements(calc):
    """VC-PF-0009: every clock-derived timing requirement checked against its source's error."""
    r = calc("DRV-PF-07", "clock-derived timing requirements against the clock budget")
    assumptions(r)
    ppm = sys_clock_budget(r)
    mhz = r.input("System clock", core_param(SYS_PLL, "GL0_0_OUT_FREQ"), "MHz")
    problems, short = [], []
    for req, statement, line in _statements():
        if not TIME_BOUND.search(statement) or req in NOT_CLOCK_DERIVED:
            if req in NOT_CLOCK_DERIVED:
                r.step("%s: not a clock-derived bound -- %s" % (req, NOT_CLOCK_DERIVED[req]))
            continue
        if req in APPLIED_ELSEWHERE:
            r.step("%s: %s" % (req, APPLIED_ELSEWHERE[req]))
            continue
        if req not in CLOCK_DERIVED:
            problems.append("%s (%s:%d) states a time bound and is not budgeted"
                            % (req, REQUIREMENTS.relative_to(REPO), line))
            continue
        bound, unit, nominal = CLOCK_DERIVED[req]
        value, kind = nominal(r, mhz, ppm)
        lo, hi = value * (1 - ppm * 1e-6), value * (1 + ppm * 1e-6)
        if kind == "min":
            margin = lo - bound
            r.step("%s: at least %g %s; nominal %.4f %s, %.4f at -%.0f ppm: margin **%+.4f %s**"
                   % (req, bound, unit, value, unit, lo, ppm, margin, unit))
        else:
            tol = 0.05 * bound
            margin = min(lo - (bound - tol), (bound + tol) - hi)
            r.step("%s: %g %s +/-5%%; nominal %.1f %s, %.1f to %.1f at +/-%.0f ppm: margin **%+.1f %s**"
                   % (req, bound, unit, value, unit, lo, hi, ppm, margin, unit))
        nominal_ok = (value >= bound) if kind == "min" else abs(value - bound) <= 0.05 * bound
        if margin < 0 and nominal_ok:
            r.step("  **%s meets its bound only at the nominal frequency**: the clock error takes "
                   "it below. Recorded against %s" % (req, req))
            short.append(req)
        elif margin < 0:
            r.step("  %s misses its bound at the nominal frequency already; that is its own finding" % req)
    r.step("Budget applied to every clock-derived timing bound in the document. Bounds met only "
           "at the nominal frequency: %s" % (", ".join(short) or "none"))
    for x in problems:
        r.step("**Omitted:** " + x)
    assert not problems, "; ".join(problems)


# ---------------------------------------------------------------------------
# PF-TRIG-12

TRIG = REPO / "ip" / "cam_trig_ip" / "src"


# ---------------------------------------------------------------------------
# The PPS discipline loop, iterated as pps.sv computes it

PPS_SV = REPO / "ip" / "pps_ip" / "src" / "pps.sv"
#: PF-PPS-02's simulation: one 45,000,000-clock period after a nominal start
#: leaves the frequency error at -625,000 (tests/test_pf_pps_discipline.py).
PPS02_PERIOD, PPS02_FREQUENCY_ERROR = 45_000_000, -625_000


def _loop_inputs(r):
    """Record the update equations the loop model follows, each with its line."""
    for label, pattern in (
            ("Edge detected two clocks after it is sampled", r"(pps_in_posedge\s+= pps_in_sync\[2:1\] == 2'b01;)"),
            ("Period measured", r"(last_pps_in_period <= pps_in_cntr \+ 'd1;)"),
            ("Phase error, near side", r"(phase_error\s+<=\s+ticks - pps_rx_delay;)"),
            ("Phase error, far side", r"(phase_error\s+<=\s+ticks - pps_rx_delay - clock_rate;)"),
            ("Exponential average, 1/8 new", r"(intermediate_reg\s+<= ticks_sum - \(ticks_sum >> NUM_SAMPLES_TO_SMOOTH_LOG2\);)"),
            ("Smoothed period", r"(smoothed_pps_in_period <= ticks_sum_nxt >> NUM_SAMPLES_TO_SMOOTH_LOG2;)"),
            ("Frequency error", r"(frequency_error <= smoothed_pps_in_period - clock_rate;)"),
            ("New second length", r"(adjusted_clock_rate = clock_rate \+ phase_error \+ frequency_error;)"),
            ("Clamped to +/-1/8", r"(localparam MAX_CLOCK_RATE\s+= DEFAULT_PPS_PERIOD \+ \(DEFAULT_PPS_PERIOD >> 3\);)"),
            ("The RTC's second ends after clock_rate clocks", r"(end else if\(ticks >= clock_rate - 'd1\) begin)")):
        r.input(label, find(PPS_SV, pattern))


def _discipline(ppm: float, seconds: int, rx_delay: int, n: int = 50_000_000) -> list:
    """Per true second: (error at the true PPS edge, error at the end of the
    RTC's second), in FPGA clocks; positive when the RTC is behind.

    The registers of pps.sv, updated as its always_ff blocks update them, with
    the FPGA clock `ppm` off nominal and the PPS at exact true seconds.
    """
    from fractions import Fraction
    t = Fraction(n) / (1 - Fraction(ppm).limit_denominator(10 ** 6) / 1_000_000)
    clock_rate, ticks_sum = n, n << 3
    rtc_start, prev = 0, None
    out = []
    for k in range(1, seconds + 1):
        c = math.floor(t * k) + 1                # the first clock edge after the PPS edge
        det = c + 2                              # pps_in_sync[2:1] == 01 acted on here
        while rtc_start + clock_rate <= det - 1:
            rtc_start += clock_rate
        ticks = det - 1 - rtc_start

        def wrap(x):                             # the nearer RTC second boundary
            return x - clock_rate if x > clock_rate / 2 else x + clock_rate if x < -clock_rate / 2 else x

        e = wrap(rtc_start - t * k)
        cntr = det - 1 if prev is None else c - prev - 1
        prev = c
        if not (n - (n >> 1) < cntr < n + (n >> 1)):
            out.append((float(e), float(e)))
            continue
        ph = ticks - rx_delay
        if ph > clock_rate >> 1:
            ph -= clock_rate
        ticks_sum = ticks_sum - (ticks_sum >> 3) + cntr + 1
        smoothed = ticks_sum >> 3
        clock_rate = max(n - (n >> 3), min(n + (n >> 3), smoothed + ph))
        if rtc_start + clock_rate <= det + 3:    # the running second is already longer
            rtc_start = det + 4
        out.append((float(e), float(wrap(rtc_start + clock_rate - t * (k + 1)))))
    return out


def _discipline_bound(r, ppm_budget: float, t_ns: float) -> tuple:
    """(worst settled error ns, seconds to settle) over the clock's tolerance."""
    _loop_inputs(r)
    n = 50_000_000
    ts = (7 * n + PPS02_PERIOD) // 8
    check = ts - n
    r.step("Check against the RTL: from a nominal start, one %d-clock period gives a frequency "
           "error of %d by these equations; the simulation of `PF-PPS-02` measured %d "
           "(`verification/tests/test_pf_pps_discipline.py`)" % (PPS02_PERIOD, check, PPS02_FREQUENCY_ERROR))
    assert check == PPS02_FREQUENCY_ERROR, "the loop model disagrees with the RTL's simulation"
    rx = 2
    r.step("Iterated for 300 s with the PPS at exact true seconds, the FPGA clock at each offset "
           "from -%g to +%g ppm, and `pps_rx_delay` %d, the synchroniser's two clocks; firmware "
           "sets it by command (`farsight-avionics-sw/Camera/src/command.c`), and any other value "
           "moves the RTC by the difference, 20 ns a count" % (ppm_budget, ppm_budget, rx))
    offsets = sorted({round(ppm_budget * f / 20, 3) for f in range(-20, 21)} | {-0.3, 0.3, -1, 1})
    worst, settle, start = 0.0, 0, 0.0
    for ppm in offsets:
        errs = _discipline(ppm, 300, rx)
        steady = max(max(abs(a), abs(b)) for a, b in errs[-100:])
        limit = steady + 0.5
        first = next(i + 1 for i in range(len(errs))
                     if all(max(abs(a), abs(b)) <= limit for a, b in errs[i:]))
        worst = max(worst, steady)
        settle = max(settle, first)
        start = max(start, abs(errs[0][0]))
    r.step("Settled, the RTC is within **+/-%.2f clocks (%.0f ns)** of true time across the "
           "second, at every offset. That includes the PPS edge's sampling, up to one clock"
           % (worst, worst * t_ns))
    r.step("Unsettled it is not: from power-up, or after the clock's offset changes, the error "
           "starts at up to **%.0f us** and shrinks by an eighth a second, as the exponential "
           "average catches up -- **%d s** to settle at the edge of the tolerance"
           % (start * t_ns / 1e3, settle))
    return worst * t_ns, settle, start * t_ns


def test_PF_TRIG_12_trigger_timing_budget(calc):
    """VC-PF-0036: each trigger source's edge within 100 ns of its commanded time."""
    r = calc("PF-TRIG-12", "trigger edge against commanded time, per source")
    assumptions(r)
    bound = r.given("Bound", 100, "ns", "PF-TRIG-12, at the FPGA trigger pin")
    ppm = sys_clock_budget(r)
    mhz = r.input("Trigger clock", core_param(SYS_PLL, "GL0_0_OUT_FREQ"), "MHz")
    t = 1e3 / mhz
    # Register stages from the start to the pin, each cited.
    fsm = r.input("Stage: start -> state", find(TRIG / "cam_trig.sv", r"(curr_state <= next_state;)"))
    pin = r.input("Stage: state -> xtrig", find(TRIG / "cam_trig.sv", r"(xtrig\s+<= \(curr_state != XTRIG_LOW_PERIOD\)[^;]*;)"))
    common = 2
    r.step("Common to every source: %d register stages from `start` to `xtrig`, **%d ns**" % (common, common * t))
    problems = []

    reg = r.input("Manual: the START register", find(TRIG / "cam_trig_apb_reg.sv", r"(mem\[ADDR_START\] <= \{31'b0, pwdata\[0\]\};)"))
    out = r.input("Manual: registered to the core", find(TRIG / "cam_trig_apb_reg.sv", r"(start\s+<= mem\[ADDR_START\]\[0\];)"))
    manual = (1 + common) * t
    r.step("**Manual:** from the APB write that commands it, 1 + %d stages = **%d ns**, fixed; "
           "no oscillator term over 3 cycles. Margin %+d ns, before the output path" % (common, manual, bound - manual))

    sync = r.input("LVDS: synchroniser", find(TRIG / "cam_trig_top.sv", r"(lvds_start_sync <= \{lvds_start_sync\[1:0\], lvds_start\};)"))
    edge = r.input("LVDS: edge detect", find(TRIG / "cam_trig_top.sv", r"(start = lvds_start_sync\[1\] && ~lvds_start_sync\[2\];)"))
    lvds_min, lvds_max = (1 + common) * t, (2 + common) * t
    r.step("**LVDS:** the edge is sampled 0-%d ns after it arrives, then 1 more stage to `start` and "
           "%d to the pin: **%d to %d ns**. Margin %+d ns, before the input and output paths"
           % (t, common, lvds_min, lvds_max, bound - lvds_max))

    cmp_ = r.input("Scheduled: compare against the RTC", find(TRIG / "cam_trig_top.sv", r"(\(rtc_nsec >= scheduler_time_nsec\))"))
    tick = r.input("RTC step per clock", find(REPO / "ip/pps_ip/src/pps.sv", r"(nanoseconds\s+<= nanoseconds \+ nanoseconds_per_tick;)"))
    sched = (1 + common) * t + t
    r.step("**Scheduled:** the RTC passes the commanded time in steps of one clock (up to %d ns "
           "late), then 1 + %d stages: **%d to %d ns** after the RTC reads the commanded time" % (
               t, common, (1 + common) * t, sched))
    room = bound - sched
    free = room / (ppm * 1e-6) / 1e6  # ms of free-running before the clock error uses the room
    r.step("The RTC's own error then adds. Free-running -- no external PPS, or the local source "
           "-- it counts nominal nanoseconds on a clock that is off by up to +/-%.0f ppm, so it "
           "drifts %.0f ns per ms since the time was set. The %d ns left is used up **%.2f ms** "
           "after the last time jam: a scheduled trigger more than that after it misses"
           % (ppm, ppm * 1e-3 * 1e3, room, free))
    problems.append("scheduled, free-running: the oscillator's +/-%.0f ppm exceeds the %d ns left "
                    "%.2f ms after the time is set" % (ppm, room, free))
    r.step("With an external PPS the RTC's rate is re-measured every second. Its error is "
           "bounded here by iterating the loop as `pps.sv` computes it, over the clock's "
           "tolerance (worst-case analysis; the PF V&V plan, VVP-PF-005)")
    settled, settle_s, start_ns = _discipline_bound(r, ppm, t)
    total = sched + settled
    r.step("**Scheduled, external PPS, settled:** %d ns of path plus %.0f ns of RTC error: "
           "**%.0f ns**, margin %+.0f ns. The PPS's own accuracy at the FPGA pin is the "
           "source's, and adds" % (sched, settled, total, bound - total))
    if total > bound:
        problems.append("scheduled, external PPS, settled: %.0f ns of path and RTC error" % total)
    problems.append("scheduled, external PPS, for %d s after power-up or a change in the clock's "
                    "offset: up to %.0f us (PF-F-54)" % (settle_s, start_ns / 1e3))
    r.step("Not included anywhere: the input and output paths to the pins, which the build does "
           "not time (`PF-F-46`)")
    assert not problems, "; ".join(problems)


# ---------------------------------------------------------------------------
# PF-TRIG-13, PF-META-10: the end of an exposure

META = REPO / "ip" / "image_metadata_ip" / "src" / "image_metadata_apb_reg.sv"


def test_PF_TRIG_13_exposure_stop_budget(calc):
    """VC-PF-0129: the exposure pulse ends within 100 ns of its commanded duration."""
    r = calc("PF-TRIG-13", "the end of the exposure pulse against its commanded duration")
    assumptions(r)
    bound = r.given("Bound", 100, "ns", "PF-TRIG-13, at the FPGA trigger pin")
    ppm = sys_clock_budget(r)
    mhz = r.input("Trigger clock", core_param(SYS_PLL, "GL0_0_OUT_FREQ"), "MHz")
    t = 1e3 / mhz
    r.input("Duration register, in clock cycles", find(TRIG / "cam_trig.sv", r"(input\s+logic \[27:0\]\s+xtrig_low_time,)"))
    r.input("Counted unconverted", find(TRIG / "cam_trig.sv", r"(assign xtrig_low_cycles\s+= xtrig_low_time_reg;)"))
    r.input("The low state lasts the count", find(TRIG / "cam_trig.sv", r"(if \(timer_cnt >= xtrig_low_cycles-1\) begin\s+next_state = XTRIG_HIGH_PERIOD;)"))
    r.input("Both edges leave through the same register", find(TRIG / "cam_trig.sv", r"(xtrig\s+<= \(curr_state != XTRIG_LOW_PERIOD\)[^;]*;)"))
    r.step("The pulse is exactly the commanded number of %g ns cycles: no quantisation error, "
           "and the start and stop edges share their path to the pin, so its delay cancels" % t)
    longest = (2 ** 28 - 1) * t * 1e-9
    limit = bound * 1e-9 / (ppm * 1e-6)
    r.step("Its length in time is off by the clock's error, +/-%.0f ppm: **+/-%.0f ns per ms** of "
           "exposure. The %d ns bound holds up to **%.3f ms**; at the longest the register "
           "commands, %.2f s, the stop is **+/-%.0f us** off"
           % (ppm, ppm * 1e-3 * 1e3, bound, limit * 1e3, longest, longest * ppm * 1e-6 * 1e6))
    r.step("Not included: the output path to the pin, common to both edges, so it moves the "
           "pulse and not its length")
    assert longest <= limit, ("an exposure longer than %.3f ms ends more than %d ns from its "
                              "commanded duration with the clock +/-%.0f ppm off; the register "
                              "commands up to %.2f s" % (limit * 1e3, bound, ppm, longest))


def test_PF_META_10_exposure_stop_detection(calc):
    """VC-PF-0130: the end of exposure is detected within 100 ns of the sensor's edge."""
    r = calc("PF-META-10", "detecting the sensor's end of exposure")
    assumptions(r)
    bound = r.given("Bound", 100, "ns", "PF-META-10, from the FPGA pin")
    ppm = sys_clock_budget(r)
    mhz = r.input("Metadata clock", core_param(SYS_PLL, "GL0_0_OUT_FREQ"), "MHz")
    r.input("which is the metadata block's `pclk`", find(BD / "cam_rx_hier" / "components" / "cam_rx_hier.tcl", r'"(cam_spi_apb_clk)"[^}]*"image_metadata_top_inst:pclk"|"image_metadata_top_inst:pclk"[^}]*"(cam_spi_apb_clk)"'))
    r.input("and that, the 50 MHz system clock", find(TOP, r'"(cam_rx_inst:cam_spi_apb_clk)"'))
    t = 1e3 / mhz
    r.input("Synchroniser", find(META, r"(cam_tout_sync <= \{cam_tout_sync\[1:0\], cam_tout\};)"))
    r.input("The rise, seen at the second stage", find(META, r"(assign cam_tout_rise = cam_tout_sync\[1\] & ~cam_tout_sync\[2\];)"))
    r.input("Acted on, the exposure latched", find(META, r"(if \(cam_tout_rise\) begin\s+expo_time <=)"))
    first = (0, t)            # the edge waits for the first clock
    soonest, latest = first[0] + 2 * t, first[1] + 2 * t
    late = latest + t         # the first stage resolving metastability the wrong way
    r.step("The edge is sampled 0-%g ns after it arrives, reaches the second stage one clock "
           "later, and is acted on the clock after that: **%g to %g ns**, or **%g ns** when "
           "the first stage resolves late" % (t, soonest, latest, late))
    r.step("The clock's +/-%.0f ppm changes %g ns by %.3f ps" % (ppm, late, late * ppm * 1e-6 * 1e3))
    r.step("Margin %+g ns. Not included: the input path from the pin to the synchroniser, which "
           "the build does not time (`PF-F-46`)" % (bound - late))
    assert late <= bound, "detected up to %g ns after the edge" % late
