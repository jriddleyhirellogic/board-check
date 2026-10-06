add_library(mpf_hal_static STATIC 
                "${CMAKE_CURRENT_LIST_DIR}/hal_irq.c"
                "${CMAKE_CURRENT_LIST_DIR}/hw_reg_access.S"
                )

target_include_directories(mpf_hal_static PUBLIC
    "${CMAKE_CURRENT_LIST_DIR}/"
    "${CMAKE_SOURCE_DIR}/lib/mpf_platform_config/"
    "${CMAKE_SOURCE_DIR}/lib/mpf_platform_driver/"
)

target_link_libraries(
    mpf_hal_static 
    mpf_fpga_config_interface 
    miv_rv32_hal_static
)
