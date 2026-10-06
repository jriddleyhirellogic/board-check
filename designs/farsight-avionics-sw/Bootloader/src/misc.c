/*
 * misc.c
 *
 *  Created on: May 1, 2026
 *      Author: iboard
 */

#include <stdint.h>
#include <stddef.h>

void *memset(void *pdest, int Val, size_t u32_Len )
{
    uint8_t *pu8_dest = (uint8_t *)pdest;
    while( u32_Len-- != 0 )
    {
        *pu8_dest = (uint8_t)Val;
    }
//    return (void *)0;
}

void *   memcpy (void *pdest, const void *psrc, size_t len )
{
    uint8_t *pu8_dest = (uint8_t *)pdest;
    uint8_t *pu8_src = (uint8_t *)psrc;
    while(len-- != 0)
    {
        *pu8_dest++ = *pu8_src++;
    }
//    return (void *)0;
}
