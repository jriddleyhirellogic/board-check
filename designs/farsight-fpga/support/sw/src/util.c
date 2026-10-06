/*******************************************************************************
 * @file      util.c
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      09/17/2025
 * 
 * @brief     Utility functions including cam spi write function and busy delay
 * 
 * @section changelog
 * - 09/17/2025: Saba Janamian - Initial implementation
 * 
*******************************************************************************/

#include "util.h"
#include "image_metadata.h"

//------------------------------------------------------------------------------
// Global state counter.
//------------------------------------------------------------------------------
volatile uint32_t g_10ms_count;
volatile uint32_t timerdone = 0;
volatile uint32_t g_10ms_count1;
volatile uint32_t g_ms_count;
uint32_t          g_state = 1;

volatile uint32_t rx_tmr_done = 0;
volatile uint32_t rx_ms_count1;
volatile uint32_t rx_ms_count;
uint32_t          t_ms_count   = 0;
uint32_t          process_data = 0;

//------------------------------------------------------------------------------
// Camera functions
//------------------------------------------------------------------------------
uint8_t reverse_bits(uint8_t num)
{
    uint8_t reversed = 0;
    for (int i = 0; i < 8; i++) {
        reversed <<= 1;
        reversed |= (num & 1);
        num >>= 1;
    }
    return reversed;
}

void spi_wr(uint8_t chip_id, uint8_t reg_addr, uint8_t spi_data)
{
    SPI_set_slave_select(&spi_obj, SPI_SLAVE_0);
    uint8_t read_buffer[3]  = {0, 0, 0};
    uint8_t write_buffer[3] = {0, 0, 0};

    write_buffer[0] = reverse_bits(chip_id);
    write_buffer[1] = reverse_bits(reg_addr);
    write_buffer[2] = reverse_bits(spi_data);

    SPI_transfer_block(
        &spi_obj, write_buffer, sizeof(write_buffer), read_buffer, 0);
    SPI_clear_slave_select(&spi_obj, SPI_SLAVE_0);
    msdelay(100);
}

uint8_t spi_rd(uint8_t chip_id, uint8_t reg_addr)
{
    SPI_set_slave_select(&spi_obj, SPI_SLAVE_0);
    uint8_t read_buffer[1]  = {0};
    uint8_t write_buffer[2] = {0, 0};

    write_buffer[0] = reverse_bits(chip_id);
    write_buffer[1] = reverse_bits(reg_addr);

    SPI_transfer_block(&spi_obj,
                       write_buffer,
                       sizeof(write_buffer),
                       read_buffer,
                       sizeof(read_buffer));
    SPI_clear_slave_select(&spi_obj, SPI_SLAVE_0);
    msdelay(100);

    return reverse_bits(read_buffer[0]);
}

void spi_set_and_confirm(uint8_t wr_chip_id,
                         uint8_t rd_chip_id,
                         uint8_t reg_addr,
                         uint8_t wr_spi_data)
{
    const int max_attempts = 4;

    for (int attempt = 0; attempt < max_attempts; ++attempt) {
        spi_wr(wr_chip_id, reg_addr, wr_spi_data);
        uint8_t rd_spi_data = spi_rd(rd_chip_id, reg_addr);
        if (wr_spi_data == rd_spi_data) {
            return;
        } else {
            msdelay(100);
        }
    }

    HAL_ASSERT(0);
}

void async_reset_ddr4(void);
void clear_fault(void);

void set_standby_and_master_mode(uint8_t sel)
{   // STANDBY - 0: Normal operation; 1: Standby
    spi_set_and_confirm(0x02, 0x82, 0x00, sel);
    msdelay(100);
    // XMSTA - 0: Master mode operation start; 1: Master mode operation stop
    spi_set_and_confirm(0x02, 0x82, 0x10, sel);
    msdelay(100);
    // Reset DDR4 and clear fault as XTRIG gets asserted in the process
    if (sel == 0x00) {
        async_reset_ddr4();
        clear_fault();
    }
}

