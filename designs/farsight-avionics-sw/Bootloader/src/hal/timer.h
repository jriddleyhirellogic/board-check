/*
 * timer.h
 *
 *  Created on: Nov 24, 2025
 *      Author: iboard
 */

#ifndef HAL_TIMER_H_
#define HAL_TIMER_H_

typedef enum
{
    TIMER_PRESCALE_FACTOR_2,
    TIMER_PRESCALE_FACTOR_4,
    TIMER_PRESCALE_FACTOR_8,
    TIMER_PRESCALE_FACTOR_16,
    TIMER_PRESCALE_FACTOR_32,
    TIMER_PRESCALE_FACTOR_64,
    TIMER_PRESCALE_FACTOR_128,
    TIMER_PRESCALE_FACTOR_256,
    TIMER_PRESCALE_FACTOR_512,
    TIMER_PRESCALE_FACTOR_1024
}Timer_Prescale_t;

// Timer Register Offsets from base address
#define TIMER_LOAD_OFFSET              0
#define TIMER_VALUE_OFFSET             0x4
#define TIMER_CONTROL_OFFSET           0x8
#define TIMER_PRESCALE_OFFSET          0xC
#define TIMER_IRQ_CLR_OFFSET           0x10
#define TIMER_IRQ_STATUS_OFFSET        0x14  // Raw interrupt status
#define TIMER_MASKED_IRQ_STATUS_OFFSET 0x18

// Timer Control Bits
#define TIMER_ENABLE      (1 << 0)
#define TIMER_IRQ_ENABLE  (1 << 1)
#define TIMER_MODE        (1 << 2)

#define TIMER_MODE_ONE_SHOT (1 << 2)
#define TIMER_MODE_CONT     0


typedef struct
{
    uint32_t u32_Base_Address;
}Timer_Instance_t;

typedef struct
{
    uint32_t u32_Base_Address;
    uint8_t u8_Prescale;
    uint8_t u8_Mode;
}Timer_Init_t;

void v_Init_Timer(Timer_Instance_t *p_Instance,  Timer_Init_t *p_Init );
void v_Enable_Timer(Timer_Instance_t *p_Instance, uint8_t b_Enable);
void v_Load_Timer(Timer_Instance_t *p_Instance, uint16_t u16_Timer_Reload_Value );
void v_Enable_Timer_IRQ(Timer_Instance_t *p_Instance, uint8_t b_Enable);
uint8_t b_Check_Timer_IRQ_Status( Timer_Instance_t *p_Instance );

#endif /* HAL_TIMER_H_ */
