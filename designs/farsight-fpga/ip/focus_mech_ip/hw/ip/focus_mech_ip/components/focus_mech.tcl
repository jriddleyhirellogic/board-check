# Creating SmartDesign "focus_mech"
set sd_name {focus_mech}
create_smartdesign -sd_name ${sd_name}

# Disable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 0

# Create top level Scalar Ports
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_LVDT_Gain_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_LVDT_Gain_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_LVDT_Gain_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_PRI_I_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_PRI_I_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_PRI_I_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_PRI_Q_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_PRI_Q_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_PRI_Q_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_SEC_I_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_SEC_I_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_SEC_I_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_SEC_Q_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_SEC_Q_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_SEC_Q_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PRI_STP_APB_STEPPER_CONTROLS_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PRI_STP_APB_STEPPER_CONTROLS_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PRI_STP_APB_STEPPER_CONTROLS_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PRI_STP_APB_STEPPER_OUT_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PRI_STP_APB_STEPPER_OUT_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PRI_STP_APB_STEPPER_OUT_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PRI_STP_APB_STEPPER_OVERFLOW_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PRI_STP_APB_STEPPER_OVERFLOW_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PRI_STP_APB_STEPPER_OVERFLOW_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PRI_STP_APB_VREF_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PRI_STP_APB_VREF_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PRI_STP_APB_VREF_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SEC_STP_APB_STEPPER_CONTROLS_APB_STEPPER_CONTROLS_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SEC_STP_APB_STEPPER_CONTROLS_APB_STEPPER_CONTROLS_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SEC_STP_APB_STEPPER_CONTROLS_APB_STEPPER_CONTROLS_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SEC_STP_APB_STEPPER_OUT_APB_STEPPER_OUT_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SEC_STP_APB_STEPPER_OUT_APB_STEPPER_OUT_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SEC_STP_APB_STEPPER_OUT_APB_STEPPER_OUT_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SEC_STP_APB_STEPPER_OVERFLOW_APB_STEPPER_OVERFLOW_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SEC_STP_APB_STEPPER_OVERFLOW_APB_STEPPER_OVERFLOW_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SEC_STP_APB_STEPPER_OVERFLOW_APB_STEPPER_OVERFLOW_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SEC_STP_APB_VREF_APB_VREF_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SEC_STP_APB_VREF_APB_VREF_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SEC_STP_APB_VREF_APB_VREF_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_stepper_wd_penable} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_stepper_wd_psel} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_stepper_wd_pwrite} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {lvdt_adc_spi_miso} -port_direction {IN} -port_is_pad {1}
sd_create_scalar_port -sd_name ${sd_name} -port_name {pri_stp_motor_fault_n} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sec_stp_motor_fault_n} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sys_clk_50mhz} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {sys_rst_n} -port_direction {IN}

sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_LVDT_Gain_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_LVDT_Gain_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_PRI_I_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_PRI_I_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_PRI_Q_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_PRI_Q_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_SEC_I_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_SEC_I_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_SEC_Q_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_SEC_Q_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PRI_STP_APB_STEPPER_CONTROLS_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PRI_STP_APB_STEPPER_CONTROLS_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PRI_STP_APB_STEPPER_OUT_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PRI_STP_APB_STEPPER_OUT_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PRI_STP_APB_STEPPER_OVERFLOW_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PRI_STP_APB_STEPPER_OVERFLOW_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PRI_STP_APB_VREF_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {PRI_STP_APB_VREF_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SEC_STP_APB_STEPPER_CONTROLS_APB_STEPPER_CONTROLS_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SEC_STP_APB_STEPPER_CONTROLS_APB_STEPPER_CONTROLS_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SEC_STP_APB_STEPPER_OUT_APB_STEPPER_OUT_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SEC_STP_APB_STEPPER_OUT_APB_STEPPER_OUT_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SEC_STP_APB_STEPPER_OVERFLOW_APB_STEPPER_OVERFLOW_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SEC_STP_APB_STEPPER_OVERFLOW_APB_STEPPER_OVERFLOW_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SEC_STP_APB_VREF_APB_VREF_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {SEC_STP_APB_VREF_APB_VREF_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_stepper_wd_pready} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {apb_stepper_wd_pslverr} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_pri_stp_motor_dir} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_pri_stp_motor_en} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_pri_stp_motor_fault_n} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_pri_stp_motor_step} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_pri_stp_motor_vref_pwm} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_sec_stp_motor_dir} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_sec_stp_motor_en} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_sec_stp_motor_fault_n} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_sec_stp_motor_step} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {dbg_sec_stp_motor_vref_pwm} -port_direction {OUT}
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


