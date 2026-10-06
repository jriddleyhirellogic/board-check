///////////////////////////////////////////////////////////////////////////////////////////////////
// Company: <Name>
//
// File: SINE_SCALER.v
// File history:
//      <Revision number>: <Date>: <Comments>
//      <Revision number>: <Date>: <Comments>
//      <Revision number>: <Date>: <Comments>
//
// Description: 
//
// <Description here>
//
// Targeted device: <Family::PolarFireSoC> <Die::MPFS095T> <Package::FCSG325>
// Author: <Name>
//
/////////////////////////////////////////////////////////////////////////////////////////////////// 

//`timescale <time_units> / <precision>

module SINE_SCALER
    #(  parameter INPUT_WIDTH = 17,
        parameter MULTIPLIER = 42128,
        parameter MULTIPLIER_WIDTH = 16
    )

    (   input wire i_clk,
        input wire signed [INPUT_WIDTH - 1: 0] i_data,
        output reg signed [INPUT_WIDTH - 2: 0] o_data
    );

reg signed [INPUT_WIDTH - 2 : 0] temp;

always @(posedge i_clk)
begin  

    if (i_data == 2'b01 << (INPUT_WIDTH - 2))
        begin
        temp <= i_data - 1;
        end
    else
        begin
        temp <= i_data;
        end
    
    o_data <= (temp * MULTIPLIER) >> MULTIPLIER_WIDTH;

end



//<statements>

endmodule

