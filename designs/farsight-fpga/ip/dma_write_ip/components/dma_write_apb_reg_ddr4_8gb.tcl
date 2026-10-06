# Exporting core word_alignment to TCL
# Exporting Create HDL core command for module word_alignment
set hdl_file "[file normalize [file join [file dirname [info script]] ./../src/dma_write_apb_reg_ddr4_8gb.sv]]"
create_hdl_core -file ${hdl_file} -module {dma_write_apb_reg_ddr4_8gb} -library {work} -package {}
# Exporting BIF information of  HDL core command for module word_alignment
hdl_core_add_bif -hdl_core_name {dma_write_apb_reg_ddr4_8gb} -bif_definition {APB:AMBA:AMBA2:slave} -bif_name {s_apb} -signal_map {\
"PADDR:paddr" \
"PENABLE:penable" \
"PWRITE:pwrite" \
"PRDATA:prdata" \
"PWDATA:pwdata" \
"PREADY:pready" \
"PSLVERR:pslverr" \
"PSELx:psel" }