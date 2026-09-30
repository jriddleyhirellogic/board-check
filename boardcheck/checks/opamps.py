"""Op-amp and comparator DC operating points.

Each op-amp or comparator input (pins whose part data function is
OPAMP_IN_P/N or COMPARATOR_IN_P/N) is traced through the resistor and op-amp
network around it (see analog.py) and the network solved at its nominal
operating point: rails at their nominal voltages, ground at 0 V, no current
in any shunt. The input's voltage is compared with the part's common-mode
range (`vi_op`) and absolute maximum (`vi_abs`); each op-amp output's
voltage with its guaranteed swing (`voh` minimum, `vol` maximum). Networks
also driven by something other than resistors, rails and op-amps (another
part's output, a connector, a diode) have no fixed operating point and are
reported as not evaluated.

The output swing rows may carry a `load_resistance` condition (the data
sheet's RL to midsupply). The load is taken as the current the output
drives at the operating point, as the resistance that would draw it from
half the supply; the most favourable row that load satisfies applies, or
the least favourable row when it satisfies none.
"""

import re

from . import ERROR, INFO, WARNING, Finding, check
from .levels import _levels
from .pins import _pin_types
from ..analog import Network, operating_point
from ..model import natural_key

_INPUTS = {"OPAMP_IN_P", "OPAMP_IN_N", "COMPARATOR_IN_P", "COMPARATOR_IN_N"}


class InputPoint:
    def __init__(self, pin, key, volts, why=None):
        self.pin = pin
        self.key = key              # pin_functions key
        self.volts = volts          # None when not evaluated
        self.why = why              # reason when not evaluated


class OutputPoint:
    def __init__(self, pin, key, volts, load_ohms):
        self.pin = pin
        self.key = key
        self.volts = volts
        self.load_ohms = load_ohms  # None: no load current


def _network(ctx, cache, net):
    if net not in cache:
        nw = Network(ctx, net)
        sol = operating_point(nw) if nw.ok and not nw.unknown else None
        cache[net] = (nw, sol)
    return cache[net]


def _why(nw):
    if not nw.ok:
        return "a resistor value is unknown or the network is too large"
    if nw.unknown:
        who = sorted({p.ref for p in nw.unknown}, key=natural_key)
        return "also driven by " + ", ".join(who[:4]) + (" ..." if len(who) > 4 else "")
    return "the network has no unique solution (an op-amp without feedback?)"


def evaluate(ctx):
    """{component designator: ([InputPoint], [OutputPoint])} for parts with
    op-amp or comparator input pins in their part data."""
    if hasattr(ctx, "_opamp_points"):
        return ctx._opamp_points
    out = {}
    if ctx.partsdb is None:
        ctx._opamp_points = out
        return out
    pt = _pin_types(ctx)
    cache = {}
    for comp in sorted(ctx.design.components.values(), key=lambda c: natural_key(c.designator)):
        entries = [(p, pt.part_entry(p)) for p in comp.pins]
        ins = [(p, pp) for p, pp in entries if pp and pp.entry.get("function") in _INPUTS]
        if not ins:
            continue
        inputs, outputs = [], []
        for p, pp in sorted(ins, key=lambda x: natural_key(x[0].designator)):
            fixed = ctx.config.net_voltage(p.net)
            if ctx.config.is_ground(p.net):
                fixed = 0.0
            if fixed is not None:
                inputs.append(InputPoint(p, pp.key, fixed))
                continue
            nw, sol = _network(ctx, cache, p.net)
            if sol is None or p.net not in sol:
                inputs.append(InputPoint(p, pp.key, None, _why(nw)))
                continue
            inputs.append(InputPoint(p, pp.key, sol[p.net]))
            for onet, opin in nw.outputs.items():
                if opin.component is not comp or onet not in sol \
                        or any(o.pin is opin for o in outputs):
                    continue
                opp = pt.part_entry(opin)
                amps = sum((sol[onet] - sol.get(b if a == onet else a, 0.0)) / r
                           for a, b, r, _ in nw.edges if onet in (a, b))
                outputs.append(OutputPoint(opin, opp.key if opp else opin.name, sol[onet],
                                           None if abs(amps) < 1e-9 else amps))
        out[comp.designator] = (inputs, outputs)
    ctx._opamp_points = out
    return out


def _range(lv, pl, name):
    lo = lv.value(pl, name, "min", "high")[0]
    hi = lv.value(pl, name, "max", "low")[0]
    return lo, hi


def _fmt(lo, hi):
    return f"{'-' if lo is None else f'{lo:.3g}'} to {'-' if hi is None else f'{hi:.3g}'} V"


def _channel(key):
    """Channel of an op-amp or comparator pin key: "+IN A" -> "A", "IN4-" -> "4"."""
    return re.sub(r"IN|OUT|[+\-\s]", "", key.upper())


def _outside(lv, pl, v):
    """(limit text, beyond absolute maximum?) when v is outside the input's
    range, else None."""
    alo, ahi = _range(lv, pl, "vi_abs")
    if (alo is not None and v < alo - 1e-6) or (ahi is not None and v > ahi + 1e-6):
        return f"beyond its absolute maximum rating ({_fmt(alo, ahi)})", True
    lo, hi = _range(lv, pl, "vi_op")
    if (lo is not None and v < lo - 1e-6) or (hi is not None and v > hi + 1e-6):
        return f"outside its common-mode range ({_fmt(lo, hi)})", False
    return None


def _either_input(lv, pl):
    return any(char.get("either_input") for _, char in lv._tables(pl, "vi_op"))


