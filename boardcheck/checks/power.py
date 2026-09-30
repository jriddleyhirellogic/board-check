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


@check("PWR008", "IC supply rail outside the part's recommended range", ERROR, needs_partsdb=True)
def supply_in_range(ctx):
    """Each supply pin's rail against the part data's `supply_<pin>`
    recommended operating range (a range_table applying to that pin, or
    named after it). Rows conditioned on an I/O standard or bank type are
    FPGA bank rules, checked by LVL004."""
    from .levels import PinLevels, _levels
    from .pins import _norm, _pin_types
    pt = _pin_types(ctx)
    lv = _levels(ctx)
    cfg = ctx.config
    for comp in sorted(ctx.design.components.values(), key=lambda c: natural_key(c.designator)):
        chars = ctx.partsdb.characteristics(comp.part_number) or {}
        table = pt.table(comp.part_number)
        if not chars or not table:
            continue
        for key, char in chars.items():
            if not key.startswith("supply_") or not isinstance(char, dict) or char.get("kind") != "range_table":
                continue
            targets = char.get("applies_to") or [k for k in table["by_name"].values()
                                                 if _norm(k.key) == _norm(key[len("supply_"):])]
            targets = [t if isinstance(t, str) else t.key for t in targets]
            rows = [r for r in char.get("rows") or []
                    if not set(r.get("conditions") or {}) - {"ambient_temperature", "junction_temperature"}]
            if not rows:
                continue
            for target in targets:
                pp = table["by_name"].get(_norm(target))
                if pp is None or pp.per_bank:
                    continue
                pins = [p for p in comp.pins if str(p.designator) in pp.numbers or _norm(p.name) == _norm(target)]
                rails = {p.net for p in pins if cfg.net_voltage(p.net) is not None}
                if not pins:
                    continue
                # Limits may name another supply of the part ("2.7 V to VA").
                pl = PinLevels(pins[0], chars, key=pp.key)
                bounds = []
                for r in rows:
                    lo = lv._limit(pl, r["min"]) if "min" in r else float("-inf")
                    hi = lv._limit(pl, r["max"]) if "max" in r else float("inf")
                    if lo is not None and hi is not None:
                        bounds.append((lo, hi))
                if not bounds:
                    continue
                for rail in sorted(rails):
                    v = cfg.net_voltage(rail)
                    if not any(lo - 1e-9 <= v <= hi + 1e-9 for lo, hi in bounds):
                        span = ", ".join(f"{lo:g}-{hi:g} V" for lo, hi in bounds)
                        yield Finding("PWR008", f"{comp.designator} ({comp.part_number}) {target} is on '{rail}' "
                                                f"({v:g} V); recommended {span} ({char.get('_source', 'part data')})",
                                      refs=[comp.designator], nets=[rail], part_number=comp.part_number)


def _solve(a, b):
    """Gaussian elimination for a small dense system; None when singular."""
    n = len(b)
    m = [row[:] + [b[i]] for i, row in enumerate(a)]
    for c in range(n):
        piv = max(range(c, n), key=lambda r: abs(m[r][c]))
        if abs(m[piv][c]) < 1e-18:
            return None
        m[c], m[piv] = m[piv], m[c]
        for r in range(n):
            if r != c and m[r][c]:
                f = m[r][c] / m[c][c]
                m[r] = [x - f * y for x, y in zip(m[r], m[c])]
    return [m[i][n] / m[i][i] for i in range(n)]


def feedback_network(ctx, fb_net, max_nodes=30):
    """(k, rth, output net, resistors) for the resistor network around a
    feedback node: Vfb = k * Vout + rth * I, where Vout is the one rail (with
    its sense nets) the network reaches besides ground and I is a current
    injected into the feedback node. Capacitors and IC pins are open. None
    when the network reaches no rail, more than one rail voltage, or a
    resistor of unknown value."""
    from .levels import _ohms
    cfg = ctx.config
    nodes, sources, edges, seen_res = [fb_net], {}, [], set()
    i = 0
    while i < len(nodes):
        net = nodes[i]
        i += 1
        for q in ctx.design.nets[net].pins:
            c = q.component
            if ctx.kind(c) != "resistor" or len(c.pins) != 2 or c.designator in seen_res:
                continue
            seen_res.add(c.designator)
            other = next((p.net for p in c.pins if p is not q), None)
            ohms = _ohms(ctx, c)
            if ohms is None or other is None:
                return None
            edges.append((net, other, max(ohms, 1e-3), c))
            v = cfg.net_voltage(other)
            if cfg.is_ground(other) or v is not None:
                sources[other] = 0.0 if cfg.is_ground(other) else v
            elif other not in nodes:
                nodes.append(other)
                if len(nodes) > max_nodes:
                    return None
    live = {n for n, v in sources.items() if v}
    if not live or len({round(sources[n], 3) for n in live}) != 1:
        return None
    idx = {n: j for j, n in enumerate(nodes)}

    def fb_voltage(v_out, inject):
        a = [[0.0] * len(nodes) for _ in nodes]
        b = [0.0] * len(nodes)
        b[0] += inject
        for x, y, r, _ in edges:
            g = 1.0 / r
            for n1, n2 in ((x, y), (y, x)):
                if n1 not in idx:
                    continue
                a[idx[n1]][idx[n1]] += g
                if n2 in idx:
                    a[idx[n1]][idx[n2]] -= g
                else:
                    b[idx[n1]] += g * (v_out if n2 in live else 0.0)
        sol = _solve(a, b)
        return sol[0] if sol else None

    k = fb_voltage(1.0, 0.0)
    rth = fb_voltage(0.0, 1.0)
    if not k or rth is None:
        return None
    out = min(live, key=lambda n: (not cfg.is_rail(n), n))
    return k, rth, out, [e[3] for e in edges]


