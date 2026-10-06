/*
 * serial_comm.c
 *
 *  Created on: Oct 3, 2025
 *      Author: iboard
 */


#include <stdint.h>
#include <string.h>

#include "hal_uart16550.h"
#include "timer.h"
#include "serial_comm.h"
#include "mem_map.h"

#include "serial_sm.h"
//#include "events.h"
#include "command.h"

static UART_16550_Instance_t *p_serial_comm_instance;
static Timer_Instance_t *p_Timer_Instance;

//static uint8_t u8_Msgs_Received;

//void Reset_Serial_SM(void);
void v_Update_Serial_SM(uint8_t u8_Received_Char);
void v_Comm_Timer_Handler(void);
void v_UART16550_Handler(void );

void v_Set_Busy(void);
void v_Clear_Busy(void);

void v_Check_Serial_IRQs(void)
{
uint8_t u8_Cause = u8_Get_Interrupt_Cause( p_serial_comm_instance );

    if( (u8_Cause & IRQ_ID_RX_DATA_AVAIL) != 0 || (u8_Cause & IRQ_TX_HOLD_REG_EMPTY) != 0 )
    {
        v_UART16550_Handler();
    }

    if( b_Check_Timer_IRQ_Status( p_Timer_Instance) ) // Check for expiration of timer
    {
        v_Comm_Timer_Handler();
    }
}

void v_Set_Serial_Comm_Instance( UART_16550_Instance_t *p_Instance  )
{
    p_serial_comm_instance = p_Instance;
}

void v_Set_Serial_Timer_Instance( Timer_Instance_t *p_Instance )
{
    p_Timer_Instance = p_Instance;
}

void v_Enable_Serial_Comm(void)
{
    v_Enable_Timer( p_Timer_Instance, 1 );

    v_Enable_UART_IRQ( p_serial_comm_instance, UART_ERBFI );
    v_Enable_Timer_IRQ( p_Timer_Instance, 1 );
}


//static uint8_t u8_Rx_Count;
//static uint8_t u8_Tx_Buffer[SERIAL_BUF_SIZE];
static uint8_t *p_Tx_Ptr;
static uint8_t u8_Tx_Count_Remaining;
void v_UART16550_Handler(void )
{
    uint8_t u8_Line_Status = u8_Get_Line_Status( p_serial_comm_instance  );
    uint8_t b_Rx_Data_Present = (u8_Line_Status & LINE_STATUS_DR) != 0;
    uint8_t b_Tx_Holding_Reg_Empty = (u8_Line_Status & LINE_STATUS_THRE) != 0;
    uint8_t u8_IRQ_Cause = u8_Get_Interrupt_Cause( p_serial_comm_instance );

    if( (u8_IRQ_Cause & IRQ_ID_RX_DATA_AVAIL ) != 0 && b_Rx_Data_Present )
    {
        uint8_t u8_Data = u8_Get_UART_Rx_Data( p_serial_comm_instance  );
        v_Update_Serial_SM(u8_Data);

        // The reload value corresponds to 3 character times at 115200 bits/sec
        Reload_Comm_Timer( 6510 );
    }

    // Transmit - have to do it this way because interrupt is auto cleared when read
    if( b_Is_UART_IRQ_Enabled( p_serial_comm_instance, IRQ_TX_HOLD_REG_EMPTY ) && b_Is_Tx_Hold_Reg_Empty( p_serial_comm_instance ))
    {
        if( u8_Tx_Count_Remaining != 0 )
        {
            v_Write_UART_Tx_Data( p_serial_comm_instance, *p_Tx_Ptr++ );
            --u8_Tx_Count_Remaining;
        }
        else
        {
            v_Disable_UART_IRQ( p_serial_comm_instance, UART_ETBEI );
            v_Clear_Busy();
        }
    }

}



static uint32_t u32_Comm_IRQ_Counter;
void v_Framing_Timeout(void);

void v_Comm_Timer_Handler(void)
{
    ++u32_Comm_IRQ_Counter;

    v_Framing_Timeout();

    // Clear interrupt
    *(volatile uint32_t *)(p_Timer_Instance->u32_Base_Address + TIMER_IRQ_CLR_OFFSET ) = 1;
}

void Reload_Comm_Timer( uint16_t u16_Timer_Reload )
{
    *(volatile uint32_t *)(p_Timer_Instance->u32_Base_Address + TIMER_LOAD_OFFSET ) = u16_Timer_Reload;
}

void v_Send_Serial_Comm( uint8_t *p_Buffer, uint8_t u8_Length )
{
    //assert( u8_Length <= UART_BUF_SIZE );

    // Copy to buffer
    //memcpy( u8_Tx_Buffer, p_Buffer, u8_Length );

    // Initialize pointer and msg length
//    p_Tx_Ptr = &u8_Tx_Buffer[0];
    p_Tx_Ptr = p_Buffer;
    u8_Tx_Count_Remaining = u8_Length;  // This kicks off the sending
    v_Enable_UART_IRQ( p_serial_comm_instance, UART_ETBEI );

}




