"""Power, derating and rail checks.

Net voltages come from the rail naming convention ("3V3_MISC" = 3.3 V) plus
explicit overrides in the config; see Config.net_voltage. A part is only
checked when the voltage on both of its terminals is known.
"""

import re

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
                    and not cfg.ground_pin_re.match(pin.name or "") \
                    and not re.search(r"GROUND|SENSE|CHARGE|PUMP|BOOT|SWITCH|PHASE", str(pp.entry.get("function") or ""), re.I)
            else:
                is_supply = bool(cfg.power_pin_re.match(pin.name or "")) and not cfg.ground_pin_re.match(pin.name or "")
            net = ctx.design.nets.get(pin.net)
            if not is_supply or net is None or len(net.pins) < 2:
                continue        # an unconnected supply pin is NET003's
            if any(ctx.kind(c) == "capacitor" for c in net.components()):
                continue        # decoupled to ground, or a charge-pump / bootstrap capacitor to another node
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


def _setpoints(ctx):
    """{rail: (typ, min, max, regulator designator)} for every regulator whose
    output PWR009 can work out."""
    if hasattr(ctx, "_setpoints"):
        return ctx._setpoints
    out = {}
    for comp in sorted(ctx.design.components.values(), key=lambda c: natural_key(c.designator)):
        block = ctx.partsdb.regulator(comp.part_number) if ctx.partsdb else None
        sp = regulator_setpoint(ctx, comp, block) if block else None
        if sp:
            out[sp[3]] = (sp[0], sp[1] if sp[1] is not None else sp[0], sp[2] if sp[2] is not None else sp[0],
                          comp.designator)
    ctx._setpoints = out
    return out


def _dropout(chars, amps):
    """Worst (largest) data sheet maximum dropout at `amps`, interpolated
    between the v_dropout rows' load currents (clamped at the ends); None
    without data."""
    points = {}
    for row in (chars.get("v_dropout") or {}).get("rows") or []:
        lc = (row.get("conditions") or {}).get("load_current") or {}
        if isinstance(row.get("max"), (int, float)) and "value" in lc:
            a = float(lc["value"]) * (1e-3 if lc.get("unit", "mA") == "mA" else 1.0)
            points[a] = max(points.get(a, 0.0), float(row["max"]))
    if not points:
        return None
    xs = sorted(points)
    if amps <= xs[0]:
        return points[xs[0]]
    for a, b in zip(xs, xs[1:]):
        if amps <= b:
            return points[a] + (points[b] - points[a]) * (amps - a) / (b - a)
    return points[xs[-1]]


def _current_limit(ctx, comp, block):
    """(amps, how) the regulator can deliver: its programmed current limit
    (resistor from the limit pin to ground), else its rating."""
    from .levels import _ohms
    from .pins import _norm
    rating = block.get("output_current_max")
    cl = block.get("current_limit") or {}
    pins = [p for p in comp.pins if cl.get("pin") and _norm(p.name) == _norm(cl["pin"])]
    if pins:
        net = pins[0].net
        if ctx.config.is_ground(net):
            amps = cl.get("internal")
            if amps is not None:
                return float(amps), f"{cl['pin']} grounded: internal limit"
        rs = [q.component for q in ctx.design.nets[net].pins if ctx.kind(q.component) == "resistor"
              and len(q.component.pins) == 2 and any(ctx.config.is_ground(x.net) for x in q.component.pins)]
        if len(rs) == 1 and _ohms(ctx, rs[0]) and cl.get("k"):
            amps = float(cl["k"]) / _ohms(ctx, rs[0])
            how = f"{rs[0].designator} programs a {amps * 1000:.0f} mA limit"
            if rating is not None and amps > float(rating):
                return float(rating), how + f", above the {float(rating) * 1000:.0f} mA rating"
            return amps, how
    if rating is not None:
        return float(rating), "rated output current"
    return None, None


