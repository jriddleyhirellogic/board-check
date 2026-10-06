#-------------------------------------------------------------------------------
# File             : riscv-toolchain.cmake
#
# Description      : RISC-V toolchain cmake file to populate required build tools
#
# Author/Integrator: Saba Janamian 
#
# Initial Date     : 11/15/2024
#
#-------------------------------------------------------------------------------

# Look for GCC in path
FIND_FILE(RISCV_COMPILER_PATH "riscv64-unknown-elf-gcc" PATHS ENV INCLUDE)

if (EXISTS ${RISCV_COMPILER_PATH})
    set(RISCV_GCC_COMPILER "${RISCV_COMPILER_PATH}")
else()
    # Stop early if RISC-V GCC was not found
    message(FATAL_ERROR "RISC-V GCC not found.")
endif()

message(STATUS "RISC-V GCC found: ${RISCV_GCC_COMPILER}")

get_filename_component(RISCV_TOOLCHAIN_BIN_PATH "${RISCV_GCC_COMPILER}" DIRECTORY)
get_filename_component(RISCV_TOOLCHAIN_BIN_GCC "${RISCV_GCC_COMPILER}" NAME_WE)
get_filename_component(RISCV_TOOLCHAIN_BIN_EXT "${RISCV_GCC_COMPILER}" EXT)

# Extract the GCC file prefix to be used for other required tools
STRING(REGEX REPLACE "-gcc" "" CROSS_COMPILER_PREFIX "${RISCV_TOOLCHAIN_BIN_GCC}")

message(STATUS "RISC-V RISCV_TOOLCHAIN_BIN_PATH: ${RISCV_TOOLCHAIN_BIN_PATH}")
message(STATUS "RISC-V CROSS_COMPILER_PREFIX:    ${CROSS_COMPILER_PREFIX}")

# ------------------------------------------------------------------------------
# Setting up the RISC-V build toolchain
# ------------------------------------------------------------------------------
set(CMAKE_C_COMPILER   "${RISCV_TOOLCHAIN_BIN_PATH}/${CROSS_COMPILER_PREFIX}-gcc")
set(CMAKE_CXX_COMPILER "${RISCV_TOOLCHAIN_BIN_PATH}/${CROSS_COMPILER_PREFIX}-g++")
set(CMAKE_ASM_COMPILER "${RISCV_TOOLCHAIN_BIN_PATH}/${CROSS_COMPILER_PREFIX}-gcc")
set(CMAKE_AR           "${RISCV_TOOLCHAIN_BIN_PATH}/${CROSS_COMPILER_PREFIX}-ar")
set(CMAKE_LINKER       "${RISCV_TOOLCHAIN_BIN_PATH}/${CROSS_COMPILER_PREFIX}-ld")
set(CMAKE_AR           "${RISCV_TOOLCHAIN_BIN_PATH}/${CROSS_COMPILER_PREFIX}-ar")
set(CMAKE_RANLIB       "${RISCV_TOOLCHAIN_BIN_PATH}/${CROSS_COMPILER_PREFIX}-ranlib")
set(CMAKE_STRIP        "${RISCV_TOOLCHAIN_BIN_PATH}/${CROSS_COMPILER_PREFIX}-strip")  
set(CMAKE_OBJCOPY      "${RISCV_TOOLCHAIN_BIN_PATH}/${CROSS_COMPILER_PREFIX}-objcopy"
    CACHE FILEPATH "The toolchain objcopy command" FORCE)
set(CMAKE_OBJDUMP      "${RISCV_TOOLCHAIN_BIN_PATH}/${CROSS_COMPILER_PREFIX}-objdump"
    CACHE FILEPATH "The toolchain objdump command" FORCE)
set(ELF_SIZE_TOOL "${RISCV_TOOLCHAIN_BIN_PATH}/${CROSS_COMPILER_PREFIX}-size")

set(COMPILER_LIST
    ${CMAKE_C_COMPILER}
    ${CMAKE_CXX_COMPILER}
    ${CMAKE_ASM_COMPILER}
    ${CMAKE_AR}
    ${CMAKE_OBJCOPY}
    ${CMAKE_OBJDUMP}     
)

set(COMPILER_NAMES
    "C Compiler"
    "C++ Compiler"
    "ASM Compiler"
    "AR Tool"
    "Objcopy Tool"
    "Objdump Tool"
)

# Check if all required tools exist
foreach(comp_addr comp_name IN ZIP_LISTS COMPILER_LIST COMPILER_NAMES)
    if(NOT EXISTS "${comp_addr}")
        message(FATAL_ERROR "Could not find ${comp_name} in provided address '${comp_addr}'")
    endif()
endforeach()

message(STATUS "RISC-V CMAKE_C_COMPILER:   ${CMAKE_C_COMPILER}")
message(STATUS "RISC-V CMAKE_CXX_COMPILER: ${CMAKE_CXX_COMPILER}")
message(STATUS "RISC-V CMAKE_ASM_COMPILER: ${CMAKE_ASM_COMPILER}")
message(STATUS "RISC-V CMAKE_AR:           ${CMAKE_AR}")
message(STATUS "RISC-V CMAKE_OBJCOPY:      ${CMAKE_OBJCOPY}")
message(STATUS "RISC-V CMAKE_OBJDUMP:      ${CMAKE_OBJDUMP}")

# ------------------------------------------------------------------------------
# Setting up system name, processor, and executable suffix
# ------------------------------------------------------------------------------
set(CMAKE_SYSTEM_NAME       "Generic")
# RV32I is a load-store ISA with 32, 32-bit general-purpose integer registers.
set(CMAKE_SYSTEM_PROCESSOR  "rv32i")
set(CMAKE_EXECUTABLE_SUFFIX ".elf")

message(STATUS "RISC-V CMAKE_SYSTEM_NAME:       ${CMAKE_SYSTEM_NAME}")
message(STATUS "RISC-V CMAKE_EXECUTABLE_SUFFIX: ${CMAKE_EXECUTABLE_SUFFIX}")
message(STATUS "RISC-V CMAKE_SYSTEM_PROCESSOR:  ${CMAKE_SYSTEM_PROCESSOR}")

#-------------------------------------------------------------------------------
# Footer
#
# Change log:
#   [version: 0.1, date: 11/15/2024, author: Saba Janamian]: 
#   Initial implementation of riscv-toolchain.  
# 
#
#-------------------------------------------------------------------------------
