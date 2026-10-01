from boardcheck.checks import export, parts
from boardcheck.diff import diff
from boardcheck.model import Design
from helpers import build_ctx, findings, make_export


def _comp(desig, pn, footprint, pins=(("1", "1", "A"), ("2", "2", "B"))):
    return {"designator": desig, "partNumber": pn, "parts": [(desig, list(pins))], "footprint": footprint,
            "footprintLibrary": "LIB.PcbLib" if footprint else None, "footprintAlternates": []}


def test_footprints_are_read_and_checked():
    ctx = build_ctx([_comp("R1", "RC0603", "RESC1608X55"), _comp("R2", "RC0603", "RESC1608X55"),
                     _comp("R3", "RC0603", "RESC2012X65"), _comp("C1", "CAP", None),
                     _comp("MH1", "HOLE", None)])
    assert ctx.design.has_footprints and ctx.design.components["R1"].footprint == "RESC1608X55"
    assert findings(export.footprints_present, ctx) == []
    (f,) = findings(parts.footprint_consistency, ctx)
    assert f.message == "RC0603 uses 2 footprints (RESC1608X55: R1, R2; RESC2012X65: R3)"
    (m,) = findings(parts.missing_footprint, ctx)
    assert m.message == "C1 (CAP): no current footprint on the symbol", "MH1 is mechanical"


def test_older_exports_skip_footprint_checks():
    from boardcheck.config import Config
    from boardcheck.runner import run
    design = Design(make_export([("R1", "RC0603", [("1", "1", "A"), ("2", "2", "B")])]))
    assert not design.has_footprints
    result = run(design, Config(), only={"PRT008", "PRT009", "EXP008"})
    assert ("PRT008", "export has no footprints (needs export script >= 2.4.0)") in result.skipped
    assert [f.check for f in result.active] == ["EXP008"]


def test_diff_reports_footprint_changes():
    old = Design(make_export([_comp("R1", "RC0603", "RESC1608X55")]))
    new = Design(make_export([_comp("R1", "RC0603", "RESC2012X65")]))
    assert diff(old, new).footprint_changes == [("R1", "RESC1608X55", "RESC2012X65")]
    legacy = Design(make_export([("R1", "RC0603", [("1", "1", "A"), ("2", "2", "B")])]))
    assert diff(legacy, new).footprint_changes == [], "no footprint data on one side: nothing to compare"
