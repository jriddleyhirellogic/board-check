/*
 * pps.c
 *
 *  Created on: Jun 29, 2026
 *      Author: iboard
 */

#include "pps.h"
#include "config.h"

void v_PPS_Start(void)
{
    PPS_BASE[TRIGGER_TIME_JAM] = 1;
}

void v_PPS_Load_Seconds(Sys_Time_t *p_Time)
{
    PPS_BASE[LOAD_SECONDS]  = p_Time->u32_Time_Sec;
}

void v_PPS_Set_Rx_Delay(uint32_t u32_Delay)
{
    PPS_BASE[PPS_RX_DELAY] = u32_Delay;
}

void v_PPS_Enable_Local_PPS_Source(uint8_t b_Enable)
{
    PPS_BASE[EN_LOCAL_PPS_SOURCE] = b_Enable ? 1 : 0;
}

uint32_t u32_Get_PPS_Freq_Error(void)
{
    return PPS_BASE[FREQUENCY_ERROR];
}

uint32_t u32_Get_PPS_Phase_Error(void)
{
    return PPS_BASE[PHASE_ERROR];
}

uint8_t b_PPS_Is_Locked(void)
{
    return 1;
}

void v_Get_PPS_Time(Sys_Time_t *PPS_Time)
{
    PPS_Time->u32_Time_Sec = PPS_BASE[SECONDS];
    PPS_Time->u32_Time_msec = PPS_BASE[NANOSECONDS] / 1000000;

}

static void v_Reset_PPS_Irq(void)
{
    PPS_BASE[RESET_IRQ] = 1;
}

void v_Enable_PPS_IRQ( uint8_t b_Enable )
{
    if( b_Enable )
    {
        __asm volatile ( "csrs mie, %0" ::"r" ( PPS_IRQ ) );
    }
    else
    {
        __asm volatile ( "csrc mie, %0" ::"r" ( PPS_IRQ ) );
    }
}

static uint32_t u32_PPS_Counter;

void v_PPS_IRQ_Handler()
{
    v_Reset_PPS_Irq();
    ++u32_PPS_Counter;
}
