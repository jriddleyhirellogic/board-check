"""Pin electrical type checks: type verification, contention, floating inputs.

Two sources describe what a pin does:

- the part data: `pin_functions` in electronic-parts-repository, written
  from the datasheet. This is the reference.
- the schematic symbol's pin type (export script >= 2.3.0). Designers set
  these by hand and they are often wrong, so they are a claim to verify.

A third source covers programmable pins: for an FPGA configured under
`fpga`, the FPGA project's constraint files assign each port to a pin and
set its pull, and the design's top-level port declarations (or, without
them, the constraints) set its direction. They take precedence over both,
because they are what the bitstream does.

Every check resolves a pin's type from the constraints, then the part
data, and falls back to the symbol only when neither covers the pin.
Findings built on symbol-only types are marked "schematic only" and held to
warning; the same finding backed by part data or constraints is an error.
"""

import re
from dataclasses import dataclass

from . import ERROR, INFO, WARNING, Finding, check
from ..model import natural_key

PART, CONSTRAINTS, SCHEMATIC, KIND = "part", "constraints", "schematic only", "kind"
_CONSTRAINT_TYPES = {"input": "input", "output": "output", "inout": "io"}

# Kinds that have no active pins; their pins count as passive when neither
# source says otherwise.
_PASSIVE_KINDS = {"capacitor", "resistor", "inductor", "ferrite", "crystal", "fuse", "testpoint",
                  "mechanical", "transformer", "switch"}
# Kinds whose pins lead off the board: whatever is on the other side may
# drive the net.
_EXTERNAL_KINDS = {"connector"}


def _norm(name):
    """Comparable pin name. Altium draws an overbar as a backslash after each
    character ("C\\E\\"); an overbarred name keeps a trailing "#" so that
    "G" and "G\\" stay different pins and "CE#" still matches "C\\E\\"."""
    name = str(name).strip().upper()
    if "\\" in name:
        name = name.replace("\\", "").rstrip("#") + "#"
    return name


@dataclass
class PartPin:
    """One pin_functions entry."""
    key: str                 # key as written, e.g. "1\\O\\E\\"
    direction: str           # direction word as written
    mapped: str              # schematic-vocabulary type, None if unrecognised
    entry: dict

    @property
    def numbers(self):
        return [str(n) for n in self.entry.get("pins", [])]

    @property
    def three_state(self):
        return self.entry.get("three_state")

    @property
    def internal_bias(self):
        return self.entry.get("internal_bias")

    @property
    def per_bank(self):
        """One supply per I/O bank, named on the symbol with the bank number
        appended ("VDDI" -> VDDI0, VDDI1, ...)."""
        return bool(self.entry.get("per_bank"))

    def names_bank_pin(self, pin_name):
        return self.per_bank and re.fullmatch(re.escape(_norm(self.key)) + r"\d+", _norm(pin_name)) is not None


