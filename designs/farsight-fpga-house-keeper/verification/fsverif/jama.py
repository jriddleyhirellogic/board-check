"""The Jama requirements the housekeeper answers to, and what traces to them.

`docs/requirements/jama.yaml` is a snapshot of the Jama requirements that fall
on the housekeeper: every FAR-PM_FPGA L4 requirement, every other Jama
requirement a housekeeper requirement cites as its parent, and any that the
findings say fall on the housekeeper with nothing under them. It is committed
so that traceability can be checked without Jama, and refreshed from a Jama
trace-view CSV export with

    python -m fsverif.jama --csv <export.csv>

The export loses non-ASCII characters: Jama's >= and <= arrive as "?".
`SYMBOL_FIXES` restores the ones confirmed against Jama itself; extraction
refuses to write a text with a "?" it cannot account for.
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from dataclasses import dataclass
from pathlib import Path

import yaml

from fsverif.evidence import REPO, REQUIREMENTS

JAMA = REPO / "docs" / "requirements" / "jama.yaml"

JAMA_ID = re.compile(r"FAR-[A-Z]+(?:_[A-Z]+)*_L\dREQ-\d+")
PARENT = re.compile(r"^- \*\*Parent:\*\*(.*)$", re.M)
HEADING = re.compile(r"^### (DRV-HK-\d+|HK-[A-Z]+-\d+)\s*$", re.M)

#: The whole set allocated to the housekeeper FPGA.
HOUSEKEEPER = re.compile(r"FAR-PM_FPGA_L4REQ-\d+")

#: Characters the CSV export mangled, checked against Jama on 2026-09-30.
SYMBOL_FIXES = {
    "FAR-PM_FPGA_L4REQ-17": ("goes low for? 5 us", "goes low for \u2265 5 us"),
    "FAR-PM_FPGA_L4REQ-19": ("power region ? 4 times", "power region \u2264 4 times"),
}


@dataclass
class JamaReq:
    id: str
    name: str
    text: str
    note: str = ""

    @property
    def allocated(self) -> bool:
        """Allocated to the housekeeper FPGA as a whole, not merely cited."""
        return bool(HOUSEKEEPER.fullmatch(self.id))

    @property
    def short(self) -> str:
        """`FAR-PM_FPGA_L4REQ-14` -> `L4REQ-14`; others unchanged."""
        return self.id.replace("FAR-PM_FPGA_", "")


def _number(jid: str) -> tuple:
    head, _, n = jid.rpartition("-")
    return (not HOUSEKEEPER.fullmatch(jid), head, int(n))


def load(path: Path = JAMA) -> dict:
    """Jama id -> JamaReq, housekeeper L4s first, each group in number order."""
    if not path.is_file():
        return {}
    raw = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    reqs = [JamaReq(id=r["id"], name=r.get("name", ""), text=" ".join(str(r.get("text", "")).split()),
                    note=" ".join(str(r.get("note", "")).split()))
            for r in raw.get("requirements", [])]
    return {r.id: r for r in sorted(reqs, key=lambda r: _number(r.id))}


def parents(path: Path = REQUIREMENTS) -> dict:
    """Housekeeper requirement -> the Jama ids its Parent line cites."""
    text = path.read_text(encoding="utf-8")
    text = text.split("\n## Withdrawn", 1)[0]
    marks = list(HEADING.finditer(text))
    out = {}
    for n, mark in enumerate(marks):
        end = marks[n + 1].start() if n + 1 < len(marks) else len(text)
        line = PARENT.search(text[mark.end():end])
        out[mark.group(1)] = list(dict.fromkeys(JAMA_ID.findall(line.group(1)))) if line else []
    return out


def children(parent_map: dict) -> dict:
    """Jama id -> the housekeeper requirements citing it, in document order."""
    out = {}
    for hk, cited in parent_map.items():
        for jid in cited:
            out.setdefault(jid, []).append(hk)
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

    Takes every FAR-PM_FPGA L4 requirement, every parent the requirements
    document cites, and every entry already in the snapshot (whose note is
    kept: it records why an uncited requirement is listed).
    """
    exported = read_export(csv_path)
    wanted = {j for j in exported if HOUSEKEEPER.fullmatch(j)}
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
        out[jid] = JamaReq(id=jid, name=name, text=text,
                           note=keep[jid].note if jid in keep else "")
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
        "# Jama requirements that fall on the PA3 housekeeper. Generated by",
        "# `python -m fsverif.jama --csv <export>`; edit `note:` by hand, not the text.",
        "#",
        "# Every FAR-PM_FPGA L4 requirement, every other Jama requirement a",
        "# housekeeper requirement cites as its parent, and any listed with a `note:`",
        "# saying why it is here with nothing under it.",
        f"source: {source}",
        "requirements:",
    ]
    for r in reqs.values():
        out += [f"  - id: {r.id}", f"    name: {yaml.safe_dump(r.name, width=10**6).strip().removesuffix('...').strip()}",
                "    text: >", block(r.text)]
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
