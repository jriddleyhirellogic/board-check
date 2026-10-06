#This Tcl file sources other Tcl files to build the design(on which recursive export is run) in a bottom-up fashion

#Sourcing the Tcl files for creating individual components under the top level
source [file join [file dirname [info script]] components/PCIe_TX_PLL.tcl]
source [file join [file dirname [info script]] components/PF_XCVR_REF_CLK_C1.tcl]
source [file join [file dirname [info script]] components/PF_PCIE_C0.tcl]
source [file join [file dirname [info script]] components/CLK_DIV2.tcl]
source [file join [file dirname [info script]] components/NGMUX.tcl]
source [file join [file dirname [info script]] components/AHBtoAPB.tcl]
source [file join [file dirname [info script]] components/AXItoAHBL.tcl]
source [file join [file dirname [info script]] components/Core_AHBL.tcl]
source [file join [file dirname [info script]] components/Core_APB.tcl]
source [file join [file dirname [info script]] components/COREAXI4INTERCONNECT_C1.tcl]
source [file join [file dirname [info script]] components/pcie_hier.tcl]
build_design_hierarchy
