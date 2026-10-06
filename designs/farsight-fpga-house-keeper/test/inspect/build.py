"""The flight build, as delivered: HK-IMPL-01, -02, -03, -04 and -18.

Items: VC-HK-0009, VC-HK-0010, VC-HK-0011, VC-HK-0012, VC-HK-0013.

  HK-IMPL-01  The housekeeper shall be implemented on a Microsemi
              A3PE3000L-FG484M ProASIC3 device.
  HK-IMPL-02  All sequential logic in the flight build shall be implemented
              with triple modular redundancy.
  HK-IMPL-03  Every state register in the design shall be synthesised with
              safe state encoding.
  HK-IMPL-04  The flight build shall contain no logic, conditional compilation
              or parameter value whose purpose is to support simulation or test.
  HK-IMPL-18  Each programming file shall identify the build variant it was
              produced from, independently of where the file is stored.

Read from a Libero build of the flight variant, `make inspect-build
BUILD=<build dir>`: its synthesis project, report and netlist, its
place-and-route report, the programming image and manifest filed beside it, and
the sources at the commit the build records. Collected only when a build is
given (conftest.py).
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from fsverif import edif

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "script"))
import build_variant  # noqa: E402

DEVICE, PACKAGE, PINS, GRADE = "A3PE3000L", "FG484", "484", "MIL"


def test_HK_IMPL_01_target_device(build):
    """VC-HK-0009: synthesis, place-and-route and the programming file all
    name the A3PE3000L in the 484-ball FBGA at military temperature grade --
    the FG484M."""
    problems = []
    prj = build.synthesis_project
    part = re.search(r"set_option -part (\S+)", prj)
    package = re.search(r"set_option -package (\S+)", prj)
    if not part or part.group(1) != DEVICE:
        problems.append(f"synthesis part {part and part.group(1)}, not {DEVICE}")
    if not package or package.group(1) != f"FBGA{PINS}":
        problems.append(f"synthesis package {package and package.group(1)}, not FBGA{PINS}")
    par = build.place_and_route_report
    die = re.search(r"Die:\s*(\S+)\s+Package:\s*(\d+)\s+(\S+)", par)
    temp = re.search(r"Junction Temperature Range:\s*(\S+)", par)
    if not die or (die.group(1), die.group(2), die.group(3)) != (DEVICE, PINS, "FBGA"):
        problems.append(f"place and route: {die and die.group(0)}, not Die: {DEVICE} Package: {PINS} FBGA")
    if not temp or temp.group(1) != GRADE:
        problems.append(f"place and route temperature range {temp and temp.group(1)}, not {GRADE}")
    header = build.image_member("header.xml")
    field = lambda name: (re.search(rf"<{name}[^>]*>([^<]*)<", header) or [None, None])[1]
    image = (field("extDie"), (field("inPackage") or "").upper(), field("tempGrade"))
    if image != (DEVICE, PACKAGE, GRADE):
        problems.append(f"programming file: die {image[0]}, package {image[1]}, grade {image[2]}; "
                        f"not {DEVICE}, {PACKAGE}, {GRADE}")
    assert not problems, "\n  ".join([f"{build.name} does not target the {DEVICE}-{PACKAGE}M:"] + problems)


#: Sequential primitives of the ProASIC3 library: flip-flops and latches.
SEQUENTIAL = re.compile(r"^(DF|DL)")
VOTER = "MAJ3"
#: Approved exceptions: (cell, instance) -> (approver, date, rationale).
APPROVED = {}


def test_HK_IMPL_02_tmr_on_all_sequential(build):
    """VC-HK-0010: every flip-flop and latch in the synthesised netlist is one
    of three whose outputs meet at one majority voter. Read from the structure,
    not the names: Synplify renames copies inconsistently."""
    netlist = edif.load(build.netlist)
    counts = netlist.instance_counts()
    total, unvoted = 0, {}
    for key, times in counts.items():
        cell = netlist.cells[key]
        flops = {i.name for i in cell.instances.values() if SEQUENTIAL.match(i.cell)}
        if not flops:
            continue
        total += len(flops) * times
        driver = {net: inst for net, pins in cell.nets.items()
                  for inst, port in pins if inst in flops and port == "Q"}
        voted = set()
        for inst in cell.instances.values():
            if inst.cell == VOTER:
                fed = [driver.get(cell.net_of(inst.name, p)) for p in ("A", "B", "C")]
                if all(fed) and len(set(fed)) == 3:
                    voted |= set(fed)
        for name in sorted(flops - voted):
            if (key[1], name) not in APPROVED:
                unvoted.setdefault(key[1], []).append(name)
    assert total, f"no sequential element found in {build.netlist}: the netlist was not read"
    count = sum(len(v) for v in unvoted.values())
    assert not unvoted, "\n  ".join(
        [f"{count} of {total} sequential elements are not voted triplicates:"]
        + [f"{cell}: {', '.join(names[:12])}{' ...' if len(names) > 12 else ''}"
           for cell, names in sorted(unvoted.items())])


_EXTRACTED = re.compile(r"CL201 :(?:\"[^\"]*/)?([\w.]+?)\"?:(\d+):.*?\n\s*Extracted state machine for register (\w+)")
_ENCODING = re.compile(r"^Encoding state machine (\w+)\[[^\]]*\] \(in view: work\.(\S+?)\(", re.M)
_SAFE = re.compile(r"MO195 :.*?syn_encoding = safe.*?enabled for (\w+)\[")
_REMOVED = re.compile(r"BN115 :.*?Removing instance \w+ .*?of type view:work\.(\S+?)\(")
#: A state register in this design's own source: a variable of an enum type.
_ENUM_VAR = re.compile(r"^\s*(\w+_states|boot_states)\s+([\w\s,]+?)(?:/\*|;)", re.M)


def test_HK_IMPL_03_safe_state_encoding(build):
    """VC-HK-0011: every state machine Synplify extracted carries safe
    encoding (MO195: error recovery to the reset state) wherever it was
    encoded, unless its instance was removed as unused; and every state
    register in the source was extracted."""
    srr = build.synthesis_report
    problems = []
    extracted = [(f, int(line), reg) for f, line, reg in _EXTRACTED.findall(srr)]
    removed = set(_REMOVED.findall(srr))
    # Each "Encoding state machine" entry must be followed by its MO195 before
    # the next one; Synplify reports each encoding once per pass.
    marks = list(_ENCODING.finditer(srr)) + [None]
    encoded = {}
    for here, nxt in zip(marks, marks[1:]):
        reg, view = here.group(1), here.group(2)
        span = srr[here.end(): nxt.start() if nxt else len(srr)]
        safe = reg in _SAFE.findall(span)
        encoded.setdefault((reg, view), True)
        encoded[(reg, view)] &= safe
    for (reg, view), safe in sorted(encoded.items()):
        if not safe:
            problems.append(f"{reg} in {view.split('_0s')[0]} is encoded without safe "
                            "recovery: an upset into an unused code has no way out")
    for f, line, reg in extracted:
        stem = Path(f).stem
        if not any(r == reg and stem in v for r, v in encoded):
            if not any(stem in v for v in removed):
                problems.append(f"{reg} ({f}:{line}) was extracted but never encoded")
    for path in build.sources:
        if not path.startswith("src/") or not path.endswith(".sv"):
            continue
        for _, names in _ENUM_VAR.findall(build.source_at_commit(path)):
            for reg in (n.strip() for n in names.split(",") if n.strip()):
                if not any(r == reg and Path(f).stem == Path(path).stem for f, _, r in extracted):
                    problems.append(f"{reg} ({path}) is a state register Synplify did not extract")
    assert extracted, "no state machine in the synthesis report: the report was not read"
    assert not problems, "\n  ".join(["state registers without safe encoding:"] + problems)


#: Conditional-compilation symbols the flight build may test, and why.
ALLOWED_DEFINES = {"TMR": "selects the TMR variant, which the flight build is (HK-IMPL-02)"}
_TEST_HOOKS = re.compile(r"translate_off|synthesis\s+off|pragma\s+translate|synopsys\s+translate",
                         re.I)


def test_HK_IMPL_04_no_test_logic_in_flight(build):
    """VC-HK-0012: the delivered build sets no parameter and no define of its
    own beyond the TMR switch; its sources, at the commit it records, test no
    other compilation symbol and carry no synthesis-excluded test hook."""
    problems = []
    prj = build.synthesis_project
    for option in re.findall(r"set_option\s+-(hdl_param|hdl_define)\b[^\n]*", prj):
        problems.append(f"the synthesis project sets -{option}")
    if not build.manifest.get("tree_clean"):
        problems.append("the manifest records a dirty tree: the build is not its commit")
    defines = set(re.findall(r"`define\s+(\w+)", build_variant.contents(build.variant)))
    for symbol in sorted(defines - set(ALLOWED_DEFINES)):
        problems.append(f"build_variant.vh for {build.variant} defines {symbol}")
    for path in build.sources:
        if path.endswith(".vh"):
            continue                    # generated per variant: checked above
        text = build.source_at_commit(path)
        for n, line in enumerate(text.splitlines(), 1):
            for symbol in re.findall(r"`(?:ifdef|ifndef|elsif)\s+(\w+)", line):
                if symbol not in ALLOWED_DEFINES:
                    problems.append(f"{path}:{n} tests `{symbol}`")
            if _TEST_HOOKS.search(line):
                problems.append(f"{path}:{n} excludes code from synthesis: {line.strip()}")
    assert build.sources, "the synthesis project lists no repository source: it was not read"
    assert not problems, "\n  ".join([f"{build.name} carries test accommodations:"] + problems)


def test_HK_IMPL_18_variant_identifier_in_file(build):
    """VC-HK-0013: the programming file carries a deliberate variant
    identifier -- its silicon signature (USERCODE), readable from the file and
    from a programmed device -- and the manifest records the same one. A path
    that happens to contain the variant is not an identifier."""
    ini = build.image_member("ini.xml")
    signature = (re.search(r"<siliconSignature>([^<]*)</siliconSignature>", ini) or [None, ""])[1]
    problems = []
    if not signature:
        problems.append("the programming file's silicon signature is empty, so nothing in the "
                        "file identifies its variant")
    recorded = build.manifest.get("silicon_signature")
    if signature and recorded != signature:
        problems.append(f"the manifest records signature {recorded!r}, the file carries {signature!r}")
    assert not problems, "\n  ".join([f"{build.manifest.get('image')} does not identify its "
                                      f"variant ({build.variant}):"] + problems)
