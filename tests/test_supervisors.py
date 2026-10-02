from boardcheck.checks import levels, pins, power
from helpers import build_ctx, findings, res


def _rt(applies, rows, unit="V"):
    return {"kind": "range_table", "unit": unit, "applies_to": applies, "rows": rows}


HSC = {
    "pin_functions": {
        "VCAP": {"direction": "power", "function": "REGULATOR_CAP", "pins": ["1"]},
        "UV": {"direction": "input", "function": "UV", "pins": ["3"], "io_standard": "analog"},
        "OV": {"direction": "input", "function": "OV", "pins": ["4"], "io_standard": "analog"},
        "FAULT": {"direction": "open_drain", "function": "FAULT_N", "pins": ["6"]},
        "GND": {"direction": "power", "function": "GROUND", "pins": ["7"]},
        "FB_PG": {"direction": "input", "function": "POWER_GOOD_SENSE", "pins": ["10"], "io_standard": "analog"},
        "FLB": {"direction": "input", "function": "FOLDBACK", "pins": ["11"], "io_standard": "analog"},
        "SENSE-": {"direction": "input", "function": "CURRENT_SENSE_N", "pins": ["14"], "io_standard": "analog"},
        "VCC": {"direction": "power", "function": "POWER", "pins": ["15"]}},
    "electrical_characteristics": {
        "v_vcap": _rt(["VCAP"], [{"min": 3.546, "typ": 3.6, "max": 3.636}]),
        "vi_abs": _rt(["UV", "OV", "FLB", "FB_PG"], [{"min": -0.3, "max": 6}]),
        "vth_uv_rising": _rt(["UV"], [{"min": 1.04, "typ": 1.06, "max": 1.08}]),
        "vth_uv_falling": _rt(["UV"], [{"min": 0.985, "typ": 1.0, "max": 1.015}]),
        "vth_ov_rising": _rt(["OV"], [{"min": 0.985, "typ": 1.0, "max": 1.015}]),
        "vth_ov_falling": _rt(["OV"], [{"min": 0.95, "typ": 0.97, "max": 0.99}]),
        "vth_pg_rising": _rt(["FB_PG"], [{"min": 0.985, "typ": 1.0, "max": 1.015}]),
        "vth_pg_falling": _rt(["FB_PG"], [{"min": 0.95, "typ": 0.97, "max": 0.99}]),
        "v_sense_cl": _rt(["VCC", "SENSE-"], [{"min": 0.047, "typ": 0.05, "max": 0.053}])},
    "monitors": [{"pin": "UV", "kind": "undervoltage", "rising": "vth_uv_rising", "falling": "vth_uv_falling"},
                 {"pin": "OV", "kind": "overvoltage", "rising": "vth_ov_rising", "falling": "vth_ov_falling"},
                 {"pin": "FB_PG", "kind": "power_good", "rising": "vth_pg_rising", "falling": "vth_pg_falling"}],
    "current_sense": {"pins": ["VCC", "SENSE-"], "v_limit": "v_sense_cl"},
}

VALUES = {"R49K9": ("49.9k", None), "R5K36": ("5.36k", None), "R2K7": ("2.7k", None), "R24K": ("24k", None),
          "R100K": ("100k", None), "RS": ("0.05", "0.1W"), "R10K": ("10k", None)}


def _ctx(uv=("R49K9", "R5K36"), ov=("R49K9", "R2K7"), pg=("R24K", "R24K", "R5K36"), flb_mid=True, out="28V0_OUT"):
    comps = [("U1", "HSC", [("1", "VCAP", "VCAP_N"), ("3", "UV", "UV_N"), ("4", "OV", "OV_N"), ("6", "FAULT", "FLT"),
                            ("7", "GND", "GND"), ("10", "FB_PG", "PG_N"), ("11", "FLB", "FLB_N" if flb_mid else "VCAP_N"),
                            ("14", "SENSE-", "SNS_N"), ("15", "VCC", "28V0")]),
             res("R1", uv[0], "28V0", "UV_N"), res("R2", uv[1], "UV_N", "GND"),
             res("R3", ov[0], "28V0", "OV_N"), res("R4", ov[1], "OV_N", "GND"),
             res("R5", pg[0], out, "FLB_N"), res("R6", pg[1], "FLB_N", "PG_N"), res("R7", pg[2], "PG_N", "GND"),
             res("R8", "RS", "28V0", "SNS_N"), res("R9", "R100K", "VCAP_N", "FLT")]
    ctx = build_ctx(comps, parts={"HSC": HSC})
    for pn, (v, w) in VALUES.items():
        if pn in ctx.design.part_params:
            ctx.design.part_params[pn]["R_Value"] = v
            if w:
                ctx.design.part_params[pn]["Power_Rating"] = w
    return ctx


