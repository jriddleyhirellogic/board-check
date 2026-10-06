"""The firmware version, as delivered: HK-TLM-08.

Item: VC-HK-0081.

  HK-TLM-08  The housekeeper shall report a firmware version number to the
             PolarFire.

Criteria: a firmware version number is readable by the PolarFire, and its
value in the delivered build equals the version recorded in the build
manifest. Read from a Libero build (`make inspect-build`), the sources at its
commit, its pinout and the flight schematic.
"""

from __future__ import annotations

import re

from fsverif import design

PORT = "fw_version"


def test_HK_TLM_08_firmware_version_reported(build, board):
    """VC-HK-0081: every bit of the version reaches the PolarFire as an output
    on a housekeeper-to-PolarFire link, and the value the delivered RTL drives
    is the one its manifest records."""
    problems = []
    top = build.source_at_commit("src/top.sv")
    width = re.search(r"output\s+(?:wire|logic)?\s*\[(\d+):(\d+)\]\s*%s\b" % PORT, top)
    if not width:
        problems.append(f"top.sv at {build.commit} has no {PORT} output bus")
        bits = []
    else:
        hi, lo = int(width.group(1)), int(width.group(2))
        bits = [f"{PORT}[{i}]" for i in range(min(hi, lo), max(hi, lo) + 1)]
    pins = design.pin_constraints("fm")
    for bit in bits:
        pin = pins.get(bit)
        if pin is None:
            problems.append(f"{bit} has no pin, so the PolarFire cannot read it")
            continue
        pad = board.net_of("U2", pin.ball)
        nets = design.signal_nets(board, pad) if pad else []
        if not any(n.startswith("PA3_TO_PF") for n in nets):
            problems.append(f"{bit} on {pin.ball} reaches {nets}, not a housekeeper-to-PolarFire link")
    rtl = re.search(r"assign\s+%s\s*=\s*([^;]+);" % PORT,
                    build.source_at_commit("src/health_monitor.sv"))
    recorded = build.manifest.get("firmware_version")
    if recorded is None:
        problems.append("the manifest records no firmware version")
    elif rtl and str(recorded) not in rtl.group(1):
        problems.append(f"the RTL drives {rtl.group(1).strip()}; the manifest records {recorded}")
    assert not problems, "\n  ".join([f"the firmware version is not reported as delivered "
                                      f"({build.name}):"] + problems)