@check("ANA001", "Op-amp or comparator input outside its common-mode range", ERROR, needs_partsdb=True)
def input_range(ctx):
    """An input beyond its absolute maximum is always an error. Outside the
    common-mode range: an error for an op-amp; for a comparator whose part
    data marks `vi_op` with `either_input` (its output stays correct while
    one input of the channel is in range), an error only when both inputs
    of the channel are out of range, a warning when the other input's
    level is not known."""
    lv = _levels(ctx)
    for desig, (inputs, _) in evaluate(ctx).items():
        by_channel = {}
        for ip in inputs:
            by_channel.setdefault(_channel(ip.key), []).append(ip)
        for ch, ips in sorted(by_channel.items()):
            states = []
            for ip in ips:
                pl = lv.for_pin(ip.pin)
                states.append((ip, pl, _outside(lv, pl, ip.volts) if pl and ip.volts is not None else None))
            both = [(ip, pl, out) for ip, pl, out in states if out and not out[1]]
            if len(both) > 1 and len(both) == len(states):
                comp = both[0][0].pin.component
                parts = " and ".join(f"{ip.key} on '{ip.pin.net}' at {ip.volts:.3g} V" for ip, _, _ in both)
                either = _either_input(lv, both[0][1])
                yield Finding("ANA001", f"{desig} channel {ch}: {parts} are both {both[0][2][0]} at the nominal "
                                        "operating point" + (", so the comparator's output is indeterminate"
                                                             if either else ""),
                              refs=[desig], nets=[ip.pin.net for ip, _, _ in both], part_number=comp.part_number)
                continue
            for ip, pl, out in states:
                if out is None:
                    continue
                text, absolute = out
                where = f"{ip.pin.ref} {ip.key} on '{ip.pin.net}' sits at {ip.volts:.3g} V at its nominal operating point"
                severity = None
                if not absolute and _either_input(lv, pl):
                    others = [(o, oout) for o, _, oout in states if o is not ip]
                    if any(o.volts is not None and oout is None for o, oout in others):
                        continue            # the other input is in range: the output is still correct
                    unknown = [o for o, _ in others if o.volts is None]
                    severity = WARNING
                    text += (f"; the output is correct only while {', '.join(o.key for o in unknown) or 'the other input'} "
                             "is within range, and its level is not evaluated")
                yield Finding("ANA001", f"{where}, {text}", severity=severity,
                              refs=[desig], nets=[ip.pin.net], part_number=ip.pin.component.part_number)


def _swing(lv, pl, name, side, load_ohms, vcc, vee):
    """The limit of `name` for this load: (volts, applied row's RL or None)."""
    rows = []
    for _, char in lv._tables(pl, name):
        for row in char.get("rows") or []:
            if side in row and not lv._row_ok(pl, row):
                rl = ((row.get("conditions") or {}).get("load_resistance") or {}).get("min")
                v = lv._limit(pl, row[side])
                if v is not None:
                    rows.append((v, rl))
    if not rows:
        return None, None
    fits = [r for r in rows if r[1] is None or load_ohms is None or load_ohms >= r[1]]
    best_first = side == "min"      # voh: a higher minimum is more favourable
    if fits:
        return sorted(fits, key=lambda r: r[0], reverse=best_first)[0]
    return sorted(rows, key=lambda r: r[0], reverse=not best_first)[0]


@check("ANA002", "Op-amp output beyond its guaranteed swing", WARNING, needs_partsdb=True)
def output_swing(ctx):
    """At the nominal operating point the output must sit within the
    output's guaranteed swing; beyond it the amplifier is saturated and the
    circuit does not do what its resistors say."""
    lv = _levels(ctx)
    for desig, (_, outputs) in evaluate(ctx).items():
        for op in outputs:
            pl = lv.for_pin(op.pin)
            if pl is None:
                continue
            vcc = lv.supply_volts(pl, "VCC")
            vee = lv.supply_volts(pl, "VEE") or 0.0
            load = abs((vcc - vee) / 2 / op.load_ohms) if (op.load_ohms and vcc is not None) else None
            hi, rl_hi = _swing(lv, pl, "voh", "min", load, vcc, vee)
            lo, rl_lo = _swing(lv, pl, "vol", "max", load, vcc, vee)
            v = op.volts
            for bad, limit, rl, word in ((hi is not None and v > hi + 1e-6, hi, rl_hi, "above the highest"),
                                         (lo is not None and v < lo - 1e-6, lo, rl_lo, "below the lowest")):
                if bad:
                    load_txt = f", {load / 1000:.3g} kOhm effective load" if load else ", no DC load"
                    yield Finding("ANA002", f"{op.pin.ref} {op.key} on '{op.pin.net}' sits at {v:.3g} V at its nominal "
                                            f"operating point, {word} level it is guaranteed to reach ({limit:.3g} V"
                                            + (f", RL >= {rl / 1000:g} kOhm" if rl else "") + f"{load_txt})",
                                  refs=[desig], nets=[op.pin.net], part_number=op.pin.component.part_number)


@check("ANA003", "Op-amp or comparator input operating point not evaluated", INFO, needs_partsdb=True)
def not_evaluated(ctx):
    for desig, (inputs, _) in evaluate(ctx).items():
        skipped = [ip for ip in inputs if ip.volts is None]
        if skipped:
            yield Finding("ANA003", f"{desig}: " + "; ".join(f"{ip.key} on '{ip.pin.net}': {ip.why}" for ip in skipped),
                          refs=[desig], part_number=skipped[0].pin.component.part_number)


def operating_points(ctx):
    """Report rows: (designator, pin, net, volts or reason)."""
    rows = []
    for desig, (inputs, outputs) in evaluate(ctx).items():
        for ip in inputs:
            rows.append((desig, ip.key, ip.pin.net, f"{ip.volts:.3g} V" if ip.volts is not None else ip.why))
        for op in outputs:
            rows.append((desig, op.key, op.pin.net, f"{op.volts:.3g} V"))
    return rows
