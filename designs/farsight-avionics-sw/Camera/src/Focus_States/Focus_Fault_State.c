/*
 * Focus_Fault_State.c
 *
 *  Created on: Jan 15, 2026
 *      Author: iboard
 */
#include <focus.h>
#include <focus_states.h>
#include "hal_stepper.h"
#include "states.h"
#include "debug_gpio.h"
#include "misc.h"

// Need to reset in order to get out of this state.
State_t Focus_Fault_State( Context_t *context, Event_t *event )
{
    State_t next_state = (State_t)Focus_Fault_State;

    switch( event->no_data.sig )
    {
    case ENTRANCE:
        v_Set_Stepper_out( 0 );
        v_Stop_Focus_Timer();
        v_Stop_Focus_Fault_Timer();
        break;

    case EXIT:
        break;

    default:
        break;
    }

    return next_state;

}

