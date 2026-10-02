from boardcheck.checks import clocks, levels, pins
from helpers import build_ctx, findings, res


def _rt(applies, rows, unit="V"):
    return {"kind": "range_table", "unit": unit, "applies_to": applies, "rows": rows}


def _osc(hz, vdd="VDD"):
    return {"part_info": {"type": "oscillator", "frequency_hz": hz},
            "pin_functions": {"OE": {"direction": "input", "function": "OE", "pins": ["1"], "supply": vdd},
                              "GND": {"direction": "power", "function": "GROUND", "pins": ["2"]},
                              "OUT": {"direction": "output", "function": "CLOCK_OUT", "pins": ["3"], "supply": vdd},
                              vdd: {"direction": "power", "function": "POWER", "pins": ["4"]}},
            "electrical_characteristics": {"voh": _rt(["OUT"], [{"min": "0.9*VDD"}]),
                                           "vol": _rt(["OUT"], [{"max": "0.1*VDD"}])}}


def _lvds(hz, p_pin, n_pin):
    return {"part_info": {"type": "oscillator", "frequency_hz": hz},
            "pin_functions": {"GND": {"direction": "power", "pins": ["3"]},
                              "OUT": {"direction": "output", "function": "CLOCK_OUT_P", "pins": [p_pin],
                                      "supply": "VDD", "diff_pair": "OUT2"},
                              "OUT2": {"direction": "output", "function": "CLOCK_OUT_N", "pins": [n_pin],
                                       "supply": "VDD", "diff_pair": "OUT"},
                              "VDD": {"direction": "power", "pins": ["6"]}}}


def _osc_pins(desig, pn, out_net, vdd="3V3"):
    return (desig, pn, [("1", "OE", vdd), ("2", "GND", "GND"), ("3", "OUT", out_net), ("4", "VDD", vdd)])


def test_alternates_are_one_driver_and_reported():
    parts = {"A50": _osc(50e6), "B50": _osc(50e6)}
    ctx = build_ctx([_osc_pins("Y1", "A50", "ETH_50MHZ_CLK"), _osc_pins("Y4", "B50", "ETH_50MHZ_CLK")], parts=parts)
    assert clocks.alternates(ctx) == [["Y1", "Y4"]]
    assert not findings(pins.contention, ctx)
    fs = findings(clocks.oscillator_alternates, ctx)
    assert len(fs) == 1 and "Y1 (A50), Y4 (B50) all drive 'ETH_50MHZ_CLK'" in fs[0].message
    assert not findings(clocks.alternates_differ, ctx)
    assert not findings(clocks.frequency_vs_name, ctx)


def test_alternates_through_select_resistors():
    parts = {"A50": _osc(50e6), "B25": _osc(25e6)}
    ctx = build_ctx([_osc_pins("Y3", "A50", "N1"), _osc_pins("Y7", "B25", "N2"),
                     res("R1", "R0", "N1", "CLK_50MHZ"), res("R2", "R0", "N2", "CLK_50MHZ")], parts=parts)
    for r in ("R0",):
        ctx.design.part_params[r]["R_Value"] = "0"
    assert clocks.alternates(ctx) == [["Y3", "Y7"]]
    fs = findings(clocks.alternates_differ, ctx)
    assert [f.message for f in fs] == ["alternate oscillators have different frequencies: Y3 50 MHz, Y7 25 MHz"]
    fs = findings(clocks.frequency_vs_name, ctx)
    assert len(fs) == 1 and fs[0].message == "Y7 (B25) runs at 25 MHz but drives 'CLK_50MHZ' (50 MHz)"


def test_declared_alternates():
    parts = {"A50": _osc(50e6)}
    ctx = build_ctx([_osc_pins("U1", "A50", "X"), _osc_pins("U2", "A50", "Y")], parts=parts,
                    config={"parts": {"alternates": [["U1", "U2"]]}})
    assert clocks.alternates(ctx) == [["U1", "U2"]]


def test_name_frequency():
    assert clocks.name_frequency("148.5MHZ_P") == 148.5e6
    assert clocks.name_frequency("REF_148P5MHZ") == 148.5e6
    assert clocks.name_frequency("ETH1_50MHZ_OSC_OUT") == 50e6
    assert clocks.name_frequency("PCIE_REFCLK") is None
    assert clocks.name_frequency("SPI_32KHZ") == 32e3


