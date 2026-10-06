# Creating SmartDesign "top"
set sd_name {top}
create_smartdesign -sd_name ${sd_name}

# Disable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 0

# Create top level Scalar Ports
sd_create_scalar_port -sd_name ${sd_name} -port_name {SWITCH10} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SWITCH7} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SWITCH8} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SWITCH9} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {TCK} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {TDI} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {TMS} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {TRSTB} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {lvdt_adc_spi_miso} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pri_stp_motor_fault_n} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sec_stp_motor_fault_n} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sys_clk_50mhz} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {uart_rx} -port_direction {IN}

sd_create_scalar_port -sd_name ${sd_name} -port_name {TDO} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {j1_dbg10_pin9} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {j1_dbg11_pin5} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {j1_dbg12_pin1} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {j1_dbg5_pin7} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {j1_dbg6_pin3} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {j1_dbg9_pin11} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {j2_dbg1_pin11} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {j2_dbg2_pin9} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {j2_dbg3_pin5} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {j2_dbg4_pin1} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {j2_dbg7_pin7} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {j2_dbg8_pin3} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {j7_a2_pin2} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {j7_a3_pin4} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {j7_c3_pin6} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {j7_c4_pin1} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {j7_d3_pin3} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {j7_d4_pin5} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {j8_debug_io1_pin3} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {j8_debug_io2_pin5} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {j8_debug_io3_pin7} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {j8_debug_io4_pin13} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {led0} -port_direction {OUT}
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
sd_create_scalar_port -sd_name ${sd_name} -port_name {uart_tx} -port_direction {OUT}



sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {j1_dbg10_pin9} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {j1_dbg11_pin5} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {j1_dbg12_pin1} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {j1_dbg5_pin7} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {j1_dbg6_pin3} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {j1_dbg9_pin11} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {j2_dbg1_pin11} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {j2_dbg2_pin9} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {j2_dbg3_pin5} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {j2_dbg4_pin1} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {j7_a2_pin2} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {j7_c4_pin1} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {j7_d3_pin3} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {j7_d4_pin5} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {j8_debug_io1_pin3} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {j8_debug_io2_pin5} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {j8_debug_io3_pin7} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {j8_debug_io4_pin13} -value {GND}
# Add CLKBUF_0 instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {CLKBUF} -instance_name {CLKBUF_0}



# Add CORE16550_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {CORE16550_C0} -instance_name {CORE16550_inst}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {CORE16550_inst:BAUDOUTN}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {CORE16550_inst:CTSN} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {CORE16550_inst:DCDN} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {CORE16550_inst:DSRN} -value {GND}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {CORE16550_inst:DTRN}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {CORE16550_inst:OUT1N}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {CORE16550_inst:OUT2N}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {CORE16550_inst:RIN} -value {VCC}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {CORE16550_inst:RTSN}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {CORE16550_inst:RXFIFO_EMPTY}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {CORE16550_inst:RXFIFO_FULL}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {CORE16550_inst:RXRDYN}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {CORE16550_inst:TXRDYN}



# Add CoreAPB3_C1_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {CoreAPB3_C1} -instance_name {CoreAPB3_C1_inst}



# Add COREJTAGDEBUG_C0_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {COREJTAGDEBUG_C0} -instance_name {COREJTAGDEBUG_C0_inst}



# Add CORERESET_PF_C0_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {CORERESET_PF_C0} -instance_name {CORERESET_PF_C0_inst}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {CORERESET_PF_C0_inst:EXT_RST_N} -value {VCC}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {CORERESET_PF_C0_inst:BANK_x_VDDI_STATUS} -value {VCC}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {CORERESET_PF_C0_inst:BANK_y_VDDI_STATUS} -value {VCC}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {CORERESET_PF_C0_inst:SS_BUSY} -value {GND}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {CORERESET_PF_C0_inst:FF_US_RESTORE} -value {GND}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {CORERESET_PF_C0_inst:PLL_POWERDOWN_B}



