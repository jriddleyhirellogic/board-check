/*
 * @file      image_metadata_top_tb.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      02/05/2026
 *
 * @brief     Testbench for image_metadata_top module
 *
 * @section changelog
 * - 02/05/2026: Saba Janamian - Initial implementation
 * - 02/10/2026: Saba Janamian - Updated for 20-register metadata format and CRC32
 * - 08/18/2026: Steven Knyazher - Updated for cam_tout based exposure time
 *                                 measurement and expo_time_valid triggering
 */

`timescale 1ns/1ps

module image_metadata_top_tb;

//------------------------------------------------------------------------------
// Parameters
//------------------------------------------------------------------------------
localparam integer APB_DATA_WIDTH              = 32;
localparam integer APB_ADDR_WIDTH              = 32;
localparam integer CAM_DATA_WIDTH              = 384;
localparam integer METADATA_WIDTH              = 640;
localparam integer CLOCK_FREQ_MHZ              = 50;
localparam integer EXPO_TIME_WIDTH             = 22;
localparam integer FRAME_CAPTURE_TIME_WIDTH    = 24;
localparam integer FRAME_CAPTURE_AMOUNT_WIDTH  = 10;
localparam integer DDR4_8GB_FRAME_INDEX_WIDTH  = 8;
localparam integer DDR4_16GB_FRAME_INDEX_WIDTH = 9;

// Number of pclk cycles per microsecond, must match the RTL derivation
localparam integer CYCLES_PER_US = CLOCK_FREQ_MHZ;

// Clock periods
localparam real PCLK_PERIOD      = 20.00;   // 50 MHz APB clock
localparam real PIXEL_CLK_PERIOD = 12.626;  // ~79.2 MHz pixel clock

// Camera timing parameters
// 100µs blanking period before first line_valid (realistic camera behavior)
// 100,000ns / 12.626ns ≈ 7920 cycles
localparam integer FRAME_TO_LINE_DELAY_CYCLES = 7920;

// APB register addresses (byte addresses, word-aligned)
// Matches image_metadata_apb_reg.sv register map
localparam integer ADDR_METADATA_START_FLAG       = 'h00; // RO
localparam integer ADDR_METADATA_SIZE_BYTES       = 'h04; // RO
localparam integer ADDR_SENSOR_PXL_READOUT_FORMAT = 'h08; // RW
localparam integer ADDR_SENSOR_READ_DIR           = 'h0C; // RW
localparam integer ADDR_SENSOR_BIT_DEPTH          = 'h10; // RO
localparam integer ADDR_SENSOR_GAIN               = 'h14; // RW
localparam integer ADDR_SENSOR_BLO                = 'h18; // RW
localparam integer ADDR_SENSOR_EXPO_USEC          = 'h1C; // RO
localparam integer ADDR_SENSOR_TRIG_MODE          = 'h20; // RO
localparam integer ADDR_SENSOR_TEMP_RAW           = 'h24; // RW
localparam integer ADDR_BUFF_WRITE_INDEX          = 'h28; // RO
localparam integer ADDR_FOCUS_REQ_DIST_M          = 'h2C; // RW
localparam integer ADDR_FOCUS_COMP_DIST_M         = 'h30; // RW
localparam integer ADDR_FOCUS_LVDT_POS_NM         = 'h34; // RW
localparam integer ADDR_TIMESTAMP_UNIX_EPOCH_SEC  = 'h38; // RO
localparam integer ADDR_TIMESTAMP_SUBSEC_NSEC     = 'h3C; // RO
localparam integer ADDR_VERSION                   = 'h40; // RW
localparam integer ADDR_RESERVED_PADDING0         = 'h44; // RO
localparam integer ADDR_RESERVED_PADDING1         = 'h48; // RO
localparam integer ADDR_METADATA_CRC32            = 'h4C; // RO

//------------------------------------------------------------------------------
// Signals
//------------------------------------------------------------------------------
// Clocks and resets
logic                                  pixel_clk;
logic                                  pixel_rst_n;
logic                                  pclk;
logic                                  presetn;

// APB interface
logic                                  penable;
logic                                  psel;
logic [APB_ADDR_WIDTH-1:0]             paddr;
logic                                  pwrite;
logic [APB_DATA_WIDTH-1:0]             pwdata;
logic [APB_DATA_WIDTH-1:0]             prdata;
logic                                  pready;
logic                                  pslverr;

// Timestamp inputs
logic [31:0]                           timestamp_sec;
logic [31:0]                           timestamp_nsec;

// Trigger info inputs
logic [1:0]                            trig_mode;
logic                                  cam_tout;
logic [FRAME_CAPTURE_TIME_WIDTH-1:0]   frame_capture_time;
logic [FRAME_CAPTURE_AMOUNT_WIDTH-1:0] frame_capture_amount;

// DDR4 buffer space index inputs
logic                                  cam_mux_select;
logic [DDR4_8GB_FRAME_INDEX_WIDTH-1:0] ddr4_8gb_frame_index;
logic [DDR4_16GB_FRAME_INDEX_WIDTH-1:0] ddr4_16gb_frame_index;

// Camera input signals
logic                                  frame_valid_in;
logic                                  line_valid_in;
logic [CAM_DATA_WIDTH-1:0]             cam_data_in;

// Camera output signals
logic                                  frame_valid_out;
logic                                  line_valid_out;
logic [CAM_DATA_WIDTH-1:0]             cam_data_out;

// Test variables
logic [APB_DATA_WIDTH-1:0]             read_data;
integer                                test_pass_count;
integer                                test_fail_count;

// Expected RW register values (distinct DEADBEE* patterns)
localparam logic [31:0] EXP_SENSOR_PXL_READOUT_FORMAT = 32'hDEADBEE0;
localparam logic [31:0] EXP_SENSOR_READ_DIR           = 32'hDEADBEE1;
localparam logic [31:0] EXP_SENSOR_GAIN               = 32'hDEADBEE2;
localparam logic [31:0] EXP_SENSOR_BLO                = 32'hDEADBEE3;
localparam logic [31:0] EXP_SENSOR_TEMP_RAW           = 32'hDEADBEE4;
localparam logic [31:0] EXP_FOCUS_REQ_DIST_M          = 32'hDEADBEE5;
localparam logic [31:0] EXP_FOCUS_COMP_DIST_M         = 32'hDEADBEE6;
localparam logic [31:0] EXP_FOCUS_LVDT_POS_NM         = 32'hDEADBEE7;
localparam logic [31:0] EXP_VERSION                   = 32'hDEADBEE8;

// Expected RO input-driven values
localparam logic [31:0] EXP_TIMESTAMP_SEC             = 32'hDEADBEE9;
localparam logic [31:0] EXP_TIMESTAMP_NSEC            = 32'hDEADBEEA;

// Hardware input expected values (limited by bit widths)
// Exposure time is measured by the DUT as the cam_tout low duration, so the
// testbench drives cam_tout low for exactly this many microseconds.
localparam integer      EXP_EXPO_TIME_US              = 25;
localparam integer      EXP_EXPO_TIME_US_UPDATED      = 40;
localparam logic [1:0]  EXP_TRIG_MODE                 = 2'b00;
localparam logic [7:0]  EXP_DDR4_8GB_FRAME_INDEX      = 8'hE8;
localparam logic [8:0]  EXP_DDR4_16GB_FRAME_INDEX     = 9'h1E9;

// Expected metadata chunks
logic [CAM_DATA_WIDTH-1:0] expected_metadata_chunk0;
logic [CAM_DATA_WIDTH-1:0] expected_metadata_chunk1;

// Captured output for assertion
logic [CAM_DATA_WIDTH-1:0] captured_chunk0;
logic [CAM_DATA_WIDTH-1:0] captured_chunk1;
logic                      chunk0_captured;
logic                      chunk1_captured;
integer                    metadata_insert_count;

//------------------------------------------------------------------------------
// CRC32 functions (mirrors RTL for verification)
//------------------------------------------------------------------------------

// CRC32 over a single byte (IEEE 802.3, reflected polynomial 0xEDB88320)
function automatic logic [31:0] tb_crc32_byte(
    input logic [31:0] crc_in,
    input logic [7:0]  data_byte
);
    logic [31:0] crc;
    crc = crc_in ^ {24'b0, data_byte};
    for (int i = 0; i < 8; i++) begin
        if (crc[0])
            crc = (crc >> 1) ^ 32'hEDB88320;
        else
            crc = crc >> 1;
    end
    return crc;
endfunction

// CRC32 over a 32-bit word (little-endian byte order)
function automatic logic [31:0] tb_crc32_word(
    input logic [31:0] crc_in,
    input logic [31:0] data_word
);
    logic [31:0] crc;
    crc = tb_crc32_byte(crc_in, data_word[7:0]);
    crc = tb_crc32_byte(crc,    data_word[15:8]);
    crc = tb_crc32_byte(crc,    data_word[23:16]);
    crc = tb_crc32_byte(crc,    data_word[31:24]);
    return crc;
endfunction

//------------------------------------------------------------------------------
// DUT instantiation
//------------------------------------------------------------------------------
image_metadata_top #(
    .APB_DATA_WIDTH              (APB_DATA_WIDTH             ),
    .APB_ADDR_WIDTH              (APB_ADDR_WIDTH             ),
    .CAM_DATA_WIDTH              (CAM_DATA_WIDTH             ),
    .METADATA_WIDTH              (METADATA_WIDTH             ),
    .CLOCK_FREQ_MHZ              (CLOCK_FREQ_MHZ             ),
    .EXPO_TIME_WIDTH             (EXPO_TIME_WIDTH            ),
    .FRAME_CAPTURE_TIME_WIDTH    (FRAME_CAPTURE_TIME_WIDTH   ),
    .FRAME_CAPTURE_AMOUNT_WIDTH  (FRAME_CAPTURE_AMOUNT_WIDTH ),
    .DDR4_8GB_FRAME_INDEX_WIDTH  (DDR4_8GB_FRAME_INDEX_WIDTH ),
    .DDR4_16GB_FRAME_INDEX_WIDTH (DDR4_16GB_FRAME_INDEX_WIDTH)
) dut (
    .pixel_clk           (pixel_clk          ),
    .pixel_rst_n         (pixel_rst_n        ),
    .pclk                (pclk               ),
    .presetn             (presetn            ),
    .penable             (penable            ),
    .psel                (psel               ),
    .paddr               (paddr              ),
    .pwrite              (pwrite             ),
    .pwdata              (pwdata             ),
    .prdata              (prdata             ),
    .pready              (pready             ),
    .pslverr             (pslverr            ),
    .timestamp_sec       (timestamp_sec      ),
    .timestamp_nsec      (timestamp_nsec     ),
    .trig_mode           (trig_mode          ),
    .cam_tout            (cam_tout           ),
    .frame_capture_time  (frame_capture_time ),
    .frame_capture_amount(frame_capture_amount),
    .cam_mux_select      (cam_mux_select     ),
    .ddr4_8gb_frame_index(ddr4_8gb_frame_index),
    .ddr4_16gb_frame_index(ddr4_16gb_frame_index),
    .frame_valid_in      (frame_valid_in     ),
    .line_valid_in       (line_valid_in      ),
    .cam_data_in         (cam_data_in        ),
    .frame_valid_out     (frame_valid_out    ),
    .line_valid_out      (line_valid_out     ),
    .cam_data_out        (cam_data_out       )
);

//------------------------------------------------------------------------------
// Clock generation
//------------------------------------------------------------------------------
initial begin
    pclk = 1'b0;
    forever #(PCLK_PERIOD/2) pclk = ~pclk;
end

initial begin
    pixel_clk = 1'b0;
    forever #(PIXEL_CLK_PERIOD/2) pixel_clk = ~pixel_clk;
end

//------------------------------------------------------------------------------
// APB Tasks
//------------------------------------------------------------------------------
task apb_write(input [APB_ADDR_WIDTH-1:0] addr, input [APB_DATA_WIDTH-1:0] data);
    begin
        @(posedge pclk);
        psel    <= 1'b1;
        pwrite  <= 1'b1;
        paddr   <= addr;
        pwdata  <= data;
        penable <= 1'b0;

        @(posedge pclk);
        penable <= 1'b1;

        @(posedge pclk);
        while (!pready) @(posedge pclk);

        @(posedge pclk);
        psel    <= 1'b0;
        penable <= 1'b0;
        pwrite  <= 1'b0;
        paddr   <= 'b0;
        pwdata  <= 'b0;
    end
endtask

task apb_read(input [APB_ADDR_WIDTH-1:0] addr, output [APB_DATA_WIDTH-1:0] data);
    begin
        @(posedge pclk);
        psel    <= 1'b1;
        pwrite  <= 1'b0;
        paddr   <= addr;
        penable <= 1'b0;

        @(posedge pclk);
        penable <= 1'b1;

        @(posedge pclk);
        while (!pready) @(posedge pclk);
        data = prdata;

        @(posedge pclk);
        psel    <= 1'b0;
        penable <= 1'b0;
        paddr   <= 'b0;
    end
endtask

//------------------------------------------------------------------------------
// Camera simulation tasks
//------------------------------------------------------------------------------
// Drives cam_tout low for exactly expo_us microseconds. The DUT measures this
// low duration and reports it (rounded to the nearest microsecond) in the
// SENSOR_EXPO_USEC register, asserting expo_time_valid on the rising edge.
task do_exposure(input integer expo_us);
    begin
        @(posedge pclk);
        cam_tout <= 1'b0;
        $display("[CAM] cam_tout low (exposure start) at time %0t", $time);

        repeat(expo_us * CYCLES_PER_US) @(posedge pclk);

        cam_tout <= 1'b1;
        $display("[CAM] cam_tout high (exposure end, %0d us) at time %0t",
                 expo_us, $time);

        // Allow the measurement to latch and expo_time_valid to propagate
        repeat(10) @(posedge pclk);
    end
endtask

// Simulates realistic camera timing:
// - ~100µs delay from frame_valid to first line_valid (blanking period)
// - During this blanking period, metadata is injected by the DUT
// - Camera does NOT assert line_valid during blanking, only DUT does for metadata
task send_frame(input integer num_lines, input integer pixels_per_line);
    integer line_idx, pixel_idx;
    begin
        // Start frame
        @(posedge pixel_clk);
        frame_valid_in <= 1'b1;
        $display("[CAM] frame_valid_in asserted at time %0t", $time);

        // Camera blanking period (~100µs) - metadata injection happens here
        // The DUT will inject metadata during this time using its own line_valid_out
        // The camera's line_valid_in stays LOW during this period
        repeat(FRAME_TO_LINE_DELAY_CYCLES) @(posedge pixel_clk);
        $display("[CAM] Blanking period complete at time %0t, starting line data", $time);

        // Send lines (actual camera pixel data)
        for (line_idx = 0; line_idx < num_lines; line_idx = line_idx + 1) begin
            @(posedge pixel_clk);
            line_valid_in <= 1'b1;

            for (pixel_idx = 0; pixel_idx < pixels_per_line; pixel_idx = pixel_idx + 1) begin
                cam_data_in <= {384{1'b0}} | ((line_idx << 16) | pixel_idx);
                @(posedge pixel_clk);
            end

            line_valid_in <= 1'b0;
            cam_data_in   <= 'b0;

            // Horizontal blanking between lines
            repeat(100) @(posedge pixel_clk);
        end

        // End frame
        @(posedge pixel_clk);
        frame_valid_in <= 1'b0;
        $display("[CAM] frame_valid_in deasserted at time %0t", $time);

        // Vertical blanking between frames
        repeat(500) @(posedge pixel_clk);
    end
endtask

//------------------------------------------------------------------------------
// Check task
//------------------------------------------------------------------------------
task check_value(input string name, input [31:0] expected, input [31:0] actual);
    begin
        if (expected == actual) begin
            $display("[PASS] %s: Expected 0x%08h, Got 0x%08h", name, expected, actual);
            test_pass_count++;
        end else begin
            $display("[FAIL] %s: Expected 0x%08h, Got 0x%08h", name, expected, actual);
            test_fail_count++;
        end
    end
endtask

//------------------------------------------------------------------------------
// Main test sequence
//------------------------------------------------------------------------------
initial begin
    // Initialize signals
    presetn             = 1'b0;
    pixel_rst_n         = 1'b0;
    penable             = 1'b0;
    psel                = 1'b0;
    paddr               = 'b0;
    pwrite              = 1'b0;
    pwdata              = 'b0;
    timestamp_sec       = EXP_TIMESTAMP_SEC;
    timestamp_nsec      = EXP_TIMESTAMP_NSEC;
    trig_mode           = EXP_TRIG_MODE;
    cam_tout            = 1'b1;  // Idles high, goes low during exposure
    frame_capture_time  = 'b0;
    frame_capture_amount= 'b0;
    cam_mux_select      = 1'b0;  // DDR4 8GB
    ddr4_8gb_frame_index= EXP_DDR4_8GB_FRAME_INDEX;
    ddr4_16gb_frame_index= EXP_DDR4_16GB_FRAME_INDEX;
    frame_valid_in      = 1'b0;
    line_valid_in       = 1'b0;
    cam_data_in         = 'b0;
    test_pass_count     = 0;
    test_fail_count     = 0;
    chunk0_captured     = 1'b0;
    chunk1_captured     = 1'b0;
    captured_chunk0     = 'b0;
    captured_chunk1     = 'b0;

    // Release reset
    #100;
    presetn     = 1'b1;
    pixel_rst_n = 1'b1;
    #100;

    $display("========================================");
    $display("Starting Image Metadata Top Testbench");
    $display("========================================");

    //--------------------------------------------------------------------------
    // Test 0: Exposure time measurement from cam_tout low duration
    //--------------------------------------------------------------------------
    $display("\n--- Test 0: Exposure Time Measurement (cam_tout) ---");

    do_exposure(EXP_EXPO_TIME_US);

    apb_read(ADDR_SENSOR_EXPO_USEC, read_data);
    check_value("SENSOR_EXPO_USEC (measured)", EXP_EXPO_TIME_US, read_data);

    //--------------------------------------------------------------------------
    // Test 1: APB Write/Read to RW registers (DEADBEE* patterns)
    //--------------------------------------------------------------------------
    $display("\n--- Test 1: APB Write/Read Tests (DEADBEE* patterns) ---");

    apb_write(ADDR_SENSOR_PXL_READOUT_FORMAT, EXP_SENSOR_PXL_READOUT_FORMAT);
    apb_read(ADDR_SENSOR_PXL_READOUT_FORMAT, read_data);
    check_value("SENSOR_PXL_READOUT_FORMAT", EXP_SENSOR_PXL_READOUT_FORMAT, read_data);

    apb_write(ADDR_SENSOR_READ_DIR, EXP_SENSOR_READ_DIR);
    apb_read(ADDR_SENSOR_READ_DIR, read_data);
    check_value("SENSOR_READ_DIR", EXP_SENSOR_READ_DIR, read_data);

    apb_write(ADDR_SENSOR_GAIN, EXP_SENSOR_GAIN);
    apb_read(ADDR_SENSOR_GAIN, read_data);
    check_value("SENSOR_GAIN", EXP_SENSOR_GAIN, read_data);

    apb_write(ADDR_SENSOR_BLO, EXP_SENSOR_BLO);
    apb_read(ADDR_SENSOR_BLO, read_data);
    check_value("SENSOR_BLO", EXP_SENSOR_BLO, read_data);

    apb_write(ADDR_SENSOR_TEMP_RAW, EXP_SENSOR_TEMP_RAW);
    apb_read(ADDR_SENSOR_TEMP_RAW, read_data);
    check_value("SENSOR_TEMP_RAW", EXP_SENSOR_TEMP_RAW, read_data);

    apb_write(ADDR_FOCUS_REQ_DIST_M, EXP_FOCUS_REQ_DIST_M);
    apb_read(ADDR_FOCUS_REQ_DIST_M, read_data);
    check_value("FOCUS_REQ_DIST_M", EXP_FOCUS_REQ_DIST_M, read_data);

    apb_write(ADDR_FOCUS_COMP_DIST_M, EXP_FOCUS_COMP_DIST_M);
    apb_read(ADDR_FOCUS_COMP_DIST_M, read_data);
    check_value("FOCUS_COMP_DIST_M", EXP_FOCUS_COMP_DIST_M, read_data);

    apb_write(ADDR_FOCUS_LVDT_POS_NM, EXP_FOCUS_LVDT_POS_NM);
    apb_read(ADDR_FOCUS_LVDT_POS_NM, read_data);
    check_value("FOCUS_LVDT_POS_NM", EXP_FOCUS_LVDT_POS_NM, read_data);

    apb_write(ADDR_VERSION, EXP_VERSION);
    apb_read(ADDR_VERSION, read_data);
    check_value("VERSION", EXP_VERSION, read_data);

    //--------------------------------------------------------------------------
    // Test 2: Read-only registers (FPGA updated)
    //--------------------------------------------------------------------------
    $display("\n--- Test 2: Read-only Register Tests ---");

    apb_read(ADDR_METADATA_START_FLAG, read_data);
    check_value("METADATA_START_FLAG", 32'h4D455441, read_data);

    apb_read(ADDR_METADATA_SIZE_BYTES, read_data);
    check_value("METADATA_SIZE_BYTES", 32'd80, read_data);

    apb_read(ADDR_SENSOR_BIT_DEPTH, read_data);
    check_value("SENSOR_BIT_DEPTH", 32'h0, read_data);

    apb_read(ADDR_SENSOR_EXPO_USEC, read_data);
    check_value("SENSOR_EXPO_USEC", EXP_EXPO_TIME_US, read_data);

    apb_read(ADDR_SENSOR_TRIG_MODE, read_data);
    check_value("SENSOR_TRIG_MODE", {30'b0, EXP_TRIG_MODE}, read_data);

    // Frame buffer index (8GB mode)
    apb_read(ADDR_BUFF_WRITE_INDEX, read_data);
    check_value("BUFF_WRITE_INDEX (8GB)", {24'h000002, EXP_DDR4_8GB_FRAME_INDEX}, read_data);

    apb_read(ADDR_TIMESTAMP_UNIX_EPOCH_SEC, read_data);
    check_value("TIMESTAMP_UNIX_EPOCH_SEC", EXP_TIMESTAMP_SEC, read_data);

    apb_read(ADDR_TIMESTAMP_SUBSEC_NSEC, read_data);
    check_value("TIMESTAMP_SUBSEC_NSEC", EXP_TIMESTAMP_NSEC, read_data);

    apb_read(ADDR_RESERVED_PADDING0, read_data);
    check_value("RESERVED_PADDING0", 32'h0, read_data);

    apb_read(ADDR_RESERVED_PADDING1, read_data);
    check_value("RESERVED_PADDING1", 32'h0, read_data);

    //--------------------------------------------------------------------------
    // Test 3: Switch to 16GB DDR4 and verify frame index
    //--------------------------------------------------------------------------
    $display("\n--- Test 3: DDR4 16GB Frame Index ---");
    cam_mux_select = 1'b1;  // Switch to 16GB
    repeat(5) @(posedge pclk);

    apb_read(ADDR_BUFF_WRITE_INDEX, read_data);
    check_value("BUFF_WRITE_INDEX (16GB)", {23'b0, EXP_DDR4_16GB_FRAME_INDEX}, read_data);

    // Switch back to 8GB for remaining tests
    cam_mux_select = 1'b0;
    repeat(5) @(posedge pclk);

    //--------------------------------------------------------------------------
    // Test 4: CRC32 verification
    //--------------------------------------------------------------------------
    $display("\n--- Test 4: CRC32 Verification ---");

    begin : test4_crc
        logic [31:0] expected_crc;
        logic [31:0] crc;

        // Wait for CRC to settle after all register writes
        repeat(5) @(posedge pclk);

        // Compute expected CRC32 over mem[1] through mem[18]
        crc = 32'hFFFFFFFF;
        crc = tb_crc32_word(crc, 32'd80);                                    // mem[1]  METADATA_SIZE_BYTES
        crc = tb_crc32_word(crc, EXP_SENSOR_PXL_READOUT_FORMAT);             // mem[2]
        crc = tb_crc32_word(crc, EXP_SENSOR_READ_DIR);                       // mem[3]
        crc = tb_crc32_word(crc, 32'h0);                                     // mem[4]  SENSOR_BIT_DEPTH
        crc = tb_crc32_word(crc, EXP_SENSOR_GAIN);                           // mem[5]
        crc = tb_crc32_word(crc, EXP_SENSOR_BLO);                            // mem[6]
        crc = tb_crc32_word(crc, EXP_EXPO_TIME_US);                         // mem[7]  SENSOR_EXPO_USEC
        crc = tb_crc32_word(crc, {30'b0, EXP_TRIG_MODE});                   // mem[8]  SENSOR_TRIG_MODE
        crc = tb_crc32_word(crc, EXP_SENSOR_TEMP_RAW);                      // mem[9]
        crc = tb_crc32_word(crc, {24'h000002, EXP_DDR4_8GB_FRAME_INDEX});   // mem[10] BUFF_WRITE_INDEX
        crc = tb_crc32_word(crc, EXP_FOCUS_REQ_DIST_M);                     // mem[11]
        crc = tb_crc32_word(crc, EXP_FOCUS_COMP_DIST_M);                    // mem[12]
        crc = tb_crc32_word(crc, EXP_FOCUS_LVDT_POS_NM);                    // mem[13]
        crc = tb_crc32_word(crc, EXP_TIMESTAMP_SEC);                        // mem[14]
        crc = tb_crc32_word(crc, EXP_TIMESTAMP_NSEC);                       // mem[15]
        crc = tb_crc32_word(crc, EXP_VERSION);                              // mem[16]
        crc = tb_crc32_word(crc, 32'h0);                                    // mem[17] RESERVED_PADDING0
        crc = tb_crc32_word(crc, 32'h0);                                    // mem[18] RESERVED_PADDING1
        expected_crc = crc ^ 32'hFFFFFFFF;

        apb_read(ADDR_METADATA_CRC32, read_data);
        check_value("METADATA_CRC32", expected_crc, read_data);
        $display("[INFO] Expected CRC32: 0x%08h", expected_crc);
    end

    //--------------------------------------------------------------------------
    // Test 5: Frame capture with metadata injection
    //--------------------------------------------------------------------------
    $display("\n--- Test 5: Frame Capture with Metadata Injection ---");

    // Calculate expected metadata chunks
    // Metadata layout (640 bits = 20 x 32-bit registers):
    // mem[0]  = METADATA_START_FLAG          -> bits [31:0]
    // mem[1]  = METADATA_SIZE_BYTES          -> bits [63:32]
    // mem[2]  = SENSOR_PXL_READOUT_FORMAT    -> bits [95:64]
    // mem[3]  = SENSOR_READ_DIR              -> bits [127:96]
    // mem[4]  = SENSOR_BIT_DEPTH             -> bits [159:128]
    // mem[5]  = SENSOR_GAIN                  -> bits [191:160]
    // mem[6]  = SENSOR_BLO                   -> bits [223:192]
    // mem[7]  = SENSOR_EXPO_USEC             -> bits [255:224]
    // mem[8]  = SENSOR_TRIG_MODE             -> bits [287:256]
    // mem[9]  = SENSOR_TEMP_RAW              -> bits [319:288]
    // mem[10] = BUFF_WRITE_INDEX             -> bits [351:320]
    // mem[11] = FOCUS_REQ_DIST_M             -> bits [383:352]
    // mem[12] = FOCUS_COMP_DIST_M            -> bits [415:384]
    // mem[13] = FOCUS_LVDT_POS_NM            -> bits [447:416]
    // mem[14] = TIMESTAMP_UNIX_EPOCH_SEC     -> bits [479:448]
    // mem[15] = TIMESTAMP_SUBSEC_NSEC        -> bits [511:480]
    // mem[16] = VERSION                      -> bits [543:512]
    // mem[17] = RESERVED_PADDING0            -> bits [575:544]
    // mem[18] = RESERVED_PADDING1            -> bits [607:576]
    // mem[19] = METADATA_CRC32               -> bits [639:608]
    //
    // Chunk 0: metadata[0 +: 384] = bits [383:0]   = {mem[11], ..., mem[0]}
    // Chunk 1: {128'b0, metadata[384 +: 256]} = {128'b0, mem[19], ..., mem[12]}

    begin : test5_metadata
        logic [31:0] expected_crc;
        logic [31:0] crc;

        // Compute CRC for expected metadata
        crc = 32'hFFFFFFFF;
        crc = tb_crc32_word(crc, 32'd80);
        crc = tb_crc32_word(crc, EXP_SENSOR_PXL_READOUT_FORMAT);
        crc = tb_crc32_word(crc, EXP_SENSOR_READ_DIR);
        crc = tb_crc32_word(crc, 32'h0);
        crc = tb_crc32_word(crc, EXP_SENSOR_GAIN);
        crc = tb_crc32_word(crc, EXP_SENSOR_BLO);
        crc = tb_crc32_word(crc, EXP_EXPO_TIME_US);
        crc = tb_crc32_word(crc, {30'b0, EXP_TRIG_MODE});
        crc = tb_crc32_word(crc, EXP_SENSOR_TEMP_RAW);
        crc = tb_crc32_word(crc, {24'h000002, EXP_DDR4_8GB_FRAME_INDEX});
        crc = tb_crc32_word(crc, EXP_FOCUS_REQ_DIST_M);
        crc = tb_crc32_word(crc, EXP_FOCUS_COMP_DIST_M);
        crc = tb_crc32_word(crc, EXP_FOCUS_LVDT_POS_NM);
        crc = tb_crc32_word(crc, EXP_TIMESTAMP_SEC);
        crc = tb_crc32_word(crc, EXP_TIMESTAMP_NSEC);
        crc = tb_crc32_word(crc, EXP_VERSION);
        crc = tb_crc32_word(crc, 32'h0);
        crc = tb_crc32_word(crc, 32'h0);
        expected_crc = crc ^ 32'hFFFFFFFF;

        expected_metadata_chunk0 = {
            EXP_FOCUS_REQ_DIST_M,                        // mem[11] bits [383:352]
            {24'h000002, EXP_DDR4_8GB_FRAME_INDEX},      // mem[10] bits [351:320]
            EXP_SENSOR_TEMP_RAW,                         // mem[9]  bits [319:288]
            {30'b0, EXP_TRIG_MODE},                      // mem[8]  bits [287:256]
            EXP_EXPO_TIME_US,                            // mem[7]  bits [255:224]
            EXP_SENSOR_BLO,                              // mem[6]  bits [223:192]
            EXP_SENSOR_GAIN,                             // mem[5]  bits [191:160]
            32'h0,                                       // mem[4]  bits [159:128] SENSOR_BIT_DEPTH
            EXP_SENSOR_READ_DIR,                         // mem[3]  bits [127:96]
            EXP_SENSOR_PXL_READOUT_FORMAT,               // mem[2]  bits [95:64]
            32'd80,                                      // mem[1]  bits [63:32]  METADATA_SIZE_BYTES
            32'h4D455441                                 // mem[0]  bits [31:0]   METADATA_START_FLAG
        };

        expected_metadata_chunk1 = {
            128'b0,                                      // Zero padding [383:256]
            expected_crc,                                // mem[19] bits [255:224] METADATA_CRC32
            32'b0,                                       // mem[18] bits [223:192] RESERVED_PADDING1
            32'b0,                                       // mem[17] bits [191:160] RESERVED_PADDING0
            EXP_VERSION,                                 // mem[16] bits [159:128]
            EXP_TIMESTAMP_NSEC,                          // mem[15] bits [127:96]
            EXP_TIMESTAMP_SEC,                           // mem[14] bits [95:64]
            EXP_FOCUS_LVDT_POS_NM,                       // mem[13] bits [63:32]
            EXP_FOCUS_COMP_DIST_M                        // mem[12] bits [31:0]
        };

        $display("[INFO] Expected Chunk 0: 0x%096h", expected_metadata_chunk0);
        $display("[INFO] Expected Chunk 1: 0x%096h", expected_metadata_chunk1);
    end

    // Wait for stable state
    repeat(20) @(posedge pixel_clk);

    // Reset capture flags
    chunk0_captured = 1'b0;
    chunk1_captured = 1'b0;
    metadata_insert_count = 0;

    // Fork to monitor outputs while sending frame
    fork
        begin : frame_sender
            send_frame(5, 10);  // Small frame: 5 lines, 10 pixels each
        end

        begin : output_monitor
            // Wait for frame_valid_out rising edge
            @(posedge frame_valid_out);
            $display("[MON] frame_valid_out asserted at time %0t", $time);

            // Metadata insertion is triggered by expo_time_valid (cam_tout back
            // high), and is signalled by the DUT driving line_valid_out while
            // the camera's line_valid_in is still low (blanking period).
            // Each insertion is two back-to-back chunks.
            while (frame_valid_out) begin
                @(posedge pixel_clk);

                if (line_valid_out && !line_valid_in) begin
                    metadata_insert_count++;

                    if (!chunk0_captured) begin
                        captured_chunk0 = cam_data_out;
                        chunk0_captured = 1'b1;
                        $display("[MON] Captured Metadata Chunk 0 during blanking at time %0t", $time);
                        $display("[MON]   Data: 0x%096h", captured_chunk0);

                        @(posedge pixel_clk);
                        if (line_valid_out && !line_valid_in) begin
                            captured_chunk1 = cam_data_out;
                            chunk1_captured = 1'b1;
                            $display("[MON] Captured Metadata Chunk 1 during blanking at time %0t", $time);
                            $display("[MON]   Data: 0x%096h", captured_chunk1);
                        end
                    end

                    // Skip to the end of this insertion
                    while (line_valid_out && !line_valid_in) @(posedge pixel_clk);
                end
            end

            $display("[MON] Total metadata insertions during frame: %0d", metadata_insert_count);
            $display("[MON] frame_valid_out deasserted at time %0t", $time);
        end
    join

    //--------------------------------------------------------------------------
    // Test 5b: Assert metadata output matches expected values
    //--------------------------------------------------------------------------
    $display("\n--- Test 5b: Metadata Output Assertions ---");

    if (chunk0_captured) begin
        if (captured_chunk0 == expected_metadata_chunk0) begin
            $display("[PASS] Metadata Chunk 0 matches expected value");
            test_pass_count++;
        end else begin
            $display("[FAIL] Metadata Chunk 0 mismatch!");
            $display("       Expected: 0x%096h", expected_metadata_chunk0);
            $display("       Got:      0x%096h", captured_chunk0);
            // Show individual field comparison
            $display("       Field breakdown (Got vs Expected):");
            $display("         mem[0]  START_FLAG:    0x%08h vs 0x%08h", captured_chunk0[31:0], 32'h4D455441);
            $display("         mem[1]  SIZE_BYTES:    0x%08h vs 0x%08h", captured_chunk0[63:32], 32'd80);
            $display("         mem[2]  PXL_READOUT:   0x%08h vs 0x%08h", captured_chunk0[95:64], EXP_SENSOR_PXL_READOUT_FORMAT);
            $display("         mem[3]  READ_DIR:      0x%08h vs 0x%08h", captured_chunk0[127:96], EXP_SENSOR_READ_DIR);
            $display("         mem[4]  BIT_DEPTH:     0x%08h vs 0x%08h", captured_chunk0[159:128], 32'h0);
            $display("         mem[5]  GAIN:          0x%08h vs 0x%08h", captured_chunk0[191:160], EXP_SENSOR_GAIN);
            $display("         mem[6]  BLO:           0x%08h vs 0x%08h", captured_chunk0[223:192], EXP_SENSOR_BLO);
            $display("         mem[7]  EXPO_USEC:     0x%08h vs 0x%08h", captured_chunk0[255:224], EXP_EXPO_TIME_US);
            $display("         mem[8]  TRIG_MODE:     0x%08h vs 0x%08h", captured_chunk0[287:256], {30'b0, EXP_TRIG_MODE});
            $display("         mem[9]  TEMP_RAW:      0x%08h vs 0x%08h", captured_chunk0[319:288], EXP_SENSOR_TEMP_RAW);
            $display("         mem[10] BUFF_IDX:      0x%08h vs 0x%08h", captured_chunk0[351:320], {24'h000002, EXP_DDR4_8GB_FRAME_INDEX});
            $display("         mem[11] FOCUS_REQ:     0x%08h vs 0x%08h", captured_chunk0[383:352], EXP_FOCUS_REQ_DIST_M);
            test_fail_count++;
        end
    end else begin
        $display("[FAIL] Metadata Chunk 0 was not captured!");
        test_fail_count++;
    end

    if (chunk1_captured) begin
        if (captured_chunk1 == expected_metadata_chunk1) begin
            $display("[PASS] Metadata Chunk 1 matches expected value");
            test_pass_count++;
        end else begin
            $display("[FAIL] Metadata Chunk 1 mismatch!");
            $display("       Expected: 0x%096h", expected_metadata_chunk1);
            $display("       Got:      0x%096h", captured_chunk1);
            $display("       Field breakdown (Got vs Expected):");
            $display("         mem[12] FOCUS_COMP:    0x%08h vs 0x%08h", captured_chunk1[31:0], EXP_FOCUS_COMP_DIST_M);
            $display("         mem[13] LVDT_POS:      0x%08h vs 0x%08h", captured_chunk1[63:32], EXP_FOCUS_LVDT_POS_NM);
            $display("         mem[14] TIME_SEC:      0x%08h vs 0x%08h", captured_chunk1[95:64], EXP_TIMESTAMP_SEC);
            $display("         mem[15] TIME_NSEC:     0x%08h vs 0x%08h", captured_chunk1[127:96], EXP_TIMESTAMP_NSEC);
            $display("         mem[16] VERSION:       0x%08h vs 0x%08h", captured_chunk1[159:128], EXP_VERSION);
            $display("         mem[17] PADDING0:      0x%08h vs 0x%08h", captured_chunk1[191:160], 32'h0);
            $display("         mem[18] PADDING1:      0x%08h vs 0x%08h", captured_chunk1[223:192], 32'h0);
            $display("         mem[19] CRC32:         0x%08h", captured_chunk1[255:224]);
            test_fail_count++;
        end
    end else begin
        $display("[FAIL] Metadata Chunk 1 was not captured!");
        test_fail_count++;
    end

    // Metadata must be inserted exactly once (two chunks) per frame
    if (metadata_insert_count == 2) begin
        $display("[PASS] Metadata inserted exactly once per frame (2 chunks)");
        test_pass_count++;
    end else begin
        $display("[FAIL] Metadata inserted %0d chunks in one frame, expected 2",
                 metadata_insert_count);
        test_fail_count++;
    end

    //--------------------------------------------------------------------------
    // Test 6: Multiple frames with updated timestamp
    //--------------------------------------------------------------------------
    $display("\n--- Test 6: Multiple Frames with Updated Timestamp ---");

    // Update timestamp between frames (use new distinct values)
    timestamp_sec  = 32'hCAFEBAB1;
    timestamp_nsec = 32'hCAFEBAB2;

    repeat(100) @(posedge pclk);

    // Send another frame
    send_frame(3, 5);

    //--------------------------------------------------------------------------
    // Test 7: New exposure and verify measured time
    //--------------------------------------------------------------------------
    $display("\n--- Test 7: Updated Exposure Time ---");

    do_exposure(EXP_EXPO_TIME_US_UPDATED);

    apb_read(ADDR_SENSOR_EXPO_USEC, read_data);
    check_value("SENSOR_EXPO_USEC (updated)", EXP_EXPO_TIME_US_UPDATED, read_data);

    //--------------------------------------------------------------------------
    // Test 8: CRC32 updates after register change
    //--------------------------------------------------------------------------
    $display("\n--- Test 8: CRC32 After Register Update ---");

    begin : test8_crc_update
        logic [31:0] expected_crc;
        logic [31:0] crc;

        repeat(5) @(posedge pclk);

        // Recompute expected CRC with updated values
        crc = 32'hFFFFFFFF;
        crc = tb_crc32_word(crc, 32'd80);                                    // mem[1]
        crc = tb_crc32_word(crc, EXP_SENSOR_PXL_READOUT_FORMAT);             // mem[2]
        crc = tb_crc32_word(crc, EXP_SENSOR_READ_DIR);                       // mem[3]
        crc = tb_crc32_word(crc, 32'h0);                                     // mem[4]
        crc = tb_crc32_word(crc, EXP_SENSOR_GAIN);                           // mem[5]
        crc = tb_crc32_word(crc, EXP_SENSOR_BLO);                            // mem[6]
        crc = tb_crc32_word(crc, EXP_EXPO_TIME_US_UPDATED);                 // mem[7]  updated exposure
        crc = tb_crc32_word(crc, {30'b0, EXP_TRIG_MODE});                   // mem[8]
        crc = tb_crc32_word(crc, EXP_SENSOR_TEMP_RAW);                      // mem[9]
        crc = tb_crc32_word(crc, {24'h000002, EXP_DDR4_8GB_FRAME_INDEX});   // mem[10]
        crc = tb_crc32_word(crc, EXP_FOCUS_REQ_DIST_M);                     // mem[11]
        crc = tb_crc32_word(crc, EXP_FOCUS_COMP_DIST_M);                    // mem[12]
        crc = tb_crc32_word(crc, EXP_FOCUS_LVDT_POS_NM);                    // mem[13]
        crc = tb_crc32_word(crc, 32'hCAFEBAB1);                             // mem[14] updated timestamp
        crc = tb_crc32_word(crc, 32'hCAFEBAB2);                             // mem[15] updated timestamp
        crc = tb_crc32_word(crc, EXP_VERSION);                              // mem[16]
        crc = tb_crc32_word(crc, 32'h0);                                    // mem[17]
        crc = tb_crc32_word(crc, 32'h0);                                    // mem[18]
        expected_crc = crc ^ 32'hFFFFFFFF;

        apb_read(ADDR_METADATA_CRC32, read_data);
        check_value("METADATA_CRC32 (after update)", expected_crc, read_data);
        $display("[INFO] Expected CRC32 after update: 0x%08h", expected_crc);
    end

    //--------------------------------------------------------------------------
    // Test Summary
    //--------------------------------------------------------------------------
    #1000;
    $display("\n========================================");
    $display("Test Summary");
    $display("========================================");
    $display("Passed: %0d", test_pass_count);
    $display("Failed: %0d", test_fail_count);

    if (test_fail_count == 0) begin
        $display("\n*** ALL TESTS PASSED ***");
    end else begin
        $display("\n*** SOME TESTS FAILED ***");
    end

    $display("========================================\n");

    $stop;
end

//------------------------------------------------------------------------------
// Timeout watchdog
//------------------------------------------------------------------------------
initial begin
    #5000000;  // 5 ms timeout (accounts for 100µs blanking per frame)
    $display("[ERROR] Simulation timeout!");
    $stop;
end

endmodule
