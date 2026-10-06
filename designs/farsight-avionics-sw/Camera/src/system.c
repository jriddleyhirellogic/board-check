/*
 * test.c
 * For test purposes
 *  Created on: Oct 3, 2025
 *      Author: iboard
 */
#include <focus.h>
#include <stdint.h>
#include <stdio.h>

#include "FreeRTOSConfig.h"
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "event_groups.h"
#include "mem_map.h"
#include "config.h"
#include "misc.h"
#include "lvdt.h"
#include "serial_comm.h"
#include "camera_task.h"
#include "camera_states.h"
#include "image_metadata.h"
#include "debug_gpio.h"
#include "misc.h"
#include "pid.h"
#include "debug_mux.h"
#include "hal_stepper.h"
#include "core_spi.h"
#include "core_qspi.h"
#include "flash.h"
#include "tlm_adc.h"
#include "pps.h"

extern EventGroupHandle_t initialized;
static uint32_t u32_Counter;

static QueueHandle_t System_Queue;

uint32_t u32_Get_Power_Enables(void);
uint32_t u32_Get_Power_Status(void);

static uint16_t u16_TLM_Data[NUMBER_TLM_SENSORS];

// System task is for monitoring and controlling system as a whole. It can poll periodically for
// things like voltage and temperature.

static uint8_t u8_N_TLM_Sensor;

void v_System_Task(void *pvParameters)
{
    uint8_t n;
    uint8_t n_written;
    uint8_t u8_Heartbeat_Counter;
    uint8_t u8_Status;
    uint32_t u32_Fpga_Temp;
    uint16_t u16_Counter = 0;
    uint8_t u8_Camera_Temp;
    uint8_t u8_State;

    // Initialization
    TickType_t xDelay = pdMS_TO_TICKS(250); // system task responds to events and polls periodically
    uint32_t u32_Heap_Remaining;

    v_Init_TLM();

    System_Queue = xQueueCreate( SYSTEM_QUEUE_LENGTH , sizeof(Event_t) );
    xEventGroupSetBits( initialized,  SYSTEM_INITIALIZED );

    // Wait for all tasks to be initialized
    xEventGroupWaitBits( initialized, ALL_INITIALIZED, pdFALSE, pdTRUE, portMAX_DELAY );

    v_Enable_PPS_IRQ( 0 );

    while(1)
    {
        BaseType_t b_Event_Received;
        Event_t Rcvd_Event;
        Event_t event;
        uint32_t u32_Arg;
        uint32_t u32_Address;
        uint8_t u8_N_TLM_Readings;

        b_Event_Received = xQueueReceive( System_Queue,
                                          &Rcvd_Event,
                                          xDelay );

         if( b_Event_Received) // Event received
         {
             switch( Rcvd_Event.no_data.sig )
             {
             case RESET_RECEIVED:
                 v_Post_Camera_Event( &Rcvd_Event );
                 v_Post_Focus_Event( &Rcvd_Event );
                 break;

             case DO_FLASH_SECTOR_ERASE:
                 u32_Address = Rcvd_Event.flash_data.u32_Address;
                 v_Flash_Sector_Erase( u32_Address );
                 break;

             case DO_FLASH_BLOCK_ERASE:
                 u32_Address = Rcvd_Event.flash_data.u32_Address;
                 v_Flash_Block_Erase( u32_Address );
                 break;

             default:
                 ++u32_Counter;
                 break;
             }
         }
         else                  // Timeout for things that need to be polled periodically
         {
             ++u16_Counter;
             uint32_t u32_Status = u32_Get_Power_Enables();
             u32_Status = u32_Get_Power_Status();
             u32_Status = u8_Get_Stepper_NFAULT();

             u8_Heartbeat_Counter = (u8_Heartbeat_Counter + 1) & 3;
             v_Set_Heartbeat_LED( u8_Heartbeat_Counter == 0 );
             u8_Status = u8_Get_Stepper_Watchdog_Status();

             // Update cached TLM readings
             for(u8_N_TLM_Readings = 0; u8_N_TLM_Readings < 3; u8_N_TLM_Readings++)
             {
                 u16_TLM_Data[u8_N_TLM_Sensor] = u32_Read_TLM( u8_N_TLM_Sensor );
                 ++u8_N_TLM_Sensor;
                 u8_N_TLM_Sensor = u8_N_TLM_Sensor == NUMBER_TLM_SENSORS ? 0 : u8_N_TLM_Sensor;
             }

             // Update camera temperature for metadata
             if(!(u16_Counter & 0x3))
             {
                 Get_Camera_State( &u8_State );

                 if( u8_State & (CAMERA_ARMED_STATE | // @todo Doesn't appear to work in idle state
                                 CAMERA_BUSY_STATE  |
                                 CAMERA_TRANSFER_STATE))
                 {
                     u8_Camera_Temp = read_cam_temp();
                     HAL_set_32bit_reg( IMG_METADATA_BASE_ADDR, SENSOR_TEMP_RAW, u8_Camera_Temp );
                 }
             }
         }
#ifdef  MEM_CHECK
        UBaseType_t uxHighWaterMark = uxTaskGetStackHighWaterMark(NULL); // Stack high water mark - view in debugger
        u32_Heap_Remaining = xPortGetFreeHeapSize();
#endif

    }
}

void v_Get_Copy_TLM_Data(uint8_t *buffer)
{
    memcpy(buffer, u16_TLM_Data, sizeof(u16_TLM_Data) );
}

void v_Post_System_Event( Event_t *event )
{
    BaseType_t Ret_Val;
    Ret_Val = xQueueSend( System_Queue, event, 2 );
}

void v_Post_System_Event_ISR( Event_t *event )
{
    BaseType_t Ret_Val;
    Ret_Val = xQueueSendFromISR(  System_Queue, event, NULL );
}
