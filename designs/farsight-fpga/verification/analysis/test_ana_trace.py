"""Data-path traces, from the SmartDesign's own connections.

Items: VC-PF-0122 (PF-SYS-01), VC-PF-0127 (PF-SYS-02), VC-PF-0128 (PF-SYS-03).
Each trace reads the `sd_connect_pins` statements of the
top-level SmartDesign, the netlist the build composes, and records every
connection it relies on with its line.
"""

from __future__ import annotations

import re

import pytest

from fsverif.design import BD, REPO

TOP = BD / "top" / "components" / "top.tcl"
DDR = ("ddr4_8gb_group_hier_inst", "ddr4_16gb_group_hier_inst")


def _nets():
    """[(line, [instance:pin or port, ...])] for every connection in top.tcl."""
    text = TOP.read_text()
    nets = []
    for m in re.finditer(r"^sd_connect_pins -sd_name \$\{sd_name\} -pin_names \{(.*)\}\s*$", text, re.M):
        pins = re.findall(r'"([^"]+)"', m.group(1))
        nets.append((text.count("\n", 0, m.start()) + 1, pins))
    return nets


def _cite(line):
    return "%s:%d" % (TOP.relative_to(REPO), line)


def _bypasses(r):
    """Every connection by which camera image data reaches export other than
    through the DDR4 groups, with each connection the trace relied on recorded."""
    nets = _nets()
    bypass = []

    # Ingress: wherever the camera receiver's image data leaves it.
    image = re.compile(r"^cam_rx_inst:\w*(cam_data|frame_valid|line_valid|ebd_valid)\w*$")
    for line, pins in nets:
        mine = [p for p in pins if image.match(p)]
        if not mine:
            continue
        others = [p for p in pins if not p.startswith("cam_rx_inst:")]
        to = sorted({p.split(":")[0] for p in others})
        r.given(", ".join(p.split(":")[1] for p in mine), " -> ".join([""] + to)[4:], "", _cite(line))
        data = any("cam_data" in p for p in mine)
        for o in others:
            inst = o.split(":")[0]
            if inst in DDR:
                continue
            if not data and inst == "dbg_mux_inst":
                continue                     # a valid strobe to the debug pins, no pixels
            bypass.append("%s reaches %s (%s)" % (", ".join(mine), o, _cite(line)))

    # Egress: where the image inputs of the Ethernet and PCIe paths come from.
    egress = re.compile(r"^(udp_hier_inst:(S_AXIS_IMG\w*|\w*img_frame\w*)|eth_pcie_mux_hier_inst:AXI4_M_DDR4\w*)$")
    for line, pins in nets:
        mine = [p for p in pins if egress.match(p)]
        if not mine:
            continue
        sources = sorted({p.split(":")[0] for p in pins if not egress.match(p)})
        r.given(", ".join(mine), "from " + ", ".join(sources), "", _cite(line))
        for s in sources:
            if s not in DDR:
                bypass.append("%s is fed from %s (%s)" % (", ".join(mine), s, _cite(line)))
    return bypass


def test_PF_SYS_01_frames_buffered_in_ddr4(calc):
    """VC-PF-0122: camera frames reach Ethernet or PCIe only through DDR4."""
    r = calc("PF-SYS-01", "camera frame data path, ingress to export")
    problems = _bypasses(r)
    r.step("Pixel data leaves the camera receiver only for the two DDR4 groups, and the UDP "
           "and PCIe paths take image data only from them: every exported frame has been "
           "through DDR4" if not problems else "Paths that bypass DDR4: %d" % len(problems))
    assert not problems, "; ".join(problems)


def test_PF_SYS_02_direct_transfer_path(calc):
    """VC-PF-0127: a path from the sensor to export that bypasses DDR4."""
    r = calc("PF-SYS-02", "a direct sensor-to-export path, the frame buffer bypassed")
    bypass = _bypasses(r)
    r.step("Paths around DDR4: %s" % ("; ".join(bypass) if bypass else
                                      "**none** -- every exported frame goes through DDR4"))
    assert bypass, ("no path carries camera data to Ethernet or PCIe export without DDR4, so "
                    "there is no direct transfer to enable (PF-F-01)")


def test_PF_SYS_03_direct_transfer_rate(calc):
    """VC-PF-0128: the direct path carries imagery at the fastest export interface's rate."""
    r = calc("PF-SYS-03", "the rate of a direct sensor-to-export transfer")
    bypass = _bypasses(r)
    assert bypass, ("there is no direct path (PF-SYS-02), so there is no direct-transfer rate "
                    "to budget (PF-F-01)")
    r.step("Direct paths: %s" % "; ".join(bypass))
    pytest.fail("a direct path exists, and its rate against the fastest export interface "
                "is not yet budgeted")
