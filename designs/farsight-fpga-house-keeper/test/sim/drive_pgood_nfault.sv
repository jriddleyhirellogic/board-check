/*
 * @file      drive_pgood_nfault.sv
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

module drive_pgood_nfault # (
    parameter FALL_TIME = 1000
) (
    input logic clk,
    input logic rstn,
    input logic enable,
    input logic inject_pgood,
    input logic [31:0] rise_time,
    input logic [31:0] retry_count,
    input logic        boot_done,
    output logic       pgood
);

logic [31:0] cntr;
logic [31:0] cntr_nxt;
logic [31:0] dwn_cntr;
logic [31:0] dwn_cntr_nxt;
logic [1:0] retry_cntr;
logic enable_r1;

always_comb begin
    cntr_nxt = cntr + enable;
    dwn_cntr_nxt = dwn_cntr + (!enable && pgood);
    if(dwn_cntr == FALL_TIME) begin
        dwn_cntr_nxt = '0;
    end
    if(boot_done) begin
        cntr_nxt = '0;
    end
end

always_ff @(posedge clk) begin
    enable_r1 <= enable;
    if(!rstn) begin
        cntr <= '0;
        pgood <= '0;
        dwn_cntr <= '0;
        retry_cntr <= '0;
    end
    else begin
        cntr <= cntr_nxt;
        if({enable_r1, enable} == 2'b10) begin
            retry_cntr <= retry_cntr + 'd1;
            cntr <= '0;
        end
        if(boot_done) begin
            retry_cntr <= '0;
        end
        dwn_cntr <= dwn_cntr_nxt;
        if(cntr >= rise_time && inject_pgood && retry_cntr >= retry_count) begin
            pgood <= '1;
        end
        else if(dwn_cntr == FALL_TIME || !inject_pgood) begin
            pgood <= '0;
        end
    end
end

endmodule