/*
 * camera.c
 *
 *  Created on: Dec 4, 2025
 *      Author: iboard
 */

#include <stdint.h>
#include <assert.h>
#include "FreeRTOSConfig.h"
#include "FreeRTOS.h"
#include "task.h"
#include "event_groups.h"
#include "mem_map.h"
#include "config.h"
#include "lvdt.h"
#include "timer.h"
#include "core_spi.h"
#include "misc.h"
#include "eth.h"
#include "register.h"
#include "udp_core_reg.h"
#include "dma_write_reg.h"
#include "udp_dmactrl_reg.h"
#include "util.h"
#include "cam_trig.h"
#include "cam_mux.h"
#include "camera.h"
#include "gpio_pin_def.h"
#include "junc_temp.h"
#include "cam_fault_detector.h"
#include "events.h"
#include "camera_task.h"
#include "camera_states.h"
#include "image_metadata.h"
#include "mem_map.h"
#include "focus.h"

void reset_dma_write(uint32_t base_addr);

// Cached sensor status. The sensor is only reachable over SPI, which blocks, so the
// state is recorded whenever software changes it and reported by u8_Get_Sensor_Status().
static uint8_t b_Sensor_Powered = 0;
uint8_t b_Sensor_In_Standby = 1;

// Line period currently programmed into the sensor. Capture starts on the faster 16GB device and
// is slowed once a burst spills into the 8GB one, which changes the shortest frame period that
// can be sustained. Tracked here so register writes can be validated without touching SPI.
static uint16_t u16_Current_HMAX = DDR4_16GB_HMAX;

/**
 * @fn uint8_t u8_Get_Sensor_Status(void)
 * @brief Composes the value reported by SENSOR_STAT_SYS_REG.
 * @return SENSOR_DISABLED, SENSOR_STANDBY or SENSOR_ARMED
 */
uint8_t u8_Get_Sensor_Status(void)
{
    if( !b_Sensor_Powered )
        return SENSOR_DISABLED;

    return b_Sensor_In_Standby ? SENSOR_STANDBY : SENSOR_ARMED;
}

/**
 * @fn uint8_t u8_Readout_Mode_To_HVMODE(uint32_t)
 * @brief Translates the READOUT_MODE field of SENSOR_FRM_MOD_SYS_REG into a sensor HVMODE value.
 *
 * The ICD and the sensor number these modes differently: the ICD lists binning as 1 and
 * subsampling as 2, while the sensor HVMODE setting is 1 for subsampling and 2 for FD binning.
 * Mode 3 is prohibited and is rejected by Set_Sensor_Frame_Mode(), so it cannot be stored here.
 *
 * @param u32_Frm_Mod Raw SENSOR_FRM_MOD_SYS_REG value
 * @return The value to pass to set_hvmode()
 */
static uint8_t u8_Readout_Mode_To_HVMODE( uint32_t u32_Frm_Mod )
{
    switch( ( u32_Frm_Mod & FRM_MOD_READOUT_MODE_MASK ) >> FRM_MOD_READOUT_MODE_SHIFT )
    {
    case READOUT_2X2_BINNING:
        return 0x02;   // HVMODE: FD binning

    case READOUT_HALF_SUBSAMPLE:
        return 0x01;   // HVMODE: 1/2 subsampling

    default:
        return 0x00;   // HVMODE: all-pixel scan
    }
}

/**
 * @fn uint8_t u8_Inversion_To_Reverse(uint32_t)
 * @brief Translates the inversion bits of SENSOR_FRM_MOD_SYS_REG into a sensor REVERSE value.
 *
 * The two are bit swapped: the ICD places HORIZ_INVERSION at bit 0 and VERT_INVERSION at bit 1,
 * while the sensor expects VREVERSE at bit 0 and HREVERSE at bit 1.
 *
 * @param u32_Frm_Mod Raw SENSOR_FRM_MOD_SYS_REG value
 * @return The value to pass to set_vreverse_and_hreverse()
 */
static uint8_t u8_Inversion_To_Reverse( uint32_t u32_Frm_Mod )
{
    uint8_t u8_Reverse = 0;

    if( u32_Frm_Mod & FRM_MOD_VERT_INVERSION_MASK )
        u8_Reverse |= (1u << 0);   // VREVERSE

    if( u32_Frm_Mod & FRM_MOD_HORIZ_INVERSION_MASK )
        u8_Reverse |= (1u << 1);   // HREVERSE

    return u8_Reverse;
}

/**
 * @fn void v_Apply_Frame_Mode(void)
 * @brief Pushes the current SENSOR_FRM_MOD_SYS_REG value out to the sensor.
 *
 * The sensor is configured over SPI, which blocks, so this cannot run from the register write
 * callback. It is called from init_slvsec() when the camera powers up and again whenever the
 * register changes while the camera sits in CAMERA_IDLE_STATE.
 *
 * @note The sensor must be powered and in standby.
 */
