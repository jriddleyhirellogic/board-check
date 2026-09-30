"""Pin electrical type checks: type verification, contention, floating inputs.

Two sources describe what a pin does:

- the part data: `pin_functions` in electronic-parts-repository, written
  from the datasheet. This is the reference.
- the schematic symbol's pin type (export script >= 2.3.0). Designers set
  these by hand and they are often wrong, so they are a claim to verify.

Every check resolves a pin's type from the part data first and falls back
to the symbol only when the part has no entry for it. Findings built on
symbol-only types are marked "schematic only" and held to warning; the
same finding backed by part data is an error.
"""

from . import ERROR, INFO, WARNING, Finding, check
from ..model import natural_key

PART, SCHEMATIC, KIND = "part", "schematic only", "kind"

# Kinds that have no active pins; their pins count as passive when neither
# source says otherwise.
_PASSIVE_KINDS = {"capacitor", "resistor", "inductor", "ferrite", "crystal", "fuse", "testpoint",
                  "mechanical", "transformer", "switch"}
# Kinds whose pins lead off the board: whatever is on the other side may
# drive the net.
_EXTERNAL_KINDS = {"connector"}


def _norm(name):
    return str(name).replace("\\", "").strip().upper()


class PinTypes:
    """Resolves each pin's type, remembering where it came from."""

    def __init__(self, ctx):
        self.ctx = ctx
        self.dmap = ctx.config["pins"]["direction_map"]
        self._tables = {}

    def table(self, part_number):
        """{normalised key: (raw key, raw direction, mapped type or None)}."""
        if part_number not in self._tables:
            raw = self.ctx.partsdb.pin_functions(part_number) if self.ctx.partsdb else None
            table = None
            if raw:
                table = {}
                for key, entry in raw.items():
                    direction = entry.get("direction") if isinstance(entry, dict) else entry
                    mapped = self.dmap.get(str(direction or "").strip().lower())
                    table[_norm(key)] = (key, direction, mapped)
            self._tables[part_number] = table
        return self._tables[part_number]

    def part_entry(self, pin):
        table = self.table(pin.component.part_number)
        if not table:
            return None
        # Name first (the parts repo keys by name), then pin number.
        return table.get(_norm(pin.name)) or table.get(_norm(pin.designator))

    @staticmethod
    def schematic(pin):
        e = pin.electrical
        return e if e and not e.startswith("unknown") else None

    def effective(self, pin):
        """(type, source) with source PART, SCHEMATIC or KIND; (None, None)
        when nothing is known."""
        entry = self.part_entry(pin)
        if entry and entry[2]:
            return entry[2], PART
        sch = self.schematic(pin)
        if sch:
            return sch, SCHEMATIC
        kind = self.ctx.kind(pin.component)
        if kind in _PASSIVE_KINDS:
            return "passive", KIND
        if kind in _EXTERNAL_KINDS:
            return "external", KIND
        return None, None


def _pin_types(ctx):
    if not hasattr(ctx, "_pin_types"):
        ctx._pin_types = PinTypes(ctx)
    return ctx._pin_types


def _label(pin, ptype, source):
    name = f" {pin.name}" if pin.name and pin.name != pin.designator else ""
    tag = "" if source == PART else f", {source}"
    return f"{pin.ref}{name} ({ptype}{tag})"


def _severity(sources):
    return ERROR if all(s == PART for s in sources) else WARNING


def _nets(ctx):
    for net in sorted(ctx.design.nets.values(), key=lambda n: n.name):
        pins = [p for p in net.pins if not ctx.config.is_mechanical(p.component)]
        if pins:
            yield net, pins


@check("PIN001", "Schematic pin type disagrees with part data", WARNING,
       needs_partsdb=True, needs_pin_types=True)
def schematic_vs_part(ctx):
    pt = _pin_types(ctx)
    for comp in sorted(ctx.design.components.values(), key=lambda c: natural_key(c.designator)):
        diffs = []
        for pin in sorted(comp.pins, key=lambda p: natural_key(p.designator)):
            entry, sch = pt.part_entry(pin), pt.schematic(pin)
            if entry and entry[2] and sch and entry[2] != sch:
                name = f" {pin.name}" if pin.name and pin.name != pin.designator else ""
                diffs.append(f"{pin.designator}{name}: symbol {sch}, part data {entry[1]}")
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
        on_symbol = set()
        for c in comps:
            for p in c.pins:
                on_symbol.update((_norm(p.name), _norm(p.designator)))
        unmatched = sorted(raw for key, (raw, _, _) in table.items() if key not in on_symbol)
        unknown = sorted({str(d) for _, d, m in table.values() if m is None})
        problems = []
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
    whether they fight depends on firmware and FPGA configuration."""
    pt = _pin_types(ctx)
    cfg = ctx.config
    for net, pins in _nets(ctx):
        typed = [(p, *pt.effective(p)) for p in pins]
        outputs = [(p, t, s) for p, t, s in typed if t == "output"]
        if len(outputs) >= 2:
            yield Finding("PIN004", f"'{net.name}' is driven by {len(outputs)} outputs: "
                          + ", ".join(_label(*o) for o in outputs),
                          severity=_severity([s for _, _, s in outputs]),
                          refs=sorted({p.component.designator for p, _, _ in outputs}), nets=[net.name])
        elif outputs and (cfg.is_ground(net.name) or cfg.is_rail(net.name)):
            yield Finding("PIN004", f"output on supply net '{net.name}': " + ", ".join(_label(*o) for o in outputs),
                          severity=_severity([s for _, _, s in outputs]),
                          refs=sorted({p.component.designator for p, _, _ in outputs}), nets=[net.name])


@check("PIN005", "Input with nothing to drive it", WARNING)
def floating_inputs(ctx):
    """Every pin on the net is an input (an unconnected input pin included).
    A net with any pin of unknown type is skipped: that pin may drive it."""
    pt = _pin_types(ctx)
    for net, pins in _nets(ctx):
        typed = [(p, *pt.effective(p)) for p in pins]
        if all(t == "input" for _, t, _ in typed):
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
