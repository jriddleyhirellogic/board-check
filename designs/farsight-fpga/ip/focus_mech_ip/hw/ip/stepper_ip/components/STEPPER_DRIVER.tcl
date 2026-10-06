# Creating SmartDesign "STEPPER_DRIVER"
set sd_name {STEPPER_DRIVER}
create_smartdesign -sd_name ${sd_name}

# Disable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 0

# Create top level Scalar Ports
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_STEPPER_CONTROLS_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_STEPPER_CONTROLS_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_STEPPER_CONTROLS_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_STEPPER_OUT_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_STEPPER_OUT_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_STEPPER_OUT_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_STEPPER_OVERFLOW_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_STEPPER_OVERFLOW_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_STEPPER_OVERFLOW_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_VREF_PENABLE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_VREF_PSEL} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_VREF_PWRITE} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {STEPPER_nFAULT} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {i_clk} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {i_rst} -port_direction {IN}

sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_STEPPER_CONTROLS_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_STEPPER_CONTROLS_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_STEPPER_OUT_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_STEPPER_OUT_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_STEPPER_OVERFLOW_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_STEPPER_OVERFLOW_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_VREF_PREADY} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {APB_VREF_PSLVERR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {Decay0_Out_Enable} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {M0_Out_Enable} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {M1_Out_Enable} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {STEPPER_DECAY0} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {STEPPER_DECAY1} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {STEPPER_DIR} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {STEPPER_EN} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {STEPPER_M0} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {STEPPER_M1} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {STEPPER_STEP} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {STEPPER_TOFF} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {STEPPER_VREF_PWM} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {STEPPER_nSLEEP} -port_direction {OUT}
sd_create_scalar_port -sd_name ${sd_name} -port_name {TOFF_Out_Enable} -port_direction {OUT}


# Create top level Bus Ports
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_STEPPER_CONTROLS_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_STEPPER_CONTROLS_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_STEPPER_OUT_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_STEPPER_OUT_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_STEPPER_OVERFLOW_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_STEPPER_OVERFLOW_PWDATA} -port_direction {IN} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_VREF_PADDR} -port_direction {IN} -port_range {[7:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_VREF_PWDATA} -port_direction {IN} -port_range {[15:0]}

sd_create_bus_port -sd_name ${sd_name} -port_name {APB_STEPPER_CONTROLS_PRDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_STEPPER_OUT_PRDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_STEPPER_OVERFLOW_PRDATA} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {APB_VREF_PRDATA} -port_direction {OUT} -port_range {[15:0]}


# Create top level Bus interface Ports
sd_create_bif_port -sd_name ${sd_name} -port_name {APB_VREF} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:APB_VREF_PADDR" \
"PSELx:APB_VREF_PSEL" \
"PENABLE:APB_VREF_PENABLE" \
"PWRITE:APB_VREF_PWRITE" \
"PRDATA:APB_VREF_PRDATA" \
"PWDATA:APB_VREF_PWDATA" \
"PREADY:APB_VREF_PREADY" \
"PSLVERR:APB_VREF_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {APB_STEPPER_OUT} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:APB_STEPPER_OUT_PADDR" \
"PSELx:APB_STEPPER_OUT_PSEL" \
"PENABLE:APB_STEPPER_OUT_PENABLE" \
"PWRITE:APB_STEPPER_OUT_PWRITE" \
"PRDATA:APB_STEPPER_OUT_PRDATA" \
"PWDATA:APB_STEPPER_OUT_PWDATA" \
"PREADY:APB_STEPPER_OUT_PREADY" \
"PSLVERR:APB_STEPPER_OUT_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {APB_STEPPER_OVERFLOW} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:APB_STEPPER_OVERFLOW_PADDR" \
"PSELx:APB_STEPPER_OVERFLOW_PSEL" \
"PENABLE:APB_STEPPER_OVERFLOW_PENABLE" \
"PWRITE:APB_STEPPER_OVERFLOW_PWRITE" \
"PRDATA:APB_STEPPER_OVERFLOW_PRDATA" \
"PWDATA:APB_STEPPER_OVERFLOW_PWDATA" \
"PREADY:APB_STEPPER_OVERFLOW_PREADY" \
"PSLVERR:APB_STEPPER_OVERFLOW_PSLVERR" } 

sd_create_bif_port -sd_name ${sd_name} -port_name {APB_STEPPER_CONTROLS} -port_bif_vlnv {AMBA:AMBA2:APB:r0p0} -port_bif_role {slave} -port_bif_mapping {\
"PADDR:APB_STEPPER_CONTROLS_PADDR" \
"PSELx:APB_STEPPER_CONTROLS_PSEL" \
"PENABLE:APB_STEPPER_CONTROLS_PENABLE" \
"PWRITE:APB_STEPPER_CONTROLS_PWRITE" \
"PRDATA:APB_STEPPER_CONTROLS_PRDATA" \
"PWDATA:APB_STEPPER_CONTROLS_PWDATA" \
"PREADY:APB_STEPPER_CONTROLS_PREADY" \
"PSLVERR:APB_STEPPER_CONTROLS_PSLVERR" } 

# Add STEP_DIR_0 instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {STEP_DIR} -instance_name {STEP_DIR_0}
# Exporting Parameters of instance STEP_DIR_0
sd_configure_core_instance -sd_name ${sd_name} -instance_name {STEP_DIR_0} -params {\
"INPUT_WIDTH:32" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {STEP_DIR_0}
sd_update_instance -sd_name ${sd_name} -instance_name {STEP_DIR_0}



# Add STEPPER_CONTROLS instance
sd_instantiate_component -sd_name ${sd_name} -component_name {FOCUS_MECH_CoreGPIO_C2} -instance_name {STEPPER_CONTROLS}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {STEPPER_CONTROLS:GPIO_IN} -pin_slices {[0:0]}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {STEPPER_CONTROLS:GPIO_IN[0:0]} -value {GND}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {STEPPER_CONTROLS:GPIO_IN} -pin_slices {[1:1]}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {STEPPER_CONTROLS:GPIO_IN[1:1]} -value {GND}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {STEPPER_CONTROLS:GPIO_IN} -pin_slices {[2:2]}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {STEPPER_CONTROLS:GPIO_IN[2:2]} -value {GND}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {STEPPER_CONTROLS:GPIO_IN} -pin_slices {[3:3]}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {STEPPER_CONTROLS:GPIO_IN[3:3]} -value {GND}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {STEPPER_CONTROLS:GPIO_IN} -pin_slices {[4:4]}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {STEPPER_CONTROLS:GPIO_IN[4:4]} -value {GND}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {STEPPER_CONTROLS:GPIO_IN} -pin_slices {[5:5]}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {STEPPER_CONTROLS:GPIO_IN[5:5]} -value {GND}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {STEPPER_CONTROLS:GPIO_IN} -pin_slices {[6:6]}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {STEPPER_CONTROLS:GPIO_IN[6:6]} -value {GND}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {STEPPER_CONTROLS:GPIO_IN} -pin_slices {[7:7]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {STEPPER_CONTROLS:GPIO_OUT} -pin_slices {[0:0]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {STEPPER_CONTROLS:GPIO_OUT} -pin_slices {[1:1]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {STEPPER_CONTROLS:GPIO_OUT} -pin_slices {[2:2]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {STEPPER_CONTROLS:GPIO_OUT} -pin_slices {[3:3]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {STEPPER_CONTROLS:GPIO_OUT} -pin_slices {[4:4]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {STEPPER_CONTROLS:GPIO_OUT} -pin_slices {[5:5]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {STEPPER_CONTROLS:GPIO_OUT} -pin_slices {[6:6]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {STEPPER_CONTROLS:GPIO_OUT} -pin_slices {[7:7]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {STEPPER_CONTROLS:GPIO_OUT[7:7]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {STEPPER_CONTROLS:GPIO_OE} -pin_slices {[0:0]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {STEPPER_CONTROLS:GPIO_OE} -pin_slices {[1:1]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {STEPPER_CONTROLS:GPIO_OE} -pin_slices {[2:2]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {STEPPER_CONTROLS:GPIO_OE[2:2]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {STEPPER_CONTROLS:GPIO_OE} -pin_slices {[3:3]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {STEPPER_CONTROLS:GPIO_OE} -pin_slices {[4:4]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {STEPPER_CONTROLS:GPIO_OE[4:4]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {STEPPER_CONTROLS:GPIO_OE} -pin_slices {[5:5]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {STEPPER_CONTROLS:GPIO_OE} -pin_slices {[6:6]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {STEPPER_CONTROLS:GPIO_OE[6:6]}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {STEPPER_CONTROLS:GPIO_OE} -pin_slices {[7:7]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {STEPPER_CONTROLS:GPIO_OE[7:7]}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {STEPPER_CONTROLS:INT}



# Add STEPPER_OUT instance
sd_instantiate_component -sd_name ${sd_name} -component_name {FOCUS_MECH_CoreGPIO_C3} -instance_name {STEPPER_OUT}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {STEPPER_OUT:INT}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {STEPPER_OUT:GPIO_IN} -value {GND}



# Add STEPPER_OVERFLOW instance
sd_instantiate_component -sd_name ${sd_name} -component_name {FOCUS_MECH_CoreGPIO_C4} -instance_name {STEPPER_OVERFLOW}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {STEPPER_OVERFLOW:INT}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {STEPPER_OVERFLOW:GPIO_IN} -value {GND}



# Add VREF_PWM instance
sd_instantiate_component -sd_name ${sd_name} -component_name {corepwm_C0} -instance_name {VREF_PWM}
sd_create_pin_slices -sd_name ${sd_name} -pin_name {VREF_PWM:PWM} -pin_slices {[0:0]}



# Add scalar net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"Decay0_Out_Enable" "STEPPER_CONTROLS:GPIO_OE[3:3]" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"M0_Out_Enable" "STEPPER_CONTROLS:GPIO_OE[0:0]" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"M1_Out_Enable" "STEPPER_CONTROLS:GPIO_OE[1:1]" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_CONTROLS:GPIO_IN[7:7]" "STEPPER_nFAULT" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_CONTROLS:GPIO_OE[5:5]" "TOFF_Out_Enable" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_CONTROLS:GPIO_OUT[0:0]" "STEPPER_M0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_CONTROLS:GPIO_OUT[1:1]" "STEPPER_M1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_CONTROLS:GPIO_OUT[2:2]" "STEPPER_EN" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_CONTROLS:GPIO_OUT[3:3]" "STEPPER_DECAY0" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_CONTROLS:GPIO_OUT[4:4]" "STEPPER_DECAY1" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_CONTROLS:GPIO_OUT[5:5]" "STEPPER_TOFF" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_CONTROLS:GPIO_OUT[6:6]" "STEPPER_nSLEEP" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_CONTROLS:PCLK" "STEPPER_OUT:PCLK" "STEPPER_OVERFLOW:PCLK" "STEP_DIR_0:i_clk" "VREF_PWM:PCLK" "i_clk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_CONTROLS:PRESETN" "STEPPER_OUT:PRESETN" "STEPPER_OVERFLOW:PRESETN" "STEP_DIR_0:i_res" "VREF_PWM:PRESETN" "i_rst" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_DIR" "STEP_DIR_0:o_dir" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_STEP" "STEP_DIR_0:o_step" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_VREF_PWM" "VREF_PWM:PWM[0:0]" }

# Add bus net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_OUT:GPIO_OUT" "STEP_DIR_0:i_data" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"STEPPER_OVERFLOW:GPIO_OUT" "STEP_DIR_0:i_overflow" }

# Add bus interface net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"APB_STEPPER_CONTROLS" "STEPPER_CONTROLS:APB_bif" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"APB_STEPPER_OUT" "STEPPER_OUT:APB_bif" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"APB_STEPPER_OVERFLOW" "STEPPER_OVERFLOW:APB_bif" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"APB_VREF" "VREF_PWM:APBslave" }

# Re-enable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 1
# Save the SmartDesign 
save_smartdesign -sd_name ${sd_name}
# Generate SmartDesign "STEPPER_DRIVER"
generate_component -component_name ${sd_name}
