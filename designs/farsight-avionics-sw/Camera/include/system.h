/*
 * system.h
 *
 *  Created on: Jan 28, 2026
 *      Author: iboard
 */

#ifndef SYSTEM_H_
#define SYSTEM_H_

#include "events.h"

void v_Post_System_Event( Event_t *event );
void v_Post_System_Event_ISR( Event_t *event );

#endif /* SYSTEM_H_ */
