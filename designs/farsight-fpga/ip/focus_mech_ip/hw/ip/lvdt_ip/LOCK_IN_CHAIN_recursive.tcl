#This Tcl file sources other Tcl files to build the design(on which recursive export is run) in a bottom-up fashion

#Sourcing the Tcl file in which all the HDL source files used in the design are imported or linked
build_design_hierarchy

#Sourcing the Tcl files in which HDL+ core definitions are created for HDL modules
source [file join [file dirname [info script]] components/DECIMATOR.tcl] 
source [file join [file dirname [info script]] components/IIR_BIQUAD.tcl] 
source [file join [file dirname [info script]] components/IQ_MIXER.tcl] 
source [file join [file dirname [info script]] components/MIXER_READY_VALID_HANDLER.tcl] 
build_design_hierarchy

#Sourcing the Tcl files for creating individual components under the top level
source [file join [file dirname [info script]] components/LOCK_IN_CHAIN.tcl] 
build_design_hierarchy

