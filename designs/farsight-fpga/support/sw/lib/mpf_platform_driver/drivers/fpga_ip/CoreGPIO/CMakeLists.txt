add_library(CoreGPIO_static STATIC 
                "${CMAKE_CURRENT_LIST_DIR}/core_gpio.c")

target_include_directories(CoreGPIO_static PUBLIC
    "${CMAKE_CURRENT_LIST_DIR}/"
    "${CMAKE_SOURCE_DIR}/lib/mpf_platform_driver/"
)

target_link_libraries(
    CoreGPIO_static
    mpf_hal_static 
)
