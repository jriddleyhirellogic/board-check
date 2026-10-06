/*
 * pwm.c
 *
 *  Created on: Sep 29, 2025
 *      Author: iboard
 */
#include <assert.h>
#include "hal.h"
#include "hw_reg_access.h"
#include "pwm.h"

/**
 * @fn void v_Init_PWM(PWM_Instance_t*, PWM_Init_t*)
 * @brief Initializes the pwm VRef generator used to set the current limit.
 * @param instance to particular PWM instance.
 * @param init
 */
void v_Init_PWM( PWM_Instance_t *instance, PWM_Init_t *init)
{
    // Set base address
    instance->u32_Base_Address = init->u32_Base_Address;

    // Start with PWM disabled
    HAL_set_16bit_reg( instance->u32_Base_Address, PWM_ENABLE_0_7, 0);

    // Prescaler
    HAL_set_16bit_reg( instance->u32_Base_Address, PRESCALE, init->u16_Prescale );

    // Period - in cycles of clk/prescale value
    HAL_set_16bit_reg( instance->u32_Base_Address, PERIOD, init->u16_Period );

    // Posedge
    //HAL_set_16bit_reg( instance->u32_Base_Address, PWM1_POSEDGE, init->u16_Posedge );

    // Negedge
    HAL_set_16bit_reg( instance->u32_Base_Address, PWM1_NEGEDGE, init->u16_Negedge );

    // Enable channel 0
    HAL_set_16bit_reg( instance->u32_Base_Address, PWM_ENABLE_0_7, 1 );

}

/**
 * @fn void v_Set_PWM_Duty_Cycle(PWM_Instance_t*, uint16_t)
 * @brief Sets the PWM duty cycle
 * The PWM signal is lowpass filtered to produce a voltage which is input to the stepper controller.
 * The output voltage is given by: v_out = V_ref * u16_Duty_Cycle/(2^16-1)
 * @param instance The actual instance of the PWM generator in case system has more than one.
 * @param u16_Duty_Cycle
 */
void v_Set_PWM_Duty_Cycle( PWM_Instance_t *instance, uint16_t u16_Duty_Cycle )
{
    HAL_set_16bit_reg( instance->u32_Base_Address, PWM1_NEGEDGE, u16_Duty_Cycle );
}

/*
 * The relationship between the data duty cycle and the current setpoint is:
 * I_FS = (V_Ref / K_V) * DC (%)
 *
 *      => DC(%) = (I_FS(mA) * 1.32) / 3200 (mV)
 */

/**
 * @fn void PWM_Set_Voltage_mV(PWM_Instance_t*, uint16_t)
 * @brief Converts a desired voltage into an equivalent duty cycle.
 * This is assuming VRef = 3200 mV.
 * @param instance PWM instance in use.
 * @param u16_V_Set_mV Desired output voltage.
 */
void PWM_Set_Voltage_mV( PWM_Instance_t *instance, uint16_t u16_V_Set_mV )
{
    uint32_t u32_Temp;
    uint16_t u16_DC_Setpoint;
    /** PWM Count = (set_v_mv / vref_mv) * max_count
                  = (max_count / vref_mv) * set_v_mv
               */
    u32_Temp = COUNT_PER_MV * (uint32_t)u16_V_Set_mV;
    u16_DC_Setpoint = (uint16_t)(u32_Temp >> 10 );
#ifndef FULL_STEPPER_CURRENT
    HAL_set_16bit_reg( instance->u32_Base_Address, PWM1_NEGEDGE, u16_DC_Setpoint );
#else
    HAL_set_16bit_reg( instance->u32_Base_Address, PWM1_NEGEDGE, 0xFFFF );
#endif

}

/**
 * @fn void PWM_Set_Current_mA(PWM_Instance_t*, uint16_t)
 * @brief Converts a desired max current for stepper into an equivalent duty cycle.
 * This is assuming the use of a TI DRV8434 stepper driver IC.
 * @param instance The PWM instance in use.
 * @param u16_I_Set_mA Desired max current in mA.
 */
void PWM_Set_Current_mA( PWM_Instance_t *instance, uint16_t u16_I_Set_mA )
{
    /**
     * Count/2^16 = (I_mA * 1.32)/V_ref(mV)
     * => Count = (I_mA *1.32 * 2^16)/3200   assumes Vref = 3200 mV
     *          ~= I_mA * 27
     */
    assert(u16_I_Set_mA < I_MAX_MA );
    uint16_t u16_DC_Setpoint = u16_I_Set_mA * 27;
#ifndef FULL_STEPPER_CURRENT
#ifdef AVIONICS_BOARD
    HAL_set_16bit_reg( instance->u32_Base_Address, PWM1_NEGEDGE, u16_DC_Setpoint*10 );
#else
    HAL_set_16bit_reg( instance->u32_Base_Address, PWM1_NEGEDGE, u16_DC_Setpoint );
#endif
#else
    HAL_set_16bit_reg( instance->u32_Base_Address, PWM1_NEGEDGE, 0xFFFF );
#endif

}
