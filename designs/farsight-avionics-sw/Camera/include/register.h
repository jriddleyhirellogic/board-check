/*
 * register.h
 *
 *  Created on: Dec 3, 2025
 *      Author: iboard
 */

#ifndef REGISTER_H_
#define REGISTER_H_

#include <stdint.h>
#include "errors.h"

typedef enum
{
    //Camera Status and Control
    SENSOR_STAT_SYS_REG = 0,
    SENSOR_FRM_MOD_SYS_REG,
    SENSOR_BIT_DEPTH_SYS_REG,
    SENSOR_GAIN_SYS_REG,
    SENSOR_BLO_SYS_REG,
    SENSOR_EXPO_USEC_SYS_REG,
    SENSOR_TEMP_KEL_SYS_REG,
    SENSOR_OVER_TEMP_KEL_SYS_REG,

    //System
    ERROR_RESET_REG,
    FPGA_VOLTAGE_TEMP_REG,
    PWR_STATUS_REG,
    ERROR_COUNT_SYS_REG,
    BOOT_COUNT_SYS_REG,
    UPTIME_SEC_REG,
    TIMESTAMP_UNIX_SYS_REG,
    WDOG_TIMEOUT_MSEC_SYS_REG,
    BUFF_WRITE_POLICY_SYS_REG,
    BUFF_WRITE_PTR_SYS_REG,
    BUFF_BYTES_AVAIL_L_SYS_REG,
    BUFF_BYTES_AVAIL_M_SYS_REG,

    //System Imaging
    TRIG_MODE_SYS_REG,
    IMG_PER_TRIGGER_SYS_REG,
    FRAME_CAPTURE_TIME_SYS_REG,     /**< Time allotted to capture one frame, usec */
    CAPTURE_TIME_SEC_SYS_REG,       /**< Scheduled capture time, whole seconds (PPS trigger mode) */
    CAPTURE_TIME_MSEC_SYS_REG,      /**< Scheduled capture time, sub-second msec (PPS trigger mode) */
    CAP_START_DLY_USEC_SYS_REG,
    FRAME_COUNT_SYS_REG,
    FOCUS_REQ_DIST_M_SYS_REG,
    FOCUS_COMP_DIST_M_SYS_REG,
    FOCUS_LVDT_POS_NM_REG,

    //System Communications
    GPO_CONF_SYS_REG,
    GPI_CONF_SYS_REG,
    INTR_PIN_CONF_SYS_REG,
    TRIG_PIN_CONF_SYS_REG,
    TRIG_DELAY_USEC_SYS_REG,
    TRIG_TIMEOUT_MSEC_SYS_REG,
    TMTC_TIMEOUT_MSEC_SYS_REG,
    SRC_MAC_ADDRESS_0_3_SYS_REG,
    SRC_MAC_ADDRESS_4_5_SYS_REG,
    DST_MAC_ADDRESS_0_3_SYS_REG,
    DST_MAC_ADDRESS_4_5_SYS_REG,
    SRC_IP_ADDRESS_SYS_REG,
    DST_IP_ADDRESS_SYS_REG,
    SRC_PORT_SYS_REG,
    DST_PORT_SYS_REG,

    // Test and Integration
    EN_PATTERN_GEN_REG,
    NOOP_REG,
    NUMBER_REGISTERS,
}Register_ID_t;

// Callbacks are used to enforce both read/write and access restrictions
typedef Error_Code_t (*Read_Callback_t)( uint32_t *buffer);
typedef Error_Code_t (*Write_Callback_t)(uint32_t buffer);

#define REG_UNUSED (Read_Callback_t)0xFFFFFFFF

typedef struct
{
    uint32_t u32_Data;
    Read_Callback_t read;
    Write_Callback_t write;
}Register_Entry_t;

// Exported Functions
void v_Init_Registers(void);
void v_Sync_Registers_To_Hardware(void);
Error_Code_t Read_Register( uint16_t u16_ID, uint32_t *read_buffer );
Error_Code_t Write_Register( uint16_t u16_ID, uint32_t u32_write_data );


#endif /* REGISTER_H_ */
