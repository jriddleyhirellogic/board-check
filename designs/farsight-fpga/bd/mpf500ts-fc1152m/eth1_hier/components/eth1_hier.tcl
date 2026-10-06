# Creating SmartDesign "eth1_hier"
set sd_name {eth1_hier}
create_smartdesign -sd_name ${sd_name}

# Disable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 0

# Create top level Scalar Ports
sd_create_scalar_port -sd_name ${sd_name} -port_name {MRXACPT} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {MTXEOF} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {MTXRDY} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {MTXSOF} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {clk_50mhz} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_ctrl_apb_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_ctrl_apb_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_ctrl_apb_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_mac_apb_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_mac_apb_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_mac_apb_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_mac_clk_100mhz} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_mac_rst_n} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_pwr_status} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_rgmii_rx_ctl} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_rgmii_rxc} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_stat_apb_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_stat_apb_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_stat_apb_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_stat_clkout} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_stat_fastlink_fail} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_stat_mdint} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_stat_rcvrd_clk} -port_direction {IN}

sd_create_scalar_port -sd_name ${sd_name} -port_name {MRXEOF} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {MRXRDY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {MRXSOF} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {MTXACPT} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_ctrl_apb_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_ctrl_apb_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_ctrl_clk_squelch_in} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_ctrl_comma_mode} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_mac_apb_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_mac_apb_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_phy_mdc} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_phy_rst_n} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_rgmii_tx_ctl} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_rgmii_txc} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_stat_apb_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_stat_apb_PSLVERR} -port_direction {OUT}

sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_phy_mdio} -port_direction {INOUT} -port_is_pad {1}

