# Creating SmartDesign "ddr4_8gb_group_hier"
set sd_name {ddr4_8gb_group_hier}
create_smartdesign -sd_name ${sd_name}

# Disable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 0

# Create top level Scalar Ports
sd_create_scalar_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_arready} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_awready} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_bvalid} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_rlast} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_rvalid} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_wready} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_ARVALID} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_AWVALID} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_BREADY} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_RREADY} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_WLAST} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_WVALID} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {M_AXIS_UDP_PYL_SIZE_m_axis_udp_pyl_size_tready} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {M_AXIS_UDP_PYL_m_axis_udp_pyl_tready} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_clk} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_rst_n} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_frame_valid} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_line_valid} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {core_busy} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr_8gb_rst_n} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eof_ack} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pixel_clk} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pixel_rst_n} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pyl_acpt} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ddr4_8gb_reg_penable} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ddr4_8gb_reg_psel} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ddr4_8gb_reg_pwrite} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_penable} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_psel} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_pwrite} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ctrl_reg_penable} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ctrl_reg_psel} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ctrl_reg_pwrite} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sys_rst_n} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {udp_clk} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {udp_rst_n} -port_direction {IN}

sd_create_scalar_port -sd_name ${sd_name} -port_name {ACT_N} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {CAS_N} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {CK0_N} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {CK0} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {CKE} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {CS_N} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_arvalid} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_awvalid} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_bready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_rready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_wlast} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_wvalid} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_ARREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_AWREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_BVALID} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_RLAST} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_RVALID} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_WREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {M_AXIS_UDP_PYL_SIZE_m_axis_udp_pyl_size_tvalid} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {M_AXIS_UDP_PYL_m_axis_udp_pyl_tlast} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {M_AXIS_UDP_PYL_m_axis_udp_pyl_tvalid} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ODT} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {RAS_N} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {RESET_N} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SHIELD0} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SHIELD1} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SHIELD2} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SHIELD3} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SHIELD4} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {WE_N} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {arb_read_req} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {arb_write_req} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {arb_write_valid} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_clk} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_ctrlr_ready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_pll_lock} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_frame_read_done_int} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {r0_ack_o} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {r0_data_valid_o} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {r0_done_o} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ddr4_8gb_reg_pready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ddr4_8gb_reg_pslverr} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_pready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_pslverr} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ctrl_reg_pready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ctrl_reg_pslverr} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sof_req} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {w0_ack_o} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {w0_done_o} -port_direction {OUT}


# Create top level Bus Ports
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_bid} -port_direction {IN} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_bresp} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_rdata} -port_direction {IN} -port_range {[255:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_rid} -port_direction {IN} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_rresp} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_ARADDR} -port_direction {IN} -port_range {[37:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_ARBURST} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_ARID} -port_direction {IN} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_ARLEN} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_ARSIZE} -port_direction {IN} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_AWADDR} -port_direction {IN} -port_range {[37:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_AWBURST} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_AWID} -port_direction {IN} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_AWLEN} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_AWSIZE} -port_direction {IN} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_WDATA} -port_direction {IN} -port_range {[255:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_WSTRB} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {cam_data_in} -port_direction {IN} -port_range {[383:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ddr4_8gb_reg_paddr} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ddr4_8gb_reg_pwdata} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {s_apb_paddr} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {s_apb_pwdata} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ctrl_reg_paddr} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ctrl_reg_pwdata} -port_direction {IN} -port_range {[31:0]}

