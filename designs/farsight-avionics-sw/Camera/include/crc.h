/*
 * crc.h
 *
 *  Created on: Nov 12, 2025
 *      Author: iboard
 */

#ifndef CRC_H_
#define CRC_H_
#include <stdint.h>

uint32_t crc(uint8_t const u8_Msg[], uint16_t u16_Len, uint32_t  u32_Rem);

#endif /* CRC_H_ */
