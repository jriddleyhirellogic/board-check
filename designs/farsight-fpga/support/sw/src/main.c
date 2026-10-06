/*******************************************************************************
 * @file      main.c
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      09/17/2025
 *
 * @brief     Entry point of the Farsight Avioncis Power Test application
 *
 * @section changelog
 * - 09/17/2025: Saba Janamian - Initial implementation
 *
*******************************************************************************/

#include "main.h"
#include <stdint.h>
#include "hal.h"
#include "hal_assert.h"

// Total number of lines per frame
#define LINES_PER_FRAME 4581

// 106 beats of 512
// 106 * 512 = 54272 bits = 6784 bytes
#define HORIZ_WIDTH_BYTE 6784

// ceil(4512*12)/256 for 8GB DDR4
#define HORIZ_WIDTH_BEAT_8GB 212

// ceil(4512*12)/512 for 16GB DDR4
#define HORIZ_WIDTH_BEAT_16GB 106

#define ETH1_DST_PORT 0x8931
#define ETH1_SRC_PORT 0x04D2
#define ETH1_DST_IP IP_TO_U32(10, 101, 15, 195)
#define ETH1_SRC_IP IP_TO_U32(10, 101, 15, 192)
#define ETH1_DST_MAC_MSB 0x88a4
#define ETH1_DST_MAC_LSB 0xc25649ed
#define ETH1_SRC_MAC_MSB 0x0004
#define ETH1_SRC_MAC_LSB 0xA3123456

#define CYCLES_PER_USEC 50u
#define XTRIG_LOW_TIME_CYCLES 50000
#define FRAME_CAPTURE_TIME_USEC 20000
#define DDR4_8GB_FRAME_CAPTURE_AMOUNT 256
#define DDR4_16GB_FRAME_CAPTURE_AMOUNT 512
#define XTRIG_SRC_SEL_MANUAL 0
#define XTRIG_SRC_SEL_PPS 1
#define XTRIG_SRC_SEL_LVDS 2
#define PPS_SCHEDULER_TIME_SEC DATETIME_TO_UNIX(2026, 07, 07, 14, 00, 30)
#define PPS_SCHEDULER_TIME_MSEC 0

#define DDR4_16GB_HMAX 0x00E2u
#define DDR4_8GB_HMAX 0x00F7u
#define DDR4_16GB_FPS 70u
#define DDR4_8GB_FPS 64u
#define DDR4_16GB_FRAME_TIME (1000000u / DDR4_16GB_FPS)
#define DDR4_8GB_FRAME_TIME (1000000u / DDR4_8GB_FPS)

#define PPS_START_TIME DATETIME_TO_UNIX(2026, 07, 07, 14, 00, 00)

//------------------------------------------------------------------------------
// GPIO instances
//------------------------------------------------------------------------------
gpio_instance_t pwr_ctrl;
gpio_instance_t pwr_stat;
gpio_instance_t eth1_ctrl;
gpio_instance_t eth1_stat;
gpio_instance_t cam_ctrl;
gpio_instance_t cam_stat;
gpio_instance_t dbg_ctrl;
gpio_instance_t eth_pcie_mux;
gpio_instance_t ddr4_8gb_async_rst;
gpio_instance_t ddr4_16gb_async_rst;

//------------------------------------------------------------------------------
// Eth core instances
//------------------------------------------------------------------------------
eth_core_regs_t eth_core_1_regs;

//------------------------------------------------------------------------------
// Cam SPI instance
//------------------------------------------------------------------------------
extern spi_instance_t spi_obj;
addr_t                spi_addr   = SLVSEC_SPI_BASE_ADDR;
uint16_t              fifo_depth = 32u;

//------------------------------------------------------------------------------
// UART instance
//------------------------------------------------------------------------------
UART_16550_Instance_t tmtc_uart;

