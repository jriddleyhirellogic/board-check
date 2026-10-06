/*
 * events.h
 *
 *  Created on: Oct 7, 2025
 *      Author: iboard
 */

#ifndef EVENTS_H_
#define EVENTS_H_

#include <stdint.h>
#include "serial_sm.h"

/**
 * @enum Event_Sig_t
 * @brief Signal Values for IPC messages
 *
 */
typedef enum
{
    // Pseudo events used for state entrance and exit
    ENTRANCE,                   /**< Pseudo event for state entry */
    EXIT,                       /**< Pseudo event for state exit  */
    RECEIVED_SERIAL_MESSAGE,    /**< A TMTC message has been received on the serial port  */
    FOCUS_TIMER_EXPIRED,      /**< Expiration of timer used in focus PI controller  */
    FOCUS_FAULT_TIMER_EXPIRED,/**< Focus fault timer expiration */
    CAMERA_TIMER_EXPIRED,       /**< Expiration of camera timer */
    RESET_RECEIVED,             /**< A reset message has been received through TMTC  */
    ZERO_STEPPER,               /**< Begin zeroing (homing) operation of focus mechanism */
    GOTO_POSITION,              /**< Begin focus operation - go to programmed position  */

    // Camera
    POWER_UP_CAMERA,
    POWER_DOWN_CAMERA,
    ARM_CAMERA,
    IDLE_CAMERA,
    CAMERA_TAKE_PICTURE,
    CAMERA_MODE_SET,
    CAMERA_CONFIG_CHANGED,      /**< A register write may have changed the imaging configuration */
    CAMERA_SEND_FRAMES,
    CAMERA_GET_METADATA,
    CAMERA_RESET_FRAME_INDEX,
    BURST_CAPTURE_COMPLETE,
    BURST_CAPTURE_STARTED,
    UDP_TRANSFER_COMPLETE,

    // System
    SYSTEM_RESET,
    DO_FLASH_SECTOR_ERASE,
    DO_FLASH_BLOCK_ERASE,
    DO_FLASH_READ,
    DO_FLASH_WRITE,

    // For test/debug purposes
    START_TEST_1,
    START_TEST_2,

    // debug and test events follow
    TEST_MSG
}Event_Sig_t;

/**
 * @struct Serial_Msg_Test_t
 * @brief Notifies serial comm task of received message
 *
 */
typedef struct
{
    Event_Sig_t sig;              /**< Signal value identifying event type */
    Serial_Msg_Header_t header;   /**< Parsed received message header */
    uint8_t *Data;                /**< Receive message buffer */
}Event_Serial_Msg_Test_t;

/**
 * @struct Command_Msg_Test_t
 * @brief  Command message
 *
 */
typedef struct
{
    Event_Sig_t sig;      /**< Signal value identifying event type */
    uint8_t *Buffer;
    uint8_t u8_Function;
    uint8_t u8_Buffer_Length;
}Command_Msg_Test_t;

/**
 * @struct Event_Msg_No_Data_t
 * @brief  Event with no data payload - simply signifies something happened.
 *
 */
typedef struct
{
    Event_Sig_t sig;     /**< Signal value identifying event type */
}Event_Msg_No_Data_t;

typedef struct
{
    Event_Sig_t sig;
    uint8_t u8_Mode;
}Event_Mode_Set_t;

typedef struct               /**< Flash data associated with an address  */
{
    Event_Sig_t sig;
    uint32_t u32_Address;
    uint8_t *p_Data;
}Flash_Data_t;

typedef struct
{
    Event_Sig_t sig;         /**< Signal value identifying event type */
    int32_t i32_Position;    /**< Destination position (microns) */
}Event_Msg_Position_t;

/**
 * @enum xfer_type_t
 * @brief Selects the operation performed by the camera transfer state
 */
typedef enum
{
    XFER_TYPE_FRAMES,        /**< Stream image frame(s) out over UDP */
    XFER_TYPE_METADATA       /**< Read image metadata and return it over serial */
}xfer_type_t;

typedef struct
{
    Event_Sig_t sig;         /**< Signal value identifying event type */
    uint16_t u16_index;      /**< Starting frame index (0 to TOTAL-1) */
    uint16_t u16_num;        /**< Number of frames to transfer (1 to TOTAL) */
    uint8_t  u8_xfer_type;   /**< xfer_type_t: frame transfer vs. metadata read */
}Event_Xfer_Frames_t;

/**
 * @union Event_t
 * @brief Union of possible message types
 */
typedef union
{
    Event_Msg_No_Data_t    no_data;
    Event_Mode_Set_t       mode_set;
    Command_Msg_Test_t     command;
    Event_Msg_Position_t   position;
    Event_Serial_Msg_Test_t serial_msg;
    Flash_Data_t           flash_data;
    Event_Xfer_Frames_t    xfer_frames;
}Event_t;


#endif /* EVENTS_H_ */
