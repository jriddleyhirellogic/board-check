"""Configuration straps: pins a part samples at reset to set its mode.

The part data's `straps` block names the pins, the event that latches them
(`latched_by`, normally reset deassertion), what each field's bits mean,
and whether other devices may drive the pins while they are sampled. At
that moment only resistors set the level: the board's, plus the part's own
internal pull on the pin (`internal_bias`, with `r_weak_pull_up/_down` at
both ends of its range when the part data gives it). Each strap pin's
signal (joined through small series resistors, as for the level checks)
is reduced to its Thevenin voltage and compared with the pin's VIL/VIH
from the part data, or `power_up.assumed_thresholds` of its supply when
the part data has none (those findings are warnings).
"""

from . import ERROR, INFO, WARNING, Finding, check
from .levels import _levels, input_thresholds, signals
from .pins import _norm, _pin_types
from .powerup import _thevenin
from ..model import natural_key


class StrapPin:
    def __init__(self, pin, key, volts, word, thresholds, drivers):
        self.pin = pin
        self.key = key              # pin_functions key
        self.volts = volts          # Thevenin level, None when floating
        self.word = word            # "low" | "high" | "undefined" | "floating" | "unknown"
        self.thresholds = thresholds
        self.drivers = drivers      # other parts' outputs on the signal
        self.bias = None            # the part's internal pull on the pin, if any
        self.volts_range = None


def _component_straps(ctx):
    """[(component, straps block, {key: StrapPin})] for parts with strap data."""
    if hasattr(ctx, "_straps"):
        return ctx._straps
    out = []
    if ctx.partsdb is None:
        ctx._straps = out
        return out
    lv = _levels(ctx)
    pt = _pin_types(ctx)
    by_net = {n: s for s in signals(ctx) for n in s.nets}
    lo_frac, hi_frac = ctx.config["power_up"]["assumed_thresholds"]
    for comp in sorted(ctx.design.components.values(), key=lambda c: natural_key(c.designator)):
        block = ctx.partsdb.straps(comp.part_number)
        if not block:
            continue
        keys = {b.get("pin") for f in block.get("fields", []) for b in f.get("bits", [])} - {None}
        pins = {}
        for pin in comp.pins:
            pp = pt.part_entry(pin)
            if pp is None or pp.key not in keys:
                continue
            sig = by_net.get(pin.net)
            pl = lv.for_pin(pin)
            if sig is None:         # tied straight to a rail or ground
                v = ctx.config.net_voltage(pin.net)
                sp = StrapPin(pin, pp.key, v, "unknown" if v is None else None, None, [])
                volts = [v] if v is not None else []
            else:
                unknown = [t for t in sig.ties if t[3] is None]
                ties = [(t[2], t[3]) for t in sig.ties if t[3] is not None]
                drivers = [p for p in sig.pins if p.component is not comp
                           and pt.base(p)[0] in ("output", "io")]
                sp = StrapPin(pin, pp.key, None, "unknown" if unknown else None, None, drivers)
                # The part's own internal pull (pin_functions internal_bias,
                # resistance r_weak_pull_up/_down) holds the pin too.
                bias = pp.internal_bias
                internal = []
                if bias in ("pull_up", "pull_down"):
                    rail = lv.own_supply(pl) if (pl and bias == "pull_up") else 0.0
                    name = "r_weak_" + bias
                    r_lo = lv.value(pl, name, "min", "low")[0] if pl else None
                    r_hi = lv.value(pl, name, "max", "high")[0] if pl else None
                    if rail is not None and r_lo and r_hi:
                        internal = [(rail, r_lo), (rail, r_hi)]
                    elif rail is not None and not ties:
                        internal = [(rail, 1.0)]        # only the internal pull: its rail, value unknown
                if internal:
                    volts = [_thevenin(ties + [t]) for t in internal]
                else:
                    volts = [_thevenin(ties)] if ties else []
                sp.bias = bias
            pins[pp.key] = sp
            sp.volts = min(volts) if volts else None
            sp.volts_range = (min(volts), max(volts)) if volts else None
            vil, vih = input_thresholds(lv, pl)
            if vil is not None and vih is not None:
                sp.thresholds = (vil, vih, False)
            else:
                supply = lv.own_supply(pl) if pl else None
                if supply:
                    sp.thresholds = (lo_frac * supply, hi_frac * supply, True)
            if sp.word is None:
                if not volts:
                    sp.word = "floating"
                elif sp.thresholds is None:
                    sp.word = "unknown"
                else:
                    vil, vih, _ = sp.thresholds
                    words = {"low" if v <= vil else "high" if v >= vih else "undefined" for v in volts}
                    sp.word = words.pop() if len(words) == 1 else "undefined"
        out.append((comp, block, pins))
    ctx._straps = out
    return out


