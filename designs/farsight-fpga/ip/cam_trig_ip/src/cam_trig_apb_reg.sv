/*
 * @file      cam_trig_apb_reg.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      11/07/2025
 *
 * @brief     Camera Trigger APB Register IP. This module receives controls from the APB bus.
 *
 * @section changelog
 * - 11/07/2025: Steven Knyazher - Initial implementation
 * - 08/18/2026: Steven Knyazher - xtrig_low_time is now a 28-bit clock cycle
 *                                 count (20 ns per count at 50 MHz) instead of
 *                                 a 22-bit microsecond value, so no conversion
 *                                 arithmetic sits in front of the counters
 *
 */

module cam_trig_apb_reg #(
    parameter APB_DATA_WIDTH = 32,
    parameter APB_ADDR_WIDTH = 32
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

    // Control
    output logic [27:0]                xtrig_low_time,      // clock cycles (20 ns each at 50 MHz)
    output logic [23:0]                frame_capture_time,  // microseconds
    output logic [9:0]                 frame_capture_amount,
    output logic                       start,
    output logic [1:0]                 xtrig_src_sel,
    output logic [31:0]                scheduler_time_sec,
    output logic [31:0]                scheduler_time_nsec,
    output logic                       ctrl_valid,
    input  logic                       ctrl_ready,

    // Status
    input  logic                       finish,
    input  logic                       busy,

    // Interrupt
    input  logic                       irq_status, // Latched xtrig_int level
    output logic                       irq_clear   // W1C pulse to clear the latch
);

//------------------------------------------------------------------------------
// Register address definitions
//------------------------------------------------------------------------------
localparam integer ADDR_XTRIG_LOW_TIME       = 'h00;
localparam integer ADDR_FRAME_CAPTURE_TIME   = 'h01;
localparam integer ADDR_FRAME_CAPTURE_AMOUNT = 'h02;
localparam integer ADDR_START                = 'h03;
localparam integer ADDR_XTRIG_SRC_SEL        = 'h04;
localparam integer ADDR_SCHEDULER_TIME_SEC   = 'h05;
localparam integer ADDR_SCHEDULER_TIME_MSEC  = 'h06;
localparam integer ADDR_BUSY                 = 'h07;
localparam integer ADDR_IRQ_STATUS           = 'h08; // R: latched IRQ, W1C: clear

localparam integer NUM_REGS  = 16; // Can only be 8, 16, 32
localparam integer REG_WIDTH = $clog2(NUM_REGS);

//------------------------------------------------------------------------------
// Register space
//------------------------------------------------------------------------------
logic [APB_DATA_WIDTH-1:0] mem[NUM_REGS];

