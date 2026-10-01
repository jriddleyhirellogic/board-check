from boardcheck.checks import ERROR, INFO, WARNING, export, nets, parts, power
from boardcheck.partsdb import DecodedPart
from helpers import build_ctx, cap, findings, res


def ids(fs):
    return [f.check for f in fs]


# -- export -----------------------------------------------------------------

def test_export_version_too_old():
    ctx = build_ctx([cap("C1", "X", "3V3_A", "GND")], version="2.1.0")
    assert ids(findings(export.export_version, ctx)) == ["EXP001"]
    ctx = build_ctx([cap("C1", "X", "3V3_A", "GND")])
    assert findings(export.export_version, ctx) == []


def test_empty_sheet_unless_allowed():
    comps = [cap("C1", "X", "3V3_A", "GND")]
    ctx = build_ctx(comps, sheets=["TITLE.SchDoc"])
    assert "TITLE.SchDoc" in findings(export.empty_sheets, ctx)[0].message
    ctx = build_ctx(comps, sheets=["TITLE.SchDoc"], config={"export": {"empty_sheets_ok": ["TITLE.SchDoc"]}})
    assert findings(export.empty_sheets, ctx) == []


def test_lone_non_first_subpart():
    ctx = build_ctx([{"designator": "U1", "partNumber": "FPGA", "parts": [("U1B", [("A1", "IO", "X")])]}])
    f = findings(export.lone_subparts, ctx)
    assert ids(f) == ["EXP003"] and f[0].refs == ["U1"]
    ctx = build_ctx([{"designator": "U1", "partNumber": "FPGA",
                      "parts": [("U1A", [("A1", "IO", "X")]), ("U1B", [("A2", "IO", "Y")])]}])
    assert findings(export.lone_subparts, ctx) == []
    # channel B of a multi-channel sheet: the component is C153B itself, not a sub-part
    ctx = build_ctx([{"designator": "C153B", "partNumber": "CAP", "parts": [("C153B", [("1", "1", "X")])]}])
    assert findings(export.lone_subparts, ctx) == []


def test_part_number_missing_from_dictionary():
    ctx = build_ctx([cap("C1", "X", "3V3_A", "GND")])
    ctx.design.part_params.pop("X")
    assert ids(findings(export.unknown_part_numbers, ctx)) == ["EXP004"]


def test_conflicting_part_numbers_for_one_designator():
    ctx = build_ctx([
        {"designator": "U1", "partNumber": "A", "sheet": "1", "parts": [("U1A", [("1", "a", "N1")])]},
        {"designator": "U1", "partNumber": "B", "sheet": "2", "parts": [("U1B", [("2", "b", "N2")])]},
    ])
    assert ids(findings(export.conflicting_part_numbers, ctx)) == ["EXP005"]


def test_expected_totals():
    comps = [{"designator": "U1", "partNumber": "F", "parts": [("U1A", [("1", "a", "N1")])]}]
    cfg = {"export": {"expect": {"sheets": 2, "designators": {"U1": {"parts": 2, "pins": 1}, "U9": {}}}}}
    msgs = [f.message for f in findings(export.expected_totals, build_ctx(comps, config=cfg))]
    assert any("1 sheets exported, expected 2" in m for m in msgs)
    assert any("U1 has 1 parts, expected 2" in m for m in msgs)
    assert any("U9 is missing" in m for m in msgs)
    assert len(msgs) == 3


# -- nets -------------------------------------------------------------------

def test_single_pin_named_net_but_spares_allowed():
    ctx = build_ctx([
        ("U1", "IC", [("1", "IO1", "MY_SIGNAL"), ("2", "IO2", "B4_GPIO_SPARE0"), ("3", "IO3", "NetU1_3")]),
    ])
    f = findings(nets.single_pin_named_nets, ctx)
    assert [x.nets for x in f] == [["MY_SIGNAL"]]


