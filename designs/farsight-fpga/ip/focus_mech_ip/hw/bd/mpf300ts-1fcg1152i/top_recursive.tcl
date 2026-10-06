#This Tcl file sources other Tcl files to build the design(on which recursive export is run) in a bottom-up fashion

#Sourcing the Tcl files for creating individual components under the top level
source [file join [file dirname [info script]] components/CORE16550_C0.tcl]
source [file join [file dirname [info script]] components/CoreAPB3_C1.tcl]
source [file join [file dirname [info script]] components/FOCUS_MECH_CoreGPIO_C1.tcl]
source [file join [file dirname [info script]] components/FOCUS_MECH_CoreGPIO_C5.tcl]
source [file join [file dirname [info script]] components/COREJTAGDEBUG_C0.tcl]
source [file join [file dirname [info script]] components/CORERESET_PF_C0.tcl]
source [file join [file dirname [info script]] components/MIV_RV32_C0.tcl]
source [file join [file dirname [info script]] components/PF_CCC_C0.tcl]
source [file join [file dirname [info script]] components/PF_INIT_MONITOR_C0.tcl]
source [file join [file dirname [info script]] components/PF_SRAM_AHBL_AXI_C0.tcl]
source [file join [file dirname [info script]] components/top.tcl]
build_design_hierarchy

