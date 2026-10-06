
# Exporting core pps to TCL
# Exporting Create HDL core command for module pps
set hdl_file "[file normalize [file join [file dirname [info script]] ../src/pps.sv]]"
create_hdl_core -file ${hdl_file} -module {pps} -library {work} -package {}
# Exporting BIF information of  HDL core command for module pps
hdl_core_add_bif -hdl_core_name {pps} -bif_definition {APB:AMBA:AMBA2:slave} -bif_name {s_apb} -signal_map {\
"PADDR:paddr" \
"PENABLE:penable" \
"PWRITE:pwrite" \
"PRDATA:prdata" \
"PWDATA:pwdata" \
"PREADY:pready" \
"PSLVERR:pslverr" \
"PSELx:psel" }