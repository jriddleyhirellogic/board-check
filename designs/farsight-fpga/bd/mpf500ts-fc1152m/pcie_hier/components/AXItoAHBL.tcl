# Exporting Component Description of AXItoAHBL to TCL
# Family: PolarFire
# Part Number: MPF500TS-FC1152
# Create and Configure the core component AXItoAHBL
create_and_configure_core -core_vlnv {Actel:DirectCore:COREAXITOAHBL:3.6.101} -component_name {AXItoAHBL} -params {\
"AHBL_SEL_MS_M:0"  \
"ASYNC_CLOCKS:false"  \
"AXI_DWIDTH:64"  \
"AXI_INTERFACE:1"  \
"AXI_SEL_MM_S:0"  \
"EXPOSE_WID:false"  \
"ID_WIDTH:5"  \
"NO_BURST_TRANS:false"  \
"RAM_TYPE:2"  \
"WRAP_SUPPORT:false"   }
# Exporting Component Description of AXItoAHBL to TCL done
