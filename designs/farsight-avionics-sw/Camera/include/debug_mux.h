/*
 * debug_mux.h
 *
 *  Created on: Feb 3, 2026
 *      Author: iboard
 */

#ifndef DEBUG_MUX_H_
#define DEBUG_MUX_H_

typedef enum
{
    DEFAULT_DEBUG = 0,
    USER_DEBUG = 1,
    STEPPER_DEBUG = 2,
    QSPI_DEBUG = 4,
    TLM_DEBUG = 8
}Debug_Mux_Setting_t;

/*      QSPI_DEBUG
 *      dbg_gpio0  = nvm_qspi_dbg_clk;
        dbg_gpio1  = nvm_qspi_dbg_din0;
        dbg_gpio2  = nvm_qspi_dbg_din1;
        dbg_gpio3  = nvm_qspi_dbg_din2;
        dbg_gpio4  = nvm_qspi_dbg_din3;
        dbg_gpio5  = nvm_qspi_dbg_dout0;
        dbg_gpio6  = nvm_qspi_dbg_dout1;
        dbg_gpio7  = 1'b0;
        dbg_gpio8  = 1'b0;
        dbg_gpio9  = nvm_qspi_dbg_doen0;
        dbg_gpio10 = nvm_qspi_dbg_doen1;
        dbg_gpio11 = nvm_qspi_dbg_cs_n;
        dbg_gpio12 = 1'b0;
 */

/*
 *      dbg_gpio0  = tlm_spi_dbg_sclk;
        dbg_gpio1  = tlm_spi_dbg_cs1_n;
        dbg_gpio2  = tlm_spi_dbg_cs2_n;
        dbg_gpio3  = tlm_spi_dbg_cs3_n;
        dbg_gpio4  = tlm_spi_dbg_cs4_n;
        dbg_gpio5  = tlm_spi_dbg_cs5_n;
        dbg_gpio6  = tlm_spi_dbg_cs6_n;
        dbg_gpio7  = tlm_spi_dbg_mosi;
        dbg_gpio8  = tlm_spi_dbg_miso;
        dbg_gpio9  = 1'b0;
        dbg_gpio10 = 1'b0;
        dbg_gpio11 = 1'b0;
        dbg_gpio12 = 1'b0;
 */

/*      STEPPER_DEBUG
 *      dbg_gpio0  = pri_stp_motor_vref_pwm;
        dbg_gpio1  = pri_stp_motor_step;
        dbg_gpio2  = pri_stp_motor_dir;
        dbg_gpio3  = pri_stp_motor_en;
        dbg_gpio4  = pri_stp_motor_fault_n;

        dbg_gpio5  = sec_stp_motor_vref_pwm;
        dbg_gpio6  = sec_stp_motor_step;
        dbg_gpio7  = sec_stp_motor_dir;
        dbg_gpio8  = sec_stp_motor_en;
        dbg_gpio9  = sec_stp_motor_fault_n;

        dbg_gpio10 = 1'b0;
        dbg_gpio11 = 1'b0;
        dbg_gpio12 = 1'b0;
        */


void v_Init_Debug_Mux(void);
void v_Set_Debug_Mux(Debug_Mux_Setting_t eSetting );
void v_Set_Heartbeat_LED( uint8_t u8_On );

#endif /* DEBUG_MUX_H_ */
