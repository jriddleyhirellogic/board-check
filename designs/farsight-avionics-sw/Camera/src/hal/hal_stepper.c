/*
 * hal_stepper.c
 *
 *  Created on: Sep 27, 2025
 *      Author: iboard
 */

#include "hal_stepper.h"
#include "gpio_pin_def.h"

/** Stepper calculations:
 *
 * lead screw displacement [microns/step pulse] = lead screw pitch/(fraction of input rev/pulse * microstep ratio * gear reduction ratio)
 *                                              =  500.0 [microns] / ( 20 * MS * 256)
 *                                              = 97.65625e-3/MS where MS = microstep ratio
 *
 *  step pulse base frequency = f_clk/counter overflow
 *                            = 50.0e6 / 190735
 *                            = 262.1438 [steps/sec]
 *
 *  pulse frequency = counter increment * base frequency
 *
 * For f_clk = 50 MHz, the base rates of travel [microns/sec], to be multiplied by counter increment, are:
 *
 * MS = 1  => 2.56e1  [microns/sec]
 * MS = 2  => 1.28e1  [microns/sec]
 * MS = 4  => 6.4e0   [microns/sec]
 * MS = 8  => 3.2e0   [microns/sec]
 * MS = 16 => 1.6e0   [microns/sec]
 * MS = 32 => 8.0e-1  [microns/sec]
 * MS = 128 => 2.0e-1 [microns/sec]
 * MS = 256 => 1.0e-1 [microns/sec]
 *
 *
 */
static Stepper_Instance_t *p_instance;
static gpio_instance_t Power_GPIOs;

void v_Init_Stepper( Stepper_Instance_t *instance, Stepper_Init_t *init )
{
    uint8_t u8_N;
    uint32_t u32_Config_Reg_Addr;

    GPIO_init( &Power_GPIOs , GPO_HK_PWR_BASE_ADDR, GPIO_APB_32_BITS_BUS);
    instance->Stepper_Power_Enable = init->u8_Power_Enable;

    p_instance = instance;

    gpio_instance_t *p_Gpio_Instance = &p_instance->stepper_controls;

    // Stepper Controls
    // bits[6:0] are outputs, bit[7] is input
    p_Gpio_Instance->apb_bus_width = GPIO_APB_32_BITS_BUS;
    p_Gpio_Instance->base_addr = init->u32_Stepper_Control_Base;

    // Set up config register for output bits [6:0]
    for( u8_N = 0; u8_N < 7; u8_N++ )
    {
        GPIO_config( p_Gpio_Instance, u8_N, GPIO_OUTPUT_MODE );
    }

    // Overflow value
    p_Gpio_Instance = &p_instance->stepper_overflow;
    p_Gpio_Instance->apb_bus_width = GPIO_APB_32_BITS_BUS;
    p_Gpio_Instance->base_addr = init->u32_Stepper_Overflow_Base;
    GPIO_set_outputs(p_Gpio_Instance, init->u32_Overflow_Value );

    // Stepper Out
    // bits[31:0] are outputs
    p_instance->stepper_out.apb_bus_width = GPIO_APB_32_BITS_BUS;
    p_instance->stepper_out.base_addr = init->u32_Stepper_Out_Base;

    // Initializing PWM to generate VRef
    v_Init_PWM( &p_instance->pwm, init->Pwm_Init );
}

void v_Set_Stepper_Instance(Stepper_Instance_t *instance )
{
    GPIO_set_output( &Power_GPIOs, STEPPER_PRI_PWR_EN, 0);
    GPIO_set_output( &Power_GPIOs, STEPPER_SEC_PWR_EN, 0);
    GPIO_set_output( &Power_GPIOs, instance->Stepper_Power_Enable, 1);
    p_instance = instance;
}

void v_Set_Microstep_Mode( Step_Mode_t e_Mode )
{
    uint8_t u8_HiZ_Set = 0;
    uint32_t u32_Current_Control_Output = GPIO_get_outputs( &p_instance->stepper_controls );
    u32_Current_Control_Output &= ~(M0_MASK | M1_MASK);

    switch( e_Mode )
    {                                        // M0      M1
    case FULL_STEP_FULL_CURRENT:             // 0       0
        break;

    case NON_CIRCULAR_HALF_STEP:             // 1       0
        u32_Current_Control_Output |= M0_MASK;
        break;

    case STEP_2:                             // HiZ     0
        // M0 value becomes don't care
        u8_HiZ_Set = M0_MASK;
        break;

    case STEP_4:                             // 0       1
        u32_Current_Control_Output |= M1_MASK;
        break;

    case STEP_8:                             // 1       1
        u32_Current_Control_Output |= (M0_MASK | M1_MASK);
        break;

    case STEP_16:                            // HiZ     1
        u8_HiZ_Set = M0_MASK;
        u32_Current_Control_Output |= M1_MASK;
        break;

    case STEP_32:                            // 0       HiZ
        u8_HiZ_Set = M1_MASK;
        break;

    case STEP_128:                           // HiZ     HkZ
        u8_HiZ_Set = (M0_MASK | M1_MASK);
        break;

    case STEP_256:                           // 1       HiZ
        u8_HiZ_Set = M1_MASK;
        u32_Current_Control_Output |= M0_MASK;
        break;

    default:
        break; // assert(0
    }

    v_Stepper_Control_Enable_HiZ( u8_HiZ_Set );
    GPIO_set_outputs( &p_instance->stepper_controls, u32_Current_Control_Output);

}


