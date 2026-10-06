/*
 * command.h
 *
 *  Created on: Oct 8, 2025
 *      Author: iboard
 */

#ifndef COMMAND_H_
#define COMMAND_H_

/**
 * @enum Serial_Function_Code_t
 * @brief Opcodes used by TMTC commands
 */
typedef enum
{
    // Values are from the ICD
    GET_VERSION_SYS_CMD = 0x00,   /**< Get version info. Returns seven 32-bit words:
                                       PF FPGA version, PF FPGA git hash,
                                       PF FPGA build time (Unix epoch seconds),
                                       PA3 FPGA version, SW version,
                                       FAV device ID and sensor ID */
    SET_MODE_SYS_CMD = 0x01,      /**< Put camera in indicated mode */
    RESET_SYS_CMD = 0x02,         /**< Do system reset */
    REG_READ_SYS_CMD = 0x03,      /**< Read register */
    REG_WRITE_SYS_CMD = 0x04,     /**< Write register */
    SET_TIME_SYS_CMD = 0x05,      /**< Set time at the next PPS edge */
    START_ACQ_SYS_CMD = 0x06,     /**< Take picture */
    STOP_ACQ_SYS_CMD = 0x07,      /**< Halt picture taking */
    FOCUS_SYS_CMD = 0x08,         /**< Move focus mechanism to indicated position */
    HALT_FOCUS_SYS_CMD = 0x09,    /**< Stop focus operation in progress */
    XFER_BUFF_SYS_CMD = 0x0A,     /**< Transfer image buffer */
    GET_INFO_SYS_CMD = 0x0C,      /**< Get system information */
    CONF_EVENT_LOG_SYS_CMD = 0x0D,/**< CONF_EVENT_LOG_SYS_CMD */
    EN_TL_CHAN_LOG_SYS_CMD = 0x0E,/**< EN_TL_CHAN_LOG_SYS_CMD */
    XFER_LOG_SYS_CMD = 0x0F,      /**< XFER_LOG_SYS_CMD */

    // User defined, for debug and integration
    ECHO_FUNCTION = 25,           /**< Reflects received data for testing TMTC interface */
    GET_STATUS_FUNCTION,          /**< Get focus position, velocity and fault state */
    SET_VREF_FUNCTION,            /**< Set the overcurrent voltage reference in focus mechanism */
    SET_POSITION,                 /**< Go to indicated position */
    SET_CONTROL_OUTPUTS_FUNCTION, /**< Set control outputs on focus mechanism */
    ZERO_FUNCTION,                /**< Zero (home) the focus mechanism */
    SET_LVDT_OFFSET_FUNCTION,     /**< Set offset (microns) between LVDT electrical zero and mech zero */
    GET_POSITION_FUNCTION,        /**< Get the current position indicated by LVDT*/
    GET_PROJECTION = 34,          /**< GET_PROJECTION */
    UPDATE_NET_ADDRESS = 36,
    GET_TLM_READING,

    // Functions to read and write flash memory
    FLASH_ERASE_SECTOR,
    FLASH_ERASE_BLOCK,
    WRITE_FLASH_PAGE,
    READ_FLASH,
    RESET_FLASH,

    // Misc
    GET_CAMERA_TEMP,
    GET_FPGA_TEMP,
    GET_CAMERA_STATE,
    GET_METADATA,           
    SET_PPS_DELAY,       /**< Get image frame metadata (returned on UART) */
    GET_SYSTEM_TIME,
    GET_PPS_ERRORS,
    GET_ALL_TLM,

    // The remaining are only for the bootloader
    BOOTLOADER_ONLY = 75,
    LOAD_FLASH_TO_MEM,
    START_APP,
    UPDATE

}Serial_Function_Code_t;

/**
 * @brief Bit field values for the target_reset argument of RESET_SYS_CMD
 */
#define RESET_CAM_SENSOR   (1 << 0)   /**< Reset the camera and imaging sensor */
#define RESET_FOCUS_MECH   (1 << 1)   /**< Reset the focus mechanism */
#define RESET_REG_SPACE    (1 << 2)   /**< Restore all registers to their default values */
#define RESET_MEM_BUFF     (1 << 3)   /**< Reset the image frame buffer index to 0 */

#define RESET_TARGET_MASK  ( RESET_CAM_SENSOR | \
                             RESET_FOCUS_MECH | \
                             RESET_REG_SPACE  | \
                             RESET_MEM_BUFF )

typedef enum
{
    OK,
    MALFORMED_PACKET,
    UNIMPLEMENTED
}Command_Exec_Status_t;

uint8_t Execute_Command( Serial_Msg_Header_t *p_Header,
                         uint8_t *p_u8_Data,
                         uint8_t *p_Response_Buffer,
                         uint8_t *p_u8_Response_Length );

void v_Send_Metadata_Response( uint32_t *p_Metadata, uint8_t u8_Word_Count );



#endif /* COMMAND_H_ */