//------------------------------------------------------------------------------
// APB write and read register logic
//------------------------------------------------------------------------------
always_ff @(posedge pclk, negedge presetn) begin
    if (~presetn) begin
        prdata        <= 'b0;
        pready        <= 'b0;
        pslverr       <= 'b0;
        irq_clear     <= 'b0;
        mem           <= '{default: 1'b0};
    end else begin
        pslverr   <= 'b0; // Not used
        irq_clear <= 'b0; // Default: deassert clear pulse every cycle

        if (finish) begin
            mem[ADDR_START] <= 'b0;
        end

        // APB Write operation
        if (psel && penable && pwrite && paddr[1:0] == 'b0) begin
            prdata  <= 'b0;
            pready  <= 'b1;  // Indicate done

            case (paddr[6:2])
                ADDR_XTRIG_LOW_TIME: begin
                    mem[ADDR_XTRIG_LOW_TIME] <= {4'b0, pwdata[27:0]};
                end

                ADDR_FRAME_CAPTURE_TIME: begin
                    mem[ADDR_FRAME_CAPTURE_TIME] <= {8'b0, pwdata[23:0]};
                end

                ADDR_FRAME_CAPTURE_AMOUNT: begin
                    mem[ADDR_FRAME_CAPTURE_AMOUNT] <= {22'b0, pwdata[9:0]};
                end

                ADDR_START: begin
                    mem[ADDR_START] <= {31'b0, pwdata[0]};
                end

                ADDR_XTRIG_SRC_SEL: begin
                    mem[ADDR_XTRIG_SRC_SEL] <= {30'b0, pwdata[1:0]};
                end

                ADDR_SCHEDULER_TIME_SEC: begin
                    mem[ADDR_SCHEDULER_TIME_SEC] <= pwdata;
                end

                ADDR_SCHEDULER_TIME_MSEC: begin
                    mem[ADDR_SCHEDULER_TIME_MSEC] <= {22'b0, pwdata[9:0]};
                end

                ADDR_IRQ_STATUS: begin
                    // Write-1-to-clear: pulse irq_clear to clear the latch.
                    // Nothing is stored in mem for this register.
                    irq_clear <= pwdata[0];
                end

                default: begin
                    pslverr <= 'b0;
                end
            endcase

        // APB READ operation
        end else if (psel && penable && !pwrite && paddr[1:0] == 'b0) begin
            pready <= 'b1; // Indicate done

            case (paddr[6:2])
                ADDR_XTRIG_LOW_TIME: begin
                    prdata <= {4'b0, mem[ADDR_XTRIG_LOW_TIME][27:0]};
                end

                ADDR_FRAME_CAPTURE_TIME: begin
                    prdata <= {8'b0, mem[ADDR_FRAME_CAPTURE_TIME][23:0]};
                end

                ADDR_FRAME_CAPTURE_AMOUNT: begin
                    prdata <= {22'b0, mem[ADDR_FRAME_CAPTURE_AMOUNT][9:0]};
                end

                ADDR_START: begin
                    prdata <= {31'b0, mem[ADDR_START][0]};
                end

                ADDR_XTRIG_SRC_SEL: begin
                    prdata <= {30'b0, mem[ADDR_XTRIG_SRC_SEL][1:0]};
                end

                ADDR_SCHEDULER_TIME_SEC: begin
                    prdata <= mem[ADDR_SCHEDULER_TIME_SEC];
                end

                ADDR_SCHEDULER_TIME_MSEC: begin
                    prdata <= {22'b0, mem[ADDR_SCHEDULER_TIME_MSEC][9:0]};
                end

                ADDR_BUSY: begin
                    prdata <= {31'b0, busy};
                end

                ADDR_IRQ_STATUS: begin
                    prdata <= {31'b0, irq_status};
                end

                default: begin
                    pslverr <= 'b0;
                end
            endcase

        end else begin
            pready  <= 'b0;
            prdata  <= 'b0;
            pslverr <= 'b0;
        end
    end
end

//------------------------------------------------------------------------------
// Output controller
//------------------------------------------------------------------------------
always_ff @(posedge pclk, negedge presetn) begin
    if (~presetn) begin
        xtrig_low_time       <= 'b0;
        frame_capture_time   <= 'b0;
        frame_capture_amount <= 'b0;
        start                <= 'b0;
        xtrig_src_sel        <= 'b0;
        scheduler_time_sec   <= 'b0;
        scheduler_time_nsec  <= 'b0;
        ctrl_valid           <= 'b0;
    end else begin
        // Port updates based on reg values
        if (ctrl_ready) begin
            xtrig_low_time       <= mem[ADDR_XTRIG_LOW_TIME][27:0];
            frame_capture_time   <= mem[ADDR_FRAME_CAPTURE_TIME][23:0];
            frame_capture_amount <= mem[ADDR_FRAME_CAPTURE_AMOUNT][9:0];
            start                <= mem[ADDR_START][0];
            xtrig_src_sel        <= mem[ADDR_XTRIG_SRC_SEL][1:0];
            scheduler_time_sec   <= mem[ADDR_SCHEDULER_TIME_SEC];
            scheduler_time_nsec  <= mem[ADDR_SCHEDULER_TIME_MSEC][9:0] * 1000000;
            ctrl_valid           <= 1'b1;
        end else begin
            xtrig_low_time       <= mem[ADDR_XTRIG_LOW_TIME][27:0];
            frame_capture_time   <= mem[ADDR_FRAME_CAPTURE_TIME][23:0];
            frame_capture_amount <= mem[ADDR_FRAME_CAPTURE_AMOUNT][9:0];
            start                <= 'b0;
            xtrig_src_sel        <= mem[ADDR_XTRIG_SRC_SEL][1:0];
            scheduler_time_sec   <= mem[ADDR_SCHEDULER_TIME_SEC];
            scheduler_time_nsec  <= mem[ADDR_SCHEDULER_TIME_MSEC][9:0] * 1000000;
            ctrl_valid           <= 'b0;
        end
    end
end

endmodule
