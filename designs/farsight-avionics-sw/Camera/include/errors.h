/*
 * errors.h
 *
 *  Created on: Nov 14, 2025
 *      Author: iboard
 */

#ifndef ERRORS_H_
#define ERRORS_H_

/**
 * @enum Error_Code_t
 * @brief TMTC command error codes
 */
typedef enum
{
    NO_ERROR,                 /**< NO_ERROR */
    ERR_CMD_INVALID_MODE,     /**< ERR_CMD_INVALID_MODE */
    ERR_CMD_INVALID_OPCODE,   /**< ERR_CMD_INVALID_OPCODE */
    ERR_PKT_INVALID_HDR_CRC,  /**< ERR_PKT_INVALID_HDR_CRC */
    ERR_PKT_INVALID_DATA_CRC, /**< ERR_PKT_INVALID_DATA_CRC */
    ERR_PKT_INVALID_DATA_LEN, /**< ERR_PKT_INVALID_DATA_LEN */
    ERR_PKT_INVALID_HDR_PARAM,/**< ERR_PKT_INVALID_HDR_PARAM */
    ERR_REG_INVALID_ADDR,     /**< ERR_REG_INVALID_ADDR */
    ERR_REG_INVALID_LIMIT,    /**< ERR_REG_INVALID_LIMIT */
    ERR_REG_WRITE_DENIED_RO,  /**< ERR_REG_WRITE_DENIED_RO */
    ERR_REG_MODE_REJECTED,    /**< ERR_REG_MODE_REJECTED */
    // User codes for debug below
    ERR_XFER_INVALID_INDEX,    /**< ERR_XFER_INVALID_INDEX - index out of [0, TOTAL-1] */
    ERR_XFER_INVALID_NUM,      /**< ERR_XFER_INVALID_NUM - num out of [1, TOTAL] */
    ERR_XFER_OUT_OF_BOUNDS,    /**< ERR_XFER_OUT_OF_BOUNDS - index + num exceeds total frame count */
}Error_Code_t;


#endif /* ERRORS_H_ */
