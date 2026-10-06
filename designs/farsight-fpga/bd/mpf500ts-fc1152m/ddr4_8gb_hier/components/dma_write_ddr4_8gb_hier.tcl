# Creating SmartDesign "dma_write_ddr4_8gb_hier"
set sd_name {dma_write_ddr4_8gb_hier}
create_smartdesign -sd_name ${sd_name}

# Disable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 0

# Create top level Scalar Ports
sd_create_scalar_port -sd_name ${sd_name} -port_name {arb_write_ack} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {arb_write_done} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_frame_valid} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_line_valid} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_clk} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_rst_n} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pclk} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pixel_clk} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pixel_rst_n} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {presetn} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_penable} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_psel} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_pwrite} -port_direction {IN}

sd_create_scalar_port -sd_name ${sd_name} -port_name {arb_write_req} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {arb_write_valid} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_pready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {s_apb_pslverr} -port_direction {OUT}


# Create top level Bus Ports
sd_create_bus_port -sd_name ${sd_name} -port_name {cam_data_in} -port_direction {IN} -port_range {[383:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {s_apb_paddr} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {s_apb_pwdata} -port_direction {IN} -port_range {[31:0]}

sd_create_bus_port -sd_name ${sd_name} -port_name {arb_write_burst_len} -port_direction {OUT} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {arb_write_data} -port_direction {OUT} -port_range {[255:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {arb_write_start_addr} -port_direction {OUT} -port_range {[37:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_8gb_wr_frame_index} -port_direction {OUT} -port_range {[7:0]}
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

# Add dma_write_apb_reg_ddr4_8gb_inst instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {dma_write_apb_reg_ddr4_8gb} -instance_name {dma_write_apb_reg_ddr4_8gb_inst}
# Exporting Parameters of instance dma_write_apb_reg_ddr4_8gb_inst
sd_configure_core_instance -sd_name ${sd_name} -instance_name {dma_write_apb_reg_ddr4_8gb_inst} -params {\
"APB_ADDR_WIDTH:32" \
"APB_DATA_WIDTH:32" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {dma_write_apb_reg_ddr4_8gb_inst}
sd_update_instance -sd_name ${sd_name} -instance_name {dma_write_apb_reg_ddr4_8gb_inst}
sd_create_pin_group -sd_name ${sd_name} -group_name {DMA_WR_INTF} -instance_name {dma_write_apb_reg_ddr4_8gb_inst} -pin_names {"clear_index" "frame_index" "core_ready" "frame_write_done" "timeout_err" "h_size_byte" }



# Add dma_write_ddr4_8gb_inst instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {dma_write_ddr4_8gb} -instance_name {dma_write_ddr4_8gb_inst}
# Exporting Parameters of instance dma_write_ddr4_8gb_inst
sd_configure_core_instance -sd_name ${sd_name} -instance_name {dma_write_ddr4_8gb_inst} -params {\
"CLOCK_FREQ_MHZ:150" \
"TIMEOUT_USEC:10000" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {dma_write_ddr4_8gb_inst}
sd_update_instance -sd_name ${sd_name} -instance_name {dma_write_ddr4_8gb_inst}
sd_create_pin_group -sd_name ${sd_name} -group_name {clk_and_rst} -instance_name {dma_write_ddr4_8gb_inst} -pin_names {"ddr_rst_n" "ddr_clk" "pixel_clk" "pixel_rst_n" }
sd_create_pin_group -sd_name ${sd_name} -group_name {CAM_INTF} -instance_name {dma_write_ddr4_8gb_inst} -pin_names {"cam_frame_valid" "cam_line_valid" "cam_data_in" }
sd_create_pin_group -sd_name ${sd_name} -group_name {ARB_INTF} -instance_name {dma_write_ddr4_8gb_inst} -pin_names {"arb_write_req" "arb_write_done" "arb_write_ack" "arb_write_data" "arb_write_valid" "arb_write_start_addr" "arb_write_burst_len" }
sd_create_pin_group -sd_name ${sd_name} -group_name {RISCV_INTF} -instance_name {dma_write_ddr4_8gb_inst} -pin_names {"apb_reg_frame_index" "apb_reg_h_size_byte" "apb_reg_clear_index" "apb_reg_timeout_err" "apb_reg_frame_write_done" "apb_reg_core_ready" }



# Add scalar net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"arb_write_ack" "dma_write_ddr4_8gb_inst:arb_write_ack" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"arb_write_done" "dma_write_ddr4_8gb_inst:arb_write_done" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"arb_write_req" "dma_write_ddr4_8gb_inst:arb_write_req" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"arb_write_valid" "dma_write_ddr4_8gb_inst:arb_write_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_frame_valid" "dma_write_ddr4_8gb_inst:cam_frame_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_line_valid" "dma_write_ddr4_8gb_inst:cam_line_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_clk" "dma_write_ddr4_8gb_inst:ddr_clk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_rst_n" "dma_write_ddr4_8gb_inst:ddr_rst_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_write_apb_reg_ddr4_8gb_inst:clear_index" "dma_write_ddr4_8gb_inst:apb_reg_clear_index" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_write_apb_reg_ddr4_8gb_inst:core_ready" "dma_write_ddr4_8gb_inst:apb_reg_core_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_write_apb_reg_ddr4_8gb_inst:frame_write_done" "dma_write_ddr4_8gb_inst:apb_reg_frame_write_done" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_write_apb_reg_ddr4_8gb_inst:pclk" "pclk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_write_apb_reg_ddr4_8gb_inst:presetn" "presetn" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_write_ddr4_8gb_inst:pixel_clk" "pixel_clk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_write_ddr4_8gb_inst:pixel_rst_n" "pixel_rst_n" }

# Add bus net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"arb_write_burst_len" "dma_write_ddr4_8gb_inst:arb_write_burst_len" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"arb_write_data" "dma_write_ddr4_8gb_inst:arb_write_data" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"arb_write_start_addr" "dma_write_ddr4_8gb_inst:arb_write_start_addr" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_data_in" "dma_write_ddr4_8gb_inst:cam_data_in" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_wr_frame_index" "dma_write_apb_reg_ddr4_8gb_inst:frame_index" "dma_write_ddr4_8gb_inst:apb_reg_frame_index" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_write_apb_reg_ddr4_8gb_inst:h_size_byte" "dma_write_ddr4_8gb_inst:apb_reg_h_size_byte" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_write_apb_reg_ddr4_8gb_inst:timeout_err" "dma_write_ddr4_8gb_inst:apb_reg_timeout_err" }

# Add bus interface net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"dma_write_apb_reg_ddr4_8gb_inst:s_apb" "s_apb" }

# Re-enable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 1
# Save the SmartDesign 
save_smartdesign -sd_name ${sd_name}
# Generate SmartDesign "dma_write_ddr4_8gb_hier"
generate_component -component_name ${sd_name}
