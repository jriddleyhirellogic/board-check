# Creating SmartDesign "dma_read_ddr4_16gb_hier"
set sd_name {dma_read_ddr4_16gb_hier}
create_smartdesign -sd_name ${sd_name}

# Disable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 0

# Create top level Scalar Ports
sd_create_scalar_port -sd_name ${sd_name} -port_name {M_AXIS_UDP_PYL_SIZE_m_axis_udp_pyl_size_tready} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {M_AXIS_UDP_PYL_m_axis_udp_pyl_tready} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_clk} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_rst_n} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {arb_read_ack} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {arb_read_done} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {arb_read_valid} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {core_busy} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr_16gb_clk} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr_16gb_rst_n} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eof_ack} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pyl_acpt} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ddr4_16gb_reg_penable} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ddr4_16gb_reg_psel} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ddr4_16gb_reg_pwrite} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ctrl_reg_penable} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ctrl_reg_psel} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ctrl_reg_pwrite} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {udp_clk} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {udp_rst_n} -port_direction {IN}

sd_create_scalar_port -sd_name ${sd_name} -port_name {frame_read_done_int} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {M_AXIS_UDP_PYL_SIZE_m_axis_udp_pyl_size_tvalid} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {M_AXIS_UDP_PYL_m_axis_udp_pyl_tlast} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {M_AXIS_UDP_PYL_m_axis_udp_pyl_tvalid} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {arb_read_req} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ddr4_16gb_reg_pready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ddr4_16gb_reg_pslverr} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ctrl_reg_pready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ctrl_reg_pslverr} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sof_req} -port_direction {OUT}


# Create top level Bus Ports
sd_create_bus_port -sd_name ${sd_name} -port_name {arb_data_in} -port_direction {IN} -port_range {[511:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ddr4_16gb_reg_paddr} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ddr4_16gb_reg_pwdata} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ctrl_reg_paddr} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ctrl_reg_pwdata} -port_direction {IN} -port_range {[31:0]}

