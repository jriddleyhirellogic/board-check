/*
 * misc.h
 *
 *  Created on: Oct 3, 2025
 *      Author: iboard
 */

#ifndef MISC_H_
#define MISC_H_

// Enables external interrupt in processor core
void v_IRQ_Setup(void);

void v_Enable_Logging(uint8_t u8_Enable );
uint8_t b_Is_Logging_Enabled(void);
void v_Toggle_Logging(void);

//uint8_t reverse_bits(uint8_t num);

#endif /* MISC_H_ */
