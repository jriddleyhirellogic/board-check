/*
 * @file      junc_temp.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      05/15/2026
 * 
 * @brief     This module instantiates the TVS IP and the APB register for the
 *            RISC-V to read the juction temperature.
 *
 * @section changelog
 * - 05/15/2026: Steven Knyazher - Initial implementation
 * 
 */

module junc_temp #(
    parameter integer APB_DATA_WIDTH    = 32,
    parameter integer APB_ADDR_WIDTH    = 32
)(
    // APB Slave interface
    input  logic                          pclk,     // APB clock
    input  logic                          presetn,  // APB resetn
    input  logic                          penable,  // APB enable
    input  logic                          psel,     // APB periph select
    input  logic [APB_ADDR_WIDTH-1:0]     paddr,    // APB address bus
    input  logic                          pwrite,   // APB write req
    input  logic [APB_DATA_WIDTH-1:0]     pwdata,   // APB write data
    output logic [APB_DATA_WIDTH-1:0]     prdata,   // APB read data
    output logic                          pready,   // APB ready signal
    output logic                          pslverr   // APB error signal
);

//------------------------------------------------------------------------------
// Internal signals
//------------------------------------------------------------------------------
logic        tvs_valid;
logic [15:0] tvs_value;
logic [1:0]  tvs_channel;

//------------------------------------------------------------------------------
// TVS instance
//------------------------------------------------------------------------------
PF_TVS_C0 tvs_ip_inst(
    .TEMP_HIGH_CLEAR ('b1        ),
    .TEMP_LOW_CLEAR  ('b1        ),
    .ENABLE_TEMP     ('b1        ),
    .TEMP_HIGH       ( /* NC */  ),
    .TEMP_LOW        ( /* NC */  ),
    .VALID           (tvs_valid  ),
    .ACTIVE          ( /* NC */  ),
    .VALUE           (tvs_value  ),
    .CHANNEL         (tvs_channel)
);

//------------------------------------------------------------------------------
// APB instance
//------------------------------------------------------------------------------
junc_temp_apb_reg #(
    .APB_DATA_WIDTH (APB_DATA_WIDTH),
    .APB_ADDR_WIDTH (APB_ADDR_WIDTH)
) junc_temp_apb_reg_inst (
    .pclk           (pclk          ),
    .presetn        (presetn       ),
    .penable        (penable       ),
    .psel           (psel          ),
    .paddr          (paddr         ),
    .pwrite         (pwrite        ),
    .pwdata         (pwdata        ),
    .prdata         (prdata        ),
    .pready         (pready        ),
    .pslverr        (pslverr       ),
    .tvs_valid      (tvs_valid     ),
    .tvs_value      (tvs_value     ),
    .tvs_channel    (tvs_channel   )
);

endmodule