//------------------------------------------------------------------------------
// FPGA build information
//------------------------------------------------------------------------------
uint32_t hw_build_version;
uint32_t hw_build_git_hash;
uint32_t hw_build_time_utc_sec;

//------------------------------------------------------------------------------
int main()
{
    uint32_t reg32_status = 0;

    // Set
    MRV_systick_config(SYS_CLK_FREQ / 1000);
    msdelay(100);

    //--------------------------------------------------------------------------
    // Read FPGA build information
    //--------------------------------------------------------------------------
    get_hw_info();

    //--------------------------------------------------------------------------
    // Initialize Hardware cores
    //--------------------------------------------------------------------------
    tmtc_uart.u32_Base_Address = TMTC_UART_BASE_ADDR;
    tmtc_uart.u8_Status        = 0;

    v_Init_UART(&tmtc_uart);  // 115200, 8N1, FIFOs enabled

    //--------------------------------------------------------------------------
    // Test UART
    //--------------------------------------------------------------------------
    // test_uart();

    //--------------------------------------------------------------------------
    // Initialize Hardware cores
    //--------------------------------------------------------------------------
    GPIO_init(&pwr_ctrl, GPO_HK_PWR_BASE_ADDR, GPIO_APB_32_BITS_BUS);
    GPIO_init(&pwr_stat, GPI_HK_STATUS_BASE_ADDR, GPIO_APB_32_BITS_BUS);
    GPIO_init(&eth1_ctrl, ETH1_CTRL_BASE_ADDR, GPIO_APB_32_BITS_BUS);
    GPIO_init(&eth1_stat, ETH1_STAT_BASE_ADDR, GPIO_APB_32_BITS_BUS);
    GPIO_init(&cam_ctrl, GPO_CAM_BASE_ADDR, GPIO_APB_32_BITS_BUS);
    GPIO_init(&dbg_ctrl, DBG_GPIO_BASE_ADDR, GPIO_APB_32_BITS_BUS);
    GPIO_init(&eth_pcie_mux, ETH_PCIE_MUX_BASE_ADDR, GPIO_APB_32_BITS_BUS);
    GPIO_init(&ddr4_8gb_async_rst,
              ASYNC_RST_DDR4_8GB_BASE_ADDR,
              GPIO_APB_32_BITS_BUS);
    GPIO_init(&ddr4_16gb_async_rst,
              ASYNC_RST_DDR4_16GB_BASE_ADDR,
              GPIO_APB_32_BITS_BUS);

    SPI_init(&spi_obj, spi_addr, fifo_depth);
    SPI_configure_master_mode(&spi_obj);

    //--------------------------------------------------------------------------
    // Eth1 Phy POWER ON
    //--------------------------------------------------------------------------
    // Power on Eth1
    GPIO_set_output(&pwr_ctrl, ETH1_PWR_EN, 1);
    uint32_t eth1_pwr_status = (GPIO_get_inputs(&pwr_stat) >> 6) & 1;
    msdelay(10);
    GPIO_set_output(&eth1_ctrl, ETH1_PHY_RST_N, 1);
    GPIO_set_output(&eth1_ctrl, ETH1_CTRL_COMMA_MODE, 0);
    GPIO_set_output(&eth1_ctrl, ETH1_CTRL_CLK_SQUELCH_IN, 1);
    // IMPORTANT: 20ms is needed for the PHY to load after reset before any MDIO
    // can be sent
    msdelay(20);

    //--------------------------------------------------------------------------
    // IMX531 Sensor POWER ON
    //--------------------------------------------------------------------------
    // Power on IMX
    GPIO_set_output(&pwr_ctrl, CAM_PWR_EN, 1);
    uint32_t cam_pwr_status = (GPIO_get_inputs(&pwr_stat) >> 11) & 1;
    msdelay(10);
    // Enable sensor oscillator
    GPIO_set_output(&pwr_ctrl, CAM_OSC_EN, 1);

    //--------------------------------------------------------------------------
    // Eth config
    //--------------------------------------------------------------------------
    init_eth1();

    //--------------------------------------------------------------------------
    // Configure UDP cores
    //--------------------------------------------------------------------------
    configure_udp1();

    //--------------------------------------------------------------------------
    // Configure DMA Write
    //--------------------------------------------------------------------------
    reset_write_index();

    configure_dma_write(DMA_WRITE_DDR4_8GB_BASE_ADDR, HORIZ_WIDTH_BYTE);
    configure_dma_write(DMA_WRITE_DDR4_16GB_BASE_ADDR, HORIZ_WIDTH_BYTE);

    //--------------------------------------------------------------------------
    // Configure DMA Read
    //--------------------------------------------------------------------------
    reset_dma_read_ctrl(DMA_READ_CTRL_DDR4_8GB_BASE_ADDR);
    reset_dma_read_ctrl(DMA_READ_CTRL_DDR4_16GB_BASE_ADDR);

    configure_dma_read_ctrl(DMA_READ_CTRL_DDR4_8GB_BASE_ADDR,
                            LINES_PER_FRAME,
                            HORIZ_WIDTH_BYTE,
                            HORIZ_WIDTH_BEAT_8GB);

    configure_dma_read_ctrl(DMA_READ_CTRL_DDR4_16GB_BASE_ADDR,
                            LINES_PER_FRAME,
                            HORIZ_WIDTH_BYTE,
                            HORIZ_WIDTH_BEAT_16GB);

    //--------------------------------------------------------------------------
    // Configure Eth PCIe MUX
    //--------------------------------------------------------------------------
    eth_sel();
    // pcie_sel();

    //--------------------------------------------------------------------------
    // Configure PPS
    //--------------------------------------------------------------------------
    configure_pps(PPS_BASE_ADDR, PPS_START_TIME, 3, 1);
    pps_start(PPS_BASE_ADDR);

    //--------------------------------------------------------------------------
    // SLVSEC Cam Config
    //--------------------------------------------------------------------------
    cam_reset();
    init_slvsec();

    //--------------------------------------------------------------------------
    // Test UDP Standard Frame
    //--------------------------------------------------------------------------
    // HAL_set_32bit_reg(UDP_TX_BASE_ADDR, FRAME_GAP, 1000);
    // for (int i = 0; i < 10; i++) {
    //     test_udp_dbg(UDP_TX_BASE_ADDR, 0, 1000);
    // }

    set_standby_and_master_mode(0x00);

    msdelay(1000);

    configure_trig(
        CAM_TRIG_BASE_ADDR,
        XTRIG_LOW_TIME_CYCLES,
        FRAME_CAPTURE_TIME_USEC,
        DDR4_16GB_FRAME_CAPTURE_AMOUNT + DDR4_8GB_FRAME_CAPTURE_AMOUNT,
        XTRIG_SRC_SEL_MANUAL,
        PPS_SCHEDULER_TIME_SEC,
        PPS_SCHEDULER_TIME_MSEC);

    msdelay(1000);

    trig_capture(CAM_TRIG_BASE_ADDR);

    uint8_t cam_temp = read_cam_temp();

    while (!trig_busy(CAM_TRIG_BASE_ADDR)) {
        msdelay(5);
    }

    do {
        msdelay(100);
    } while (trig_busy(CAM_TRIG_BASE_ADDR));

    uint32_t fpga_temp = read_fpga_temp();

    uint32_t fault = check_fault();

    uint32_t err_stat = 0;
    uint32_t metadata[METADATA_WORD_COUNT];

    while (1) {
        int current_mux = -1;

        for (int index = 0; index < DDR4_16GB_FRAME_CAPTURE_AMOUNT
                                        + DDR4_8GB_FRAME_CAPTURE_AMOUNT;
             index++) {
            if (index < DDR4_16GB_FRAME_CAPTURE_AMOUNT) {
                if (current_mux != UDP_MUX_SELECT_DDR4_16GB) {
                    set_read_mux(UDP_TX_BASE_ADDR, UDP_MUX_SELECT_DDR4_16GB);
                    current_mux = UDP_MUX_SELECT_DDR4_16GB;
                }
                xfer_frame_via_udp(DMA_READ_CTRL_DDR4_16GB_BASE_ADDR, index);
                err_stat = HAL_get_32bit_reg(DMA_READ_DDR4_16GB_BASE_ADDR,
                                             TIMEOUT_ERR_DMA_READ);
                msdelay(100);
                get_metadata(
                    DMA_READ_CTRL_DDR4_16GB_BASE_ADDR, index, metadata);
                msdelay(10);
            } else if (index < DDR4_16GB_FRAME_CAPTURE_AMOUNT
                                   + DDR4_8GB_FRAME_CAPTURE_AMOUNT) {
                if (current_mux != UDP_MUX_SELECT_DDR4_8GB) {
                    set_read_mux(UDP_TX_BASE_ADDR, UDP_MUX_SELECT_DDR4_8GB);
                    current_mux = UDP_MUX_SELECT_DDR4_8GB;
                }
                int adjusted_index = index - DDR4_16GB_FRAME_CAPTURE_AMOUNT;
                xfer_frame_via_udp(DMA_READ_CTRL_DDR4_8GB_BASE_ADDR,
                                   adjusted_index);
                err_stat = HAL_get_32bit_reg(DMA_READ_DDR4_8GB_BASE_ADDR,
                                             TIMEOUT_ERR_DMA_READ);
                msdelay(100);
                get_metadata(
                    DMA_READ_CTRL_DDR4_8GB_BASE_ADDR, adjusted_index, metadata);
                msdelay(10);
            } else {
                /* index out of range — should never reach here */
                break;
            }
        }
    }
}

