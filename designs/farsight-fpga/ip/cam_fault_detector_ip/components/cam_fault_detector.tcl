# Exporting core cam_fault_detector to TCL
# Exporting Create HDL core command for module cam_fault_detector
set hdl_file "[file normalize [file join [file dirname [info script]] ./../src/cam_fault_detector.sv]]"
create_hdl_core -file ${hdl_file} -module {cam_fault_detector} -library {work} -package {}
# Exporting BIF information of HDL core command for module cam_fault_detector
