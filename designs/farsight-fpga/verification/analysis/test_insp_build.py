"""Inspections of the build: target device, reproducibility, the CDC inventory.

Items: VC-PF-0001 (PF-BUILD-06), VC-PF-0071 (PF-VER-02), VC-PF-0006 (DRV-PF-02).
"""

from __future__ import annotations

import collections
import csv
import hashlib
import json
import re
import subprocess

from fsverif import board
from fsverif.build import retained
from fsverif.design import BOARD, REPO, find

PROJ = REPO / "script" / BOARD / "proj_config.tcl"
SYNTH = REPO / "synth.tcl"
PROJ_UTIL = REPO / "script" / "common" / "proj_util.tcl"
VERSION_TEMPLATE = REPO / "ip" / "hw_version_ip" / "template" / "hw_version_apb_reg.sv.template"

#: The part the requirement names (PF-BUILD-06).
REQUIRED = "MPF500TS-FC1152M"
#: PolarFire ordering code: the temperature-grade suffix for each operating range.
GRADE = {"MIL": "M", "IND": "I", "EXT": "E", "COM": "C"}


def test_PF_BUILD_06_targets_mpf500t(calc):
    """VC-PF-0001: the build targets the flight device and package."""
    r = calc("PF-BUILD-06", "target device and package")
    r.given("Required", REQUIRED, "", "PF-BUILD-06")
    die = r.input("Die", find(PROJ, r"set die_name\s+\{(\w+)\}"))
    package = r.input("Package", find(PROJ, r"set die_package\s+\{(\w+)\}"))
    grade = r.input("Range", find(PROJ, r"set die_part_range\s+\{(\w+)\}"))
    r.input("Only supported board", find(SYNTH, r"set supported_targes \[list (\S+)\]"))
    design = "%s-%s%s" % (die, package, GRADE.get(grade, "?"))
    r.step("The project is created for **%s**" % design)
    b = retained()
    part = json.loads((b.designer / "max_report.json").read_text())["header"]["part"]
    r.given("Built for", "%s %s %s, %s" % (part["family"], part["die"], part["package"],
                                           part["operating range"]), "",
            b.cite(b.designer / "max_report.json"))
    sch = board.schematic()
    fitted = sch.parts[board.PF][0]
    r.given("Fitted to the board", fitted, "", "%s, %s part number" % (sch.name, board.PF))
    problems = []
    if (part["die"], part["package"]) != (die, package):
        problems.append("the build is for %s %s, not the project's %s %s"
                        % (part["die"], part["package"], die, package))
    if fitted != design:
        problems.append("the board carries %s, the design targets %s" % (fitted, design))
    if design != REQUIRED:
        problems.append("the design targets %s; PF-BUILD-06 requires %s" % (design, REQUIRED))
    assert not problems, "; ".join(problems)


def test_PF_VER_02_identical_programming_files(calc):
    """VC-PF-0071: two builds of the same source give byte-identical programming files."""
    r = calc("PF-VER-02", "reproducibility of the programming file")
    problems = []
    now = find(SYNTH, r"set current_time\s+(\[clock seconds\])")
    r.input("Build time taken from the wall clock", now)
    passed = find(SYNTH, r"-time_utc (\$current_time)")
    r.input("and passed to the version block", passed)
    slot = find(VERSION_TEMPLATE, r"localparam integer (BUILD_TIME_UTC_SEC)\s*=.*@AUTO UPDATE AT BUILD@")
    r.input("which writes it into the synthesised constant", slot)
    read = find(VERSION_TEMPLATE, r"prdata\s*<=\s*(BUILD_TIME_UTC_SEC);")
    r.input("read back over APB, so it is kept in the netlist", read)
    r.input("The committed copy carries the last build's value",
            find(REPO / "ip" / "hw_version_ip" / "src" / "hw_version_apb_reg.sv",
                 r"BUILD_TIME_UTC_SEC\s*=\s*(32'd\d+)"))
    problems.append("the build writes the wall-clock time (%s, %s) into a synthesised constant "
                    "that firmware reads (%s): two builds a second apart differ"
                    % (now.source, passed.source, read.source))
    name = find(SYNTH, r'set proj_name\s+"(.*formatted_time.*)"')
    r.input("Project name, which also carries the time", name)
    r.step("Whether Libero puts the project name into the programming file is not established "
           "here; the build time above is enough to make the files differ")

    builds = collections.defaultdict(list)
    for d in sorted((REPO / "build").glob("export_%s_*" % BOARD)):
        commit = re.search(r"_([0-9a-f]{8})$", d.name).group(1)
        for f in sorted(d.glob("*.dat")):
            builds[commit].append((d.name, hashlib.sha256(f.read_bytes()).hexdigest()))
    for commit, files in builds.items():
        r.step("Commit %s: %d retained programming file(s): %s"
               % (commit, len(files), "; ".join("%s sha256 %s..." % (n, h[:16]) for n, h in files)))
        if len({h for _, h in files}) > 1:
            problems.append("commit %s has %d different programming files" % (commit, len(files)))
    if not any(len(f) > 1 for f in builds.values()):
        r.step("No commit has two retained programming files, so no byte comparison is possible yet")
    assert not problems, "; ".join(problems)


