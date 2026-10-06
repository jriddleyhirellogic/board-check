/*
 * error_id.h
 *
 *  Created on: Dec 4, 2025
 *      Author: iboard
 */

#ifndef ERROR_ID_H_
#define ERROR_ID_H_

typedef enum
{
    NO_ERROR = 0x00,
    ERR_CMD_INVALID_MODE = 0x01,
    ERR_CMD_INVALID_OPCODE = 0x02,
    ERR_PKT_INVALID_HDR_CRC = 0x03,
    ERR_PKT_INVALID_DATA_CRC = 0x04,
    ERR_PKT_INVALID_DATA_LEN = 0x05,
    ERR_PKT_INVALID_HDR_PARAM = 0x06,
    ERR_REG_INVALID_ADDR = 0x07,
    ERR_REG_INVALID_LIMIT = 0x08,
    ERR_REG_WRITE_DENIED_RO = 0x09,
    ERR_REG_MODE_REJECTED = 0x0A
}Error_ID_t;


#endif /* ERROR_ID_H_ */
