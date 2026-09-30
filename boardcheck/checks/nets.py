"""Connectivity and net naming checks."""

import re

from . import ERROR, INFO, WARNING, Finding, check
from ..model import natural_key

_MAX_LISTED = 12


def _pin_list(pins):
    names = [f"{p.designator}" + (f" ({p.name})" if p.name and p.name != p.designator else "")
             for p in sorted(pins, key=lambda p: natural_key(p.designator))]
    if len(names) > _MAX_LISTED:
        names = names[:_MAX_LISTED] + [f"... {len(names) - _MAX_LISTED} more"]
    return ", ".join(names)


def _electrical(ctx):
    return [c for c in ctx.design.components.values() if not ctx.config.is_mechanical(c)]


@check("NET001", "Named net has only one connection", WARNING)
def single_pin_named_nets(ctx):
    """A labelled net that reaches one pin is usually a typo in a net label
    or port, or a connection that was never finished."""
    allowed = re.compile(ctx.config["nets"]["single_pin_ok"])
    for net in sorted(ctx.design.nets.values(), key=lambda n: n.name):
        if net.auto_named or len(net.pins) != 1 or allowed.search(net.name):
            continue
        pin = net.pins[0]
        if ctx.config.is_mechanical(pin.component):
            continue
        yield Finding("NET001", f"net '{net.name}' connects only to {pin.ref}"
                                + (f" ({pin.name})" if pin.name else ""),
                      refs=[pin.component.designator], nets=[net.name])


def _unconnected(ctx):
    """Pins on auto-named nets that reach no other pin."""
    out = {}
    for net in ctx.design.nets.values():
        if net.auto_named and len(net.pins) == 1:
            pin = net.pins[0]
            out.setdefault(pin.component.designator, []).append(pin)
    return out


@check("NET002", "Unconnected pins", INFO)
def unconnected_pins(ctx):
    """Listed for review: without pin electrical types in the export, an
    intentional no-connect cannot be told from a missed wire."""
    comps = ctx.design.components
    for desig, pins in sorted(_unconnected(ctx).items(), key=lambda kv: natural_key(kv[0])):
        comp = comps[desig]
        if ctx.config.is_mechanical(comp) or len(pins) == len(comp.pins):
            continue  # NET008 reports fully unconnected components
        signal = [p for p in pins if not _is_supply_pin(ctx, p)]
        if signal:
            yield Finding("NET002", f"{desig}: {len(signal)} unconnected pin(s): {_pin_list(signal)}",
                          refs=[desig])


def _is_supply_pin(ctx, pin):
    return bool(ctx.config.power_pin_re.match(pin.name) or ctx.config.ground_pin_re.match(pin.name))


@check("NET003", "Power or ground pin unconnected", ERROR)
def unconnected_supply_pins(ctx):
    comps = ctx.design.components
    for desig, pins in sorted(_unconnected(ctx).items(), key=lambda kv: natural_key(kv[0])):
        if ctx.config.is_mechanical(comps[desig]):
            continue
        supply = [p for p in pins if _is_supply_pin(ctx, p)]
        if supply:
            yield Finding("NET003", f"{desig}: supply pin(s) not connected: {_pin_list(supply)}",
                          refs=[desig])


@check("NET004", "Net names differ only by case or spacing", WARNING)
def near_duplicate_names(ctx):
    groups = {}
    for name in ctx.design.nets:
        groups.setdefault(re.sub(r"\s+", "", name).upper(), []).append(name)
    for names in groups.values():
        if len(names) > 1:
            yield Finding("NET004", "nets " + ", ".join(f"'{n}'" for n in sorted(names))
                          + " look like the same signal but are separate nets", nets=sorted(names))


@check("NET005", "Net name contains whitespace", WARNING)
def whitespace_in_names(ctx):
    for name in sorted(ctx.design.nets):
        if re.search(r"\s", name):
            yield Finding("NET005", f"net '{name}' contains whitespace", nets=[name])


@check("NET006", "Differential pair half without its partner", WARNING)
def diff_pairs(ctx):
    cfg = ctx.config["nets"]
    ignore = [re.compile(p) for p in cfg["diff_pair_ignore"]]
    names = set(ctx.design.nets)
    reported = set()
    for name in sorted(names):
        if ctx.design.nets[name].auto_named or any(r.search(name) for r in ignore):
            continue
        for pos, neg in cfg["diff_pair_suffixes"]:
            for mine, other in ((pos, neg), (neg, pos)):
                # Suffix may be followed by a lane index: "_P0" / "_N0".
                m = re.match(rf"^(.*){re.escape(mine)}(\d*)$", name)
                if not m:
                    continue
                partner = f"{m.group(1)}{other}{m.group(2)}"
                if partner not in names and name not in reported:
                    reported.add(name)
                    yield Finding("NET006", f"'{name}' has no partner net '{partner}'", nets=[name])


@check("NET007", "Two-terminal part shorted to one net", WARNING)
def shorted_parts(ctx):
    for comp in _electrical(ctx):
        if len(comp.pins) == 2 and comp.pins[0].net == comp.pins[1].net:
            yield Finding("NET007", f"{comp.designator} ({comp.part_number}) has both pins on '{comp.pins[0].net}'",
                          refs=[comp.designator], nets=[comp.pins[0].net])


@check("NET008", "Component with no connections", WARNING)
def floating_components(ctx):
    unconnected = _unconnected(ctx)
    for comp in _electrical(ctx):
        if comp.pins and len(unconnected.get(comp.designator, [])) == len(comp.pins):
            yield Finding("NET008", f"{comp.designator} ({comp.part_number}) has no pin connected to anything",
                          refs=[comp.designator])
