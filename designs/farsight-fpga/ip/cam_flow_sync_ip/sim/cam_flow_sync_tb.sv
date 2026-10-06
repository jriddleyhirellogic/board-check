/*
 * @file      cam_flow_sync_tb.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      03/03/2026
 *
 * @brief     Testbench for cam_flow_sync module. Verifies the 2-cycle
 *            pipeline latency, valid signal merging, data propagation,
 *            and frame_valid trailing extension (EXTEND_CYCLES).
 *
 * @section changelog
 * - 03/03/2026: Saba Janamian - Initial implementation
 *
 */

`timescale 1ns/1ps

module cam_flow_sync_tb;

//------------------------------------------------------------------------------
// Parameters
//------------------------------------------------------------------------------
localparam DATA_WIDTH    = 16;     // Narrow bus for readability in sim
localparam EXTEND_CYCLES = 10;     // Must match DUT parameter
localparam CLK_PERIOD    = 10;     // 10 ns -> 100 MHz pixel clock

//------------------------------------------------------------------------------
// DUT signals
//------------------------------------------------------------------------------
logic                  clk;
logic                  rst_n;
logic                  frame_valid_in;
logic                  line_valid_in;
logic                  ebd_valid_in;
logic [DATA_WIDTH-1:0] data_in;
logic                  frame_valid_out;
logic                  line_or_ebd_valid_out;
logic [DATA_WIDTH-1:0] data_out;

//------------------------------------------------------------------------------
// DUT instantiation
//------------------------------------------------------------------------------
cam_flow_sync #(
    .DATA_WIDTH    (DATA_WIDTH   ),
    .EXTEND_CYCLES (EXTEND_CYCLES)
) dut (
    .clk                   (clk                  ),
    .rst_n                 (rst_n                ),
    .frame_valid_in        (frame_valid_in       ),
    .line_valid_in         (line_valid_in        ),
    .ebd_valid_in          (ebd_valid_in         ),
    .data_in               (data_in              ),
    .frame_valid_out       (frame_valid_out      ),
    .line_or_ebd_valid_out (line_or_ebd_valid_out),
    .data_out              (data_out             )
);

//------------------------------------------------------------------------------
// Clock generation
//------------------------------------------------------------------------------
initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

//------------------------------------------------------------------------------
// Test stimulus
//------------------------------------------------------------------------------
integer fail_count = 0;
integer i;

initial begin
    // Initialise
    rst_n          = 0;
    frame_valid_in = 0;
    line_valid_in  = 0;
    ebd_valid_in   = 0;
    data_in        = '0;

    repeat(5) @(posedge clk);
    rst_n = 1;
    repeat(2) @(posedge clk);

    // -----------------------------------------------------------------
    $display("----------------------------------------------");
    $display(" TEST 1: Reset state - all outputs should be 0");
    $display("----------------------------------------------");
    if (frame_valid_out !== 1'b0 || line_or_ebd_valid_out !== 1'b0 || data_out !== '0) begin
        $display("FAIL: outputs not zero after reset (fv=%0b, lev=%0b, d=%0h)",
                 frame_valid_out, line_or_ebd_valid_out, data_out);
        fail_count++;
    end else begin
        $display("PASS: all outputs are 0 after reset");
    end

    // -----------------------------------------------------------------
    $display("----------------------------------------------");
    $display(" TEST 2: frame_valid rising-edge latency");
    $display("----------------------------------------------");
    @(posedge clk);
    frame_valid_in = 1;
    // After 1 clock: output still 0
    @(posedge clk);
    if (frame_valid_out !== 1'b0) begin
        $display("FAIL: frame_valid_out asserted after only 1 cycle");
        fail_count++;
    end else begin
        $display("PASS: frame_valid_out still 0 after 1 cycle");
    end
    // After 4 clocks: output should now be 1 (reg -> prev -> out = 3 stages + 1 eval offset)
    repeat(3) @(posedge clk);
    if (frame_valid_out !== 1'b1) begin
        $display("FAIL: frame_valid_out = %0b after 4 cycles, expected 1", frame_valid_out);
        fail_count++;
    end else begin
        $display("PASS: frame_valid_out = 1 after 4-cycle latency");
    end
    frame_valid_in = 0;
    repeat(EXTEND_CYCLES + 5) @(posedge clk);

    // -----------------------------------------------------------------
    $display("----------------------------------------------");
    $display(" TEST 3: 2-cycle latency for data");
    $display("----------------------------------------------");
    @(posedge clk);
    data_in = 16'hBEEF;
    // After 1 clock: not yet
    @(posedge clk);
    if (data_out === 16'hBEEF) begin
        $display("FAIL: data appeared at output after only 1 cycle");
        fail_count++;
    end else begin
        $display("PASS: data not yet at output after 1 cycle");
    end
    // After 3 clocks: output should be BEEF
    repeat(2) @(posedge clk);
    if (data_out !== 16'hBEEF) begin
        $display("FAIL: data_out = %0h after 3 cycles, expected BEEF", data_out);
        fail_count++;
    end else begin
        $display("PASS: data_out = BEEF after 3-cycle latency");
    end
    data_in = '0;
    repeat(3) @(posedge clk);

    // -----------------------------------------------------------------
    $display("----------------------------------------------");
    $display(" TEST 4: line_valid only -> line_or_ebd_valid_out");
    $display("----------------------------------------------");
    @(posedge clk);
    line_valid_in = 1;
    ebd_valid_in  = 0;
    repeat(3) @(posedge clk);
    if (line_or_ebd_valid_out !== 1'b1) begin
        $display("FAIL: line_or_ebd_valid_out = %0b, expected 1 (line_valid only)",
                 line_or_ebd_valid_out);
        fail_count++;
    end else begin
        $display("PASS: line_or_ebd_valid_out = 1 with line_valid only");
    end
    line_valid_in = 0;
    repeat(3) @(posedge clk);

    // -----------------------------------------------------------------
    $display("----------------------------------------------");
    $display(" TEST 5: ebd_valid only -> line_or_ebd_valid_out");
    $display("----------------------------------------------");
    @(posedge clk);
    line_valid_in = 0;
    ebd_valid_in  = 1;
    repeat(3) @(posedge clk);
    if (line_or_ebd_valid_out !== 1'b1) begin
        $display("FAIL: line_or_ebd_valid_out = %0b, expected 1 (ebd_valid only)",
                 line_or_ebd_valid_out);
        fail_count++;
    end else begin
        $display("PASS: line_or_ebd_valid_out = 1 with ebd_valid only");
    end
    ebd_valid_in = 0;
    repeat(3) @(posedge clk);

    // -----------------------------------------------------------------
    $display("----------------------------------------------");
    $display(" TEST 6: both line_valid and ebd_valid asserted");
    $display("----------------------------------------------");
    @(posedge clk);
    line_valid_in = 1;
    ebd_valid_in  = 1;
    repeat(3) @(posedge clk);
    if (line_or_ebd_valid_out !== 1'b1) begin
        $display("FAIL: line_or_ebd_valid_out = %0b, expected 1 (both asserted)",
                 line_or_ebd_valid_out);
        fail_count++;
    end else begin
        $display("PASS: line_or_ebd_valid_out = 1 with both valid signals");
    end
    line_valid_in = 0;
    ebd_valid_in  = 0;
    repeat(3) @(posedge clk);

    // -----------------------------------------------------------------
    $display("----------------------------------------------");
    $display(" TEST 7: neither line_valid nor ebd_valid");
    $display("----------------------------------------------");
    @(posedge clk);
    line_valid_in = 0;
    ebd_valid_in  = 0;
    repeat(2) @(posedge clk);
    if (line_or_ebd_valid_out !== 1'b0) begin
        $display("FAIL: line_or_ebd_valid_out = %0b, expected 0 (neither asserted)",
                 line_or_ebd_valid_out);
        fail_count++;
    end else begin
        $display("PASS: line_or_ebd_valid_out = 0 with no valid signals");
    end
    repeat(2) @(posedge clk);

    // -----------------------------------------------------------------
    $display("----------------------------------------------");
    $display(" TEST 8: Full frame simulation (EBD + image lines)");
    $display("----------------------------------------------");
    // Simulate a small frame: 2 EBD lines, then 4 image lines, 4 pixels each
    @(posedge clk);
    frame_valid_in = 1;

    // -- Embedded data lines --
    for (i = 0; i < 2; i++) begin
        @(posedge clk);
        ebd_valid_in = 1;
        data_in      = 16'hE000 + i[DATA_WIDTH-1:0];
        repeat(3) @(posedge clk);  // 4 pixel clocks per line (1 already used)
        ebd_valid_in = 0;
        data_in      = '0;
        @(posedge clk);            // horizontal blanking
    end

    // -- Image lines --
    for (i = 0; i < 4; i++) begin
        @(posedge clk);
        line_valid_in = 1;
        data_in       = 16'hA000 + i[DATA_WIDTH-1:0];
        repeat(3) @(posedge clk);
        line_valid_in = 0;
        data_in       = '0;
        @(posedge clk);
    end

    frame_valid_in = 0;
    // Wait for pipeline latency (3 cycles) + full extension + margin
    repeat(EXTEND_CYCLES + 6) @(posedge clk);

    // After frame ends + pipeline drain + extension, outputs should be deasserted
    if (frame_valid_out !== 1'b0) begin
        $display("FAIL: frame_valid_out still asserted after frame end");
        fail_count++;
    end else begin
        $display("PASS: frame_valid_out deasserted after frame ends");
    end

    if (line_or_ebd_valid_out !== 1'b0) begin
        $display("FAIL: line_or_ebd_valid_out still asserted after frame end");
        fail_count++;
    end else begin
        $display("PASS: line_or_ebd_valid_out deasserted after frame ends");
    end

    // -----------------------------------------------------------------
    $display("----------------------------------------------");
    $display(" TEST 9: Reset mid-operation clears pipeline");
    $display("----------------------------------------------");
    @(posedge clk);
    frame_valid_in = 1;
    line_valid_in  = 1;
    data_in        = 16'hCAFE;
    repeat(2) @(posedge clk);
    // Assert reset while pipeline is active
    rst_n = 0;
    repeat(3) @(posedge clk);
    if (frame_valid_out !== 1'b0 || line_or_ebd_valid_out !== 1'b0 || data_out !== '0) begin
        $display("FAIL: outputs not cleared during reset");
        fail_count++;
    end else begin
        $display("PASS: reset clears all pipeline outputs");
    end
    // Release reset
    rst_n = 1;
    frame_valid_in = 0;
    line_valid_in  = 0;
    data_in        = '0;
    repeat(3) @(posedge clk);

    // -----------------------------------------------------------------
    $display("----------------------------------------------");
    $display(" TEST 10: frame_valid trailing extension");
    $display("----------------------------------------------");
    // Assert frame_valid for a few cycles then drop it
    @(posedge clk);
    frame_valid_in = 1;
    repeat(5) @(posedge clk);
    frame_valid_in = 0;

    // After 3 pipeline cycles the FSM has entered EXTEND and output is high
    repeat(3) @(posedge clk);
    if (frame_valid_out !== 1'b1) begin
        $display("FAIL: frame_valid_out not extended after falling edge (got %0b)", frame_valid_out);
        fail_count++;
    end else begin
        $display("PASS: frame_valid_out held high during extension");
    end

    // After EXTEND_CYCLES+1 cycles the extension should have expired
    repeat(EXTEND_CYCLES + 1) @(posedge clk);
    if (frame_valid_out !== 1'b0) begin
        $display("FAIL: frame_valid_out still high after extension expired (got %0b)", frame_valid_out);
        fail_count++;
    end else begin
        $display("PASS: frame_valid_out deasserted after extension period");
    end
    repeat(3) @(posedge clk);

    // -----------------------------------------------------------------
    $display("----------------------------------------------");
    if (fail_count == 0)
        $display(" ALL TESTS PASSED");
    else
        $display(" %0d TEST(S) FAILED", fail_count);
    $display("----------------------------------------------");

    $stop;
end

// Timeout guard
initial begin
    #100_000;
    $display("TIMEOUT: simulation exceeded limit");
    $stop;
end

endmodule