# Add dbg_gpio_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {FOCUS_MECH_CoreGPIO_C1} -instance_name {dbg_gpio_inst}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[0:0]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[10:10]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dbg_gpio_inst:GPIO_OUT[10:10]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[11:11]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dbg_gpio_inst:GPIO_OUT[11:11]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[12:12]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dbg_gpio_inst:GPIO_OUT[12:12]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[13:13]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dbg_gpio_inst:GPIO_OUT[13:13]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[14:14]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dbg_gpio_inst:GPIO_OUT[14:14]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[15:15]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dbg_gpio_inst:GPIO_OUT[15:15]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[16:16]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dbg_gpio_inst:GPIO_OUT[16:16]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[17:17]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dbg_gpio_inst:GPIO_OUT[17:17]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[18:18]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dbg_gpio_inst:GPIO_OUT[18:18]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[19:19]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dbg_gpio_inst:GPIO_OUT[19:19]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[1:1]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dbg_gpio_inst:GPIO_OUT[1:1]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[20:20]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dbg_gpio_inst:GPIO_OUT[20:20]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[21:21]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dbg_gpio_inst:GPIO_OUT[21:21]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[22:22]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dbg_gpio_inst:GPIO_OUT[22:22]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[2:2]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dbg_gpio_inst:GPIO_OUT[2:2]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[31:23]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dbg_gpio_inst:GPIO_OUT[31:23]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[3:3]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dbg_gpio_inst:GPIO_OUT[3:3]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[4:4]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dbg_gpio_inst:GPIO_OUT[4:4]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[5:5]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dbg_gpio_inst:GPIO_OUT[5:5]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[6:6]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[7:7]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[8:8]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dbg_gpio_inst:GPIO_OUT[8:8]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {dbg_gpio_inst:GPIO_OUT} -pin_slices {[9:9]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dbg_gpio_inst:GPIO_OUT[9:9]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dbg_gpio_inst:INT}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {dbg_gpio_inst:GPIO_IN} -value {GND}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {dbg_gpio_inst:GPIO_OE}



# Add Debug_Switches_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {FOCUS_MECH_CoreGPIO_C5} -instance_name {Debug_Switches_inst}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {Debug_Switches_inst:GPIO_IN} -pin_slices {[0:0]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {Debug_Switches_inst:GPIO_IN} -pin_slices {[1:1]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {Debug_Switches_inst:GPIO_IN} -pin_slices {[2:2]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {Debug_Switches_inst:GPIO_IN} -pin_slices {[3:3]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {Debug_Switches_inst:INT}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {Debug_Switches_inst:GPIO_OUT}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {Debug_Switches_inst:GPIO_OE}



# Add focus_mech_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {focus_mech} -instance_name {focus_mech_inst}
sd_create_pin_group -sd_name ${sd_name} -group_name {LVDT_ADC_SPI} -instance_name {focus_mech_inst} -pin_names {"lvdt_adc_spi_miso" "lvdt_adc_spi_cs_n" "lvdt_adc_spi_mosi" "lvdt_adc_spi_sclk" }
sd_create_pin_group -sd_name ${sd_name} -group_name {SEC_STEPPER} -instance_name {focus_mech_inst} -pin_names {"sec_stp_motor_fault_n" "sec_stp_motor_decay0" "sec_stp_motor_decay1" "sec_stp_motor_dir" "sec_stp_motor_en" "sec_stp_motor_m0" "sec_stp_motor_m1" "sec_stp_motor_sleep_n" "sec_stp_motor_step" "sec_stp_motor_toff" "sec_stp_motor_vref_pwm" }
sd_create_pin_group -sd_name ${sd_name} -group_name {PRI_STEPPER} -instance_name {focus_mech_inst} -pin_names {"pri_stp_motor_fault_n" "pri_stp_motor_step" "pri_stp_motor_toff" "pri_stp_motor_vref_pwm" "pri_stp_motor_decay1" "pri_stp_motor_m0" "pri_stp_motor_dir" "pri_stp_motor_m1" "pri_stp_motor_en" "pri_stp_motor_sleep_n" "pri_stp_motor_decay0" }
sd_create_pin_group -sd_name ${sd_name} -group_name {LAVDT_DAC} -instance_name {focus_mech_inst} -pin_names {"lvdt_dac_b0" "lvdt_dac_b7" "lvdt_dac_b2" "lvdt_dac_b3" "lvdt_dac_b4" "lvdt_dac_b5" "lvdt_dac_b1" "lvdt_dac_b6" }
sd_create_pin_group -sd_name ${sd_name} -group_name {LVDT_GAIN_CTRL} -instance_name {focus_mech_inst} -pin_names {"lvdt_gain_switch" }
sd_create_pin_group -sd_name ${sd_name} -group_name {CLK_RST} -instance_name {focus_mech_inst} -pin_names {"sys_rst_n" "sys_clk_50mhz" }
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {focus_mech_inst:dbg_pri_stp_motor_dir}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {focus_mech_inst:dbg_pri_stp_motor_en}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {focus_mech_inst:dbg_pri_stp_motor_fault_n}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {focus_mech_inst:dbg_pri_stp_motor_step}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {focus_mech_inst:dbg_pri_stp_motor_vref_pwm}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {focus_mech_inst:dbg_sec_stp_motor_dir}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {focus_mech_inst:dbg_sec_stp_motor_en}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {focus_mech_inst:dbg_sec_stp_motor_fault_n}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {focus_mech_inst:dbg_sec_stp_motor_step}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {focus_mech_inst:dbg_sec_stp_motor_vref_pwm}



