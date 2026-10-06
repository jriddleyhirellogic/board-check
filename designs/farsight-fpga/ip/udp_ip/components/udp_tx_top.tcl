# Exporting core udp_tx_top to TCL
# Exporting Create HDL core command for module udp_tx_top
create_hdl_core -file "[file normalize [file join [file dirname [info script]] ./../src/udp_tx_top.sv]]" -module {udp_tx_top} -library {work} -package {}
# Exporting BIF information of  HDL core command for module udp_tx_top
hdl_core_add_bif -hdl_core_name {udp_tx_top} -bif_definition {AXI4Stream:AMBA:AMBA4:slave} -bif_name {S_AXIS_UDP_PYL} -signal_map {\
"TVALID:s_axis_udp_pyl_tvalid" \
"TREADY:s_axis_udp_pyl_tready" \
"TDATA:s_axis_udp_pyl_tdata" \
"TKEEP:s_axis_udp_pyl_tkeep" \
"TLAST:s_axis_udp_pyl_tlast" }
hdl_core_add_bif -hdl_core_name {udp_tx_top} -bif_definition {AXI4Stream:AMBA:AMBA4:slave} -bif_name {S_AXIS_UDP_PYL_SIZE} -signal_map {\
"TVALID:udp_pyl_size_valid" \
"TREADY:udp_pyl_size_ready" \
"TDATA:udp_pyl_size" }
