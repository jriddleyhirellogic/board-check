   
set(LD_FILE "${CMAKE_SOURCE_DIR}/lib/linker/miv-rv32-ram.ld")
message(STATUS "Linker file: " ${LD_FILE})
set(LINKER_SCRIPT_FILE ${LD_FILE})
set(LOAD_MEMORY_ADDRESS "*-0x80000000")