# Create top level Bus Ports
sd_create_bus_port -sd_name ${sd_name} -port_name {MTXBYTEVALID} -port_direction {IN} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {MTXDAT} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {eth1_ctrl_apb_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {eth1_ctrl_apb_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {eth1_mac_apb_PADDR} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {eth1_mac_apb_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {eth1_rgmii_rxd} -port_direction {IN} -port_range {[3:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {eth1_stat_apb_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {eth1_stat_apb_PWDATA} -port_direction {IN} -port_range {[31:0]}

sd_create_bus_port -sd_name ${sd_name} -port_name {MRXBYTEVALID} -port_direction {OUT} -port_range {[1:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {MRXDAT} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {eth1_ctrl_apb_PRDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {eth1_mac_apb_PRDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {eth1_rgmii_txd} -port_direction {OUT} -port_range {[3:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {eth1_stat_apb_PRDATA} -port_direction {OUT} -port_range {[31:0]}


# Create top level Bus interface Ports
sd_create_bif_port -sd_name ${sd_name} -port_name {eth1_mac_apb} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:eth1_mac_apb_PADDR" \
"PSELx:eth1_mac_apb_PSEL" \
"PENABLE:eth1_mac_apb_PENABLE" \
"PWRITE:eth1_mac_apb_PWRITE" \
"PRDATA:eth1_mac_apb_PRDATA" \
"PWDATA:eth1_mac_apb_PWDATA" \
"PREADY:eth1_mac_apb_PREADY" \
"PSLVERR:eth1_mac_apb_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {eth1_stat_apb} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:eth1_stat_apb_PADDR" \
"PSELx:eth1_stat_apb_PSEL" \
"PENABLE:eth1_stat_apb_PENABLE" \
"PWRITE:eth1_stat_apb_PWRITE" \
"PRDATA:eth1_stat_apb_PRDATA" \
"PWDATA:eth1_stat_apb_PWDATA" \
"PREADY:eth1_stat_apb_PREADY" \
"PSLVERR:eth1_stat_apb_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {eth1_ctrl_apb} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:eth1_ctrl_apb_PADDR" \
"PSELx:eth1_ctrl_apb_PSEL" \
"PENABLE:eth1_ctrl_apb_PENABLE" \
"PWRITE:eth1_ctrl_apb_PWRITE" \
"PRDATA:eth1_ctrl_apb_PRDATA" \
"PWDATA:eth1_ctrl_apb_PWDATA" \
"PREADY:eth1_ctrl_apb_PREADY" \
"PSLVERR:eth1_ctrl_apb_PSLVERR" } 

# Add eth1_mac_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {CORETSE_ETH1} -instance_name {eth1_mac_inst}
sd_create_pin_group -sd_name ${sd_name} -group_name {MTX} -instance_name {eth1_mac_inst} -pin_names {"MTXACPT" "MTXCLK" "MTXRDY" "MTXSOF" "MTXEOF" "MTXDAT" "MTXBYTEVALID" }
sd_create_pin_group -sd_name ${sd_name} -group_name {MRX} -instance_name {eth1_mac_inst} -pin_names {"MRXACPT" "MRXRDY" "MRXSOF" "MRXEOF" "MRXDAT" "MRXBYTEVALID" }
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {eth1_mac_inst:MTXHWM}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {eth1_mac_inst:TSM_CONTROL}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {eth1_mac_inst:TSM_TX_INTR}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {eth1_mac_inst:TSM_RX_INTR}



# Add eth1_rgmii_to_gmii_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {PF_RGMII_TO_GMII_ETH1} -instance_name {eth1_rgmii_to_gmii_inst}



# Add eth_phy_mdio_bibuf_inst instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {BIBUF} -instance_name {eth_phy_mdio_bibuf_inst}



# Add gpi_eth1_stat_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {CoreGPIO_ETH1_STAT} -instance_name {gpi_eth1_stat_inst}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_eth1_stat_inst:GPIO_IN} -pin_slices {[0:0]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_eth1_stat_inst:GPIO_IN} -pin_slices {[1:1]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_eth1_stat_inst:GPIO_IN} -pin_slices {[2:2]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_eth1_stat_inst:GPIO_IN} -pin_slices {[31:4]}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {gpi_eth1_stat_inst:GPIO_IN[31:4]} -value {GND}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpi_eth1_stat_inst:GPIO_IN} -pin_slices {[3:3]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {gpi_eth1_stat_inst:INT}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {gpi_eth1_stat_inst:GPIO_OUT}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {gpi_eth1_stat_inst:GPIO_OE}



# Add gpo_eth1_ctrl instance
sd_instantiate_component -sd_name ${sd_name} -component_name {CoreGPIO_ETH1_CTRL} -instance_name {gpo_eth1_ctrl}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpo_eth1_ctrl:GPIO_OUT} -pin_slices {[0:0]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpo_eth1_ctrl:GPIO_OUT} -pin_slices {[1:1]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpo_eth1_ctrl:GPIO_OUT} -pin_slices {[2:2]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {gpo_eth1_ctrl:GPIO_OUT} -pin_slices {[31:3]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {gpo_eth1_ctrl:GPIO_OUT[31:3]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {gpo_eth1_ctrl:INT}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {gpo_eth1_ctrl:GPIO_IN} -value {GND}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {gpo_eth1_ctrl:GPIO_OE}



# Add TRIBUFF_eth1_ctrl_clk_squelch_in_inst instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {TRIBUFF} -instance_name {TRIBUFF_eth1_ctrl_clk_squelch_in_inst}



# Add TRIBUFF_eth1_ctrl_comma_mode_inst instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {TRIBUFF} -instance_name {TRIBUFF_eth1_ctrl_comma_mode_inst}



# Add TRIBUFF_eth1_phy_mdc_inst instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {TRIBUFF} -instance_name {TRIBUFF_eth1_phy_mdc_inst}



# Add TRIBUFF_eth1_phy_rst_n_inst instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {TRIBUFF} -instance_name {TRIBUFF_eth1_phy_rst_n_inst}



# Add scalar net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"MRXACPT" "eth1_mac_inst:MRXACPT" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"MRXEOF" "eth1_mac_inst:MRXEOF" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"MRXRDY" "eth1_mac_inst:MRXRDY" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"MRXSOF" "eth1_mac_inst:MRXSOF" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"MTXACPT" "eth1_mac_inst:MTXACPT" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"MTXEOF" "eth1_mac_inst:MTXEOF" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"MTXRDY" "eth1_mac_inst:MTXRDY" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"MTXSOF" "eth1_mac_inst:MTXSOF" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"TRIBUFF_eth1_ctrl_clk_squelch_in_inst:D" "gpo_eth1_ctrl:GPIO_OUT[2:2]" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"TRIBUFF_eth1_ctrl_clk_squelch_in_inst:E" "TRIBUFF_eth1_ctrl_comma_mode_inst:E" "TRIBUFF_eth1_phy_mdc_inst:E" "TRIBUFF_eth1_phy_rst_n_inst:E" "eth1_pwr_status" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"TRIBUFF_eth1_ctrl_clk_squelch_in_inst:PAD" "eth1_ctrl_clk_squelch_in" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"TRIBUFF_eth1_ctrl_comma_mode_inst:D" "gpo_eth1_ctrl:GPIO_OUT[1:1]" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"TRIBUFF_eth1_ctrl_comma_mode_inst:PAD" "eth1_ctrl_comma_mode" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"TRIBUFF_eth1_phy_mdc_inst:D" "eth1_mac_inst:MDC" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"TRIBUFF_eth1_phy_mdc_inst:PAD" "eth1_phy_mdc" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"TRIBUFF_eth1_phy_rst_n_inst:D" "gpo_eth1_ctrl:GPIO_OUT[0:0]" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"TRIBUFF_eth1_phy_rst_n_inst:PAD" "eth1_phy_rst_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"clk_50mhz" "eth1_mac_inst:PCLK" "gpi_eth1_stat_inst:PCLK" "gpo_eth1_ctrl:PCLK" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_mac_clk_100mhz" "eth1_mac_inst:MRXCLK" "eth1_mac_inst:MTXCLK" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_mac_inst:COL" "eth1_rgmii_to_gmii_inst:GMII_COL" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_mac_inst:CRS" "eth1_rgmii_to_gmii_inst:GMII_CRS" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_mac_inst:MDI" "eth_phy_mdio_bibuf_inst:Y" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_mac_inst:MDO" "eth_phy_mdio_bibuf_inst:D" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_mac_inst:MDOEN" "eth_phy_mdio_bibuf_inst:E" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_mac_inst:PRESETN" "eth1_mac_rst_n" "gpi_eth1_stat_inst:PRESETN" "gpo_eth1_ctrl:PRESETN" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_mac_inst:RXCLK" "eth1_mac_inst:TXCLK" "eth1_rgmii_to_gmii_inst:GMII_RXCLK" "eth1_rgmii_to_gmii_inst:GMII_TXCLK" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_mac_inst:RXDV" "eth1_rgmii_to_gmii_inst:GMII_RX_DV" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_mac_inst:RXER" "eth1_rgmii_to_gmii_inst:GMII_RX_ER" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_mac_inst:TXEN" "eth1_rgmii_to_gmii_inst:GMII_TX_EN" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_mac_inst:TXER" "eth1_rgmii_to_gmii_inst:GMII_TX_ER" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_phy_mdio" "eth_phy_mdio_bibuf_inst:PAD" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_rgmii_rx_ctl" "eth1_rgmii_to_gmii_inst:RGMII_RX_CTL" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_rgmii_rxc" "eth1_rgmii_to_gmii_inst:RGMII_RXC" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_rgmii_to_gmii_inst:RGMII_TXC" "eth1_rgmii_txc" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_rgmii_to_gmii_inst:RGMII_TX_CTL" "eth1_rgmii_tx_ctl" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_stat_clkout" "gpi_eth1_stat_inst:GPIO_IN[3:3]" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_stat_fastlink_fail" "gpi_eth1_stat_inst:GPIO_IN[0:0]" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_stat_mdint" "gpi_eth1_stat_inst:GPIO_IN[1:1]" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_stat_rcvrd_clk" "gpi_eth1_stat_inst:GPIO_IN[2:2]" }

# Add bus net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"MRXBYTEVALID" "eth1_mac_inst:MRXBYTEVALID" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"MRXDAT" "eth1_mac_inst:MRXDAT" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"MTXBYTEVALID" "eth1_mac_inst:MTXBYTEVALID" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"MTXDAT" "eth1_mac_inst:MTXDAT" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_mac_inst:RXD" "eth1_rgmii_to_gmii_inst:GMII_RXD" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_mac_inst:TXD" "eth1_rgmii_to_gmii_inst:GMII_TXD" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_rgmii_rxd" "eth1_rgmii_to_gmii_inst:RGMII_RXD" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_rgmii_to_gmii_inst:RGMII_TXD" "eth1_rgmii_txd" }

# Add bus interface net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_ctrl_apb" "gpo_eth1_ctrl:APB_bif" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_mac_apb" "eth1_mac_inst:APBS" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_stat_apb" "gpi_eth1_stat_inst:APB_bif" }

# Re-enable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 1
# Save the SmartDesign 
save_smartdesign -sd_name ${sd_name}
# Generate SmartDesign "eth1_hier"
generate_component -component_name ${sd_name}
