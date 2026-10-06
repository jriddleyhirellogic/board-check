#This Tcl file sources other Tcl files to build the design(on which recursive export is run) in a bottom-up fashion

#Sourcing the Tcl files for creating individual components under the top level
source [file join [file dirname [info script]] components/CORE16550_C0.tcl]
source [file join [file dirname [info script]] components/PF_CCC_C1.tcl]
source [file join [file dirname [info script]] components/PF_CCC_SYS_CLK_50MHZ.tcl]
source [file join [file dirname [info script]] components/PF_OSC_C0.tcl]
source [file join [file dirname [info script]] components/PF_XCVR_REF_CLK_C0.tcl]
source [file join [file dirname [info script]] components/CoreGPIO_C6.tcl]
source [file join [file dirname [info script]] components/CoreGPIO_C8.tcl]
source [file join [file dirname [info script]] components/CORESPI_C1.tcl]
source [file join [file dirname [info script]] components/CORESPI_C2.tcl]
source [file join [file dirname [info script]] components/top.tcl]
build_design_hierarchy

