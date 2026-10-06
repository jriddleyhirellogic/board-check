/*
 * serial_sm.c
 *
 *  Created on: Oct 6, 2025
 *      Author: iboard
 */




#include <stdint.h>
#include <string.h>

#include "hal_uart16550.h"
#include "serial_comm.h"
#include "mem_map.h"
#include "serial_sm.h"
#include "command.h"
#include "crc.h"

/* Serial Message States
typedef enum
{
    SYNC_WAIT,
    SYNC,
    FUNCTION,
    DATA_COUNT,
    DATA
}Serial_Msg_State_t;
*/


#define RX_BUFSIZE 160
#define TX_BUFSIZE 160

static Serial_Msg_State_t Current_State, Next_State;
static uint8_t u8_Bytes_Received;


static uint8_t u8_Rx_Buf[RX_BUFSIZE];
static uint8_t Tx_Buf[TX_BUFSIZE];

static void Received_Message_Notification(void);
static uint32_t u32_Calculated_CRC, u32_Received_CRC;
/*
 * | Packet Structure (latest) from ICD |
 * | SYNC FRAME (0x1ACFFC1D) - 4 bytes  |
 * | OPCODE  (Function)      - 1 byte   |
 * | Error (in reply)        - 1 byte   |
 * | Seq Number              - 1 byte   |
 * | Data Length (bytes)       1 byte   |
 * | Reserved                - 8 bytes  |
 * | Data Payload            - variable |
 * | CRC                     - 4 bytes  |
 *
 * Notes: CRC is calculated over all bytes except sync frame
 *        Transmission order eg, header: 0x1A, 0xCF, 0xFC, 0x1D
 *
 */

static Serial_Msg_Header_t Header;
static uint8_t u8_Cnt;

void v_Set_Busy(void);
void v_Clear_Busy(void);


