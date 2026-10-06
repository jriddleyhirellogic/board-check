/*
 * hw_init.c
 *
 *  Created on: Oct 3, 2025
 *      Author: iboard
 */
#include <stdint.h>
#include <string.h>

#include "FreeRTOSConfig.h"
#include "FreeRTOS.h"
#include "task.h"
#include "event_groups.h"
#include "mem_map.h"

#include "config.h"

#include "hal_uart16550.h"
#include "serial_comm.h"
#include "debug_gpio.h"
#include "core_gpio.h"
#include "gpio_pin_def.h"
#include "debug_switches.h"
#include "pwm.h"
#include "hal_stepper.h"
#include "lvdt.h"
#include "timer.h"
#include "misc.h"
#include "register.h"
#include "crc.h"
#include "debug_mux.h"
#include "debug_switches.h"
#include "flash.h"
#include "cal.h"

// For now only stepper 1 is being used. Later, there will be a provision to switch over to the other in case of failure.
static UART_16550_Instance_t Serial_Comm_UART;
static Stepper_Instance_t Primary_Stepper, Secondary_Stepper;
static Timer_Instance_t Serial_Timer_Instance;

static gpio_instance_t Power_GPIOs;
static gpio_instance_t Power_Status;

/**
 * @fn void v_Hw_Init(void)
 * @brief Low level hardware initialization.
 * This is called before the scheduler is started.
 *
 */

