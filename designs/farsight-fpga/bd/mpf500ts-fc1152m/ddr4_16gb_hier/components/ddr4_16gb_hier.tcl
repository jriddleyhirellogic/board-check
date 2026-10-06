# Creating SmartDesign "ddr4_16gb_hier"
set sd_name {ddr4_16gb_hier}
create_smartdesign -sd_name ${sd_name}

# Disable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 0

# Create top level Scalar Ports
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_ARVALID} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_AWVALID} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_BREADY} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_RREADY} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_WLAST} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_WVALID} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_16gb_rst_n} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pll_ref_clk_50mhz} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sys_rst_n} -port_direction {IN}

sd_create_scalar_port -sd_name ${sd_name} -port_name {ACT_N} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_ARREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_AWREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_BVALID} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_RLAST} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_RVALID} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_WREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {CAS_N} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {CK0_N} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {CK0} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {CKE} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {CS_N} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ODT} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {RAS_N} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {RESET_N} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SHIELD0} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SHIELD1} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SHIELD2} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SHIELD3} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SHIELD4} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SHIELD5} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SHIELD6} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SHIELD7} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SHIELD8} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {WE_N} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_16gb_clk} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_16gb_ctrlr_ready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_16gb_pll_lock} -port_direction {OUT}


# Create top level Bus Ports
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_ARADDR} -port_direction {IN} -port_range {[38:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_ARBURST} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_ARID} -port_direction {IN} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_ARLEN} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_ARSIZE} -port_direction {IN} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_AWADDR} -port_direction {IN} -port_range {[38:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_AWBURST} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_AWID} -port_direction {IN} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_AWLEN} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_AWSIZE} -port_direction {IN} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_WDATA} -port_direction {IN} -port_range {[511:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_WSTRB} -port_direction {IN} -port_range {[63:0]}

sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_BID} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_BRESP} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_RDATA} -port_direction {OUT} -port_range {[511:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_RID} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4_SLAVE_RRESP} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {A} -port_direction {OUT} -port_range {[13:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {BA} -port_direction {OUT} -port_range {[1:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {BG} -port_direction {OUT} -port_range {[1:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {DM_N} -port_direction {OUT} -port_range {[8:0]} -port_is_pad {1}

sd_create_bus_port -sd_name ${sd_name} -port_name {DQS_N} -port_direction {INOUT} -port_range {[8:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {DQS} -port_direction {INOUT} -port_range {[8:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {DQ} -port_direction {INOUT} -port_range {[71:0]} -port_is_pad {1}

# Create top level Bus interface Ports
sd_create_bif_port -sd_name ${sd_name} -port_name {ddr4_16gb_s_aximm} -port_bif_vlnv {AMBA:AMBA4:AXI4:r0p0_0} -port_bif_role {slave} -port_bif_mapping {\
"AWID:AXI4_SLAVE_AWID" \
"AWADDR:AXI4_SLAVE_AWADDR" \
"AWLEN:AXI4_SLAVE_AWLEN" \
"AWSIZE:AXI4_SLAVE_AWSIZE" \
"AWBURST:AXI4_SLAVE_AWBURST" \
"AWVALID:AXI4_SLAVE_AWVALID" \
"AWREADY:AXI4_SLAVE_AWREADY" \
"WDATA:AXI4_SLAVE_WDATA" \
"WSTRB:AXI4_SLAVE_WSTRB" \
"WLAST:AXI4_SLAVE_WLAST" \
"WVALID:AXI4_SLAVE_WVALID" \
"WREADY:AXI4_SLAVE_WREADY" \
"BID:AXI4_SLAVE_BID" \
"BRESP:AXI4_SLAVE_BRESP" \
"BVALID:AXI4_SLAVE_BVALID" \
"BREADY:AXI4_SLAVE_BREADY" \
"ARID:AXI4_SLAVE_ARID" \
"ARADDR:AXI4_SLAVE_ARADDR" \
"ARLEN:AXI4_SLAVE_ARLEN" \
"ARSIZE:AXI4_SLAVE_ARSIZE" \
"ARBURST:AXI4_SLAVE_ARBURST" \
"ARVALID:AXI4_SLAVE_ARVALID" \
"ARREADY:AXI4_SLAVE_ARREADY" \
"RID:AXI4_SLAVE_RID" \
"RDATA:AXI4_SLAVE_RDATA" \
"RRESP:AXI4_SLAVE_RRESP" \
"RLAST:AXI4_SLAVE_RLAST" \
"RVALID:AXI4_SLAVE_RVALID" \
"RREADY:AXI4_SLAVE_RREADY" }

# Add ddr4_16gb_axi_to_native_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {COREDDR_LITEAXI_C0} -instance_name {ddr4_16gb_axi_to_native_inst}
sd_create_pin_group -sd_name ${sd_name} -group_name {DDR4_NATIVE} -instance_name {ddr4_16gb_axi_to_native_inst} -pin_names {"L_R_REQ" "L_BUSY" "L_D_REQ" "L_R_VALID" "L_DATAOUT" "L_DM_IN" "L_DATAIN" "L_B_SIZE" "L_ADDR" "L_W_REQ" }



# Add ddr4_inst0_nw instance
sd_instantiate_component -sd_name ${sd_name} -component_name {PF_DDR4_C0} -instance_name {ddr4_inst0_nw}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {ddr4_inst0_nw:l_auto_pch_p0} -value {VCC}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {ddr4_inst0_nw:l_r_valid_last_p0}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {ddr4_inst0_nw:l_d_req_last_p0}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {ddr4_inst0_nw:ECC_ERROR_1BIT}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {ddr4_inst0_nw:ECC_ERROR_2BIT}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {ddr4_inst0_nw:ECC_ERROR_POS}



# Add scalar net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"ACT_N" "ddr4_inst0_nw:ACT_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CAS_N" "ddr4_inst0_nw:CAS_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CK0" "ddr4_inst0_nw:CK0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CK0_N" "ddr4_inst0_nw:CK0_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CKE" "ddr4_inst0_nw:CKE" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CS_N" "ddr4_inst0_nw:CS_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ODT" "ddr4_inst0_nw:ODT" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"RAS_N" "ddr4_inst0_nw:RAS_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"RESET_N" "ddr4_inst0_nw:RESET_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"SHIELD0" "ddr4_inst0_nw:SHIELD0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"SHIELD1" "ddr4_inst0_nw:SHIELD1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"SHIELD2" "ddr4_inst0_nw:SHIELD2" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"SHIELD3" "ddr4_inst0_nw:SHIELD3" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"SHIELD4" "ddr4_inst0_nw:SHIELD4" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"SHIELD5" "ddr4_inst0_nw:SHIELD5" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"SHIELD6" "ddr4_inst0_nw:SHIELD6" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"SHIELD7" "ddr4_inst0_nw:SHIELD7" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"SHIELD8" "ddr4_inst0_nw:SHIELD8" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"WE_N" "ddr4_inst0_nw:WE_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_axi_to_native_inst:ACLK" "ddr4_16gb_clk" "ddr4_inst0_nw:SYS_CLK" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_axi_to_native_inst:ARESET_N" "ddr4_16gb_rst_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_axi_to_native_inst:L_BUSY" "ddr4_inst0_nw:l_busy_p0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_axi_to_native_inst:L_D_REQ" "ddr4_inst0_nw:l_d_req_p0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_axi_to_native_inst:L_R_REQ" "ddr4_inst0_nw:l_r_req_p0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_axi_to_native_inst:L_R_VALID" "ddr4_inst0_nw:l_r_valid_p0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_axi_to_native_inst:L_W_REQ" "ddr4_inst0_nw:l_w_req_p0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_ctrlr_ready" "ddr4_inst0_nw:CTRLR_READY" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_pll_lock" "ddr4_inst0_nw:PLL_LOCK" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_inst0_nw:PLL_REF_CLK" "pll_ref_clk_50mhz" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_inst0_nw:SYS_RESET_N" "sys_rst_n" }

# Add bus net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"A" "ddr4_inst0_nw:A" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BA" "ddr4_inst0_nw:BA" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BG" "ddr4_inst0_nw:BG" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"DM_N" "ddr4_inst0_nw:DM_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"DQ" "ddr4_inst0_nw:DQ" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"DQS" "ddr4_inst0_nw:DQS" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"DQS_N" "ddr4_inst0_nw:DQS_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_axi_to_native_inst:L_ADDR" "ddr4_inst0_nw:l_addr_p0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_axi_to_native_inst:L_B_SIZE" "ddr4_inst0_nw:l_b_size_p0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_axi_to_native_inst:L_DATAIN" "ddr4_inst0_nw:l_datain_p0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_axi_to_native_inst:L_DATAOUT" "ddr4_inst0_nw:l_dataout" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_axi_to_native_inst:L_DM_IN" "ddr4_inst0_nw:l_dm_in_p0" }

# Add bus interface net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_axi_to_native_inst:AXI4_SLAVE" "ddr4_16gb_s_aximm" }

# Re-enable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 1
# Save the SmartDesign
save_smartdesign -sd_name ${sd_name}
# Generate SmartDesign "ddr4_16gb_hier"
generate_component -component_name ${sd_name}
