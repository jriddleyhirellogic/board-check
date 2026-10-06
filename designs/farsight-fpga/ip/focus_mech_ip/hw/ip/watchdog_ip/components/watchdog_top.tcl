# Exporting core watchdog_top to TCL
# Exporting Create HDL core command for module watchdog_top
create_hdl_core -file "[file normalize [file join [file dirname [info script]] ./../src/watchdog_top.sv]]" -module {watchdog_top} -library {work} -package {}
# Exporting BIF information of  HDL core command for module watchdog_top
hdl_core_add_bif -hdl_core_name {watchdog_top} -bif_definition {APB:AMBA:AMBA2:slave} -bif_name {s_apb} -signal_map {\
"PADDR:paddr" \
"PENABLE:penable" \
"PWRITE:pwrite" \
"PRDATA:prdata" \
"PWDATA:pwdata" \
"PREADY:pready" \
"PSLVERR:pslverr" \
"PSELx:psel" }