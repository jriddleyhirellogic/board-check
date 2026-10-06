#-------------------------------------------------------------------------------
# File             : CMakeLists.txt
#
# Description      : Top CMakeLists file for building farsight-avionics-sw 
#                    executable and testing components
#
# Author/Integrator: Saba Janamian 
#
# Initial Date     : 08/18/2025
#
#-------------------------------------------------------------------------------

cmake_minimum_required(VERSION 3.26)

# ------------------------------------------------------------------------------
# Project setup
# ------------------------------------------------------------------------------
project("farsight_avionics_sw" VERSION 0.1.0.0 LANGUAGES C CXX ASM)

set(CMAKE_C_STANDARD              11)
set(CMAKE_CXX_STANDARD            17)
set(CMAKE_C_STANDARD_REQUIRED     ON)
set(CMAKE_CXX_STANDARD_REQUIRED   ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Add these cmake utilities that are needed to build the project
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

include("no_in_src_builds")
include("code_format"     )
include("cpp_check"       )
include("build_config"    )
include("linker_config"   )

# ------------------------------------------------------------------------------
# Build options
# ------------------------------------------------------------------------------
option(ENABLE_TESTING "Enable building unit tests" OFF)
option(ENABLE_DOC_GEN "Enable building documentation using Doxygen" OFF)
option(ENABLE_ALL_COMPILER_WARN "Enable all compiler warnings" OFF)

# This is the name of the final executable.
set(EXECUTABLE_NAME "exec_farsight")
# ------------------------------------------------------------------------------
# Project build setup
# ------------------------------------------------------------------------------

if(NOT ENABLE_TESTING)
    # Include the following cmake utilities
    include("riscv_toolchain" )
    include("riscv_flags"     )

# ------------------------------------------------------------------------------
# Add project's subdirectories
# ------------------------------------------------------------------------------
    add_subdirectory(lib)
    add_subdirectory(src)
endif()