def test_vcap_net_gets_its_voltage_from_part_data():
    ctx = _ctx()
    assert ctx.config.net_voltage("VCAP_N") == 3.6 and ctx.config.derived == {"VCAP_N": 3.6}
    # FAULT pulled up to VCAP: no PIN006, and PWR004 does not ask VCAP for a test point
    assert not findings(pins.open_drain_pullups, ctx)
    assert not [f for f in findings(power.rail_testpoints, ctx) if "VCAP_N" in f.message]


def test_monitor_trip_points():
    fs = {f.message.split(" pin ")[0].split(") ")[1]: f for f in findings(power.monitor_trips, _ctx())}
    uv = fs["undervoltage"]
    # 1.08 V max rising through 49.9k / 5.36k: 1.08 * 55.26 / 5.36 = 11.1 V
    assert uv.severity == "info" and "turns on above 11.1 V on '28V0', off below 10.2 V (nominal 28 V)" in uv.message
    assert "trips above 19.2 V on '28V0'" in fs["overvoltage"].message and fs["overvoltage"].severity is None   # default: error
    pg = fs["power good"]
    assert "reports good above 10.1 V on '28V0_OUT'" in pg.message and pg.severity == "info"


def test_monitor_tied_off():
    ctx = _ctx()
    ctx.design.components["R3"].pins[0].net = "GND"
    ctx.design.components["U1"].pins[2].net = "GND"
    fs = [f for f in findings(power.monitor_trips, ctx) if "overvoltage" in f.message]
    assert len(fs) == 1 and "tied to 'GND': the overvoltage monitor is disabled" in fs[0].message


def test_undriven_level_solves_resistor_chain():
    # 28 V -> 24k -> FLB -> 24k -> PG -> 5.36k -> GND: FLB at 15.4 V, over its 6 V rating
    ctx = _ctx()
    fs = [f for f in findings(levels.input_overvoltage, ctx) if "FLB" in f.message]
    assert len(fs) == 1 and "resistor network R5, R6, R7 (15.4 V)" in fs[0].message
    # FLB tied to VCAP instead: 3.6 V, within its rating
    assert not [f for f in findings(levels.input_overvoltage, _ctx(flb_mid=False)) if "FLB" in f.message]


def test_current_limit_and_sense_resistor_power():
    fs = findings(power.current_limits, _ctx())
    # 53 mV / 0.05 ohm = 1.06 A; 56 mW in a 0.1 W resistor: 56 % of rating, over the 50 % derating
    assert len(fs) == 1 and fs[0].severity is None     # the check's default, warning
    assert "1 A typical, 1.06 A maximum" in fs[0].message and "56% of its 0.1 W rating" in fs[0].message


def test_two_hop_pullup_through_led_node():
    od = {"pin_functions": {"PG": {"direction": "open_drain", "pins": ["1"]},
                            "GND": {"direction": "power", "pins": ["2"]}}}
    comps = [("U1", "OD", [("1", "PG", "PGOOD"), ("2", "GND", "GND")]),
             res("R1", "R2K", "PGOOD", "LED_A"), res("R2", "R2K", "LED_A", "3V3"),
             ("D1", "LED", [("1", "A", "LED_A"), ("2", "K", "GND")])]
    ctx = build_ctx(comps, parts={"OD": od})
    assert not findings(pins.open_drain_pullups, ctx)


VTT = {"pin_functions": {"VDDQSNS": {"direction": "input", "pins": ["5"], "io_standard": "analog"},
                         "VLDOIN": {"direction": "power", "pins": ["7"]},
                         "VTT": {"direction": "power", "function": "VOUT", "pins": ["23"]}},
       "regulator": {"input_pins": ["VLDOIN"], "output_pins": ["VTT"],
                     "tracking": {"reference_pin": "VDDQSNS", "ratio": 0.5}}}


def test_tracking_regulator_against_rail_name():
    def ctx(out):
        return build_ctx([("U1", "VTT", [("5", "VDDQSNS", "1V2"), ("7", "VLDOIN", "1V2"), ("23", "VTT", out)])],
                         parts={"VTT": VTT})
    assert not findings(power.regulator_output, ctx("0V6_VTT"))
    fs = findings(power.regulator_output, ctx("0V75_VTT"))
    assert len(fs) == 1 and "sets '0V75_VTT' to 0.600 V through 0.5 x '1V2' (VDDQSNS)" in fs[0].message