sd_create_bus_port -sd_name ${sd_name} -port_name {M_AXIS_UDP_PYL_SIZE_m_axis_udp_pyl_size_tdata} -port_direction {OUT} -port_range {[15:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {M_AXIS_UDP_PYL_m_axis_udp_pyl_tdata} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {M_AXIS_UDP_PYL_m_axis_udp_pyl_tkeep} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {arb_read_burst_len} -port_direction {OUT} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {arb_read_start_addr} -port_direction {OUT} -port_range {[38:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ddr4_16gb_reg_prdata} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ctrl_reg_prdata} -port_direction {OUT} -port_range {[31:0]}


# Create top level Bus interface Ports
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

sd_create_bif_port -sd_name ${sd_name} -port_name {s_apb_dma_read_ddr4_16gb_reg} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:s_apb_dma_read_ddr4_16gb_reg_paddr" \
"PSELx:s_apb_dma_read_ddr4_16gb_reg_psel" \
"PENABLE:s_apb_dma_read_ddr4_16gb_reg_penable" \
"PWRITE:s_apb_dma_read_ddr4_16gb_reg_pwrite" \
"PRDATA:s_apb_dma_read_ddr4_16gb_reg_prdata" \
"PWDATA:s_apb_dma_read_ddr4_16gb_reg_pwdata" \
"PREADY:s_apb_dma_read_ddr4_16gb_reg_pready" \
"PSLVERR:s_apb_dma_read_ddr4_16gb_reg_pslverr" } 

# Add dma_read_apb_reg_ddr4_16gb_inst instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {dma_read_apb_reg_ddr4_16gb} -instance_name {dma_read_apb_reg_ddr4_16gb_inst}
# Exporting Parameters of instance dma_read_apb_reg_ddr4_16gb_inst
sd_configure_core_instance -sd_name ${sd_name} -instance_name {dma_read_apb_reg_ddr4_16gb_inst} -params {\
"APB_ADDR_WIDTH:32" \
"APB_DATA_WIDTH:32" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {dma_read_apb_reg_ddr4_16gb_inst}
sd_update_instance -sd_name ${sd_name} -instance_name {dma_read_apb_reg_ddr4_16gb_inst}
sd_create_pin_group -sd_name ${sd_name} -group_name {DMA_READ_INTF} -instance_name {dma_read_apb_reg_ddr4_16gb_inst} -pin_names {"clear" "dma_timeout_err" }



# Add dma_read_ddr4_16gb_inst instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {dma_read_ddr4_16gb} -instance_name {dma_read_ddr4_16gb_inst}
# Exporting Parameters of instance dma_read_ddr4_16gb_inst
sd_configure_core_instance -sd_name ${sd_name} -instance_name {dma_read_ddr4_16gb_inst} -params {\
"DATA_OUT_WIDTH:32" \
"DDR4_CLOCK_FREQ_MHZ:150" \
"DDR_ADDR_WIDTH:39" \
"DDR_DATA_WIDTH:512" \
"TIMEOUT_USEC:10000" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {dma_read_ddr4_16gb_inst}
sd_update_instance -sd_name ${sd_name} -instance_name {dma_read_ddr4_16gb_inst}
sd_create_pin_group -sd_name ${sd_name} -group_name {ARB_INTF} -instance_name {dma_read_ddr4_16gb_inst} -pin_names {"arb_read_start_addr" "arb_read_ack" "arb_read_done" "arb_read_valid" "arb_data_in" "arb_read_req" "arb_read_burst_len" }
sd_create_pin_group -sd_name ${sd_name} -group_name {DMA_INTF} -instance_name {dma_read_ddr4_16gb_inst} -pin_names {"dma_ready" "dma_read_req" "dma_read_ack" "dma_fifo_clear" }
sd_create_pin_group -sd_name ${sd_name} -group_name {CTRL_INTF} -instance_name {dma_read_ddr4_16gb_inst} -pin_names {"ctrl_info_valid" "ctrl_read_addr" "ctrl_burst_count" }
sd_create_pin_group -sd_name ${sd_name} -group_name {APB_INTF} -instance_name {dma_read_ddr4_16gb_inst} -pin_names {"clear" "timeout_err" }



# Add dma_read_ctrl_apb_reg_ddr4_16gb_inst instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {dma_read_ctrl_apb_reg_ddr4_16gb} -instance_name {dma_read_ctrl_apb_reg_ddr4_16gb_inst}
# Exporting Parameters of instance dma_read_ctrl_apb_reg_ddr4_16gb_inst
sd_configure_core_instance -sd_name ${sd_name} -instance_name {dma_read_ctrl_apb_reg_ddr4_16gb_inst} -params {\
"APB_ADDR_WIDTH:32" \
"APB_DATA_WIDTH:32" \
"FRAME_INDEX_WIDTH:9" \
"METADATA_WIDTH:640" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {dma_read_ctrl_apb_reg_ddr4_16gb_inst}
sd_update_instance -sd_name ${sd_name} -instance_name {dma_read_ctrl_apb_reg_ddr4_16gb_inst}
sd_create_pin_group -sd_name ${sd_name} -group_name {DMA_CTRL_INTF} -instance_name {dma_read_ctrl_apb_reg_ddr4_16gb_inst} -pin_names {"clear" "frame_index" "frame_read_done_int" "frame_read_done" "frame_read_req" "h_size_beat" "h_size_byte" "jumbo_en" "v_size_line" "udp_metadata_sel" }
sd_create_pin_group -sd_name ${sd_name} -group_name {APB_REG_ERR_INTF} -instance_name {dma_read_ctrl_apb_reg_ddr4_16gb_inst} -pin_names {"frame_xfer_timeout_err" "send_pyl_err" "sof_req_err" "pyl_acpt_err" "send_last_err" "wait_ack_err" "dma_timeout_err" }
sd_create_pin_group -sd_name ${sd_name} -group_name {METADATA_INTF} -instance_name {dma_read_ctrl_apb_reg_ddr4_16gb_inst} -pin_names {"metadata_data" "metadata_valid" }
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {dma_read_ctrl_apb_reg_ddr4_16gb_inst:frame_xfer_timeout_err} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {dma_read_ctrl_apb_reg_ddr4_16gb_inst:dma_timeout_err} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {dma_read_ctrl_apb_reg_ddr4_16gb_inst:pyl_acpt_err} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {dma_read_ctrl_apb_reg_ddr4_16gb_inst:send_last_err} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {dma_read_ctrl_apb_reg_ddr4_16gb_inst:send_pyl_err} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {dma_read_ctrl_apb_reg_ddr4_16gb_inst:sof_req_err} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {dma_read_ctrl_apb_reg_ddr4_16gb_inst:wait_ack_err} -value {GND}



# Add dma_read_ctrl_ddr4_16gb_inst instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {dma_read_ctrl_ddr4_16gb} -instance_name {dma_read_ctrl_ddr4_16gb_inst}
# Exporting Parameters of instance dma_read_ctrl_ddr4_16gb_inst
sd_configure_core_instance -sd_name ${sd_name} -instance_name {dma_read_ctrl_ddr4_16gb_inst} -params {\
"CLOCK_FREQ_MHZ:100" \
"DDR_ADDR_WIDTH:39" \
"DDR_DATA_WIDTH:512" \
"FRAME_INDEX_WIDTH:9" \
"METADATA_WIDTH:640" \
"FRAME_WIDTH:25" \
"TIMEOUT_USEC:10000" \
"USABLE_ADDR_WIDTH:34" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {dma_read_ctrl_ddr4_16gb_inst}
sd_update_instance -sd_name ${sd_name} -instance_name {dma_read_ctrl_ddr4_16gb_inst}
sd_create_pin_group -sd_name ${sd_name} -group_name {APB_REG_INTF} -instance_name {dma_read_ctrl_ddr4_16gb_inst} -pin_names {"clear" "frame_read_req" "frame_read_done" "h_size_beat" "h_size_byte" "v_size_line" "frame_index" "jumbo_en" "udp_metadata_sel" }
sd_create_pin_group -sd_name ${sd_name} -group_name {DMA_RD_INTF} -instance_name {dma_read_ctrl_ddr4_16gb_inst} -pin_names {"dma_fifo_clear" "dma_read_ack" "dma_read_req" "dma_ready" }
sd_create_pin_group -sd_name ${sd_name} -group_name {CTRL_INTF} -instance_name {dma_read_ctrl_ddr4_16gb_inst} -pin_names {"ctrl_burst_count" "ctrl_info_valid" "ctrl_read_addr" }
sd_create_pin_group -sd_name ${sd_name} -group_name {UDP_IP_CTRL_INTF} -instance_name {dma_read_ctrl_ddr4_16gb_inst} -pin_names {"sof_req" "eof_ack" "pyl_acpt" "core_busy" }
sd_create_pin_group -sd_name ${sd_name} -group_name {APB_REG_ERR_INTF} -instance_name {dma_read_ctrl_ddr4_16gb_inst} -pin_names {"sof_req_err" "pyl_acpt_err" "send_pyl_err" "send_last_err" "wait_ack_err" "dma_timeout_err" "frame_xfer_timeout_err" }
sd_create_pin_group -sd_name ${sd_name} -group_name {METADATA_INTF} -instance_name {dma_read_ctrl_ddr4_16gb_inst} -pin_names {"metadata_data" "metadata_valid" }
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dma_read_ctrl_ddr4_16gb_inst:frame_xfer_timeout_err}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dma_read_ctrl_ddr4_16gb_inst:sof_req_err}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dma_read_ctrl_ddr4_16gb_inst:pyl_acpt_err}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dma_read_ctrl_ddr4_16gb_inst:send_pyl_err}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dma_read_ctrl_ddr4_16gb_inst:send_last_err}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dma_read_ctrl_ddr4_16gb_inst:wait_ack_err}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dma_read_ctrl_ddr4_16gb_inst:dma_timeout_err}



