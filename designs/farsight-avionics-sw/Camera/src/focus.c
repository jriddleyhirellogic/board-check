/*
 * control.c
 *
 *  Created on: Oct 17, 2025
 *      Author: iboard
 */


#include <stdint.h>
#include <stdio.h>
#include <assert.h>
#include <focus_states.h>

#include "FreeRTOSConfig.h"
#include "FreeRTOS.h"
#include "task.h"
#include "event_groups.h"
#include "queue.h"
#include "timers.h"
#include "mem_map.h"
#include "config.h"
#include "misc.h"
#include "lvdt.h"
#include "serial_comm.h"
#include "states.h"
#include "cal.h"
#include "debug_gpio.h"

extern EventGroupHandle_t initialized;

static QueueHandle_t Control_Queue;
TimerHandle_t Focus_Timer;
TimerHandle_t Focus_Fault_Timer;

static uint32_t u32_Timeout_Counter;
static void Focus_Timer_Expiration( TimerHandle_t xTimer );
static void Focus_Fault_Timer_Expiration( TimerHandle_t xTimer );
static Context_t focus_context;

static uint32_t u32_Thin_Lens(uint32_t u32_d_meter);
void v_Init_Focus_Calc(Focus_Cal_t *);
int32_t i32_Get_Focus_Target(uint32_t u32_d_meter);
uint32_t u32_Target_Distance_From_Offset(int32_t i32_Offset_Microns);
int32_t i32_Test;

static Focus_Cal_t focus_cal;

void v_Focus_Task(void *pvParameters)
{
    uint8_t u8_Timer_ID;
    TickType_t Control_Update_Period = pdMS_TO_TICKS(10);  // For periodic tasks

    // Queue for events directed at control thread
    Control_Queue = xQueueCreate( CONTROL_QUEUE_LENGTH , sizeof(Event_t) );

    // Initializes the focus calculations using calibration data. This is to establish
    // the relation between target distance and stepper motor offset in the focus mechanism.
    v_Init_Focus_Calc(&focus_cal);

#ifdef TEST_FOCUS_CALC
    i32_Test = i32_Get_Focus_Target(5000);     // 5 km, closest focus
    i32_Test = i32_Get_Focus_Target(10000);    // 10 km
    i32_Test = i32_Get_Focus_Target(10000000); // 10,000 km farthest focus

    i32_Test = u32_Target_Distance_From_Offset( -800 );
    i32_Test = u32_Target_Distance_From_Offset( 800 );
    i32_Test = u32_Target_Distance_From_Offset( 0 );
#endif

    // Control timer
     Focus_Timer = xTimerCreate(
                                  "Focus_Timer",
                                   100,                        // Default period (mS)
                                   pdFALSE,                    // One shot, no auto-reload
                                   &u8_Timer_ID,
                                   Focus_Timer_Expiration  );

     Focus_Fault_Timer = xTimerCreate(
                                  "Control_Fault",
                                   100,                        // Default period (mS)
                                   pdFALSE,                    // One shot, no auto-reload
                                   &u8_Timer_ID,
                                   Focus_Fault_Timer_Expiration  );


    // Initialization complete
    xEventGroupSetBits( initialized,  CONTROL_INITIALIZED );

    // Wait for all tasks to be initialized
    xEventGroupWaitBits( initialized, ALL_INITIALIZED, pdFALSE, pdTRUE, portMAX_DELAY );

    v_Stop_Focus_Timer();

    focus_context.cal = p_Get_Motion_Cal();

    v_Init_Focus_State_Machine( &focus_context, Idle_State );

    while(1)
    {
        BaseType_t b_Event_Received;
        Event_t Rcvd_Event;

        b_Event_Received = xQueueReceive( Control_Queue,
                                          &Rcvd_Event,
                                          portMAX_DELAY );

         if( b_Event_Received) // Event received
         {
             v_Update_Focus_State( &focus_context, &Rcvd_Event );
         }
         else                  // Timeout for period updates
         {
             ++u32_Timeout_Counter;
         }

#ifdef MEM_CHECK
         // Measure remaining stack space
         UBaseType_t uxHighWaterMark = uxTaskGetStackHighWaterMark(NULL);
#endif

    }
}

