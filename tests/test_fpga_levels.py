import os

from boardcheck import fpga
from boardcheck.checks import ERROR, WARNING, fpga as fio, levels, pins
from helpers import build_ctx, findings, res

PDC = """\
# comment line
set base_dir       [file normalize [file dirname [info script]]]
set pins_file_addr [file normalize [file join $base_dir "./common/pins.tcl"]]
source $pins_file_addr

set_iobank -bank_name Bank1 -vcci 1.80 -fixed "false"
set_iobank -bank_name Bank2 -vcci 3.30 -fixed "true"

set ports {}
lappend ports [list {led}      {led}]
lappend ports [list {btn}      {sys_btn}]
lappend ports [list {bus[0]}   {bus[0]} {io_std "LVCMOS18"}]
# lappend ports [list {spare} {spare}]
apply_pin_constraints $ports $pins
"""

PINS = """\
dict set pins {led}     {pin_name "A1" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {sys_btn} {pin_name "A2" io_std "LVCMOS33" DIRECTION "INPUT"}
dict set pins {bus[0]}  {pin_name "B1" io_std "LVCMOS33" DIRECTION "INOUT"}
dict set pins {spare}   {pin_name "B2" io_std "LVCMOS33" DIRECTION "OUTPUT"}
"""


def _write(tmp_path, name, text):
    path = tmp_path / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return str(path)


def test_libero_pin_map_is_applied_as_libero_would(tmp_path):
    _write(tmp_path, "common/pins.tcl", PINS)
    io = fpga.load("U1", [_write(tmp_path, "io.pdc", PDC)])
    assert io.problems == [] and io.available
    assert io.banks == {"Bank1": 1.8, "Bank2": 3.3}
    assert sorted(io.pins) == ["A1", "A2", "B1"], "commented-out ports are not constrained"
    assert (io.pins["A1"].port, io.pins["A1"].direction, io.pins["A1"].io_std) == ("led", "output", "LVCMOS33")
    assert io.pins["A2"].port == "btn", "the firmware port name, mapped to the PCB port's pin"
    assert io.pins["B1"].io_std == "LVCMOS18", "a third list element overrides the pin map"
    assert io.pins["A1"].where.startswith("io.pdc:") and "pins.tcl:1" in io.pins["A1"].where
    assert io.unapplied == {"B2": ("spare", "pins.tcl:4")}, "a pin-map entry no port list applies"


def test_set_io_form_problems_and_missing_files(tmp_path):
    pdc = _write(tmp_path, "pa3.pdc", """\
set_io {a} -pinname "C4" -iostd "LVCMOS33" -direction "OUTPUT" -RES_PULL "DOWN" -out_drive 2
set_io {b} -pinname "C4" -iostd "LVCMOS33" -direction "INPUT" -RES_PULL "UP"
set_io {c} -pinname "" -iostd "LVCMOS33"
frobnicate everything
""")
    io = fpga.load("U2", [pdc, str(tmp_path / "nope.pdc")])
    c = io.pins["C4"]
    assert (c.port, c.pull, c.direction) == ("b", "pull_up", "input")
    assert any("assigned to 'b' and to 'a'" in p for p in io.problems)
    assert any("'c' has no pin" in p for p in io.problems)
    assert any("'frobnicate' not understood" in p for p in io.problems)
    assert io.missing == [str(tmp_path / "nope.pdc")] and not io.available


def test_top_level_ports_from_smartdesign_and_hdl(tmp_path):
    sd = _write(tmp_path, "top.tcl", """\
sd_create_scalar_port -sd_name ${sd_name} -port_name {led} -port_direction {OUT} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {bus} -port_direction {INOUT} -port_range {[1:0]} -port_is_pad {1}
""")
    sv = _write(tmp_path, "top.sv", """\
module other (input wire x);
endmodule
module top #(
    parameter int W = 4   // width (not a port)
) (
    input  wire clk, rst_n,   // two ports
    output logic [W-1:0] data,
    inout  wire [2:0] gpio
);
endmodule
""")
    io = fpga.load("U1", [], "", [sd])
    assert io.ports == {"led": "output", "bus[0]": "inout", "bus[1]": "inout"}
    io = fpga.load("U2", [], "", [sv], "top")
    assert io.ports == {"clk": "input", "rst_n": "input", "gpio[0]": "inout", "gpio[1]": "inout", "gpio[2]": "inout"}
    assert io.port_direction("data[3]") == "output", "a parameterised range is matched by base name"


# -- board-level ------------------------------------------------------------------

