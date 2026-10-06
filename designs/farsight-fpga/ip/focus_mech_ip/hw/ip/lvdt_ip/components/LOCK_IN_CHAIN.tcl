# Creating SmartDesign "LOCK_IN_CHAIN"
set sd_name {LOCK_IN_CHAIN}
create_smartdesign -sd_name ${sd_name}

# Disable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 0

# Create top level Scalar Ports
sd_create_scalar_port -sd_name ${sd_name} -port_name {i_clk} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {i_data_valid} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {i_osc_data_valid} -port_direction {IN}
sd_create_scalar_port -sd_name ${sd_name} -port_name {i_res} -port_direction {IN}

sd_create_scalar_port -sd_name ${sd_name} -port_name {o_data_ready} -port_direction {OUT}


# Create top level Bus Ports
sd_create_bus_port -sd_name ${sd_name} -port_name {i_cos} -port_direction {IN} -port_range {[16:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {i_data} -port_direction {IN} -port_range {[12:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {i_sin} -port_direction {IN} -port_range {[16:0]}

sd_create_bus_port -sd_name ${sd_name} -port_name {o_data_i} -port_direction {OUT} -port_range {[31:0]}
sd_create_bus_port -sd_name ${sd_name} -port_name {o_data_q} -port_direction {OUT} -port_range {[31:0]}


# Add BANDPASS_1_2 instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {IIR_BIQUAD} -instance_name {BANDPASS_1_2}
# Exporting Parameters of instance BANDPASS_1_2
sd_configure_core_instance -sd_name ${sd_name} -instance_name {BANDPASS_1_2} -params {\
"A1:-61019" \
"A2:30087" \
"B0:32786" \
"B1:65536" \
"B2:32768" \
"COEFFICIENT_WIDTH:18" \
"FIXED_POINT:15" \
"G:204" \
"INPUT_WIDTH:13" \
"OUTPUT_WIDTH:21" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {BANDPASS_1_2}
sd_update_instance -sd_name ${sd_name} -instance_name {BANDPASS_1_2}



# Add BANDPASS_2_2 instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {IIR_BIQUAD} -instance_name {BANDPASS_2_2}
# Exporting Parameters of instance BANDPASS_2_2
sd_configure_core_instance -sd_name ${sd_name} -instance_name {BANDPASS_2_2} -params {\
"A1:-62735" \
"A2:30870" \
"B0:32768" \
"B1:-65536" \
"B2:32768" \
"COEFFICIENT_WIDTH:18" \
"FIXED_POINT:15" \
"G:3" \
"INPUT_WIDTH:21" \
"OUTPUT_WIDTH:23" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {BANDPASS_2_2}
sd_update_instance -sd_name ${sd_name} -instance_name {BANDPASS_2_2}



# Add BS_I_1_3 instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {IIR_BIQUAD} -instance_name {BS_I_1_3}
# Exporting Parameters of instance BS_I_1_3
sd_configure_core_instance -sd_name ${sd_name} -instance_name {BS_I_1_3} -params {\
"A1:12170" \
"A2:-8022" \
"B0:32768" \
"B1:32232" \
"B2:32768" \
"COEFFICIENT_WIDTH:18" \
"FIXED_POINT:15" \
"G:3" \
"INPUT_WIDTH:32" \
"OUTPUT_WIDTH:31" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {BS_I_1_3}
sd_update_instance -sd_name ${sd_name} -instance_name {BS_I_1_3}



# Add BS_I_2_3 instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {IIR_BIQUAD} -instance_name {BS_I_2_3}
# Exporting Parameters of instance BS_I_2_3
sd_configure_core_instance -sd_name ${sd_name} -instance_name {BS_I_2_3} -params {\
"A1:-15737" \
"A2:23532" \
"B0:32768" \
"B1:31416" \
"B2:32768" \
"COEFFICIENT_WIDTH:18" \
"FIXED_POINT:15" \
"G:6" \
"INPUT_WIDTH:31" \
"OUTPUT_WIDTH:30" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {BS_I_2_3}
sd_update_instance -sd_name ${sd_name} -instance_name {BS_I_2_3}



# Add BS_I_3_3 instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {IIR_BIQUAD} -instance_name {BS_I_3_3}
# Exporting Parameters of instance BS_I_3_3
sd_configure_core_instance -sd_name ${sd_name} -instance_name {BS_I_3_3} -params {\
"A1:53140" \
"A2:27802" \
"B0:32768" \
"B1:33035" \
"B2:32768" \
"COEFFICIENT_WIDTH:18" \
"FIXED_POINT:15" \
"G:11" \
"INPUT_WIDTH:30" \
"OUTPUT_WIDTH:30" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {BS_I_3_3}
sd_update_instance -sd_name ${sd_name} -instance_name {BS_I_3_3}



# Add BS_Q_1_3 instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {IIR_BIQUAD} -instance_name {BS_Q_1_3}
# Exporting Parameters of instance BS_Q_1_3
sd_configure_core_instance -sd_name ${sd_name} -instance_name {BS_Q_1_3} -params {\
"A1:12170" \
"A2:-8022" \
"B0:32768" \
"B1:32232" \
"B2:32768" \
"COEFFICIENT_WIDTH:18" \
"FIXED_POINT:15" \
"G:3" \
"INPUT_WIDTH:32" \
"OUTPUT_WIDTH:31" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {BS_Q_1_3}
sd_update_instance -sd_name ${sd_name} -instance_name {BS_Q_1_3}



# Add BS_Q_2_3 instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {IIR_BIQUAD} -instance_name {BS_Q_2_3}
# Exporting Parameters of instance BS_Q_2_3
sd_configure_core_instance -sd_name ${sd_name} -instance_name {BS_Q_2_3} -params {\
"A1:-15737" \
"A2:23532" \
"B0:32768" \
"B1:31416" \
"B2:32768" \
"COEFFICIENT_WIDTH:18" \
"FIXED_POINT:15" \
"G:6" \
"INPUT_WIDTH:31" \
"OUTPUT_WIDTH:30" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {BS_Q_2_3}
sd_update_instance -sd_name ${sd_name} -instance_name {BS_Q_2_3}



# Add BS_Q_3_3 instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {IIR_BIQUAD} -instance_name {BS_Q_3_3}
# Exporting Parameters of instance BS_Q_3_3
sd_configure_core_instance -sd_name ${sd_name} -instance_name {BS_Q_3_3} -params {\
"A1:53140" \
"A2:27802" \
"B0:32768" \
"B1:33035" \
"B2:32768" \
"COEFFICIENT_WIDTH:18" \
"FIXED_POINT:15" \
"G:11" \
"INPUT_WIDTH:30" \
"OUTPUT_WIDTH:30" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {BS_Q_3_3}
sd_update_instance -sd_name ${sd_name} -instance_name {BS_Q_3_3}



# Add DECIMATOR_I instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {DECIMATOR} -instance_name {DECIMATOR_I}
# Exporting Parameters of instance DECIMATOR_I
sd_configure_core_instance -sd_name ${sd_name} -instance_name {DECIMATOR_I} -params {\
"DATA_WIDTH:32" \
"DECIMATION_RATIO:5" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {DECIMATOR_I}
sd_update_instance -sd_name ${sd_name} -instance_name {DECIMATOR_I}



# Add DECIMATOR_Q instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {DECIMATOR} -instance_name {DECIMATOR_Q}
# Exporting Parameters of instance DECIMATOR_Q
sd_configure_core_instance -sd_name ${sd_name} -instance_name {DECIMATOR_Q} -params {\
"DATA_WIDTH:32" \
"DECIMATION_RATIO:5" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {DECIMATOR_Q}
sd_update_instance -sd_name ${sd_name} -instance_name {DECIMATOR_Q}



# Add IQ_MIXER_0 instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {IQ_MIXER} -instance_name {IQ_MIXER_0}
# Exporting Parameters of instance IQ_MIXER_0
sd_configure_core_instance -sd_name ${sd_name} -instance_name {IQ_MIXER_0} -params {\
"INPUT_DATA_WIDTH:23" \
"INPUT_OSC_WIDTH:17" \
"OUTPUT_WIDTH:32" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {IQ_MIXER_0}
sd_update_instance -sd_name ${sd_name} -instance_name {IQ_MIXER_0}



# Add LP_I_1_2 instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {IIR_BIQUAD} -instance_name {LP_I_1_2}
# Exporting Parameters of instance LP_I_1_2
sd_configure_core_instance -sd_name ${sd_name} -instance_name {LP_I_1_2} -params {\
"A1:-32086" \
"A2:8618" \
"B0:32768" \
"B1:65536" \
"B2:32768" \
"COEFFICIENT_WIDTH:18" \
"FIXED_POINT:15" \
"G:15" \
"INPUT_WIDTH:30" \
"OUTPUT_WIDTH:30" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {LP_I_1_2}
sd_update_instance -sd_name ${sd_name} -instance_name {LP_I_1_2}



# Add LP_I_2_2 instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {IIR_BIQUAD} -instance_name {LP_I_2_2}
# Exporting Parameters of instance LP_I_2_2
sd_configure_core_instance -sd_name ${sd_name} -instance_name {LP_I_2_2} -params {\
"A1:-40919" \
"A2:20011" \
"B0:32768" \
"B1:65536" \
"B2:32768" \
"COEFFICIENT_WIDTH:18" \
"FIXED_POINT:15" \
"G:15" \
"INPUT_WIDTH:30" \
"OUTPUT_WIDTH:32" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {LP_I_2_2}
sd_update_instance -sd_name ${sd_name} -instance_name {LP_I_2_2}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {LP_I_2_2:o_data_valid}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {LP_I_2_2:i_data_ready} -value {VCC}



# Add LP_Q_1_2 instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {IIR_BIQUAD} -instance_name {LP_Q_1_2}
# Exporting Parameters of instance LP_Q_1_2
sd_configure_core_instance -sd_name ${sd_name} -instance_name {LP_Q_1_2} -params {\
"A1:-32086" \
"A2:8618" \
"B0:32768" \
"B1:65536" \
"B2:32768" \
"COEFFICIENT_WIDTH:18" \
"FIXED_POINT:15" \
"G:15" \
"INPUT_WIDTH:30" \
"OUTPUT_WIDTH:30" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {LP_Q_1_2}
sd_update_instance -sd_name ${sd_name} -instance_name {LP_Q_1_2}



# Add LP_Q_2_2 instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {IIR_BIQUAD} -instance_name {LP_Q_2_2}
# Exporting Parameters of instance LP_Q_2_2
sd_configure_core_instance -sd_name ${sd_name} -instance_name {LP_Q_2_2} -params {\
"A1:-40919" \
"A2:20011" \
"B0:32768" \
"B1:65536" \
"B2:32768" \
"COEFFICIENT_WIDTH:18" \
"FIXED_POINT:15" \
"G:15" \
"INPUT_WIDTH:30" \
"OUTPUT_WIDTH:32" }\
-validate_rules 0
sd_save_core_instance_config -sd_name ${sd_name} -instance_name {LP_Q_2_2}
sd_update_instance -sd_name ${sd_name} -instance_name {LP_Q_2_2}
sd_mark_pins_unused -sd_name ${sd_name} -pin_names {LP_Q_2_2:o_data_valid}
sd_connect_pins_to_constant -sd_name ${sd_name} -pin_names {LP_Q_2_2:i_data_ready} -value {VCC}



# Add MIXER_FLOW_SPLITTER instance
sd_instantiate_hdl_core -sd_name ${sd_name} -hdl_core_name {MIXER_READY_VALID_HANDLER} -instance_name {MIXER_FLOW_SPLITTER}



# Add scalar net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"BANDPASS_1_2:i_clk" "BANDPASS_2_2:i_clk" "BS_I_1_3:i_clk" "BS_I_2_3:i_clk" "BS_I_3_3:i_clk" "BS_Q_1_3:i_clk" "BS_Q_2_3:i_clk" "BS_Q_3_3:i_clk" "DECIMATOR_I:i_clk" "DECIMATOR_Q:i_clk" "IQ_MIXER_0:i_clk" "LP_I_1_2:i_clk" "LP_I_2_2:i_clk" "LP_Q_1_2:i_clk" "LP_Q_2_2:i_clk" "i_clk" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BANDPASS_1_2:i_data_ready" "BANDPASS_2_2:o_data_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BANDPASS_1_2:i_data_valid" "i_data_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BANDPASS_1_2:i_res" "BANDPASS_2_2:i_res" "BS_I_1_3:i_res" "BS_I_2_3:i_res" "BS_I_3_3:i_res" "BS_Q_1_3:i_res" "BS_Q_2_3:i_res" "BS_Q_3_3:i_res" "DECIMATOR_I:i_res" "DECIMATOR_Q:i_res" "IQ_MIXER_0:i_res" "LP_I_1_2:i_res" "LP_I_2_2:i_res" "LP_Q_1_2:i_res" "LP_Q_2_2:i_res" "i_res" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BANDPASS_1_2:o_data_ready" "o_data_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BANDPASS_1_2:o_data_valid" "BANDPASS_2_2:i_data_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BANDPASS_2_2:i_data_ready" "IQ_MIXER_0:o_data_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BANDPASS_2_2:o_data_valid" "IQ_MIXER_0:i_data_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BS_I_1_3:i_data_ready" "BS_I_2_3:o_data_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BS_I_1_3:i_data_valid" "DECIMATOR_I:o_data_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BS_I_1_3:o_data_ready" "DECIMATOR_I:i_data_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BS_I_1_3:o_data_valid" "BS_I_2_3:i_data_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BS_I_2_3:i_data_ready" "BS_I_3_3:o_data_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BS_I_2_3:o_data_valid" "BS_I_3_3:i_data_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BS_I_3_3:i_data_ready" "LP_I_1_2:o_data_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BS_I_3_3:o_data_valid" "LP_I_1_2:i_data_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BS_Q_1_3:i_data_ready" "BS_Q_2_3:o_data_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BS_Q_1_3:i_data_valid" "DECIMATOR_Q:o_data_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BS_Q_1_3:o_data_ready" "DECIMATOR_Q:i_data_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BS_Q_1_3:o_data_valid" "BS_Q_2_3:i_data_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BS_Q_2_3:i_data_ready" "BS_Q_3_3:o_data_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BS_Q_2_3:o_data_valid" "BS_Q_3_3:i_data_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BS_Q_3_3:i_data_ready" "LP_Q_1_2:o_data_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BS_Q_3_3:o_data_valid" "LP_Q_1_2:i_data_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"DECIMATOR_I:i_data_valid" "MIXER_FLOW_SPLITTER:o_f1_data_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"DECIMATOR_I:o_data_ready" "MIXER_FLOW_SPLITTER:i_f1_data_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"DECIMATOR_Q:i_data_valid" "MIXER_FLOW_SPLITTER:o_f2_data_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"DECIMATOR_Q:o_data_ready" "MIXER_FLOW_SPLITTER:i_f2_data_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"IQ_MIXER_0:i_data_ready" "MIXER_FLOW_SPLITTER:o_mixer_data_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"IQ_MIXER_0:i_osc_data_valid" "i_osc_data_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"IQ_MIXER_0:o_data_valid" "MIXER_FLOW_SPLITTER:i_mixer_data_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LP_I_1_2:i_data_ready" "LP_I_2_2:o_data_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LP_I_1_2:o_data_valid" "LP_I_2_2:i_data_valid" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LP_Q_1_2:i_data_ready" "LP_Q_2_2:o_data_ready" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LP_Q_1_2:o_data_valid" "LP_Q_2_2:i_data_valid" }

# Add bus net connections
sd_connect_pins -sd_name ${sd_name} -pin_names {"BANDPASS_1_2:i_data" "i_data" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BANDPASS_1_2:o_data" "BANDPASS_2_2:i_data" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BANDPASS_2_2:o_data" "IQ_MIXER_0:i_data" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BS_I_1_3:i_data" "DECIMATOR_I:o_data" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BS_I_1_3:o_data" "BS_I_2_3:i_data" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BS_I_2_3:o_data" "BS_I_3_3:i_data" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BS_I_3_3:o_data" "LP_I_1_2:i_data" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BS_Q_1_3:i_data" "DECIMATOR_Q:o_data" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BS_Q_1_3:o_data" "BS_Q_2_3:i_data" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BS_Q_2_3:o_data" "BS_Q_3_3:i_data" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"BS_Q_3_3:o_data" "LP_Q_1_2:i_data" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"DECIMATOR_I:i_data" "IQ_MIXER_0:o_i_data" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"DECIMATOR_Q:i_data" "IQ_MIXER_0:o_q_data" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"IQ_MIXER_0:i_cos" "i_cos" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"IQ_MIXER_0:i_sin" "i_sin" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LP_I_1_2:o_data" "LP_I_2_2:i_data" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LP_I_2_2:o_data" "o_data_i" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LP_Q_1_2:o_data" "LP_Q_2_2:i_data" }
sd_connect_pins -sd_name ${sd_name} -pin_names {"LP_Q_2_2:o_data" "o_data_q" }


# Re-enable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 1
# Save the SmartDesign 
save_smartdesign -sd_name ${sd_name}
# Generate SmartDesign "LOCK_IN_CHAIN"
generate_component -component_name ${sd_name}
