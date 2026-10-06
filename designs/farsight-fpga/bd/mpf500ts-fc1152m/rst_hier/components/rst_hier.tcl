# Creating SmartDesign "rst_hier"
set sd_name {rst_hier}
create_smartdesign -sd_name ${sd_name}

# Disable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 0

# Create top level Scalar Ports
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_async_rst_ddr4_16gb_APB_bif_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_async_rst_ddr4_16gb_APB_bif_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_async_rst_ddr4_16gb_APB_bif_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_async_rst_ddr4_8gb_APB_bif_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_async_rst_ddr4_8gb_APB_bif_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_async_rst_ddr4_8gb_APB_bif_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {clk_100mhz} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_16gb_clk} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_16gb_ctrlr_ready} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_16gb_pll_lock} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_clk} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_ctrlr_ready} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_pll_lock} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pcs_arst_n} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pixel_clk_79p2mhz_pll_lock} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pixel_clk_79p2mhz} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sys_clk_50mhz_pll_lock} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sys_clk_50mhz} -port_direction {IN}

sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_async_rst_ddr4_16gb_APB_bif_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_async_rst_ddr4_16gb_APB_bif_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_async_rst_ddr4_8gb_APB_bif_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_async_rst_ddr4_8gb_APB_bif_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pcie_init_done} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pixel_rst_n} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {rst_n_100mhz_clk_domain} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {rst_n_ddr4_16gb_clk_domain} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {rst_n_ddr4_8gb_clk_domain} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {rst_n_sys_clk_50mhz} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {xcvr_init_done} -port_direction {OUT}


# Create top level Bus Ports
sd_create_bus_port -sd_name ${sd_name} -port_name {apb_async_rst_ddr4_16gb_APB_bif_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb_async_rst_ddr4_16gb_APB_bif_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb_async_rst_ddr4_8gb_APB_bif_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb_async_rst_ddr4_8gb_APB_bif_PWDATA} -port_direction {IN} -port_range {[31:0]}

sd_create_bus_port -sd_name ${sd_name} -port_name {apb_async_rst_ddr4_16gb_APB_bif_PRDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb_async_rst_ddr4_8gb_APB_bif_PRDATA} -port_direction {OUT} -port_range {[31:0]}


# Create top level Bus interface Ports
sd_create_bif_port -sd_name ${sd_name} -port_name {apb_async_rst_ddr4_8gb} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:apb_async_rst_ddr4_8gb_APB_bif_PADDR" \
"PSELx:apb_async_rst_ddr4_8gb_APB_bif_PSEL" \
"PENABLE:apb_async_rst_ddr4_8gb_APB_bif_PENABLE" \
"PWRITE:apb_async_rst_ddr4_8gb_APB_bif_PWRITE" \
"PRDATA:apb_async_rst_ddr4_8gb_APB_bif_PRDATA" \
"PWDATA:apb_async_rst_ddr4_8gb_APB_bif_PWDATA" \
"PREADY:apb_async_rst_ddr4_8gb_APB_bif_PREADY" \
"PSLVERR:apb_async_rst_ddr4_8gb_APB_bif_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb_async_rst_ddr4_16gb} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:apb_async_rst_ddr4_16gb_APB_bif_PADDR" \
"PSELx:apb_async_rst_ddr4_16gb_APB_bif_PSEL" \
"PENABLE:apb_async_rst_ddr4_16gb_APB_bif_PENABLE" \
"PWRITE:apb_async_rst_ddr4_16gb_APB_bif_PWRITE" \
"PRDATA:apb_async_rst_ddr4_16gb_APB_bif_PRDATA" \
"PWDATA:apb_async_rst_ddr4_16gb_APB_bif_PWDATA" \
"PREADY:apb_async_rst_ddr4_16gb_APB_bif_PREADY" \
"PSLVERR:apb_async_rst_ddr4_16gb_APB_bif_PSLVERR" } 

# Add init_monitor_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {PF_INIT_MONITOR_C0} -instance_name {init_monitor_inst}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {init_monitor_inst:USRAM_INIT_DONE}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {init_monitor_inst:SRAM_INIT_DONE}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {init_monitor_inst:USRAM_INIT_FROM_SNVM_DONE}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {init_monitor_inst:USRAM_INIT_FROM_UPROM_DONE}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {init_monitor_inst:USRAM_INIT_FROM_SPI_DONE}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {init_monitor_inst:SRAM_INIT_FROM_SNVM_DONE}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {init_monitor_inst:SRAM_INIT_FROM_UPROM_DONE}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {init_monitor_inst:SRAM_INIT_FROM_SPI_DONE}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {init_monitor_inst:AUTOCALIB_DONE}



# Add rst_clk_100mhz_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {CORERESET_PF_C0} -instance_name {rst_clk_100mhz_inst}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {rst_clk_100mhz_inst:EXT_RST_N} -value {VCC}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {rst_clk_100mhz_inst:BANK_x_VDDI_STATUS} -value {VCC}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {rst_clk_100mhz_inst:BANK_y_VDDI_STATUS} -value {VCC}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {rst_clk_100mhz_inst:SS_BUSY} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {rst_clk_100mhz_inst:FF_US_RESTORE} -value {GND}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {rst_clk_100mhz_inst:PLL_POWERDOWN_B}



# Add rst_ddr4_hier_8gb_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {rst_ddr4_hier} -instance_name {rst_ddr4_hier_8gb_inst}



