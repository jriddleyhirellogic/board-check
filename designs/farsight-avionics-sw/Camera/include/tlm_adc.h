/*
 * tlm_adc.h
 *
 *  Created on: Mar 25, 2026
 *      Author: iboard
 */

#ifndef TLM_ADC_H_
#define TLM_ADC_H_

typedef enum
{
    CS_1,  // U89 - Schematic ref.
    CS_2,  // U90
    CS_3,  // U91
    CS_4,  // U92
    CS_5,  // U93
    CS_6   // U94
}ADC_Select_t;

typedef enum
{
    IN0,
    IN1,
    IN2,
    IN3,
    IN4,
    IN5,
    IN6,
    IN7
}Channel_Select_t;

typedef struct
{
    Channel_Select_t channel;
    ADC_Select_t adc;
}Sensor_t;

typedef struct
{
    float f_Gain;
    float f_Offset;
}TLM_Cal_t;

typedef enum
{
    TLM_1V5_ASIC_ISENSE,
    TLM_1V5_ASIC,
    TLM_10V0_SENSE,
    TLM_3V3_RH,
    TLM_1V1_IMX_ISENSE,
    TLM_28V0_EPS,
    TLM_6V0_REG,
    TLM_6V0_REG_ISENSE,
    TLM_4V0_REG_ISENSE,
    TLM_2V2_REG_ISENSE,
    TLM_1V0_FPGA_ISENSE,
    TLM_1V2_16GB_ISENSE,
    TLM_2V5_16GB_ISENSE,
    TLM_1V0A_ETH2,
    TLM_2V5A_ETH2,
    TLM_3V3_ASIC,
    TLM_3V0_REG_ISENSE,
    TLM_2V5_16GB,
    TLM_1V2_16GB,
    TLM_0V6_VTT_16GB,
    TLM_1V0_FPGA,
    TLM_2V5A_ETH1,
    TLM_1V0_ETH2,
    TLM_3V3_ETH2,
    TLM_2V2_REG,
    TLM_3V0_REG,
    TLM_4V0_REG,
    TLM_1V1_IMX,
    TLM_1V8_IMX,
    TLM_3V3_ETH1,
    TLM_1V0_ETH1,
    TLM_1V0A_ETH1,
    TLM_3V3_IMX_SNS,
    TLM_2V9_IMX_SNS,
    TLM_1V0A_FPGA,
    TLM_1V25A_FPGA,
    TLM_2V5A_FPGA,
    TLM_1V2_8GB,
    TLM_3V3_MISC,
    TLM_15V0_LVDT,
    TLM_1V8_FPGA,
    TLM_1V8_IMX_FPGA,
    TLM_3V3_B4_FPGA,
    TLM_3V3_B5_FPGA,
    TLM_0V6_VTT_8GB,
    TLM_2V5_8GB,
    TLM_2V5_8GB_ISENSE,
    TLM_1V2_8GB_ISENSE,
    NUMBER_TLM_SENSORS
}TLM_Signal_t;

/*
1V5_ASIC_ISENSE     CURRENT        IN0       CS_1
1V5_ASIC            VOLTAGE        IN1       CS_1
10V0_SENSE          VOLTAGE        IN2       CS_1
3V3_RH              VOLTAGE        IN3       CS_1
1V1_IMX_ISENSE      CURRENT        IN4       CS_1
28V0_EPS            VOLTAGE        IN5       CS_1
6V0_REG             VOLTAGE        IN6       CS_1
6V0_REG_ISENSE      CURRENT        IN7       CS_1
4V0_REG_ISENSE      CURRENT        IN0       CS_2
2V2_REG_ISENSE      CURRENT        IN1       CS_2
1V0_FPGA_ISENSE     CURRENT        IN2       CS_2
1V2_16GB_ISENSE     CURRENT        IN3       CS_2
2V5_16GB_ISENSE     CURRENT        IN4       CS_2
1V0A_ETH2           VOLTAGE        IN5       CS_2
2V5A_ETH2           VOLTAGE        IN6       CS_2
3V3_ASIC            VOLTAGE        IN7       CS_2
3V0_REG_ISENSE      CURRENT        IN0       CS_3
2V5_16GB            VOLTAGE        IN1       CS_3
1V2_16GB            VOLTAGE        IN2       CS_3
0V6_VTT_16GB        VOLTAGE        IN3       CS_3
1V0_FPGA            VOLTAGE        IN4       CS_3
2V5A_ETH1           VOLTAGE        IN5       CS_3
1V0_ETH2            VOLTAGE        IN6       CS_3
3V3_ETH2            VOLTAGE        IN7       CS_3
2V2_REG             VOLTAGE        IN0       CS_4
3V0_REG             VOLTAGE        IN1       CS_4
4V0_REG             VOLTAGE        IN2       CS_4
1V1_IMX             VOLTAGE        IN3       CS_4
1V8_IMX             VOLTAGE        IN4       CS_4
3V3_ETH1            VOLTAGE        IN5       CS_4
1V0_ETH1            VOLTAGE        IN6       CS_4
1V0A_ETH1           VOLTAGE        IN7       CS_4
3V3_IMX_SNS         VOLTAGE        IN0       CS_5
2V9_IMX_SNS         VOLTAGE        IN1       CS_5
1V0A_FPGA           VOLTAGE        IN2       CS_5
1V25A_FPGA          VOLTAGE        IN3       CS_5
2V5A_FPGA           VOLTAGE        IN4       CS_5
1V2_8GB             VOLTAGE        IN5       CS_5
3V3_MISC            VOLTAGE        IN6       CS_5
15V0_LVDT           VOLTAGE        IN7       CS_5
1V8_FPGA            VOLTAGE        IN0       CS_6
1V8_IMX_FPGA        VOLTAGE        IN1       CS_6
3V3_B4_FPGA         VOLTAGE        IN2       CS_6
3V3_B5_FPGA         VOLTAGE        IN3       CS_6
0V6_VTT_8GB         VOLTAGE        IN4       CS_6
2V5_8GB             VOLTAGE        IN5       CS_6
2V5_8GB_ISENSE      CURRENT        IN6       CS_6
1V2_8GB_ISENSE      CURRENT        IN7       CS_6

*/

void  v_Init_TLM( void );
uint32_t u32_Read_TLM(TLM_Signal_t);
uint8_t b_Is_TLM_Initialized(void);

#endif /* TLM_ADC_H_ */
