///////////////////////////////////////////////////////////////////////////////////////////////////
// Company: <Name>
//
// File: RST_HANDLER.v
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

module RST_HANDLER( i_clk, i_rst, i_init_over, o_data_valid);
input i_clk, i_rst;
input i_init_over;
output o_data_valid;

reg o_data_valid;

always @(posedge i_clk)
begin
    if (i_rst == 0)
        o_data_valid <= 0;
    else if (i_init_over == 1)
        o_data_valid <= 1;
    else
        o_data_valid <= o_data_valid;
end
        

//<statements>

endmodule

