/*
 * timer.c
 *
 *  Created on: Nov 24, 2025
 *      Author: iboard
 */
#include <stdint.h>
#include "mem_map.h"
#include "timer.h"


void v_Init_Timer(Timer_Instance_t *p_Instance,  Timer_Init_t *p_Init )
{
    p_Instance->u32_Base_Address = p_Init->u32_Base_Address;

    // Set mode and start with timer and irq disabled
    *(volatile uint32_t *)(p_Instance->u32_Base_Address + TIMER_CONTROL_OFFSET ) = p_Init->u8_Mode;

    // Set prescale
    *(volatile uint32_t *)(p_Instance->u32_Base_Address + TIMER_PRESCALE_OFFSET ) = p_Init->u8_Prescale & 0xF;

    // Clear any pending interrupt
    *(volatile uint32_t *)(p_Instance->u32_Base_Address + TIMER_IRQ_CLR_OFFSET ) = 1;
}

void v_Enable_Timer(Timer_Instance_t *p_Instance, uint8_t b_Enable)
{
    uint32_t u32_Regval = *(volatile uint32_t *)(p_Instance->u32_Base_Address + TIMER_CONTROL_OFFSET );

    if( b_Enable )
    {
        u32_Regval |= TIMER_ENABLE;

    }
    else
    {
        u32_Regval &= ~TIMER_ENABLE;
    }

    *(volatile uint32_t *)(p_Instance->u32_Base_Address + TIMER_CONTROL_OFFSET ) = u32_Regval;
}

void v_Load_Timer(Timer_Instance_t *p_Instance, uint16_t u16_Timer_Reload_Value )
{
    *(volatile uint32_t *)(p_Instance->u32_Base_Address + TIMER_LOAD_OFFSET )= u16_Timer_Reload_Value;
}

void v_Enable_Timer_IRQ(Timer_Instance_t *p_Instance, uint8_t b_Enable)
{
    uint32_t u32_Regval = *(volatile uint32_t *)(p_Instance->u32_Base_Address + TIMER_CONTROL_OFFSET );

    if( b_Enable )
    {
        u32_Regval |= TIMER_IRQ_ENABLE;

    }
    else
    {
        u32_Regval &= ~TIMER_IRQ_ENABLE;
    }

    *(volatile uint32_t *)(p_Instance->u32_Base_Address + TIMER_CONTROL_OFFSET ) = u32_Regval;

}

uint8_t b_Check_Timer_IRQ_Status( Timer_Instance_t *p_Instance )
{
    uint8_t u8_IRQ_Status = *(volatile uint32_t *)(p_Instance->u32_Base_Address + TIMER_MASKED_IRQ_STATUS_OFFSET );
    return u8_IRQ_Status;
}