def test_unconnected_pins_split_supply_from_signal():
    ctx = build_ctx([
        ("U1", "IC", [("1", "IO1", "NetU1_1"), ("2", "VDD", "NetU1_2"), ("3", "GND", "GND")]),
        ("C1", "X", [("1", "1", "GND"), ("2", "2", "3V3_A")]),
    ])
    info = findings(nets.unconnected_pins, ctx)
    err = findings(nets.unconnected_supply_pins, ctx)
    assert len(info) == 1 and "1 (IO1)" in info[0].message
    assert len(err) == 1 and "2 (VDD)" in err[0].message


def test_near_duplicate_and_whitespace_names():
    ctx = build_ctx([
        ("U1", "IC", [("1", "a", "PGOOD_1V2"), ("2", "b", "pgood_1v2"), ("3", "c", "X_ Y")]),
    ])
    assert ids(findings(nets.near_duplicate_names, ctx)) == ["NET004"]
    assert [f.nets for f in findings(nets.whitespace_in_names, ctx)] == [["X_ Y"]]


def test_diff_pairs():
    ctx = build_ctx([
        ("U1", "IC", [("1", "a", "CLK_P"), ("2", "b", "CLK_N"), ("3", "c", "LANE_P0"),
                      ("4", "d", "SYS_RESET_N"), ("5", "e", "NetU1_P5")]),
    ])
    f = findings(nets.diff_pairs, ctx)
    assert [x.nets for x in f] == [["LANE_P0"]]
    assert "LANE_N0" in f[0].message


def test_shorted_two_terminal_part():
    ctx = build_ctx([cap("C1", "X", "3V3_A", "3V3_A"), cap("C2", "X", "3V3_A", "GND")])
    assert [f.refs for f in findings(nets.shorted_parts, ctx)] == [["C1"]]


def test_floating_component_ignores_mechanical():
    ctx = build_ctx([
        ("R1", "X", [("1", "1", "NetR1_1"), ("2", "2", "NetR1_2")]),
        ("FID1", "F", [("1", "1", "NetFID1_1")]),
    ])
    assert [f.refs for f in findings(nets.floating_components, ctx)] == [["R1"]]


# -- parts ------------------------------------------------------------------

def _res_part(pn, ohms, size="0603"):
    return DecodedPart(pn, "resistor", "TEST", resistance=ohms, power_max=0.1, tolerance=1.0, size=size)


def test_comment_mismatch_severity():
    comps = [
        {"designator": "R1", "partNumber": "PN60K4", "comment": "PN909K", "parts": [("R1", [])]},
        {"designator": "U1", "partNumber": "FPGA-1", "comment": "FPGA-1_PROJECT", "parts": [("U1", [])]},
        {"designator": "U2", "partNumber": "ABC", "comment": "XYZ", "parts": [("U2", [])]},
    ]
    parts_db = {"PN60K4": _res_part("PN60K4", 60400), "PN909K": _res_part("PN909K", 909000, "0805")}
    f = {x.part_number: x for x in findings(parts.comment_vs_part_number, build_ctx(comps, parts=parts_db))}
    assert f["PN60K4"].severity == ERROR and "909k" in f["PN60K4"].message
    assert f["FPGA-1"].severity == INFO
    assert f["ABC"].severity == WARNING


def test_required_params():
    pns = {"C-PN": {"Part Number": "C-PN", "Manufacturer": "M", "C_Value": "1uF", "Voltage": "",
                    "Tolerance": "10%", "Dialectric": "X7R", "Size": "0603"}}
    f = findings(parts.required_params, build_ctx([cap("C1", "C-PN", "A", "B")], part_numbers=pns))
    assert len(f) == 1 and f[0].message == "C-PN is missing Voltage"


