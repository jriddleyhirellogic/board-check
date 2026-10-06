///////////////////////////////////////////////////////////////////////////////////////////////////
// Company: <Name>
//
// File: STEP_DIR.sv
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

module STEP_DIR
    #(  parameter INPUT_WIDTH = 32
    )

    (   input wire i_clk,
        input wire i_res,
        input wire signed [INPUT_WIDTH - 1: 0] i_data,
        input wire [31:0] i_overflow,

        output reg o_step,
        output reg o_dir

    );

reg signed [32 : 0] step_counter;

wire signed [32:0] i_overflow_s = {1'b0, i_overflow};

reg unsigned [7 : 0] step_min_dt_counter;
reg unsigned [3 : 0] dir_setup_counter;
reg unsigned [6 : 0] step_fall_counter;
reg unsigned [3 : 0] dir_hold_counter;

localparam const_step_min_dt = 150;
localparam const_step_fall = 75;
localparam const_dir_hold = 15;

always @(posedge i_clk)
begin  

    if(i_res == 0)
    begin

        step_counter <= 0;
        o_step <= 0;
        o_dir <= 0;

        step_min_dt_counter <= const_step_min_dt;
        dir_setup_counter <= const_dir_hold;
        step_fall_counter <= 0;
        dir_hold_counter <= const_dir_hold;

    end
    else
    begin

        if (dir_hold_counter == 0 && o_dir != i_data[INPUT_WIDTH - 1])
        begin

            o_dir <= i_data[INPUT_WIDTH - 1];
            o_step <= o_step;
            
            step_counter <= step_counter + i_data;

            if (step_min_dt_counter > 0) step_min_dt_counter <= step_min_dt_counter - 1;
            else step_min_dt_counter <= step_min_dt_counter;

            dir_setup_counter <= const_dir_hold;

            if (step_fall_counter > 0) step_fall_counter <= step_fall_counter - 1;
            else step_fall_counter <= step_fall_counter;
            
            dir_hold_counter <= dir_hold_counter;

        end
        else if (step_fall_counter == 0 && o_step == 1)
        begin
            
            o_dir <= o_dir;
            o_step <= 0;

            step_counter <= step_counter + i_data;

            if (step_min_dt_counter > 0) step_min_dt_counter <= step_min_dt_counter - 1;
            else step_min_dt_counter <= step_min_dt_counter;

            if (dir_setup_counter > 0) dir_setup_counter <= dir_setup_counter - 1;
            else dir_setup_counter <= dir_setup_counter;

            step_fall_counter <= step_fall_counter;

            if (dir_hold_counter > 0) dir_hold_counter <= dir_hold_counter - 1;
            else dir_hold_counter <= dir_hold_counter;

        end
        else if (step_min_dt_counter == 0 && dir_setup_counter == 0)
        begin

            if (step_counter < 0)
            begin

                o_dir <= o_dir;
                o_step <= 1;

                step_counter <= step_counter + i_overflow_s + i_data;

                step_min_dt_counter <= const_step_min_dt;
                dir_setup_counter <= dir_setup_counter;
                step_fall_counter <= const_step_fall;
                dir_hold_counter <= const_dir_hold;

            end
            else if (step_counter > i_overflow_s)
            begin

                o_dir <= o_dir;
                o_step <= 1;

                step_counter <= step_counter - i_overflow_s + i_data;

                step_min_dt_counter <= const_step_min_dt;
                dir_setup_counter <= dir_setup_counter;
                step_fall_counter <= const_step_fall;
                dir_hold_counter <= const_dir_hold;

            end
            else
            begin

                o_dir <= o_dir;
                o_step <= o_step;

                step_counter <= step_counter + i_data;

                step_min_dt_counter <= step_min_dt_counter;

                dir_setup_counter <= dir_setup_counter;

                if (step_fall_counter > 0) step_fall_counter <= step_fall_counter - 1;
                else step_fall_counter <= step_fall_counter;

                if (dir_hold_counter > 0) dir_hold_counter <= dir_hold_counter - 1;
                else dir_hold_counter <= dir_hold_counter;

            end
        end
        else
        begin
            
            o_dir <= o_dir;
            o_step <= o_step;

            step_counter <= step_counter + i_data;

            if (step_min_dt_counter > 0) step_min_dt_counter <= step_min_dt_counter - 1;
            else step_min_dt_counter <= step_min_dt_counter;

            if (dir_setup_counter > 0) dir_setup_counter <= dir_setup_counter - 1;
            else dir_setup_counter <= dir_setup_counter;
            
            if (step_fall_counter > 0) step_fall_counter <= step_fall_counter - 1;
            else step_fall_counter <= step_fall_counter;
            
            if (dir_hold_counter > 0) dir_hold_counter <= dir_hold_counter - 1;
            else dir_hold_counter <= dir_hold_counter;

        end

    end

end

//<statements>

endmodule

