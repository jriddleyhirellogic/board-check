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


def test_calibration_rows_must_follow_the_enum(tmp_path):
    ctx = _scaled(tmp_path, ["TLM_3V3_MISC,1,0", "TLM_1V8_FPGA,1,0", "TLM_5V0,1,0"])
    assert findings(fw.calibration_names, ctx) == []
    ctx = _scaled(tmp_path, ["TLM_3V3_MISC,1,0", "TLM_1V8_FPGA_,1,0", "TLM_5V0,1,0"])
    f = findings(fw.calibration_names, ctx)
    assert len(f) == 1 and "row 2 'TLM_1V8_FPGA_' (enum: TLM_1V8_FPGA)" in f[0].message
