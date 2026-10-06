# Exporting core cam_mux to TCL
# Exporting Create HDL core command for module cam_mux
set hdl_file "[file normalize [file join [file dirname [info script]] ./../src/cam_mux.sv]]"
create_hdl_core -file ${hdl_file} -module {cam_mux} -library {work} -package {}
# Exporting BIF information of HDL core command for module cam_mux
