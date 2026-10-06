/*
 * @file      cam_fault_detector_tb.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      04/24/2026
 *
 * @brief     Testbench for top module of cam_fault_detector module. Verifies
 *            fault detection and APB register access.
 *
 * @section changelog
 * - 04/24/2026: Steven Knyazher - Initial implementation
 *
 */

`timescale 1ns/1ps

module cam_fault_detector_tb;

//------------------------------------------------------------------------------
// Parameters
//------------------------------------------------------------------------------
localparam APB_DATA_WIDTH = 32;
localparam APB_ADDR_WIDTH = 32;
localparam CLOCK_FREQ_MHZ = 50;
localparam TIMEOUT_US     = 1000;

localparam CLK_PERIOD     = 20;

// APB register addresses (paddr[6:2] selects word; bottom 2 bits must be 0)
localparam ADDR_FAULT       = 32'h00;
localparam ADDR_FAULT_CLEAR = 32'h04;

// CDC + pipeline guard: 2FF sync adds 2 cycles in each direction
localparam CDC_LAT = 4;

//------------------------------------------------------------------------------
// DUT signals
//------------------------------------------------------------------------------
logic                        pclk;
logic                        presetn;
logic                        penable;
logic                        psel;
logic [APB_ADDR_WIDTH-1:0]   paddr;
logic                        pwrite;
logic [APB_DATA_WIDTH-1:0]   pwdata;
logic [APB_DATA_WIDTH-1:0]   prdata;
logic                        pready;
logic                        pslverr;

logic                        xtrig_clk;
logic                        xtrig_rst_n;

logic                        xtrig;
logic                        frame_valid;
logic                        capture_start;
logic                        capture_finish;
logic                        cam_pwr_status;

//------------------------------------------------------------------------------
// DUT instantiation
//------------------------------------------------------------------------------
cam_fault_detector_top #(
    .APB_DATA_WIDTH (APB_DATA_WIDTH),
    .APB_ADDR_WIDTH (APB_ADDR_WIDTH),
    .CLOCK_FREQ_MHZ (CLOCK_FREQ_MHZ),
    .TIMEOUT_US     (TIMEOUT_US)
) dut (
    .pclk           (pclk          ),
    .presetn        (presetn       ),
    .penable        (penable       ),
    .psel           (psel          ),
    .paddr          (paddr         ),
    .pwrite         (pwrite        ),
    .pwdata         (pwdata        ),
    .prdata         (prdata        ),
    .pready         (pready        ),
    .pslverr        (pslverr       ),
    .xtrig_clk      (xtrig_clk     ),
    .xtrig_rst_n    (xtrig_rst_n   ),
    .xtrig          (xtrig         ),
    .frame_valid    (frame_valid   ),
    .capture_start  (capture_start ),
    .capture_finish (capture_finish),
    .cam_pwr_status (cam_pwr_status)
);

//------------------------------------------------------------------------------
// Clock generation (shared pclk/xtrig_clk for simplicity)
//------------------------------------------------------------------------------
initial pclk = 0;
always #(CLK_PERIOD/2) pclk = ~pclk;

assign xtrig_clk = pclk;

//------------------------------------------------------------------------------
// APB task: write
//------------------------------------------------------------------------------
task apb_write(input logic [APB_ADDR_WIDTH-1:0] addr,
               input logic [APB_DATA_WIDTH-1:0] data);
    @(posedge pclk);
    psel    <= 1'b1;
    pwrite  <= 1'b1;
    paddr   <= addr;
    pwdata  <= data;
    penable <= 1'b0;
    @(posedge pclk);
    penable <= 1'b1;
    wait (pready == 1'b1);
    @(posedge pclk);
    psel    <= 1'b0;
    penable <= 1'b0;
    pwrite  <= 1'b0;
endtask

//------------------------------------------------------------------------------
// APB task: read
//------------------------------------------------------------------------------
task apb_read(input  logic [APB_ADDR_WIDTH-1:0] addr,
              output logic [APB_DATA_WIDTH-1:0] data);
    @(posedge pclk);
    psel    <= 1'b1;
    pwrite  <= 1'b0;
    paddr   <= addr;
    penable <= 1'b0;
    @(posedge pclk);
    penable <= 1'b1;
    wait (pready == 1'b1);
    data = prdata;
    @(posedge pclk);
    psel    <= 1'b0;
    penable <= 1'b0;
endtask

//------------------------------------------------------------------------------
// Helper: write 1 to FAULT_CLEAR, wait for CDC, then de-assert to re-arm
//------------------------------------------------------------------------------
task clear_fault();
    apb_write(ADDR_FAULT_CLEAR, 32'h1);
    repeat(CDC_LAT + 2) @(posedge pclk);
    apb_write(ADDR_FAULT_CLEAR, 32'h0);
    repeat(CDC_LAT + 2) @(posedge pclk);
endtask

//------------------------------------------------------------------------------
// Test stimulus
//------------------------------------------------------------------------------
integer fail_count = 0;
logic [APB_DATA_WIDTH-1:0] read_data;

initial begin
    // Initialise
    presetn        = 0;
    xtrig_rst_n    = 0;
    psel           = 0;
    penable        = 0;
    pwrite         = 0;
    paddr          = '0;
    pwdata         = '0;
    xtrig          = 0;
    frame_valid    = 0;
    capture_start  = 0;
    capture_finish = 0;
    cam_pwr_status = 1;

    repeat(5) @(posedge pclk);
    presetn     = 1;
    xtrig_rst_n = 1;
    repeat(5) @(posedge pclk);

    // -----------------------------------------------------------------
    $display("----------------------------------------------");
    $display(" TEST 1: Reset state - FAULT register reads 0");
    $display("----------------------------------------------");
    apb_read(ADDR_FAULT, read_data);
    if (read_data[0] !== 1'b0) begin
        $display("FAIL: FAULT = %0b after reset, expected 0", read_data[0]);
        fail_count++;
    end else begin
        $display("PASS: FAULT = 0 after reset");
    end

    // -----------------------------------------------------------------
    $display("----------------------------------------------");
    $display(" TEST 2: No fault when frame_valid arrives in time");
    $display("----------------------------------------------");
    // Rising edge on xtrig, then assert frame_valid within 5 cycles (< 10 us timeout)
    @(posedge pclk); xtrig = 1;
    @(posedge pclk); xtrig = 0;
    repeat(3) @(posedge pclk);
    frame_valid = 1;
    repeat(2) @(posedge pclk);
    frame_valid = 0;

    // Wait well past the timeout window then check
    repeat(TIMEOUT_US + CDC_LAT + 5) @(posedge pclk);
    apb_read(ADDR_FAULT, read_data);
    if (read_data[0] !== 1'b0) begin
        $display("FAIL: FAULT = %0b after timely frame_valid, expected 0", read_data[0]);
        fail_count++;
    end else begin
        $display("PASS: No fault - frame_valid arrived within timeout");
    end

    // -----------------------------------------------------------------
    $display("--------------------------------------------------");
    $display(" TEST 3: Timeout fault - xtrig with no frame_valid");
    $display("--------------------------------------------------");
    @(posedge pclk); xtrig = 1;
    @(posedge pclk); xtrig = 0;

    // Wait for timeout to fire + CDC sync to propagate to APB domain
    repeat(TIMEOUT_US + CDC_LAT + 5) @(posedge pclk);
    apb_read(ADDR_FAULT, read_data);
    if (read_data[0] !== 1'b1) begin
        $display("FAIL: FAULT = %0b after timeout, expected 1", read_data[0]);
        fail_count++;
    end else begin
        $display("PASS: Timeout fault latched correctly");
    end

    // -----------------------------------------------------------------
    $display("-------------------------------------------------");
    $display(" TEST 4: Fault clear via APB FAULT_CLEAR register");
    $display("-------------------------------------------------");
    // fault should still be set from test 3
    apb_read(ADDR_FAULT, read_data);
    if (read_data[0] !== 1'b1) begin
        $display("FAIL: FAULT not set before clear test, expected 1");
        fail_count++;
    end

    clear_fault();

    apb_read(ADDR_FAULT, read_data);
    if (read_data[0] !== 1'b0) begin
        $display("FAIL: FAULT = %0b after clear, expected 0", read_data[0]);
        fail_count++;
    end else begin
        $display("PASS: Fault cleared by APB write");
    end

    // Verify FAULT_CLEAR register reads back 0 after re-arm write
    apb_read(ADDR_FAULT_CLEAR, read_data);
    if (read_data[0] !== 1'b0) begin
        $display("FAIL: FAULT_CLEAR = %0b after re-arm, expected 0", read_data[0]);
        fail_count++;
    end else begin
        $display("PASS: FAULT_CLEAR deasserted after re-arm write");
    end

    // -----------------------------------------------------------------
    $display("-------------------------------------------------------------");
    $display(" TEST 5: Re-arm works - new timeout fault latches after clear");
    $display("-------------------------------------------------------------");
    @(posedge pclk); xtrig = 1;
    @(posedge pclk); xtrig = 0;

    repeat(TIMEOUT_US + CDC_LAT + 5) @(posedge pclk);
    apb_read(ADDR_FAULT, read_data);
    if (read_data[0] !== 1'b1) begin
        $display("FAIL: FAULT = %0b after second timeout, expected 1", read_data[0]);
        fail_count++;
    end else begin
        $display("PASS: New timeout fault latched after re-arm");
    end

    clear_fault();

    // -----------------------------------------------------------------
    $display("----------------------------------------------------------");
    $display(" TEST 6: Power fault - cam_pwr_status drops during capture");
    $display("----------------------------------------------------------");
    @(posedge pclk); capture_start = 1;
    @(posedge pclk); capture_start = 0;
    repeat(3) @(posedge pclk);

    cam_pwr_status = 0;  // power drops mid-capture
    repeat(2) @(posedge pclk);
    cam_pwr_status = 1;  // recovers, but fault should be latched

    repeat(CDC_LAT + 5) @(posedge pclk);
    apb_read(ADDR_FAULT, read_data);
    if (read_data[0] !== 1'b1) begin
        $display("FAIL: FAULT = %0b after power drop, expected 1", read_data[0]);
        fail_count++;
    end else begin
        $display("PASS: Power fault latched on cam_pwr_status dropout");
    end

    clear_fault();
    @(posedge pclk); capture_finish = 1;
    @(posedge pclk); capture_finish = 0;

    // -----------------------------------------------------------------
    $display("----------------------------------------------------------------");
    $display(" TEST 7: No fault - cam_pwr_status stays high throughout capture");
    $display("----------------------------------------------------------------");
    cam_pwr_status = 1;
    @(posedge pclk); capture_start = 1;
    @(posedge pclk); capture_start = 0;

    repeat(10) @(posedge pclk);  // capture in progress, pwr stays high

    @(posedge pclk); capture_finish = 1;
    @(posedge pclk); capture_finish = 0;

    repeat(CDC_LAT + 5) @(posedge pclk);
    apb_read(ADDR_FAULT, read_data);
    if (read_data[0] !== 1'b0) begin
        $display("FAIL: FAULT = %0b after clean capture, expected 0", read_data[0]);
        fail_count++;
    end else begin
        $display("PASS: No fault on clean capture with power maintained");
    end

    // -----------------------------------------------------------------
    $display("----------------------------------------------");
    if (fail_count == 0)
        $display(" ALL TESTS PASSED");
    else
        $display(" %0d TEST(S) FAILED", fail_count);
    $display("----------------------------------------------");

    $stop;
end

// Simulation timeout guard
initial begin
    #5_000_000;
    $display("TIMEOUT: simulation exceeded limit");
    $stop;
end

endmodule