uint8_t b_Is_Idle(void)
{
    return focus_context.current_state == (State_t)Idle_State;
}

void v_Post_Focus_Event( Event_t *event )
{
    BaseType_t Ret_Val;
    Ret_Val = xQueueSend( Control_Queue, event, 2 );
}

void v_Post_Focus_Event_ISR( Event_t *event )
{
    BaseType_t Ret_Val;
    Ret_Val = xQueueSendFromISR(  Control_Queue, event, NULL );
}

void v_Start_Focus_Timer( TickType_t ticks)
{
    BaseType_t ret_val =  xTimerChangePeriod( Focus_Timer, ticks, 5);
    ret_val = xTimerStart( Focus_Timer, 5 );
}

void v_Stop_Focus_Timer(void)
{
    BaseType_t ret_val = xTimerStop( Focus_Timer, 5 );
}

static void Focus_Timer_Expiration( TimerHandle_t xTimer )
{
    Event_t event;
    event.no_data.sig = FOCUS_TIMER_EXPIRED;
    v_Post_Focus_Event( &event );
}

// Fault timer for focusing operations

void v_Start_Focus_Fault_Timer( TickType_t ticks)
{
    BaseType_t ret_val =  xTimerChangePeriod( Focus_Fault_Timer, ticks, 5);
    ret_val = xTimerStart( Focus_Timer, 5 );
}

void v_Stop_Focus_Fault_Timer(void)
{
    BaseType_t ret_val = xTimerStop( Focus_Fault_Timer, 5 );
}

static void Focus_Fault_Timer_Expiration( TimerHandle_t xTimer )
{
    Event_t event;
    event.no_data.sig = FOCUS_FAULT_TIMER_EXPIRED;
    v_Post_Focus_Event( &event );
}

// Finds direction depending on sense of motion related to stepper direction
int32_t i32_Motion_Sense(int32_t i32_Value)
{
    Motion_Cal_t *motion_cal = p_Get_Motion_Cal();

    if( motion_cal->u32_Motion_Sense )
    {
        return  i32_Value >= 0 ? 1 : -1;
    }
    else
    {
        return  i32_Value >= 0 ? -1 : 1;
    }
}

// Returns focus position in microns
// Note: it appears as if double precision is necessary due to the huge dynamic range.
static uint32_t u32_Thin_Lens(uint32_t u32_d_meter)
{
    // Thin lens equation
    double d_microns = (double)u32_d_meter * 1000000.0;
    double f_microns = (double)focus_cal.u32_f_inf_microns;
    double d2_microns = (d_microns * f_microns)/(d_microns - f_microns);

    return (uint32_t)d2_microns;
}

// Returns target offset for focus mechanism in microns.
int32_t i32_Get_Focus_Target(uint32_t u32_d_meter)
{
    uint32_t u32_Target = u32_Thin_Lens(u32_d_meter);
    return (int32_t)u32_Target - (int32_t)focus_cal.u32_f_10km_microns;
}

uint32_t u32_Target_Distance_From_Offset(int32_t i32_Offset_Microns)
{
    double d_Offset_Meters = ((double)i32_Offset_Microns) * 1.0e-6;
    d_Offset_Meters += ((double)focus_cal.u32_f_10km_microns) * 1.0e-6;
    double d_Focus_Inf = ((double)focus_cal.u32_f_inf_microns) * 1.0e-6;
    double d_Target_Meters = (d_Focus_Inf * d_Offset_Meters)/( d_Offset_Meters - d_Focus_Inf );
    return (uint32_t)d_Target_Meters;
}



void v_Init_Focus_Calc(Focus_Cal_t *cal)  // @todo This should be replaced by flash based cal values
{
    cal->u32_f_inf_microns = 2811000;
    cal->u32_f_10km_microns = u32_Thin_Lens(10000);  // 10 km distance corresponds to zero position
}

uint8_t u8_Get_Focus_Fault_Status(void)
{
    return focus_context.current_state == (State_t)Focus_Fault_State;
}



