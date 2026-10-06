/*
 * misc.c
 *
 *  Created on: Sep 27, 2025
 *      Author: iboard
 */

#include <stdint.h>
#include <assert.h>
#include <focus.h>
#include "FreeRTOSConfig.h"
#include "FreeRTOS.h"
#include "task.h"
#include "debug_switches.h"
#include "serial_comm.h"
#include "misc.h"
#include "hal_stepper.h"
#include "version.h"

static volatile uint8_t b_Logging_Enabled;
static uint8_t u8_SW2_Counter, u8_SW3_Counter;

//uint32_t u32_Step = 1;
uint32_t u32_Step = 50;
#define FAST 40
#define SLOW 1

/**
 * @fn void vApplicationMallocFailedHook()
 * @brief Handler in case malloc fails.
 * Currently, FreeRTOS is using the heap1 model, in which only malloc() is implemented,
 * not free(). Dynamic allocation is used only during initialization, not during operation.
 * Initialization failures are handled by configASSERT()s so this may not be necessary.
 *
 */
void vApplicationMallocFailedHook()
{
}

/**
 * @fn void vApplicationIdleHook()
 * @brief Called when no task is executing. This may be used in the future. It
 * is important that nothing that causes task suspension or delay be executed here.
 *
 */
void vApplicationIdleHook()
{
}


/**
 * @fn void vApplicationTickHook()
 * @brief Called during system tick. This is called after times have been updated - last - before any
 * context switch. This is currently unused but may be used in the future for things which call
 * for fast, low-overhead polling.
 *
 */
void v_Set_Stepper_Vel(uint32_t u32_Vel);

void vApplicationTickHook()
{
    uint32_t u32_Raw_Switch_State;

    uint8_t SW2_State_Debounced = u8_Update_Switch_Debounce( &u8_SW2_Counter, SW2);
    uint8_t SW3_State_Debounced = u8_Update_Switch_Debounce( &u8_SW3_Counter, SW3 );

    if( b_Is_Idle() )
    {
        u32_Raw_Switch_State = u32_Get_Switch_State();

        if( !(u32_Raw_Switch_State & SW2) || !(u32_Raw_Switch_State & SW3))
          v_Enable_Stepper(1);
        else
          v_Enable_Stepper(0);

        if( SW2_State_Debounced & !SW3_State_Debounced ) // these are debounced, so they give the stepper driver time to come up
        {
            v_Arm_Stepper_Watchdog();
            v_Set_Stepper_Vel( u32_Step*SLOW );                // UP - pos dir
//            v_Set_Stepper_Vel( u32_Step*FAST );
        }
        else if( !SW2_State_Debounced & SW3_State_Debounced )  // DOWN - neg dir
        {
            v_Arm_Stepper_Watchdog();
            v_Set_Stepper_Vel(-(u32_Step*SLOW) );
//            v_Set_Stepper_Vel(-(u32_Step*FAST) );
        }
        else
            v_Set_Stepper_Vel(0 );
    }
}

void vApplicationStackOverflowHook( TaskHandle_t xTask,  char * pcTaskName )
{
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wbuiltin-declaration-mismatch"

/**
 * @fn void memcpy(void*, void*, size_t)
 * @brief memcpy to avoid needing libgcc
 *
 * @param dest
 * @param from
 * @param n_bytes
 */
void memcpy( void *dest, void *from, size_t  n_bytes)
{
   size_t n;
   char *p_dest = (char *)dest;
   char *p_from = (char *)from;

   for( n = 0; n < n_bytes; n++ )
       *p_dest++ = *p_from++;
}

void memset(void *s, int c, size_t n_bytes)
{
  size_t n;
  char *p_dest = (char *)s;

  for( n = 0; n < n_bytes; n++ )
      *p_dest++ = (char)c;
}


#pragma GCC_diagnostic pop

#ifndef VECTORED_IRQ_FREERTOS
void v_UART16550_Handler(void);

void freertos_risc_v_application_interrupt_handler( unsigned long cause )
{
    uint8_t u8_Cause = cause & 0xff;

    if ( u8_Cause == 0xb )
    {
        v_UART16550_Handler();
    }
}

void v_IRQ_Setup(void)
{
#define MIE_MEIE ( 1UL << 11 )
__asm volatile ( "csrs mie, %0" ::"r" ( MIE_MEIE ) );
}

#else /* VECTORED_IRQ_FREERTOS */

/*
 * Strong override of the weak FreeRTOS default in portASM.S (which just spins).
 * It runs from freertos_risc_v_trap_handler AFTER the full interrupt context has
 * been saved to the TCB and sp switched to xISRStackTop, so it is safe to call
 * the FreeRTOS ...FromISR() APIs here. The MSYS external vectors EI3/EI4/EI5 in
 * miv_rv32_entry.S are routed here and dispatched by mcause. Running these on the
 * dedicated ISR stack (instead of the interrupted task's stack via the old
 * irq_save_regs path) is required to avoid stack corruption / firmware crash.
 */
extern void v_Camera_Trigger_IRQ_Handler(void);
extern void v_UDP_Transfer_Handler(void);
extern void v_PPS_IRQ_Handler(void);

void freertos_risc_v_application_interrupt_handler( unsigned long cause )
{
    switch ( cause & 0xff )
    {
        case 27:    /* MSYS EI3 - camera trigger */
            v_Camera_Trigger_IRQ_Handler();
            break;

        case 28:    /* MSYS EI4 - PPS */
            v_PPS_IRQ_Handler();
            break;

        case 29:    /* MSYS EI5 - UDP transfer complete */
            v_UDP_Transfer_Handler();
            break;

        default:
            break;
    }
}

#endif

/**
 * @fn void __assert_func(const char*, int, const char*, const char*)
 * @brief Function called when assert() fails
 * Keeps file, line number and function where assertion failed. To assist in debugging.
 * @param filename
 * @param line_number
 * @param function
 * @param test
 */
void _ATTRIBUTE ((__noreturn__)) __assert_func (const char *filename, int line_number, const char *function, const char *test)
{
    __asm volatile( "ebreak" );
    for( ;; );
}



