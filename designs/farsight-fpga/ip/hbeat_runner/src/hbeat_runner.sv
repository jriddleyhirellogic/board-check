/*
 * @file      hbeat_runner.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      2/6/2025
 *
 * @brief     Payload Heatbeat for reference test
 *
 * @section changelog
 * - 11/11/2025: Saba Janamian - Initial implementation
 *
 */

`timescale 1ns / 1ps

module hbeat_runner #(
    parameter integer CLK_FREQ_HZ = 50_000_000,      // Clock frequency
    parameter integer COUNT_MAX   = CLK_FREQ_HZ >> 1 // Max counter value for heartbeat
)(
    input  wire         clk,
    input  wire         rst_n,
    output wire         hbeat           // LED heartbeat
);

    reg [31:0] clk_counter;             // Clock counter for heartbeat
    reg        hbeat_reg;               // Heartbeat signal

    assign hbeat = hbeat_reg;

    // Clock counter and heartbeat
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            clk_counter <= 0;
            hbeat_reg <= 0;
        end else begin
            if (clk_counter < COUNT_MAX - 1) begin
                clk_counter <= clk_counter + 1;
            end else begin
                clk_counter <= 0;
                hbeat_reg <= ~hbeat_reg;
            end
        end
    end

endmodule