PF_PART = {
    "pin_functions": {"VDDI": {"direction": "power", "per_bank": True}},
    "io_standards": {"SHIELD12": {"tie_to": "ground"}},
    "electrical_characteristics": {
        "supply_vddi": {"kind": "range_table", "unit": "V", "rows": [
            {"min": 3.15, "max": 3.45, "conditions": {"io_standard": {"value": "LVCMOS33"}}},
            {"min": 1.71, "max": 1.89, "conditions": {"io_standard": {"value": "LVCMOS18"}}}]},
        "vi_abs": {"kind": "range_table", "unit": "V", "rows": [
            {"max": 3.8, "conditions": {"bank_type": {"value": "GPIO"}}},
            {"max": 2.2, "conditions": {"bank_type": {"value": "HSIO"}}}]},
        "vih": {"kind": "range_table", "unit": "V", "rows": [
            {"min": 2.0, "max": 3.45, "conditions": {"io_standard": {"value": ["LVTTL", "LVCMOS33"]}}},
            {"min": "0.65*VDDI", "max": 1.89, "conditions": {"io_standard": {"value": "LVCMOS18"}}}]},
        "vil": {"kind": "range_table", "unit": "V", "rows": [
            {"max": 0.8, "conditions": {"io_standard": {"value": "LVCMOS33"}}},
            {"max": "0.35*VDDI", "conditions": {"io_standard": {"value": "LVCMOS18"}}}]},
        "voh": {"kind": "range_table", "unit": "V", "rows": [
            {"min": "VDDI-0.4", "conditions": {"io_standard": {"value": "LVCMOS33"}}},
            {"min": "VDDI-0.45", "conditions": {"io_standard": {"value": "LVCMOS18"}}},
            {"min": 2.4, "conditions": {"io_standard": {"value": "LVCMOS33"}, "drive_strength": {"value": 2, "unit": "mA"},
                                        "load_current": {"value": -2, "unit": "mA"}}}]},
        "vol": {"kind": "range_table", "unit": "V", "rows": [
            {"max": 0.4, "conditions": {"io_standard": {"value": "LVCMOS33"}}},
            {"max": 0.45, "conditions": {"io_standard": {"value": "LVCMOS18"}}}]},
    },
}

BUF_PART = {  # a 3.3 V-supplied buffer: 1.8 V input levels do not reach its VIH
    "pin_functions": {"VCC": {"direction": "power"}, "GND": {"direction": "power"},
                      "A": {"direction": "input", "supply": "VCC"}, "Y": {"direction": "output", "supply": "VCC"}},
    "electrical_characteristics": {
        "vi_abs": {"kind": "range_table", "unit": "V", "applies_to": ["A"], "rows": [{"min": -0.5, "max": 4.6}]},
        "vih": {"kind": "range_table", "unit": "V", "applies_to": ["A"], "rows": [
            {"min": "0.7*VCC", "conditions": {"supply_voltage": {"min": 3.0, "max": 3.6, "unit": "V", "supply": "VCC"}}}]},
        "vil": {"kind": "range_table", "unit": "V", "applies_to": ["A"], "rows": [{"max": "0.3*VCC"}]},
        "voh": {"kind": "range_table", "unit": "V", "applies_to": ["Y"], "rows": [
            {"min": "VCC-0.1", "conditions": {"load_current": {"value": -0.05, "unit": "mA"}}},
            {"min": 2.2, "conditions": {"load_current": {"value": -24, "unit": "mA"}}}]},
        "vol": {"kind": "range_table", "unit": "V", "applies_to": ["Y"], "rows": [{"max": 0.1}]},
    },
}


def _board(tmp_path, pins_tcl, extra=(), fpga_cfg=None, top=None, parts=None):
    """U1: FPGA with bank 1 (HSIO, 1V8) and bank 2 (GPIO, 3V3) on the symbol."""
    _write(tmp_path, "common/pins.tcl", pins_tcl)
    ports = "\n".join(f"lappend ports [list {{{p}}} {{{p}}}]"
                      for p in [line.split("{")[1].split("}")[0] for line in pins_tcl.splitlines() if line.strip()])
    pdc = _write(tmp_path, "io.pdc", PDC.split("set ports {}")[0] + "set ports {}\n" + ports +
                 "\napply_pin_constraints $ports $pins\n")
    cfg = {"constraints": [pdc], "bank_pattern": r"(?:GPIO|HSIO)\d+[PN]B(\d+)", "bank_supply": "VDDI{bank}",
           "bank_name": "Bank{bank}", "bank_type_pattern": "^(GPIO|HSIO)"}
    if top:
        cfg["top_level"] = [_write(tmp_path, "top.tcl", top)]
    cfg.update(fpga_cfg or {})
    u1 = ("U1", "MPF", [("A1", "HSIO1PB1", "SIG18"), ("A2", "HSIO2PB1", "GND"), ("A3", "HSIO3PB1", "NetU1_A3"),
                        ("B1", "GPIO1PB2", "SIG33"), ("B2", "GPIO2PB2", "WIRED"),
                        ("V1", "VDDI1", "1V8"), ("V2", "VDDI2", "3V3")])
    comps = [u1, ("U5", "BUF", [("1", "VCC", "3V3"), ("2", "A", "SIG18"), ("3", "Y", "OUT"), ("4", "GND", "GND")]),
             ("U6", "BUF", [("1", "VCC", "3V3"), ("2", "A", "WIRED"), ("3", "Y", "NetU6_3"), ("4", "GND", "GND")])]
    comps += list(extra)
    return build_ctx(comps, config={"fpga": {"U1": cfg}}, parts=parts or {"MPF": PF_PART, "BUF": BUF_PART})


