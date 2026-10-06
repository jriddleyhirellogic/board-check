#-------------------------------------------------------------------------------
# File             : CMakeLists.txt
#
# Description      : Create FPGA configuration header library
#
# Author/Integrator: Saba Janamian 
#
# Initial Date     : 12/25/2024
#
#-------------------------------------------------------------------------------

add_library(mpf_fpga_config_interface INTERFACE
  "${CMAKE_CURRENT_LIST_DIR}/fpga_design_config/fpga_design_config.h"
)