# Add scalar net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb_clk" "dma_read_apb_reg_ddr4_16gb_inst:pclk" "dma_read_ctrl_apb_reg_ddr4_16gb_inst:pclk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb_rst_n" "dma_read_apb_reg_ddr4_16gb_inst:presetn" "dma_read_ctrl_apb_reg_ddr4_16gb_inst:presetn" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"arb_read_ack" "dma_read_ddr4_16gb_inst:arb_read_ack" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"arb_read_done" "dma_read_ddr4_16gb_inst:arb_read_done" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"arb_read_req" "dma_read_ddr4_16gb_inst:arb_read_req" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"arb_read_valid" "dma_read_ddr4_16gb_inst:arb_read_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"core_busy" "dma_read_ctrl_ddr4_16gb_inst:core_busy" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr_16gb_clk" "dma_read_ddr4_16gb_inst:ddr_clk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr_16gb_rst_n" "dma_read_ddr4_16gb_inst:ddr_rst_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_apb_reg_ddr4_16gb_inst:clear" "dma_read_ddr4_16gb_inst:clear" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ddr4_16gb_inst:ctrl_clk" "udp_clk" "dma_read_ctrl_ddr4_16gb_inst:udp_clk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ddr4_16gb_inst:ctrl_info_valid" "dma_read_ctrl_ddr4_16gb_inst:ctrl_info_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ddr4_16gb_inst:ctrl_rst_n" "dma_read_ctrl_ddr4_16gb_inst:udp_rst_n" "udp_rst_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ddr4_16gb_inst:dma_fifo_clear" "dma_read_ctrl_ddr4_16gb_inst:dma_fifo_clear" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ddr4_16gb_inst:dma_read_ack" "dma_read_ctrl_ddr4_16gb_inst:dma_read_ack" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ddr4_16gb_inst:dma_read_req" "dma_read_ctrl_ddr4_16gb_inst:dma_read_req" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ddr4_16gb_inst:dma_ready" "dma_read_ctrl_ddr4_16gb_inst:dma_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eof_ack" "dma_read_ctrl_ddr4_16gb_inst:eof_ack" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pyl_acpt" "dma_read_ctrl_ddr4_16gb_inst:pyl_acpt" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"sof_req" "dma_read_ctrl_ddr4_16gb_inst:sof_req" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ctrl_apb_reg_ddr4_16gb_inst:clear" "dma_read_ctrl_ddr4_16gb_inst:clear" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ctrl_apb_reg_ddr4_16gb_inst:frame_read_done" "dma_read_ctrl_ddr4_16gb_inst:frame_read_done" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ctrl_apb_reg_ddr4_16gb_inst:frame_read_req" "dma_read_ctrl_ddr4_16gb_inst:frame_read_req" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ctrl_apb_reg_ddr4_16gb_inst:frame_read_done_int" "frame_read_done_int" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ctrl_apb_reg_ddr4_16gb_inst:jumbo_en" "dma_read_ctrl_ddr4_16gb_inst:jumbo_en" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ctrl_apb_reg_ddr4_16gb_inst:metadata_valid" "dma_read_ctrl_ddr4_16gb_inst:metadata_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ctrl_apb_reg_ddr4_16gb_inst:udp_metadata_sel" "dma_read_ctrl_ddr4_16gb_inst:udp_metadata_sel" }

