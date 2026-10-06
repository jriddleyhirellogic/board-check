/*
 * @file      glitch_filter.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Chase Whyte (cwhyte@turionspace.com)
 * @date      08/14/2025
 * 
 * @brief     filters out pulses that are less than PULSE_WIDTH clock cycles in length
 * 
 * @section changelog
 * - 08/14/2025: Chase Whyte - Initial implementation
 * 
 */

module glitch_filter # (
    parameter PULSE_WIDTH = 32'd250
) (
    input  logic clk,
    input  logic rstn,
    input  logic d_in,
    output logic d_out
);
logic [$clog2(PULSE_WIDTH)-1:0] cntr;
logic d_in_r1;
logic edge_det;

assign edge_det = d_in_r1 ^ d_in;

generate
    if(PULSE_WIDTH == 1'd1) begin: passthrough
        assign d_out = d_in;
    end
    else begin: filter_pulse
        always_ff @(posedge clk) begin
            if(!rstn) begin
                cntr <= '0;
                d_out <= d_in_r1;
            end
            else begin
                if(edge_det) begin
                    cntr <= '0;
                end
                else begin
                    cntr <= cntr + 1'd1;
                end
                if(cntr >= PULSE_WIDTH - 1'd1) begin
                    d_out <= d_in_r1;
                end
            end
        end

        always_ff @(posedge clk) begin
            d_in_r1 <= d_in;
        end
    end
endgenerate


endmodule
