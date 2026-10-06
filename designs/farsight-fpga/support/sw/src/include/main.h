#ifndef MAIN_H
#define MAIN_H

#include "cam_fault_detector.h"
#include "cam_mux.h"
#include "cam_trig.h"
#include "core_gpio.h"
#include "core_spi.h"
#include "core_uart_apb.h"
#include "dma_read_ctrl_reg.h"
#include "dma_read_reg.h"
#include "dma_write_reg.h"
#include "eth.h"
#include "fpga_design_config/fpga_design_config.h"
#include "gpio_pin_def.h"
#include "hal/hal.h"
#include "hal_uart16550.h"
#include "hw_version.h"
#include "image_metadata.h"
#include "junc_temp.h"
#include "miv_rv32_hal/miv_rv32_hal.h"
#include "pps.h"
#include "timer.h"
#include "tsecore_reg.h"
#include "udp_core_reg.h"
#include "util.h"

#define IP_TO_U32(w, x, y, z) \
    (((w & 0xff) << 24) | ((x & 0xff) << 16) | ((y & 0xff) << 8) | (z & 0xff))

#define IS_LEAP_YEAR(y) \
    (((y) % 4 == 0) && (((y) % 100 != 0) || ((y) % 400 == 0)))

#define DAYS_BEFORE_MONTH(y, mo)                   \
    (((mo) == 1)  ? 0   :                          \
     ((mo) == 2)  ? 31  :                          \
     ((mo) == 3)  ? (59  + IS_LEAP_YEAR(y)) :      \
     ((mo) == 4)  ? (90  + IS_LEAP_YEAR(y)) :      \
     ((mo) == 5)  ? (120 + IS_LEAP_YEAR(y)) :      \
     ((mo) == 6)  ? (151 + IS_LEAP_YEAR(y)) :      \
     ((mo) == 7)  ? (181 + IS_LEAP_YEAR(y)) :      \
     ((mo) == 8)  ? (212 + IS_LEAP_YEAR(y)) :      \
     ((mo) == 9)  ? (243 + IS_LEAP_YEAR(y)) :      \
     ((mo) == 10) ? (273 + IS_LEAP_YEAR(y)) :      \
     ((mo) == 11) ? (304 + IS_LEAP_YEAR(y)) :      \
                    (334 + IS_LEAP_YEAR(y)))

/* Convert UTC date/time to Unix timestamp (seconds since 1970-01-01 00:00:00).
 * Equivalent to: date -d "YYYY-MM-DD HH:MM:SS UTC" +%s */
#define DATETIME_TO_UNIX(y, mo, d, h, mi, s)       \
    ((uint32_t)(                                    \
        (                                           \
            ((y) - 1970) * 365UL                    \
            + ((y) - 1) / 4                         \
            - ((y) - 1) / 100                       \
            + ((y) - 1) / 400                       \
            - 477                                   \
            + DAYS_BEFORE_MONTH((y), (mo))          \
            + (d) - 1                               \
        ) * 86400UL                                 \
        + (h) * 3600UL                              \
        + (mi) * 60UL                               \
        + (s)                                       \
    ))

//------------------------------------------------------------------------------
// Function declarations
//------------------------------------------------------------------------------
void init_eth1(void);
void init_slvsec(void);
void cam_reset(void);
void configure_udp(uint32_t base_addr,
                   uint16_t dst_port,
                   uint16_t src_port,
                   uint32_t dst_ip,
                   uint32_t src_ip,
                   uint16_t dst_mac_msb,
                   uint32_t dst_mac_lsb,
                   uint16_t src_mac_msb,
                   uint32_t src_mac_lsb);

void configure_udp1(void);

void configure_dma_write(uint32_t base_addr, uint32_t h_size_byte);
void reset_dma_write(uint32_t base_addr);
void cam_mux_clear(void);
void reset_write_index(void);
void async_reset_ddr4(void);

void reset_dma_read_ctrl(uint32_t base_addr);
void configure_dma_read_ctrl(uint32_t base_addr,
                             uint32_t v_size_line,
                             uint32_t h_size_byte,
                             uint32_t h_size_beat);
void xfer_frame_via_udp(uint32_t base_addr, uint32_t frame_index);
void get_metadata(uint32_t base_addr, uint32_t frame_index,
                  uint32_t *metadata_out);
void set_read_mux(uint32_t base_addr, uint32_t sel);

int configure_trig(uint32_t base_addr,
                   uint32_t xtrig_low_time_cycles,
                   uint32_t frame_capture_time,
                   uint32_t frame_capture_amount,
                   uint32_t xtrig_src_sel,
                   uint32_t scheduler_time_sec,
                   uint32_t scheduler_time_msec);

void trig_capture(uint32_t base_addr);

uint32_t trig_busy(uint32_t base_addr);

void configure_pps(uint32_t base_addr,
                   uint32_t load_seconds,
                   uint32_t pps_rx_delay,
                   uint32_t en_local_pps_source);

void pps_start(uint32_t base_addr);

void eth_sel(void);
void pcie_sel(void);

uint8_t read_cam_temp(void);
uint32_t read_fpga_temp(void);

uint32_t check_fault(void);
void clear_fault(void);

void get_hw_info(void);

void test_uart();

#endif
