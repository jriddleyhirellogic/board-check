/*
 * hw_init.c
 *
 *  Created on: Oct 3, 2025
 *      Author: iboard
 */
#include <stdint.h>

#include "mem_map.h"
#include "hal_uart16550.h"
#include "serial_comm.h"
#include "hal/timer.h"
#include "flash.h"
#include "debug_mux.h"
#include "debug_switches.h"
#include "crc.h"

static UART_16550_Instance_t Serial_Comm_UART;
static Timer_Instance_t Serial_Timer_Instance;


void v_Hw_Init(void)
{
    v_Init_Debug_Mux();
    v_Set_Debug_Mux( QSPI_DEBUG  );

    v_Init_Debug_Switches();

    // Serial Comm UART
    Serial_Comm_UART.u32_Base_Address = TMTC_UART_BASE_ADDR;
    Serial_Comm_UART.u8_Status = 0;
    v_Init_UART( &Serial_Comm_UART );

    // Serial comm timer
    Timer_Init_t Timer_Init =
    {
        .u32_Base_Address = SERIAL_COMM_TIMER_BASE,
         .u8_Prescale = TIMER_PRESCALE_FACTOR_2,
         .u8_Mode = TIMER_MODE_ONE_SHOT
    };

    v_Init_Timer( &Serial_Timer_Instance,  &Timer_Init );

    v_Set_Serial_Comm_Instance( &Serial_Comm_UART );
    v_Set_Serial_Timer_Instance( &Serial_Timer_Instance );

    v_Init_Flash();
    v_Flash_Reset();
    v_Global_Flash_Unlock();

    Reset_Serial_SM();
    v_Enable_Serial_Comm();  // Does not enable interrupts in MIE

}

//void v_Framing_Timeout(void);
void v_Check_Serial_IRQs(void);

//void v_Check_Serial(void);

void v_Check_IRQs(void)
{
    v_Check_Serial_IRQs();
}

