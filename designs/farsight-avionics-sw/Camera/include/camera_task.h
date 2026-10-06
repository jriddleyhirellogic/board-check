/*
 * camera.h
 *
 *  Created on: Nov 25, 2025
 *      Author: iboard
 */

#ifndef _CAMERA_H_
#define _CAMERA_H_

#include "FreeRTOSConfig.h"
#include "FreeRTOS.h"
#include "task.h"
#include "event_groups.h"
#include "queue.h"
#include "timers.h"

#include "events.h"

void v_Camera_Task(void *pvParameters);
void v_Post_Camera_Event( Event_t *event );
void v_Post_Camera_Event_ISR( Event_t *event );
void v_Start_Camera_Timer( TickType_t ticks);
void v_Stop_Camera_Timer(void);

#endif /* CAMERA_H_ */
