"""Reset, as built: DRV-HK-05.

Item: VC-HK-0022.

  DRV-HK-05  Every register in the design shall be asynchronously reset to a
             defined state, unless that register is individually recorded as
             an approved exception.

Criteria: every sequential element in the elaborated netlist has an
asynchronous reset connected. Each that does not appears individually in the
approved exception list with a recorded rationale; a blanket exception fails.

A register is asynchronously reset when the block assigning it is sensitive to
a reset edge as well as the clock -- `always_ff @(posedge clk or negedge
arstn)`. Read from the design as Verilator elaborates it, vendor IP included,
once per module however often it is instantiated.
"""

from __future__ import annotations

from fsverif import elaborated as E

CLOCK = ("input", "clk")

#: Approved exceptions: "module.register" -> (approver, date, rationale). A
#: register is excepted individually or not at all.
APPROVED = {}


def test_DRV_HK_05_every_register_async_reset(netlist):
    """VC-HK-0022: every register's block has an asynchronous reset edge, or
    the register is an approved exception."""
    unreset, reset, seen = {}, 0, set()
    for place in E.places(netlist):
        module = place.module
        if module.name in seen:
            continue
        seen.add(module.name)
        for block in module.always:
            if not block.clocked:
                continue
            origins = [E.origin(netlist, place, s) for _, signals in block.senses for s in signals]
            if any(o != CLOCK for o in origins):
                reset += len(block.assigns)
                continue
            for reg in block.assigns:
                if f"{module.base}.{reg}" not in APPROVED:
                    unreset.setdefault(module.base, set()).add((reg, block.line))
    assert reset, "no asynchronously reset register found: the design was not read"
    count = sum(len(v) for v in unreset.values())
    assert not unreset, "\n  ".join(
        [f"{count} registers have no asynchronous reset and no approved exception "
         f"({reset} do have one):"]
        + [f"{m}: " + ", ".join(f"{r} (:{line})" for r, line in sorted(regs))
           for m, regs in sorted(unreset.items())])
