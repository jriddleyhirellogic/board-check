# Exporting core dma_read_apb_reg_ddr4_8gb to TCL
# Exporting Create HDL core command for module dma_read_apb_reg_ddr4_8gb
create_hdl_core -file "[file normalize [file join [file dirname [info script]] ./../src/dma_read_apb_reg_ddr4_8gb.sv]]" -module {dma_read_apb_reg_ddr4_8gb} -library {work} -package {}
# Exporting BIF information of  HDL core command for module dma_read_apb_reg_ddr4_8gb
hdl_core_add_bif -hdl_core_name {dma_read_apb_reg_ddr4_8gb} -bif_definition {APB:AMBA:AMBA2:slave} -bif_name {s_apb} -signal_map {\
"PADDR:paddr" \
"PENABLE:penable" \
"PWRITE:pwrite" \
"PRDATA:prdata" \
"PWDATA:pwdata" \
"PREADY:pready" \
"PSLVERR:pslverr" \
"PSELx:psel" }
