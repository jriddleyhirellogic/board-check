/*
 * @file      cam_fault_detector_top.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      04/24/2026
 *
 * @brief     Top module of the camera fault detector module. It encapsulates
 *            the APB register module and fault detector module as a top level.
 *
 * @section changelog
 * - 04/24/2026: Steven Knyazher - Initial implementation
 *
 */

module cam_fault_detector_top #(
    parameter APB_DATA_WIDTH = 32,
    parameter APB_ADDR_WIDTH = 32,
    parameter CLOCK_FREQ_MHZ = 50,
    parameter TIMEOUT_US     = 1000
)(
    // APB Slave interface
    input  logic                       pclk,     // APB clock
    input  logic                       presetn,  // APB resetn
    input  logic                       penable,  // APB enable
    input  logic                       psel,     // APB periph select
    input  logic [APB_ADDR_WIDTH-1:0]  paddr,    // APB address bus
    input  logic                       pwrite,   // APB write req
    input  logic [APB_DATA_WIDTH-1:0]  pwdata,   // APB write data
    output logic [APB_DATA_WIDTH-1:0]  prdata,   // APB read data
    output logic                       pready,   // APB ready signal
    output logic                       pslverr,  // APB error signal

    // Clock and Reset
    input  logic                       xtrig_clk,
    input  logic                       xtrig_rst_n,

    // Camera
    input  logic                       xtrig,
    input  logic                       frame_valid,
    input  logic                       capture_start,
    input  logic                       capture_finish,
    input  logic                       cam_pwr_status
);

//------------------------------------------------------------------------------
// Internal signals
//------------------------------------------------------------------------------
logic fault;
logic fault_clear;

//------------------------------------------------------------------------------
// Instances
//------------------------------------------------------------------------------
cam_fault_detector_apb_reg #(
    .APB_DATA_WIDTH (APB_DATA_WIDTH),
    .APB_ADDR_WIDTH (APB_ADDR_WIDTH)
) cam_fault_detector_apb_reg_inst (
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
    .fault          (fault         ),
    .fault_clear    (fault_clear   )
);

cam_fault_detector #(
    .CLOCK_FREQ_MHZ (CLOCK_FREQ_MHZ),
    .TIMEOUT_US     (TIMEOUT_US)
) cam_fault_detector_inst (
    .clk            (xtrig_clk     ),
    .rst_n          (xtrig_rst_n   ),
    .xtrig          (xtrig         ),
    .frame_valid    (frame_valid   ),
    .capture_start  (capture_start ),
    .capture_finish (capture_finish),
    .cam_pwr_status (cam_pwr_status),
    .fault          (fault         ),
    .fault_clear    (fault_clear   )
);

endmodule
