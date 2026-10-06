/*
 * camer_states.h
 *
 *  Created on: Dec 8, 2025
 *      Author: iboard
 */

#ifndef CAMERA_STATES_H_
#define CAMERA_STATES_H_

#include "errors.h"
#include "camera.h"
#include "states.h"

#define CAMERA_LP_STATE         (1 << 0)
#define CAMERA_IDLE_STATE       (1 << 1)
#define CAMERA_ARMED_STATE      (1 << 2)
#define CAMERA_BUSY_STATE       (1 << 3)
#define CAMERA_FAULT_STATE      (1 << 4)
#define CAMERA_TRANSFER_STATE   (1 << 5)

#define ALL_CAMERA_STATES ( CAMERA_LP_STATE |      \
                            CAMERA_IDLE_STATE |    \
                            CAMERA_ARMED_STATE |   \
                            CAMERA_BUSY_STATE  |   \
                            CAMERA_FAULT_STATE |   \
                            CAMERA_TRANSFER_STATE  )

typedef struct
{
    State_t current_state;
    State_t saved_state;     //To facilitate return to a remembered state
    void *param;             //For the rare instances where something needs to be saved across state transitions
    Camera_Instance_t *instance;
    uint8_t  eState;
}Camera_Context_t;

// Camera States
State_t Camera_Low_Power_State( Camera_Context_t *context, Event_t *event );
State_t Camera_Idle_State( Camera_Context_t *context, Event_t *event );
State_t Camera_Armed_State( Camera_Context_t *context, Event_t *event );
State_t Camera_Busy_State( Camera_Context_t *context, Event_t *event );
State_t Camera_Fault_State( Camera_Context_t *context, Event_t *event );
State_t Camera_Transfer_State( Camera_Context_t *context, Event_t *event );

typedef void *(*Camera_State_Handler_t)( Camera_Context_t*, Event_t * );

void v_Update_Camera_State( Camera_Context_t *, Event_t *p_event );
void v_Init_Camera_State_Machine( Camera_Context_t *, State_t initial_state );
Error_Code_t Get_Camera_State(uint8_t *pu8_State);

#endif /* CAMERA_STATES_H_ */
