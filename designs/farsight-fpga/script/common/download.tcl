set CoreGPIOver {3.2.102}
set CorePCSver {3.6.103}
set CORESPIver {5.2.104}
set PF_RGMII_TO_GMIIver {1.3.109}
set PF_XCVR_ERMver {3.1.205}
set SLVS_EC_RXver {4.4.1}
set COREDDR_LITEAXIver {2.0.101}
set PF_DDR4ver {2.5.111}
set CORETSE_AHBver {4.1.100}
set CoreAHBLitever {6.1.101}
set COREAHBTOAPB3ver {4.0.106}
set CoreAPB3ver {4.2.100}
set COREAXI4INTERCONNECTver {2.9.100}
set COREAXITOAHBLver {3.6.101}
set COREJTAGDEBUGver {4.0.100}
set CoreTimerver {2.0.103}
set MIV_RV32ver {3.1.200}
set PF_SRAM_AHBL_AXIver {1.2.111}
set CORERESET_PFver {2.3.100}
set PF_INIT_MONITORver {2.0.307}
set CORE16550ver {3.4.101}
set DDR_AXI4_ARBITER_PFver {2.2.0}
set PF_CCCver {2.2.220}
set PF_XCVR_REF_CLKver {1.0.103}
set COREFIFOver {3.1.101}
set COREQSPIver {2.0.100}
set corepwmver {4.5.100}
set COREDDSver {4.0.108}
set CORETSEver {4.0.124}

download_core -vlnv "Actel:DirectCore:CoreGPIO:${CoreGPIOver}" -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv "Actel:DirectCore:CorePCS:${CorePCSver}" -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv "Actel:DirectCore:CORESPI:${CORESPIver}" -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv "Actel:SystemBuilder:PF_RGMII_TO_GMII:${PF_RGMII_TO_GMIIver}" -location {www.microchip-ip.com/repositories/SgCore}
download_core -vlnv "Actel:SystemBuilder:PF_XCVR_ERM:${PF_XCVR_ERMver}" -location {www.microchip-ip.com/repositories/SgCore}
download_core -vlnv "Microchip:SolutionCore:SLVS_EC_RX:${SLVS_EC_RXver}" -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv "Microsemi:DirectCore:COREDDR_LITEAXI:${COREDDR_LITEAXIver}" -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv "Actel:SystemBuilder:PF_DDR4:${PF_DDR4ver}" -location {www.microchip-ip.com/repositories/SgCore}
download_core -vlnv "Actel:DirectCore:CORETSE_AHB:${CORETSE_AHBver}" -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv "Actel:DirectCore:CoreAHBLite:${CoreAHBLitever}" -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv "Actel:DirectCore:COREAHBTOAPB3:${COREAHBTOAPB3ver}" -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv "Actel:DirectCore:CoreAPB3:${CoreAPB3ver}" -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv "Actel:DirectCore:COREAXI4INTERCONNECT:${COREAXI4INTERCONNECTver}" -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv "Actel:DirectCore:COREAXITOAHBL:${COREAXITOAHBLver}" -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv "Actel:DirectCore:COREJTAGDEBUG:${COREJTAGDEBUGver}" -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv "Actel:DirectCore:CoreTimer:${CoreTimerver}" -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv "Microsemi:MiV:MIV_RV32:${MIV_RV32ver}" -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv "Actel:SystemBuilder:PF_SRAM_AHBL_AXI:${PF_SRAM_AHBL_AXIver}" -location {www.microchip-ip.com/repositories/SgCore}
download_core -vlnv "Actel:DirectCore:CORERESET_PF:${CORERESET_PFver}" -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv "Actel:SgCore:PF_INIT_MONITOR:${PF_INIT_MONITORver}" -location {www.microchip-ip.com/repositories/SgCore}
download_core -vlnv "Actel:DirectCore:CORE16550:${CORE16550ver}" -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv "Microchip:SolutionCore:DDR_AXI4_ARBITER_PF:${DDR_AXI4_ARBITER_PFver}" -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv "Actel:SgCore:PF_CCC:${PF_CCCver}" -location {www.microchip-ip.com/repositories/SgCore}
download_core -vlnv "Actel:SgCore:PF_XCVR_REF_CLK:${PF_XCVR_REF_CLKver}" -location {www.microchip-ip.com/repositories/SgCore}
download_core -vlnv "Actel:DirectCore:COREFIFO:${COREFIFOver}" -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv "Actel:DirectCore:COREQSPI:${COREQSPIver}" -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv "Actel:DirectCore:corepwm:${corepwmver}" -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv "Actel:DirectCore:COREDDS:${COREDDSver}" -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv "Actel:DirectCore:CORETSE:${CORETSEver}" -location {www.microchip-ip.com/repositories/DirectCore}