void init_eth1(void)
{
    // Initialize register pointers for each core
    eth_core_init_regs(&eth_core_1_regs, ETH1_MAC_BASE_ADDR);

    // Initialize eth1
    tse_init(&eth_core_1_regs);
    phy_init(&eth_core_1_regs);
    phy_advertise(&eth_core_1_regs);
    phy_autonegotiation(&eth_core_1_regs);
}

void init_slvsec(void)
{
    set_standby_and_master_mode(0x01);
    set_incksel(0x01);
    set_hvmode(0x00);
    set_vopb_vblk_hwidth(0x11A0);
    set_finfo_hwidth(0x11A0);
    set_vmax(0x00001244);
    set_hmax(DDR4_16GB_HMAX);
    set_freq(0x00);
    set_vndmy(0x00);
    set_vndmy_trig(0x00);
    set_gmrwt(0x0C);
    set_gmtwt(0x14);
    set_gaindly(0x04);
    set_gsdly(0x20);
    set_roi_mode(0x00);
    set_vreverse_and_hreverse(0x00);
    set_adbit(0x01);
    set_slvs_en(0x00);
    set_shs(0x00000048);
    set_trig_mode_timing(0x02, 0x01);
    set_odbit(0x01);
    set_tout0sel(0x01);
    set_gain_rts(0x00);
    set_gain(0x00F0);
    set_blklevel(0x00F0);
    // set_pattern_gen();
    set_synccode(0x00AA);
    set_crc_err_mode(0x00);
    set_standby_and_master_mode(0x00);
    set_standby_and_master_mode(0x01);
}

