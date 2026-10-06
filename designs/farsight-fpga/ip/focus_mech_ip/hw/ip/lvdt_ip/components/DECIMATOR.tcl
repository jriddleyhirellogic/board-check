# Exporting core DECIMATOR to TCL
# Exporting Create HDL core command for module DECIMATOR
create_hdl_core -file "[file normalize [file join [file dirname [info script]] ../src/DECIMATOR.sv]]" -module {DECIMATOR} -library {work} -package {}
# Exporting BIF information of  HDL core command for module DECIMATOR
