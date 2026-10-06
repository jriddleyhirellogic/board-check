/*
 * command.c
 *
 *  Created on: Oct 8, 2025
 *      Author: iboard
 */
#include <stdint.h>
#include <string.h>
#include <assert.h>
#include "hal_uart16550.h"
#include "serial_comm.h"
#include "mem_map.h"

#include "serial_sm.h"
#include "command.h"
#include "errors.h"
#include "crc.h"
#include "flash.h"
#include "version.h"

static void v_Init_Response( Serial_Msg_Header_t *p_Header, uint8_t *p_Response_Buffer );
static void v_Add_Response_Data( void *p_Data, uint8_t u8_Data_Size, uint8_t *p_Response_Buffer );
static void v_Finalize_Msg( uint8_t *p_Response_Buffer, uint8_t *p_u8_Response_Length );
static void v_Set_Error_Code(uint8_t u8_Error, uint8_t *p_Response_Buffer );
static void v_Set_Sequence(uint8_t u8_Sequence, uint8_t *p_Response_Buffer );
void v_Set_Pending( uint8_t u8_Operation, uint8_t *p_u32_Src, uint8_t u8_N_Args );
void start_application();
void v_Set_Boot_Flag(uint8_t b_Val);

static uint8_t u8_Response_Length;

// Set version info in version.h
static const uint32_t u32_BL_Version = ((BL_MAJOR_VERSION & 0xFF) << 24)  |\
                                ((BL_MINOR_VERSION & 0xFF) << 16)  |\
                                ((BL_BUILD_VERSION & 0xFF) << 8)   |\
                                (BL_FIX_VERSION & 0xFF);

uint8_t Execute_Command( Serial_Msg_Header_t *p_Header,
                         uint8_t *p_u8_Data,
                         uint8_t *p_Response_Buffer,
                         uint8_t *p_u8_Response_Length )
{
    uint32_t u32_Arg;
    uint32_t u32_Test_Val;
    uint8_t u8_Ret_Val = OK;
    uint32_t u32_Address;
    uint32_t u32_Flash_Address, u32_Mem_Address, u32_N_Bytes;

    v_Init_Response( p_Header, p_Response_Buffer );

    switch( p_Header->u8_Opcode )
    {
    case GET_VERSION_SYS_CMD:
        v_Add_Response_Data( (void*)&u32_BL_Version, sizeof(uint32_t), p_Response_Buffer );
        break;

    case ECHO_FUNCTION:
        v_Add_Response_Data( p_u8_Data, p_Header->u8_Data_Length, p_Response_Buffer );
        break;

    case FLASH_ERASE_SECTOR:
        memcpy( &u32_Address, p_u8_Data, sizeof(uint32_t ));
        if( u32_Address & 0xFFF )   // Sector must be multiple of 4K
        {
            v_Set_Error_Code(ERR_REG_INVALID_ADDR, p_Response_Buffer );
            break;
        }
        v_Set_Pending( PENDING_FLASH_SECTOR_ERASE, p_u8_Data, 1);
        break;

    case FLASH_ERASE_BLOCK:
        memcpy( &u32_Address, p_u8_Data, sizeof(uint32_t ));
        if( u32_Address & 0x1FFF ) //smallest block is 8K, all other addresses are multiple
        {
            v_Set_Error_Code(ERR_REG_INVALID_ADDR, p_Response_Buffer );
            break;
        }
        v_Set_Pending( PENDING_FLASH_BLOCK_ERASE, p_u8_Data, 1 );
        break;

    case WRITE_FLASH_PAGE:
        memcpy( &u32_Address, p_u8_Data, sizeof(uint32_t ));
        if( u32_Address & 0x7F ) // Making sure address is a multiple of 128
        {
            v_Set_Error_Code(ERR_REG_INVALID_ADDR, p_Response_Buffer );
            break;
        }

        u8_Flash_Page_Program( u32_Address, p_u8_Data + 4, 128 );
        break;

    case READ_FLASH:
        memcpy( &u32_Address, p_u8_Data, sizeof(uint32_t ));
        u8_Flash_Read(u32_Address, 128, p_Response_Buffer + u8_Response_Length );
        u8_Response_Length += 128;
        break;

    case RESET_FLASH :    // Resets the counters and status regs in the flash
        v_Flash_Reset();
        break;

    case GET_INFO_SYS_CMD:
        {
            uint32_t u32_Response = 0xb007; // Indicates in bootloader
            v_Add_Response_Data( (void*)&u32_Response, sizeof(uint32_t), p_Response_Buffer );
        }
        break;

    case LOAD_FLASH_TO_MEM:
        v_Set_Pending( FLASH_MEMORY_LOAD, p_u8_Data, 3);
        break;

    case START_APP:
        start_application();
        break;

    case UPDATE:
        v_Set_Boot_Flag(0);
        break;

    default: // well formed but not recognized
        //v_Set_Error_Code( ERR_CMD_INVALID_OPCODE, p_Response_Buffer );
        break;
    }

    v_Finalize_Msg( p_Response_Buffer, p_u8_Response_Length );
    return u8_Ret_Val;

}



