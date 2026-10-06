# Exporting core image_metadata_apb_reg to TCL
# Exporting Create HDL core command for module image_metadata_apb_reg
set hdl_file "[file normalize [file join [file dirname [info script]] ./../src/image_metadata_apb_reg.sv]]"
create_hdl_core -file ${hdl_file} -module {image_metadata_apb_reg} -library {work} -package {}
# Exporting BIF information of  HDL core command for module image_metadata_apb_reg
