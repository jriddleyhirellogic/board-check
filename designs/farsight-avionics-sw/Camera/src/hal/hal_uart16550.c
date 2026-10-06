/**
 * @file hal_uart16550.h
 * @author  iboard
 * @brief driver for microchip/actal 16550 type uart
 *  Created on: Sep 26, 2025
 */

#include "hal_uart16550.h"
#include "hal.h"
#include "hw_reg_access.h"

static void v_Set_UART_Divisor( UART_16550_Instance_t *this_instance, uint16_t u16_Divisor );
static void v_Init_UART_Line(UART_16550_Instance_t *this_instance, uint8_t u8_Line_Params );
static void v_Init_FIFOs(UART_16550_Instance_t *this_instance);
static void v_Set_Modem_Ctrl( UART_16550_Instance_t *this_instance );

/**
 * @fn void v_Init_UART(UART_16550_Instance_t*)
 * @brief Initializes 16550 type uart
 * Initialization includes baud rate, line mode and fifos
 * @param this_instance Pointer to particular instance
 */
void v_Init_UART( UART_16550_Instance_t *this_instance )
{
    v_Disable_UART_IRQ( this_instance, UART_ALL_IRQ_ENABLES );
    v_Set_UART_Divisor(this_instance, BAUDRATE_115200 );         //115200 baud with 50 MHz clock
    v_Init_UART_Line(this_instance, UART16550_WLS_8_BITS );      // 8/N/1
    v_Init_FIFOs( this_instance );                               // Enable and clear RX and TX FIFOs, set RX threshold to 1
}

/**
 * @fn uint8_t u8_Get_UART_Rx_Data(UART_16550_Instance_t*)
 * @brief Wrapper function to retrieve single byte from receive fifo
 *
 * @param this_instance uart instance
 * @return
 */
uint8_t u8_Get_UART_Rx_Data( UART_16550_Instance_t *this_instance )
{
    return HAL_get_8bit_reg( this_instance->u32_Base_Address, RX_DATA );
}

/**
 * @fn void v_Init_FIFOs(UART_16550_Instance_t*)
 * @brief Reset and initialize transmit and receive fifos
 *
 * @param this_instance
 */
static void v_Init_FIFOs(UART_16550_Instance_t *this_instance)
{
    // Enables and clears RX and TX FIFOs
    HAL_set_8bit_reg(this_instance->u32_Base_Address, FIFO_CTRL, 7 );
}

/**
 * @fn uint8_t b_Is_Tx_Hold_Reg_Empty(UART_16550_Instance_t*)
 * @brief Test if tx holding register is empty
 *
 * @param this_instance
 * @return 1 if empty, 0 if contains data
 */
uint8_t b_Is_Tx_Hold_Reg_Empty( UART_16550_Instance_t *this_instance )
{
    uint8_t u8_LSR = HAL_get_8bit_reg( this_instance->u32_Base_Address, LINE_STATUS );
    return (u8_LSR & LINE_STATUS_THRE) != 0;
}

/**
 * @fn void v_Write_UART_Tx_Data(UART_16550_Instance_t*, uint8_t)
 * @brief Write single byte to tx fifo
 * @param this_instance
 * @param u8_Data Byte to write to fifo
 */
void v_Write_UART_Tx_Data(UART_16550_Instance_t *this_instance, uint8_t u8_Data )
{
    //@todo Need to wait while TXHR is not empty
    HAL_set_8bit_reg(this_instance->u32_Base_Address, TX_HOLD, u8_Data );
}

uint8_t u8_Get_Modem_Status(UART_16550_Instance_t *this_instance)
{
    return HAL_get_8bit_reg( this_instance->u32_Base_Address, MODEM_STATUS );
}

uint8_t u8_Get_Interrupt_Cause( UART_16550_Instance_t *this_instance )
{
    return HAL_get_8bit_reg( this_instance->u32_Base_Address, IRQ_ID );
}


