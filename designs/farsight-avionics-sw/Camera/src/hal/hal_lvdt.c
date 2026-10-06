/*
 * lvdt.c
 *
 *  Created on: Sep 28, 2025
 *      Author: iboard
 */
#include "FreeRTOSConfig.h"
#include "FreeRTOS.h"
#include "task.h"
#include "event_groups.h"
#include "mem_map.h"
#include "config.h"
#include "misc.h"
#include "debug_gpio.h"
#include "lvdt.h"
#include "cal.h"
//#include "lvdt_cal.h"

static LVDT_Instance_t LVDT_Instance;
static LVDT_Instance_t *instance;

static int32_t i32_Low_Gain_Limit[2];
static int32_t i32_High_Gain_Limit[2];
static int32_t i32_Displacement_Offset;

static float f_Interpolate_2D( float f_x, float f_x0, float f_x1, float f_y0, float f_y1 );

static LVDT_Calibration_t *p_LVDT_Cals;

/**
 * @fn void v_Init_LVDT(void)
 * @brief  Initializes lvdt (position) sensor hardware.
 * This initializes the hardware used to read the LVDT sensor: the voltage on both the primary
 * and secondary coils are complex valued (I and Q), plus a GPIO register used to set the gain to
 * either 1 or 8.
 * Two calibration tables are initialized. One is for use when the LVDT gain setting is 1, the other
 * for when it is 8.
 *
 */
void v_Init_LVDT(void)
{
    uint8_t n_table_entries;

    instance = &LVDT_Instance;

    instance->Primary_I.apb_bus_width = GPIO_APB_32_BITS_BUS;
    instance->Primary_I.base_addr = LVDT_RO_PRI_I_BASE_ADDR;

    instance->Primary_Q.apb_bus_width = GPIO_APB_32_BITS_BUS;
    instance->Primary_Q.base_addr = LVDT_RO_PRI_Q_BASE_ADDR;

    instance->Secondary_I.apb_bus_width = GPIO_APB_32_BITS_BUS;
    instance->Secondary_I.base_addr = LVDT_RO_SEC_I_BASE_ADDR;

    instance->Secondary_Q.apb_bus_width = GPIO_APB_32_BITS_BUS;
    instance->Secondary_Q.base_addr = LVDT_RO_SEC_Q_BASE_ADDR;

    instance->Gain.apb_bus_width = GPIO_APB_32_BITS_BUS;
    instance->Gain.base_addr = LVDT_GAIN_BASE_ADDR;

    p_LVDT_Cals = p_Get_LVDT_Cal();

    // Establish limits of cal tables to determine which one to use

    // Low gain
    n_table_entries = p_LVDT_Cals->u32_Low_Gain_Points;
    i32_Low_Gain_Limit[0] = p_LVDT_Cals->Cal_G1[n_table_entries-1].i32_Projection; // Smallest value of projection
    i32_Low_Gain_Limit[1] = p_LVDT_Cals->Cal_G1[0].i32_Projection;

    // High gain
    n_table_entries = p_LVDT_Cals->u32_High_Gain_Points;
    i32_High_Gain_Limit[0] = p_LVDT_Cals->Cal_G8[n_table_entries-1].i32_Projection;     // Smallest value of projection
    i32_High_Gain_Limit[1] = p_LVDT_Cals->Cal_G8[0].i32_Projection;

}

/**
 * @fn void v_Set_LVDT_Gain(LVDT_Gain_Sel_t)
 * @brief Selects whether x1 or x8 gain is used with LVDT sensor
 *
 * @param eGain 0 - x1,  1 - x8
 */
void v_Set_LVDT_Gain(LVDT_Gain_Sel_t eGain)
{
    GPIO_set_output( &instance->Gain, 0, (uint8_t)eGain );
}

/**
 * @fn LVDT_Gain_Sel_t e_Get_LVDT_Gain(void)
 * @brief Retrieves current gain setting for LVDT sensor
 *
 * @return Current gain setting - 0 (x1), 1 (x8)
 */
LVDT_Gain_Sel_t e_Get_LVDT_Gain( void )
{
    return (GPIO_get_outputs( &instance->Gain ) & 1) ? LVDT_GAIN_8 : LVDT_GAIN_1;
}

/**
 * @fn void v_Set_Displacement_Offset(int32_t)
 * @brief Sets the LVDT offset in microns applied to position readings following table lookup and interpolation.
 * This is used because the mechanical zero of the focus mechanism will not coincide perfecty with the
 * electrical zero of the LVDT. Measured and true position are related as:
 * True Position = Measured Position + Offset.
 *
 * @param i32_Offset
 */
void v_Set_Displacement_Offset( int32_t i32_Offset )
{
    i32_Displacement_Offset = i32_Offset;
}

/**
 * @fn void V_Get_LVDT_Snapshot(LVDT_Sample_t*)
 * @brief Takes a complex valued sample of the primary and secondary voltages on the LVDT sensor.
 *
 * @param p_LVDT_Sample Pointer to LVDT sample struct to fill in.
 */
void V_Get_LVDT_Snapshot( LVDT_Sample_t *p_LVDT_Sample )
{
    p_LVDT_Sample->i32_I_Primary = GPIO_get_inputs( &instance->Primary_I );
    p_LVDT_Sample->i32_Q_Primary = GPIO_get_inputs( &instance->Primary_Q );

    p_LVDT_Sample->i32_I_Secondary = GPIO_get_inputs( &instance->Secondary_I );
    p_LVDT_Sample->i32_Q_Secondary = GPIO_get_inputs( &instance->Secondary_Q );

}

