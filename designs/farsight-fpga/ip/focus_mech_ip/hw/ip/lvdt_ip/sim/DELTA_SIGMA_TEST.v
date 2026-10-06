///////////////////////////////////////////////////////////////////////////////////////////////////
// Company: <Name>
//
// File: test.v
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

module DELTA_SIGMA_TEST();

reg i_clk;
reg i_res;
reg [4:0] i_data;
reg i_data_valid;

wire [2:0] o_data;

DELTA_SIGMA 

    #(
        .INPUT_WIDTH(5), 
        .OUTPUT_WIDTH(3)) 
    del_sig
    (  
        .i_clk(i_clk),
        .i_res(i_res),
        .i_data(i_data),
        .i_data_valid(i_data_valid),
        .o_data(o_data)
    );


always
    #5 i_clk = ~i_clk;

initial begin
    
    i_clk = 0;
    i_res = 0;
    i_data_valid = 0;
    i_data = -16;

    #100;

    i_res = 1;
    i_data_valid = 1;

    while(1)
    begin
        #10000;
        i_data = i_data + 1;
    end

end




//<statements>

endmodule

