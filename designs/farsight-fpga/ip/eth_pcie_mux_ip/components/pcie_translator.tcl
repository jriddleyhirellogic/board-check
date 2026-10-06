# Exporting core pcie_translator to TCL
# Exporting Create HDL core command for module pcie_translator
create_hdl_core -file "[file normalize [file join [file dirname [info script]] ./../src/pcie_translator.sv]]" -module {pcie_translator} -library {work} -package {}
# Exporting BIF information of  HDL core command for module pcie_translator
hdl_core_add_bif -hdl_core_name {pcie_translator} -bif_definition {AXI4:AMBA:AMBA4:mirroredMaster} -bif_name {AXI4_S} -signal_map {\
"AWID:s_awid" \
"AWADDR:s_awaddr" \
"AWLEN:s_awlen" \
"AWSIZE:s_awsize" \
"AWBURST:s_awburst" \
"AWVALID:s_awvalid" \
"AWREADY:s_awready" \
"WDATA:s_wdata" \
"WSTRB:s_wstrb" \
"WLAST:s_wlast" \
"WVALID:s_wvalid" \
"WREADY:s_wready" \
"BID:s_bid" \
"BRESP:s_bresp" \
"BVALID:s_bvalid" \
"BREADY:s_bready" \
"ARID:s_arid" \
"ARADDR:s_araddr" \
"ARLEN:s_arlen" \
"ARSIZE:s_arsize" \
"ARBURST:s_arburst" \
"ARVALID:s_arvalid" \
"ARREADY:s_arready" \
"RID:s_rid" \
"RDATA:s_rdata" \
"RRESP:s_rresp" \
"RLAST:s_rlast" \
"RVALID:s_rvalid" \
"RREADY:s_rready" }
hdl_core_add_bif -hdl_core_name {pcie_translator} -bif_definition {AXI4:AMBA:AMBA4:mirroredSlave} -bif_name {AXI4_M} -signal_map {\
"AWID:m_awid" \
"AWADDR:m_awaddr" \
"AWLEN:m_awlen" \
"AWSIZE:m_awsize" \
"AWBURST:m_awburst" \
"AWVALID:m_awvalid" \
"AWREADY:m_awready" \
"WDATA:m_wdata" \
"WSTRB:m_wstrb" \
"WLAST:m_wlast" \
"WVALID:m_wvalid" \
"WREADY:m_wready" \
"BID:m_bid" \
"BRESP:m_bresp" \
"BVALID:m_bvalid" \
"BREADY:m_bready" \
"ARID:m_arid" \
"ARADDR:m_araddr" \
"ARLEN:m_arlen" \
"ARSIZE:m_arsize" \
"ARBURST:m_arburst" \
"ARVALID:m_arvalid" \
"ARREADY:m_arready" \
"RID:m_rid" \
"RDATA:m_rdata" \
"RRESP:m_rresp" \
"RLAST:m_rlast" \
"RVALID:m_rvalid" \
"RREADY:m_rready" }
