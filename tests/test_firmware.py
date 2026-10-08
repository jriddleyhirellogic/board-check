from boardcheck.checks import firmware as fw
from helpers import build_ctx, findings, res

ENUM = """
typedef enum { CS_1, CS_2 } ADC_Select_t;   // other enums are ignored
typedef enum
{
    TLM_3V3_MISC,      // select 0, IN0
    TLM_1V8_FPGA,      // select 0, IN1
    TLM_5V0 = 4,       // explicit value: select 1, IN0
    NUMBER_TLM
} TLM_Signal_t;
"""
TOP = """\
sd_create_scalar_port -sd_name x -port_name {cs1_n} -port_direction {OUT}
sd_create_scalar_port -sd_name x -port_name {cs2_n} -port_direction {OUT}
sd_connect_pins -sd_name x -pin_names {"spi_inst:SPISS[0:0]" "cs1_n" }
sd_connect_pins -sd_name x -pin_names {"cs2_n" "spi_inst:SPISS[1:1]" }
"""


def _ctx(tmp_path, adc1_in0="3V3_MISC_TLM_ADC", adc1_in1="1V8_FPGA_TLM_ADC", extra=(), values=None):
    (tmp_path / "tlm.h").write_text(ENUM)
    (tmp_path / "top.tcl").write_text(TOP)
    (tmp_path / "io.pdc").write_text('set_io {cs1_n} -pinname "A1" -iostd "LVCMOS33" -direction "OUTPUT"\n'
                                     'set_io {cs2_n} -pinname "A2" -iostd "LVCMOS33" -direction "OUTPUT"\n')
    comps = [("U1", "FPGA", [("A1", "GPIO1PB2", "R_NCS_1"), ("A2", "GPIO2PB2", "NCS_2")]),
             res("R1", "R", "R_NCS_1", "NCS_1"),
             ("U10", "ADC", [("1", "CS", "NCS_1"), ("4", "IN0", adc1_in0), ("5", "IN1", adc1_in1),
                             ("6", "IN2", "SPARE_TLM_ADC")]),
             ("U11", "ADC", [("1", "CS", "NCS_2"), ("4", "IN0", "5V0_TLM_ADC")]),
             ("U12", "BUF", [("1", "Y", adc1_in0), ("2", "Y", adc1_in1), ("3", "Y", "SPARE_TLM_ADC"),
                             ("4", "Y", "5V0_TLM_ADC")])] + list(extra)
    spec = {"name": "tlm", "enum_file": str(tmp_path / "tlm.h"), "enum": "TLM_Signal_t", "skip": ["NUMBER_TLM"],
            "strip_prefix": "TLM_", "channels_per_select": 4, "fpga": "U1",
            "select_link": r"spi_inst:SPISS\[{n}:{n}\]", "net_strip": ["_ADC$", "_TLM$"]}
    ctx = build_ctx(comps, config={"fpga": {"U1": {"constraints": [str(tmp_path / "io.pdc")],
                                                   "top_level": [str(tmp_path / "top.tcl")]}},
                                   "firmware": {"adc_channel_maps": [spec]}})
    ctx.design.part_params.setdefault("R", {})["R_Value"] = "33"
    for pn, v in (values or {}).items():
        ctx.design.part_params[pn]["R_Value"] = v
    return ctx


def test_parse_enum_with_explicit_values(tmp_path):
    (tmp_path / "e.h").write_text(ENUM)
    assert fw.parse_enum(str(tmp_path / "e.h"), "TLM_Signal_t") == [
        ("TLM_3V3_MISC", 0), ("TLM_1V8_FPGA", 1), ("TLM_5V0", 4), ("NUMBER_TLM", 5)]


def test_matching_map_and_unread_input(tmp_path):
    ctx = _ctx(tmp_path)
    assert findings(fw.channel_names, ctx) == []
    cov = [f.message for f in findings(fw.channel_coverage, ctx)]
    assert cov == ["tlm: U10.6 IN2 is wired to 'SPARE_TLM_ADC' but no firmware channel reads it"]
    assert "3 channels traced" in findings(fw.channel_map, ctx)[0].message


