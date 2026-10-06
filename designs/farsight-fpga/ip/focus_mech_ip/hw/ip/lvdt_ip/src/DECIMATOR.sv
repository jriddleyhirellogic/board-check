///////////////////////////////////////////////////////////////////////////////////////////////////
// Company: <Name>
//
// File: DECIMATOR.sv
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

module DECIMATOR

    #(  
        parameter   DATA_WIDTH = 19,
        parameter   DECIMATION_RATIO = 10

    )

    (
        i_clk,
        i_res,
        i_data,
        i_data_valid,
        o_data_ready,
        o_data,
        o_data_valid,
        i_data_ready
    );

enum {WAITING_FOR_READ, WAITING_FOR_INPUT} FSM_state;

input i_clk, i_res, i_data_valid, i_data_ready;
output o_data_valid, o_data_ready;

input signed [DATA_WIDTH - 1 : 0] i_data;
output signed [DATA_WIDTH - 1 : 0] o_data;

reg [$clog2(DECIMATION_RATIO) - 1 : 0] sample_counter;

reg [DATA_WIDTH - 1 : 0] i_data_stored;
reg [DATA_WIDTH - 1 : 0] o_data_stored;

reg out_data_valid;

assign o_data_valid = out_data_valid;
assign o_data_ready = 1;

assign o_data = o_data_stored;

always @(posedge(i_clk))
begin
    if (i_res == 0)
    begin
        sample_counter <= 0;
        o_data_stored <= 0;
        out_data_valid <= 0;

        FSM_state <= WAITING_FOR_INPUT;
    end
    else
    begin
        if(i_data_valid == 1)
        begin
            sample_counter += 1;
            i_data_stored <= i_data;
        end
        if(sample_counter == DECIMATION_RATIO - 1)
        begin
            sample_counter <= 0;
            FSM_state <= WAITING_FOR_READ;
            o_data_stored <= i_data_stored;
            out_data_valid <= 1;
        end
        else if(FSM_state == WAITING_FOR_READ)
        begin
            if(i_data_ready == 1)
            begin
                out_data_valid <= 0;
                FSM_state <= WAITING_FOR_INPUT;
            end
        end
    end
end

endmodule