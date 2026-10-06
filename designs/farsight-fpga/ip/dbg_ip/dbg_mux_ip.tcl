
# Exporting core dbg_mux to TCL
# Exporting Create HDL core command for module dbg_mux
set hdl_file "[file normalize [file join [file dirname [info script]] ./src/dbg_mux.sv]]"
create_hdl_core -file ${hdl_file} -module {dbg_mux} -library {work} -package {}
# Exporting BIF information of  HDL core command for module dbg_mux
