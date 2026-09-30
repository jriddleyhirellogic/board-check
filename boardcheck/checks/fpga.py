"""FPGA pin configuration against the schematic.

The FPGA constraint files (see boardcheck/fpga.py) say what each FPGA pin is
configured as; the schematic says what it is wired to. These checks join the
two: constrained pins that are not I/O on the board, banks whose I/O voltage
disagrees with the rail feeding them, and wired I/O the constraints leave
unassigned.
"""

from . import ERROR, WARNING, Finding, check
from ..model import natural_key

_TOLERANCE = 0.02   # fractional difference allowed between a bank VCCI and its rail


def _fpgas(ctx):
    for desig in sorted(ctx.fpgas, key=natural_key):
        f = ctx.fpga_for(ctx.design.components.get(desig)) if desig in ctx.design.components else None
        if f is not None:
            yield desig, f


@check("FIO001", "FPGA constraints missing or not fully read", WARNING)
def constraints_readable(ctx):
    for desig in sorted(ctx.fpgas, key=natural_key):
        f = ctx.fpgas[desig]
        io = f.io if hasattr(f, "io") else f
        if desig not in ctx.design.components:
            yield Finding("FIO001", f"{desig} is configured under 'fpga' but is not in the design", refs=[desig])
        if not io.files:
            yield Finding("FIO001", f"{desig}: no constraint files configured; its pins fall back to "
                                    "part data and symbol types", refs=[desig])
        for path in io.missing:
            yield Finding("FIO001", f"{desig}: constraint file not found: {path}. FPGA pin checks for "
                                    f"{desig} are skipped; check out the FPGA repository next to this one "
                                    "or fix the path in the config", refs=[desig])
        for problem in io.problems:
            yield Finding("FIO001", f"{desig}: {problem}", refs=[desig])


@check("FIO002", "Constrained FPGA port on a pin that is not board I/O", ERROR)
def constrained_pin_wiring(ctx):
    cfg = ctx.config
    for desig, f in _fpgas(ctx):
        pins = {str(p.designator): p for p in f.component.pins}
        for ball, c in sorted(f.io.pins.items(), key=lambda kv: natural_key(kv[0])):
            pin = pins.get(ball)
            if pin is None:
                yield Finding("FIO002", f"{desig}: port '{c.port}' is constrained to pin {ball}, which the "
                                        f"schematic symbol does not have ({c.where})", refs=[desig])
            elif ctx.io_standard_info(f.component, c.io_std).get("tie_to") == "ground":
                if not cfg.is_ground(pin.net):
                    yield Finding("FIO002", f"{desig}.{ball} ({pin.name}) carries port '{c.port}' as {c.io_std}, "
                                            f"which the part data says is tied to ground, but it is on '{pin.net}' "
                                            f"({c.where})", refs=[desig], nets=[pin.net])
            elif cfg.is_ground(pin.net) or cfg.is_rail(pin.net):
                yield Finding("FIO002", f"{desig}.{ball} ({pin.name}) carries port '{c.port}' "
                                        f"({c.direction or 'no direction'}) but is tied to '{pin.net}' "
                                        f"({c.where})", refs=[desig], nets=[pin.net])


@check("FIO003", "Constrained FPGA port on an unconnected pin", WARNING)
def constrained_pin_unconnected(ctx):
    for desig, f in _fpgas(ctx):
        for pin in sorted(f.component.pins, key=lambda p: natural_key(p.designator)):
            c = f.constraint(pin)
            net = ctx.design.nets.get(pin.net)
            if c is not None and net is not None and len(net.pins) == 1:
                yield Finding("FIO003", f"{desig}.{pin.designator} ({pin.name}) carries port '{c.port}' "
                                        f"({c.direction or 'no direction'}) but connects to nothing "
                                        f"({c.where})", refs=[desig], nets=[pin.net])


