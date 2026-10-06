/*
 * @file      watchdog.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      02/24/2026
 *
 * @brief     This module implements a watchdog timer that accepts a clock cycle
 *            count value. When wd_refresh is asserted, the value of
 *            counter updates to the value of wd_timeout_val.
 *            The counter only runs when the wd_clear signal is 0.
 *            After reaching the timeout limit the wd_active signal will be
 *            deasserted to indicate watchdog expired.
 *            The signal will stay in expired state
 *            until it is cleared again.
 *
 * @section changelog
 * - 02/24/2026: Steven Knyazher - Initial implementation
 * - 03/02/2026: Added State machine
 *
 */

module watchdog #(
    parameter TIMER_COUNT_WIDTH = 27
)(
    // Source Clock and Reset
    input  logic                          clk,
    input  logic                          rst_n,

    // Timer Control
    input  logic                          wd_clear,
    input  logic [TIMER_COUNT_WIDTH-1:0]  wd_timeout_val,
    input  logic                          wd_refresh,

    // Timer Status
    output logic                          wd_active
);

//------------------------------------------------------------------------------
// State definition
//------------------------------------------------------------------------------
typedef enum logic {
    EXPIRED = 1'b0,
    RUNNING = 1'b1
} state;

state curr_state;
state next_state;

//------------------------------------------------------------------------------
// Internal Signals
//------------------------------------------------------------------------------
logic [TIMER_COUNT_WIDTH-1:0]  counter;

//------------------------------------------------------------------------------
// WD Moore FSM (Sequential logic)
//------------------------------------------------------------------------------
always_ff @(posedge clk, negedge rst_n) begin
    if(~rst_n) begin
        counter          <= 'b0;
        wd_active        <= 1'b0;
        curr_state       <= EXPIRED;
    
    end else begin
        curr_state       <= next_state;

        if (curr_state == EXPIRED) begin

            wd_active    <= 1'b0;
            
            if (wd_clear) begin
                counter  <= wd_timeout_val;
            end else begin
                counter  <= 'b0;
            end

        end else if (curr_state == RUNNING) begin

            wd_active    <= 1'b1;

            if (wd_clear) begin
                counter  <= wd_timeout_val;
            end else if (wd_refresh) begin
                counter  <= wd_timeout_val;
            end else begin
                counter  <= counter - 1;
            end

        end else begin
            wd_active    <= 1'b0;
            counter      <= 'b0;
        end
    end
end

//------------------------------------------------------------------------------
// WD Moore FSM (Combinational logic)
//------------------------------------------------------------------------------
always_comb begin

    next_state = curr_state;

    case(curr_state)

        EXPIRED: begin
            if (wd_clear) begin
                next_state = RUNNING;
            end else begin
                next_state = EXPIRED;
            end
        end

        RUNNING: begin
            if (wd_clear) begin
                next_state = RUNNING;
            end else if((counter-1) == 0) begin
                next_state = EXPIRED;
            end else begin
                next_state = RUNNING;
            end
        end

    endcase
end

endmodule