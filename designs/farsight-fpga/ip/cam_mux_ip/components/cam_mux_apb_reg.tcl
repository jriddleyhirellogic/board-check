# Exporting core cam_mux_apb_reg to TCL
# Exporting Create HDL core command for module cam_mux_apb_reg
set hdl_file "[file normalize [file join [file dirname [info script]] ./../src/cam_mux_apb_reg.sv]]"
create_hdl_core -file ${hdl_file} -module {cam_mux_apb_reg} -library {work} -package {}
# Exporting BIF information of HDL core command for module cam_mux_apb_reg
hdl_core_add_bif -hdl_core_name {cam_mux_apb_reg} -bif_definition {APB:AMBA:AMBA2:slave} -bif_name {s_apb} -signal_map {\
"PADDR:paddr" \
"PENABLE:penable" \
"PWRITE:pwrite" \
"PRDATA:prdata" \
"PWDATA:pwdata" \
"PREADY:pready" \
"PSLVERR:pslverr" \
"PSELx:psel" }