# Add rst_ddr4_hier_16gb_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {rst_ddr4_hier} -instance_name {rst_ddr4_hier_16gb_inst}



# Add rst_slvsec_pixel_clk_domain_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {CORERESET_PF_C3} -instance_name {rst_slvsec_pixel_clk_domain_inst}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {rst_slvsec_pixel_clk_domain_inst:BANK_x_VDDI_STATUS} -value {VCC}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {rst_slvsec_pixel_clk_domain_inst:BANK_y_VDDI_STATUS} -value {VCC}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {rst_slvsec_pixel_clk_domain_inst:SS_BUSY} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {rst_slvsec_pixel_clk_domain_inst:FF_US_RESTORE} -value {GND}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {rst_slvsec_pixel_clk_domain_inst:PLL_POWERDOWN_B}



# Add rst_sys_clk_50mhz_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {CORERESET_PF_SYS_CLK_50MHZ} -instance_name {rst_sys_clk_50mhz_inst}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {rst_sys_clk_50mhz_inst:EXT_RST_N} -value {VCC}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {rst_sys_clk_50mhz_inst:BANK_x_VDDI_STATUS} -value {VCC}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {rst_sys_clk_50mhz_inst:BANK_y_VDDI_STATUS} -value {VCC}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {rst_sys_clk_50mhz_inst:SS_BUSY} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {rst_sys_clk_50mhz_inst:FF_US_RESTORE} -value {GND}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {rst_sys_clk_50mhz_inst:PLL_POWERDOWN_B}



# Add scalar net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"clk_100mhz" "rst_clk_100mhz_inst:CLK" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_clk" "rst_ddr4_hier_16gb_inst:ddr4_clk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_ctrlr_ready" "rst_ddr4_hier_16gb_inst:ddr4_ctrlr_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_pll_lock" "rst_ddr4_hier_16gb_inst:ddr4_pll_lock" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_clk" "rst_ddr4_hier_8gb_inst:ddr4_clk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_ctrlr_ready" "rst_ddr4_hier_8gb_inst:ddr4_ctrlr_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_pll_lock" "rst_ddr4_hier_8gb_inst:ddr4_pll_lock" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"init_monitor_inst:BANK_0_VDDI_STATUS" "rst_ddr4_hier_16gb_inst:BANK_x_VDDI_STATUS" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"init_monitor_inst:BANK_6_VDDI_STATUS" "rst_ddr4_hier_8gb_inst:BANK_x_VDDI_STATUS" "rst_ddr4_hier_8gb_inst:BANK_y_VDDI_STATUS" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"init_monitor_inst:BANK_7_VDDI_STATUS" "rst_ddr4_hier_16gb_inst:BANK_y_VDDI_STATUS" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"init_monitor_inst:DEVICE_INIT_DONE" "rst_clk_100mhz_inst:INIT_DONE" "rst_sys_clk_50mhz_inst:INIT_DONE" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"init_monitor_inst:FABRIC_POR_N" "rst_clk_100mhz_inst:FPGA_POR_N" "rst_ddr4_hier_16gb_inst:FABRIC_POR_N" "rst_ddr4_hier_8gb_inst:FABRIC_POR_N" "rst_slvsec_pixel_clk_domain_inst:FPGA_POR_N" "rst_sys_clk_50mhz_inst:FPGA_POR_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"init_monitor_inst:PCIE_INIT_DONE" "pcie_init_done" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"init_monitor_inst:XCVR_INIT_DONE" "rst_slvsec_pixel_clk_domain_inst:INIT_DONE" "xcvr_init_done" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pcs_arst_n" "rst_slvsec_pixel_clk_domain_inst:EXT_RST_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pixel_clk_79p2mhz" "rst_slvsec_pixel_clk_domain_inst:CLK" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pixel_clk_79p2mhz_pll_lock" "rst_slvsec_pixel_clk_domain_inst:PLL_LOCK" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pixel_rst_n" "rst_slvsec_pixel_clk_domain_inst:FABRIC_RESET_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"rst_clk_100mhz_inst:FABRIC_RESET_N" "rst_n_100mhz_clk_domain" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"rst_clk_100mhz_inst:PLL_LOCK" "rst_sys_clk_50mhz_inst:PLL_LOCK" "sys_clk_50mhz_pll_lock" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"rst_ddr4_hier_16gb_inst:rst_n_ddr4_clk_domain" "rst_n_ddr4_16gb_clk_domain" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"rst_ddr4_hier_16gb_inst:rst_n_sys_clk_50mhz" "rst_ddr4_hier_8gb_inst:rst_n_sys_clk_50mhz" "rst_n_sys_clk_50mhz" "rst_sys_clk_50mhz_inst:FABRIC_RESET_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"rst_ddr4_hier_16gb_inst:sys_clk_50mhz" "rst_ddr4_hier_8gb_inst:sys_clk_50mhz" "rst_sys_clk_50mhz_inst:CLK" "sys_clk_50mhz" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"rst_ddr4_hier_8gb_inst:rst_n_ddr4_clk_domain" "rst_n_ddr4_8gb_clk_domain" }


# Add bus interface net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb_async_rst_ddr4_16gb" "rst_ddr4_hier_16gb_inst:apb_async_rst_ddr4" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb_async_rst_ddr4_8gb" "rst_ddr4_hier_8gb_inst:apb_async_rst_ddr4" }

# Re-enable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 1
# Save the SmartDesign 
save_smartdesign -sd_name ${sd_name}
# Generate SmartDesign "rst_hier"
generate_component -component_name ${sd_name}
