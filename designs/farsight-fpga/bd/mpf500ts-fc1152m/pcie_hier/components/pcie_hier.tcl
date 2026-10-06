# Creating SmartDesign "pcie_hier"
set sd_name {pcie_hier}
create_smartdesign -sd_name ${sd_name}

# Disable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 0

# Create top level Scalar Ports
sd_create_scalar_port -sd_name ${sd_name} -port_name {ACLK} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ARESETN} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_ARREADY} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_AWREADY} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_BVALID} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_RLAST} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_RVALID} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_WREADY} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI_CLK_STABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI_CLK} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {OSC_CLK} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PCIESS_LANE_RXD0_N} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PCIESS_LANE_RXD0_P} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PCIESS_LANE_RXD1_N} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PCIESS_LANE_RXD1_P} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PCIE_0_PERST_N} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PCIE_INIT_DONE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {REF_CLK_PAD_N} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {REF_CLK_PAD_P} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {RESET_N} -port_direction {IN}

sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_ARVALID} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_AWVALID} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_BREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_RREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_WLAST} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_WVALID} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PCIESS_LANE_TXD0_N} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PCIESS_LANE_TXD0_P} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PCIESS_LANE_TXD1_N} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PCIESS_LANE_TXD1_P} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PCIE_0_INTERRUPT_OUT} -port_direction {OUT}


