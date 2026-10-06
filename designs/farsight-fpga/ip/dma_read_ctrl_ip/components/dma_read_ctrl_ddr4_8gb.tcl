# Exporting core dma_read_ctrl_ddr4_8gb to TCL
# Exporting Create HDL core command for module dma_read_ctrl_ddr4_8gb
create_hdl_core -file "[file normalize [file join [file dirname [info script]] ./../src/dma_read_ctrl_ddr4_8gb.sv]]" -module {dma_read_ctrl_ddr4_8gb} -library {work} -package {}
# Exporting BIF information of  HDL core command for module dma_read_ctrl_ddr4_8gb
hdl_core_add_bif -hdl_core_name {dma_read_ctrl_ddr4_8gb} -bif_definition {AXI4Stream:AMBA:AMBA4:master} -bif_name {M_AXIS_UDP_PYL_SIZE} -signal_map {\
"TVALID:m_axis_udp_pyl_size_tvalid" \
"TREADY:m_axis_udp_pyl_size_tready" \
"TDATA:m_axis_udp_pyl_size_tdata" }
hdl_core_add_bif -hdl_core_name {dma_read_ctrl_ddr4_8gb} -bif_definition {AXI4Stream:AMBA:AMBA4:master} -bif_name {M_AXIS_UDP_PYL} -signal_map {\
"TVALID:m_axis_udp_pyl_tvalid" \
"TREADY:m_axis_udp_pyl_tready" \
"TDATA:m_axis_udp_pyl_tdata" \
"TKEEP:m_axis_udp_pyl_tkeep" \
"TLAST:m_axis_udp_pyl_tlast" }
hdl_core_add_bif -hdl_core_name {dma_read_ctrl_ddr4_8gb} -bif_definition {AXI4Stream:AMBA:AMBA4:slave} -bif_name {S_AXIS_DMA_FIFO} -signal_map {\
"TVALID:s_axis_dma_tvalid" \
"TREADY:s_axis_dma_tready" \
"TDATA:s_axis_dma_tdata" }