void v_Apply_Frame_Mode(void)
{
    uint32_t u32_Frm_Mod;

    Read_Register( SENSOR_FRM_MOD_SYS_REG, &u32_Frm_Mod );
    set_hvmode( u8_Readout_Mode_To_HVMODE( u32_Frm_Mod ) );
    set_vreverse_and_hreverse( u8_Inversion_To_Reverse( u32_Frm_Mod ) );
}

/**
 * @fn uint8_t u8_Bit_Depth_To_Sensor(uint32_t)
 * @brief Translates SENSOR_BIT_DEPTH_SYS_REG into a sensor ADBIT/ODBIT value.
 *
 * The ICD and the sensor number these differently: the ICD counts up from 8 bits, while the
 * sensor uses 0 for 10 bit, 1 for 12 bit and 2 for 8 bit.
 *
 * @param u32_Bit_Depth Raw SENSOR_BIT_DEPTH_SYS_REG value
 * @return The value to pass to set_adbit() and set_odbit()
 */
static uint8_t u8_Bit_Depth_To_Sensor( uint32_t u32_Bit_Depth )
{
    switch( u32_Bit_Depth )
    {
    case CAMERA_DEPTH_EIGHT_BITS:
        return 0x02;

    case CAMERA_DEPTH_TEN_BITS:
        return 0x00;

    default:
        return 0x01;   // 12 bit
    }
}

/**
 * @fn uint8_t u8_Current_Sensor_Bit_Depth(void)
 * @brief Reads SENSOR_BIT_DEPTH_SYS_REG and translates it to a sensor ADBIT/ODBIT value.
 * @return The value to pass to set_adbit() and set_odbit()
 */
static uint8_t u8_Current_Sensor_Bit_Depth(void)
{
    uint32_t u32_Bit_Depth;

    Read_Register( SENSOR_BIT_DEPTH_SYS_REG, &u32_Bit_Depth );
    return u8_Bit_Depth_To_Sensor( u32_Bit_Depth );
}

/**
 * @fn void v_Apply_Bit_Depth(void)
 * @brief Pushes the current SENSOR_BIT_DEPTH_SYS_REG value out to the sensor.
 *
 * Like v_Apply_Frame_Mode(), this cannot run from the register write callback because the sensor
 * is configured over SPI. It is called from init_slvsec() when the camera powers up and again
 * whenever the register changes while the camera sits in CAMERA_IDLE_STATE.
 *
 * @note The sensor must be powered and in standby.
 */
void v_Apply_Bit_Depth(void)
{
    uint8_t u8_Depth = u8_Current_Sensor_Bit_Depth();

    set_adbit( u8_Depth );
    set_odbit( u8_Depth );
}

/**
 * @fn void v_Apply_Gain(void)
 * @brief Pushes the current SENSOR_GAIN_SYS_REG value out to the sensor.
 *
 * Like v_Apply_Frame_Mode(), this cannot run from the register write callback because the sensor
 * is configured over SPI.
 *
 * @note Unlike the frame mode and bit depth, the sensor accepts a gain change at any time and
 *       does not have to be in standby.
 */
void v_Apply_Gain(void)
{
    uint32_t u32_Gain;

    Read_Register( SENSOR_GAIN_SYS_REG, &u32_Gain );
    set_gain( u32_Gain & 0xFFFF );
}

/**
 * @fn void v_Apply_Black_Level(void)
 * @brief Pushes the current SENSOR_BLO_SYS_REG value out to the sensor.
 *
 * Like v_Apply_Gain(), this cannot run from the register write callback because the sensor is
 * configured over SPI, and the sensor accepts the change at any time without needing standby.
 */
void v_Apply_Black_Level(void)
{
    uint32_t u32_Offset;

    Read_Register( SENSOR_BLO_SYS_REG, &u32_Offset );
    set_blklevel( u32_Offset & 0xFFFF );
}

/**
 * @fn void v_Apply_Pattern_Gen(void)
 * @brief Pushes the current EN_PATTERN_GEN_REG value out to the sensor.
 *
 * Like v_Apply_Gain(), this cannot run from the register write callback because the sensor is
 * configured over SPI.
 *
 * @note The pattern generator registers are left completely untouched until the register is
 *       enabled for the first time, so the default configuration is unchanged from a build
 *       without this register.
 */
void v_Apply_Pattern_Gen(void)
{
    static uint8_t b_Ever_Enabled = 0;
    uint32_t u32_Enable;

    Read_Register( EN_PATTERN_GEN_REG, &u32_Enable );

    if( u32_Enable == 0u && !b_Ever_Enabled )
    {
        return;
    }

    b_Ever_Enabled = 1;
    set_pattern_gen( u32_Enable ? 1u : 0u );
}

