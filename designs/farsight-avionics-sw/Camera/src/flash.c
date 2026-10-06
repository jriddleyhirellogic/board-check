/*
 * flash.c
 *
 *  Created on: Dec 23, 2025
 *      Author: iboard
 */
#include <stdint.h>
#include <string.h>
#include <assert.h>
#include "mem_map.h"
#include "core_spi.h"
#include "flash.h"

static spi_instance_t flash_spi;

static void v_Wait_For_Not_Busy(void);
static void v_Wait_For_Write_Enable(void);

static void __attribute__((unused)) spi_status(void)   // For debug purposes
{
    uint32_t u32_Reg_Val;

    u32_Reg_Val = *(volatile uint32_t *)(FLASH_NORMAL_SPI_BASE );        // Control
    u32_Reg_Val = *(volatile uint32_t *)(FLASH_NORMAL_SPI_BASE + 0x18 ); // control2
    u32_Reg_Val = *(volatile uint32_t *)(FLASH_NORMAL_SPI_BASE + 0x20 ); // status
    u32_Reg_Val = *(volatile uint32_t *)(FLASH_NORMAL_SPI_BASE + 0x24 ); // SSEL
}

static void v_Set_Write_Enable( void )
{
    uint8_t command_buf[1] __attribute__ ((aligned (4)));

    command_buf[0] = FLASH_WREN;
    SPI_transfer_block( &flash_spi, command_buf, 1, (void *)0, 0 );
}

void v_Init_Flash(void)
{
    uint32_t reg;

    SPI_init( &flash_spi, FLASH_NORMAL_SPI_BASE, 32 );
    SPI_configure_master_mode( &flash_spi );
    SPI_set_slave_select(&flash_spi, SPI_SLAVE_0 );
}

void v_Flash_Reset(void)
{
    uint8_t num_idle_cycles = 0;
    uint8_t u8_Rd_Buf;
    uint32_t u32_Reg_Val;

    const uint8_t rst_en_command_buf[1] __attribute__ ((aligned (4))) = {FLASH_RSTEN};
    const uint8_t rst_command_buf[1] __attribute__ ((aligned (4))) = {FLASH_RST};

    SPI_transfer_block( &flash_spi, rst_en_command_buf, 1, &u8_Rd_Buf, 0 );
    SPI_transfer_block( &flash_spi, rst_command_buf, 1, &u8_Rd_Buf, 0 );
}

void v_Flash_Get_Discovery_Params(void *params)
{
  // @todo - not sure about this, need to research
}
uint8_t u8_Flash_Read( uint32_t u32_Address, uint32_t u32_Count, void *buffer )
{
    uint8_t command_buf[10] __attribute__ ((aligned (4))) = {0};

    command_buf[1] = (u32_Address >> 16u) & 0xFFu;
    command_buf[2] = (u32_Address >> 8u) & 0xFFu;
    command_buf[3] = u32_Address & 0xFFu;
    command_buf[0] = FLASH_READ;

    SPI_transfer_block( &flash_spi, command_buf, 4, buffer, u32_Count );

    return 0;
}

uint32_t u32_Read_JEDEC_ID( void )
{
    uint8_t command_buf[1] __attribute__ ((aligned (4))) = { FLASH_JREAD };
    uint8_t u8_Buf[3];
    SPI_transfer_block( &flash_spi, command_buf, 1, u8_Buf, 3 );
    return (uint32_t)u8_Buf[2] << 16 | (uint32_t)u8_Buf[1] << 8 | (uint32_t)u8_Buf[0];
}


uint8_t u32_Read_Config_Reg( void )
{
    uint8_t command_buf[1] __attribute__ ((aligned (4))) = { FLASH_RDCR };
    uint8_t u8_Buf[1];
    SPI_transfer_block( &flash_spi, command_buf, 1, u8_Buf, 1 );
    return u8_Buf[0];
}

uint8_t u8_Read_Block_Prot_Reg( void )
{
    uint8_t command_buf[1] __attribute__ ((aligned (4))) = { FLASH_RBPR };
    uint8_t u8_Buf[1];
    SPI_transfer_block( &flash_spi, command_buf, 1, u8_Buf, 1 );
    return u8_Buf[0];
}

void v_Global_Flash_Unlock( void )
{
    uint8_t command_buf[1] __attribute__ ((aligned (4))) = { FLASH_ULBPR };

    v_Set_Write_Enable();
    v_Wait_For_Write_Enable();

    SPI_transfer_block( &flash_spi, command_buf, 1, (void*)0, 0 );
}

