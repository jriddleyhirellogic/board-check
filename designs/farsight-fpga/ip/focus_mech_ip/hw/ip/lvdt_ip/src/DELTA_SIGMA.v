///////////////////////////////////////////////////////////////////////////////////////////////////
// Company: <Name>
//
// File: main.v
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

module DELTA_SIGMA
    #(  parameter   INPUT_WIDTH   = 16,
        parameter   OUTPUT_WIDTH  = 8
    )

    (
        input wire i_clk,
        input wire i_res,
        input wire signed [INPUT_WIDTH - 1 : 0] i_data,
        input wire i_data_valid,
        output wire [OUTPUT_WIDTH - 1: 0] o_data
    );

localparam LSB_INPUT_WIDTH = INPUT_WIDTH - OUTPUT_WIDTH + 1;

reg [INPUT_WIDTH-1:0] i_data_latched;

wire [LSB_INPUT_WIDTH - 1 : 0] lsb_data;

reg signed [LSB_INPUT_WIDTH+1:0] acc_1;
wire signed [LSB_INPUT_WIDTH+1:0] lsb_data_ext;

//R2R Driver
assign o_data[OUTPUT_WIDTH - 1: 1] = i_data_latched[INPUT_WIDTH - 1: LSB_INPUT_WIDTH];
assign lsb_data = i_data_latched[LSB_INPUT_WIDTH - 1: 0];

always @(posedge i_clk)
begin

    if (i_res == 0)
        begin  
            i_data_latched <= 0;
        end

    if (i_data_valid == 1)
        begin   
            i_data_latched <= {!i_data[INPUT_WIDTH - 1], i_data[INPUT_WIDTH - 2: 0]};
        end

end

//Delta Sigma Modulator
assign lsb_data_ext = {1'b0, 1'b0, lsb_data};
assign o_data[0] = acc_1[LSB_INPUT_WIDTH];

always @(posedge i_clk)
    begin
        if(i_res == 0)
            begin
                acc_1 <= 0;
            end
        else
        if(o_data[0] == 1)
            begin
                acc_1 <= acc_1 + lsb_data_ext - 2**LSB_INPUT_WIDTH;
            end
        else
            begin
                acc_1 <= acc_1 + lsb_data_ext;
            end
    end

//<statements>

endmodule

