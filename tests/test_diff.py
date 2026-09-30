import json

from boardcheck import diff as diffmod
from boardcheck.cli import main
from boardcheck.model import Design
from helpers import make_export


def _design(components, **kw):
    return Design(make_export(components, **kw), source="x.json")


BASE = [("U1", "IC", [("1", "A", "SIG_A"), ("2", "B", "NetR1_1"), ("3", "C", "SIG_C")]),
        ("R1", "RES", [("1", "1", "NetR1_1"), ("2", "2", "GND")]),
        ("U2", "IC", [("1", "A", "SIG_A"), ("2", "B", "SIG_C")])]


def test_identical_exports_have_no_changes():
    d = diffmod.diff(_design(BASE), _design(BASE))
    assert d.empty and "No connectivity" in diffmod.markdown(d)


def test_rename_move_add_remove_and_part_changes():
    new = [("U1", "IC", [("1", "A", "SIG_A_RENAMED"), ("2", "B", "NetR1_1"), ("3", "C", "SIG_A_RENAMED")]),
           ("R1", "RES2", [("1", "1", "NetR1_1"), ("2", "2", "GND")]),
           ("U3", "IC", [("1", "A", "NEW_NET")])]
    old_d = _design(BASE)
    new_d = _design(new, part_numbers={"IC": {"Part Number": "IC", "Qualification": "AEC-Q100"}})
    d = diffmod.diff(old_d, new_d)
    assert d.added_components == ["U3"] and d.removed_components == ["U2"]
    assert d.part_number_changes == [("R1", "RES", "RES2")]
    assert ("SIG_A", "SIG_A_RENAMED") not in d.renamed_nets, "U1.3 joined it, so it is not a pure rename"
    assert ("U1.3", "SIG_C", "SIG_A_RENAMED") in d.moved_pins
    assert not any(p[0] == "U1.1" for p in d.moved_pins), "U1.1 followed its net's new name"
    assert "NEW_NET" in d.added_nets
    assert ("IC", "Qualification", None, "AEC-Q100") in d.param_changes


def test_pure_rename_is_reported_as_rename_only():
    new = [(c[0], c[1], [(p[0], p[1], "SIG_A2" if p[2] == "SIG_A" else p[2]) for p in c[2]]) for c in BASE]
    d = diffmod.diff(_design(BASE), _design(new))
    assert d.renamed_nets == [("SIG_A", "SIG_A2")] and d.moved_pins == []
    assert d.added_nets == [] and d.removed_nets == []


def test_cli_diff_reports_new_findings_and_fails_on_them(tmp_path):
    old = make_export([("C1", "X", [("1", "1", "3V3_A"), ("2", "2", "GND")])])
    new = make_export([("C1", "X", [("1", "1", "3V3_A"), ("2", "2", "3V3_A")])])       # shorted: NET007
    a, b = tmp_path / "a.json", tmp_path / "b.json"
    a.write_text(json.dumps(old))
    b.write_text(json.dumps(new))
    out = tmp_path / "d.json"
    code = main(["diff", str(a), str(b), "--no-partsdb", "-f", "json", "-o", str(out), "--fail-on", "warning"])
    data = json.loads(out.read_text())
    assert code == 1 and any(f["check"] == "NET007" for f in data["new_findings"])
    assert data["pins_moved"] == [["C1.2", "GND", "3V3_A"]]
    assert main(["diff", str(a), str(b), "--no-partsdb", "--no-findings"]) == 0
