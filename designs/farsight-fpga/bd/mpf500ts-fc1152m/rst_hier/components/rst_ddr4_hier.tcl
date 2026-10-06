# Creating SmartDesign "rst_ddr4_hier"
set sd_name {rst_ddr4_hier}
create_smartdesign -sd_name ${sd_name}

# Disable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 0

# Create top level Scalar Ports
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_bif_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_bif_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_bif_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {BANK_x_VDDI_STATUS} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {BANK_y_VDDI_STATUS} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {FABRIC_POR_N} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_clk} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_ctrlr_ready} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_pll_lock} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {rst_n_sys_clk_50mhz} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sys_clk_50mhz} -port_direction {IN}

sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_bif_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_bif_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {rst_n_ddr4_clk_domain} -port_direction {OUT}


# Create top level Bus Ports
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_bif_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_bif_PWDATA} -port_direction {IN} -port_range {[31:0]}

sd_create_bus_port -sd_name ${sd_name} -port_name {APB_bif_PRDATA} -port_direction {OUT} -port_range {[31:0]}


# Create top level Bus interface Ports
sd_create_bif_port -sd_name ${sd_name} -port_name {apb_async_rst_ddr4} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:APB_bif_PADDR" \
"PSELx:APB_bif_PSEL" \
"PENABLE:APB_bif_PENABLE" \
"PWRITE:APB_bif_PWRITE" \
"PRDATA:APB_bif_PRDATA" \
"PWDATA:APB_bif_PWDATA" \
"PREADY:APB_bif_PREADY" \
"PSLVERR:APB_bif_PSLVERR" } 

# Add AND2_RST_DDR4_INST instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {AND2} -instance_name {AND2_RST_DDR4_INST}



# Add async_rst_ddr4_coregpio_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {CoreGPIO_C5} -instance_name {async_rst_ddr4_coregpio_inst}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {async_rst_ddr4_coregpio_inst:GPIO_OUT} -pin_slices {[0:0]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {async_rst_ddr4_coregpio_inst:GPIO_OUT} -pin_slices {[31:1]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {async_rst_ddr4_coregpio_inst:GPIO_OUT[31:1]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {async_rst_ddr4_coregpio_inst:INT}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {async_rst_ddr4_coregpio_inst:GPIO_IN} -value {GND}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {async_rst_ddr4_coregpio_inst:GPIO_OE}



# Add INVD_DDR4_ASYNC_RST_N_INST instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {INVD} -instance_name {INVD_DDR4_ASYNC_RST_N_INST}



# Add rst_ddr4_clk_domain_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {CORERESET_PF_C2} -instance_name {rst_ddr4_clk_domain_inst}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {rst_ddr4_clk_domain_inst:SS_BUSY} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {rst_ddr4_clk_domain_inst:FF_US_RESTORE} -value {GND}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {rst_ddr4_clk_domain_inst:PLL_POWERDOWN_B}



# Add scalar net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"AND2_RST_DDR4_INST:A" "INVD_DDR4_ASYNC_RST_N_INST:Y" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"AND2_RST_DDR4_INST:B" "async_rst_ddr4_coregpio_inst:PRESETN" "rst_n_sys_clk_50mhz" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"AND2_RST_DDR4_INST:Y" "rst_ddr4_clk_domain_inst:EXT_RST_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BANK_x_VDDI_STATUS" "rst_ddr4_clk_domain_inst:BANK_x_VDDI_STATUS" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BANK_y_VDDI_STATUS" "rst_ddr4_clk_domain_inst:BANK_y_VDDI_STATUS" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"FABRIC_POR_N" "rst_ddr4_clk_domain_inst:FPGA_POR_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"INVD_DDR4_ASYNC_RST_N_INST:A" "async_rst_ddr4_coregpio_inst:GPIO_OUT[0:0]" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"async_rst_ddr4_coregpio_inst:PCLK" "sys_clk_50mhz" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_clk" "rst_ddr4_clk_domain_inst:CLK" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_ctrlr_ready" "rst_ddr4_clk_domain_inst:INIT_DONE" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_pll_lock" "rst_ddr4_clk_domain_inst:PLL_LOCK" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"rst_ddr4_clk_domain_inst:FABRIC_RESET_N" "rst_n_ddr4_clk_domain" }


# Add bus interface net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb_async_rst_ddr4" "async_rst_ddr4_coregpio_inst:APB_bif" }

# Re-enable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 1
# Save the SmartDesign 
save_smartdesign -sd_name ${sd_name}
# Generate SmartDesign "rst_ddr4_hier"
generate_component -component_name ${sd_name}