void v_Set_Decay_Mode( Decay_Mode_t e_Mode )
{
    uint8_t u8_HiZ_Set = 0;
    uint32_t u32_Current_Control_Output = GPIO_get_outputs( &p_instance->stepper_controls );
    u32_Current_Control_Output &= ~(DECAY0_MASK | DECAY1_MASK);

    switch( e_Mode )                //      DECAY0       DECAY1
    {
    case SMART_DYNAMIC_DECAY_MODE:  //        0            0
        break;

    case SMART_RIPPLE_CONTROL_MODE: //        0            1
        u32_Current_Control_Output |= DECAY1_MASK;
        break;

    case MIXED_30_PERCENT_FAST_MODE://        1            0
        u32_Current_Control_Output |= DECAY0_MASK;
        break;

    case SLOW_DECAY_INC_MODE:       //        1            1
        u32_Current_Control_Output |= (DECAY0_MASK | DECAY1_MASK);
        break;

    case MIXED_60_PERCENT_FAST_MODE://        Hi-Z         0
        u8_HiZ_Set |= DECAY0_MASK;
        break;

    case SLOW_DECAY_MODE:           //        Hi-Z         1
        u8_HiZ_Set |= DECAY0_MASK;
        u32_Current_Control_Output |= DECAY1_MASK;
        break;

    default:
        break; // assert(0
    }

    v_Stepper_Control_Enable_HiZ( u8_HiZ_Set );
    GPIO_set_outputs( &p_instance->stepper_controls, u32_Current_Control_Output);

}

void v_Enable_Stepper(uint8_t b_Enable )
{
    uint32_t u32_Current_Control_Output = GPIO_get_outputs( &p_instance->stepper_controls );
    if( b_Enable )
    {
        u32_Current_Control_Output |= EN_MASK;
    }
    else
    {
        u32_Current_Control_Output &= ~EN_MASK;
    }
    GPIO_set_outputs( &p_instance->stepper_controls, u32_Current_Control_Output);
}

void v_Set_Stepper_Control_Output( uint8_t u8_Output )
{
   gpio_instance_t *p_Gpio_Instance = &p_instance->stepper_controls;
   GPIO_set_outputs( p_Gpio_Instance, u8_Output & 0x7F );
}

void v_Stepper_Set_Vref( uint16_t u16_V_Set_mV )
{
    PWM_Set_Voltage_mV( &p_instance->pwm, u16_V_Set_mV );
}

void v_Stepper_Set_I_Max_mA( uint16_t u16_V_Set_I_Max_mA )
{
    PWM_Set_Current_mA( &p_instance->pwm, u16_V_Set_I_Max_mA );
}

// u8_Set_HiZ - enable/disable HiZ by bit position
void v_Stepper_Control_Enable_HiZ(  uint8_t u8_Set_HiZ )
{
    uint8_t u8_N;
    uint32_t u32_Config_Reg_Addr;
    uint8_t u8_Output_Enabled;
    uint8_t u8_Config;

    gpio_instance_t *p_Gpio_Instance = &p_instance->stepper_controls;
    for( u8_N = 0; u8_N < 7; u8_N++ )
    {
        // Each output bit has it's own enable register
        u32_Config_Reg_Addr = p_Gpio_Instance->base_addr + (u8_N * 4);
        u8_Config = HW_get_8bit_reg( u32_Config_Reg_Addr );

        if( !u8_Set_HiZ )  // All remaining outputs enabled, can exit early
            break;

        if( u8_Set_HiZ & (1 << u8_N))                       // Hi-Z enabled clear output enable bit
        {
            u8_Config &=  ~OUTPUT_BUFFER_ENABLE_MASK;
            u8_Set_HiZ &= ~(1 << u8_N);

        }
        else                  // Normal mode, set output enable bit
        {
            u8_Config |= OUTPUT_BUFFER_ENABLE_MASK;    // Hi-Z disabled, output enabled
        }

        HW_set_8bit_reg( u32_Config_Reg_Addr, u8_Config );

    }

}


void v_Set_Stepper_out(  uint32_t u32_Output)
{
    gpio_instance_t *p_Gpio_Instance = &p_instance->stepper_out;
    GPIO_set_outputs( p_Gpio_Instance, u32_Output );
}

int32_t i32_Get_Stepper_Out(void)
{
    gpio_instance_t *p_Gpio_Instance = &p_instance->stepper_out;
    return GPIO_get_outputs(p_Gpio_Instance);
}


uint8_t u8_Get_Stepper_NFAULT( void )
{
    uint32_t u32_Inputs;
    gpio_instance_t *p_Gpio_Instance = &p_instance->stepper_controls;
    u32_Inputs = GPIO_get_inputs(p_Gpio_Instance);
    return u32_Inputs & NFAULT_MASK != 0;
}

void v_Arm_Stepper_Watchdog(void)
{
    Focus_Watchdog_Clear_Reg = 1;
    Focus_Watchdog_Timeout_ms_Reg = WATCHDOG_TIMEOUT_MS;
    Focus_Watchdog_Clear_Reg = 0;
}

void v_Refresh_Stepper_Watchdog(void)
{
    Focus_Watchdog_Timeout_ms_Reg = WATCHDOG_TIMEOUT_MS;
}

uint8_t u8_Get_Stepper_Watchdog_Status(void)
{
    return (uint8_t)(Focus_Watchdog_Status_Reg);
}
