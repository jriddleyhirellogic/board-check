# Creating SmartDesign "top"
set sd_name {top}
create_smartdesign -sd_name ${sd_name}

# Disable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 0

# Create top level Scalar Ports
sd_create_scalar_port -sd_name ${sd_name} -port_name {btn0} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {btn1} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {bus_to_fav_gpi} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {bus_to_fav_pps} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {bus_to_fav_trig} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane0_rxd_n} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane0_rxd_p} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane1_rxd_n} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane1_rxd_p} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane2_rxd_n} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane2_rxd_p} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane3_rxd_n} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane3_rxd_p} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane4_rxd_n} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane4_rxd_p} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane5_rxd_n} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane5_rxd_p} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane6_rxd_n} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane6_rxd_p} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane7_rxd_n} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_lane7_rxd_p} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_miso} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_pwr_status} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_tout_primary} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr16gb_pwr_status} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr8gb_pwr_status} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_pwr_status} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_rgmii_rx_ctl} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_rgmii_rxc} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_stat_clkout} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_stat_fastlink_fail} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_stat_mdint} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_stat_rcvrd_clk} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth2_pwr_status} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {jtag_tck} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {jtag_tdi} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {jtag_tms} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {jtag_trstb} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {lvds_pwr_status} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {lvdt_adc_spi_miso} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {lvdt_pwr_status} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {nvm_spi_sio1} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_pwr_status} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc10} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc11} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc12} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc13} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc14} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc15} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc3} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc4} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc5} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc6} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc7} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc8} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pa3_to_pf_misc9} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pcie0_lane0_rxd_n} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pcie0_lane0_rxd_p} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pcie0_lane1_rxd_n} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pcie0_lane1_rxd_p} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pcie0_perstn} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pcie_ext_ref_clk_n} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pcie_ext_ref_clk_p} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pf_pwr_status} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pri_stp_motor_fault_n} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ref_clk_148p5mhz_n} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ref_clk_148p5mhz_p} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sec_stp_motor_fault_n} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {step_down_pwr_status} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {stepper_pri_pwr_status} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {stepper_sec_pwr_status} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sys_clk_50mhz} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {tlm_spi_miso} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {uart0_rx} -port_direction {IN}

sd_create_scalar_port -sd_name ${sd_name} -port_name {fav_to_bus_gpo} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_buff_en_n} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_mosi} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_osc_en} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_pwr_en} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_sck} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_xce_n} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_xclr_n} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {cam_xtrig_primary} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_gpio0} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_gpio10} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_gpio11} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_gpio12} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_gpio13} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_gpio1} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_gpio2} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_gpio3} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_gpio4} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_gpio5} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_gpio6} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_gpio7} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_gpio8} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_gpio9} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r0_act_n} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r0_cas_n} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r0_ck0_n} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r0_ck0} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r0_cke} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r0_cs_n} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r0_odt} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r0_ras_n} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r0_reset_n} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r0_shield0} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r0_shield1} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r0_shield2} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r0_shield3} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r0_shield4} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r0_shield5} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r0_shield6} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r0_shield7} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r0_shield8} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r0_we_n} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r2_act_n} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r2_cas_n} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r2_ck0_n} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r2_ck0} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r2_cke} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r2_cs_n} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r2_odt} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r2_ras_n} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r2_reset_n} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r2_shield0} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r2_shield1} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r2_shield2} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r2_shield3} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r2_shield4} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {ddr4_r2_we_n} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_ctrl_clk_squelch_in} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_ctrl_comma_mode} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_phy_mdc} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_phy_rst_n} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_pwr_en} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_rgmii_tx_ctl} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_rgmii_txc} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth2_ctrl_clk_squelch_in} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth2_ctrl_comma_mode} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth2_phy_mdc} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth2_phy_rst_n} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {eth2_pwr_en} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {jtag_tdo} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {lvds_pwr_en} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {lvdt_adc_spi_cs_n} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {lvdt_adc_spi_mosi} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {lvdt_adc_spi_sclk} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {lvdt_dac_b0} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {lvdt_dac_b1} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {lvdt_dac_b2} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {lvdt_dac_b3} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {lvdt_dac_b4} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {lvdt_dac_b5} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {lvdt_dac_b6} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {lvdt_dac_b7} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {lvdt_gain_switch} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {lvdt_pwr_en} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {nvm_spi_cs_n} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {nvm_spi_sck} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {nvm_spi_sio0} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pcie0_lane0_txd_n} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pcie0_lane0_txd_p} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pcie0_lane1_txd_n} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pcie0_lane1_txd_p} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pf_heartbeat} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pri_stp_motor_decay0} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pri_stp_motor_decay1} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pri_stp_motor_dir} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pri_stp_motor_en} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pri_stp_motor_m0} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pri_stp_motor_m1} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pri_stp_motor_sleep_n} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pri_stp_motor_step} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pri_stp_motor_toff} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pri_stp_motor_vref_pwm} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sec_stp_motor_decay0} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sec_stp_motor_decay1} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sec_stp_motor_dir} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sec_stp_motor_en} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sec_stp_motor_m0} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sec_stp_motor_m1} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sec_stp_motor_sleep_n} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sec_stp_motor_step} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sec_stp_motor_toff} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sec_stp_motor_vref_pwm} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {stepper_pri_pwr_en} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {stepper_sec_pwr_en} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {tlm_spi_cs1_n} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {tlm_spi_cs2_n} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {tlm_spi_cs3_n} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {tlm_spi_cs4_n} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {tlm_spi_cs5_n} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {tlm_spi_cs6_n} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {tlm_spi_mosi} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {tlm_spi_sclk} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {uart0_tx} -port_direction {OUT}

sd_create_scalar_port -sd_name ${sd_name} -port_name {eth1_phy_mdio} -port_direction {INOUT} -port_is_pad {1}

