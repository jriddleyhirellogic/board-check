"""FPGA pin configuration against the schematic.

The FPGA constraint files (see boardcheck/fpga.py) say what each FPGA pin is
configured as; the schematic says what it is wired to. These checks join the
two: constrained pins that are not I/O on the board, banks whose I/O voltage
disagrees with the rail feeding them, and wired I/O the constraints leave
unassigned.
"""

import re

from . import ERROR, INFO, WARNING, Finding, check
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


def _split_index(port):
    m = re.match(r"^(.*?)(\[\d+\])?$", port)
    return m.group(1), m.group(2) or ""


def diff_port_pairs(ctx, f):
    """([(positive port, negative port)], [(port, missing partner)]): pairs
    among the constrained ports by the configured name suffixes (first
    matching rule wins), and positive halves whose partner is not
    constrained."""
    ports = {c.port for c in f.io.pins.values()}
    rules = ctx.config["fpga_pins"]["diff_port_suffixes"]
    pairs, used, halves = [], set(), []
    for name in sorted(ports, key=natural_key):
        if name in used:
            continue
        base, idx = _split_index(name)
        for pos, neg in rules:
            if not neg or not base.lower().endswith(neg.lower()):
                continue
            partner = base[:len(base) - len(neg)] + pos + idx
            if partner in ports and partner != name and partner not in used:
                pairs.append((partner, name))
                used.update((partner, name))
                break
    # A lone positive half (_p, _t) is suspicious; a lone _n is usually an
    # active-low signal, not half a pair.
    for name in sorted(ports - used, key=natural_key):
        base, idx = _split_index(name)
        for pos, neg in rules:
            if pos and base.lower().endswith(pos.lower()):
                halves.append((name, base[:len(base) - len(pos)] + neg + idx))
                break
    return pairs, halves


def _ball_of(f):
    by_port = {c.port: c for c in f.io.pins.values()}
    pins = {str(p.designator): p for p in f.component.pins}
    return by_port, pins


@check("FIO008", "FPGA differential pair not on a P/N ball pair", ERROR)
def diff_pair_balls(ctx):
    """Two ports that form a differential pair (by name suffix) must land on
    the P and N pins of one pair, as the schematic pin names give them
    (`pair_patterns`); a _p (or _t) port whose partner has no constraint is
    a warning."""
    for desig, f in _fpgas(ctx):
        if not f._pair_res:
            continue
        by_port, pins = _ball_of(f)
        pairs, halves = diff_port_pairs(ctx, f)
        for pos, neg in pairs:
            cp, cn = by_port[pos], by_port[neg]
            pp, pn = pins.get(cp.ball), pins.get(cn.ball)
            if pp is None or pn is None:
                continue        # FIO002 reports balls missing from the symbol
            ap, an = f.pair(pp), f.pair(pn)
            where = f"'{pos}' on {cp.ball} ({pp.name}), '{neg}' on {cn.ball} ({pn.name})"
            if ap is None or an is None:
                yield Finding("FIO008", f"{desig}: {where}: "
                                        f"{'neither ball' if ap is None and an is None else 'one ball'} is half of a "
                                        "differential pair", refs=[desig], nets=[pp.net, pn.net])
            elif ap[0] != an[0]:
                yield Finding("FIO008", f"{desig}: {where}: the balls belong to different pairs "
                                        f"({ap[0]}{ap[1]} and {an[0]}{an[1]})", refs=[desig], nets=[pp.net, pn.net])
            elif (ap[1], an[1]) != ("P", "N"):
                yield Finding("FIO008", f"{desig}: {where}: positive and negative are swapped on pair {ap[0]}",
                              refs=[desig], nets=[pp.net, pn.net])
        for port, partner in halves:
            yield Finding("FIO008", f"{desig}: '{port}' is constrained but its partner '{partner}' is not",
                          severity=WARNING, refs=[desig])


def _net_polarity(ctx, net):
    """("stem", "P" or "N") when a net name carries a diff-pair suffix."""
    for pos, neg in ctx.config["nets"]["diff_pair_suffixes"]:
        for suffix, pol in ((pos, "P"), (neg, "N")):
            if suffix and net.upper().endswith(suffix.upper()):
                return net[:len(net) - len(suffix)].upper(), pol
    return None


@check("FIO009", "Board swaps a differential pair's polarity at the FPGA", ERROR)
def diff_pair_nets(ctx):
    """The schematic nets on a differential port pair's balls: when both
    carry pair suffixes of one stem (DDR4_CK_P / DDR4_CK_N), the positive
    port's ball must be on the positive net."""
    for desig, f in _fpgas(ctx):
        by_port, pins = _ball_of(f)
        pairs, _ = diff_port_pairs(ctx, f)
        for pos, neg in pairs:
            pp, pn = pins.get(by_port[pos].ball), pins.get(by_port[neg].ball)
            if pp is None or pn is None:
                continue
            np_, nn = _net_polarity(ctx, pp.net), _net_polarity(ctx, pn.net)
            if np_ and nn and np_[0] == nn[0] and (np_[1], nn[1]) == ("N", "P"):
                yield Finding("FIO009", f"{desig}: '{pos}' ({by_port[pos].ball}) is on '{pp.net}' and '{neg}' "
                                        f"({by_port[neg].ball}) on '{pn.net}': the board crosses the pair",
                              refs=[desig], nets=[pp.net, pn.net])


