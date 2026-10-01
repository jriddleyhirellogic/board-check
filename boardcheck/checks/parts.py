"""Part data checks: library parameters, BOM fields, and part number decoding."""

import re

from . import ERROR, INFO, WARNING, Finding, check
from ..model import natural_key
from ..units import close, format_value, parse_percent, parse_value

# EIA dielectric codes ("X7R", "C0G"); decoders that only say "Ceramic"
# are not compared.
_DIELECTRIC_RE = re.compile(r"\b([XYZ]\d[A-Z]|C0G|NP0|U2J|BX|BP)\b", re.I)
# Metric case codes some decoders report ("7343-43"), mapped to the
# imperial codes Altium libraries use. Codes that are valid imperial sizes
# are never remapped.
_IMPERIAL = {"0201", "0402", "0603", "0805", "1206", "1210", "1411", "1812", "2010", "2220", "2312",
             "2512", "2917", "2924"}
_METRIC_TO_INCH = {"1005": "0402", "1608": "0603", "2012": "0805", "3216": "1206", "3225": "1210",
                   "3528": "1411", "4532": "1812", "5750": "2220", "6032": "2312", "7343": "2917",
                   "7360": "2924"}


def _refs(comps):
    return sorted((c.designator for c in comps), key=natural_key)


def _size_code(text):
    """Imperial case code from "0603", "7343-43", "1206S"; None if absent."""
    m = re.match(r"^\s*(\d{4})", str(text or ""))
    if not m:
        return None
    code = m.group(1)
    return code if code in _IMPERIAL else _METRIC_TO_INCH.get(code, code)


def _describe(decoded):
    if decoded is None:
        return None
    if decoded.kind == "capacitor":
        bits = [format_value(decoded.capacitance, "F"), format_value(decoded.voltage_rated, "V"),
                decoded.size, decoded.dielectric]
    elif decoded.kind == "resistor":
        bits = [format_value(decoded.resistance, "Ω"), decoded.size]
    else:
        return None
    return " ".join(b for b in bits if b and b != "?")


@check("PRT001", "Comment does not match Part Number", WARNING)
def comment_vs_part_number(ctx):
    """The Comment usually lands on the BOM and assembly drawing; a stale one
    from a copied library component describes a different part."""
    groups = {}
    for comp in ctx.design.components.values():
        if comp.comment and comp.part_number and comp.comment != comp.part_number:
            groups.setdefault((comp.part_number, comp.comment), []).append(comp)
    for (pn, comment), comps in sorted(groups.items()):
        severity = WARNING
        detail = ""
        if pn.startswith(comment) or comment.startswith(pn):
            severity = INFO
            detail = " (one is a prefix of the other: likely an ordering or project suffix)"
        elif ctx.partsdb is not None:
            got_pn, got_comment = ctx.partsdb.decode(pn), ctx.partsdb.decode(comment)
            if got_pn and got_comment and _describe(got_pn) != _describe(got_comment):
                severity = ERROR
                detail = f": comment decodes as {_describe(got_comment)}, part number as {_describe(got_pn)}"
        yield Finding("PRT001", f"Comment '{comment}' but Part Number '{pn}'{detail}",
                      severity=severity, refs=_refs(comps), part_number=pn)


@check("PRT002", "Part missing required parameters", WARNING)
def required_params(ctx):
    rules = ctx.config["parts"]["required_params"]
    for pn, comps in sorted(ctx.design.components_by_part_number().items()):
        if not pn or pn not in ctx.design.part_params:
            continue  # EXP004 reports these
        kinds = {ctx.kind(c) for c in comps}
        required = list(rules.get("*", []))
        for k in sorted(kinds):
            required += rules.get(k, [])
        missing = [alts for alts in required
                   if ctx.design.param(comps[0], *alts.split("|")) is None]
        if missing:
            yield Finding("PRT002", f"{pn} is missing {', '.join(m.split('|')[0] for m in missing)}",
                          refs=_refs(comps), part_number=pn)


