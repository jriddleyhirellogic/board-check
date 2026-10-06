# Exporting core STEP_DIR to TCL
# Exporting Create HDL core command for module STEP_DIR
create_hdl_core -file "[file normalize [file join [file dirname [info script]] ../src/STEP_DIR.sv]]" -module {STEP_DIR} -library {work} -package {}
# Exporting BIF information of  HDL core command for module STEP_DIR
