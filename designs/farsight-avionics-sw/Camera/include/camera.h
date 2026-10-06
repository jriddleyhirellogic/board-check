/*
 * camera.h
 *
 *  Created on: Dec 4, 2025
 *      Author: iboard
 */

#ifndef CAMERA_H_
#define CAMERA_H_

#include "core_gpio.h"
#include "core_spi.h"
#include "misc_math.h"
#include "pps.h"
#include "errors.h"

typedef enum
{
    CAMERA_DEPTH_EIGHT_BITS,
    CAMERA_DEPTH_TEN_BITS,
    CAMERA_DEPTH_TWELVE_BITS
}Camera_Bit_Depth_t;

/**
 * @enum Trigger_Mode_t
 * @brief Values accepted by TRIG_MODE_SYS_REG.
 * These are written verbatim into the XTRIG_SRC_SEL register of the capture trigger IP, so the
 * numbering is fixed by the FPGA and cannot be reassigned.
 */
typedef enum
{
    SW_TRIGGER  = 0,  /**< Capture starts on a START_ACQ_SYS_CMD */
    PPS_TRIGGER = 1,  /**< Capture starts at the scheduled time on the PPS disciplined clock */
    EXT_TRIGGER = 2   /**< Capture starts on the rising edge of the external trigger pin */
}Trigger_Mode_t;

/**
 * @enum Sensor_Status_t
 * @brief Values reported by SENSOR_STAT_SYS_REG
 */
typedef enum
{
    SENSOR_DISABLED = 0,  /**< Sensor is unpowered and cannot initiate an acquisition */
    SENSOR_STANDBY  = 1,  /**< Sensor is powered and configurable but is not ready to image */
    SENSOR_ARMED    = 2   /**< Sensor is out of standby and capable of capturing images */
}Sensor_Status_t;

/* SENSOR_FRM_MOD_SYS_REG bitfields */
#define FRM_MOD_HORIZ_INVERSION_MASK  (1u << 0)
#define FRM_MOD_VERT_INVERSION_MASK   (1u << 1)
#define FRM_MOD_READOUT_MODE_SHIFT    2
#define FRM_MOD_READOUT_MODE_MASK     (3u << FRM_MOD_READOUT_MODE_SHIFT)
#define FRM_MOD_RESERVED_MASK         (~0xFu)

/**
 * @enum Readout_Mode_t
 * @brief READOUT_MODE field of SENSOR_FRM_MOD_SYS_REG. These are the ICD values, which are
 *        not the same numbering as the sensor HVMODE setting they are translated to.
 */
typedef enum
{
    READOUT_ALL_PIXEL      = 0,  /**< 4504x4504 all-pixel scan */
    READOUT_2X2_BINNING    = 1,  /**< 2252x2252 2x2 binning */
    READOUT_HALF_SUBSAMPLE = 2,  /**< 2252x2252 1/2 subsampling */
    READOUT_PROHIBITED     = 3   /**< Setting prohibited by the sensor */
}Readout_Mode_t;

/* SENSOR_GAIN_SYS_REG limits, in tenths of a dB */
#define SENSOR_GAIN_MIN   0
#define SENSOR_GAIN_MAX   480

/* SENSOR_BLO_SYS_REG limits, in LSBs of the 12 bit pixel range */
#define SENSOR_BLO_MIN    0
#define SENSOR_BLO_MAX    4095

/* SENSOR_EXPO_USEC_SYS_REG limits, in microseconds. The register itself is 22 bits wide, and the
 * exposure sits one pedestal above whatever pulse is programmed. The xtrig_low_time port of the
 * trigger IP is a 28 bit count of 50 MHz cycles, which spans more than the register can ask for,
 * so the register width is what bounds the exposure.
 *
 * The two limits use opposite line periods so that an accepted exposure can be honoured no matter
 * which DDR4 buffer the burst ends up in: the minimum takes the larger 8GB pedestal, since that
 * is the case needing the longest pulse to reach a given exposure, and the maximum takes the
 * smaller 16GB pedestal for the same reason.
 */