def test_params_vs_decoded():
    pns = {"C-PN": {"C_Value": "100nF", "Voltage": "50V", "Dialectric": "X7R", "Tolerance": "10%", "Size": "0603"},
           "T-PN": {"C_Value": "330uF", "Voltage": "10V", "Tolerance": "10%", "Size": "2917"}}
    db = {"C-PN": DecodedPart("C-PN", "capacitor", "D", capacitance=100e-9, voltage_rated=25.0,
                              tolerance=10.0, size="0603", dielectric="Ceramic"),
          "T-PN": DecodedPart("T-PN", "capacitor", "D", capacitance=330e-6, voltage_rated=10.0,
                              tolerance=10.0, size="7343-43")}
    ctx = build_ctx([cap("C1", "C-PN", "A", "B"), cap("C2", "T-PN", "A", "B")], part_numbers=pns, parts=db)
    f = findings(parts.params_vs_decoded, ctx)
    # Voltage differs; "Ceramic" is not compared as a dielectric; 7343 metric == 2917.
    assert len(f) == 1 and f[0].part_number == "C-PN"
    assert "Voltage 50V vs decoded 25V" in f[0].message and "dielectric" not in f[0].message


def test_qualification_missing_and_not_allowed():
    pns = {"A": {"Qualification": "AEC-Q200"}, "B": {"Qualification": "COTS"}, "C": {}}
    ctx = build_ctx([cap("C1", "A", "x", "y"), cap("C2", "B", "x", "y"), cap("C3", "C", "x", "y")],
                    part_numbers=pns)
    f = {x.part_number: x.message for x in findings(parts.qualification, ctx)}
    assert set(f) == {"B", "C"}


def test_prefix_vs_decoded_type():
    db = {"R-PN": _res_part("R-PN", 100)}
    ctx = build_ctx([cap("C1", "R-PN", "a", "b")], parts=db)
    assert ids(findings(parts.prefix_vs_type, ctx)) == ["PRT006"]


# -- power ------------------------------------------------------------------

def test_cap_voltage_over_rating_and_derating():
    pns = {"C16V": {"Voltage": "16V", "Dialectric": "X7R"}, "C50V": {"Voltage": "50V", "Dialectric": "X7R"}}
    ctx = build_ctx([
        cap("C1", "C16V", "28V0_BUS", "GND"),   # over rating
        cap("C2", "C16V", "12V0_BUS", "GND"),   # 75% > 60% ceramic limit
        cap("C3", "C50V", "12V0_BUS", "GND"),   # fine
        cap("C4", "C16V", "SIGNAL", "GND"),     # unknown voltage, skipped
    ], part_numbers=pns)
    f = {x.refs[0]: x for x in findings(power.cap_voltage, ctx)}
    assert set(f) == {"C1", "C2"}
    assert f["C1"].severity == ERROR
    assert f["C2"].severity is None  # runner fills in the check default (warning)


def test_cap_rating_uses_lower_of_param_and_decoded():
    pns = {"C": {"Voltage": "50V", "Dialectric": "X7R"}}
    db = {"C": DecodedPart("C", "capacitor", "D", voltage_rated=10.0)}
    ctx = build_ctx([cap("C1", "C", "12V0_BUS", "GND")], part_numbers=pns, parts=db)
    f = findings(power.cap_voltage, ctx)
    assert f[0].severity == ERROR and "decoded part number" in f[0].message


def test_resistor_power_and_zero_ohm_between_rails():
    pns = {"R100": {"R_Value": "100R", "Power_Rating": "100mW"}, "R0": {"R_Value": "0R"},
           "R10K": {"R_Value": "10K", "Power_Rating": "100mW"}}
    ctx = build_ctx([
        res("R1", "R100", "5V0_A", "GND"),     # 250 mW on 100 mW
        res("R2", "R0", "3V3_A", "1V8_B"),     # shorts two rails
        res("R3", "R10K", "5V0_A", "GND"),     # 2.5 mW, fine
    ], part_numbers=pns)
    f = {x.refs[0]: x for x in findings(power.resistor_power, ctx)}
    assert set(f) == {"R1", "R2"}
    assert "shorts two different rails" in f["R2"].message


