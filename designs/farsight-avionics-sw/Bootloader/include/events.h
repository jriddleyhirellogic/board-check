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

// Signal Definitions
typedef enum
{
    ENTRANCE,
    EXIT,
    RECEIVED_SERIAL_MESSAGE,
    CONTROL_TIMER_EXPIRED,
    CAMERA_TIMER_EXPIRED,
    RESET_RECEIVED,
    ZERO_STEPPER,
    GOTO_POSITION,
    // Camera
    POWER_UP_CAMERA,
    POWER_DOWN_CAMERA,
    ARM_CAMERA,
    CAMERA_TAKE_PICTURE,
    // For test/debug purposes
    START_TEST_1,
    START_TEST_2,
    // debug and test events follow
    TEST_MSG
}Event_Sig_t;

typedef struct
{
    Event_Sig_t sig;
    uint8_t *Buffer;
    uint8_t u8_Function;
    uint8_t u8_Buffer_Length;

}Event_Msg_Test_t;

typedef struct
{
    Event_Sig_t sig;
    Serial_Msg_Header_t header;
    uint8_t *Data;

}Event_Serial_Msg_Test_t;

typedef struct
{
    Event_Sig_t sig;
    uint8_t *Buffer;
    uint8_t u8_Function;
    uint8_t u8_Buffer_Length;

}Command_Msg_Test_t;

typedef struct
{
    Event_Sig_t sig;
}Event_Msg_No_Data_t;

typedef struct
{
    Event_Sig_t sig;
    int32_t i32_Position;
}Event_Msg_Position_t;

typedef union
{
    Event_Msg_No_Data_t no_data;
    Event_Msg_Test_t    test;
    Command_Msg_Test_t  command;
    Event_Msg_Position_t position;
    Event_Serial_Msg_Test_t serial_msg;
}Event_t;


#endif /* EVENTS_H_ */
