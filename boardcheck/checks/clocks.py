"""Clock oscillators and the clock inputs they feed.

Oscillator part data (`part_info.type: oscillator`) gives the frequency
(`part_info.frequency_hz`) and the output pins (function CLOCK_OUT, or
CLOCK_OUT_P / CLOCK_OUT_N for a differential output). Several oscillators
whose outputs reach one signal (directly, or through the small series
resistors that select one of them) are alternate footprints of which only
one is fitted; `parts.alternates` declares other such groups. The export
carries no fitted/not-fitted data, so the alternates are checked against
each other instead: same frequency, same output standard, true output on
the same net.

A net name with a frequency in it (`ETH1_50MHZ_OSC_OUT`, `148.5MHZ_P`)
states what the clock should be. A part whose `clock_inputs` data ties a
clock input's expected frequency to select pins (the VSC8541's
REFCLK_SEL[1:0]) has the select pins' static levels read like straps and
compared with the oscillator that drives the input.
"""

import re

from . import ERROR, INFO, WARNING, Finding, check
from .levels import signals
from .pins import _pin_types
from ..model import natural_key

_OUT = {"CLOCK_OUT", "CLOCK_OUT_P", "CLOCK_OUT_N"}
_FREQ = re.compile(r"(?<![A-Z0-9.])(\d+(?:[.P]\d+)?)\s*([KMG])HZ", re.I)
_SCALE = {"K": 1e3, "M": 1e6, "G": 1e9}


def name_frequency(net):
    """Frequency (Hz) a net name states (`100MHZ_P`, `148P5MHZ`), or None."""
    m = _FREQ.search(net or "")
    if not m:
        return None
    return float(m.group(1).upper().replace("P", ".")) * _SCALE[m.group(2).upper()]


def _mhz(hz):
    return f"{hz / 1e6:g} MHz"


class Oscillator:
    def __init__(self, comp, info, outs):
        self.comp = comp
        self.hz = info.get("frequency_hz")
        self.outs = outs            # {function: pin}

    @property
    def standard(self):
        return "differential" if "CLOCK_OUT_P" in self.outs else "single-ended"

    @property
    def true_net(self):
        pin = self.outs.get("CLOCK_OUT_P") or self.outs.get("CLOCK_OUT")
        return pin.net if pin else None


def oscillators(ctx):
    """{designator: Oscillator} for parts whose part data is an oscillator."""
    if hasattr(ctx, "_oscillators"):
        return ctx._oscillators
    out = {}
    if ctx.partsdb is not None:
        pt = _pin_types(ctx)
        for comp in ctx.design.components.values():
            info = ctx.partsdb.part_info(comp.part_number)
            if info.get("type") != "oscillator":
                continue
            outs = {}
            for p in comp.pins:
                pp = pt.part_entry(p)
                func = pp.entry.get("function") if pp else None
                if func in _OUT and p.net:
                    outs.setdefault(func, p)
            if outs:
                out[comp.designator] = Oscillator(comp, info, outs)
    ctx._oscillators = out
    return out


def alternates(ctx):
    """[[designator, ...]] groups of which only one part is fitted: the
    oscillators driving one signal, and `parts.alternates`."""
    if hasattr(ctx, "_alternates"):
        return ctx._alternates
    parent = {}

    def find(x):
        parent.setdefault(x, x)
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    by_net = {n: s.nets[0] for s in signals(ctx) for n in s.nets}
    first = {}
    for desig, osc in sorted(oscillators(ctx).items(), key=lambda kv: natural_key(kv[0])):
        for pin in osc.outs.values():
            key = by_net.get(pin.net, pin.net)
            if key in first:
                parent[find(desig)] = find(first[key])
            else:
                first[key] = desig
    declared = []
    for group in ctx.config["parts"].get("alternates") or []:
        group = [str(d) for d in group if str(d) in ctx.design.components]
        declared.append(group)
        for d in group[1:]:
            parent[find(d)] = find(group[0])
    groups = {}
    for d in parent:
        groups.setdefault(find(d), []).append(d)
    ctx._alternates = sorted((sorted(g, key=natural_key) for g in groups.values() if len(g) > 1),
                             key=lambda g: natural_key(g[0]))
    ctx._alternates_declared = declared
    return ctx._alternates


def alternate_of(ctx):
    """{designator: first designator of its alternate group}."""
    return {d: g[0] for g in alternates(ctx) for d in g}


def _true_signal(ctx, o):
    """The signal the true output reaches (alternates selected by series
    resistors sit on different nets of one signal); the net itself when the
    pair's halves share a signal (joined by a termination resistor)."""
    by_net = {n: s for s in signals(ctx) for n in s.nets}
    sig = by_net.get(o.true_net)
    comp = o.outs.get("CLOCK_OUT_N")
    if sig is None or (comp is not None and comp.net in sig.nets):
        return o.true_net
    return sig.nets[0]


@check("CLK001", "Oscillators driving one clock (alternate footprints)", INFO, needs_partsdb=True)
def oscillator_alternates(ctx):
    """Oscillators whose outputs reach one signal are taken as alternates,
    one fitted; output contention between them is not reported (PIN004)."""
    osc = oscillators(ctx)
    for group in alternates(ctx):
        if not all(d in osc for d in group):
            continue
        nets = sorted({p.net for d in group for p in osc[d].outs.values()}, key=natural_key)
        yield Finding("CLK001", f"{', '.join(f'{d} ({osc[d].comp.part_number})' for d in group)} all drive "
                                f"{', '.join(repr(n) for n in nets)}: taken as alternate footprints with one fitted",
                      refs=group, nets=nets)


