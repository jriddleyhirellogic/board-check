/*
 * register_callbacks.c
 *
 *  Created on: Dec 10, 2025
 *      Author: iboard
 */
#include "register.h"
#include "register_callbacks.h"
#include "mem_map.h"
#include "hal/hal.h"
#include "lvdt.h"
#include "camera.h"
#include "camera_states.h"
#include "gpio_pin_def.h"

#include "cam_trig.h"

uint32_t u32_Get_Power_Status(void);   // Defined in hw_init.c

// Read Callbacks

Error_Code_t Get_Sensor_State( uint32_t *state )
{
    uint8_t u8_State;
    Get_Camera_State( &u8_State );
	*state = u8_State;
    return NO_ERROR;
}

/* PWR_STATUS_REG. Each bit reports the power good status of one supply, sampled directly from
 * the housekeeping status GPIO. The upper bits of that GPIO carry unrelated signals and are
 * masked off.
 */
Error_Code_t Get_Power_Status( uint32_t *status )
{
    *status = u32_Get_Power_Status() & PWR_STATUS_MASK;
    return NO_ERROR;
}

/* FRAME_COUNT_SYS_REG. Number of frames held in the DDR4 frame buffer, counting both devices.
 * It counts up as frames are captured and returns to zero when the buffer is emptied by a
 * RESET_FRAME_INDEX_SYS_CMD, so it is the index the next frame will be stored at.
 */
Error_Code_t Get_Sensor_Frame_Count( uint32_t *count )
{
    *count = u32_Total_Frames_Stored();
    return NO_ERROR;
}

/* Focus distance requested by the user from a FOCUS_SYS_CMD,
 * which is the only way to update this register value.
 */
Error_Code_t Get_Requested_Focus_Distance( uint32_t *count )
{
    return NO_ERROR;
}

/*Focus distance computed from LVDT position and calibrated LUT */
Error_Code_t Get_Computed_Focus_Distance( uint32_t *count )
{
    return NO_ERROR;
}

/*Reading of the sensor position in nanometers that can be mapped to focus distance. */
Error_Code_t Get_LVDT_Position( uint32_t *count )
{
    *count = (uint32_t)i32_Get_Position();
    return NO_ERROR;
}

Error_Code_t Get_Sensor_Temperature( uint32_t *temp )
{
    uint8_t u8_State;
    Get_Camera_State( &u8_State );
    if( u8_State == 4 ) // powered up
    {
        uint32_t u8_Raw_Temp = (uint32_t)read_cam_temp();
        *temp =  (uint32_t)(((float)u8_Raw_Temp - 51.784)/1.3125f);
        return NO_ERROR;
    }
    else
    {
        *temp = 0xFFFFFFFF;
        return ERR_CMD_INVALID_MODE;
    }

}

// Write Callbacks

Error_Code_t Read_Only( uint32_t dummy )
{
    return ERR_REG_WRITE_DENIED_RO;
}

/* SENSOR_FRM_MOD_SYS_REG. The sensor is configured over SPI, which blocks, so this callback
 * only validates. The accepted value is cached by Write_Register() and pushed to the sensor by
 * init_slvsec() when the camera leaves the low power state.
 */
Error_Code_t Set_Sensor_Frame_Mode( uint32_t u32_Mode )
{
    if( u32_Mode & FRM_MOD_RESERVED_MASK )
    {
        return ERR_REG_INVALID_LIMIT;
    }

    // The sensor prohibits the fourth readout mode
    if( ( ( u32_Mode & FRM_MOD_READOUT_MODE_MASK ) >> FRM_MOD_READOUT_MODE_SHIFT )
            == READOUT_PROHIBITED )
    {
        return ERR_REG_INVALID_LIMIT;
    }

    return NO_ERROR;
}

/* SENSOR_BIT_DEPTH_SYS_REG. Like the frame mode, this callback only validates, and the accepted
 * value is applied to the sensor by v_Apply_Bit_Depth(). The SLVS-EC IP is currently configured
 * for 12 bit pixels, so the other depths are rejected until it is made selectable.
 */
Error_Code_t Set_Sensor_Bit_Depth( uint32_t u32_Mode )
{
    if( u32_Mode != CAMERA_DEPTH_TWELVE_BITS )
    {
        return ERR_REG_INVALID_LIMIT;
    }

    return NO_ERROR;
}

/* SENSOR_GAIN_SYS_REG. Validates only; the accepted value is applied by v_Apply_Gain(). */
Error_Code_t Set_Sensor_Gain( uint32_t u32_Gain )
{
    if( u32_Gain > SENSOR_GAIN_MAX )
    {
        return ERR_REG_INVALID_LIMIT;
    }

    return NO_ERROR;
}