void cam_reset(void)
{
    GPIO_set_output(&cam_ctrl, CAM_XCLR_N, 0u);
    msdelay(1000);
    GPIO_set_output(&cam_ctrl, CAM_XCLR_N, 1u);
    msdelay(1000);
}

void configure_udp(uint32_t base_addr,
                   uint16_t dst_port,
                   uint16_t src_port,
                   uint32_t dst_ip,
                   uint32_t src_ip,
                   uint16_t dst_mac_msb,
                   uint32_t dst_mac_lsb,
                   uint16_t src_mac_msb,
                   uint32_t src_mac_lsb)
{
    uint32_t reg32_status = 0;

    // Configure UDP ports
    HAL_set_32bit_reg(base_addr, UDP_DST_PORT, dst_port);
    reg32_status = HAL_get_32bit_reg(base_addr, UDP_DST_PORT);

    HAL_set_32bit_reg(base_addr, UDP_SRC_PORT, src_port);
    reg32_status = HAL_get_32bit_reg(base_addr, UDP_SRC_PORT);

    // Configure IP addresses
    HAL_set_32bit_reg(base_addr, DST_IP, dst_ip);
    reg32_status = HAL_get_32bit_reg(base_addr, DST_IP);

    HAL_set_32bit_reg(base_addr, SRC_IP, src_ip);
    reg32_status = HAL_get_32bit_reg(base_addr, SRC_IP);

    // Configure destination MAC address
    HAL_set_32bit_reg(base_addr, DST_MAC_MSB, dst_mac_msb);
    reg32_status = HAL_get_32bit_reg(base_addr, DST_MAC_MSB);

    HAL_set_32bit_reg(base_addr, DST_MAC_LSB, dst_mac_lsb);
    reg32_status = HAL_get_32bit_reg(base_addr, DST_MAC_LSB);

    // Configure source MAC address
    HAL_set_32bit_reg(base_addr, SRC_MAC_MSB, src_mac_msb);
    reg32_status = HAL_get_32bit_reg(base_addr, SRC_MAC_MSB);

    HAL_set_32bit_reg(base_addr, SRC_MAC_LSB, src_mac_lsb);
    reg32_status = HAL_get_32bit_reg(base_addr, SRC_MAC_LSB);
}