class PinTypes:
    """Resolves each pin's type, remembering where it came from."""

    def __init__(self, ctx):
        self.ctx = ctx
        self.dmap = ctx.config["pins"]["direction_map"]
        self._tables = {}

    def table(self, part_number):
        """{"by_name": {norm key: PartPin}, "by_number": {pin: PartPin},
        "entries": [PartPin]}, or None when the part has no pin data.
        Underscore keys (_source, _note, ...) are annotations, not pins."""
        if part_number not in self._tables:
            raw = self.ctx.partsdb.pin_functions(part_number) if self.ctx.partsdb else None
            table = None
            if raw:
                table = {"by_name": {}, "by_number": {}, "entries": [], "per_bank": []}
                for key, entry in raw.items():
                    if str(key).startswith("_"):
                        continue
                    entry = entry if isinstance(entry, dict) else {"direction": entry}
                    direction = entry.get("direction")
                    pp = PartPin(key, direction, self.dmap.get(str(direction or "").strip().lower()), entry)
                    table["entries"].append(pp)
                    table["by_name"][_norm(key)] = pp
                    if pp.per_bank:
                        table["per_bank"].append(pp)
                    for n in pp.numbers:
                        table["by_number"][n] = pp
            self._tables[part_number] = table
        return self._tables[part_number]

    def part_entry(self, pin):
        table = self.table(pin.component.part_number)
        if not table:
            return None
        # Name first (the parts repo keys by name), then package pin number,
        # then a key that is itself a pin number.
        found = (table["by_name"].get(_norm(pin.name)) or table["by_number"].get(str(pin.designator))
                 or table["by_name"].get(_norm(pin.designator)))
        if found is None:
            found = next((pp for pp in table["per_bank"] if pp.names_bank_pin(pin.name)), None)
        return found

    @staticmethod
    def schematic(pin):
        e = pin.electrical
        return e if e and not e.startswith("unknown") else None

    def constraint(self, pin):
        """The FPGA constraint for this pin, or None."""
        fpga = self.ctx.fpga_for(pin.component)
        return fpga.constraint(pin) if fpga else None

    def base(self, pin):
        """(type, source) ignoring 3-state enables."""
        c = self.constraint(pin)
        if c is not None and self.ctx.io_standard_info(pin.component, c.io_std).get("tie_to") == "ground":
            return "power", CONSTRAINTS     # a soft ground (e.g. PolarFire SHIELD12)
        if c is not None:
            direction = self.ctx.fpga_for(pin.component).direction(c)
            if direction in _CONSTRAINT_TYPES:
                return _CONSTRAINT_TYPES[direction], CONSTRAINTS
        pp = self.part_entry(pin)
        if pp and pp.mapped:
            return pp.mapped, PART
        sch = self.schematic(pin)
        if sch:
            return sch, SCHEMATIC
        kind = self.ctx.kind(pin.component)
        if kind in _PASSIVE_KINDS:
            return "passive", KIND
        if kind in _EXTERNAL_KINDS:
            return "external", KIND
        return None, None

    def effective(self, pin):
        """(type, source) with source PART, SCHEMATIC or KIND; (None, None)
        when nothing is known. A 3-state output counts as "output" only when
        its enable is strapped active; otherwise it is "hiz"."""
        ptype, source = self.base(pin)
        if ptype == "output" and source == PART:
            ts = self.part_entry(pin).three_state
            if ts and not self.always_enabled(pin.component, ts):
                return "hiz", PART
        return ptype, source

    def internal_bias(self, pin):
        c = self.constraint(pin)
        if c is not None and c.pull:
            return c.pull
        pp = self.part_entry(pin)
        return pp.internal_bias if pp else None

    def always_enabled(self, component, three_state):
        terms = three_state.get("enable") or []
        if not terms:
            return True
        hits = []
        for term in terms:
            pin = self._pin_named(component, term.get("pin", ""))
            hits.append(pin is not None and self.static_level(pin.net) == term.get("active"))
        return all(hits) if three_state.get("logic") == "all" else any(hits)

    def _pin_named(self, component, key):
        for p in component.pins:
            if _norm(p.name) == _norm(key):
                return p
        pp = (self.table(component.part_number) or {}).get("by_name", {}).get(_norm(key))
        for p in component.pins:
            if pp and str(p.designator) in pp.numbers:
                return p
        return None

    def static_level(self, net_name):
        """"high" or "low" when a net is tied to a rail or ground, directly or
        through resistors, with nothing else but inputs on it; else None."""
        cfg = self.ctx.config
        if cfg.is_ground(net_name):
            return "low"
        if cfg.is_rail(net_name):
            return "high"
        net = self.ctx.design.nets.get(net_name)
        if net is None:
            return None
        levels = set()
        for p in net.pins:
            comp = p.component
            if self.ctx.kind(comp) == "resistor" and len(comp.pins) == 2:
                other = [q.net for q in comp.pins if q is not p][0]
                if cfg.is_ground(other):
                    levels.add("low")
                elif cfg.is_rail(other):
                    levels.add("high")
                else:
                    return None
            elif self.base(p)[0] != "input":
                return None
        return levels.pop() if len(levels) == 1 else None


def _pin_types(ctx):
    if not hasattr(ctx, "_pin_types"):
        ctx._pin_types = PinTypes(ctx)
    return ctx._pin_types


def _label(pin, ptype, source):
    name = f" {pin.name}" if pin.name and pin.name != pin.designator else ""
    tag = "" if source == PART else f", {source}"
    return f"{pin.ref}{name} ({ptype}{tag})"


def _severity(sources):
    return ERROR if all(s in (PART, CONSTRAINTS) for s in sources) else WARNING


def _nets(ctx):
    for net in sorted(ctx.design.nets.values(), key=lambda n: n.name):
        pins = [p for p in net.pins if not ctx.config.is_mechanical(p.component)]
        if pins:
            yield net, pins


