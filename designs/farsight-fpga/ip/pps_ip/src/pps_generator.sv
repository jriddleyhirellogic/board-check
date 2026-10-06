/*
 * @file      pps_generator.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      11/18/2025
 *
 * @brief     Local PPS generator
 *
 * @section changelog
 * - 11/18/2025: Saba Janamian - Initial implementation
 *
 */

module pps_generator #(
    parameter CLOCK_FREQ_MHZ = 50,
    parameter POLARITY       = 1 // Use 0 for clock transition from 0 to 1
)(
    input  logic clk,
    input  logic rst_n,
    output logic pps_out
);

//------------------------------------------------------------------------------
// Local Parameters
//------------------------------------------------------------------------------
localparam PULSE_WIDTH   = (CLOCK_FREQ_MHZ * 1_000_000) >> 1;
localparam COUNTER_WIDTH = $clog2(PULSE_WIDTH);

//------------------------------------------------------------------------------
// Internal Signals
//------------------------------------------------------------------------------
logic [COUNTER_WIDTH-1:0] counter;

//------------------------------------------------------------------------------
// PPS pulse generator (50% duty cycle at 1Hz) synchronous reset
//------------------------------------------------------------------------------
always_ff @(posedge clk) begin
    if (!rst_n) begin
        counter <= 0;
        pps_out <= POLARITY;
    end else begin
        if (counter == PULSE_WIDTH - 1) begin
            counter <= 0;
            pps_out <= ~pps_out;
        end else begin
            counter <= counter + 1;
            pps_out <= pps_out;
        end
    end
end

endmodule