@check("PWR010", "Linear regulator input too close to its output", WARNING, needs_partsdb=True)
def ldo_headroom(ctx):
    """For each linear regulator (part data `regulator.topology: linear`),
    the input rail less the output it sets against the data sheet's
    maximum dropout (`v_dropout`) at the most current it can deliver: its
    programmed current limit (`regulator.current_limit`) or its rating.
    Rails set by other regulators are taken at their worst case (input at
    its minimum, output at its maximum, over the references' tolerance);
    other rails at their named voltage. Error when the headroom is below
    the dropout at the lightest tabulated load, warning when it only
    covers part of the current the limit allows."""
    sps = _setpoints(ctx)
    for comp in sorted(ctx.design.components.values(), key=lambda c: natural_key(c.designator)):
        block = ctx.partsdb.regulator(comp.part_number)
        if not block or block.get("topology") != "linear":
            continue
        chars = ctx.partsdb.characteristics(comp.part_number) or {}
        sp = regulator_setpoint(ctx, comp, block)
        ins = [p for p in comp.pins if p.name in (block.get("input_pins") or [])]
        if sp is None or not ins:
            continue
        vin_net = ins[0].net
        up = sps.get(vin_net)
        vin = up[1] if up else ctx.config.net_voltage(vin_net)
        if vin is None:
            continue
        vout = sp[2] if sp[2] is not None else sp[0]
        head = vin - vout
        amps, how = _current_limit(ctx, comp, block)
        light = _dropout(chars, 0.0)
        full = _dropout(chars, amps) if amps else None
        if light is None:
            continue
        src = f"'{vin_net}' at {vin:.3f} V" + (f" ({up[3]} minimum)" if up else "")
        where = f"{comp.designator} ({comp.part_number}): {src} feeds '{sp[3]}' at up to {vout:.3f} V, {head:.3f} V of headroom"
        if head < light:
            yield Finding("PWR010", f"{where}, below the {light * 1000:.0f} mV maximum dropout at the lightest "
                                    "tabulated load", severity=ERROR, refs=[comp.designator], nets=[vin_net, sp[3]],
                          part_number=comp.part_number)
        elif full is not None and head < full:
            # the most current whose maximum dropout still fits
            lo, hi = 0.0, amps
            for _ in range(40):
                mid = (lo + hi) / 2
                lo, hi = (mid, hi) if _dropout(chars, mid) <= head else (lo, mid)
            yield Finding("PWR010", f"{where}; the maximum dropout reaches that at about {lo * 1000:.0f} mA, but "
                                    f"{how} ({full * 1000:.0f} mV dropout there)",
                          refs=[comp.designator], nets=[vin_net, sp[3]], part_number=comp.part_number)


def _pin_by_key(ctx, comp, key):
    from .pins import _norm, _pin_types
    pt = _pin_types(ctx)
    for p in comp.pins:
        pp = pt.part_entry(p)
        if (pp and _norm(pp.key) == _norm(key)) or _norm(p.name) == _norm(key):
            return p
    return None


def _threshold(lv, pl, name, side, pick):
    """A reference threshold's limit. Rows are tried as usual first; failing
    that, a row rejected only for a supply test point above the rail (the
    data sheet's general test condition, e.g. LM5116 VIN = 48 V) still
    applies: the threshold comes from the part's reference, not its supply."""
    v = lv.value(pl, name, side, "high" if pick is max else "low")[0]
    if v is not None:
        return v
    vals = []
    for _, char in lv._tables(pl, name):
        for row in char.get("rows") or []:
            cond = dict(row.get("conditions") or {})
            sv = cond.pop("supply_voltage", None)
            if side in row and (sv is None or "value" in sv) and not lv._row_ok(pl, dict(row, conditions=cond)):
                vals.append(lv._limit(pl, row[side]))
    vals = [v for v in vals if v is not None]
    return pick(vals) if vals else None