def decode(block, pins):
    """[(field name, value or None, meaning or reason)] for a component."""
    values = {}
    out = []
    for field in block.get("fields", []):
        bits = field.get("bits") or []
        value, missing = 0, []
        for b in bits:
            sp = pins.get(b.get("pin"))
            if sp is None or sp.word not in ("low", "high"):
                missing.append(b.get("pin"))
            elif sp.word == "high":
                value |= 1 << int(b.get("bit", 0))
        when = field.get("when") or {}
        applies = all(str(values.get(k)) == str(v) for k, v in when.items())
        if missing:
            values[field["name"]] = None
            out.append((field["name"], None, f"not defined ({', '.join(missing)})"))
            continue
        values[field["name"]] = value
        if not applies:
            continue
        meaning = (field.get("values") or {}).get(str(value))
        out.append((field["name"], value, meaning or ""))
    return out


def _where(comp, sp):
    return f"{comp.designator}.{sp.pin.designator} {sp.key} on '{sp.pin.net}'"


def _thr(sp):
    if not sp.thresholds:
        return ""
    vil, vih, assumed = sp.thresholds
    return f" (low <= {vil:.2f} V, high >= {vih:.2f} V{', assumed' if assumed else ''})"


@check("STP001", "Strap pin floats at reset", ERROR, needs_partsdb=True)
def floating_straps(ctx):
    for comp, block, pins in _component_straps(ctx):
        for sp in sorted(pins.values(), key=lambda s: natural_key(s.pin.designator)):
            if sp.word == "floating":
                yield Finding("STP001", f"{_where(comp, sp)}: nothing sets its level when "
                                        f"{block.get('latched_by', {}).get('pin', 'reset')} releases",
                              refs=[comp.designator], nets=[sp.pin.net], part_number=comp.part_number)


@check("STP002", "Strap pin between logic levels at reset", ERROR, needs_partsdb=True)
def undefined_straps(ctx):
    for comp, block, pins in _component_straps(ctx):
        for sp in sorted(pins.values(), key=lambda s: natural_key(s.pin.designator)):
            if sp.word == "undefined":
                lo, hi = sp.volts_range
                at = f"{lo:.2f} V" if hi - lo < 0.005 else f"{lo:.2f}-{hi:.2f} V"
                yield Finding("STP002", f"{_where(comp, sp)} sits at {at}{_thr(sp)}"
                                        + (f" (with its internal {sp.bias.replace('_', '-')})" if sp.bias else ""),
                              severity=WARNING if sp.thresholds[2] else ERROR,
                              refs=[comp.designator], nets=[sp.pin.net], part_number=comp.part_number)


@check("STP003", "Strap pin driven by another part", ERROR, needs_partsdb=True)
def driven_straps(ctx):
    """The data sheet says other devices must not drive strap pins while
    they are sampled; an output or bidirectional pin on the same signal
    can."""
    for comp, block, pins in _component_straps(ctx):
        if not block.get("must_not_be_driven"):
            continue
        for sp in sorted(pins.values(), key=lambda s: natural_key(s.pin.designator)):
            if sp.drivers:
                yield Finding("STP003", f"{_where(comp, sp)} is also driven by "
                                        f"{', '.join(p.ref for p in sp.drivers)}; it must not be driven while "
                                        "the strap is sampled",
                              refs=sorted({comp.designator} | {p.component.designator for p in sp.drivers},
                                          key=natural_key), nets=[sp.pin.net], part_number=comp.part_number)


@check("STP004", "Strapped configuration", INFO, needs_partsdb=True)
def strapped_configuration(ctx):
    for comp, block, pins in _component_straps(ctx):
        parts = []
        for name, value, meaning in decode(block, pins):
            parts.append(f"{name} = {'?' if value is None else value}" + (f" ({meaning})" if meaning else ""))
        if parts:
            yield Finding("STP004", f"{comp.designator} ({comp.part_number}): " + "; ".join(parts),
                          refs=[comp.designator], part_number=comp.part_number)
