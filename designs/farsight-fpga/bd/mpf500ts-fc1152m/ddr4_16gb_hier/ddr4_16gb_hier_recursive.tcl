#This Tcl file sources other Tcl files to build the design(on which recursive export is run) in a bottom-up fashion

#Sourcing the Tcl files for creating individual components under the top level
source [file join [file dirname [info script]] components/COREDDR_LITEAXI_C0.tcl]
source [file join [file dirname [info script]] components/PF_DDR4_C0.tcl]
source [file join [file dirname [info script]] components/DDR4_16GB_AXI4_ARBITER_PF.tcl]
source [file join [file dirname [info script]] components/dma_read_ddr4_16gb_hier.tcl]
source [file join [file dirname [info script]] components/dma_write_ddr4_16gb_hier.tcl]
source [file join [file dirname [info script]] components/ddr4_16gb_hier.tcl]
source [file join [file dirname [info script]] components/ddr4_16gb_group_hier.tcl]
build_design_hierarchy

