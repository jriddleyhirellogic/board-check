/*
 * debug_mux.c
 *
 *  Created on: Feb 3, 2026
 *      Author: iboard
 */
#include "core_gpio.h"
#include "mem_map.h"
#include "debug_mux.h"

static gpio_instance_t debug_mux_setting;

void v_Init_Debug_Mux(void)
{
    debug_mux_setting.apb_bus_width = GPIO_APB_32_BITS_BUS;
    debug_mux_setting.base_addr = DBG_GPIO_BASE_ADDR;
}

void v_Set_Debug_Mux(Debug_Mux_Setting_t eSetting )
{
    GPIO_set_outputs( &debug_mux_setting,  ((uint32_t)eSetting & 0xe ));
}

void v_Set_Heartbeat_LED( uint8_t u8_On )
{
    GPIO_set_output(&debug_mux_setting, GPIO_0, u8_On != 0);
}
