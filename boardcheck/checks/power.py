"""Power, derating and rail checks.

Net voltages come from the rail naming convention ("3V3_MISC" = 3.3 V) plus
explicit overrides in the config; see Config.net_voltage. A part is only
checked when the voltage on both of its terminals is known.
"""

from . import ERROR, INFO, WARNING, Finding, check
from ..model import natural_key
from ..units import format_value, parse_value


def _two_terminal(ctx, kind):
    for comp in ctx.design.components.values():
        if ctx.kind(comp) == kind and len(comp.pins) == 2:
            yield comp


def _across(ctx, comp):
    """(|V|, net_a, net_b) across a two-terminal part, or None if unknown."""
    a, b = comp.pins[0].net, comp.pins[1].net
    va, vb = ctx.config.net_voltage(a), ctx.config.net_voltage(b)
    if va is None or vb is None:
        return None
    return abs(va - vb), a, b


def _rated(ctx, comp, param, unit, decoded_value):
    """Lowest of the library parameter and decoded rating, with its source."""
    candidates = []
    v = parse_value(ctx.design.param(comp, param), unit)
    if v is not None:
        candidates.append((v, f"{param} parameter"))
    if decoded_value is not None:
        candidates.append((decoded_value, "decoded part number"))
    return min(candidates) if candidates else (None, None)


def _cap_class(ctx, comp, decoded):
    text = " ".join(filter(None, [
        ctx.design.param(comp, "Dialectric", "Dielectric"),
        decoded.dielectric if decoded else None,
        decoded.source if decoded else None,
        comp.part_number,
    ])).upper()
    if "TANTALUM" in text:
        return "tantalum"
    if any(d in text for d in ("X7R", "X5R", "X7S", "X8L", "X6S", "C0G", "NP0", "BX", "BP", "MLCC")):
        return "ceramic"
    return "default"


def cap_voltage_coverage(ctx):
    """(checked, total, worst) where worst is (ratio, designator, volts, rated)."""
    total = checked = 0
    worst = None
    for comp in _two_terminal(ctx, "capacitor"):
        total += 1
        across = _across(ctx, comp)
        if not across:
            continue
        decoded = ctx.decoded(comp)
        rated, _ = _rated(ctx, comp, "Voltage", "V", decoded.voltage_rated if decoded else None)
        if not rated:
            continue
        checked += 1
        ratio = across[0] / rated
        if worst is None or ratio > worst[0]:
            worst = (ratio, comp.designator, across[0], rated)
    return checked, total, worst


@check("PWR001", "Capacitor voltage over rating or derating limit", WARNING)
def cap_voltage(ctx):
    limits = ctx.config["derating"]["capacitor_voltage"]
    for comp in _two_terminal(ctx, "capacitor"):
        across = _across(ctx, comp)
        if not across or across[0] == 0:
            continue
        volts, a, b = across
        decoded = ctx.decoded(comp)
        rated, source = _rated(ctx, comp, "Voltage", "V", decoded.voltage_rated if decoded else None)
        if rated is None:
            continue  # PRT002 reports the missing rating
        cls = _cap_class(ctx, comp, decoded)
        factor = limits.get(cls, limits["default"])
        where = f"{comp.designator} ({comp.part_number}) sees {volts:g} V across {a} / {b}"
        if volts > rated:
            yield Finding("PWR001", f"{where}, above its {rated:g} V rating ({source})", severity=ERROR,
                          refs=[comp.designator], nets=[a, b], part_number=comp.part_number)
        elif volts > factor * rated:
            yield Finding("PWR001", f"{where}: {volts / rated:.0%} of its {rated:g} V rating ({source}), "
                                    f"{cls} limit is {factor:.0%}",
                          refs=[comp.designator], nets=[a, b], part_number=comp.part_number)


@check("PWR002", "Resistor between rails over power or voltage rating", WARNING)
def resistor_power(ctx):
    factor = ctx.config["derating"]["resistor_power"]
    for comp in _two_terminal(ctx, "resistor"):
        across = _across(ctx, comp)
        if not across or across[0] == 0:
            continue
        volts, a, b = across
        decoded = ctx.decoded(comp)
        ohms = parse_value(ctx.design.param(comp, "R_Value"), "Ω")
        if ohms is None and decoded:
            ohms = decoded.resistance
        if ohms is None:
            continue
        where = f"{comp.designator} ({comp.part_number}) across {a} / {b} ({volts:g} V)"
        if ohms == 0:
            yield Finding("PWR002", f"{where} is 0 Ω: it shorts two different rails", severity=ERROR,
                          refs=[comp.designator], nets=[a, b], part_number=comp.part_number)
            continue
        watts = volts ** 2 / ohms
        rated, source = _rated(ctx, comp, "Power_Rating", "W", decoded.power_max if decoded else None)
        if rated is not None:
            if watts > rated:
                yield Finding("PWR002", f"{where} dissipates {format_value(watts, 'W')}, above its "
                                        f"{format_value(rated, 'W')} rating ({source})", severity=ERROR,
                              refs=[comp.designator], nets=[a, b], part_number=comp.part_number)
            elif watts > factor * rated:
                yield Finding("PWR002", f"{where} dissipates {format_value(watts, 'W')}: {watts / rated:.0%} "
                                        f"of {format_value(rated, 'W')} ({source}), limit {factor:.0%}",
                              refs=[comp.designator], nets=[a, b], part_number=comp.part_number)
        if decoded and decoded.voltage_rated and volts > decoded.voltage_rated:
            yield Finding("PWR002", f"{where} exceeds its {decoded.voltage_rated:g} V working voltage",
                          severity=ERROR, refs=[comp.designator], nets=[a, b], part_number=comp.part_number)


