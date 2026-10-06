/*
 * metadata.c
 *
 *  Created on: Jan 5, 2026
 *      Author: iboard
 */
#include <stdint.h>
#include "flash.h"

#define METADATA_8K_BLOCK 0

extern uint32_t __metadata_start;
extern uint32_t METADATA_SIZE;
extern uint32_t APPLICATION_ENTRY;

typedef struct
{
    uint32_t u32_Flash_Address;
    uint32_t u32_Size_Bytes;
    uint32_t u32_crc;
}Application_Image_t;

uint32_t u32_Metadata_Size = (uint32_t)&METADATA_SIZE;
uint32_t u32_App_Entry = (uint32_t)&APPLICATION_ENTRY;

uint8_t u8_Metadata_Buffer[128] __attribute__((section(".metadata")));
uint8_t *p_metadata = &u8_Metadata_Buffer[0];

static Application_Image_t *p_App_Image;


void v_Init_Metadata(void)
{
    u8_Flash_Read( 0, 128, u8_Metadata_Buffer );
    p_App_Image = (Application_Image_t *)&u8_Metadata_Buffer[0];
}

uint32_t crc(uint8_t const u8_Msg[], uint32_t u32_Len, uint32_t u32_Rem);

uint8_t b_Check_App(void)
{

    uint32_t u32_Calculated_CRC = 0;
    if( p_App_Image->u32_Flash_Address > 0 &&             // sanity check
       (p_App_Image->u32_Flash_Address & 0xffff) == 0 &&  // address must be on a 64K block boundary
        p_App_Image->u32_Size_Bytes < 65536 )             // for now, must fit in a single 64K block
    {
        v_Flash_Memory_Load( p_App_Image->u32_Flash_Address,
                             0x80004000,
                             p_App_Image->u32_Size_Bytes );


        u32_Calculated_CRC = crc((uint8_t *)0x80004000, p_App_Image->u32_Size_Bytes, 0 );

    }
    return u32_Calculated_CRC == p_App_Image->u32_crc;

}
