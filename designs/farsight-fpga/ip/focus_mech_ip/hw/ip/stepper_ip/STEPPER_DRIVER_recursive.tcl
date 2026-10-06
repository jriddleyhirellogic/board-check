#This Tcl file sources other Tcl files to build the design(on which recursive export is run) in a bottom-up fashion

#Sourcing the Tcl file in which all the HDL source files used in the design are imported or linked
source [file join [file dirname [info script]] components/STEP_DIR.tcl]
build_design_hierarchy

#Sourcing the Tcl files in which HDL+ core definitions are created for HDL modules
source [file join [file dirname [info script]] components/FOCUS_MECH_CoreGPIO_C2.tcl] 
source [file join [file dirname [info script]] components/FOCUS_MECH_CoreGPIO_C3.tcl] 
source [file join [file dirname [info script]] components/FOCUS_MECH_CoreGPIO_C4.tcl] 
source [file join [file dirname [info script]] components/corepwm_C0.tcl] 
build_design_hierarchy

#Sourcing the Tcl files for creating individual components under the top level
source [file join [file dirname [info script]] components/STEPPER_DRIVER.tcl] 
build_design_hierarchy