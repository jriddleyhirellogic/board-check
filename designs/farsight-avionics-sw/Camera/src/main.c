/*
 ============================================================================
 Name        : main.c
 Author      : ian
 Version     :
 Copyright   : Your copyright notice
 Description : Top level for camera control program
 ============================================================================
 */

#include <stdint.h>
#include <assert.h>
#include <camera_task.h>
#include <focus.h>

#include "FreeRTOSConfig.h"
#include "FreeRTOS.h"
#include "task.h"
#include "event_groups.h"
#include "mem_map.h"
#include "config.h"
#include "hal/hal.h"
#include "version.h"
#include "hw_version.h"
#include "image_metadata.h"

// Synchronization point to make sure all threads are initialized
EventGroupHandle_t initialized;

void v_Hw_Init(void);

// Tasks
void v_Serial_Comm_Task(void *pvParameters);
void v_System_Task(void *pvParameters);

/**
 * @fn int main(void)
 * @brief Low level initialization of hardware, creates threads and starts scheduler
 *
 * @return
 */
void main(void)
{
    BaseType_t retval;  // For debug

    v_Read_Version_Info();
    Version_t *p_Version = Get_Version_Info();

   initialized =  xEventGroupCreate();

    v_Hw_Init();

    retval = xTaskCreate( v_System_Task,                    // System level
                "System",
                SYSTEM_STACK_SIZE,
                NULL,
                SYSTEM_TASK_PRIORITY,
                NULL);

    retval = xTaskCreate( v_Serial_Comm_Task,               // For handling received messages
                "serial_comm",
                SERIAL_COMM_STACK_SIZE_WORDS,
                NULL,
                COMM_TASK_PRIORITY,
                NULL);

    retval = xTaskCreate( v_Focus_Task,                    // Control updates for stepper
                "control",
                FOCUS_STACK_SIZE_WORDS,
                NULL,
                CONTROL_TASK_PRIORITY,
                NULL);


    retval = xTaskCreate( v_Camera_Task,                    // Camera handling
                "camera",
                CAMERA_STACK_SIZE,
                NULL,
                CAMERA_TASK_PRIORITY,
                NULL);


    vTaskStartScheduler();

    while(1); // Should never reach this point

    (void)retval;

}



