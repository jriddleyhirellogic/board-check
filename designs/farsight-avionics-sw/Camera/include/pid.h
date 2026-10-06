/*
 * pid.h
 *
 *  Created on: Oct 29, 2025
 *      Author: iboard
 */

#ifndef PID_H_
#define PID_H_

typedef struct
{
  float   k_p;
  float   k_i;
  int32_t deadband;
  int32_t integral_deadband;
  int32_t max_out;
  int32_t min_out;

  int32_t i32_E_m_1;  // previous value of error
  int32_t i32_Integral_Sum;
}PID_Instance_t;

typedef struct
{
    float   k_p;
    float   k_i;
    int32_t deadband;
    int32_t integral_deadband;
    int32_t max_out;
    int32_t min_out;
}PID_Init_t;

typedef struct
{
    int32_t i32_Position;
    int32_t i32_Setpoint;
    int32_t i32_Error;
    int32_t i32_Integral_Sum;
    int32_t i32_Output;
    int state;
}PID_Log_Info_t;


void v_Init_PID( PID_Instance_t *instance, PID_Init_t *init );
int32_t i32_Update_PID( PID_Instance_t *instance, int32_t i32_Input, int32_t i32_Setpoint, int32_t i32_Feedforward );
void v_Reset_PID( PID_Instance_t *instance );
void v_Get_PID_Log_Info( PID_Log_Info_t *p_Info );

#endif /* PID_H_ */
