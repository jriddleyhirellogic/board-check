/*
 * @file      cam_trig.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      11/07/2025
 *
 * @brief     Camera Trigger IP. This module receives controls and sends out a precise xtrig.
 *
 * @section changelog
 * - 11/07/2025: Steven Knyazher - Initial implementation
 * - 08/18/2026: Steven Knyazher - xtrig_low_time is now a 28-bit clock cycle
 *                                 count (20 ns per count at 50 MHz) instead of
 *                                 a 22-bit microsecond value, so no conversion
 *                                 arithmetic sits in front of the counters
 *
 */

module cam_trig #(
    parameter CLOCK_FREQ_MHZ = 50
)(
    // Clock and Reset
    input  logic                       clk,
    input  logic                       rst_n,

    // Control
    input  logic [27:0]                xtrig_low_time,      // clock cycles (20 ns each at 50 MHz)
    input  logic [23:0]                frame_capture_time,  // microseconds
    input  logic [9:0]                 frame_capture_amount,
    input  logic                       start,
    input  logic                       ctrl_valid,
    output logic                       ctrl_ready,

    // Finish
    output logic                       finish,

    // Enable
    input logic                        en,

    // XTRIG
    output logic                       xtrig

);

//------------------------------------------------------------------------------
// Clock cycles per microsecond
//------------------------------------------------------------------------------
localparam CYCLES_PER_US = CLOCK_FREQ_MHZ;

//------------------------------------------------------------------------------
// Control registers
//------------------------------------------------------------------------------
logic [27:0]    xtrig_low_time_reg;
logic [23:0]    frame_capture_time_reg;
logic [9:0]     frame_capture_amount_reg;

//------------------------------------------------------------------------------
// FSM
//------------------------------------------------------------------------------
typedef enum logic [2:0] {
    OFF, 
    IDLE,
    XTRIG_LOW_PERIOD,
    XTRIG_HIGH_PERIOD,
    DONE
} state_t;

state_t curr_state, next_state;

//------------------------------------------------------------------------------
// Counters
//------------------------------------------------------------------------------
logic [31:0] timer_cnt;
logic [31:0] cycle_cnt;

//------------------------------------------------------------------------------
// Timing targets in clock cycles
//------------------------------------------------------------------------------
logic [31:0] xtrig_low_cycles;
logic [31:0] frame_capture_cycles;

//------------------------------------------------------------------------------
// Convert the programmed times to clock cycles
//------------------------------------------------------------------------------
assign xtrig_low_cycles     = xtrig_low_time_reg;
assign frame_capture_cycles = frame_capture_time_reg * CYCLES_PER_US;

//------------------------------------------------------------------------------
// Updating control info
//------------------------------------------------------------------------------
always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        ctrl_ready               <= 'b0;
        xtrig_low_time_reg       <= 'b0;
        frame_capture_time_reg   <= 'b0;
        frame_capture_amount_reg <= 'b0;
    end else begin
        // Indicating we can accept info if needed.
        ctrl_ready <= (curr_state == IDLE);

        if (ctrl_valid) begin
            xtrig_low_time_reg       <= xtrig_low_time;
            frame_capture_time_reg   <= frame_capture_time;
            frame_capture_amount_reg <= frame_capture_amount;
        end else begin
            xtrig_low_time_reg       <= xtrig_low_time_reg;
            frame_capture_time_reg   <= frame_capture_time_reg;
            frame_capture_amount_reg <= frame_capture_amount_reg;
        end
    end
end

//------------------------------------------------------------------------------
// Current state logic
//------------------------------------------------------------------------------
always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        xtrig      <= 1'b0;
        finish     <= 1'b0;
        timer_cnt  <= 0;
        cycle_cnt  <= 0;
        curr_state <= OFF;
    end else begin

        curr_state <= next_state;

        xtrig  <= (curr_state != XTRIG_LOW_PERIOD) && (curr_state != OFF);
        finish <= (curr_state == DONE);

        case (curr_state)
            OFF: begin
                timer_cnt <= 0;
                cycle_cnt <= 0;
            end

            IDLE: begin
                timer_cnt <= 0;
                cycle_cnt <= 0;
            end

            XTRIG_LOW_PERIOD: begin
                if (timer_cnt >= xtrig_low_cycles-1) begin
                    timer_cnt <= 0;
                end else begin
                    timer_cnt <= timer_cnt+1;
                end
            end

            XTRIG_HIGH_PERIOD: begin
                if (timer_cnt >= (frame_capture_cycles-xtrig_low_cycles)-1) begin
                    timer_cnt <= 0;
                    if (frame_capture_amount_reg > 0) begin    // If frame_capture_amount_reg, infinite stream
                        cycle_cnt <= cycle_cnt+1;
                    end
                end else begin
                    timer_cnt <= timer_cnt+1;
                end
            end

            DONE: begin
                timer_cnt <= 0;
                cycle_cnt <= 0;
            end

            default: begin
                xtrig     <= 1'b0;
                finish    <= 1'b0;
                timer_cnt <= 0;
                cycle_cnt <= 0;
            end
        endcase
    end
end

//------------------------------------------------------------------------------
// Next state logic
//------------------------------------------------------------------------------
always_comb begin
    next_state = curr_state;

    case (curr_state)
        OFF: begin
            if (en) begin
                next_state = IDLE;
            end
        end

        IDLE: begin
            if (start) begin
                next_state = XTRIG_LOW_PERIOD;
            end
        end

        XTRIG_LOW_PERIOD: begin
            if (timer_cnt >= xtrig_low_cycles-1) begin
                next_state = XTRIG_HIGH_PERIOD;
            end
        end

        XTRIG_HIGH_PERIOD: begin
            if (timer_cnt >= (frame_capture_cycles-xtrig_low_cycles)-1) begin
                if ((frame_capture_amount_reg > 0) && (cycle_cnt >= frame_capture_amount_reg-1)) begin    // If frame_capture_amount_reg, infinite stream
                    next_state = DONE;
                end else begin
                    next_state = XTRIG_LOW_PERIOD;
                end
            end
        end

        DONE: begin
            next_state = IDLE;
        end

        default: begin
            next_state = OFF;
        end
    endcase
end

endmodule