__attribute__((unused)) static void v_Set_Modem_Ctrl( UART_16550_Instance_t *this_instance )
{
    HAL_set_8bit_reg(this_instance->u32_Base_Address, MODEM_CTRL, (1 << 1 ) | (1 << 0 ));
}

uint8_t u8_Get_Line_Status(UART_16550_Instance_t *this_instance )
{
    return HAL_get_8bit_reg( this_instance->u32_Base_Address, LINE_STATUS );
}

/**
 * @fn void v_Enable_UART_IRQ(UART_16550_Instance_t*, uint8_t)
 * @brief Enables the interrupt at the uart
 * @param this_instance
 * @param u8_IRQ
 */
void v_Enable_UART_IRQ( UART_16550_Instance_t *this_instance, uint8_t u8_IRQ )
{
    uint8_t u8_Temp = HAL_get_8bit_reg( this_instance->u32_Base_Address, IRQ_ENABLE );
    u8_Temp |= u8_IRQ & 0xf;
    HAL_set_8bit_reg(this_instance->u32_Base_Address, IRQ_ENABLE, u8_Temp );
}

/**
 * @fn void v_Disable_UART_IRQ(UART_16550_Instance_t*, uint8_t)
 * @brief Disables the interrupt at the uart
 * @param this_instance
 * @param u8_IRQ
 */
void v_Disable_UART_IRQ( UART_16550_Instance_t *this_instance, uint8_t u8_IRQ )
{
    uint8_t u8_Temp = HAL_get_8bit_reg( this_instance->u32_Base_Address, IRQ_ENABLE );
    u8_Temp &= (~u8_IRQ) & 0xf;
    HAL_set_8bit_reg(this_instance->u32_Base_Address, IRQ_ENABLE, u8_Temp );
}

static void v_Init_UART_Line(UART_16550_Instance_t *this_instance, uint8_t u8_Line_Init )
{
    HAL_set_8bit_reg(this_instance->u32_Base_Address, LINE_CTRL, u8_Line_Init);
}

/**
 * @fn void v_Set_UART_Divisor(UART_16550_Instance_t*, uint16_t)
 * @brief Sets the the baud rate
 *     Baud rate = PCLK/(16 * divisor)
 *     Example - for 115200, PCLK = 50 MHz Divisor = 27 Error is 0.4%
 * @param this_instance
 * @param u16_Divisor
 */
static void v_Set_UART_Divisor( UART_16550_Instance_t *this_instance, uint16_t u16_Divisor )
{
    uint8_t u8_Temp;
    uint8_t u8_Readback;

    // @todo enter critical section
    // Set Data latch access bit
    u8_Temp = HAL_get_8bit_reg( this_instance->u32_Base_Address, LINE_CTRL );
    u8_Temp |= UART16550_DLAB;
    HAL_set_8bit_reg(this_instance->u32_Base_Address, LINE_CTRL, u8_Temp);

    // Set MSB
    HAL_set_8bit_reg(this_instance->u32_Base_Address, DIVISOR_LATCH_MSB, u16_Divisor >> 8);
    u8_Readback = HAL_get_8bit_reg( this_instance->u32_Base_Address, DIVISOR_LATCH_MSB );

    // Set LSB
    HAL_set_8bit_reg(this_instance->u32_Base_Address, DIVISOR_LATCH_LSB, u16_Divisor & 0xFF);
    u8_Readback = HAL_get_8bit_reg( this_instance->u32_Base_Address, DIVISOR_LATCH_LSB );

    // Clear Data latch access bit
    u8_Temp &= ~UART16550_DLAB;
    HAL_set_8bit_reg(this_instance->u32_Base_Address, LINE_CTRL, u8_Temp );

    // @todo exit critical section
}

void v_Set_UART_Scratch( UART_16550_Instance_t *this_instance, uint8_t u8_Value )
{
    HAL_set_8bit_reg(this_instance->u32_Base_Address, SCRATCH, u8_Value );
}