// Note: the scheduler and interrupts are not running when this is called so task delays cannot be used.
void v_Hw_Init(void)
{
    uint32_t u32_CRC;
    uint8_t u8_Status;
    uint32_t u32_ID;
    uint8_t u8_Test;
    uint8_t u8_N;
    uint8_t b_Program = 1;

    v_Init_Debug_Mux();
//    v_Set_Debug_Mux( STEPPER_DEBUG  );
   v_Set_Debug_Mux( DEFAULT_DEBUG  );
    // v_Set_Debug_Mux( QSPI_DEBUG  );
//    v_Set_Debug_Mux( TLM_DEBUG   );
    v_Init_Debug_Switches();

    // Done before any of the hardware init as some will use register settings
    v_Init_Registers();

    v_Init_Flash();
    v_Flash_Reset();
    v_Global_Flash_Unlock();

    v_Init_Calibration();

    // Power up necessary LDOs
    GPIO_init( &Power_GPIOs , GPO_HK_PWR_BASE_ADDR, GPIO_APB_32_BITS_BUS);
    GPIO_init( &Power_Status , GPI_HK_STATUS_BASE_ADDR, GPIO_APB_32_BITS_BUS);

    //GPIO_set_output( &Power_GPIOs, STEPPER_SEC_PWR_EN, 1);
    GPIO_set_output( &Power_GPIOs, LVDT_PWR_EN, 1);

    // Serial Comm UART
    Serial_Comm_UART.u32_Base_Address = TMTC_UART_BASE_ADDR;
    Serial_Comm_UART.u8_Status = 0;
    v_Init_UART( &Serial_Comm_UART );

    // Serial comm timer
    Timer_Init_t Timer_Init =
    {
        .u32_Base_Address = SERIAL_COMM_TIMER_BASE,
         .u8_Prescale = TIMER_PRESCALE_FACTOR_2,
         .u8_Mode = TIMER_MODE_ONE_SHOT
    };
    v_Init_Timer( &Serial_Timer_Instance,  &Timer_Init );

    v_Set_Serial_Comm_Instance( &Serial_Comm_UART );
    v_Set_Serial_Timer_Instance( &Serial_Timer_Instance );

    /* Initializing primary stepper interface */
    // Stepper Control Block
    /*
     * Initial setup for stepper
     * M0: 1
     * M1: Hi-Z
     * Decay0: 0
     * Decay1: 1
     * TOFF: 1 or Hi-Z
     * nSleep: 1
     * Enable : 0 or 1 depending on mode
     * Vref : 304 mV
     */
    PWM_Init_t Pri_PWM_Init =
    {
       .u32_Base_Address = PRI_STP_VREF_BASE_ADDR,
       .u16_Prescale = 1,
       .u16_Period = (1 << 16)-1, // 16 bit
       .u16_Negedge = 0
    };

    uint32_t u32_Stepper_Control_Base;
    uint32_t u32_Stepper_Out_Base;
    uint32_t u32_Stepper_Overflow_Base;
    uint32_t u32_Overflow_Value;
    PWM_Init_t *Pwm_Init;
    uint8_t u8_Power_Enable;

    Stepper_Init_t Pri_Stepper_Init =
    {
        .u32_Stepper_Control_Base = PRI_STP_CTRL_BASE_ADDR,
        .u32_Stepper_Out_Base = PRI_STP_OUT_BASE_ADDR,
        .Pwm_Init = &Pri_PWM_Init,
        .u8_Power_Enable = STEPPER_PRI_PWR_EN,
        .u32_Stepper_Overflow_Base = PRI_STP_APB_STEPPER_OVERFLOW,
        .u32_Overflow_Value = 4882813
    };

    v_Init_Stepper( &Primary_Stepper, &Pri_Stepper_Init );

    v_Set_Stepper_Instance( &Primary_Stepper );
    v_Set_Stepper_Control_Output( STEPPER_CONTROL_DEFAULTS  );
    v_Set_Microstep_Mode( STEP_256 );
    v_Set_Decay_Mode( SMART_DYNAMIC_DECAY_MODE );

    /* Initializing secondary stepper interface */
    // Initialization is the same as the primary, just different addresses
    PWM_Init_t Sec_PWM_Init =
    {
       .u32_Base_Address = SEC_STP_VREF_BASE_ADDR,
       .u16_Prescale = 1,
       .u16_Period = (1 << 16)-1, // 16 bit
       .u16_Negedge = 0
    };

    Stepper_Init_t Sec_Stepper_Init =
    {
        .u32_Stepper_Control_Base = SEC_STP_CTRL_BASE_ADDR,
        .u32_Stepper_Out_Base = SEC_STP_OUT_BASE_ADDR,
        .Pwm_Init = &Sec_PWM_Init,
        .u8_Power_Enable = STEPPER_SEC_PWR_EN,
        .u32_Stepper_Overflow_Base = SEC_STP_APB_STEPPER_OVERFLOW,
        .u32_Overflow_Value = 4882813
    };


    v_Init_Stepper( &Secondary_Stepper, &Sec_Stepper_Init );
    v_Set_Stepper_Instance( &Secondary_Stepper );
    v_Set_Stepper_Control_Output( STEPPER_CONTROL_DEFAULTS  );
    v_Set_Microstep_Mode( STEP_256 );
    v_Set_Decay_Mode( SMART_DYNAMIC_DECAY_MODE );

    //v_Set_Stepper_Instance( &Secondary_Stepper );
    v_Set_Stepper_Instance( &Primary_Stepper );


#ifdef STEPPER_3p3V
    v_Stepper_Set_Vref( 304 );        // For use with the 3.3V stepper
#else
    v_Stepper_Set_I_Max_mA( 300 );//150 );    // For use with 12V stepper
#endif

    v_Set_Stepper_out(  0 );

    // LVDT
    v_Init_LVDT();
    v_Set_LVDT_Gain( LVDT_GAIN_1 );

    // Various Debug GPIOs
    v_Init_Debug_GPIO();

    v_PPS_Enable_Local_PPS_Source(1);

}

uint32_t u32_Get_Power_Enables(void)
{
    uint32_t u32_Status = GPIO_get_outputs( &Power_GPIOs );
    return u32_Status;
}

uint32_t u32_Get_Power_Status(void)
{
    uint32_t u32_Status = GPIO_get_inputs( &Power_Status );
    return u32_Status;
}

void v_Set_Stepper_Vel(uint32_t u32_Vel)
{
    v_Set_Stepper_out( u32_Vel );
}

