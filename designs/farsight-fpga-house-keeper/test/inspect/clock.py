"""The clock, as built: HK-CLK-01.

Item: VC-HK-0016.

  HK-CLK-01  The housekeeper shall operate from a single 50 MHz free-running
             clock.

Criteria: the constraint file declares exactly one create_clock, at 50 MHz,
and the elaborated design contains no generated clock, no derived clock and no
inferred clock gate. A second clock domain fails even if unused.

Every clocked block in the elaborated design -- vendor UART core included --
has each of its edges followed back through the instance hierarchy to where it
comes from. A clock edge must come from the top-level `clk` unchanged: a
register (a generated clock) or any logic on the way (a derived clock, or a
gate) fails. An asynchronous reset edge must come from the reset input
`arstn` or the reset synchroniser's output register.
"""

from __future__ import annotations

import re

from fsverif import elaborated as E
from fsverif.design import REPO

SDC = REPO / "constr" / "a3pe3000l-fg484m" / "sdc" / "timing_user_constraints.sdc"
CLOCK = ("input", "clk")
#: Where an asynchronous reset may come from: the reset pin, or the reset
#: synchroniser that turns it into a released-synchronously reset.
RESETS = {("input", "arstn"), ("register", "reset_synchronizer.rstn_r10")}


def test_HK_CLK_01_single_free_running_clock(netlist):
    """VC-HK-0016: one create_clock, 20 ns on `clk`; every clocked block in
    the elaborated design clocked by `clk` itself."""
    problems = []
    sdc = re.sub(r"#.*", "", SDC.read_text(encoding="utf-8"))
    clocks = re.findall(r"create_clock\b([^\n]*)", sdc)
    if len(clocks) != 1:
        problems.append(f"{SDC.name}: {len(clocks)} create_clock commands, not one")
    elif not (re.search(r"-period\s+20(\.0+)?\b", clocks[0])
              and re.search(r"get_ports\s*\{\s*clk\s*\}", clocks[0])):
        problems.append(f"{SDC.name}: the clock is not 20 ns on port clk: {clocks[0].strip()}")
    if re.search(r"create_generated_clock", sdc):
        problems.append(f"{SDC.name}: declares a generated clock")

    blocks, edges = 0, {}
    for place in E.places(netlist):
        for block in place.module.always:
            if not block.clocked:
                continue
            blocks += 1
            for edge, signals in block.senses:
                for signal in signals:
                    found = E.origin(netlist, place, signal)
                    if found == CLOCK or found in RESETS:
                        edges.setdefault(found, 0)
                        edges[found] += 1
                        continue
                    kind = {"register": "a generated clock (a register's output)",
                            "logic": "a derived or gated clock"}.get(found[0], found[0])
                    problems.append(f"{place} ({place.module.file.split('/')[-1]}:{block.line}): "
                                    f"{edge.lower()}edge {signal} is {kind}: {found[1]}")
    if not blocks or CLOCK not in edges:
        problems.append("no clocked block found clocked by clk: the design was not read")
    assert not problems, "\n  ".join(["more than one clock, or a clock not from clk:"] + problems)
