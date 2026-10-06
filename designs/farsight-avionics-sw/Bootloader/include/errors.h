/*
 * errors.h
 *
 *  Created on: Nov 14, 2025
 *      Author: iboard
 */

#ifndef ERRORS_H_
#define ERRORS_H_

typedef enum
{
    NO_ERROR,
    ERR_CMD_INVALID_MODE,
    ERR_CMD_INVALID_OPCODE,
    ERR_PKT_INVALID_HDR_CRC,
    ERR_PKT_INVALID_DATA_CRC,
    ERR_PKT_INVALID_DATA_LEN,
    ERR_PKT_INVALID_HDR_PARAM,
    ERR_REG_INVALID_ADDR,
    ERR_REG_INVALID_LIMIT,
    ERR_REG_WRITE_DENIED_RO,
    ERR_REG_MODE_REJECTED,
    // User codes for debug below
}Error_Code_t;


#endif /* ERRORS_H_ */