// This establishes defaults for the reply message based on the received message.
static void v_Init_Response( Serial_Msg_Header_t *p_Header, uint8_t *p_Response_Buffer )
{
    u8_Response_Length = 0;
    // Sync field
    p_Response_Buffer[u8_Response_Length++] = SYNC1_CODE;
    p_Response_Buffer[u8_Response_Length++] = SYNC2_CODE;
    p_Response_Buffer[u8_Response_Length++] = SYNC3_CODE;
    p_Response_Buffer[u8_Response_Length++] = SYNC4_CODE;

    // Header
    p_Response_Buffer[u8_Response_Length++] = p_Header->u8_Opcode;
    p_Response_Buffer[u8_Response_Length++] = p_Header->u8_Error_Code;
    p_Response_Buffer[u8_Response_Length++] = p_Header->u8_Sequence;
    p_Response_Buffer[u8_Response_Length++] = 0;              // Data length before anything is added

    memset( p_Response_Buffer + u8_Response_Length, 0, RESERVED_SIZE );  // Rserved field
    u8_Response_Length += RESERVED_SIZE;
}

// These functions are for overriding the defaults set by v_Init_Response()
// based on the received packet. They must be called before v_Finalize_Msg()
static void v_Set_Error_Code(uint8_t u8_Error, uint8_t *p_Response_Buffer )
{
    p_Response_Buffer[ERROR_OFFSET] = u8_Error;
}


__attribute__((unused)) static void v_Set_Sequence(uint8_t u8_Sequence, uint8_t *p_Response_Buffer )
{
    p_Response_Buffer[SEQUENCE_OFFSET] = u8_Sequence;
}


static void v_Add_Response_Data( void *p_Data, uint8_t u8_Data_Size, uint8_t *p_Response_Buffer )
{
    memcpy( p_Response_Buffer + u8_Response_Length, p_Data, u8_Data_Size );
    u8_Response_Length += u8_Data_Size;
}

static void v_Finalize_Msg( uint8_t *p_Response_Buffer, uint8_t *p_u8_Response_Length )
{
    // Set real data size
    p_Response_Buffer[DATA_LENGTH_OFFSET] = u8_Response_Length - (SYNC_LENGTH + HEADER_SIZE);
    // Calculate over all fields except for sync
    uint32_t u32_CRC = crc( p_Response_Buffer + 4, u8_Response_Length - 4, 0 );
    p_Response_Buffer[u8_Response_Length++]= (u32_CRC >> 24) & 0xFF;
    p_Response_Buffer[u8_Response_Length++]= (u32_CRC >> 16) & 0xFF;
    p_Response_Buffer[u8_Response_Length++]= (u32_CRC >> 8) & 0xFF;
    p_Response_Buffer[u8_Response_Length++]= u32_CRC & 0xFF;

    *p_u8_Response_Length = u8_Response_Length;
}





