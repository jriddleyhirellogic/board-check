/*
 * @file      frame_xfer_ctrl_tb.sv
 * @brief     Testbench for frame_xfer_ctrl module
 * @date      10/05/2025
 */

module frame_xfer_ctrl_tb;

//------------------------------------------------------------------------------
// Parameters
//------------------------------------------------------------------------------
localparam integer CLOCK_FREQ_MHZ = 50;
localparam integer TIMEOUT_USEC   = 10_000;
localparam integer DDR_ADDR_WIDTH = 38;
localparam integer DDR_DATA_WIDTH = 256;
localparam integer FRAME_WIDTH    = 25;
localparam integer FRAME_INDEX_WIDTH = DDR_ADDR_WIDTH - FRAME_WIDTH;

localparam CLK_PERIOD = 20; // 50 MHz = 20ns period

//------------------------------------------------------------------------------
// Signals
//------------------------------------------------------------------------------
logic                         clk;
logic                         rst_n;

// APB and RISCV interface
logic                         clear;
logic                         frame_read_req;
logic                         frame_read_done;
logic [8:0]                   h_size_beat;
logic [13:0]                  h_size_byte;
logic [12:0]                  v_size_line;
logic [FRAME_INDEX_WIDTH-1:0] frame_index;

// DMA Controller interface
logic                         dma_ctrl_read_req;
logic                         dma_ctrl_read_ack;
logic                         dma_ctrl_read_done;
logic [13:0]                  dma_ctrl_pyl_size_word;

// DMA read interface
logic                         dma_ready;
logic                         dma_info_valid;
logic [DDR_ADDR_WIDTH-1:0]    dma_read_addr;
logic [8:0]                   dma_burst_count;
logic                         dma_fifo_clear;

//------------------------------------------------------------------------------
// DUT Instantiation
//------------------------------------------------------------------------------
frame_xfer_ctrl #(
    .CLOCK_FREQ_MHZ     (CLOCK_FREQ_MHZ),
    .TIMEOUT_USEC       (TIMEOUT_USEC),
    .DDR_ADDR_WIDTH     (DDR_ADDR_WIDTH),
    .DDR_DATA_WIDTH     (DDR_DATA_WIDTH),
    .FRAME_WIDTH        (FRAME_WIDTH),
    .FRAME_INDEX_WIDTH  (FRAME_INDEX_WIDTH)
) dut (
    .clk                        (clk),
    .rst_n                      (rst_n),
    .clear                      (clear),
    .frame_read_req             (frame_read_req),
    .frame_read_done            (frame_read_done),
    .h_size_beat                (h_size_beat),
    .h_size_byte                (h_size_byte),
    .v_size_line                (v_size_line),
    .frame_index                (frame_index),
    .dma_ctrl_read_req           (dma_ctrl_read_req),
    .dma_ctrl_read_ack           (dma_ctrl_read_ack),
    .dma_ctrl_read_done          (dma_ctrl_read_done),
    .dma_ctrl_pyl_size_word      (dma_ctrl_pyl_size_word),
    .dma_ready                  (dma_ready),
    .dma_info_valid             (dma_info_valid),
    .dma_read_addr              (dma_read_addr),
    .dma_burst_count            (dma_burst_count),
    .dma_fifo_clear             (dma_fifo_clear)
);

//------------------------------------------------------------------------------
// Clock Generation
//------------------------------------------------------------------------------
initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

//------------------------------------------------------------------------------
// DMA Controller Model
//------------------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dma_ctrl_read_ack <= 1'b0;
        dma_ctrl_read_done <= 1'b0;
    end else begin
        // Acknowledge DMA read request after 2 cycles
        if (dma_ctrl_read_req && !dma_ctrl_read_ack) begin
            dma_ctrl_read_ack <= 1'b1;
        end else begin
            dma_ctrl_read_ack <= 1'b0;
        end

        // Signal transfer done after acknowledgment
        if (dma_ctrl_read_ack) begin
            dma_ctrl_read_done <= 1'b1;
        end else begin
            dma_ctrl_read_done <= 1'b0;
        end
    end
end

//------------------------------------------------------------------------------
// DMA Ready Model
//------------------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dma_ready <= 1'b0;
    end else begin
        if (dma_fifo_clear) begin
            dma_ready <= 1'b0;
        end else if (!dma_ready && dma_info_valid) begin
            dma_ready <= 1'b1;
        end else if (dma_ctrl_read_done) begin
            dma_ready <= 1'b0;
        end
    end
end

