/*
 * debug_gpio.h
 *
 *  Created on: Sep 27, 2025
 *      Author: iboard
 */

#ifndef DEBUG_GPIO_H_
#define DEBUG_GPIO_H_

#include "mem_map.h"

typedef enum
{
    eLED_PIN  = 0,
    eJ8_DEBUG_PIN_3,
    eJ8_DEBUG_PIN_5,
    eJ8_DEBUG_PIN_13,
    eJ7_PIN_2,
    eJ7_PIN_4,
    eJ7_PIN_6,
    eJ7_PIN_1,
    eJ7_PIN_3,
    eJ7_PIN_5,
    eJ1_PIN_1,
    eJ1_PIN_3,
    eJ1_PIN_5,
    eJ1_PIN_7,
    eJ1_PIN_9,
    eJ1_PIN_11,
    eJ2_PIN_1,
    eJ2_PIN_3,
    eJ2_PIN_5,
    eJ2_PIN_7,
    eJ2_PIN_9,
    eJ2_PIN_11,
    NUMBER_GPIO_PINS
}eDebug_GPIO_Pin_t;

#define LED_PIN              (1 << 0)
#define J8_DEBUG_PIN_3       (1 << 1)
#define J8_DEBUG_PIN_5       (1 << 2)
#define J8_DEBUG_PIN_13      (1 << 4)
#define J7_PIN_2             (1 << 5)
#define J7_PIN_4             (1 << 6)
#define J7_PIN_6             (1 << 7)
#define J7_PIN_1             (1 << 8)
#define J7_PIN_3             (1 << 9)
#define J7_PIN_5             (1 << 10)
#define J1_PIN_1             (1 << 11)
#define J1_PIN_3             (1 << 12)
#define J1_PIN_5             (1 << 13)
#define J1_PIN_7             (1 << 14)
#define J1_PIN_9             (1 << 15)
#define J1_PIN_11            (1 << 16)
#define J2_PIN_1             (1 << 17)
#define J2_PIN_3             (1 << 18)
#define J2_PIN_5             (1 << 19)
#define J2_PIN_7             (1 << 20)
#define J2_PIN_9             (1 << 21)
#define J2_PIN_11            (1 << 22)

void v_Init_Debug_GPIO(void);
void v_Set_Debug_GPIO(uint32_t u32_Set, uint32_t u32_Clear );
void v_Set_LED( uint8_t b_On );

#endif /* DEBUG_GPIO_H_ */
