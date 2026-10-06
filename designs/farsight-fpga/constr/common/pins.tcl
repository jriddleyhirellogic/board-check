# ------------------------------------------------------------------------------
# Description   : Constraint pinout map
# Target Device : MPF500TS-FC1152M
# Origin Date   : 09-11-2025 22:16:28
# Originator    : Saba Janamian
#
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# System Clock
# ------------------------------------------------------------------------------
dict set pins {sys_clk_50mhz} {pin_name "T9" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}

# ------------------------------------------------------------------------------
# Cam XCVR Ref Clock
# ------------------------------------------------------------------------------
dict set pins {ref_clk_148p5mhz_p} {pin_name "AG27" DIRECTION "INPUT"}
dict set pins {ref_clk_148p5mhz_n} {pin_name "AG28" DIRECTION "INPUT"}

# ------------------------------------------------------------------------------
# Aux XCVR Ref Clock
# ------------------------------------------------------------------------------
dict set pins {aux_ref_clk_p} {pin_name "N27" DIRECTION "INPUT"}
dict set pins {aux_ref_clk_n} {pin_name "N28" DIRECTION "INPUT"}

# ------------------------------------------------------------------------------
# PCIE x2 XCVR EXT Ref Clock
# ------------------------------------------------------------------------------
dict set pins {pcie_ext_ref_clk_p} {pin_name "W27" DIRECTION "INPUT"}
dict set pins {pcie_ext_ref_clk_n} {pin_name "W28" DIRECTION "INPUT"}

# ------------------------------------------------------------------------------
# PCIE x2 XCVR Oscillator
# ------------------------------------------------------------------------------
dict set pins {pcie_clk_125mhz_p} {pin_name "AA27" DIRECTION "INPUT"}
dict set pins {pcie_clk_125mhz_n} {pin_name "AA28" DIRECTION "INPUT"}

# ------------------------------------------------------------------------------
# External 10MHz Clock
# ------------------------------------------------------------------------------
dict set pins {ext_clk_10mhz} {pin_name "K2" io_std "LVTTL" fixed "true" DIRECTION "INPUT"}