# Add MIV_RV32_C0_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {MIV_RV32_C0} -instance_name {MIV_RV32_C0_inst}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {MIV_RV32_C0_inst:MSYS_EI} -pin_slices {[0:0]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {MIV_RV32_C0_inst:EXT_RESETN}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {MIV_RV32_C0_inst:TIME_COUNT_OUT}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {MIV_RV32_C0_inst:JTAG_TDO_DR}



# Add PF_CCC_C0_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {PF_CCC_C0} -instance_name {PF_CCC_C0_inst}



# Add PF_INIT_MONITOR_C0_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {PF_INIT_MONITOR_C0} -instance_name {PF_INIT_MONITOR_C0_inst}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {PF_INIT_MONITOR_C0_inst:PCIE_INIT_DONE}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {PF_INIT_MONITOR_C0_inst:USRAM_INIT_DONE}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {PF_INIT_MONITOR_C0_inst:SRAM_INIT_DONE}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {PF_INIT_MONITOR_C0_inst:XCVR_INIT_DONE}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {PF_INIT_MONITOR_C0_inst:USRAM_INIT_FROM_SNVM_DONE}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {PF_INIT_MONITOR_C0_inst:USRAM_INIT_FROM_UPROM_DONE}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {PF_INIT_MONITOR_C0_inst:USRAM_INIT_FROM_SPI_DONE}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {PF_INIT_MONITOR_C0_inst:SRAM_INIT_FROM_SNVM_DONE}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {PF_INIT_MONITOR_C0_inst:SRAM_INIT_FROM_UPROM_DONE}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {PF_INIT_MONITOR_C0_inst:SRAM_INIT_FROM_SPI_DONE}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {PF_INIT_MONITOR_C0_inst:AUTOCALIB_DONE}



# Add PF_SRAM_AHBL_AXI_C0_inst instance
sd_instantiate_component -sd_name ${sd_name} -component_name {PF_SRAM_AHBL_AXI_C0} -instance_name {PF_SRAM_AHBL_AXI_C0_inst}



