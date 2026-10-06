/*
 * @file      watchdog_tb.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      02/24/2026
 *
 * @brief     Testbench for top module of watchdog module.
 *
 * @section changelog
 * - 02/24/2026: Steven Knyazher - Initial implementation
 * - 03/02/2026: Saba Janamian - Updated for new register interface
 *
 */

`timescale 1ns/1ps

module watchdog_tb;

//------------------------------------------------------------------------------
// Parameters
//------------------------------------------------------------------------------
localparam APB_DATA_WIDTH    = 32;
localparam APB_ADDR_WIDTH    = 32;
localparam CLOCK_FREQ_MHZ    = 1;      // 1 MHz -> CYCLES_PER_MS = 1000
localparam TIMER_COUNT_WIDTH = 27;

localparam CLK_PERIOD        = 20;     // 20ns -> 50 MHz

// APB register addresses (word-aligned, paddr[6:2] selects register)
localparam ADDR_WD_CLEAR        = 32'h00;  // paddr[6:2] = 0
localparam ADDR_WD_TIMEOUT_MS  = 32'h04;  // paddr[6:2] = 1
localparam ADDR_WD_ACTIVE_STAT = 32'h08;  // paddr[6:2] = 2

// Derived
localparam CYCLES_PER_MS = CLOCK_FREQ_MHZ * 1000;

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
logic                        wd_active;

//------------------------------------------------------------------------------
// DUT instantiation
//------------------------------------------------------------------------------
watchdog_top #(
    .APB_DATA_WIDTH    (APB_DATA_WIDTH   ),
    .APB_ADDR_WIDTH    (APB_ADDR_WIDTH   ),
    .CLOCK_FREQ_MHZ    (CLOCK_FREQ_MHZ   ),
    .TIMER_COUNT_WIDTH (TIMER_COUNT_WIDTH )
) dut (
    .pclk       (pclk      ),
    .presetn    (presetn   ),
    .penable    (penable   ),
    .psel       (psel      ),
    .paddr      (paddr     ),
    .pwrite     (pwrite    ),
    .pwdata     (pwdata    ),
    .prdata     (prdata    ),
    .pready     (pready    ),
    .pslverr    (pslverr   ),
    .wd_active (wd_active)
);

//------------------------------------------------------------------------------
// Clock generation
//------------------------------------------------------------------------------
initial pclk = 0;
always #(CLK_PERIOD/2) pclk = ~pclk;

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
// Test stimulus
//------------------------------------------------------------------------------
integer fail_count = 0;
logic [APB_DATA_WIDTH-1:0] read_data;

initial begin
    // Initialise
    presetn = 0;
    psel    = 0;
    penable = 0;
    pwrite  = 0;
    paddr   = '0;
    pwdata  = '0;

    repeat(5) @(posedge pclk);
    presetn = 1;
    repeat(5) @(posedge pclk);

    // -----------------------------------------------------------------
    $display("----------------------------------------------");
    $display(" TEST 1: Reset state - wd_active should be 0");
    $display("----------------------------------------------");
    if (wd_active !== 1'b0) begin
        $display("FAIL: wd_active = %0b, expected 0", wd_active);
        fail_count++;
    end else begin
        $display("PASS: wd_active = 0 after reset (expired, no timeout configured)");
    end

    // -----------------------------------------------------------------
    $display("----------------------------------------------");
    $display(" TEST 2: Arm watchdog and start countdown");
    $display("----------------------------------------------");
    apb_write(ADDR_WD_CLEAR, 32'd1);        // wd_clear = 1 (clear expired)
    apb_write(ADDR_WD_TIMEOUT_MS, 32'd5);  // 5 ms timeout
    apb_write(ADDR_WD_CLEAR, 32'd0);        // wd_clear = 0 (start countdown)
    repeat(5) @(posedge pclk);               // Allow pipeline to settle
    if (wd_active !== 1'b1) begin
        $display("FAIL: wd_active = %0b after arming, expected 1", wd_active);
        fail_count++;
    end else begin
        $display("PASS: wd_active = 1 after arming watchdog");
    end

    // -----------------------------------------------------------------
    $display("----------------------------------------------");
    $display(" TEST 3: Read back wd_active_stat register");
    $display("----------------------------------------------");
    apb_read(ADDR_WD_ACTIVE_STAT, read_data);
    if (read_data[0] !== 1'b1) begin
        $display("FAIL: wd_active_stat read = %0h, expected 1", read_data);
        fail_count++;
    end else begin
        $display("PASS: wd_active_stat register reads 1 (running)");
    end

    // -----------------------------------------------------------------
    $display("----------------------------------------------");
    $display(" TEST 4: Wait for timer to expire");
    $display("----------------------------------------------");
    // 5 ms * CYCLES_PER_MS + margin
    repeat(5 * CYCLES_PER_MS + 50) @(posedge pclk);
    if (wd_active !== 1'b0) begin
        $display("FAIL: wd_active = %0b after expiry, expected 0", wd_active);
        fail_count++;
    end else begin
        $display("PASS: wd_active = 0 after timer expiry");
    end

    // -----------------------------------------------------------------
    $display("----------------------------------------------");
    $display(" TEST 5: Read back expired status after expiry");
    $display("----------------------------------------------");
    apb_read(ADDR_WD_ACTIVE_STAT, read_data);
    if (read_data[0] !== 1'b0) begin
        $display("FAIL: wd_active_stat read = %0h, expected 0", read_data);
        fail_count++;
    end else begin
        $display("PASS: wd_active_stat register reads 0 (expired)");
    end

    // -----------------------------------------------------------------
    $display("----------------------------------------------");
    $display(" TEST 6: Refresh (re-kick) watchdog mid-count");
    $display("----------------------------------------------");
    apb_write(ADDR_WD_CLEAR, 32'd1);        // Clear expired state
    apb_write(ADDR_WD_TIMEOUT_MS, 32'd5);  // 5 ms timeout
    apb_write(ADDR_WD_CLEAR, 32'd0);        // Start countdown
    repeat(5) @(posedge pclk);
    repeat(2 * CYCLES_PER_MS) @(posedge pclk);  // Wait ~2 ms
    apb_write(ADDR_WD_TIMEOUT_MS, 32'd5);      // Re-kick with 5 ms
    repeat(5) @(posedge pclk);
    if (wd_active !== 1'b1) begin
        $display("FAIL: wd_active = %0b after re-kick, expected 1", wd_active);
        fail_count++;
    end else begin
        $display("PASS: wd_active = 1 after re-kick");
    end
    // Now let it expire
    repeat(5 * CYCLES_PER_MS + 50) @(posedge pclk);
    if (wd_active !== 1'b0) begin
        $display("FAIL: wd_active = %0b after re-kick expiry, expected 0", wd_active);
        fail_count++;
    end else begin
        $display("PASS: wd_active = 0 after re-kick expiry");
    end

    // -----------------------------------------------------------------
    $display("----------------------------------------------");
    $display(" TEST 7: Clear after expiry re-arms watchdog");
    $display("----------------------------------------------");
    apb_write(ADDR_WD_CLEAR, 32'd1);        // Clear expired state
    apb_write(ADDR_WD_TIMEOUT_MS, 32'd3);  // 3 ms timeout
    apb_write(ADDR_WD_CLEAR, 32'd0);        // Start countdown
    repeat(5) @(posedge pclk);
    if (wd_active !== 1'b1) begin
        $display("FAIL: wd_active = %0b after clear+reload, expected 1", wd_active);
        fail_count++;
    end else begin
        $display("PASS: wd_active = 1 after clear and reload");
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

// Timeout guard
initial begin
    #1_000_000;
    $display("TIMEOUT: simulation exceeded limit");
    $stop;
end

endmodule
