"""Analyses of the retained build's reports: clocks, timing, utilisation, CDC.

Each reads Libero's and Synplify's own reports from the newest retained build
(`fsverif.build`), which must be of the current design, and records what it
read with the file and line. Items: VC-PF-0003, -0002, -0005, -0007, -0010,
-0011.
"""

from __future__ import annotations

import collections
import csv
import json
import re
import xml.etree.ElementTree as ET

from fsverif.build import line_of, retained
from fsverif.design import BD, REPO, Value

USER_SDC = REPO / "constr" / "mpf500ts-fc1152m" / "sdc" / "timing_user_constraints.sdc"
SYS_OUT0 = "pll_sys_clk_50mhz_inst/PF_CCC_SYS_CLK_50MHZ_0/pll_inst_0/OUT0"


def _build(r):
    b = retained()
    r.given("Build", b.root.name, "", "commit %s; no design source changed since" % b.commit)
    return b


def _domain_slack(path):
    """Clock domain -> (worst slack, corner), from a multi-corner summary."""
    root = ET.parse(path).getroot()
    sec = next(s for s in root.iter("section")
               if s.find("name") is not None and s.find("name").text == "Summary")
    hdr = [c.text for c in sec.find("table").find("header").iter("cell")]
    out = {}
    for row in sec.find("table").findall("row"):
        c = [x.text for x in row.iter("cell")]
        slack = c[hdr.index("Worst Slack (ns)")]
        if slack not in (None, "", "N/A"):
            out[c[0]] = (float(slack), c[hdr.index("Operating Conditions")])
    return out


def _corners_and_slack(r, b):
    head = json.loads((b.designer / "max_report.json").read_text())["header"]
    corners = head["timing analysis"]["operating conditions"]
    part = head["part"]
    r.given("Corners analysed", ", ".join(corners), "", b.cite(b.designer / "max_report.json"))
    r.given("Range analysed", "%s, %s" % (part["operating range"], part["voltage"]), "",
            b.cite(b.designer / "max_report.json") + ", part")
    setup = _domain_slack(b.designer / "top_max_timing_multi_corner.xml")
    hold = _domain_slack(b.designer / "top_min_timing_multi_corner.xml")
    s_worst = min(setup.items(), key=lambda kv: kv[1][0])
    h_worst = min(hold.items(), key=lambda kv: kv[1][0])
    r.step("Setup, worst per domain over every corner: %d domains with paths, worst %+.3f ns "
           "(%s, %s)" % (len(setup), s_worst[1][0], s_worst[0].split("/")[0], s_worst[1][1]))
    r.step("Hold: %d domains, worst %+.3f ns (%s, %s)" % (len(hold), h_worst[1][0],
                                                        h_worst[0].split("/")[0], h_worst[1][1]))
    coverage = line_of(b.designer / "top_has_violations", r"_timing_constraints_coverage\s+(\S+)")[1].group(1)
    r.given("Paths constrained", coverage, "", b.cite(b.designer / "top_has_violations"))
    negative = [d for d, (s, _) in list(setup.items()) + list(hold.items()) if s < 0]
    return corners, part, negative


# -----------------------------------------------------------------------------

def test_PF_CLK_02_50mhz_control_clock(calc):
    """VC-PF-0003: the 50 MHz board clock, declared, and driving the control plane."""
    r = calc("PF-CLK-02", "the board 50 MHz clock as the control-plane clock")
    b = _build(r)
    ln, m = line_of(USER_SDC, r"create_clock -name \{sys_clk_50mhz\} -period (\S+) \[ get_ports \{ sys_clk_50mhz \} \]")
    period = r.input("Board clock declared", Value(float(m.group(1)), "%s:%d" % (USER_SDC.relative_to(REPO), ln)), "ns")
    sdc = b.designer / "timing_analysis.sdc"
    ln, m = line_of(sdc, r"create_generated_clock -name \{%s\} -divide_by 1 -source \[ get_pins \{ ([^ ]+) \} \]" % re.escape(SYS_OUT0))
    r.given("Control-plane clock", "PLL OUT0, generated from %s, divide by 1" % m.group(1), "", b.cite(sdc, ln))
    top = BD / "top" / "components" / "top.tcl"
    _, buf = line_of(top, r'sd_connect_pins .*\{"sys_clk_50mhz" "(sys_clkint_buf_inst):A" \}')
    ln, m = line_of(top, r'sd_connect_pins .*"pll_sys_clk_50mhz_inst:OUT0_FABCLK_0".*')
    driven = m.group(0)
    users = [u for u in ("focus_mech_inst:sys_clk_50mhz", "pps_hier_inst:sys_clk_50mhz",
                         "interconnect_hier_inst:sys_clk_50mhz") if u in driven]
    r.given("Port to PLL reference", "through %s" % buf.group(1), "", "top.tcl")
    r.given("OUT0 drives", ", ".join(users) + " and the APB peripherals' PCLK", "",
            "%s:%d" % (top.relative_to(REPO), ln))
    ln, m = line_of(b.designer / "clocklist.txt", r'^"%s",([0-9.]+),' % re.escape(SYS_OUT0))
    r.given("OUT0 in the timing analysis", m.group(1), "ns", b.cite(b.designer / "clocklist.txt", ln))
    assert period == 20 and float(m.group(1)) == 20 and len(users) == 3