def test_swapped_channels_are_errors(tmp_path):
    ctx = _ctx(tmp_path, adc1_in0="1V8_FPGA_TLM_ADC", adc1_in1="3V3_MISC_TLM_ADC")
    msgs = sorted(f.message for f in findings(fw.channel_names, ctx))
    assert msgs == ["tlm: firmware 'TLM_1V8_FPGA' reads U10.5 IN1 (select 0), which the schematic wires to "
                    "'3V3_MISC_TLM_ADC'",
                    "tlm: firmware 'TLM_3V3_MISC' reads U10.4 IN0 (select 0), which the schematic wires to "
                    "'1V8_FPGA_TLM_ADC'"]


def test_missing_enum_file_is_reported(tmp_path):
    ctx = _ctx(tmp_path)
    ctx.config["firmware"]["adc_channel_maps"][0]["enum_file"] = str(tmp_path / "nope.h")
    assert any("enum file not found" in f.message for f in findings(fw.channel_names, ctx))


SCALING = [res("R101", "R1K3", "3V3_MISC_TLM", "3V3_MISC_TLM_ADC"), res("R102", "R2K", "3V3_MISC_TLM_ADC", "GND"),
           res("R103", "R1K", "5V0_TLM", "5V0_TLM_ADC")]


def _scaled(tmp_path, cal_rows):
    ctx = _ctx(tmp_path, extra=SCALING, values={"R1K3": "1k3", "R2K": "2k", "R1K": "1k"})
    from boardcheck.model import Pin
    for adc in ("U10", "U11"):
        ctx.design.components[adc].pins.append(Pin("2", "VA", "3V3", ctx.design.components[adc]))
    (tmp_path / "cal.csv").write_text("Signal,Gain,Offset\n" + "".join(f"{r}\n" for r in cal_rows))
    ctx.config["firmware"]["adc_channel_maps"][0]["calibration"] = {"file": str(tmp_path / "cal.csv")}
    return ctx


def test_full_scale_and_calibration_gain(tmp_path):
    # 3V3_MISC via 1k3 / 2k: ratio 0.606, 3.3 V * 1000 / 4096 / 0.606 = 1.329 mV/count
    ctx = _scaled(tmp_path, ["TLM_3V3_MISC,1.329,0", "TLM_1V8_FPGA,1,0", "TLM_5V0,1,0"])
    full = findings(fw.channel_full_scale, ctx)
    assert len(full) == 1 and "'TLM_5V0' (5V0, 5 V nominal) reaches U11.4 IN0 at 5.00 V through R103 (ratio 1)" \
        in full[0].message
    gains = findings(fw.calibration_gains, ctx)
    assert len(gains) == 1 and "1 voltage channel gain(s)" in gains[0].message
    assert "TLM_5V0 1 (board: 0.8057 mV/count, ratio 1)" in gains[0].message, "3V3_MISC is within 5%"


def test_placeholder_calibration_is_reported_once(tmp_path):
    ctx = _scaled(tmp_path, ["TLM_3V3_MISC,1,0", "TLM_1V8_FPGA,1,0", "TLM_5V0,1,0"])
    (f,) = findings(fw.calibration_gains, ctx)
    assert "every row of cal.csv is gain 1, offset 0" in f.message
    assert findings(fw.current_offsets, ctx) == [], "FW010 leaves a placeholder table to FW005"


def test_calibration_rows_must_follow_the_enum(tmp_path):
    ctx = _scaled(tmp_path, ["TLM_3V3_MISC,1,0", "TLM_1V8_FPGA,1,0", "TLM_5V0,1,0"])
    assert findings(fw.calibration_names, ctx) == []
    ctx = _scaled(tmp_path, ["TLM_3V3_MISC,1,0", "TLM_1V8_FPGA_,1,0", "TLM_5V0,1,0"])
    f = findings(fw.calibration_names, ctx)
    assert len(f) == 1 and "row 2 'TLM_1V8_FPGA_' (enum: TLM_1V8_FPGA)" in f[0].message
    ctx = _scaled(tmp_path, ["TLM_3V3_MISC,1,0", '"TLM_1V8_FPGA, ",1,0', "TLM_5V0,1,0"])
    assert findings(fw.calibration_names, ctx) == [], "a stray trailing comma is not a different signal"


