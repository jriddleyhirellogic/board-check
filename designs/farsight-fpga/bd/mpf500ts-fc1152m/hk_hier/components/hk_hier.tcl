# Creating SmartDesign "hk_hier"
set sd_name {hk_hier}
create_smartdesign -sd_name ${sd_name}

# Disable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 0

# Create top level Scalar Ports
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_bif_PENABLE_1} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_bif_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_bif_PSEL_1} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_bif_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_bif_PWRITE_1} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_bif_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_pwr_status} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr16gb_pwr_status} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr8gb_pwr_status} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_pwr_status} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth2_pwr_status} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {lvds_pwr_status} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {lvdt_pwr_status} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_pwr_status} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc10} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc11} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc12} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc13} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc14} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc15} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc1} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc2} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc3} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc4} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc5} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc6} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc7} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc8} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc9} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pclk} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pf_pwr_status} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {prst_n} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {step_down_pwr_status} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {stepper_pri_pwr_status} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {stepper_sec_pwr_status} -port_direction {IN}

sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_bif_PREADY_1} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_bif_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_bif_PSLVERR_1} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_bif_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_buff_en_n} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_osc_en} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_pwr_en} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_spi_tribuff_en} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_pwr_en} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_pwr_status_out} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth2_pwr_en} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {lvds_pwr_en} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {lvdt_pwr_en} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {stepper_pri_pwr_en} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {stepper_sec_pwr_en} -port_direction {OUT}


# Create top level Bus Ports
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_bif_PADDR_1} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_bif_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_bif_PWDATA_1} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_bif_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {pa3_fw_version} -port_direction {IN} -port_range {[2:0]}

sd_create_bus_port -sd_name ${sd_name} -port_name {APB_bif_PRDATA_1} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_bif_PRDATA} -port_direction {OUT} -port_range {[31:0]}


# Create top level Bus interface Ports
sd_create_bif_port -sd_name ${sd_name} -port_name {gpo_hk_pwr_ctrl_apb} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:APB_bif_PADDR" \
"PSELx:APB_bif_PSEL" \
"PENABLE:APB_bif_PENABLE" \
"PWRITE:APB_bif_PWRITE" \
"PRDATA:APB_bif_PRDATA" \
"PWDATA:APB_bif_PWDATA" \
"PREADY:APB_bif_PREADY" \
"PSLVERR:APB_bif_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {gpi_hk_status_apb} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:APB_bif_PADDR_1" \
"PSELx:APB_bif_PSEL_1" \
"PENABLE:APB_bif_PENABLE_1" \
"PWRITE:APB_bif_PWRITE_1" \
"PRDATA:APB_bif_PRDATA_1" \
"PWDATA:APB_bif_PWDATA_1" \
"PREADY:APB_bif_PREADY_1" \
"PSLVERR:APB_bif_PSLVERR_1" } 

# Add gpi_hk_status_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {CoreGPIO_C1} -instance_name {gpi_hk_status_inst}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[0:0]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[10:10]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[11:11]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[12:12]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[13:13]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[14:14]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[15:15]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[16:16]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[17:17]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[18:18]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[19:19]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[1:1]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[20:20]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[21:21]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[22:22]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[23:23]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[24:24]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[25:25]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[26:26]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[27:27]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[28:28]}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {gpi_hk_status_inst:GPIO_IN[28:28]} -value {GND}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[2:2]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[31:29]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[3:3]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[4:4]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[5:5]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[6:6]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[7:7]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[8:8]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_hk_status_inst:GPIO_IN} -pin_slices {[9:9]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {gpi_hk_status_inst:INT}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {gpi_hk_status_inst:GPIO_OUT}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {gpi_hk_status_inst:GPIO_OE}



# Add gpo_hk_pwr_ctrl_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {CoreGPIO_C3} -instance_name {gpo_hk_pwr_ctrl_inst}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpo_hk_pwr_ctrl_inst:GPIO_OUT} -pin_slices {[0:0]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpo_hk_pwr_ctrl_inst:GPIO_OUT} -pin_slices {[1:1]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpo_hk_pwr_ctrl_inst:GPIO_OUT} -pin_slices {[2:2]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpo_hk_pwr_ctrl_inst:GPIO_OUT} -pin_slices {[31:8]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {gpo_hk_pwr_ctrl_inst:GPIO_OUT[31:8]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpo_hk_pwr_ctrl_inst:GPIO_OUT} -pin_slices {[3:3]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpo_hk_pwr_ctrl_inst:GPIO_OUT} -pin_slices {[4:4]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpo_hk_pwr_ctrl_inst:GPIO_OUT} -pin_slices {[5:5]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpo_hk_pwr_ctrl_inst:GPIO_OUT} -pin_slices {[6:6]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpo_hk_pwr_ctrl_inst:GPIO_OUT} -pin_slices {[7:7]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {gpo_hk_pwr_ctrl_inst:INT}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {gpo_hk_pwr_ctrl_inst:GPIO_IN} -value {GND}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {gpo_hk_pwr_ctrl_inst:GPIO_OE}