void set_incksel(uint8_t sel)
{   // INCKSEL - 0: 74.25 MHz; 1: 54 MHz; 2: 37.125 MHz
    if (sel == 0x00) {
        spi_set_and_confirm(0x02, 0x82, 0x14, 0x0A);
        spi_set_and_confirm(0x02, 0x82, 0x15, 0x22);
        spi_set_and_confirm(0x02, 0x82, 0x16, 0xB1);
        spi_set_and_confirm(0x02, 0x82, 0x18, 0x3F);
        spi_set_and_confirm(0x02, 0x82, 0x19, 0x04);
        spi_set_and_confirm(0x02, 0x82, 0x1B, 0x3A);

        spi_set_and_confirm(0x04, 0x84, 0x1C, 0x80);
        spi_set_and_confirm(0x04, 0x84, 0x1E, 0xE0);
        spi_set_and_confirm(0x04, 0x84, 0x1F, 0x00);
        spi_set_and_confirm(0x04, 0x84, 0x20, 0x80);
        spi_set_and_confirm(0x04, 0x84, 0x22, 0xE0);
        spi_set_and_confirm(0x04, 0x84, 0x23, 0x00);
        spi_set_and_confirm(0x04, 0x84, 0x26, 0x20);
    } else if (sel == 0x01) {
        spi_set_and_confirm(0x02, 0x82, 0x14, 0xF0);
        spi_set_and_confirm(0x02, 0x82, 0x15, 0xD2);
        spi_set_and_confirm(0x02, 0x82, 0x16, 0x80);
        spi_set_and_confirm(0x02, 0x82, 0x18, 0x17);
        spi_set_and_confirm(0x02, 0x82, 0x19, 0x03);
        spi_set_and_confirm(0x02, 0x82, 0x1B, 0x2A);

        spi_set_and_confirm(0x04, 0x84, 0x1C, 0x80);
        spi_set_and_confirm(0x04, 0x84, 0x1E, 0x34);
        spi_set_and_confirm(0x04, 0x84, 0x1F, 0x01);
        spi_set_and_confirm(0x04, 0x84, 0x20, 0x80);
        spi_set_and_confirm(0x04, 0x84, 0x22, 0x34);
        spi_set_and_confirm(0x04, 0x84, 0x23, 0x01);
        spi_set_and_confirm(0x04, 0x84, 0x26, 0x2C);
    } else if (sel == 0x02) {
        spi_set_and_confirm(0x02, 0x82, 0x14, 0x05);
        spi_set_and_confirm(0x02, 0x82, 0x15, 0x91);
        spi_set_and_confirm(0x02, 0x82, 0x16, 0x60);
        spi_set_and_confirm(0x02, 0x82, 0x18, 0x1F);
        spi_set_and_confirm(0x02, 0x82, 0x19, 0x02);
        spi_set_and_confirm(0x02, 0x82, 0x1B, 0x1D);

        spi_set_and_confirm(0x04, 0x84, 0x1C, 0x40);
        spi_set_and_confirm(0x04, 0x84, 0x1E, 0xE0);
        spi_set_and_confirm(0x04, 0x84, 0x1F, 0x00);
        spi_set_and_confirm(0x04, 0x84, 0x20, 0x40);
        spi_set_and_confirm(0x04, 0x84, 0x22, 0xE0);
        spi_set_and_confirm(0x04, 0x84, 0x23, 0x00);
        spi_set_and_confirm(0x04, 0x84, 0x26, 0x40);
    }
    spi_set_and_confirm(0x04, 0x84, 0x1D, 0x05);
    spi_set_and_confirm(0x04, 0x84, 0x21, 0x05);
    spi_set_and_confirm(0x04, 0x84, 0x24, 0x10);
    spi_set_and_confirm(0x04, 0x84, 0x25, 0x14);
}

void set_hvmode(uint8_t sel)
{   // HVMODE - 0: All-pixel; 1: 1/2 Subsampling mode; 2: FD binning; 3: Setting prohibited
    if (sel == 0x00) {
        spi_set_and_confirm(0x02, 0x82, 0x3C, 0x01);
        spi_set_and_confirm(0x07, 0x87, 0x21, 0xC9);
        HAL_set_32bit_reg(IMAGE_METADATA_BASE_ADDR, SENSOR_PXL_READOUT_FORMAT, 0);
    } else if (sel == 0x01) {
        spi_set_and_confirm(0x02, 0x82, 0x3C, 0x09);
        spi_set_and_confirm(0x07, 0x87, 0x21, 0x65);
        HAL_set_32bit_reg(IMAGE_METADATA_BASE_ADDR, SENSOR_PXL_READOUT_FORMAT, 1);
    } else if (sel == 0x02) {
        spi_set_and_confirm(0x02, 0x82, 0x3C, 0x11);
        spi_set_and_confirm(0x07, 0x87, 0x21, 0x65);
        HAL_set_32bit_reg(IMAGE_METADATA_BASE_ADDR, SENSOR_PXL_READOUT_FORMAT, 2);
    } else if (sel == 0x03) {
        spi_set_and_confirm(0x02, 0x82, 0x3C, 0x19);
        HAL_set_32bit_reg(IMAGE_METADATA_BASE_ADDR, SENSOR_PXL_READOUT_FORMAT, 3);
    }
    spi_set_and_confirm(0x07, 0x87, 0x22, 0xB0);
    spi_set_and_confirm(0x07, 0x87, 0x46, 0x32);
    spi_set_and_confirm(0x08, 0x88, 0x10, 0xFF);
    spi_set_and_confirm(0x0B, 0x8B, 0x04, 0x00);
}

