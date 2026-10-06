# Exporting core cam_flow_sync to TCL
# Exporting Create HDL core command for module cam_flow_sync
set hdl_file "[file normalize [file join [file dirname [info script]] ./../src/cam_flow_sync.sv]]"
create_hdl_core -file ${hdl_file} -module {cam_flow_sync} -library {work} -package {}
# Exporting BIF information of  HDL core command for module cam_flow_sync
