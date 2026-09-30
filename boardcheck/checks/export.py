"""Checks that the JSON export itself is complete and trustworthy.

A bad export (license checkout failure, sheets not opened, multi-part
components skipped) is structurally valid JSON; these checks catch it
before every other check reports on a partial netlist.
"""

from . import ERROR, INFO, Finding, check
from ..model import split_part_suffix


def _version_tuple(v):
    parts = []
    for p in str(v).split("."):
        try:
            parts.append(int(p))
        except ValueError:
            parts.append(0)
    return tuple(parts)


@check("EXP001", "Export script version too old", ERROR)
def export_version(ctx):
    minimum = ctx.config["export"]["min_version"]
    got = ctx.design.export_version
    if not got or _version_tuple(got) < _version_tuple(minimum):
        yield Finding("EXP001", f"exportScriptVersion is '{got or 'missing'}', need >= {minimum}; "
                                "older exports can silently drop multi-part components")


@check("EXP002", "Sheet exported with no components", ERROR)
def empty_sheets(ctx):
    ok = set(ctx.config["export"]["empty_sheets_ok"])
    for sheet in ctx.design.sheets:
        if sheet.component_count == 0 and sheet.name not in ok:
            yield Finding("EXP002", f"sheet '{sheet.name}' has no components; if it is a title or "
                                    "hierarchy sheet, list it in export.empty_sheets_ok")


@check("EXP003", "Multi-part component missing its first part", ERROR)
def lone_subparts(ctx):
    for comp in ctx.design.components.values():
        suffixes = {split_part_suffix(p)[1] for p in comp.parts}
        suffixes.discard("")
        if suffixes and "A" not in suffixes:
            yield Finding("EXP003", f"{comp.designator} exported only as {', '.join(sorted(comp.parts))}; "
                                    "part A is missing, so the export likely skipped sub-parts",
                          refs=[comp.designator])


@check("EXP004", "Component part number not in part dictionary", ERROR)
def unknown_part_numbers(ctx):
    known = ctx.design.part_params
    missing = {}
    for comp in ctx.design.components.values():
        if ctx.config.is_mechanical(comp) and not comp.part_number:
            continue
        if comp.part_number not in known:
            missing.setdefault(comp.part_number, []).append(comp.designator)
    for pn, refs in sorted(missing.items()):
        label = f"'{pn}'" if pn else "(empty)"
        yield Finding("EXP004", f"part number {label} used by {len(refs)} component(s) has no entry "
                                "in partNumbers", refs=sorted(refs), part_number=pn or None)


@check("EXP005", "Designator carries more than one part number", ERROR)
def conflicting_part_numbers(ctx):
    for comp in ctx.design.components.values():
        if len(comp.part_numbers_seen) > 1:
            yield Finding("EXP005", f"{comp.designator} has part numbers "
                                    f"{', '.join(sorted(comp.part_numbers_seen))} across sheets or sub-parts",
                          refs=[comp.designator])


@check("EXP006", "Export totals differ from expected", ERROR)
def expected_totals(ctx):
    expect = ctx.config["export"]["expect"] or {}
    d = ctx.design
    if "sheets" in expect and len(d.sheets) != expect["sheets"]:
        yield Finding("EXP006", f"{len(d.sheets)} sheets exported, expected {expect['sheets']}")
    if "part_numbers" in expect and len(d.part_params) != expect["part_numbers"]:
        yield Finding("EXP006", f"{len(d.part_params)} part numbers exported, expected {expect['part_numbers']}")
    if "components" in expect and isinstance(expect["components"], int) and len(d.components) != expect["components"]:
        yield Finding("EXP006", f"{len(d.components)} components exported, expected {expect['components']}")
    for desig, want in (expect.get("designators") or {}).items():
        comp = d.components.get(desig)
        if comp is None:
            yield Finding("EXP006", f"{desig} is missing from the export", refs=[desig])
            continue
        if "parts" in want and len(comp.parts) != want["parts"]:
            yield Finding("EXP006", f"{desig} has {len(comp.parts)} parts, expected {want['parts']}", refs=[desig])
        if "pins" in want and len(comp.pins) != want["pins"]:
            yield Finding("EXP006", f"{desig} has {len(comp.pins)} pins, expected {want['pins']}", refs=[desig])


@check("EXP007", "Export has no pin electrical types", INFO)
def pin_types_present(ctx):
    if not ctx.design.has_pin_types:
        yield Finding("EXP007", "no pin carries an electricalType; re-export with script >= 2.3.0 so symbol "
                                "pin types can be checked against the part data. Pin checks use part data only.")
