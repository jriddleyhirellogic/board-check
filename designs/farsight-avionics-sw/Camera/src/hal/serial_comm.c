/*
 * serial_comm.c
 *
 *  Created on: Oct 3, 2025
 *      Author: iboard
 */


#include <stdint.h>
#include <string.h>

#include "FreeRTOSConfig.h"
#include "FreeRTOS.h"
#include "task.h"
#include "event_groups.h"
#include "queue.h"
#include "hal_uart16550.h"
#include "timer.h"
#include "serial_comm.h"
#include "mem_map.h"
#include "config.h"
#include "serial_sm.h"
#include "events.h"
#include "command.h"

extern EventGroupHandle_t initialized;
static UART_16550_Instance_t *p_serial_comm_instance;
static Timer_Instance_t *p_Timer_Instance;


uint8_t static u8_Response[MAX_MSG_SIZE] __attribute__ ((aligned (4)));

static uint8_t u8_Msgs_Received;

static QueueHandle_t Serial_Comm_Queue;
void Reset_Serial_SM(void);

/**
 * @fn void v_Serial_Comm_Task(void*)
 * @brief Thread to manage serial communcations
 * Serial messages are parse and crc-checked in the serial interrupt. When a well formed
 * message arrives, an event is sent to the queue in the this thread. Where (optionally) a
 * command is executed and a response sent.
 *
 * @param pvParameters Optional param that can be passed into task when it is launched.
 */