PINS_OK = """\
dict set pins {out18} {pin_name "A1" io_std "LVCMOS18" DIRECTION "OUTPUT"}
dict set pins {in33}  {pin_name "B1" io_std "LVCMOS33" DIRECTION "INPUT"}
"""


def test_constraint_checks(tmp_path):
    pins_tcl = PINS_OK + """\
dict set pins {gnd_out} {pin_name "A2" io_std "LVCMOS18" DIRECTION "OUTPUT"}
dict set pins {nc_out}  {pin_name "A3" io_std "LVCMOS18" DIRECTION "OUTPUT"}
dict set pins {ghost}   {pin_name "Z9" io_std "LVCMOS18" DIRECTION "OUTPUT"}
"""
    ctx = _board(tmp_path, pins_tcl)
    msgs = [f.message for f in findings(fio.constrained_pin_wiring, ctx)]
    assert any("'gnd_out'" in m and "tied to 'GND'" in m for m in msgs)
    assert any("'ghost'" in m and "does not have" in m for m in msgs)
    unconnected = [f.message for f in findings(fio.constrained_pin_unconnected, ctx)]
    assert any("'nc_out'" in m for m in unconnected) and not any("'out18'" in m for m in unconnected)
    assert ["U1.B2" in f.message for f in findings(fio.unconstrained_io, ctx)] == [True]
    assert findings(fio.bank_voltage, ctx) == [], "Bank1 1.8 V on 1V8, Bank2 3.3 V on 3V3"


def test_bank_voltage_mismatch_and_missing_constraints(tmp_path):
    ctx = _board(tmp_path, PINS_OK, extra=[])
    ctx.design.components["U1"].pins[-1].net = "2V5"     # VDDI2 on a 2.5 V rail, Bank2 set to 3.3 V
    f = findings(fio.bank_voltage, ctx)
    assert len(f) == 1 and "bank 2" in f[0].message and "3.3 V" in f[0].message and "2V5" in f[0].message
    ctx = _board(tmp_path, PINS_OK, fpga_cfg={"constraints": [str(tmp_path / "gone.pdc")]})
    assert any("not found" in f.message for f in findings(fio.constraints_readable, ctx))
    assert findings(fio.bank_voltage, ctx) == [], "skipped, not guessed, when the files are missing"


def test_design_direction_overrides_constraint_and_is_cross_checked(tmp_path):
    pins_tcl = PINS_OK.replace('{in33}  {pin_name "B1" io_std "LVCMOS33" DIRECTION "INPUT"}',
                               '{in33}  {pin_name "B1" io_std "LVCMOS33" DIRECTION "OUTPUT"}')
    top = """\
sd_create_scalar_port -sd_name x -port_name {out18} -port_direction {OUT}
sd_create_scalar_port -sd_name x -port_name {in33} -port_direction {IN}
sd_create_scalar_port -sd_name x -port_name {lost} -port_direction {OUT} -port_is_pad {1}
"""
    ctx = _board(tmp_path, pins_tcl, top=top)
    f = findings(fio.constraint_direction, ctx)
    assert len(f) == 1 and f[0].severity == ERROR and "'in33' is input in the FPGA design but output" in f[0].message
    assert ["'lost'" in f.message for f in findings(fio.unplaced_ports, ctx)] == [True]
    pt = pins.PinTypes(ctx)
    b1 = [p for p in ctx.design.components["U1"].pins if p.designator == "B1"][0]
    assert pt.base(b1) == ("input", pins.CONSTRAINTS)


