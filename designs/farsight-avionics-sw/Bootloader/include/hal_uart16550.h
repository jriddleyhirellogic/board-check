#ifndef _HAL_UART16550_H
#define _HAL_UART16550_H
#include <stdint.h>
#include "mem_map.h"

// To allow for the possibility of more than one UART
typedef struct
{
    uint32_t u32_Base_Address;
    uint8_t u8_Status;
}UART_16550_Instance_t;

// The addresses are the same. The use depends on the direction (R/W)
#define RX_DATA_REG_OFFSET 0     // (R) DL Bit = 0
#define TX_HOLD_REG_OFFSET 0      // (W) DL Bit = 0

// These depend on setting the divisor latch bit
#define DIVISOR_LATCH_LSB_REG_OFFSET 0      //DL Bit = 1
#define DIVISOR_LATCH_MSB_REG_OFFSET 4      //DL Bit = 1

// Interrupts
#define IRQ_ENABLE_REG_OFFSET 4
// Interrupt enable bits
#define UART_ERBFI (1 << 0)  // Receive data
#define UART_ETBEI (1 << 1)  // Transmit holding reg empty
#define UART_ELSI  (1 << 2)  // Receive line status change
#define UART_EDSSI (1 << 3)  // Modem status change
#define UART_ALL_IRQ_ENABLES (UART_ERBFI | UART_ETBEI | UART_ELSI |  UART_EDSSI)

// Interrupt reasons
#define IRQ_ID_REG_OFFSET 8          //(R)

// Possible values for the IRQ ID field only makes sense to read in an interrupt
#define IRQ_ID_RX_LINE_STATUS 6
#define IRQ_ID_RX_DATA_AVAIL  4
#define IRQ_ID_TIMEOUT_IND    0xC
#define IRQ_TX_HOLD_REG_EMPTY 2
#define IRQ_ID_MODEM_STATUS   0

#define FIFO_CTRL_REG_OFFSET 8    //(W)

// Line control register
#define LINE_CTRL_REG_OFFSET 0xC
// Word length
#define UART16550_WLS_5_BITS 0
#define UART16550_WLS_6_BITS 1
#define UART16550_WLS_7_BITS 2
#define UART16550_WLS_8_BITS 3
#define UART16550_WLS(x)  (x & 3)
#define UART16550_STB (1 << 2)
#define UART16550_PEN (1 << 3)
#define UART16550_EPS (1 << 4)
#define UART16550_SP  (1 << 5)
#define UART16550_SB  (1 << 6)
#define UART16550_DLAB (1 << 7)

#define MODEM_CTRL_REG_OFFSET     0x10

#define LINE_STATUS_REG_OFFSET    0x14
// Line Status Register Bits
#define LINE_STATUS_DR     (1 << 0)
#define LINE_STATUS OE     (1 << 1)
#define LINE_STATUS_PE     (1 << 2)
#define LINE_STATUS_FE     (1 << 3)
#define LINE_STATUS_BI     (1 << 4)
#define LINE_STATUS_THRE   (1 << 5)
#define LINE_STATUS_TEMT   (1 << 6)
#define LINE_STATUS_FIER   (1 << 7)


#define MODEM_STATUS_REG_OFFSET   0x18

// Doesn't affect modem operation
#define SCRATCH_REG_OFFSET        0x1C

// Baud rate calc
// BR = F_PCLK/(16 * DIVISOR)
// => DIVISOR = F_PCLK/(BR * 16)
// Round up or down to get least BR error
#define BAUDRATE_115200 27

// Public functions
uint8_t u8_Get_UART_Rx_Data(UART_16550_Instance_t *this_intance );
void v_Write_UART_Tx_Data(UART_16550_Instance_t *this_instance, uint8_t u8_Data );
void v_Enable_UART_IRQ( UART_16550_Instance_t *this_instance, uint8_t u8_IQQ );
void v_Disable_UART_IRQ( UART_16550_Instance_t *this_instance, uint8_t u8_IQQ );
void v_Init_UART(UART_16550_Instance_t *this_instance );
uint8_t u8_Get_Modem_Status(UART_16550_Instance_t *this_instance);
uint8_t u8_Get_Line_Status(UART_16550_Instance_t *this_instance);
uint8_t b_Is_Tx_Hold_Reg_Empty( UART_16550_Instance_t *this_instance );
void v_Set_UART_Scratch( UART_16550_Instance_t *this_instance, uint8_t u8_Value );
uint8_t u8_Get_Interrupt_Cause( UART_16550_Instance_t *this_instance );
uint8_t b_Is_UART_IRQ_Enabled( UART_16550_Instance_t *this_instance, uint8_t u8_IRQ );

#endif