@check("PRT003", "Library parameter disagrees with decoded part number", WARNING, needs_partsdb=True)
def params_vs_decoded(ctx):
    """Altium parameters feed derating and analysis; the part number is what
    gets bought. When they disagree one of them is wrong."""
    for pn, comps in sorted(ctx.design.components_by_part_number().items()):
        decoded = ctx.partsdb.decode(pn)
        if decoded is None or decoded.kind == "other":
            continue
        c = comps[0]
        p = lambda *n: ctx.design.param(c, *n)  # noqa: E731
        diffs = []

        def cmp_value(label, text, unit, want, rel=0.01):
            got = parse_value(text, unit)
            if got is not None and want is not None and not close(got, want, rel):
                diffs.append(f"{label} {text} vs decoded {format_value(want, unit)}")

        if decoded.kind == "capacitor":
            cmp_value("C_Value", p("C_Value"), "F", decoded.capacitance)
            cmp_value("Voltage", p("Voltage"), "V", decoded.voltage_rated)
            diel = p("Dialectric", "Dielectric")
            codes = {c.upper().replace("NP0", "C0G") for c in _DIELECTRIC_RE.findall(decoded.dielectric or "")}
            if diel and codes and diel.upper().replace("NP0", "C0G") not in codes:
                diffs.append(f"dielectric {diel} vs decoded {decoded.dielectric}")
        else:
            cmp_value("R_Value", p("R_Value"), "Ω", decoded.resistance)
            cmp_value("Power_Rating", p("Power_Rating"), "W", decoded.power_max, rel=0.05)
        tol = parse_percent(p("Tolerance"))
        if tol is not None and decoded.tolerance is not None and not close(tol, decoded.tolerance):
            diffs.append(f"tolerance {tol:g}% vs decoded {decoded.tolerance:g}%")
        size, dsize = _size_code(p("Size")), _size_code(decoded.size)
        if size and dsize and size != dsize:
            diffs.append(f"size {p('Size')} vs decoded {decoded.size}")
        if diffs:
            yield Finding("PRT003", f"{pn}: " + "; ".join(diffs) + f" [decoder: {decoded.source}]",
                          refs=_refs(comps), part_number=pn)


@check("PRT004", "Passive part not decodable by the parts repository", INFO, needs_partsdb=True)
def not_decodable(ctx):
    for pn, comps in sorted(ctx.design.components_by_part_number().items()):
        kinds = {ctx.kind(c) for c in comps}
        if kinds & {"capacitor", "resistor"} and ctx.partsdb.decode(pn) is None:
            yield Finding("PRT004", f"{pn} ({'/'.join(sorted(kinds))}) is not in electronic-parts-repository; "
                                    "checks fall back to library parameters",
                          refs=_refs(comps), part_number=pn)


@check("PRT005", "Part qualification missing or not allowed", WARNING)
def qualification(ctx):
    q = ctx.config["parts"]["qualification"]
    allowed = {a.upper() for a in q["allowed"]}
    for pn, comps in sorted(ctx.design.components_by_part_number().items()):
        kinds = {ctx.kind(c) for c in comps}
        if not kinds & set(q["kinds"]) or pn not in ctx.design.part_params:
            continue
        value = ctx.design.param(comps[0], q["param"])
        if value is None:
            yield Finding("PRT005", f"{pn} has no {q['param']}", refs=_refs(comps), part_number=pn)
        elif value.upper() not in allowed:
            yield Finding("PRT005", f"{pn} {q['param']} is '{value}', not one of {', '.join(q['allowed'])}",
                          refs=_refs(comps), part_number=pn)


@check("PRT006", "Designator prefix does not match part type", ERROR, needs_partsdb=True)
def prefix_vs_type(ctx):
    for comp in ctx.design.components.values():
        decoded = ctx.decoded(comp)
        if decoded is None or decoded.kind == "other":
            continue
        kind = ctx.kind(comp)
        if kind != decoded.kind:
            yield Finding("PRT006", f"{comp.designator} is a {kind} by designator but {comp.part_number} "
                                    f"decodes as a {decoded.kind}", refs=[comp.designator],
                          part_number=comp.part_number)


@check("PRT007", "Design Item ID does not match Part Number", WARNING)
def design_item_id(ctx):
    for pn, comps in sorted(ctx.design.components_by_part_number().items()):
        item = ctx.design.part_params.get(pn, {}).get("Design Item ID")
        if item and item != pn:
            yield Finding("PRT007", f"Design Item ID '{item}' but Part Number '{pn}'",
                          refs=_refs(comps), part_number=pn)


@check("PRT008", "Component without a footprint", WARNING, needs_footprints=True)
def missing_footprint(ctx):
    """Every component except mechanical ones (`mechanical_kinds`) needs a
    current PCB footprint on its symbol (export script >= 2.4.0)."""
    missing = [c for c in ctx.design.components.values()
               if not c.footprint and not ctx.config.is_mechanical(c)]
    by_pn = {}
    for c in missing:
        by_pn.setdefault(c.part_number, []).append(c)
    for pn, comps in sorted(by_pn.items()):
        yield Finding("PRT008", f"{', '.join(_refs(comps))} ({pn or 'no part number'}): no current footprint on the "
                                "symbol", refs=_refs(comps), part_number=pn or None)


@check("PRT009", "Same part number placed with different footprints", ERROR, needs_footprints=True)
def footprint_consistency(ctx):
    """All components of one part number must use the same footprint; a
    different one usually means a symbol placed from another library or
    with an alternate footprint selected."""
    for pn, comps in sorted(ctx.design.components_by_part_number().items()):
        if not pn:
            continue
        groups = {}
        for c in comps:
            if c.footprint:
                groups.setdefault(c.footprint, []).append(c)
        if len(groups) > 1:
            parts = "; ".join(f"{fp}: {', '.join(_refs(cs))}"
                              for fp, cs in sorted(groups.items(), key=lambda x: -len(x[1])))
            yield Finding("PRT009", f"{pn} uses {len(groups)} footprints ({parts})",
                          refs=_refs([c for cs in groups.values() for c in cs]), part_number=pn)
