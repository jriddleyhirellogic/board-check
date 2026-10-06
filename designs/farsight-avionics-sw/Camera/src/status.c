/*
 * status.c
 *
 *  Created on: Oct 20, 2025
 *      Author: iboard
 */
#include <stdint.h>
#include "status.h"
#include "lvdt.h"
#include "hal_stepper.h"
#include "focus.h"

void v_Get_Status( Status_t *p_Status )
{
    p_Status->i32_Velocity = i32_Get_Stepper_Out();
    p_Status->i32_Position_Microns = i32_Get_Position();
    p_Status->u8_Fault_Status = u8_Get_Focus_Fault_Status();
}