void configure_udp1(void)
{
    configure_udp(UDP_TX_BASE_ADDR,
                  ETH1_DST_PORT,
                  ETH1_SRC_PORT,
                  ETH1_DST_IP,
                  ETH1_SRC_IP,
                  ETH1_DST_MAC_MSB,
                  ETH1_DST_MAC_LSB,
                  ETH1_SRC_MAC_MSB,
                  ETH1_SRC_MAC_LSB);
}

void configure_dma_write(uint32_t base_addr, uint32_t h_size_byte)
{
    uint32_t reg32_status = 0;

    HAL_set_32bit_reg(base_addr, DMA_WRITE_H_SIZE_BYTE, h_size_byte);
    reg32_status = HAL_get_32bit_reg(base_addr, DMA_WRITE_H_SIZE_BYTE);
}

void reset_dma_write(uint32_t base_addr)
{
    HAL_set_32bit_reg(base_addr, CLEAR_INDEX, 1);
    msdelay(10);
    HAL_set_32bit_reg(base_addr, CLEAR_INDEX, 0);
}

void cam_mux_clear(void)
{
    HAL_set_32bit_reg(CAM_MUX_BASE_ADDR, MUX_CLEAR, 1);
    msdelay(10);
}

void reset_write_index(void)
{
    reset_dma_write(DMA_WRITE_DDR4_8GB_BASE_ADDR);
    reset_dma_write(DMA_WRITE_DDR4_16GB_BASE_ADDR);
    cam_mux_clear();
}

void async_reset_ddr4(void)
{
    GPIO_set_output(&ddr4_8gb_async_rst, ASYNC_DDR4_RST, 1);
    GPIO_set_output(&ddr4_16gb_async_rst, ASYNC_DDR4_RST, 1);
    msdelay(10);
    GPIO_set_output(&ddr4_8gb_async_rst, ASYNC_DDR4_RST, 0);
    GPIO_set_output(&ddr4_16gb_async_rst, ASYNC_DDR4_RST, 0);
}

