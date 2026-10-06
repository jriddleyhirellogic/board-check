# Exporting Component Description of PF_RGMII_TO_GMII_ETH1 to TCL
# Family: PolarFire
# Part Number: MPF500TS-FC1152
# Create and Configure the core component PF_RGMII_TO_GMII_ETH1
create_and_configure_core -core_vlnv {Actel:SystemBuilder:PF_RGMII_TO_GMII:1.3.109} -component_name {PF_RGMII_TO_GMII_ETH1} -params {\
"CLK_TO_DATA:ALIGNED" \
"RGMII_TO_GMII_EN:true" \
"RX_CLOCK_SOURCE:GLOBAL" }
# Exporting Component Description of PF_RGMII_TO_GMII_ETH1 to TCL done
