/*
 * debug_switches.c
 *
 *  Created on: Feb 6, 2026
 *      Author: iboard
 */
#include "mem_map.h"
#include "core_gpio.h"
#include "debug_switches.h"

static gpio_instance_t debug_switches;

void v_Init_Debug_Switches(void)
{
    debug_switches.apb_bus_width = GPIO_APB_32_BITS_BUS;
    debug_switches.base_addr = DBG_GPIO_BASE_ADDR;
}

uint32_t u32_Get_Switch_State(void)
{
    uint32_t u32_Inputs = GPIO_get_inputs(&debug_switches);
    return u32_Inputs & ALL_SWITCHES;
}


