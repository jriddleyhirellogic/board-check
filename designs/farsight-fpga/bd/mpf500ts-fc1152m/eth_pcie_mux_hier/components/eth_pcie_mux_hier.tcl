# Creating SmartDesign "eth_pcie_mux_hier"
set sd_name {eth_pcie_mux_hier}
create_smartdesign -sd_name ${sd_name}

# Disable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 0

# Create top level Scalar Ports
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_arready} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_awready} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_bvalid} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_rlast} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_rvalid} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_wready} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_arready} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_awready} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_bvalid} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_rlast} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_rvalid} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_wready} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_arvalid} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_awvalid} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_bready} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_rready} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_wlast} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_wvalid} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_arvalid} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_awvalid} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_bready} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_rready} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_wlast} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_wvalid} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_arvalid} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_awvalid} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_bready} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_rready} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_wlast} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_wvalid} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_16gb_clk} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_16gb_resetn} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_clk} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_resetn} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pclk} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {presetn} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_penable} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_psel} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_pwrite} -port_direction {IN}

sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_arvalid} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_awvalid} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_bready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_rready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_wlast} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_wvalid} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_arvalid} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_awvalid} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_bready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_rready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_wlast} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_wvalid} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_arready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_awready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_bvalid} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_rlast} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_rvalid} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_wready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_arready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_awready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_bvalid} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_rlast} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_rvalid} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_wready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_arready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_awready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_bvalid} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_rlast} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_rvalid} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_wready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_pready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_pslverr} -port_direction {OUT}


# Create top level Bus Ports
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_bid} -port_direction {IN} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_bresp} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_rdata} -port_direction {IN} -port_range {[511:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_rid} -port_direction {IN} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_rresp} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_bid} -port_direction {IN} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_bresp} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_rdata} -port_direction {IN} -port_range {[255:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_rid} -port_direction {IN} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_rresp} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_araddr} -port_direction {IN} -port_range {[38:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_arburst} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_arid} -port_direction {IN} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_arlen} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_arsize} -port_direction {IN} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_awaddr} -port_direction {IN} -port_range {[38:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_awburst} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_awid} -port_direction {IN} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_awlen} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_awsize} -port_direction {IN} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_wdata} -port_direction {IN} -port_range {[511:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_wstrb} -port_direction {IN} -port_range {[63:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_araddr} -port_direction {IN} -port_range {[37:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_arburst} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_arid} -port_direction {IN} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_arlen} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_arsize} -port_direction {IN} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_awaddr} -port_direction {IN} -port_range {[37:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_awburst} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_awid} -port_direction {IN} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_awlen} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_awsize} -port_direction {IN} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_wdata} -port_direction {IN} -port_range {[255:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_wstrb} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_araddr} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_arburst} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_arid} -port_direction {IN} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_arlen} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_arsize} -port_direction {IN} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_awaddr} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_awburst} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_awid} -port_direction {IN} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_awlen} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_awsize} -port_direction {IN} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_wdata} -port_direction {IN} -port_range {[63:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_wstrb} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {s_apb_paddr} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {s_apb_pwdata} -port_direction {IN} -port_range {[31:0]}

sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_araddr} -port_direction {OUT} -port_range {[38:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_arburst} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_arid} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_arlen} -port_direction {OUT} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_arsize} -port_direction {OUT} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_awaddr} -port_direction {OUT} -port_range {[38:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_awburst} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_awid} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_awlen} -port_direction {OUT} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_awsize} -port_direction {OUT} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_wdata} -port_direction {OUT} -port_range {[511:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB_m_wstrb} -port_direction {OUT} -port_range {[63:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_araddr} -port_direction {OUT} -port_range {[37:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_arburst} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_arid} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_arlen} -port_direction {OUT} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_arsize} -port_direction {OUT} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_awaddr} -port_direction {OUT} -port_range {[37:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_awburst} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_awid} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_awlen} -port_direction {OUT} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_awsize} -port_direction {OUT} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_wdata} -port_direction {OUT} -port_range {[255:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB_m_wstrb} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_bid} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_bresp} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_rdata} -port_direction {OUT} -port_range {[511:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_rid} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER_s0_rresp} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_bid} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_bresp} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_rdata} -port_direction {OUT} -port_range {[255:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_rid} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER_s0_rresp} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_bid} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_bresp} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_rdata} -port_direction {OUT} -port_range {[63:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_rid} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE_s_rresp} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {s_apb_prdata} -port_direction {OUT} -port_range {[31:0]}


