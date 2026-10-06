/*
 * path_planner.h
 *
 *  Created on: Nov 6, 2025
 *      Author: iboard
 */

#ifndef PATH_PLANNER_H_
#define PATH_PLANNER_H_

#include <stdint.h>

#define BASE_VEL  0.1f  // Lead screw velocity in microns/sec when counter = 1 and MS = 256

// Motion parameters
#define ACCELERATION   1            // acceleration
#define MAX_V          400      // max vel - x base freq of steps (262 Hz), (x 0.1 microns/sec)
#define MIN_V         -MAX_V
#define DEADBAND_MICRONS 2
#define DB_HYST 3
#define SOFT_TRAVEL_LIMIT_MICRONS 1125

typedef struct
{
    // Based on 10 ms tick period
    int32_t v_max;
    int32_t v_min;
    int32_t a;
}Motion_Params_t;

void v_Init_Path_Planner( int32_t i32_Start, int32_t i32_Final );
int32_t i32__Update_Path_SM();
void v_Reset_Path(void);

#endif /* PATH_PLANNER_H_ */
