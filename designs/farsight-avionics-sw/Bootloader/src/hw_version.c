/*
 * hw_version.c
 *
 *  Created on: Apr 1, 2026
 *      Author: iboard
 */

#include "mem_map.h"
#include "hw_version.h"

uint32_t u32_Get_HW_Version(void)
{
    return *((volatile uint32_t *)VERSION_BASE_ADDR);
}

uint32_t u32_Get_HW_Git_Hash(void)
{
    return *((volatile uint32_t *)(VERSION_BASE_ADDR + 4));
}

uint32_t u32_Get_HW_Build_Time(void)
{
    return *((volatile uint32_t *)(VERSION_BASE_ADDR + 8));
}