INVENTORY = re.compile(r"(cdc|crossing)", re.I)
NOT_INVENTORY = re.compile(r"\.(sv|v|vhd|vhdl|tcl|json)$|^ip/|^bd/|^verification/(tests|analysis)/")


def test_DRV_PF_02_crossing_inventory_reviewed(calc):
    """VC-PF-0006: a reviewed inventory of every crossing, with its transfer means."""
    r = calc("DRV-PF-02", "reviewed inventory of the clock-domain crossings")
    b = retained()
    r.given("Build", b.root.name, "", "commit %s; no design source changed since" % b.commit)
    path = b.synthesis / "top_cdc.csv"
    with path.open() as f:
        rows = [x for x in csv.DictReader(f) if x["START_CLOCK"] != x["END_CLOCK"]]
    pairs = collections.Counter((x["START_CLOCK"], x["END_CLOCK"]) for x in rows)
    r.given("Crossings to account for", "%d, between %d pairs of clocks" % (len(rows), len(pairs)), "",
            b.cite(path))
    tracked = subprocess.run(["git", "ls-files"], cwd=REPO, capture_output=True, text=True,
                             check=True).stdout.split()
    candidates = [p for p in tracked if INVENTORY.search(p.rsplit("/", 1)[-1]) and not NOT_INVENTORY.search(p)]
    docs = [p for p in tracked if p.endswith(".md") and p.startswith("docs/")
            and re.search(r"crossing inventory|CDC inventory", (REPO / p).read_text(errors="replace"), re.I)]
    r.step("Tracked files that could be the inventory (named for CDC or crossings, not HDL, "
           "scripts or generated cores), or documents calling themselves one: %s"
           % (", ".join(candidates + docs) or "**none**"))
    covered = []
    for p in candidates + docs:
        text = (REPO / p).read_text(errors="replace")
        reviewed = re.search(r"review", text, re.I)
        named = sum(1 for (a, z) in pairs if a in text and z in text)
        covered.append((p, named, bool(reviewed)))
        r.step("%s: names %d of %d clock pairs; review recorded: %s" % (p, named, len(pairs), bool(reviewed)))
    r.step("Synplify's CDC report lists crossings, but it is the tool's classification, not a "
           "review: it records no chosen means per crossing and no reviewer")
    assert any(n == len(pairs) and rev for _, n, rev in covered), (
        "no reviewed crossing inventory: %d crossings between %d clock pairs are recorded only "
        "in the tool's report" % (len(rows), len(pairs)))


def test_PF_BUILD_23_system_controller_available(calc):
    """VC-PF-0126: the build leaves the system controller available for reprogramming."""
    r = calc("PF-BUILD-23", "the system controller, kept available for in-orbit reprogramming")
    problems = []
    setting = r.input("Project setting", find(PROJ, r"set sys_ctrl_suspend\s+\{SYSTEM_CONTROLLER_SUSPEND_MODE:(\d)\}"))
    passed = find(SYNTH, r'-adv_options\s+"\$(proj::sys_ctrl_suspend)"')
    r.input("Passed to the project by", passed)
    b = retained()
    tools = b.root / "tooldata" / "top_tools.xml"
    m = re.search(r'SYSTEM_CONTROLLER_SUSPEND_MODE="(\d)"', tools.read_text(errors="replace"))
    r.given("As built", m.group(1) if m else "not recorded", "", b.cite(tools))
    if str(setting) != "0":
        problems.append("the project suspends the system controller (SYSTEM_CONTROLLER_SUSPEND_MODE:%s)" % setting)
    if not m or m.group(1) != "0":
        problems.append("the retained build does not record the system controller as available")
    r.step("The system controller is not suspended, in the project or in the build" if not problems
           else "; ".join(problems))
    r.step("The board's SPI_EN strap, which disables every SPI programming route as built, is "
           "HW-IF-12's and HW-F-08's, not this requirement's")
    assert not problems, "; ".join(problems)
