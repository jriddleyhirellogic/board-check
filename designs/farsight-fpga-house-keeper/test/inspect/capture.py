"""How inputs are captured, as built: HK-IO-04.

Item: VC-HK-0029.

  HK-IO-04  Every input shall be captured by a means appropriate to its timing
            relationship with the capturing clock.

Criteria: every input port is classified as synchronous or asynchronous to the
housekeeper clock. Each asynchronous input passes through at least two
register stages before any combinational logic reads it; each synchronous
input carries a constrained input delay. An unclassified input fails.

Every input is followed down the elaborated design's hierarchy, through ports
it is wired to unchanged. An asynchronous input must arrive only at the data
input of a synchroniser -- `dff_sync`, or `reset_synchroniser` for the reset --
of at least two stages, and the synchroniser itself is checked: a register
chain with no logic before its last stage. Anything else reading it first is
logic on an unsynchronised signal.
"""

from __future__ import annotations

import re

from fsverif import elaborated as E
from fsverif.design import REPO

SDC = REPO / "constr" / "a3pe3000l-fg484m" / "sdc" / "timing_user_constraints.sdc"

#: Inputs that are not data captured by the housekeeper's clock, and why.
CLOCKS = {"clk": "the clock itself"}
#: Combinationally forwarded rather than captured: the RS-422 pass-through
#: (HK-UART-01). The requirement places them in neither category.
FORWARDED = {"rs422_ttl_bus_to_farsight_pa3": "HK-UART-01",
             "rs422_ttl_farsight_to_bus_pf": "HK-UART-01"}
#: Inputs with a defined phase relationship to clk, which must be constrained
#: (set_input_delay) rather than synchronised. None today.
CONSTRAINED = {}
#: Every other input is asynchronous.

SYNCHRONISERS = {"dff_sync": "d_in", "reset_synchronizer": "arstn"}
MIN_STAGES = 2


def _synchroniser_problem(module) -> str | None:
    """Why a synchroniser module is not a register chain of two or more."""
    stages = module.params.get("NUM_STAGES")
    if stages is None or stages < MIN_STAGES:
        return f"{module.name}: {stages} stage(s), needs {MIN_STAGES} or more"
    data = SYNCHRONISERS[module.base]
    clocked = [b for b in module.always if b.clocked]
    if len(clocked) != 1:
        return f"{module.name}: {len(clocked)} clocked blocks, not one register chain"
    if data in module.ports and any(data in E.refs(b.node) for b in module.always
                                    if not b.clocked and b.keyword != "cont_assign"):
        return f"{module.name}: {data} is read by combinational logic"
    for lhs, rhs in E._cont_assigns(module):
        if data in E.refs(rhs):
            return f"{module.name}: {data} reaches {lhs} without a register"
    return None


def _trace(netlist, place, name, out, depth=0):
    for use in E.uses(netlist, place, name):
        if use[0] == "read":
            out.append(("read", place, use[2]))
            continue
        _, below, _inst, port, wiring = use
        if below.module.base in SYNCHRONISERS and port == SYNCHRONISERS[below.module.base]:
            out.append(("sync" if wiring else "logic-before-sync", below, port))
        elif wiring and depth < 8:
            _trace(netlist, below, port, out, depth + 1)
        else:
            out.append(("logic-before-port", below, port))
    return out


def test_HK_IO_04_inputs_captured_appropriately(netlist):
    """VC-HK-0029: every asynchronous input reaches logic only through a
    synchroniser of two or more stages; every constrained input carries an
    input delay; every input is in one of the classes."""
    top = E.places(netlist)[0]
    inputs = [p for p, d in top.module.ports.items() if d == "INPUT"]
    sdc = SDC.read_text(encoding="utf-8")
    problems, synchronised = [], 0
    checked = set()
    for port in inputs:
        if port in CLOCKS:
            continue
        uses = _trace(netlist, top, port, [])
        if not uses:
            problems.append(f"{port}: reaches nothing")
        if port in FORWARDED:
            clocked = [str(u[1]) for u in uses if u[0] == "read" and
                       any(port in E.refs(b.node) for b in u[1].module.always if b.clocked)]
            if clocked or any(u[0] != "read" for u in uses):
                problems.append(f"{port}: classed as forwarded ({FORWARDED[port]}) but captured")
            continue
        if port in CONSTRAINED:
            if not re.search(r"set_input_delay[^\n]*get_ports\s*\{\s*%s\s*\}" % re.escape(port), sdc):
                problems.append(f"{port}: constrained input with no set_input_delay")
            continue
        for kind, place, where in uses:
            if kind == "sync":
                synchronised += 1
                if place.module.name not in checked:
                    checked.add(place.module.name)
                    bad = _synchroniser_problem(place.module)
                    if bad:
                        problems.append(bad)
            elif kind == "read":
                problems.append(f"{port}: read in {place} ({place.module.file.split('/')[-1]}:{where}) "
                                "before any synchroniser")
            else:
                problems.append(f"{port}: {kind.replace('-', ' ')} {place}.{where}")
    assert synchronised, "no input reached a synchroniser: the design was not read"
    assert not problems, "\n  ".join(["inputs not captured appropriately:"] + problems)
