# Creating SmartDesign "interconnect_hier"
set sd_name {interconnect_hier}
create_smartdesign -sd_name ${sd_name}

# Disable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 0

# Create top level Scalar Ports
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave0_PREADYS0_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave0_PREADYS0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave0_PSLVERRS0_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave0_PSLVERRS0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave10_PREADYS10} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave10_PSLVERRS10} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave11_PREADYS11} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave11_PSLVERRS11} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave14_PREADYS14} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave14_PSLVERRS14} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave1_PREADYS1_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave1_PREADYS1} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave1_PSLVERRS1_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave1_PSLVERRS1} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave2_PREADYS2} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave2_PSLVERRS2} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave3_PREADYS3} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave3_PSLVERRS3} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave4_PREADYS4} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave4_PSLVERRS4} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave5_PREADYS5} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave5_PSLVERRS5} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave6_PREADYS6} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave6_PSLVERRS6} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave7_PREADYS7} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave7_PSLVERRS7} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave8_PREADYS8} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave8_PSLVERRS8} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave9_PREADYS9} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave9_PSLVERRS9} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_ARVALID} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_AWVALID} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_BREADY} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_RREADY} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_WLAST} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_WVALID} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb0_slave12_PREADYS12} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb0_slave12_PSLVERRS12} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb0_slave13_PREADYS13} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb0_slave13_PSLVERRS13} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb0_slave15_PREADYS15} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb0_slave15_PSLVERRS15} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave10_PREADYS10_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave10_PSLVERRS10_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave11_PREADYS11_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave11_PSLVERRS11_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave12_PREADYS12_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave12_PSLVERRS12_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave3_PREADYS3_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave3_PSLVERRS3_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave4_PREADYS4_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave4_PSLVERRS4_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave5_PREADYS5_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave5_PSLVERRS5_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave6_PREADYS6_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave6_PSLVERRS6_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave7_PREADYS7_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave7_PSLVERRS7_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave8_PREADYS8_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave8_PSLVERRS8_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave9_PREADYS9_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave9_PSLVERRS9_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave0_PREADYS0_1} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave0_PSLVERRS0_1} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave10_PREADYS10_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave10_PSLVERRS10_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave11_PREADYS11_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave11_PSLVERRS11_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave12_PREADYS12} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave12_PSLVERRS12} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave13_PREADYS13} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave13_PSLVERRS13} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave14_PREADYS14} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave14_PSLVERRS14} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave15_PREADYS15} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave15_PSLVERRS15} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave1_PREADYS1_1} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave1_PSLVERRS1_1} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave2_PREADYS2_1} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave2_PSLVERRS2_1} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave3_PREADYS3_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave3_PSLVERRS3_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave4_PREADYS4_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave4_PSLVERRS4_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave5_PREADYS5_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave5_PSLVERRS5_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave6_PREADYS6_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave6_PSLVERRS6_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave7_PREADYS7_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave7_PSLVERRS7_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave8_PREADYS8_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave8_PSLVERRS8_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave9_PREADYS9_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave9_PSLVERRS9_0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {rst_n_sys_clk_50mhz} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sys_clk_50mhz} -port_direction {IN}

sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave0_PENABLES_0} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave0_PENABLES} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave0_PSELS0_0} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave0_PSELS0} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave0_PWRITES_0} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave0_PWRITES} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave10_PSELS10} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave11_PSELS11} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave14_PSELS14} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave1_PSELS1_0} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave1_PSELS1} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave2_PSELS2} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave3_PSELS3} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave4_PSELS4} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave5_PSELS5} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave6_PSELS6} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave7_PSELS7} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave8_PSELS8} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APBmslave9_PSELS9} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_ARREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_AWREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_BVALID} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_RLAST} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_RVALID} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_WREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb0_slave12_PSELS12} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb0_slave13_PSELS13} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb0_slave15_PSELS15} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave10_PSELS10_0} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave11_PSELS11_0} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave12_PSELS12_0} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave3_PSELS3_0} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave4_PSELS4_0} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave5_PSELS5_0} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave6_PSELS6_0} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave7_PSELS7_0} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave8_PSELS8_0} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb1_slave9_PSELS9_0} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave0_PENABLES_1} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave0_PSELS0_1} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave0_PWRITES_1} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave10_PSELS10_0} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave11_PSELS11_0} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave12_PSELS12} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave13_PSELS13} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave14_PSELS14} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave15_PSELS15} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave1_PSELS1_1} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave2_PSELS2_1} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave3_PSELS3_0} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave4_PSELS4_0} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave5_PSELS5_0} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave6_PSELS6_0} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave7_PSELS7_0} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave8_PSELS8_0} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb2_slave9_PSELS9_0} -port_direction {OUT}


