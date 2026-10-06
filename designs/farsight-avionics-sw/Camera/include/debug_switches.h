/*
 * debug_switches.h
 *
 *  Created on: Oct 14, 2025
 *      Author: iboard
 */

#ifndef DEBUG_SWITCHES_H_
#define DEBUG_SWITCHES_H_

#define SW2 (1 << 30)
#define SW3 (1 << 31)

#define ALL_SWITCHES (SW2 | SW3 )

#define DEBOUNCE_THRESHOLD_COUNT 25 // debounce time in milliseconds

void v_Init_Debug_Switches(void);
uint32_t u32_Get_Switch_State(void);
uint8_t u8_Update_Switch_Debounce( uint8_t *p_Counter, uint32_t u32_Switch_Mask );

#endif /* DEBUG_SWITCHES_H_ */
