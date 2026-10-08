from boardcheck import fpga
from boardcheck.checks import clocks
from helpers import build_ctx, findings, res

OSC = {"part_info": {"type": "oscillator", "frequency_hz": 25e6},
       "pin_functions": {"OUT": {"direction": "output", "function": "CLOCK_OUT", "pins": ["3"]},
                         "VDD": {"direction": "power", "function": "POWER", "pins": ["4"]}}}


def _ctx(tmp_path, port="sys_clk", period="20", osc_hz=25e6, clock_net="CLK"):
    (tmp_path / "io.pdc").write_text(f'set_io {{{port}}} -pinname "A1" -iostd "LVCMOS33" -direction "INPUT"\n')
    (tmp_path / "t.sdc").write_text(f"create_clock -name {{c}} -period {period} \\\\\n    [ get_ports {{ {port} }} ]\n")
    cfg = {"constraints": [str(tmp_path / "io.pdc")], "timing": [str(tmp_path / "t.sdc")]}
    comps = [("U1", "FPGA", [("A1", "IO1", "CLK_R")]),
             ("Y1", "OSC", [("3", "OUT", clock_net), ("4", "VDD", "3V3")]),
             res("R1", "R33", clock_net, "CLK_R")]
    osc = dict(OSC, part_info={"type": "oscillator", "frequency_hz": osc_hz})
    ctx = build_ctx(comps, config={"fpga": {"U1": cfg}}, parts={"OSC": osc, "FPGA": {"pin_functions": {}}})
    ctx.design.part_params["R33"]["R_Value"] = "33"
    return ctx


def test_sdc_create_clock_is_read(tmp_path):
    (tmp_path / "a.sdc").write_text("# create_clock -period 1 [get_ports {x}]\n"
                                    "create_clock -name {a} -period 8.000 [get_ports {a b}]\n"
                                    "create_clock -name {c} \\\n  -period 40 [ get_ports { c } ]\n")
    io = fpga.load("U1", [], "", (), None, [str(tmp_path / "a.sdc")])
    assert io.clocks == {"a": (125e6, "a.sdc:2"), "b": (125e6, "a.sdc:2"), "c": (25e6, "a.sdc:3")}


def test_oscillator_differs_from_timing_constraint(tmp_path):
    (f,) = findings(clocks.fpga_clock_frequency, _ctx(tmp_path))
    assert f.message == ("U1 'sys_clk' (A1) is 50 MHz by its timing file t.sdc:1, but the board clocks it from "
                         "Y1 (OSC) at 25 MHz")
    assert f.refs == ["U1", "Y1"]


def test_matching_clock_and_port_name(tmp_path):
    ctx = _ctx(tmp_path, osc_hz=50e6)
    assert findings(clocks.fpga_clock_frequency, ctx) == []
    (s,) = findings(clocks.fpga_clock_summary, ctx)
    assert s.message == "U1 clock inputs: 'sys_clk' A1: 50 MHz (timing file t.sdc:1) <- Y1 (OSC) 50 MHz"
    # the port name states a frequency too
    ctx = _ctx(tmp_path, port="clk_100mhz", period="10", osc_hz=50e6)
    (f,) = findings(clocks.fpga_clock_frequency, ctx)
    assert "is 100 MHz by its timing file t.sdc:1, port name" in f.message


def test_clock_from_a_connector_is_listed_not_compared(tmp_path):
    (tmp_path / "io.pdc").write_text('set_io {tck} -pinname "A1" -iostd "LVCMOS33" -direction "INPUT"\n')
    (tmp_path / "t.sdc").write_text("create_clock -name {tck} -period 100 [get_ports {tck}]\n")
    cfg = {"constraints": [str(tmp_path / "io.pdc")], "timing": [str(tmp_path / "t.sdc")]}
    ctx = build_ctx([("U1", "FPGA", [("A1", "IO1", "TCK")]), ("J1", "HDR", [("1", "1", "TCK")])],
                    config={"fpga": {"U1": cfg}}, parts={"FPGA": {"pin_functions": {}}})
    assert findings(clocks.fpga_clock_frequency, ctx) == []
    (s,) = findings(clocks.fpga_clock_summary, ctx)
    assert s.message == ("U1 clock inputs: 'tck' A1: 10 MHz (timing file t.sdc:1) <- from J1.1 (connector), "
                         "not compared")