# Create top level Bus Ports
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_LVDT_Gain_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_LVDT_Gain_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_PRI_I_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_PRI_I_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_PRI_Q_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_PRI_Q_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_SEC_I_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_SEC_I_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_SEC_Q_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_SEC_Q_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {PRI_STP_APB_STEPPER_CONTROLS_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {PRI_STP_APB_STEPPER_CONTROLS_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {PRI_STP_APB_STEPPER_OUT_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {PRI_STP_APB_STEPPER_OUT_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {PRI_STP_APB_STEPPER_OVERFLOW_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {PRI_STP_APB_STEPPER_OVERFLOW_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {PRI_STP_APB_VREF_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {PRI_STP_APB_VREF_PWDATA} -port_direction {IN} -port_range {[15:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {SEC_STP_APB_STEPPER_CONTROLS_APB_STEPPER_CONTROLS_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {SEC_STP_APB_STEPPER_CONTROLS_APB_STEPPER_CONTROLS_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {SEC_STP_APB_STEPPER_OUT_APB_STEPPER_OUT_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {SEC_STP_APB_STEPPER_OUT_APB_STEPPER_OUT_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {SEC_STP_APB_STEPPER_OVERFLOW_APB_STEPPER_OVERFLOW_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {SEC_STP_APB_STEPPER_OVERFLOW_APB_STEPPER_OVERFLOW_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {SEC_STP_APB_VREF_APB_VREF_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {SEC_STP_APB_VREF_APB_VREF_PWDATA} -port_direction {IN} -port_range {[15:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb_stepper_wd_paddr} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb_stepper_wd_pwdata} -port_direction {IN} -port_range {[31:0]}

sd_create_bus_port -sd_name ${sd_name} -port_name {APB_LVDT_Gain_PRDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_PRI_I_PRDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_PRI_Q_PRDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_SEC_I_PRDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_SEC_Q_PRDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {PRI_STP_APB_STEPPER_CONTROLS_PRDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {PRI_STP_APB_STEPPER_OUT_PRDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {PRI_STP_APB_STEPPER_OVERFLOW_PRDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {PRI_STP_APB_VREF_PRDATA} -port_direction {OUT} -port_range {[15:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {SEC_STP_APB_STEPPER_CONTROLS_APB_STEPPER_CONTROLS_PRDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {SEC_STP_APB_STEPPER_OUT_APB_STEPPER_OUT_PRDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {SEC_STP_APB_STEPPER_OVERFLOW_APB_STEPPER_OVERFLOW_PRDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {SEC_STP_APB_VREF_APB_VREF_PRDATA} -port_direction {OUT} -port_range {[15:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {apb_stepper_wd_prdata} -port_direction {OUT} -port_range {[31:0]}


# Create top level Bus interface Ports
sd_create_bif_port -sd_name ${sd_name} -port_name {PRI_STP_APB_STEPPER_CONTROLS} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:PRI_STP_APB_STEPPER_CONTROLS_PADDR" \
"PSELx:PRI_STP_APB_STEPPER_CONTROLS_PSEL" \
"PENABLE:PRI_STP_APB_STEPPER_CONTROLS_PENABLE" \
"PWRITE:PRI_STP_APB_STEPPER_CONTROLS_PWRITE" \
"PRDATA:PRI_STP_APB_STEPPER_CONTROLS_PRDATA" \
"PWDATA:PRI_STP_APB_STEPPER_CONTROLS_PWDATA" \
"PREADY:PRI_STP_APB_STEPPER_CONTROLS_PREADY" \
"PSLVERR:PRI_STP_APB_STEPPER_CONTROLS_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {PRI_STP_APB_VREF} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:PRI_STP_APB_VREF_PADDR" \
"PSELx:PRI_STP_APB_VREF_PSEL" \
"PENABLE:PRI_STP_APB_VREF_PENABLE" \
"PWRITE:PRI_STP_APB_VREF_PWRITE" \
"PRDATA:PRI_STP_APB_VREF_PRDATA" \
"PWDATA:PRI_STP_APB_VREF_PWDATA" \
"PREADY:PRI_STP_APB_VREF_PREADY" \
"PSLVERR:PRI_STP_APB_VREF_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {PRI_STP_APB_STEPPER_OUT} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:PRI_STP_APB_STEPPER_OUT_PADDR" \
"PSELx:PRI_STP_APB_STEPPER_OUT_PSEL" \
"PENABLE:PRI_STP_APB_STEPPER_OUT_PENABLE" \
"PWRITE:PRI_STP_APB_STEPPER_OUT_PWRITE" \
"PRDATA:PRI_STP_APB_STEPPER_OUT_PRDATA" \
"PWDATA:PRI_STP_APB_STEPPER_OUT_PWDATA" \
"PREADY:PRI_STP_APB_STEPPER_OUT_PREADY" \
"PSLVERR:PRI_STP_APB_STEPPER_OUT_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {PRI_STP_APB_STEPPER_OVERFLOW} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:PRI_STP_APB_STEPPER_OVERFLOW_PADDR" \
"PSELx:PRI_STP_APB_STEPPER_OVERFLOW_PSEL" \
"PENABLE:PRI_STP_APB_STEPPER_OVERFLOW_PENABLE" \
"PWRITE:PRI_STP_APB_STEPPER_OVERFLOW_PWRITE" \
"PRDATA:PRI_STP_APB_STEPPER_OVERFLOW_PRDATA" \
"PWDATA:PRI_STP_APB_STEPPER_OVERFLOW_PWDATA" \
"PREADY:PRI_STP_APB_STEPPER_OVERFLOW_PREADY" \
"PSLVERR:PRI_STP_APB_STEPPER_OVERFLOW_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {SEC_STP_APB_STEPPER_CONTROLS} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:SEC_STP_APB_STEPPER_CONTROLS_APB_STEPPER_CONTROLS_PADDR" \
"PSELx:SEC_STP_APB_STEPPER_CONTROLS_APB_STEPPER_CONTROLS_PSEL" \
"PENABLE:SEC_STP_APB_STEPPER_CONTROLS_APB_STEPPER_CONTROLS_PENABLE" \
"PWRITE:SEC_STP_APB_STEPPER_CONTROLS_APB_STEPPER_CONTROLS_PWRITE" \
"PRDATA:SEC_STP_APB_STEPPER_CONTROLS_APB_STEPPER_CONTROLS_PRDATA" \
"PWDATA:SEC_STP_APB_STEPPER_CONTROLS_APB_STEPPER_CONTROLS_PWDATA" \
"PREADY:SEC_STP_APB_STEPPER_CONTROLS_APB_STEPPER_CONTROLS_PREADY" \
"PSLVERR:SEC_STP_APB_STEPPER_CONTROLS_APB_STEPPER_CONTROLS_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {SEC_STP_APB_VREF} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:SEC_STP_APB_VREF_APB_VREF_PADDR" \
"PSELx:SEC_STP_APB_VREF_APB_VREF_PSEL" \
"PENABLE:SEC_STP_APB_VREF_APB_VREF_PENABLE" \
"PWRITE:SEC_STP_APB_VREF_APB_VREF_PWRITE" \
"PRDATA:SEC_STP_APB_VREF_APB_VREF_PRDATA" \
"PWDATA:SEC_STP_APB_VREF_APB_VREF_PWDATA" \
"PREADY:SEC_STP_APB_VREF_APB_VREF_PREADY" \
"PSLVERR:SEC_STP_APB_VREF_APB_VREF_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {SEC_STP_APB_STEPPER_OUT} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:SEC_STP_APB_STEPPER_OUT_APB_STEPPER_OUT_PADDR" \
"PSELx:SEC_STP_APB_STEPPER_OUT_APB_STEPPER_OUT_PSEL" \
"PENABLE:SEC_STP_APB_STEPPER_OUT_APB_STEPPER_OUT_PENABLE" \
"PWRITE:SEC_STP_APB_STEPPER_OUT_APB_STEPPER_OUT_PWRITE" \
"PRDATA:SEC_STP_APB_STEPPER_OUT_APB_STEPPER_OUT_PRDATA" \
"PWDATA:SEC_STP_APB_STEPPER_OUT_APB_STEPPER_OUT_PWDATA" \
"PREADY:SEC_STP_APB_STEPPER_OUT_APB_STEPPER_OUT_PREADY" \
"PSLVERR:SEC_STP_APB_STEPPER_OUT_APB_STEPPER_OUT_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {SEC_STP_APB_STEPPER_OVERFLOW} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:SEC_STP_APB_STEPPER_OVERFLOW_APB_STEPPER_OVERFLOW_PADDR" \
"PSELx:SEC_STP_APB_STEPPER_OVERFLOW_APB_STEPPER_OVERFLOW_PSEL" \
"PENABLE:SEC_STP_APB_STEPPER_OVERFLOW_APB_STEPPER_OVERFLOW_PENABLE" \
"PWRITE:SEC_STP_APB_STEPPER_OVERFLOW_APB_STEPPER_OVERFLOW_PWRITE" \
"PRDATA:SEC_STP_APB_STEPPER_OVERFLOW_APB_STEPPER_OVERFLOW_PRDATA" \
"PWDATA:SEC_STP_APB_STEPPER_OVERFLOW_APB_STEPPER_OVERFLOW_PWDATA" \
"PREADY:SEC_STP_APB_STEPPER_OVERFLOW_APB_STEPPER_OVERFLOW_PREADY" \
"PSLVERR:SEC_STP_APB_STEPPER_OVERFLOW_APB_STEPPER_OVERFLOW_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {APB_LVDT_Gain} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:APB_LVDT_Gain_PADDR" \
"PSELx:APB_LVDT_Gain_PSEL" \
"PENABLE:APB_LVDT_Gain_PENABLE" \
"PWRITE:APB_LVDT_Gain_PWRITE" \
"PRDATA:APB_LVDT_Gain_PRDATA" \
"PWDATA:APB_LVDT_Gain_PWDATA" \
"PREADY:APB_LVDT_Gain_PREADY" \
"PSLVERR:APB_LVDT_Gain_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_SEC_Q} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:LVDT_READOUT_APB_SEC_Q_PADDR" \
"PSELx:LVDT_READOUT_APB_SEC_Q_PSEL" \
"PENABLE:LVDT_READOUT_APB_SEC_Q_PENABLE" \
"PWRITE:LVDT_READOUT_APB_SEC_Q_PWRITE" \
"PRDATA:LVDT_READOUT_APB_SEC_Q_PRDATA" \
"PWDATA:LVDT_READOUT_APB_SEC_Q_PWDATA" \
"PREADY:LVDT_READOUT_APB_SEC_Q_PREADY" \
"PSLVERR:LVDT_READOUT_APB_SEC_Q_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_PRI_I} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:LVDT_READOUT_APB_PRI_I_PADDR" \
"PSELx:LVDT_READOUT_APB_PRI_I_PSEL" \
"PENABLE:LVDT_READOUT_APB_PRI_I_PENABLE" \
"PWRITE:LVDT_READOUT_APB_PRI_I_PWRITE" \
"PRDATA:LVDT_READOUT_APB_PRI_I_PRDATA" \
"PWDATA:LVDT_READOUT_APB_PRI_I_PWDATA" \
"PREADY:LVDT_READOUT_APB_PRI_I_PREADY" \
"PSLVERR:LVDT_READOUT_APB_PRI_I_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_SEC_I} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:LVDT_READOUT_APB_SEC_I_PADDR" \
"PSELx:LVDT_READOUT_APB_SEC_I_PSEL" \
"PENABLE:LVDT_READOUT_APB_SEC_I_PENABLE" \
"PWRITE:LVDT_READOUT_APB_SEC_I_PWRITE" \
"PRDATA:LVDT_READOUT_APB_SEC_I_PRDATA" \
"PWDATA:LVDT_READOUT_APB_SEC_I_PWDATA" \
"PREADY:LVDT_READOUT_APB_SEC_I_PREADY" \
"PSLVERR:LVDT_READOUT_APB_SEC_I_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {LVDT_READOUT_APB_PRI_Q} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:LVDT_READOUT_APB_PRI_Q_PADDR" \
"PSELx:LVDT_READOUT_APB_PRI_Q_PSEL" \
"PENABLE:LVDT_READOUT_APB_PRI_Q_PENABLE" \
"PWRITE:LVDT_READOUT_APB_PRI_Q_PWRITE" \
"PRDATA:LVDT_READOUT_APB_PRI_Q_PRDATA" \
"PWDATA:LVDT_READOUT_APB_PRI_Q_PWDATA" \
"PREADY:LVDT_READOUT_APB_PRI_Q_PREADY" \
"PSLVERR:LVDT_READOUT_APB_PRI_Q_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {apb_stepper_wd} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:apb_stepper_wd_paddr" \
"PSELx:apb_stepper_wd_psel" \
"PENABLE:apb_stepper_wd_penable" \
"PWRITE:apb_stepper_wd_pwrite" \
"PRDATA:apb_stepper_wd_prdata" \
"PWDATA:apb_stepper_wd_pwdata" \
"PREADY:apb_stepper_wd_pready" \
"PSLVERR:apb_stepper_wd_pslverr" } 

# Add AND2_motor1_step_and_wdt_inst instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {AND2} -instance_name {AND2_motor1_step_and_wdt_inst}



# Add AND2_motor2_step_and_wdt_inst instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {AND2} -instance_name {AND2_motor2_step_and_wdt_inst}



# Add INBUF_0 instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {INBUF} -instance_name {INBUF_0}



# Add LVDT_Gain_0 instance
sd_instantiate_component -sd_name ${sd_name} -component_name {LVDT_Gain} -instance_name {LVDT_Gain_0}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {LVDT_Gain_0:INT}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {LVDT_Gain_0:GPIO_IN} -value {GND}



# Add LVDT_READOUT_0 instance
sd_instantiate_component -sd_name ${sd_name} -component_name {LVDT_READOUT} -instance_name {LVDT_READOUT_0}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {LVDT_READOUT_0:o_data} -pin_slices {[0:0]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {LVDT_READOUT_0:o_data} -pin_slices {[1:1]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {LVDT_READOUT_0:o_data} -pin_slices {[2:2]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {LVDT_READOUT_0:o_data} -pin_slices {[3:3]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {LVDT_READOUT_0:o_data} -pin_slices {[4:4]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {LVDT_READOUT_0:o_data} -pin_slices {[5:5]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {LVDT_READOUT_0:o_data} -pin_slices {[6:6]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {LVDT_READOUT_0:o_data} -pin_slices {[7:7]}



# Add OUTBUF_0 instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {OUTBUF} -instance_name {OUTBUF_0}



# Add OUTBUF_1 instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {OUTBUF} -instance_name {OUTBUF_1}



# Add OUTBUF_2 instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {OUTBUF} -instance_name {OUTBUF_2}



# Add OUTBUF_3 instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {OUTBUF} -instance_name {OUTBUF_3}



# Add OUTBUF_4 instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {OUTBUF} -instance_name {OUTBUF_4}



# Add OUTBUF_5 instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {OUTBUF} -instance_name {OUTBUF_5}



# Add OUTBUF_6 instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {OUTBUF} -instance_name {OUTBUF_6}



# Add OUTBUF_7 instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {OUTBUF} -instance_name {OUTBUF_7}



# Add OUTBUF_8 instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {OUTBUF} -instance_name {OUTBUF_8}



# Add OUTBUF_9 instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {OUTBUF} -instance_name {OUTBUF_9}



# Add OUTBUF_10 instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {OUTBUF} -instance_name {OUTBUF_10}



# Add OUTBUF_10_0 instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {OUTBUF} -instance_name {OUTBUF_10_0}



# Add OUTBUF_10_1 instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {OUTBUF} -instance_name {OUTBUF_10_1}



# Add OUTBUF_10_2 instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {OUTBUF} -instance_name {OUTBUF_10_2}



# Add OUTBUF_10_3 instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {OUTBUF} -instance_name {OUTBUF_10_3}



# Add STEPPER_DRIVER_1 instance
sd_instantiate_component -sd_name ${sd_name} -component_name {STEPPER_DRIVER} -instance_name {STEPPER_DRIVER_1}



# Add STEPPER_DRIVER_2 instance
sd_instantiate_component -sd_name ${sd_name} -component_name {STEPPER_DRIVER} -instance_name {STEPPER_DRIVER_2}



# Add TRIBUFF_0 instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {TRIBUFF} -instance_name {TRIBUFF_0}



# Add TRIBUFF_1 instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {TRIBUFF} -instance_name {TRIBUFF_1}



# Add TRIBUFF_1_0 instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {TRIBUFF} -instance_name {TRIBUFF_1_0}



# Add TRIBUFF_1_1 instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {TRIBUFF} -instance_name {TRIBUFF_1_1}



# Add TRIBUFF_2 instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {TRIBUFF} -instance_name {TRIBUFF_2}



# Add TRIBUFF_3 instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {TRIBUFF} -instance_name {TRIBUFF_3}



# Add TRIBUFF_3_0 instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {TRIBUFF} -instance_name {TRIBUFF_3_0}



# Add TRIBUFF_3_0_0 instance
sd_instantiate_macro -sd_name ${sd_name} -macro_name {TRIBUFF} -instance_name {TRIBUFF_3_0_0}



# Add watchdog_top_inst instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {watchdog_top} -instance_name {watchdog_top_inst}
# Exporting Parameters of instance watchdog_top_inst
sd_configure_core_instance -sd_name ${sd_name} -instance_name {watchdog_top_inst} -params {\
"APB_ADDR_WIDTH:32" \
"APB_DATA_WIDTH:32" \
"CLOCK_FREQ_MHZ:50" \
"TIMER_COUNT_WIDTH:27" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {watchdog_top_inst}
sd_update_instance -sd_name ${sd_name} -instance_name {watchdog_top_inst}



# Add scalar net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"AND2_motor1_step_and_wdt_inst:A" "STEPPER_DRIVER_1:STEPPER_STEP" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"AND2_motor1_step_and_wdt_inst:B" "AND2_motor2_step_and_wdt_inst:B" "watchdog_top_inst:wd_active" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"AND2_motor1_step_and_wdt_inst:Y" "OUTBUF_10_0:D" "dbg_pri_stp_motor_step" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"AND2_motor2_step_and_wdt_inst:A" "STEPPER_DRIVER_2:STEPPER_STEP" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"AND2_motor2_step_and_wdt_inst:Y" "OUTBUF_10_2:D" "dbg_sec_stp_motor_step" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"INBUF_0:PAD" "lvdt_adc_spi_miso" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"INBUF_0:Y" "LVDT_READOUT_0:lvdt_adc_spi_miso" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LVDT_Gain_0:GPIO_OUT" "lvdt_gain_switch" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LVDT_Gain_0:PCLK" "LVDT_READOUT_0:i_clk" "STEPPER_DRIVER_1:i_clk" "STEPPER_DRIVER_2:i_clk" "sys_clk_50mhz" "watchdog_top_inst:pclk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LVDT_Gain_0:PRESETN" "LVDT_READOUT_0:i_res" "STEPPER_DRIVER_1:i_rst" "STEPPER_DRIVER_2:i_rst" "sys_rst_n" "watchdog_top_inst:presetn" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LVDT_READOUT_0:o_data[0:0]" "OUTBUF_10:D" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LVDT_READOUT_0:o_data[1:1]" "OUTBUF_9:D" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LVDT_READOUT_0:o_data[2:2]" "OUTBUF_8:D" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LVDT_READOUT_0:o_data[3:3]" "OUTBUF_7:D" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LVDT_READOUT_0:o_data[4:4]" "OUTBUF_6:D" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LVDT_READOUT_0:o_data[5:5]" "OUTBUF_5:D" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LVDT_READOUT_0:o_data[6:6]" "OUTBUF_4:D" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LVDT_READOUT_0:o_data[7:7]" "OUTBUF_3:D" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LVDT_READOUT_0:o_spi_clk" "OUTBUF_0:D" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LVDT_READOUT_0:o_spi_cs" "OUTBUF_1:D" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LVDT_READOUT_0:o_spi_mosi" "OUTBUF_2:D" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"OUTBUF_0:PAD" "lvdt_adc_spi_sclk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"OUTBUF_10:PAD" "lvdt_dac_b0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"OUTBUF_10_0:PAD" "pri_stp_motor_step" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"OUTBUF_10_1:D" "STEPPER_DRIVER_1:STEPPER_DIR" "dbg_pri_stp_motor_dir" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"OUTBUF_10_1:PAD" "pri_stp_motor_dir" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"OUTBUF_10_2:PAD" "sec_stp_motor_step" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"OUTBUF_10_3:D" "STEPPER_DRIVER_2:STEPPER_DIR" "dbg_sec_stp_motor_dir" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"OUTBUF_10_3:PAD" "sec_stp_motor_dir" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"OUTBUF_1:PAD" "lvdt_adc_spi_cs_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"OUTBUF_2:PAD" "lvdt_adc_spi_mosi" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"OUTBUF_3:PAD" "lvdt_dac_b7" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"OUTBUF_4:PAD" "lvdt_dac_b6" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"OUTBUF_5:PAD" "lvdt_dac_b5" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"OUTBUF_6:PAD" "lvdt_dac_b4" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"OUTBUF_7:PAD" "lvdt_dac_b3" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"OUTBUF_8:PAD" "lvdt_dac_b2" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"OUTBUF_9:PAD" "lvdt_dac_b1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_DRIVER_1:Decay0_Out_Enable" "TRIBUFF_3_0:E" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_DRIVER_1:M0_Out_Enable" "TRIBUFF_3_0_0:E" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_DRIVER_1:M1_Out_Enable" "TRIBUFF_3:E" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_DRIVER_1:STEPPER_DECAY0" "TRIBUFF_3_0:D" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_DRIVER_1:STEPPER_DECAY1" "pri_stp_motor_decay1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_DRIVER_1:STEPPER_EN" "dbg_pri_stp_motor_en" "pri_stp_motor_en" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_DRIVER_1:STEPPER_M0" "TRIBUFF_3_0_0:D" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_DRIVER_1:STEPPER_M1" "TRIBUFF_3:D" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_DRIVER_1:STEPPER_TOFF" "TRIBUFF_2:D" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_DRIVER_1:STEPPER_VREF_PWM" "dbg_pri_stp_motor_vref_pwm" "pri_stp_motor_vref_pwm" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_DRIVER_1:STEPPER_nFAULT" "dbg_pri_stp_motor_fault_n" "pri_stp_motor_fault_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_DRIVER_1:STEPPER_nSLEEP" "pri_stp_motor_sleep_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_DRIVER_1:TOFF_Out_Enable" "TRIBUFF_2:E" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_DRIVER_2:Decay0_Out_Enable" "TRIBUFF_1_1:E" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_DRIVER_2:M0_Out_Enable" "TRIBUFF_1_0:E" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_DRIVER_2:M1_Out_Enable" "TRIBUFF_0:E" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_DRIVER_2:STEPPER_DECAY0" "TRIBUFF_1_1:D" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_DRIVER_2:STEPPER_DECAY1" "sec_stp_motor_decay1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_DRIVER_2:STEPPER_EN" "dbg_sec_stp_motor_en" "sec_stp_motor_en" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_DRIVER_2:STEPPER_M0" "TRIBUFF_1_0:D" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_DRIVER_2:STEPPER_M1" "TRIBUFF_0:D" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_DRIVER_2:STEPPER_TOFF" "TRIBUFF_1:D" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_DRIVER_2:STEPPER_VREF_PWM" "dbg_sec_stp_motor_vref_pwm" "sec_stp_motor_vref_pwm" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_DRIVER_2:STEPPER_nFAULT" "dbg_sec_stp_motor_fault_n" "sec_stp_motor_fault_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_DRIVER_2:STEPPER_nSLEEP" "sec_stp_motor_sleep_n" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_DRIVER_2:TOFF_Out_Enable" "TRIBUFF_1:E" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"TRIBUFF_0:PAD" "sec_stp_motor_m1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"TRIBUFF_1:PAD" "sec_stp_motor_toff" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"TRIBUFF_1_0:PAD" "sec_stp_motor_m0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"TRIBUFF_1_1:PAD" "sec_stp_motor_decay0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"TRIBUFF_2:PAD" "pri_stp_motor_toff" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"TRIBUFF_3:PAD" "pri_stp_motor_m1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"TRIBUFF_3_0:PAD" "pri_stp_motor_decay0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"TRIBUFF_3_0_0:PAD" "pri_stp_motor_m0" }


# Add bus interface net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"APB_LVDT_Gain" "LVDT_Gain_0:APB_bif" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LVDT_READOUT_0:APB_PRI_I" "LVDT_READOUT_APB_PRI_I" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LVDT_READOUT_0:APB_PRI_Q" "LVDT_READOUT_APB_PRI_Q" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LVDT_READOUT_0:APB_SEC_I" "LVDT_READOUT_APB_SEC_I" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LVDT_READOUT_0:APB_SEC_Q" "LVDT_READOUT_APB_SEC_Q" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"PRI_STP_APB_STEPPER_CONTROLS" "STEPPER_DRIVER_1:APB_STEPPER_CONTROLS" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"PRI_STP_APB_STEPPER_OUT" "STEPPER_DRIVER_1:APB_STEPPER_OUT" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"PRI_STP_APB_STEPPER_OVERFLOW" "STEPPER_DRIVER_1:APB_STEPPER_OVERFLOW" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"PRI_STP_APB_VREF" "STEPPER_DRIVER_1:APB_VREF" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"SEC_STP_APB_STEPPER_CONTROLS" "STEPPER_DRIVER_2:APB_STEPPER_CONTROLS" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"SEC_STP_APB_STEPPER_OUT" "STEPPER_DRIVER_2:APB_STEPPER_OUT" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"SEC_STP_APB_STEPPER_OVERFLOW" "STEPPER_DRIVER_2:APB_STEPPER_OVERFLOW" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"SEC_STP_APB_VREF" "STEPPER_DRIVER_2:APB_VREF" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"apb_stepper_wd" "watchdog_top_inst:s_apb" }

# Re-enable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 1
# Save the SmartDesign 
save_smartdesign -sd_name ${sd_name}
# Generate SmartDesign "focus_mech"
generate_component -component_name ${sd_name}
