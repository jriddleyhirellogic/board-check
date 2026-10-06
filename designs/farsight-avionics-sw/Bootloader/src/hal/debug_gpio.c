/*
 * debug_gpio.c
 *
 *  Created on: Sep 27, 2025
 *      Author: iboard
 */
#include <stdint.h>
#include "core_gpio.h"
#include "debug_gpio.h"
#include "mem_map.h"

static gpio_instance_t debug_gpios;
static uint32_t u32_Current_Output;

void v_Init_Debug_GPIO(void)
{
    uint8_t u8_N_Pin;

    GPIO_init( &debug_gpios, DBG_GPIO_BASE_ADDR, GPIO_APB_32_BITS_BUS );

    u32_Current_Output = 0;

}

/*
 * void GPIO_set_output
(
    gpio_instance_t *   this_gpio,
    gpio_id_t           port_id,
    uint8_t             value
)

uint32_t GPIO_get_outputs
(
    gpio_instance_t *   this_gpio
)
 */

void v_Set_Debug_GPIO(uint32_t u32_Set, uint32_t u32_Clear )
{
    uint32_t u32_Current_Outputs = GPIO_get_outputs( &debug_gpios );
    if( u32_Set )
    {
      u32_Current_Outputs |= u32_Set;
      GPIO_set_outputs( &debug_gpios, u32_Current_Outputs );
    }
    if( u32_Clear )
    {
        u32_Current_Outputs &= ~u32_Clear;
        GPIO_set_outputs( &debug_gpios, u32_Current_Outputs );
    }
}

void v_Set_LED( uint8_t b_On )
{
    if( b_On )
        v_Set_Debug_GPIO( LED_PIN, 0 );
    else
        v_Set_Debug_GPIO( 0, LED_PIN  );

}


