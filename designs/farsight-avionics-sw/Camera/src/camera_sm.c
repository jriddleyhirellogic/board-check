/*
 * camera_sm.c
 *
 *  Created on: Dec 8, 2025
 *      Author: iboard
 */
#include "states.h"
#include "camera_states.h"

void v_Init_Camera_State_Machine( Camera_Context_t *context, State_t initial_state )
{
    Event_t event;
    event.no_data.sig = ENTRANCE;

    ((Camera_State_Handler_t)initial_state)( context, &event );

    context->current_state = initial_state;

}

void v_Update_Camera_State( Camera_Context_t *p_context, Event_t *p_event )
{
    // Handle immediate events - doesn't matter what state you are in
    State_t next_state = 0;
    State_t immediate = (State_t)0;

    // events that must be handled regardless of current state
    switch( p_event->no_data.sig )
    {
    case POWER_DOWN_CAMERA:
        immediate = (State_t)Camera_Low_Power_State;
        break;

    case CAMERA_MODE_SET:
        switch( p_event->mode_set.u8_Mode)
        {
            case CAMERA_LP_STATE:
                immediate = (State_t)Camera_Low_Power_State;
                break;

            case CAMERA_IDLE_STATE:
                immediate = (State_t)Camera_Idle_State;
                break;

            case CAMERA_ARMED_STATE:
                immediate = (State_t)Camera_Armed_State;
                break;

            case CAMERA_BUSY_STATE:
                immediate = (State_t)Camera_Busy_State;
                break;

            case CAMERA_TRANSFER_STATE:
                immediate = (State_t)Camera_Transfer_State;
                break;

            case CAMERA_FAULT_STATE:
                immediate = (State_t)Camera_Fault_State;
                break;

            default:
                break;
        }
        break;

    case RESET_RECEIVED:
        immediate = (State_t)Camera_Low_Power_State;
        break;
    default:
        break;
    }


    if( immediate ==  (State_t)0 )
    {
        next_state  = ((Camera_State_Handler_t)p_context->current_state)( p_context, p_event );
    }
    else
    {
        next_state = immediate;
    }

    if( next_state != p_context->current_state )
    {
        Event_t event;
        event.no_data.sig = EXIT;

        // In the rare event that we wish to return to whence we came.
        p_context->saved_state = p_context->current_state;

        ((Camera_State_Handler_t)p_context->current_state)( p_context, &event );

        p_event->no_data.sig = ENTRANCE;
        ((Camera_State_Handler_t)next_state)( p_context, p_event );

        p_context->current_state = next_state;

    }
}
