#This Tcl file sources other Tcl files to build the design(on which recursive export is run) in a bottom-up fashion

#Sourcing the Tcl files for creating individual components under the top level
source [file join [file dirname [info script]] components/CoreGPIO_ETH1_STAT.tcl]
source [file join [file dirname [info script]] components/CoreGPIO_ETH1_CTRL.tcl]
source [file join [file dirname [info script]] components/CORETSE_ETH1.tcl]
source [file join [file dirname [info script]] components/PF_RGMII_TO_GMII_ETH1.tcl]
source [file join [file dirname [info script]] components/eth1_hier.tcl]
build_design_hierarchy
