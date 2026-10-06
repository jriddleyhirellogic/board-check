/*
 * config.h
 *
 *  Created on: Oct 3, 2025
 *      Author: iboard
 */

#ifndef CONFIG_H_
#define CONFIG_H_


// Tasks initialized
#define SYSTEM_INITIALIZED              (1 << 0)
#define SERIAL_COMM_INITIALIZED         (1 << 1)
#define CONTROL_INITIALIZED             (1 << 2)
#define CAMERA_INITIALIZED              (1 << 3)
//#define ALL_INITIALIZED   (SYSTEM_INITIALIZED |        \
//                           SERIAL_COMM_INITIALIZED |   \
//                           CONTROL_INITIALIZED |       \
//                           CAMERA_INITIALIZED )

#define ALL_INITIALIZED   (SYSTEM_INITIALIZED |        \
                           SERIAL_COMM_INITIALIZED |     \
                           CONTROL_INITIALIZED  |   \
                           CAMERA_INITIALIZED )

// Task priorities
#define COMM_TASK_PRIORITY     3
#define SYSTEM_TASK_PRIORITY   2
#define CONTROL_TASK_PRIORITY  2
#define CAMERA_TASK_PRIORITY   2
// Timer task priority is 2 @TODO test relative priorities of timer and serial comm tasks

// Stack sizes (words)
#define SERIAL_COMM_STACK_SIZE_WORDS   200 //512
#define FOCUS_STACK_SIZE_WORDS         256 //800
#define SYSTEM_STACK_SIZE              200 //512
#define CAMERA_STACK_SIZE              200

#define SERIAL_BUF_SIZE                160    // Same size for receive and transmit buffers

// Interrupt bits
#define COMM_TIMER_IRQ  (1UL << 24 )
#define UART_IRQ        (1UL << 25 )
#define CAM_SPI_IRQ     (1UL << 26 )
#define CAM_TRIGGER_IRQ (1UL << 27 )
#define PPS_IRQ         (1UL << 28 )
#define UDP_IRQ         (1UL << 29 )

// Queue Lengths
#define SERIAL_COMM_QUEUE_LENGTH     3
#define CONTROL_QUEUE_LENGTH         3
#define CAMERA_QUEUE_LENGTH          3
#define SYSTEM_QUEUE_LENGTH          2

#endif /* CONFIG_H_ */
