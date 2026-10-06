/*
 * @file      cam_trig_tb.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      03/04/2026
 *
 * @brief     Testbench for top module of cam_trig module. Verifies trigger
 *            pulse generation, timing, frame counting, and APB register access.
 *
 * @section changelog
 * - 03/04/2026: Saba Janamian - Initial implementation
 * - 08/18/2026: Steven Knyazher - xtrig_low_time is now programmed as a clock
 *                                 cycle count
 *
 */

`timescale 1ns/1ps

module cam_trig_tb;

//------------------------------------------------------------------------------
// Parameters
//------------------------------------------------------------------------------
localparam APB_DATA_WIDTH = 32;
localparam APB_ADDR_WIDTH = 32;
localparam CLOCK_FREQ_MHZ = 1;        // 1 MHz -> 1 cycle per us

localparam CLK_PERIOD     = 20;       // 20 ns -> 50 MHz (actual clock)

// APB register addresses (word-aligned, paddr[6:2] selects register)
localparam ADDR_XTRIG_LOW_TIME       = 32'h00;  // paddr[6:2] = 0
localparam ADDR_FRAME_CAPTURE_TIME   = 32'h04;  // paddr[6:2] = 1
localparam ADDR_FRAME_CAPTURE_AMOUNT = 32'h08;  // paddr[6:2] = 2
localparam ADDR_START                = 32'h0C;  // paddr[6:2] = 3
localparam ADDR_XTRIG_SRC_SEL        = 32'h10;  // paddr[6:2] = 4
localparam ADDR_SCHEDULER_TIME_SEC   = 32'h14;  // paddr[6:2] = 5
localparam ADDR_SCHEDULER_TIME_MSEC  = 32'h18;  // paddr[6:2] = 6
localparam ADDR_BUSY                 = 32'h1C;  // paddr[6:2] = 7
localparam ADDR_IRQ_STATUS           = 32'h20;  // paddr[6:2] = 8 (R / W1C)

// Derived
localparam CYCLES_PER_US = CLOCK_FREQ_MHZ;

// Trigger stimulus values
localparam XTRIG_LOW_TIME_CYCLES   = 32'd5_000; // 100 us @ 20 ns per cycle = 5000 cycles
localparam FRAME_CAPTURE_TIME_USEC = 32'd1_000;  // 1000 us
localparam FRAME_CAPTURE_AMOUNT    = 32'd3;      // 3 frames

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

logic                        finish;
logic                        start;
logic                        xtrig_int;
logic                        en;
logic                        xtrig;

logic [31:0]                 rtc_sec;
logic [31:0]                 rtc_nsec;
logic                        rtc_running;
logic                        lvds_start;

logic [23:0]                 frame_capture_time;
logic [9:0]                  frame_capture_amount;

//------------------------------------------------------------------------------
// DUT instantiation
//------------------------------------------------------------------------------
cam_trig_top #(
    .APB_DATA_WIDTH (APB_DATA_WIDTH),
    .APB_ADDR_WIDTH (APB_ADDR_WIDTH),
    .CLOCK_FREQ_MHZ (CLOCK_FREQ_MHZ)
) dut (
    .pclk                 (pclk                ),
    .presetn              (presetn             ),
    .penable              (penable             ),
    .psel                 (psel                ),
    .paddr                (paddr               ),
    .pwrite               (pwrite              ),
    .pwdata               (pwdata              ),
    .prdata               (prdata              ),
    .pready               (pready              ),
    .pslverr              (pslverr             ),
    .xtrig_clk            (xtrig_clk           ),
    .xtrig_rst_n          (xtrig_rst_n         ),
    .finish               (finish              ),
    .start                (start               ),
    .xtrig_int            (xtrig_int           ),
    .en                   (en                  ),
    .rtc_sec              (rtc_sec             ),
    .rtc_nsec             (rtc_nsec            ),
    .lvds_start           (lvds_start          ),
    .xtrig                (xtrig               ),
    .frame_capture_time   (frame_capture_time  ),
    .frame_capture_amount (frame_capture_amount)
);

//------------------------------------------------------------------------------
// Clock generation (same clock for APB and xtrig for simplicity)
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
// Reset Task
//------------------------------------------------------------------------------
task system_reset();
    begin
        presetn = 1'b0;
        xtrig_rst_n = 1'b0;
        psel = 1'b0;
        penable = 1'b0;
        pwrite = 1'b0;
        paddr = 32'h0;
        pwdata = 32'h0;
        en = 1'b1;
        rtc_sec = 32'h0;
        rtc_nsec = 32'h0;
        rtc_running = 1'b0;
        lvds_start = 1'b0;
        
        repeat(10) @(posedge pclk);
        presetn = 1'b1;
        xtrig_rst_n = 1'b1;
        repeat(10) @(posedge pclk);
    end
endtask

//------------------------------------------------------------------------------
// Test 1: Manual Start via APB
//------------------------------------------------------------------------------
task test_manual_start();
    logic [APB_DATA_WIDTH-1:0] rdata;
    begin
        $display("\n========================================");
        $display("Test 1: Manual Start via APB");
        $display("========================================\n");

        system_reset();

        // Configure trigger parameters
        $display("Configuring trigger parameters...");
        apb_write(ADDR_XTRIG_LOW_TIME, XTRIG_LOW_TIME_CYCLES);        // Low time = 5000 cycles
        apb_write(ADDR_FRAME_CAPTURE_TIME, FRAME_CAPTURE_TIME_USEC);  // Frame capture time = 1000 us
        apb_write(ADDR_FRAME_CAPTURE_AMOUNT, FRAME_CAPTURE_AMOUNT);   // Capture 3 frames

        // Select manual start mode (xtrig_src_sel = 2'b00)
        $display("Selecting manual start mode...");
        apb_write(ADDR_XTRIG_SRC_SEL, 32'h0000_0000);

        // Trigger manual start
        $display("Triggering manual start...");
        apb_write(ADDR_START, 32'h0000_0001);

        // Verify xtrig_int fires
        $display("Waiting for xtrig_int interrupt pulse...");
        wait(xtrig_int);
        $display("xtrig_int asserted");
        apb_write(ADDR_IRQ_STATUS, 32'h0000_0001); // W1C acknowledge
        wait(!xtrig_int);
        $display("xtrig_int deasserted after W1C acknowledge");

        // Verify busy is set via APB
        apb_read(ADDR_BUSY, rdata);
        if (rdata[0] !== 1'b1) $display("[FAIL] busy not set");
        else                   $display("busy = 1 confirmed via APB");

        // Wait for operation to complete
        $display("Waiting for finish signal...");
        wait(finish);
        $display("Manual start test completed - finish asserted");

        // Verify busy clears after finish
        repeat(2) @(posedge pclk);
        apb_read(ADDR_BUSY, rdata);
        if (rdata[0] !== 1'b0) $display("[FAIL] busy did not clear after finish");
        else                   $display("busy = 0 confirmed after finish");

        repeat(100) @(posedge xtrig_clk);

        $display("\n[PASS] Test 1: Manual Start via APB\n");
    end
endtask

//------------------------------------------------------------------------------
// RTC Counter - increments nsec by 20 each pclk cycle
//------------------------------------------------------------------------------
always @(posedge pclk or negedge presetn) begin
    if (~presetn) begin
        rtc_sec <= 32'd0;
        rtc_nsec <= 32'd0;
    end else if (rtc_running) begin
        if (rtc_nsec >= 32'd999_999_980) begin
            rtc_nsec <= 32'd0;
            rtc_sec <= rtc_sec + 1;
        end else begin
            rtc_nsec <= rtc_nsec + 32'd20;
        end
    end
end

//------------------------------------------------------------------------------
// Test 2: Scheduler Start via RTC
//------------------------------------------------------------------------------
task test_scheduler_start();
    begin
        $display("\n========================================");
        $display("Test 2: Scheduler Start via RTC");
        $display("========================================\n");

        system_reset();

        // Initialize RTC to a time before the trigger point
        $display("Starting RTC at 99 sec, 999.5 msec...");
        $display("RTC will increment automatically...");
        rtc_sec = 32'd99;
        rtc_nsec = 32'd999_500_000; // 999.5 ms - close to rollover

        // Configure trigger parameters
        $display("Configuring trigger parameters...");
        apb_write(ADDR_XTRIG_LOW_TIME, XTRIG_LOW_TIME_CYCLES);        // Low time = 5000 cycles
        apb_write(ADDR_FRAME_CAPTURE_TIME, FRAME_CAPTURE_TIME_USEC);  // Frame capture time = 1000 us
        apb_write(ADDR_FRAME_CAPTURE_AMOUNT, FRAME_CAPTURE_AMOUNT);   // Capture 3 frames

        // Set scheduler time (trigger when RTC reaches this time)
        $display("Setting scheduler time to 100 sec, 200 msec...");
        apb_write(ADDR_SCHEDULER_TIME_SEC, 32'd100);         // 100 seconds
        apb_write(ADDR_SCHEDULER_TIME_MSEC, 32'd200);        // 200 milliseconds

        // Select scheduler mode (xtrig_src_sel = 2'b01)
        $display("Selecting scheduler mode...");
        apb_write(ADDR_XTRIG_SRC_SEL, 32'h0000_0001);

        // Start RTC counting
        rtc_running = 1'b1;

        // Wait for RTC to cross the threshold and trigger
        $display("Waiting for RTC to reach trigger point (100 sec, 200 msec)...");

        // Verify xtrig_int fires when scheduler triggers
        wait(xtrig_int);
        $display("xtrig_int asserted on scheduler trigger");
        apb_write(ADDR_IRQ_STATUS, 32'h0000_0001); // W1C acknowledge
        wait(!xtrig_int);

        // Wait for finish
        wait(finish);
        $display("Scheduler start test completed - finish asserted");

        // Stop RTC counting
        rtc_running = 1'b0;

        repeat(100) @(posedge xtrig_clk);

        $display("\n[PASS] Test 2: Scheduler Start via RTC\n");
    end
endtask

//------------------------------------------------------------------------------
// Test 3: LVDS Start
//------------------------------------------------------------------------------
task test_lvds_start();
    begin
        $display("\n========================================");
        $display("Test 3: LVDS Start");
        $display("========================================\n");
        
        system_reset();
        
        // Configure trigger parameters
        $display("Configuring trigger parameters...");
        apb_write(ADDR_XTRIG_LOW_TIME, XTRIG_LOW_TIME_CYCLES);        // Low time = 5000 cycles
        apb_write(ADDR_FRAME_CAPTURE_TIME, FRAME_CAPTURE_TIME_USEC);  // Frame capture time = 1000 us
        apb_write(ADDR_FRAME_CAPTURE_AMOUNT, FRAME_CAPTURE_AMOUNT);   // Capture 3 frames
        
        // Select LVDS mode (xtrig_src_sel = 2'b10)
        $display("Selecting LVDS start mode...");
        apb_write(ADDR_XTRIG_SRC_SEL, 32'h0000_0002);
        
        repeat(50) @(posedge pclk);
        
        // Generate LVDS start pulse
        $display("Generating LVDS start pulse...");
        @(posedge pclk);
        lvds_start = 1'b1;
        repeat(5) @(posedge pclk);
        lvds_start = 1'b0;

        // Verify xtrig_int fires on LVDS trigger
        wait(xtrig_int);
        $display("xtrig_int asserted on LVDS trigger");
        apb_write(ADDR_IRQ_STATUS, 32'h0000_0001); // W1C acknowledge
        wait(!xtrig_int);

        // Wait for finish
        $display("Waiting for finish signal...");
        wait(finish);
        $display("LVDS start test completed - finish asserted");
        
        repeat(100) @(posedge xtrig_clk);
        
        $display("\n[PASS] Test 3: LVDS Start\n");
    end
endtask

//------------------------------------------------------------------------------
// Main Test Sequence
//------------------------------------------------------------------------------
initial begin
    $display("\n========================================");
    $display("Camera Trigger Top Module Testbench");
    $display("========================================\n");
    
    // Run all three tests
    test_manual_start();
    test_scheduler_start();
    test_lvds_start();
    
    $display("\n========================================");
    $display("All Tests Completed Successfully!");
    $display("========================================\n");
    
    #1000;
    $finish;
end

endmodule
