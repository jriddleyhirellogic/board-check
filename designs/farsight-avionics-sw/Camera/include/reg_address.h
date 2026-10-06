/*
 * reg_address.h
 *
 *  Created on: Dec 4, 2025
 *      Author: iboard
 */

#ifndef REG_ADDRESS_H_
#define REG_ADDRESS_H_

// CAMERA STATUS AND CONTROL
#define SENSOR_STAT_SYS_REG          0x0
#define SENSOR_FRM_MOD_SYS_REG       0x1
#define SENSOR_BIT_DEPTH_SYS_REG     0x2
#define SENSOR_GAIN_SYS_REG          0x3
#define SENSOR_BLO_SYS_REG           0x5
#define SENSOR_EXPO_USEC_SYS_REG     0x7
#define SENSOR_TEMP_KEL_SYS_REG      0xB
#define SENSOR_OVER_TEMP_KEL_SYS_REG 0xD

//SYSTEM
#define MODE_SYS_REG               0xF
#define LAST_ERROR_SYS_REG         0x10
#define RST_REASON_SYS_REG         0x11
#define FPGA_TEMP_KEL_SYS_REG      0x12
#define FPGA_VOLTAGE_SYS_REG       0x14
#define DDR4_16_PWR_STATUS         0x16
#define DDR4_8_PWR_STATUS_REG          0x17
#define LVDS_PWR_STATUS_REG            0x18
#define ETH0_PWR_STATUS            0x19
#define ETH1_PWR_STATUS_REG            0x1A
#define FOCUS_MECH_PWR_STATUS      0x1B
#define SENSOR_PWR_STATUS          0x1C
#define ERROR_COUNT_SYS_REG        0x1D
#define BOOT_COUNT_SYS_REG         0x21
#define UPTIME_MSEC_SYS_REG        0x25
#define TIMESTAMP_UNIX_SYS_REG     0x2D
#define WDOG_TIMEOUT_MSEC_SYS_REG  0x35
#define BUFF_WRITE_POLICY_SYS_REG  0x39
#define BUFF_WRITE_PTR_SYS_REG     0x41
#define BUFF_BYTES_AVAIL_SYS_REG   0x49
#define FRAME_BYTE_PACKING_EN_REG  0x51

//SYSTEM IMAGING
#define TRIG_MODE_SYS_REG          0x52
#define IMG_PER_TRIGGER_SYS_REG    0x53
#define FRAMES_PER_SEC_SYS_REG     0x55
#define CAP_START_DLY_USEC_SYS_REG 0x56
#define FRAME_COUNT_SYS_REG        0x5A
#define FOCUS_REQ_DIST_M_SYS_REG   0x5E
#define FOCUS_COMP_DIST_M_SYS_REG  0x62
#define FOCUS_LVDT_POS_NM_REG      0x66

//SYSTEM COMMUNICATION
#define GPO_CONF_SYS_REG            0x6A
#define GPI_CONF_SYS_REG            0x6B
#define INTR_PIN_CONF_SYS_REG       0x6C
#define TRIG_PIN_CONF_SYS_REG       0x6D
#define TRIG_DELAY_USEC_SYS_REG     0x6E
#define TRIG_TIMEOUT_MSEC_SYS_REG   0x70
#define TMTC_TIMEOUT_MSEC_SYS_REG   0x74
#define SER_BAUD_SYS_REG            0x78
#define ETH0_MAC_ADDRESS_SYS_REG    0x75
#define ETH1_MAC_ADDRESS_SYS_REG    0x7B
#define ETH0_IP_ADDRESS_SYS_REG     0x81
#define ETH1_IP_ADDRESS_SYS_REG     0x85
#define GATEWAY_SYS_REG             0x89
#define SUBNET_MASK_SYS_REG         0x8D
#define ETH0_PORT_SYS_REG           0x91
#define ETH1_PORT_SYS_REG           0x93

//SYSTEM VERSION
#define FAV_DEVICE_ID_SYS_REG 0x95
#define SENSOR_ID_SYS_REG     0x97
#define TMTC_VERS_SYS_REG     0x99
#define SW_VERS_SYS_REG       0x9B
#define PF_FW_VERS_SYS_REG    0x9D
#define P3_FW_VERS_SYS_REG    0x9F
#define FW_MD5_SYS_REG        0xA0


#endif /* REG_ADDRESS_H_ */