void v_Init_Camera( Camera_Instance_t *instance )
{

    GPIO_init( &instance->pwr_ctrl,   GPO_HK_PWR_BASE_ADDR,    GPIO_APB_32_BITS_BUS);
    GPIO_init( &instance->pwr_stat,   GPI_HK_STATUS_BASE_ADDR, GPIO_APB_32_BITS_BUS);
    GPIO_init( &instance->eth1_ctrl,  ETH1_CTRL_BASE_ADDR,     GPIO_APB_32_BITS_BUS);
    GPIO_init( &instance->eth1_stat,  ETH1_STAT_BASE_ADDR,     GPIO_APB_32_BITS_BUS);
    GPIO_init( &instance->cam_ctrl,   GPO_CAM_BASE_ADDR,       GPIO_APB_32_BITS_BUS);
    // GPIO_init( &instance->cam_stat,   GPI_CAM_BASE_ADDR,       GPIO_APB_32_BITS_BUS);
    GPIO_init( &instance->dbg_ctrl,   DBG_GPIO_BASE_ADDR,      GPIO_APB_32_BITS_BUS);
    GPIO_init( &instance->eth_pcie_mux, ETH_PCIE_MUX_BASE_ADDR, GPIO_APB_32_BITS_BUS);
    GPIO_init( &instance->ddr4_16gb_async_rst, DDR4_16GB_ASYNC_RST_BASE_ADDR, GPIO_APB_32_BITS_BUS);
    GPIO_init( &instance->ddr4_8gb_async_rst, DDR4_8GB_ASYNC_RST_BASE_ADDR, GPIO_APB_32_BITS_BUS);

    // SPI
    SPI_init( &instance->spi, SLVSEC_SPI_BASE_ADDR, SPI_FIFO_DEPTH );
    SPI_configure_master_mode( &instance->spi );
    v_Set_Camera_SPI_Instance( &instance->spi );
    v_Set_Camera_Instance( instance );

#ifdef USE_ETH1
    //--------------------------------------------------------------------------
    // Eth1 Phy POWER ON
    //--------------------------------------------------------------------------
    GPIO_set_output(&instance->pwr_ctrl, ETH1_PWR_EN, 1);
    uint32_t eth1_pwr_status = (GPIO_get_inputs(&instance->pwr_stat) >> 6) & 1;

    vTaskDelay(20);

    GPIO_set_output(&instance->eth1_ctrl, ETH1_PHY_RST_N, 1);
    GPIO_set_output(&instance->eth1_ctrl, ETH1_CTRL_COMMA_MODE, 0);
    GPIO_set_output(&instance->eth1_ctrl, ETH1_CTRL_CLK_SQUELCH_IN, 1);

#endif

    // Camera and oscillator power up are reserved to state machine

    // @todo - are both eth1 and eth2 used or just eth1?

//     //--------------------------------------------------------------------------
//     // Eth config
//     //--------------------------------------------------------------------------

    init_eth1( &instance->eth_core_1_regs );

     //--------------------------------------------------------------------------
     // Configure UDP cores - sets IP and MAC addresses of board and flight computer
     // Reads network params from registers, can be called later through TMTC interface.
     //--------------------------------------------------------------------------
     update_network_addresses();

     //--------------------------------------------------------------------------
     // Configure DMA Write
     //--------------------------------------------------------------------------
     v_Reset_Camera_Buffer();

     configure_dma_write(DMA_WRITE_DDR4_8GB_BASE_ADDR, HORIZ_WIDTH_BYTE);
     configure_dma_write(DMA_WRITE_DDR4_16GB_BASE_ADDR, HORIZ_WIDTH_BYTE);

     //--------------------------------------------------------------------------
     // Configure DMA Read
     //--------------------------------------------------------------------------
     reset_udp_dmactrl(UDP_DMACTRL_DDR4_8GB_BASE_ADDR);
     reset_udp_dmactrl(UDP_DMACTRL_DDR4_16GB_BASE_ADDR);

     configure_udp_dmactrl(UDP_DMACTRL_DDR4_8GB_BASE_ADDR,
                           LINES_PER_FRAME,
                           HORIZ_WIDTH_BYTE,
                           HORIZ_WIDTH_BEAT_8GB);

     configure_udp_dmactrl(UDP_DMACTRL_DDR4_16GB_BASE_ADDR,
                           LINES_PER_FRAME,
                           HORIZ_WIDTH_BYTE,
                           HORIZ_WIDTH_BEAT_16GB );
}