void reset_dma_read_ctrl(uint32_t base_addr)
{
    HAL_set_32bit_reg(base_addr, CLEAR_DMA_READ_CTRL, 1);
    msdelay(10);
    HAL_set_32bit_reg(base_addr, CLEAR_DMA_READ_CTRL, 0);
    msdelay(10);
    HAL_set_32bit_reg(base_addr, RESET_DONE_COUNTER, 1);
    msdelay(10);
    HAL_set_32bit_reg(base_addr, RESET_DONE_COUNTER, 0);
}

void configure_dma_read_ctrl(uint32_t base_addr,
                             uint32_t v_size_line,
                             uint32_t h_size_byte,
                             uint32_t h_size_beat)
{
    HAL_set_32bit_reg(base_addr, V_SIZE_LINE, v_size_line);
    HAL_set_32bit_reg(base_addr, H_SIZE_BYTE, h_size_byte);
    HAL_set_32bit_reg(base_addr, H_SIZE_BEAT, h_size_beat);
}

void xfer_frame_via_udp(uint32_t base_addr, uint32_t frame_index)
{
    HAL_set_32bit_reg(base_addr, UDP_METADATA_SEL, 0);

    // Make sure the register is cleared
    HAL_set_32bit_reg(base_addr, FRAME_READ_REQ, 0);

    HAL_set_32bit_reg(base_addr, DMA_READ_FRAME_INDEX, frame_index);
    uint32_t prev_read_count =
        HAL_get_32bit_reg(base_addr, FRAME_READ_DONE_COUNT);

    // Send the read request
    HAL_set_32bit_reg(base_addr, FRAME_READ_REQ, 1);

    while (HAL_get_32bit_reg(base_addr, FRAME_READ_DONE_COUNT) ==
           prev_read_count) {}

    // Clear the register
    HAL_set_32bit_reg(base_addr, FRAME_READ_REQ, 0);
}

void get_metadata(uint32_t base_addr, uint32_t frame_index,
                  uint32_t *metadata_out)
{
    HAL_set_32bit_reg(base_addr, UDP_METADATA_SEL, 1);

    // Make sure the register is cleared
    HAL_set_32bit_reg(base_addr, FRAME_READ_REQ, 0);

    HAL_set_32bit_reg(base_addr, DMA_READ_FRAME_INDEX, frame_index);
    uint32_t prev_read_count =
        HAL_get_32bit_reg(base_addr, FRAME_READ_DONE_COUNT);

    // Send the read request
    HAL_set_32bit_reg(base_addr, FRAME_READ_REQ, 1);

    msdelay(5);

    HAL_set_32bit_reg(base_addr, FRAME_READ_REQ, 0);
    HAL_set_32bit_reg(base_addr, UDP_METADATA_SEL, 0);

    volatile uint32_t *regs =
        (volatile uint32_t *)(base_addr + METADATA_DATA_BASE_REG_OFFSET);
    for (uint32_t i = 0u; i < METADATA_WORD_COUNT; i++) {
        metadata_out[i] = regs[i];
    }
}

void set_read_mux(uint32_t base_addr, uint32_t sel)
{
    HAL_set_32bit_reg(base_addr, UDP_MUX_SEL, sel);
}

