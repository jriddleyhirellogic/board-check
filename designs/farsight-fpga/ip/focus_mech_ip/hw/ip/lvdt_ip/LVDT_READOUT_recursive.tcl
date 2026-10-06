#This Tcl file sources other Tcl files to build the design(on which recursive export is run) in a bottom-up fashion

#Sourcing the Tcl file in which all the HDL source files used in the design are imported or linked
source [file join [file dirname [info script]] LOCK_IN_CHAIN_recursive.tcl]
build_design_hierarchy

#Sourcing the Tcl files in which HDL+ core definitions are created for HDL modules
source [file join [file dirname [info script]] components/ADC128S102_DRIVER.tcl] 
source [file join [file dirname [info script]] components/DELTA_SIGMA.tcl] 
source [file join [file dirname [info script]] components/RST_HANDLER.tcl] 
source [file join [file dirname [info script]] components/SINE_SCALER.tcl] 
build_design_hierarchy

#Sourcing the Tcl files for creating individual components under the top level
source [file join [file dirname [info script]] components/FOCUS_MECH_CoreGPIO_C0.tcl] 
source [file join [file dirname [info script]] components/SIN_COS_GEN.tcl] 
source [file join [file dirname [info script]] components/LVDT_READOUT.tcl] 
build_design_hierarchy