void v_DDR4_Async_Reset( Camera_Instance_t *instance )
{
    GPIO_set_output(&instance->ddr4_8gb_async_rst, ASYNC_DDR4_RST, 1u);
    GPIO_set_output(&instance->ddr4_16gb_async_rst, ASYNC_DDR4_RST, 1u);
    vTaskDelay(5);
    GPIO_set_output(&instance->ddr4_8gb_async_rst, ASYNC_DDR4_RST, 0u);
    GPIO_set_output(&instance->ddr4_16gb_async_rst, ASYNC_DDR4_RST, 0u);
    vTaskDelay(5);
}

void reset_dma_write(uint32_t base_addr)
{
    HAL_set_32bit_reg(base_addr, CLEAR_INDEX, 1);
    vTaskDelay(10);
    HAL_set_32bit_reg(base_addr, CLEAR_INDEX, 0);
}

void cam_mux_clear(void)
{
    uint32_t reg32_status = 0;

    HAL_set_32bit_reg(CAM_MUX_BASE_ADDR, MUX_CLEAR, 1);
    vTaskDelay(10);
    reg32_status = HAL_get_32bit_reg(CAM_MUX_BASE_ADDR, MUX_CLEAR);
}

void v_Enable_Camera_Power( Camera_Instance_t *instance, uint8_t b_Enable )
{
    b_Sensor_Powered = b_Enable ? 1 : 0;
    if ( b_Enable == 0 ) {
        v_Invalidate_HMAX_Band();

        GPIO_set_output(&instance->pwr_ctrl, CAM_OSC_EN, 0u);
        GPIO_set_output(&instance->cam_ctrl, CAM_XCLR_N, 0u);

        vTaskDelay(5);

        GPIO_set_output(&instance->pwr_ctrl, CAM_PWR_EN, 0u);
        uint32_t cam_pwr_status = (GPIO_get_inputs(&instance->pwr_stat) >> 11) & 1;
    } else {
        GPIO_set_output(&instance->pwr_ctrl, CAM_PWR_EN, 1u);
        uint32_t cam_pwr_status = (GPIO_get_inputs(&instance->pwr_stat) >> 11) & 1;

        vTaskDelay(5);

        GPIO_set_output(&instance->cam_ctrl, CAM_XCLR_N, 1u);
        
        vTaskDelay(5);

        GPIO_set_output(&instance->pwr_ctrl, CAM_OSC_EN, 1u);
    }
}

void xfer_frame_via_udp(uint32_t base_addr, uint32_t frame_index)
{
    HAL_set_32bit_reg(base_addr, UDP_METADATA_SEL, 0);

    // Make sure the register is cleared
    HAL_set_32bit_reg(base_addr, FRAME_READ_REQ, 0);

    HAL_set_32bit_reg(base_addr, DMA_READ_FRAME_INDEX, frame_index);
    uint32_t prev_read_count = HAL_get_32bit_reg(base_addr, FRAME_READ_DONE_COUNT);

    // Send the read request
    HAL_set_32bit_reg(base_addr, FRAME_READ_REQ, 1);

//    while (HAL_get_32bit_reg(base_addr, FRAME_READ_DONE_COUNT)
//           == prev_read_count) {}

    // Clear the register
    HAL_set_32bit_reg(base_addr, FRAME_READ_REQ, 0);
}

void get_metadata(uint32_t base_addr, uint32_t frame_index, uint32_t *metadata_out)
{
    HAL_set_32bit_reg(base_addr, UDP_METADATA_SEL, 1);

    // Make sure the register is cleared
    HAL_set_32bit_reg(base_addr, FRAME_READ_REQ, 0);

    HAL_set_32bit_reg(base_addr, DMA_READ_FRAME_INDEX, frame_index);

    // Send the read request
    HAL_set_32bit_reg(base_addr, FRAME_READ_REQ, 1);

    vTaskDelay(5);

    HAL_set_32bit_reg(base_addr, FRAME_READ_REQ, 0);
    HAL_set_32bit_reg(base_addr, UDP_METADATA_SEL, 0);

    volatile uint32_t *regs = (volatile uint32_t *)(base_addr + METADATA_DATA_BASE_REG_OFFSET);

    for (uint32_t i = 0u; i < METADATA_WORD_COUNT; i++) {
        metadata_out[i] = regs[i];
    }
}

void v_Fetch_Metadata( uint32_t u32_Frame_Index, uint32_t *pu32_Buffer )
{
uint32_t base_addr;

    // Ajust index for which buffer it resides in
    if( u32_Frame_Index < DDR4_16GB_FRAME_CAPTURE_AMOUNT )   // 16GB buffer
    {
        base_addr = UDP_DMACTRL_DDR4_16GB_BASE_ADDR;
    }
    else                                               // 8GB buffer
    {
        base_addr = UDP_DMACTRL_DDR4_8GB_BASE_ADDR;
        u32_Frame_Index = u32_Frame_Index - DDR4_16GB_FRAME_CAPTURE_AMOUNT;
    }

    get_metadata( base_addr, u32_Frame_Index, pu32_Buffer );
}

