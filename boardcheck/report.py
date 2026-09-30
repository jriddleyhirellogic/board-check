"""Render a check Result as text, Markdown, or JSON."""

import json
from collections import Counter

from .checks import ERROR, INFO, REGISTRY, WARNING
from .checks.power import cap_voltage_coverage, rail_summary

_ICON = {ERROR: "E", WARNING: "W", INFO: "I"}


def _counts_line(result):
    return (f"{result.count(ERROR)} error(s), {result.count(WARNING)} warning(s), "
            f"{result.count(INFO)} info, {len(result.waived)} waived")


def text(result):
    d = result.ctx.design
    lines = [f"{d.name}  (export v{d.export_version}, {len(d.sheets)} sheets, "
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
    out.append(f"Source `{d.source}`, export script v{d.export_version}: {len(d.sheets)} sheets, "
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
    out.append(f"- Parts repository: {'used' if ctx.partsdb else 'not installed'}.")
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
        "counts": {ERROR: result.count(ERROR), WARNING: result.count(WARNING),
                   INFO: result.count(INFO), "waived": len(result.waived)},
        "skipped": [{"check": c, "reason": r} for c, r in result.skipped],
        "findings": [f.to_dict() for f in result.findings],
    }, indent=2)
