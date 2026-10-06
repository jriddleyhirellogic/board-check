#-------------------------------------------------------------------------------
# File             : riscv_flags.cmake
#
# Description      : Define GCC flags as variables with descriptions
#
# Author/Integrator: Saba Janamian 
#
# Initial Date     : 12/25/2024
#
#-------------------------------------------------------------------------------

# IMPORTANT: 
#       Care must be taken when modifying these flags as they are tightly 
#       coupled with PolarFire RISCV-MIV32 IP configuration in the FPGA design.

# ------------------------------------------------------------------------------
# Compiler Architecture flags
# ------------------------------------------------------------------------------
set(ARCH_FLAGS              "-march=rv32im" 
    CACHE STRING "Target architecture: RISC-V 32-bit with \
    base integer and multiplication extensions.")

set(ABI_FLAGS               "-mabi=ilp32" 
    CACHE STRING "Target ABI: Integer, long, and pointer are all 32-bit.")

set(SMALL_DATA_LIMIT_FLAGS  "-msmall-data-limit=8" 
    CACHE STRING "Set small data section limit to 8 bytes.")

set(NO_SAVE_RESTORE_FLAGS   "-mno-save-restore" 
    CACHE STRING "Disable hardware save/restore instructions.")

set(MESSAGE_LENGTH_FLAGS    "-fmessage-length=0" 
    CACHE STRING "Do not wrap compiler messages in the terminal.")

set(SIGNED_CHAR_FLAGS       "-fsigned-char" 
    CACHE STRING "Treat 'char' type as signed.")

set(FUNCTION_SECTIONS_FLAGS "-ffunction-sections" 
    CACHE STRING "Place each function in its own section.")

set(DATA_SECTIONS_FLAGS     "-fdata-sections" 
    CACHE STRING "Place each data variable in its own section.")

# ------------------------------------------------------------------------------
# Assembler flags
# ------------------------------------------------------------------------------
set(ASSEMBLER_WITH_CPP_FLAGS "-x assembler-with-cpp" 
    CACHE STRING "Enable preprocessing of assembly files with the C preprocessor.")

# ------------------------------------------------------------------------------
# Linker flags
# ------------------------------------------------------------------------------
set(LINKER_SCRIPT_FLAGS      "-T ${LINKER_SCRIPT_FILE}" 
    CACHE STRING "Specify the linker script.")

set(NO_STARTFILES_FLAGS      "-nostartfiles" 
    CACHE STRING "Disable standard startup files.")

set(GC_SECTIONS_FLAGS        "-Xlinker --gc-sections" 
    CACHE STRING "Enable garbage collection of unused sections.")

set(MAP_FILE_FLAGS "-Wl,-Map=${EXECUTABLE_NAME}.map" 
    CACHE STRING "Generate a map file for the executable.")

# ------------------------------------------------------------------------------
# Compiler Debuging and optimization flags
# ------------------------------------------------------------------------------
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(OPTIMIZATION_FLAGS      "-O0" 
        CACHE STRING "Optimization level: No optimization for easier debugging.")
    set(DEBUG_FLAGS             "-g3" 
        CACHE STRING "Generate debug information at the highest level.")

elseif(CMAKE_BUILD_TYPE STREQUAL "Release")

    set(OPTIMIZATION_FLAGS      "-O2" 
        CACHE STRING "Optimization level: Optimize for speed.")
    
    set(DEBUG_FLAGS             "-DNDEBUG" 
        CACHE STRING "Disable debug information.")

endif()
# ------------------------------------------------------------------------------
# Apply flags
# ------------------------------------------------------------------------------
set(C_FLAGS "\
    ${ARCH_FLAGS} \
    ${ABI_FLAGS} \
    ${SMALL_DATA_LIMIT_FLAGS} \
    ${NO_SAVE_RESTORE_FLAGS} \
    ${OPTIMIZATION_FLAGS} \
    ${MESSAGE_LENGTH_FLAGS} \
    ${SIGNED_CHAR_FLAGS} \
    ${FUNCTION_SECTIONS_FLAGS} \
    ${DATA_SECTIONS_FLAGS} \
    ${DEBUG_FLAGS}"
 CACHE STRING
    "C flags: Specify compiler flags"
)

set(CPP_FLAGS "\
    ${ARCH_FLAGS} \
    ${ABI_FLAGS} \
    ${SMALL_DATA_LIMIT_FLAGS} \
    ${NO_SAVE_RESTORE_FLAGS} \
    ${OPTIMIZATION_FLAGS} \
    ${MESSAGE_LENGTH_FLAGS} \
    ${SIGNED_CHAR_FLAGS} \
    ${FUNCTION_SECTIONS_FLAGS} \
    ${DATA_SECTIONS_FLAGS} \
    ${DEBUG_FLAGS}"
 CACHE STRING
    "CPP flags: Specify compiler flags"
)

set(ASM_FLAGS "\
    ${ASSEMBLER_WITH_CPP_FLAGS} \
    ${ARCH_FLAGS} \
    ${ABI_FLAGS} \
    ${SMALL_DATA_LIMIT_FLAGS} \
    ${NO_SAVE_RESTORE_FLAGS} \
    ${DEBUG_FLAGS}"
    CACHE STRING
    "ASM flags: Enable C preprocessor, specify architecture, ABI, and debug level."
)

# Linker script file
set(LINKER_SCRIPT "${LINKER_SCRIPT_FILE}" 
    CACHE FILEPATH "Path to the linker script.")

# Linker script flags
set(LINKER_FLAGS "\
    ${LINKER_SCRIPT_FLAGS} \
    ${NO_STARTFILES_FLAGS} \
    ${GC_SECTIONS_FLAGS} \
    ${MAP_FILE_FLAGS}"
    CACHE STRING
    "Linker flags: Specify linker script, disable standard startup files, and \
    garbage-collect unused sections."
)


# Apply the flags. Note: Need to make sure flags are appended to the existing flags.
set(CMAKE_C_FLAGS          "${CMAKE_C_FLAGS} ${C_FLAGS}")
set(CMAKE_CXX_FLAGS        "${CMAKE_CXX_FLAGS} ${CPP_FLAGS}")
set(CMAKE_ASM_FLAGS        "${CMAKE_ASM_FLAGS} ${ASM_FLAGS}")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${LINKER_FLAGS}")


#-------------------------------------------------------------------------------
# Footer
#
# Change log:
#   [version: 0.1, date: 12/25/2024, author: Saba Janamian]: 
#   Initial implementation based on Microchip Softconsole configuration.
# 
#
#-------------------------------------------------------------------------------