"""Control signals before the FPGAs drive them.

A flash FPGA drives its pins only once its I/Os are active. Before that,
while it powers up, while it is blank, and while it is being programmed,
each pin is high impedance or weakly pulled, as the part data's
`power_up_io` block says. Whatever a regulator enable, reset or chip select
sees in those windows comes from the board's resistors, plus the FPGA's
weak pull (`r_weak_pull_up`) when one is on.

For each FPGA output whose port name marks it as a control signal
(`power_up.control_ports`), each window's level is worked out from the
signal's resistors to rails and ground (the Thevenin voltage, the weak pull
taken at both ends of its range) and compared with the receivers'
thresholds: their VIL/VIH from the part data, or, for receivers without it,
`power_up.assumed_thresholds` fractions of the FPGA bank voltage.
"""

from collections import defaultdict
import re

from . import ERROR, INFO, WARNING, Finding, check
from .levels import _levels, signals
from ..model import natural_key

_NOT_LOADS = {"resistor", "capacitor", "inductor", "ferrite", "testpoint", "mechanical"}


class _Window:
    def __init__(self, state, phases):
        self.state = state          # "hiz" | "weak_pull_up" | "weak_pull_down"
        self.phases = phases        # ["power_up", "programming", ...]

    @property
    def label(self):
        what = {"hiz": "high impedance", "weak_pull_up": "weakly pulled up",
                "weak_pull_down": "weakly pulled down"}.get(self.state, self.state)
        return f"{what} ({', '.join(p.replace('_', ' ') for p in self.phases)})"


def _windows(ctx, component):
    states = ctx.partsdb.power_up_io(component.part_number) if ctx.partsdb else []
    phases = defaultdict(list)
    for s in states:
        if s.get("state") in ("hiz", "weak_pull_up", "weak_pull_down") and s.get("phase") not in phases[s["state"]]:
            phases[s["state"]].append(s.get("phase", "?"))
    order = ["hiz", "weak_pull_up", "weak_pull_down"]
    return [_Window(st, phases[st]) for st in order if st in phases]


def _thevenin(ties):
    """Volts from [(volts, ohms)], or None when nothing ties the signal."""
    if not ties:
        return None
    if any(r == 0 for _, r in ties):
        return next(v for v, r in ties if r == 0)
    g = sum(1.0 / r for _, r in ties)
    return sum(v / r for v, r in ties) / g


class Evaluation:
    """One FPGA control pin's levels across the pre-drive windows."""

    def __init__(self, fpga_desig, pin, port, sig, loads, windows):
        self.fpga = fpga_desig
        self.pin = pin
        self.port = port
        self.signal = sig
        self.loads = loads
        self.windows = windows      # [(window, level word, text)]
        self.thresholds = None      # (vil, vih, assumed)
        self.unknown = []           # resistors with no value

    @property
    def who(self):
        return f"{self.pin.ref} ('{self.port}')"


def evaluate(ctx):
    """[Evaluation] for every FPGA control output that reaches another part."""
    if hasattr(ctx, "_power_up"):
        return ctx._power_up
    out = []
    cfg = ctx.config["power_up"]
    control = re.compile(cfg["control_ports"], re.I)
    lo_frac, hi_frac = cfg["assumed_thresholds"]
    lv = _levels(ctx)
    by_net = {n: s for s in signals(ctx) for n in s.nets}
    for desig in sorted(ctx.fpgas, key=natural_key):
        comp = ctx.design.components.get(desig)
        f = ctx.fpga_for(comp) if comp is not None else None
        if f is None:
            continue
        windows = _windows(ctx, comp)
        if not windows:
            continue
        for pin in sorted(comp.pins, key=lambda p: natural_key(p.designator)):
            c = f.constraint(pin)
            if c is None or f.direction(c) not in ("output", "inout") or not control.search(c.port):
                continue
            sig = by_net.get(pin.net)
            if sig is None:
                continue
            loads = [p for p in sig.pins + sig.external
                     if p.component is not comp and ctx.kind(p.component) not in _NOT_LOADS]
            if not loads:
                continue
            ev = Evaluation(desig, pin, c.port, sig, loads, [])
            ev.unknown = sorted({t[0].designator for t in sig.ties if t[3] is None}, key=natural_key)
            pl = lv.for_pin(pin)
            bank_v = lv.own_supply(pl) if pl else None
            ties = [(t[2], t[3]) for t in sig.ties if t[3] is not None]
            # receiver thresholds
            vils, vihs = [], []
            for p in loads:
                rl = lv.for_pin(p)
                if rl is None:
                    continue
                vil = lv.value(rl, "vil", "max", "low")[0]
                vih = lv.value(rl, "vih", "min", "high")[0]
                if vil is not None and vih is not None:
                    vils.append(vil)
                    vihs.append(vih)
            if vils:
                ev.thresholds = (min(vils), max(vihs), False)
            elif bank_v is not None:
                ev.thresholds = (lo_frac * bank_v, hi_frac * bank_v, True)
            for w in windows:
                if ev.unknown:
                    ev.windows.append((w, "unknown", f"resistor value unknown ({', '.join(ev.unknown)})"))
                    continue
                if w.state == "hiz":
                    ev.windows.append((w, *_classify(ev, [_thevenin(ties)])))
                    continue
                r_lo = lv.value(pl, "r_" + w.state, "min", "low")[0] if pl else None
                r_hi = lv.value(pl, "r_" + w.state, "max", "high")[0] if pl else None
                pull_v = bank_v if w.state == "weak_pull_up" else 0.0
                if r_lo is None or r_hi is None or pull_v is None:
                    ev.windows.append((w, "unknown", f"no {'r_' + w.state} data or bank voltage for {pin.ref}"))
                    continue
                ev.windows.append((w, *_classify(ev, [_thevenin(ties + [(pull_v, r)]) for r in (r_lo, r_hi)])))
            out.append(ev)
    ctx._power_up = out
    return out