def _pwm_ctx(tmp_path, bottom="3k65", constant="3200"):
    (tmp_path / "pwm.h").write_text(f"#define PWM_VREF_mV    {constant}\n#define OTHER 1\n")
    (tmp_path / "io.pdc").write_text('set_io {vref_pwm} -pinname "A1" -iostd "LVCMOS33" -direction "OUTPUT"\n')
    comps = [("U1", "FPGA", [("A1", "GPIO1PB2", "R_VREF"), ("V2", "VDDI2", "3V3")]),
             res("R10", "R10K", "R_VREF", "VREF"), res("R11", "RB", "VREF", "GND"),
             ("U5", "DRV", [("17", "VREF", "VREF")])]
    ctx = build_ctx(comps, config={
        "fpga": {"U1": {"constraints": [str(tmp_path / "io.pdc")], "bank_pattern": r"(?:GPIO|HSIO)\d+[PN]B(\d+)",
                        "bank_supply": "VDDI{bank}"}},
        "firmware": {"pwm_outputs": [{"name": "vref", "constant_file": str(tmp_path / "pwm.h"),
                                      "constant": "PWM_VREF_mV", "fpga": "U1", "ports": ["vref_pwm"]}]}})
    ctx.design.part_params["R10K"]["R_Value"] = "10k"
    ctx.design.part_params["RB"]["R_Value"] = bottom
    return ctx


def test_pwm_full_scale_against_firmware_constant(tmp_path):
    assert fw.parse_define(__file__.replace("test_firmware.py", "helpers.py"), "NOPE") is None
    f = findings(fw.pwm_constants, _pwm_ctx(tmp_path))
    assert len(f) == 1 and "reaches U5.17 VREF at 0.882 V full scale (3.3 V bank rail through R10/R11)" in \
        f[0].message and "scaled by 0.276" in f[0].message
    assert findings(fw.pwm_constants, _pwm_ctx(tmp_path, constant="882")) == [], "a matching constant passes"


def test_firmware_limit_beyond_board_full_scale(tmp_path):
    from helpers import FakePartsDB
    ctx = _pwm_ctx(tmp_path)
    (tmp_path / "pwm.h").write_text("#define PWM_VREF_mV 3200\n#define I_MAX_MA 2500\n")
    ctx.config["firmware"]["pwm_outputs"][0]["limit"] = {"constant": "I_MAX_MA", "unit": "mA", "gain": "kv"}
    ctx.partsdb = FakePartsDB({"DRV": {
        "pin_functions": {"VREF": {"direction": "input", "pins": ["17"], "io_standard": "analog"}},
        "electrical_characteristics": {"kv": {"kind": "range_table", "unit": "V/A", "applies_to": ["VREF"],
                                              "rows": [{"min": 1.254, "typ": 1.32, "max": 1.386}]}}}})
    f = findings(fw.pwm_limits, ctx)
    assert len(f) == 1 and "I_MAX_MA = 2500 mA" in f[0].message and "at most 0.704 A (kv 1.254 minimum, 0.668 typical)" \
        in f[0].message


CURRENT_ENUM = """
typedef enum
{
    TLM_3V3_MISC_ISENSE,
    TLM_1V8_FPGA,
    NUMBER_TLM
} TLM_Signal_t;
"""
# Shunt R200 (10 mOhm, Kelvin nets named after the rail), difference amplifier
# U20 with 1k / 100k (gain 100) referenced to 0V3_REF, 1k into the ADC.
AMP = [res("R200", "R0.01", "3V3_MISC_RSENSE_P", "3V3_MISC_RSENSE_N"),
       res("R201", "R1K", "3V3_MISC_RSENSE_N", "AMP_N"), res("R202", "R100K", "AMP_N", "AMP_OUT"),
       res("R203", "R1K", "3V3_MISC_RSENSE_P", "AMP_P"), res("R204", "R100K", "AMP_P", "0V3_REF"),
       res("R205", "R1K", "AMP_OUT", "3V3_MISC_ISENSE_ADC"),
       ("U20", "OPAMP", [("1", "OUT A", "AMP_OUT"), ("2", "-IN A", "AMP_N"), ("3", "+IN A", "AMP_P")])]


