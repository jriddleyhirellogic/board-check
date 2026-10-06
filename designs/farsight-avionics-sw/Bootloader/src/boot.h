/*
 * flags.h
 *
 *  Created on: Aug 12, 2026
 *      Author: iboard
 */

#ifndef BOOT_H_
#define BOOT_H_

#include <stdint.h>

#define UPDATE_FLAG (1 << 0)

typedef struct
{
    uint32_t u32_Bootloader_Version;
    uint32_t u32_Flags;

}Boot_Info_t;



#endif /* BOOT_H_ */
