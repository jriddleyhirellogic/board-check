# Exporting core SINE_SCALER to TCL
# Exporting Create HDL core command for module SINE_SCALER
create_hdl_core -file "[file normalize [file join [file dirname [info script]] ../src/SINE_SCALER.v]]" -module {SINE_SCALER} -library {work} -package {}
# Exporting BIF information of  HDL core command for module SINE_SCALER