# ------------------------------------------------------------------------------
# Reset
# ------------------------------------------------------------------------------
dict set pins {dev_rst_n}  {pin_name "L15" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {sys_rst_n}  {pin_name "M6" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {proc_rst_n} {pin_name "N6" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}

# ------------------------------------------------------------------------------
# JTAG
# ------------------------------------------------------------------------------
dict set pins {jtag_tck}   {pin_name "J10" DIRECTION "INPUT"}
dict set pins {jtag_tdi}   {pin_name "K11" DIRECTION "INPUT"}
dict set pins {jtag_tdo}   {pin_name "K9" DIRECTION "OUTPUT"}
dict set pins {jtag_tms}   {pin_name "J9" DIRECTION "INPUT"}
dict set pins {jtag_trstb} {pin_name "N14" DIRECTION "INPUT"}

# ------------------------------------------------------------------------------
# Sys Ctrl SPI
# ------------------------------------------------------------------------------
dict set pins {sys_ctrl_sck}         {pin_name "L14" io_std "LVTTL" fixed "true" DIRECTION "INOUT"}
dict set pins {sys_ctrl_ss}          {pin_name "M14" io_std "LVTTL" fixed "true" DIRECTION "INOUT"}
dict set pins {sys_ctrl_sdi}         {pin_name "K12" io_std "LVTTL" fixed "true" DIRECTION "INPUT"}
dict set pins {sys_ctrl_sdo}         {pin_name "K10" io_std "LVTTL" fixed "true" DIRECTION "OUTPUT"}
dict set pins {sys_ctrl_spi_en}      {pin_name "L13" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {sys_ctrl_io_cfg_intf} {pin_name "L12" io_std "LVCMOS33" fixed "true" DIRECTION "INOUT"}

# ------------------------------------------------------------------------------
# PF to PA3 Power Enable
# ------------------------------------------------------------------------------
dict set pins {lvds_pwr_en}        {pin_name "AC2" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {eth1_pwr_en}        {pin_name "AC1" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {eth2_pwr_en}        {pin_name "AA2" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {stepper_pri_pwr_en} {pin_name "AB1" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {stepper_sec_pwr_en} {pin_name "AD1" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {lvdt_pwr_en}        {pin_name "K5" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {cam_pwr_en}         {pin_name "P5" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}

# ------------------------------------------------------------------------------
# PA3 Power Status
# ------------------------------------------------------------------------------
dict set pins {stepper_pri_pwr_status} {pin_name "R11" io_std "LVCMOS33" fixed "true" DIRECTION "INOUT"}
dict set pins {stepper_sec_pwr_status} {pin_name "U14" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {pf_pwr_status}          {pin_name "P3" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {step_down_pwr_status}   {pin_name "L2" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {ddr16gb_pwr_status}     {pin_name "N9" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {ddr8gb_pwr_status}      {pin_name "N11" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {eth1_pwr_status}        {pin_name "P11" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {eth2_pwr_status}        {pin_name "M11" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {lvdt_pwr_status}        {pin_name "L9" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {lvds_pwr_status}        {pin_name "M12" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {pa3_pwr_status}         {pin_name "L5" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {cam_pwr_status}         {pin_name "T12" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {pa3_fw_version[0]}      {pin_name "E5" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {pa3_fw_version[1]}      {pin_name "C1" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {pa3_fw_version[2]}      {pin_name "B1" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}

# ------------------------------------------------------------------------------
# PCIE x2
# ------------------------------------------------------------------------------
dict set pins {pcie0_lane0_txd_p} {pin_name "V33"}
dict set pins {pcie0_lane0_txd_n} {pin_name "V34"}
dict set pins {pcie0_lane0_rxd_p} {pin_name "V29"}
dict set pins {pcie0_lane0_rxd_n} {pin_name "V30"}
dict set pins {pcie0_lane1_txd_p} {pin_name "Y33"}
dict set pins {pcie0_lane1_txd_n} {pin_name "Y34"}
dict set pins {pcie0_lane1_rxd_p} {pin_name "W31"}
dict set pins {pcie0_lane1_rxd_n} {pin_name "W32"}
dict set pins {pcie0_perstn}      {pin_name "R7" io_std "LVTTL" fixed "true" DIRECTION "INPUT"}

# ------------------------------------------------------------------------------
# Camera Data Out
# ------------------------------------------------------------------------------
dict set pins {cam_lane0_rxd_p} {pin_name "AP29"}
dict set pins {cam_lane0_rxd_n} {pin_name "AP30"}
dict set pins {cam_lane1_rxd_p} {pin_name "AM29"}
dict set pins {cam_lane1_rxd_n} {pin_name "AM30"}
dict set pins {cam_lane2_rxd_p} {pin_name "AK29"}
dict set pins {cam_lane2_rxd_n} {pin_name "AK30"}
dict set pins {cam_lane3_rxd_p} {pin_name "AJ31"}
dict set pins {cam_lane3_rxd_n} {pin_name "AJ32"}
dict set pins {cam_lane4_rxd_p} {pin_name "AH29"}
dict set pins {cam_lane4_rxd_n} {pin_name "AH30"}
dict set pins {cam_lane5_rxd_p} {pin_name "AG31"}
dict set pins {cam_lane5_rxd_n} {pin_name "AG32"}
dict set pins {cam_lane6_rxd_p} {pin_name "AD29"}
dict set pins {cam_lane6_rxd_n} {pin_name "AD30"}
dict set pins {cam_lane7_rxd_p} {pin_name "AC31"}
dict set pins {cam_lane7_rxd_n} {pin_name "AC32"}

# ------------------------------------------------------------------------------
# Cam Ctrl
# ------------------------------------------------------------------------------
dict set pins {cam_miso}          {pin_name "AG25" io_std "LVCMOS18" fixed "true" DIRECTION "OUTPUT"}
dict set pins {cam_sck}           {pin_name "AH24" io_std "LVCMOS18" fixed "true" DIRECTION "OUTPUT"}
dict set pins {cam_mosi}          {pin_name "AH25" io_std "LVCMOS18" fixed "true" DIRECTION "INPUT"}
dict set pins {cam_xce_n}         {pin_name "AJ24" io_std "LVCMOS18" fixed "true" DIRECTION "OUTPUT"}
dict set pins {cam_xclr_n}        {pin_name "AG22" io_std "LVCMOS18" fixed "true" DIRECTION "OUTPUT"}
dict set pins {cam_xtrig_primary} {pin_name "AL25" io_std "LVCMOS18" fixed "true" DIRECTION "OUTPUT"}
dict set pins {cam_tout_primary}  {pin_name "AL27" io_std "LVCMOS18" fixed "true" DIRECTION "INPUT"}
dict set pins {cam_osc_en}        {pin_name "AK23" io_std "LVCMOS18" fixed "true" DIRECTION "OUTPUT"}
dict set pins {cam_buff_en_n}     {pin_name "AF22" io_std "LVCMOS18" fixed "true" DIRECTION "OUTPUT"}

# ------------------------------------------------------------------------------
# RS422 UART
# ------------------------------------------------------------------------------
dict set pins {uart0_tx} {pin_name "R6" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {uart0_rx} {pin_name "P13" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}

# ------------------------------------------------------------------------------
# Stepper Motor Controller 0
# ------------------------------------------------------------------------------
dict set pins {pri_stp_motor_m0}       {pin_name "E7" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {pri_stp_motor_m1}       {pin_name "C8" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {pri_stp_motor_en}       {pin_name "A4" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {pri_stp_motor_decay0}   {pin_name "C7" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {pri_stp_motor_decay1}   {pin_name "D8" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {pri_stp_motor_dir}      {pin_name "B7" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {pri_stp_motor_step}     {pin_name "B5" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {pri_stp_motor_toff}     {pin_name "E8" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {pri_stp_motor_sleep_n}  {pin_name "A5" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {pri_stp_motor_fault_n}  {pin_name "F8" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {pri_stp_motor_vref_pwm} {pin_name "F9" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}

# ------------------------------------------------------------------------------
# Stepper Motor Controller 1
# ------------------------------------------------------------------------------
dict set pins {sec_stp_motor_m0}       {pin_name "G5" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {sec_stp_motor_m1}       {pin_name "D6" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {sec_stp_motor_en}       {pin_name "C2" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {sec_stp_motor_decay0}   {pin_name "C4" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {sec_stp_motor_decay1}   {pin_name "F5" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {sec_stp_motor_dir}      {pin_name "D5" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {sec_stp_motor_step}     {pin_name "C3" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {sec_stp_motor_toff}     {pin_name "F4" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {sec_stp_motor_sleep_n}  {pin_name "E6" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {sec_stp_motor_fault_n}  {pin_name "G6" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {sec_stp_motor_vref_pwm} {pin_name "G4" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}

# ------------------------------------------------------------------------------
# LVDT Analog Sig Gain Switch
# ------------------------------------------------------------------------------
dict set pins {lvdt_gain_switch} {pin_name "G1" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}

# ------------------------------------------------------------------------------
# LVDT SPI
# ------------------------------------------------------------------------------
dict set pins {lvdt_adc_spi_cs_n} {pin_name "F10" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {lvdt_adc_spi_sclk} {pin_name "F13" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {lvdt_adc_spi_miso} {pin_name "F12" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {lvdt_adc_spi_mosi} {pin_name "E13" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}

# ------------------------------------------------------------------------------
# LVDT DAC
# ------------------------------------------------------------------------------
dict set pins {lvdt_dac_b0} {pin_name "C12" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {lvdt_dac_b1} {pin_name "C11" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {lvdt_dac_b2} {pin_name "D11" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {lvdt_dac_b3} {pin_name "D10" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {lvdt_dac_b4} {pin_name "A10" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {lvdt_dac_b5} {pin_name "A9" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {lvdt_dac_b6} {pin_name "D13" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {lvdt_dac_b7} {pin_name "B10" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}

# ------------------------------------------------------------------------------
# Power Telemtry ADCs SPI
# ------------------------------------------------------------------------------
dict set pins {tlm_spi_sclk}  {pin_name "N7" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {tlm_spi_miso}  {pin_name "M5" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {tlm_spi_mosi}  {pin_name "J3" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {tlm_spi_cs1_n} {pin_name "J1" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {tlm_spi_cs2_n} {pin_name "J5" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {tlm_spi_cs3_n} {pin_name "H4" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {tlm_spi_cs4_n} {pin_name "H3" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {tlm_spi_cs5_n} {pin_name "H2" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {tlm_spi_cs6_n} {pin_name "H1" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}

# ------------------------------------------------------------------------------
# Ethernet Phy 1
# ------------------------------------------------------------------------------
dict set pins {eth1_phy_mdc}             {pin_name "T5" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {eth1_phy_mdio}            {pin_name "U5" io_std "LVCMOS33" fixed "true" DIRECTION "INOUT"}
dict set pins {eth1_phy_rst_n}           {pin_name "V3" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {eth1_rgmii_rxc}           {pin_name "U10" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {eth1_rgmii_rx_ctl}        {pin_name "Y11" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {eth1_rgmii_rxd[3]}        {pin_name "Y3" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {eth1_rgmii_rxd[2]}        {pin_name "AA3" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {eth1_rgmii_rxd[1]}        {pin_name "AA4" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {eth1_rgmii_rxd[0]}        {pin_name "AA10" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {eth1_rgmii_txc}           {pin_name "P1" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {eth1_rgmii_tx_ctl}        {pin_name "R3" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {eth1_rgmii_txd[3]}        {pin_name "T3" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {eth1_rgmii_txd[2]}        {pin_name "T4" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {eth1_rgmii_txd[1]}        {pin_name "R1" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {eth1_rgmii_txd[0]}        {pin_name "R2" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {eth1_stat_fastlink_fail}  {pin_name "U2" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {eth1_stat_mdint}          {pin_name "U1" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {eth1_stat_rcvrd_clk}      {pin_name "W3" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {eth1_stat_clkout}         {pin_name "V4" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {eth1_ctrl_clk_squelch_in} {pin_name "W5" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {eth1_ctrl_comma_mode}     {pin_name "W4" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}

# ------------------------------------------------------------------------------
# Ethernet Phy 2
# ------------------------------------------------------------------------------
dict set pins {eth2_phy_mdc}             {pin_name "AB4" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {eth2_phy_mdio}            {pin_name "AC4" io_std "LVCMOS33" fixed "true" DIRECTION "INOUT"}
dict set pins {eth2_phy_rst_n}           {pin_name "AB9" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {eth2_rgmii_rxc}           {pin_name "AD4" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {eth2_rgmii_rx_ctl}        {pin_name "AC8" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {eth2_rgmii_rxd[3]}        {pin_name "AB6" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {eth2_rgmii_rxd[2]}        {pin_name "AB7" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {eth2_rgmii_rxd[1]}        {pin_name "AC9" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {eth2_rgmii_rxd[0]}        {pin_name "AC7" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {eth2_rgmii_txc}           {pin_name "W6" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {eth2_rgmii_tx_ctl}        {pin_name "Y5" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {eth2_rgmii_txd[3]}        {pin_name "AB5" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {eth2_rgmii_txd[2]}        {pin_name "AB2" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {eth2_rgmii_txd[1]}        {pin_name "Y7" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {eth2_rgmii_txd[0]}        {pin_name "Y6" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {eth2_stat_fastlink_fail}  {pin_name "AA8" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {eth2_stat_mdint}          {pin_name "AA7" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {eth2_stat_rcvrd_clk}      {pin_name "AB11" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {eth2_stat_clkout}         {pin_name "Y10" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {eth2_ctrl_clk_squelch_in} {pin_name "AC11" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {eth2_ctrl_comma_mode}     {pin_name "AA12" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}

# ------------------------------------------------------------------------------
# Aux XCVR
# ------------------------------------------------------------------------------
dict set pins {xcvr1_lane0_rx_p} {pin_name "M29" DIRECTION "INPUT"}
dict set pins {xcvr1_lane0_rx_n} {pin_name "M30" DIRECTION "INPUT"}
dict set pins {xcvr1_lane0_tx_p} {pin_name "N31" DIRECTION "OUTPUT"}
dict set pins {xcvr1_lane0_tx_n} {pin_name "N32" DIRECTION "OUTPUT"}

# ------------------------------------------------------------------------------
# Avionics GPIO
# ------------------------------------------------------------------------------
dict set pins {bus_to_fav_pps}    {pin_name "N4" io_std "LVTTL" fixed "true" DIRECTION "INPUT"}
dict set pins {bus_to_fav_trig}   {pin_name "N3" io_std "LVTTL" fixed "true" DIRECTION "INPUT"}
dict set pins {bus_to_fav_gpi}    {pin_name "N2" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {fav_to_bus_gpo}    {pin_name "L4" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {bus_fav_interrupt} {pin_name "M2" io_std "LVCMOS33" fixed "true" DIRECTION "INOUT"}

# ------------------------------------------------------------------------------
# NVM SPI
# ------------------------------------------------------------------------------
dict set pins {nvm_spi_sio0} {pin_name "L7" io_std "LVCMOS33" fixed "true" DIRECTION "INOUT"}
dict set pins {nvm_spi_sio1} {pin_name "L8" io_std "LVCMOS33" fixed "true" DIRECTION "INOUT"}
dict set pins {nvm_spi_cs_n} {pin_name "K3" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}
dict set pins {nvm_spi_sck}  {pin_name "K7" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}

# ------------------------------------------------------------------------------
# PF Heartbeat LED
# ------------------------------------------------------------------------------
dict set pins {pf_heartbeat} {pin_name "Y1" io_std "LVCMOS33" fixed "true" DIRECTION "OUTPUT"}

# ------------------------------------------------------------------------------
# PA3 to PolarFire Misc
# ------------------------------------------------------------------------------
dict set pins {pa3_to_pf_misc3}  {pin_name "A2" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {pa3_to_pf_misc4}  {pin_name "A3" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {pa3_to_pf_misc5}  {pin_name "R12" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {pa3_to_pf_misc6}  {pin_name "T14" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {pa3_to_pf_misc7}  {pin_name "T13" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {pa3_to_pf_misc8}  {pin_name "P4" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {pa3_to_pf_misc9}  {pin_name "L3" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {pa3_to_pf_misc10} {pin_name "M9" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {pa3_to_pf_misc11} {pin_name "N12" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {pa3_to_pf_misc12} {pin_name "P10" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {pa3_to_pf_misc13} {pin_name "M10" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {pa3_to_pf_misc14} {pin_name "L10" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}
dict set pins {pa3_to_pf_misc15} {pin_name "N13" io_std "LVCMOS33" fixed "true" DIRECTION "INPUT"}

# ------------------------------------------------------------------------------
# Debug GPIO
# ------------------------------------------------------------------------------
dict set pins {dbg_gpio0}  {pin_name "AJ25" io_std "LVCMOS18" fixed "true" DIRECTION "INOUT"}
dict set pins {dbg_gpio1}  {pin_name "AN26" io_std "LVCMOS18" fixed "true" DIRECTION "INOUT"}
dict set pins {dbg_gpio2}  {pin_name "AM26" io_std "LVCMOS18" fixed "true" DIRECTION "INOUT"}
dict set pins {dbg_gpio3}  {pin_name "AL26" io_std "LVCMOS18" fixed "true" DIRECTION "INOUT"}
dict set pins {dbg_gpio4}  {pin_name "AP27" io_std "LVCMOS18" fixed "true" DIRECTION "INOUT"}
dict set pins {dbg_gpio5}  {pin_name "AN27" io_std "LVCMOS18" fixed "true" DIRECTION "INOUT"}
dict set pins {dbg_gpio6}  {pin_name "AM27" io_std "LVCMOS18" fixed "true" DIRECTION "INOUT"}
dict set pins {dbg_gpio7}  {pin_name "AL23" io_std "LVCMOS18" fixed "true" DIRECTION "INOUT"}
dict set pins {dbg_gpio8}  {pin_name "AL24" io_std "LVCMOS18" fixed "true" DIRECTION "INOUT"}
dict set pins {dbg_gpio9}  {pin_name "AP24" io_std "LVCMOS18" fixed "true" DIRECTION "INOUT"}
dict set pins {dbg_gpio10} {pin_name "AN24" io_std "LVCMOS18" fixed "true" DIRECTION "INOUT"}
dict set pins {dbg_gpio11} {pin_name "AM25" io_std "LVCMOS18" fixed "true" DIRECTION "INOUT"}
dict set pins {dbg_gpio12} {pin_name "AP25" io_std "LVCMOS18" fixed "true" DIRECTION "INOUT"}
dict set pins {dbg_gpio13} {pin_name "AK25" io_std "LVCMOS18" fixed "true" DIRECTION "INOUT"}

# ------------------------------------------------------------------------------
# DDR4 R0 16GB ECC NW
# ------------------------------------------------------------------------------
dict set pins {ddr4_r0_a[0]}     {pin_name "AE5" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_a[1]}     {pin_name "AF5" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_ck0}      {pin_name "AG4" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_ck0_n}    {pin_name "AG5" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_a[2]}     {pin_name "AF2" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_a[3]}     {pin_name "AF3" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_a[4]}     {pin_name "AH3" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_a[5]}     {pin_name "AJ3" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_a[6]}     {pin_name "AH1" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_a[7]}     {pin_name "AH2" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_a[8]}     {pin_name "AK3" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_a[9]}     {pin_name "AL3" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_a[10]}    {pin_name "AJ1" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_a[11]}    {pin_name "AK1" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_a[12]}    {pin_name "AH4" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_a[13]}    {pin_name "AJ4" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_we_n}     {pin_name "AK2" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_cas_n}    {pin_name "AL2" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_ras_n}    {pin_name "AD9" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_ba[0]}    {pin_name "AD8" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_ba[1]}    {pin_name "AD6" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_act_n}    {pin_name "AE6" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_bg[0]}    {pin_name "AG7" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_bg[1]}    {pin_name "AG6" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_cs_n}     {pin_name "AF9" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_cke}      {pin_name "AG9" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_odt}      {pin_name "AE7" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_reset_n}  {pin_name "AF7" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_dq[0]}    {pin_name "AE12" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[1]}    {pin_name "AF12" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[2]}    {pin_name "AG10" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[3]}    {pin_name "AF10" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dqs[0]}   {pin_name "AE13" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dqs_n[0]} {pin_name "AF13" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[4]}    {pin_name "AD10" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[5]}    {pin_name "AE10" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[6]}    {pin_name "AD13" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[7]}    {pin_name "AD14" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dm_n[0]}  {pin_name "AE11" io_std "POD12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_dq[8]}    {pin_name "AH6" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[9]}    {pin_name "AH7" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[10]}   {pin_name "AJ9" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[11]}   {pin_name "AJ8" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dqs[1]}   {pin_name "AJ5" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dqs_n[1]} {pin_name "AJ6" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[12]}   {pin_name "AH9" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[13]}   {pin_name "AK5" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[14]}   {pin_name "AK6" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[15]}   {pin_name "AK7" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dm_n[1]}  {pin_name "AK8" io_std "POD12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_dq[16]}   {pin_name "AM1" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[17]}   {pin_name "AM2" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[18]}   {pin_name "AN1" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[19]}   {pin_name "AN2" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dqs[2]}   {pin_name "AL4" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dqs_n[2]} {pin_name "AM4" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[20]}   {pin_name "AP2" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[21]}   {pin_name "AP3" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[22]}   {pin_name "AL5" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[23]}   {pin_name "AM5" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dm_n[2]}  {pin_name "AN3" io_std "POD12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_dq[24]}   {pin_name "AG11" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[25]}   {pin_name "AH11" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[26]}   {pin_name "AG12" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[27]}   {pin_name "AH12" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dqs[3]}   {pin_name "AH14" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dqs_n[3]} {pin_name "AH13" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[28]}   {pin_name "AJ10" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[29]}   {pin_name "AJ11" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[30]}   {pin_name "AJ14" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[31]}   {pin_name "AJ13" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dm_n[3]}  {pin_name "AK13" io_std "POD12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_dq[32]}   {pin_name "AD15" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[33]}   {pin_name "AE15" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[34]}   {pin_name "AF14" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[35]}   {pin_name "AG14" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dqs[4]}   {pin_name "AE16" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dqs_n[4]} {pin_name "AD16" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[36]}   {pin_name "AF15" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[37]}   {pin_name "AG15" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[38]}   {pin_name "AD17" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[39]}   {pin_name "AE17" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dm_n[4]}  {pin_name "AF17" io_std "POD12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_dq[40]}   {pin_name "AL7" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[41]}   {pin_name "AM7" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[42]}   {pin_name "AP4" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[43]}   {pin_name "AP5" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dqs[5]}   {pin_name "AM6" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dqs_n[5]} {pin_name "AN7" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[44]}   {pin_name "AL8" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[45]}   {pin_name "AL9" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[46]}   {pin_name "AN6" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[47]}   {pin_name "AP6" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dm_n[5]}  {pin_name "AN8" io_std "POD12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_dq[48]}   {pin_name "AG17" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[49]}   {pin_name "AH16" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[50]}   {pin_name "AG19" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[51]}   {pin_name "AH19" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dqs[6]}   {pin_name "AK16" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dqs_n[6]} {pin_name "AJ16" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[52]}   {pin_name "AH17" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[53]}   {pin_name "AH18" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[54]}   {pin_name "AJ18" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[55]}   {pin_name "AJ19" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dm_n[6]}  {pin_name "AJ15" io_std "POD12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_dq[56]}   {pin_name "AK10" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[57]}   {pin_name "AL10" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[58]}   {pin_name "AM9" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[59]}   {pin_name "AM10" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dqs[7]}   {pin_name "AM11" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dqs_n[7]} {pin_name "AN11" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[60]}   {pin_name "AK11" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[61]}   {pin_name "AL12" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[62]}   {pin_name "AN9" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[63]}   {pin_name "AP9" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dm_n[7]}  {pin_name "AP10" io_std "POD12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_dq[64]}   {pin_name "AC18" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[65]}   {pin_name "AD19" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[66]}   {pin_name "AF20" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[67]}   {pin_name "AG20" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dqs[8]}   {pin_name "AD18" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dqs_n[8]} {pin_name "AE18" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[68]}   {pin_name "AE20" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[69]}   {pin_name "AD20" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[70]}   {pin_name "AF19" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dq[71]}   {pin_name "AF18" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r0_dm_n[8]}  {pin_name "AD21" io_std "POD12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_shield0}  {pin_name "AD11" io_std "SHIELD12" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_shield1}  {pin_name "AH8" io_std "SHIELD12" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_shield2}  {pin_name "AN4" io_std "SHIELD12" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_shield3}  {pin_name "AK12" io_std "SHIELD12" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_shield4}  {pin_name "AG16" io_std "SHIELD12" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_shield5}  {pin_name "AP8" io_std "SHIELD12" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_shield6}  {pin_name "AK15" io_std "SHIELD12" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_shield7}  {pin_name "AP11" io_std "SHIELD12" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_shield8}  {pin_name "AE21" io_std "SHIELD12" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r0_ext_ref}  {pin_name "AF4" DIRECTION "INPUT"}

# ------------------------------------------------------------------------------
# DDR4 R2 8GB ECC SE
# ------------------------------------------------------------------------------
dict set pins {ddr4_r2_a[0]}     {pin_name "B26" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_a[1]}     {pin_name "C27" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_ck0}      {pin_name "A25" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_ck0_n}    {pin_name "B25" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_a[2]}     {pin_name "C26" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_a[3]}     {pin_name "D25" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_a[4]}     {pin_name "C24" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_a[5]}     {pin_name "D24" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_a[6]}     {pin_name "A24" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_a[7]}     {pin_name "B24" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_a[8]}     {pin_name "F22" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_a[9]}     {pin_name "G22" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_a[10]}    {pin_name "F24" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_a[11]}    {pin_name "F23" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_a[12]}    {pin_name "H24" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_a[13]}    {pin_name "G24" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_we_n}     {pin_name "H22" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_cas_n}    {pin_name "H23" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_ras_n}    {pin_name "K25" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_ba[0]}    {pin_name "J25" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_ba[1]}    {pin_name "L24" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_act_n}    {pin_name "L25" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_bg[0]}    {pin_name "J24" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_bg[1]}    {pin_name "J23" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_cs_n}     {pin_name "M23" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_cke}      {pin_name "M22" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_odt}      {pin_name "L22" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_reset_n}  {pin_name "K22" io_std "HSTL12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_dq[0]}    {pin_name "A23" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[1]}    {pin_name "A22" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[2]}    {pin_name "C23" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[3]}    {pin_name "D23" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dqs[0]}   {pin_name "C22" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dqs_n[0]} {pin_name "B22" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[4]}    {pin_name "E23" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[5]}    {pin_name "E22" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[6]}    {pin_name "B21" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[7]}    {pin_name "C21" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dm_n[0]}  {pin_name "D21" io_std "POD12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_dq[8]}    {pin_name "A20" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[9]}    {pin_name "B20" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[10]}   {pin_name "A19" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[11]}   {pin_name "B19" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dqs[1]}   {pin_name "A17" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dqs_n[1]} {pin_name "A18" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[12]}   {pin_name "C19" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[13]}   {pin_name "C18" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[14]}   {pin_name "B17" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[15]}   {pin_name "C17" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dm_n[1]}  {pin_name "D20" io_std "POD12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_dq[16]}   {pin_name "G21" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[17]}   {pin_name "G20" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[18]}   {pin_name "L20" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[19]}   {pin_name "K20" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dqs[2]}   {pin_name "J21" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dqs_n[2]} {pin_name "K21" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[20]}   {pin_name "G19" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[21]}   {pin_name "H19" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[22]}   {pin_name "G17" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[23]}   {pin_name "H18" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dm_n[2]}  {pin_name "H21" io_std "POD12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_dq[24]}   {pin_name "A15" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[25]}   {pin_name "B15" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[26]}   {pin_name "B16" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[27]}   {pin_name "C16" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dqs[3]}   {pin_name "A13" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dqs_n[3]} {pin_name "A14" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[28]}   {pin_name "B14" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[29]}   {pin_name "C14" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[30]}   {pin_name "A12" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[31]}   {pin_name "B12" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dm_n[3]}  {pin_name "C13" io_std "POD12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_dq[32]}   {pin_name "F17" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[33]}   {pin_name "E17" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[34]}   {pin_name "E20" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[35]}   {pin_name "F20" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dqs[4]}   {pin_name "D18" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dqs_n[4]} {pin_name "E18" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[36]}   {pin_name "D16" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[37]}   {pin_name "E16" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[38]}   {pin_name "D15" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dq[39]}   {pin_name "E15" io_std "POD12I" fixed "true" DIRECTION "INOUT"}
dict set pins {ddr4_r2_dm_n[4]}  {pin_name "F19" io_std "POD12I" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_shield0}  {pin_name "E21" io_std "SHIELD12" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_shield1}  {pin_name "D19" io_std "SHIELD12" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_shield2}  {pin_name "J20" io_std "SHIELD12" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_shield3}  {pin_name "D14" io_std "SHIELD12" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_shield4}  {pin_name "F18" io_std "SHIELD12" fixed "true" DIRECTION "OUTPUT"}
dict set pins {ddr4_r2_ext_ref}  {pin_name "B27" DIRECTION "INPUT"}
