/*
 * Camera_Low_Power_State.c
 *
 *  Created on: Dec. 8, 20225
 *      Author: iboard
 */
#include "FreeRTOSConfig.h"
#include "FreeRTOS.h"
#include "task.h"
#include "register.h"
#include "errors.h"
#include "camera.h"
#include "states.h"
#include "camera_states.h"
#include "misc.h"

/**
 * @fn State_t Camera_Low_Power_State(Camera_Context_t*, Event_t*)
 * @brief Low power event handler for low power state.
 * In this state, the camera camera sensor and oscillator are powered down.
 * @param context Context info for state
 * @param event
 * @return Next state
 */
State_t Camera_Low_Power_State( Camera_Context_t *context, Event_t *event )
{
    State_t next_state = (State_t)Camera_Low_Power_State;
    Camera_Instance_t *camera_instance = context->instance;
    Error_Code_t err = NO_ERROR;

    switch( event->no_data.sig )
    {
    case ENTRANCE:
        v_Enable_Camera_IRQ(0);
        v_Enable_Camera_Power( camera_instance, 0 ); // start with camera powered down
        context->eState = CAMERA_LP_STATE;
        break;

    case EXIT:
        break;
        
    case POWER_UP_CAMERA:
        next_state = (State_t)Camera_Idle_State;
        break;
    
    case POWER_DOWN_CAMERA:
        break;

    case CAMERA_RESET_FRAME_INDEX:
        v_Reset_Camera_Buffer();
        break;

    case CAMERA_SEND_FRAMES:
        next_state = (State_t)Camera_Transfer_State;
        break;


    default:
        // @todo unhandled commands should set error
        break;
    }

    return next_state;

}
