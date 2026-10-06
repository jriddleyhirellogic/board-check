add_library(CoreSPI_static STATIC 
                "${CMAKE_CURRENT_LIST_DIR}/core_spi.c")

target_include_directories(CoreSPI_static PUBLIC
    "${CMAKE_CURRENT_LIST_DIR}/"
    "${CMAKE_SOURCE_DIR}/lib/mpf_platform_driver/"
)

target_link_libraries(
    CoreSPI_static
    mpf_hal_static 
)