# Add bus net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"arb_data_in" "dma_read_ddr4_16gb_inst:arb_data_in" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"arb_read_burst_len" "dma_read_ddr4_16gb_inst:arb_read_burst_len" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"arb_read_start_addr" "dma_read_ddr4_16gb_inst:arb_read_start_addr" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_apb_reg_ddr4_16gb_inst:dma_timeout_err" "dma_read_ddr4_16gb_inst:timeout_err" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ddr4_16gb_inst:ctrl_burst_count" "dma_read_ctrl_ddr4_16gb_inst:ctrl_burst_count" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ddr4_16gb_inst:ctrl_read_addr" "dma_read_ctrl_ddr4_16gb_inst:ctrl_read_addr" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ctrl_apb_reg_ddr4_16gb_inst:frame_index" "dma_read_ctrl_ddr4_16gb_inst:frame_index" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ctrl_apb_reg_ddr4_16gb_inst:h_size_beat" "dma_read_ctrl_ddr4_16gb_inst:h_size_beat" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ctrl_apb_reg_ddr4_16gb_inst:h_size_byte" "dma_read_ctrl_ddr4_16gb_inst:h_size_byte" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ctrl_apb_reg_ddr4_16gb_inst:metadata_data" "dma_read_ctrl_ddr4_16gb_inst:metadata_data" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ctrl_apb_reg_ddr4_16gb_inst:v_size_line" "dma_read_ctrl_ddr4_16gb_inst:v_size_line" }

# Add bus interface net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"M_AXIS_UDP_PYL" "dma_read_ctrl_ddr4_16gb_inst:M_AXIS_UDP_PYL" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"M_AXIS_UDP_PYL_SIZE" "dma_read_ctrl_ddr4_16gb_inst:M_AXIS_UDP_PYL_SIZE" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_apb_reg_ddr4_16gb_inst:s_apb" "s_apb_dma_read_ddr4_16gb_reg" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_read_ddr4_16gb_inst:M_AXIS_DMA_FIFO" "dma_read_ctrl_ddr4_16gb_inst:S_AXIS_DMA_FIFO" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"s_apb_dma_read_ctrl_reg" "dma_read_ctrl_apb_reg_ddr4_16gb_inst:s_apb" }

# Re-enable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 1
# Save the SmartDesign 
save_smartdesign -sd_name ${sd_name}
# Generate SmartDesign "dma_read_ddr4_16gb_hier"
generate_component -component_name ${sd_name}