# Add scalar net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"CLKBUF_0:PAD" "sys_clk_50mhz" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CLKBUF_0:Y" "PF_CCC_C0_inst:REF_CLK_0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CORE16550_inst:INTR" "MIV_RV32_C0_inst:EXT_IRQ" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CORE16550_inst:PCLK" "CORERESET_PF_C0_inst:CLK" "Debug_Switches_inst:PCLK" "MIV_RV32_C0_inst:CLK" "PF_CCC_C0_inst:OUT1_FABCLK_0" "PF_SRAM_AHBL_AXI_C0_inst:HCLK" "dbg_gpio_inst:PCLK" "focus_mech_inst:sys_clk_50mhz" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CORE16550_inst:PRESETN" "CORERESET_PF_C0_inst:FABRIC_RESET_N" "Debug_Switches_inst:PRESETN" "MIV_RV32_C0_inst:RESETN" "PF_SRAM_AHBL_AXI_C0_inst:HRESETN" "dbg_gpio_inst:PRESETN" "focus_mech_inst:sys_rst_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CORE16550_inst:SIN" "j2_dbg7_pin7" "uart_rx" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CORE16550_inst:SOUT" "j2_dbg8_pin3" "uart_tx" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"COREJTAGDEBUG_C0_inst:TCK" "TCK" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"COREJTAGDEBUG_C0_inst:TDI" "TDI" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"COREJTAGDEBUG_C0_inst:TDO" "TDO" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"COREJTAGDEBUG_C0_inst:TGT_TCK_0" "MIV_RV32_C0_inst:JTAG_TCK" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"COREJTAGDEBUG_C0_inst:TGT_TDI_0" "MIV_RV32_C0_inst:JTAG_TDI" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"COREJTAGDEBUG_C0_inst:TGT_TDO_0" "MIV_RV32_C0_inst:JTAG_TDO" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"COREJTAGDEBUG_C0_inst:TGT_TMS_0" "MIV_RV32_C0_inst:JTAG_TMS" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"COREJTAGDEBUG_C0_inst:TGT_TRSTN_0" "MIV_RV32_C0_inst:JTAG_TRSTN" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"COREJTAGDEBUG_C0_inst:TMS" "TMS" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"COREJTAGDEBUG_C0_inst:TRSTB" "TRSTB" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CORERESET_PF_C0_inst:FPGA_POR_N" "PF_INIT_MONITOR_C0_inst:FABRIC_POR_N" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CORERESET_PF_C0_inst:INIT_DONE" "PF_INIT_MONITOR_C0_inst:DEVICE_INIT_DONE" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CORERESET_PF_C0_inst:PLL_LOCK" "PF_CCC_C0_inst:PLL_LOCK_0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"Debug_Switches_inst:GPIO_IN[0:0]" "SWITCH7" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"Debug_Switches_inst:GPIO_IN[1:1]" "SWITCH8" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"Debug_Switches_inst:GPIO_IN[2:2]" "SWITCH9" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"Debug_Switches_inst:GPIO_IN[3:3]" "SWITCH10" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_gpio_inst:GPIO_OUT[0:0]" "led0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_gpio_inst:GPIO_OUT[6:6]" "j7_a3_pin4" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"dbg_gpio_inst:GPIO_OUT[7:7]" "j7_c3_pin6" }
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


# Add bus interface net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"CORE16550_inst:APBtarget" "CoreAPB3_C1_inst:APBmslave11" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CoreAPB3_C1_inst:APB3mmaster" "MIV_RV32_C0_inst:APB_INITIATOR" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CoreAPB3_C1_inst:APBmslave0" "focus_mech_inst:PRI_STP_APB_VREF" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CoreAPB3_C1_inst:APBmslave1" "focus_mech_inst:PRI_STP_APB_STEPPER_CONTROLS" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CoreAPB3_C1_inst:APBmslave10" "dbg_gpio_inst:APB_bif" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CoreAPB3_C1_inst:APBmslave12" "focus_mech_inst:APB_LVDT_Gain" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CoreAPB3_C1_inst:APBmslave13" "Debug_Switches_inst:APB_bif" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CoreAPB3_C1_inst:APBmslave14" "focus_mech_inst:apb_stepper_wd" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CoreAPB3_C1_inst:APBmslave2" "focus_mech_inst:PRI_STP_APB_STEPPER_OUT" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CoreAPB3_C1_inst:APBmslave3" "focus_mech_inst:SEC_STP_APB_VREF" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CoreAPB3_C1_inst:APBmslave4" "focus_mech_inst:SEC_STP_APB_STEPPER_CONTROLS" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CoreAPB3_C1_inst:APBmslave5" "focus_mech_inst:SEC_STP_APB_STEPPER_OUT" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CoreAPB3_C1_inst:APBmslave6" "focus_mech_inst:LVDT_READOUT_APB_PRI_Q" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CoreAPB3_C1_inst:APBmslave7" "focus_mech_inst:LVDT_READOUT_APB_PRI_I" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CoreAPB3_C1_inst:APBmslave8" "focus_mech_inst:LVDT_READOUT_APB_SEC_I" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"CoreAPB3_C1_inst:APBmslave9" "focus_mech_inst:LVDT_READOUT_APB_SEC_Q" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"MIV_RV32_C0_inst:AHBL_M_TARGET" "PF_SRAM_AHBL_AXI_C0_inst:AHBSlaveInterface" }

# Re-enable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 1
# Save the SmartDesign 
save_smartdesign -sd_name ${sd_name}
# Generate SmartDesign "top"
generate_component -component_name ${sd_name}