def test_DRV_PF_10_margin_and_slack(calc):
    """VC-PF-0002: 20% of logic and memory unused, and no negative slack."""
    r = calc("DRV-PF-10", "resource margin and worst-case slack")
    b = _build(r)
    rpt = b.designer / "top_compile_netlist_resources.rpt"
    problems = []
    for kind in ("4LUT", "DFF", "uSRAM", "LSRAM", "Math"):
        ln, m = line_of(rpt, r"^\| %s\s+\| (\d+)\s+\| (\d+)\s+\| ([0-9.]+)" % re.escape(kind))
        used = float(m.group(3))
        r.given("%s used" % kind, "%s of %s, %.2f%%; %.2f%% free" % (m.group(1), m.group(2), used, 100 - used),
                "", b.cite(rpt, ln))
        if 100 - used < 20:
            problems.append("%s %.1f%% free" % (kind, 100 - used))
    _, _, negative = _corners_and_slack(r, b)
    if negative:
        problems.append("negative slack in %s" % ", ".join(negative))
    assert not problems, "; ".join(problems)


def test_DRV_PF_05_worst_case_pvt_closed(calc):
    """VC-PF-0010: closed at the operational range's worst corners, every domain."""
    r = calc("DRV-PF-05", "static timing at the worst-case PVT corners")
    b = _build(r)
    corners, part, negative = _corners_and_slack(r, b)
    r.given("Operational range", "not defined", "", "HW-ENV-01, open")
    r.step("The build is analysed over the part's whole %s range, slow and fast process at low "
           "and high voltage. Whether that range is the operational one, and so whether these "
           "corners are its worst, cannot be shown until HW-ENV-01 defines it" % part["operating range"])
    problems = ["the operational range is not defined (HW-ENV-01), so the report cannot be shown "
                "to name it; the part's range, %s, was analysed" % part["operating range"]]
    if negative:
        problems.append("negative slack in %s" % ", ".join(negative))
    assert not problems, "; ".join(problems)


def _sdc_constraints(r):
    text = USER_SDC.read_text()
    groups = [(text.count("\n", 0, m.start()) + 1, m.group(1))
              for m in re.finditer(r"^set_clock_groups -name \{(\w+)\} -asynchronous -group\s+\[[^\]]*\]\s*$", text, re.M)]
    specific = [(text.count("\n", 0, m.start()) + 1, m.group(0)[:80])
                for m in re.finditer(r"^\s*set_(max_delay|false_path|multicycle_path)\b.*get_(cells|pins).*$", text, re.M)]
    claims = re.findall(r"^#\s+-\s+(.*)$", text[:text.index("# Clocks")], re.M)
    return groups, specific, claims


def _crossings(b):
    path = b.synthesis / "top_cdc.csv"
    with path.open() as f:
        rows = list(csv.DictReader(f))
    return path, rows


def test_DRV_PF_03_specific_crossing_constraints(calc):
    """VC-PF-0007: every asynchronous crossing has a constraint of its own."""
    r = calc("DRV-PF-03", "per-crossing constraints")
    b = _build(r)
    groups, specific, claims = _sdc_constraints(r)
    r.given("The file's account of itself", "; ".join(claims[:3]), "", "%s:4-9" % USER_SDC.relative_to(REPO))
    r.given("Asynchronous clock groups", "%d, each of one clock: %s" % (
        len(groups), ", ".join(n for _, n in groups[:6]) + ", ..."), "",
        "%s:%d-%d" % (USER_SDC.relative_to(REPO), groups[0][0], groups[-1][0]))
    r.given("Constraints naming cells or pins (set_max_delay, set_false_path, set_multicycle_path)",
            len(specific), "", USER_SDC.relative_to(REPO).as_posix())
    path, rows = _crossings(b)
    pairs = collections.Counter((x["START_CLOCK"], x["END_CLOCK"]) for x in rows
                                if x["START_CLOCK"] != x["END_CLOCK"])
    r.given("Crossings between different clocks", "%d, over %d clock pairs" % (sum(pairs.values()), len(pairs)),
            "", b.cite(path))
    r.step("A one-clock asynchronous group makes that clock asynchronous to every other: each "
           "of the %d crossings is discharged by the group, none by a constraint of its own"
           % sum(pairs.values()))
    assert specific, ("%d crossings, every one discharged only by %d blanket asynchronous clock "
                      "groups; no constraint names a crossing" % (sum(pairs.values()), len(groups)))