def rail_summary(ctx):
    """[(rail, volts, pins, caps_to_ground, testpoints)] for every supply rail."""
    rows = []
    for net in ctx.design.nets.values():
        if not ctx.config.is_rail(net.name):
            continue
        caps = tps = 0
        for comp in net.components():
            kind = ctx.kind(comp)
            if kind == "capacitor" and any(ctx.config.is_ground(n) for n in comp.nets()):
                caps += 1
            elif kind == "testpoint":
                tps += 1
        rows.append((net.name, ctx.config.net_voltage(net.name), len(net.pins), caps, tps))
    return sorted(rows, key=lambda r: (r[1], r[0]))


@check("PWR003", "Supply rail with no capacitor to ground", WARNING)
def rail_decoupling(ctx):
    for name, volts, pins, caps, _ in rail_summary(ctx):
        if caps == 0:
            yield Finding("PWR003", f"rail '{name}' ({volts:g} V, {pins} pins) has no capacitor to ground",
                          nets=[name])


@check("PWR004", "Supply rail with no test point", INFO)
def rail_testpoints(ctx):
    for name, volts, pins, _, tps in rail_summary(ctx):
        if tps == 0:
            yield Finding("PWR004", f"rail '{name}' ({volts:g} V) has no test point", nets=[name])


@check("PWR005", "Supply pin on the wrong kind of net", WARNING)
def supply_pin_nets(ctx):
    """Ground-named pins must sit on a ground net and power-named pins must
    not; either way round is a swapped or mislabelled connection."""
    cfg = ctx.config
    for comp in ctx.design.components.values():
        if ctx.kind(comp) not in ("ic", "unknown"):
            continue
        bad = []
        for pin in comp.pins:
            net = ctx.design.nets[pin.net]
            if net.auto_named and len(net.pins) == 1:
                continue  # NET003 reports unconnected supply pins
            if cfg.ground_pin_re.match(pin.name) and not cfg.is_ground(pin.net):
                bad.append(f"{pin.designator} ({pin.name}) on '{pin.net}'")
            elif (cfg.power_pin_re.match(pin.name) and not cfg.ground_pin_re.match(pin.name)
                  and cfg.is_ground(pin.net)):
                bad.append(f"{pin.designator} ({pin.name}) on ground '{pin.net}'")
        if bad:
            yield Finding("PWR005", f"{comp.designator} ({comp.part_number}): " + "; ".join(bad[:12])
                          + (f"; ... {len(bad) - 12} more" if len(bad) > 12 else ""),
                          refs=[comp.designator])


@check("PWR006", "I2C line without pull-up", WARNING)
def i2c_pullups(ctx):
    cfg = ctx.config
    for net in sorted(ctx.design.nets.values(), key=lambda n: n.name):
        if not cfg.i2c_re.search(net.name):
            continue
        pulled = False
        for comp in net.components():
            if ctx.kind(comp) == "resistor" and len(comp.pins) == 2:
                other = [p.net for p in comp.pins if p.net != net.name]
                if other and cfg.is_rail(other[0]):
                    pulled = True
        if not pulled:
            yield Finding("PWR006", f"'{net.name}' has no resistor to a supply rail", nets=[net.name])


@check("PWR007", "IC supply pin on a net with no capacitor to ground", WARNING)
def supply_pin_decoupling(ctx):
    """An IC supply pin (power in the part data, else a power-like name) on
    a net that is not a named rail and has no capacitor to ground: a local
    supply (filtered, switched, or a reference) left undecoupled. Named
    rails are PWR003's."""
    from .pins import _pin_types
    pt = _pin_types(ctx)
    cfg = ctx.config
    verify = set(cfg["pins"]["verify_kinds"])
    found = {}
    for comp in ctx.design.components.values():
        if ctx.kind(comp) not in verify:
            continue
        for pin in comp.pins:
            if cfg.is_ground(pin.net) or cfg.is_rail(pin.net):
                continue
            pp = pt.part_entry(pin)
            if pp is not None:
                is_supply = pp.direction == "power" and not cfg.ground_pin_re.match(pp.key) \
                    and not cfg.ground_pin_re.match(pin.name or "")
            else:
                is_supply = bool(cfg.power_pin_re.match(pin.name or "")) and not cfg.ground_pin_re.match(pin.name or "")
            net = ctx.design.nets.get(pin.net)
            if not is_supply or net is None or len(net.pins) < 2:
                continue        # an unconnected supply pin is NET003's
            if any(ctx.kind(c) == "capacitor" and any(cfg.is_ground(n) for n in c.nets()) for c in net.components()):
                continue
            found.setdefault(pin.net, []).append(pin)
    for net, pins in sorted(found.items()):
        yield Finding("PWR007", f"'{net}' supplies {', '.join(f'{p.ref} {p.name}' for p in pins[:6])} "
                                "but has no capacitor to ground",
                      refs=sorted({p.component.designator for p in pins}, key=natural_key), nets=[net])
