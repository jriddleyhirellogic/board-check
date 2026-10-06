# Exporting core cam_trig to TCL
# Exporting Create HDL core command for module cam_trig
set hdl_file "[file normalize [file join [file dirname [info script]] ./../src/cam_trig.sv]]"
create_hdl_core -file ${hdl_file} -module {cam_trig} -library {work} -package {}
# Exporting BIF information of HDL core command for module cam_trig