def _current(tmp_path, cal_rows):
    ctx = _ctx(tmp_path, adc1_in0="3V3_MISC_ISENSE_ADC", extra=AMP,
               values={"R0.01": "0R01", "R1K": "1k", "R100K": "100k"})
    (tmp_path / "tlm.h").write_text(CURRENT_ENUM)
    from boardcheck.model import Pin
    ctx.design.components["U10"].pins.append(Pin("2", "VA", "3V3", ctx.design.components["U10"]))
    (tmp_path / "cal.csv").write_text("Signal,Gain,Offset\n" + "".join(f"{r}\n" for r in cal_rows))
    ctx.config["firmware"]["adc_channel_maps"][0]["calibration"] = {"file": str(tmp_path / "cal.csv")}
    return ctx


def test_current_channel_scaling_through_difference_amplifier(tmp_path):
    ctx = _current(tmp_path, ["TLM_3V3_MISC_ISENSE,1,0", "TLM_1V8_FPGA,1,0"])
    (f,) = findings(fw.current_scaling, ctx)
    # 3.3 V / 4096 / (100 * 0.01 Ohm) = 0.8057 mA/count; 0.3 V = 372 counts; (3.3 - 0.3) / 1 = 3 A
    assert f.message == ("tlm: 'TLM_3V3_MISC_ISENSE' reads shunt R200 (10 mOhm) with gain 100: 0.8057 mA/count, "
                         "zero current at 0.3 V (372 counts), full scale 3 A")
    assert f.refs == ["R200", "U10"]


def test_current_calibration_offset_must_remove_zero_output(tmp_path):
    ctx = _current(tmp_path, ["TLM_3V3_MISC_ISENSE,1,0", "TLM_1V8_FPGA,0.8057,0"])
    (f,) = findings(fw.current_offsets, ctx)
    assert "TLM_3V3_MISC_ISENSE gain 1 offset 0 (zero current at 0 counts; board: 372 counts, 0.3 V)" in f.message
    # mA units: gain 0.8057, offset -0.8057 * 372.4 = -300; A units give the same ratio
    for row in ("TLM_3V3_MISC_ISENSE,0.8057,-300", "TLM_3V3_MISC_ISENSE,0.0008057,-0.3"):
        ctx = _current(tmp_path, [row, "TLM_1V8_FPGA,1,0"])
        assert findings(fw.current_offsets, ctx) == []


def test_current_channel_without_a_shunt_is_reported(tmp_path):
    ctx = _current(tmp_path, ["TLM_3V3_MISC_ISENSE,1,0", "TLM_1V8_FPGA,1,0"])
    ctx.design.part_params["R0.01"]["R_Value"] = "1k"
    (f,) = findings(fw.current_scaling, ctx)
    assert "could not trace '3V3_MISC_ISENSE_ADC'" in f.message


GPIO_H = """\
// Power
#define A_PWR_EN   GPIO_0
#define B_PWR_EN   GPIO_1
#define SPARE_OUT  GPIO_3
// Unmapped block
#define OTHER      GPIO_0
"""