def _types_agree(pp, sch):
    """Whether a symbol pin type is an acceptable drawing of the part data.
    Altium's HiZ type is its 3-state output; it has no no-connect type."""
    if pp.mapped == sch:
        return True
    if pp.mapped == "output" and pp.three_state and sch == "hiz":
        return True
    return pp.mapped == "nc" and sch == "passive"


@check("PIN001", "Schematic pin type disagrees with part data", WARNING,
       needs_partsdb=True, needs_pin_types=True)
def schematic_vs_part(ctx):
    pt = _pin_types(ctx)
    for comp in sorted(ctx.design.components.values(), key=lambda c: natural_key(c.designator)):
        diffs = []
        for pin in sorted(comp.pins, key=lambda p: natural_key(p.designator)):
            pp, sch = pt.part_entry(pin), pt.schematic(pin)
            if pp and pp.mapped and sch and not _types_agree(pp, sch):
                name = f" {pin.name}" if pin.name and pin.name != pin.designator else ""
                diffs.append(f"{pin.designator}{name}: symbol {sch}, part data {pp.direction}"
                             + (" (3-state)" if pp.three_state else ""))
        if diffs:
            shown = diffs[:12] + ([f"... {len(diffs) - 12} more"] if len(diffs) > 12 else [])
            yield Finding("PIN001", f"{comp.designator} ({comp.part_number}): " + "; ".join(shown),
                          refs=[comp.designator], part_number=comp.part_number)


@check("PIN002", "Part has no pin data; symbol pin types unverified", INFO, needs_partsdb=True)
def missing_pin_data(ctx):
    pt = _pin_types(ctx)
    kinds = set(ctx.config["pins"]["verify_kinds"])
    for pn, comps in sorted(ctx.design.components_by_part_number().items()):
        comps = [c for c in comps if ctx.kind(c) in kinds]
        if comps and not pt.table(pn):
            refs = sorted((c.designator for c in comps), key=natural_key)
            yield Finding("PIN002", f"{pn} has no pin_functions in electronic-parts-repository; "
                                    f"{', '.join(refs)} {'relies' if len(refs) == 1 else 'rely'} on the symbol's pin types",
                          refs=refs, part_number=pn or None)


@check("PIN003", "Part pin data does not line up with the symbol", WARNING, needs_partsdb=True)
def pin_data_alignment(ctx):
    pt = _pin_types(ctx)
    for pn, comps in sorted(ctx.design.components_by_part_number().items()):
        table = pt.table(pn)
        if not table:
            continue
        names, numbers = set(), set()
        misnumbered = set()
        for c in comps:
            for p in c.pins:
                names.add(_norm(p.name))
                numbers.add(str(p.designator))
                pp = table["by_name"].get(_norm(p.name))
                if pp and pp.numbers and str(p.designator) not in pp.numbers:
                    misnumbered.add(f"{p.name} is pin {p.designator} on the symbol, "
                                    f"{'/'.join(pp.numbers)} in the part data")
        unmatched = sorted(pp.key for pp in table["entries"]
                           if not (not pp.numbers and "pins" not in pp.entry
                                   and pp.entry.get("function") in ("GROUND", "THERMAL_PAD"))   # unnumbered pad
                           and _norm(pp.key) not in names and not set(pp.numbers) & numbers
                           and _norm(pp.key) not in numbers
                           and not any(pp.names_bank_pin(n) for n in names))
        unknown = sorted({str(pp.direction) for pp in table["entries"] if pp.mapped is None})
        problems = []
        if misnumbered:
            problems.append("pin numbers differ: " + "; ".join(sorted(misnumbered)))
        if unmatched:
            problems.append("pin_functions entries matching no pin on the symbol: " + ", ".join(unmatched))
        if unknown:
            problems.append("unrecognised direction value(s): " + ", ".join(unknown)
                            + " (add to pins.direction_map)")
        if problems:
            yield Finding("PIN003", f"{pn}: " + "; ".join(problems),
                          refs=sorted((c.designator for c in comps), key=natural_key), part_number=pn)


