/*
 * @file      cam_fault_detector.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      04/24/2026
 *
 * @brief     Camera Fault Detector IP. This module sends out the fault status
 *            of the camera based on frame_valid going high within a certain
 *            time after xtrog goes high, and cam_pwr_status stays high between
 *            capture_start and capture_finish.
 *
 * @section changelog
 * - 04/24/2026: Steven Knyazher - Initial implementation
 *
 */

module cam_fault_detector #(
    parameter CLOCK_FREQ_MHZ = 50,
    parameter TIMEOUT_US     = 1000
)(
    // Clock and Reset
    input  logic        clk,
    input  logic        rst_n,

    // Camera
    input  logic        xtrig,
    input  logic        frame_valid,
    input  logic        capture_start,
    input  logic        capture_finish,
    input  logic        cam_pwr_status,

    // Fault
    output logic        fault,
    input  logic        fault_clear
);

localparam             TIMEOUT_CYCLES = CLOCK_FREQ_MHZ * TIMEOUT_US;
localparam             CNT_W          = $clog2(TIMEOUT_CYCLES + 1);
localparam [CNT_W-1:0] TIMEOUT_VAL    = CNT_W'(TIMEOUT_CYCLES - 1);

//------------------------------------------------------------------------------
// CDC Synchronizers (frame_valid and fault_clear are from other clock domains)
//------------------------------------------------------------------------------
logic [1:0] frame_valid_sync;
logic [1:0] fault_clear_sync;

always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        frame_valid_sync <= 2'b0;
        fault_clear_sync <= 2'b0;
    end else begin
        frame_valid_sync <= {frame_valid_sync[0], frame_valid};
        fault_clear_sync <= {fault_clear_sync[0], fault_clear};
    end
end

//------------------------------------------------------------------------------
// Fault 1: frame_valid must arrive within TIMEOUT_US after xtrig rising edge
//------------------------------------------------------------------------------
logic             xtrig_d;
logic             watching;
logic [CNT_W-1:0] timeout_cnt;
logic             timeout_fault;

always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        xtrig_d       <= 1'b0;
        watching      <= 1'b0;
        timeout_cnt   <= '0;
        timeout_fault <= 1'b0;
    end else begin
        xtrig_d <= xtrig;

        if (fault_clear_sync[1]) begin
            timeout_fault <= 1'b0;
        end else if (xtrig && ~xtrig_d) begin
            watching    <= 1'b1;
            timeout_cnt <= '0;
        end else if (watching) begin
            if (frame_valid_sync[1]) begin
                watching    <= 1'b0;
                timeout_cnt <= '0;
            end else if (timeout_cnt == TIMEOUT_VAL) begin
                watching      <= 1'b0;
                timeout_fault <= 1'b1;
            end else begin
                timeout_cnt <= timeout_cnt + 1'b1;
            end
        end
    end
end

//------------------------------------------------------------------------------
// Fault 2: cam_pwr_status must stay high between capture_start and capture_finish
//------------------------------------------------------------------------------
logic capturing;
logic pwr_fault;

always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        capturing <= 1'b0;
        pwr_fault <= 1'b0;
    end else begin
        if (fault_clear_sync[1]) begin
            pwr_fault <= 1'b0;
        end else if (capturing && ~cam_pwr_status) begin
            pwr_fault <= 1'b1;
        end

        if (capture_start) begin
            capturing <= 1'b1;
        end

        if (capture_finish) begin
            capturing <= 1'b0;
        end
    end
end

//------------------------------------------------------------------------------
// Fault output (clearable via fault_clear from APB reg)
//------------------------------------------------------------------------------
assign fault = timeout_fault | pwr_fault;

endmodule
