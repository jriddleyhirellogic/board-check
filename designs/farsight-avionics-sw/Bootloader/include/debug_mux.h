/*
 * debug_mux.h
 *
 *  Created on: Feb 3, 2026
 *      Author: iboard
 */

#ifndef DEBUG_MUX_H_
#define DEBUG_MUX_H_

typedef enum
{
    DEFAULT_DEBUG = 0,
    USER_DEBUG = 1,
    STEPPER_DEBUG = 2,
    QSPI_DEBUG = 4
}Debug_Mux_Setting_t;


void v_Init_Debug_Mux(void);
void v_Set_Debug_Mux(Debug_Mux_Setting_t eSetting );
void v_Set_Heartbeat_LED( uint8_t u8_On );

#endif /* DEBUG_MUX_H_ */
