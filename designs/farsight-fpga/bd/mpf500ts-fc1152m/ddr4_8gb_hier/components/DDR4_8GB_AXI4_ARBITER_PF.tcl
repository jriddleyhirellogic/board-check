# Exporting Component Description of DDR4_8GB_AXI4_ARBITER_PF to TCL
# Family: PolarFire
# Part Number: MPF500TS-FC1152
# Create and Configure the core component DDR4_8GB_AXI4_ARBITER_PF
create_and_configure_core -core_vlnv {Microchip:SolutionCore:DDR_AXI4_ARBITER_PF:2.2.0} -component_name {DDR4_8GB_AXI4_ARBITER_PF} -params {\
"AXI4_SELECTION:2"  \
"AXI_ADDR_WIDTH:38"  \
"AXI_DATA_WIDTH:256"  \
"AXI_ID_WIDTH:4"  \
"FORMAT:0"  \
"NO_OF_READ_CHANNELS:1"  \
"NO_OF_WRITE_CHANNELS:1"   }
# Exporting Component Description of DDR4_8GB_AXI4_ARBITER_PF to TCL done
