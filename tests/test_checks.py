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
