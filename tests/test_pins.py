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
                    parts={"UART": pf(TXD="output", **{"RTS#": "output"})})
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


def test_inputs_tied_to_supply_are_not_floating():
    ctx = build_ctx([("U1", "A", [("1", "EN", "3V3_A", "input"), ("2", "SEL", "GND", "input")])])
    assert findings(pins.floating_inputs, ctx) == []


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


def buf(oe_net, y_net, a_net="A_IN"):
    """A one-channel 3-state buffer with an active-low enable."""
    return ("U1", "BUF", [("1", "O\\E\\", oe_net), ("2", "A", a_net), ("3", "Y", y_net)])


BUF_DATA = {"BUF": {"pin_functions": {
    "_source": "test datasheet",
    "O\\E\\": {"direction": "input", "pins": ["1"]},
    "A": {"direction": "input", "pins": ["2"], "internal_bias": "pull_down"},
    "Y": {"direction": "output", "pins": ["3"],
          "three_state": {"enable": [{"pin": "O\\E\\", "active": "low"}], "logic": "any"}},
}}}


def test_underscore_keys_are_annotations():
    ctx = build_ctx([buf("GND", "OUT")], parts=BUF_DATA)
    table = pins.PinTypes(ctx).table("BUF")
    assert [pp.key for pp in table["entries"]] == ["O\\E\\", "A", "Y"]


def test_three_state_output_counts_only_when_enable_strapped():
    y = lambda ctx: ctx.design.components["U1"].pins[2]  # noqa: E731
    # Enable tied straight to ground: always driving.
    ctx = build_ctx([buf("GND", "OUT")], parts=BUF_DATA)
    assert pins.PinTypes(ctx).effective(y(ctx)) == ("output", pins.PART)
    # Enable pulled to ground through a resistor with only inputs on the net: still strapped.
    ctx = build_ctx([buf("OE_STRAP", "OUT"), res("R1", "R", "OE_STRAP", "GND")], parts=BUF_DATA)
    assert pins.PinTypes(ctx).effective(y(ctx))[0] == "output"
    # Enable driven by something else: may be off, so not counted as a driver.
    ctx = build_ctx([buf("OE_CTRL", "OUT"), ("U2", "MCU", [("1", "GPIO", "OE_CTRL", "io")])],
                    parts=BUF_DATA)
    assert pins.PinTypes(ctx).effective(y(ctx))[0] == "hiz"
    # Enable pulled to the inactive level: disabled.
    ctx = build_ctx([buf("OE_STRAP", "OUT"), res("R1", "R", "OE_STRAP", "3V3_A")], parts=BUF_DATA)
    assert pins.PinTypes(ctx).effective(y(ctx))[0] == "hiz"


def test_disabled_three_state_outputs_do_not_contend():
    data = dict(BUF_DATA)
    ctx = build_ctx([buf("OE1", "BUS"), ("U2", "BUF", [("1", "O\\E\\", "OE2"), ("2", "A", "A2"), ("3", "Y", "BUS")]),
                     ("U3", "MCU", [("1", "G1", "OE1", "io"), ("2", "G2", "OE2", "io")])], parts=data)
    assert findings(pins.contention, ctx) == []
    ctx = build_ctx([buf("GND", "BUS"), ("U2", "BUF", [("1", "O\\E\\", "GND"), ("2", "A", "A2"), ("3", "Y", "BUS")])],
                    parts=data)
    assert findings(pins.contention, ctx)[0].severity == ERROR


def test_internal_bias_means_not_floating():
    ctx = build_ctx([buf("GND", "OUT", a_net="NetU1_2")], parts=BUF_DATA)
    assert findings(pins.floating_inputs, ctx) == []


