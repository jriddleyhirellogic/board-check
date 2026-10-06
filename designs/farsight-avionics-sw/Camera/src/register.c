/*
 * register.c
 *
 *  Created on: Dec 3, 2025
 *      Author: iboard
 */

#include <string.h>
#include <assert.h>

#include "FreeRTOSConfig.h"
#include "FreeRTOS.h"
#include "task.h"

#include "register.h"
#include "version.h"
#include "hw_version.h"
#include "defaults.h"
#include "register_callbacks.h"
#include "camera.h"

//static Register_Entry_t *Register_List_Head;
static Register_Entry_t Register_Table[NUMBER_REGISTERS];
Register_Entry_t *Get_Register_Entry( uint16_t u16_ID );
static void v_Init_Register_Entry( uint8_t u8_ID,
                                   uint32_t u32_Reset_Value,
                                   Read_Callback_t read_fn,
                                   Write_Callback_t write_fn );
/**
 * @fn void v_Init_Registers(void)
 * @brief Initializes registers identified in ICD
 * For each register, this includes initial (default) values optional read and write
 * callbacks are used to query hardware and for enforcing permissions. For example, a write callback
 * simply returning an error value is used to make a register read only. When a callback is non-zero
 * after initialization, it is prioritized over SRAM.
 *
 *
 */