def test_constraints_drive_pin_checks_and_pull(tmp_path):
    pins_tcl = PINS_OK.replace('DIRECTION "OUTPUT"}', 'DIRECTION "INPUT"}') + \
        'dict set pins {pulled} {pin_name "B2" io_std "LVCMOS33" DIRECTION "INPUT" RES_PULL "DOWN"}\n'
    ctx = _board(tmp_path, pins_tcl)
    msgs = [f.message for f in findings(pins.floating_inputs, ctx)]
    assert any("'SIG18' has only inputs" in m and "constraints" in m for m in msgs)
    assert not any("WIRED" in m for m in msgs), "an internal pull-down gives the net a level"


def test_shield_standard_is_a_soft_ground(tmp_path):
    pins_tcl = PINS_OK + 'dict set pins {shield0} {pin_name "A2" io_std "SHIELD12" DIRECTION "OUTPUT"}\n'
    ctx = _board(tmp_path, pins_tcl)
    assert findings(fio.constrained_pin_wiring, ctx) == []
    assert findings(pins.contention, ctx) == []
    ctx.design.components["U1"].pins[1].net = "SIG_X"
    assert any("tied to ground" in f.message for f in findings(fio.constrained_pin_wiring, ctx))


def test_per_bank_supply_matches_symbol_pins(tmp_path):
    ctx = _board(tmp_path, PINS_OK)
    assert findings(pins.pin_data_alignment, ctx) == [], "VDDI stands for VDDI1, VDDI2"
    v1 = [p for p in ctx.design.components["U1"].pins if p.name == "VDDI1"][0]
    assert pins.PinTypes(ctx).part_entry(v1).key == "VDDI"


def test_level_high_mismatch_1v8_fpga_into_3v3_buffer(tmp_path):
    ctx = _board(tmp_path, PINS_OK)
    f = findings(levels.high_level, ctx)
    assert len(f) == 1 and f[0].severity == ERROR
    assert "U1.A1 HSIO1PB1 LVCMOS18 VOH min 1.35 V is below U5.2 A VIH min 2.31 V" in f[0].message
    assert findings(levels.low_level, ctx) == []


def test_level_overvoltage_into_hsio_and_through_series_resistor(tmp_path):
    # U5 (3.3 V) drives through a 33 ohm series resistor into U1.A1 (HSIO, 2.2 V abs max).
    pins_tcl = PINS_OK.replace('{out18} {pin_name "A1" io_std "LVCMOS18" DIRECTION "OUTPUT"}',
                               '{in18} {pin_name "A1" io_std "LVCMOS18" DIRECTION "INPUT"}')
    extra = [res("R1", "RES", "OUT", "SIG18")]
    ctx = _board(tmp_path, pins_tcl, extra=extra,
                 parts={"MPF": PF_PART, "BUF": BUF_PART, "RES": {}})
    ctx.design.part_params["RES"]["R_Value"] = "33"
    f = findings(levels.input_overvoltage, ctx)
    assert any("U5.3 Y (supply 3.3 V) exceeds the absolute maximum input of U1.A1 HSIO1PB1 LVCMOS18 2.2 V" in x.message
               for x in f), [x.message for x in f]
    assert "SIG18" in f[0].nets and "OUT" in f[0].nets


def test_divider_level_is_not_a_pull_up_to_the_rail(tmp_path):
    # 5 V -> 10k -> SIG33 -> 10k -> GND: 2.5 V, within a 3.3 V bank's limits.
    pins_tcl = PINS_OK
    extra = [res("R1", "R10K", "5V0", "SIG33"), res("R2", "R10K", "SIG33", "GND")]
    ctx = _board(tmp_path, pins_tcl, extra=extra, parts={"MPF": PF_PART, "BUF": BUF_PART, "R10K": {}})
    ctx.design.part_params["R10K"]["R_Value"] = "10k"
    assert findings(levels.input_overvoltage, ctx) == []
    levels_ctx = _board(tmp_path, pins_tcl, extra=[res("R1", "R10K", "5V0", "SIG33")],
                        parts={"MPF": PF_PART, "BUF": BUF_PART, "R10K": {}})
    levels_ctx.design.part_params["R10K"]["R_Value"] = "10k"
    f = findings(levels.input_overvoltage, levels_ctx)
    assert len(f) == 1 and "pull-up R1 to 5V0 exceeds the absolute maximum input of U1.B1 GPIO1PB2 LVCMOS33 3.8 V" in f[0].message
    # 3.6 V through the same pull-up: above VIH max 3.45 V, below the 3.8 V absolute maximum
    levels_ctx.design.components["R1"].pins[0].net = "3V6"
    del levels_ctx._signals
    levels_ctx.__dict__.pop("_undriven", None)
    f = findings(levels.input_overvoltage, levels_ctx)
    assert len(f) == 1 and "recommended maximum input of U1.B1 GPIO1PB2 LVCMOS33 3.45 V (vih)" in f[0].message


