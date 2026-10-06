/*
 * calibration.c
 *
 *  Created on: Jun 4, 2026
 *      Author: iboard
 */

#include <stdint.h>
#include "flash.h"

#define CALIBRATION_8K_BLOCK 1

extern uint32_t __calibration_start;
extern uint32_t  CALIBRATION_SIZE;

uint32_t u32_Cal_Table_Size = (uint32_t)&CALIBRATION_SIZE;
uint8_t u8_Cal_Table[1024] __attribute__((section(".calibration")));

void v_Init_Calibration(void)
{
    u8_Flash_Read( 0, u32_Cal_Table_Size, (void*)u8_Cal_Table );
}
