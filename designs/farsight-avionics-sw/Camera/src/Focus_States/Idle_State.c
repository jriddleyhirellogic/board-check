/*
 * idle_state.c
 *
 *  Created on: Oct 18, 2025
 *      Author: iboard
 */
#include <focus.h>
#include <focus_states.h>
#include "states.h"
#include "debug_gpio.h"
#include "misc.h"
#include "hal_stepper.h"

void v_Set_Focus_Destination( int32_t i32_Destination );

/**
 * @fn State_t Idle_State(Context_t*, Event_t*)
 * @brief Focus mechanism is not moving and not faulted
 * The focus mechanism has been initialized and is waiting for
 * a command to move to an indicated position.
 *
 * @param context Focus state context
 * @param event
 * @return Next state
 */
State_t Idle_State( Context_t *context, Event_t *event )
{
    State_t next_state = (State_t)Idle_State;

    switch( event->no_data.sig )
    {
    case ENTRANCE:
        v_Enable_Stepper(0);      // Start with the stepper driver disabled.
        break;

    case EXIT:
        v_Stop_Focus_Timer();
        v_Arm_Stepper_Watchdog(); // all other states except for fault are ones that are moving.
        v_Enable_Stepper(1);
        vTaskDelay(5);            // allow a short period for stepper driver to be enabled.
        break;

    case GOTO_POSITION:
        v_Set_Focus_Destination( event->position.i32_Position );
        next_state = (State_t)Coarse_Focus_State;
        break;

    default:
        break;
    }

    return next_state;

}

int32_t i32_Final_Destination;

void v_Set_Focus_Destination( int32_t i32_Destination )
{
    i32_Final_Destination = i32_Destination;
}

int32_t i32_Get_Focus_Destination(void)
{
    return i32_Final_Destination;
}
