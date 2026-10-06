add_executable(
    ${EXECUTABLE_NAME}
    "main.c"
    "util.c"
    "eth.c"
)

target_include_directories(${EXECUTABLE_NAME} PRIVATE
    "${CMAKE_CURRENT_LIST_DIR}/include"
    "${CMAKE_SOURCE_DIR}/lib/mpf_platform_config/fpga_design_config"
    "${CMAKE_SOURCE_DIR}/lib/mpf_platform_driver/drivers/fpga_ip/Core16550"
    "${CMAKE_SOURCE_DIR}/lib/mpf_platform_driver/drivers/fpga_ip/CoreSPI"
    "${CMAKE_SOURCE_DIR}/lib/mpf_platform_driver/drivers/fpga_ip/CoreGPIO"
)

target_link_libraries(
    ${EXECUTABLE_NAME}
    mpf_hal_static
    mpf_fpga_config_interface
    miv_rv32_hal_static
    CoreUARTapb_static
    CoreSPI_static
    CoreGPIO_static
    Core16550_static
)

Format        (${EXECUTABLE_NAME} "${CMAKE_CURRENT_LIST_DIR}/")
AddCppCheck   (${EXECUTABLE_NAME})

# ------------------------------------------------------------------------------
# Finalize Process and package the build artifacts
# ------------------------------------------------------------------------------
include("riscv_postbuild")