def test_rail_decoupling_and_testpoints():
    ctx = build_ctx([
        cap("C1", "X", "3V3_A", "GND"),
        ("U1", "IC", [("1", "VDD", "3V3_A"), ("2", "VDD", "1V8_B"), ("3", "GND", "GND")]),
        ("TP1", "TP", [("1", "1", "1V8_B")]),
    ])
    assert [f.nets for f in findings(power.rail_decoupling, ctx)] == [["1V8_B"]]
    assert [f.nets for f in findings(power.rail_testpoints, ctx)] == [["3V3_A"]]


def test_supply_pins_on_wrong_nets():
    ctx = build_ctx([
        ("U1", "IC", [("1", "VSS", "GND"), ("2", "VDD", "GND"), ("3", "GND", "3V3_A"), ("4", "VDD", "3V3_A")]),
    ])
    f = findings(power.supply_pin_nets, ctx)
    assert len(f) == 1
    assert "2 (VDD) on ground" in f[0].message and "3 (GND) on '3V3_A'" in f[0].message
    assert "VSS" not in f[0].message


def test_i2c_pullups():
    ctx = build_ctx([
        ("U1", "IC", [("1", "SCL", "I2C0_SCL"), ("2", "SDA", "I2C0_SDA"), ("3", "SCLK", "ADC_SCLK")]),
        res("R1", "X", "I2C0_SCL", "3V3_A"),
    ])
    assert [f.nets for f in findings(power.i2c_pullups, ctx)] == [["I2C0_SDA"]]


def test_pwr007_local_supply_without_capacitor():
    from boardcheck.checks import power
    ctx = build_ctx([("U1", "LDO", [("1", "VOUT", "NetU1_1"), ("2", "GND", "GND")]),
                     ("U2", "IC", [("1", "VDD", "NetU1_1"), ("2", "VSENSE", "FB"), ("3", "GND", "GND")]),
                     ("U3", "IC", [("1", "VSENSE", "FB")])])
    f = findings(power.supply_pin_decoupling, ctx)
    assert len(f) == 1 and "'NetU1_1' supplies U2.1 VDD" in f[0].message, "VSENSE is not a supply pin"
    ctx = build_ctx([("U2", "IC", [("1", "VDD", "NetU1_1"), ("2", "GND", "GND")]),
                     ("U1", "LDO", [("1", "VOUT", "NetU1_1")]), cap("C1", "CAP", "NetU1_1", "GND")])
    assert findings(power.supply_pin_decoupling, ctx) == []


def test_pwr008_supply_outside_recommended_range():
    from helpers import FakePartsDB
    from boardcheck.checks import Context
    from boardcheck.config import Config
    from boardcheck.model import Design
    from helpers import make_export
    part = {"pin_functions": {"VA": {"direction": "power", "pins": ["2"]}, "VD": {"direction": "power", "pins": ["3"]}},
            "electrical_characteristics": {
                "supply_va": {"kind": "range_table", "unit": "V", "applies_to": ["VA"], "rows": [{"min": 2.7, "max": 5.25}]},
                "supply_vd": {"kind": "range_table", "unit": "V", "rows": [{"min": 2.7, "max": "VA"}]}}}
    d = Design(make_export([("U1", "ADC", [("2", "VA", "1V8"), ("3", "VD", "3V3")])]))
    ctx = Context(d, Config(), FakePartsDB({"ADC": part}))
    f = findings(power.supply_in_range, ctx)
    msgs = sorted(x.message for x in f)
    assert len(f) == 2 and "U1 (ADC) VA is on '1V8' (1.8 V); recommended 2.7-5.25 V" in msgs[0]
    assert "U1 (ADC) VD is on '3V3' (3.3 V); recommended 2.7-1.8 V" in msgs[1], "VD may not exceed VA"


