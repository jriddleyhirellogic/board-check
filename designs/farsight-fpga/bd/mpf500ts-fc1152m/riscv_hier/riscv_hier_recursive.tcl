#This Tcl file sources other Tcl files to build the design(on which recursive export is run) in a bottom-up fashion

#Sourcing the Tcl files for creating individual components under the top level
source [file join [file dirname [info script]] components/COREJTAGDEBUG_C0.tcl]
source [file join [file dirname [info script]] components/MIV_RV32_C0.tcl]
source [file join [file dirname [info script]] components/PF_SRAM_AHBL_AXI_C0.tcl]
source [file join [file dirname [info script]] components/CoreTimer_C0.tcl]
source [file join [file dirname [info script]] components/riscv_hier.tcl]
build_design_hierarchy