/* SENSOR_BLO_SYS_REG. Validates only; the accepted value is applied by v_Apply_Black_Level(). */
Error_Code_t Set_Sensor_Black_Level_Offset( uint32_t u32_Offset )
{
    if( u32_Offset > SENSOR_BLO_MAX )
    {
        return ERR_REG_INVALID_LIMIT;
    }

    return NO_ERROR;
}

/* EN_PATTERN_GEN_REG. Validates only; the accepted value is applied by v_Apply_Pattern_Gen(). */
Error_Code_t Set_Pattern_Gen_Enable( uint32_t u32_Enable )
{
    if( u32_Enable > 1u )
    {
        return ERR_REG_INVALID_LIMIT;
    }

    return NO_ERROR;
}
/* SENSOR_EXPO_USEC_SYS_REG. Validates only. The exposure drives the XTRIG_LOW_TIME of the
 * capture trigger, which is programmed by e_Configure_Trigger() on entry to the armed state
 * and again whenever an imaging register changes while armed.
 */
Error_Code_t Set_Sensor_Exposure( uint32_t u32_Exposure_usec )
{
    if( u32_Exposure_usec < SENSOR_EXPO_USEC_MIN || u32_Exposure_usec > SENSOR_EXPO_USEC_MAX )
    {
        return ERR_REG_INVALID_LIMIT;
    }

    return NO_ERROR;
}

/* TRIG_MODE_SYS_REG. Validates only. The accepted value is written to the XTRIG_SRC_SEL of the
 * trigger IP by e_Configure_Trigger() on entry to the armed state, and again whenever an imaging
 * register changes while armed.
 */
Error_Code_t Set_Sensor_Trigger_Mode( uint32_t u32_Mode )
{
    if( u32_Mode > (uint32_t)EXT_TRIGGER )
    {
        return ERR_REG_INVALID_LIMIT;
    }

    v_Note_Trigger_Mode_Written();

    return NO_ERROR;
}

/* IMG_PER_TRIGGER_SYS_REG. Validates only. The accepted value is written to FRAME_CAPTURE_AMOUNT
 * by e_Configure_Trigger(). The upper limit is the capacity of the DDR4 frame buffer, since a
 * burst larger than that would overwrite frames that had not been read out yet.
 */
Error_Code_t Set_Sensor_Images_Per_Trigger( uint32_t u32_Images_Per_Trigger )
{
    if( u32_Images_Per_Trigger < 1 || u32_Images_Per_Trigger > TOTAL_FRAME_CAPTURE_AMOUNT )
    {
        return ERR_REG_INVALID_LIMIT;
    }

    return NO_ERROR;
}

Error_Code_t Get_Sensor_Images_Per_Trigger(uint32_t *u32_Images_Per_Trigger )
{
    *u32_Images_Per_Trigger = HAL_get_32bit_reg( CAM_TRIG_BASE_ADDR, FRAME_CAPTURE_AMOUNT);
    return NO_ERROR;
}

/* FRAME_CAPTURE_TIME_SYS_REG. Validates only. The accepted value is written to the
 * FRAME_CAPTURE_TIME of the trigger IP by e_Configure_Trigger(). It is the period of the frame
 * capture, so it has to cover the exposure plus the time the DDR4 buffer needs to absorb the
 * frame, which depends on the line period currently in effect.
 */
Error_Code_t Set_Frame_Capture_Time( uint32_t u32_Capture_Time_usec )
{
    uint32_t u32_Exposure_usec;

    Read_Register( SENSOR_EXPO_USEC_SYS_REG, &u32_Exposure_usec );

    if( u32_Capture_Time_usec < u32_Exposure_usec + u32_Min_Frame_Time_usec() )
    {
        return ERR_REG_INVALID_LIMIT;
    }

    if( u32_Capture_Time_usec > FRAME_CAPTURE_TIME_USEC_MAX )
    {
        return ERR_REG_INVALID_LIMIT;
    }

    v_Note_Frame_Time_Written();

    return NO_ERROR;
}

/* CAPTURE_TIME_MSEC_SYS_REG. Validates only. The accepted value is written to the
 * SCHEDULER_TIME_MSEC of the trigger IP by e_Configure_Trigger(), where it is the sub-second part
 * of the scheduled capture time used in PPS trigger mode. That register keeps only the low ten
 * bits, so anything past a whole second has to be rejected rather than silently truncated.
 */
Error_Code_t Set_Capture_Time_Msec( uint32_t u32_Capture_Time_msec )
{
    if( u32_Capture_Time_msec > CAPTURE_TIME_MSEC_MAX )
    {
        return ERR_REG_INVALID_LIMIT;
    }

    return NO_ERROR;
}

Error_Code_t Set_Sensor_Capture_Delay( uint32_t u32_Mode )
{
    return NO_ERROR;
}

