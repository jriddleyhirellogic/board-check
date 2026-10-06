/*
 * lvdt.h
 *
 *  Created on: Sep 28, 2025
 *      Author: iboard
 */

#ifndef HAL_LVDT_H_
#define HAL_LVDT_H_

#include <stdint.h>
#include "core_gpio.h"
#include "mem_map.h"


typedef struct
{
    gpio_instance_t Primary_I;
    gpio_instance_t Primary_Q;
    gpio_instance_t Secondary_I;
    gpio_instance_t Secondary_Q;
    gpio_instance_t Gain;
   // May be addtional params later
}LVDT_Instance_t;

typedef struct
{
    int32_t i32_I_Primary;
    int32_t i32_Q_Primary;
    int32_t i32_I_Secondary;
    int32_t i32_Q_Secondary;
}LVDT_Sample_t;

typedef struct
{
    float f_Displacement;
    int32_t i32_Projection;
}Cal_Value_t;


typedef enum
{
    LVDT_GAIN_1 = 0,
    LVDT_GAIN_8
}LVDT_Gain_Sel_t;

#define LVDT_SCALING_FACTOR 1000000

#define POS_SGN_CONVENTION -1


void v_Init_LVDT( void );
void V_Get_LVDT_Snapshot( LVDT_Sample_t *p_LVDT_Sample );
void v_Set_LVDT_Gain(LVDT_Gain_Sel_t eGain);
int32_t i32_Get_Projection( LVDT_Sample_t *p_LVDT_Sample );
float f_Get_Displacement( int32_t i32_Projection );
LVDT_Gain_Sel_t e_Get_LVDT_Gain( void );
void v_Set_Displacement_Offset( int32_t i32_Offset );
int32_t i32_Get_Position(void);


#endif /* HAL_LVDT_H_ */
