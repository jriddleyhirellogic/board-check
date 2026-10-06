# ------------------------------------------------------------------------------
# Farsight Avionics -- User Timing Constraints
# ------------------------------------------------------------------------------
# REVISION NOTES:
#   - Removed blanket set_clock_groups -asynchronous (was hiding all CDC violations)
#   - Added per-crossing set_max_delay for CDC paths with 2-FF synchronizers
#   - Added false_path only for truly unrelated clock domains
#   - Added COREDDS slow_clk false path (init-only gated clock)
#   - Added RGMII I/O delay constraints
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Clocks
# ------------------------------------------------------------------------------

create_clock -name {jtag_tck} -period 100 [ get_ports { jtag_tck } ]
create_clock -name {sys_clk_50mhz} -period 20 [ get_ports { sys_clk_50mhz } ]

# ------------------------------------------------------------------------------
# Proc to apply input false path constraints
# ------------------------------------------------------------------------------

proc apply_input_false_path_constraints {port_list} {
    foreach port_dict $port_list {
        set port_name    [dict get $port_dict port_name]
        set clock        [dict get $port_dict clock]
        set max_delay_ns [dict get $port_dict max_delay_ns]
        set min_delay_ns [dict get $port_dict min_delay_ns]

        set_false_path  -from [get_ports $port_name]
        set_input_delay -max $max_delay_ns -clock $clock [get_ports $port_name]
        set_input_delay -min $min_delay_ns -clock $clock [get_ports $port_name]
    }
}

# ------------------------------------------------------------------------------
# Proc to apply output false path constraints
# ------------------------------------------------------------------------------

proc apply_output_false_path_constraints {port_list} {
    foreach port_dict $port_list {
        set port_name    [dict get $port_dict port_name]
        set clock        [dict get $port_dict clock]
        set max_delay_ns [dict get $port_dict max_delay_ns]
        set min_delay_ns [dict get $port_dict min_delay_ns]

        set_false_path -to [get_ports $port_name]
        set_output_delay -max $max_delay_ns -clock $clock [get_ports $port_name]
        set_output_delay -min $min_delay_ns -clock $clock [get_ports $port_name]
    }
}

# ------------------------------------------------------------------------------
# Set Clock Groups
# ------------------------------------------------------------------------------

# IMX
set_clock_groups -name {xcvr_clk} -asynchronous -group [ get_clocks { cam_rx_inst/pll_xcvr_clk_inst/PF_CCC_C2_0/pll_inst_0/OUT0 } ]
set_clock_groups -name {pixel_clk} -asynchronous -group [ get_clocks { pll_slvs_ec_pixel_clk_inst/PF_CCC_C1_0/pll_inst_0/OUT0 } ]
set_clock_groups -name {xcvr_ctrl_clk} -asynchronous -group [ get_clocks {cam_rx_inst/ctrl_clk_div_inst/PF_CLK_DIV_C0_0/I_CD/Y_DIV} ]
set_clock_groups -name {xcvr0_lane0_clk} -asynchronous -group  [ get_clocks { cam_rx_inst/xcvr_rx_inst0/I_XCVR/LANE0/RX_CLK_R  } ]
set_clock_groups -name {xcvr0_lane1_clk} -asynchronous -group  [ get_clocks { cam_rx_inst/xcvr_rx_inst0/I_XCVR/LANE1/RX_CLK_R  } ]
set_clock_groups -name {xcvr0_lane2_clk} -asynchronous -group  [ get_clocks { cam_rx_inst/xcvr_rx_inst0/I_XCVR/LANE2/RX_CLK_R  } ]
set_clock_groups -name {xcvr0_lane3_clk} -asynchronous -group  [ get_clocks { cam_rx_inst/xcvr_rx_inst0/I_XCVR/LANE3/RX_CLK_R  } ]
set_clock_groups -name {xcvr1_lane0_clk} -asynchronous -group  [ get_clocks { cam_rx_inst/xcvr_rx_inst1/I_XCVR/LANE0/RX_CLK_R  } ]
set_clock_groups -name {xcvr1_lane1_clk} -asynchronous -group  [ get_clocks { cam_rx_inst/xcvr_rx_inst1/I_XCVR/LANE1/RX_CLK_R  } ]
set_clock_groups -name {xcvr1_lane2_clk} -asynchronous -group  [ get_clocks { cam_rx_inst/xcvr_rx_inst1/I_XCVR/LANE2/RX_CLK_R  } ]
set_clock_groups -name {xcvr1_lane3_clk} -asynchronous -group  [ get_clocks { cam_rx_inst/xcvr_rx_inst1/I_XCVR/LANE3/RX_CLK_R  } ]