@check("PIN004", "Output contention", ERROR)
def contention(ctx):
    """Two push-pull outputs on one net, or a push-pull output on a supply
    rail or ground net. Tri-state and bidirectional pins are not counted:
    whether they fight depends on firmware and FPGA configuration. Outputs
    on different nets joined by small series resistors are a warning."""
    pt = _pin_types(ctx)
    cfg = ctx.config

    def one_per_function(outs):
        """A part's output split over several pins (one pin_functions entry,
        or one pin name) is one driver."""
        seen, kept = set(), []
        for o in outs:
            pp = pt.part_entry(o[0])
            key = (o[0].component.designator, pp.key if pp else o[0].name)
            if key not in seen:
                seen.add(key)
                kept.append(o)
        return kept

    for net, pins in _nets(ctx):
        typed = [(p, *pt.effective(p)) for p in pins]
        outputs = one_per_function([(p, t, s) for p, t, s in typed if t == "output"])
        if len(outputs) >= 2:
            yield Finding("PIN004", f"'{net.name}' is driven by {len(outputs)} outputs: "
                          + ", ".join(_label(*o) for o in outputs),
                          severity=_severity([s for _, _, s in outputs]),
                          refs=sorted({p.component.designator for p, _, _ in outputs}), nets=[net.name])
        elif outputs and (cfg.is_ground(net.name) or cfg.is_rail(net.name)):
            yield Finding("PIN004", f"output on supply net '{net.name}': " + ", ".join(_label(*o) for o in outputs),
                          severity=_severity([s for _, _, s in outputs]),
                          refs=sorted({p.component.designator for p, _, _ in outputs}), nets=[net.name])
    # Outputs on different nets of one signal (joined by small series
    # resistors, levels.series_max_ohms) still fight, through the resistor.
    from .levels import signals
    for sig in signals(ctx):
        if len(sig.nets) < 2:
            continue
        outputs = [(p, *pt.effective(p)) for p in sig.pins if not cfg.is_mechanical(p.component)]
        outputs = one_per_function([o for o in outputs if o[1] == "output"])
        # Two outputs of one part joined through a resistor are a
        # termination (a differential pair's), not contention.
        if len({o[0].component.designator for o in outputs}) >= 2 and len({o[0].net for o in outputs}) > 1:
            yield Finding("PIN004", f"'{sig.name}' is driven by {len(outputs)} outputs through series resistors: "
                          + ", ".join(_label(*o) for o in outputs),
                          severity=WARNING, refs=sorted({p.component.designator for p, _, _ in outputs}),
                          nets=list(sig.nets))


@check("PIN005", "Input with nothing to drive it", WARNING)
def floating_inputs(ctx):
    """Every pin on the net is an input (an unconnected input pin included).
    A net with any pin of unknown type is skipped: that pin may drive it.
    So is a net where the part data gives an input an internal pull or
    fail-safe bias: it has a defined level."""
    pt = _pin_types(ctx)
    cfg = ctx.config
    for net, pins in _nets(ctx):
        if cfg.is_ground(net.name) or cfg.net_voltage(net.name) is not None:
            continue  # tied to a supply, ground or sense node
        typed = [(p, *pt.effective(p)) for p in pins]
        if all(t == "input" for _, t, _ in typed) and not any(pt.internal_bias(p) for p in pins):
            yield Finding("PIN005", f"'{net.name}' has only inputs: " + ", ".join(_label(*x) for x in typed[:8])
                          + (f", ... {len(typed) - 8} more" if len(typed) > 8 else ""),
                          severity=_severity([s for _, _, s in typed]),
                          refs=sorted({p.component.designator for p in pins}), nets=[net.name])


@check("PIN006", "Open-drain net without pull-up", WARNING)
def open_drain_pullups(ctx):
    pt = _pin_types(ctx)
    cfg = ctx.config
    for net, pins in _nets(ctx):
        if cfg.is_ground(net.name) or cfg.is_rail(net.name):
            continue
        od = [(p, t, s) for p, t, s in ((p, *pt.effective(p)) for p in pins) if t == "open_collector"]
        if not od:
            continue
        pulled = any(
            ctx.kind(c) == "resistor" and len(c.pins) == 2
            and any(cfg.is_rail(p.net) for p in c.pins if p.net != net.name)
            for c in net.components())
        if not pulled:
            yield Finding("PIN006", f"'{net.name}' has open-drain pin(s) {', '.join(_label(*o) for o in od)} "
                                    "and no resistor to a supply rail",
                          refs=sorted({p.component.designator for p, _, _ in od}), nets=[net.name])