def _classify(ev, volts):
    """(word, text) for the level(s) a window can produce: "floating",
    "low", "high", "undefined" or "unknown"."""
    if volts[0] is None:
        return "floating", "floating: nothing pulls it either way"
    if ev.thresholds is None:
        return "unknown", f"{_span(volts)}; no thresholds to judge it against"
    vil, vih, _ = ev.thresholds
    words = {"low" if v <= vil else "high" if v >= vih else "undefined" for v in volts}
    word = words.pop() if len(words) == 1 else "undefined"
    return word, f"{word} at {_span(volts)}"


def _span(volts):
    lo, hi = min(volts), max(volts)
    return f"{lo:.2f} V" if abs(hi - lo) < 0.005 else f"{lo:.2f}-{hi:.2f} V"


def _thresholds_text(ev):
    if ev.thresholds is None:
        return ""
    vil, vih, assumed = ev.thresholds
    src = "assumed, no receiver data" if assumed else "receiver data"
    return f" (low <= {vil:.2f} V, high >= {vih:.2f} V, {src})"


def _loads_text(ev):
    names = sorted({p.ref for p in ev.loads}, key=natural_key)
    return ", ".join(names[:6]) + (" ..." if len(names) > 6 else "")


def _refs(ev):
    return sorted({ev.fpga} | {p.component.designator for p in ev.loads}, key=natural_key)


@check("PWU001", "Control signal floats before the FPGA drives it", ERROR, needs_partsdb=True)
def floating_controls(ctx):
    for ev in evaluate(ctx):
        for w, word, _ in ev.windows:
            if word == "floating":
                yield Finding("PWU001", f"'{ev.signal.name}' from {ev.who} to {_loads_text(ev)} floats while "
                                        f"{ev.fpga} is {w.label}: no resistor holds it", refs=_refs(ev),
                              nets=list(ev.signal.nets))


@check("PWU002", "Control signal between logic levels before the FPGA drives it", ERROR, needs_partsdb=True)
def undefined_controls(ctx):
    for ev in evaluate(ctx):
        for w, word, text in ev.windows:
            if word == "undefined":
                yield Finding("PWU002", f"'{ev.signal.name}' from {ev.who} to {_loads_text(ev)} is {text} while "
                                        f"{ev.fpga} is {w.label}{_thresholds_text(ev)}",
                              severity=WARNING if ev.thresholds and ev.thresholds[2] else ERROR,
                              refs=_refs(ev), nets=list(ev.signal.nets))


@check("PWU003", "Control signal changes level between power-up windows", WARNING, needs_partsdb=True)
def changing_controls(ctx):
    for ev in evaluate(ctx):
        defined = [(w, word) for w, word, _ in ev.windows if word in ("low", "high")]
        if len({word for _, word in defined}) > 1:
            steps = "; ".join(f"{word} while {w.label}" for w, word in defined)
            yield Finding("PWU003", f"'{ev.signal.name}' from {ev.who} to {_loads_text(ev)}: {steps}",
                          refs=_refs(ev), nets=list(ev.signal.nets))


@check("PWU004", "Control signal level not evaluated", INFO, needs_partsdb=True)
def unevaluated_controls(ctx):
    for ev in evaluate(ctx):
        for w, word, text in ev.windows:
            if word == "unknown":
                yield Finding("PWU004", f"'{ev.signal.name}' from {ev.who}: {text} (window: {w.label})",
                              refs=_refs(ev), nets=list(ev.signal.nets))


def power_up_summary(ctx):
    """Rows for the report: (signal, FPGA pin, port, loads, {window label: text})."""
    if ctx.partsdb is None:
        return []
    return [(ev.signal.name, ev.pin.ref, ev.port, _loads_text(ev), [(w.label, text) for w, _, text in ev.windows])
            for ev in evaluate(ctx)]
