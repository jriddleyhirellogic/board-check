# Exporting core xcvr_disparity_correction to TCL
# Exporting Create HDL core command for module xcvr_disparity_correction
set hdl_file "[file normalize [file join [file dirname [info script]] ./src/xcvr_disparity_correction.v]]"
create_hdl_core -file ${hdl_file} -module {xcvr_disparity_correction} -library {work} -package {}
# Exporting BIF information of  HDL core command for module xcvr_disparity_correction