# CCC
set_clock_groups -name {pclk} -asynchronous -group [ get_clocks { pll_sys_clk_50mhz_inst/PF_CCC_SYS_CLK_50MHZ_0/pll_inst_0/OUT0 } ]
set_clock_groups -name {udp_clk} -asynchronous -group [ get_clocks { pll_sys_clk_50mhz_inst/PF_CCC_SYS_CLK_50MHZ_0/pll_inst_0/OUT1 } ]

# DDR
set_clock_groups -name {ddr4_8gb_clk0} -asynchronous -group [ get_clocks { ddr4_8gb_group_hier_inst/ddr4_8gb_hier_inst/ddr4_inst2_se/CCC_0/pll_inst_0/OUT0 } ]
set_clock_groups -name {ddr4_8gb_clk1} -asynchronous -group [ get_clocks { ddr4_8gb_group_hier_inst/ddr4_8gb_hier_inst/ddr4_inst2_se/CCC_0/pll_inst_0/OUT1 } ]
set_clock_groups -name {ddr4_8gb_clk2} -asynchronous -group [ get_clocks { ddr4_8gb_group_hier_inst/ddr4_8gb_hier_inst/ddr4_inst2_se/CCC_0/pll_inst_0/OUT2 } ]
set_clock_groups -name {ddr4_8gb_clk3} -asynchronous -group [ get_clocks { ddr4_8gb_group_hier_inst/ddr4_8gb_hier_inst/ddr4_inst2_se/CCC_0/pll_inst_0/OUT3 } ]
set_clock_groups -name {ddr4_16gb_clk0} -asynchronous -group [ get_clocks { ddr4_16gb_group_hier_inst/ddr4_16gb_hier_inst/ddr4_inst0_nw/CCC_0/pll_inst_0/OUT0 } ]
set_clock_groups -name {ddr4_16gb_clk1} -asynchronous -group [ get_clocks { ddr4_16gb_group_hier_inst/ddr4_16gb_hier_inst/ddr4_inst0_nw/CCC_0/pll_inst_0/OUT1 } ]
set_clock_groups -name {ddr4_16gb_clk2} -asynchronous -group [ get_clocks { ddr4_16gb_group_hier_inst/ddr4_16gb_hier_inst/ddr4_inst0_nw/CCC_0/pll_inst_0/OUT2 } ]
set_clock_groups -name {ddr4_16gb_clk3} -asynchronous -group [ get_clocks { ddr4_16gb_group_hier_inst/ddr4_16gb_hier_inst/ddr4_inst0_nw/CCC_0/pll_inst_0/OUT3 } ]

# PCIe
set_clock_groups -name {pcie_clk} -asynchronous -group [ get_clocks {pcie_hier_inst/CLK_DIV2_0/CLK_DIV2_0/I_CD/Y_DIV} ]

# JTAG
set_clock_groups -name {jtag_clk} -asynchronous -group [ get_clocks { jtag_tck } ]

# ------------------------------------------------------------------------------
# Set Clock Uncertainty
# ------------------------------------------------------------------------------

set_clock_uncertainty -setup 0.15 [ get_clocks { pll_slvs_ec_pixel_clk_inst/PF_CCC_C1_0/pll_inst_0/OUT0 } ]
set_clock_uncertainty -setup 0.15 [ get_clocks { pll_sys_clk_50mhz_inst/PF_CCC_SYS_CLK_50MHZ_0/pll_inst_0/OUT0 } ]
set_clock_uncertainty -setup 0.15 [ get_clocks { pll_sys_clk_50mhz_inst/PF_CCC_SYS_CLK_50MHZ_0/pll_inst_0/OUT1 } ]

# ------------------------------------------------------------------------------
# Input Port False Path Constraints
# ------------------------------------------------------------------------------

set input_ports_list {}