sd_create_bus_port -sd_name ${sd_name} -port_name {A} -port_direction {OUT} -port_range {[13:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {BA} -port_direction {OUT} -port_range {[1:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {BG} -port_direction {OUT} -port_range {[1:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_araddr} -port_direction {OUT} -port_range {[37:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_arburst} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_arcache} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_arid} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_arlen} -port_direction {OUT} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_arlock} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_arprot} -port_direction {OUT} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_arsize} -port_direction {OUT} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_awaddr} -port_direction {OUT} -port_range {[37:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_awburst} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_awcache} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_awid} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_awlen} -port_direction {OUT} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_awlock} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_awprot} -port_direction {OUT} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_awsize} -port_direction {OUT} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_wdata} -port_direction {OUT} -port_range {[255:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER_wstrb} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_BID} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_BRESP} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_RDATA} -port_direction {OUT} -port_range {[255:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_RID} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM_RRESP} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {DM_N} -port_direction {OUT} -port_range {[4:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {M_AXIS_UDP_PYL_SIZE_m_axis_udp_pyl_size_tdata} -port_direction {OUT} -port_range {[15:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {M_AXIS_UDP_PYL_m_axis_udp_pyl_tdata} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {M_AXIS_UDP_PYL_m_axis_udp_pyl_tkeep} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_8gb_wr_frame_index} -port_direction {OUT} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ddr4_8gb_reg_prdata} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {s_apb_prdata} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ctrl_reg_prdata} -port_direction {OUT} -port_range {[31:0]}

sd_create_bus_port -sd_name ${sd_name} -port_name {DQS_N} -port_direction {INOUT} -port_range {[4:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {DQS} -port_direction {INOUT} -port_range {[4:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {DQ} -port_direction {INOUT} -port_range {[39:0]} -port_is_pad {1}

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

sd_create_bif_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ctrl_reg} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:s_apb_dma_read_ctrl_reg_paddr" \
"PSELx:s_apb_dma_read_ctrl_reg_psel" \
"PENABLE:s_apb_dma_read_ctrl_reg_penable" \
"PWRITE:s_apb_dma_read_ctrl_reg_pwrite" \
"PRDATA:s_apb_dma_read_ctrl_reg_prdata" \
"PWDATA:s_apb_dma_read_ctrl_reg_pwdata" \
"PREADY:s_apb_dma_read_ctrl_reg_pready" \
"PSLVERR:s_apb_dma_read_ctrl_reg_pslverr" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {M_AXIS_UDP_PYL_SIZE} -port_bif_vlnv {AMBA:AMBA4:AXI4Stream:r0p0_1} -port_bif_role {master} -port_bif_mapping {\
"TVALID:M_AXIS_UDP_PYL_SIZE_m_axis_udp_pyl_size_tvalid" \
"TREADY:M_AXIS_UDP_PYL_SIZE_m_axis_udp_pyl_size_tready" \
"TDATA:M_AXIS_UDP_PYL_SIZE_m_axis_udp_pyl_size_tdata" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {M_AXIS_UDP_PYL} -port_bif_vlnv {AMBA:AMBA4:AXI4Stream:r0p0_1} -port_bif_role {master} -port_bif_mapping {\
"TVALID:M_AXIS_UDP_PYL_m_axis_udp_pyl_tvalid" \
"TREADY:M_AXIS_UDP_PYL_m_axis_udp_pyl_tready" \
"TDATA:M_AXIS_UDP_PYL_m_axis_udp_pyl_tdata" \
"TKEEP:M_AXIS_UDP_PYL_m_axis_udp_pyl_tkeep" \
"TLAST:M_AXIS_UDP_PYL_m_axis_udp_pyl_tlast" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ddr4_8gb_reg} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:s_apb_dma_read_ddr4_8gb_reg_paddr" \
"PSELx:s_apb_dma_read_ddr4_8gb_reg_psel" \
"PENABLE:s_apb_dma_read_ddr4_8gb_reg_penable" \
"PWRITE:s_apb_dma_read_ddr4_8gb_reg_pwrite" \
"PRDATA:s_apb_dma_read_ddr4_8gb_reg_prdata" \
"PWDATA:s_apb_dma_read_ddr4_8gb_reg_pwdata" \
"PREADY:s_apb_dma_read_ddr4_8gb_reg_pready" \
"PSLVERR:s_apb_dma_read_ddr4_8gb_reg_pslverr" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {DDR4_8GB_ARBITER} -port_bif_vlnv {AMBA:AMBA4:AXI4:r0p0_0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"AWID:DDR4_8GB_ARBITER_awid" \
"AWADDR:DDR4_8GB_ARBITER_awaddr" \
"AWLEN:DDR4_8GB_ARBITER_awlen" \
"AWSIZE:DDR4_8GB_ARBITER_awsize" \
"AWBURST:DDR4_8GB_ARBITER_awburst" \
"AWLOCK:DDR4_8GB_ARBITER_awlock" \
"AWCACHE:DDR4_8GB_ARBITER_awcache" \
"AWPROT:DDR4_8GB_ARBITER_awprot" \
"AWVALID:DDR4_8GB_ARBITER_awvalid" \
"AWREADY:DDR4_8GB_ARBITER_awready" \
"WDATA:DDR4_8GB_ARBITER_wdata" \
"WSTRB:DDR4_8GB_ARBITER_wstrb" \
"WLAST:DDR4_8GB_ARBITER_wlast" \
"WVALID:DDR4_8GB_ARBITER_wvalid" \
"WREADY:DDR4_8GB_ARBITER_wready" \
"BID:DDR4_8GB_ARBITER_bid" \
"BRESP:DDR4_8GB_ARBITER_bresp" \
"BVALID:DDR4_8GB_ARBITER_bvalid" \
"BREADY:DDR4_8GB_ARBITER_bready" \
"ARID:DDR4_8GB_ARBITER_arid" \
"ARADDR:DDR4_8GB_ARBITER_araddr" \
"ARLEN:DDR4_8GB_ARBITER_arlen" \
"ARSIZE:DDR4_8GB_ARBITER_arsize" \
"ARBURST:DDR4_8GB_ARBITER_arburst" \
"ARLOCK:DDR4_8GB_ARBITER_arlock" \
"ARCACHE:DDR4_8GB_ARBITER_arcache" \
"ARPROT:DDR4_8GB_ARBITER_arprot" \
"ARVALID:DDR4_8GB_ARBITER_arvalid" \
"ARREADY:DDR4_8GB_ARBITER_arready" \
"RID:DDR4_8GB_ARBITER_rid" \
"RDATA:DDR4_8GB_ARBITER_rdata" \
"RRESP:DDR4_8GB_ARBITER_rresp" \
"RLAST:DDR4_8GB_ARBITER_rlast" \
"RVALID:DDR4_8GB_ARBITER_rvalid" \
"RREADY:DDR4_8GB_ARBITER_rready" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {DDR4_8GB_S_AXIMM} -port_bif_vlnv {AMBA:AMBA4:AXI4:r0p0_0} -port_bif_role {slave} -port_bif_mapping {\
"AWID:DDR4_8GB_S_AXIMM_AWID" \
"AWADDR:DDR4_8GB_S_AXIMM_AWADDR" \
"AWLEN:DDR4_8GB_S_AXIMM_AWLEN" \
"AWSIZE:DDR4_8GB_S_AXIMM_AWSIZE" \
"AWBURST:DDR4_8GB_S_AXIMM_AWBURST" \
"AWVALID:DDR4_8GB_S_AXIMM_AWVALID" \
"AWREADY:DDR4_8GB_S_AXIMM_AWREADY" \
"WDATA:DDR4_8GB_S_AXIMM_WDATA" \
"WSTRB:DDR4_8GB_S_AXIMM_WSTRB" \
"WLAST:DDR4_8GB_S_AXIMM_WLAST" \
"WVALID:DDR4_8GB_S_AXIMM_WVALID" \
"WREADY:DDR4_8GB_S_AXIMM_WREADY" \
"BID:DDR4_8GB_S_AXIMM_BID" \
"BRESP:DDR4_8GB_S_AXIMM_BRESP" \
"BVALID:DDR4_8GB_S_AXIMM_BVALID" \
"BREADY:DDR4_8GB_S_AXIMM_BREADY" \
"ARID:DDR4_8GB_S_AXIMM_ARID" \
"ARADDR:DDR4_8GB_S_AXIMM_ARADDR" \
"ARLEN:DDR4_8GB_S_AXIMM_ARLEN" \
"ARSIZE:DDR4_8GB_S_AXIMM_ARSIZE" \
"ARBURST:DDR4_8GB_S_AXIMM_ARBURST" \
"ARVALID:DDR4_8GB_S_AXIMM_ARVALID" \
"ARREADY:DDR4_8GB_S_AXIMM_ARREADY" \
"RID:DDR4_8GB_S_AXIMM_RID" \
"RDATA:DDR4_8GB_S_AXIMM_RDATA" \
"RRESP:DDR4_8GB_S_AXIMM_RRESP" \
"RLAST:DDR4_8GB_S_AXIMM_RLAST" \
"RVALID:DDR4_8GB_S_AXIMM_RVALID" \
"RREADY:DDR4_8GB_S_AXIMM_RREADY" } 

# Add ddr4_8gb_arbiter_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {DDR4_8GB_AXI4_ARBITER_PF} -instance_name {ddr4_8gb_arbiter_inst}
sd_create_pin_group -sd_name ${sd_name} -group_name {READ_CHANNEL} -instance_name {ddr4_8gb_arbiter_inst} -pin_names {"rdata_o" "r0_ack_o" "r0_data_valid_o" "r0_done_o" "r0_req_i" "r0_burst_size_i" "r0_rstart_addr_i" }
sd_create_pin_group -sd_name ${sd_name} -group_name {WRITE_CHANNEL} -instance_name {ddr4_8gb_arbiter_inst} -pin_names {"w0_ack_o" "w0_data_valid_i" "w0_req_i" "w0_burst_size_i" "w0_data_i" "w0_wstart_addr_i" "w0_done_o" }



# Add ddr4_8gb_hier_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {ddr4_8gb_hier} -instance_name {ddr4_8gb_hier_inst}



# Add dma_read_ddr4_8gb_hier_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {dma_read_ddr4_8gb_hier} -instance_name {dma_read_ddr4_8gb_hier_inst}
sd_create_pin_group -sd_name ${sd_name} -group_name {ARB_INTF} -instance_name {dma_read_ddr4_8gb_hier_inst} -pin_names {"arb_read_start_addr" "arb_read_ack" "arb_read_done" "arb_read_req" "arb_read_burst_len" "arb_read_valid" "arb_data_in" }
sd_create_pin_group -sd_name ${sd_name} -group_name {UDP_INTF} -instance_name {dma_read_ddr4_8gb_hier_inst} -pin_names {"core_busy" "eof_ack" "pyl_acpt" "sof_req" "frame_read_done_int" }



# Add dma_write_ddr4_8gb_hier_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {dma_write_ddr4_8gb_hier} -instance_name {dma_write_ddr4_8gb_hier_inst}
sd_create_pin_group -sd_name ${sd_name} -group_name {ARB_INTF} -instance_name {dma_write_ddr4_8gb_hier_inst} -pin_names {"arb_write_start_addr" "arb_write_ack" "arb_write_done" "arb_write_req" "arb_write_valid" "arb_write_burst_len" "arb_write_data" }
sd_create_pin_group -sd_name ${sd_name} -group_name {CAM_INTF} -instance_name {dma_write_ddr4_8gb_hier_inst} -pin_names {"cam_data_in" "cam_frame_valid" "cam_line_valid" }
sd_create_pin_group -sd_name ${sd_name} -group_name {FRAME_INDEX} -instance_name {dma_write_ddr4_8gb_hier_inst} -pin_names {"ddr4_8gb_wr_frame_index" }



# Add scalar net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"ACT_N" "ddr4_8gb_hier_inst:ACT_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CAS_N" "ddr4_8gb_hier_inst:CAS_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CK0" "ddr4_8gb_hier_inst:CK0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CK0_N" "ddr4_8gb_hier_inst:CK0_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CKE" "ddr4_8gb_hier_inst:CKE" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CS_N" "ddr4_8gb_hier_inst:CS_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ODT" "ddr4_8gb_hier_inst:ODT" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"RAS_N" "ddr4_8gb_hier_inst:RAS_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"RESET_N" "ddr4_8gb_hier_inst:RESET_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"SHIELD0" "ddr4_8gb_hier_inst:SHIELD0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"SHIELD1" "ddr4_8gb_hier_inst:SHIELD1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"SHIELD2" "ddr4_8gb_hier_inst:SHIELD2" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"SHIELD3" "ddr4_8gb_hier_inst:SHIELD3" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"SHIELD4" "ddr4_8gb_hier_inst:SHIELD4" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"WE_N" "ddr4_8gb_hier_inst:WE_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb_clk" "ddr4_8gb_hier_inst:pll_ref_clk_50mhz" "dma_read_ddr4_8gb_hier_inst:apb_clk" "dma_write_ddr4_8gb_hier_inst:pclk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb_rst_n" "dma_read_ddr4_8gb_hier_inst:apb_rst_n" "dma_write_ddr4_8gb_hier_inst:presetn" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"arb_read_req" "ddr4_8gb_arbiter_inst:r0_req_i" "dma_read_ddr4_8gb_hier_inst:arb_read_req" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"arb_write_req" "ddr4_8gb_arbiter_inst:w0_req_i" "dma_write_ddr4_8gb_hier_inst:arb_write_req" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"arb_write_valid" "ddr4_8gb_arbiter_inst:w0_data_valid_i" "dma_write_ddr4_8gb_hier_inst:arb_write_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_frame_valid" "dma_write_ddr4_8gb_hier_inst:cam_frame_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_line_valid" "dma_write_ddr4_8gb_hier_inst:cam_line_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"core_busy" "dma_read_ddr4_8gb_hier_inst:core_busy" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_arbiter_inst:ddr_ctrl_ready_i" "ddr4_8gb_ctrlr_ready" "ddr4_8gb_hier_inst:ddr4_8gb_ctrlr_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_arbiter_inst:r0_ack_o" "dma_read_ddr4_8gb_hier_inst:arb_read_ack" "r0_ack_o" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_arbiter_inst:r0_data_valid_o" "dma_read_ddr4_8gb_hier_inst:arb_read_valid" "r0_data_valid_o" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_arbiter_inst:r0_done_o" "dma_read_ddr4_8gb_hier_inst:arb_read_done" "r0_done_o" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_arbiter_inst:reset_i" "ddr4_8gb_hier_inst:ddr4_8gb_rst_n" "ddr_8gb_rst_n" "dma_read_ddr4_8gb_hier_inst:ddr_8gb_rst_n" "dma_write_ddr4_8gb_hier_inst:ddr4_8gb_rst_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_arbiter_inst:sys_clk_i" "ddr4_8gb_clk" "ddr4_8gb_hier_inst:ddr4_8gb_clk" "dma_read_ddr4_8gb_hier_inst:ddr_8gb_clk" "dma_write_ddr4_8gb_hier_inst:ddr4_8gb_clk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_arbiter_inst:w0_ack_o" "dma_write_ddr4_8gb_hier_inst:arb_write_ack" "w0_ack_o" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_arbiter_inst:w0_done_o" "dma_write_ddr4_8gb_hier_inst:arb_write_done" "w0_done_o" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_frame_read_done_int" "dma_read_ddr4_8gb_hier_inst:frame_read_done_int" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_hier_inst:ddr4_8gb_pll_lock" "ddr4_8gb_pll_lock" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_hier_inst:sys_rst_n" "sys_rst_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ddr4_8gb_hier_inst:eof_ack" "eof_ack" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ddr4_8gb_hier_inst:pyl_acpt" "pyl_acpt" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ddr4_8gb_hier_inst:sof_req" "sof_req" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ddr4_8gb_hier_inst:udp_clk" "udp_clk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ddr4_8gb_hier_inst:udp_rst_n" "udp_rst_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_write_ddr4_8gb_hier_inst:pixel_clk" "pixel_clk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_write_ddr4_8gb_hier_inst:pixel_rst_n" "pixel_rst_n" }

# Add bus net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"A" "ddr4_8gb_hier_inst:A" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BA" "ddr4_8gb_hier_inst:BA" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BG" "ddr4_8gb_hier_inst:BG" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"DM_N" "ddr4_8gb_hier_inst:DM_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"DQ" "ddr4_8gb_hier_inst:DQ" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"DQS" "ddr4_8gb_hier_inst:DQS" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"DQS_N" "ddr4_8gb_hier_inst:DQS_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_data_in" "dma_write_ddr4_8gb_hier_inst:cam_data_in" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_arbiter_inst:r0_burst_size_i" "dma_read_ddr4_8gb_hier_inst:arb_read_burst_len" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_arbiter_inst:r0_rstart_addr_i" "dma_read_ddr4_8gb_hier_inst:arb_read_start_addr" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_arbiter_inst:rdata_o" "dma_read_ddr4_8gb_hier_inst:arb_data_in" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_arbiter_inst:w0_burst_size_i" "dma_write_ddr4_8gb_hier_inst:arb_write_burst_len" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_arbiter_inst:w0_data_i" "dma_write_ddr4_8gb_hier_inst:arb_write_data" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_arbiter_inst:w0_wstart_addr_i" "dma_write_ddr4_8gb_hier_inst:arb_write_start_addr" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_wr_frame_index" "dma_write_ddr4_8gb_hier_inst:ddr4_8gb_wr_frame_index" }

# Add bus interface net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"DDR4_8GB_ARBITER" "ddr4_8gb_arbiter_inst:MIRRORED_SLAVE_AXI4" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"DDR4_8GB_S_AXIMM" "ddr4_8gb_hier_inst:ddr4_8gb_s_aximm" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"M_AXIS_UDP_PYL" "dma_read_ddr4_8gb_hier_inst:M_AXIS_UDP_PYL" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"M_AXIS_UDP_PYL_SIZE" "dma_read_ddr4_8gb_hier_inst:M_AXIS_UDP_PYL_SIZE" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ddr4_8gb_hier_inst:s_apb_dma_read_ddr4_8gb_reg" "s_apb_dma_read_ddr4_8gb_reg" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ddr4_8gb_hier_inst:s_apb_dma_read_ctrl_reg" "s_apb_dma_read_ctrl_reg" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_write_ddr4_8gb_hier_inst:s_apb" "s_apb" }

# Re-enable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 1
# Save the SmartDesign 
save_smartdesign -sd_name ${sd_name}
# Generate SmartDesign "ddr4_8gb_group_hier"
generate_component -component_name ${sd_name}
