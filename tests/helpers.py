"""Builders for small synthetic exports used across the tests."""

from boardcheck.checks import Context
from boardcheck.config import Config
from boardcheck.model import Design


def make_export(components, part_numbers=None, sheets=None, version="2.2.1"):
    """Build an export dict. components: list of
    (designator, part_number, [(pin, name, net), ...]) or dicts with
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
            "parts": [{"designator": pd, "pins": [{"designator": d, "name": n, "netName": net}
                                                  for d, n, net in pins]}
                      for pd, pins in c["parts"]],
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


def cap(desig, pn, net_a, net_b):
    return (desig, pn, [("1", "1", net_a), ("2", "2", net_b)])


res = cap


class FakePartsDB:
    def __init__(self, parts):
        self.parts = parts

    def decode(self, pn):
        return self.parts.get(pn)


def findings(check_func, ctx):
    return list(check_func(ctx))


def build_ctx(components, part_numbers=None, config=None, parts=None, **kw):
    design = Design(make_export(components, part_numbers, **kw))
    return Context(design, Config(config), FakePartsDB(parts) if parts is not None else None)
