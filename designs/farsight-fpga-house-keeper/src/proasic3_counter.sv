/*
 * @file      proasic3_counter.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Chase Whyte (cwhyte@turionspace.com)
 * @date      10/28/2025
 * 
 * @brief     Customized counter to use for proasic3 in order to pass timing
 *            splits counter into two parts, uses a modified carry look ahead algorithm
 *            
 * 
 * @section changelog
 * - 10/28/2025: Chase Whyte - Initial implementation
 * 
 */
module proasic3_counter # (
    parameter integer unsigned CNTR_RESOLUTION = 10,
    parameter integer unsigned CNTR_PRECISION  = 14
) (
    input  logic                       clk,
    input  logic                       rstn,
    input  logic                       clr,
    output logic [CNTR_RESOLUTION-1:0] cntr
);

logic                      cout;
logic [CNTR_PRECISION-1:0] subcntr;
logic [CNTR_PRECISION-1:0] subcntr_dv;
logic                      cntr_incr;

always_comb begin
    cout = '1;
    for(integer unsigned i = 0; i < CNTR_PRECISION; i++) begin
        subcntr_dv[i] = subcntr[i] ^ cout;
        cout &= subcntr[i];
    end
end

always_ff @(posedge clk) begin
    if(!rstn || clr) begin
        cntr      <= '0;
        cntr_incr <= '0;
        subcntr   <= '0;
    end
    else begin
        cntr_incr <= (subcntr == '1);
        //counter saturates on reaching all 1s
        if(cntr != '1)
            cntr      <= cntr + cntr_incr;
        subcntr   <= subcntr_dv;
    end
end

endmodule
