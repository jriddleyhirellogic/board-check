# Exporting core watchdog to TCL
# Exporting Create HDL core command for module watchdog
set hdl_file "[file normalize [file join [file dirname [info script]] ./../src/watchdog.sv]]"
create_hdl_core -file ${hdl_file} -module {watchdog} -library {work} -package {}
# Exporting BIF information of HDL core command for module watchdog
