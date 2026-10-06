
# Exporting core hbeat_runner to TCL
# Exporting Create HDL core command for module hbeat_runner
set hdl_file "[file normalize [file join [file dirname [info script]] ./src/hbeat_runner.sv]]"
create_hdl_core -file ${hdl_file} -module {hbeat_runner} -library {work} -package {}
# Exporting BIF information of  HDL core command for module hbeat_runner