@check("FIO004", "FPGA bank I/O voltage differs from its supply rail", ERROR)
def bank_voltage(ctx):
    cfg = ctx.config
    for desig, f in _fpgas(ctx):
        for bank in f.banks():
            vcci = f.bank_vcci(bank)
            supply = f.supply_pin_name(bank)
            nets = f.bank_supply_nets(bank)
            if supply and not nets:
                if vcci is not None:
                    yield Finding("FIO004", f"{desig} bank {bank}: constraints set VCCI {vcci:g} V but the "
                                            f"symbol has no {supply} pin to check it against", refs=[desig])
                continue
            if len(nets) > 1:
                yield Finding("FIO004", f"{desig} bank {bank}: {supply} pins are on different nets: "
                                        + ", ".join(sorted(nets)), refs=[desig], nets=sorted(nets))
                continue
            if vcci is None or not nets:
                continue
            net = next(iter(nets))
            volts = cfg.net_voltage(net)
            if volts is None:
                yield Finding("FIO004", f"{desig} bank {bank}: constraints set VCCI {vcci:g} V; {supply} is on "
                                        f"'{net}', whose voltage is unknown (add it to nets.voltages)",
                              severity=WARNING, refs=[desig], nets=[net])
            elif abs(volts - vcci) > _TOLERANCE * vcci:
                yield Finding("FIO004", f"{desig} bank {bank}: constraints set VCCI {vcci:g} V but {supply} is "
                                        f"on '{net}' ({volts:g} V)", refs=[desig], nets=[net])


@check("FIO005", "Wired FPGA I/O pin with no constraint", WARNING)
def unconstrained_io(ctx):
    """A bank I/O pin on a signal net shared with other parts, but no port is
    constrained to it: the FPGA does not drive or read what the board
    connects there."""
    cfg = ctx.config
    for desig, f in _fpgas(ctx):
        loose = []
        for pin in sorted(f.component.pins, key=lambda p: natural_key(p.designator)):
            if f.bank(pin) is None or f.constraint(pin) is not None:
                continue
            if cfg.is_ground(pin.net) or cfg.net_voltage(pin.net) is not None:
                continue
            net = ctx.design.nets.get(pin.net)
            others = [p for p in net.pins if p.component is not f.component] if net else []
            if others:
                loose.append((pin, net))
        for pin, net in loose:
            yield Finding("FIO005", f"{desig}.{pin.designator} ({pin.name}) is on '{net.name}' with "
                                    f"{', '.join(sorted({p.component.designator for p in net.pins if p.component is not f.component}, key=natural_key)[:6])} "
                                    "but no constraint assigns it a port", refs=[desig], nets=[net.name])


@check("FIO006", "FPGA constraint direction disagrees with the design", ERROR)
def constraint_direction(ctx):
    """The constraint's DIRECTION against the port as the FPGA design
    declares it (needs `top_level`). Input against output is an error: one
    of the two files is wrong about which way the signal goes. A
    bidirectional constraint on a one-way port is a warning."""
    for desig, f in _fpgas(ctx):
        for ball, c in sorted(f.io.pins.items(), key=lambda kv: natural_key(kv[0])):
            design = f.io.port_direction(c.port)
            if not design or not c.direction or design == c.direction:
                continue
            severity = WARNING if "inout" in (design, c.direction) else ERROR
            yield Finding("FIO006", f"{desig}.{ball}: port '{c.port}' is {design} in the FPGA design but "
                                    f"{c.direction} in the constraints ({c.where})",
                          severity=severity, refs=[desig])


@check("FIO007", "FPGA top-level port with no pin constraint", ERROR)
def unplaced_ports(ctx):
    """A top-level port no constraint assigns to a pin: place-and-route puts
    it on any free I/O, which on a built board is whatever that pin is wired to."""
    for desig, f in _fpgas(ctx):
        placed = {c.port for c in f.io.pins.values()}
        for port in sorted(f.io.ports, key=natural_key):
            if port not in placed:
                yield Finding("FIO007", f"{desig}: top-level port '{port}' ({f.io.ports[port]}) has no pin "
                                        "constraint; Libero will place it on any free I/O", refs=[desig])
