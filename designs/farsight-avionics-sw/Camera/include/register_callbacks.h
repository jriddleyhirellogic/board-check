/*
 * register_callbacks.h
 *
 *  Created on: Dec 11, 2025
 *      Author: iboard
 */

#ifndef REGISTER_CALLBACKS_H_
#define REGISTER_CALLBACKS_H_

// Write callback to enforce read only
Error_Code_t Read_Only( uint32_t dummy );
Error_Code_t Get_Sensor_State( uint32_t *state );
Error_Code_t Get_Power_Status( uint32_t *status );
Error_Code_t Set_Sensor_Frame_Mode( uint32_t u32_Mode );
Error_Code_t Set_Sensor_Bit_Depth( uint32_t u32_Mode );
Error_Code_t Set_Sensor_Gain( uint32_t u32_Gain );
Error_Code_t Set_Sensor_Black_Level_Offset( uint32_t u32_Offset );
Error_Code_t Set_Pattern_Gen_Enable( uint32_t u32_Enable );
Error_Code_t Set_Sensor_Exposure( uint32_t u32_Exposure_usec );
Error_Code_t Get_Sensor_Temperature( uint32_t *temp );
Error_Code_t Set_Sensor_Trigger_Mode( uint32_t u32_Mode );
Error_Code_t Set_Sensor_Images_Per_Trigger( uint32_t u32_Mode );
Error_Code_t Get_Sensor_Images_Per_Trigger( uint32_t *u32_Mode );
Error_Code_t Set_Frame_Capture_Time( uint32_t u32_Capture_Time_usec );
Error_Code_t Set_Capture_Time_Msec( uint32_t u32_Capture_Time_msec );
Error_Code_t Set_Sensor_Capture_Delay( uint32_t u32_Mode );
Error_Code_t Get_Sensor_Frame_Count( uint32_t *count );
Error_Code_t Get_Requested_Focus_Distance( uint32_t *count );
Error_Code_t Get_Computed_Focus_Distance( uint32_t *count );
Error_Code_t Get_LVDT_Position( uint32_t *count );

#endif /* REGISTER_CALLBACKS_H_ */
