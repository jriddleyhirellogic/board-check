/*******************************************************************************
 * Copyright 2022 Microchip FPGA Embedded Systems Solutions.
 *
 * SPDX-License-Identifier: MIT
 *
 * @file fpga_design_config.h
 * @author Microchip FPGA Embedded Systems Solutions
 * @brief FPGA Design configuration settings
 *
 */
/*========================================================================*//**
  @mainpage
    FIXME: Need to update the descriptions here
    File detailing how the fpga_design_config.h should be constructed
    for the SoftConsole project targeted for Mi-V processors.

    @section intro_sec Introduction
    The SoftConsole project targeted for Mi-V processors now have an improved
    folder structure. Detailed description of the folder structure is available
    at https://github.com/Mi-V-Soft-RISC-V/miv-rv32-documentation.

    The fpga_design_config.h must be stored as shown below
    <project-root>/boards/<board-name>/fpga_design_config.h

    Currently this file must be hand crafted when using the Mi-V Soft Processor.
    In future, all the design and soft IP configurations will be automatically
    generated from the Libero design description data.

    You can use this sample file as an example.
    Rename this file from sample_fpga_design_config.h to fpga_design_config.h
    and then customize it per your hardware design.

    @section Project configuration Instructions
    1. Change SYS_CLK_FREQ define to frequency of Mi-V Soft processor clock
    2  Add all the soft IP core BASE addresses
    3. Add the peripheral Core Interrupts to Mi-V Soft processor IRQ number
       mappings
    4. Define MSCC_STDIO_UART_BASE_ADDR if you want a CoreUARTapb mapped to
       STDIO

    **NOTE**
    In the legacy folder structures, the file hw_config.h as was used at the
    root of the project folder. This file is now depricated.

*//*=========================================================================*/

#ifndef __FPGA_DESIGN_CONFIG_H__
#define __FPGA_DESIGN_CONFIG_H__

/***************************************************************************/ /**
 * Soft-processor clock definition
 * This is the only clock brought over from the Mi-V Libero design.
 */
#ifndef SYS_CLK_FREQ
#define SYS_CLK_FREQ 50000000UL
#endif

//------------------------------------------------------------------------------
// Peripheral base addresses
// Format of define is:
// <corename>_<instance>_BASE_ADDR
//------------------------------------------------------------------------------

#define APB3_BASE_ADDR 0x70000000UL

#define TMTC_UART_BASE_ADDR                          0x70000000UL
#define SLVSEC_SPI_BASE_ADDR                         0x70001000UL
#define GPO_CAM_BASE_ADDR                            0x70003000UL
#define DMA_WRITE_DDR4_8GB_BASE_ADDR                 0x70004000UL
#define DMA_WRITE_DDR4_16GB_BASE_ADDR                0x70005000UL
#define DMA_READ_CTRL_DDR4_8GB_BASE_ADDR             0x70006000UL
#define DMA_READ_CTRL_DDR4_16GB_BASE_ADDR            0x70007000UL
#define ETH1_MAC_BASE_ADDR                           0x70008000UL
#define ETH1_STAT_BASE_ADDR                          0x70009000UL
#define ETH1_CTRL_BASE_ADDR                          0x7000A000UL
#define CAM_MUX_BASE_ADDR                            0x7000B000UL
#define IMAGE_METADATA_BASE_ADDR                     0x7000C000UL
#define STP_WD_BASE_ADDR                             0x7000D000UL
#define UDP_TX_BASE_ADDR                             0x7000E000UL
#define CAM_TRIG_BASE_ADDR                           0x7000F000UL
#define GPI_HK_STATUS_BASE_ADDR                      0x70010000UL
#define GPO_HK_PWR_BASE_ADDR                         0x70011000UL
#define DBG_GPIO_BASE_ADDR                           0x70012000UL
#define DMA_READ_DDR4_8GB_BASE_ADDR                  0x70013000UL
#define DMA_READ_DDR4_16GB_BASE_ADDR                 0x70014000UL
#define PPS_BASE_ADDR                                0x70015000UL
#define TIMER_BASE_ADDR                              0x70016000UL
#define HW_VERSION_BASE_ADDR                         0x70017000UL
#define FLASH_SPI_BASE_ADDR                          0x70018000UL
#define ETH_PCIE_MUX_BASE_ADDR                       0x70019000UL
#define JUNC_TEMP_BASE_ADDR                          0x7001A000UL
#define CAM_FAULT_DETECTOR_BASE_ADDR                 0x7001B000UL
#define FAV_GPIO_BASE_ADDR                           0x7001C000UL
#define PRI_STP_CTRL_BASE_ADDR                       0x70030000UL
#define PRI_STP_VREF_BASE_ADDR                       0x70031000UL
#define PRI_STP_OUT_BASE_ADDR                        0x70032000UL
#define SEC_STP_CTRL_BASE_ADDR                       0x70033000UL
#define SEC_STP_VREF_BASE_ADDR                       0x70034000UL
#define SEC_STP_OUT_BASE_ADDR                        0x70035000UL
#define LVDT_GAIN_BASE_ADDR                          0x70036000UL
#define LVDT_RO_SEC_Q_BASE_ADDR                      0x70037000UL
#define LVDT_RO_PRI_I_BASE_ADDR                      0x70038000UL
#define LVDT_RO_SEC_I_BASE_ADDR                      0x70039000UL
#define LVDT_RO_PRI_Q_BASE_ADDR                      0x7003A000UL
#define ASYNC_RST_DDR4_16GB_BASE_ADDR                0x7003B000UL
#define ASYNC_RST_DDR4_8GB_BASE_ADDR                 0x7003C000UL
#define TEMP_TLM_SPI_BASE_ADDR                       0x7003D000UL
#define PRI_STP_OVERFLOW_BASE_ADDR                   0x7003E000UL
#define SEC_STP_OVERFLOW_BASE_ADDR                   0x7003F000UL

