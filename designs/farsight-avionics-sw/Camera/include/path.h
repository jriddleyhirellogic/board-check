/*
 * path.h
 *
 *  Created on: Oct 30, 2025
 *      Author: iboard
 */

#ifndef PATH_H_
#define PATH_H_

#include "FreeRTOSConfig.h"
#include "FreeRTOS.h"
#include "task.h"
#include "path.h"

#define END_OF_PATH 999999

int32_t i32_Get_Setpoint(TickType_t current_time );


#endif /* PATH_H_ */