# Create top level Bus Ports
sd_create_bus_port -sd_name ${sd_name} -port_name {eth1_rgmii_rxd} -port_direction {IN} -port_range {[3:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {pa3_fw_version} -port_direction {IN} -port_range {[2:0]}

sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_r0_a} -port_direction {OUT} -port_range {[13:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_r0_ba} -port_direction {OUT} -port_range {[1:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_r0_bg} -port_direction {OUT} -port_range {[1:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_r0_dm_n} -port_direction {OUT} -port_range {[8:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_r2_a} -port_direction {OUT} -port_range {[13:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_r2_ba} -port_direction {OUT} -port_range {[1:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_r2_bg} -port_direction {OUT} -port_range {[1:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_r2_dm_n} -port_direction {OUT} -port_range {[4:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {eth1_rgmii_txd} -port_direction {OUT} -port_range {[3:0]} -port_is_pad {1}

sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_r0_dqs_n} -port_direction {INOUT} -port_range {[8:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_r0_dqs} -port_direction {INOUT} -port_range {[8:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_r0_dq} -port_direction {INOUT} -port_range {[71:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_r2_dqs_n} -port_direction {INOUT} -port_range {[4:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_r2_dqs} -port_direction {INOUT} -port_range {[4:0]} -port_is_pad {1}
sd_create_bus_port -sd_name ${sd_name} -port_name {ddr4_r2_dq} -port_direction {INOUT} -port_range {[39:0]} -port_is_pad {1}

sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {eth2_ctrl_clk_squelch_in} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {eth2_ctrl_comma_mode} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {eth2_phy_mdc} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {eth2_phy_rst_n} -value {GND}



# Add bus_to_fav_gpi_inbuf_inst instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {INBUF} -instance_name {bus_to_fav_gpi_inbuf_inst}



# Add bus_to_fav_gpio_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {CoreGPIO_C8} -instance_name {bus_to_fav_gpio_inst}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {bus_to_fav_gpio_inst:GPIO_IN} -pin_slices {[31:1]}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {bus_to_fav_gpio_inst:GPIO_IN[31:1]} -value {GND}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {bus_to_fav_gpio_inst:GPIO_IN} -pin_slices {[0:0]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {bus_to_fav_gpio_inst:GPIO_OUT} -pin_slices {[31:0]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {bus_to_fav_gpio_inst:GPIO_OUT[31:0]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {bus_to_fav_gpio_inst:INT}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {bus_to_fav_gpio_inst:GPIO_OE}



# Add fav_to_bus_gpo_inbuf_inst instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {OUTBUF} -instance_name {fav_to_bus_gpo_outbuf_inst}



# Add bus_to_fav_pps_inbuf_inst instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {INBUF} -instance_name {bus_to_fav_pps_inbuf_inst}



# Add bus_to_fav_trig_inbuf_inst instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {INBUF} -instance_name {bus_to_fav_trig_inbuf_inst}



# Add cam_rx_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {cam_rx_hier} -instance_name {cam_rx_inst}
sd_create_pin_group -sd_name ${sd_name} -group_name {CAM_TO_DDR4_8GB} -instance_name {cam_rx_inst} -pin_names {"ddr4_8gb_cam_data_out" "ddr4_8gb_line_valid_out" "ddr4_8gb_frame_valid_out" }
sd_create_pin_group -sd_name ${sd_name} -group_name {CAM_TO_DDR4_16GB} -instance_name {cam_rx_inst} -pin_names {"ddr4_16gb_cam_data_out" "ddr4_16gb_line_valid_out" "ddr4_16gb_frame_valid_out" }
sd_create_pin_group -sd_name ${sd_name} -group_name {CAM_CTRL_PINS} -instance_name {cam_rx_inst} -pin_names {"cam_en" "cam_xclr_n" "cam_tout_primary" "cam_xtrig_primary" "lvds_start" "cam_trig_int" }
sd_create_pin_group -sd_name ${sd_name} -group_name {CAM_SPI_INTF} -instance_name {cam_rx_inst} -pin_names {"cam_spi_int" "cam_spi_miso" "cam_spi_mosi" "cam_spi_sck" "cam_spi_xce_n" }
sd_create_pin_group -sd_name ${sd_name} -group_name {SERDES_RX} -instance_name {cam_rx_inst} -pin_names {"cam_lane7_rxd_p" "cam_lane0_rxd_p" "cam_lane7_rxd_n" "cam_lane6_rxd_n" "cam_lane6_rxd_p" "cam_lane5_rxd_n" "cam_lane5_rxd_p" "cam_lane3_rxd_n" "cam_lane4_rxd_n" "cam_lane3_rxd_p" "cam_lane4_rxd_p" "cam_lane2_rxd_n" "cam_lane2_rxd_p" "cam_lane1_rxd_n" "cam_lane1_rxd_p" "cam_lane0_rxd_n" }
sd_create_pin_group -sd_name ${sd_name} -group_name {APB_CLK_AND_RST} -instance_name {cam_rx_inst} -pin_names {"cam_spi_apb_rst_n" "cam_spi_apb_clk" }
sd_create_pin_group -sd_name ${sd_name} -group_name {PIXEL_CLK_AND_RST} -instance_name {cam_rx_inst} -pin_names {"pixel_ref_clk" "pixel_fab_clk" "osc_clk" "pixel_rst_n" "pcs_arst_n" "pma_arst_n" }
sd_create_pin_group -sd_name ${sd_name} -group_name {CDR_CLK} -instance_name {cam_rx_inst} -pin_names {"cdr_ref_clk_148p5mhz" }
sd_create_pin_group -sd_name ${sd_name} -group_name {CAM_DBG} -instance_name {cam_rx_inst} -pin_names {"dbg_ebd_valid" "dbg_frame_valid" "dbg_cam_mux_select" "dbg_line_valid" "dbg_cam_mux_enable" }
sd_create_pin_group -sd_name ${sd_name} -group_name {TIMESTAMP} -instance_name {cam_rx_inst} -pin_names {"timestamp_sec" "timestamp_nsec" }
sd_create_pin_group -sd_name ${sd_name} -group_name {STAT} -instance_name {cam_rx_inst} -pin_names {"cam_pwr_status" }
sd_create_pin_group -sd_name ${sd_name} -group_name {FRAME_INDEX} -instance_name {cam_rx_inst} -pin_names {"ddr4_16gb_frame_index" "ddr4_8gb_frame_index" }



# Add cam_spi_miso_inbuf_inst instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {INBUF} -instance_name {cam_spi_miso_inbuf_inst}



# Add cam_spi_mosi_tribuf_inst instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {TRIBUFF} -instance_name {cam_spi_mosi_tribuf_inst}



# Add cam_spi_sck_tribuf_inst instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {TRIBUFF} -instance_name {cam_spi_sck_tribuf_inst}



# Add cam_spi_xce_n_tribuf_inst instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {TRIBUFF} -instance_name {cam_spi_xce_n_tribuf_inst}



# Add cam_xcvr_ref_clk_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {PF_XCVR_REF_CLK_C0} -instance_name {cam_xcvr_ref_clk_inst}



# Add dbg_gpio_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {CoreGPIO_C6} -instance_name {dbg_gpio_inst}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_IN} -pin_slices {[29:0]}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {dbg_gpio_inst:GPIO_IN[29:0]} -value {GND}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_IN} -pin_slices {[30:30]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_IN} -pin_slices {[31:31]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[0:0]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[1:1]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[2:2]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[31:4]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dbg_gpio_inst:GPIO_OUT[31:4]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[3:3]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dbg_gpio_inst:INT}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dbg_gpio_inst:GPIO_OE}



# Add dbg_mux_inst instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {dbg_mux} -instance_name {dbg_mux_inst}
sd_create_pin_group -sd_name ${sd_name} -group_name {CAM_DBG} -instance_name {dbg_mux_inst} -pin_names {"cam_tout" "ebd_valid" "cam_xtrig" "frame_valid" "line_valid" }
sd_create_pin_group -sd_name ${sd_name} -group_name {DDR4_8GB_WRITE} -instance_name {dbg_mux_inst} -pin_names {"ddr4_8gb_write_ack" "ddr4_8gb_write_req" "ddr4_8gb_write_valid" "ddr4_8gb_write_done" }
sd_create_pin_group -sd_name ${sd_name} -group_name {DDR4_16GB_WRITE} -instance_name {dbg_mux_inst} -pin_names {"ddr4_16gb_write_done" "ddr4_16gb_write_ack" "ddr4_16gb_write_req" "ddr4_16gb_write_valid" }
sd_create_pin_group -sd_name ${sd_name} -group_name {DDR4_8GB_READ} -instance_name {dbg_mux_inst} -pin_names {"ddr4_8gb_read_done" "ddr4_8gb_read_ack" "ddr4_8gb_read_req" "ddr4_8gb_read_valid" }
sd_create_pin_group -sd_name ${sd_name} -group_name {DDR4_16GB_READ} -instance_name {dbg_mux_inst} -pin_names {"ddr4_16gb_read_done" "ddr4_16gb_read_ack" "ddr4_16gb_read_req" "ddr4_16gb_read_valid" }
sd_create_pin_group -sd_name ${sd_name} -group_name {MAX_INRF} -instance_name {dbg_mux_inst} -pin_names {"mac_mtxsof" "mac_mtxrdy" "mac_mtxacpt" "mac_mtxeof" }
sd_create_pin_group -sd_name ${sd_name} -group_name {NVM_SPI} -instance_name {dbg_mux_inst} -pin_names {"nvm_spi_dbg_clk" "nvm_spi_dbg_miso" "nvm_spi_dbg_mosi" "nvm_spi_dbg_cs_n" }
sd_create_pin_group -sd_name ${sd_name} -group_name {UART} -instance_name {dbg_mux_inst} -pin_names {"uart_rx" "uart_tx" }
sd_create_pin_group -sd_name ${sd_name} -group_name {FOCUS_MECH} -instance_name {dbg_mux_inst} -pin_names {"sec_stp_motor_fault_n" "pri_stp_motor_vref_pwm" "pri_stp_motor_fault_n" "pri_stp_motor_step" "sec_stp_motor_vref_pwm" "pri_stp_motor_dir" "sec_stp_motor_step" "pri_stp_motor_en" "sec_stp_motor_dir" "sec_stp_motor_en" }



# Add ddr4_8gb_group_hier_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {ddr4_8gb_group_hier} -instance_name {ddr4_8gb_group_hier_inst}
sd_create_pin_group -sd_name ${sd_name} -group_name {DDR4_PAD} -instance_name {ddr4_8gb_group_hier_inst} -pin_names {"ACT_N" "CAS_N" "CK0" "CK0_N" "CKE" "CS_N" "ODT" "RAS_N" "RESET_N" "WE_N" "A" "BA" "BG" "DM_N" "DQ" "DQS" "DQS_N" "SHIELD0" "SHIELD1" "SHIELD2" "SHIELD3" "SHIELD4" }
sd_create_pin_group -sd_name ${sd_name} -group_name {DDR4_MIG_RST} -instance_name {ddr4_8gb_group_hier_inst} -pin_names {"sys_rst_n" }
sd_create_pin_group -sd_name ${sd_name} -group_name {ARB_DBG_READ} -instance_name {ddr4_8gb_group_hier_inst} -pin_names {"r0_ack_o" "r0_data_valid_o" "r0_done_o" "arb_read_req" }
sd_create_pin_group -sd_name ${sd_name} -group_name {ARB_DBG_WRITE} -instance_name {ddr4_8gb_group_hier_inst} -pin_names {"w0_ack_o" "w0_done_o" "arb_write_req" "arb_write_valid" }
sd_create_pin_group -sd_name ${sd_name} -group_name {DMA_READ_CLK_RST} -instance_name {ddr4_8gb_group_hier_inst} -pin_names {"apb_clk" "apb_rst_n" "udp_clk" "udp_rst_n" }
sd_create_pin_group -sd_name ${sd_name} -group_name {UDP_INTF} -instance_name {ddr4_8gb_group_hier_inst} -pin_names {"core_busy" "eof_ack" "pyl_acpt" "sof_req" }
sd_create_pin_group -sd_name ${sd_name} -group_name {CAM_INTF} -instance_name {ddr4_8gb_group_hier_inst} -pin_names {"cam_frame_valid" "cam_line_valid" "pixel_clk" "pixel_rst_n" "cam_data_in" "ddr4_8gb_wr_frame_index" }
sd_create_pin_group -sd_name ${sd_name} -group_name {DDR4_CLK_RST} -instance_name {ddr4_8gb_group_hier_inst} -pin_names {"ddr4_8gb_pll_lock" "ddr_8gb_rst_n" "ddr4_8gb_clk" "ddr4_8gb_ctrlr_ready" }



# Add ddr4_16gb_group_hier_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {ddr4_16gb_group_hier} -instance_name {ddr4_16gb_group_hier_inst}
sd_create_pin_group -sd_name ${sd_name} -group_name {DDR4_PAD} -instance_name {ddr4_16gb_group_hier_inst} -pin_names {"ACT_N" "CAS_N" "CK0" "CK0_N" "CKE" "CS_N" "ODT" "RAS_N" "RESET_N" "WE_N" "A" "BA" "BG" "DM_N" "DQ" "DQS" "DQS_N" "SHIELD0" "SHIELD1" "SHIELD2" "SHIELD3" "SHIELD4" "SHIELD5" "SHIELD6" "SHIELD7" "SHIELD8" }
sd_create_pin_group -sd_name ${sd_name} -group_name {DDR4_MIG_RST} -instance_name {ddr4_16gb_group_hier_inst} -pin_names {"sys_rst_n" }
sd_create_pin_group -sd_name ${sd_name} -group_name {ARB_DBG_READ} -instance_name {ddr4_16gb_group_hier_inst} -pin_names {"r0_ack_o" "r0_data_valid_o" "r0_done_o" "arb_read_req" }
sd_create_pin_group -sd_name ${sd_name} -group_name {ARB_DBG_WRITE} -instance_name {ddr4_16gb_group_hier_inst} -pin_names {"w0_ack_o" "w0_done_o" "arb_write_req" "arb_write_valid" }
sd_create_pin_group -sd_name ${sd_name} -group_name {DMA_READ_CLK_RST} -instance_name {ddr4_16gb_group_hier_inst} -pin_names {"apb_clk" "apb_rst_n" "udp_clk" "udp_rst_n" }
sd_create_pin_group -sd_name ${sd_name} -group_name {UDP_INTF} -instance_name {ddr4_16gb_group_hier_inst} -pin_names {"core_busy" "eof_ack" "pyl_acpt" "sof_req" }
sd_create_pin_group -sd_name ${sd_name} -group_name {CAM_INTF} -instance_name {ddr4_16gb_group_hier_inst} -pin_names {"cam_frame_valid" "cam_line_valid" "pixel_clk" "pixel_rst_n" "cam_data_in" "ddr4_16gb_wr_frame_index" }
sd_create_pin_group -sd_name ${sd_name} -group_name {DDR4_CLK_RST} -instance_name {ddr4_16gb_group_hier_inst} -pin_names {"ddr4_16gb_pll_lock" "ddr4_16gb_rst_n" "ddr4_16gb_clk" "ddr4_16gb_ctrlr_ready" }



# Add frame_read_done_int instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {OR2} -instance_name {frame_read_done_int}



# Add eth1_hier_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {eth1_hier} -instance_name {eth1_hier_inst}
sd_create_pin_group -sd_name ${sd_name} -group_name {MTX} -instance_name {eth1_hier_inst} -pin_names {"MTXBYTEVALID" "MTXACPT" "MTXRDY" "MTXSOF" "MTXEOF" "MTXDAT" }
sd_create_pin_group -sd_name ${sd_name} -group_name {MRX} -instance_name {eth1_hier_inst} -pin_names {"MRXACPT" "MRXSOF" "MRXRDY" "MRXEOF" "MRXBYTEVALID" "MRXDAT" }



# Add eth_pcie_mux_hier_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {eth_pcie_mux_hier} -instance_name {eth_pcie_mux_hier_inst}



# Add flash_spi_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {CORESPI_C2} -instance_name {flash_spi_inst}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {flash_spi_inst:SPISS} -pin_slices {[0:0]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {flash_spi_inst:SPISS} -pin_slices {[7:1]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {flash_spi_inst:SPISS[7:1]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {flash_spi_inst:SPIRXAVAIL}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {flash_spi_inst:SPITXRFM}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {flash_spi_inst:SPISSI} -value {VCC}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {flash_spi_inst:SPICLKI} -value {GND}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {flash_spi_inst:SPIOEN}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {flash_spi_inst:SPIMODE}



# Add focus_mech_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {focus_mech} -instance_name {focus_mech_inst}
sd_create_pin_group -sd_name ${sd_name} -group_name {LVDT_GAIN_CTRL} -instance_name {focus_mech_inst} -pin_names {"lvdt_gain_switch" }
sd_create_pin_group -sd_name ${sd_name} -group_name {CLK_RST} -instance_name {focus_mech_inst} -pin_names {"sys_rst_n" "sys_clk_50mhz" }
sd_create_pin_group -sd_name ${sd_name} -group_name {LVDT_ADC_SPI} -instance_name {focus_mech_inst} -pin_names {"lvdt_adc_spi_miso" "lvdt_adc_spi_cs_n" "lvdt_adc_spi_mosi" "lvdt_adc_spi_sclk" }
sd_create_pin_group -sd_name ${sd_name} -group_name {SEC_STEPPER} -instance_name {focus_mech_inst} -pin_names {"sec_stp_motor_fault_n" "sec_stp_motor_decay0" "sec_stp_motor_decay1" "sec_stp_motor_dir" "sec_stp_motor_en" "sec_stp_motor_m0" "sec_stp_motor_m1" "sec_stp_motor_sleep_n" "sec_stp_motor_step" "sec_stp_motor_toff" "sec_stp_motor_vref_pwm" }
sd_create_pin_group -sd_name ${sd_name} -group_name {PRI_STEPPER} -instance_name {focus_mech_inst} -pin_names {"pri_stp_motor_fault_n" "pri_stp_motor_step" "pri_stp_motor_toff" "pri_stp_motor_vref_pwm" "pri_stp_motor_decay1" "pri_stp_motor_m0" "pri_stp_motor_dir" "pri_stp_motor_m1" "pri_stp_motor_en" "pri_stp_motor_sleep_n" "pri_stp_motor_decay0" }
sd_create_pin_group -sd_name ${sd_name} -group_name {LAVDT_DAC} -instance_name {focus_mech_inst} -pin_names {"lvdt_dac_b0" "lvdt_dac_b7" "lvdt_dac_b2" "lvdt_dac_b3" "lvdt_dac_b4" "lvdt_dac_b5" "lvdt_dac_b1" "lvdt_dac_b6" }
sd_create_pin_group -sd_name ${sd_name} -group_name {DBG_FOCUS_MECH} -instance_name {focus_mech_inst} -pin_names {"dbg_pri_stp_motor_dir" "dbg_sec_stp_motor_vref_pwm" "dbg_pri_stp_motor_vref_pwm" "dbg_sec_stp_motor_dir" "dbg_sec_stp_motor_en" "dbg_sec_stp_motor_fault_n" "dbg_pri_stp_motor_en" "dbg_pri_stp_motor_fault_n" "dbg_pri_stp_motor_step" "dbg_sec_stp_motor_step" }



# Add hbeat_runner_inst instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {hbeat_runner} -instance_name {hbeat_runner_inst}
# Exporting Parameters of instance hbeat_runner_inst
sd_configure_core_instance -sd_name ${sd_name} -instance_name {hbeat_runner_inst} -params {\
"CLK_FREQ_HZ:50000000" \
"COUNT_MAX:25000000" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {hbeat_runner_inst}
sd_update_instance -sd_name ${sd_name} -instance_name {hbeat_runner_inst}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {hbeat_runner_inst:hbeat}



# Add hk_hier_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {hk_hier} -instance_name {hk_hier_inst}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {hk_hier_inst:pa3_to_pf_misc0} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {hk_hier_inst:pa3_to_pf_misc1} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {hk_hier_inst:pa3_to_pf_misc2} -value {GND}



# Add interconnect_hier_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {interconnect_hier} -instance_name {interconnect_hier_inst}



# Add osc_clk_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {PF_OSC_C0} -instance_name {osc_clk_inst}



# Add pcie_hier_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {pcie_hier} -instance_name {pcie_hier_inst}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {pcie_hier_inst:PCIE_0_INTERRUPT_OUT}



# Add pll_slvs_ec_pixel_clk_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {PF_CCC_C1} -instance_name {pll_slvs_ec_pixel_clk_inst}



# Add pll_sys_clk_50mhz_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {PF_CCC_SYS_CLK_50MHZ} -instance_name {pll_sys_clk_50mhz_inst}



# Add pps_hier_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {pps_hier} -instance_name {pps_hier_inst}



# Add riscv_hier_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {riscv_hier} -instance_name {riscv_hier_inst}



# Add rst_hier_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {rst_hier} -instance_name {rst_hier_inst}



# Add sys_clkint_buf_inst instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {CLKINT} -instance_name {sys_clkint_buf_inst}



# Add temp_tlm_spi_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {CORESPI_C1} -instance_name {temp_tlm_spi_inst}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {temp_tlm_spi_inst:SPISS} -pin_slices {[0:0]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {temp_tlm_spi_inst:SPISS} -pin_slices {[1:1]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {temp_tlm_spi_inst:SPISS} -pin_slices {[2:2]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {temp_tlm_spi_inst:SPISS} -pin_slices {[3:3]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {temp_tlm_spi_inst:SPISS} -pin_slices {[4:4]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {temp_tlm_spi_inst:SPISS} -pin_slices {[5:5]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {temp_tlm_spi_inst:SPISS} -pin_slices {[7:6]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {temp_tlm_spi_inst:SPISS[7:6]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {temp_tlm_spi_inst:SPIRXAVAIL}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {temp_tlm_spi_inst:SPITXRFM}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {temp_tlm_spi_inst:SPISSI} -value {VCC}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {temp_tlm_spi_inst:SPICLKI} -value {GND}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {temp_tlm_spi_inst:SPIOEN}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {temp_tlm_spi_inst:SPIMODE}



# Add tmtc_uart_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {CORE16550_C0} -instance_name {tmtc_uart_inst}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {tmtc_uart_inst:BAUDOUTN}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {tmtc_uart_inst:CTSN} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {tmtc_uart_inst:DCDN} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {tmtc_uart_inst:DSRN} -value {GND}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {tmtc_uart_inst:DTRN}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {tmtc_uart_inst:OUT1N}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {tmtc_uart_inst:OUT2N}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {tmtc_uart_inst:RIN} -value {VCC}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {tmtc_uart_inst:RTSN}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {tmtc_uart_inst:RXFIFO_EMPTY}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {tmtc_uart_inst:RXFIFO_FULL}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {tmtc_uart_inst:RXRDYN}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {tmtc_uart_inst:TXRDYN}



# Add udp_hier_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {udp_hier} -instance_name {udp_hier_inst}
sd_create_pin_group -sd_name ${sd_name} -group_name {MTX} -instance_name {udp_hier_inst} -pin_names {"MTXSOF" "MTXACPT" "MTXBYTEVALID" "MTXDAT" "MTXEOF" "MTXRDY" }
sd_create_pin_group -sd_name ${sd_name} -group_name {DMA_8GB_INTF} -instance_name {udp_hier_inst} -pin_names {"ddr4_8gb_img_frame_sof_req" "ddr4_8gb_img_frame_core_busy" "ddr4_8gb_img_frame_eof_ack" "ddr4_8gb_img_frame_pyl_acpt" }
sd_create_pin_group -sd_name ${sd_name} -group_name {DMA_16GB_INTF} -instance_name {udp_hier_inst} -pin_names {"ddr4_16gb_img_frame_sof_req" "ddr4_16gb_img_frame_core_busy" "ddr4_16gb_img_frame_eof_ack" "ddr4_16gb_img_frame_pyl_acpt" }
sd_create_pin_group -sd_name ${sd_name} -group_name {DBG} -instance_name {udp_hier_inst} -pin_names {"udp_mux_sel" }
sd_create_pin_group -sd_name ${sd_name} -group_name {MRX} -instance_name {udp_hier_inst} -pin_names {"MRXSOF" "MRXACPT" "MRXBYTEVALID" "MRXRDY" "MRXEOF" "MRXDAT" }



# Add scalar net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"btn0" "dbg_gpio_inst:GPIO_IN[30:30]" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"btn1" "dbg_gpio_inst:GPIO_IN[31:31]" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"bus_to_fav_gpi" "bus_to_fav_gpi_inbuf_inst:PAD" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"bus_to_fav_gpi_inbuf_inst:Y" "bus_to_fav_gpio_inst:GPIO_IN[0:0]" "fav_to_bus_gpo_outbuf_inst:D" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"fav_to_bus_gpo" "fav_to_bus_gpo_outbuf_inst:PAD" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"bus_to_fav_pps" "bus_to_fav_pps_inbuf_inst:PAD" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"bus_to_fav_pps_inbuf_inst:Y" "dbg_mux_inst:pps_in" "pps_hier_inst:pps_in" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"bus_to_fav_trig" "bus_to_fav_trig_inbuf_inst:PAD" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"bus_to_fav_trig_inbuf_inst:Y" "cam_rx_inst:lvds_start" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_buff_en_n" "hk_hier_inst:cam_buff_en_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane0_rxd_n" "cam_rx_inst:cam_lane0_rxd_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane0_rxd_p" "cam_rx_inst:cam_lane0_rxd_p" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane1_rxd_n" "cam_rx_inst:cam_lane1_rxd_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane1_rxd_p" "cam_rx_inst:cam_lane1_rxd_p" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane2_rxd_n" "cam_rx_inst:cam_lane2_rxd_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane2_rxd_p" "cam_rx_inst:cam_lane2_rxd_p" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane3_rxd_n" "cam_rx_inst:cam_lane3_rxd_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane3_rxd_p" "cam_rx_inst:cam_lane3_rxd_p" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane4_rxd_n" "cam_rx_inst:cam_lane4_rxd_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane4_rxd_p" "cam_rx_inst:cam_lane4_rxd_p" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane5_rxd_n" "cam_rx_inst:cam_lane5_rxd_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane5_rxd_p" "cam_rx_inst:cam_lane5_rxd_p" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane6_rxd_n" "cam_rx_inst:cam_lane6_rxd_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane6_rxd_p" "cam_rx_inst:cam_lane6_rxd_p" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane7_rxd_n" "cam_rx_inst:cam_lane7_rxd_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_lane7_rxd_p" "cam_rx_inst:cam_lane7_rxd_p" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_miso" "cam_spi_miso_inbuf_inst:PAD" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_mosi" "cam_spi_mosi_tribuf_inst:PAD" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_osc_en" "hk_hier_inst:cam_osc_en" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_pwr_en" "hk_hier_inst:cam_pwr_en" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_pwr_status" "cam_rx_inst:cam_pwr_status" "hk_hier_inst:cam_pwr_status" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:cam_en" "cam_spi_mosi_tribuf_inst:E" "cam_spi_sck_tribuf_inst:E" "cam_spi_xce_n_tribuf_inst:E" "hk_hier_inst:cam_spi_tribuff_en" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"bus_to_fav_gpio_inst:PCLK" "cam_rx_inst:cam_spi_apb_clk" "dbg_gpio_inst:PCLK" "ddr4_16gb_group_hier_inst:apb_clk" "ddr4_8gb_group_hier_inst:apb_clk" "eth1_hier_inst:clk_50mhz" "eth_pcie_mux_hier_inst:pclk" "flash_spi_inst:PCLK" "focus_mech_inst:sys_clk_50mhz" "hbeat_runner_inst:clk" "hk_hier_inst:pclk" "interconnect_hier_inst:sys_clk_50mhz" "pcie_hier_inst:ACLK" "pll_sys_clk_50mhz_inst:OUT0_FABCLK_0" "pps_hier_inst:sys_clk_50mhz" "riscv_hier_inst:sys_clk_50mhz" "rst_hier_inst:sys_clk_50mhz" "temp_tlm_spi_inst:PCLK" "tmtc_uart_inst:PCLK" "udp_hier_inst:pclk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"bus_to_fav_gpio_inst:PRESETN" "cam_rx_inst:cam_spi_apb_rst_n" "dbg_gpio_inst:PRESETN" "ddr4_16gb_group_hier_inst:apb_rst_n" "ddr4_8gb_group_hier_inst:apb_rst_n" "eth1_hier_inst:eth1_mac_rst_n" "eth_pcie_mux_hier_inst:presetn" "flash_spi_inst:PRESETN" "focus_mech_inst:sys_rst_n" "hbeat_runner_inst:rst_n" "hk_hier_inst:prst_n" "interconnect_hier_inst:rst_n_sys_clk_50mhz" "pcie_hier_inst:ARESETN" "pps_hier_inst:sys_rst_n" "riscv_hier_inst:rst_n_sys_clk_50mhz" "rst_hier_inst:rst_n_sys_clk_50mhz" "temp_tlm_spi_inst:PRESETN" "tmtc_uart_inst:PRESETN" "udp_hier_inst:presetn" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:cam_spi_int" "riscv_hier_inst:cam_spi_irq" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:cam_spi_miso" "cam_spi_miso_inbuf_inst:Y" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:cam_spi_mosi" "cam_spi_mosi_tribuf_inst:D" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:cam_spi_sck" "cam_spi_sck_tribuf_inst:D" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:cam_spi_xce_n" "cam_spi_xce_n_tribuf_inst:D" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:cam_tout_primary" "cam_tout_primary" "dbg_mux_inst:cam_tout" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:cam_trig_int" "dbg_mux_inst:cam_trig_irq" "riscv_hier_inst:cam_trig_irq" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:cam_xclr_n" "cam_xclr_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:cam_xtrig_primary" "cam_xtrig_primary" "dbg_mux_inst:cam_xtrig" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:cdr_ref_clk_148p5mhz" "cam_xcvr_ref_clk_inst:REF_CLK" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:dbg_cam_mux_enable" "dbg_mux_inst:cam_mux_output_en" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:dbg_cam_mux_select" "dbg_mux_inst:ddr4_write_sel" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:dbg_ebd_valid" "dbg_mux_inst:ebd_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:dbg_frame_valid" "dbg_mux_inst:frame_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:dbg_line_valid" "dbg_mux_inst:line_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:ddr4_16gb_frame_valid_out" "ddr4_16gb_group_hier_inst:cam_frame_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:ddr4_16gb_line_valid_out" "ddr4_16gb_group_hier_inst:cam_line_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:ddr4_8gb_frame_valid_out" "ddr4_8gb_group_hier_inst:cam_frame_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:ddr4_8gb_line_valid_out" "ddr4_8gb_group_hier_inst:cam_line_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:osc_clk" "osc_clk_inst:RCOSC_160MHZ_CLK_DIV" "pcie_hier_inst:OSC_CLK" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:pcs_arst_n" "rst_hier_inst:pcs_arst_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:pixel_fab_clk" "ddr4_16gb_group_hier_inst:pixel_clk" "ddr4_8gb_group_hier_inst:pixel_clk" "pll_slvs_ec_pixel_clk_inst:OUT0_FABCLK_0" "rst_hier_inst:pixel_clk_79p2mhz" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:pixel_ref_clk" "pll_slvs_ec_pixel_clk_inst:REF_CLK_0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:pixel_rst_n" "ddr4_16gb_group_hier_inst:pixel_rst_n" "ddr4_8gb_group_hier_inst:pixel_rst_n" "rst_hier_inst:pixel_rst_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:pma_arst_n" "rst_hier_inst:xcvr_init_done" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_sck" "cam_spi_sck_tribuf_inst:PAD" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_spi_xce_n_tribuf_inst:PAD" "cam_xce_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_xcvr_ref_clk_inst:REF_CLK_PAD_N" "ref_clk_148p5mhz_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_xcvr_ref_clk_inst:REF_CLK_PAD_P" "ref_clk_148p5mhz_p" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_gpio0" "dbg_mux_inst:dbg_gpio0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_gpio1" "dbg_mux_inst:dbg_gpio1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_gpio10" "dbg_mux_inst:dbg_gpio10" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_gpio11" "dbg_mux_inst:dbg_gpio11" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_gpio12" "dbg_mux_inst:dbg_gpio12" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_gpio13" "dbg_mux_inst:dbg_gpio13" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_gpio2" "dbg_mux_inst:dbg_gpio2" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_gpio3" "dbg_mux_inst:dbg_gpio3" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_gpio4" "dbg_mux_inst:dbg_gpio4" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_gpio5" "dbg_mux_inst:dbg_gpio5" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_gpio6" "dbg_mux_inst:dbg_gpio6" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_gpio7" "dbg_mux_inst:dbg_gpio7" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_gpio8" "dbg_mux_inst:dbg_gpio8" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_gpio9" "dbg_mux_inst:dbg_gpio9" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_gpio_inst:GPIO_OUT[0:0]" "dbg_mux_inst:user_dbg_gpio" "pf_heartbeat" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_gpio_inst:GPIO_OUT[1:1]" "dbg_mux_inst:stp_dbg_en" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_gpio_inst:GPIO_OUT[2:2]" "dbg_mux_inst:spi_dbg_en" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_gpio_inst:GPIO_OUT[3:3]" "dbg_mux_inst:tlm_dbg_en" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:ddr4_16gb_read_ack" "ddr4_16gb_group_hier_inst:r0_ack_o" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:ddr4_16gb_read_done" "ddr4_16gb_group_hier_inst:r0_done_o" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:ddr4_16gb_read_req" "ddr4_16gb_group_hier_inst:arb_read_req" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:ddr4_16gb_read_valid" "ddr4_16gb_group_hier_inst:r0_data_valid_o" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:ddr4_16gb_write_ack" "ddr4_16gb_group_hier_inst:w0_ack_o" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:ddr4_16gb_write_done" "ddr4_16gb_group_hier_inst:w0_done_o" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:ddr4_16gb_write_req" "ddr4_16gb_group_hier_inst:arb_write_req" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:ddr4_16gb_write_valid" "ddr4_16gb_group_hier_inst:arb_write_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:ddr4_8gb_read_ack" "ddr4_8gb_group_hier_inst:r0_ack_o" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:ddr4_8gb_read_done" "ddr4_8gb_group_hier_inst:r0_done_o" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:ddr4_8gb_read_req" "ddr4_8gb_group_hier_inst:arb_read_req" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:ddr4_8gb_read_valid" "ddr4_8gb_group_hier_inst:r0_data_valid_o" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:ddr4_8gb_write_ack" "ddr4_8gb_group_hier_inst:w0_ack_o" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:ddr4_8gb_write_done" "ddr4_8gb_group_hier_inst:w0_done_o" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:ddr4_8gb_write_req" "ddr4_8gb_group_hier_inst:arb_write_req" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:ddr4_8gb_write_valid" "ddr4_8gb_group_hier_inst:arb_write_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:mac_mtxacpt" "eth1_hier_inst:MTXACPT" "udp_hier_inst:MTXACPT" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:mac_mtxeof" "eth1_hier_inst:MTXEOF" "udp_hier_inst:MTXEOF" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:mac_mtxrdy" "eth1_hier_inst:MTXRDY" "udp_hier_inst:MTXRDY" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:mac_mtxsof" "eth1_hier_inst:MTXSOF" "udp_hier_inst:MTXSOF" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:nvm_spi_dbg_clk" "flash_spi_inst:SPISCLKO" "nvm_spi_sck" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:nvm_spi_dbg_cs_n" "flash_spi_inst:SPISS[0:0]" "nvm_spi_cs_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:nvm_spi_dbg_miso" "flash_spi_inst:SPISDI" "nvm_spi_sio1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:nvm_spi_dbg_mosi" "flash_spi_inst:SPISDO" "nvm_spi_sio0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:pps_out" "pps_hier_inst:pps_out" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:pri_stp_motor_dir" "focus_mech_inst:dbg_pri_stp_motor_dir" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:pri_stp_motor_en" "focus_mech_inst:dbg_pri_stp_motor_en" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:pri_stp_motor_fault_n" "focus_mech_inst:dbg_pri_stp_motor_fault_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:pri_stp_motor_step" "focus_mech_inst:dbg_pri_stp_motor_step" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:pri_stp_motor_vref_pwm" "focus_mech_inst:dbg_pri_stp_motor_vref_pwm" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:sec_stp_motor_dir" "focus_mech_inst:dbg_sec_stp_motor_dir" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:sec_stp_motor_en" "focus_mech_inst:dbg_sec_stp_motor_en" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:sec_stp_motor_fault_n" "focus_mech_inst:dbg_sec_stp_motor_fault_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:sec_stp_motor_step" "focus_mech_inst:dbg_sec_stp_motor_step" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:sec_stp_motor_vref_pwm" "focus_mech_inst:dbg_sec_stp_motor_vref_pwm" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:tlm_spi_dbg_cs1_n" "temp_tlm_spi_inst:SPISS[0:0]" "tlm_spi_cs1_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:tlm_spi_dbg_cs2_n" "temp_tlm_spi_inst:SPISS[1:1]" "tlm_spi_cs2_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:tlm_spi_dbg_cs3_n" "temp_tlm_spi_inst:SPISS[2:2]" "tlm_spi_cs3_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:tlm_spi_dbg_cs4_n" "temp_tlm_spi_inst:SPISS[3:3]" "tlm_spi_cs4_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:tlm_spi_dbg_cs5_n" "temp_tlm_spi_inst:SPISS[4:4]" "tlm_spi_cs5_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:tlm_spi_dbg_cs6_n" "temp_tlm_spi_inst:SPISS[5:5]" "tlm_spi_cs6_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:tlm_spi_dbg_miso" "temp_tlm_spi_inst:SPISDI" "tlm_spi_miso" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:tlm_spi_dbg_mosi" "temp_tlm_spi_inst:SPISDO" "tlm_spi_mosi" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:tlm_spi_dbg_sclk" "temp_tlm_spi_inst:SPISCLKO" "tlm_spi_sclk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:uart_rx" "tmtc_uart_inst:SIN" "uart0_rx" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:uart_tx" "tmtc_uart_inst:SOUT" "uart0_tx" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr16gb_pwr_status" "hk_hier_inst:ddr16gb_pwr_status" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:ACT_N" "ddr4_r0_act_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:CAS_N" "ddr4_r0_cas_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:CK0" "ddr4_r0_ck0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:CK0_N" "ddr4_r0_ck0_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:CKE" "ddr4_r0_cke" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:CS_N" "ddr4_r0_cs_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:ODT" "ddr4_r0_odt" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:RAS_N" "ddr4_r0_ras_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:RESET_N" "ddr4_r0_reset_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:SHIELD0" "ddr4_r0_shield0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:SHIELD1" "ddr4_r0_shield1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:SHIELD2" "ddr4_r0_shield2" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:SHIELD3" "ddr4_r0_shield3" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:SHIELD4" "ddr4_r0_shield4" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:SHIELD5" "ddr4_r0_shield5" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:SHIELD6" "ddr4_r0_shield6" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:SHIELD7" "ddr4_r0_shield7" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:SHIELD8" "ddr4_r0_shield8" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:WE_N" "ddr4_r0_we_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:core_busy" "udp_hier_inst:ddr4_16gb_img_frame_core_busy" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:ddr4_16gb_clk" "eth_pcie_mux_hier_inst:ddr4_16gb_clk" "rst_hier_inst:ddr4_16gb_clk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:ddr4_16gb_ctrlr_ready" "rst_hier_inst:ddr4_16gb_ctrlr_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:ddr4_16gb_pll_lock" "rst_hier_inst:ddr4_16gb_pll_lock" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:ddr4_16gb_frame_read_done_int" "frame_read_done_int:A" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:ddr4_16gb_rst_n" "eth_pcie_mux_hier_inst:ddr4_16gb_resetn" "rst_hier_inst:rst_n_ddr4_16gb_clk_domain" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:eof_ack" "udp_hier_inst:ddr4_16gb_img_frame_eof_ack" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:pyl_acpt" "udp_hier_inst:ddr4_16gb_img_frame_pyl_acpt" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:sof_req" "udp_hier_inst:ddr4_16gb_img_frame_sof_req" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:sys_rst_n" "ddr4_8gb_group_hier_inst:sys_rst_n" "pll_sys_clk_50mhz_inst:PLL_LOCK_0" "rst_hier_inst:sys_clk_50mhz_pll_lock" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:udp_clk" "ddr4_8gb_group_hier_inst:udp_clk" "eth1_hier_inst:eth1_mac_clk_100mhz" "pll_sys_clk_50mhz_inst:OUT1_FABCLK_0" "rst_hier_inst:clk_100mhz" "udp_hier_inst:udp_clk_100mhz" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:udp_rst_n" "ddr4_8gb_group_hier_inst:udp_rst_n" "rst_hier_inst:rst_n_100mhz_clk_domain" "udp_hier_inst:udp_rst_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:ACT_N" "ddr4_r2_act_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:CAS_N" "ddr4_r2_cas_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:CK0" "ddr4_r2_ck0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:CK0_N" "ddr4_r2_ck0_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:CKE" "ddr4_r2_cke" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:CS_N" "ddr4_r2_cs_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:ODT" "ddr4_r2_odt" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:RAS_N" "ddr4_r2_ras_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:RESET_N" "ddr4_r2_reset_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:SHIELD0" "ddr4_r2_shield0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:SHIELD1" "ddr4_r2_shield1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:SHIELD2" "ddr4_r2_shield2" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:SHIELD3" "ddr4_r2_shield3" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:SHIELD4" "ddr4_r2_shield4" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:WE_N" "ddr4_r2_we_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:core_busy" "udp_hier_inst:ddr4_8gb_img_frame_core_busy" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:ddr4_8gb_clk" "eth_pcie_mux_hier_inst:ddr4_8gb_clk" "pcie_hier_inst:AXI_CLK" "rst_hier_inst:ddr4_8gb_clk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:ddr4_8gb_ctrlr_ready" "rst_hier_inst:ddr4_8gb_ctrlr_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:ddr4_8gb_pll_lock" "pcie_hier_inst:AXI_CLK_STABLE" "rst_hier_inst:ddr4_8gb_pll_lock" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:ddr4_8gb_frame_read_done_int" "frame_read_done_int:B" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:ddr_8gb_rst_n" "eth_pcie_mux_hier_inst:ddr4_8gb_resetn" "pcie_hier_inst:RESET_N" "rst_hier_inst:rst_n_ddr4_8gb_clk_domain" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:eof_ack" "udp_hier_inst:ddr4_8gb_img_frame_eof_ack" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:pyl_acpt" "udp_hier_inst:ddr4_8gb_img_frame_pyl_acpt" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:sof_req" "udp_hier_inst:ddr4_8gb_img_frame_sof_req" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr8gb_pwr_status" "hk_hier_inst:ddr8gb_pwr_status" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_ctrl_clk_squelch_in" "eth1_hier_inst:eth1_ctrl_clk_squelch_in" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_ctrl_comma_mode" "eth1_hier_inst:eth1_ctrl_comma_mode" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_hier_inst:MRXACPT" "udp_hier_inst:MRXACPT" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_hier_inst:MRXEOF" "udp_hier_inst:MRXEOF" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_hier_inst:MRXRDY" "udp_hier_inst:MRXRDY" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_hier_inst:MRXSOF" "udp_hier_inst:MRXSOF" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_hier_inst:eth1_phy_mdc" "eth1_phy_mdc" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_hier_inst:eth1_phy_mdio" "eth1_phy_mdio" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_hier_inst:eth1_phy_rst_n" "eth1_phy_rst_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_hier_inst:eth1_pwr_status" "hk_hier_inst:eth1_pwr_status_out" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_hier_inst:eth1_rgmii_rx_ctl" "eth1_rgmii_rx_ctl" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_hier_inst:eth1_rgmii_rxc" "eth1_rgmii_rxc" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_hier_inst:eth1_rgmii_tx_ctl" "eth1_rgmii_tx_ctl" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_hier_inst:eth1_rgmii_txc" "eth1_rgmii_txc" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_hier_inst:eth1_stat_clkout" "eth1_stat_clkout" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_hier_inst:eth1_stat_fastlink_fail" "eth1_stat_fastlink_fail" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_hier_inst:eth1_stat_mdint" "eth1_stat_mdint" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_hier_inst:eth1_stat_rcvrd_clk" "eth1_stat_rcvrd_clk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_pwr_en" "hk_hier_inst:eth1_pwr_en" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_pwr_status" "hk_hier_inst:eth1_pwr_status" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth2_pwr_en" "hk_hier_inst:eth2_pwr_en" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth2_pwr_status" "hk_hier_inst:eth2_pwr_status" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"frame_read_done_int:Y" "riscv_hier_inst:frame_read_done_irq" "dbg_mux_inst:frame_read_done_irq" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:lvdt_adc_spi_cs_n" "lvdt_adc_spi_cs_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:lvdt_adc_spi_miso" "lvdt_adc_spi_miso" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:lvdt_adc_spi_mosi" "lvdt_adc_spi_mosi" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:lvdt_adc_spi_sclk" "lvdt_adc_spi_sclk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:lvdt_dac_b0" "lvdt_dac_b0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:lvdt_dac_b1" "lvdt_dac_b1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:lvdt_dac_b2" "lvdt_dac_b2" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:lvdt_dac_b3" "lvdt_dac_b3" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:lvdt_dac_b4" "lvdt_dac_b4" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:lvdt_dac_b5" "lvdt_dac_b5" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:lvdt_dac_b6" "lvdt_dac_b6" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:lvdt_dac_b7" "lvdt_dac_b7" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:lvdt_gain_switch" "lvdt_gain_switch" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:pri_stp_motor_decay0" "pri_stp_motor_decay0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:pri_stp_motor_decay1" "pri_stp_motor_decay1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:pri_stp_motor_dir" "pri_stp_motor_dir" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:pri_stp_motor_en" "pri_stp_motor_en" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:pri_stp_motor_fault_n" "pri_stp_motor_fault_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:pri_stp_motor_m0" "pri_stp_motor_m0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:pri_stp_motor_m1" "pri_stp_motor_m1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:pri_stp_motor_sleep_n" "pri_stp_motor_sleep_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:pri_stp_motor_step" "pri_stp_motor_step" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:pri_stp_motor_toff" "pri_stp_motor_toff" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:pri_stp_motor_vref_pwm" "pri_stp_motor_vref_pwm" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:sec_stp_motor_decay0" "sec_stp_motor_decay0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:sec_stp_motor_decay1" "sec_stp_motor_decay1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:sec_stp_motor_dir" "sec_stp_motor_dir" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:sec_stp_motor_en" "sec_stp_motor_en" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:sec_stp_motor_fault_n" "sec_stp_motor_fault_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:sec_stp_motor_m0" "sec_stp_motor_m0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:sec_stp_motor_m1" "sec_stp_motor_m1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:sec_stp_motor_sleep_n" "sec_stp_motor_sleep_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:sec_stp_motor_step" "sec_stp_motor_step" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:sec_stp_motor_toff" "sec_stp_motor_toff" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:sec_stp_motor_vref_pwm" "sec_stp_motor_vref_pwm" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"hk_hier_inst:lvds_pwr_en" "lvds_pwr_en" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"hk_hier_inst:lvds_pwr_status" "lvds_pwr_status" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"hk_hier_inst:lvdt_pwr_en" "lvdt_pwr_en" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"hk_hier_inst:lvdt_pwr_status" "lvdt_pwr_status" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"hk_hier_inst:pa3_pwr_status" "pa3_pwr_status" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"hk_hier_inst:pa3_to_pf_misc10" "pa3_to_pf_misc10" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"hk_hier_inst:pa3_to_pf_misc11" "pa3_to_pf_misc11" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"hk_hier_inst:pa3_to_pf_misc12" "pa3_to_pf_misc12" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"hk_hier_inst:pa3_to_pf_misc13" "pa3_to_pf_misc13" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"hk_hier_inst:pa3_to_pf_misc14" "pa3_to_pf_misc14" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"hk_hier_inst:pa3_to_pf_misc15" "pa3_to_pf_misc15" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"hk_hier_inst:pa3_to_pf_misc3" "pa3_to_pf_misc3" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"hk_hier_inst:pa3_to_pf_misc4" "pa3_to_pf_misc4" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"hk_hier_inst:pa3_to_pf_misc5" "pa3_to_pf_misc5" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"hk_hier_inst:pa3_to_pf_misc6" "pa3_to_pf_misc6" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"hk_hier_inst:pa3_to_pf_misc7" "pa3_to_pf_misc7" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"hk_hier_inst:pa3_to_pf_misc8" "pa3_to_pf_misc8" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"hk_hier_inst:pa3_to_pf_misc9" "pa3_to_pf_misc9" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"hk_hier_inst:pf_pwr_status" "pf_pwr_status" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"hk_hier_inst:step_down_pwr_status" "step_down_pwr_status" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"hk_hier_inst:stepper_pri_pwr_en" "stepper_pri_pwr_en" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"hk_hier_inst:stepper_pri_pwr_status" "stepper_pri_pwr_status" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"hk_hier_inst:stepper_sec_pwr_en" "stepper_sec_pwr_en" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"hk_hier_inst:stepper_sec_pwr_status" "stepper_sec_pwr_status" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"jtag_tck" "riscv_hier_inst:jtag_tck" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"jtag_tdi" "riscv_hier_inst:jtag_tdi" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"jtag_tdo" "riscv_hier_inst:jtag_tdo" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"jtag_tms" "riscv_hier_inst:jtag_tms" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"jtag_trstb" "riscv_hier_inst:jtag_trstb" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pcie0_lane0_rxd_n" "pcie_hier_inst:PCIESS_LANE_RXD0_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pcie0_lane0_rxd_p" "pcie_hier_inst:PCIESS_LANE_RXD0_P" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pcie0_lane0_txd_n" "pcie_hier_inst:PCIESS_LANE_TXD0_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pcie0_lane0_txd_p" "pcie_hier_inst:PCIESS_LANE_TXD0_P" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pcie0_lane1_rxd_n" "pcie_hier_inst:PCIESS_LANE_RXD1_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pcie0_lane1_rxd_p" "pcie_hier_inst:PCIESS_LANE_RXD1_P" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pcie0_lane1_txd_n" "pcie_hier_inst:PCIESS_LANE_TXD1_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pcie0_lane1_txd_p" "pcie_hier_inst:PCIESS_LANE_TXD1_P" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pcie0_perstn" "pcie_hier_inst:PCIE_0_PERST_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pcie_ext_ref_clk_n" "pcie_hier_inst:REF_CLK_PAD_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pcie_ext_ref_clk_p" "pcie_hier_inst:REF_CLK_PAD_P" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pcie_hier_inst:PCIE_INIT_DONE" "rst_hier_inst:pcie_init_done" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pll_slvs_ec_pixel_clk_inst:PLL_LOCK_0" "rst_hier_inst:pixel_clk_79p2mhz_pll_lock" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pll_sys_clk_50mhz_inst:REF_CLK_0" "sys_clkint_buf_inst:Y" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"pps_hier_inst:pps_irq" "riscv_hier_inst:pps_irq" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"riscv_hier_inst:tmtc_ext_irq" "tmtc_uart_inst:INTR" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"sys_clk_50mhz" "sys_clkint_buf_inst:A" }

# Add bus net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:ddr4_16gb_cam_data_out" "ddr4_16gb_group_hier_inst:cam_data_in" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:ddr4_16gb_frame_index" "ddr4_16gb_group_hier_inst:ddr4_16gb_wr_frame_index" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:ddr4_8gb_cam_data_out" "ddr4_8gb_group_hier_inst:cam_data_in" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:ddr4_8gb_frame_index" "ddr4_8gb_group_hier_inst:ddr4_8gb_wr_frame_index" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:timestamp_nsec" "pps_hier_inst:nanoseconds" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:timestamp_sec" "pps_hier_inst:seconds" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_mux_inst:ddr4_read_sel" "udp_hier_inst:udp_mux_sel" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:A" "ddr4_r0_a" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:BA" "ddr4_r0_ba" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:BG" "ddr4_r0_bg" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:DM_N" "ddr4_r0_dm_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:DQ" "ddr4_r0_dq" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:DQS" "ddr4_r0_dqs" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:DQS_N" "ddr4_r0_dqs_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:A" "ddr4_r2_a" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:BA" "ddr4_r2_ba" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:BG" "ddr4_r2_bg" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:DM_N" "ddr4_r2_dm_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:DQ" "ddr4_r2_dq" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:DQS" "ddr4_r2_dqs" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:DQS_N" "ddr4_r2_dqs_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_hier_inst:MRXBYTEVALID" "udp_hier_inst:MRXBYTEVALID" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_hier_inst:MRXDAT" "udp_hier_inst:MRXDAT" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_hier_inst:MTXBYTEVALID" "udp_hier_inst:MTXBYTEVALID" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_hier_inst:MTXDAT" "udp_hier_inst:MTXDAT" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_hier_inst:eth1_rgmii_rxd" "eth1_rgmii_rxd" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_hier_inst:eth1_rgmii_txd" "eth1_rgmii_txd" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"hk_hier_inst:pa3_fw_version" "pa3_fw_version" }

# Add bus interface net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"bus_to_fav_gpio_inst:APB_bif" "interconnect_hier_inst:apb1_slave12" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:cam_fault_detector_apb" "interconnect_hier_inst:apb1_slave11" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:cam_mux_apb" "interconnect_hier_inst:apb0_slave11" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:cam_trig_ctrl_apb" "interconnect_hier_inst:apb0_slave15" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:gpo_cam_apb" "interconnect_hier_inst:apb0_slave3" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:img_metadata_apb" "interconnect_hier_inst:apb0_slave12" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"cam_rx_inst:slvsec_spi_apb" "interconnect_hier_inst:apb0_slave1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_gpio_inst:APB_bif" "interconnect_hier_inst:apb1_slave2" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:DDR4_16GB_ARBITER" "eth_pcie_mux_hier_inst:AXI4_S_DDR4_16GB_ARBITER" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:DDR4_16GB_S_AXIMM" "eth_pcie_mux_hier_inst:AXI4_M_DDR4_16GB" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:M_AXIS_UDP_PYL" "udp_hier_inst:S_AXIS_IMG_FRAM_PYL_DDR4_16GB" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:M_AXIS_UDP_PYL_SIZE" "udp_hier_inst:S_AXIS_IMG_FRAME_PYL_SIZE_DDR4_16GB" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:s_apb" "interconnect_hier_inst:apb0_slave5" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:s_apb_dma_read_ddr4_16gb_reg" "interconnect_hier_inst:apb1_slave4" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_16gb_group_hier_inst:s_apb_dma_read_ctrl_reg" "interconnect_hier_inst:apb0_slave7" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:DDR4_8GB_ARBITER" "eth_pcie_mux_hier_inst:AXI4_S_DDR4_8GB_ARBITER" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:DDR4_8GB_S_AXIMM" "eth_pcie_mux_hier_inst:AXI4_M_DDR4_8GB" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:M_AXIS_UDP_PYL" "udp_hier_inst:S_AXIS_IMG_FRAM_PYL_DDR4_8GB" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:M_AXIS_UDP_PYL_SIZE" "udp_hier_inst:S_AXIS_IMG_FRAME_PYL_SIZE_DDR4_8GB" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:s_apb" "interconnect_hier_inst:apb0_slave4" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:s_apb_dma_read_ddr4_8gb_reg" "interconnect_hier_inst:apb1_slave3" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"ddr4_8gb_group_hier_inst:s_apb_dma_read_ctrl_reg" "interconnect_hier_inst:apb0_slave6" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_hier_inst:eth1_ctrl_apb" "interconnect_hier_inst:apb0_slave10" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_hier_inst:eth1_mac_apb" "interconnect_hier_inst:apb0_slave8" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth1_hier_inst:eth1_stat_apb" "interconnect_hier_inst:apb0_slave9" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth_pcie_mux_hier_inst:AXI4_S_PCIE" "pcie_hier_inst:AXI_0_MASTER" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"eth_pcie_mux_hier_inst:s_apb" "interconnect_hier_inst:apb1_slave9" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"flash_spi_inst:APB_bif" "interconnect_hier_inst:apb1_slave8" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:APB_LVDT_Gain" "interconnect_hier_inst:apb2_slave6" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:LVDT_READOUT_APB_PRI_I" "interconnect_hier_inst:apb2_slave8" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:LVDT_READOUT_APB_PRI_Q" "interconnect_hier_inst:apb2_slave10" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:LVDT_READOUT_APB_SEC_I" "interconnect_hier_inst:apb2_slave9" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:LVDT_READOUT_APB_SEC_Q" "interconnect_hier_inst:apb2_slave7" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:PRI_STP_APB_STEPPER_CONTROLS" "interconnect_hier_inst:apb2_slave0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:PRI_STP_APB_STEPPER_OUT" "interconnect_hier_inst:apb2_slave2" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:PRI_STP_APB_STEPPER_OVERFLOW" "interconnect_hier_inst:apb2_slave14" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:PRI_STP_APB_VREF" "interconnect_hier_inst:apb2_slave1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:SEC_STP_APB_STEPPER_CONTROLS" "interconnect_hier_inst:apb2_slave3" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:SEC_STP_APB_STEPPER_OUT" "interconnect_hier_inst:apb2_slave5" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:SEC_STP_APB_STEPPER_OVERFLOW" "interconnect_hier_inst:apb2_slave15" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:SEC_STP_APB_VREF" "interconnect_hier_inst:apb2_slave4" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"focus_mech_inst:apb_stepper_wd" "interconnect_hier_inst:apb0_slave13" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"hk_hier_inst:gpi_hk_status_apb" "interconnect_hier_inst:apb1_slave0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"hk_hier_inst:gpo_hk_pwr_ctrl_apb" "interconnect_hier_inst:apb1_slave1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"interconnect_hier_inst:apb0_slave0" "tmtc_uart_inst:APBtarget" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"interconnect_hier_inst:apb0_slave14" "udp_hier_inst:udp_tx_reg_apb" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"interconnect_hier_inst:apb1_slave10" "riscv_hier_inst:apb_junc_temp" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"interconnect_hier_inst:apb1_slave5" "pps_hier_inst:apb_pps" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"interconnect_hier_inst:apb1_slave6" "riscv_hier_inst:apb_timer" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"interconnect_hier_inst:apb1_slave7" "riscv_hier_inst:apb_hw_version" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"interconnect_hier_inst:apb2_slave11" "rst_hier_inst:apb_async_rst_ddr4_16gb" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"interconnect_hier_inst:apb2_slave12" "rst_hier_inst:apb_async_rst_ddr4_8gb" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"interconnect_hier_inst:apb2_slave13" "temp_tlm_spi_inst:APB_bif" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"interconnect_hier_inst:riscv_aximm" "riscv_hier_inst:riscv_axi4_initator" }

# Re-enable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 1
# Save the SmartDesign 
save_smartdesign -sd_name ${sd_name}
# Generate SmartDesign "top"
generate_component -component_name ${sd_name}