void set_vopb_vblk_hwidth(uint16_t sel)
{   // VOPB_VBLK_HWIDTH
    spi_set_and_confirm(0x02, 0x82, 0xD0, sel);
    spi_set_and_confirm(0x02, 0x82, 0xD1, (sel >> 8));
}

void set_finfo_hwidth(uint16_t sel)
{   // FINFO_HWIDTH
    spi_set_and_confirm(0x02, 0x82, 0xD2, sel);
    spi_set_and_confirm(0x02, 0x82, 0xD3, (sel >> 8));
}

void set_vmax(uint32_t sel)
{   // VMAX
    spi_set_and_confirm(0x02, 0x82, 0xD4, sel);
    spi_set_and_confirm(0x02, 0x82, 0xD5, (sel >> 8));
    spi_set_and_confirm(0x02, 0x82, 0xD6, (sel >> 16));
}

void set_hmax(uint16_t sel)
{   // HMAX
    spi_set_and_confirm(0x02, 0x82, 0xD8, sel);
    spi_set_and_confirm(0x02, 0x82, 0xD9, (sel >> 8));
}

void set_freq(uint8_t sel)
{   // FREQ - 0: 4.752 Gbps; 1: 2.376 Gbps; 2: 1.188 Gbps; 3: Setting prohibited
    if (sel == 0x00) {
        spi_set_and_confirm(0x02, 0x82, 0xDC, 0x00);
        spi_set_and_confirm(0x04, 0x84, 0x27, 0xC0);
        spi_set_and_confirm(0x04, 0x84, 0x33, 0x00);
        spi_set_and_confirm(0x0C, 0x8C, 0x0C, 0x18);
    } else if (sel == 0x01) {
        spi_set_and_confirm(0x02, 0x82, 0xDC, 0x01);
        spi_set_and_confirm(0x04, 0x84, 0x27, 0xD0);
        spi_set_and_confirm(0x04, 0x84, 0x33, 0x50);
        spi_set_and_confirm(0x0C, 0x8C, 0x0C, 0x0B);
    } else if (sel == 0x02) {
        spi_set_and_confirm(0x02, 0x82, 0xDC, 0x02);
        spi_set_and_confirm(0x04, 0x84, 0x27, 0xE0);
        spi_set_and_confirm(0x04, 0x84, 0x33, 0xA0);
        spi_set_and_confirm(0x0C, 0x8C, 0x0C, 0x05);
    } else if (sel == 0x03) {
        spi_set_and_confirm(0x02, 0x82, 0xDC, 0x03);
    }
}

void set_vndmy(uint8_t sel)
{   // VNDMY - 0: All-pixel or ROI; 1: 1/2 Subsampling mode or FD binning; Others: Setting prohibited
    if (sel == 0x00) {
        spi_set_and_confirm(0x02, 0x82, 0xE0, 0x04);
    } else if (sel == 0x01) {
        spi_set_and_confirm(0x02, 0x82, 0xE0, 0x08);
    } else {
        spi_set_and_confirm(0x02, 0x82, 0xE0, 0xFF);
    }
}

void set_vndmy_trig(uint8_t sel)
{   // VNDMY_TRIG - 0: All-pixel or ROI; 1: 1/2 Subsampling mode or FD binning; Others: Setting prohibited
    if (sel == 0x00) {
        spi_set_and_confirm(0x02, 0x82, 0xE1, 0x04);
    } else if (sel == 0x01) {
        spi_set_and_confirm(0x02, 0x82, 0xE1, 0x08);
    } else {
        spi_set_and_confirm(0x02, 0x82, 0xE1, 0xFF);
    }
}

void set_gmrwt(uint8_t sel)
{   // GMRWT
    spi_set_and_confirm(0x02, 0x82, 0xE2, sel);
}

