"""Render a check Result as text, Markdown, or JSON."""

import json
import os
from collections import Counter

from .checks import ERROR, INFO, REGISTRY, WARNING
from .checks.levels import level_coverage
from .checks.power import cap_voltage_coverage, rail_summary
from .checks.powerup import power_up_summary

_ICON = {ERROR: "E", WARNING: "W", INFO: "I"}


def _counts_line(result):
    return (f"{result.count(ERROR)} error(s), {result.count(WARNING)} warning(s), "
            f"{result.count(INFO)} info, {len(result.waived)} waived")


def text(result):
    d = result.ctx.design
    sch = f"SCH {d.schematic_id}, " if d.schematic_id else ""
    lines = [f"{d.name}  ({sch}export v{d.export_version}, {len(d.sheets)} sheets, "
             f"{len(d.components)} components, {len(d.nets)} nets)"]
    for f in result.active:
        lines.append(f"[{_ICON[f.severity]}] {f.check} {f.message}")
    for check_id, reason in result.skipped:
        lines.append(f"[-] {check_id} skipped: {reason}")
    lines.append(_counts_line(result))
    return "\n".join(lines) + "\n"


def _md_escape(s):
    return str(s).replace("|", "\\|")


def markdown(result):
    ctx = result.ctx
    d = ctx.design
    out = [f"# Board check: {d.name}", ""]
    sch = f"Schematic {d.schematic_id}. " if d.schematic_id else ""
    out.append(f"{sch}Source `{d.source}`, export script v{d.export_version}: {len(d.sheets)} sheets, "
               f"{len(d.components)} components, {len(d.part_params)} part numbers, {len(d.nets)} nets.")
    out.append("")
    out.append(f"**{_counts_line(result)}**")
    out.append("")

    by_check = Counter(f.check for f in result.active)
    out += ["## Summary", "", "| Check | Title | Severity | Findings |", "|---|---|---|---|"]
    for check_id, info in sorted(REGISTRY.items()):
        skipped = dict(result.skipped).get(check_id)
        n = "skipped: " + skipped if skipped else str(by_check.get(check_id, 0))
        sev = ctx.config["severity"].get(check_id, info.severity)
        out.append(f"| {check_id} | {info.title} | {sev} | {n} |")
    out.append("")

    for severity, heading in ((ERROR, "Errors"), (WARNING, "Warnings"), (INFO, "Info")):
        items = [f for f in result.active if f.severity == severity]
        if not items:
            continue
        out.append(f"## {heading}")
        current = None
        for f in items:
            if f.check != current:
                current = f.check
                title = REGISTRY[f.check].title if f.check in REGISTRY else "Configuration"
                out += ["", f"### {f.check}: {title}", ""]
            out.append(f"- {_md_escape(f.message)}" + (f"  \n  refs: {', '.join(f.refs)}" if len(f.refs) > 1 else ""))
        out.append("")

    if result.waived:
        out += ["## Waived", "", "| Check | Finding | Reason |", "|---|---|---|"]
        for f in result.waived:
            out.append(f"| {f.check} | {_md_escape(f.message)} | {_md_escape(f.waived_by)} |")
        out.append("")

    checked, total, worst = cap_voltage_coverage(ctx)
    out += ["## Coverage", ""]
    out.append(f"- Capacitor voltage derating: {checked} of {total} two-terminal capacitors have a known voltage "
               "on both nets and a rating" + (f"; highest stress {worst[0]:.0%} ({worst[1]}, {worst[2]:g} V on "
                                              f"{worst[3]:g} V)" if worst else "") + ".")
    lv_checked, lv_total, lv_gaps = level_coverage(ctx)
    if ctx.partsdb:
        out.append(f"- Logic levels: {lv_checked} of {lv_total} driver/receiver pairs had levels at both ends"
                   + (f"; parts without them: {', '.join(sorted(lv_gaps))}" if lv_gaps else "") + ".")
    for desig, f in sorted(ctx.fpgas.items()):
        io = f.io if hasattr(f, "io") else f
        state = (f"{len(io.pins)} constrained pins from {', '.join(os.path.basename(p) for p in io.read)}"
                 if io.available else "constraint files not found")
        out.append(f"- FPGA {desig}: {state}.")
    out.append(f"- Parts repository: {'used' if ctx.partsdb else 'not installed'}.")
    out.append("")

    pu = power_up_summary(ctx)
    if pu:
        out += ["## Power-up defaults", "",
                "FPGA control outputs, and the level their loads see before the FPGA drives them.", "",
                "| Signal | FPGA pin | Port | Loads | Before the FPGA drives it |", "|---|---|---|---|---|"]
        for sig, pin, port, loads, windows in pu:
            states = "; ".join(f"{label}: {text}" for label, text in windows)
            out.append(f"| {_md_escape(sig)} | {pin} | {port} | {loads} | {_md_escape(states)} |")
        out.append("")

    rows = rail_summary(ctx)
    if rows:
        out += ["## Supply rails", "", "| Rail | Volts | Pins | Caps to GND | Test points |",
                "|---|---:|---:|---:|---:|"]
        for name, volts, pins, caps, tps in rows:
            out.append(f"| {name} | {volts:g} | {pins} | {caps} | {tps} |")
        out.append("")
    return "\n".join(out)


def as_json(result):
    d = result.ctx.design
    return json.dumps({
        "design": d.name,
        "source": d.source,
        "export_version": d.export_version,
        "schematic": d.schematic_id or None,
        "counts": {ERROR: result.count(ERROR), WARNING: result.count(WARNING),
                   INFO: result.count(INFO), "waived": len(result.waived)},
        "skipped": [{"check": c, "reason": r} for c, r in result.skipped],
        "findings": [f.to_dict() for f in result.findings],
    }, indent=2)
