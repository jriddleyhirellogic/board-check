# Exporting core image_metadata to TCL
# Exporting Create HDL core command for module image_metadata
set hdl_file "[file normalize [file join [file dirname [info script]] ./../src/image_metadata.sv]]"
create_hdl_core -file ${hdl_file} -module {image_metadata} -library {work} -package {}
# Exporting BIF information of  HDL core command for module image_metadata
