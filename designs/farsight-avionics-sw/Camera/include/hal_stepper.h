/*
 * stepper.h
 *
 *  Created on: Sep 27, 2025
 *      Author: iboard
 */

#ifndef HAL_STEPPER_H_
#define HAL_STEPPER_H_

#include <stdint.h>
#include "mem_map.h"
#include "core_gpio.h"
#include "pwm.h"

// Control Outputs
#define M0_SHIFT      0
#define M0_MASK       (1 << M0_SHIFT)
#define M1_SHIFT      1
#define M1_MASK       (1 << M1_SHIFT)
#define EN_SHIFT      2
#define EN_MASK       (1 << EN_SHIFT)
#define DECAY0_SHIFT  3
#define DECAY0_MASK   (1 << DECAY0_SHIFT)
#define DECAY1_SHIFT  4
#define DECAY1_MASK   (1 << DECAY1_SHIFT)
#define TOFF_SHIFT    5
#define TOFF_MASK     (1 << TOFF_SHIFT)
#define NSLEEP_SHIFT  6
#define NSLEEP_MASK   (1 << NSLEEP_SHIFT)
#define CONTROL_OUTPUTS (M0_MASK | M1_MASK | EN_MASK | DECAY0_MASK | DECAY1_MASK | TOFF_MASK | NSLEEP_MASK )

// Control Inputs
#define NFAULT_SHIFT  7
#define NFAULT_MASK   (1 << NFAULT_SHIFT)

#define OUTPUT_BUFFER_ENABLE_MASK   0x00000004UL

typedef struct
{
    gpio_instance_t stepper_controls; // bits [6:0] are outputs, bit [7] is input,apb 8 bits
    gpio_instance_t stepper_out;      // bits [31:0] are outputs, no inputs, apb is 8 bit address
    gpio_instance_t stepper_overflow; // makes overflow value programmable
    PWM_Instance_t  pwm;
    uint8_t Stepper_Power_Enable;
}Stepper_Instance_t;

typedef struct
{
    uint32_t u32_Stepper_Control_Base;
    uint32_t u32_Stepper_Out_Base;
    uint32_t u32_Stepper_Overflow_Base;
    uint32_t u32_Overflow_Value;
    PWM_Init_t *Pwm_Init;
    uint8_t u8_Power_Enable;
}Stepper_Init_t;

typedef enum
{
    FULL_STEP_FULL_CURRENT,            // 0       0
    NON_CIRCULAR_HALF_STEP,            // 1       0
    STEP_2,                            // HiZ     0
    STEP_4,                            // 0       1
    STEP_8,                            // 1       1
    STEP_16,                           // HiZ     1
    STEP_32,                           // 0       HiZ
    STEP_128,                          // HiZ     HiZ
    STEP_256                           // 1       HiZ

}Step_Mode_t;

typedef enum
{
    SMART_DYNAMIC_DECAY_MODE,
    SMART_RIPPLE_CONTROL_MODE,
    MIXED_30_PERCENT_FAST_MODE,
    SLOW_DECAY_INC_MODE,
    MIXED_60_PERCENT_FAST_MODE,
    SLOW_DECAY_MODE
}Decay_Mode_t;


// PWM
#define PWM_PRESCALE_REG_OFFSET        0
#define PWM_PERIOD_OFFSET              4
#define PWM_PWM_ENABLE_0_7_OFFSET      8
#define PWM_SYNC_UPDATE_OFFSET         0xC
#define PWM_PWM1_POSEDGE               0x10
#define PWM_PWM1_NEGEDGE               0x14

#define STEPPER_CONTROL_DEFAULTS ( DECAY1_MASK | TOFF_MASK | NSLEEP_MASK )

#define Focus_Watchdog_Clear_Reg          *(volatile uint32_t *)(STEPPER_WATCHDOG_BASE_ADDR)
#define Focus_Watchdog_Timeout_ms_Reg     *(volatile uint32_t *)(STEPPER_WATCHDOG_BASE_ADDR + 4)

#define Focus_Watchdog_Status_Reg         *(volatile uint32_t *)(STEPPER_WATCHDOG_BASE_ADDR + 8)
#define FOCUS_WATCHDOG_ACTIVE  (1 << 0)

#define WATCHDOG_TIMEOUT_MS 100

void v_Init_Stepper( Stepper_Instance_t *instance, Stepper_Init_t *init );
void v_Set_Stepper_Control_Output(  uint8_t u8_Output );
void v_Stepper_Control_Enable_HiZ(  uint8_t u8_Set );
void v_Set_Stepper_out(  uint32_t u32_Output);
uint8_t u8_Get_Stepper_NFAULT( void );
void v_Stepper_Set_Vref(  uint16_t u16_V_Set_mV );
void v_Stepper_Set_I_Max_mA( uint16_t u16_V_Set_I_Max_mA );
void v_Set_Microstep_Mode( Step_Mode_t e_Mode );
void v_Set_Decay_Mode( Decay_Mode_t e_Mode );
void v_Enable_Stepper( uint8_t b_Enable );
int32_t i32_Get_Stepper_Out(void);
void v_Set_Stepper_Instance(Stepper_Instance_t *instance );
uint8_t u8_Get_Stepper_Watchdog_Status(void);
void v_Refresh_Stepper_Watchdog(void);
void v_Arm_Stepper_Watchdog(void);


#endif /* HAL_STEPPER_H_ */
