/*
 * @file      cam_trig_top.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      11/17/2025
 *
 * @brief     Top module of IMX trigger module. It encapsulates APB register
 *            module and xtrig module as a top level.
 *
 * @section changelog
 * - 11/17/2025: Saba Janamian - Initial implementation
 * - 08/18/2026: Steven Knyazher - xtrig_low_time is now a 28-bit clock cycle
 *                                 count (20 ns per count at 50 MHz) instead of
 *                                 a 22-bit microsecond value, so no conversion
 *                                 arithmetic sits in front of the counters
 *
 */

module cam_trig_top #(
    parameter APB_DATA_WIDTH = 32,
    parameter APB_ADDR_WIDTH = 32,
    parameter CLOCK_FREQ_MHZ = 50
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

    // Status
    output logic                       start,
    output logic                       finish,
    output logic                       xtrig_int,

    // Enable
    input logic                        en,

    // RTC
    input logic [31:0]                 rtc_sec,
    input logic [31:0]                 rtc_nsec,

    // LVDS
    input                              lvds_start,

    // XTRIG
    output logic                       xtrig,

    // Trig Info
    output logic [1:0]                 xtrig_src_sel,
    output logic [23:0]                frame_capture_time,
    output logic [9:0]                 frame_capture_amount
);

//------------------------------------------------------------------------------
// Internal signals
//------------------------------------------------------------------------------
logic        manual_start;
logic        scheduler_start;
logic        scheduler_start_d;
logic [2:0]  lvds_start_sync;
logic [31:0] scheduler_time_sec;
logic [31:0] scheduler_time_nsec;
logic        ctrl_valid;
logic        ctrl_ready;
logic        busy;
logic        irq_clear;
logic [27:0] xtrig_low_time;

//------------------------------------------------------------------------------
// Instances
//------------------------------------------------------------------------------
cam_trig_apb_reg #(
    .APB_DATA_WIDTH       (APB_DATA_WIDTH      ),
    .APB_ADDR_WIDTH       (APB_ADDR_WIDTH      )
) cam_trig_apb_reg_inst (
    .pclk                 (pclk                ),
    .presetn              (presetn             ),
    .penable              (penable             ),
    .psel                 (psel                ),
    .paddr                (paddr               ),
    .pwrite               (pwrite              ),
    .pwdata               (pwdata              ),
    .prdata               (prdata              ),
    .pready               (pready              ),
    .pslverr              (pslverr             ),
    .xtrig_low_time       (xtrig_low_time      ),
    .frame_capture_time   (frame_capture_time  ),
    .frame_capture_amount (frame_capture_amount),
    .start                (manual_start        ),
    .xtrig_src_sel        (xtrig_src_sel       ),
    .scheduler_time_sec   (scheduler_time_sec  ),
    .scheduler_time_nsec  (scheduler_time_nsec ),
    .ctrl_valid           (ctrl_valid          ),
    .ctrl_ready           (ctrl_ready          ),
    .finish               (finish              ),
    .busy                 (busy                ),
    .irq_status           (xtrig_int           ),
    .irq_clear            (irq_clear           )
);

cam_trig #(
    .CLOCK_FREQ_MHZ       (CLOCK_FREQ_MHZ      )
) cam_trig_inst (
    .clk                  (xtrig_clk           ),
    .rst_n                (xtrig_rst_n         ),
    .xtrig_low_time       (xtrig_low_time      ),
    .frame_capture_time   (frame_capture_time  ),
    .frame_capture_amount (frame_capture_amount),
    .start                (start               ),
    .ctrl_valid           (ctrl_valid          ),
    .ctrl_ready           (ctrl_ready          ),
    .finish               (finish              ),
    .en                   (en                  ),
    .xtrig                (xtrig               )
);

//------------------------------------------------------------------------------
// Scheduler & LVDS
//------------------------------------------------------------------------------
always_ff @(posedge pclk, negedge presetn) begin
    if (~presetn) begin
        scheduler_start   <= 'b0;
        scheduler_start_d <= 'b0;
        lvds_start_sync   <= 3'b0;
    end else begin
        lvds_start_sync <= {lvds_start_sync[1:0], lvds_start};

        if (xtrig_src_sel == 2'b01) begin
            if ((rtc_sec > scheduler_time_sec) ||
                ((rtc_sec == scheduler_time_sec) && (rtc_nsec >= scheduler_time_nsec))) begin
                scheduler_start <= 'b1;
            end else begin
                scheduler_start <= 'b0;
            end
            scheduler_start_d <= scheduler_start;
        end else begin
            scheduler_start   <= 'b0;
            scheduler_start_d <= 'b0;
        end
    end
end

always_comb begin
    if (xtrig_src_sel == 2'b00) begin
        start = manual_start;
    end else if (xtrig_src_sel == 2'b01) begin
        start = scheduler_start && ~scheduler_start_d;
    end else if (xtrig_src_sel == 2'b10) begin
        start = lvds_start_sync[1] && ~lvds_start_sync[2];
    end else begin
        start = 'b0;
    end
end

// busy: high from start until finish
// xtrig_int: sticky interrupt, set on start and on finish, held until the
//            firmware acknowledges it via a write-1-to-clear (irq_clear).
//            A set event always takes priority over a simultaneous clear so
//            that a start/finish coinciding with an acknowledge is not lost.
always_ff @(posedge pclk, negedge presetn) begin
    if (~presetn) begin
        busy      <= 'b0;
        xtrig_int <= 'b0;
    end else begin
        // busy tracking
        if (start && ~busy) begin
            busy <= 'b1;
        end else if (finish && busy) begin
            busy <= 'b0;
        end

        // sticky interrupt latch
        if ((start && ~busy) || (finish && busy)) begin
            xtrig_int <= 'b1;
        end else if (irq_clear) begin
            xtrig_int <= 'b0;
        end
    end
end

endmodule
