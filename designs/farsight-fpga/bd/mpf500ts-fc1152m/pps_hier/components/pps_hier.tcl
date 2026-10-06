# Creating SmartDesign "pps_hier"
set sd_name {pps_hier}
create_smartdesign -sd_name ${sd_name}

# Disable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 0

# Create top level Scalar Ports
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_pps_penable} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_pps_psel} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_pps_pwrite} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pps_in} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sys_clk_50mhz} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sys_rst_n} -port_direction {IN}

sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_pps_pready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_pps_pslverr} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pps_irq} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pps_out} -port_direction {OUT}


# Create top level Bus Ports
sd_create_bus_port -sd_name ${sd_name} -port_name {apb_pps_paddr} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb_pps_pwdata} -port_direction {IN} -port_range {[31:0]}

sd_create_bus_port -sd_name ${sd_name} -port_name {apb_pps_prdata} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {nanoseconds} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {seconds} -port_direction {OUT} -port_range {[31:0]}


# Create top level Bus interface Ports
sd_create_bif_port -sd_name ${sd_name} -port_name {apb_pps} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:apb_pps_paddr" \
"PSELx:apb_pps_psel" \
"PENABLE:apb_pps_penable" \
"PWRITE:apb_pps_pwrite" \
"PRDATA:apb_pps_prdata" \
"PWDATA:apb_pps_pwdata" \
"PREADY:apb_pps_pready" \
"PSLVERR:apb_pps_pslverr" } 

# Add pps_generator_inst instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {pps_generator} -instance_name {pps_generator_inst}
# Exporting Parameters of instance pps_generator_inst
sd_configure_core_instance -sd_name ${sd_name} -instance_name {pps_generator_inst} -params {\
"CLOCK_FREQ_MHZ:50" \
"POLARITY:1" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {pps_generator_inst}
sd_update_instance -sd_name ${sd_name} -instance_name {pps_generator_inst}



# Add pps_inst instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {pps} -instance_name {pps_inst}
# Exporting Parameters of instance pps_inst
sd_configure_core_instance -sd_name ${sd_name} -instance_name {pps_inst} -params {\
"APB_ADDR_WIDTH:32" \
"APB_DATA_WIDTH:32" \
"CLOCK_PER:20" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {pps_inst}
sd_update_instance -sd_name ${sd_name} -instance_name {pps_inst}



# Add pps_mux_inst instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {pps_mux} -instance_name {pps_mux_inst}



# Add scalar net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"pps_generator_inst:clk" "pps_inst:pclk" "sys_clk_50mhz" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pps_generator_inst:pps_out" "pps_mux_inst:local_pps_in" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pps_generator_inst:rst_n" "pps_inst:presetn" "sys_rst_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pps_in" "pps_inst:extrn_pps_in" "pps_mux_inst:extrn_pps_in" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pps_inst:en_local_pps" "pps_mux_inst:en_local_pps" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pps_inst:pps_in" "pps_mux_inst:pps_out" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pps_inst:pps_irq" "pps_irq" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pps_inst:pps_out" "pps_out" }

# Add bus net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"nanoseconds" "pps_inst:nanoseconds" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pps_inst:seconds" "seconds" }

# Add bus interface net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb_pps" "pps_inst:s_apb" }

# Re-enable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 1
# Save the SmartDesign 
save_smartdesign -sd_name ${sd_name}
# Generate SmartDesign "pps_hier"
generate_component -component_name ${sd_name}
