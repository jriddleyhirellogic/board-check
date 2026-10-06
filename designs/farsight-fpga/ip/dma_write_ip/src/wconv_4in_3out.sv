/*
 * @file      wconv_4in_3out.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      10/09/2025
 *
 * @brief     Generic width converter for n*4 = m*3 relationship
 *              Converts DWIDTH_IN to DWIDTH_OUT over 4 input cycles
*              384-bit input to 512-bit output (384*4 = 512*3)
 *               - Cycle 0: Buffer all 384 bits, output nothing
 *               - Cycle 1: Buffer 256 bits, output 512 (128 new + 384 buffered)
 *               - Cycle 2: Buffer 128 bits, output 512 (256 new + 256 buffered)
 *               - Cycle 3: Buffer 0 bits,   output 512 (384 new + 128 buffered)
 *
 * @section changelog
 * - 10/09/2025: Saba Janamian - Initial implementation
 *
 */

module wconv_4in_3out #(
    parameter integer DWIDTH_IN  = 384,
    parameter integer DWIDTH_OUT = 512
)(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  valid_in,
    input  logic [DWIDTH_IN-1:0]  data_in,
    output logic                  valid_out,
    output logic [DWIDTH_OUT-1:0] data_out
);

//------------------------------------------------------------------------------
// Local parameteres
//------------------------------------------------------------------------------

localparam TWO_THIRD = (DWIDTH_IN * 2) - DWIDTH_OUT;       // 384*2-512*1 = 256
localparam ONE_THIRD = (DWIDTH_IN * 3) - (DWIDTH_OUT * 2); // 384*3-512*2 = 128

//------------------------------------------------------------------------------
// Internal signals
//------------------------------------------------------------------------------
// Memory buffer for holding beats
logic [DWIDTH_IN-1:0] buffer;


//------------------------------------------------------------------------------
// FSM State definition
//------------------------------------------------------------------------------
typedef enum logic [1:0] {
    RECV_CHUNK_0 = 2'h0,
    RECV_CHUNK_1 = 2'h1,
    RECV_CHUNK_2 = 2'h2,
    RECV_CHUNK_3 = 2'h3
} state_t;

state_t curr_state;
state_t next_state;

//------------------------------------------------------------------------------
// Width converter FSM
//------------------------------------------------------------------------------
always_ff @(posedge clk, negedge rst_n) begin

    if(~rst_n) begin
        curr_state <= RECV_CHUNK_0;
        data_out   <= 'b0;
        buffer     <= '{default: 1'b0};
        valid_out  <= 'b0;

    end else begin

        curr_state <= next_state;

        if(curr_state == RECV_CHUNK_0) begin

            if(valid_in) begin
                // Output: Nothing
                // Buffer: All input bits
                data_out  <= 'b0;
                buffer    <= data_in;
                valid_out <= 'b0;
            end else begin
                data_out  <= 'b0;
                buffer    <= 'b0;
                valid_out <= 'b0;
            end

        end else if (curr_state == RECV_CHUNK_1) begin

            if(valid_in) begin
                // Output: lower ONE_THIRD bits of new input + all buffered bits
                // Buffer: upper TWO_THIRD bits of new input
                data_out  <= {data_in[0 +: ONE_THIRD], buffer};
                buffer    <= {{ONE_THIRD{1'b0}}, data_in[ONE_THIRD +: TWO_THIRD]};
                valid_out <= 'b1;
            end else begin
                // Send the buffer out with padding
                data_out  <= {{ONE_THIRD{1'b0}}, buffer};
                buffer    <= 'b0;
                valid_out <= 'b1;
            end

        end else if (curr_state == RECV_CHUNK_2) begin

            if(valid_in) begin
                // Output: lower TWO_THIRD bits of new input + buffered bits
                // Buffer: upper bits of new input
                data_out  <= {data_in[0 +: TWO_THIRD], buffer[0 +: TWO_THIRD]};
                buffer  <= {{TWO_THIRD{1'b0}}, data_in[TWO_THIRD +: ONE_THIRD]};
                valid_out <= 'b1;
            end else begin
                // Send the buffer out with padding
                data_out  <= {{TWO_THIRD{1'b0}}, buffer[0 +: TWO_THIRD]};
                buffer    <= 'b0;
                valid_out <= 'b1;
            end

        end else if (curr_state == RECV_CHUNK_3) begin

            if(valid_in) begin
                // Output: all new input + remaining buffered bits
                // Buffer: Nothing
                data_out  <= {data_in, buffer[0 +: ONE_THIRD]};
                buffer    <= 'b0;
                valid_out <= 'b1;
            end else begin
                // Send the buffer out with padding
                data_out  <= {{DWIDTH_IN{1'b0}}, buffer[0 +: ONE_THIRD]};
                buffer    <= 'b0;
                valid_out <= 'b1;
            end

        end
    end
end

always_comb begin

    next_state = curr_state;

    case(curr_state)
        RECV_CHUNK_0: begin
            if(valid_in) begin
                next_state = RECV_CHUNK_1;
            end else begin
                next_state = RECV_CHUNK_0;
            end
        end

        RECV_CHUNK_1: begin
            if(valid_in) begin
                next_state = RECV_CHUNK_2;
            end else begin
                next_state = RECV_CHUNK_0;
            end
        end

        RECV_CHUNK_2: begin
            if(valid_in) begin
                next_state = RECV_CHUNK_3;
            end else begin
                next_state = RECV_CHUNK_0;
            end
        end

        RECV_CHUNK_3: begin
            next_state = RECV_CHUNK_0;
        end

        default: begin
            next_state = RECV_CHUNK_0;
        end

    endcase
end

endmodule
