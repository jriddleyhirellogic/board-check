"""Net-level difference between two exports of the same design.

What a reviewer needs from a schematic change, without opening Altium:

- components added or removed, and part number / comment changes
- connectivity: every pin whose net changed. Net names are not stable
  (Altium names unlabelled nets after a pin, "NetR345_2", and a label
  edit renames a whole net), so nets are matched by their pins first: a net
  whose pins are all the same under a new name is a rename, not a change
- part-number parameter changes (the library data the BOM is built from)
- sheets added or removed
- check findings introduced and resolved, when both exports are run
"""

from collections import defaultdict
from dataclasses import dataclass, field

from .model import natural_key


def _pin_key(pin):
    return f"{pin.component.designator}.{pin.designator}"


@dataclass
class DesignDiff:
    old: object
    new: object
    added_components: list = field(default_factory=list)
    removed_components: list = field(default_factory=list)
    part_number_changes: list = field(default_factory=list)     # (desig, old pn, new pn)
    comment_changes: list = field(default_factory=list)         # (desig, old, new)
    footprint_changes: list = field(default_factory=list)       # (desig, old, new), both exports >= 2.4.0
    renamed_nets: list = field(default_factory=list)            # (old name, new name)
    added_nets: list = field(default_factory=list)              # new names with no old counterpart
    removed_nets: list = field(default_factory=list)
    moved_pins: list = field(default_factory=list)              # (pin, old net, new net)
    param_changes: list = field(default_factory=list)           # (pn, name, old, new)
    added_sheets: list = field(default_factory=list)
    removed_sheets: list = field(default_factory=list)
    new_findings: list = field(default_factory=list)
    resolved_findings: list = field(default_factory=list)

    @property
    def empty(self):
        return not any([self.added_components, self.removed_components, self.part_number_changes,
                        self.comment_changes, self.footprint_changes, self.renamed_nets, self.added_nets, self.removed_nets,
                        self.moved_pins, self.param_changes, self.added_sheets, self.removed_sheets])


def diff(old, new):
    d = DesignDiff(old, new)
    oc, nc = old.components, new.components
    d.added_components = sorted(set(nc) - set(oc), key=natural_key)
    d.removed_components = sorted(set(oc) - set(nc), key=natural_key)
    for desig in sorted(set(oc) & set(nc), key=natural_key):
        a, b = oc[desig], nc[desig]
        if a.part_number != b.part_number:
            d.part_number_changes.append((desig, a.part_number, b.part_number))
        if a.comment != b.comment:
            d.comment_changes.append((desig, a.comment, b.comment))
        if old.has_footprints and new.has_footprints and a.footprint != b.footprint:
            d.footprint_changes.append((desig, a.footprint, b.footprint))

    old_sheets = {s.name for s in old.sheets}
    new_sheets = {s.name for s in new.sheets}
    d.added_sheets = sorted(new_sheets - old_sheets)
    d.removed_sheets = sorted(old_sheets - new_sheets)

    # Pins present in both designs decide how nets correspond.
    old_net_of = {_pin_key(p): p.net for c in oc.values() for p in c.pins}
    new_net_of = {_pin_key(p): p.net for c in nc.values() for p in c.pins}
    common = set(old_net_of) & set(new_net_of)
    old_pins = {n: {_pin_key(p) for p in net.pins} & common for n, net in old.nets.items()}
    new_pins = {n: {_pin_key(p) for p in net.pins} & common for n, net in new.nets.items()}

    # Which new net each old net became. A name present in both is the same
    # net. Otherwise an old net became the new net holding most of its
    # surviving pins, unless that new net is already some other old net's
    # continuation (a merge): the strongest claim wins and the other net's
    # pins count as moved.
    mapping = {n: n for n in old.nets if n in new.nets}
    taken = set(mapping.values())
    claims = []
    for name, pins in old_pins.items():
        if name in mapping or not pins:
            continue
        votes = defaultdict(int)
        for k in pins:
            votes[new_net_of[k]] += 1
        best = max(sorted(votes), key=lambda n: votes[n])
        claims.append((-votes[best], name, best))
    for _, name, best in sorted(claims):
        if best not in taken:
            mapping[name] = best
            taken.add(best)
    claimed = defaultdict(list)
    for o, n in mapping.items():
        claimed[n].append(o)

    for o, n in sorted(mapping.items()):
        if o != n and old_pins[o] == new_pins[n] and claimed[n] == [o] and n not in old.nets:
            d.renamed_nets.append((o, n))
    renamed_old = {o for o, _ in d.renamed_nets}
    renamed_new = {n for _, n in d.renamed_nets}

    d.removed_nets = sorted((n for n in old.nets if n not in new.nets and n not in renamed_old), key=natural_key)
    d.added_nets = sorted((n for n in new.nets if n not in old.nets and n not in renamed_new), key=natural_key)

    # A pin moved when its new net is not the one its old net became.
    for k in sorted(common, key=natural_key):
        o, n = old_net_of[k], new_net_of[k]
        if mapping.get(o, o) != n and o != n:
            d.moved_pins.append((k, o, n))

    for pn in sorted(set(old.part_params) & set(new.part_params)):
        a, b = old.part_params[pn], new.part_params[pn]
        for name in sorted(set(a) | set(b)):
            if a.get(name) != b.get(name):
                d.param_changes.append((pn, name, a.get(name), b.get(name)))
    return d


