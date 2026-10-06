# Exporting core rsp_top to TCL
# Exporting Create HDL core command for module rsp_top
create_hdl_core -file "[file normalize [file join [file dirname [info script]] ./../src/rsp_top.sv]]" -module {rsp_top} -library {work} -package {}