/***************************************************************************/ /**
 * Peripheral Interrupts are mapped to the corresponding Mi-V Soft processor
 * interrupt in the Libero design.
 *
 * On the legacy RV32 cores, there can be up to 31 external interrupts (IRQ[30:0]
 * pins). The legacy RV32 Soft processor external interrupts are defined in the
   miv_rv32_plic.h
 *
 * These are of the form
 * typedef enum
{
    NoInterrupt_IRQn = 0,
    External_1_IRQn  = 1,
    External_2_IRQn  = 2,
    .
    .
    .
    External_31_IRQn = 31
} IRQn_Type;

 On the legacy RV32 processors, the PLIC identifies the interrupt and passes it
 on to the processor core. The interrupt 0 is not used. The pin IRQ[0] should
 map to External_1_IRQn likewise IRQ[30] should map to External_31_IRQn

e.g

#define TIMER0_IRQn                     External_30_IRQn
#define TIMER1_IRQn                     External_31_IRQn

 The MIV_RV32 soft processor has up to six optional system interrupts, MSYS_EI[n]
 in addition to one EXT_IRQ.
 The MIV_RV32 does not have an inbuilt PLIC and all the interrupts are directly
 delivered to the processor core, hence unlike legacy RV32 cores, no interrupt
 number mapping is necessary on MIV_RV32 core.
 */


#define TIMER0_IRQn External_30_IRQn
#define TIMER1_IRQn External_31_IRQn
//#define I2C_CAM2_IRQn                   External_30_IRQn

//#define I2C_CAM1_IRQn                   MSYS_EI1_IRQHandler
//#define HDMI_I2C_IRQn                   MSYS_EI0_IRQHandler


/****************************************************************************
 * Baud value to achieve a 115200 baud rate with system clock defined by
 * SYS_CLK_FREQ.
 * This value is calculated using the following equation:
 *      BAUD_VALUE = (CLOCK / (16 * BAUD_RATE)) - 1
 *****************************************************************************/
#define BAUD_VALUE_115200 ((SYS_CLK_FREQ / (16 * 115200)) - 1)

/******************************************************************************
 * Baud value to achieve a 57600 baud rate with system clock defined by
 * SYS_CLK_FREQ.
 * This value is calculated using the following equation:
 *      BAUD_VALUE = (CLOCK / (16 * BAUD_RATE)) - 1
 *****************************************************************************/
#define BAUD_VALUE_57600 ((SYS_CLK_FREQ / (16 * 57600)) - 1)

/***************************************************************************/ /**
 * Define MSCC_STDIO_THRU_CORE_UART_APB in the project settings if you want the
 * standard IOs to be redirected to a terminal via UART.
 */
#ifdef MSCC_STDIO_THRU_CORE_UART_APB
/*
 * A base address mapping for the STDIO printf/scanf mapping to CortUARTapb
 * must be provided if it is being used
 *
 * e.g. #define MSCC_STDIO_UART_BASE_ADDR COREUARTAPB1_BASE_ADDR
 */
#define MSCC_STDIO_UART_BASE_ADDR COREUARTAPB0_BASE_ADDR

#ifndef MSCC_STDIO_UART_BASE_ADDR
#error MSCC_STDIO_UART_BASE_ADDR not defined- e.g. #define MSCC_STDIO_UART_BASE_ADDR COREUARTAPB1_BASE_ADDR
#endif

#ifndef MSCC_STDIO_BAUD_VALUE
/*
 * The MSCC_STDIO_BAUD_VALUE define should be set in your project's settings to
 * specify the baud value used by the standard output CoreUARTapb instance for
 * generating the UART's baud rate if you want a different baud rate from the
 * default of 115200 baud
 */
#define MSCC_STDIO_BAUD_VALUE 115200
#endif /*MSCC_STDIO_BAUD_VALUE*/

#endif /* end of MSCC_STDIO_THRU_CORE_UART_APB */
/*******************************************************************************
 * End of user edit section
 */
#endif /* FPGA_DESIGN_CONFIG_H_ */
