# Creating SmartDesign "LVDT_READOUT"
set sd_name {LVDT_READOUT}
create_smartdesign -sd_name ${sd_name}

# Disable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 0

# Create top level Scalar Ports
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_PRI_I_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_PRI_I_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_PRI_I_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_PRI_Q_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_PRI_Q_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_PRI_Q_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_SEC_I_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_SEC_I_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_SEC_I_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_SEC_Q_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_SEC_Q_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_SEC_Q_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {i_clk} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {i_res} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {lvdt_adc_spi_miso} -port_direction {IN}

sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_PRI_I_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_PRI_I_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_PRI_Q_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_PRI_Q_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_SEC_I_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_SEC_I_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_SEC_Q_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_SEC_Q_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {o_spi_clk} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {o_spi_cs} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {o_spi_mosi} -port_direction {OUT}


# Create top level Bus Ports
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_PRI_I_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_PRI_I_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_PRI_Q_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_PRI_Q_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_SEC_I_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_SEC_I_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_SEC_Q_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_SEC_Q_PWDATA} -port_direction {IN} -port_range {[31:0]}

sd_create_bus_port -sd_name ${sd_name} -port_name {APB_PRI_I_PRDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_PRI_Q_PRDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_SEC_I_PRDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_SEC_Q_PRDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {o_data} -port_direction {OUT} -port_range {[7:0]}


# Create top level Bus interface Ports
sd_create_bif_port -sd_name ${sd_name} -port_name {APB_PRI_Q} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:APB_PRI_Q_PADDR" \
"PSELx:APB_PRI_Q_PSEL" \
"PENABLE:APB_PRI_Q_PENABLE" \
"PWRITE:APB_PRI_Q_PWRITE" \
"PRDATA:APB_PRI_Q_PRDATA" \
"PWDATA:APB_PRI_Q_PWDATA" \
"PREADY:APB_PRI_Q_PREADY" \
"PSLVERR:APB_PRI_Q_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {APB_PRI_I} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:APB_PRI_I_PADDR" \
"PSELx:APB_PRI_I_PSEL" \
"PENABLE:APB_PRI_I_PENABLE" \
"PWRITE:APB_PRI_I_PWRITE" \
"PRDATA:APB_PRI_I_PRDATA" \
"PWDATA:APB_PRI_I_PWDATA" \
"PREADY:APB_PRI_I_PREADY" \
"PSLVERR:APB_PRI_I_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {APB_SEC_I} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:APB_SEC_I_PADDR" \
"PSELx:APB_SEC_I_PSEL" \
"PENABLE:APB_SEC_I_PENABLE" \
"PWRITE:APB_SEC_I_PWRITE" \
"PRDATA:APB_SEC_I_PRDATA" \
"PWDATA:APB_SEC_I_PWDATA" \
"PREADY:APB_SEC_I_PREADY" \
"PSLVERR:APB_SEC_I_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {APB_SEC_Q} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:APB_SEC_Q_PADDR" \
"PSELx:APB_SEC_Q_PSEL" \
"PENABLE:APB_SEC_Q_PENABLE" \
"PWRITE:APB_SEC_Q_PWRITE" \
"PRDATA:APB_SEC_Q_PRDATA" \
"PWDATA:APB_SEC_Q_PWDATA" \
"PREADY:APB_SEC_Q_PREADY" \
"PSLVERR:APB_SEC_Q_PSLVERR" } 

# Add ADC128S102_DRIVER_0_0 instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {ADC128S102_DRIVER} -instance_name {ADC128S102_DRIVER_0_0}
# Exporting Parameters of instance ADC128S102_DRIVER_0_0
sd_configure_core_instance -sd_name ${sd_name} -instance_name {ADC128S102_DRIVER_0_0} -params {\
"CHANNEL_COUNT:8" \
"SPI_CLK_DIV:4" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {ADC128S102_DRIVER_0_0}
sd_update_instance -sd_name ${sd_name} -instance_name {ADC128S102_DRIVER_0_0}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {ADC128S102_DRIVER_0_0:o_data} -pin_slices {[103:91]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {ADC128S102_DRIVER_0_0:o_data} -pin_slices {[12:0]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {ADC128S102_DRIVER_0_0:o_data[12:0]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {ADC128S102_DRIVER_0_0:o_data} -pin_slices {[25:13]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {ADC128S102_DRIVER_0_0:o_data[25:13]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {ADC128S102_DRIVER_0_0:o_data} -pin_slices {[38:26]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {ADC128S102_DRIVER_0_0:o_data[38:26]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {ADC128S102_DRIVER_0_0:o_data} -pin_slices {[51:39]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {ADC128S102_DRIVER_0_0:o_data} -pin_slices {[64:52]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {ADC128S102_DRIVER_0_0:o_data[64:52]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {ADC128S102_DRIVER_0_0:o_data} -pin_slices {[77:65]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {ADC128S102_DRIVER_0_0:o_data[77:65]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {ADC128S102_DRIVER_0_0:o_data} -pin_slices {[90:78]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {ADC128S102_DRIVER_0_0:o_data[90:78]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {ADC128S102_DRIVER_0_0:o_data_valid} -pin_slices {[0:0]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {ADC128S102_DRIVER_0_0:o_data_valid[0:0]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {ADC128S102_DRIVER_0_0:o_data_valid} -pin_slices {[1:1]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {ADC128S102_DRIVER_0_0:o_data_valid[1:1]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {ADC128S102_DRIVER_0_0:o_data_valid} -pin_slices {[2:2]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {ADC128S102_DRIVER_0_0:o_data_valid[2:2]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {ADC128S102_DRIVER_0_0:o_data_valid} -pin_slices {[3:3]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {ADC128S102_DRIVER_0_0:o_data_valid} -pin_slices {[4:4]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {ADC128S102_DRIVER_0_0:o_data_valid[4:4]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {ADC128S102_DRIVER_0_0:o_data_valid} -pin_slices {[5:5]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {ADC128S102_DRIVER_0_0:o_data_valid[5:5]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {ADC128S102_DRIVER_0_0:o_data_valid} -pin_slices {[6:6]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {ADC128S102_DRIVER_0_0:o_data_valid[6:6]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {ADC128S102_DRIVER_0_0:o_data_valid} -pin_slices {[7:7]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {ADC128S102_DRIVER_0_0:i_data_ready} -pin_slices {[0:0]}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {ADC128S102_DRIVER_0_0:i_data_ready[0:0]} -value {GND}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {ADC128S102_DRIVER_0_0:i_data_ready} -pin_slices {[1:1]}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {ADC128S102_DRIVER_0_0:i_data_ready[1:1]} -value {GND}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {ADC128S102_DRIVER_0_0:i_data_ready} -pin_slices {[2:2]}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {ADC128S102_DRIVER_0_0:i_data_ready[2:2]} -value {GND}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {ADC128S102_DRIVER_0_0:i_data_ready} -pin_slices {[3:3]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {ADC128S102_DRIVER_0_0:i_data_ready} -pin_slices {[4:4]}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {ADC128S102_DRIVER_0_0:i_data_ready[4:4]} -value {GND}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {ADC128S102_DRIVER_0_0:i_data_ready} -pin_slices {[5:5]}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {ADC128S102_DRIVER_0_0:i_data_ready[5:5]} -value {GND}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {ADC128S102_DRIVER_0_0:i_data_ready} -pin_slices {[6:6]}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {ADC128S102_DRIVER_0_0:i_data_ready[6:6]} -value {GND}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {ADC128S102_DRIVER_0_0:i_data_ready} -pin_slices {[7:7]}



# Add DELTA_SIGMA_0 instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {DELTA_SIGMA} -instance_name {DELTA_SIGMA_0}
# Exporting Parameters of instance DELTA_SIGMA_0
sd_configure_core_instance -sd_name ${sd_name} -instance_name {DELTA_SIGMA_0} -params {\
"INPUT_WIDTH:16" \
"OUTPUT_WIDTH:8" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {DELTA_SIGMA_0}
sd_update_instance -sd_name ${sd_name} -instance_name {DELTA_SIGMA_0}



# Add LOCK_IN_CHAIN_PRIMARY_COIL instance
sd_instantiate_component -sd_name ${sd_name} -component_name {LOCK_IN_CHAIN} -instance_name {LOCK_IN_CHAIN_PRIMARY_COIL}



# Add LOCK_IN_CHAIN_SECONDARY_COIL instance
sd_instantiate_component -sd_name ${sd_name} -component_name {LOCK_IN_CHAIN} -instance_name {LOCK_IN_CHAIN_SECONDARY_COIL}



# Add primary_i instance
sd_instantiate_component -sd_name ${sd_name} -component_name {FOCUS_MECH_CoreGPIO_C0} -instance_name {primary_i}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {primary_i:INT}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {primary_i:GPIO_OUT}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {primary_i:GPIO_OE}



# Add primary_q instance
sd_instantiate_component -sd_name ${sd_name} -component_name {FOCUS_MECH_CoreGPIO_C0} -instance_name {primary_q}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {primary_q:INT}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {primary_q:GPIO_OUT}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {primary_q:GPIO_OE}



# Add RST_HANDLER_0 instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {RST_HANDLER} -instance_name {RST_HANDLER_0}



# Add secondary_i instance
sd_instantiate_component -sd_name ${sd_name} -component_name {FOCUS_MECH_CoreGPIO_C0} -instance_name {secondary_i}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {secondary_i:INT}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {secondary_i:GPIO_OUT}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {secondary_i:GPIO_OE}



# Add secondary_q instance
sd_instantiate_component -sd_name ${sd_name} -component_name {FOCUS_MECH_CoreGPIO_C0} -instance_name {secondary_q}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {secondary_q:INT}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {secondary_q:GPIO_OUT}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {secondary_q:GPIO_OE}



# Add SIN_COS_GEN_0 instance
sd_instantiate_component -sd_name ${sd_name} -component_name {SIN_COS_GEN} -instance_name {SIN_COS_GEN_0}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {SIN_COS_GEN_0:RSTN} -value {VCC}



# Add SINE_SCALER_0 instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {SINE_SCALER} -instance_name {SINE_SCALER_0}
# Exporting Parameters of instance SINE_SCALER_0
sd_configure_core_instance -sd_name ${sd_name} -instance_name {SINE_SCALER_0} -params {\
"INPUT_WIDTH:17" \
"MULTIPLIER:65535" \
"MULTIPLIER_WIDTH:16" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {SINE_SCALER_0}
sd_update_instance -sd_name ${sd_name} -instance_name {SINE_SCALER_0}



# Add scalar net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"ADC128S102_DRIVER_0_0:i_clk" "DELTA_SIGMA_0:i_clk" "LOCK_IN_CHAIN_PRIMARY_COIL:i_clk" "LOCK_IN_CHAIN_SECONDARY_COIL:i_clk" "RST_HANDLER_0:i_clk" "SINE_SCALER_0:i_clk" "SIN_COS_GEN_0:CLK" "i_clk" "primary_i:PCLK" "primary_q:PCLK" "secondary_i:PCLK" "secondary_q:PCLK" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ADC128S102_DRIVER_0_0:i_data_ready[3:3]" "LOCK_IN_CHAIN_PRIMARY_COIL:o_data_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ADC128S102_DRIVER_0_0:i_data_ready[7:7]" "LOCK_IN_CHAIN_SECONDARY_COIL:o_data_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ADC128S102_DRIVER_0_0:i_res" "DELTA_SIGMA_0:i_res" "LOCK_IN_CHAIN_PRIMARY_COIL:i_res" "LOCK_IN_CHAIN_SECONDARY_COIL:i_res" "RST_HANDLER_0:i_rst" "SIN_COS_GEN_0:NGRST" "i_res" "primary_i:PRESETN" "primary_q:PRESETN" "secondary_i:PRESETN" "secondary_q:PRESETN" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ADC128S102_DRIVER_0_0:lvdt_adc_spi_miso" "lvdt_adc_spi_miso" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ADC128S102_DRIVER_0_0:o_data_valid[3:3]" "LOCK_IN_CHAIN_PRIMARY_COIL:i_data_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ADC128S102_DRIVER_0_0:o_data_valid[7:7]" "LOCK_IN_CHAIN_SECONDARY_COIL:i_data_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ADC128S102_DRIVER_0_0:o_spi_clk" "o_spi_clk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ADC128S102_DRIVER_0_0:o_spi_cs" "o_spi_cs" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ADC128S102_DRIVER_0_0:o_spi_mosi" "o_spi_mosi" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"DELTA_SIGMA_0:i_data_valid" "LOCK_IN_CHAIN_PRIMARY_COIL:i_osc_data_valid" "LOCK_IN_CHAIN_SECONDARY_COIL:i_osc_data_valid" "RST_HANDLER_0:o_data_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"RST_HANDLER_0:i_init_over" "SIN_COS_GEN_0:INIT_OVER" }

# Add bus net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"ADC128S102_DRIVER_0_0:o_data[103:91]" "LOCK_IN_CHAIN_SECONDARY_COIL:i_data" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ADC128S102_DRIVER_0_0:o_data[51:39]" "LOCK_IN_CHAIN_PRIMARY_COIL:i_data" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"DELTA_SIGMA_0:i_data" "SINE_SCALER_0:o_data" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"DELTA_SIGMA_0:o_data" "o_data" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LOCK_IN_CHAIN_PRIMARY_COIL:i_cos" "LOCK_IN_CHAIN_SECONDARY_COIL:i_cos" "SIN_COS_GEN_0:COSINE" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LOCK_IN_CHAIN_PRIMARY_COIL:i_sin" "LOCK_IN_CHAIN_SECONDARY_COIL:i_sin" "SINE_SCALER_0:i_data" "SIN_COS_GEN_0:SINE" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LOCK_IN_CHAIN_PRIMARY_COIL:o_data_i" "primary_i:GPIO_IN" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LOCK_IN_CHAIN_PRIMARY_COIL:o_data_q" "primary_q:GPIO_IN" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LOCK_IN_CHAIN_SECONDARY_COIL:o_data_i" "secondary_i:GPIO_IN" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LOCK_IN_CHAIN_SECONDARY_COIL:o_data_q" "secondary_q:GPIO_IN" }

# Add bus interface net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"APB_PRI_I" "primary_i:APB_bif" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"APB_PRI_Q" "primary_q:APB_bif" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"APB_SEC_I" "secondary_i:APB_bif" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"APB_SEC_Q" "secondary_q:APB_bif" }

# Re-enable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 1
# Save the SmartDesign 
save_smartdesign -sd_name ${sd_name}
# Generate SmartDesign "LVDT_READOUT"
generate_component -component_name ${sd_name}

