# Create top level Bus Ports
sd_create_bus_port -sd_name ${sd_name} -port_name {APBmslave0_PRDATAS0_0} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APBmslave0_PRDATAS0} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APBmslave10_PRDATAS10} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APBmslave11_PRDATAS11} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APBmslave14_PRDATAS14} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APBmslave1_PRDATAS1_0} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APBmslave1_PRDATAS1} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APBmslave2_PRDATAS2} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APBmslave3_PRDATAS3} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APBmslave4_PRDATAS4} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APBmslave5_PRDATAS5} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APBmslave6_PRDATAS6} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APBmslave7_PRDATAS7} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APBmslave8_PRDATAS8} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APBmslave9_PRDATAS9} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_ARADDR} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_ARBURST} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_ARCACHE} -port_direction {IN} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_ARID} -port_direction {IN} -port_range {[0:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_ARLEN} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_ARLOCK} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_ARPROT} -port_direction {IN} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_ARQOS} -port_direction {IN} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_ARREGION} -port_direction {IN} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_ARSIZE} -port_direction {IN} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_ARUSER} -port_direction {IN} -port_range {[0:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_AWADDR} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_AWBURST} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_AWCACHE} -port_direction {IN} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_AWID} -port_direction {IN} -port_range {[0:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_AWLEN} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_AWLOCK} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_AWPROT} -port_direction {IN} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_AWQOS} -port_direction {IN} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_AWREGION} -port_direction {IN} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_AWSIZE} -port_direction {IN} -port_range {[2:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_AWUSER} -port_direction {IN} -port_range {[0:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_WDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_WSTRB} -port_direction {IN} -port_range {[3:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_WUSER} -port_direction {IN} -port_range {[0:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb0_slave12_PRDATAS12} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb0_slave13_PRDATAS13} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb0_slave15_PRDATAS15} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb1_slave10_PRDATAS10_0} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb1_slave11_PRDATAS11_0} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb1_slave12_PRDATAS12_0} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb1_slave3_PRDATAS3_0} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb1_slave4_PRDATAS4_0} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb1_slave5_PRDATAS5_0} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb1_slave6_PRDATAS6_0} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb1_slave7_PRDATAS7_0} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb1_slave8_PRDATAS8_0} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb1_slave9_PRDATAS9_0} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb2_slave0_PRDATAS0_1} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb2_slave10_PRDATAS10_0} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb2_slave11_PRDATAS11_0} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb2_slave12_PRDATAS12} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb2_slave13_PRDATAS13} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb2_slave14_PRDATAS14} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb2_slave15_PRDATAS15} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb2_slave1_PRDATAS1_1} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb2_slave2_PRDATAS2_1} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb2_slave3_PRDATAS3_0} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb2_slave4_PRDATAS4_0} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb2_slave5_PRDATAS5_0} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb2_slave6_PRDATAS6_0} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb2_slave7_PRDATAS7_0} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb2_slave8_PRDATAS8_0} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb2_slave9_PRDATAS9_0} -port_direction {IN} -port_range {[31:0]}

