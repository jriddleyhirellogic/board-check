#This Tcl file sources other Tcl files to build the design(on which recursive export is run) in a bottom-up fashion

#Sourcing the Tcl files for creating individual components under the top level
source [file join [file dirname [info script]] components/CoreGPIO_C0.tcl]
source [file join [file dirname [info script]] components/CORESPI_C0.tcl]
source [file join [file dirname [info script]] components/PF_CCC_C2.tcl]
source [file join [file dirname [info script]] components/PF_CLK_DIV_C0.tcl]
source [file join [file dirname [info script]] components/PF_XCVR_ERM_C0.tcl]
source [file join [file dirname [info script]] components/PF_XCVR_ERM_C1.tcl]
source [file join [file dirname [info script]] components/SLVS_EC_RX_C0.tcl]
source [file join [file dirname [info script]] components/cam_rx_hier.tcl]
build_design_hierarchy