int configure_trig(uint32_t base_addr,
                   uint32_t xtrig_low_time_cycles,
                   uint32_t frame_capture_time,
                   uint32_t frame_capture_amount,
                   uint32_t xtrig_src_sel,
                   uint32_t scheduler_time_sec,
                   uint32_t scheduler_time_msec)
{
    uint32_t xtrig_low_time_usec = xtrig_low_time_cycles / CYCLES_PER_USEC;

    uint32_t ddr4_16gb_frame_index =
        HAL_get_32bit_reg(DMA_WRITE_DDR4_16GB_BASE_ADDR, DMA_WRITE_FRAME_INDEX);
    uint32_t ddr4_16gb_full =
        HAL_get_32bit_reg(CAM_MUX_BASE_ADDR, DDR4_16GB_FULL);
    uint32_t ddr4_16gb_stored_count =
        ddr4_16gb_full
            ? DDR4_16GB_FRAME_CAPTURE_AMOUNT
            : (ddr4_16gb_frame_index == DDR4_16GB_FRAME_CAPTURE_AMOUNT - 1u
                   ? 0u
                   : ddr4_16gb_frame_index + 1u);
    uint32_t ddr4_8gb_frame_index =
        HAL_get_32bit_reg(DMA_WRITE_DDR4_8GB_BASE_ADDR, DMA_WRITE_FRAME_INDEX);
    uint32_t ddr4_8gb_full =
        HAL_get_32bit_reg(CAM_MUX_BASE_ADDR, DDR4_8GB_FULL);
    uint32_t ddr4_8gb_stored_count =
        ddr4_8gb_full
            ? DDR4_8GB_FRAME_CAPTURE_AMOUNT
            : (ddr4_8gb_frame_index == DDR4_8GB_FRAME_CAPTURE_AMOUNT - 1u
                   ? 0u
                   : ddr4_8gb_frame_index + 1u);

    if (ddr4_16gb_stored_count + ddr4_8gb_stored_count + frame_capture_amount
        > DDR4_16GB_FRAME_CAPTURE_AMOUNT + DDR4_8GB_FRAME_CAPTURE_AMOUNT) {
        return -1;
    }

    if (ddr4_16gb_stored_count + frame_capture_amount
            > DDR4_16GB_FRAME_CAPTURE_AMOUNT
        && ddr4_8gb_stored_count == 0u) {
        set_hmax(DDR4_8GB_HMAX);
    }

    if (ddr4_16gb_stored_count + frame_capture_amount
        > DDR4_16GB_FRAME_CAPTURE_AMOUNT) {
        if (frame_capture_time < xtrig_low_time_usec + DDR4_8GB_FRAME_TIME) {
            return -1;
        }
    } else {
        if (frame_capture_time < xtrig_low_time_usec + DDR4_16GB_FRAME_TIME) {
            return -1;
        }
    }

    uint32_t reg32_status = 0;

    HAL_set_32bit_reg(base_addr, XTRIG_LOW_TIME, xtrig_low_time_cycles);
    reg32_status = HAL_get_32bit_reg(base_addr, XTRIG_LOW_TIME);

    HAL_set_32bit_reg(base_addr, FRAME_CAPTURE_TIME, frame_capture_time);
    reg32_status = HAL_get_32bit_reg(base_addr, FRAME_CAPTURE_TIME);

    HAL_set_32bit_reg(base_addr, FRAME_CAPTURE_AMOUNT, frame_capture_amount);
    reg32_status = HAL_get_32bit_reg(base_addr, FRAME_CAPTURE_AMOUNT);

    HAL_set_32bit_reg(base_addr, SCHEDULER_TIME_SEC, scheduler_time_sec);
    reg32_status = HAL_get_32bit_reg(base_addr, SCHEDULER_TIME_SEC);

    HAL_set_32bit_reg(base_addr, SCHEDULER_TIME_MSEC, scheduler_time_msec);
    reg32_status = HAL_get_32bit_reg(base_addr, SCHEDULER_TIME_MSEC);

    HAL_set_32bit_reg(base_addr, XTRIG_SRC_SEL, xtrig_src_sel);
    reg32_status = HAL_get_32bit_reg(base_addr, XTRIG_SRC_SEL);

    return 0;
}

void trig_capture(uint32_t base_addr)
{
    uint32_t reg32_status = 0;
    HAL_set_32bit_reg(base_addr, XTRIG_START, 0);
    HAL_set_32bit_reg(base_addr, XTRIG_START, 1);
    reg32_status = HAL_get_32bit_reg(base_addr, XTRIG_START);
}