void v_Update_Serial_SM(uint8_t u8_Received_Char)
{
    Event_t event;
    //u8_Rx_Buf[u8_Bytes_Received++] = u8_Received_Char;

    switch( Current_State )
    {
    case SYNC_WAIT:                                 // Idle state waiting for msg start
        u8_Bytes_Received = 0;
        if (u8_Received_Char == SYNC1_CODE )
        {
            Next_State = SYNC1;
            u8_Rx_Buf[u8_Bytes_Received++] = SYNC1_CODE;
            v_Set_Busy();
        }
        else
            Next_State = SM_ERROR;
        break;

    case SYNC1:                                     // Received SYNC1
        if (u8_Received_Char == SYNC2_CODE )
        {
            Next_State = SYNC2;
            u8_Rx_Buf[u8_Bytes_Received++] = SYNC2_CODE;
        }
        else
            Next_State = SM_ERROR;
        break;

    case SYNC2:                                     // Received SYNC2
        if (u8_Received_Char == SYNC3_CODE )
        {
            Next_State = SYNC3;
            u8_Rx_Buf[u8_Bytes_Received++] = u8_Received_Char;
        }
        else
            Next_State = SM_ERROR;
        break;

    case SYNC3:                                     // Received SYNC3
        if (u8_Received_Char == SYNC4_CODE )
        {
            Next_State = SYNC4;
            u8_Rx_Buf[u8_Bytes_Received++] = u8_Received_Char;
            memset(&Header, 0, sizeof(Serial_Msg_Header_t));
        }
        else
            Next_State = SM_ERROR;
        break;

    case SYNC4:                                      // Received last SYNC_CHAR
        Header.u8_Opcode = u8_Received_Char;
        u8_Rx_Buf[u8_Bytes_Received++] = Header.u8_Opcode;
        u32_Calculated_CRC = crc( &u8_Received_Char, 1, 0 );
        Next_State = FUNCTION;
        break;

    case FUNCTION:                                   // Received function code
        Header.u8_Error_Code = u8_Received_Char;
        u32_Calculated_CRC = crc( &u8_Received_Char, 1, u32_Calculated_CRC );
        u8_Rx_Buf[u8_Bytes_Received++] = u8_Received_Char;
        Next_State = ERROR_CODE;
        break;

    case ERROR_CODE:
        Header.u8_Sequence = u8_Received_Char;
        u32_Calculated_CRC = crc( &u8_Received_Char, 1, u32_Calculated_CRC );
        u8_Rx_Buf[u8_Bytes_Received++] = u8_Received_Char;
        Next_State = SEQUENCE;
        break;

    case SEQUENCE:
        Header.u8_Data_Length = u8_Received_Char;            // Size of data payload
        u32_Calculated_CRC = crc( &u8_Received_Char, 1, u32_Calculated_CRC );
        u8_Rx_Buf[u8_Bytes_Received++] = u8_Received_Char;
        u8_Cnt = 0;
        Next_State = RESERVED;
        break;

    case RESERVED:
        Header.u8_Reserved[u8_Cnt++] = u8_Received_Char;
        u32_Calculated_CRC = crc( &u8_Received_Char, 1, u32_Calculated_CRC );
        u8_Rx_Buf[u8_Bytes_Received++] = u8_Received_Char;
        if( u8_Cnt == 8 )
        {
            if( Header.u8_Data_Length == 0 ) // Command with no data payload
            {
               Next_State =  CRC1;
            }
            else
            {
                Next_State = DATA;
            }
        }
        break;

    case DATA:
        u8_Rx_Buf[u8_Bytes_Received++] = u8_Received_Char;
        u32_Calculated_CRC = crc( &u8_Received_Char, 1, u32_Calculated_CRC );
        if( u8_Bytes_Received == ( SYNC_LENGTH + HEADER_SIZE + Header.u8_Data_Length))
        {
            Next_State = CRC1;
        }
        break;

    case CRC1:
        u8_Rx_Buf[u8_Bytes_Received++] = u8_Received_Char;
        u32_Received_CRC = u8_Received_Char;
        Next_State = CRC2;
        break;

    case CRC2:
        u8_Rx_Buf[u8_Bytes_Received++] = u8_Received_Char;
        u32_Received_CRC = (u32_Received_CRC << 8) | u8_Received_Char;
        Next_State = CRC3;
        break;

    case CRC3:
        u8_Rx_Buf[u8_Bytes_Received++] = u8_Received_Char;
        u32_Received_CRC = (u32_Received_CRC << 8) | u8_Received_Char;
        Next_State = CRC4;
        break;

    case CRC4:
        u8_Rx_Buf[u8_Bytes_Received++] = u8_Received_Char;
        u32_Received_CRC = (u32_Received_CRC << 8) | u8_Received_Char;
        break;

    case SM_ERROR:   // absorbing state until reset by timeout
        break;
    default:
        break;
    }

    Current_State = Next_State;
}

// The timer is reloaded with every received character. The expiration is set to 3 character times. When the timer expires, the crc
// is checked and if good, the serial comm task is notified. The state machines and crcs are reset as well.
void v_Framing_Timeout(void)
{
    // Need to change this so that if crc isn't good, it still sends response
    // but with error code set so update can resend.
    if( u32_Received_CRC == u32_Calculated_CRC &&
        Current_State == CRC4  )
    {
        Received_Message_Notification();
    }

    Reset_Serial_SM();
    Current_State = Next_State = SYNC_WAIT;
}


static void Received_Message_Notification(void)
{
uint8_t u8_Retval;
uint8_t u8_Response_Length = 0;
uint8_t *p_Response = &Tx_Buf[0];

    u8_Retval = Execute_Command( &Header,
                                 &u8_Rx_Buf[SYNC_LENGTH + HEADER_SIZE],
                                 p_Response,
                                 &u8_Response_Length );
    if( !u8_Retval )
        v_Send_Serial_Comm( p_Response, u8_Response_Length );
}

void Reset_Serial_SM(void)
{
    Current_State = Next_State = SYNC_WAIT;
    u32_Calculated_CRC = u32_Received_CRC = 0;
    memset(&Header, 0, sizeof(Serial_Msg_Header_t));
}

uint8_t b_In_Error_State(void)
{
    return Current_State == SM_ERROR;
}
