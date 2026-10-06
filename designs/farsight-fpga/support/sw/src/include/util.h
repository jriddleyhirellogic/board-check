#ifndef UTIL_H
#define UTIL_H
#include "core_spi.h"
#include "fpga_design_config/fpga_design_config.h"
#include "hal/hal.h"
#include "miv_rv32_hal/miv_rv32_hal.h"

spi_instance_t spi_obj;

uint8_t reverse_bits(uint8_t num);

void spi_wr(uint8_t chip_id, uint8_t reg_addr, uint8_t spi_data);

uint8_t spi_rd(uint8_t chip_id, uint8_t reg_addr);

void spi_set_and_confirm(uint8_t wr_chip_id,
                         uint8_t rd_chip_id,
                         uint8_t reg_addr,
                         uint8_t wr_spi_data);

void set_standby_and_master_mode(uint8_t sel);

void set_incksel(uint8_t sel);

void set_hvmode(uint8_t sel);

void set_vopb_vblk_hwidth(uint16_t sel);

void set_finfo_hwidth(uint16_t sel);

void set_vmax(uint32_t sel);

void set_hmax(uint16_t sel);

void set_freq(uint8_t sel);

void set_vndmy(uint8_t sel);

void set_vndmy_trig(uint8_t sel);

void set_gmrwt(uint8_t sel);

void set_gmtwt(uint8_t sel);

void set_gaindly(uint8_t sel);

void set_gsdly(uint8_t sel);

void set_roi_mode(uint8_t sel);

void set_adbit(uint8_t sel);

void set_slvs_en(uint8_t sel);

void set_shs(uint32_t sel);

void set_trig_mode_timing(uint8_t sel1, uint8_t sel2);

void set_odbit(uint8_t sel);

void set_tout0sel(uint8_t sel);

void set_gain_rts(uint8_t sel);

void set_gain(uint16_t sel);

void set_blklevel(uint16_t sel);

void set_synccode(uint16_t sel);

void set_crc_err_mode(uint8_t sel);

void set_pattern_gen(void);

void msdelay(uint32_t tms);

void SysTick_Handler(void);

#endif
