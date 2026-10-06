set CoreAPB3_C0ver {4.2.100}
set CoreGPIOver {3.2.102}
set COREJTAGDEBUGver {4.0.100}
set CORERESET_PFver {2.3.100}
set COREUARTapbver {5.7.100}
set MIV_RV32ver {3.1.200}
set PF_CCCver {2.2.220}
set PF_SRAM_AHBL_AXIver {1.2.111}
set PFSOC_INIT_MONITORver {1.0.307}
set COREDDSver {4.0.108} 

download_core -vlnv "Actel:DirectCore:CoreAPB3:${CoreAPB3_C0ver}" -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv "Actel:DirectCore:CoreGPIO:${CoreGPIOver}" -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv "Actel:DirectCore:CoreGPIO:${CoreGPIOver}" -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv "Actel:DirectCore:COREJTAGDEBUG:${COREJTAGDEBUGver}" -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv "Actel:DirectCore:CORERESET_PF:${CORERESET_PFver}" -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv "Actel:DirectCore:CoreUARTapb:${COREUARTapbver}" -location {www.microchip-ip.com/repositories/SgCore}
download_core -vlnv "Microsemi:MiV:MIV_RV32:${MIV_RV32ver}" -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv "Actel:SgCore:PF_CCC:${PF_CCCver}" -location {www.microchip-ip.com/repositories/SgCore}
download_core -vlnv "Actel:SystemBuilder:PF_SRAM_AHBL_AXI:${PF_SRAM_AHBL_AXIver}" -location {www.microchip-ip.com/repositories/SgCore}
download_core -vlnv "Microsemi:SgCore:PFSOC_INIT_MONITOR:${PFSOC_INIT_MONITORver}" -location {www.microchip-ip.com/repositories/SgCore} 
download_core -vlnv "Actel:DirectCore:COREDDS:${COREDDSver}" -location {www.microchip-ip.com/repositories/DirectCore}


# set COREAXI4INTERCONNECTver {2.8.103}
# set MIV_ESSver {2.0.200}
# set PF_INIT_MONITORver {2.0.307}
# set PF_DDR4ver {2.5.111}
# set PF_DDR3ver {2.4.122}
# download_core -vlnv "Actel:DirectCore:COREAXI4INTERCONNECT:${COREAXI4INTERCONNECTver}" -location {www.microchip-ip.com/repositories/DirectCore}
# download_core -vlnv "Actel:SystemBuilder:MIV_ESS:${MIV_ESSver}" -location {www.microchip-ip.com/repositories/SgCore}
# download_core -vlnv "Actel:SystemBuilder:PF_DDR3:${PF_DDR3ver}" -location {www.microchip-ip.com/repositories/SgCore}
# download_core -vlnv "Actel:SystemBuilder:PF_DDR4:${PF_DDR4ver}" -location {www.microchip-ip.com/repositories/SgCore}
# download_core -vlnv {Actel:DirectCore:COREAHBTOAPB3:3.2.101} -location {www.microchip-ip.com/repositories/DirectCore}
# download_core -vlnv {Actel:DirectCore:CoreAPB3:4.2.100} -location {www.microchip-ip.com/repositories/DirectCore}
# download_core -vlnv {Actel:DirectCore:COREAXITOAHBL:3.6.101} -location {www.microchip-ip.com/repositories/DirectCore}
# download_core -vlnv {Actel:DirectCore:COREI2C:7.2.101} -location {www.microchip-ip.com/repositories/DirectCore}
# download_core -vlnv {Actel:DirectCore:CORESPI:5.2.104} -location {www.microchip-ip.com/repositories/DirectCore}
# download_core -vlnv {Actel:DirectCore:CorePCS:3.6.103} -location {www.microchip-ip.com/repositories/DirectCore}
# download_core -vlnv {Microchip:SolutionCore:DDR_AXI4_ARBITER_PF:2.2.0} -location {www.microchip-ip.com/repositories/DirectCore}
# download_core -vlnv {Microchip:SolutionCore:DDR_Read:1.2.0} -location {www.microchip-ip.com/repositories/DirectCore}
# download_core -vlnv {Microchip:SolutionCore:DDR_Write:1.3.0} -location {www.microchip-ip.com/repositories/DirectCore}
# download_core -vlnv {Microsemi:SolutionCore:Defective_Pixel:1.0.0} -location {www.microchip-ip.com/repositories/DirectCore}
# download_core -vlnv {Microchip:SolutionCore:Display_Controller:4.8.0} -location {www.microchip-ip.com/repositories/DirectCore}
# download_core -vlnv {Microchip:SolutionCore:HDMI_TX:5.3.0} -location {www.microchip-ip.com/repositories/DirectCore}
# download_core -vlnv {Actel:SgCore:PF_TX_PLL:2.0.304} -location {www.microchip-ip.com/repositories/SgCore}
# download_core -vlnv {Actel:SystemBuilder:PF_XCVR_ERM:3.1.205} -location {www.microchip-ip.com/repositories/SgCore}
# download_core -vlnv {Actel:SgCore:PF_XCVR_REF_CLK:1.0.103} -location {www.microchip-ip.com/repositories/SgCore}
# download_core -vlnv {Microchip:SolutionCore:SLVS_EC_RX:4.2.0} -location {www.microchip-ip.com/repositories/DirectCore}
# download_core -vlnv {Microsemi:SolutionCore:SLVS_EC_RX:4.1.0} -location {www.microchip-ip.com/repositories/DirectCore}
