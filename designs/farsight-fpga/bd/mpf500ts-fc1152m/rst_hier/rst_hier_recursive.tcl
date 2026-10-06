#This Tcl file sources other Tcl files to build the design(on which recursive export is run) in a bottom-up fashion

#Sourcing the Tcl files for creating individual components under the top level
source [file join [file dirname [info script]] components/CORERESET_PF_C0.tcl]
source [file join [file dirname [info script]] components/CORERESET_PF_C2.tcl]
source [file join [file dirname [info script]] components/CORERESET_PF_C3.tcl]
source [file join [file dirname [info script]] components/CORERESET_PF_SYS_CLK_50MHZ.tcl]
source [file join [file dirname [info script]] components/PF_INIT_MONITOR_C0.tcl]
source [file join [file dirname [info script]] components/CoreGPIO_C5.tcl]
source [file join [file dirname [info script]] components/rst_ddr4_hier.tcl]
source [file join [file dirname [info script]] components/rst_hier.tcl]
build_design_hierarchy
