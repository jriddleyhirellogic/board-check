/*
 * flash.h
 *
 *  Created on: Dec 23, 2025
 *      Author: iboard
 */

#ifndef FLASH_H_
#define FLASH_H_

// For SST26LF064RT SPI flash chip

// Opcodes

// Configuration
#define FLASH_NOP      0x00
#define FLASH_RSTEN    0x66
#define FLASH_RST      0x99
#define FLASH_EQIO     0x38
#define FLASH_RSTQIO   0xFF
#define FLASH_RDSR     0x05
#define FLASH_WRSR     0x01
#define FLASH_RDCR     0x35

// Read
#define FLASH_READ     0x03
#define FLASH_SQOR     0x6B
#define FLASH_SQIOR    0xEB
#define FLASH_SDOR     0x3B
#define FLASH_SDIOR    0xBB
#define FLASH_SB       0xC0
#define FLASH_RBSQI    0x0C
#define FLASH_RBSPI    0xEC
#define FLASH_JREAD    0x9F
#define FLASH_QJID     0xAF

// Write
#define FLASH_WREN     0x06
#define FLASH_WRDI     0x04
#define FLASH_SE       0x20
#define FLASH_BE       0xD8
#define FLASH_CE       0xC7
#define FLASH_PP       0x02
#define FLASH_SQPP     0x32
#define FLASH_WRSU     0xB0
#define FLASH_WRRE     0x30
#define FLASH_RBPR     0x72
#define FLASH_WBPR     0x42
#define FLASH_LBPR     0x8D
#define FLASH_nVWLDR   0xE8
#define FLASH_ULBPR    0x98
#define FLASH_RSID     0x88
#define FLASH_PSID     0xA5
#define FLASH_LSID     0x85

// Status return values
#define STATUS_BUSY    (1 << 0)  // busy
#define STATUS_WEL     (1 << 1)  // write enable latch
#define STATUS_WSE     (1 << 2)  // write suspend erase
#define STATUS_WSP     (1 << 3)  // write suspend erase
#define STATUS_WPLD    (1 << 4)  // write protect lockdown
#define STATUS_SEC     (1 << 5)  // security ID status
#define STATUS_RES     (1 << 6)  // reserved for future use
#define STATUS_BUSY1   (1 << 7)  // appears to be a duplicate of bit 0

// Unique to SST26LF064RT
#define N_64K_SECTORS 126
#define BASE_64K_ADDRESS 0x10000  // Starting address of the first 64K sector
#define SIZE_64K_SECTOR (1 << 16)

#define N_32K_SECTORS 2
#define BASE_32K_ADDRESS 0x8000
#define SIZE_32K_SECTOR (1 << 15)

#define N_8K_SECTORS 4
#define BASE_8K_ADDRESS 0x0000
#define SIZE_8K_SECTOR (1 << 13)

typedef enum
{
    FLASH_BLOCK_64K,
    FLASH_BLOCK_32K,
    FLASH_BLOCK_8K

}Flash_Block_Type_t;

typedef struct
{
    uint32_t u32_Base_Address;
    Flash_Block_Type_t type;
}Flash_Block_Descriptor_t;

void v_Init_Flash(void);
void v_Flash_Reset(void);
void v_Flash_Get_Discovery_Params(void *params);
uint8_t u8_Flash_Read( uint32_t u32_Address, uint32_t u32_Count, void *buffer );
void v_Flash_Sector_Erase( uint32_t u32_Address );
void v_Flash_Block_Erase( uint32_t u32_Address );
uint8_t u8_Flash_Page_Program( uint32_t u32_Page_Address, void *buffer, uint16_t u16_Count );
void v_Flash_Read_Status( uint8_t *u8_Status );
uint32_t u32_Read_JEDEC_ID( void );
uint8_t u32_Read_Config_Reg( void );
uint8_t u8_Read_Block_Prot_Reg( void );
void v_Global_Flash_Unlock( void );
void  v_Flash_Sector_Erase( uint32_t u32_Address );

// Unique to SST26LF064RT flash chip
uint32_t u32_Get_64K_Block_Base( uint8_t u8_Block );
uint32_t u32_Get_32K_Sector_Base( uint8_t u8_Sector );
uint32_t u32_Get_8K_Sector_Base( uint8_t u8_Sector );


#endif /* FLASH_H_ */
