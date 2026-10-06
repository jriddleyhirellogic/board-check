#-------------------------------------------------------------------------------
# File             : CMakeLists.txt
#
# Description      : PolarFire FPGA Platform Driver Library
#
# Author/Integrator: Saba Janamian 
#
# Initial Date     : 12/30/2024
#
#-------------------------------------------------------------------------------

add_subdirectory("${CMAKE_CURRENT_LIST_DIR}/miv_rv32_hal")
add_subdirectory("${CMAKE_CURRENT_LIST_DIR}/hal")
add_subdirectory("${CMAKE_CURRENT_LIST_DIR}/drivers")