def test_DRV_PF_02_crossing_means_appropriate(calc):
    """VC-PF-0005: every crossing transferred by means that suit it."""
    r = calc("DRV-PF-02", "CDC crossings classified by means")
    b = _build(r)
    path, rows = _crossings(b)
    cross = [x for x in rows if x["START_CLOCK"] != x["END_CLOCK"]]
    r.given("Crossings, from Synplify's CDC report", len(cross), "", b.cite(path))

    def width(inst):
        m = re.search(r"\[(\d+):(\d+)\]$", inst)
        return abs(int(m.group(1)) - int(m.group(2))) + 1 if m else 1

    unsafe = [x for x in cross if x["SAFE_CDC"].strip().upper() != "YES"]
    bitwise = [x for x in cross if width(x["END_INSTANCE"]) > 1 and x["SYNCHRONIZER"].strip().upper() == "YES"
               and "fifo" not in x["END_INSTANCE"].lower() and "gray" not in x["END_INSTANCE"].lower()]
    kinds = collections.Counter(x["DESCRIPTION"].split(".")[0][:60] for x in unsafe)
    r.step("Reported unsafe: **%d** of %d. By the tool's description: %s"
           % (len(unsafe), len(cross), "; ".join("%d %s" % (n, k) for k, n in kinds.most_common(5))))
    vendor = re.compile(r"ddr4_inst\d|PF_DDR4|COREFIFO|CORETSE|PF_PCIE|pcie_hier_inst\.PF_PCIE|MIV_RV32|"
                        r"COREAXI4|CoreAHBLite|COREAHBTOAPB|CORESPI|CoreGPIO|CORE16550|SLVS_EC|PF_XCVR|COREDDS")
    ours = [x for x in unsafe if not vendor.search(x["END_INSTANCE"] + x["START_INSTANCE"])]
    where = collections.Counter(x["END_INSTANCE"].split(".")[0] for x in ours)
    r.step("Of those, %d are inside Microchip cores (DDR4, FIFOs, MAC, PCIe, processor, "
           "fabric) and **%d** in this design's own logic, by top-level block: %s"
           % (len(unsafe) - len(ours), len(ours), ", ".join("%s %d" % kv for kv in where.most_common(8))))
    r.step("Multi-bit registers synchronised bit by bit (a width over 1 through flip-flop "
           "synchronisers, outside a FIFO): **%d**, e.g. %s"
           % (len(bitwise), ", ".join(x["END_INSTANCE"].split(".")[-1] for x in bitwise[:3])))
    assert not unsafe and not bitwise, ("%d of %d crossings reported unsafe, and %d multi-bit "
                                        "registers synchronised bit by bit" % (len(unsafe), len(cross), len(bitwise)))


def test_DRV_PF_06_source_sync_sta_closed(calc):
    """VC-PF-0011: timing-constrained external interfaces constrained and closed."""
    r = calc("DRV-PF-06", "timing-constrained external interfaces")
    b = _build(r)
    sdc = b.designer / "timing_analysis.sdc"
    text = sdc.read_text()
    pdc = REPO / "constr" / "mpf500ts-fc1152m" / "io" / "io_constraints.pdc"
    interfaces = {"telemetry ADC SPI (ADC128S102)": r"tlm_spi_\w+",
                  "LVDT ADC SPI (ADC128S102)": r"lvdt_adc_spi_\w+",
                  "RGMII (ETH1)": r"eth1_rgmii_\w+(?:\[\d+\])?"}
    problems = []
    for name, pattern in interfaces.items():
        ports = sorted(set(re.findall(r"lappend ports \[list \{(%s)\}" % pattern, pdc.read_text())))
        # A clock input is a clock, not a data port to be timed against one.
        ports = [p for p in ports if not re.search(r"create_clock .*get_ports \{ %s \}" % re.escape(p), text)]
        delayed = [p for p in ports if re.search(r"set_(input|output)_delay .*get_ports \{ %s \}" % re.escape(p), text)]
        false = [p for p in ports if re.search(r"set_false_path -(from|to) \[ get_ports \{ %s \} \]" % re.escape(p), text)]
        timed = [p for p in delayed if p not in false]
        r.given(name, "%d ports; %d with I/O delays, %d of them also false-pathed: %d timed"
                % (len(ports), len(delayed), len([p for p in delayed if p in false]), len(timed)), "",
                "%s; %s" % (pdc.relative_to(REPO), b.cite(sdc)))
        if len(timed) < len(ports):
            problems.append("%s: %d of %d ports timed" % (name, len(timed), len(ports)))
    r.step("The user constraints give every listed port an input or output delay and then, in "
           "the same procedure, a false path, which removes it from timing "
           "(`constr/mpf500ts-fc1152m/sdc/timing_user_constraints.sdc:23-51`, `:238`, `:244`)")
    assert not problems, "; ".join(problems)