void  v_Flash_Sector_Erase( uint32_t u32_Address )
{
    uint8_t command_buf[10] __attribute__ ((aligned (4))) = {0};

    command_buf[0] = FLASH_SE;
    command_buf[1] = (u32_Address >> 16) & 0xFFu;
    command_buf[2] = (u32_Address >> 8u) & 0xFFu;
    command_buf[3] = u32_Address & 0xFFu;

    v_Set_Write_Enable();

    SPI_transfer_block( &flash_spi, command_buf, 4, (void *)0, 0 );

    v_Wait_For_Not_Busy();
}

void v_Flash_Block_Erase( uint32_t u32_Address )
{
    uint8_t command_buf[10] __attribute__ ((aligned (4))) = {0};

    assert(u32_Address != 0);       // To avoid erasing metadata section
    assert(u32_Address != 0x2000);  // Avoid erasing calibrations

    command_buf[0] = FLASH_BE;
    command_buf[1] = (u32_Address >> 16) & 0xFFu;
    command_buf[2] = (u32_Address >> 8u) & 0xFFu;
    command_buf[3] = u32_Address & 0xFFu;

    v_Set_Write_Enable();

    SPI_transfer_block( &flash_spi, command_buf, 4, (void *)0, 0 );

    v_Wait_For_Not_Busy();

}

uint8_t u8_Flash_Page_Program( uint32_t u32_Page_Address, void *buffer, uint16_t u16_Count ) // Use 32 bit address, assumes LS 8 bits of address are 0
{
    uint8_t command_buf[256] __attribute__ ((aligned (4))) = {0}; // @todo check necessary buffer size

     uint8_t flag_status_reg;
     //@todo may want to move command buffer off the stack

     assert( u32_Page_Address != 0); // To avoid erasing metadata section

    /*execute Write enable command again for writing the data*/
    command_buf[0] = FLASH_WREN;
    SPI_transfer_block( &flash_spi, command_buf, 1, buffer, 0 );

    v_Wait_For_Write_Enable();
    v_Wait_For_Not_Busy();

    /*This command works for all modes. No Dummy cycles*/
    /*now program the sector. This will set the desired bits to 0.*/

    command_buf[0] = FLASH_PP;
    command_buf[1] = (u32_Page_Address >> 16) & 0xFFu;
    command_buf[2] = (u32_Page_Address >> 8) & 0xFFu;
    command_buf[3] = u32_Page_Address & 0xFFu;

    // Copy transmit data into same buffer as command
    memcpy( command_buf + 4, buffer, u16_Count);

    SPI_transfer_block( &flash_spi, command_buf, u16_Count+4, (void *)0, 0 );

    v_Wait_For_Not_Busy();

    return flag_status_reg;
}


void v_Flash_Read_Status( uint8_t *u8_Status )
{
    const uint8_t command_buf[1] __attribute__ ((aligned (4))) = { FLASH_RDSR };
    SPI_transfer_block( &flash_spi, command_buf, 1, u8_Status, 1 );
}

static void v_Wait_For_Write_Enable(void)
{
    uint8_t status_reg = 0;
    do{
        v_Flash_Read_Status( &status_reg);
    }while ( (STATUS_WEL & status_reg) == 0 );
}

/*Make sure that the erase operation is complete. i.e. wait for  write enable bit to go 0*/
static void v_Wait_For_Not_Busy(void)
{
    uint8_t status_reg = 0;
    do{
        v_Flash_Read_Status( &status_reg );
    }while ( STATUS_BUSY & status_reg );
}

uint32_t u32_Get_64K_Block_Base( uint8_t u8_Sector )
{
    assert(u8_Sector < N_64K_SECTORS );
    return BASE_64K_ADDRESS + (uint32_t)u8_Sector * SIZE_64K_SECTOR;
}

uint32_t u32_Get_32K_Sector_Base( uint8_t u8_Sector )
{
    assert(u8_Sector < N_32K_SECTORS );
    return u8_Sector == 0 ? 0x8000 : 0x7F0000;
}


uint32_t u32_Get_8K_Sector_Base( uint8_t u8_Sector )
{
    assert(u8_Sector < N_8K_SECTORS );
    uint32_t u32_Sector_Base = u8_Sector < 4 ? 0 : 0x7f8000;
    return u32_Sector_Base + (uint32_t)u8_Sector << 13;
}