def test_differential_polarity_and_alternates():
    parts = {"XD": _lvds(100e6, "5", "4"), "XL": _lvds(100e6, "4", "5")}
    def osc(desig, pn, n4, n5):
        return (desig, pn, [("3", "GND", "GND"), ("4", "A", n4), ("5", "B", n5), ("6", "VDD", "3V3")])
    # XD's true output (pin 5) on _N: swapped; XL's (pin 4) on _P
    ctx = build_ctx([osc("Y12", "XD", "100MHZ_P", "100MHZ_N"), osc("Y11", "XL", "100MHZ_P", "100MHZ_N")], parts=parts)
    fs = findings(pins.diff_polarity, ctx)
    assert [f.refs for f in fs] == [["Y12"]]
    fs = findings(clocks.alternates_differ, ctx)
    assert len(fs) == 1 and "true output on different nets" in fs[0].message
    assert not findings(pins.contention, ctx)


PHY = {"pin_functions": {"XTAL1": {"direction": "input", "function": "XTAL_IN", "pins": ["63"], "supply": "VDDIO"},
                         "SEL1": {"direction": "input", "function": "REFCLK_SEL", "pins": ["61"], "supply": "VDDIO"},
                         "SEL0": {"direction": "input", "function": "REFCLK_SEL", "pins": ["62"], "supply": "VDDIO"},
                         "VDDIO": {"direction": "power", "pins": ["1"]}},
       "electrical_characteristics": {"vih": _rt(["SEL1", "SEL0"], [{"min": 2.0}]),
                                      "vil": _rt(["SEL1", "SEL0"], [{"max": 0.8}])},
       "clock_inputs": [{"pin": "XTAL1", "select": ["SEL1", "SEL0"],
                         "frequency_hz": {"00": 25e6, "01": 25e6, "10": 50e6, "11": 125e6}}]}


def _phy_ctx(osc_hz, sel1_rail, sel0_rail):
    comps = [("U3", "PHY", [("1", "VDDIO", "3V3"), ("61", "SEL1", "S1"), ("62", "SEL0", "S0"), ("63", "XTAL1", "CLK")]),
             _osc_pins("Y1", "OSC", "CLK"),
             res("R1", "R4K7", sel1_rail, "S1"), res("R2", "R4K7", sel0_rail, "S0")]
    ctx = build_ctx(comps, parts={"PHY": PHY, "OSC": _osc(osc_hz)})
    ctx.design.part_params["R4K7"]["R_Value"] = "4.7k"
    return ctx


def test_clock_select_matches_and_differs():
    assert not findings(clocks.clock_select, _phy_ctx(50e6, "3V3", "GND"))
    fs = findings(clocks.clock_select, _phy_ctx(50e6, "3V3", "3V3"))
    assert len(fs) == 1 and fs[0].message == ("U3.63 XTAL1 gets 50 MHz from Y1 (OSC), but its select pins "
                                              "(SEL1 high, SEL0 high = 11) expect 125 MHz")


RX = {"pin_functions": {"IN": {"direction": "input", "pins": ["1"], "supply": "VDD25"},
                        "VDD25": {"direction": "power", "pins": ["2"]}},
      "electrical_characteristics": {"vih": _rt(["IN"], [{"min": 1.7, "max": 2.75}]),
                                     "vil": _rt(["IN"], [{"max": 0.7}])}}


def _divider_ctx(top, bottom):
    comps = [_osc_pins("Y1", "OSC", "OSC_OUT"), ("U3", "RX", [("1", "IN", "OSC_SCALED"), ("2", "VDD25", "2V5")]),
             res("R1", "RTOP", "OSC_OUT", "OSC_SCALED")]
    if bottom:
        comps.append(res("R2", "RBOT", "GND", "OSC_SCALED"))
    ctx = build_ctx(comps, parts={"RX": RX, "OSC": _osc(50e6)})
    ctx.design.part_params["RTOP"]["R_Value"] = top
    if bottom:
        ctx.design.part_params["RBOT"]["R_Value"] = bottom
    return ctx


def test_divider_scales_driven_level():
    # 3.3 V through 270 / 820 ohm: 2.48 V at the input, below its 2.75 V maximum
    ctx = _divider_ctx("270", "820")
    sig = [s for s in levels.signals(ctx) if "OSC_OUT" in s.nets][0]
    assert abs(levels.driven_level(ctx, sig, "OSC_OUT", 3.3, "OSC_SCALED") - 3.3 * 820 / 1090) < 1e-6
    assert not findings(levels.input_overvoltage, ctx)
    # VOH min 2.97 V divided to 2.23 V still meets VIH 1.7 V
    assert not findings(levels.high_level, ctx)
    # no divider: the full 3.3 V reaches the input
    fs = findings(levels.input_overvoltage, _divider_ctx("33", None))
    assert len(fs) == 1 and "2.75 V" in fs[0].message


def test_divider_too_low_for_vih():
    fs = findings(levels.high_level, _divider_ctx("1k", "820"))
    # 2.97 V * 820 / 1820 = 1.34 V < 1.7 V
    assert len(fs) == 1 and "1.34 V at OSC_SCALED after the divider" in fs[0].message
