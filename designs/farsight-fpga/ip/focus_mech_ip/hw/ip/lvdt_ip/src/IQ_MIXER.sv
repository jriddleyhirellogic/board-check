///////////////////////////////////////////////////////////////////////////////////////////////////
// Company: <Name>
//
// File: IQ_MIXER.v
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

module IQ_MIXER
    #(  parameter INPUT_DATA_WIDTH  = 30,
        parameter INPUT_OSC_WIDTH   = 16,
        parameter OUTPUT_WIDTH      = 46
    )
    
    (
        i_clk, 
        i_res, 
        i_sin, 
        i_cos, 
        i_osc_data_valid,
        i_data,
        i_data_valid,
        o_data_ready,
        o_i_data,
        o_q_data,
        o_data_valid,
        i_data_ready
    );

localparam MULT_WIDTH = INPUT_DATA_WIDTH + INPUT_OSC_WIDTH;

input i_clk, i_res, i_osc_data_valid, i_data_valid, i_data_ready;
output o_data_ready, o_data_valid;

input signed [INPUT_DATA_WIDTH - 1 : 0] i_data;
input signed [INPUT_OSC_WIDTH - 1 : 0] i_sin;
input signed [INPUT_OSC_WIDTH - 1 : 0] i_cos;

output signed [OUTPUT_WIDTH - 1 : 0] o_i_data;
output signed [OUTPUT_WIDTH - 1 : 0] o_q_data;

reg signed [INPUT_DATA_WIDTH - 1 : 0] i_data_stored;
reg signed [INPUT_OSC_WIDTH - 1 : 0] i_sin_stored;
reg signed [INPUT_OSC_WIDTH - 1 : 0] i_cos_stored;


reg signed [MULT_WIDTH - 1 : 0] mult_stored; 
reg signed [MULT_WIDTH - 1 : 0] in_phase_product;
reg signed [MULT_WIDTH - 1 : 0] quad_product;

reg in_data_ready;
reg out_data_valid;

assign o_data_valid = out_data_valid;
assign o_data_ready = in_data_ready;

assign o_i_data = in_phase_product[MULT_WIDTH - 1 : MULT_WIDTH - OUTPUT_WIDTH];
assign o_q_data = quad_product[MULT_WIDTH - 1 : MULT_WIDTH - OUTPUT_WIDTH];

enum {WAITING_FOR_INPUT, I_MULT, Q_MULT, OUTPUT_LOAD, WAITING_FOR_READ} FSM_state;

always @(posedge i_clk)
begin

    if (i_res == 0)
    begin
        FSM_state <= WAITING_FOR_INPUT;
        i_data_stored <= 0;
        out_data_valid <= 0;
        in_data_ready <= 1;
        in_phase_product <= 0;
        quad_product <= 0;
    end
    else
    begin
        case (FSM_state)
            WAITING_FOR_INPUT: 
            begin
                if(i_data_valid == 1 && i_osc_data_valid == 1)
                begin
                    i_sin_stored <= i_sin;
                    i_data_stored <= i_data;
                    i_cos_stored <= i_cos;

                    out_data_valid <= 0;
                    in_data_ready <= 0;

                    in_phase_product <= in_phase_product;

                    FSM_state <= I_MULT;
                end
            end
            I_MULT:
            begin
                mult_stored <= i_data_stored * i_sin_stored;
                i_sin_stored <= i_cos_stored;

                out_data_valid <= 0;
                in_data_ready <= 0;

                FSM_state <= Q_MULT;
            end
            Q_MULT:
            begin
                in_phase_product <= mult_stored;
                mult_stored <= i_data_stored * i_sin_stored;

                out_data_valid <= 0;
                in_data_ready <= 0;

                FSM_state <= OUTPUT_LOAD;
            end
            OUTPUT_LOAD:
            begin
                quad_product <= mult_stored;

                out_data_valid <= 1;
                in_data_ready <= 0;
                FSM_state <= WAITING_FOR_READ;
            end
            WAITING_FOR_READ:
            begin
                if(i_data_ready == 1)
                begin
                    out_data_valid <= 0;
                    in_data_ready <= 1;

                    FSM_state <= WAITING_FOR_INPUT;
                end
            end
            default: 
            begin
                if(i_data_valid == 1 && i_osc_data_valid == 1)
                begin
                    in_phase_product <= i_data * i_sin;
                    i_data_stored <= i_data;
                    i_cos_stored <= i_cos;
                    out_data_valid <= 0;
                    in_data_ready <= 0;

                    FSM_state <= I_MULT;
                end
            end
        endcase
    end
end

endmodule

