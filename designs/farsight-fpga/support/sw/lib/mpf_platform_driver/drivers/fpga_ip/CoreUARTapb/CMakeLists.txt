add_library(CoreUARTapb_static STATIC 
                "${CMAKE_CURRENT_LIST_DIR}/core_uart_apb.c")

target_include_directories(CoreUARTapb_static PUBLIC
    "${CMAKE_CURRENT_LIST_DIR}/"
    "${CMAKE_SOURCE_DIR}/lib/mpf_platform_driver/"
)

target_link_libraries(
    CoreUARTapb_static
    mpf_hal_static 
)
