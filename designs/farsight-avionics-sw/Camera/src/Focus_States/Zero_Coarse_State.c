/*
 * Zero_Coarse.c
 *
 *  Created on: Oct 21, 2025
 *      Author: iboard
 */

#include <focus.h>
#include <focus_states.h>
#include "states.h"
#include "lvdt.h"
#include "hal_stepper.h"
#include "debug_gpio.h"
#include "misc_math.h"
#include "cal.h"

/**
 * @fn State_t Zero_Coarse_State(Context_t*, Event_t*)
 * @brief Coarse movement for homing (zero) command
 * This uses only the projection of the secondary response onto the primary -
 * Re{s/p}  where s = secondary response of lvdt p = primary
 * When this value is small enough in magnitude, the state transitions to Zero_Fine_State
 * which slows the speed down and continues movement in the same direction until the sign of
 * the projection == 0, indicating that the electrical zero of the lvdt has been found. This
 * method does not depend on any calibration being present.
 *
 * @param context State contect for the focus mechanism
 * @param event Incoming message (event) in this case, there is no data payload.
 * @return The next state for the focus mechanism.
 */
State_t Zero_Coarse_State( Context_t *context, Event_t *event )
{
    State_t next_state = (State_t)Zero_Coarse_State;
    int32_t i32_Projection,i32_Step_Dir;
    LVDT_Sample_t LVDT_Sample;
    Motion_Cal_t *motion = (Motion_Cal_t *)context->cal;

    switch( event->no_data.sig )
    {
    case ENTRANCE:
        v_Start_Focus_Timer(10);        // Give everything a chance to settle first
        v_Set_LVDT_Gain( LVDT_GAIN_1 );
        v_Set_Microstep_Mode( STEP_256 );
        break;

    case EXIT:
        v_Stop_Focus_Timer();
        v_Set_Stepper_out( 0 );
        break;

    case FOCUS_TIMER_EXPIRED:
        v_Refresh_Stepper_Watchdog();
        v_Start_Focus_Timer(10);

        V_Get_LVDT_Snapshot( &LVDT_Sample );
        i32_Projection = i32_Get_Projection( &LVDT_Sample );

        i32_Step_Dir = i32_Motion_Sense(i32_Projection);

        if( ABS( i32_Projection ) <= motion->u32_Coarse_Fine_Proj_Threshold )
        {
            next_state = (State_t)Zero_Fine_State;
            context->param = (void *)( i32_Projection < 0 ? -1 : 1 );  // remember direction of travel on entry to fine zero state
        }

        v_Set_Stepper_out( -i32_Step_Dir * motion->u32_Coarse_Zero_Speed );

        break;

    default:
        break;
    }

    return next_state;

}

