/*
 * pwm.h
 *
 *  Created on: Sep 29, 2025
 *      Author: iboard
 */

#ifndef HAL_PWM_H_
#define HAL_PWM_H_

#define PWM_VREF_mV    3200
#define PWM_MAX_DC     0xFFFF
#define COUNT_PER_MV ((PWM_MAX_DC << 10)/PWM_VREF_mV)
#define I_MAX_MA 2500

typedef struct
{
    uint32_t u32_Base_Address;
}PWM_Instance_t;

typedef struct
{
    uint32_t u32_Base_Address;
    uint16_t u16_Prescale;
    uint16_t u16_Period;
    uint16_t u16_Posedge;
    uint16_t u16_Negedge;
}PWM_Init_t;

// Register Offsets

#define PRESCALE_REG_OFFSET        0
#define PERIOD_REG_OFFSET          4
#define PWM_ENABLE_0_7_REG_OFFSET  8
#define SYNC_UPDATE_REG_OFFSET     0xE4
#define PWM1_POSEDGE_REG_OFFSET    0x10
#define PWM1_NEGEDGE_REG_OFFSET    0x14

void v_Init_PWM( PWM_Instance_t *, PWM_Init_t *);
void v_Set_PWM_Duty_Cycle( PWM_Instance_t *, uint16_t u16_Duty_Cycle );
void PWM_Set_Voltage_mV( PWM_Instance_t *, uint16_t u16_V_Set_mV );
void PWM_Set_Current_mA( PWM_Instance_t *instance, uint16_t u16_I_Set_mA );

#endif /* HAL_PWM_H_ */