def _ldo_ctx(top="120k", bottom="60k", extra=()):
    from boardcheck.checks import Context
    from boardcheck.config import Config
    from boardcheck.model import Design
    from helpers import FakePartsDB, make_export
    ldo = {"pin_functions": {"IN": {"direction": "power", "pins": ["1"]}, "OUT": {"direction": "power", "pins": ["9"]},
                             "ADJ": {"direction": "input", "pins": ["8"]}},
           "electrical_characteristics": {"v_feedback": {"kind": "range_table", "unit": "V", "applies_to": ["ADJ"],
                                                         "rows": [{"min": 0.594, "typ": 0.6, "max": 0.606}]}},
           "regulator": {"feedback_pin": "ADJ", "feedback_bias_current": 1.6e-08}}
    comps = [("U1", "LDO", [("1", "IN", "3V3"), ("9", "OUT", "1V8_X"), ("8", "ADJ", "FB")]),
             res("R1", "RT", "1V8_X", "FB"), res("R2", "RB", "FB", "GND")] + list(extra)
    d = Design(make_export(comps))
    d.part_params["RT"]["R_Value"] = top
    d.part_params["RB"]["R_Value"] = bottom
    for pn in ("RS", "RK"):
        if pn in d.part_params:
            d.part_params[pn]["R_Value"] = {"RS": "100", "RK": "2k"}[pn]
    return Context(d, Config(), FakePartsDB({"LDO": ldo}))


def test_pwr009_regulator_setpoint_against_rail_name():
    # 0.6 V x (1 + 120k/60k) - 16 nA x 120k = 1.798 V: matches 1V8_X
    ctx = _ldo_ctx()
    assert findings(power.regulator_output, ctx) == []
    from boardcheck.checks.power import regulator_setpoint
    sp = regulator_setpoint(ctx, ctx.design.components["U1"], ctx.partsdb.regulator("LDO"))
    assert abs(sp[0] - (0.6 * 3 - 1.6e-8 * 120e3)) < 1e-9
    # a 1.5 V divider on a rail named 1V8
    f = findings(power.regulator_output, _ldo_ctx(top="90k"))
    assert len(f) == 1 and "sets '1V8_X' to 1.499 V" in f[0].message and "named for 1.8 V" in f[0].message


def test_pwr009_sense_nets_are_part_of_the_output():
    # a resistor from the feedback node to the rail's sense net is solved with the rail (both 1.8 V nominal)
    ctx = _ldo_ctx(extra=[res("R3", "RS", "FB", "1V8_X_SNS")])
    ctx.design.part_params["RT"]["R_Value"] = "120k"
    from boardcheck.checks.power import feedback_network
    k, rth, out, rs = feedback_network(ctx, "FB")
    assert out == "1V8_X" and {r.designator for r in rs} == {"R1", "R2", "R3"}
    assert findings(power.regulator_output, ctx)[0].message.startswith("U1 (LDO) sets '1V8_X' to")


def _headroom_ctx(vin_net="2V2", rimax="1k"):
    ctx = _ldo_ctx(extra=[("U1", "LDO", [("5", "IMAX", "ILIM")]), res("R9", "RIMAX", "ILIM", "GND")])
    ctx.design.part_params["RIMAX"]["R_Value"] = rimax
    u1 = ctx.design.components["U1"]
    next(p for p in u1.pins if p.name == "IN").net = vin_net
    ldo = ctx.partsdb.parts["LDO"]
    ldo["pin_functions"]["IMAX"] = {"direction": "input", "pins": ["5"]}
    ldo["electrical_characteristics"]["v_dropout"] = {"kind": "range_table", "unit": "V", "rows": [
        {"max": 0.21, "conditions": {"load_current": {"value": 10, "unit": "mA"}}},
        {"max": 0.51, "conditions": {"load_current": {"value": 500, "unit": "mA"}}}]}
    ldo["regulator"].update(topology="linear", input_pins=["IN"], output_current_max=0.5,
                            current_limit={"pin": "IMAX", "k": 300.0, "internal": 0.9})
    return ctx