sd_create_bus_port -sd_name ${sd_name} -port_name {APBmslave0_PADDRS_0} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APBmslave0_PADDRS} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APBmslave0_PWDATAS_0} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APBmslave0_PWDATAS} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_BID} -port_direction {OUT} -port_range {[0:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_BRESP} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_BUSER} -port_direction {OUT} -port_range {[0:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_RDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_RID} -port_direction {OUT} -port_range {[0:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_RRESP} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {AXI4mmaster0_MASTER0_RUSER} -port_direction {OUT} -port_range {[0:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb2_slave0_PADDRS_1} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb2_slave0_PWDATAS_1} -port_direction {OUT} -port_range {[31:0]}


# Create top level Bus interface Ports
sd_create_bif_port -sd_name ${sd_name} -port_name {riscv_aximm} -port_bif_vlnv {AMBA:AMBA4:AXI4:r0p0_0} -port_bif_role {mirroredMaster} -port_bif_mapping {\
"AWID:AXI4mmaster0_MASTER0_AWID" \
"AWADDR:AXI4mmaster0_MASTER0_AWADDR" \
"AWLEN:AXI4mmaster0_MASTER0_AWLEN" \
"AWSIZE:AXI4mmaster0_MASTER0_AWSIZE" \
"AWBURST:AXI4mmaster0_MASTER0_AWBURST" \
"AWLOCK:AXI4mmaster0_MASTER0_AWLOCK" \
"AWCACHE:AXI4mmaster0_MASTER0_AWCACHE" \
"AWPROT:AXI4mmaster0_MASTER0_AWPROT" \
"AWQOS:AXI4mmaster0_MASTER0_AWQOS" \
"AWREGION:AXI4mmaster0_MASTER0_AWREGION" \
"AWVALID:AXI4mmaster0_MASTER0_AWVALID" \
"AWREADY:AXI4mmaster0_MASTER0_AWREADY" \
"WDATA:AXI4mmaster0_MASTER0_WDATA" \
"WSTRB:AXI4mmaster0_MASTER0_WSTRB" \
"WLAST:AXI4mmaster0_MASTER0_WLAST" \
"WVALID:AXI4mmaster0_MASTER0_WVALID" \
"WREADY:AXI4mmaster0_MASTER0_WREADY" \
"BID:AXI4mmaster0_MASTER0_BID" \
"BRESP:AXI4mmaster0_MASTER0_BRESP" \
"BVALID:AXI4mmaster0_MASTER0_BVALID" \
"BREADY:AXI4mmaster0_MASTER0_BREADY" \
"ARID:AXI4mmaster0_MASTER0_ARID" \
"ARADDR:AXI4mmaster0_MASTER0_ARADDR" \
"ARLEN:AXI4mmaster0_MASTER0_ARLEN" \
"ARSIZE:AXI4mmaster0_MASTER0_ARSIZE" \
"ARBURST:AXI4mmaster0_MASTER0_ARBURST" \
"ARLOCK:AXI4mmaster0_MASTER0_ARLOCK" \
"ARCACHE:AXI4mmaster0_MASTER0_ARCACHE" \
"ARPROT:AXI4mmaster0_MASTER0_ARPROT" \
"ARQOS:AXI4mmaster0_MASTER0_ARQOS" \
"ARREGION:AXI4mmaster0_MASTER0_ARREGION" \
"ARVALID:AXI4mmaster0_MASTER0_ARVALID" \
"ARREADY:AXI4mmaster0_MASTER0_ARREADY" \
"RID:AXI4mmaster0_MASTER0_RID" \
"RDATA:AXI4mmaster0_MASTER0_RDATA" \
"RRESP:AXI4mmaster0_MASTER0_RRESP" \
"RLAST:AXI4mmaster0_MASTER0_RLAST" \
"RVALID:AXI4mmaster0_MASTER0_RVALID" \
"RREADY:AXI4mmaster0_MASTER0_RREADY" \
"AWUSER:AXI4mmaster0_MASTER0_AWUSER" \
"WUSER:AXI4mmaster0_MASTER0_WUSER" \
"BUSER:AXI4mmaster0_MASTER0_BUSER" \
"ARUSER:AXI4mmaster0_MASTER0_ARUSER" \
"RUSER:AXI4mmaster0_MASTER0_RUSER" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb1_slave0} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS" \
"PSELx:APBmslave0_PSELS0" \
"PENABLE:APBmslave0_PENABLES" \
"PWRITE:APBmslave0_PWRITES" \
"PRDATA:APBmslave0_PRDATAS0" \
"PWDATA:APBmslave0_PWDATAS" \
"PREADY:APBmslave0_PREADYS0" \
"PSLVERR:APBmslave0_PSLVERRS0" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb1_slave1} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS" \
"PSELx:APBmslave1_PSELS1" \
"PENABLE:APBmslave0_PENABLES" \
"PWRITE:APBmslave0_PWRITES" \
"PRDATA:APBmslave1_PRDATAS1" \
"PWDATA:APBmslave0_PWDATAS" \
"PREADY:APBmslave1_PREADYS1" \
"PSLVERR:APBmslave1_PSLVERRS1" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb1_slave2} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS" \
"PSELx:APBmslave2_PSELS2" \
"PENABLE:APBmslave0_PENABLES" \
"PWRITE:APBmslave0_PWRITES" \
"PRDATA:APBmslave2_PRDATAS2" \
"PWDATA:APBmslave0_PWDATAS" \
"PREADY:APBmslave2_PREADYS2" \
"PSLVERR:APBmslave2_PSLVERRS2" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb1_slave3} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS" \
"PSELx:apb1_slave3_PSELS3_0" \
"PENABLE:APBmslave0_PENABLES" \
"PWRITE:APBmslave0_PWRITES" \
"PRDATA:apb1_slave3_PRDATAS3_0" \
"PWDATA:APBmslave0_PWDATAS" \
"PREADY:apb1_slave3_PREADYS3_0" \
"PSLVERR:apb1_slave3_PSLVERRS3_0" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb1_slave4} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS" \
"PSELx:apb1_slave4_PSELS4_0" \
"PENABLE:APBmslave0_PENABLES" \
"PWRITE:APBmslave0_PWRITES" \
"PRDATA:apb1_slave4_PRDATAS4_0" \
"PWDATA:APBmslave0_PWDATAS" \
"PREADY:apb1_slave4_PREADYS4_0" \
"PSLVERR:apb1_slave4_PSLVERRS4_0" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb1_slave5} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS" \
"PSELx:apb1_slave5_PSELS5_0" \
"PENABLE:APBmslave0_PENABLES" \
"PWRITE:APBmslave0_PWRITES" \
"PRDATA:apb1_slave5_PRDATAS5_0" \
"PWDATA:APBmslave0_PWDATAS" \
"PREADY:apb1_slave5_PREADYS5_0" \
"PSLVERR:apb1_slave5_PSLVERRS5_0" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb1_slave6} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS" \
"PSELx:apb1_slave6_PSELS6_0" \
"PENABLE:APBmslave0_PENABLES" \
"PWRITE:APBmslave0_PWRITES" \
"PRDATA:apb1_slave6_PRDATAS6_0" \
"PWDATA:APBmslave0_PWDATAS" \
"PREADY:apb1_slave6_PREADYS6_0" \
"PSLVERR:apb1_slave6_PSLVERRS6_0" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb1_slave7} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS" \
"PSELx:apb1_slave7_PSELS7_0" \
"PENABLE:APBmslave0_PENABLES" \
"PWRITE:APBmslave0_PWRITES" \
"PRDATA:apb1_slave7_PRDATAS7_0" \
"PWDATA:APBmslave0_PWDATAS" \
"PREADY:apb1_slave7_PREADYS7_0" \
"PSLVERR:apb1_slave7_PSLVERRS7_0" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb1_slave8} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS" \
"PSELx:apb1_slave8_PSELS8_0" \
"PENABLE:APBmslave0_PENABLES" \
"PWRITE:APBmslave0_PWRITES" \
"PRDATA:apb1_slave8_PRDATAS8_0" \
"PWDATA:APBmslave0_PWDATAS" \
"PREADY:apb1_slave8_PREADYS8_0" \
"PSLVERR:apb1_slave8_PSLVERRS8_0" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb1_slave9} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS" \
"PSELx:apb1_slave9_PSELS9_0" \
"PENABLE:APBmslave0_PENABLES" \
"PWRITE:APBmslave0_PWRITES" \
"PRDATA:apb1_slave9_PRDATAS9_0" \
"PWDATA:APBmslave0_PWDATAS" \
"PREADY:apb1_slave9_PREADYS9_0" \
"PSLVERR:apb1_slave9_PSLVERRS9_0" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb1_slave10} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS" \
"PSELx:apb1_slave10_PSELS10_0" \
"PENABLE:APBmslave0_PENABLES" \
"PWRITE:APBmslave0_PWRITES" \
"PRDATA:apb1_slave10_PRDATAS10_0" \
"PWDATA:APBmslave0_PWDATAS" \
"PREADY:apb1_slave10_PREADYS10_0" \
"PSLVERR:apb1_slave10_PSLVERRS10_0" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb1_slave11} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS" \
"PSELx:apb1_slave11_PSELS11_0" \
"PENABLE:APBmslave0_PENABLES" \
"PWRITE:APBmslave0_PWRITES" \
"PRDATA:apb1_slave11_PRDATAS11_0" \
"PWDATA:APBmslave0_PWDATAS" \
"PREADY:apb1_slave11_PREADYS11_0" \
"PSLVERR:apb1_slave11_PSLVERRS11_0" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb1_slave12} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS" \
"PSELx:apb1_slave12_PSELS12_0" \
"PENABLE:APBmslave0_PENABLES" \
"PWRITE:APBmslave0_PWRITES" \
"PRDATA:apb1_slave12_PRDATAS12_0" \
"PWDATA:APBmslave0_PWDATAS" \
"PREADY:apb1_slave12_PREADYS12_0" \
"PSLVERR:apb1_slave12_PSLVERRS12_0" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb0_slave0} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS_0" \
"PSELx:APBmslave0_PSELS0_0" \
"PENABLE:APBmslave0_PENABLES_0" \
"PWRITE:APBmslave0_PWRITES_0" \
"PRDATA:APBmslave0_PRDATAS0_0" \
"PWDATA:APBmslave0_PWDATAS_0" \
"PREADY:APBmslave0_PREADYS0_0" \
"PSLVERR:APBmslave0_PSLVERRS0_0" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb0_slave1} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS_0" \
"PSELx:APBmslave1_PSELS1_0" \
"PENABLE:APBmslave0_PENABLES_0" \
"PWRITE:APBmslave0_PWRITES_0" \
"PRDATA:APBmslave1_PRDATAS1_0" \
"PWDATA:APBmslave0_PWDATAS_0" \
"PREADY:APBmslave1_PREADYS1_0" \
"PSLVERR:APBmslave1_PSLVERRS1_0" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb0_slave3} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS_0" \
"PSELx:APBmslave3_PSELS3" \
"PENABLE:APBmslave0_PENABLES_0" \
"PWRITE:APBmslave0_PWRITES_0" \
"PRDATA:APBmslave3_PRDATAS3" \
"PWDATA:APBmslave0_PWDATAS_0" \
"PREADY:APBmslave3_PREADYS3" \
"PSLVERR:APBmslave3_PSLVERRS3" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb0_slave4} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS_0" \
"PSELx:APBmslave4_PSELS4" \
"PENABLE:APBmslave0_PENABLES_0" \
"PWRITE:APBmslave0_PWRITES_0" \
"PRDATA:APBmslave4_PRDATAS4" \
"PWDATA:APBmslave0_PWDATAS_0" \
"PREADY:APBmslave4_PREADYS4" \
"PSLVERR:APBmslave4_PSLVERRS4" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb0_slave5} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS_0" \
"PSELx:APBmslave5_PSELS5" \
"PENABLE:APBmslave0_PENABLES_0" \
"PWRITE:APBmslave0_PWRITES_0" \
"PRDATA:APBmslave5_PRDATAS5" \
"PWDATA:APBmslave0_PWDATAS_0" \
"PREADY:APBmslave5_PREADYS5" \
"PSLVERR:APBmslave5_PSLVERRS5" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb0_slave6} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS_0" \
"PSELx:APBmslave6_PSELS6" \
"PENABLE:APBmslave0_PENABLES_0" \
"PWRITE:APBmslave0_PWRITES_0" \
"PRDATA:APBmslave6_PRDATAS6" \
"PWDATA:APBmslave0_PWDATAS_0" \
"PREADY:APBmslave6_PREADYS6" \
"PSLVERR:APBmslave6_PSLVERRS6" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb0_slave7} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS_0" \
"PSELx:APBmslave7_PSELS7" \
"PENABLE:APBmslave0_PENABLES_0" \
"PWRITE:APBmslave0_PWRITES_0" \
"PRDATA:APBmslave7_PRDATAS7" \
"PWDATA:APBmslave0_PWDATAS_0" \
"PREADY:APBmslave7_PREADYS7" \
"PSLVERR:APBmslave7_PSLVERRS7" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb0_slave8} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS_0" \
"PSELx:APBmslave8_PSELS8" \
"PENABLE:APBmslave0_PENABLES_0" \
"PWRITE:APBmslave0_PWRITES_0" \
"PRDATA:APBmslave8_PRDATAS8" \
"PWDATA:APBmslave0_PWDATAS_0" \
"PREADY:APBmslave8_PREADYS8" \
"PSLVERR:APBmslave8_PSLVERRS8" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb0_slave9} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS_0" \
"PSELx:APBmslave9_PSELS9" \
"PENABLE:APBmslave0_PENABLES_0" \
"PWRITE:APBmslave0_PWRITES_0" \
"PRDATA:APBmslave9_PRDATAS9" \
"PWDATA:APBmslave0_PWDATAS_0" \
"PREADY:APBmslave9_PREADYS9" \
"PSLVERR:APBmslave9_PSLVERRS9" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb0_slave10} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS_0" \
"PSELx:APBmslave10_PSELS10" \
"PENABLE:APBmslave0_PENABLES_0" \
"PWRITE:APBmslave0_PWRITES_0" \
"PRDATA:APBmslave10_PRDATAS10" \
"PWDATA:APBmslave0_PWDATAS_0" \
"PREADY:APBmslave10_PREADYS10" \
"PSLVERR:APBmslave10_PSLVERRS10" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb0_slave11} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS_0" \
"PSELx:APBmslave11_PSELS11" \
"PENABLE:APBmslave0_PENABLES_0" \
"PWRITE:APBmslave0_PWRITES_0" \
"PRDATA:APBmslave11_PRDATAS11" \
"PWDATA:APBmslave0_PWDATAS_0" \
"PREADY:APBmslave11_PREADYS11" \
"PSLVERR:APBmslave11_PSLVERRS11" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb0_slave12} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS_0" \
"PSELx:apb0_slave12_PSELS12" \
"PENABLE:APBmslave0_PENABLES_0" \
"PWRITE:APBmslave0_PWRITES_0" \
"PRDATA:apb0_slave12_PRDATAS12" \
"PWDATA:APBmslave0_PWDATAS_0" \
"PREADY:apb0_slave12_PREADYS12" \
"PSLVERR:apb0_slave12_PSLVERRS12" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb0_slave14} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS_0" \
"PSELx:APBmslave14_PSELS14" \
"PENABLE:APBmslave0_PENABLES_0" \
"PWRITE:APBmslave0_PWRITES_0" \
"PRDATA:APBmslave14_PRDATAS14" \
"PWDATA:APBmslave0_PWDATAS_0" \
"PREADY:APBmslave14_PREADYS14" \
"PSLVERR:APBmslave14_PSLVERRS14" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb0_slave15} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS_0" \
"PSELx:apb0_slave15_PSELS15" \
"PENABLE:APBmslave0_PENABLES_0" \
"PWRITE:APBmslave0_PWRITES_0" \
"PRDATA:apb0_slave15_PRDATAS15" \
"PWDATA:APBmslave0_PWDATAS_0" \
"PREADY:apb0_slave15_PREADYS15" \
"PSLVERR:apb0_slave15_PSLVERRS15" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb0_slave13} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:APBmslave0_PADDRS_0" \
"PSELx:apb0_slave13_PSELS13" \
"PENABLE:APBmslave0_PENABLES_0" \
"PWRITE:APBmslave0_PWRITES_0" \
"PRDATA:apb0_slave13_PRDATAS13" \
"PWDATA:APBmslave0_PWDATAS_0" \
"PREADY:apb0_slave13_PREADYS13" \
"PSLVERR:apb0_slave13_PSLVERRS13" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb2_slave0} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:apb2_slave0_PADDRS_1" \
"PSELx:apb2_slave0_PSELS0_1" \
"PENABLE:apb2_slave0_PENABLES_1" \
"PWRITE:apb2_slave0_PWRITES_1" \
"PRDATA:apb2_slave0_PRDATAS0_1" \
"PWDATA:apb2_slave0_PWDATAS_1" \
"PREADY:apb2_slave0_PREADYS0_1" \
"PSLVERR:apb2_slave0_PSLVERRS0_1" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb2_slave1} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:apb2_slave0_PADDRS_1" \
"PSELx:apb2_slave1_PSELS1_1" \
"PENABLE:apb2_slave0_PENABLES_1" \
"PWRITE:apb2_slave0_PWRITES_1" \
"PRDATA:apb2_slave1_PRDATAS1_1" \
"PWDATA:apb2_slave0_PWDATAS_1" \
"PREADY:apb2_slave1_PREADYS1_1" \
"PSLVERR:apb2_slave1_PSLVERRS1_1" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb2_slave2} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:apb2_slave0_PADDRS_1" \
"PSELx:apb2_slave2_PSELS2_1" \
"PENABLE:apb2_slave0_PENABLES_1" \
"PWRITE:apb2_slave0_PWRITES_1" \
"PRDATA:apb2_slave2_PRDATAS2_1" \
"PWDATA:apb2_slave0_PWDATAS_1" \
"PREADY:apb2_slave2_PREADYS2_1" \
"PSLVERR:apb2_slave2_PSLVERRS2_1" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb2_slave3} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:apb2_slave0_PADDRS_1" \
"PSELx:apb2_slave3_PSELS3_0" \
"PENABLE:apb2_slave0_PENABLES_1" \
"PWRITE:apb2_slave0_PWRITES_1" \
"PRDATA:apb2_slave3_PRDATAS3_0" \
"PWDATA:apb2_slave0_PWDATAS_1" \
"PREADY:apb2_slave3_PREADYS3_0" \
"PSLVERR:apb2_slave3_PSLVERRS3_0" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb2_slave4} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:apb2_slave0_PADDRS_1" \
"PSELx:apb2_slave4_PSELS4_0" \
"PENABLE:apb2_slave0_PENABLES_1" \
"PWRITE:apb2_slave0_PWRITES_1" \
"PRDATA:apb2_slave4_PRDATAS4_0" \
"PWDATA:apb2_slave0_PWDATAS_1" \
"PREADY:apb2_slave4_PREADYS4_0" \
"PSLVERR:apb2_slave4_PSLVERRS4_0" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb2_slave5} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:apb2_slave0_PADDRS_1" \
"PSELx:apb2_slave5_PSELS5_0" \
"PENABLE:apb2_slave0_PENABLES_1" \
"PWRITE:apb2_slave0_PWRITES_1" \
"PRDATA:apb2_slave5_PRDATAS5_0" \
"PWDATA:apb2_slave0_PWDATAS_1" \
"PREADY:apb2_slave5_PREADYS5_0" \
"PSLVERR:apb2_slave5_PSLVERRS5_0" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb2_slave6} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:apb2_slave0_PADDRS_1" \
"PSELx:apb2_slave6_PSELS6_0" \
"PENABLE:apb2_slave0_PENABLES_1" \
"PWRITE:apb2_slave0_PWRITES_1" \
"PRDATA:apb2_slave6_PRDATAS6_0" \
"PWDATA:apb2_slave0_PWDATAS_1" \
"PREADY:apb2_slave6_PREADYS6_0" \
"PSLVERR:apb2_slave6_PSLVERRS6_0" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb2_slave7} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:apb2_slave0_PADDRS_1" \
"PSELx:apb2_slave7_PSELS7_0" \
"PENABLE:apb2_slave0_PENABLES_1" \
"PWRITE:apb2_slave0_PWRITES_1" \
"PRDATA:apb2_slave7_PRDATAS7_0" \
"PWDATA:apb2_slave0_PWDATAS_1" \
"PREADY:apb2_slave7_PREADYS7_0" \
"PSLVERR:apb2_slave7_PSLVERRS7_0" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb2_slave8} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:apb2_slave0_PADDRS_1" \
"PSELx:apb2_slave8_PSELS8_0" \
"PENABLE:apb2_slave0_PENABLES_1" \
"PWRITE:apb2_slave0_PWRITES_1" \
"PRDATA:apb2_slave8_PRDATAS8_0" \
"PWDATA:apb2_slave0_PWDATAS_1" \
"PREADY:apb2_slave8_PREADYS8_0" \
"PSLVERR:apb2_slave8_PSLVERRS8_0" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb2_slave9} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:apb2_slave0_PADDRS_1" \
"PSELx:apb2_slave9_PSELS9_0" \
"PENABLE:apb2_slave0_PENABLES_1" \
"PWRITE:apb2_slave0_PWRITES_1" \
"PRDATA:apb2_slave9_PRDATAS9_0" \
"PWDATA:apb2_slave0_PWDATAS_1" \
"PREADY:apb2_slave9_PREADYS9_0" \
"PSLVERR:apb2_slave9_PSLVERRS9_0" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb2_slave10} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:apb2_slave0_PADDRS_1" \
"PSELx:apb2_slave10_PSELS10_0" \
"PENABLE:apb2_slave0_PENABLES_1" \
"PWRITE:apb2_slave0_PWRITES_1" \
"PRDATA:apb2_slave10_PRDATAS10_0" \
"PWDATA:apb2_slave0_PWDATAS_1" \
"PREADY:apb2_slave10_PREADYS10_0" \
"PSLVERR:apb2_slave10_PSLVERRS10_0" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb2_slave11} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:apb2_slave0_PADDRS_1" \
"PSELx:apb2_slave11_PSELS11_0" \
"PENABLE:apb2_slave0_PENABLES_1" \
"PWRITE:apb2_slave0_PWRITES_1" \
"PRDATA:apb2_slave11_PRDATAS11_0" \
"PWDATA:apb2_slave0_PWDATAS_1" \
"PREADY:apb2_slave11_PREADYS11_0" \
"PSLVERR:apb2_slave11_PSLVERRS11_0" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb2_slave12} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:apb2_slave0_PADDRS_1" \
"PSELx:apb2_slave12_PSELS12" \
"PENABLE:apb2_slave0_PENABLES_1" \
"PWRITE:apb2_slave0_PWRITES_1" \
"PRDATA:apb2_slave12_PRDATAS12" \
"PWDATA:apb2_slave0_PWDATAS_1" \
"PREADY:apb2_slave12_PREADYS12" \
"PSLVERR:apb2_slave12_PSLVERRS12" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb2_slave13} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:apb2_slave0_PADDRS_1" \
"PSELx:apb2_slave13_PSELS13" \
"PENABLE:apb2_slave0_PENABLES_1" \
"PWRITE:apb2_slave0_PWRITES_1" \
"PRDATA:apb2_slave13_PRDATAS13" \
"PWDATA:apb2_slave0_PWDATAS_1" \
"PREADY:apb2_slave13_PREADYS13" \
"PSLVERR:apb2_slave13_PSLVERRS13" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb2_slave14} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:apb2_slave0_PADDRS_1" \
"PSELx:apb2_slave14_PSELS14" \
"PENABLE:apb2_slave0_PENABLES_1" \
"PWRITE:apb2_slave0_PWRITES_1" \
"PRDATA:apb2_slave14_PRDATAS14" \
"PWDATA:apb2_slave0_PWDATAS_1" \
"PREADY:apb2_slave14_PREADYS14" \
"PSLVERR:apb2_slave14_PSLVERRS14" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb2_slave15} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {mirroredSlave} -port_bif_mapping {\
"PADDR:apb2_slave0_PADDRS_1" \
"PSELx:apb2_slave15_PSELS15" \
"PENABLE:apb2_slave0_PENABLES_1" \
"PWRITE:apb2_slave0_PWRITES_1" \
"PRDATA:apb2_slave15_PRDATAS15" \
"PWDATA:apb2_slave0_PWDATAS_1" \
"PREADY:apb2_slave15_PREADYS15" \
"PSLVERR:apb2_slave15_PSLVERRS15" } 

