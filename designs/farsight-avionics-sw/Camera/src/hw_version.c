/*
 * hw_version.c
 *
 *  Created on: Apr 1, 2026
 *      Author: iboard
 */

#include "mem_map.h"
#include "hw_version.h"
#include "hal/hal.h"
#include "image_metadata.h"


uint32_t u32_Get_PF_FPGA_Version(void)
{
    uint32_t u32_Version = *((volatile uint32_t *)VERSION_BASE_ADDR);

    HAL_set_32bit_reg( IMG_METADATA_BASE_ADDR, VERSION, u32_Version );

    return u32_Version;
}

uint32_t u32_Get_PF_FPGA_Git_Hash(void)
{
    return *((volatile uint32_t *)(VERSION_BASE_ADDR + 4));
}

uint32_t u32_Get_PF_FPGA_Build_Time(void)
{
    return *((volatile uint32_t *)(VERSION_BASE_ADDR + 8));
}


