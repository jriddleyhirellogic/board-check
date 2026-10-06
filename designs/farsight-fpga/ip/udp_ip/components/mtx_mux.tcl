# Exporting core mtx_mux to TCL
# Exporting Create HDL core command for module mtx_mux
set hdl_file "[file normalize [file join [file dirname [info script]] ../src/mtx_mux.sv]]"
create_hdl_core -file ${hdl_file} -module {mtx_mux} -library {work} -package {}
# Exporting BIF information of  HDL core command for module mtx_mux
