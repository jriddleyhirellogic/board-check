# Exporting core DELTA_SIGMA to TCL
# Exporting Create HDL core command for module DELTA_SIGMA
create_hdl_core -file "[file normalize [file join [file dirname [info script]] ../src/DELTA_SIGMA.v]]" -module {DELTA_SIGMA} -library {work} -package {}
# Exporting BIF information of  HDL core command for module DELTA_SIGMA