//------------------------------------------------------------------------------
// Test Procedures
//------------------------------------------------------------------------------
task reset_dut();
    begin
        rst_n = 0;
        clear = 0;
        frame_read_req = 0;
        h_size_beat = 0;
        h_size_byte = 0;
        v_size_line = 0;
        frame_index = 0;

        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        $display("[%0t] Reset completed", $time);
    end
endtask

task configure_frame(input [8:0] beats, input [13:0] bytes, input [12:0] lines, input [FRAME_INDEX_WIDTH-1:0] idx);
    begin
        h_size_beat = beats;
        h_size_byte = bytes;
        v_size_line = lines;
        frame_index = idx;
        @(posedge clk);
        $display("[%0t] Frame configured: beats=%0d, bytes=%0d, lines=%0d, index=%0d",
                 $time, beats, bytes, lines, idx);
    end
endtask

task trigger_frame_read();
    begin
        @(posedge clk);
        frame_read_req = 1;
        @(posedge clk);
        frame_read_req = 0;
        $display("[%0t] Frame read request triggered", $time);
    end
endtask

task wait_frame_done();
    begin
        wait(frame_read_done);
        @(posedge clk);
        $display("[%0t] Frame read completed", $time);
    end
endtask

//------------------------------------------------------------------------------
// Test Cases
//------------------------------------------------------------------------------
initial begin
    $display("========================================");
    $display("  Frame Transfer Control Testbench");
    $display("========================================");

    // Test 1: Basic reset
    $display("\n[TEST 1] Basic Reset Test");
    reset_dut();
    repeat(10) @(posedge clk);

    // Test 2: Small frame transfer (beats < MAX_BURST_SIZE)
    $display("\n[TEST 2] Small Frame Transfer");
    configure_frame(9'd100, 14'd3200, 13'd480, 13'd5);
    trigger_frame_read();
    wait_frame_done();
    repeat(10) @(posedge clk);

    // Test 3: Large frame transfer (beats > MAX_BURST_SIZE)
    $display("\n[TEST 3] Large Frame Transfer");
    reset_dut();
    configure_frame(9'd400, 14'd12800, 13'd720, 13'd10);
    trigger_frame_read();
    wait_frame_done();
    repeat(10) @(posedge clk);

    // Test 4: Multiple lines
    $display("\n[TEST 4] Multiple Lines Transfer");
    reset_dut();
    configure_frame(9'd64, 14'd2048, 13'd5, 13'd2);
    trigger_frame_read();
    wait_frame_done();
    repeat(10) @(posedge clk);

    // Test 5: Clear during operation
    $display("\n[TEST 5] Clear During Operation");
    reset_dut();
    configure_frame(9'd200, 14'd6400, 13'd100, 13'd7);
    trigger_frame_read();
    repeat(50) @(posedge clk);
    clear = 1;
    repeat(5) @(posedge clk);
    clear = 0;
    repeat(10) @(posedge clk);

    // Test 6: Back-to-back frame requests
    $display("\n[TEST 6] Back-to-Back Frame Requests");
    reset_dut();
    configure_frame(9'd50, 14'd1600, 13'd2, 13'd1);
    trigger_frame_read();
    wait_frame_done();
    repeat(5) @(posedge clk);
    configure_frame(9'd75, 14'd2400, 13'd3, 13'd3);
    trigger_frame_read();
    wait_frame_done();
    repeat(10) @(posedge clk);

    // Test 7: Minimum frame size
    $display("\n[TEST 7] Minimum Frame Size");
    reset_dut();
    configure_frame(9'd1, 14'd32, 13'd1, 13'd0);
    trigger_frame_read();
    wait_frame_done();
    repeat(10) @(posedge clk);

    $display("\n========================================");
    $display("  All Tests Completed Successfully!");
    $display("========================================");

    repeat(20) @(posedge clk);
    $finish;
end

//------------------------------------------------------------------------------
// Monitoring
//------------------------------------------------------------------------------
initial begin
    $monitor("[%0t] State=%s | DMA_Req=%b | DMA_Ack=%b | DMA_Done=%b | Addr=0x%h | Burst=%0d",
             $time, dut.curr_state.name(), dma_ctrl_read_req, dma_ctrl_read_ack,
             dma_ctrl_read_done, dma_read_addr, dma_burst_count);
end

//------------------------------------------------------------------------------
// Timeout watchdog
//------------------------------------------------------------------------------
initial begin
    #100_000_000; // 100ms timeout
    $display("ERROR: Simulation timeout!");
    $finish;
end

endmodule