# Add apb3_interconnect_inst0 instance
sd_instantiate_component -sd_name ${sd_name} -component_name {CoreAPB3_C0} -instance_name {apb3_interconnect_inst0}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {apb3_interconnect_inst0:APBmslave2}



# Add apb3_interconnect_inst1 instance
sd_instantiate_component -sd_name ${sd_name} -component_name {CoreAPB3_C1} -instance_name {apb3_interconnect_inst1}



# Add apb3_interconnect_inst2 instance
sd_instantiate_component -sd_name ${sd_name} -component_name {CoreAPB3_C2} -instance_name {apb3_interconnect_inst2}



# Add CoreAHBLite_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {CoreAHBLite_C0} -instance_name {CoreAHBLite_inst}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {CoreAHBLite_inst:REMAP_M0} -value {GND}



# Add COREAHBTOAPB3_inst0 instance
sd_instantiate_component -sd_name ${sd_name} -component_name {COREAHBTOAPB3_C0} -instance_name {COREAHBTOAPB3_inst0}



# Add COREAHBTOAPB3_inst1 instance
sd_instantiate_component -sd_name ${sd_name} -component_name {COREAHBTOAPB3_C0} -instance_name {COREAHBTOAPB3_inst1}



# Add COREAHBTOAPB3_inst2 instance
sd_instantiate_component -sd_name ${sd_name} -component_name {COREAHBTOAPB3_C0} -instance_name {COREAHBTOAPB3_inst2}