#define XTRIG_LOW_TIME_CYCLES_MAX ( ( 1u << 28 ) - 1u )
#define SENSOR_EXPO_USEC_MIN   ( EXPOSURE_PEDESTAL_USEC( DDR4_8GB_HMAX ) + 1u )
#define SENSOR_EXPO_USEC_MAX   ( ( 1u << 22 ) - 1u )

#include "eth.h"

typedef struct
{
    uint16_t dst_port;
    uint16_t src_port;
    uint32_t dst_ip;
    uint32_t src_ip;
    uint16_t dst_mac_msb;
    uint32_t dst_mac_lsb;
    uint16_t src_mac_msb;
    uint32_t src_mac_lsb;
}Network_Addresses_t;

typedef struct
{
    gpio_instance_t pwr_ctrl;
    gpio_instance_t pwr_stat;
    gpio_instance_t eth1_ctrl;
    gpio_instance_t eth1_stat;
    gpio_instance_t cam_ctrl;
    gpio_instance_t cam_stat;
    //gpio_instance_t cam_mux;
    gpio_instance_t dbg_ctrl;
    gpio_instance_t eth_pcie_mux;
    gpio_instance_t ddr4_16gb_async_rst;
    gpio_instance_t ddr4_8gb_async_rst;
    spi_instance_t  spi;
    eth_core_regs_t eth_core_1_regs;
    Network_Addresses_t addresses;
}Camera_Instance_t;

#define SPI_FIFO_DEPTH 32

// Total number of lines per frame
#define LINES_PER_FRAME 4581

// 106 + 1 = 107 beats of 512
// 107 * 512 = 54784 bits = 6848 bytes
#define HORIZ_WIDTH_BYTE 6784

// ceil(4512*12)/256 for 8GB DDR4
#define HORIZ_WIDTH_BEAT_8GB 212

// ceil(4512*12)/512 for 16GB DDR4
#define HORIZ_WIDTH_BEAT_16GB 106

#define XTRIG_LOW_TIME_USEC 1000
#define FRAME_CAPTURE_TIME_USEC 20000
#define DDR4_8GB_FRAME_CAPTURE_AMOUNT 256
#define DDR4_16GB_FRAME_CAPTURE_AMOUNT 512
#define TOTAL_FRAME_CAPTURE_AMOUNT  (DDR4_16GB_FRAME_CAPTURE_AMOUNT + DDR4_8GB_FRAME_CAPTURE_AMOUNT)

/* The two DDR4 devices sustain different write bandwidths, so the sensor line period (HMAX) has
 * to be slowed down when a burst spills over into the smaller 8GB buffer. Each HMAX gives a
 * different maximum frame rate, and hence a different minimum frame period.
 */
#define DDR4_16GB_HMAX 0x00E3u
#define DDR4_8GB_HMAX  0x00F7u

/* The frame rate is set by the line period, so it is derived from HMAX rather than written down
 * separately. The sensor runs at 75.9 fps at its default HMAX of 0xD1, and the rate scales
 * inversely with the line period:
 *
 *     fps = SENSOR_DEFAULT_FPS * SENSOR_DEFAULT_HMAX / hmax
 *
 * The frame period is the reciprocal of that. Both are worked out in one integer expression so
 * an intermediate frame rate is never rounded before it is inverted, which is what made the
 * hand-written constants drift from the HMAX they were supposed to match.
 *
 * The rate is kept in hundredths of a frame per second, since 75.9 cannot be held as an integer.
 */
#define SENSOR_DEFAULT_HMAX       0x00D1u
#define SENSOR_DEFAULT_FPS_CENTI  7590u