void v_Clear_Read_Req( uint32_t u32_Base_Address )
{
    HAL_set_32bit_reg( u32_Base_Address , FRAME_READ_REQ, 0);
    HAL_set_32bit_reg( u32_Base_Address , FRAME_READ_REQ, 1);
    HAL_set_32bit_reg( u32_Base_Address , FRAME_READ_REQ, 0);
}

void init_eth1(eth_core_regs_t *p_eth_core_1_regs )
{
    // Initialize register pointers for each core
    eth_core_init_regs(p_eth_core_1_regs, ETH1_MAC_BASE_ADDR);

    // Initialize eth1
    tse_init( p_eth_core_1_regs );
    phy_init( p_eth_core_1_regs );
    phy_advertise( p_eth_core_1_regs );
    phy_autonegotiation( p_eth_core_1_regs );
}


void update_network_addresses(void)
{
uint32_t base_addr = UDP_TX_BASE_ADDR;
uint16_t dst_port;
uint16_t src_port;
uint32_t dst_ip;
uint32_t src_ip;
uint16_t dst_mac_msb;
uint32_t dst_mac_lsb;
uint16_t src_mac_msb;
uint32_t src_mac_lsb;
uint32_t reg32_status = 0;
Error_Code_t err = NO_ERROR;

     uint32_t u32_Reg_Val;

     // Configure UDP ports
     err = Read_Register( DST_PORT_SYS_REG, &u32_Reg_Val );
     dst_port = u32_Reg_Val & 0xffff;

     err = Read_Register( SRC_PORT_SYS_REG, &u32_Reg_Val );
     src_port = u32_Reg_Val & 0xffff;

    HAL_set_32bit_reg(base_addr, UDP_DST_PORT, dst_port);
    HAL_set_32bit_reg(base_addr, UDP_SRC_PORT, src_port);

    // Configure IP addresses
    err = Read_Register( DST_IP_ADDRESS_SYS_REG, &dst_ip );
    HAL_set_32bit_reg(base_addr, DST_IP, dst_ip);

    err = Read_Register( SRC_IP_ADDRESS_SYS_REG, &src_ip );
    HAL_set_32bit_reg(base_addr, SRC_IP, src_ip);

    // Configure destination MAC address
    err = Read_Register( DST_MAC_ADDRESS_4_5_SYS_REG, &u32_Reg_Val );
    dst_mac_msb = u32_Reg_Val & 0xffff;
    HAL_set_32bit_reg(base_addr, DST_MAC_MSB, dst_mac_msb);

    err = Read_Register( DST_MAC_ADDRESS_0_3_SYS_REG, &dst_mac_lsb );
    HAL_set_32bit_reg(base_addr, DST_MAC_LSB, dst_mac_lsb);

    // Configure source MAC address
    err = Read_Register( SRC_MAC_ADDRESS_4_5_SYS_REG, &u32_Reg_Val );
    src_mac_msb = u32_Reg_Val & 0xffff;
    HAL_set_32bit_reg(base_addr, SRC_MAC_MSB, src_mac_msb);

    err = Read_Register( SRC_MAC_ADDRESS_0_3_SYS_REG, &src_mac_lsb );
    HAL_set_32bit_reg(base_addr, SRC_MAC_LSB, src_mac_lsb);

}

void configure_dma_write(uint32_t base_addr, uint32_t h_size_byte)
{
    uint32_t reg32_status = 0;
    HAL_set_32bit_reg(base_addr, DMA_WRITE_H_SIZE_BYTE, h_size_byte);

    reg32_status = HAL_get_32bit_reg(base_addr, DMA_WRITE_H_SIZE_BYTE);

    (void)reg32_status;
}

void configure_udp_dmactrl(uint32_t base_addr,
                           uint32_t v_size_line,
                           uint32_t h_size_byte,
                           uint32_t h_size_beat)
{
    HAL_set_32bit_reg(base_addr, V_SIZE_LINE, v_size_line);
    HAL_set_32bit_reg(base_addr, H_SIZE_BYTE, h_size_byte);
    HAL_set_32bit_reg(base_addr, H_SIZE_BEAT, h_size_beat);
}

void reset_udp_dmactrl(uint32_t base_addr)
{
    HAL_set_32bit_reg(base_addr, CLEAR_UDP_DMACTRL, 1);
    vTaskDelay(5);

    HAL_set_32bit_reg(base_addr, CLEAR_UDP_DMACTRL, 0);
    vTaskDelay(5);

    HAL_set_32bit_reg(base_addr, RESET_DONE_COUNTER, 1);
    vTaskDelay(5);

    HAL_set_32bit_reg(base_addr, RESET_DONE_COUNTER, 0);
    vTaskDelay(5);
}

