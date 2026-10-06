/*
 * @file      dff_sync.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Chase Whyte (cwhyte@turionspace.com)
 * @date      08/14/2025
 * 
 * @brief     Short description of what this module does.
 * 
 * @section changelog
 * - 08/14/2025: Chase Whyte - Initial implementation
 * 
 */

module dff_sync # (
    parameter BWIDTH = 1,
    parameter NUM_STAGES = 2
) (
    input  logic clk,
    input  logic [BWIDTH-1:0] d_in,
    output logic [BWIDTH-1:0] d_out
);
logic [NUM_STAGES:1][BWIDTH-1:0] d_in_meta;

always_ff @(posedge clk) begin
    d_in_meta <= {d_in_meta[NUM_STAGES-1:1], d_in};
end

assign d_out = d_in_meta[NUM_STAGES];

endmodule
