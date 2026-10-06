"""What the housekeeper tells the PolarFire, as built: HK-TLM-04 and -06.

Items: VC-HK-0077, VC-HK-0079.

  HK-TLM-04  The failure metadata outputs shall be sized to the number of
             sources in their region.
  HK-TLM-06  The housekeeper shall report to the PolarFire that it is powered
             and configured.
"""

from __future__ import annotations

import math

from fsverif import design
from fsverif.pins import HARDWARE_REGIONS, SOFTWARE_REGIONS

FPGA, POLARFIRE = "U2", "U1"


def test_HK_TLM_04_metadata_width_matches_sources(board):
    """VC-HK-0077: each region's failure metadata identifies any one of its
    sources and is no wider than that needs. In a software-controlled region
    it also carries whether the failure was a boot failure or a latchup
    (HK-TLM-03), which is one bit more."""
    widths = design.port_widths()
    regions = ([(name, enables, False) for name, enables in HARDWARE_REGIONS]
               + [(name, enables, True) for name, _, enables in SOFTWARE_REGIONS])
    problems, seen = [], 0
    for name, enables, software in regions:
        port = f"{name}_failure_metadata"
        if port not in widths:
            if software:
                problems.append(f"{name}: software-controlled, so HK-TLM-03 needs its failure "
                                f"reported, but there is no {port}")
            continue
        seen += 1
        index = math.ceil(math.log2(len(enables))) if len(enables) > 1 else 0
        needed = index + (1 if software else 0)
        if widths[port] != needed:
            problems.append(f"{port}: {widths[port]} bit(s) for {len(enables)} source(s); needs "
                            f"{needed} ({index} for the source"
                            + (", 1 for boot failure or latchup)" if software else ")"))
    assert seen, "no failure metadata outputs found; the port list was not read"
    assert not problems, "\n  ".join(["failure metadata not sized to its region:"] + problems)


def test_HK_TLM_06_powered_and_configured(board):
    """VC-HK-0079: an output reaches the PolarFire saying the housekeeper is
    powered and configured, and it cannot read asserted before configuration
    completes: driven only by the design, and pulled low until then."""
    port = "pa3_status_to_pf"
    problems = []
    if design.ports().get(port) != "output":
        problems.append(f"top.sv has no output {port}")
    drivers = design.drivers(port)
    if len(drivers) != 1:
        problems.append(f"{port}: {len(drivers)} drivers, not one: {list(map(str, drivers))}")
    for variant in design.PDC:
        pin = design.pin_constraints(variant).get(port)
        if pin is None:
            problems.append(f"{variant}: {port} is not placed")
            continue
        if variant != "fm":
            if pin.pull != "DOWN":
                problems.append(f"{variant}: {port} pull {pin.pull}; before configuration "
                                "nothing holds it low, so the PolarFire can read it asserted")
            continue
        pad = board.net_of(FPGA, pin.ball)
        nets = design.signal_nets(board, pad) if pad else []
        reaches = [(n, p.designator, p.name) for n in nets for p in board.nets[n].pins
                   if p.component.designator == POLARFIRE]
        if not reaches:
            problems.append(f"fm: {port} on {pin.ball} ({' -> '.join(nets) or 'nothing'}) does "
                            "not reach the PolarFire")
        board_pulls = [(r, how) for n in nets for r, how in design.pulls(board, n)]
        if any(how == "up" for _, how in board_pulls):
            problems.append(f"fm: {port} is pulled up on the board ({board_pulls}), so it reads "
                            "asserted before configuration")
        if pin.pull != "DOWN" and not any(how == "down" for _, how in board_pulls):
            problems.append(f"fm: {port} pull {pin.pull} and no pull-down on the board; before "
                            "configuration it floats, so the PolarFire can read it asserted"
                            + (f" (it reaches the PolarFire at {reaches[0][1]})" if reaches else ""))
    assert not problems, "\n  ".join([f"{port} can report the housekeeper configured when it "
                                      "is not:"] + problems)
