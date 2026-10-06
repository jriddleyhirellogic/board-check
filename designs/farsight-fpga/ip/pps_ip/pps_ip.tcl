#Sourcing the Tcl files for creating individual components under the top level
source [file join [file dirname [info script]] components/pps.tcl]
source [file join [file dirname [info script]] components/pps_generator.tcl]
source [file join [file dirname [info script]] components/pps_mux.tcl]
build_design_hierarchy