void set_gmtwt(uint8_t sel)
{   // GMTWT
    spi_set_and_confirm(0x02, 0x82, 0xE3, sel);
}

void set_gaindly(uint8_t sel)
{   // GAINDLY
    spi_set_and_confirm(0x02, 0x82, 0xE5, sel);
}

void set_gsdly(uint8_t sel)
{   // GSDLY
    spi_set_and_confirm(0x02, 0x82, 0xE6, sel);
}

void set_roi_mode(uint8_t sel)
{   // ROI_MODE - 0: ROI Mode; 1: Overlap ROI Mode
    spi_set_and_confirm(0x03, 0x83, 0x00, sel);
}

void set_vreverse_and_hreverse(uint8_t sel)
{   // VREVERSE (bit 0) and HREVERSE (bit 1) - 0: Normal; 1: Inverted
    sel &= 0x03;
    spi_set_and_confirm(0x04, 0x84, 0x04, sel);
    HAL_set_32bit_reg(IMAGE_METADATA_BASE_ADDR, SENSOR_READ_DIR, sel);
}

void set_adbit(uint8_t sel)
{   // ADBIT - 0: 10 bit; 1: 12 bit; 2: 8 bit; 3: Setting prohibited
    if (sel == 0x00) {
        spi_set_and_confirm(0x04, 0x84, 0x00, 0x04);
        spi_set_and_confirm(0x08, 0x88, 0x0D, 0x0D);
    } else if (sel == 0x01) {
        spi_set_and_confirm(0x04, 0x84, 0x00, 0x14);
        spi_set_and_confirm(0x08, 0x88, 0x0D, 0x0F);
    } else if (sel == 0x02) {
        spi_set_and_confirm(0x04, 0x84, 0x00, 0x24);
        spi_set_and_confirm(0x08, 0x88, 0x0D, 0x0A);
    } else if (sel == 0x03) {
        spi_set_and_confirm(0x04, 0x84, 0x00, 0x34);
    }
}

void set_slvs_en(uint8_t sel)
{   // SLVS_EN - 0: SLVS-EC; 1: SLVS
    if (sel == 0x00) {
        spi_set_and_confirm(0x04, 0x84, 0x2B, 0x02);
    } else if (sel == 0x01) {
        spi_set_and_confirm(0x04, 0x84, 0x2B, 0x06);
    }
}

void set_shs(uint32_t sel)
{   // SHS
    spi_set_and_confirm(0x04, 0x84, 0x40, sel);
    spi_set_and_confirm(0x04, 0x84, 0x41, (sel >> 8));
    spi_set_and_confirm(0x04, 0x84, 0x42, (sel >> 16));
}

void set_trig_mode_timing(uint8_t sel1, uint8_t sel2)
{   // TRIGMODE - 0: Global shutter mode setting; 0: Normal mode; 1: Sequential Trigger mode; 2: Fast Trigger mode; Others: Setting prohibited
    if (sel2
        == 0x00) {  // TRIGTIMING - 0: Normal mode; 1: Trigger mode; Others: Setting prohibited
        if (sel1 == 0x00) {
            spi_set_and_confirm(0x06, 0x86, 0x00, 0x00);
        } else {
            spi_set_and_confirm(0x06, 0x86, 0x00, 0x07);
        }
    } else if (sel2 == 0x01) {
        if (sel1 == 0x01) {
            spi_set_and_confirm(0x06, 0x86, 0x00, 0x09);
        } else if (sel1 == 0x02) {
            spi_set_and_confirm(0x06, 0x86, 0x00, 0x0A);
        } else {
            spi_set_and_confirm(0x06, 0x86, 0x00, 0x0F);
        }
    } else {
        spi_set_and_confirm(0x06, 0x86, 0x00, 0x1F);
    }
}

void set_odbit(uint8_t sel)
{   // ODBIT - 0: 10 bit; 1: 12 bit; 2: 8 bit; 3: Setting prohibited
    if (sel == 0x00) {
        spi_set_and_confirm(0x06, 0x86, 0x30, 0x00);
        HAL_set_32bit_reg(IMAGE_METADATA_BASE_ADDR, SENSOR_BIT_DEPTH, 10);
    } else if (sel == 0x01) {
        spi_set_and_confirm(0x06, 0x86, 0x30, 0x01);
        HAL_set_32bit_reg(IMAGE_METADATA_BASE_ADDR, SENSOR_BIT_DEPTH, 12);
    } else if (sel == 0x02) {
        spi_set_and_confirm(0x06, 0x86, 0x30, 0x02);
        HAL_set_32bit_reg(IMAGE_METADATA_BASE_ADDR, SENSOR_BIT_DEPTH, 8);
    } else if (sel == 0x03) {
        spi_set_and_confirm(0x06, 0x86, 0x30, 0x03);
        HAL_set_32bit_reg(IMAGE_METADATA_BASE_ADDR, SENSOR_BIT_DEPTH, 0);
    }
}