void v_Serial_Comm_Task(void *pvParameters)
{
    Serial_Comm_Queue = xQueueCreate( SERIAL_COMM_QUEUE_LENGTH,
                                  sizeof(Event_t) );

    Reset_Serial_SM();

    xEventGroupSetBits( initialized,  SERIAL_COMM_INITIALIZED );
    xEventGroupWaitBits( initialized, ALL_INITIALIZED, pdFALSE, pdTRUE, portMAX_DELAY );

    v_Enable_Serial_Comm();

    while(1)
    {
        BaseType_t b_Data_Present;
        Event_t Rcvd_Event;
         b_Data_Present = xQueueReceive(
                                        Serial_Comm_Queue,
                                        &Rcvd_Event,
                                        portMAX_DELAY );

         if( b_Data_Present ) // Event received
         {
             uint8_t u8_Response_Length = 0;
             uint8_t u8_Retval;

             // Parse the received packet
             u8_Retval = Execute_Command( &Rcvd_Event.serial_msg.header,
                                          Rcvd_Event.serial_msg.Data,
                                          u8_Response,
                                          &u8_Response_Length );

             if( !u8_Retval )
                 v_Send_Serial_Comm( u8_Response, u8_Response_Length );

             ++u8_Msgs_Received;
         }
         else // timeout or something wrong
         {

         }
#ifdef  MEM_CHECK
        UBaseType_t uxHighWaterMark = uxTaskGetStackHighWaterMark(NULL); // Stack high water mark - view in debugger
#endif

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
    __asm volatile ( "csrs mie, %0" ::"r" ( UART_IRQ | COMM_TIMER_IRQ ) );

    v_Enable_UART_IRQ( p_serial_comm_instance, UART_ERBFI );
    v_Enable_Timer_IRQ( p_Timer_Instance, 1 );
}

void v_Disable_Serial_Comm(void)
{
    v_Disable_UART_IRQ( p_serial_comm_instance, UART_ERBFI );
}


static uint8_t u8_Rx_Count;
static uint8_t u8_Tx_Buffer[SERIAL_BUF_SIZE];
static uint8_t *p_Tx_Ptr;
static uint8_t u8_Tx_Count_Remaining;

/**
 * @fn void v_UART16550_Handler(void)
 * @brief Interrupt handler for the 16550 type uart.
 * This handles both receive and transmit interrupts. A timer with a timeout of
 * 3 characters is reloaded every time a character is received. Each receive character
 * updates a state machine which parses the packet, extracting the header and data and
 * updating a crc check. When the time expires, the serial_comm thread is notified.
 * Note that ill formed messages and garbage data do not result in the notification.
 */
void v_UART16550_Handler(void)
{
    uint8_t u8_Line_Status = u8_Get_Line_Status( p_serial_comm_instance );
    uint8_t b_Rx_Data_Present = (u8_Line_Status & LINE_STATUS_DR) != 0;
    uint8_t b_Tx_Holding_Reg_Empty = (u8_Line_Status & LINE_STATUS_THRE) != 0;
    uint8_t u8_IRQ_Cause = u8_Get_Interrupt_Cause( p_serial_comm_instance );


    if( (u8_IRQ_Cause & IRQ_ID_RX_DATA_AVAIL ) != 0 && b_Rx_Data_Present )
    {
        uint8_t u8_Data = u8_Get_UART_Rx_Data( p_serial_comm_instance );
        v_Update_Serial_SM(u8_Data);

        // The reload value corresponds to 3 character times at 115200 bits/sec
        Reload_Comm_Timer( 13020 );
        ++u8_Rx_Count;
    }

    // Transmit
    if( (u8_IRQ_Cause & IRQ_TX_HOLD_REG_EMPTY ) != 0 )
    {
        if( u8_Tx_Count_Remaining != 0 )
        {
            v_Write_UART_Tx_Data( p_serial_comm_instance, *p_Tx_Ptr++ );
            --u8_Tx_Count_Remaining;
        }
        else
        {
            v_Disable_UART_IRQ( p_serial_comm_instance, UART_ETBEI );
        }
    }

}

static uint32_t u32_Comm_IRQ_Counter;
void v_Framing_Timeout(void);

/**
 * @fn void v_Comm_Timer_Handler(void)
 * @brief Timer to determine framing of serial packets.
 * When this timer expires a notification is generated.
 */
void v_Comm_Timer_Handler(void)
{
    ++u32_Comm_IRQ_Counter;

    v_Framing_Timeout();

    // Clear interrupt
    *(volatile uint32_t *)(p_Timer_Instance->u32_Base_Address + TIMER_IRQ_CLR_OFFSET ) = 1;
}

/**
 * @fn void Reload_Comm_Timer(uint16_t)
 * @brief The timer is reloaded every time a character is received.
 *
 * @param u16_Timer_Reload
 */
void Reload_Comm_Timer( uint16_t u16_Timer_Reload )
{
    *(volatile uint32_t *)(p_Timer_Instance->u32_Base_Address + TIMER_LOAD_OFFSET ) = u16_Timer_Reload;
}

/**
 * @fn void v_Send_Serial_Comm(uint8_t*, uint8_t)
 * @brief Initiates transmission of a buffer
 * @param p_Buffer Character data to be transmitted
 * @param u8_Length Number of characters to be sent
 */
void v_Send_Serial_Comm( uint8_t *p_Buffer, uint8_t u8_Length )
{
    //assert( u8_Length <= UART_BUF_SIZE );

    // Copy to buffer
    memcpy( u8_Tx_Buffer, p_Buffer, u8_Length );

    // Initialize pointer and msg length
    p_Tx_Ptr = &u8_Tx_Buffer[0];
    u8_Tx_Count_Remaining = u8_Length;  // This kicks off the sending
    v_Enable_UART_IRQ( p_serial_comm_instance, UART_ETBEI );

}

/**
 * @fn void v_Post_Serial_Event(Event_t*)
 * @brief Post an event to the message queue of the serial comm thread
 * This is used from other threads.
 * @param event
 */
void v_Post_Serial_Event( Event_t *event )
{
    BaseType_t Ret_Val;
    Ret_Val = xQueueSend( Serial_Comm_Queue, event, 5 );
}

/**
 * @fn void v_Post_Serial_Event_ISR(Event_t*)
 * @brief Post an event to the serial comm thread's message queue from interrupt
 *
 * @param event
 */
void v_Post_Serial_Event_ISR( Event_t *event )
{
    BaseType_t Ret_Val;
    Ret_Val = xQueueSendFromISR( Serial_Comm_Queue, event, NULL );
}