// Sets auto-incremement address back to zero - writes
void v_Reset_Camera_Buffer(void)
{
    reset_dma_write(DMA_WRITE_DDR4_8GB_BASE_ADDR);
    reset_dma_write(DMA_WRITE_DDR4_16GB_BASE_ADDR);
    cam_mux_clear();

    // Both buffers are empty again, so capture can restart at the faster line rate of the 16GB
    // device. The buffer can also be reset while the camera is powered down, and the sensor
    // cannot be reached over SPI then - init_slvsec() sets the same value on the way back up.
    u16_Current_HMAX = DDR4_16GB_HMAX;

    if( b_Sensor_Powered )
    {
        set_hmax( DDR4_16GB_HMAX );
    }
}

/* Programs the sensor line period and records it, so that u32_Min_Frame_Time_usec() stays in
 * step with the hardware.
 */
void v_Set_Line_Period( uint16_t u16_HMAX )
{
    set_hmax( u16_HMAX );
    u16_Current_HMAX = u16_HMAX;
}

/* Shortest frame period the sensor can sustain at the line period currently in effect. */
uint32_t u32_Min_Frame_Time_usec(void)
{
    return FRAME_TIME_USEC( u16_Current_HMAX );
}

/* Line period currently programmed into the sensor. */
uint32_t u32_Current_Line_Period(void)
{
    return (uint32_t)u16_Current_HMAX;
}

/**
 * @fn uint32_t u32_Frames_Stored(uint32_t, uint32_t, uint32_t)
 * @brief Number of frames already written into one of the DDR4 buffers.
 * The DMA write index is the position of the last frame written, so the count is one more than
 * the index. Once the buffer reports full the index wraps and is no longer meaningful.
 * @param u32_DMA_Base_Addr Base address of the DMA write block for this buffer
 * @param u32_Full_Offset Offset of the buffer full flag in the camera mux
 * @param u32_Capacity Number of frames this buffer holds
 * @return Frames currently stored
 */
uint32_t u32_Frames_Stored( uint32_t u32_DMA_Base_Addr,
                            uint32_t u32_Full_Offset,
                            uint32_t u32_Capacity )
{
    uint32_t u32_Index;

    if( HW_get_32bit_reg( CAM_MUX_BASE_ADDR + u32_Full_Offset ) )
        return u32_Capacity;

    u32_Index = HAL_get_32bit_reg( u32_DMA_Base_Addr, DMA_WRITE_FRAME_INDEX );

    // The index wraps to the top of the buffer before the full flag is raised
    return ( u32_Index == u32_Capacity - 1u ) ? 0u : u32_Index + 1u;
}

/* Frames held in the frame buffer, counting both DDR4 devices. Capture fills the 16GB device
 * first and spills into the 8GB one, and both are emptied together by v_Reset_Camera_Buffer().
 */
uint32_t u32_Total_Frames_Stored(void)
{
    return u32_Frames_Stored( DMA_WRITE_DDR4_16GB_BASE_ADDR,
                              DDR4_16GB_FULL_REG_OFFSET,
                              DDR4_16GB_FRAME_CAPTURE_AMOUNT )
         + u32_Frames_Stored( DMA_WRITE_DDR4_8GB_BASE_ADDR,
                              DDR4_8GB_FULL_REG_OFFSET,
                              DDR4_8GB_FRAME_CAPTURE_AMOUNT );
}

void cam_reset( Camera_Instance_t *instance )
{

    GPIO_set_output(&instance->cam_ctrl, CAM_XCLR_N, 0u);
    vTaskDelay(1000);

    GPIO_set_output(&instance->cam_ctrl, CAM_XCLR_N, 1u);
    vTaskDelay(1000); // was 1000
}

void init_slvsec( Camera_Instance_t *camera_instance)
{ // @todo some of these values will get replaced by register values
    set_standby_and_master_mode(0x01);
    set_incksel(                0x01);

    v_Apply_Frame_Mode();

    set_vopb_vblk_hwidth(       0x11A0);
    set_finfo_hwidth(           0x11A0);
    set_vmax(                   0x00001244);
    v_Set_Line_Period(          DDR4_16GB_HMAX);
    set_freq(                   0x00);
    set_vndmy(                  0x00);
    set_vndmy_trig(             0x00);
    set_gmrwt(                  SENSOR_GMRWT);
    set_gmtwt(                  0x14);
    set_gaindly(                0x04);
    set_gsdly(                  0x20);
    set_roi_mode(               0x00);
    set_adbit( u8_Current_Sensor_Bit_Depth() );
    set_slvs_en(                0x00);
    set_shs(                    0x00000048);
    set_trig_mode_timing(       0x02, 0x01);
    set_odbit( u8_Current_Sensor_Bit_Depth() );
    set_tout0sel(               0x01);
    set_gain_rts(               0x00);

    v_Apply_Gain();
    v_Apply_Black_Level();
    v_Apply_Pattern_Gen();

    set_synccode(             0x00AA);
    set_crc_err_mode(         0x00);

    // Note: it is necessary to get out of stdby, back in, then out again
    //       This appears to be a quirk of the SLVS-EC Microchip IP
    set_standby_and_master_mode(0x00);
    set_standby_and_master_mode(0x01);
}

