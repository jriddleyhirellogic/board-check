# Exporting core cam_mux_top to TCL
# Exporting Create HDL core command for module cam_mux_top
create_hdl_core -file "[file normalize [file join [file dirname [info script]] ./../src/cam_mux_top.sv]]" -module {cam_mux_top} -library {work} -package {}
# Exporting BIF information of  HDL core command for module cam_mux_top
hdl_core_add_bif -hdl_core_name {cam_mux_top} -bif_definition {APB:AMBA:AMBA2:slave} -bif_name {s_apb} -signal_map {\
"PADDR:paddr" \
"PENABLE:penable" \
"PWRITE:pwrite" \
"PRDATA:prdata" \
"PWDATA:pwdata" \
"PREADY:pready" \
"PSLVERR:pslverr" \
"PSELx:psel" }