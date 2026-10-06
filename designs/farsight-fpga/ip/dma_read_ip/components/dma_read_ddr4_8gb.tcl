# Exporting core word_alignment to TCL
# Exporting Create HDL core command for module word_alignment
set hdl_file "[file normalize [file join [file dirname [info script]] ./../src/dma_read_ddr4_8gb.sv]]"
create_hdl_core -file ${hdl_file} -module {dma_read_ddr4_8gb} -library {work} -package {}
# Exporting BIF information of  HDL core command for module word_alignment
hdl_core_add_bif -hdl_core_name {dma_read_ddr4_8gb} -bif_definition {AXI4Stream:AMBA:AMBA4:master} -bif_name {M_AXIS_DMA_FIFO} -signal_map {\
"TVALID:m_axis_dma_tvalid" \
"TREADY:m_axis_dma_tready" \
"TDATA:m_axis_dma_tdata" }