void configure_trig(uint32_t base_addr,
                    uint32_t xtrig_low_time_cycles, // XTRIG low pulse width, in 20 nsec cycles
                    uint32_t frame_capture_time,    // overall time to complete
                    uint32_t frame_capture_amount,
                    uint32_t xtrig_src_sel,
                    uint32_t scheduler_time_sec,
                    uint32_t scheduler_time_msec)
{
    uint32_t reg32_status = 0;

    HAL_set_32bit_reg(base_addr, XTRIG_LOW_TIME, xtrig_low_time_cycles);
    reg32_status = HAL_get_32bit_reg(base_addr, XTRIG_LOW_TIME);

    HAL_set_32bit_reg(base_addr, FRAME_CAPTURE_TIME, frame_capture_time); // exposure + frame
    reg32_status = HAL_get_32bit_reg(base_addr, FRAME_CAPTURE_TIME);

    HAL_set_32bit_reg(base_addr, FRAME_CAPTURE_AMOUNT, frame_capture_amount);
    reg32_status = HAL_get_32bit_reg(base_addr, FRAME_CAPTURE_AMOUNT);

    HAL_set_32bit_reg(base_addr, SCHEDULER_TIME_SEC, scheduler_time_sec);
    reg32_status = HAL_get_32bit_reg(base_addr, SCHEDULER_TIME_SEC);

    HAL_set_32bit_reg(base_addr, SCHEDULER_TIME_MSEC, scheduler_time_msec);
    reg32_status = HAL_get_32bit_reg(base_addr, SCHEDULER_TIME_MSEC);

    HAL_set_32bit_reg(base_addr, XTRIG_SRC_SEL, xtrig_src_sel);  // Do this last
    reg32_status = HAL_get_32bit_reg(base_addr, XTRIG_SRC_SEL);
}

uint8_t b_Is_Capture_Busy(void)
{
    uint32_t reg32_status;

    reg32_status = HAL_get_32bit_reg( CAM_TRIG_BASE_ADDR, CAM_TRIG_BUSY );

    return reg32_status;
}

void v_Set_Capture_Timing( uint32_t  u32_Xtrig_Low_Time,  uint32_t u32_Frame_Capture_Time )
{
uint32_t u32_Reg_Status; // mostly for debug

    HAL_set_32bit_reg( CAM_TRIG_BASE_ADDR, XTRIG_LOW_TIME, u32_Xtrig_Low_Time );         // actual exposure 7000F000, 1000
    u32_Reg_Status = HAL_get_32bit_reg( CAM_TRIG_BASE_ADDR, XTRIG_LOW_TIME);

    HAL_set_32bit_reg(CAM_TRIG_BASE_ADDR, FRAME_CAPTURE_TIME, u32_Frame_Capture_Time ); // exposure + frame
    u32_Reg_Status = HAL_get_32bit_reg( CAM_TRIG_BASE_ADDR, FRAME_CAPTURE_TIME);
}

void v_Set_Scheduler_Time( uint32_t u32_Time_Sec, uint32_t u32_Time_msec )
{
    uint32_t u32_Reg_Status;

    HAL_set_32bit_reg(CAM_TRIG_BASE_ADDR, SCHEDULER_TIME_SEC, u32_Time_Sec);
    u32_Reg_Status = HAL_get_32bit_reg( CAM_TRIG_BASE_ADDR, SCHEDULER_TIME_SEC);

    HAL_set_32bit_reg( CAM_TRIG_BASE_ADDR, SCHEDULER_TIME_MSEC, u32_Time_msec);
    u32_Reg_Status = HAL_get_32bit_reg( CAM_TRIG_BASE_ADDR, SCHEDULER_TIME_MSEC);
}

void v_Set_Capture_Amount(uint32_t u32_Frame_Capture_Amount)
{
    uint32_t u32_Reg_Status;

    HAL_set_32bit_reg( CAM_TRIG_BASE_ADDR, FRAME_CAPTURE_AMOUNT, u32_Frame_Capture_Amount );
    u32_Reg_Status = HAL_get_32bit_reg( CAM_TRIG_BASE_ADDR, FRAME_CAPTURE_AMOUNT);
}