@check("CLK002", "Alternate oscillators differ", ERROR, needs_partsdb=True)
def alternates_differ(ctx):
    """Alternates must be interchangeable: the same frequency, the same
    kind of output, and the true output on the same net."""
    osc = oscillators(ctx)
    for group in alternates(ctx):
        members = [osc[d] for d in group if d in osc]
        if len(members) < 2:
            continue
        refs = [o.comp.designator for o in members]
        if len({o.hz for o in members}) > 1:
            yield Finding("CLK002", "alternate oscillators have different frequencies: "
                          + ", ".join(f"{o.comp.designator} {_mhz(o.hz)}" for o in members if o.hz), refs=refs)
        if len({o.standard for o in members}) > 1:
            yield Finding("CLK002", "alternate oscillators have different outputs: "
                          + ", ".join(f"{o.comp.designator} {o.standard}" for o in members), refs=refs)
        elif len({_true_signal(ctx, o) for o in members}) > 1:
            yield Finding("CLK002", "alternate oscillators put their true output on different nets: "
                          + ", ".join(f"{o.comp.designator} on '{o.true_net}'" for o in members),
                          refs=refs, nets=sorted({o.true_net for o in members}))


@check("CLK003", "Oscillator frequency differs from the net name", ERROR, needs_partsdb=True)
def frequency_vs_name(ctx):
    by_net = {n: s for s in signals(ctx) for n in s.nets}
    for desig, o in sorted(oscillators(ctx).items(), key=lambda kv: natural_key(kv[0])):
        if not o.hz:
            continue
        nets = set()
        for pin in o.outs.values():
            sig = by_net.get(pin.net)
            nets.update(sig.nets if sig else [pin.net])
        wrong = sorted((n for n in nets if name_frequency(n) and abs(name_frequency(n) - o.hz) > 1),
                       key=natural_key)
        if wrong:
            yield Finding("CLK003", f"{desig} ({o.comp.part_number}) runs at {_mhz(o.hz)} but drives "
                                    + ", ".join(f"'{n}' ({_mhz(name_frequency(n))})" for n in wrong),
                          refs=[desig], nets=wrong, part_number=o.comp.part_number)


def _sources(ctx, sig, comp):
    """[(Hz, label)] for what clocks the signal: oscillators on it, else a
    frequency in one of its net names."""
    osc = oscillators(ctx)
    found = []
    for p in sig.pins:
        o = osc.get(p.component.designator)
        if o and p.component is not comp and any(q is p for q in o.outs.values()) and o.hz:
            found.append((o.hz, f"{o.comp.designator} ({o.comp.part_number})"))
    if found:
        return found
    for n in sig.nets:
        hz = name_frequency(n)
        if hz:
            return [(hz, f"the net name '{n}'")]
    return []


@check("CLK004", "Clock input frequency differs from its select pins", ERROR, needs_partsdb=True)
def clock_select(ctx):
    """For each `clock_inputs` entry: the select pins' static levels pick
    an expected frequency; the oscillator on the input (or the frequency
    its net name states) must match it. Select pins whose level cannot be
    read are a warning."""
    from .straps import static_level
    pt = _pin_types(ctx)
    by_net = {n: s for s in signals(ctx) for n in s.nets}
    for comp in sorted(ctx.design.components.values(), key=lambda c: natural_key(c.designator)):
        inputs = ctx.partsdb.clock_inputs(comp.part_number)
        if not inputs:
            continue
        pins = {}
        for p in comp.pins:
            pp = pt.part_entry(p)
            if pp is not None:
                pins.setdefault(pp.key, (p, pp))
        for ci in inputs:
            if ci["pin"] not in pins:
                continue
            clk = pins[ci["pin"]][0]
            sig = by_net.get(clk.net)
            sources = _sources(ctx, sig, comp) if sig else []
            if not sources:
                continue
            words = []
            for key in ci.get("select", []):
                if key not in pins:
                    words.append((key, "unknown"))
                    continue
                sp = static_level(ctx, *pins[key])
                words.append((key, sp.word if not sp.drivers else "driven"))
            levels = ", ".join(f"{k} {w}" for k, w in words)
            if any(w not in ("low", "high") for _, w in words):
                yield Finding("CLK004", f"{comp.designator}.{clk.designator} {ci['pin']}: the select pins' levels "
                                        f"cannot be read ({levels}), so the expected clock is unknown",
                              severity=WARNING, refs=[comp.designator], part_number=comp.part_number)
                continue
            value = "".join("1" if w == "high" else "0" for _, w in words)
            want = (ci.get("frequency_hz") or {}).get(value)
            if want is None:
                continue
            for hz, label in sources:
                if abs(hz - want) > 1:
                    yield Finding("CLK004", f"{comp.designator}.{clk.designator} {ci['pin']} gets {_mhz(hz)} from "
                                            f"{label}, but its select pins ({levels} = {value}) expect "
                                            f"{_mhz(want)}", refs=[comp.designator], nets=list(sig.nets),
                                  part_number=comp.part_number)
