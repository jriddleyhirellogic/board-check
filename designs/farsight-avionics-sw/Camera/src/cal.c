/*
 * cal.c
 *
 *  Created on: Jun 15, 2026
 *      Author: iboard
 */
#include <assert.h>
#include <string.h>
#include "cal.h"
#include "flash.h"
#include "config.h"

static uint8_t Cal_Data[2048] __attribute__((section(".cal_table")));

static Calibration_t Calibration;

void v_Init_Calibration(void)
{
    uint32_t u32_Cal_Flash_Address = u32_Get_8K_Sector_Base( CAL_BLOCK );
    uint32_t u32_N_Read;
    uint8_t *p_Cal_Init = &Cal_Data[0];

    // Calibration gets loaded from flash into specified area in RAM
    for( u32_N_Read = 0; u32_N_Read < sizeof(Cal_Data); u32_N_Read += 128 )
    {
        u8_Flash_Read( u32_Cal_Flash_Address + u32_N_Read, 128, p_Cal_Init );
        p_Cal_Init += 128;
    }

    memcpy( &Calibration.u32_Cal_Version, Cal_Data, sizeof(uint32_t));
    Calibration.lvdt_cal = (LVDT_Calibration_t *)(Cal_Data + LVDT_CAL_OFFSET);
    Calibration.motion = (Motion_Cal_t *)(Cal_Data + MOTION_CAL_OFFSET);
    Calibration.tlm_cal = (TLM_Cal_t *)(Cal_Data + TLM_CAL_OFFSET);

    assert(Calibration.u32_Cal_Version == EXPECTED_CAL_VERSION);
}

uint32_t u32_Get_Cal_Version(void)
{
    return Calibration.u32_Cal_Version;
}

LVDT_Calibration_t *p_Get_LVDT_Cal(void)
{
    return Calibration.lvdt_cal;
}

Motion_Cal_t *p_Get_Motion_Cal(void)
{
    return Calibration.motion;
}

TLM_Cal_t *p_Get_TLM_Cals(void)
{
    return Calibration.tlm_cal;
}



