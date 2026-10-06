/*
 * version.h
 *
 *  Created on: Dec 11, 2025
 *      Author: iboard
 */

#ifndef VERSION_H_
#define VERSION_H_

#include <stdint.h>

// Increment these values with new builds
#define FW_MAJOR 1
#define FW_MINOR 0
#define FW_BUILD 0
#define FW_FIX   0

#define PF_FW_VERSION    (((FW_MAJOR & 0xFF) << 24) |\
                          ((FW_MINOR & 0xFF) << 16) |\
                          ((FW_FIX   & 0xFF) <<  8) |\
                           (FW_BUILD & 0xFF) )
#define PA3_FPGA_VERSION 0x11112222
#define SENSOR_ID        0x33334444
#define FAV_DEVICE_ID    0x44445555

typedef struct
{
    uint32_t u32_PF_FPGA_Version;
    uint32_t u32_PF_FPGA_Git_Hash;
    uint32_t u32_PF_FPGA_Build_Time;
    uint32_t u32_PA3_FPGA_Version;
    uint32_t u32_PF_FW_Version;
    uint32_t u32_FAV_Device_ID;
    uint32_t u32_Sensor_ID;
//    uint32_t u32_Bootloader_Version;
}Version_t;

void v_Read_Version_Info(void);
Version_t *Get_Version_Info(void);

#endif /* VERSION_H_ */
