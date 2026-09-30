from boardcheck.checks import ERROR, WARNING, export, pins
from boardcheck.model import Design
from helpers import build_ctx, findings, make_export, res


def pf(**directions):
    return {"pin_functions": {k: {"direction": v} for k, v in directions.items()}}


def test_electrical_type_loaded_and_null_net_is_unconnected():
    export_ = make_export([("U1", "IC", [("1", "A", "N1", "input"), ("2", "B", None)])])
    d = Design(export_)
    u1 = d.components["U1"]
    assert u1.pins[0].electrical == "input" and u1.pins[1].electrical is None
    assert u1.pins[1].net == "NetU1_2" and d.nets["NetU1_2"].auto_named
    assert d.has_pin_types


def test_exp007_when_export_has_no_pin_types():
    assert [f.check for f in findings(export.pin_types_present, build_ctx([("U1", "IC", [("1", "A", "N")])]))] \
        == ["EXP007"]
    assert findings(export.pin_types_present, build_ctx([("U1", "IC", [("1", "A", "N", "io")])])) == []


def test_part_data_wins_and_names_match_with_overbars():
    ctx = build_ctx([("U1", "UART", [("1", "TXD", "N1", "input"), ("2", "R\\T\\S\\", "N2", "output"),
                                     ("3", "EXTRA", "N3", "io")])],
                    parts={"UART": pf(TXD="output", RTS="output")})
    pt = pins.PinTypes(ctx)
    u1 = ctx.design.components["U1"]
    assert pt.effective(u1.pins[0]) == ("output", pins.PART)
    assert pt.effective(u1.pins[1]) == ("output", pins.PART)
    assert pt.effective(u1.pins[2]) == ("io", pins.SCHEMATIC)


def test_pin001_flags_symbol_part_disagreement():
    ctx = build_ctx([("U1", "UART", [("1", "TXD", "N1", "input"), ("2", "RXD", "N2", "input")])],
                    parts={"UART": pf(TXD="output", RXD="input")})
    f = findings(pins.schematic_vs_part, ctx)
    assert len(f) == 1 and "1 TXD: symbol input, part data output" in f[0].message


def test_pin002_lists_ics_without_pin_data():
    ctx = build_ctx([("U1", "NODATA", [("1", "A", "N1")]), ("U2", "UART", [("1", "TXD", "N1")]),
                     res("R1", "RES", "N1", "GND")],
                    parts={"UART": pf(TXD="output")})
    assert [f.part_number for f in findings(pins.missing_pin_data, ctx)] == ["NODATA"]


def test_pin003_unmatched_entries_and_unknown_directions():
    ctx = build_ctx([("U1", "UART", [("1", "TXD", "N1")])],
                    parts={"UART": pf(TXD="output", RESET="input", CLK="sideways")})
    msg = findings(pins.pin_data_alignment, ctx)[0].message
    assert "CLK, RESET" in msg and "sideways" in msg


def test_contention_severity_depends_on_source():
    # Both drivers from part data: error.
    ctx = build_ctx([("U1", "A", [("1", "Y", "BUS")]), ("U2", "A", [("1", "Y", "BUS")])],
                    parts={"A": pf(Y="output")})
    f = findings(pins.contention, ctx)
    assert len(f) == 1 and f[0].severity == ERROR
    # One driver typed only on the symbol: warning, and labelled as such.
    ctx = build_ctx([("U1", "A", [("1", "Y", "BUS")]), ("U2", "B", [("1", "Q", "BUS", "output")])],
                    parts={"A": pf(Y="output")})
    f = findings(pins.contention, ctx)
    assert f[0].severity == WARNING and "schematic only" in f[0].message


def test_contention_ignores_tristate_and_flags_output_on_rail():
    ctx = build_ctx([("U1", "A", [("1", "Y", "BUS", "io"), ("2", "Z", "3V3_A", "output")]),
                     ("U2", "A", [("1", "Y", "BUS", "io")])])
    f = findings(pins.contention, ctx)
    assert [x.nets for x in f] == [["3V3_A"]] and "supply net" in f[0].message


def test_floating_inputs():
    ctx = build_ctx([
        ("U1", "A", [("1", "IN", "ONLY_INPUTS", "input"), ("2", "IN2", "PULLED", "input"),
                     ("3", "IN3", "MYSTERY", "input"), ("4", "IN4", "NetU1_4", "input")]),
        ("U2", "B", [("1", "X", "MYSTERY")]),     # unknown type: could drive
        res("R1", "R", "PULLED", "3V3_A"),
        ("U3", "C", [("1", "IN", "ONLY_INPUTS", "input")]),
    ])
    assert sorted(f.nets[0] for f in findings(pins.floating_inputs, ctx)) == ["NetU1_4", "ONLY_INPUTS"]


def test_open_drain_needs_pullup():
    ctx = build_ctx([
        ("U1", "A", [("1", "INT", "IRQ_A"), ("2", "INT2", "IRQ_B")]),
        res("R1", "R", "IRQ_A", "3V3_A"),
    ], parts={"A": pf(INT="open_drain", INT2="open_drain")})
    assert [f.nets for f in findings(pins.open_drain_pullups, ctx)] == [["IRQ_B"]]