# Add COREAXI4INTERCONNECT_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {COREAXI4INTERCONNECT_C0} -instance_name {COREAXI4INTERCONNECT_inst}



# Add COREAXITOAHBL_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {COREAXITOAHBL_C0} -instance_name {COREAXITOAHBL_inst}



# Add scalar net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"COREAHBTOAPB3_inst0:HCLK" "COREAHBTOAPB3_inst1:HCLK" "COREAHBTOAPB3_inst2:HCLK" "COREAXI4INTERCONNECT_inst:ACLK" "COREAXITOAHBL_inst:ACLK" "COREAXITOAHBL_inst:HCLK" "CoreAHBLite_inst:HCLK" "sys_clk_50mhz" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"COREAHBTOAPB3_inst0:HRESETN" "COREAHBTOAPB3_inst1:HRESETN" "COREAHBTOAPB3_inst2:HRESETN" "COREAXI4INTERCONNECT_inst:ARESETN" "COREAXITOAHBL_inst:ARESETN" "COREAXITOAHBL_inst:HRESETN" "CoreAHBLite_inst:HRESETN" "rst_n_sys_clk_50mhz" }


# Add bus interface net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"COREAHBTOAPB3_inst0:AHBtarget" "CoreAHBLite_inst:AHBmslave0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"COREAHBTOAPB3_inst0:APBinitiator" "apb3_interconnect_inst0:APB3mmaster" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"COREAHBTOAPB3_inst1:AHBtarget" "CoreAHBLite_inst:AHBmslave1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"COREAHBTOAPB3_inst1:APBinitiator" "apb3_interconnect_inst1:APB3mmaster" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"COREAHBTOAPB3_inst2:AHBtarget" "CoreAHBLite_inst:AHBmslave3" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"COREAHBTOAPB3_inst2:APBinitiator" "apb3_interconnect_inst2:APB3mmaster" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"COREAXI4INTERCONNECT_inst:AXI3mslave0" "COREAXITOAHBL_inst:AXISlaveIF" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"COREAXI4INTERCONNECT_inst:AXI4mmaster0" "riscv_aximm" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"COREAXITOAHBL_inst:AHBMasterIF" "CoreAHBLite_inst:AHBmmaster0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb0_slave0" "apb3_interconnect_inst0:APBmslave0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb0_slave1" "apb3_interconnect_inst0:APBmslave1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb0_slave10" "apb3_interconnect_inst0:APBmslave10" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb0_slave11" "apb3_interconnect_inst0:APBmslave11" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb0_slave12" "apb3_interconnect_inst0:APBmslave12" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb0_slave13" "apb3_interconnect_inst0:APBmslave13" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb0_slave14" "apb3_interconnect_inst0:APBmslave14" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb0_slave15" "apb3_interconnect_inst0:APBmslave15" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb0_slave3" "apb3_interconnect_inst0:APBmslave3" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb0_slave4" "apb3_interconnect_inst0:APBmslave4" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb0_slave5" "apb3_interconnect_inst0:APBmslave5" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb0_slave6" "apb3_interconnect_inst0:APBmslave6" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb0_slave7" "apb3_interconnect_inst0:APBmslave7" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb0_slave8" "apb3_interconnect_inst0:APBmslave8" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb0_slave9" "apb3_interconnect_inst0:APBmslave9" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb1_slave0" "apb3_interconnect_inst1:APBmslave0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb1_slave1" "apb3_interconnect_inst1:APBmslave1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb1_slave10" "apb3_interconnect_inst1:APBmslave10" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb1_slave11" "apb3_interconnect_inst1:APBmslave11" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb1_slave12" "apb3_interconnect_inst1:APBmslave12" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb1_slave2" "apb3_interconnect_inst1:APBmslave2" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb1_slave3" "apb3_interconnect_inst1:APBmslave3" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb1_slave4" "apb3_interconnect_inst1:APBmslave4" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb1_slave5" "apb3_interconnect_inst1:APBmslave5" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb1_slave6" "apb3_interconnect_inst1:APBmslave6" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb1_slave7" "apb3_interconnect_inst1:APBmslave7" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb1_slave8" "apb3_interconnect_inst1:APBmslave8" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb1_slave9" "apb3_interconnect_inst1:APBmslave9" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb2_slave0" "apb3_interconnect_inst2:APBmslave0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb2_slave1" "apb3_interconnect_inst2:APBmslave1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb2_slave10" "apb3_interconnect_inst2:APBmslave10" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb2_slave11" "apb3_interconnect_inst2:APBmslave11" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb2_slave12" "apb3_interconnect_inst2:APBmslave12" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb2_slave13" "apb3_interconnect_inst2:APBmslave13" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb2_slave14" "apb3_interconnect_inst2:APBmslave14" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb2_slave15" "apb3_interconnect_inst2:APBmslave15" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb2_slave2" "apb3_interconnect_inst2:APBmslave2" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb2_slave3" "apb3_interconnect_inst2:APBmslave3" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb2_slave4" "apb3_interconnect_inst2:APBmslave4" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb2_slave5" "apb3_interconnect_inst2:APBmslave5" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb2_slave6" "apb3_interconnect_inst2:APBmslave6" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb2_slave7" "apb3_interconnect_inst2:APBmslave7" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb2_slave8" "apb3_interconnect_inst2:APBmslave8" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb2_slave9" "apb3_interconnect_inst2:APBmslave9" }

# Re-enable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 1
# Save the SmartDesign 
save_smartdesign -sd_name ${sd_name}
# Generate SmartDesign "interconnect_hier"
generate_component -component_name ${sd_name}