/**
 * @fn int32_t i32_Get_Projection(LVDT_Sample_t*)
 * @brief Calculates the projection of the secondary response onto the primary excitation
 * If the primary and secondary complex valued voltages are represented as vectors, this is
 * the projection of the secondary onto the primary, normalized by the amplitude of the primary.
 * This can be seen as a complex valued loss between the primary and secondary. Mathematically, this
 * is:
 * Projection = (S dot P)/ norm(P)^2
 * where P = primary (I,Q) pair
 *       S = secondary (I,Q) pair
 *       dot - vector dot product
 *       norm - vector norm (length)
 *
 * @param p_LVDT_Sample The (I,Q) values for both the primary and the secondary coils of the LVDT
 * @return  The normalized projection of the secondary response onto the primary excitation
 */
int32_t i32_Get_Projection( LVDT_Sample_t *p_LVDT_Sample )
{
    // This calculates the projection of the secondary response onto the primary viewing them as 2D vectors
    // formed by (I,Q)
    // The projection is scaled to increase precision.

    int64_t numerator = (int64_t)p_LVDT_Sample->i32_I_Primary * (int64_t)p_LVDT_Sample->i32_I_Secondary +
                        (int64_t)p_LVDT_Sample->i32_Q_Primary * (int64_t)p_LVDT_Sample->i32_Q_Secondary;

    int64_t denom     = ((int64_t)p_LVDT_Sample->i32_I_Primary  * (int64_t)p_LVDT_Sample->i32_I_Primary  ) +
                        ((int64_t)p_LVDT_Sample->i32_Q_Primary  * (int64_t)p_LVDT_Sample->i32_Q_Primary  );

    // Calculates the ratio of the length of the projection of S along P to the norm of P
    // r = (S dot P)/ norm(P)^2

    int64_t i64_Projection = (numerator * LVDT_SCALING_FACTOR  ) / denom;

    return (int32_t)i64_Projection;
}

/**
 * @fn float f_Get_Displacement(int32_t)
 * @brief Uses the projection of secondary response onto primary to calculate a displacement in microns
 * @note The appropriate interpolation table is selected based on the gain setting in use.
 *
 * @param i32_Projection
 * @return Displacement in microns.
 */
float f_Get_Displacement( int32_t i32_Projection )
{
    Cal_Value_t *table;
    uint8_t u8_Table_Size;
    LVDT_Gain_Sel_t e_Gain_Sel;

    /// choose table based on minimums for range
    e_Gain_Sel = e_Get_LVDT_Gain();

    switch( e_Gain_Sel )
    {
    case LVDT_GAIN_1:

        u8_Table_Size = p_LVDT_Cals->u32_Low_Gain_Points;
        table = p_LVDT_Cals->Cal_G1;
        break;

    case LVDT_GAIN_8:
        u8_Table_Size = p_LVDT_Cals->u32_High_Gain_Points;
        table = p_LVDT_Cals->Cal_G8;
        break;

    default:
        break;
    }

    uint8_t u8_n;
    float f_Displacement;

    /// Check first to see if it is out of range wrt to table limits
    if( i32_Projection < table[u8_Table_Size-1].i32_Projection )
        return -999999.0f;

    if( i32_Projection > table[0].i32_Projection )
        return 999999.0f;

    /// Find the two points bracketing the projection value, will be in interval (u8_n, u8_n+1)
    for( u8_n = 0; u8_n < (u8_Table_Size - 1); u8_n++ )
    {
        if( i32_Projection >  table[u8_n+1].i32_Projection )
            break;
    }

    f_Displacement = f_Interpolate_2D( (float) i32_Projection,
                                       (float)table[u8_n].i32_Projection,
                                       (float)table[u8_n+1].i32_Projection,
                                       table[u8_n].f_Displacement,
                                       table[u8_n+1].f_Displacement );



    return f_Displacement;
}

/**
 * @fn float f_Interpolate_2D(float, float, float, float, float)
 * @brief 2 Dimensional Lagrangian interpolation
 * @param x  Value of x between x0 and x1 where y is to be evaluated
 * @param x0 Lower bound of interval containing x
 * @param x1 Upper bound of interval containing x
 * @param y0 Value of y at lower bound
 * @param y1 Value of y at upper bound
 * @return
 */
static float f_Interpolate_2D( float x, float x0, float x1, float y0, float y1 )
{
    float  y = (x - x0) * y1 + (x1 - x) * y0;
    y /= (x1 - x0 );

    return y;
}

/**
 * @fn int32_t i32_Get_Position(void)
 * @brief Higher level function to take snapshot of LVDT response and derive a position in microns.
 * @return Position in microns of LVDT.
 */
int32_t i32_Get_Position(void)
{
    LVDT_Sample_t LVDT_Sample;
    int32_t i32_Projection;
    int32_t  i32_Displacement_microns;

    V_Get_LVDT_Snapshot( &LVDT_Sample );
    i32_Projection = i32_Get_Projection( &LVDT_Sample );

    ///Applying rounding
    i32_Displacement_microns  = (int32_t)(f_Get_Displacement( i32_Projection ) + 0.5f);

    return POS_SGN_CONVENTION * i32_Displacement_microns;
}
