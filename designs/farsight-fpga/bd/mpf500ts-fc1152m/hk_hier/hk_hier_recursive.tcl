#This Tcl file sources other Tcl files to build the design(on which recursive export is run) in a bottom-up fashion

#Sourcing the Tcl files for creating individual components under the top level
source [file join [file dirname [info script]] components/CoreGPIO_C1.tcl]
source [file join [file dirname [info script]] components/CoreGPIO_C3.tcl]
source [file join [file dirname [info script]] components/hk_hier.tcl]
build_design_hierarchy