def compare_findings(d, old_result, new_result):
    """Findings in the new result that were not in the old one, and the
    reverse, matched on check id and message."""
    key = lambda f: (f.check, f.message)                                   # noqa: E731
    old_keys = {key(f) for f in old_result.active}
    new_keys = {key(f) for f in new_result.active}
    d.new_findings = [f for f in new_result.active if key(f) not in old_keys]
    d.resolved_findings = [f for f in old_result.active if key(f) not in new_keys]
    return d


# -- rendering ---------------------------------------------------------------------

def _section(title, rows, fmt, limit=200):
    if not rows:
        return []
    out = [f"### {title} ({len(rows)})", ""]
    out += [f"- {fmt(r)}" for r in rows[:limit]]
    if len(rows) > limit:
        out.append(f"- ... {len(rows) - limit} more")
    out.append("")
    return out


def markdown(d):
    o, n = d.old, d.new
    out = [f"## Schematic changes: {n.name}", "",
           f"From `{o.source.split('/')[-1]}` (script {o.export_version}) to "
           f"`{n.source.split('/')[-1]}` (script {n.export_version}).", ""]
    if d.empty and not d.new_findings and not d.resolved_findings:
        return "\n".join(out + ["No connectivity, component or part data changes.", ""])
    counts = [("components added", d.added_components), ("removed", d.removed_components),
              ("pins moved", d.moved_pins), ("nets renamed", d.renamed_nets),
              ("part number changes", d.part_number_changes), ("footprint changes", d.footprint_changes),
              ("parameter changes", d.param_changes), ("new findings", d.new_findings), ("resolved findings", d.resolved_findings)]
    out += ["| " + " | ".join(k for k, _ in counts) + " |", "|" + "---:|" * len(counts),
            "| " + " | ".join(str(len(v)) for _, v in counts) + " |", ""]
    sev = {"error": "E", "warning": "W", "info": "I"}
    out += _section("New findings", d.new_findings, lambda f: f"[{sev.get(f.severity, '?')}] {f.check} {f.message}")
    out += _section("Resolved findings", d.resolved_findings, lambda f: f"{f.check} {f.message}")
    out += _section("Sheets added", d.added_sheets, str)
    out += _section("Sheets removed", d.removed_sheets, str)
    comps = n.components
    out += _section("Components added", d.added_components,
                    lambda c: f"{c} {comps[c].part_number} ({', '.join(comps[c].sheets)})")
    out += _section("Components removed", d.removed_components,
                    lambda c: f"{c} {o.components[c].part_number}")
    out += _section("Part number changes", d.part_number_changes, lambda r: f"{r[0]}: {r[1]} -> {r[2]}")
    out += _section("Comment changes", d.comment_changes, lambda r: f"{r[0]}: {r[1]} -> {r[2]}")
    out += _section("Footprint changes", d.footprint_changes, lambda r: f"{r[0]}: {r[1] or 'none'} -> {r[2] or 'none'}")
    out += _section("Pins moved to another net", d.moved_pins, lambda r: f"{r[0]}: {r[1]} -> {r[2]}")
    out += _section("Nets renamed (same pins)", d.renamed_nets, lambda r: f"{r[0]} -> {r[1]}")
    out += _section("Nets removed", d.removed_nets, str)
    out += _section("Nets added", d.added_nets, str)
    out += _section("Part parameter changes", d.param_changes,
                    lambda r: f"{r[0]} {r[1]}: {r[2] if r[2] is not None else '(none)'} -> "
                              f"{r[3] if r[3] is not None else '(none)'}")
    return "\n".join(out)


def text(d):
    return markdown(d).replace("### ", "").replace("## ", "")


def as_json(d):
    import json
    return json.dumps({
        "old": {"source": d.old.source, "version": d.old.export_version},
        "new": {"source": d.new.source, "version": d.new.export_version},
        "components_added": d.added_components, "components_removed": d.removed_components,
        "part_number_changes": d.part_number_changes, "comment_changes": d.comment_changes,
        "footprint_changes": d.footprint_changes,
        "pins_moved": d.moved_pins, "nets_renamed": d.renamed_nets,
        "nets_added": d.added_nets, "nets_removed": d.removed_nets,
        "param_changes": d.param_changes, "sheets_added": d.added_sheets, "sheets_removed": d.removed_sheets,
        "new_findings": [f.to_dict() for f in d.new_findings],
        "resolved_findings": [f.to_dict() for f in d.resolved_findings],
    }, indent=2)
