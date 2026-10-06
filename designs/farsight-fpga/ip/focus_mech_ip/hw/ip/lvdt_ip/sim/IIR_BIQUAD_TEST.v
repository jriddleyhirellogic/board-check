///////////////////////////////////////////////////////////////////////////////////////////////////
// Company: <Name>
//
// File: IIR_BIQUAD_TEST.v
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

`timescale 1ns / 100ps

module IIR_BIQUAD_TEST();

reg i_clk;
reg i_res;

reg unsigned [12:0] i_data;
reg i_data_valid;
wire o_data_ready;

wire signed [25:0] o_data_1;
wire o_data_valid_1;
wire i_data_ready_1;

wire signed [29:0] o_data;
wire o_data_valid;
reg i_data_ready_2;

IIR_BIQUAD #(   .INPUT_WIDTH(13),  
                .COEFFICIENT_WIDTH(18),
                .OUTPUT_WIDTH(26),
                .FIXED_POINT(15),
                .B0(32768),
                .B1(2*32768),
                .B2(32768),
                .A1(-64986),
                .A2(32539),
                .G (5766)
            ) 

    biquad_1(    .i_clk(i_clk),
                .i_res(i_res),
                .i_data(i_data),
                .i_data_valid(i_data_valid),
                .o_data_ready(o_data_ready),
                .o_data(o_data_1),
                .o_data_valid(o_data_valid_1),
                .i_data_ready(i_data_ready_1)
            );

IIR_BIQUAD #(   .INPUT_WIDTH(26),
                .COEFFICIENT_WIDTH(18),
                .OUTPUT_WIDTH(30),
                .B0(32768),
                .B1(-65536),
                .B2(32768),
                .A1(-65044),
                .A2(32555),
                .G (15)
            )
    biquad_2(   .i_clk(i_clk),
                .i_res(i_res),
                .i_data(o_data_1),
                .i_data_valid(o_data_valid_1),
                .o_data_ready(i_data_ready_1),
                .o_data(o_data),
                .o_data_valid(o_data_valid),
                .i_data_ready(i_data_ready_2)
            );

always

    #5 i_clk = ~i_clk;

initial begin
    
    i_clk = 0;
    i_res = 0;
    i_data_valid = 0;
    i_data = 0;
    i_data_ready_2 = 0;

    #20;

    i_res = 1;
    i_data_ready_2 = 1;

    while(1)
    begin
        
        i_data = integer'(2047+2047*$sin(2 * 3.14159 * 3050 / (10**9) * $time));
        i_data_valid = 1;
        #10;
        i_data_valid = 0;
        #4990;
    end

end




//<statements>

endmodule