# Create top level Bus interface Ports
sd_create_bif_port -sd_name ${sd_name} -port_name {s_apb} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:s_apb_paddr" \
"PSELx:s_apb_psel" \
"PENABLE:s_apb_penable" \
"PWRITE:s_apb_pwrite" \
"PRDATA:s_apb_prdata" \
"PWDATA:s_apb_pwdata" \
"PREADY:s_apb_pready" \
"PSLVERR:s_apb_pslverr" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {AXI4_S_PCIE} -port_bif_vlnv {AMBA:AMBA4:AXI4:r0p0_0} -port_bif_role {slave} -port_bif_mapping {\
"AWID:AXI4_S_PCIE_s_awid" \
"AWADDR:AXI4_S_PCIE_s_awaddr" \
"AWLEN:AXI4_S_PCIE_s_awlen" \
"AWSIZE:AXI4_S_PCIE_s_awsize" \
"AWBURST:AXI4_S_PCIE_s_awburst" \
"AWVALID:AXI4_S_PCIE_s_awvalid" \
"AWREADY:AXI4_S_PCIE_s_awready" \
"WDATA:AXI4_S_PCIE_s_wdata" \
"WSTRB:AXI4_S_PCIE_s_wstrb" \
"WLAST:AXI4_S_PCIE_s_wlast" \
"WVALID:AXI4_S_PCIE_s_wvalid" \
"WREADY:AXI4_S_PCIE_s_wready" \
"BID:AXI4_S_PCIE_s_bid" \
"BRESP:AXI4_S_PCIE_s_bresp" \
"BVALID:AXI4_S_PCIE_s_bvalid" \
"BREADY:AXI4_S_PCIE_s_bready" \
"ARID:AXI4_S_PCIE_s_arid" \
"ARADDR:AXI4_S_PCIE_s_araddr" \
"ARLEN:AXI4_S_PCIE_s_arlen" \
"ARSIZE:AXI4_S_PCIE_s_arsize" \
"ARBURST:AXI4_S_PCIE_s_arburst" \
"ARVALID:AXI4_S_PCIE_s_arvalid" \
"ARREADY:AXI4_S_PCIE_s_arready" \
"RID:AXI4_S_PCIE_s_rid" \
"RDATA:AXI4_S_PCIE_s_rdata" \
"RRESP:AXI4_S_PCIE_s_rresp" \
"RLAST:AXI4_S_PCIE_s_rlast" \
"RVALID:AXI4_S_PCIE_s_rvalid" \
"RREADY:AXI4_S_PCIE_s_rready" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_8GB_ARBITER} -port_bif_vlnv {AMBA:AMBA4:AXI4:r0p0_0} -port_bif_role {slave} -port_bif_mapping {\
"AWID:AXI4_S_DDR4_8GB_ARBITER_s0_awid" \
"AWADDR:AXI4_S_DDR4_8GB_ARBITER_s0_awaddr" \
"AWLEN:AXI4_S_DDR4_8GB_ARBITER_s0_awlen" \
"AWSIZE:AXI4_S_DDR4_8GB_ARBITER_s0_awsize" \
"AWBURST:AXI4_S_DDR4_8GB_ARBITER_s0_awburst" \
"AWVALID:AXI4_S_DDR4_8GB_ARBITER_s0_awvalid" \
"AWREADY:AXI4_S_DDR4_8GB_ARBITER_s0_awready" \
"WDATA:AXI4_S_DDR4_8GB_ARBITER_s0_wdata" \
"WSTRB:AXI4_S_DDR4_8GB_ARBITER_s0_wstrb" \
"WLAST:AXI4_S_DDR4_8GB_ARBITER_s0_wlast" \
"WVALID:AXI4_S_DDR4_8GB_ARBITER_s0_wvalid" \
"WREADY:AXI4_S_DDR4_8GB_ARBITER_s0_wready" \
"BID:AXI4_S_DDR4_8GB_ARBITER_s0_bid" \
"BRESP:AXI4_S_DDR4_8GB_ARBITER_s0_bresp" \
"BVALID:AXI4_S_DDR4_8GB_ARBITER_s0_bvalid" \
"BREADY:AXI4_S_DDR4_8GB_ARBITER_s0_bready" \
"ARID:AXI4_S_DDR4_8GB_ARBITER_s0_arid" \
"ARADDR:AXI4_S_DDR4_8GB_ARBITER_s0_araddr" \
"ARLEN:AXI4_S_DDR4_8GB_ARBITER_s0_arlen" \
"ARSIZE:AXI4_S_DDR4_8GB_ARBITER_s0_arsize" \
"ARBURST:AXI4_S_DDR4_8GB_ARBITER_s0_arburst" \
"ARVALID:AXI4_S_DDR4_8GB_ARBITER_s0_arvalid" \
"ARREADY:AXI4_S_DDR4_8GB_ARBITER_s0_arready" \
"RID:AXI4_S_DDR4_8GB_ARBITER_s0_rid" \
"RDATA:AXI4_S_DDR4_8GB_ARBITER_s0_rdata" \
"RRESP:AXI4_S_DDR4_8GB_ARBITER_s0_rresp" \
"RLAST:AXI4_S_DDR4_8GB_ARBITER_s0_rlast" \
"RVALID:AXI4_S_DDR4_8GB_ARBITER_s0_rvalid" \
"RREADY:AXI4_S_DDR4_8GB_ARBITER_s0_rready" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_8GB} -port_bif_vlnv {AMBA:AMBA4:AXI4:r0p0_0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"AWID:AXI4_M_DDR4_8GB_m_awid" \
"AWADDR:AXI4_M_DDR4_8GB_m_awaddr" \
"AWLEN:AXI4_M_DDR4_8GB_m_awlen" \
"AWSIZE:AXI4_M_DDR4_8GB_m_awsize" \
"AWBURST:AXI4_M_DDR4_8GB_m_awburst" \
"AWVALID:AXI4_M_DDR4_8GB_m_awvalid" \
"AWREADY:AXI4_M_DDR4_8GB_m_awready" \
"WDATA:AXI4_M_DDR4_8GB_m_wdata" \
"WSTRB:AXI4_M_DDR4_8GB_m_wstrb" \
"WLAST:AXI4_M_DDR4_8GB_m_wlast" \
"WVALID:AXI4_M_DDR4_8GB_m_wvalid" \
"WREADY:AXI4_M_DDR4_8GB_m_wready" \
"BID:AXI4_M_DDR4_8GB_m_bid" \
"BRESP:AXI4_M_DDR4_8GB_m_bresp" \
"BVALID:AXI4_M_DDR4_8GB_m_bvalid" \
"BREADY:AXI4_M_DDR4_8GB_m_bready" \
"ARID:AXI4_M_DDR4_8GB_m_arid" \
"ARADDR:AXI4_M_DDR4_8GB_m_araddr" \
"ARLEN:AXI4_M_DDR4_8GB_m_arlen" \
"ARSIZE:AXI4_M_DDR4_8GB_m_arsize" \
"ARBURST:AXI4_M_DDR4_8GB_m_arburst" \
"ARVALID:AXI4_M_DDR4_8GB_m_arvalid" \
"ARREADY:AXI4_M_DDR4_8GB_m_arready" \
"RID:AXI4_M_DDR4_8GB_m_rid" \
"RDATA:AXI4_M_DDR4_8GB_m_rdata" \
"RRESP:AXI4_M_DDR4_8GB_m_rresp" \
"RLAST:AXI4_M_DDR4_8GB_m_rlast" \
"RVALID:AXI4_M_DDR4_8GB_m_rvalid" \
"RREADY:AXI4_M_DDR4_8GB_m_rready" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {AXI4_S_DDR4_16GB_ARBITER} -port_bif_vlnv {AMBA:AMBA4:AXI4:r0p0_0} -port_bif_role {slave} -port_bif_mapping {\
"AWID:AXI4_S_DDR4_16GB_ARBITER_s0_awid" \
"AWADDR:AXI4_S_DDR4_16GB_ARBITER_s0_awaddr" \
"AWLEN:AXI4_S_DDR4_16GB_ARBITER_s0_awlen" \
"AWSIZE:AXI4_S_DDR4_16GB_ARBITER_s0_awsize" \
"AWBURST:AXI4_S_DDR4_16GB_ARBITER_s0_awburst" \
"AWVALID:AXI4_S_DDR4_16GB_ARBITER_s0_awvalid" \
"AWREADY:AXI4_S_DDR4_16GB_ARBITER_s0_awready" \
"WDATA:AXI4_S_DDR4_16GB_ARBITER_s0_wdata" \
"WSTRB:AXI4_S_DDR4_16GB_ARBITER_s0_wstrb" \
"WLAST:AXI4_S_DDR4_16GB_ARBITER_s0_wlast" \
"WVALID:AXI4_S_DDR4_16GB_ARBITER_s0_wvalid" \
"WREADY:AXI4_S_DDR4_16GB_ARBITER_s0_wready" \
"BID:AXI4_S_DDR4_16GB_ARBITER_s0_bid" \
"BRESP:AXI4_S_DDR4_16GB_ARBITER_s0_bresp" \
"BVALID:AXI4_S_DDR4_16GB_ARBITER_s0_bvalid" \
"BREADY:AXI4_S_DDR4_16GB_ARBITER_s0_bready" \
"ARID:AXI4_S_DDR4_16GB_ARBITER_s0_arid" \
"ARADDR:AXI4_S_DDR4_16GB_ARBITER_s0_araddr" \
"ARLEN:AXI4_S_DDR4_16GB_ARBITER_s0_arlen" \
"ARSIZE:AXI4_S_DDR4_16GB_ARBITER_s0_arsize" \
"ARBURST:AXI4_S_DDR4_16GB_ARBITER_s0_arburst" \
"ARVALID:AXI4_S_DDR4_16GB_ARBITER_s0_arvalid" \
"ARREADY:AXI4_S_DDR4_16GB_ARBITER_s0_arready" \
"RID:AXI4_S_DDR4_16GB_ARBITER_s0_rid" \
"RDATA:AXI4_S_DDR4_16GB_ARBITER_s0_rdata" \
"RRESP:AXI4_S_DDR4_16GB_ARBITER_s0_rresp" \
"RLAST:AXI4_S_DDR4_16GB_ARBITER_s0_rlast" \
"RVALID:AXI4_S_DDR4_16GB_ARBITER_s0_rvalid" \
"RREADY:AXI4_S_DDR4_16GB_ARBITER_s0_rready" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {AXI4_M_DDR4_16GB} -port_bif_vlnv {AMBA:AMBA4:AXI4:r0p0_0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"AWID:AXI4_M_DDR4_16GB_m_awid" \
"AWADDR:AXI4_M_DDR4_16GB_m_awaddr" \
"AWLEN:AXI4_M_DDR4_16GB_m_awlen" \
"AWSIZE:AXI4_M_DDR4_16GB_m_awsize" \
"AWBURST:AXI4_M_DDR4_16GB_m_awburst" \
"AWVALID:AXI4_M_DDR4_16GB_m_awvalid" \
"AWREADY:AXI4_M_DDR4_16GB_m_awready" \
"WDATA:AXI4_M_DDR4_16GB_m_wdata" \
"WSTRB:AXI4_M_DDR4_16GB_m_wstrb" \
"WLAST:AXI4_M_DDR4_16GB_m_wlast" \
"WVALID:AXI4_M_DDR4_16GB_m_wvalid" \
"WREADY:AXI4_M_DDR4_16GB_m_wready" \
"BID:AXI4_M_DDR4_16GB_m_bid" \
"BRESP:AXI4_M_DDR4_16GB_m_bresp" \
"BVALID:AXI4_M_DDR4_16GB_m_bvalid" \
"BREADY:AXI4_M_DDR4_16GB_m_bready" \
"ARID:AXI4_M_DDR4_16GB_m_arid" \
"ARADDR:AXI4_M_DDR4_16GB_m_araddr" \
"ARLEN:AXI4_M_DDR4_16GB_m_arlen" \
"ARSIZE:AXI4_M_DDR4_16GB_m_arsize" \
"ARBURST:AXI4_M_DDR4_16GB_m_arburst" \
"ARVALID:AXI4_M_DDR4_16GB_m_arvalid" \
"ARREADY:AXI4_M_DDR4_16GB_m_arready" \
"RID:AXI4_M_DDR4_16GB_m_rid" \
"RDATA:AXI4_M_DDR4_16GB_m_rdata" \
"RRESP:AXI4_M_DDR4_16GB_m_rresp" \
"RLAST:AXI4_M_DDR4_16GB_m_rlast" \
"RVALID:AXI4_M_DDR4_16GB_m_rvalid" \
"RREADY:AXI4_M_DDR4_16GB_m_rready" } 

