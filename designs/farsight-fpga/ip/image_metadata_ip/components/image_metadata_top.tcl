# Exporting core image_metadata_top to TCL
# Exporting Create HDL core command for module image_metadata_top
set hdl_file "[file normalize [file join [file dirname [info script]] ./../src/image_metadata_top.sv]]"
create_hdl_core -file ${hdl_file} -module {image_metadata_top} -library {work} -package {}
# Exporting BIF information of  HDL core command for module image_metadata_top
hdl_core_add_bif -hdl_core_name {image_metadata_top} -bif_definition {APB:AMBA:AMBA2:slave} -bif_name {s_apb} -signal_map {\
"PADDR:paddr" \
"PENABLE:penable" \
"PWRITE:pwrite" \
"PRDATA:prdata" \
"PWDATA:pwdata" \
"PREADY:pready" \
"PSLVERR:pslverr" \
"PSELx:psel" }