def test_overbar_is_part_of_the_name_and_pin_numbers_are_checked():
    data = {"LVDS": {"pin_functions": {
        "G": {"direction": "input", "pins": ["4"]},
        "G\\": {"direction": "input", "pins": ["12"]},
    }}}
    ok = build_ctx([("U1", "LVDS", [("4", "G", "3V3_A"), ("12", "G\\", "GND")])], parts=data)
    assert findings(pins.pin_data_alignment, ok) == []
    swapped = build_ctx([("U1", "LVDS", [("12", "G", "3V3_A"), ("4", "G\\", "GND")])], parts=data)
    msg = findings(pins.pin_data_alignment, swapped)[0].message
    assert "G is pin 12 on the symbol, 4 in the part data" in msg


def test_match_by_package_pin_number_when_names_differ():
    data = {"X": {"pin_functions": {"DATA_OUT": {"direction": "output", "pins": ["7"]}}}}
    ctx = build_ctx([("U1", "X", [("7", "DOUT", "N1")])], parts=data)
    pin = ctx.design.components["U1"].pins[0]
    assert pins.PinTypes(ctx).effective(pin) == ("output", pins.PART)
    assert findings(pins.pin_data_alignment, ctx) == []


def test_three_state_symbol_drawn_as_hiz_agrees():
    ctx = build_ctx([("U1", "BUF", [("1", "O\\E\\", "GND", "input"), ("2", "A", "N", "input"),
                                    ("3", "Y", "OUT", "hiz")])], parts=BUF_DATA)
    assert findings(pins.schematic_vs_part, ctx) == []


RX = {"pin_functions": {
    "A": {"direction": "input", "function": "LVDS_IN_P", "diff_pair": "B", "pins": ["1"], "io_standard": "LVDS"},
    "B": {"direction": "input", "function": "LVDS_IN_N", "diff_pair": "A", "pins": ["2"], "io_standard": "LVDS"}}}


def _rx_ctx(extra, p="SIG_P", n="SIG_N", values=None):
    from helpers import res
    comps = [("U1", "RX", [("1", "A", p), ("2", "B", n)]), ("J1", "CONN", [("1", "1", "SIG_P"), ("2", "2", "SIG_N")])]
    ctx = build_ctx(comps + list(extra), parts={"RX": RX})
    for pn, v in (values or {}).items():
        ctx.design.part_params[pn]["R_Value"] = v
    return ctx


def test_diff_receiver_termination():
    from helpers import res
    from boardcheck.checks import pins
    ctx = _rx_ctx([])
    (f,) = findings(pins.diff_termination, ctx)
    assert f.message == "U1 A/B on 'SIG_P'/'SIG_N': no 80-150 ohm termination across the pair"
    assert findings(pins.diff_termination, _rx_ctx([res("R1", "R100", "SIG_P", "SIG_N")], values={"R100": "100"})) == []
    # split termination: 2 x 49.9 through a centre tap with a capacitor to ground
    split = [res("R1", "R50", "SIG_P", "CT"), res("R2", "R50", "CT", "SIG_N"), ("C1", "CAP", [("1", "1", "CT"), ("2", "2", "GND")])]
    assert findings(pins.diff_termination, _rx_ctx(split, values={"R50": "49.9"})) == []
    # wrong value, and a second termination
    (w,) = findings(pins.diff_termination, _rx_ctx([res("R1", "R1K", "SIG_P", "SIG_N")], values={"R1K": "1k"}))
    assert "(found R1 1000 ohm)" in w.message
    two = [res("R1", "R100", "SIG_P", "SIG_N"), res("R2", "R100", "SIG_P", "SIG_N")]
    (d,) = findings(pins.diff_termination, _rx_ctx(two, values={"R100": "100"}))
    assert d.severity == "warning" and "terminated more than once (R1 100 ohm, R2 100 ohm)" in d.message


def test_diff_receiver_polarity():
    from boardcheck.checks import pins
    assert findings(pins.diff_polarity, _rx_ctx([])) == []
    (f,) = findings(pins.diff_polarity, _rx_ctx([], p="SIG_N", n="SIG_P"))
    assert f.message == "U1 A (+) is on 'SIG_N' and B (-) on 'SIG_P': the pair is swapped"
