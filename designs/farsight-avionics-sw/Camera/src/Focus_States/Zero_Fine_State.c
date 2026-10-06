/*
 * zero_fine.c
 *
 *  Created on: Oct 24, 2025
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

static int32_t i32_Original_Direction;

/**
 * @fn State_t Zero_Fine_State(Context_t*, Event_t*)
 * @brief State handler for fine movement in homing (zero commmand).
 * This moves the stepper very slowly in the same direction as when the state is
 * entered until the sign of the projection reverses. The amplitude of the projection near the
 * electrial zero fluctuates a lot and is less reliable than the sign. The sign reversal indicates
 * that the electrical zero of the lvdt has been found. The projection is given by:
 * Re{s/p} where s = complex values secondary response p = complex valued primary response
 *
 * @param context Focus state context
 * @param event Incoming event
 * @return Next state
 */
State_t Zero_Fine_State( Context_t *context, Event_t *event )
{
    State_t next_state = (State_t)Zero_Fine_State;
    int32_t i32_Projection, i32_Displacement_microns, i32_Step_Dir;
    LVDT_Sample_t LVDT_Sample;
    Motion_Cal_t *motion = (Motion_Cal_t *)context->cal;

    switch( event->no_data.sig )
    {
    case ENTRANCE:
        v_Start_Focus_Timer(10);        // Give everything a chance to settle first
        v_Set_LVDT_Gain( LVDT_GAIN_8 );
        v_Set_Microstep_Mode( STEP_256 );
        i32_Original_Direction = (int32_t)(context->param);
        break;

    case EXIT:
        v_Stop_Focus_Timer();
        v_Set_Stepper_out( 0 );
        break;

    case FOCUS_TIMER_EXPIRED:
        v_Refresh_Stepper_Watchdog();
        v_Start_Focus_Timer(10);

        V_Get_LVDT_Snapshot( &LVDT_Sample );
        i32_Projection  = i32_Get_Projection( &LVDT_Sample );

        i32_Step_Dir = i32_Motion_Sense(i32_Projection);

        v_Set_Stepper_out( -i32_Step_Dir * motion->u32_Fine_Zero_Speed );

        if( i32_Step_Dir != i32_Original_Direction )  // Wait for sign change
            next_state = (State_t)Idle_State;

        break;

    default:
        break;
    }

    return next_state;

}

