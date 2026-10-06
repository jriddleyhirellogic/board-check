`timescale 1ns/1ps

module cam_mux_tb;

//------------------------------------------------------------------------------
// Parameters
//------------------------------------------------------------------------------
parameter DATA_WIDTH        = 384;
parameter CLK_PERIOD        = 10;   // 10ns = 100MHz
parameter LINE_VALID_CYCLES = 141;
parameter LINE_BLANK_CYCLES = 200;
parameter LINES_PER_FRAME   = 10;
parameter NUM_FRAMES        = 6;

//------------------------------------------------------------------------------
// DUT Signals
//------------------------------------------------------------------------------
logic                   pixel_clk;
logic                   pixel_rst_n;
logic                   frame_valid_in;
logic                   line_valid_in;
logic [DATA_WIDTH-1:0]  cam_data_in;
logic                   mux_clear;
logic                   mux_enable;
logic                   mux_select;
logic                   ddr4_16gb_full;
logic                   ddr4_8gb_full;
logic                   mux_clear_ack;
logic                   ddr4_8gb_frame_valid_out;
logic                   ddr4_8gb_line_valid_out;
logic [DATA_WIDTH-1:0]  ddr4_8gb_cam_data_out;
logic                   ddr4_16gb_frame_valid_out;
logic                   ddr4_16gb_line_valid_out;
logic [DATA_WIDTH-1:0]  ddr4_16gb_cam_data_out;

//------------------------------------------------------------------------------
// Clock Generation
//------------------------------------------------------------------------------
initial pixel_clk = 0;
always #(CLK_PERIOD/2) pixel_clk = ~pixel_clk;

//------------------------------------------------------------------------------
// DUT Instantiation
//------------------------------------------------------------------------------
cam_mux #(
    .DATA_WIDTH(DATA_WIDTH)
) dut (
    .pixel_clk                (pixel_clk               ),
    .pixel_rst_n              (pixel_rst_n             ),
    .frame_valid_in           (frame_valid_in          ),
    .line_valid_in            (line_valid_in           ),
    .cam_data_in              (cam_data_in             ),
    .mux_clear                (mux_clear               ),
    .mux_enable               (mux_enable              ),
    .mux_select               (mux_select              ),
    .ddr4_16gb_full           (ddr4_16gb_full          ),
    .ddr4_8gb_full            (ddr4_8gb_full           ),
    .mux_clear_ack            (mux_clear_ack           ),
    .ddr4_8gb_frame_valid_out (ddr4_8gb_frame_valid_out),
    .ddr4_8gb_line_valid_out  (ddr4_8gb_line_valid_out ),
    .ddr4_8gb_cam_data_out    (ddr4_8gb_cam_data_out   ),
    .ddr4_16gb_frame_valid_out(ddr4_16gb_frame_valid_out),
    .ddr4_16gb_line_valid_out (ddr4_16gb_line_valid_out ),
    .ddr4_16gb_cam_data_out   (ddr4_16gb_cam_data_out  )
);

//------------------------------------------------------------------------------
// Test Variables
//------------------------------------------------------------------------------
int frame_count;
int line_count;
int pixel_count;
int ddr4_8gb_frame_count;
int ddr4_16gb_frame_count;

logic ddr4_8gb_fv_prev;
logic ddr4_16gb_fv_prev;

always_ff @(posedge pixel_clk) begin
    ddr4_8gb_fv_prev  <= ddr4_8gb_frame_valid_out;
    ddr4_16gb_fv_prev <= ddr4_16gb_frame_valid_out;
    if (ddr4_8gb_frame_valid_out  && !ddr4_8gb_fv_prev)  ddr4_8gb_frame_count++;
    if (ddr4_16gb_frame_valid_out && !ddr4_16gb_fv_prev) ddr4_16gb_frame_count++;
end

task reset_counters();
    @(negedge pixel_clk);
    ddr4_8gb_frame_count  = 0;
    ddr4_16gb_frame_count = 0;
    frame_count           = 0;
    line_count            = 0;
    pixel_count           = 0;
endtask

//------------------------------------------------------------------------------
// Task: Reset
//------------------------------------------------------------------------------
task reset();
    mux_clear       = 0;
    pixel_rst_n     = 0;
    frame_valid_in  = 0;
    line_valid_in   = 0;
    cam_data_in     = 0;
    repeat(10) @(posedge pixel_clk);
    pixel_rst_n = 1;
    repeat(5)  @(posedge pixel_clk);
    $display("[%0t] Reset complete", $time);
endtask

//------------------------------------------------------------------------------
// Task: do_mux_clear — assert mux_clear, complete 4-phase handshake
//------------------------------------------------------------------------------
task do_mux_clear();
    $display("[%0t] Asserting mux_clear", $time);
    @(negedge pixel_clk);
    mux_clear = 1;
    // Wait for cam_mux to ack (rising edge of mux_clear_ack)
    @(posedge mux_clear_ack);
    @(negedge pixel_clk);
    mux_clear = 0;
    // Wait for cam_mux to deassert ack (falling edge)
    @(negedge mux_clear_ack);
    repeat(3) @(posedge pixel_clk);
    $display("[%0t] mux_clear handshake complete", $time);
endtask

//------------------------------------------------------------------------------
// Task: Generate Single Line
//------------------------------------------------------------------------------
task generate_line();
    line_valid_in = 1;
    for (int i = 0; i < LINE_VALID_CYCLES; i++) begin
        cam_data_in = $urandom;
        @(posedge pixel_clk);
        pixel_count++;
    end
    line_valid_in = 0;
    cam_data_in   = 0;
    repeat(LINE_BLANK_CYCLES) @(posedge pixel_clk);
endtask

//------------------------------------------------------------------------------
// Task: Generate Single Frame
//------------------------------------------------------------------------------
task generate_frame();
    frame_valid_in = 1;
    repeat(10) @(posedge pixel_clk);
    for (int i = 0; i < LINES_PER_FRAME; i++) begin
        line_count++;
        generate_line();
    end
    frame_valid_in = 0;
    repeat(200) @(posedge pixel_clk);
    frame_count++;
endtask

//------------------------------------------------------------------------------
// Task: Generate N frames
//------------------------------------------------------------------------------
task generate_frames(input int n, input string label);
    $display("[%0t] Generating %0d frame(s) — %s", $time, n, label);
    for (int i = 0; i < n; i++)
        generate_frame();
    $display("[%0t]   16GB frames: %0d   8GB frames: %0d",
             $time, ddr4_16gb_frame_count, ddr4_8gb_frame_count);
endtask

//------------------------------------------------------------------------------
// Main Test Sequence
//------------------------------------------------------------------------------
initial begin
    $display("==============================================");
    $display("CAM MUX Testbench Started");
    $display("Config: %0d lines/frame, %0d line-valid cycles, %0d frames/test",
             LINES_PER_FRAME, LINE_VALID_CYCLES, NUM_FRAMES);
    $display("==============================================");

    ddr4_8gb_frame_count  = 0;
    ddr4_16gb_frame_count = 0;
    frame_count           = 0;
    line_count            = 0;
    pixel_count           = 0;

    reset();

    // ------------------------------------------------------------------
    // Test 1: MUX disabled — no output before mux_clear
    // ------------------------------------------------------------------
    $display("\n--- Test 1: MUX disabled before mux_clear ---");
    generate_frames(NUM_FRAMES, "expect no output");
    if (ddr4_16gb_frame_count == 0 && ddr4_8gb_frame_count == 0)
        $display("Test 1 PASS");
    else
        $error("Test 1 FAIL: 16GB=%0d  8GB=%0d (expected 0/0)",
               ddr4_16gb_frame_count, ddr4_8gb_frame_count);

    // ------------------------------------------------------------------
    // Test 2: mux_clear handshake — routing starts on DDR4 16GB
    // ------------------------------------------------------------------
    $display("\n--- Test 2: mux_clear handshake + DDR4 16GB routing ---");
    reset_counters();
    do_mux_clear();
    generate_frames(NUM_FRAMES, "expect all 16GB");
    if (ddr4_16gb_frame_count == NUM_FRAMES && ddr4_8gb_frame_count == 0)
        $display("Test 2 PASS");
    else
        $error("Test 2 FAIL: 16GB=%0d (exp %0d)  8GB=%0d (exp 0)",
               ddr4_16gb_frame_count, NUM_FRAMES, ddr4_8gb_frame_count);

    // ------------------------------------------------------------------
    // Test 3: pixel_rst_n cycle preserves frame counter and routing
    // ------------------------------------------------------------------
    $display("\n--- Test 3: pixel_rst_n cycle preserves counter ---");
    begin
        int cnt_before = ddr4_16gb_frame_count;
        $display("[%0t] Cycling pixel_rst_n", $time);
        pixel_rst_n = 0;
        repeat(10) @(posedge pixel_clk);
        pixel_rst_n = 1;
        repeat(5)  @(posedge pixel_clk);
        generate_frames(NUM_FRAMES, "expect routing resumes on 16GB");
        if (ddr4_16gb_frame_count == cnt_before + NUM_FRAMES && ddr4_8gb_frame_count == 0)
            $display("Test 3 PASS");
        else
            $error("Test 3 FAIL: 16GB=%0d (exp %0d)  8GB=%0d (exp 0)",
                   ddr4_16gb_frame_count, cnt_before + NUM_FRAMES, ddr4_8gb_frame_count);
    end

    // ------------------------------------------------------------------
    // Test 4: mux_clear resets counters and restarts from 16GB
    // ------------------------------------------------------------------
    $display("\n--- Test 4: mux_clear resets counters and restarts ---");
    reset_counters();
    do_mux_clear();
    generate_frames(NUM_FRAMES, "fresh run after clear");
    if (ddr4_16gb_frame_count == NUM_FRAMES && ddr4_8gb_frame_count == 0)
        $display("Test 4 PASS");
    else
        $error("Test 4 FAIL: 16GB=%0d (exp %0d)  8GB=%0d (exp 0)",
               ddr4_16gb_frame_count, NUM_FRAMES, ddr4_8gb_frame_count);

    // ------------------------------------------------------------------
    // Test 5: mux_clear mid-frame — FSM drains current frame then resets
    // ------------------------------------------------------------------
    $display("\n--- Test 5: mux_clear mid-frame (frame-safe drain) ---");
    reset_counters();
    do_mux_clear();
    frame_valid_in = 1;
    repeat(10) @(posedge pixel_clk);
    generate_line();
    generate_line();
    $display("[%0t] Issuing mux_clear mid-frame", $time);
    do_mux_clear();
    generate_line();
    frame_valid_in = 0;
    repeat(200) @(posedge pixel_clk);
    reset_counters();
    do_mux_clear();
    generate_frames(NUM_FRAMES, "expect fresh 16GB routing post-drain");
    if (ddr4_16gb_frame_count == NUM_FRAMES && ddr4_8gb_frame_count == 0)
        $display("Test 5 PASS");
    else
        $error("Test 5 FAIL: 16GB=%0d (exp %0d)  8GB=%0d (exp 0)",
               ddr4_16gb_frame_count, NUM_FRAMES, ddr4_8gb_frame_count);

    repeat(100) @(posedge pixel_clk);
    $display("\n==============================================");
    $display("All Tests Complete");
    $display("  Total frames: %0d   Total pixels: %0d", frame_count, pixel_count);
    $display("==============================================");
    $stop;
end

//------------------------------------------------------------------------------
// Timeout Watchdog
//------------------------------------------------------------------------------
initial begin
    #(CLK_PERIOD * 5_000_000);
    $display("ERROR: Testbench timeout!");
    $stop;
end

endmodule
