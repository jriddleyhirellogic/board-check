/*
 * camera_idle_state.c
 *
 *  Created on: Dec 8, 2025
 *      Author: iboard
 */
#include "FreeRTOS.h"
#include "task.h"

#include "camera.h"
#include "states.h"
#include "mem_map.h"
#include "camera_states.h"
#include "misc.h"
#include "cam_mux.h"
#include "register.h"
#include "util.h"

/**
 * @fn State_t Camera_Idle_State(Camera_Context_t*, Event_t*)
 * @brief Camera is powered up, but not ready to take pictures.
 * On entry, the camera is reset and the lvds links are initialized.
 * @param context
 * @param event
 * @return Next state, determined by event
 */
State_t Camera_Idle_State( Camera_Context_t *context, Event_t *event )
{
    State_t next_state = (State_t)Camera_Idle_State;
    Camera_Instance_t *camera_instance = context->instance;
    Error_Code_t err = NO_ERROR;
    uint32_t u32_IMX_Test_Enabled;
    uint32_t u32_Base_Address;

    switch( event->no_data.sig )
    {
    case ENTRANCE:
        if (context->eState == CAMERA_LP_STATE) {
//            context->eState = CAMERA_IDLE_STATE;
            v_Enable_Camera_Power( camera_instance, 1 );
            vTaskDelay(1500);
            init_slvsec( context->instance );
        } else {
//            context->eState = CAMERA_IDLE_STATE;
            set_standby_and_master_mode(0x01);
            // Pick up any sensor configuration written while the camera was not idle
            v_Apply_Frame_Mode();
            v_Apply_Bit_Depth();
            v_Apply_Gain();
            v_Apply_Black_Level();
            v_Apply_Pattern_Gen();
        }
        v_Enable_Camera_IRQ(0);
        context->eState = CAMERA_IDLE_STATE;
        break;

    case EXIT:
        break;

    case POWER_UP_CAMERA:  // Camera already powered up. Harmless but ignored
        break;

    case POWER_DOWN_CAMERA:
        next_state = (State_t)Camera_Low_Power_State;
        break;

    case ARM_CAMERA:
        next_state = (State_t)Camera_Armed_State;
        break;

    case CAMERA_CONFIG_CHANGED:
        // The sensor is powered and in standby here, so it can be reconfigured in place
        v_Apply_Frame_Mode();
        v_Apply_Bit_Depth();
        v_Apply_Gain();
        v_Apply_Black_Level();
        v_Apply_Pattern_Gen();
        break;

    case CAMERA_RESET_FRAME_INDEX:
        v_Reset_Camera_Buffer();
        break;

    case CAMERA_SEND_FRAMES:
        next_state = (State_t)Camera_Transfer_State;
        break;


    default:
        break;
    }

    return next_state;

}

