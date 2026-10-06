#Sourcing the Tcl files for creating individual components under the top level
source [file join [file dirname [info script]] components/CoreAHBLite_C0.tcl]
source [file join [file dirname [info script]] components/COREAHBTOAPB3_C0.tcl]
source [file join [file dirname [info script]] components/CoreAPB3_C0.tcl]
source [file join [file dirname [info script]] components/CoreAPB3_C1.tcl]
source [file join [file dirname [info script]] components/CoreAPB3_C2.tcl]
source [file join [file dirname [info script]] components/COREAXI4INTERCONNECT_C0.tcl]
source [file join [file dirname [info script]] components/COREAXITOAHBL_C0.tcl]
source [file join [file dirname [info script]] components/interconnect_hier.tcl]
build_design_hierarchy