uint32_t trig_busy(uint32_t base_addr)
{
    return HAL_get_32bit_reg(base_addr, CAM_TRIG_BUSY);
}

void configure_pps(uint32_t base_addr,
                   uint32_t load_seconds,
                   uint32_t pps_rx_delay,
                   uint32_t en_local_pps_source)
{
    uint32_t reg32_status = 0;

    HAL_set_32bit_reg(base_addr, LOAD_SECONDS, load_seconds);
    reg32_status = HAL_get_32bit_reg(base_addr, LOAD_SECONDS);

    HAL_set_32bit_reg(base_addr, PPS_RX_DELAY, pps_rx_delay);
    reg32_status = HAL_get_32bit_reg(base_addr, PPS_RX_DELAY);

    HAL_set_32bit_reg(base_addr, EN_LOCAL_PPS_SOURCE, en_local_pps_source);
    reg32_status = HAL_get_32bit_reg(base_addr, EN_LOCAL_PPS_SOURCE);
}

void pps_start(uint32_t base_addr)
{
    HAL_set_32bit_reg(base_addr, TRIGGER_TIME_JAM, 1);
}

void eth_sel(void)
{
    GPIO_set_output(&eth_pcie_mux, ETH_PCIE_SEL, 0);
}

void pcie_sel(void)
{
    GPIO_set_output(&eth_pcie_mux, ETH_PCIE_SEL, 1);
}

uint8_t read_cam_temp(void)
{
    spi_wr(0x07, 0x96, 0x01);
    msdelay(1);
    uint8_t cam_temp = spi_rd(0x87, 0x94);
    HAL_set_32bit_reg(IMAGE_METADATA_BASE_ADDR, SENSOR_TEMP_RAW, cam_temp);
    return cam_temp;
}

uint32_t read_fpga_temp(void)
{
    return HAL_get_32bit_reg(JUNC_TEMP_BASE_ADDR, JUNC_TEMP);
}

uint32_t check_fault(void)
{
    return HAL_get_32bit_reg(CAM_FAULT_DETECTOR_BASE_ADDR, CAM_FAULT);
}

void clear_fault(void)
{
    HAL_set_32bit_reg(CAM_FAULT_DETECTOR_BASE_ADDR, CAM_FAULT_CLEAR, 1);
    msdelay(10);
    HAL_set_32bit_reg(CAM_FAULT_DETECTOR_BASE_ADDR, CAM_FAULT_CLEAR, 0);
}

void get_hw_info(void)
{
    hw_build_version      = HAL_get_32bit_reg(HW_VERSION_BASE_ADDR, BUILD_VERSION);
    HAL_set_32bit_reg(IMAGE_METADATA_BASE_ADDR, VERSION, hw_build_version);
    hw_build_git_hash     = HAL_get_32bit_reg(HW_VERSION_BASE_ADDR, BUILD_GIT_HASH);
    hw_build_time_utc_sec = HAL_get_32bit_reg(HW_VERSION_BASE_ADDR, BUILD_TIME_UTC_SEC);
}

void test_uart()
{
    while (1) {
        uint8_t line_status = u8_Get_Line_Status(&tmtc_uart);

        // v_Write_UART_Tx_Data(&tmtc_uart, 'Z');

        // Check Data Ready bit
        if (line_status & LINE_STATUS_DR) {
            uint8_t rx_byte = u8_Get_UART_Rx_Data(&tmtc_uart);

            // Wait until TX holding register is empty
            while (!b_Is_Tx_Hold_Reg_Empty(&tmtc_uart)) {
                // spin
            }

            // Toggle case: lower->upper, upper->lower, else pass through
            if (rx_byte >= 'a' && rx_byte <= 'z') {
                rx_byte -= 32;
            } else if (rx_byte >= 'A' && rx_byte <= 'Z') {
                rx_byte += 32;
            }

            v_Write_UART_Tx_Data(&tmtc_uart, rx_byte);
        }
    }
}
