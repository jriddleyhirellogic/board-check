/*
 * states.c
 *
 *  Created on: Oct 17, 2025
 *      Author: iboard
 */
#include <focus_states.h>
#include "FreeRTOSConfig.h"
#include "FreeRTOS.h"
#include "task.h"
#include "states.h"

/**
 * @fn void v_Init_Focus_State_Machine(Context_t*, State_t)
 * @brief Initializes the focus state machine.
 * Sets the initial state and calls the handler for entrance
 *
 * @param context
 * @param initial_state
 */
void v_Init_Focus_State_Machine( Context_t *context, State_t initial_state )
{
    Event_t event;
    event.no_data.sig = ENTRANCE;

    ((State_Handler_t)initial_state)( context, &event );

    context->current_state = initial_state;

}

/**
 * @fn void v_Update_Focus_State(Context_t*, Event_t*)
 * @brief Respond to and event.
 * The handler has two parts: immediate and non-immediate. Immediate corresponds to
 * events which must be handled irrespective of what state the focus state machine is in.
 * An example would be a reset or a fault. Non-immediate calls the handler for the current
 * state with the event and if necessary causes the transition to a new state. If the state
 * machine transitions to a new state, the exit method for the current state is called, then
 * the entrance method for the new state.
 *
 * @param p_context Focus state context
 * @param p_event Pointer to event
 */
void v_Update_Focus_State( Context_t *p_context, Event_t *p_event )
{
    // Handle immediate events - doesn't matter what state you are in
    State_t next_state = 0;
    State_t immediate = (State_t)0;

    switch( p_event->no_data.sig )
    {
    case RESET_RECEIVED:
        immediate =  (State_t)Idle_State;
        break;

    case ZERO_STEPPER:
        immediate = (State_t)Zero_Coarse_State;
        break;

    case FOCUS_FAULT_TIMER_EXPIRED:
        immediate = (State_t)Focus_Fault_State;
        break;

    default:
        break;
    }
    if( immediate ==  (State_t)0 )
    {
        next_state  = ((State_Handler_t)p_context->current_state)( p_context, p_event );
    }
    else
    {
        next_state = immediate;
    }

    if( next_state != p_context->current_state )
    {
        Event_t event;
        event.no_data.sig = EXIT;

        ((State_Handler_t)p_context->current_state)( p_context, &event );

        p_event->no_data.sig = ENTRANCE;
        ((State_Handler_t)next_state)( p_context, p_event );

        p_context->current_state = next_state;

    }
}

