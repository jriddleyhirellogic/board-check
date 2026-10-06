/*
 * @file      divider_with_remainder.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Chase Whyte (cwhyte@turionspace.com)
 * @date      11/20/2025
 *
 * @brief     SystemVerilog Divider Module with Remainder
 *            Clean restoring division algorithm implementation
 *            Designed for PolarFire FPGA implementation
 * @section changelog
 * - 11/20/2025: Chase Whyte - Initial implementation
 *
 */

module divider_with_remainder #(
    parameter WIDTH = 32
)(
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    start,       // Start division operation
    input  logic [WIDTH-1:0]        dividend,   // Dividend input
    input  logic [WIDTH-1:0]        divisor,    // Divisor input

    output logic [WIDTH-1:0]        quotient,   // Quotient output
    output logic [WIDTH-1:0]        remainder,  // Remainder output
    output logic                    valid,       // Result valid signal
    output logic                    ready,       // Ready for new operation
    output logic                    div_by_zero  // Division by zero flag
);

// State machine
typedef enum logic [1:0] {
    IDLE     = 'd0,
    DIVIDING = 'd1,
    DONE     = 'd2
} state_t;

state_t state;

// Internal registers
logic [WIDTH-1:0]       divisor_reg;
logic [WIDTH-1:0]       quotient_reg;
logic [WIDTH-1:0]       remainder_reg;
logic [WIDTH-1:0]       temp_remainder;
logic [$clog2(WIDTH):0] counter;

// Control signals
assign ready     = (state == IDLE);
assign quotient  = quotient_reg;
assign remainder = remainder_reg;

// Main state machine and division logic
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state          <= IDLE;
        quotient_reg   <= '0;
        remainder_reg  <= '0;
        temp_remainder <= '0;
        divisor_reg    <= '0;
        counter        <= '0;
        valid          <= 1'b0;
        div_by_zero    <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                valid       <= 1'b0;

                if (start) begin
                    // Check for division by zero
                    if (divisor == 0) begin
                        quotient_reg   <= '1;      // All 1's for error
                        remainder_reg  <= dividend;
                        div_by_zero    <= 1'b1;
                        temp_remainder <= '0;
                        counter        <= '0;
                        state          <= DONE;
                    end else begin
                        // Initialize for restoring division
                        divisor_reg    <= divisor;
                        quotient_reg   <= '0;
                        remainder_reg  <= '0;
                        div_by_zero    <= 1'b0;
                        temp_remainder <= dividend;  // Start with dividend
                        counter        <= WIDTH;     // Count down from WIDTH
                        state          <= DIVIDING;
                    end
                end
            end

            DIVIDING: begin
                valid          <= 1'b0;
                div_by_zero    <= 1'b0;
                // Shift remainder and quotient left
                temp_remainder <= temp_remainder << 1;

                // Try subtracting divisor
                if ({remainder_reg[WIDTH-2:0], temp_remainder[WIDTH-1]} >= divisor_reg) begin
                    quotient_reg[0] <= 1'b1;
                    // Subtraction successful - set quotient bit and update remainder
                    remainder_reg   <= {remainder_reg[WIDTH-2:0], temp_remainder[WIDTH-1]} - divisor_reg;
                end else begin
                    // If subtraction not possible, quotient bit stays 0
                    quotient_reg   <= quotient_reg << 1;
                    remainder_reg  <= {remainder_reg[WIDTH-2:0], temp_remainder[WIDTH-1]};
                end

                counter <= counter - 1;

                if (counter == 1) begin
                    state <= DONE;
                end
            end

            DONE: begin
                valid <= 1'b1;
                if (!start) begin
                    state <= IDLE;
                end
            end
        endcase
    end
end

endmodule