/** Frame rate at a given line period, in hundredths of a frame per second */
#define FPS_CENTI(hmax)                                                          \
    ( (uint32_t)( ( (uint64_t)SENSOR_DEFAULT_HMAX * SENSOR_DEFAULT_FPS_CENTI     \
                    + (uint32_t)(hmax) / 2u )                                    \
                  / (uint32_t)(hmax) ) )

/** Shortest frame period the sensor can sustain at a given line period, in usec. This is
 *  1e6 / fps expanded out, so the frame rate is never rounded on the way through. */
#define FRAME_TIME_USEC(hmax)                                                    \
    ( (uint32_t)( ( (uint64_t)(uint32_t)(hmax) * 1000000u * 100u                 \
                    + ( (uint64_t)SENSOR_DEFAULT_HMAX                            \
                        * SENSOR_DEFAULT_FPS_CENTI ) / 2u )                      \
                  / ( (uint64_t)SENSOR_DEFAULT_HMAX * SENSOR_DEFAULT_FPS_CENTI ) ) )

#define DDR4_16GB_FPS_CENTI  FPS_CENTI( DDR4_16GB_HMAX )
#define DDR4_8GB_FPS_CENTI   FPS_CENTI( DDR4_8GB_HMAX )
#define DDR4_16GB_FRAME_TIME FRAME_TIME_USEC( DDR4_16GB_HMAX )
#define DDR4_8GB_FRAME_TIME  FRAME_TIME_USEC( DDR4_8GB_HMAX )

/** FRAME_CAPTURE_TIME_SYS_REG upper limit. The frame_capture_time port of the trigger IP is
 *  24 bits wide. */
#define FRAME_CAPTURE_TIME_USEC_MAX ( ( 1u << 24 ) - 1u )

/** CAPTURE_TIME_MSEC_SYS_REG upper limit. It is the sub-second part of the scheduled capture
 *  time, so a whole second belongs in CAPTURE_TIME_SEC_SYS_REG instead. */
#define CAPTURE_TIME_MSEC_MAX 999u

/* The sensor does not expose the shutter directly. The exposure it actually integrates is the
 * XTRIG low pulse extended by the gain and reset settling time GMRWT, measured in line periods,
 * plus a small fixed delay:
 *
 *     exposure = XTRIG low time + GMRWT * HMAX / 74.25 MHz + 1.665 usec
 *
 * The 1.665 usec was measured on TOUT and replaces the 2.46 usec given in the datasheet, which is
 * quoted at a different INCK. Software inverts this so SENSOR_EXPO_USEC_SYS_REG is the exposure
 * the sensor really integrates, not the width of the trigger pulse.
 *
 * The HMAX line period is referenced to 74.25 MHz regardless of the INCKSEL setting.
 */
#define SENSOR_GMRWT              12u
#define SENSOR_CLK_KHZ            74250u
#define XTRIG_FIXED_DELAY_NSEC    1665u

/* The trigger IP counts its own 50 MHz clock, so xtrig_low_time is programmed in 20 nsec cycles
 * rather than in whole microseconds. The pulse width is therefore worked out in nanoseconds and
 * converted at the end, which keeps the sub-microsecond part of the pedestal instead of rounding
 * it away.
 */
#define TRIG_CLK_MHZ              50u
#define TRIG_CYCLE_NSEC           ( 1000u / TRIG_CLK_MHZ )

/** Nanoseconds to trigger clock cycles, rounded to the nearest cycle */
#define NSEC_TO_TRIG_CYCLES(nsec) ( ( (uint32_t)(nsec) + TRIG_CYCLE_NSEC / 2u ) / TRIG_CYCLE_NSEC )

/** Amount by which the sensor exposure exceeds the XTRIG low pulse width, in nsec */
#define EXPOSURE_PEDESTAL_NSEC(hmax)                                             \
    ( (uint32_t)( ( (uint64_t)SENSOR_GMRWT * (uint32_t)(hmax) * 1000000u )       \
                  / SENSOR_CLK_KHZ ) + XTRIG_FIXED_DELAY_NSEC )

