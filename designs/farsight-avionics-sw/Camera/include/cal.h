/*
 * cal.h
 *
 *  Created on: Jun 15, 2026
 *      Author: iboard
 */

#ifndef CAL_H_
#define CAL_H_

#include <stdint.h>
#include "lvdt.h"
#include "tlm_adc.h"

#define EXPECTED_CAL_VERSION   3
#define CAL_BLOCK 1
#define MAX_HIGH_GAIN_POINTS 12
#define MAX_LO_GAIN_POINTS   25

typedef struct
{
    uint32_t u32_High_Gain_Points;
    uint32_t u32_Low_Gain_Points;
    Cal_Value_t Cal_G8[MAX_HIGH_GAIN_POINTS];
    Cal_Value_t Cal_G1[MAX_LO_GAIN_POINTS];
}LVDT_Calibration_t;

typedef struct
{
    uint32_t u32_Deadband_Microns;
    uint32_t u32_Deadband_Hysteresis;
    uint32_t u32_Abs_Soft_Travel_Limit_Microns;
    uint32_t u32_Fault_Timeout_Ticks;
    uint32_t u32_Fine_Focus_Speed_10x_Microns_Sec;
    uint32_t u32_Fine_Focus_Threshold_Microns;
    uint32_t u32_Coarse_Focus_Speed_10x_Microns_Sec;
    uint32_t u32_Coarse_Zero_Speed;
    uint32_t u32_Fine_Zero_Speed;
    uint32_t u32_Coarse_Fine_Proj_Threshold;
    uint32_t u32_Motion_Sense;
}Motion_Cal_t;

#define LVDT_CAL_OFFSET     64
#define MOTION_CAL_OFFSET  600
#define TLM_CAL_OFFSET     728
typedef struct
{
    uint32_t u32_Cal_Version;
    LVDT_Calibration_t *lvdt_cal;
    Motion_Cal_t *motion;
    TLM_Cal_t *tlm_cal;
}Calibration_t;


void v_Init_Calibration(void);
LVDT_Calibration_t *p_Get_LVDT_Cal(void);
Motion_Cal_t *p_Get_Motion_Cal(void);
TLM_Cal_t *p_Get_TLM_Cals(void);
uint32_t u32_Get_Cal_Version(void);

#endif /* CAL_H_ */
