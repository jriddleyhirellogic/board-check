# Creating SmartDesign "ddr4_8gb_hier"
set sd_name {ddr4_8gb_hier}
create_smartdesign -sd_name ${sd_name}

# Disable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 0

# Create top level Scalar Ports
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_rst_n} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_ARVALID} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_AWVALID} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_BREADY} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_RREADY} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_WLAST} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_WVALID} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pll_ref_clk_50mhz} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sys_rst_n} -port_direction {IN}

sd_create_scalar_port -sd_name ${sd_name} -port_name {ACT_N} -port_direction {OUT} -port_is_pad {1}
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
sd_create_scalar_port -sd_name ${sd_name} -port_name {WE_N} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_clk} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_ctrlr_ready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_pll_lock} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_ARREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_AWREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_BVALID} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_RLAST} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_RVALID} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_WREADY} -port_direction {OUT}


# Create top level Bus Ports
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_ARADDR} -port_direction {IN} -port_range {[37:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_ARBURST} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_ARID} -port_direction {IN} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_ARLEN} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_ARSIZE} -port_direction {IN} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_AWADDR} -port_direction {IN} -port_range {[37:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_AWBURST} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_AWID} -port_direction {IN} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_AWLEN} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_AWSIZE} -port_direction {IN} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_WDATA} -port_direction {IN} -port_range {[255:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_WSTRB} -port_direction {IN} -port_range {[31:0]}

sd_create_bus_port -sd_name ${sd_name} -port_name {A} -port_direction {OUT} -port_range {[13:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {BA} -port_direction {OUT} -port_range {[1:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {BG} -port_direction {OUT} -port_range {[1:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {DM_N} -port_direction {OUT} -port_range {[4:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_BID} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_BRESP} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_RDATA} -port_direction {OUT} -port_range {[255:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_RID} -port_direction {OUT} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm_RRESP} -port_direction {OUT} -port_range {[1:0]}

sd_create_bus_port -sd_name ${sd_name} -port_name {DQS_N} -port_direction {INOUT} -port_range {[4:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {DQS} -port_direction {INOUT} -port_range {[4:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {DQ} -port_direction {INOUT} -port_range {[39:0]} -port_is_pad {1}

# Create top level Bus interface Ports
sd_create_bif_port -sd_name ${sd_name} -port_name {ddr4_8gb_s_aximm} -port_bif_vlnv {AMBA:AMBA4:AXI4:r0p0_0} -port_bif_role {slave} -port_bif_mapping {\
"AWID:ddr4_8gb_s_aximm_AWID" \
"AWADDR:ddr4_8gb_s_aximm_AWADDR" \
"AWLEN:ddr4_8gb_s_aximm_AWLEN" \
"AWSIZE:ddr4_8gb_s_aximm_AWSIZE" \
"AWBURST:ddr4_8gb_s_aximm_AWBURST" \
"AWVALID:ddr4_8gb_s_aximm_AWVALID" \
"AWREADY:ddr4_8gb_s_aximm_AWREADY" \
"WDATA:ddr4_8gb_s_aximm_WDATA" \
"WSTRB:ddr4_8gb_s_aximm_WSTRB" \
"WLAST:ddr4_8gb_s_aximm_WLAST" \
"WVALID:ddr4_8gb_s_aximm_WVALID" \
"WREADY:ddr4_8gb_s_aximm_WREADY" \
"BID:ddr4_8gb_s_aximm_BID" \
"BRESP:ddr4_8gb_s_aximm_BRESP" \
"BVALID:ddr4_8gb_s_aximm_BVALID" \
"BREADY:ddr4_8gb_s_aximm_BREADY" \
"ARID:ddr4_8gb_s_aximm_ARID" \
"ARADDR:ddr4_8gb_s_aximm_ARADDR" \
"ARLEN:ddr4_8gb_s_aximm_ARLEN" \
"ARSIZE:ddr4_8gb_s_aximm_ARSIZE" \
"ARBURST:ddr4_8gb_s_aximm_ARBURST" \
"ARVALID:ddr4_8gb_s_aximm_ARVALID" \
"ARREADY:ddr4_8gb_s_aximm_ARREADY" \
"RID:ddr4_8gb_s_aximm_RID" \
"RDATA:ddr4_8gb_s_aximm_RDATA" \
"RRESP:ddr4_8gb_s_aximm_RRESP" \
"RLAST:ddr4_8gb_s_aximm_RLAST" \
"RVALID:ddr4_8gb_s_aximm_RVALID" \
"RREADY:ddr4_8gb_s_aximm_RREADY" }

# Add ddr4_8gb_axi_to_native_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {COREDDR_LITEAXI_C1} -instance_name {ddr4_8gb_axi_to_native_inst}
sd_create_pin_group -sd_name ${sd_name} -group_name {DDR4_NATIVE} -instance_name {ddr4_8gb_axi_to_native_inst} -pin_names {"L_R_REQ" "L_DATAOUT" "L_D_REQ" "L_R_VALID" "L_BUSY" "L_W_REQ" "L_ADDR" "L_B_SIZE" "L_DATAIN" "L_DM_IN" }



# Add ddr4_inst2_se instance
sd_instantiate_component -sd_name ${sd_name} -component_name {PF_DDR4_C2} -instance_name {ddr4_inst2_se}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {ddr4_inst2_se:l_auto_pch_p0} -value {VCC}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {ddr4_inst2_se:l_r_valid_last_p0}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {ddr4_inst2_se:l_d_req_last_p0}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {ddr4_inst2_se:ECC_ERROR_1BIT}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {ddr4_inst2_se:ECC_ERROR_2BIT}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {ddr4_inst2_se:ECC_ERROR_POS}



# Add scalar net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"ACT_N" "ddr4_inst2_se:ACT_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CAS_N" "ddr4_inst2_se:CAS_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CK0" "ddr4_inst2_se:CK0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CK0_N" "ddr4_inst2_se:CK0_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CKE" "ddr4_inst2_se:CKE" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CS_N" "ddr4_inst2_se:CS_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ODT" "ddr4_inst2_se:ODT" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"RAS_N" "ddr4_inst2_se:RAS_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"RESET_N" "ddr4_inst2_se:RESET_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"SHIELD0" "ddr4_inst2_se:SHIELD0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"SHIELD1" "ddr4_inst2_se:SHIELD1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"SHIELD2" "ddr4_inst2_se:SHIELD2" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"SHIELD3" "ddr4_inst2_se:SHIELD3" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"SHIELD4" "ddr4_inst2_se:SHIELD4" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"WE_N" "ddr4_inst2_se:WE_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_axi_to_native_inst:ACLK" "ddr4_8gb_clk" "ddr4_inst2_se:SYS_CLK" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_axi_to_native_inst:ARESET_N" "ddr4_8gb_rst_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_axi_to_native_inst:L_BUSY" "ddr4_inst2_se:l_busy_p0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_axi_to_native_inst:L_D_REQ" "ddr4_inst2_se:l_d_req_p0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_axi_to_native_inst:L_R_REQ" "ddr4_inst2_se:l_r_req_p0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_axi_to_native_inst:L_R_VALID" "ddr4_inst2_se:l_r_valid_p0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_axi_to_native_inst:L_W_REQ" "ddr4_inst2_se:l_w_req_p0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_ctrlr_ready" "ddr4_inst2_se:CTRLR_READY" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_pll_lock" "ddr4_inst2_se:PLL_LOCK" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_inst2_se:PLL_REF_CLK" "pll_ref_clk_50mhz" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_inst2_se:SYS_RESET_N" "sys_rst_n" }

# Add bus net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"A" "ddr4_inst2_se:A" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BA" "ddr4_inst2_se:BA" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BG" "ddr4_inst2_se:BG" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"DM_N" "ddr4_inst2_se:DM_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"DQ" "ddr4_inst2_se:DQ" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"DQS" "ddr4_inst2_se:DQS" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"DQS_N" "ddr4_inst2_se:DQS_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_axi_to_native_inst:L_ADDR" "ddr4_inst2_se:l_addr_p0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_axi_to_native_inst:L_B_SIZE" "ddr4_inst2_se:l_b_size_p0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_axi_to_native_inst:L_DATAIN" "ddr4_inst2_se:l_datain_p0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_axi_to_native_inst:L_DATAOUT" "ddr4_inst2_se:l_dataout" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_axi_to_native_inst:L_DM_IN" "ddr4_inst2_se:l_dm_in_p0" }

# Add bus interface net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_axi_to_native_inst:AXI4_SLAVE" "ddr4_8gb_s_aximm" }

# Re-enable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 1
# Save the SmartDesign
save_smartdesign -sd_name ${sd_name}
# Generate SmartDesign "ddr4_8gb_hier"
generate_component -component_name ${sd_name}
