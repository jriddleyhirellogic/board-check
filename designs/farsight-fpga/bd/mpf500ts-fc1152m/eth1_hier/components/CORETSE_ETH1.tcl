# Exporting Component Description of CORETSE_ETH1 to TCL
# Family: PolarFire
# Part Number: MPF500TS-FC1152
# Create and Configure the core component CORETSE_ETH1
create_and_configure_core -core_vlnv {Actel:DirectCore:CORETSE:4.0.124} -component_name {CORETSE_ETH1} -params {\
"GMII_TBI:0"  \
"MDIO_PHYID:18"  \
"PACKET_SIZE:13"  \
"SAL:false"  \
"SLIP_ENABLE:false"  \
"STATS:true"  \
"WoL:false"   }
# Exporting Component Description of CORETSE_ETH1 to TCL done
