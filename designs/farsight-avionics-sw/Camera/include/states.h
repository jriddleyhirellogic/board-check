/*
 * states.h
 *
 *  Created on: Oct 17, 2025
 *      Author: iboard
 */

#ifndef STATES_H_
#define STATES_H_
#include "events.h"
#include "pid.h"

typedef void *State_t;

typedef struct
{
    State_t current_state;
    State_t saved_state;     //To facilitate return to a remembered state
    void *param;             //For the rare instances where something needs to be saved across state transitions
    void *cal;
}Context_t;

typedef void *(*State_Handler_t)( Context_t*, Event_t * );

void v_Update_Focus_State( Context_t *, Event_t * );
void v_Init_Focus_State_Machine( Context_t *context, State_t initial_state );

#endif /* STATES_H_ */
