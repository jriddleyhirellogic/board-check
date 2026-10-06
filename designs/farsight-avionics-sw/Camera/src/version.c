/*
 * version.c
 *
 *  Created on: Aug 12, 2026
 *      Author: iboard
 */


#include "version.h"
#include "hw_version.h"

static Version_t version_info;
Version_t *p_Version = &version_info;

void v_Read_Version_Info(void)
{
    p_Version->u32_PF_FPGA_Version =  u32_Get_PF_FPGA_Version();  // This should be first
//    HAL_set_32bit_reg(IMG_METADATA_BASE_ADDR, VERSION, u32_PF_FPGA_Version);
    p_Version->u32_PF_FPGA_Git_Hash = u32_Get_PF_FPGA_Git_Hash();
    p_Version->u32_PF_FPGA_Build_Time = u32_Get_PF_FPGA_Build_Time();
    p_Version->u32_PA3_FPGA_Version = PA3_FPGA_VERSION;
    p_Version->u32_PF_FW_Version = PF_FW_VERSION;
    p_Version->u32_FAV_Device_ID = FAV_DEVICE_ID;
    p_Version->u32_Sensor_ID = SENSOR_ID;
}

Version_t *Get_Version_Info(void)
{
    return p_Version;
}
