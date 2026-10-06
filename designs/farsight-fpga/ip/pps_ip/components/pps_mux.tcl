
# Exporting core pps_mux to TCL
# Exporting Create HDL core command for module pps_mux
set hdl_file "[file normalize [file join [file dirname [info script]] ../src/pps_mux.sv]]"
create_hdl_core -file ${hdl_file} -module {pps_mux} -library {work} -package {}
# Exporting BIF information of  HDL core command for module pps_mux
