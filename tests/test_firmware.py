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


def _ctx(tmp_path, adc1_in0="3V3_MISC_TLM_ADC", adc1_in1="1V8_FPGA_TLM_ADC"):
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
                             ("4", "Y", "5V0_TLM_ADC")])]
    spec = {"name": "tlm", "enum_file": str(tmp_path / "tlm.h"), "enum": "TLM_Signal_t", "skip": ["NUMBER_TLM"],
            "strip_prefix": "TLM_", "channels_per_select": 4, "fpga": "U1",
            "select_link": r"spi_inst:SPISS\[{n}:{n}\]", "net_strip": ["_ADC$", "_TLM$"]}
    ctx = build_ctx(comps, config={"fpga": {"U1": {"constraints": [str(tmp_path / "io.pdc")],
                                                   "top_level": [str(tmp_path / "top.tcl")]}},
                                   "firmware": {"adc_channel_maps": [spec]}})
    ctx.design.part_params.setdefault("R", {})["R_Value"] = "33"
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