def test_pwr010_ldo_headroom_at_its_current_limit():
    # 1V8_X at up to 0.606 x 3 - 16 nA x 120k = 1.816 V from 2.2 V: 0.384 V of headroom.
    # R9 = 1k programs 300 mA, where the maximum dropout is 0.21 + 0.3 x 290/490 = 0.388 V.
    (f,) = findings(power.ldo_headroom, _headroom_ctx())
    assert f.severity is None or f.severity == "warning"
    assert "U1 (LDO): '2V2' at 2.200 V feeds '1V8_X' at up to 1.816 V, 0.384 V of headroom" in f.message
    assert "R9 programs a 300 mA limit (388 mV dropout there)" in f.message and "about 294 mA" in f.message
    # 1.5k: 200 mA, 0.326 V dropout: fits
    assert findings(power.ldo_headroom, _headroom_ctx(rimax="1k5")) == []
    # 1.9 V in: below even the light-load dropout
    (e,) = findings(power.ldo_headroom, _headroom_ctx(vin_net="1V9"))
    assert e.severity == "error" and "below the 210 mV maximum dropout" in e.message


def _en_ctx(top="100k", bottom="20k", vin="12V0"):
    from boardcheck.checks import Context
    from boardcheck.config import Config
    from boardcheck.model import Design
    from helpers import FakePartsDB, make_export
    rt = lambda applies, rows, unit="V": {"kind": "range_table", "unit": unit, "applies_to": applies, "rows": rows}  # noqa: E731
    buck = {"pin_functions": {"VIN": {"direction": "power", "pins": ["1"]}, "EN": {"direction": "input", "pins": ["2"]}},
            "electrical_characteristics": {
                "supply_vin": rt(["VIN"], [{"min": 4.5, "max": 17}]),
                "vt_pos": rt(["EN"], [{"typ": 1.21, "max": 1.26}]),
                "vt_neg": rt(["EN"], [{"min": 1.1, "typ": 1.17}]),
                "i_en_pullup": rt(["EN"], [{"typ": 1.15}], "uA")},
            "regulator": {"enable_pin": "EN", "input_pins": ["VIN"], "feedback_pin": "FB"}}
    comps = [("U1", "BUCK", [("1", "VIN", vin), ("2", "EN", "EN_DIV")]),
             res("R1", "RT", vin, "EN_DIV"), res("R2", "RB", "EN_DIV", "GND")]
    d = Design(make_export(comps))
    d.part_params["RT"]["R_Value"] = top
    d.part_params["RB"]["R_Value"] = bottom
    return Context(d, Config(), FakePartsDB({"BUCK": buck}))


def test_pwr011_enable_divider_turn_on_voltage():
    # 100k / 20k: EN = Vin / 6 + 1.15 uA x 16.7k; on at (1.26 - 0.0192) x 6 = 7.45 V, off at 6.49 V
    (f,) = findings(power.turn_on_voltage, _en_ctx())
    assert f.severity == "info" and f.message == ("U1 (BUCK) EN on 'EN_DIV' (R1, R2 and its 1.15 uA pull-up): turns on "
                                                  "at 7.45 V on '12V0', off at 6.49 V")
    # 100k / 10k: on at 13.7 V, above the 12 V rail
    (e,) = findings(power.turn_on_voltage, _en_ctx(bottom="10k"))
    assert e.severity is None and e.message.endswith("above the rail's 12 V")
    # 100k / 50k: off at 3.19 V, below the 4.5 V minimum input
    (w,) = findings(power.turn_on_voltage, _en_ctx(bottom="50k"))
    assert w.severity == "warning" and w.message.endswith("below the regulator's 4.5 V minimum input")
