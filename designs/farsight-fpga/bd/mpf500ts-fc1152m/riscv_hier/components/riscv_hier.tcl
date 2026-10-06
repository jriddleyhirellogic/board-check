# Creating SmartDesign "riscv_hier"
set sd_name {riscv_hier}
create_smartdesign -sd_name ${sd_name}

# Disable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 0

# Create top level Scalar Ports
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_ARREADY} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_AWREADY} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_BID} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_BVALID} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_RID} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_RLAST} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_RVALID} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_WREADY} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_hw_version_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_hw_version_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_hw_version_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_junc_temp_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_junc_temp_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_junc_temp_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_timer_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_timer_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_timer_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_spi_irq} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_trig_irq} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {frame_read_done_irq} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {jtag_tck} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {jtag_tdi} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {jtag_tms} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {jtag_trstb} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pps_irq} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {rst_n_sys_clk_50mhz} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sys_clk_50mhz} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {tmtc_ext_irq} -port_direction {IN}

sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_ARID} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_ARVALID} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_AWID} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_AWVALID} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_BREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_RREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_WLAST} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_WVALID} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_hw_version_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_hw_version_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_junc_temp_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_junc_temp_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {jtag_tdo} -port_direction {OUT}


# Create top level Bus Ports
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_BRESP} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_RDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_RRESP} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb_hw_version_PADDR} -port_direction {IN} -port_range {[4:2]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb_hw_version_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb_junc_temp_PADDR} -port_direction {IN} -port_range {[4:2]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb_junc_temp_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb_timer_PADDR} -port_direction {IN} -port_range {[4:2]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb_timer_PWDATA} -port_direction {IN} -port_range {[31:0]}

sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_ARADDR} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_ARBURST} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_ARCACHE} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_ARLEN} -port_direction {OUT} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_ARLOCK} -port_direction {OUT} -port_range {[0:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_ARPROT} -port_direction {OUT} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_ARSIZE} -port_direction {OUT} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_AWADDR} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_AWBURST} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_AWCACHE} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_AWLEN} -port_direction {OUT} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_AWLOCK} -port_direction {OUT} -port_range {[0:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_AWPROT} -port_direction {OUT} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_AWSIZE} -port_direction {OUT} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_WDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_INITIATOR_AXI_WSTRB} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb_hw_version_PRDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb_junc_temp_PRDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb_timer_PRDATA} -port_direction {OUT} -port_range {[31:0]}


# Create top level Bus interface Ports
sd_create_bif_port -sd_name ${sd_name} -port_name {apb_timer} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:apb_timer_PADDR" \
"PSELx:apb_timer_PSEL" \
"PENABLE:apb_timer_PENABLE" \
"PWRITE:apb_timer_PWRITE" \
"PRDATA:apb_timer_PRDATA" \
"PWDATA:apb_timer_PWDATA" }

sd_create_bif_port -sd_name ${sd_name} -port_name {apb_hw_version} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:apb_hw_version_PADDR" \
"PSELx:apb_hw_version_PSEL" \
"PENABLE:apb_hw_version_PENABLE" \
"PWRITE:apb_hw_version_PWRITE" \
"PRDATA:apb_hw_version_PRDATA" \
"PWDATA:apb_hw_version_PWDATA" \
"PREADY:apb_hw_version_PREADY" \
"PSLVERR:apb_hw_version_PSLVERR" }

sd_create_bif_port -sd_name ${sd_name} -port_name {apb_junc_temp} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:apb_junc_temp_PADDR" \
"PSELx:apb_junc_temp_PSEL" \
"PENABLE:apb_junc_temp_PENABLE" \
"PWRITE:apb_junc_temp_PWRITE" \
"PRDATA:apb_junc_temp_PRDATA" \
"PWDATA:apb_junc_temp_PWDATA" \
"PREADY:apb_junc_temp_PREADY" \
"PSLVERR:apb_junc_temp_PSLVERR" }

sd_create_bif_port -sd_name ${sd_name} -port_name {riscv_axi4_initator} -port_bif_vlnv {AMBA:AMBA4:AXI4:r0p0_0} -port_bif_role {master} -port_bif_mapping {\
"AWID:AXI4_INITIATOR_AXI_AWID" \
"AWADDR:AXI4_INITIATOR_AXI_AWADDR" \
"AWLEN:AXI4_INITIATOR_AXI_AWLEN" \
"AWSIZE:AXI4_INITIATOR_AXI_AWSIZE" \
"AWBURST:AXI4_INITIATOR_AXI_AWBURST" \
"AWLOCK:AXI4_INITIATOR_AXI_AWLOCK" \
"AWCACHE:AXI4_INITIATOR_AXI_AWCACHE" \
"AWPROT:AXI4_INITIATOR_AXI_AWPROT" \
"AWVALID:AXI4_INITIATOR_AXI_AWVALID" \
"AWREADY:AXI4_INITIATOR_AXI_AWREADY" \
"WDATA:AXI4_INITIATOR_AXI_WDATA" \
"WSTRB:AXI4_INITIATOR_AXI_WSTRB" \
"WLAST:AXI4_INITIATOR_AXI_WLAST" \
"WVALID:AXI4_INITIATOR_AXI_WVALID" \
"WREADY:AXI4_INITIATOR_AXI_WREADY" \
"BID:AXI4_INITIATOR_AXI_BID" \
"BRESP:AXI4_INITIATOR_AXI_BRESP" \
"BVALID:AXI4_INITIATOR_AXI_BVALID" \
"BREADY:AXI4_INITIATOR_AXI_BREADY" \
"ARID:AXI4_INITIATOR_AXI_ARID" \
"ARADDR:AXI4_INITIATOR_AXI_ARADDR" \
"ARLEN:AXI4_INITIATOR_AXI_ARLEN" \
"ARSIZE:AXI4_INITIATOR_AXI_ARSIZE" \
"ARBURST:AXI4_INITIATOR_AXI_ARBURST" \
"ARLOCK:AXI4_INITIATOR_AXI_ARLOCK" \
"ARCACHE:AXI4_INITIATOR_AXI_ARCACHE" \
"ARPROT:AXI4_INITIATOR_AXI_ARPROT" \
"ARVALID:AXI4_INITIATOR_AXI_ARVALID" \
"ARREADY:AXI4_INITIATOR_AXI_ARREADY" \
"RID:AXI4_INITIATOR_AXI_RID" \
"RDATA:AXI4_INITIATOR_AXI_RDATA" \
"RRESP:AXI4_INITIATOR_AXI_RRESP" \
"RLAST:AXI4_INITIATOR_AXI_RLAST" \
"RVALID:AXI4_INITIATOR_AXI_RVALID" \
"RREADY:AXI4_INITIATOR_AXI_RREADY" } 

