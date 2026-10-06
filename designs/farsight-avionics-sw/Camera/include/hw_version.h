/*
 * hw_version.h
 *
 *  Created on: Apr 1, 2026
 *      Author: iboard
 */

#ifndef HW_VERSION_H_
#define HW_VERSION_H_

#include <stdint.h>

uint32_t u32_Get_PF_FPGA_Version(void);
uint32_t u32_Get_PF_FPGA_Git_Hash(void);
uint32_t u32_Get_PF_FPGA_Build_Time(void);

#endif /* HW_VERSION_H_ */