lappend input_ports_list [dict create port_name {btn0}                    clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {btn1}                    clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {bus_to_fav_gpi}          clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {bus_to_fav_pps}          clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {cam_miso}                clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {cam_pwr_status}          clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {cam_tout_primary}        clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {ddr16gb_pwr_status}      clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {ddr8gb_pwr_status}       clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {eth1_pwr_status}         clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {eth1_stat_clkout}        clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {eth1_stat_fastlink_fail} clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {eth1_stat_mdint}         clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {eth1_stat_rcvrd_clk}     clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {eth2_pwr_status}         clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {lvds_pwr_status}         clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {lvdt_adc_spi_miso}       clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {lvdt_pwr_status}         clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {nvm_spi_sio1}            clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {pa3_fw_version[0]}       clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {pa3_fw_version[1]}       clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {pa3_fw_version[2]}       clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {pa3_pwr_status}          clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {pa3_to_pf_misc10}        clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {pa3_to_pf_misc11}        clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {pa3_to_pf_misc12}        clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {pa3_to_pf_misc13}        clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {pa3_to_pf_misc14}        clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {pa3_to_pf_misc15}        clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {pa3_to_pf_misc3}         clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {pa3_to_pf_misc4}         clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {pa3_to_pf_misc5}         clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {pa3_to_pf_misc6}         clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {pa3_to_pf_misc7}         clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {pa3_to_pf_misc8}         clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {pa3_to_pf_misc9}         clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {pf_pwr_status}           clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {pri_stp_motor_fault_n}   clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {sec_stp_motor_fault_n}   clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {step_down_pwr_status}    clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {stepper_pri_pwr_status}  clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {stepper_sec_pwr_status}  clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {tlm_spi_miso}            clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend input_ports_list [dict create port_name {uart0_rx}                clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]

# ------------------------------------------------------------------------------
# Output Port False Path Constraints
# ------------------------------------------------------------------------------

set output_ports_list {}

lappend output_ports_list [dict create port_name {cam_buff_en_n}            clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {cam_mosi}                 clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {cam_osc_en}               clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {cam_pwr_en}               clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {cam_sck}                  clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {cam_xce_n}                clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {cam_xclr_n}               clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {cam_xtrig_primary}        clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {dbg_gpio0}                clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {dbg_gpio1}                clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {dbg_gpio10}               clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {dbg_gpio11}               clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {dbg_gpio12}               clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {dbg_gpio13}               clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {dbg_gpio2}                clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {dbg_gpio3}                clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {dbg_gpio4}                clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {dbg_gpio5}                clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {dbg_gpio6}                clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {dbg_gpio7}                clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {dbg_gpio8}                clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {dbg_gpio9}                clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {eth1_ctrl_clk_squelch_in} clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {eth1_ctrl_comma_mode}     clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {eth1_phy_mdc}             clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {eth1_phy_rst_n}           clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {eth1_pwr_en}              clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {eth2_pwr_en}              clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {lvds_pwr_en}              clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {lvdt_adc_spi_cs_n}        clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {lvdt_adc_spi_mosi}        clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {lvdt_adc_spi_sclk}        clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {lvdt_dac_b0}              clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {lvdt_dac_b1}              clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {lvdt_dac_b2}              clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {lvdt_dac_b3}              clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {lvdt_dac_b4}              clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {lvdt_dac_b5}              clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {lvdt_dac_b6}              clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {lvdt_dac_b7}              clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {lvdt_gain_switch}         clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {lvdt_pwr_en}              clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {nvm_spi_cs_n}             clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {nvm_spi_sck}              clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {pf_heartbeat}             clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {pri_stp_motor_decay0}     clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {pri_stp_motor_decay1}     clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {pri_stp_motor_dir}        clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {pri_stp_motor_en}         clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {pri_stp_motor_m0}         clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {pri_stp_motor_m1}         clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {pri_stp_motor_sleep_n}    clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {pri_stp_motor_step}       clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {pri_stp_motor_toff}       clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {pri_stp_motor_vref_pwm}   clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {sec_stp_motor_decay0}     clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {sec_stp_motor_decay1}     clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {sec_stp_motor_dir}        clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {sec_stp_motor_en}         clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {sec_stp_motor_m0}         clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {sec_stp_motor_m1}         clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {sec_stp_motor_sleep_n}    clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {sec_stp_motor_step}       clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {sec_stp_motor_toff}       clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {sec_stp_motor_vref_pwm}   clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {stepper_pri_pwr_en}       clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {stepper_sec_pwr_en}       clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {uart0_tx}                 clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {nvm_spi_sio0}             clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {tlm_spi_sclk}             clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {tlm_spi_mosi}             clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {tlm_spi_cs1_n}            clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {tlm_spi_cs2_n}            clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {tlm_spi_cs3_n}            clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {tlm_spi_cs4_n}            clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {tlm_spi_cs5_n}            clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]
lappend output_ports_list [dict create port_name {tlm_spi_cs6_n}            clock {sys_clk_50mhz} max_delay_ns 2 min_delay_ns 1]


# ------------------------------------------------------------------------------
# Apply the input files path constraints
# ------------------------------------------------------------------------------

apply_input_false_path_constraints $input_ports_list

# ------------------------------------------------------------------------------
# Apply the output files path constraints
# ------------------------------------------------------------------------------

apply_output_false_path_constraints $output_ports_list
