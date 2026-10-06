/*
 * control.h
 *
 *  Created on: Oct 17, 2025
 *      Author: iboard
 */

#ifndef CONTROL_H_
#define CONTROL_H_
#include "FreeRTOS.h"
#include "timers.h"
#include "events.h"

void v_Focus_Task(void *pvParameters);
void v_Post_Focus_Event( Event_t *event );
void v_Post_Focus_Event_ISR( Event_t *event );
void v_Start_Focus_Timer( TickType_t ticks);
void v_Stop_Focus_Timer(void);
void v_Start_Focus_Fault_Timer( TickType_t ticks);
void v_Stop_Focus_Fault_Timer(void);
uint8_t b_Is_Idle(void);
uint8_t u8_Get_Focus_Fault_Status(void);
int32_t i32_Motion_Sense(int32_t i32_Value);

typedef struct
{
    uint32_t u32_f_inf_microns;  // infinity focus
    uint32_t u32_f_10km_microns; // 10 km focus
}Focus_Cal_t;

#define TARGET_LOWER_LIMIT_DISTANCE  5000
#define TARGET_UPPER_LIMIT_DISTANCE  10000000

//#define MOTION_SENSE(x) ((x >= 0)?- -1 : 1)
#define MOTION_SENSE(x) ( x >= 0 ? -1 : 1)


#endif /* CONTROL_H_ */