def regulator_setpoint(ctx, comp, block):
    """(vout typ, vout min, vout max, output net, network resistors, [])
    for a regulator whose feedback pin sits in a resistor network between
    its output rail (and its sense nets) and ground, from the
    part data's v_feedback and `regulator` block; None when the feedback
    network is not that shape or a value is unknown."""
    from .levels import PinLevels, _levels, _ohms
    from .pins import _norm, _pin_types
    cfg = ctx.config
    pt = _pin_types(ctx)
    table = pt.table(comp.part_number)
    fb_entry = table["by_name"].get(_norm(block["feedback_pin"])) if table else None
    if fb_entry is None:
        return None
    fb_pins = [p for p in comp.pins if str(p.designator) in fb_entry.numbers or _norm(p.name) == _norm(fb_entry.key)]
    if not fb_pins:
        return None
    fb_net = fb_pins[0].net
    net_model = feedback_network(ctx, fb_net)
    if net_model is None:
        return None
    k, rth, out, resistors = net_model
    chars = ctx.partsdb.characteristics(comp.part_number) or {}
    rows = (chars.get("v_feedback") or {}).get("rows") or []
    typs = [r["typ"] for r in rows if isinstance(r.get("typ"), (int, float))]
    lows = [r["min"] for r in rows if isinstance(r.get("min"), (int, float))]
    highs = [r["max"] for r in rows if isinstance(r.get("max"), (int, float))]
    if not typs:
        return None
    ibias = float(block.get("feedback_bias_current") or 0.0)
    # Vfb = k * Vout + I * Rth at regulation equals Vref; for a plain divider
    # this is the data sheet's VOUT = VREF (1 + Rtop/Rbottom) - I x Rtop.
    f = lambda v: (v - ibias * rth) / k            # noqa: E731
    typ = f(sorted(typs)[len(typs) // 2])
    return (typ, f(min(lows)) if lows else None, f(max(highs)) if highs else None, out, resistors, [])


@check("PWR009", "Regulator feedback divider sets a different voltage than the rail's name", ERROR, needs_partsdb=True)
def regulator_output(ctx):
    """For each regulator with part data (`regulator` block, `v_feedback`),
    the output its feedback divider sets (the data sheet's equation, with
    the typical reference and the min/max span) against the nominal voltage
    of the rail it regulates, from the rail's name. Tolerance:
    `power.regulator_tolerance`."""
    cfg = ctx.config
    tol = float(cfg["power"]["regulator_tolerance"])
    for comp in sorted(ctx.design.components.values(), key=lambda c: natural_key(c.designator)):
        block = ctx.partsdb.regulator(comp.part_number)
        if not block:
            continue
        sp = regulator_setpoint(ctx, comp, block)
        if sp is None:
            yield Finding("PWR009", f"{comp.designator} ({comp.part_number}): feedback network at "
                                    f"{block['feedback_pin']} not recognised (it must reach one rail voltage and "
                                    "ground through resistors of known value)", severity=INFO, refs=[comp.designator])
            continue
        typ, lo, hi, out, top, bottom = sp
        nominal = cfg.net_voltage(out)
        span = f" ({lo:.3f}-{hi:.3f} V over the reference tolerance)" if lo is not None and hi is not None else ""
        divider = ", ".join(c.designator for c in sorted(top, key=lambda c: natural_key(c.designator)))
        if nominal is None:
            yield Finding("PWR009", f"{comp.designator} ({comp.part_number}) sets {typ:.3f} V{span} through "
                                    f"{divider} on '{out}', whose voltage the net name does not give",
                          severity=INFO, refs=[comp.designator], nets=[out])
        elif abs(typ - nominal) > tol * nominal:
            yield Finding("PWR009", f"{comp.designator} ({comp.part_number}) sets '{out}' to {typ:.3f} V{span} "
                                    f"through {divider}, but the rail is named for {nominal:g} V",
                          refs=[comp.designator] + [c.designator for c in top], nets=[out], part_number=comp.part_number)