void v_Init_Registers(void)
{
    uint8_t u8_N_Reg;
    Register_Entry_t *p_Reg;

    // start by clearing everything
    memset( Register_Table, 0, sizeof(Register_Table));

    // Initially mark unused
    for( u8_N_Reg = 0; u8_N_Reg < NUMBER_REGISTERS; u8_N_Reg++ )
    {
        v_Init_Register_Entry( u8_N_Reg, 0, REG_UNUSED, 0 );
    }

    /*   Camera Status and Control  */
    v_Init_Register_Entry( SENSOR_STAT_SYS_REG, 0, Get_Sensor_State, Read_Only );
    v_Init_Register_Entry( SENSOR_FRM_MOD_SYS_REG, DEFAULT_SENSOR_FRAME, 0, Set_Sensor_Frame_Mode );
    v_Init_Register_Entry( SENSOR_BIT_DEPTH_SYS_REG, DEFAULT_SENSOR_DEPTH, 0, Set_Sensor_Bit_Depth );
    v_Init_Register_Entry( SENSOR_GAIN_SYS_REG, DEFAULT_SENSOR_GAIN, 0, Set_Sensor_Gain );
    v_Init_Register_Entry( SENSOR_BLO_SYS_REG, DEFAULT_SENSOR_BLO, 0, Set_Sensor_Black_Level_Offset );
    v_Init_Register_Entry( SENSOR_EXPO_USEC_SYS_REG, DEFAULT_SENSOR_EXPOSURE_USEC, 0, Set_Sensor_Exposure );
    v_Init_Register_Entry( SENSOR_TEMP_KEL_SYS_REG, 0, Get_Sensor_Temperature, Read_Only );
    //SENSOR_OVER_TEMP_KEL_SYS_REG

    /*    System    */
    //ERROR_RESET_REG
    //FPGA_VOLTAGE_TEMP_REG
    v_Init_Register_Entry( PWR_STATUS_REG, 0, Get_Power_Status, Read_Only );
    //ERROR_COUNT_SYS_REG
    //BOOT_COUNT_SYS_REG
    //UPTIME_SEC_REG
    //TIMESTAMP_UNIX_SYS_REG
    //WDOG_TIMEOUT_MSEC_SYS_REG
    //BUFF_WRITE_POLICY_SYS_REG
    //BUFF_WRITE_PTR_SYS_REG
    //BUFF_BYTES_AVAIL_L_SYS_REG
    //BUFF_BYTES_AVAIL_M_SYS_REG

    /*    System Imaging    */
    v_Init_Register_Entry( CAPTURE_TIME_SEC_SYS_REG, 0, 0, 0 );
    v_Init_Register_Entry( CAPTURE_TIME_MSEC_SYS_REG, 0, 0, Set_Capture_Time_Msec );
    v_Init_Register_Entry( TRIG_MODE_SYS_REG, DEFAULT_TRIGGER_MODE, 0, Set_Sensor_Trigger_Mode );
    v_Init_Register_Entry( IMG_PER_TRIGGER_SYS_REG, DEFAULT_IMAGES_PER_TRIGGER, 0, Set_Sensor_Images_Per_Trigger );
    v_Init_Register_Entry( FRAME_CAPTURE_TIME_SYS_REG, DEFAULT_FRAME_CAPTURE_TIME_USEC, 0, Set_Frame_Capture_Time );
    v_Init_Register_Entry( CAP_START_DLY_USEC_SYS_REG, 0, 0, Set_Sensor_Capture_Delay );
    v_Init_Register_Entry( FRAME_COUNT_SYS_REG, 0, Get_Sensor_Frame_Count, Read_Only );
    v_Init_Register_Entry( FOCUS_REQ_DIST_M_SYS_REG, 0, Get_Requested_Focus_Distance, Read_Only );
    v_Init_Register_Entry( FOCUS_COMP_DIST_M_SYS_REG, 0, Get_Computed_Focus_Distance, Read_Only );
    v_Init_Register_Entry( FOCUS_LVDT_POS_NM_REG, 0, Get_LVDT_Position, Read_Only );

    /*    System Communications    */
    //GPO_CONF_SYS_REG
    //GPI_CONF_SYS_REG
    //INTR_PIN_CONF_SYS_REG
    //TRIG_PIN_CONF_SYS_REG
    //TRIG_DELAY_USEC_SYS_REG
    //TRIG_TIMEOUT_MSEC_SYS_REG
    //TMTC_TIMEOUT_MSEC_SYS_REG

    //SRC_MAC_ADDRESS - own address of avionics board
    v_Init_Register_Entry( SRC_MAC_ADDRESS_0_3_SYS_REG, 0, 0, 0 );
    v_Init_Register_Entry( SRC_MAC_ADDRESS_4_5_SYS_REG, 0, 0, 0 );
    v_Init_Register_Entry( SRC_IP_ADDRESS_SYS_REG, 0, 0, 0 );

    //DST_MAC_ADDRESS - address of flight computer or pc
    v_Init_Register_Entry( DST_MAC_ADDRESS_0_3_SYS_REG, 0, 0, 0 );
    v_Init_Register_Entry( DST_MAC_ADDRESS_4_5_SYS_REG, 0, 0, 0 );
    v_Init_Register_Entry( DST_IP_ADDRESS_SYS_REG, 0, 0, 0 );

    // Ports
    v_Init_Register_Entry( SRC_PORT_SYS_REG, 0, 0, 0 );
    v_Init_Register_Entry( DST_PORT_SYS_REG, 0, 0, 0 );

    /* Test and Integration */
    v_Init_Register_Entry( EN_PATTERN_GEN_REG, 0, 0, Set_Pattern_Gen_Enable );

    v_Init_Register_Entry( NOOP_REG, 0xabcd1234,  0,  0 );
}

/**
 * @fn void v_Init_Register_Entry(uint8_t, uint32_t, Read_Callback_t, Write_Callback_t)
 * @brief Initializes a single register
 *
 * @param u8_ID The register address, per the ICD
 * @param u32_Reset_Value The default (initial) value
 * @param read_fn  When non-zero, a callback for read operations.
 * @param write_fn An optional callback for write operations. Read only can be enforced through this callback.
 */
static void v_Init_Register_Entry( uint8_t u8_ID,
                                   uint32_t u32_Reset_Value,
                                   Read_Callback_t read_fn,
                                   Write_Callback_t write_fn )
{
    assert( u8_ID < NUMBER_REGISTERS );
    Register_Entry_t *p_Reg = &Register_Table[u8_ID];
    p_Reg->u32_Data = u32_Reset_Value;
    p_Reg->read = read_fn;
    p_Reg->write = write_fn;
}

