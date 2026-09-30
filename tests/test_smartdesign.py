from boardcheck.smartdesign import Hierarchy

TOP = """\
set sd_name {top}
sd_create_scalar_port -sd_name ${sd_name} -port_name {en_a} -port_direction {OUT}
sd_create_bus_port -sd_name ${sd_name} -port_name {ver} -port_direction {IN} -port_range {[2:0]}
sd_create_scalar_port -sd_name ${sd_name} -port_name {rst_n} -port_direction {OUT}
sd_instantiate_component -sd_name ${sd_name} -component_name {sub} -instance_name {sub_inst}
sd_connect_pins -sd_name ${sd_name} -pin_names {"sub_inst:en" "en_a" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ver" "sub_inst:ver_in" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"sub_inst:rst_pad" "rst_n" }
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {sub_inst:spare} -value {GND}
"""
SUB = """\
set sd_name {sub}
sd_create_scalar_port -sd_name ${sd_name} -port_name {en} -port_direction {OUT}
sd_create_bus_port -sd_name ${sd_name} -port_name {ver_in} -port_direction {IN} -port_range {[2:0]}
sd_create_scalar_port -sd_name ${sd_name} -port_name {rst_pad} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {spare} -port_direction {IN}
sd_instantiate_component -sd_name ${sd_name} -component_name {CoreGPIO_C1} -instance_name {gpio}
sd_instantiate_macro -sd_name ${sd_name} -macro_name {INV} -instance_name {inv_rst}
sd_instantiate_macro -sd_name ${sd_name} -macro_name {TRIBUFF} -instance_name {buf_rst}
sd_instantiate_macro -sd_name ${sd_name} -macro_name {AND2} -instance_name {gate}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpio:GPIO_OUT} -pin_slices {[0:0]}
sd_connect_pins -sd_name ${sd_name} -pin_names {"en" "gpio:GPIO_OUT[0:0]" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpio:GPIO_IN[7:5]" "ver_in" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpio:GPIO_OUT[1:1]" "inv_rst:A" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"inv_rst:Y" "buf_rst:D" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"buf_rst:PAD" "rst_pad" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpio:GPIO_IN[0:0]" "spare" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpio:GPIO_OUT[2:2]" "gate:A" }
"""


def _hier(tmp_path):
    (tmp_path / "top" / "components").mkdir(parents=True)
    (tmp_path / "blk" / "components").mkdir(parents=True)
    (tmp_path / "top" / "components" / "top.tcl").write_text(TOP)
    (tmp_path / "blk" / "components" / "sub_design.tcl").write_text(SUB)   # file name need not match
    return Hierarchy(str(tmp_path), "top")


def test_trace_through_ports_slices_and_macros(tmp_path):
    h = _hier(tmp_path)
    up = lambda pin, bit: h.trace_up(["sub_inst", "gpio"], pin, bit)   # noqa: E731
    assert up("GPIO_OUT", 0) == ("port", "en_a", None, False)
    # GPIO_IN[7:5] <- ver_in[2:0] <- ver[2:0], LSB to LSB
    assert [up("GPIO_IN", b)[1:3] for b in (5, 6, 7)] == [("ver", 0), ("ver", 1), ("ver", 2)]
    assert up("GPIO_OUT", 1) == ("port", "rst_n", None, True)          # through INV and TRIBUFF
    assert up("GPIO_IN", 0)[:2] == ("constant", "GND")                   # tied off in the parent
    assert up("GPIO_OUT", 2)[0] == "internal"                            # into an AND2
    assert up("GPIO_OUT", 3)[0] == "open"
    assert h.trace_up(["nope", "gpio"], "GPIO_OUT", 0)[0] == "open"
