add_library(Core16550_static STATIC 
                "${CMAKE_CURRENT_LIST_DIR}/hal_uart16550.c")

target_include_directories(Core16550_static PUBLIC
    "${CMAKE_CURRENT_LIST_DIR}/"
    "${CMAKE_SOURCE_DIR}/lib/mpf_platform_driver/"
)

target_link_libraries(
    Core16550_static
    mpf_hal_static 
)
