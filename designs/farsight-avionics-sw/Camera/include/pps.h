/*
 * pps.h
 *
 *  Created on: Jun 29, 2026
 *      Author: iboard
 */

#ifndef PPS_H_
#define PPS_H_

#include <stdint.h>
#include "mem_map.h"

typedef enum
{
    TRIGGER_TIME_JAM,
    LOAD_SECONDS,
    PPS_RX_DELAY,
    EN_LOCAL_PPS_SOURCE,
    FREQUENCY_ERROR,
    PHASE_ERROR,
    SECONDS,
    NANOSECONDS,
    RESET_IRQ
}PPS_Reg_Offset_t;

#define PPS_BASE ((volatile uint32_t *)(PPS_BASE_ADDR))


typedef struct
{
    uint32_t u32_Time_Sec;
    uint32_t u32_Time_msec;
}Sys_Time_t;

void v_PPS_Start(void);
void v_PPS_Load_Seconds(Sys_Time_t *p_Time);
void v_PPS_Set_Rx_Delay(uint32_t);
void v_PPS_Enable_Local_PPS_Source(uint8_t b_Enable);
uint32_t u32_Get_PPS_Freq_Error(void);
uint32_t u32_Get_PPS_Phase_Error(void);
void v_Get_PPS_Time(Sys_Time_t *);
void v_Enable_PPS_IRQ( uint8_t b_Enable );
uint8_t b_PPS_Is_Locked(void);

#endif /* PPS_H_ */
