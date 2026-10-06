/*
 * @file      glitch_filter_tb.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Chase Whyte (cwhyte@turionspace.com)
 * @date      08/14/2025
 * 
 * @brief     Short description of what this module does.
 * 
 * @section changelog
 * - 08/14/2025: Chase Whyte - Initial implementation
 * 
 */

module glitch_filter_tb;
logic clk = 1'b0;
logic rstn = 1'b0;
logic d_in;
logic d_out;

glitch_filter glitch_fiter_i(.*);

always #10ns clk = ~clk;

initial begin
    d_in = 1'b0;
    repeat(10) @(posedge clk);
    d_in = 1'b1;
    @(posedge clk);
    d_in = 1'b0;
    repeat(3) @(posedge clk);
    d_in = 1'b1;
    @(posedge clk);
    d_in = 1'b0;
    @(posedge clk);
    d_in = 1'b1;
    repeat (2) @(posedge clk);
    d_in = 1'b0;
    repeat (2) @(posedge clk);
    d_in = 1'b1;
    repeat (2) @(posedge clk);
    d_in = 1'b0;
    repeat (2) @(posedge clk);
    d_in = 1'b1;
    @(posedge clk);
    d_in = 1'b0;
    repeat(10) @(posedge clk);
    $stop;
end


endmodule