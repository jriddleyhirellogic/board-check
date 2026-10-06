/*
 * tlm_adc.c
 *
 *  Created on: Mar 25, 2026
 *      Author: iboard
 */

#include <assert.h>
#include "core_spi.h"
#include "mem_map.h"

#include "tlm_adc.h"
#include "cal.h"

// Voltage (mV) = Vref * raw_count / 2^12 + offset

//static const Sensor_t Sensor[NUMBER_TLM_SENSORS] =
//{
//    /*1V5_ASIC_ISENSE*/  {IN0, CS_1},
//    /*1V5_ASIC */        {IN1, CS_1},
//    /*10V0_SENSE*/       {IN2, CS_1},
//    /*3V3_RH*/           {IN3, CS_1},
//    /*1V1_IMX_ISENSE*/   {IN4, CS_1},
//    /*28V0_EPS*/         {IN5, CS_1},
//    /*6V0_REG*/          {IN6, CS_1},
//    /*6V0_REG_ISENSE*/   {IN7, CS_1},
//    /*4V0_REG_ISENSE*/   {IN0, CS_2},
//    /*2V2_REG_ISENSE*/   {IN1, CS_2},
//    /*1V0_FPGA_ISENSE*/  {IN2, CS_2},
//    /*1V2_16GB_ISENSE*/  {IN3, CS_2},
//    /*2V5_16GB_ISENSE*/  {IN4, CS_2},
//    /*1V0A_ETH2*/        {IN5, CS_2},
//    /*2V5A_ETH2*/        {IN6, CS_2},
//    /*3V3_ASIC*/         {IN7, CS_2},
//    /*3V0_REG_ISENSE*/   {IN0, CS_3},
//    /*2V5_16GB*/         {IN1, CS_3},
//    /*1V2_16GB*/         {IN2, CS_3},
//    /*0V6_VTT_16GB*/     {IN3, CS_3},
//    /*1V0_FPGA*/         {IN4, CS_3},
//    /*2V5A_ETH1*/        {IN5, CS_3},
//    /*1V0_ETH2*/         {IN6, CS_3},
//    /*3V3_ETH2*/         {IN7, CS_3},
//    /*2V2_REG*/          {IN0, CS_4},
//    /*3V0_REG*/          {IN1, CS_4},
//    /*4V0_REG*/          {IN2, CS_4},
//    /*1V1_IMX*/          {IN3, CS_4},
//    /*1V8_IMX*/          {IN4, CS_4},
//    /*3V3_ETH1*/         {IN5, CS_4},
//    /*1V0_ETH1*/         {IN6, CS_4},
//    /*1V0A_ETH1*/        {IN7, CS_4},
//    /*3V3_IMX_SNS*/      {IN0, CS_5},
//    /*2V9_IMX_SNS*/      {IN1, CS_5},
//    /*1V0A_FPGA*/        {IN2, CS_5},
//    /*1V25A_FPGA*/       {IN3, CS_5},
//    /*2V5A_FPGA*/        {IN4, CS_5},
//    /*1V2_8GB*/          {IN5, CS_5},
//    /*3V3_MISC*/         {IN6, CS_5},
//    /*15V0_LVDT*/        {IN7, CS_5},
//    /*1V8_FPGA*/         {IN0, CS_6},
//    /*1V8_IMX_FPGA*/     {IN1, CS_6},
//    /*3V3_B4_FPGA*/      {IN2, CS_6},
//    /*3V3_B5_FPGA*/      {IN3, CS_6},
//    /*0V6_VTT_8GB*/      {IN4, CS_6},
//    /*2V5_8GB*/          {IN5, CS_6},
//    /*2V5_8GB_ISENSE*/   {IN6, CS_6},
//    /*1V2_8GB_ISENSE*/   {IN7, CS_6}
//};

static spi_instance_t tlm_spi;
static uint8_t b_TLM_Initialized;

static TLM_Cal_t *p_TLM_Cal;

void  v_Init_TLM()
{
    SPI_init( &tlm_spi, TLM_SPI_BASE_ADDR, 16 );
    SPI_configure_master_mode( &tlm_spi );
    p_TLM_Cal = p_Get_TLM_Cals();
    assert(p_TLM_Cal != (TLM_Cal_t *)0);
    b_TLM_Initialized = 1;
}

uint8_t b_Is_TLM_Initialized(void)
{
    return b_TLM_Initialized;
}

uint32_t u32_Read_TLM( TLM_Signal_t e_Signal )
{
    uint32_t u32_Raw_Val;
    uint32_t u32_Scaled_Value;
    float f_Gain, f_Offset;
    uint8_t u8_N_TLM_Sensor;

    uint8_t u8_Rx_Buffer[3];

//    uint8_t u8_In = Sensor[e_Signal].channel;
//    uint8_t u8_CS = Sensor[e_Signal].adc;

    uint8_t u8_In = (uint8_t)e_Signal & 0x7;
    uint8_t u8_CS = (uint8_t)e_Signal >> 3;

    // ADC control register for selecting input
    uint8_t u8_Control_Reg = u8_In << 3;

    // Read the selected channel 3 times and keep the last sample to give cap time
    // to charge up.
    for( u8_N_TLM_Sensor = 0; u8_N_TLM_Sensor < 3; u8_N_TLM_Sensor++ )
    {
        SPI_set_slave_select( &tlm_spi, (spi_slave_t)u8_CS );
        SPI_transfer_block( &tlm_spi, &u8_Control_Reg, 1, u8_Rx_Buffer, 2 );
        SPI_clear_slave_select( &tlm_spi, (spi_slave_t)u8_CS );
    }

    u32_Raw_Val = (uint32_t)u8_Rx_Buffer[1] * 256 + (uint32_t)u8_Rx_Buffer[0];

    f_Gain = p_TLM_Cal[e_Signal].f_Gain;
    f_Offset = p_TLM_Cal[e_Signal].f_Offset;

    u32_Scaled_Value = (uint32_t)((float)u32_Raw_Val * f_Gain + f_Offset + 0.5f);

    return u32_Scaled_Value;
}

