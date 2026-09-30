"""In-memory model of an Altium schematic JSON export (ExportAllSchematicsToJSON)."""

import json
import re
from collections import defaultdict
from dataclasses import dataclass, field

# Multi-part designators: "U1A", "U101E". The base must end in a digit so
# that a plain designator such as "FID" or "TP" is never split.
_PART_SUFFIX_RE = re.compile(r"^(.*\d)([A-Z])$")
_PREFIX_RE = re.compile(r"^([A-Za-z_]+)")


@dataclass
class Pin:
    designator: str       # pin number / ball, e.g. "A12"
    name: str             # pin name, e.g. "VDD"
    net: str
    component: "Component" = field(repr=False, default=None)
    part: str = ""        # sub-part designator, e.g. "U1C"

    @property
    def ref(self):
        return f"{self.component.designator}.{self.designator}"


@dataclass
class Component:
    designator: str
    part_number: str
    comment: str
    library_reference: str
    sheets: list = field(default_factory=list)
    parts: list = field(default_factory=list)        # sub-part designators
    pins: list = field(default_factory=list)
    part_numbers_seen: set = field(default_factory=set)

    @property
    def prefix(self):
        m = _PREFIX_RE.match(self.designator)
        return m.group(1).upper() if m else ""

    def nets(self):
        return {p.net for p in self.pins}


@dataclass
class Net:
    name: str
    pins: list = field(default_factory=list)

    @property
    def auto_named(self):
        # Altium names unlabelled nets after one of their pins: "NetU10_N7".
        return self.name.startswith("Net") and "_" in self.name

    def components(self):
        seen = {}
        for p in self.pins:
            seen.setdefault(p.component.designator, p.component)
        return list(seen.values())


@dataclass
class Sheet:
    name: str
    component_count: int


class Design:
    def __init__(self, raw, source=""):
        self.raw = raw
        self.source = source
        project = raw["project"]
        self.name = project.get("name", "")
        self.export_version = project.get("exportScriptVersion", "")
        self.part_params = {
            p["partNumber"]: {x["name"]: x["value"] for x in p.get("parameters", [])}
            for p in project.get("partNumbers", [])
        }
        self.sheets = []
        self.components = {}
        self.nets = {}
        self._load(project.get("schematics", []))

    @classmethod
    def load(cls, path):
        with open(path, encoding="utf-8") as f:
            return cls(json.load(f), source=str(path))

    def _load(self, schematics):
        pins_seen = set()
        for sheet in schematics:
            sheet_name = sheet.get("documentName") or sheet.get("filename", "")
            comps = sheet.get("components", [])
            self.sheets.append(Sheet(sheet_name, len(comps)))
            for c in comps:
                desig = c["designator"]
                comp = self.components.get(desig)
                if comp is None:
                    comp = Component(
                        designator=desig,
                        part_number=c.get("partNumber") or "",
                        comment=c.get("comment") or "",
                        library_reference=c.get("libraryReference") or "",
                    )
                    self.components[desig] = comp
                comp.part_numbers_seen.add(c.get("partNumber") or "")
                if sheet_name not in comp.sheets:
                    comp.sheets.append(sheet_name)
                for part in c.get("parts", []):
                    part_desig = part.get("designator", desig)
                    if part_desig not in comp.parts:
                        comp.parts.append(part_desig)
                    for p in part.get("pins", []):
                        key = (desig, p["designator"])
                        if key in pins_seen:
                            continue
                        pins_seen.add(key)
                        pin = Pin(p["designator"], p.get("name", ""), p.get("netName", ""),
                                  comp, part_desig)
                        comp.pins.append(pin)
                        self.nets.setdefault(pin.net, Net(pin.net)).pins.append(pin)

    # -- lookups -----------------------------------------------------------

    def params(self, component):
        return self.part_params.get(component.part_number, {})

    def param(self, component, *names):
        """First non-empty value among parameter names (case-insensitive)."""
        params = self.params(component)
        lowered = {k.lower(): v for k, v in params.items()}
        for n in names:
            v = lowered.get(n.lower())
            if v not in (None, ""):
                return v
        return None

    def components_by_part_number(self):
        out = defaultdict(list)
        for c in self.components.values():
            out[c.part_number].append(c)
        return out


def natural_key(text):
    """Sort key that orders "R2" before "R10"."""
    return [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", text)]


def split_part_suffix(part_designator):
    """"U1C" -> ("U1", "C"); "R5" -> ("R5", "")."""
    m = _PART_SUFFIX_RE.match(part_designator)
    return (m.group(1), m.group(2)) if m else (part_designator, "")
