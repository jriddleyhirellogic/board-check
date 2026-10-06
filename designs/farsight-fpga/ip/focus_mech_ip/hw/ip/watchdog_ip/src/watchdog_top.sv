/*
 * @file      watchdog_top.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      02/24/2026
 *
 * @brief     Top module of watchdog module. It encapsulates APB register
 *            module and watchdog module as a top level.
 *
 * @section changelog
 * - 02/24/2026: Steven Knyazher - Initial implementation
 *
 */

module watchdog_top #(
    parameter APB_DATA_WIDTH    = 32,
    parameter APB_ADDR_WIDTH    = 32,
    parameter CLOCK_FREQ_MHZ    = 50,
    parameter TIMER_COUNT_WIDTH = 27
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

    // Watchdog Status
    output logic                       wd_active
);

//------------------------------------------------------------------------------
// Internal signals
//------------------------------------------------------------------------------
logic                          wd_clear;
logic [TIMER_COUNT_WIDTH-1:0]  wd_timeout_val;
logic                          wd_refresh;

//------------------------------------------------------------------------------
// Instances
//------------------------------------------------------------------------------
watchdog_apb_reg #(
    .APB_DATA_WIDTH      (APB_DATA_WIDTH    ),
    .APB_ADDR_WIDTH      (APB_ADDR_WIDTH    ),
    .CLOCK_FREQ_MHZ      (CLOCK_FREQ_MHZ    ),
    .TIMER_COUNT_WIDTH   (TIMER_COUNT_WIDTH  )
) watchdog_apb_reg_inst (
    .pclk                (pclk              ),
    .presetn             (presetn           ),
    .penable             (penable           ),
    .psel                (psel              ),
    .paddr               (paddr             ),
    .pwrite              (pwrite            ),
    .pwdata              (pwdata            ),
    .prdata              (prdata            ),
    .pready              (pready            ),
    .pslverr             (pslverr           ),
    .wd_clear            (wd_clear          ),
    .wd_timeout_val      (wd_timeout_val    ),
    .wd_refresh          (wd_refresh        ),
    .wd_active           (wd_active         )
);

watchdog #(
    .TIMER_COUNT_WIDTH   (TIMER_COUNT_WIDTH )
) watchdog_inst (
    .clk                 (pclk              ),
    .rst_n               (presetn           ),
    .wd_clear            (wd_clear          ),
    .wd_timeout_val      (wd_timeout_val    ),
    .wd_refresh          (wd_refresh        ),
    .wd_active           (wd_active         )
);

endmodule
