"""Builders for small synthetic exports used across the tests."""

from boardcheck.checks import Context
from boardcheck.config import Config
from boardcheck.model import Design


def make_export(components, part_numbers=None, sheets=None, version="2.2.1"):
    """Build an export dict. components: list of
    (designator, part_number, [(pin, name, net[, electricalType]), ...]) or dicts with
    'sheet', 'comment' and 'parts' ([(part_designator, pins)]) overrides."""
    by_sheet = {}
    for c in components:
        if not isinstance(c, dict):
            desig, pn, pins = c
            c = {"designator": desig, "partNumber": pn, "parts": [(desig, pins)]}
        entry = {
            "designator": c["designator"],
            "comment": c.get("comment", c["partNumber"]),
            "libraryReference": c["partNumber"],
            "partNumber": c["partNumber"],
            "partCount": len(c["parts"]),
            "parts": [{"designator": pd, "pins": [_pin(*pin) for pin in pins]} for pd, pins in c["parts"]],
        }
        by_sheet.setdefault(c.get("sheet", "MAIN.SchDoc"), []).append(entry)
    for s in sheets or []:
        by_sheet.setdefault(s, [])
    pns = part_numbers if part_numbers is not None else {}
    for comps in by_sheet.values():
        for e in comps:
            pns.setdefault(e["partNumber"], {"Part Number": e["partNumber"], "Manufacturer": "ACME"})
    return {"project": {
        "name": "TEST.PrjPcb",
        "exportScriptVersion": version,
        "partNumbers": [{"partNumber": pn, "parameters": [{"name": k, "value": v} for k, v in params.items()]}
                        for pn, params in pns.items()],
        "schematics": [{"documentName": name, "components": comps} for name, comps in by_sheet.items()],
    }}


def _pin(designator, name, net, electrical=None):
    pin = {"designator": designator, "name": name, "netName": net}
    if electrical:
        pin["electricalType"] = electrical
    return pin


def cap(desig, pn, net_a, net_b):
    return (desig, pn, [("1", "1", net_a), ("2", "2", net_b)])


res = cap


class FakePartsDB:
    """parts: {pn: DecodedPart or {"pin_functions": {...}}}."""

    def __init__(self, parts):
        self.parts = parts

    def decode(self, pn):
        part = self.parts.get(pn)
        return None if isinstance(part, dict) else part

    def pin_functions(self, pn):
        part = self.parts.get(pn)
        return part.get("pin_functions") if isinstance(part, dict) else None

    def characteristics(self, pn):
        part = self.parts.get(pn)
        return part.get("electrical_characteristics") if isinstance(part, dict) else None

    def power_up_io(self, pn):
        part = self.parts.get(pn)
        return ((part.get("power_up_io") or {}).get("states", [])) if isinstance(part, dict) else []

    def io_standards(self, pn):
        part = self.parts.get(pn)
        block = part.get("io_standards") if isinstance(part, dict) else None
        return {k.upper(): v for k, v in (block or {}).items()}


def findings(check_func, ctx):
    return list(check_func(ctx))


def build_ctx(components, part_numbers=None, config=None, parts=None, **kw):
    design = Design(make_export(components, part_numbers, **kw))
    return Context(design, Config(config), FakePartsDB(parts) if parts is not None else None)
