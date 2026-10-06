///////////////////////////////////////////////////////////////////////////////////////////////////
// Company: <Name>
//
// File: DELTA_SIGMA.v
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

module IIR_BIQUAD
    #(  parameter   INPUT_WIDTH   = 13,
        parameter   COEFFICIENT_WIDTH = 18,
        parameter   OUTPUT_WIDTH = 21,
        parameter   FIXED_POINT   = 15,
        parameter signed [COEFFICIENT_WIDTH - 1 : 0] B0 = 32768,
        parameter signed [COEFFICIENT_WIDTH - 1 : 0] B1 = 32768,
        parameter signed [COEFFICIENT_WIDTH - 1 : 0] B2 = 0,
        parameter signed [COEFFICIENT_WIDTH - 1 : 0] A1 = -29770,
        parameter signed [COEFFICIENT_WIDTH - 1 : 0] A2 = 0,
        parameter        [COEFFICIENT_WIDTH - 1 : 0] G  = 24
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

enum {WAITING_FOR_INPUT, ACC_1, ACC_2, ACC_3, ACC_4, ACC_5, ACC_6, WAITING_FOR_READ} FSM_state;

localparam HISTORY_WIDTH = INPUT_WIDTH + $clog2(G);
localparam ACC_WIDTH = HISTORY_WIDTH + COEFFICIENT_WIDTH + 3;

input i_clk, i_res, i_data_valid, i_data_ready;
output o_data_ready, o_data_valid;

input signed [INPUT_WIDTH - 1 : 0] i_data;
output signed [OUTPUT_WIDTH - 1 : 0] o_data;

reg signed [INPUT_WIDTH - 1: 0] x;
reg signed [INPUT_WIDTH - 1 : 0] x_1;
reg signed [INPUT_WIDTH - 1 : 0] x_2;

reg signed [HISTORY_WIDTH - 1 : 0] y;
reg signed [HISTORY_WIDTH - 1 : 0] y_1;
reg signed [HISTORY_WIDTH - 1 : 0] y_2;

wire signed [COEFFICIENT_WIDTH - 1 : 0] b_0 = B0;
wire signed [COEFFICIENT_WIDTH - 1 : 0] b_1 = B1;
wire signed [COEFFICIENT_WIDTH - 1 : 0] b_2 = B2;
wire signed [COEFFICIENT_WIDTH - 1 : 0] a_1 = A1;
wire signed [COEFFICIENT_WIDTH - 1 : 0] a_2 = A2;

reg signed [HISTORY_WIDTH - 1 : 0] sample_preload;
reg signed [COEFFICIENT_WIDTH - 1 : 0] coeff_preload;

reg signed [ACC_WIDTH - 1 : 0] acc_reg;

reg in_data_ready;
reg out_data_valid;

assign o_data = y[HISTORY_WIDTH - 1 : HISTORY_WIDTH - OUTPUT_WIDTH];
assign o_data_ready = in_data_ready;
assign o_data_valid = out_data_valid;

//State Machine
always @(posedge i_clk)
begin
    
    if (i_res == 0)
    begin
        x <= 0;
        x_1 <= 0;
        x_2 <= 0;
        y <= 0;
        y_1 <= 0;
        y_2 <= 0;

        sample_preload <= 0;
        coeff_preload <= 0;

        acc_reg <= 0;
        in_data_ready <= 1;
        out_data_valid <= 0;
        FSM_state <= WAITING_FOR_INPUT;
    end
    else
    begin
        if (FSM_state == WAITING_FOR_INPUT)
        begin
                if(i_data_valid == 1)
                begin
                    x <= i_data;
                    x_1 <= x;
                    x_2 <= x_1;
                    y_1 <= y;
                    y_2 <= y_1;

                    acc_reg <= 0;
                    
                    sample_preload <= i_data;
                    coeff_preload <= b_0;

                    out_data_valid <= 0;
                    in_data_ready <= 0;

                    FSM_state <= ACC_1;
                end
        end
        else if(FSM_state == ACC_1)
        begin
            acc_reg <= acc_reg + sample_preload * coeff_preload;

            sample_preload <= x_1;
            coeff_preload <= b_1;

            out_data_valid <= 0;
            in_data_ready <= 0;

            FSM_state <= ACC_2;
        end
        else if(FSM_state == ACC_2)
        begin
            acc_reg <= acc_reg + sample_preload * coeff_preload;

            sample_preload <= x_2;
            coeff_preload <= b_2;

            out_data_valid <= 0;
            in_data_ready <= 0;

            FSM_state <= ACC_3;
        end
        else if(FSM_state == ACC_3)
        begin
            acc_reg <= acc_reg + sample_preload * coeff_preload;

            sample_preload <= y_1;
            coeff_preload <= a_1;

            out_data_valid <= 0;
            in_data_ready <= 0;            
            
            FSM_state <= ACC_4;
        end
        else if(FSM_state == ACC_4)
        begin
            acc_reg <= acc_reg - sample_preload * coeff_preload;

            sample_preload <= y_2;
            coeff_preload <= a_2;
            out_data_valid <= 0;
            in_data_ready <= 0;            
            
            FSM_state <= ACC_5;
        end
        else if(FSM_state == ACC_5)
        begin
            acc_reg <= acc_reg - sample_preload * coeff_preload;

            out_data_valid <= 0;
            in_data_ready <= 0;

            FSM_state <= ACC_6;
        end
        else if(FSM_state == ACC_6)
        begin   

            y <= acc_reg >> FIXED_POINT;
            out_data_valid <= 1;
            in_data_ready <= 0;

            FSM_state <= WAITING_FOR_READ;
        end
        else if (FSM_state == WAITING_FOR_READ)
        begin
            if(i_data_ready == 1)
            begin
                out_data_valid <= 0;
                in_data_ready <= 1;
                FSM_state <= WAITING_FOR_INPUT;
            end
        end
    end
end

//<statements>

endmodule