def _is_refclk(ctx, f, port):
    fp = ctx.config["fpga_pins"]
    if f.io.port_links:
        pads = re.compile(fp["refclk_pads"])
        base, idx = _split_index(port)
        links = f.io.port_links.get(port) or f.io.port_links.get(base) or set()
        return any(pads.search(link) for link in links)
    return re.search(fp["refclk_ports"], port, re.I) is not None


@check("FIO010", "Transceiver pin carries the wrong kind of port", ERROR)
def transceiver_pins(ctx):
    """Reference clock ports (connected to a reference-clock pad in the
    SmartDesign top level, or named like one without it) must be on REFCLK
    pins; ports on transceiver RX pins must be inputs and on TX pins
    outputs. A REFCLK pin carrying a port that is not a reference clock is a
    warning."""
    for desig, f in _fpgas(ctx):
        if f._xcvr_re is None:
            continue
        _, pins = _ball_of(f)
        for ball, c in sorted(f.io.pins.items(), key=lambda kv: natural_key(kv[0])):
            pin = pins.get(ball)
            if pin is None:
                continue
            xc = f.transceiver(pin)
            ref = _is_refclk(ctx, f, c.port)
            direction = f.direction(c)
            where = f"{desig}.{ball} ({pin.name}) carries '{c.port}'"
            if ref and (xc is None or xc[1] != "REFCLK"):
                yield Finding("FIO010", f"{where}, a transceiver reference clock, but it is not a REFCLK pin",
                              refs=[desig], nets=[pin.net])
            elif xc and xc[1] == "REFCLK" and not ref:
                yield Finding("FIO010", f"{where}, which is not connected to a reference clock pad",
                              severity=WARNING, refs=[desig], nets=[pin.net])
            elif xc and xc[1] in ("RX", "TX") and direction:
                want = "input" if xc[1] == "RX" else "output"
                if direction != want:
                    yield Finding("FIO010", f"{where} ({direction}) on a transceiver {xc[1]} pin, which needs "
                                            f"an {want}", refs=[desig], nets=[pin.net])


@check("FIO011", "Transceiver quad without a reachable reference clock", WARNING, needs_partsdb=True)
def quad_reference_clocks(ctx):
    """Each quad with used lanes needs a reference clock on its own REFCLK
    pins or, where the part data says reference clocks cascade down
    (`transceivers.refclk_cascade`), on a quad above it in
    `quads_top_to_bottom`. Relying on a cascade is reported as info (confirm
    the placement in the vendor tool); no reachable pin at all is a warning,
    since the lanes' CDRs would then need a fabric clock."""
    for desig, f in _fpgas(ctx):
        info = ctx.partsdb.transceivers(f.component.part_number) if ctx.partsdb else None
        if not info or f._xcvr_re is None:
            continue
        order = [str(q) for q in info.get("quads_top_to_bottom") or []]
        _, pins = _ball_of(f)
        lanes, refclks = {}, {}
        for ball, c in f.io.pins.items():
            pin = pins.get(ball)
            xc = f.transceiver(pin) if pin is not None else None
            if xc is None:
                continue
            quad, role = xc
            if role in ("RX", "TX"):
                lanes.setdefault(quad, []).append(c.port)
            elif role == "REFCLK" and _is_refclk(ctx, f, c.port):
                refclks.setdefault(quad, []).append(f"{pin.name} ('{c.port}')")
        for quad in sorted(lanes, key=natural_key):
            ports = ", ".join(sorted(lanes[quad], key=natural_key)[:4]) + (" ..." if len(lanes[quad]) > 4 else "")
            if quad in refclks:
                continue
            above = order[:order.index(quad)] if quad in order else []
            sources = [q for q in reversed(above) if q in refclks] if info.get("refclk_cascade") == "down" else []
            if sources:
                src = sources[0]
                yield Finding("FIO011", f"{desig} quad {quad} ({ports}) has no reference clock pin of its own; it "
                                        f"relies on the cascade from quad {src} ({', '.join(sorted(refclks[src]))}). "
                                        "The part data gives no cascade reach table: confirm the placement in the "
                                        "vendor tool", severity=INFO, refs=[desig])
            else:
                yield Finding("FIO011", f"{desig} quad {quad} ({ports}) has no reference clock on its own REFCLK pins "
                                        "or on a quad above it; its lanes would need a fabric CDR reference",
                              refs=[desig])
