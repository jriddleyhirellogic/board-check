# Creating SmartDesign "udp_hier"
set sd_name {udp_hier}
create_smartdesign -sd_name ${sd_name}

# Disable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 0

# Create top level Scalar Ports
sd_create_scalar_port -sd_name ${sd_name} -port_name {MRXEOF} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {MRXRDY} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {MRXSOF} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {MTXACPT} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {S_AXIS_IMG_FRAME_PYL_SIZE_DDR4_16GB_ddr4_16gb_img_frame_udp_pyl_size_valid} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {S_AXIS_IMG_FRAME_PYL_SIZE_DDR4_8GB_ddr4_8gb_img_frame_udp_pyl_size_valid} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {S_AXIS_IMG_FRAM_PYL_DDR4_16GB_ddr4_16gb_img_frame_s_udp_pyl_axis_tlast} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {S_AXIS_IMG_FRAM_PYL_DDR4_16GB_ddr4_16gb_img_frame_s_udp_pyl_axis_tvalid} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {S_AXIS_IMG_FRAM_PYL_DDR4_8GB_ddr4_8gb_img_frame_s_udp_pyl_axis_tlast} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {S_AXIS_IMG_FRAM_PYL_DDR4_8GB_ddr4_8gb_img_frame_s_udp_pyl_axis_tvalid} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_16gb_img_frame_sof_req} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_img_frame_sof_req} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pclk} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {presetn} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {udp_clk_100mhz} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {udp_rst_n} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {udp_tx_reg_apb_penable} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {udp_tx_reg_apb_psel} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {udp_tx_reg_apb_pwrite} -port_direction {IN}

