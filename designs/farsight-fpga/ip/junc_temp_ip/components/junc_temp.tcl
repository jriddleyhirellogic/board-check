# Exporting core junc_temp to TCL
# Exporting Create HDL core command for module junc_temp
set hdl_file "[file normalize [file join [file dirname [info script]] ./../src/junc_temp.sv]]"
create_hdl_core -file ${hdl_file} -module {junc_temp} -library {work} -package {}
# Exporting BIF information of  HDL core command for module junc_temp
hdl_core_add_bif -hdl_core_name {junc_temp} -bif_definition {APB:AMBA:AMBA2:slave} -bif_name {s_apb} -signal_map {\
"PADDR:paddr" \
"PENABLE:penable" \
"PWRITE:pwrite" \
"PRDATA:prdata" \
"PWDATA:pwdata" \
"PREADY:pready" \
"PSLVERR:pslverr" \
"PSELx:psel" }