/*
 * camera_transfer_state.c
 *
 *  Created on: Jul 15, 2026
 *      Author: iboard
 */


/*
 * Camera_Low_Power_State.c
 *
 *  Created on: Dec. 8, 20225
 *      Author: iboard
 */
#include "FreeRTOSConfig.h"
#include "FreeRTOS.h"
#include "task.h"
#include "mem_map.h"
#include "register.h"
#include "errors.h"
#include "camera.h"
#include "camera_task.h"
#include "states.h"
#include "camera_states.h"
#include "udp_core_reg.h"
#include "udp_dmactrl_reg.h"
#include "command.h"
#include "misc.h"

/**
 * @fn State_t Camera_Transfer_State(Camera_Context_t*, Event_t*)
 * @brief For transferring frames through udp
 * This is due to the fact that you can't take pictures and transfer at the same time.
 * @param context Context info for state
 * @param event
 * @return Next state
 */

static uint16_t u16_Start_Index;
static uint16_t u16_N_Frames;
static uint16_t u16_Current_Index;
static uint8_t  u8_xfer_type;

#define UDP_TRANSFER_TIMEOUT 500

static void v_Transfer_Frame(uint16_t u16_Index );
static void v_Send_Frame_Metadata(uint16_t u16_Index );

State_t Camera_Transfer_State( Camera_Context_t *context, Event_t *event )
{
    State_t next_state = (State_t)Camera_Transfer_State;
    Camera_Instance_t *camera_instance = context->instance;
    Error_Code_t err = NO_ERROR;
    uint32_t u32_Mux;
    uint16_t u16_Index;
    Event_t done_event;

    switch( event->no_data.sig )
    {
    case ENTRANCE:
        // Reset the UDP DMA control for both buffers
        reset_udp_dmactrl(UDP_DMACTRL_DDR4_8GB_BASE_ADDR);
        reset_udp_dmactrl(UDP_DMACTRL_DDR4_16GB_BASE_ADDR);
        
//        context->eState = CAMERA_TRANSFER_STATE;
        u16_Start_Index = u16_Current_Index = event->xfer_frames.u16_index;
        u16_N_Frames = event->xfer_frames.u16_num;

        v_Enable_UDP_IRQ(1);
        v_Transfer_Frame(u16_Current_Index );
        v_Start_Camera_Timer( UDP_TRANSFER_TIMEOUT );
        context->eState = CAMERA_TRANSFER_STATE;
        break;

    case EXIT:
        v_Stop_Camera_Timer();
        v_Enable_UDP_IRQ(0);
        break;

    case UDP_TRANSFER_COMPLETE:
        ++u16_Current_Index;
        vTaskDelay(100);  // @todo this is so the flight computer can keep up. Revisit.
        if(u16_Current_Index < (u16_Start_Index + u16_N_Frames ))
        {
            v_Transfer_Frame(u16_Current_Index );
            v_Start_Camera_Timer( UDP_TRANSFER_TIMEOUT );
        }
        else
            next_state = (State_t)context->saved_state; // return to whence we came
        break;

    case CAMERA_TIMER_EXPIRED: // Transfer hung for some reason
        next_state = (State_t)Camera_Fault_State;
        break;

    default:
        break;
    }

    return next_state;
}

static void v_Transfer_Frame(uint16_t u16_Index )
{
uint32_t u32_Addr;
uint32_t u32_Read_Mux;

    if( u16_Index < DDR4_16GB_FRAME_CAPTURE_AMOUNT )   // 16GB buffer
    {
        u32_Addr = UDP_DMACTRL_DDR4_16GB_BASE_ADDR;
        u32_Read_Mux = UDP_MUX_SELECT_DDR4_16GB;

    }
    else                                               // 8GB buffer
    {
        u32_Addr = UDP_DMACTRL_DDR4_8GB_BASE_ADDR;
        u32_Read_Mux = UDP_MUX_SELECT_DDR4_8GB;
        u16_Index = u16_Index - DDR4_16GB_FRAME_CAPTURE_AMOUNT;

    }

    set_read_mux( UDP_TX_BASE_ADDR, u32_Read_Mux );

    xfer_frame_via_udp( u32_Addr, u16_Index );
}