def turn_on_points(ctx, comp, block):
    """[(pin, input net, V on, V off, how)] for a regulator's enable and UVLO
    pins held only by resistors (and the pin's own pull-up current) from its
    input rail: the input voltages where the pin crosses its rising
    threshold (at its maximum) and its falling threshold (at its minimum)."""
    from .levels import _levels, signals, _roles
    lv = _levels(ctx)
    by_net = {n: s for s in signals(ctx) for n in s.nets}
    ins = [p for p in comp.pins if p.name in (block.get("input_pins") or [])]
    if not ins:
        return []
    vin_net = ins[0].net
    out = []
    for key in (block.get("enable_pin"), block.get("uvlo_pin")):
        pin = _pin_by_key(ctx, comp, key) if key else None
        sig = by_net.get(pin.net) if pin else None
        if sig is None or any(t[3] is None or t[3] <= 0 for t in sig.ties):
            continue
        drivers, _ = _roles(ctx, sig)
        if drivers or sig.external or not any(t[1] == vin_net for t in sig.ties):
            continue
        pl = lv.for_pin(pin)
        if pl is None:
            continue
        on = _threshold(lv, pl, "vt_pos", "max", max)
        off = _threshold(lv, pl, "vt_neg", "min", min)
        if off is None:
            off = _threshold(lv, pl, "vt_neg", "typ", min)
        if on is None:
            continue
        # pin volts = a * Vin + b, from the ties' conductances and the pull-up current
        g = sum(1.0 / t[3] for t in sig.ties)
        a = sum(1.0 / t[3] for t in sig.ties if t[1] == vin_net) / g
        b = sum((t[2] or 0.0) / t[3] for t in sig.ties if t[1] != vin_net) / g
        ip = _threshold(lv, pl, "i_en_pullup", "typ", min)
        if ip is not None:
            b += ip * 1e-6 / g
        how = ", ".join(t[0].designator for t in sig.ties) + (f" and its {ip:g} uA pull-up" if ip else "")
        out.append((pin, vin_net, (on - b) / a, (off - b) / a if off is not None else None, how))
    return out


@check("PWR011", "Regulator enable or UVLO divider sets a turn-on outside its input range", ERROR,
       needs_partsdb=True)
def turn_on_voltage(ctx):
    """For an enable or UVLO pin (regulator `enable_pin`, `uvlo_pin`) held by
    resistors from the regulator's own input rail, the input voltage at
    which it turns on (rising threshold at its maximum) must be below the
    rail's nominal voltage (the rail at its minimum, when another
    regulator sets it), or the regulator never starts; turning off
    (falling threshold at its minimum) below the regulator's minimum input
    lets it run outside its range (warning). Each result is also listed
    (info)."""
    from .levels import _levels
    sps = _setpoints(ctx)
    lv = _levels(ctx)
    for comp in sorted(ctx.design.components.values(), key=lambda c: natural_key(c.designator)):
        block = ctx.partsdb.regulator(comp.part_number)
        if not block:
            continue
        for pin, vin_net, von, voff, how in turn_on_points(ctx, comp, block):
            up = sps.get(vin_net)
            vin = up[1] if up else ctx.config.net_voltage(vin_net)
            ins = [p for p in comp.pins if p.name in (block.get("input_pins") or [])]
            pl = lv.for_pin(ins[0]) if ins else None
            vmin = None
            if pl is not None:
                for _, char in lv._tables(pl, "supply"):
                    for row in char.get("rows") or []:
                        if isinstance(row.get("min"), (int, float)):
                            vmin = max(vmin or 0.0, float(row["min"]))
            where = (f"{comp.designator} ({comp.part_number}) {pin.name} on '{pin.net}' ({how}): turns on at "
                     f"{von:.3g} V on '{vin_net}'" + (f", off at {voff:.3g} V" if voff is not None else ""))
            refs = [comp.designator]
            if vin is not None and von > vin:
                yield Finding("PWR011", f"{where}, above the rail's {vin:.3g} V", refs=refs, nets=[vin_net, pin.net],
                              part_number=comp.part_number)
            elif vmin is not None and voff is not None and voff < vmin:
                yield Finding("PWR011", f"{where}, below the regulator's {vmin:g} V minimum input",
                              severity=WARNING, refs=refs, nets=[vin_net, pin.net], part_number=comp.part_number)
            else:
                yield Finding("PWR011", where, severity=INFO, refs=refs, nets=[vin_net, pin.net],
                              part_number=comp.part_number)
