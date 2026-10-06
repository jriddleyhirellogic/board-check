/*******************************************************************************
 * @file      FreeRTOSConfig.h
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      06/24/2025
 * 
 * @brief     FreeRTOS config file. See Notes below for important config info.
 * 
 * @section changelog
 * - 06/24/2025: Saba Janamian - Initial implementation
 * 
*******************************************************************************/

#ifndef FREERTOS_CONFIG_H
#define FREERTOS_CONFIG_H

//------------------------------------------------------------------------------
// IMPORTANT NOTE: 
// configMTIME_BASE_ADDRESS and configMTIMECMP_BASE_ADDRESS are configured for
// to Microchip MiV32 V3 and after. Legacy versions of this core have different
// MTIME address.
// configCPU_CLOCK_HZ has been configured to be 50MHz. If the clock frequency
// of the MiV32 core changes in FPGA this value must also change here!
// `RTC_PRESCALER` must match the FPGA MTIME Prescaler value
//------------------------------------------------------------------------------

#define RTC_PRESCALER                           100UL
#define configMTIME_BASE_ADDRESS                0x0200BFF8UL
#define configMTIMECMP_BASE_ADDRESS             0x02004000UL
#define configUSE_PREEMPTION                    1
#define configUSE_IDLE_HOOK                     1
#define configUSE_TICK_HOOK                     1
#define configCPU_CLOCK_HZ                      ( ( uint32_t ) ( 50000000 ) )
#define configTICK_RATE_HZ                      ( ( TickType_t ) 1000 )
#define configMAX_PRIORITIES                    ( 5 )
#define configMINIMAL_STACK_SIZE                ( ( uint32_t ) 200 )
#define configTOTAL_HEAP_SIZE                   ( ( size_t ) ( 8000 ) )
#define configMAX_TASK_NAME_LEN                 ( 16 )
#define configUSE_TRACE_FACILITY                0
#define configUSE_16_BIT_TICKS                  0
#define configIDLE_SHOULD_YIELD                 1
#define configUSE_MUTEXES                       0
#define configQUEUE_REGISTRY_SIZE               0
#define configCHECK_FOR_STACK_OVERFLOW          2
#define configUSE_RECURSIVE_MUTEXES             0
#define configUSE_MALLOC_FAILED_HOOK            1
#define configUSE_APPLICATION_TASK_TAG          0
#define configUSE_COUNTING_SEMAPHORES           0
#define configGENERATE_RUN_TIME_STATS           0
#define configUSE_PORT_OPTIMISED_TASK_SELECTION 0
#define configUSE_QUEUE_SETS                    0
#define configTASK_NOTIFICATION_ARRAY_ENTRIES   1

/* Co-routine definitions. */
#define configUSE_CO_ROUTINES                   0
#define configMAX_CO_ROUTINE_PRIORITIES         ( 2 )

/* Software timer definitions. */
#define configUSE_TIMERS                        1
#define configTIMER_TASK_PRIORITY               ( configMAX_PRIORITIES - 1 )  //2
#define configTIMER_QUEUE_LENGTH                10
#define configTIMER_TASK_STACK_DEPTH            ( configMINIMAL_STACK_SIZE *2 )

//#define configISR_STACK_SIZE_WORDS              256 // Defined by linker script

/* Task priorities.  Allow these to be overridden. */

/* Set the following definitions to 1 to include the API function, or zero
 * to exclude the API function. */
#define INCLUDE_vTaskPrioritySet                0
#define INCLUDE_uxTaskPriorityGet               0
#define INCLUDE_vTaskDelete                     0
#define INCLUDE_vTaskCleanUpResources           0
#define INCLUDE_vTaskSuspend                    1
#define INCLUDE_vTaskDelayUntil                 1
#define INCLUDE_vTaskDelay                      1
#define INCLUDE_eTaskGetState                   1
#define INCLUDE_xTimerPendFunctionCall          1
#define INCLUDE_xTaskAbortDelay                 1
#define INCLUDE_xTaskGetHandle                  1
#define INCLUDE_xSemaphoreGetMutexHolder        1
#define INCLUDE_uxTaskGetStackHighWaterMark     1 /* Used to get minimum stack size */

/* Normal assert() semantics without relying on the provision of an assert.h
 * header file. */
#define configASSERT( x ) if( ( x ) == 0 ) { taskDISABLE_INTERRUPTS(); __asm volatile( "ebreak" ); for( ;; ); }

/* Defined in main.c and used in main_blinky.c and main_full.c. */
void vSendString( const char * const pcString );

#endif /* FREERTOS_CONFIG_H */