void set_tout0sel(uint8_t sel)
{   // TOUT0SEL - 0: Low fixed; 1: Exposure period monitoring; Others: Setting prohibited
    spi_set_and_confirm(0x06, 0x86, 0x36, sel);
}

void set_gain_rts(uint8_t sel)
{   // GAIN_RTS - 0: Gain reflect at the frame; 1: Gain reflect at the next frame; Others: Setting prohibited
    if (sel == 0x00) {
        spi_set_and_confirm(0x07, 0x87, 0x02, 0x08);
    } else if (sel == 0x01) {
        spi_set_and_confirm(0x07, 0x87, 0x02, 0x09);
    } else {
        spi_set_and_confirm(0x07, 0x87, 0x02, 0xFF);
    }
}

void set_gain(uint16_t sel)
{   // GAIN
    spi_set_and_confirm(0x07, 0x87, 0x14, sel);
    spi_set_and_confirm(0x07, 0x87, 0x15, (sel >> 8));
    HAL_set_32bit_reg(IMAGE_METADATA_BASE_ADDR, SENSOR_GAIN, sel);
}

void set_blklevel(uint16_t sel)
{   // BLKLEVEL
    spi_set_and_confirm(0x07, 0x87, 0xB4, sel);
    spi_set_and_confirm(0x07, 0x87, 0xB5, (sel >> 8));
    HAL_set_32bit_reg(IMAGE_METADATA_BASE_ADDR, SENSOR_BLO, sel);
}

void set_synccode(uint16_t sel)
{   // SYNCCODE
    spi_set_and_confirm(0x0B, 0x8B, 0x30, sel);
    spi_set_and_confirm(0x0B, 0x8B, 0x31, (sel >> 8));
}

void set_crc_err_mode(uint8_t sel)
{   // CRC_ECC_MODE - 0: Without CRC/ECC; 1: With CRC; 2: With ECC (parity 2 byte); 3: With ECC (parity 4 byte)
    if (sel == 0x00) {
        spi_set_and_confirm(0x0C, 0x8C, 0x00, 0xC1);
    } else if (sel == 0x01) {
        spi_set_and_confirm(0x0C, 0x8C, 0x00, 0xD1);
    } else if (sel == 0x02) {
        spi_set_and_confirm(0x0C, 0x8C, 0x00, 0xE1);
    } else if (sel == 0x03) {
        spi_set_and_confirm(0x0C, 0x8C, 0x00, 0xF1);
    }
}

void set_pattern_gen(void)
{
    // Test pattern
    // spi_set_and_confirm(0x07, 0x51, 0x0A);  // Pattern Generator mode
    spi_set_and_confirm(
        0x07, 0x87, 0x50, 0x05);  // Pattern Generator ON (05)/ OFF (02)
    spi_set_and_confirm(0x07, 0x87, 0x51, 0x03);  // Pattern Generator mode
    spi_set_and_confirm(0x07, 0x87, 0x5C, 0x00);  // PGDATA1
    spi_set_and_confirm(0x07, 0x87, 0x5D, 0x00);  // PGDATA1
    spi_set_and_confirm(0x07, 0x87, 0x5E, 0x00);  // PGDATA2
    spi_set_and_confirm(0x07, 0x87, 0x5F, 0x00);  // PGDATA2
}

void SysTick_Handler(void)
{
    g_state = (~g_state) & 0x01;

    if (timerdone == 1) {
        g_10ms_count1 += 1;
        if (g_ms_count <= g_10ms_count1)
            timerdone = 0;
    }

    if (rx_tmr_done == 1) {
        rx_ms_count1 += 1;
        if (rx_ms_count1 >= rx_ms_count) {
            rx_tmr_done  = 0;
            process_data = 1;
        }
    }
}

void msdelay(uint32_t tms)
{
    g_ms_count    = tms;
    g_10ms_count1 = 0;
    timerdone     = 1;
    while (timerdone != 0) {
        //busy wait loop
    }
}