# Add inv_cam_buff_en_n_inst instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {INV} -instance_name {inv_cam_buff_en_n_inst}



# Add scalar net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_buff_en_n" "inv_cam_buff_en_n_inst:Y" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_osc_en" "gpo_hk_pwr_ctrl_inst:GPIO_OUT[7:7]" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_pwr_en" "gpo_hk_pwr_ctrl_inst:GPIO_OUT[6:6]" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_pwr_status" "cam_spi_tribuff_en" "gpi_hk_status_inst:GPIO_IN[11:11]" "inv_cam_buff_en_n_inst:A" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr16gb_pwr_status" "gpi_hk_status_inst:GPIO_IN[3:3]" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr8gb_pwr_status" "gpi_hk_status_inst:GPIO_IN[2:2]" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_pwr_en" "gpo_hk_pwr_ctrl_inst:GPIO_OUT[1:1]" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_pwr_status" "eth1_pwr_status_out" "gpi_hk_status_inst:GPIO_IN[6:6]" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth2_pwr_en" "gpo_hk_pwr_ctrl_inst:GPIO_OUT[2:2]" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth2_pwr_status" "gpi_hk_status_inst:GPIO_IN[7:7]" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpi_hk_status_inst:GPIO_IN[0:0]" "pa3_pwr_status" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpi_hk_status_inst:GPIO_IN[10:10]" "lvdt_pwr_status" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpi_hk_status_inst:GPIO_IN[12:12]" "pa3_to_pf_misc0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpi_hk_status_inst:GPIO_IN[13:13]" "pa3_to_pf_misc1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpi_hk_status_inst:GPIO_IN[14:14]" "pa3_to_pf_misc2" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpi_hk_status_inst:GPIO_IN[15:15]" "pa3_to_pf_misc3" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpi_hk_status_inst:GPIO_IN[16:16]" "pa3_to_pf_misc4" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpi_hk_status_inst:GPIO_IN[17:17]" "pa3_to_pf_misc5" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpi_hk_status_inst:GPIO_IN[18:18]" "pa3_to_pf_misc6" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpi_hk_status_inst:GPIO_IN[19:19]" "pa3_to_pf_misc7" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpi_hk_status_inst:GPIO_IN[1:1]" "step_down_pwr_status" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpi_hk_status_inst:GPIO_IN[20:20]" "pa3_to_pf_misc8" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpi_hk_status_inst:GPIO_IN[21:21]" "pa3_to_pf_misc9" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpi_hk_status_inst:GPIO_IN[22:22]" "pa3_to_pf_misc10" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpi_hk_status_inst:GPIO_IN[23:23]" "pa3_to_pf_misc11" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpi_hk_status_inst:GPIO_IN[24:24]" "pa3_to_pf_misc12" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpi_hk_status_inst:GPIO_IN[25:25]" "pa3_to_pf_misc13" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpi_hk_status_inst:GPIO_IN[26:26]" "pa3_to_pf_misc14" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpi_hk_status_inst:GPIO_IN[27:27]" "pa3_to_pf_misc15" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpi_hk_status_inst:GPIO_IN[4:4]" "pf_pwr_status" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpi_hk_status_inst:GPIO_IN[5:5]" "lvds_pwr_status" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpi_hk_status_inst:GPIO_IN[8:8]" "stepper_pri_pwr_status" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpi_hk_status_inst:GPIO_IN[9:9]" "stepper_sec_pwr_status" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpi_hk_status_inst:PCLK" "gpo_hk_pwr_ctrl_inst:PCLK" "pclk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpi_hk_status_inst:PRESETN" "gpo_hk_pwr_ctrl_inst:PRESETN" "prst_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpo_hk_pwr_ctrl_inst:GPIO_OUT[0:0]" "lvds_pwr_en" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpo_hk_pwr_ctrl_inst:GPIO_OUT[3:3]" "stepper_pri_pwr_en" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpo_hk_pwr_ctrl_inst:GPIO_OUT[4:4]" "stepper_sec_pwr_en" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpo_hk_pwr_ctrl_inst:GPIO_OUT[5:5]" "lvdt_pwr_en" }

# Add bus net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpi_hk_status_inst:GPIO_IN[31:29]" "pa3_fw_version" }

# Add bus interface net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpi_hk_status_apb" "gpi_hk_status_inst:APB_bif" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"gpo_hk_pwr_ctrl_apb" "gpo_hk_pwr_ctrl_inst:APB_bif" }

# Re-enable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 1
# Save the SmartDesign 
save_smartdesign -sd_name ${sd_name}
# Generate SmartDesign "hk_hier"
generate_component -component_name ${sd_name}
