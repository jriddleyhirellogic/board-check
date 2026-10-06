/*
 ============================================================================
 Name        : main.c
 Author      : ian
 Version     :
 Copyright   : Your copyright notice
 Description : Bootloader to read from flash and intialize RAM
 ============================================================================
 */

#include <stdint.h>
#include <assert.h>
#include <string.h>
#include "mem_map.h"
#include "flash.h"
#include "debug_mux.h"
#include "debug_switches.h"
#include "hw_version.h"
#include "version.h"

#define MAX_ARGS 5
#define BOOTLOADER_TIMEOUT_SEC 10

void v_Hw_Init(void);
void v_Check_IRQs(void);

uint32_t u32_HW_Version;
static volatile uint32_t u32_Counter;

static uint8_t u8_Pending_Operation;
static uint32_t u32_Pending_Arg[MAX_ARGS];
static uint8_t u8_N_Pending_Args;
static uint8_t u8_Busy;
static void v_Check_Pending_Operations(void);

void v_Set_Busy(void);
void v_Clear_Busy(void);
void v_Init_Metadata(void);
void v_Init_Calibration(void);
uint8_t b_Check_App(void);
void start_application();
void v_Delay_Sec(uint8_t u8_Sec );

void v_Init_Boot_Info(void);
static uint32_t u32_Seconds;
static uint8_t u8_Update_Flag;
static uint8_t u8_Boot_Flag;

int main(void)
{
    uint8_t u8_On = 0;
    u32_Counter = 0;
    uint32_t u32_Switch_State;
    u8_Boot_Flag = 1;

    v_Delay_Sec(2);

    // Make sure the hw version is at least 2
    do
    {
        u32_HW_Version = u32_Get_HW_Version();
    }while(u32_HW_Version < EXPECTED_HW_VERSION);

    v_Init_Boot_Info();

    v_Hw_Init();  // Initialize serial, serial timer, QSPI and flash

    v_Delay_Sec(5);

    u32_Switch_State = u32_Get_Switch_State(); // Depress SW2 or SW3 to go direct into console interface on powerup

    u8_Boot_Flag = u32_Switch_State == ALL_SWITCHES;

    v_Init_Metadata();

    u32_Counter = 0;

    while(1)
    {
        if( ++u32_Counter == 125000 )  // Establish approx. 1 Hz blink rate 50$ DC
        {
            ++u32_Seconds;
            v_Set_Heartbeat_LED( u8_On );
            u8_On = !u8_On;
            u32_Counter = 0;
        }

        u32_Switch_State = u32_Get_Switch_State();
        u8_Boot_Flag &= (u32_Switch_State == ALL_SWITCHES);

        if( u32_Seconds == BOOTLOADER_TIMEOUT_SEC & u8_Boot_Flag != 0 )
        {
            if( b_Check_App() && u8_Boot_Flag != 0 ) // unsucessful crc or update
            {
                v_Set_Heartbeat_LED(1);
                start_application();  // Will not return if it makes it here
            }
        }

        u32_Seconds = u32_Seconds == BOOTLOADER_TIMEOUT_SEC ? 0 : u32_Seconds;

        if(u8_Busy == 0)
          v_Check_Pending_Operations();
        v_Check_IRQs();

    }

  return 0;
}

void v_Set_Boot_Flag(uint8_t b_Val)
{
    u8_Boot_Flag = b_Val != 0;
}

void v_Delay_Sec(uint8_t u8_Sec )
{
volatile uint32_t u32_Dummy = 0;

    while(u8_Sec > 0)
    {
        for( u32_Dummy = 0; u32_Dummy < 100000; u32_Dummy++ );
        --u8_Sec;
    }
}

// For operations which can't be completed given the turnaround time for TMTC messages - so far, just erase operations
void v_Set_Pending( uint8_t u8_Operation, uint8_t *p_u32_Src, uint8_t u8_N_Args )
{
    u8_Pending_Operation = u8_Operation;
    memcpy( u32_Pending_Arg, p_u32_Src, u8_N_Args * sizeof(uint32_t) );
}

static void v_Check_Pending_Operations(void)
{
    if( u8_Pending_Operation != 0 && u8_Busy == 0)
    {
        switch( u8_Pending_Operation )
        {
        case PENDING_FLASH_BLOCK_ERASE:
            v_Flash_Block_Erase( u32_Pending_Arg[0] );
            break;

        case PENDING_FLASH_SECTOR_ERASE:
            v_Flash_Sector_Erase( u32_Pending_Arg[0] );
            break;

        case FLASH_MEMORY_LOAD: // Loads n bytes from a specified flash address to a specified memory address
            v_Flash_Memory_Load( u32_Pending_Arg[0], u32_Pending_Arg[1], u32_Pending_Arg[2] );
            break;

        default:
            break;
        }
        u8_Pending_Operation = 0;
    }
}

void v_Set_Busy(void)
{
    u8_Busy = 1;
}

void v_Clear_Busy(void)
{
    u8_Busy = 0;
}
