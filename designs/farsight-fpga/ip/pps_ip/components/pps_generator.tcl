
# Exporting core pps_generator to TCL
# Exporting Create HDL core command for module pps_generator
set hdl_file "[file normalize [file join [file dirname [info script]] ../src/pps_generator.sv]]"
create_hdl_core -file ${hdl_file} -module {pps_generator} -library {work} -package {}
# Exporting BIF information of  HDL core command for module pps_generator
