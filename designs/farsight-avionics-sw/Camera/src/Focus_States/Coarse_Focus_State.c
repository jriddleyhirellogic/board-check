/*
 * Coarse_Focus_State.c
 *
 *  Created on: Apr 27, 2026
 *      Author: iboard
 */

#include <focus.h>
#include <focus_states.h>
#include "FreeRTOSConfig.h"
#include "FreeRTOS.h"
#include "task.h"

#include "states.h"
#include "debug_gpio.h"
#include "lvdt.h"
#include "hal_stepper.h"
#include "misc.h"
#include "misc_math.h"
#include "path.h"
#include "cal.h"

#define UPDATE_PERIOD_MS    10

static uint8_t DB_Count;

TickType_t Update_Period_Ticks;

int32_t i32_Final_Destination;

/**
 * @fn State_t Focus_State(Context_t*, Event_t*)
 * @brief Implements movements of the focus mechanism
 * On entry, the PI controller and path planner are initialized with an indicated
 * final position. Time stepping (10 msec) is implemented with software timer. The path
 * planner provdes for acceleration and deccelleration. The update continues until the
 * position is within a deadband of the final position. On entry a fault timer is started. If
 * the final position is not reached within a timeout, it indicates that the mechanism is stuck.
 * When the movement is done, the state machine transitions back to idle if there are no faults
 * or to a fault state if the fault timeout occurs.
 *
 * @param context Focus state context
 * @param event
 * @return Next state.
 */

int32_t i32_Get_Focus_Destination(void);

State_t Coarse_Focus_State( Context_t *context, Event_t *event )
{
    State_t next_state = (State_t)Coarse_Focus_State;
    int32_t i32_Position, i32_Setpoint, i32_Stepper_Out;
    int32_t i32_Error, i32_Step_Dir;
    Motion_Cal_t *motion = (Motion_Cal_t *)context->cal;

    switch( event->no_data.sig )
    {
    case ENTRANCE:
        Update_Period_Ticks = pdMS_TO_TICKS( UPDATE_PERIOD_MS );

        v_Set_LVDT_Gain( LVDT_GAIN_1 );
        v_Set_Microstep_Mode( STEP_256 );

        v_Start_Focus_Timer(Update_Period_Ticks);
        v_Start_Focus_Fault_Timer( motion->u32_Fault_Timeout_Ticks );

        DB_Count = 0;             // Hysteresis count for the deadband
        v_Enable_Stepper(1);
        break;

    case EXIT:
        v_Set_Stepper_out( 0 );
        v_Stop_Focus_Timer();
        v_Stop_Focus_Fault_Timer();
        break;

    case FOCUS_TIMER_EXPIRED:
        v_Refresh_Stepper_Watchdog();
        i32_Position = i32_Get_Position();

        // Don't let commanded moves exceed the travel limit
        if( i32_Position >= (int32_t)(motion->u32_Abs_Soft_Travel_Limit_Microns) ||
            i32_Position <= -((int32_t)(motion->u32_Abs_Soft_Travel_Limit_Microns)) )
        {
            next_state = (State_t)Idle_State;
        }

        i32_Error = i32_Position - i32_Get_Focus_Destination();

        i32_Step_Dir = i32_Motion_Sense(i32_Error);

        if( ABS(i32_Error) < (int32_t)(motion->u32_Fine_Focus_Threshold_Microns) )
        {
            return (State_t)Fine_Focus_State;
        }

        i32_Stepper_Out = i32_Step_Dir * (int32_t)(motion->u32_Coarse_Focus_Speed_10x_Microns_Sec);
        v_Set_Stepper_out( i32_Stepper_Out );
        v_Start_Focus_Timer(Update_Period_Ticks);
        break;

    default:
        break;
    }

    return next_state;

}