def _gpio_ctx(tmp_path, port0="a_pwr_en", use="SPARE_OUT"):
    root = tmp_path / "bd"
    (root / "top" / "components").mkdir(parents=True)
    top = root / "top" / "components" / "top.tcl"
    top.write_text(f"""set sd_name {{top}}
sd_create_scalar_port -sd_name ${{sd_name}} -port_name {{{port0}}} -port_direction {{OUT}}
sd_create_scalar_port -sd_name ${{sd_name}} -port_name {{b_pwr_en}} -port_direction {{OUT}}
sd_instantiate_component -sd_name ${{sd_name}} -component_name {{CoreGPIO_C3}} -instance_name {{gpo}}
sd_connect_pins -sd_name ${{sd_name}} -pin_names {{"gpo:GPIO_OUT[0:0]" "{port0}" }}
sd_connect_pins -sd_name ${{sd_name}} -pin_names {{"gpo:GPIO_OUT[1:1]" "b_pwr_en" }}
""")
    (tmp_path / "io.pdc").write_text(f'set_io {{{port0}}} -pinname "A1" -iostd "LVCMOS33" -direction "OUTPUT"\n'
                                     'set_io {b_pwr_en} -pinname "A2" -iostd "LVCMOS33" -direction "OUTPUT"\n')
    (tmp_path / "gpio.h").write_text(GPIO_H)
    (tmp_path / "src").mkdir()
    (tmp_path / "src" / "main.c").write_text(f"void f(void) {{ GPIO_set_output(&g, {use}, 1); }}\n")
    spec = {"name": "gpio", "header": str(tmp_path / "gpio.h"), "source_dir": str(tmp_path / "src"), "fpga": "U1",
            "blocks": [{"groups": ["Power"], "instance": "gpo", "pin": "GPIO_OUT"}]}
    return build_ctx([("U1", "FPGA", [("A1", "GPIO1PB2", "PWR_A"), ("A2", "GPIO2PB2", "PWR_B")])],
                     config={"fpga": {"U1": {"constraints": [str(tmp_path / "io.pdc")], "top_level": [str(top)]}},
                             "firmware": {"gpio_maps": [spec]}})


def test_gpio_map_traces_defines_to_balls(tmp_path):
    ctx = _gpio_ctx(tmp_path)
    assert findings(fw.gpio_names, ctx) == []
    (f,) = findings(fw.gpio_unconnected, ctx)
    assert f.message == "gpio: firmware uses 'SPARE_OUT' (gpo:GPIO_OUT[3]), which connects to nothing in the FPGA design"
    (m,) = findings(fw.gpio_map, ctx)
    assert m.message == ("gpio: 2 of 3 defines traced to FPGA balls; constant or unconnected in the FPGA: SPARE_OUT; "
                         "header groups with no CoreGPIO configured: Unmapped block")


def test_gpio_bit_on_a_differently_named_port(tmp_path):
    ctx = _gpio_ctx(tmp_path, port0="lvds_pwr_en", use="A_PWR_EN")
    (f,) = findings(fw.gpio_names, ctx)
    assert f.message == ("gpio: firmware 'A_PWR_EN' is gpo:GPIO_OUT[0], which reaches top-level port 'lvds_pwr_en', "
                         "ball A1 'PWR_A'")
    assert findings(fw.gpio_unconnected, ctx) == []


def test_scale_table_against_board(tmp_path):
    ctx = _scaled(tmp_path, ["TLM_3V3_MISC,1,0", "TLM_1V8_FPGA,1,0", "TLM_5V0,1,0"])
    (tmp_path / "telemetry.h").write_text(
        "//3V3_MISC    VOLTAGE IN0 CS_1    N/A 0.00132967\n"
        "//1V8_FPGA    VOLTAGE IN1 CS_1    N/A 0.00080586\n"
        "//5V0         VOLTAGE IN1 CS_2    N/A 0.0016\n")
    ctx.config["firmware"]["adc_channel_maps"][0]["scale_table"] = {"file": str(tmp_path / "telemetry.h")}
    msgs = [f.message for f in findings(fw.scale_table_vs_board, ctx)]
    assert msgs == ["tlm: telemetry.h:3 puts '5V0' on select 1 input 1, the firmware enum on select 1 input 0",
                    "tlm: telemetry.h:3 scales '5V0' at 1.6 mV/count, the board at 0.80566 mV/count "
                    "(R103, ratio 1): 1.99 times the board"], "3V3_MISC 1.32967 is within 2% of 1.3294"
    (tmp_path / "telemetry.h").write_text("//3V3_MISC    VOLTAGE IN0 CS_1    N/A 0.00132967\n")
    assert [f.message for f in findings(fw.scale_table_vs_board, ctx)][-1] == \
        "tlm: 'TLM_5V0' has no row in the scale table"
