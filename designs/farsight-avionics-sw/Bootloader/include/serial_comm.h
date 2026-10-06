/*
 * serial_comm.h
 *
 *  Created on: Oct 3, 2025
 *      Author: iboard
 */

#ifndef SERIAL_COMM_H_
#define SERIAL_COMM_H_

#include "events.h"
#include "hal/timer.h"
#include "hal_uart16550.h"

#define SERIAL_BUF_SIZE 160

void v_Reset_Serial_Comm_Buffers(void);
void v_Send_Serial_Comm( uint8_t *p_Buffer, uint8_t u8_Length );
void v_Enable_Serial_Comm(void);
void v_Set_Serial_Timer_Instance( Timer_Instance_t *p_Instance );
void Reload_Comm_Timer( uint16_t u16_Timer_Reload );
void v_Set_Serial_Comm_Instance( UART_16550_Instance_t *p_Instance  );

void v_Post_Serial_Event( Event_t *event );
void v_Post_Serial_Event_ISR( Event_t *event );


#endif /* SERIAL_COMM_H_ */
