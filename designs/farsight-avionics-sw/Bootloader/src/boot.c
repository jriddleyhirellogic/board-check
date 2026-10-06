/*
 * flags.c
 *
 *  Created on: Aug 12, 2026
 *      Author: iboard
 */

#include "boot.h"
#include <stdint.h>
#include "version.h"

uint8_t u8_Boot_Info[32] __attribute__((section(".boot_args")));
uint8_t *p_Boot = &u8_Boot_Info[0];

void v_Init_Boot_Info(void)
{
    Boot_Info_t *p_BL_Info = (Boot_Info_t *)p_Boot;
    uint32_t u32_Version = (BL_MAJOR_VERSION & 0xff) << 24 |
                           (BL_MINOR_VERSION & 0xff) << 16 |
                           (BL_BUILD_VERSION & 0xff) << 8  |
                           (BL_FIX_VERSION & 0xff);
    p_BL_Info->u32_Bootloader_Version = u32_Version;
}

