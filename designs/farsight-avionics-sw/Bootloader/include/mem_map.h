#ifndef MEM_MAP_H
#define MEM_MAP_H

/*
cam_rx_inst:img_metadata_apb                                         0x7003_B000   4KB    0x7003_BFFF
flash_qspi_hier_inst:flash_qspi_ahb                                  0x7004_0000   64KB   0x7004_FFFF
 */
#define TMTC_UART_BASE_ADDR                          0x70000000
#define SLVSEC_SPI_BASE_ADDR                         0x70001000
#define GPI_CAM_BASE_ADDR                            0x70002000
#define GPO_CAM_BASE_ADDR                            0x70003000
#define DMA_WRITE_DDR4_8GB_BASE_ADDR                 0x70004000
#define DMA_WRITE_DDR4_16GB_BASE_ADDR                0x70005000
#define UDP_DMACTRL_DDR4_8GB_BASE_ADDR               0x70006000
#define UDP_DMACTRL_DDR4_16GB_BASE_ADDR              0x70007000
#define ETH1_MAC_BASE_ADDR                           0x70008000
#define ETH1_STAT_BASE_ADDR                          0x70009000
#define ETH1_CTRL_BASE_ADDR                          0x7000A000
#define CAM_MUX_CTRL_BASE_ADDR                       0x7000B000
#define IMG_METADATA_BASE_ADDR                       0x7000C000
#define STEPPER_WATCHDOG_BASE_ADDR                   0x7000D000
#define UDP_TX_BASE_ADDR                             0x7000E000
#define CAM_TRIG_BASE_ADDR                           0x7000F000
#define GPI_HK_STATUS_BASE_ADDR                      0x70010000
#define GPO_HK_PWR_BASE_ADDR                         0x70011000
#define DBG_GPIO_BASE_ADDR                           0x70012000
#define DMA_READ_DDR4_8GB_BASE_ADDR                  0x70013000
#define DMA_READ_DDR4_16GB_BASE_ADDR                 0x70014000
#define PPS_BASE_ADDR                                0x70015000
#define SERIAL_COMM_TIMER_BASE                       0x70016000
#define VERSION_BASE_ADDR                            0x70017000
#define FLASH_NORMAL_SPI_BASE                        0x70018000
#define PRI_STP_CTRL_BASE_ADDR                       0x70030000
#define PRI_STP_VREF_BASE_ADDR                       0x70031000
#define PRI_STP_OUT_BASE_ADDR                        0x70032000
#define SEC_STP_CTRL_BASE_ADDR                       0x70033000
#define SEC_STP_VREF_BASE_ADDR                       0x70034000
#define SEC_STP_OUT_BASE_ADDR                        0x70035000
#define LVDT_GAIN_BASE_ADDR                          0x70036000
#define LVDT_RO_SEC_Q_BASE_ADDR                      0x70037000
#define LVDT_RO_PRI_I_BASE_ADDR                      0x70038000
#define LVDT_RO_SEC_I_BASE_ADDR                      0x70039000
#define LVDT_RO_PRI_Q_BASE_ADDR                      0x7003A000
#define DDR4_16GB_ASYNC_RST_BASE_ADDR                0x7003B000
#define DDR4_8GB_ASYNC_RST_BASE_ADDR                 0x7003C000
#define TLM_SPI_BASE_ADDR                            0x7003D000
#define PRI_STP_APB_STEPPER_OVERFLOW                 0x7003E000
#define SEC_STP_APB_STEPPER_OVERFLOW                 0x7003F000
#define FLASH_QSPI_BASE_ADDR                         0x70040000

#endif




































