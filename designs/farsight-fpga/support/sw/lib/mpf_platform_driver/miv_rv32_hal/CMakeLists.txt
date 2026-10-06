add_library(miv_rv32_hal_static STATIC 
                "${CMAKE_CURRENT_LIST_DIR}/miv_rv32_entry.S"
                "${CMAKE_CURRENT_LIST_DIR}/miv_rv32_hal.c"
                "${CMAKE_CURRENT_LIST_DIR}/miv_rv32_init.c"
                "${CMAKE_CURRENT_LIST_DIR}/miv_rv32_stubs.c"
                "${CMAKE_CURRENT_LIST_DIR}/miv_rv32_syscall.c"
                )

target_include_directories(miv_rv32_hal_static PUBLIC
    "${CMAKE_CURRENT_LIST_DIR}"
    "${CMAKE_SOURCE_DIR}/lib/mpf_platform_config/"
)

get_property(all_definitions DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY COMPILE_DEFINITIONS)

list(FIND all_definitions "ADD_SUPPORT_FREERTOS_V11" index)
if(index EQUAL -1)
    message(WARNING "ADD_SUPPORT_FREERTOS_V11 definition is missing.\nDesign will not be compatible with FreeRTOS v11\nTo enable FreeRTOS v11 support, add: add_definitions(-DADD_SUPPORT_FREERTOS_V11)")
else()
    message(STATUS "FreeRTOS v11 support is enabled")
endif()

target_link_libraries(
    miv_rv32_hal_static 
    mpf_fpga_config_interface 
)