sd_create_scalar_port -sd_name ${sd_name} -port_name {MRXACPT} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {MTXEOF} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {MTXRDY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {MTXSOF} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {S_AXIS_IMG_FRAME_PYL_SIZE_DDR4_16GB_ddr4_16gb_img_frame_udp_pyl_size_ready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {S_AXIS_IMG_FRAME_PYL_SIZE_DDR4_8GB_ddr4_8gb_img_frame_udp_pyl_size_ready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {S_AXIS_IMG_FRAM_PYL_DDR4_16GB_ddr4_16gb_img_frame_s_udp_pyl_axis_tready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {S_AXIS_IMG_FRAM_PYL_DDR4_8GB_ddr4_8gb_img_frame_s_udp_pyl_axis_tready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_16gb_img_frame_core_busy} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_16gb_img_frame_eof_ack} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_16gb_img_frame_pyl_acpt} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_img_frame_core_busy} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_img_frame_eof_ack} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_8gb_img_frame_pyl_acpt} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {udp_tx_reg_apb_pready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {udp_tx_reg_apb_pslverr} -port_direction {OUT}


# Create top level Bus Ports
sd_create_bus_port -sd_name ${sd_name} -port_name {MRXBYTEVALID} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {MRXDAT} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {S_AXIS_IMG_FRAME_PYL_SIZE_DDR4_16GB_ddr4_16gb_img_frame_udp_pyl_size} -port_direction {IN} -port_range {[15:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {S_AXIS_IMG_FRAME_PYL_SIZE_DDR4_8GB_ddr4_8gb_img_frame_udp_pyl_size} -port_direction {IN} -port_range {[15:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {S_AXIS_IMG_FRAM_PYL_DDR4_16GB_ddr4_16gb_img_frame_s_udp_pyl_axis_tdata} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {S_AXIS_IMG_FRAM_PYL_DDR4_16GB_ddr4_16gb_img_frame_s_udp_pyl_axis_tkeep} -port_direction {IN} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {S_AXIS_IMG_FRAM_PYL_DDR4_8GB_ddr4_8gb_img_frame_s_udp_pyl_axis_tdata} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {S_AXIS_IMG_FRAM_PYL_DDR4_8GB_ddr4_8gb_img_frame_s_udp_pyl_axis_tkeep} -port_direction {IN} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {udp_tx_reg_apb_paddr} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {udp_tx_reg_apb_pwdata} -port_direction {IN} -port_range {[31:0]}

sd_create_bus_port -sd_name ${sd_name} -port_name {MTXBYTEVALID} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {MTXDAT} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {udp_mux_sel} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {udp_tx_reg_apb_prdata} -port_direction {OUT} -port_range {[31:0]}


# Create top level Bus interface Ports
sd_create_bif_port -sd_name ${sd_name} -port_name {udp_tx_reg_apb} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:udp_tx_reg_apb_paddr" \
"PSELx:udp_tx_reg_apb_psel" \
"PENABLE:udp_tx_reg_apb_penable" \
"PWRITE:udp_tx_reg_apb_pwrite" \
"PRDATA:udp_tx_reg_apb_prdata" \
"PWDATA:udp_tx_reg_apb_pwdata" \
"PREADY:udp_tx_reg_apb_pready" \
"PSLVERR:udp_tx_reg_apb_pslverr" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {S_AXIS_IMG_FRAME_PYL_SIZE_DDR4_8GB} -port_bif_vlnv {AMBA:AMBA4:AXI4Stream:r0p0_1} -port_bif_role {slave} -port_bif_mapping {\
"TVALID:S_AXIS_IMG_FRAME_PYL_SIZE_DDR4_8GB_ddr4_8gb_img_frame_udp_pyl_size_valid" \
"TREADY:S_AXIS_IMG_FRAME_PYL_SIZE_DDR4_8GB_ddr4_8gb_img_frame_udp_pyl_size_ready" \
"TDATA:S_AXIS_IMG_FRAME_PYL_SIZE_DDR4_8GB_ddr4_8gb_img_frame_udp_pyl_size" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {S_AXIS_IMG_FRAM_PYL_DDR4_16GB} -port_bif_vlnv {AMBA:AMBA4:AXI4Stream:r0p0_1} -port_bif_role {slave} -port_bif_mapping {\
"TVALID:S_AXIS_IMG_FRAM_PYL_DDR4_16GB_ddr4_16gb_img_frame_s_udp_pyl_axis_tvalid" \
"TREADY:S_AXIS_IMG_FRAM_PYL_DDR4_16GB_ddr4_16gb_img_frame_s_udp_pyl_axis_tready" \
"TDATA:S_AXIS_IMG_FRAM_PYL_DDR4_16GB_ddr4_16gb_img_frame_s_udp_pyl_axis_tdata" \
"TKEEP:S_AXIS_IMG_FRAM_PYL_DDR4_16GB_ddr4_16gb_img_frame_s_udp_pyl_axis_tkeep" \
"TLAST:S_AXIS_IMG_FRAM_PYL_DDR4_16GB_ddr4_16gb_img_frame_s_udp_pyl_axis_tlast" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {S_AXIS_IMG_FRAM_PYL_DDR4_8GB} -port_bif_vlnv {AMBA:AMBA4:AXI4Stream:r0p0_1} -port_bif_role {slave} -port_bif_mapping {\
"TVALID:S_AXIS_IMG_FRAM_PYL_DDR4_8GB_ddr4_8gb_img_frame_s_udp_pyl_axis_tvalid" \
"TREADY:S_AXIS_IMG_FRAM_PYL_DDR4_8GB_ddr4_8gb_img_frame_s_udp_pyl_axis_tready" \
"TDATA:S_AXIS_IMG_FRAM_PYL_DDR4_8GB_ddr4_8gb_img_frame_s_udp_pyl_axis_tdata" \
"TKEEP:S_AXIS_IMG_FRAM_PYL_DDR4_8GB_ddr4_8gb_img_frame_s_udp_pyl_axis_tkeep" \
"TLAST:S_AXIS_IMG_FRAM_PYL_DDR4_8GB_ddr4_8gb_img_frame_s_udp_pyl_axis_tlast" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {S_AXIS_IMG_FRAME_PYL_SIZE_DDR4_16GB} -port_bif_vlnv {AMBA:AMBA4:AXI4Stream:r0p0_1} -port_bif_role {slave} -port_bif_mapping {\
"TVALID:S_AXIS_IMG_FRAME_PYL_SIZE_DDR4_16GB_ddr4_16gb_img_frame_udp_pyl_size_valid" \
"TREADY:S_AXIS_IMG_FRAME_PYL_SIZE_DDR4_16GB_ddr4_16gb_img_frame_udp_pyl_size_ready" \
"TDATA:S_AXIS_IMG_FRAME_PYL_SIZE_DDR4_16GB_ddr4_16gb_img_frame_udp_pyl_size" } 



# Add mtx_mux_inst instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {mtx_mux} -instance_name {mtx_mux_inst}
sd_create_pin_group -sd_name ${sd_name} -group_name {UDP_MAC_TX} -instance_name {mtx_mux_inst} -pin_names {"udp_txsof" "udp_txacpt" "udp_txbytevalid" "udp_txdata" "udp_txeof" "udp_txrdy" }
sd_create_pin_group -sd_name ${sd_name} -group_name {MAC_TX} -instance_name {mtx_mux_inst} -pin_names {"MTXSOF" "MTXACPT" "MTXBYTEVALID" "MTXDAT" "MTXEOF" "MTXRDY" }
sd_create_pin_group -sd_name ${sd_name} -group_name {ARP_MAC_TX} -instance_name {mtx_mux_inst} -pin_names {"arp_txbytevalid" "arp_txacpt" "arp_txsof" "arp_txrdy" "arp_txeof" "arp_txdata" }
sd_create_pin_group -sd_name ${sd_name} -group_name {CLK_RST_GRP} -instance_name {mtx_mux_inst} -pin_names {"clk" "rst_n" }
sd_create_pin_group -sd_name ${sd_name} -group_name {CTRL} -instance_name {mtx_mux_inst} -pin_names {"udp_core_busy" "arp_core_busy" }



# Add rsp_top_inst instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {rsp_top} -instance_name {rsp_top_inst}
# Exporting Parameters of instance rsp_top_inst
sd_configure_core_instance -sd_name ${sd_name} -instance_name {rsp_top_inst} -params {\
"CLOCK_FREQ_MHZ:50" \
"IPV4_WIDTH:32" \
"MAC_DATA_WIDTH:32" \
"MAC_WIDTH:48" \
"PHY_INIT_USEC:100" \
"RSP_DATA_WIDTH:128" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {rsp_top_inst}
sd_update_instance -sd_name ${sd_name} -instance_name {rsp_top_inst}
sd_create_pin_group -sd_name ${sd_name} -group_name {ETH_HEADER} -instance_name {rsp_top_inst} -pin_names {"src_mac_valid" "src_mac_addr" }
sd_create_pin_group -sd_name ${sd_name} -group_name {IPH_HEADER} -instance_name {rsp_top_inst} -pin_names {"src_ipv4_addr" "src_ipv4_valid" }
sd_create_pin_group -sd_name ${sd_name} -group_name {MAC_RX} -instance_name {rsp_top_inst} -pin_names {"rxrdy" "rxacpt" "rxsof" "rxbytevalid" "rxeof" "rxdata" }
sd_create_pin_group -sd_name ${sd_name} -group_name {MAC_TX} -instance_name {rsp_top_inst} -pin_names {"txacpt" "txrdy" "txdata" "txeof" "txbytevalid" "txsof" }
sd_create_pin_group -sd_name ${sd_name} -group_name {STATUS} -instance_name {rsp_top_inst} -pin_names {"core_busy" }



# Add udp_mux_inst instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {udp_mux} -instance_name {udp_mux_inst}
sd_create_pin_group -sd_name ${sd_name} -group_name {DDR4_8GB_UDP_CTRL} -instance_name {udp_mux_inst} -pin_names {"ddr4_8gb_img_frame_sof_req" "ddr4_8gb_img_frame_eof_ack" "ddr4_8gb_img_frame_pyl_acpt" "ddr4_8gb_img_frame_core_busy" }
sd_create_pin_group -sd_name ${sd_name} -group_name {DDR4_16GB_UDP_CTRL} -instance_name {udp_mux_inst} -pin_names {"ddr4_16gb_img_frame_sof_req" "ddr4_16gb_img_frame_eof_ack" "ddr4_16gb_img_frame_pyl_acpt" "ddr4_16gb_img_frame_core_busy" }
sd_create_pin_group -sd_name ${sd_name} -group_name {UDP_CTRL} -instance_name {udp_mux_inst} -pin_names {"sof_req" "core_busy" "pyl_acpt" "eof_ack" }



# Add udp_tx_apb_reg_inst instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {udp_tx_apb_reg} -instance_name {udp_tx_apb_reg_inst}
# Exporting Parameters of instance udp_tx_apb_reg_inst
sd_configure_core_instance -sd_name ${sd_name} -instance_name {udp_tx_apb_reg_inst} -params {\
"APB_ADDR_WIDTH:32" \
"APB_DATA_WIDTH:32" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {udp_tx_apb_reg_inst}
sd_update_instance -sd_name ${sd_name} -instance_name {udp_tx_apb_reg_inst}
sd_create_pin_group -sd_name ${sd_name} -group_name {UDP_CTRL} -instance_name {udp_tx_apb_reg_inst} -pin_names {"udp_clr" "mux_sel" "frame_gap" }
sd_create_pin_group -sd_name ${sd_name} -group_name {UDP_HEADER} -instance_name {udp_tx_apb_reg_inst} -pin_names {"udp_hdr_ready" "udp_dst_port" "udp_src_port" "udp_hdr_valid" }
sd_create_pin_group -sd_name ${sd_name} -group_name {IPH_HEADER} -instance_name {udp_tx_apb_reg_inst} -pin_names {"iph_hdr_valid" "dst_ip_addr" "src_ip_addr" "iph_hdr_ready" }
sd_create_pin_group -sd_name ${sd_name} -group_name {ETH_HEADER} -instance_name {udp_tx_apb_reg_inst} -pin_names {"eth_hdr_ready" "dst_mac_addr" "src_mac_addr" "eth_hdr_valid" }
sd_create_pin_group -sd_name ${sd_name} -group_name {UDP_TX_STAT} -instance_name {udp_tx_apb_reg_inst} -pin_names {"wd_timeout_err_count" }



# Add udp_tx_top_inst instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {udp_tx_top} -instance_name {udp_tx_top_inst}
# Exporting Parameters of instance udp_tx_top_inst
sd_configure_core_instance -sd_name ${sd_name} -instance_name {udp_tx_top_inst} -params {\
"CLOCK_FREQ_MHZ:100" \
"ETH_TYPE:2048" \
"IP_FLAGS:0" \
"IP_FRAG_OFFSET:0" \
"IP_ID:1" \
"IP_IHL:5" \
"IP_PROTOCOL:17" \
"IP_TOS:0" \
"IP_TTL:64" \
"IP_VERSION:4" \
"MAX_TIMEOUT_USEC:10000000" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {udp_tx_top_inst}
sd_update_instance -sd_name ${sd_name} -instance_name {udp_tx_top_inst}
sd_create_pin_group -sd_name ${sd_name} -group_name {UDP_HEADER} -instance_name {udp_tx_top_inst} -pin_names {"udp_hdr_ready" "udp_hdr_valid" "udp_dst_port" "udp_src_port" }
sd_create_pin_group -sd_name ${sd_name} -group_name {IPH_HEADER} -instance_name {udp_tx_top_inst} -pin_names {"iph_hdr_ready" "dst_ip_addr" "src_ip_addr" "iph_hdr_valid" }
sd_create_pin_group -sd_name ${sd_name} -group_name {ETH_HEADER} -instance_name {udp_tx_top_inst} -pin_names {"eth_hdr_ready" "dst_mac_addr" "src_mac_addr" "eth_hdr_valid" }
sd_create_pin_group -sd_name ${sd_name} -group_name {UDP_CTRL_STATUS} -instance_name {udp_tx_top_inst} -pin_names {"eof_ack" "core_busy" "pyl_acpt" "sof_req" "wd_timeout_err_count" "clear" "frame_gap" }
sd_create_pin_group -sd_name ${sd_name} -group_name {MTX} -instance_name {udp_tx_top_inst} -pin_names {"MTXRDY" "MTXACPT" "MTXSOF" "MTXBYTEVALID" "MTXEOF" "MTXDAT" }



# Add scalar net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"MRXACPT" "rsp_top_inst:rxacpt" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"MRXEOF" "rsp_top_inst:rxeof" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"MRXRDY" "rsp_top_inst:rxrdy" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"MRXSOF" "rsp_top_inst:rxsof" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"MTXACPT" "mtx_mux_inst:MTXACPT" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"MTXEOF" "mtx_mux_inst:MTXEOF" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"MTXRDY" "mtx_mux_inst:MTXRDY" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"MTXSOF" "mtx_mux_inst:MTXSOF" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"mtx_mux_inst:clk" "rsp_top_inst:clk" "udp_clk_100mhz" "udp_tx_apb_reg_inst:udp_clk" "udp_tx_top_inst:clk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"mtx_mux_inst:rst_n" "rsp_top_inst:rst_n" "udp_rst_n" "udp_tx_apb_reg_inst:udp_rst_n" "udp_tx_top_inst:rst_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_img_frame_core_busy" "udp_mux_inst:ddr4_16gb_img_frame_core_busy" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_img_frame_eof_ack" "udp_mux_inst:ddr4_16gb_img_frame_eof_ack" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_img_frame_pyl_acpt" "udp_mux_inst:ddr4_16gb_img_frame_pyl_acpt" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_img_frame_sof_req" "udp_mux_inst:ddr4_16gb_img_frame_sof_req" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_img_frame_core_busy" "udp_mux_inst:ddr4_8gb_img_frame_core_busy" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_img_frame_eof_ack" "udp_mux_inst:ddr4_8gb_img_frame_eof_ack" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_img_frame_pyl_acpt" "udp_mux_inst:ddr4_8gb_img_frame_pyl_acpt" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_img_frame_sof_req" "udp_mux_inst:ddr4_8gb_img_frame_sof_req" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"mtx_mux_inst:arp_core_busy" "rsp_top_inst:core_busy" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"mtx_mux_inst:arp_txacpt" "rsp_top_inst:txacpt" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"mtx_mux_inst:arp_txeof" "rsp_top_inst:txeof" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"mtx_mux_inst:arp_txrdy" "rsp_top_inst:txrdy" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"mtx_mux_inst:arp_txsof" "rsp_top_inst:txsof" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"mtx_mux_inst:udp_core_busy" "udp_mux_inst:core_busy" "udp_tx_top_inst:core_busy" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"mtx_mux_inst:udp_txacpt" "udp_tx_top_inst:MTXACPT" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"mtx_mux_inst:udp_txeof" "udp_tx_top_inst:MTXEOF" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"mtx_mux_inst:udp_txrdy" "udp_tx_top_inst:MTXRDY" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"mtx_mux_inst:udp_txsof" "udp_tx_top_inst:MTXSOF" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pclk" "udp_tx_apb_reg_inst:pclk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"presetn" "udp_tx_apb_reg_inst:presetn" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"rsp_top_inst:src_ipv4_valid" "udp_tx_apb_reg_inst:iph_hdr_valid" "udp_tx_top_inst:iph_hdr_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"rsp_top_inst:src_mac_valid" "udp_tx_apb_reg_inst:eth_hdr_valid" "udp_tx_top_inst:eth_hdr_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"udp_mux_inst:eof_ack" "udp_tx_top_inst:eof_ack" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"udp_mux_inst:pyl_acpt" "udp_tx_top_inst:pyl_acpt" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"udp_mux_inst:sof_req" "udp_tx_top_inst:sof_req" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"udp_tx_apb_reg_inst:eth_hdr_ready" "udp_tx_top_inst:eth_hdr_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"udp_tx_apb_reg_inst:iph_hdr_ready" "udp_tx_top_inst:iph_hdr_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"udp_tx_apb_reg_inst:udp_clr" "udp_tx_top_inst:clear" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"udp_tx_apb_reg_inst:udp_hdr_ready" "udp_tx_top_inst:udp_hdr_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"udp_tx_apb_reg_inst:udp_hdr_valid" "udp_tx_top_inst:udp_hdr_valid" }

# Add bus net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"MRXBYTEVALID" "rsp_top_inst:rxbytevalid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"MRXDAT" "rsp_top_inst:rxdata" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"MTXBYTEVALID" "mtx_mux_inst:MTXBYTEVALID" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"MTXDAT" "mtx_mux_inst:MTXDAT" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"mtx_mux_inst:arp_txbytevalid" "rsp_top_inst:txbytevalid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"mtx_mux_inst:arp_txdata" "rsp_top_inst:txdata" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"mtx_mux_inst:udp_txbytevalid" "udp_tx_top_inst:MTXBYTEVALID" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"mtx_mux_inst:udp_txdata" "udp_tx_top_inst:MTXDAT" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"rsp_top_inst:src_ipv4_addr" "udp_tx_apb_reg_inst:src_ip_addr" "udp_tx_top_inst:src_ip_addr" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"rsp_top_inst:src_mac_addr" "udp_tx_apb_reg_inst:src_mac_addr" "udp_tx_top_inst:src_mac_addr" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"udp_mux_inst:mux_sel" "udp_mux_sel" "udp_tx_apb_reg_inst:mux_sel" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"udp_tx_apb_reg_inst:dst_ip_addr" "udp_tx_top_inst:dst_ip_addr" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"udp_tx_apb_reg_inst:dst_mac_addr" "udp_tx_top_inst:dst_mac_addr" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"udp_tx_apb_reg_inst:frame_gap" "udp_tx_top_inst:frame_gap" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"udp_tx_apb_reg_inst:udp_dst_port" "udp_tx_top_inst:udp_dst_port" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"udp_tx_apb_reg_inst:udp_src_port" "udp_tx_top_inst:udp_src_port" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"udp_tx_apb_reg_inst:wd_timeout_err_count" "udp_tx_top_inst:wd_timeout_err_count" }

# Add bus interface net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"S_AXIS_IMG_FRAME_PYL_SIZE_DDR4_16GB" "udp_mux_inst:S_AXIS_IMG_FRAME_PYL_SIZE_DDR4_16GB" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"S_AXIS_IMG_FRAME_PYL_SIZE_DDR4_8GB" "udp_mux_inst:S_AXIS_IMG_FRAME_PYL_SIZE_DDR4_8GB" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"S_AXIS_IMG_FRAM_PYL_DDR4_16GB" "udp_mux_inst:S_AXIS_IMG_FRAM_PYL_DDR4_16GB" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"S_AXIS_IMG_FRAM_PYL_DDR4_8GB" "udp_mux_inst:S_AXIS_IMG_FRAM_PYL_DDR4_8GB" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"udp_mux_inst:M_AXIS_UDP_PYL" "udp_tx_top_inst:S_AXIS_UDP_PYL" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"udp_mux_inst:M_AXIS_UDP_PYL_SIZE" "udp_tx_top_inst:S_AXIS_UDP_PYL_SIZE" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"udp_tx_apb_reg_inst:s_apb" "udp_tx_reg_apb" }

# Re-enable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 1
# Save the SmartDesign 
save_smartdesign -sd_name ${sd_name}
# Generate SmartDesign "udp_hier"
generate_component -component_name ${sd_name}
