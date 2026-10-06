# Creating SmartDesign "cam_rx_hier"
set sd_name {cam_rx_hier}
create_smartdesign -sd_name ${sd_name}

# Disable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 0

# Create top level Scalar Ports
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_en} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_fault_detector_apb_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_fault_detector_apb_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_fault_detector_apb_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane0_rxd_n} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane0_rxd_p} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane1_rxd_n} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane1_rxd_p} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane2_rxd_n} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane2_rxd_p} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane3_rxd_n} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane3_rxd_p} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane4_rxd_n} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane4_rxd_p} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane5_rxd_n} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane5_rxd_p} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane6_rxd_n} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane6_rxd_p} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane7_rxd_n} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane7_rxd_p} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_mux_apb_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_mux_apb_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_mux_apb_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_pwr_status} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_spi_apb_clk} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_spi_apb_rst_n} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_spi_miso} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_tout_primary} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_trig_ctrl_apb_penable} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_trig_ctrl_apb_psel} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_trig_ctrl_apb_pwrite} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cdr_ref_clk_148p5mhz} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {gpi_cam_apb_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {gpi_cam_apb_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {gpi_cam_apb_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {gpo_cam_apb_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {gpo_cam_apb_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {gpo_cam_apb_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {img_metadata_apb_penable} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {img_metadata_apb_psel} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {img_metadata_apb_pwrite} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {lvds_start} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {osc_clk} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pixel_fab_clk} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pixel_rst_n} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pma_arst_n} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {slvsec_spi_apb_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {slvsec_spi_apb_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {slvsec_spi_apb_PWRITE} -port_direction {IN}

sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_fault_detector_apb_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_fault_detector_apb_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_mux_apb_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_mux_apb_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_spi_int} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_spi_mosi} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_spi_sck} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_spi_xce_n} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_trig_ctrl_apb_pready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_trig_ctrl_apb_pslverr} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_trig_int} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_xclr_n} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_xtrig_primary} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_cam_mux_enable} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_cam_mux_select} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_ebd_valid} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_frame_valid} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_line_valid} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_16gb_frame_valid_out} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_16gb_line_valid_out} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_frame_valid_out} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_line_valid_out} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {gpi_cam_apb_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {gpi_cam_apb_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {gpo_cam_apb_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {gpo_cam_apb_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {img_metadata_apb_pready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {img_metadata_apb_pslverr} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pcs_arst_n} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pixel_ref_clk} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {slvsec_spi_apb_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {slvsec_spi_apb_PSLVERR} -port_direction {OUT}


# Create top level Bus Ports
sd_create_bus_port -sd_name ${sd_name} -port_name {cam_fault_detector_apb_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {cam_fault_detector_apb_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {cam_mux_apb_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {cam_mux_apb_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {cam_trig_ctrl_apb_paddr} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {cam_trig_ctrl_apb_pwdata} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_16gb_frame_index} -port_direction {IN} -port_range {[8:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_8gb_frame_index} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {gpi_cam_apb_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {gpi_cam_apb_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {gpo_cam_apb_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {gpo_cam_apb_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {img_metadata_apb_paddr} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {img_metadata_apb_pwdata} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {slvsec_spi_apb_PADDR} -port_direction {IN} -port_range {[6:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {slvsec_spi_apb_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {timestamp_nsec} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {timestamp_sec} -port_direction {IN} -port_range {[31:0]}

sd_create_bus_port -sd_name ${sd_name} -port_name {cam_fault_detector_apb_PRDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {cam_mux_apb_PRDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {cam_trig_ctrl_apb_prdata} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_16gb_cam_data_out} -port_direction {OUT} -port_range {[383:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_8gb_cam_data_out} -port_direction {OUT} -port_range {[383:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {gpi_cam_apb_PRDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {gpo_cam_apb_PRDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {img_metadata_apb_prdata} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {slvsec_spi_apb_PRDATA} -port_direction {OUT} -port_range {[31:0]}


# Create top level Bus interface Ports
sd_create_bif_port -sd_name ${sd_name} -port_name {slvsec_spi_apb} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:slvsec_spi_apb_PADDR" \
"PSELx:slvsec_spi_apb_PSEL" \
"PENABLE:slvsec_spi_apb_PENABLE" \
"PWRITE:slvsec_spi_apb_PWRITE" \
"PRDATA:slvsec_spi_apb_PRDATA" \
"PWDATA:slvsec_spi_apb_PWDATA" \
"PREADY:slvsec_spi_apb_PREADY" \
"PSLVERR:slvsec_spi_apb_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {gpo_cam_apb} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:gpo_cam_apb_PADDR" \
"PSELx:gpo_cam_apb_PSEL" \
"PENABLE:gpo_cam_apb_PENABLE" \
"PWRITE:gpo_cam_apb_PWRITE" \
"PRDATA:gpo_cam_apb_PRDATA" \
"PWDATA:gpo_cam_apb_PWDATA" \
"PREADY:gpo_cam_apb_PREADY" \
"PSLVERR:gpo_cam_apb_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {gpi_cam_apb} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:gpi_cam_apb_PADDR" \
"PSELx:gpi_cam_apb_PSEL" \
"PENABLE:gpi_cam_apb_PENABLE" \
"PWRITE:gpi_cam_apb_PWRITE" \
"PRDATA:gpi_cam_apb_PRDATA" \
"PWDATA:gpi_cam_apb_PWDATA" \
"PREADY:gpi_cam_apb_PREADY" \
"PSLVERR:gpi_cam_apb_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {cam_fault_detector_apb} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:cam_fault_detector_apb_PADDR" \
"PSELx:cam_fault_detector_apb_PSEL" \
"PENABLE:cam_fault_detector_apb_PENABLE" \
"PWRITE:cam_fault_detector_apb_PWRITE" \
"PRDATA:cam_fault_detector_apb_PRDATA" \
"PWDATA:cam_fault_detector_apb_PWDATA" \
"PREADY:cam_fault_detector_apb_PREADY" \
"PSLVERR:cam_fault_detector_apb_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {cam_mux_apb} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:cam_mux_apb_PADDR" \
"PSELx:cam_mux_apb_PSEL" \
"PENABLE:cam_mux_apb_PENABLE" \
"PWRITE:cam_mux_apb_PWRITE" \
"PRDATA:cam_mux_apb_PRDATA" \
"PWDATA:cam_mux_apb_PWDATA" \
"PREADY:cam_mux_apb_PREADY" \
"PSLVERR:cam_mux_apb_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {img_metadata_apb} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:img_metadata_apb_paddr" \
"PSELx:img_metadata_apb_psel" \
"PENABLE:img_metadata_apb_penable" \
"PWRITE:img_metadata_apb_pwrite" \
"PRDATA:img_metadata_apb_prdata" \
"PWDATA:img_metadata_apb_pwdata" \
"PREADY:img_metadata_apb_pready" \
"PSLVERR:img_metadata_apb_pslverr" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {cam_trig_ctrl_apb} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:cam_trig_ctrl_apb_paddr" \
"PSELx:cam_trig_ctrl_apb_psel" \
"PENABLE:cam_trig_ctrl_apb_penable" \
"PWRITE:cam_trig_ctrl_apb_pwrite" \
"PRDATA:cam_trig_ctrl_apb_prdata" \
"PWDATA:cam_trig_ctrl_apb_pwdata" \
"PREADY:cam_trig_ctrl_apb_pready" \
"PSLVERR:cam_trig_ctrl_apb_pslverr" } 

# Add cam_fault_detector_top_inst instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {cam_fault_detector_top} -instance_name {cam_fault_detector_top_inst}
# Exporting Parameters of instance cam_fault_detector_top_inst
sd_configure_core_instance -sd_name ${sd_name} -instance_name {cam_fault_detector_top_inst} -params {\
"APB_ADDR_WIDTH:32" \
"APB_DATA_WIDTH:32" \
"CLOCK_FREQ_MHZ:50" \
"TIMEOUT_US:1000" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {cam_fault_detector_top_inst}
sd_update_instance -sd_name ${sd_name} -instance_name {cam_fault_detector_top_inst}



# Add cam_flow_sync_inst instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {cam_flow_sync} -instance_name {cam_flow_sync_inst}
# Exporting Parameters of instance cam_flow_sync_inst
sd_configure_core_instance -sd_name ${sd_name} -instance_name {cam_flow_sync_inst} -params {\
"DATA_WIDTH:384" \
"EXTEND_CYCLES:10" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {cam_flow_sync_inst}
sd_update_instance -sd_name ${sd_name} -instance_name {cam_flow_sync_inst}



# Add cam_mux_top_inst instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {cam_mux_top} -instance_name {cam_mux_top_inst}
# Exporting Parameters of instance cam_mux_top_inst
sd_configure_core_instance -sd_name ${sd_name} -instance_name {cam_mux_top_inst} -params {\
"DATA_WIDTH:384" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {cam_mux_top_inst}
sd_update_instance -sd_name ${sd_name} -instance_name {cam_mux_top_inst}
sd_create_pin_group -sd_name ${sd_name} -group_name {CLKS_AND_RSTS} -instance_name {cam_mux_top_inst} -pin_names {"pclk" "presetn" "pixel_clk" "pixel_rst_n" }
sd_create_pin_group -sd_name ${sd_name} -group_name {CAM_INTF} -instance_name {cam_mux_top_inst} -pin_names {"cam_data_in" "frame_valid_in" "line_valid_in" }
sd_create_pin_group -sd_name ${sd_name} -group_name {STAT_INTF} -instance_name {cam_mux_top_inst} -pin_names {"mux_select" "mux_enable" }
sd_create_pin_group -sd_name ${sd_name} -group_name {DDR4_8GB_INTF} -instance_name {cam_mux_top_inst} -pin_names {"ddr4_8gb_cam_data_out" "ddr4_8gb_frame_valid_out" "ddr4_8gb_line_valid_out" }
sd_create_pin_group -sd_name ${sd_name} -group_name {DDR4_16GB_INTF} -instance_name {cam_mux_top_inst} -pin_names {"ddr4_16gb_cam_data_out" "ddr4_16gb_frame_valid_out" "ddr4_16gb_line_valid_out" }



# Add cam_spi_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {CORESPI_C0} -instance_name {cam_spi_inst}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {cam_spi_inst:SPISS} -pin_slices {[0:0]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {cam_spi_inst:SPISS} -pin_slices {[7:1]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {cam_spi_inst:SPISS[7:1]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {cam_spi_inst:SPIRXAVAIL}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {cam_spi_inst:SPITXRFM}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {cam_spi_inst:SPISSI} -value {VCC}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {cam_spi_inst:SPICLKI} -value {GND}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {cam_spi_inst:SPIOEN}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {cam_spi_inst:SPIMODE}



# Add cam_trig_top_inst instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {cam_trig_top} -instance_name {cam_trig_top_inst}
# Exporting Parameters of instance cam_trig_top_inst
sd_configure_core_instance -sd_name ${sd_name} -instance_name {cam_trig_top_inst} -params {\
"APB_ADDR_WIDTH:32" \
"APB_DATA_WIDTH:32" \
"CLOCK_FREQ_MHZ:50" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {cam_trig_top_inst}
sd_update_instance -sd_name ${sd_name} -instance_name {cam_trig_top_inst}



# Add ctrl_clk_div_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {PF_CLK_DIV_C0} -instance_name {ctrl_clk_div_inst}



# Add disp_corr_rstn instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {AND2} -instance_name {disp_corr_rstn}



# Add gpo_cam_ctrl_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {CoreGPIO_C0} -instance_name {gpo_cam_ctrl_inst}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpo_cam_ctrl_inst:GPIO_OUT} -pin_slices {[0:0]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpo_cam_ctrl_inst:GPIO_OUT} -pin_slices {[31:1]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {gpo_cam_ctrl_inst:GPIO_OUT[31:1]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {gpo_cam_ctrl_inst:INT}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {gpo_cam_ctrl_inst:GPIO_IN} -value {GND}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {gpo_cam_ctrl_inst:GPIO_OE}



# Add image_metadata_top_inst instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {image_metadata_top} -instance_name {image_metadata_top_inst}
# Exporting Parameters of instance image_metadata_top_inst
sd_configure_core_instance -sd_name ${sd_name} -instance_name {image_metadata_top_inst} -params {\
"APB_ADDR_WIDTH:32" \
"APB_DATA_WIDTH:32" \
"CAM_DATA_WIDTH:384" \
"CLOCK_FREQ_MHZ:50" \
"DDR4_8GB_FRAME_INDEX_WIDTH:8" \
"DDR4_16GB_FRAME_INDEX_WIDTH:9" \
"EXPO_TIME_WIDTH:22" \
"FRAME_CAPTURE_AMOUNT_WIDTH:10" \
"FRAME_CAPTURE_TIME_WIDTH:24" \
"METADATA_WIDTH:640" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {image_metadata_top_inst}
sd_update_instance -sd_name ${sd_name} -instance_name {image_metadata_top_inst}
sd_create_pin_group -sd_name ${sd_name} -group_name {PIXEL_CLK_GRP} -instance_name {image_metadata_top_inst} -pin_names {"pixel_rst_n" "pixel_clk" }
sd_create_pin_group -sd_name ${sd_name} -group_name {APB_CLK_GRP} -instance_name {image_metadata_top_inst} -pin_names {"presetn" "pclk" }
sd_create_pin_group -sd_name ${sd_name} -group_name {TIME} -instance_name {image_metadata_top_inst} -pin_names {"timestamp_nsec" "timestamp_sec" }
sd_create_pin_group -sd_name ${sd_name} -group_name {TRIG_INFO_GRP} -instance_name {image_metadata_top_inst} -pin_names {"cam_tout" "frame_capture_amount" "frame_capture_time" "trig_mode" }
sd_create_pin_group -sd_name ${sd_name} -group_name {FRAME_INDEX_GRP} -instance_name {image_metadata_top_inst} -pin_names {"ddr4_16gb_frame_index" "cam_mux_select" "ddr4_8gb_frame_index" }
sd_create_pin_group -sd_name ${sd_name} -group_name {CAM_DATA_IN_GRP} -instance_name {image_metadata_top_inst} -pin_names {"cam_data_in" "frame_valid_in" "line_valid_in" }
sd_create_pin_group -sd_name ${sd_name} -group_name {CAM_DATA_OUT_GRP} -instance_name {image_metadata_top_inst} -pin_names {"cam_data_out" "frame_valid_out" "line_valid_out" }



# Add pll_xcvr_clk_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {PF_CCC_C2} -instance_name {pll_xcvr_clk_inst}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {pll_xcvr_clk_inst:PLL_POWERDOWN_N_0} -value {VCC}



# Add slvs_ec_rx_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {SLVS_EC_RX_C0} -instance_name {slvs_ec_rx_inst}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {slvs_ec_rx_inst:HEADER_O}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {slvs_ec_rx_inst:LANE0_FSM_STATE_O}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {slvs_ec_rx_inst:LANE1_FSM_STATE_O}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {slvs_ec_rx_inst:LANE2_FSM_STATE_O}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {slvs_ec_rx_inst:LANE3_FSM_STATE_O}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {slvs_ec_rx_inst:LANE4_FSM_STATE_O}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {slvs_ec_rx_inst:LANE5_FSM_STATE_O}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {slvs_ec_rx_inst:LANE6_FSM_STATE_O}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {slvs_ec_rx_inst:LANE7_FSM_STATE_O}



# Add xcvr_disparity_correction_inst instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {XCVR_DISPARITY_CORRECTION} -instance_name {xcvr_disparity_correction_inst}
# Exporting Parameters of instance xcvr_disparity_correction_inst
sd_configure_core_instance -sd_name ${sd_name} -instance_name {xcvr_disparity_correction_inst} -params {\
"DISPARITY_ERR_WIDTH:4" \
"ENABLE_ERM_FIRST_LOCK:1" \
"NUM_LANES:8" \
"RST_CNT_CLKS:32" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {xcvr_disparity_correction_inst}
sd_update_instance -sd_name ${sd_name} -instance_name {xcvr_disparity_correction_inst}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {xcvr_disparity_correction_inst:RX_RST_CONTROL_INTERRUPT_O}



# Add xcvr_rx_inst0 instance
sd_instantiate_component -sd_name ${sd_name} -component_name {PF_XCVR_ERM_C0} -instance_name {xcvr_rx_inst0}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {xcvr_rx_inst0:LANE0_RX_IDLE}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {xcvr_rx_inst0:LANE1_RX_IDLE}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {xcvr_rx_inst0:LANE2_RX_IDLE}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {xcvr_rx_inst0:LANE3_RX_IDLE}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {xcvr_rx_inst0:LANE0_LOS} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {xcvr_rx_inst0:LANE0_CALIB_REQ} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {xcvr_rx_inst0:LANE1_LOS} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {xcvr_rx_inst0:LANE1_CALIB_REQ} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {xcvr_rx_inst0:LANE2_LOS} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {xcvr_rx_inst0:LANE2_CALIB_REQ} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {xcvr_rx_inst0:LANE3_LOS} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {xcvr_rx_inst0:LANE3_CALIB_REQ} -value {GND}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {xcvr_rx_inst0:LANE0_RX_CODE_VIOLATION}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {xcvr_rx_inst0:LANE1_RX_CODE_VIOLATION}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {xcvr_rx_inst0:LANE2_RX_CODE_VIOLATION}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {xcvr_rx_inst0:LANE3_RX_CODE_VIOLATION}



# Add xcvr_rx_inst1 instance
sd_instantiate_component -sd_name ${sd_name} -component_name {PF_XCVR_ERM_C1} -instance_name {xcvr_rx_inst1}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {xcvr_rx_inst1:LANE0_RX_IDLE}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {xcvr_rx_inst1:LANE1_RX_IDLE}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {xcvr_rx_inst1:LANE2_RX_IDLE}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {xcvr_rx_inst1:LANE3_RX_IDLE}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {xcvr_rx_inst1:LANE0_LOS} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {xcvr_rx_inst1:LANE0_CALIB_REQ} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {xcvr_rx_inst1:LANE1_LOS} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {xcvr_rx_inst1:LANE1_CALIB_REQ} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {xcvr_rx_inst1:LANE2_LOS} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {xcvr_rx_inst1:LANE2_CALIB_REQ} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {xcvr_rx_inst1:LANE3_LOS} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {xcvr_rx_inst1:LANE3_CALIB_REQ} -value {GND}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {xcvr_rx_inst1:LANE0_RX_CODE_VIOLATION}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {xcvr_rx_inst1:LANE1_RX_CODE_VIOLATION}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {xcvr_rx_inst1:LANE2_RX_CODE_VIOLATION}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {xcvr_rx_inst1:LANE3_RX_CODE_VIOLATION}



# Add scalar net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_en" "cam_trig_top_inst:en" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_fault_detector_top_inst:cam_pwr_status" "cam_pwr_status" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_fault_detector_top_inst:capture_finish" "cam_trig_top_inst:finish" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_fault_detector_top_inst:capture_start" "cam_trig_top_inst:start" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_fault_detector_top_inst:frame_valid" "cam_flow_sync_inst:frame_valid_in" "dbg_frame_valid" "slvs_ec_rx_inst:FRAME_VALID_O" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_fault_detector_top_inst:pclk" "cam_fault_detector_top_inst:xtrig_clk" "cam_mux_top_inst:pclk" "cam_spi_apb_clk" "cam_spi_inst:PCLK" "cam_trig_top_inst:pclk" "cam_trig_top_inst:xtrig_clk" "gpo_cam_ctrl_inst:PCLK" "image_metadata_top_inst:pclk" "xcvr_disparity_correction_inst:P_CLK_I" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_fault_detector_top_inst:presetn" "cam_fault_detector_top_inst:xtrig_rst_n" "cam_mux_top_inst:presetn" "cam_spi_apb_rst_n" "cam_spi_inst:PRESETN" "cam_trig_top_inst:presetn" "cam_trig_top_inst:xtrig_rst_n" "gpo_cam_ctrl_inst:PRESETN" "image_metadata_top_inst:presetn" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_fault_detector_top_inst:xtrig" "cam_trig_top_inst:xtrig" "cam_xtrig_primary" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_flow_sync_inst:clk" "cam_mux_top_inst:pixel_clk" "image_metadata_top_inst:pixel_clk" "pixel_fab_clk" "slvs_ec_rx_inst:PIXEL_CLOCK_I" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_flow_sync_inst:ebd_valid_in" "dbg_ebd_valid" "slvs_ec_rx_inst:EBD_VALID_O" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_flow_sync_inst:frame_valid_out" "image_metadata_top_inst:frame_valid_in" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_flow_sync_inst:line_or_ebd_valid_out" "image_metadata_top_inst:line_valid_in" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_flow_sync_inst:line_valid_in" "dbg_line_valid" "slvs_ec_rx_inst:LINE_VALID_O" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_flow_sync_inst:rst_n" "cam_mux_top_inst:pixel_rst_n" "image_metadata_top_inst:pixel_rst_n" "pixel_rst_n" "slvs_ec_rx_inst:ARST_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane0_rxd_n" "xcvr_rx_inst0:LANE0_RXD_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane0_rxd_p" "xcvr_rx_inst0:LANE0_RXD_P" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane1_rxd_n" "xcvr_rx_inst0:LANE1_RXD_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane1_rxd_p" "xcvr_rx_inst0:LANE1_RXD_P" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane2_rxd_n" "xcvr_rx_inst0:LANE2_RXD_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane2_rxd_p" "xcvr_rx_inst0:LANE2_RXD_P" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane3_rxd_n" "xcvr_rx_inst0:LANE3_RXD_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane3_rxd_p" "xcvr_rx_inst0:LANE3_RXD_P" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane4_rxd_n" "xcvr_rx_inst1:LANE0_RXD_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane4_rxd_p" "xcvr_rx_inst1:LANE0_RXD_P" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane5_rxd_n" "xcvr_rx_inst1:LANE1_RXD_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane5_rxd_p" "xcvr_rx_inst1:LANE1_RXD_P" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane6_rxd_n" "xcvr_rx_inst1:LANE2_RXD_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane6_rxd_p" "xcvr_rx_inst1:LANE2_RXD_P" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane7_rxd_n" "xcvr_rx_inst1:LANE3_RXD_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane7_rxd_p" "xcvr_rx_inst1:LANE3_RXD_P" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_mux_top_inst:mux_enable" "dbg_cam_mux_enable" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_mux_top_inst:mux_select" "dbg_cam_mux_select" "image_metadata_top_inst:cam_mux_select" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_mux_top_inst:ddr4_16gb_frame_valid_out" "ddr4_16gb_frame_valid_out" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_mux_top_inst:ddr4_16gb_line_valid_out" "ddr4_16gb_line_valid_out" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_mux_top_inst:ddr4_8gb_frame_valid_out" "ddr4_8gb_frame_valid_out" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_mux_top_inst:ddr4_8gb_line_valid_out" "ddr4_8gb_line_valid_out" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_mux_top_inst:frame_valid_in" "image_metadata_top_inst:frame_valid_out" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_mux_top_inst:line_valid_in" "image_metadata_top_inst:line_valid_out" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_spi_inst:SPIINT" "cam_spi_int" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_spi_inst:SPISCLKO" "cam_spi_sck" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_spi_inst:SPISDI" "cam_spi_miso" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_spi_inst:SPISDO" "cam_spi_mosi" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_spi_inst:SPISS[0:0]" "cam_spi_xce_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_tout_primary" "image_metadata_top_inst:cam_tout" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_trig_top_inst:lvds_start" "lvds_start" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_trig_top_inst:xtrig_int" "cam_trig_int" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_xclr_n" "gpo_cam_ctrl_inst:GPIO_OUT[0:0]" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cdr_ref_clk_148p5mhz" "pll_xcvr_clk_inst:REF_CLK_0" "xcvr_rx_inst0:LANE0_CDR_REF_CLK_0" "xcvr_rx_inst0:LANE1_CDR_REF_CLK_0" "xcvr_rx_inst0:LANE2_CDR_REF_CLK_0" "xcvr_rx_inst0:LANE3_CDR_REF_CLK_0" "xcvr_rx_inst1:LANE0_CDR_REF_CLK_0" "xcvr_rx_inst1:LANE1_CDR_REF_CLK_0" "xcvr_rx_inst1:LANE2_CDR_REF_CLK_0" "xcvr_rx_inst1:LANE3_CDR_REF_CLK_0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ctrl_clk_div_inst:CLK_IN" "osc_clk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ctrl_clk_div_inst:CLK_OUT" "xcvr_rx_inst0:CTRL_CLK" "xcvr_rx_inst1:CTRL_CLK" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"disp_corr_rstn:A" "pma_arst_n" "xcvr_rx_inst0:CTRL_ARST_N" "xcvr_rx_inst0:LANE0_PMA_ARST_N" "xcvr_rx_inst0:LANE1_PMA_ARST_N" "xcvr_rx_inst0:LANE2_PMA_ARST_N" "xcvr_rx_inst0:LANE3_PMA_ARST_N" "xcvr_rx_inst1:CTRL_ARST_N" "xcvr_rx_inst1:LANE0_PMA_ARST_N" "xcvr_rx_inst1:LANE1_PMA_ARST_N" "xcvr_rx_inst1:LANE2_PMA_ARST_N" "xcvr_rx_inst1:LANE3_PMA_ARST_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"disp_corr_rstn:B" "pll_xcvr_clk_inst:PLL_LOCK_0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"disp_corr_rstn:Y" "xcvr_disparity_correction_inst:RESET_N_I" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pcs_arst_n" "xcvr_disparity_correction_inst:RX_RST_CONTROL_O" "xcvr_rx_inst0:LANE0_PCS_ARST_N" "xcvr_rx_inst0:LANE1_PCS_ARST_N" "xcvr_rx_inst0:LANE2_PCS_ARST_N" "xcvr_rx_inst0:LANE3_PCS_ARST_N" "xcvr_rx_inst1:LANE0_PCS_ARST_N" "xcvr_rx_inst1:LANE1_PCS_ARST_N" "xcvr_rx_inst1:LANE2_PCS_ARST_N" "xcvr_rx_inst1:LANE3_PCS_ARST_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pixel_ref_clk" "slvs_ec_rx_inst:LANE0_RX_CLK_I" "xcvr_disparity_correction_inst:LANE0_RX_CLK_I" "xcvr_rx_inst0:LANE0_RX_CLK_R" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pll_xcvr_clk_inst:OUT0_FABCLK_0" "xcvr_rx_inst0:LANE0_CLK_REF" "xcvr_rx_inst0:LANE1_CLK_REF" "xcvr_rx_inst0:LANE2_CLK_REF" "xcvr_rx_inst0:LANE3_CLK_REF" "xcvr_rx_inst1:LANE0_CLK_REF" "xcvr_rx_inst1:LANE1_CLK_REF" "xcvr_rx_inst1:LANE2_CLK_REF" "xcvr_rx_inst1:LANE3_CLK_REF" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE0_RX_READY_I" "xcvr_rx_inst0:LANE0_RX_READY" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE0_RX_VALID_I" "xcvr_disparity_correction_inst:LANE0_RX_VALID_I" "xcvr_rx_inst0:LANE0_RX_VAL" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE1_RX_CLK_I" "xcvr_disparity_correction_inst:LANE1_RX_CLK_I" "xcvr_rx_inst0:LANE1_RX_CLK_R" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE1_RX_READY_I" "xcvr_rx_inst0:LANE1_RX_READY" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE1_RX_VALID_I" "xcvr_disparity_correction_inst:LANE1_RX_VALID_I" "xcvr_rx_inst0:LANE1_RX_VAL" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE2_RX_CLK_I" "xcvr_disparity_correction_inst:LANE2_RX_CLK_I" "xcvr_rx_inst0:LANE2_RX_CLK_R" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE2_RX_READY_I" "xcvr_rx_inst0:LANE2_RX_READY" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE2_RX_VALID_I" "xcvr_disparity_correction_inst:LANE2_RX_VALID_I" "xcvr_rx_inst0:LANE2_RX_VAL" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE3_RX_CLK_I" "xcvr_disparity_correction_inst:LANE3_RX_CLK_I" "xcvr_rx_inst0:LANE3_RX_CLK_R" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE3_RX_READY_I" "xcvr_rx_inst0:LANE3_RX_READY" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE3_RX_VALID_I" "xcvr_disparity_correction_inst:LANE3_RX_VALID_I" "xcvr_rx_inst0:LANE3_RX_VAL" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE4_RX_CLK_I" "xcvr_disparity_correction_inst:LANE4_RX_CLK_I" "xcvr_rx_inst1:LANE0_RX_CLK_R" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE4_RX_READY_I" "xcvr_rx_inst1:LANE0_RX_READY" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE4_RX_VALID_I" "xcvr_disparity_correction_inst:LANE4_RX_VALID_I" "xcvr_rx_inst1:LANE0_RX_VAL" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE5_RX_CLK_I" "xcvr_disparity_correction_inst:LANE5_RX_CLK_I" "xcvr_rx_inst1:LANE1_RX_CLK_R" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE5_RX_READY_I" "xcvr_rx_inst1:LANE1_RX_READY" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE5_RX_VALID_I" "xcvr_disparity_correction_inst:LANE5_RX_VALID_I" "xcvr_rx_inst1:LANE1_RX_VAL" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE6_RX_CLK_I" "xcvr_disparity_correction_inst:LANE6_RX_CLK_I" "xcvr_rx_inst1:LANE2_RX_CLK_R" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE6_RX_READY_I" "xcvr_rx_inst1:LANE2_RX_READY" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE6_RX_VALID_I" "xcvr_disparity_correction_inst:LANE6_RX_VALID_I" "xcvr_rx_inst1:LANE2_RX_VAL" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE7_RX_CLK_I" "xcvr_disparity_correction_inst:LANE7_RX_CLK_I" "xcvr_rx_inst1:LANE3_RX_CLK_R" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE7_RX_READY_I" "xcvr_rx_inst1:LANE3_RX_READY" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE7_RX_VALID_I" "xcvr_disparity_correction_inst:LANE7_RX_VALID_I" "xcvr_rx_inst1:LANE3_RX_VAL" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"xcvr_disparity_correction_inst:LANE0_CALIBRATING_I" "xcvr_rx_inst0:LANE0_CALIBRATING" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"xcvr_disparity_correction_inst:LANE1_CALIBRATING_I" "xcvr_rx_inst0:LANE1_CALIBRATING" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"xcvr_disparity_correction_inst:LANE2_CALIBRATING_I" "xcvr_rx_inst0:LANE2_CALIBRATING" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"xcvr_disparity_correction_inst:LANE3_CALIBRATING_I" "xcvr_rx_inst0:LANE3_CALIBRATING" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"xcvr_disparity_correction_inst:LANE4_CALIBRATING_I" "xcvr_rx_inst1:LANE0_CALIBRATING" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"xcvr_disparity_correction_inst:LANE5_CALIBRATING_I" "xcvr_rx_inst1:LANE1_CALIBRATING" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"xcvr_disparity_correction_inst:LANE6_CALIBRATING_I" "xcvr_rx_inst1:LANE2_CALIBRATING" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"xcvr_disparity_correction_inst:LANE7_CALIBRATING_I" "xcvr_rx_inst1:LANE3_CALIBRATING" }

# Add bus net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_flow_sync_inst:data_in" "slvs_ec_rx_inst:DATA_OUT_O" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_flow_sync_inst:data_out" "image_metadata_top_inst:cam_data_in" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_mux_top_inst:cam_data_in" "image_metadata_top_inst:cam_data_out" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_mux_top_inst:ddr4_16gb_cam_data_out" "ddr4_16gb_cam_data_out" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_mux_top_inst:ddr4_8gb_cam_data_out" "ddr4_8gb_cam_data_out" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_trig_top_inst:frame_capture_amount" "image_metadata_top_inst:frame_capture_amount" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_trig_top_inst:frame_capture_time" "image_metadata_top_inst:frame_capture_time" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_trig_top_inst:rtc_nsec" "image_metadata_top_inst:timestamp_nsec" "timestamp_nsec" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_trig_top_inst:rtc_sec" "image_metadata_top_inst:timestamp_sec" "timestamp_sec" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_trig_top_inst:xtrig_src_sel" "image_metadata_top_inst:trig_mode" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_frame_index" "image_metadata_top_inst:ddr4_16gb_frame_index" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_frame_index" "image_metadata_top_inst:ddr4_8gb_frame_index" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE0_8b10b_RX_K_I" "xcvr_rx_inst0:LANE0_8B10B_RX_K" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE0_RX_DATA_I" "xcvr_rx_inst0:LANE0_RX_DATA" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE1_8b10b_RX_K_I" "xcvr_rx_inst0:LANE1_8B10B_RX_K" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE1_RX_DATA_I" "xcvr_rx_inst0:LANE1_RX_DATA" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE2_8b10b_RX_K_I" "xcvr_rx_inst0:LANE2_8B10B_RX_K" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE2_RX_DATA_I" "xcvr_rx_inst0:LANE2_RX_DATA" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE3_8b10b_RX_K_I" "xcvr_rx_inst0:LANE3_8B10B_RX_K" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE3_RX_DATA_I" "xcvr_rx_inst0:LANE3_RX_DATA" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE4_8b10b_RX_K_I" "xcvr_rx_inst1:LANE0_8B10B_RX_K" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE4_RX_DATA_I" "xcvr_rx_inst1:LANE0_RX_DATA" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE5_8b10b_RX_K_I" "xcvr_rx_inst1:LANE1_8B10B_RX_K" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE5_RX_DATA_I" "xcvr_rx_inst1:LANE1_RX_DATA" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE6_8b10b_RX_K_I" "xcvr_rx_inst1:LANE2_8B10B_RX_K" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE6_RX_DATA_I" "xcvr_rx_inst1:LANE2_RX_DATA" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE7_8b10b_RX_K_I" "xcvr_rx_inst1:LANE3_8B10B_RX_K" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"slvs_ec_rx_inst:LANE7_RX_DATA_I" "xcvr_rx_inst1:LANE3_RX_DATA" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"xcvr_disparity_correction_inst:LANE0_DISPARITY_ERR_I" "xcvr_rx_inst0:LANE0_RX_DISPARITY_ERROR" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"xcvr_disparity_correction_inst:LANE1_DISPARITY_ERR_I" "xcvr_rx_inst0:LANE1_RX_DISPARITY_ERROR" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"xcvr_disparity_correction_inst:LANE2_DISPARITY_ERR_I" "xcvr_rx_inst0:LANE2_RX_DISPARITY_ERROR" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"xcvr_disparity_correction_inst:LANE3_DISPARITY_ERR_I" "xcvr_rx_inst0:LANE3_RX_DISPARITY_ERROR" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"xcvr_disparity_correction_inst:LANE4_DISPARITY_ERR_I" "xcvr_rx_inst1:LANE0_RX_DISPARITY_ERROR" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"xcvr_disparity_correction_inst:LANE5_DISPARITY_ERR_I" "xcvr_rx_inst1:LANE1_RX_DISPARITY_ERROR" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"xcvr_disparity_correction_inst:LANE6_DISPARITY_ERR_I" "xcvr_rx_inst1:LANE2_RX_DISPARITY_ERROR" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"xcvr_disparity_correction_inst:LANE7_DISPARITY_ERR_I" "xcvr_rx_inst1:LANE3_RX_DISPARITY_ERROR" }

# Add bus interface net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_fault_detector_apb" "cam_fault_detector_top_inst:s_apb" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_mux_apb" "cam_mux_top_inst:s_apb" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_spi_inst:APB_bif" "slvsec_spi_apb" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_trig_ctrl_apb" "cam_trig_top_inst:s_apb" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpo_cam_apb" "gpo_cam_ctrl_inst:APB_bif" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"image_metadata_top_inst:s_apb" "img_metadata_apb" }

# Re-enable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 1
# Save the SmartDesign 
save_smartdesign -sd_name ${sd_name}
# Generate SmartDesign "cam_rx_hier"
generate_component -component_name ${sd_name}
