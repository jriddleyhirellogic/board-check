/*
 * camera_fault_state.c
 *
 *  Created on: Dec 11, 2025
 *      Author: iboard
 */
#include "camera.h"
#include "states.h"
#include "camera_states.h"
#include "misc.h"

/**
 * @fn State_t Camera_Fault_State(Camera_Context_t*, Event_t*)
 * @brief A fault has been experienced by the camera
 * This is an absorbing state. It will not respond to events. To exit this state,
 * a reset or power cycle is needed.
 * @param context State context
 * @param event
 * @return Next state.
 */
State_t Camera_Fault_State( Camera_Context_t *context, Event_t *event )
{
    State_t next_state = (State_t)Camera_Fault_State;

    switch( event->no_data.sig )
    {
    case ENTRANCE:
        context->eState = CAMERA_FAULT_STATE;
        break;

    case EXIT:
        break;


    default:
        break;
    }

    return next_state;

}




