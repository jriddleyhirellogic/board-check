# Exporting core udp_mux to TCL
# Exporting Create HDL core command for module udp_mux
create_hdl_core -file "[file normalize [file join [file dirname [info script]] ./../src/udp_mux.sv]]" -module {udp_mux} -library {work} -package {}
# Exporting BIF information of  HDL core command for module udp_mux
hdl_core_add_bif -hdl_core_name {udp_mux} -bif_definition {AXI4Stream:AMBA:AMBA4:slave} -bif_name {S_AXIS_IMG_FRAME_PYL_SIZE_DDR4_8GB} -signal_map {\
"TVALID:ddr4_8gb_img_frame_udp_pyl_size_valid" \
"TREADY:ddr4_8gb_img_frame_udp_pyl_size_ready" \
"TDATA:ddr4_8gb_img_frame_udp_pyl_size" }

hdl_core_add_bif -hdl_core_name {udp_mux} -bif_definition {AXI4Stream:AMBA:AMBA4:slave} -bif_name {S_AXIS_IMG_FRAME_PYL_SIZE_DDR4_16GB} -signal_map {\
"TVALID:ddr4_16gb_img_frame_udp_pyl_size_valid" \
"TREADY:ddr4_16gb_img_frame_udp_pyl_size_ready" \
"TDATA:ddr4_16gb_img_frame_udp_pyl_size" }

hdl_core_add_bif -hdl_core_name {udp_mux} -bif_definition {AXI4Stream:AMBA:AMBA4:slave} -bif_name {S_AXIS_IMG_FRAM_PYL_DDR4_8GB} -signal_map {\
"TVALID:ddr4_8gb_img_frame_s_udp_pyl_axis_tvalid" \
"TREADY:ddr4_8gb_img_frame_s_udp_pyl_axis_tready" \
"TDATA:ddr4_8gb_img_frame_s_udp_pyl_axis_tdata" \
"TKEEP:ddr4_8gb_img_frame_s_udp_pyl_axis_tkeep" \
"TLAST:ddr4_8gb_img_frame_s_udp_pyl_axis_tlast" }

hdl_core_add_bif -hdl_core_name {udp_mux} -bif_definition {AXI4Stream:AMBA:AMBA4:slave} -bif_name {S_AXIS_IMG_FRAM_PYL_DDR4_16GB} -signal_map {\
"TVALID:ddr4_16gb_img_frame_s_udp_pyl_axis_tvalid" \
"TREADY:ddr4_16gb_img_frame_s_udp_pyl_axis_tready" \
"TDATA:ddr4_16gb_img_frame_s_udp_pyl_axis_tdata" \
"TKEEP:ddr4_16gb_img_frame_s_udp_pyl_axis_tkeep" \
"TLAST:ddr4_16gb_img_frame_s_udp_pyl_axis_tlast" }

hdl_core_add_bif -hdl_core_name {udp_mux} -bif_definition {AXI4Stream:AMBA:AMBA4:master} -bif_name {M_AXIS_UDP_PYL_SIZE} -signal_map {\
"TVALID:udp_pyl_size_valid" \
"TREADY:udp_pyl_size_ready" \
"TDATA:udp_pyl_size" }

hdl_core_add_bif -hdl_core_name {udp_mux} -bif_definition {AXI4Stream:AMBA:AMBA4:master} -bif_name {M_AXIS_UDP_PYL} -signal_map {\
"TVALID:m_udp_pyl_axis_tvalid" \
"TREADY:m_udp_pyl_axis_tready" \
"TDATA:m_udp_pyl_axis_tdata" \
"TKEEP:m_udp_pyl_axis_tkeep" \
"TLAST:m_udp_pyl_axis_tlast" }
