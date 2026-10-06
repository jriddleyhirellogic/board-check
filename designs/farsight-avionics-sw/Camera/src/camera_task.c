/*
 * camera.c
 *
 *  Created on: Nov 25, 2025
 *      Author: iboard
 */

#include <stdint.h>
#include <stdio.h>
#include <assert.h>
#include "FreeRTOSConfig.h"
#include "FreeRTOS.h"
#include "task.h"
#include "event_groups.h"
#include "queue.h"
#include "timers.h"
#include "mem_map.h"
#include "config.h"
#include "misc.h"
#include "lvdt.h"
#include "serial_comm.h"
#include "core_spi.h"
#include "states.h"
#include "register.h"
#include "camera_states.h"
#include "pid.h"
#include "debug_gpio.h"
#include "camera.h"


extern EventGroupHandle_t initialized;
static QueueHandle_t Camera_Queue;
static Camera_Context_t Camera_Context;
TimerHandle_t Camera_Timer;

static Camera_Instance_t camera_instance;

void v_Start_Camera_Timer( TickType_t ticks);
void v_Stop_Camera_Timer(void);
static void Camera_Timer_Expiration( TimerHandle_t xTimer );

/**
 * @fn void v_Camera_Task(void*)
 * @brief Thread managing camera - initialization, taking pictures, transferring image data.
 *
 * @param pvParameters Not used yet, but allows params to be passed when thread is created
 */
void v_Camera_Task(void *pvParameters)
{
    static uint32_t u32_Counter;
    uint8_t u8_Timer_ID;

    Camera_Context.instance = &camera_instance;

    // Camera initialization is being done here because there is no systick in early boot.
    v_Init_Camera( Camera_Context.instance );

    // Queue for events directed at control thread
    Camera_Queue = xQueueCreate( CAMERA_QUEUE_LENGTH , sizeof(Event_t) );

    // Camera timer
    Camera_Timer = xTimerCreate(
                                  "Camera_Timer",
                                   100,                        // Default period (mS)
                                   pdFALSE,                    // One shot, no auto-reload
                                   &u8_Timer_ID,
                                   Camera_Timer_Expiration  );

     v_Init_Camera_State_Machine( &Camera_Context, Camera_Low_Power_State );

    // Initialization complete
    xEventGroupSetBits( initialized,  CAMERA_INITIALIZED );

    // Wait for all tasks to be initialized
    xEventGroupWaitBits( initialized, ALL_INITIALIZED, pdFALSE, pdTRUE, portMAX_DELAY );

    while(1)
    {
        BaseType_t b_Event_Received;
        Event_t Rcvd_Event;

        b_Event_Received = xQueueReceive( Camera_Queue,
                                          &Rcvd_Event,
                                          portMAX_DELAY );

         if( b_Event_Received) // Event received
         {
             v_Update_Camera_State( &Camera_Context, &Rcvd_Event );
         }
         else                  // Timeout for period updates
         {
         }
    }
}

/**
 * @fn void v_Post_Camera_Event(Event_t*)
 * @brief Posts an event to message queue from other threads.
 *
 * @param event
 */
void v_Post_Camera_Event( Event_t *event )
{
    BaseType_t Ret_Val;
    Ret_Val = xQueueSend( Camera_Queue, event, 2 );
}

/**
 * @fn void v_Post_Camera_Event_ISR(Event_t*)
 * @brief Posts and event to camera thread message queue from interrupt context
 *
 * @param event (message)
 */
void v_Post_Camera_Event_ISR( Event_t *event )
{
    BaseType_t Ret_Val;
    Ret_Val = xQueueSendFromISR(  Camera_Queue, event, NULL );
}

void v_Start_Camera_Timer( TickType_t ticks)
{
    BaseType_t ret_val =  xTimerChangePeriod( Camera_Timer, ticks, 5);
    ret_val = xTimerStart( Camera_Timer, 5 );
}

void v_Stop_Camera_Timer(void)
{
    BaseType_t ret_val = xTimerStop( Camera_Timer, 5 );
}

static void Camera_Timer_Expiration( TimerHandle_t xTimer )
{
    Event_t event;
    event.no_data.sig = CAMERA_TIMER_EXPIRED;
    v_Post_Camera_Event( &event );
}

/**
 * @fn Error_Code_t Get_Camera_State(uint32_t*)
 * @brief Convenience function to sample current camera state
 *
 * @param pu8_State Pointer to state variable to be set
 * @return NO_ERROR (can always be called)
 */
Error_Code_t Get_Camera_State(uint8_t *pu8_State)
{
    *pu8_State = Camera_Context.eState;
    return NO_ERROR;
}

/**
 * @fn uint8_t b_Camera_Is_In_Armed_State(void)
 * @brief Convenience function to tell if camera is armed
 *
 * @return 1 if armed, 0 if not armed
 */
uint8_t b_Camera_Is_In_Armed_State(void)
{
    return Camera_Context.current_state == (State_t)Camera_Armed_State;
}

uint8_t b_Camera_Is_In_Busy_State(void)
{
    return Camera_Context.current_state == (State_t)Camera_Busy_State;
}

uint8_t b_Camera_Is_In_Idle_State(void)
{
    return Camera_Context.current_state == (State_t)Camera_Idle_State;
}