# Add CoreTimer_C0_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {CoreTimer_C0} -instance_name {CoreTimer_C0_inst}



# Add hw_version_apb_reg_inst instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {hw_version_apb_reg} -instance_name {hw_version_apb_reg_inst}
# Exporting Parameters of instance hw_version_apb_reg_inst
sd_configure_core_instance -sd_name ${sd_name} -instance_name {hw_version_apb_reg_inst} -params {\
"APB_ADDR_WIDTH:32" \
"APB_DATA_WIDTH:32" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {hw_version_apb_reg_inst}
sd_update_instance -sd_name ${sd_name} -instance_name {hw_version_apb_reg_inst}



# Add junc_temp_inst instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {junc_temp} -instance_name {junc_temp_inst}
# Exporting Parameters of instance junc_temp_inst
sd_configure_core_instance -sd_name ${sd_name} -instance_name {junc_temp_inst} -params {\
"APB_ADDR_WIDTH:32" \
"APB_DATA_WIDTH:32" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {junc_temp_inst}
sd_update_instance -sd_name ${sd_name} -instance_name {junc_temp_inst}



# Add jtag_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {COREJTAGDEBUG_C0} -instance_name {jtag_inst}



# Add riscv_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {MIV_RV32_C0} -instance_name {riscv_inst}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {riscv_inst:MSYS_EI} -pin_slices {[0:0]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {riscv_inst:MSYS_EI} -pin_slices {[1:1]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {riscv_inst:MSYS_EI} -pin_slices {[2:2]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {riscv_inst:MSYS_EI} -pin_slices {[3:3]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {riscv_inst:MSYS_EI} -pin_slices {[4:4]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {riscv_inst:MSYS_EI} -pin_slices {[5:5]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {riscv_inst:EXT_RESETN}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {riscv_inst:TIME_COUNT_OUT}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {riscv_inst:JTAG_TDO_DR}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {riscv_inst:EXT_IRQ} -value {GND}



# Add riscv_sram instance
sd_instantiate_component -sd_name ${sd_name} -component_name {PF_SRAM_AHBL_AXI_C0} -instance_name {riscv_sram}



# Add scalar net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"CoreTimer_C0_inst:PCLK" "hw_version_apb_reg_inst:pclk" "junc_temp_inst:pclk" "riscv_inst:CLK" "riscv_sram:HCLK" "sys_clk_50mhz" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CoreTimer_C0_inst:PRESETn" "hw_version_apb_reg_inst:presetn" "junc_temp_inst:presetn" "riscv_inst:RESETN" "riscv_sram:HRESETN" "rst_n_sys_clk_50mhz" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CoreTimer_C0_inst:TIMINT" "riscv_inst:MSYS_EI[0:0]" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_spi_irq" "riscv_inst:MSYS_EI[2:2]" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_trig_irq" "riscv_inst:MSYS_EI[3:3]" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"frame_read_done_irq" "riscv_inst:MSYS_EI[5:5]" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"jtag_inst:TCK" "jtag_tck" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"jtag_inst:TDI" "jtag_tdi" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"jtag_inst:TDO" "jtag_tdo" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"jtag_inst:TGT_TCK_0" "riscv_inst:JTAG_TCK" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"jtag_inst:TGT_TDI_0" "riscv_inst:JTAG_TDI" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"jtag_inst:TGT_TDO_0" "riscv_inst:JTAG_TDO" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"jtag_inst:TGT_TMS_0" "riscv_inst:JTAG_TMS" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"jtag_inst:TGT_TRSTN_0" "riscv_inst:JTAG_TRSTN" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"jtag_inst:TMS" "jtag_tms" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"jtag_inst:TRSTB" "jtag_trstb" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pps_irq" "riscv_inst:MSYS_EI[4:4]" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"riscv_inst:MSYS_EI[1:1]" "tmtc_ext_irq" }


# Add bus interface net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"CoreTimer_C0_inst:APBslave" "apb_timer" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb_hw_version" "hw_version_apb_reg_inst:s_apb" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb_junc_temp" "junc_temp_inst:s_apb" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"riscv_axi4_initator" "riscv_inst:AXI4_INITIATOR" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"riscv_inst:AHBL_M_TARGET" "riscv_sram:AHBSlaveInterface" }

# Re-enable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 1
# Save the SmartDesign 
save_smartdesign -sd_name ${sd_name}
# Generate SmartDesign "riscv_hier"
generate_component -component_name ${sd_name}