# Create top level Bus Ports
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_BID} -port_direction {IN} -port_range {[4:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_BRESP} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_BUSER} -port_direction {IN} -port_range {[0:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_RDATA} -port_direction {IN} -port_range {[63:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_RID} -port_direction {IN} -port_range {[4:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_RRESP} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_RUSER} -port_direction {IN} -port_range {[0:0]}

sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_ARADDR} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_ARBURST} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_ARCACHE} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_ARID} -port_direction {OUT} -port_range {[4:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_ARLEN} -port_direction {OUT} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_ARLOCK} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_ARPROT} -port_direction {OUT} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_ARQOS} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_ARREGION} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_ARSIZE} -port_direction {OUT} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_ARUSER} -port_direction {OUT} -port_range {[0:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_AWADDR} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_AWBURST} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_AWCACHE} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_AWID} -port_direction {OUT} -port_range {[4:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_AWLEN} -port_direction {OUT} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_AWLOCK} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_AWPROT} -port_direction {OUT} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_AWQOS} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_AWREGION} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_AWSIZE} -port_direction {OUT} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_AWUSER} -port_direction {OUT} -port_range {[0:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_WDATA} -port_direction {OUT} -port_range {[63:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_WSTRB} -port_direction {OUT} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI_0_MASTER_SLAVE1_WUSER} -port_direction {OUT} -port_range {[0:0]}


# Create top level Bus interface Ports
sd_create_bif_port -sd_name ${sd_name} -port_name {AXI_0_MASTER} -port_bif_vlnv {AMBA:AMBA4:AXI4:r0p0_0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"AWID:AXI_0_MASTER_SLAVE1_AWID" \
"AWADDR:AXI_0_MASTER_SLAVE1_AWADDR" \
"AWLEN:AXI_0_MASTER_SLAVE1_AWLEN" \
"AWSIZE:AXI_0_MASTER_SLAVE1_AWSIZE" \
"AWBURST:AXI_0_MASTER_SLAVE1_AWBURST" \
"AWLOCK:AXI_0_MASTER_SLAVE1_AWLOCK" \
"AWCACHE:AXI_0_MASTER_SLAVE1_AWCACHE" \
"AWPROT:AXI_0_MASTER_SLAVE1_AWPROT" \
"AWQOS:AXI_0_MASTER_SLAVE1_AWQOS" \
"AWREGION:AXI_0_MASTER_SLAVE1_AWREGION" \
"AWVALID:AXI_0_MASTER_SLAVE1_AWVALID" \
"AWREADY:AXI_0_MASTER_SLAVE1_AWREADY" \
"WDATA:AXI_0_MASTER_SLAVE1_WDATA" \
"WSTRB:AXI_0_MASTER_SLAVE1_WSTRB" \
"WLAST:AXI_0_MASTER_SLAVE1_WLAST" \
"WVALID:AXI_0_MASTER_SLAVE1_WVALID" \
"WREADY:AXI_0_MASTER_SLAVE1_WREADY" \
"BID:AXI_0_MASTER_SLAVE1_BID" \
"BRESP:AXI_0_MASTER_SLAVE1_BRESP" \
"BVALID:AXI_0_MASTER_SLAVE1_BVALID" \
"BREADY:AXI_0_MASTER_SLAVE1_BREADY" \
"ARID:AXI_0_MASTER_SLAVE1_ARID" \
"ARADDR:AXI_0_MASTER_SLAVE1_ARADDR" \
"ARLEN:AXI_0_MASTER_SLAVE1_ARLEN" \
"ARSIZE:AXI_0_MASTER_SLAVE1_ARSIZE" \
"ARBURST:AXI_0_MASTER_SLAVE1_ARBURST" \
"ARLOCK:AXI_0_MASTER_SLAVE1_ARLOCK" \
"ARCACHE:AXI_0_MASTER_SLAVE1_ARCACHE" \
"ARPROT:AXI_0_MASTER_SLAVE1_ARPROT" \
"ARQOS:AXI_0_MASTER_SLAVE1_ARQOS" \
"ARREGION:AXI_0_MASTER_SLAVE1_ARREGION" \
"ARVALID:AXI_0_MASTER_SLAVE1_ARVALID" \
"ARREADY:AXI_0_MASTER_SLAVE1_ARREADY" \
"RID:AXI_0_MASTER_SLAVE1_RID" \
"RDATA:AXI_0_MASTER_SLAVE1_RDATA" \
"RRESP:AXI_0_MASTER_SLAVE1_RRESP" \
"RLAST:AXI_0_MASTER_SLAVE1_RLAST" \
"RVALID:AXI_0_MASTER_SLAVE1_RVALID" \
"RREADY:AXI_0_MASTER_SLAVE1_RREADY" \
"AWUSER:AXI_0_MASTER_SLAVE1_AWUSER" \
"WUSER:AXI_0_MASTER_SLAVE1_WUSER" \
"BUSER:AXI_0_MASTER_SLAVE1_BUSER" \
"ARUSER:AXI_0_MASTER_SLAVE1_ARUSER" \
"RUSER:AXI_0_MASTER_SLAVE1_RUSER" } 

# Add AHBtoAPB_0 instance
sd_instantiate_component -sd_name ${sd_name} -component_name {AHBtoAPB} -instance_name {AHBtoAPB_0}



# Add AXItoAHBL_0 instance
sd_instantiate_component -sd_name ${sd_name} -component_name {AXItoAHBL} -instance_name {AXItoAHBL_0}



# Add CLK_DIV2_0 instance
sd_instantiate_component -sd_name ${sd_name} -component_name {CLK_DIV2} -instance_name {CLK_DIV2_0}



# Add Core_AHBL_0 instance
sd_instantiate_component -sd_name ${sd_name} -component_name {Core_AHBL} -instance_name {Core_AHBL_0}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {Core_AHBL_0:REMAP_M0} -value {GND}



# Add Core_APB_0 instance
sd_instantiate_component -sd_name ${sd_name} -component_name {Core_APB} -instance_name {Core_APB_0}



# Add COREAXI4INTERCONNECT_C1_0 instance
sd_instantiate_component -sd_name ${sd_name} -component_name {COREAXI4INTERCONNECT_C1} -instance_name {COREAXI4INTERCONNECT_C1_0}



# Add NGMUX_0 instance
sd_instantiate_component -sd_name ${sd_name} -component_name {NGMUX} -instance_name {NGMUX_0}



# Add PCIe_TX_PLL_0 instance
sd_instantiate_component -sd_name ${sd_name} -component_name {PCIe_TX_PLL} -instance_name {PCIe_TX_PLL_0}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {PCIe_TX_PLL_0:PLL_LOCK}



# Add PF_PCIE_C0_0 instance
sd_instantiate_component -sd_name ${sd_name} -component_name {PF_PCIE_C0} -instance_name {PF_PCIE_C0_0}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {PF_PCIE_C0_0:PCIE_0_INTERRUPT} -pin_slices {[3:0]}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {PF_PCIE_C0_0:PCIE_0_INTERRUPT[3:0]} -value {GND}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {PF_PCIE_C0_0:PCIE_0_INTERRUPT} -pin_slices {[7:4]}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {PF_PCIE_C0_0:PCIE_0_INTERRUPT[7:4]} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {PF_PCIE_C0_0:PCIE_0_M_RDERR} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {PF_PCIE_C0_0:PCIE_0_S_WDERR} -value {GND}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {PF_PCIE_C0_0:PCIE_0_M_WDERR}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {PF_PCIE_C0_0:PCIE_0_S_RDERR}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {PF_PCIE_C0_0:PCIE_0_HOT_RST_EXIT}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {PF_PCIE_C0_0:PCIE_0_DLUP_EXIT}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {PF_PCIE_C0_0:PCIE_0_LTSSM}



# Add PF_XCVR_REF_CLK_C1_0 instance
sd_instantiate_component -sd_name ${sd_name} -component_name {PF_XCVR_REF_CLK_C1} -instance_name {PF_XCVR_REF_CLK_C1_0}



# Add scalar net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"ACLK" "AHBtoAPB_0:HCLK" "AXItoAHBL_0:ACLK" "AXItoAHBL_0:HCLK" "COREAXI4INTERCONNECT_C1_0:S_CLK0" "Core_AHBL_0:HCLK" "PF_PCIE_C0_0:APB_S_PCLK" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"AHBtoAPB_0:HRESETN" "ARESETN" "AXItoAHBL_0:ARESETN" "AXItoAHBL_0:HRESETN" "Core_AHBL_0:HRESETN" "PF_PCIE_C0_0:APB_S_PRESET_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"AXI_CLK" "COREAXI4INTERCONNECT_C1_0:ACLK" "PF_PCIE_C0_0:AXI_CLK" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"AXI_CLK_STABLE" "PF_PCIE_C0_0:AXI_CLK_STABLE" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CLK_DIV2_0:CLK_IN" "OSC_CLK" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CLK_DIV2_0:CLK_OUT" "NGMUX_0:CLK0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"COREAXI4INTERCONNECT_C1_0:ARESETN" "RESET_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"NGMUX_0:CLK1" "PCIe_TX_PLL_0:CLK_125" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"NGMUX_0:CLK_OUT" "PF_PCIE_C0_0:PCIE_0_TL_CLK_125MHz" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"NGMUX_0:SEL" "PCIE_INIT_DONE" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"PCIESS_LANE_RXD0_N" "PF_PCIE_C0_0:PCIESS_LANE_RXD0_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"PCIESS_LANE_RXD0_P" "PF_PCIE_C0_0:PCIESS_LANE_RXD0_P" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"PCIESS_LANE_RXD1_N" "PF_PCIE_C0_0:PCIESS_LANE_RXD1_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"PCIESS_LANE_RXD1_P" "PF_PCIE_C0_0:PCIESS_LANE_RXD1_P" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"PCIESS_LANE_TXD0_N" "PF_PCIE_C0_0:PCIESS_LANE_TXD0_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"PCIESS_LANE_TXD0_P" "PF_PCIE_C0_0:PCIESS_LANE_TXD0_P" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"PCIESS_LANE_TXD1_N" "PF_PCIE_C0_0:PCIESS_LANE_TXD1_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"PCIESS_LANE_TXD1_P" "PF_PCIE_C0_0:PCIESS_LANE_TXD1_P" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"PCIE_0_INTERRUPT_OUT" "PF_PCIE_C0_0:PCIE_0_INTERRUPT_OUT" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"PCIE_0_PERST_N" "PF_PCIE_C0_0:PCIE_0_PERST_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"PCIe_TX_PLL_0:REF_CLK" "PF_PCIE_C0_0:PCIESS_LANE0_CDR_REF_CLK_0" "PF_PCIE_C0_0:PCIESS_LANE1_CDR_REF_CLK_0" "PF_XCVR_REF_CLK_C1_0:REF_CLK" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"PF_XCVR_REF_CLK_C1_0:REF_CLK_PAD_N" "REF_CLK_PAD_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"PF_XCVR_REF_CLK_C1_0:REF_CLK_PAD_P" "REF_CLK_PAD_P" }


# Add bus interface net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"AHBtoAPB_0:AHBtarget" "Core_AHBL_0:AHBmslave0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"AHBtoAPB_0:APBinitiator" "Core_APB_0:APB3mmaster" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"AXI_0_MASTER" "COREAXI4INTERCONNECT_C1_0:AXI4mslave1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"AXItoAHBL_0:AHBMasterIF" "Core_AHBL_0:AHBmmaster0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"AXItoAHBL_0:AXI4SlaveIF" "COREAXI4INTERCONNECT_C1_0:AXI4mslave0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"COREAXI4INTERCONNECT_C1_0:AXI4mmaster0" "PF_PCIE_C0_0:AXI_0_MASTER" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"Core_APB_0:APBmslave0" "PF_PCIE_C0_0:PCIE_APB_SLAVE" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"PCIe_TX_PLL_0:CLKS_TO_XCVR" "PF_PCIE_C0_0:CLKS_FROM_TXPLL_TO_PCIE_0" }

# Re-enable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 1
# Save the SmartDesign 
save_smartdesign -sd_name ${sd_name}
# Generate SmartDesign "pcie_hier"
generate_component -component_name ${sd_name}
