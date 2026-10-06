///////////////////////////////////////////////////////////////////////////////////////////////////
// Company: <Name>
//
// File: MIXER_READY_VALID_HANDLER.v
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

module MIXER_READY_VALID_HANDLER
    ( 
        i_mixer_data_valid,
        i_f1_data_ready, 
        i_f2_data_ready, 
        o_f1_data_valid, 
        o_f2_data_valid, 
        o_mixer_data_ready
    );

input i_mixer_data_valid, i_f1_data_ready, i_f2_data_ready;
output o_f1_data_valid, o_f2_data_valid, o_mixer_data_ready;

assign o_mixer_data_ready = i_f1_data_ready & i_f2_data_ready;
assign o_f1_data_valid = i_mixer_data_valid & i_f2_data_ready;
assign o_f2_data_valid = i_mixer_data_valid & i_f1_data_ready;

//<statements>

endmodule

