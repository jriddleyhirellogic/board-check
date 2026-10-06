/*
 * @file      cam_flow_sync.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      02/26/2026
 *
 * @brief     This module will register the output of the SLVSEC IP,
 *            combine line_valid and ebd_valid (embedding valid) signals,
 *            and output the signals as register outputs.
 *            The main reason for register input and outputs are to solve pixel
 *            clock domain timing when sending signals down to the rest of the
 *            pipeline.
 *
 * @section changelog
 * - 02/26/2026: Saba Janamian - Initial implementation
 * - 06/03/2026: Steven Knyazher - Added frame_valid extension by EXTEND_CYCLES
 *               parameter cycles on falling edge
 *
 */

module cam_flow_sync #(
    parameter DATA_WIDTH    = 384,
    parameter EXTEND_CYCLES = 10
)(
    // Pixel clock domain
    input  logic                  clk,
    input  logic                  rst_n,
    // Cam input
    input  logic                  frame_valid_in,
    input  logic                  line_valid_in,
    input  logic                  ebd_valid_in,
    input  logic [DATA_WIDTH-1:0] data_in,
    // Cam output
    output logic                  frame_valid_out,
    output logic                  line_or_ebd_valid_out,
    output logic [DATA_WIDTH-1:0] data_out
);

//------------------------------------------------------------------------------
// FSM
//------------------------------------------------------------------------------
typedef enum logic {
    NORMAL,
    EXTEND
} state_t;

state_t curr_state, next_state;

//------------------------------------------------------------------------------
// Counters
//------------------------------------------------------------------------------
logic [$clog2(EXTEND_CYCLES+1)-1:0] cycle_cnt;

//------------------------------------------------------------------------------
// Internal signals
//------------------------------------------------------------------------------
logic                  frame_valid_reg;
logic                  frame_valid_prev;
logic                  frame_valid_fe;
logic                  line_valid_reg;
logic                  ebd_valid_reg;
logic [DATA_WIDTH-1:0] data_reg;

//------------------------------------------------------------------------------
// Current state logic
//------------------------------------------------------------------------------
always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        frame_valid_reg       <= 1'b0;
        frame_valid_prev      <= 1'b0;
        frame_valid_fe        <= 1'b0;
        line_valid_reg        <= 1'b0;
        ebd_valid_reg         <= 1'b0;
        data_reg              <= 'b0;
        frame_valid_out       <= 1'b0;
        line_or_ebd_valid_out <= 1'b0;
        data_out              <= 'b0;
        cycle_cnt             <= 0;
        curr_state            <= NORMAL;
    end else begin
        curr_state <= next_state;

        // Register inputs
        frame_valid_reg <= frame_valid_in;
        line_valid_reg  <= line_valid_in;
        ebd_valid_reg   <= ebd_valid_in;
        data_reg        <= data_in;

        // Falling edge detection on registered frame_valid
        frame_valid_prev <= frame_valid_reg;
        frame_valid_fe   <= (~frame_valid_reg && frame_valid_prev);

        // Non-frame_valid outputs
        line_or_ebd_valid_out <= line_valid_reg | ebd_valid_reg;
        data_out              <= data_reg;

        // frame_valid FSM output
        case (curr_state)
            NORMAL: begin
                if (frame_valid_fe) begin
                    frame_valid_out <= 1'b1;
                end else begin
                    frame_valid_out <= frame_valid_prev;
                end
                cycle_cnt <= 0;
            end

            EXTEND: begin
                if (cycle_cnt >= EXTEND_CYCLES - 1) begin
                    frame_valid_out <= 1'b0;
                    cycle_cnt       <= 0;
                end else begin
                    frame_valid_out <= 1'b1;
                    cycle_cnt       <= cycle_cnt + 1;
                end
            end

            default: begin
                frame_valid_out <= 1'b0;
                cycle_cnt       <= 0;
                curr_state      <= NORMAL;
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
        NORMAL: begin
            if (frame_valid_fe) begin
                next_state = EXTEND;
            end
        end

        EXTEND: begin
            if (cycle_cnt >= EXTEND_CYCLES - 1) begin
                next_state = NORMAL;
            end
        end

        default: begin
            next_state = NORMAL;
        end
    endcase
end

endmodule