/**
 * @fn void v_Sync_Registers_To_Hardware(void)
 * @brief Replays the write callback of every writable register using its current table value.
 *
 * v_Init_Registers() only restores the register table, so devices that are configured through
 * a write callback keep whatever setting was last commanded. Calling this afterwards pushes the
 * restored values back out to the hardware so software and hardware agree.
 *
 * Read only registers are skipped, as their write callback exists solely to reject writes.
 *
 * @note Peripherals must already be initialized, so this must not be called from v_Hw_Init().
 */
void v_Sync_Registers_To_Hardware(void)
{
    uint8_t u8_N_Reg;
    Register_Entry_t *p_Reg;

    for( u8_N_Reg = 0; u8_N_Reg < NUMBER_REGISTERS; u8_N_Reg++ )
    {
        p_Reg = &Register_Table[u8_N_Reg];

        if( p_Reg->write != 0 && p_Reg->write != Read_Only )
        {
            p_Reg->write( p_Reg->u32_Data );
        }
    }
}

/**
 * @fn Register_Entry_t Get_Register_Entry*(uint16_t)
 * @brief Retrieves pointer to register entry
 *
 * @param u16_ID The register address from ICD
 * @return Pointer to register entry
 */
Register_Entry_t *Get_Register_Entry( uint16_t u16_ID )
{
    Register_Entry_t *p_Entry = (Register_Entry_t *)0;
    if( u16_ID < NUMBER_REGISTERS  && Register_Table[u16_ID].read != REG_UNUSED )
        p_Entry = &Register_Table[u16_ID];
    return p_Entry;
}

/**
 * @fn Error_Code_t Read_Register(uint16_t, uint32_t*)
 * @brief Read operation on register. If callback is non-zero it is called allowing hardware to be polled.
 *
 * @param u16_ID
 * @param read_buffer Buffer space for 32 bit register value
 * @return Error code - Insufficient privilege, non-existent register.
 */
Error_Code_t Read_Register( uint16_t u16_ID, uint32_t *read_buffer )
{
    Error_Code_t retval = NO_ERROR;
    Register_Entry_t *p_Reg = Get_Register_Entry( u16_ID );

    taskENTER_CRITICAL();

    if( p_Reg == (Register_Entry_t *)0 )
    {
        retval = ERR_REG_INVALID_ADDR;
    }
    else
    {
        if(p_Reg->read) // Callback overrides data element
        {
            retval = p_Reg->read(read_buffer);
        }
        else            // No callback
        {
            *read_buffer = p_Reg->u32_Data;
            retval = NO_ERROR;
        }
    }
    taskEXIT_CRITICAL();

    return retval;
}

/**
 * @fn Error_Code_t Write_Register(uint16_t, uint32_t)
 * @brief Generalized write to register. If callback is non-zero, it allows general method to be invoked.
 *
 * @param u16_ID
 * @param u32_write_data Data to write to register.
 * @return Error code - eg insufficient privilege, read-only register, non-existent register.
 */
Error_Code_t Write_Register( uint16_t u16_ID, uint32_t u32_write_data )
{
    Error_Code_t retval = NO_ERROR;
    Register_Entry_t *p_Reg = Get_Register_Entry( u16_ID );

    taskENTER_CRITICAL();
    if( p_Reg == (Register_Entry_t *)0 )
    {
        retval = ERR_REG_INVALID_ADDR;
    }
    else
    {
        if(p_Reg->write) // Callback overrides
        {
            retval = p_Reg->write( u32_write_data );
        }

        if( retval == NO_ERROR )
        {
            // In the case of callbacks, this just saves the last argument
            p_Reg->u32_Data = u32_write_data;
        }
    }
    taskEXIT_CRITICAL();

    return retval;
}