# Add axi_read_demux instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {axi_read_demux} -instance_name {axi_read_demux}
# Exporting Parameters of instance axi_read_demux
sd_configure_core_instance -sd_name ${sd_name} -instance_name {axi_read_demux} -params {\
"ADDR_WIDTH:32" \
"DATA_WIDTH:64" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {axi_read_demux}
sd_update_instance -sd_name ${sd_name} -instance_name {axi_read_demux}



# Add axi_read_mux_ddr4_8gb instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {axi_read_mux} -instance_name {axi_read_mux_ddr4_8gb}
# Exporting Parameters of instance axi_read_mux_ddr4_8gb
sd_configure_core_instance -sd_name ${sd_name} -instance_name {axi_read_mux_ddr4_8gb} -params {\
"ADDR_WIDTH:38" \
"DATA_WIDTH:256" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {axi_read_mux_ddr4_8gb}
sd_update_instance -sd_name ${sd_name} -instance_name {axi_read_mux_ddr4_8gb}



# Add axi_read_mux_ddr4_16gb instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {axi_read_mux} -instance_name {axi_read_mux_ddr4_16gb}
# Exporting Parameters of instance axi_read_mux_ddr4_16gb
sd_configure_core_instance -sd_name ${sd_name} -instance_name {axi_read_mux_ddr4_16gb} -params {\
"ADDR_WIDTH:39" \
"DATA_WIDTH:512" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {axi_read_mux_ddr4_16gb}
sd_update_instance -sd_name ${sd_name} -instance_name {axi_read_mux_ddr4_16gb}



# Add eth_pcie_sel_coregpio_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {CoreGPIO_C7} -instance_name {eth_pcie_sel_coregpio_inst}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {eth_pcie_sel_coregpio_inst:GPIO_OUT} -pin_slices {[0:0]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {eth_pcie_sel_coregpio_inst:GPIO_OUT} -pin_slices {[31:1]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {eth_pcie_sel_coregpio_inst:GPIO_OUT[31:1]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {eth_pcie_sel_coregpio_inst:INT}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {eth_pcie_sel_coregpio_inst:GPIO_IN} -value {GND}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {eth_pcie_sel_coregpio_inst:GPIO_OE}



# Add pcie_translator_ddr4_8gb instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {pcie_translator} -instance_name {pcie_translator_ddr4_8gb}
# Exporting Parameters of instance pcie_translator_ddr4_8gb
sd_configure_core_instance -sd_name ${sd_name} -instance_name {pcie_translator_ddr4_8gb} -params {\
"DDR4_ADDR_WIDTH:38" \
"DDR4_DATA_WIDTH:256" \
"PCIE_ADDR_WIDTH:32" \
"PCIE_DATA_WIDTH:64" \
"PCIE_MAX_BURST:32" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {pcie_translator_ddr4_8gb}
sd_update_instance -sd_name ${sd_name} -instance_name {pcie_translator_ddr4_8gb}



# Add pcie_translator_ddr4_16gb instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {pcie_translator} -instance_name {pcie_translator_ddr4_16gb}
# Exporting Parameters of instance pcie_translator_ddr4_16gb
sd_configure_core_instance -sd_name ${sd_name} -instance_name {pcie_translator_ddr4_16gb} -params {\
"DDR4_ADDR_WIDTH:39" \
"DDR4_DATA_WIDTH:512" \
"PCIE_ADDR_WIDTH:32" \
"PCIE_DATA_WIDTH:64" \
"PCIE_MAX_BURST:32" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {pcie_translator_ddr4_16gb}
sd_update_instance -sd_name ${sd_name} -instance_name {pcie_translator_ddr4_16gb}



# Add scalar net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth_pcie_sel_coregpio_inst:PCLK" "pclk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth_pcie_sel_coregpio_inst:PRESETN" "presetn" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth_pcie_sel_coregpio_inst:GPIO_OUT[0:0]" "axi_read_mux_ddr4_8gb:eth_pcie_sel" "axi_read_mux_ddr4_16gb:eth_pcie_sel" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"axi_read_demux:clk" "axi_read_mux_ddr4_8gb:clk" "ddr4_8gb_clk" "pcie_translator_ddr4_16gb:pcie_clk" "pcie_translator_ddr4_8gb:ddr_clk" "pcie_translator_ddr4_8gb:pcie_clk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"axi_read_demux:resetn" "axi_read_mux_ddr4_8gb:resetn" "ddr4_8gb_resetn" "pcie_translator_ddr4_16gb:pcie_resetn" "pcie_translator_ddr4_8gb:ddr_resetn" "pcie_translator_ddr4_8gb:pcie_resetn" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"axi_read_mux_ddr4_16gb:clk" "ddr4_16gb_clk" "pcie_translator_ddr4_16gb:ddr_clk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"axi_read_mux_ddr4_16gb:resetn" "ddr4_16gb_resetn" "pcie_translator_ddr4_16gb:ddr_resetn" }

# Add bus net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"axi_read_demux:ddr4_16gb_index" "pcie_translator_ddr4_16gb:index" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"axi_read_demux:ddr4_8gb_index" "pcie_translator_ddr4_8gb:index" }

# Add bus interface net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"AXI4_M_DDR4_16GB" "axi_read_mux_ddr4_16gb:AXI4_M" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"AXI4_M_DDR4_8GB" "axi_read_mux_ddr4_8gb:AXI4_M" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"AXI4_S_DDR4_16GB_ARBITER" "axi_read_mux_ddr4_16gb:AXI4_S0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"AXI4_S_DDR4_8GB_ARBITER" "axi_read_mux_ddr4_8gb:AXI4_S0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"AXI4_S_PCIE" "axi_read_demux:AXI4_S" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth_pcie_sel_coregpio_inst:APB_bif" "s_apb" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"axi_read_demux:AXI4_M0" "pcie_translator_ddr4_8gb:AXI4_S" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"axi_read_demux:AXI4_M1" "pcie_translator_ddr4_16gb:AXI4_S" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"axi_read_mux_ddr4_16gb:AXI4_S1" "pcie_translator_ddr4_16gb:AXI4_M" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"axi_read_mux_ddr4_8gb:AXI4_S1" "pcie_translator_ddr4_8gb:AXI4_M" }

# Re-enable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 1
# Save the SmartDesign 
save_smartdesign -sd_name ${sd_name}
# Generate SmartDesign "eth_pcie_mux_hier"
generate_component -component_name ${sd_name}
