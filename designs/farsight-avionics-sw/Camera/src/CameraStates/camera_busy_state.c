/*
 * camera_busy_state.c
 *
 *  Created on: Dec 8, 2025
 *      Author: iboard
 */

#include "FreeRTOSConfig.h"
#include "FreeRTOS.h"
#include "task.h"
#include "event_groups.h"
#include "queue.h"
#include "timers.h"
#include "mem_map.h"
#include "register.h"
#include "camera.h"
#include "camera_task.h"
#include "cam_mux.h"
#include "states.h"
#include "camera_states.h"
#include "command.h"
#include "misc.h"
#include "udp_core_reg.h"
#include "dma_read_reg.h"
#include "udp_dmactrl_reg.h"

/**
 * @fn State_t Camera_Busy_State(Camera_Context_t*, Event_t*)
 * @brief Camera has taken a picture and is busy transferring data
 * @param context
 * @param event
 * @return Next state
 */

static uint32_t u32_N_Frames;
static uint32_t u32_Frame_Capture_Time_usec;
static uint32_t u32_Timeout;

State_t Camera_Busy_State( Camera_Context_t *context, Event_t *event )
{
    State_t next_state = (State_t)Camera_Busy_State;
    Error_Code_t err = NO_ERROR;

    switch( event->no_data.sig )
    {
    case ENTRANCE:
        context->eState = CAMERA_BUSY_STATE;
        Read_Register( IMG_PER_TRIGGER_SYS_REG, &u32_N_Frames );
        Read_Register( FRAME_CAPTURE_TIME_SYS_REG, &u32_Frame_Capture_Time_usec );
        u32_Timeout = u32_N_Frames * u32_Frame_Capture_Time_usec;
        u32_Timeout += u32_Timeout / 2;
        v_Start_Camera_Timer(u32_Timeout);
        break;

    case EXIT:
        v_Stop_Camera_Timer();
        break;

    case BURST_CAPTURE_COMPLETE:
        next_state = (State_t)Camera_Armed_State;
        break;

    case CAMERA_TIMER_EXPIRED:
        next_state = (State_t)Camera_Fault_State;
        break;

    default:
        break;
    }

    return next_state;

}



