/*
 * @file      reset_synchronizer.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Chase Whyte (cwhyte@turionspace.com)
 * @date      08/14/2025
 * 
 * @brief     This module takes an async active-low reset and outputs a synchronous active-low
 *            reset for 10 clock cycles
 * 
 * @section changelog
 * - 08/14/2025: Chase Whyte - Initial implementation
 * 
 */
module reset_synchronizer # (
    parameter NUM_STAGES = 3  //number of flip flops for delay stages of reset, minimum of 2
) (
    input  logic clk,
    input  logic arstn,
    output logic rstn
);
logic [NUM_STAGES-1:0] rstn_r10;

assign rstn = rstn_r10[NUM_STAGES-1];

always_ff @(posedge clk or negedge arstn) begin
    if(!arstn) begin
        rstn_r10 <= '0;
    end
    else begin
        rstn_r10 <= {rstn_r10[NUM_STAGES-2:0], 1'b1};
    end
end

endmodule
