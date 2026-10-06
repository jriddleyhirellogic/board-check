/*
 * foucs_states.h
 *
 *  Created on: Oct 17, 2025
 *      Author: iboard
 */

#ifndef _FOCUS_STATES_H_
#define _FOCUS_STATES_H_

#include "states.h"
#include "focus.h"

// Control States

State_t Initial_State( Context_t *context, Event_t *event );
State_t Idle_State( Context_t *context, Event_t *event );
State_t Zero_Coarse_State( Context_t *context, Event_t *event );
State_t Zero_Fine_State( Context_t *context, Event_t *event );
State_t Goto_Position_State( Context_t *context, Event_t *event );
State_t Test_State( Context_t *context, Event_t *event );
State_t Focus_State( Context_t *context, Event_t *event );
State_t Focus_Fault_State( Context_t *context, Event_t *event );
State_t Coarse_Focus_State( Context_t *context, Event_t *event );
State_t Fine_Focus_State( Context_t *context, Event_t *event );


#endif /* _FOCUS_STATES_H_ */