def test_io_standard_vs_bank_rail_and_drive_rows(tmp_path):
    pins_tcl = PINS_OK.replace('{in33}  {pin_name "B1" io_std "LVCMOS33" DIRECTION "INPUT"}',
                               '{in33}  {pin_name "B1" io_std "LVCMOS18" DIRECTION "INPUT"}')
    ctx = _board(tmp_path, pins_tcl)
    f = findings(levels.io_standard_vs_bank, ctx)
    assert len(f) == 1 and "bank 2: LVCMOS18 needs its I/O supply at 1.71-1.89 V; VDDI2 is at 3.3 V" in f[0].message
    # drive-strength rows: with -out_drive 2 only the 2 mA row and the row with no drive condition apply
    pins_tcl = PINS_OK + 'dict set pins {weak} {pin_name "B2" io_std "LVCMOS33" DIRECTION "OUTPUT" out_drive "2"}\n'
    ctx = _board(tmp_path, pins_tcl)
    lv = levels.Levels(ctx)
    b2 = [p for p in ctx.design.components["U1"].pins if p.designator == "B2"][0]
    assert lv.value(lv.for_pin(b2), "voh", "min", "low") == (2.4, "voh"), \
        "the 2 mA row and the row with no drive condition both apply; the least favourable wins"
    lv.for_pin(b2).drive = 8.0
    assert lv.value(lv.for_pin(b2), "voh", "min", "low") == (2.9, "voh"), "the 2 mA row no longer applies"


def test_level_coverage_reports_parts_without_data(tmp_path):
    extra = [("U7", "NODATA", [("1", "IN", "SIG33", "input")])]
    ctx = _board(tmp_path, PINS_OK.replace('DIRECTION "INPUT"', 'DIRECTION "OUTPUT"'), extra=extra)
    checked, total, gaps = levels.level_coverage(ctx)
    assert gaps == {"NODATA": {"U7.1"}} and checked < total
    f = findings(levels.level_gaps, ctx)
    assert f[0].part_number == "NODATA" and f[0].severity is None


def test_analog_pins_skip_logic_thresholds_but_not_overvoltage():
    amp = {"pin_functions": {"V+": {"direction": "power", "pins": ["4"]}, "V-": {"direction": "power", "pins": ["11"]},
                             "OUT A": {"direction": "output", "pins": ["1"], "supply": "V+", "io_standard": "analog"}},
           "electrical_characteristics": {}}
    amp["electrical_characteristics"]["vo_abs"] = {"kind": "range_table", "unit": "V", "rows": [{"max": "V+"}]}
    adc = {"pin_functions": {"VA": {"direction": "power", "pins": ["2"]},
                             "IN0": {"direction": "input", "pins": ["4"], "supply": "VA", "io_standard": "analog"}},
           "electrical_characteristics": {
               "vi_abs": {"kind": "range_table", "unit": "V", "applies_to": ["IN0"], "rows": [{"min": -0.3, "max": "VA+0.3"}]}}}
    amp["pin_functions"]["-IN A"] = {"direction": "input", "pins": ["2"], "supply": "V+", "io_standard": "analog"}
    amp["electrical_characteristics"]["vi_abs"] = {"kind": "range_table", "unit": "V", "applies_to": ["-IN A"],
                                                   "rows": [{"max": 3.0}]}
    ctx = build_ctx([("U1", "AMP", [("1", "VOUT 1", "SENSE"), ("2", "-IN 1", "SENSE"), ("4", "+VS", "15V0"),
                                    ("11", "-VS", "GND")]),
                     ("U2", "ADC", [("2", "VA", "3V3"), ("4", "IN0", "SENSE")]),
                     ("U3", "ADC", [("2", "VA", "3V3"), ("4", "IN0", "SENSE")])],
                    parts={"AMP": amp, "ADC": adc})
    assert findings(levels.high_level, ctx) == [] and findings(levels.low_level, ctx) == []
    assert levels.level_coverage(ctx) == (0, 0, {}), "an analog pair is not a logic pair"
    f = findings(levels.input_overvoltage, ctx)
    assert len(f) == 1, "one finding per source, and the amplifier's own feedback input is not a victim"
    assert "U1.1 VOUT 1 (supply 15 V) exceeds the absolute maximum input of U2.4 IN0 3.6 V, U3.4 IN0 3.6 V" \
        in f[0].message and f[0].refs == ["U1", "U2", "U3"]