void trig_capture(void)
{
    HAL_set_32bit_reg( CAM_TRIG_BASE_ADDR, XTRIG_START, 0);
    HAL_set_32bit_reg( CAM_TRIG_BASE_ADDR, XTRIG_START, 1); // Generates rising edge
//    HAL_set_32bit_reg( CAM_TRIG_BASE_ADDR, XTRIG_START, 0);
}

uint8_t b_Time_Diff_OK(Sys_Time_t *t1, Sys_Time_t *t2  )
{
    uint8_t u8_Ret_Val = 0;

    // Check to make sure that t2 is the future rel to t1
    if( t2->u32_Time_Sec > t1->u32_Time_Sec )
        u8_Ret_Val = 1;
    else if( t2->u32_Time_Sec < t1->u32_Time_Sec)
        u8_Ret_Val = 0;
    else
    {
        if( t2->u32_Time_msec > t1->u32_Time_msec)
            u8_Ret_Val = 1;
        else
            u8_Ret_Val = 0;
    }
    return u8_Ret_Val;
}

void set_read_mux(uint32_t base_addr, uint32_t sel)
{
    HAL_set_32bit_reg(base_addr, UDP_MUX_SEL, sel);
}

// This is a placeholder
uint8_t u8_Calculate_Focus_Distance_microns( uint32_t u32_Distance_m, int32_t *i32_Focus_Distance_microns )
{
    uint8_t u8_Retval = NO_ERROR;

    if( u32_Distance_m < TARGET_LOWER_LIMIT_DISTANCE || u32_Distance_m > TARGET_UPPER_LIMIT_DISTANCE )
    {
        *i32_Focus_Distance_microns = 0;
        u8_Retval = ERR_REG_INVALID_LIMIT;
    }
    else
    {
        *i32_Focus_Distance_microns = i32_Get_Focus_Target( u32_Distance_m );
    }

    return u8_Retval;
}

uint8_t read_cam_temp(void)
{
    spi_wr(0x07, 0x96, 0x01);
    vTaskDelay(20);
    uint8_t rd_spi_data = spi_rd(0x87, 0x94);
    return rd_spi_data;
}

void v_Sample_Camera_Temperature(void)
{
    uint8_t u8_State;
    Get_Camera_State(&u8_State);
    if( u8_State & (CAMERA_ARMED_STATE | CAMERA_BUSY_STATE | CAMERA_TRANSFER_STATE ))
    {
        uint8_t u8_Temp = read_cam_temp();
        HAL_set_32bit_reg(IMG_METADATA_BASE_ADDR, SENSOR_TEMP_RAW, u8_Temp);

    }
}

uint32_t read_fpga_temp(void)
{
    uint32_t junc_temp = HAL_get_32bit_reg(JUNC_TEMP_BASE_ADDR, JUNC_TEMP);
    junc_temp >>= 4;
    return junc_temp;
}

void v_Enable_Camera_IRQ(uint8_t b_Enable)
{
    if( b_Enable )
    {
        __asm volatile ( "csrs mie, %0" ::"r" ( CAM_TRIGGER_IRQ ) );
    }
    else
    {
        __asm volatile ( "csrc mie, %0" ::"r" ( CAM_TRIGGER_IRQ ) );
    }
}

void v_Enable_UDP_IRQ(uint8_t b_Enable)
{
    if( b_Enable )
    {
        __asm volatile ( "csrs mie, %0" ::"r" ( UDP_IRQ ) );
    }
    else
    {
        __asm volatile ( "csrc mie, %0" ::"r" ( UDP_IRQ ) );
    }
}

void v_Camera_Trigger_IRQ_Handler(void)
{
    Event_t event;
    HAL_set_32bit_reg( CAM_TRIG_BASE_ADDR, CAM_TRIG_IRQ, 1 );
    event.no_data.sig = b_Is_Capture_Busy() ?  BURST_CAPTURE_STARTED : BURST_CAPTURE_COMPLETE;
    v_Post_Camera_Event_ISR( &event );
}


uint32_t check_fault(void)
{
    uint32_t fault = HAL_get_32bit_reg(CAM_FAULT_DETECTOR_BASE_ADDR, CAM_FAULT);
    return fault;
}

void clear_fault(void)
{
    HAL_set_32bit_reg(CAM_FAULT_DETECTOR_BASE_ADDR, CAM_FAULT_CLEAR, 1);
}

void v_UDP_Transfer_Handler(void)
{
    Event_t event;
    HAL_set_32bit_reg( UDP_DMACTRL_DDR4_8GB_BASE_ADDR,  FRAME_READ_DONE_IRQ, 1 );
    HAL_set_32bit_reg( UDP_DMACTRL_DDR4_16GB_BASE_ADDR, FRAME_READ_DONE_IRQ, 1 );
    event.no_data.sig = UDP_TRANSFER_COMPLETE;
    v_Post_Camera_Event_ISR( &event );
}


