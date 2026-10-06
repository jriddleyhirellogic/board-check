/*
 * serial_sm.h
 *
 *  Created on: Oct 6, 2025
 *      Author: iboard
 */

#ifndef SERIAL_SM_H_
#define SERIAL_SM_H_

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

// Byte offsets in serial packets
typedef enum
{
    SYNC1_OFFSET,
    SYNC2_OFFSET,
    SYNC3_OFFSET,
    SYNC4_OFFSET,
    OPCODE_OFFSET,
    ERROR_OFFSET,
    SEQUENCE_OFFSET,
    DATA_LENGTH_OFFSET,
    RESERVED_OFFSET,
    DATA_OFFSET = 15
}Packet_Field_Offset_t;

#define SYNC1_CODE 0x1A
#define SYNC2_CODE 0xCF
#define SYNC3_CODE 0xFC
#define SYNC4_CODE 0x1D

typedef struct
{
    uint8_t u8_Opcode;           // Function
    uint8_t u8_Error_Code;       // Error code to use in replies
    uint8_t u8_Sequence;         // Sequence number
    uint8_t u8_Data_Length;      // Size of data payload
    uint8_t u8_Reserved[8];      // Reserved for future use
}Serial_Msg_Header_t;

#define HEADER_SIZE     12
#define SYNC_LENGTH     4
#define CRC_LENGTH      4
#define RESERVED_SIZE   8
#define MAX_MSG_SIZE    160

// States for parsing received messages
typedef enum
{
    SYNC_WAIT,
    SYNC1,
    SYNC2,
    SYNC3,
    SYNC4,
    FUNCTION,
    ERROR_CODE,
    SEQUENCE,
    DATA_COUNT,
    RESERVED,
    DATA,
    CRC1,
    CRC2,
    CRC3,
    CRC4,
    SM_ERROR
}Serial_Msg_State_t;


void v_Check_Serial_IRQs_SM(uint8_t u8_Received_Char);
void Reset_Serial_SM(void);
void v_Update_Serial_SM(uint8_t u8_Received_Char);


#endif /* SERIAL_SM_H_ */