/** As above, rounded to whole usec. Only for the microsecond domain register limits. */
#define EXPOSURE_PEDESTAL_USEC(hmax)                                             \
    ( ( EXPOSURE_PEDESTAL_NSEC(hmax) + 500u ) / 1000u )

void v_Init_Camera( Camera_Instance_t *instance );
void init_eth1(eth_core_regs_t *p_eth_core_1_regs );
void configure_udp1(void);
void configure_udp(uint32_t base_addr,
                   uint16_t dst_port,
                   uint16_t src_port,
                   uint32_t dst_ip,
                   uint32_t src_ip,
                   uint16_t dst_mac_msb,
                   uint32_t dst_mac_lsb,
                   uint16_t src_mac_msb,
                   uint32_t src_mac_lsb);

void configure_dma_write(uint32_t base_addr, uint32_t h_size_byte);
void configure_udp_dmactrl(uint32_t base_addr,
                           uint32_t v_size_line,
                           uint32_t h_size_byte,
                           uint32_t h_size_beat);
void cam_reset(Camera_Instance_t *instance);
void init_slvsec( Camera_Instance_t *camera_instance);
void configure_trig1(void);
void configure_trig(uint32_t base_addr,
                    uint32_t xtrig_low_time_cycles,
                    uint32_t frame_capture_time,
                    uint32_t frame_capture_amount,
                    uint32_t xtrig_src_sel,
                    uint32_t scheduler_time_sec,
                    uint32_t scheduler_time_msec);
void set_read_mux(uint32_t base_addr, uint32_t sel);
void v_Enable_Camera_Power(Camera_Instance_t *instance, uint8_t b_Enable );
void set_standby_and_master_mode(uint8_t sel);
uint8_t u8_Get_Sensor_Status(void);
void v_Apply_Frame_Mode(void);
void v_Apply_Bit_Depth(void);
void v_Apply_Gain(void);
void v_Apply_Black_Level(void);
void v_Apply_Pattern_Gen(void);
void v_Reset_Camera_Buffer(void);
void v_Set_Line_Period( uint16_t u16_HMAX );
uint32_t u32_Min_Frame_Time_usec(void);
uint32_t u32_Current_Line_Period(void);
uint32_t u32_Frames_Stored( uint32_t u32_DMA_Base_Addr,
                            uint32_t u32_Full_Offset,
                            uint32_t u32_Capacity );
uint32_t u32_Total_Frames_Stored(void);
void xfer_frame_via_udp(uint32_t base_addr, uint32_t frame_index);
void get_metadata(uint32_t base_addr, uint32_t frame_index, uint32_t *metadata_out);
void trig_capture(void);
void reset_udp_dmactrl(uint32_t base_addr);
void v_Clear_Read_Req( uint32_t u32_Base_Address );
void update_network_addresses(void);
void cam_mux_clear(void);
void reset_dma_write(uint32_t base_addr);
uint8_t read_cam_temp(void);
uint32_t read_fpga_temp(void);
uint32_t check_fault(void);
void clear_fault(void);
void v_DDR4_Async_Reset(Camera_Instance_t *instance);
void v_Enable_Camera_IRQ(uint8_t b_Enable);
void v_Set_Capture_Timing( uint32_t  u32_Xtrig_Low_Time,  uint32_t u32_Frame_Capture_Time );
void v_Set_Scheduler_Time( uint32_t u32_Time_Sec, uint32_t u32_Time_msec );
void v_Set_Capture_Amount(uint32_t u32_Frame_Capture_Amount);
uint8_t b_Is_Capture_Busy(void);
void v_Enable_UDP_IRQ(uint8_t b_Enable);
uint8_t b_Time_Diff_OK( Sys_Time_t *t1, Sys_Time_t *t2 );
void v_Fetch_Metadata( uint32_t u32_Frame_Index, uint32_t *pu32_Buffer );


#endif /* CAMERA_H_ */
