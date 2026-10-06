"""The Jama requirements the PolarFire FPGA answers to, and what traces to them.

`docs/requirements/jama.yaml` is a snapshot of the Jama requirements that fall
on the PolarFire: every FAR-CDH_FPGA L3 requirement, every other Jama
requirement a PF FPGA requirement cites as its parent, and any listed by hand with
a `note:` saying why it is here with nothing under it. It is committed
so that traceability can be checked without Jama, and refreshed from a Jama
trace-view CSV export with

    python -m fsverif.jama --csv <export.csv>

The export loses non-ASCII characters: Jama's >= and <= arrive as "?".
`SYMBOL_FIXES` restores the ones confirmed against Jama itself; extraction
refuses to write a text with a "?" it cannot account for.

The export in hand is the workspace's `farsight-verification/docs/requirements/
Farsight.csv`.

Some allocated requirements fall on the PolarFire's firmware rather than its
FPGA design. Their firmware requirements live in the firmware's own repository,
not here, so such an entry carries a hand-written `verified_in:` naming where
they are, and a `note:` saying why.
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from dataclasses import dataclass
from pathlib import Path

import yaml

from fsverif.evidence import ANY_HEADING, HEADING, REPO, REQUIREMENTS

JAMA = REPO / "docs" / "requirements" / "jama.yaml"

#: `FAR-CDH_FPGA_L3REQ-20`, and the top level's `FAR-L1REQ-19`, which has no
#: component before its level.
JAMA_ID = re.compile(r"FAR-(?:[A-Z0-9]+(?:_[A-Z0-9]+)*_)?L\dREQ-\d+")
PARENT = re.compile(r"^- \*\*Parent:\*\*(.*)$", re.M)

#: The whole set allocated to the PolarFire FPGA.
ALLOCATED = re.compile(r"FAR-CDH_FPGA_L3REQ-\d+")
ALLOCATED_PREFIX = "FAR-CDH_FPGA_"

#: Characters the CSV export mangled, each confirmed against Jama by the
#: owner on 2026-10-02.
SYMBOL_FIXES: dict = {
    "FAR-CDH_FPGA_L3REQ-17": ("within ? 100 ns", "within \u2264 100 ns"),
    "FAR-CDH_FPGA_L3REQ-18": ("within ? 100 ns", "within \u2264 100 ns"),
    "FAR-CDH_FPGA_L3REQ-19": ("within ? 100 ns", "within \u2264 100 ns"),
    "FAR-SERDES_L3REQ-4": ("speeds ? 5 Gbps/lane", "speeds \u2265 5 Gbps/lane"),
    "FAR-FB_L3REQ-2": ("store ? 500 frames", "store \u2265 500 frames"),
}


@dataclass
class JamaReq:
    id: str
    name: str
    text: str
    note: str = ""
    #: Where it is verified when that is outside this repository, by hand.
    verified_in: str = ""

    @property
    def allocated(self) -> bool:
        """Allocated to the PolarFire FPGA as a whole, not merely cited."""
        return bool(ALLOCATED.fullmatch(self.id))

    @property
    def short(self) -> str:
        """`FAR-CDH_FPGA_L3REQ-20` -> `L3REQ-20`; others unchanged."""
        return self.id.replace(ALLOCATED_PREFIX, "")


def _number(jid: str) -> tuple:
    head, _, n = jid.rpartition("-")
    return (not ALLOCATED.fullmatch(jid), head, int(n))


def load(path: Path = JAMA) -> dict:
    """Jama id -> JamaReq, the allocated L3s first, each group in number order."""
    if not path.is_file():
        return {}
    raw = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    reqs = [JamaReq(id=r["id"], name=r.get("name", ""), text=" ".join(str(r.get("text", "")).split()),
                    note=" ".join(str(r.get("note", "")).split()),
                    verified_in=" ".join(str(r.get("verified_in", "")).split()))
            for r in raw.get("requirements", [])]
    return {r.id: r for r in sorted(reqs, key=lambda r: _number(r.id))}


def parents(path: Path = REQUIREMENTS, heading: re.Pattern = HEADING) -> dict:
    """PF requirement -> the Jama ids its Parent line cites."""
    if not path.is_file():
        return {}
    text = path.read_text(encoding="utf-8")
    out = {}
    for mark in heading.finditer(text):
        following = ANY_HEADING.search(text, mark.end())
        line = PARENT.search(text[mark.end():following.start() if following else len(text)])
        out[mark.group(1)] = list(dict.fromkeys(JAMA_ID.findall(line.group(1)))) if line else []
    return out


def children(parent_map: dict) -> dict:
    """Jama id -> the PF requirements citing it, in document order."""
    out = {}
    for pf, cited in parent_map.items():
        for jid in cited:
            out.setdefault(jid, []).append(pf)
    return out


# ---- refreshing the snapshot from a Jama export

def read_export(csv_path: Path) -> dict:
    """Jama id -> (name, text) for every item in a trace-view CSV export.

    The export is a grid of (item type, id, name, description) groups, one per
    trace level, so an item can appear in any group of any row.
    """
    rows = csv.reader(csv_path.open(encoding="latin-1", newline=""))
    found = {}
    for row in rows:
        for i, cell in enumerate(row[:-2]):
            cell = cell.strip()
            if JAMA_ID.fullmatch(cell) and cell not in found:
                found[cell] = (row[i + 1].strip(), " ".join(row[i + 2].split()))
    return found


#: A problem that stops the snapshot being written, rather than a warning.
MANGLED = "probably a mangled symbol"


def extract(csv_path: Path, keep: dict, cited=None) -> tuple:
    """(requirements, problems): the snapshot refreshed from an export.

    Takes every FAR-CDH_FPGA L3 requirement, every parent the FPGA requirements
    document cites, and every entry already in the snapshot (whose `note:` and
    `verified_in:` are kept: they are written by hand).
    """
    exported = read_export(csv_path)
    wanted = {j for j in exported if ALLOCATED.fullmatch(j)}
    if cited is None:
        cited = {j for js in parents().values() for j in js}
    wanted |= set(cited)
    wanted |= set(keep)
    out, problems = {}, []
    for jid in wanted:
        if jid not in exported:
            if jid in keep:
                out[jid] = keep[jid]
                problems.append(f"{jid}: not in the export; kept as it was")
            else:
                problems.append(f"{jid}: cited by a requirement but not in the export")
            continue
        name, text = exported[jid]
        if jid in SYMBOL_FIXES:
            bad, good = SYMBOL_FIXES[jid]
            text = text.replace(bad, good)
        if "?" in text:
            problems.append(f"{jid}: '?' in the text, {MANGLED}: {text!r}")
        kept = keep.get(jid)
        out[jid] = JamaReq(id=jid, name=name, text=text, note=kept.note if kept else "",
                           verified_in=kept.verified_in if kept else "")
    return dict(sorted(out.items(), key=lambda kv: _number(kv[0]))), problems


def write(reqs: dict, source: str, path: Path = JAMA) -> None:
    def block(s: str) -> str:
        words, lines, line = s.split(), [], ""
        for w in words:
            if line and len(line) + 1 + len(w) > 72:
                lines.append(line)
                line = w
            else:
                line = f"{line} {w}" if line else w
        if line:
            lines.append(line)
        return "\n".join("      " + l for l in lines)

    out = [
        "# Jama requirements that fall on the PolarFire FPGA. Generated by",
        "# `python -m fsverif.jama --csv <export>`; edit `note:` and `verified_in:`",
        "# by hand, not the text.",
        "#",
        "# Every FAR-CDH_FPGA L3 requirement, every other Jama requirement a PF FPGA",
        "# requirement cites as its parent, and any listed with a `note:` saying why",
        "# it is here with nothing under it. `verified_in:` names where one is",
        "# verified outside this repository, such as the firmware's.",
        f"source: {source}",
        "requirements:",
    ]
    for r in reqs.values():
        out += [f"  - id: {r.id}", f"    name: {yaml.safe_dump(r.name, width=10**6).strip().removesuffix('...').strip()}",
                "    text: >", block(r.text)]
        if r.verified_in:
            out += [f"    verified_in: {r.verified_in}"]
        if r.note:
            out += ["    note: >", block(r.note)]
    path.write_text("\n".join(out) + "\n", encoding="utf-8")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--csv", type=Path, required=True, help="Jama trace-view CSV export")
    ap.add_argument("--source", help="what to record as the source (default: the file name)")
    args = ap.parse_args(argv)
    reqs, problems = extract(args.csv, load())
    for p in problems:
        print(p, file=sys.stderr)
    if any(MANGLED in p for p in problems):
        print("Not written: add the confirmed text to SYMBOL_FIXES first.", file=sys.stderr)
        return 1
    write(reqs, args.source or args.csv.name)
    print(f"{len(reqs)} Jama requirements written to {JAMA.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