TOP_SD = """\
set sd_name {top}
create_smartdesign -sd_name ${sd_name}
sd_create_scalar_port -sd_name ${sd_name} -port_name {clk_in} -port_direction {IN} -port_is_pad {1}
sd_instantiate_macro -sd_name ${sd_name} -macro_name {CLKINT} -instance_name {buf_inst}
sd_instantiate_component -sd_name ${sd_name} -component_name {sub} -instance_name {sub_inst}
sd_connect_pins -sd_name ${sd_name} -pin_names {"clk_in" "buf_inst:A" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"buf_inst:Y" "sub_inst:ref" }
"""
SUB_SD = """\
set sd_name {sub}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ref} -port_direction {IN}
sd_instantiate_component -sd_name ${sd_name} -component_name {MY_CCC} -instance_name {ccc_inst}
sd_connect_pins -sd_name ${sd_name} -pin_names {"ccc_inst:REF_CLK_0" "ref" }
"""
CCC = """\
create_and_configure_core -core_vlnv {Actel:SgCore:PF_CCC:2.2.220} -component_name {MY_CCC} -params {\\
"PLL_IN_FREQ_0:{mhz}"  \\
"PLL_IN_FREQ_1:100"  }
"""


def _sd(tmp_path, mhz):
    bd = tmp_path / "bd"
    (bd / "top" / "components").mkdir(parents=True)
    (bd / "sub" / "components").mkdir(parents=True)
    (bd / "top" / "components" / "top.tcl").write_text(TOP_SD)
    (bd / "sub" / "components" / "sub.tcl").write_text(SUB_SD)
    (bd / "sub" / "components" / "MY_CCC.tcl").write_text(CCC.replace("{mhz}", mhz))
    return bd


def test_smartdesign_walks_to_ip_reference_clock(tmp_path):
    from boardcheck.config import Config
    from boardcheck.ipclocks import Index
    fp = Config()["fpga_pins"]
    ix = Index([str(_sd(tmp_path, "25"))])
    (got,) = ix.clock_settings("top", "clk_in", fp["clock_params"], fp["clock_passthrough"])
    assert got[:2] == (25.0, "MY_CCC PLL_IN_FREQ_0"), "through CLKINT A->Y and into the sub design"
    assert ix.clock_settings("top", "nothing", fp["clock_params"], fp["clock_passthrough"]) == []


def test_ip_clock_setting_against_oscillator(tmp_path):
    bd = _sd(tmp_path, "50")
    (tmp_path / "io.pdc").write_text('set_io {clk_in} -pinname "A1" -iostd "LVCMOS33" -direction "INPUT"\n')
    cfg = {"constraints": [str(tmp_path / "io.pdc")], "top_level": [str(bd / "top" / "components" / "top.tcl")],
           "smartdesign_dirs": [str(bd)]}
    comps = [("U1", "FPGA", [("A1", "IO1", "CLK")]), ("Y1", "OSC", [("3", "OUT", "CLK"), ("4", "VDD", "3V3")])]
    ctx = build_ctx(comps, config={"fpga": {"U1": cfg}}, parts={"OSC": OSC, "FPGA": {"pin_functions": {}}})
    (f,) = findings(clocks.fpga_clock_frequency, ctx)
    assert f.message == "U1 'clk_in' (A1) is 50 MHz by its IP MY_CCC PLL_IN_FREQ_0, but the board clocks it from " \
                        "Y1 (OSC) at 25 MHz"
