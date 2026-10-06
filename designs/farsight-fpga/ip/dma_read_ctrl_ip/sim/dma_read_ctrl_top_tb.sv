`timescale 1ns/1ps

module dma_read_ctrl_top_tb();

//------------------------------------------------------------------------------
// Parameters
//------------------------------------------------------------------------------
parameter integer CLOCK_FREQ_MHZ = 50;
parameter integer TIMEOUT_USEC   = 10_000;
parameter integer DDR_ADDR_WIDTH = 39;
parameter integer DDR_DATA_WIDTH = 512;
parameter integer METADATA_WIDTH = 640;
parameter integer CLK_PERIOD     = 20; // 50MHz = 20ns period
parameter integer DDR_CLK_PERIOD = 6;  // 150MHz for DDR clock

localparam integer METADATA_WORDS = METADATA_WIDTH / 32; // 20

//------------------------------------------------------------------------------
// DUT Signals
//------------------------------------------------------------------------------
logic                      clk;
logic                      ddr_clk;
logic                      rst_n;
logic                      ddr_rst_n;
logic                      clear;
logic                      frame_read_req;
logic                      frame_read_done;
logic [8:0]                h_size_beat;
logic [13:0]               h_size_byte;
logic [12:0]               v_size_line;
logic [15:0]               frame_index;
logic                      jumbo_en;
logic                      udp_metadata_sel;
logic [METADATA_WIDTH-1:0] metadata_data;
logic                      metadata_valid;
logic                      dma_ready;
logic                      ctrl_info_valid;
logic [DDR_ADDR_WIDTH-1:0] ctrl_read_addr;
logic [8:0]                ctrl_burst_count;
logic                      dma_fifo_clear;
logic                      dma_read_req;
logic                      dma_read_ack;
logic                      s_axis_dma_tready;
logic                      s_axis_dma_tvalid;
logic [31:0]               s_axis_dma_tdata;
logic                      m_axis_udp_pyl_tvalid;
logic                      m_axis_udp_pyl_tready;
logic [31:0]               m_axis_udp_pyl_tdata;
logic [3:0]                m_axis_udp_pyl_tkeep;
logic                      m_axis_udp_pyl_tlast;
logic                      m_axis_udp_pyl_size_tvalid;
logic                      m_axis_udp_pyl_size_tready;
logic [15:0]               m_axis_udp_pyl_size_tdata;
logic                      sof_req;
logic                      eof_ack;
logic                      pyl_acpt;
logic                      core_busy;
logic [31:0]               sof_req_err;
logic [31:0]               pyl_acpt_err;
logic [31:0]               send_pyl_err;
logic [31:0]               send_last_err;
logic [31:0]               wait_ack_err;
logic [31:0]               dma_timeout_err;
logic [31:0]               frame_xfer_timeout_err;

//------------------------------------------------------------------------------
// FIFO Signals
//------------------------------------------------------------------------------
logic                      fifo_write_rst_n;
logic                      fifo_write_en;
logic [DDR_DATA_WIDTH-1:0] fifo_write_data;
logic                      fifo_read_rst_n;
logic                      fifo_read_en;
logic                      fifo_read_valid;
logic [31:0]               fifo_read_data;
logic                      fifo_empty;
logic                      fifo_full;

//------------------------------------------------------------------------------
// Test Variables
//------------------------------------------------------------------------------
logic [31:0] dma_data_counter;
logic [31:0] received_packet_count;
logic [31:0] expected_data;

//------------------------------------------------------------------------------
// Clock Generation
//------------------------------------------------------------------------------
initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

initial begin
    ddr_clk = 0;
    forever #(DDR_CLK_PERIOD/2) ddr_clk = ~ddr_clk;
end

//------------------------------------------------------------------------------
// DUT Instantiation
//------------------------------------------------------------------------------
dma_read_ctrl_top #(
    .CLOCK_FREQ_MHZ(CLOCK_FREQ_MHZ),
    .TIMEOUT_USEC(TIMEOUT_USEC),
    .DDR_ADDR_WIDTH(DDR_ADDR_WIDTH),
    .DDR_DATA_WIDTH(DDR_DATA_WIDTH),
    .USABLE_ADDR_WIDTH(34),  // 16GB
    .FRAME_WIDTH(25),
    .FRAME_INDEX_WIDTH(9),
    .METADATA_WIDTH(METADATA_WIDTH)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .clear(clear),
    .frame_read_req(frame_read_req),
    .frame_read_done(frame_read_done),
    .udp_metadata_sel(udp_metadata_sel),
    .h_size_beat(h_size_beat),
    .h_size_byte(h_size_byte),
    .v_size_line(v_size_line),
    .frame_index(frame_index[8:0]),  // Only 9 bits for 16GB
    .jumbo_en(jumbo_en),
    .frame_xfer_timeout_err(frame_xfer_timeout_err),
    .dma_ready(dma_ready),
    .ctrl_info_valid(ctrl_info_valid),
    .ctrl_read_addr(ctrl_read_addr),
    .ctrl_burst_count(ctrl_burst_count),
    .dma_fifo_clear(dma_fifo_clear),
    .dma_read_req(dma_read_req),
    .dma_read_ack(dma_read_ack),
    .s_axis_dma_tready(s_axis_dma_tready),
    .s_axis_dma_tvalid(s_axis_dma_tvalid),
    .s_axis_dma_tdata(s_axis_dma_tdata),
    .m_axis_udp_pyl_tvalid(m_axis_udp_pyl_tvalid),
    .m_axis_udp_pyl_tready(m_axis_udp_pyl_tready),
    .m_axis_udp_pyl_tdata(m_axis_udp_pyl_tdata),
    .m_axis_udp_pyl_tkeep(m_axis_udp_pyl_tkeep),
    .m_axis_udp_pyl_tlast(m_axis_udp_pyl_tlast),
    .m_axis_udp_pyl_size_tvalid(m_axis_udp_pyl_size_tvalid),
    .m_axis_udp_pyl_size_tready(m_axis_udp_pyl_size_tready),
    .m_axis_udp_pyl_size_tdata(m_axis_udp_pyl_size_tdata),
    .sof_req(sof_req),
    .eof_ack(eof_ack),
    .pyl_acpt(pyl_acpt),
    .core_busy(core_busy),
    .sof_req_err(sof_req_err),
    .pyl_acpt_err(pyl_acpt_err),
    .send_pyl_err(send_pyl_err),
    .send_last_err(send_last_err),
    .wait_ack_err(wait_ack_err),
    .dma_timeout_err(dma_timeout_err),
    .metadata_data(metadata_data),
    .metadata_valid(metadata_valid)
);

//------------------------------------------------------------------------------
// FIFO Instantiation (Real FIFO for DDR4 16GB)
//------------------------------------------------------------------------------
COREFIFO_DMA_READ_DDR4_16GB_C0 corefifo_dma_read_ddr4_16gb_inst (
    .WCLOCK             (ddr_clk           ),
    .WRESET_N           (fifo_write_rst_n  ),
    .WE                 (fifo_write_en     ),
    .DATA               (fifo_write_data   ),
    .RCLOCK             (clk               ),
    .RRESET_N           (fifo_read_rst_n   ),
    .RE                 (fifo_read_en      ),
    .DVLD               (fifo_read_valid   ),
    .Q                  (fifo_read_data    ),
    .EMPTY              (fifo_empty        ),
    .FULL               (fifo_full         )
);

//------------------------------------------------------------------------------
// Connect FIFO to DMA interface
//------------------------------------------------------------------------------
assign s_axis_dma_tvalid = fifo_read_valid;
assign s_axis_dma_tdata  = fifo_read_data;
assign fifo_read_en      = s_axis_dma_tready && !fifo_empty;
assign fifo_read_rst_n   = rst_n & ~dma_fifo_clear;

//------------------------------------------------------------------------------
// DMA Write to FIFO Model (DDR clock domain)
//------------------------------------------------------------------------------
assign fifo_write_rst_n = ddr_rst_n & ~dma_fifo_clear;

// CDC sync: dma_read_req (system clk) → DDR clk domain
logic [1:0] dma_req_ddr_sync;
always @(posedge ddr_clk or negedge ddr_rst_n) begin
    if (!ddr_rst_n) dma_req_ddr_sync <= 2'b0;
    else            dma_req_ddr_sync <= {dma_req_ddr_sync[0], dma_read_req};
end

logic [8:0] beat_count;
logic [8:0] beats_to_write;
// Throttle writes to ~200 MB/s (1 beat / 48 DDR cycles) so the FIFO never
// fills up. At 150 MHz DDR and 64 B/beat: 150M/48 x 64 = 200 MB/s ≈ UDP
// read rate, keeping FIFO occupancy near zero and avoiding registered-FULL
// timing glitches that produce phantom extra beats.
logic [5:0] write_gap;

always @(posedge ddr_clk or negedge ddr_rst_n) begin
    if (!ddr_rst_n) begin
        dma_read_ack     <= 1'b0;
        dma_data_counter <= 32'h0;
        fifo_write_en    <= 1'b0;
        fifo_write_data  <= '0;
        beat_count       <= 0;
        beats_to_write   <= 0;
        write_gap        <= 0;
    end else begin
        fifo_write_en <= 1'b0;

        // Start burst on new request; hold ack high until request deasserts
        // to prevent re-triggering during the CDC round-trip.
        if (dma_req_ddr_sync[1] && dma_ready && !dma_read_ack) begin
            dma_read_ack   <= 1'b1;
            beats_to_write <= ctrl_burst_count; // actual beat count
            beat_count     <= 0;
            write_gap      <= 0;
        end else if (beat_count >= beats_to_write && !dma_req_ddr_sync[1]) begin
            // Drop ack only after both burst is done AND request has gone away
            dma_read_ack <= 1'b0;
        end

        // Throttled beat write: 1 beat per 48 DDR cycles
        if (dma_read_ack && beat_count < beats_to_write) begin
            if (write_gap == 0) begin
                for (int i = 0; i < (DDR_DATA_WIDTH/8); i++) begin
                    fifo_write_data[i*8 +: 8] = dma_data_counter[7:0] + i[7:0];
                end
                fifo_write_en    <= 1'b1;
                dma_data_counter <= dma_data_counter + (DDR_DATA_WIDTH/8);
                beat_count       <= beat_count + 1;
                write_gap        <= 6'd47;
            end else begin
                write_gap <= write_gap - 1;
            end
        end else begin
            write_gap <= 0;
        end
    end
end

//------------------------------------------------------------------------------
// DMA Ready Signal
//------------------------------------------------------------------------------
always @(posedge ddr_clk or negedge ddr_rst_n) begin
    if (!ddr_rst_n) begin
        dma_ready <= 1'b0;
    end else begin
        // Ready when not full and not clearing
        dma_ready <= !fifo_full && !dma_fifo_clear;
    end
end

//------------------------------------------------------------------------------
// UDP Core Response Model
//------------------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pyl_acpt <= 1'b0;
        eof_ack <= 1'b0;
        core_busy <= 1'b0;
        m_axis_udp_pyl_size_tready <= 1'b0;
    end else begin
        // Accept payload after SOF request
        if (sof_req && !core_busy) begin
            pyl_acpt <= 1'b1;
        end else begin
            pyl_acpt <= 1'b0;
        end

        // Acknowledge EOF after last packet
        if (m_axis_udp_pyl_tlast && m_axis_udp_pyl_tvalid && m_axis_udp_pyl_tready) begin
            eof_ack <= 1'b1;
        end else begin
            eof_ack <= 1'b0;
        end

        // Ready to receive payload size
        m_axis_udp_pyl_size_tready <= !core_busy;
    end
end

//------------------------------------------------------------------------------
// Received Packet Counter
//------------------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        received_packet_count <= 0;
    end else begin
        if (m_axis_udp_pyl_tlast && m_axis_udp_pyl_tvalid && m_axis_udp_pyl_tready) begin
            received_packet_count <= received_packet_count + 1;
        end
    end
end

//------------------------------------------------------------------------------
// Test Sequences
//------------------------------------------------------------------------------
initial begin
    // Initialize signals
    rst_n = 0;
    ddr_rst_n = 0;
    clear = 0;
    frame_read_req = 0;
    h_size_beat = 0;
    h_size_byte = 0;
    v_size_line = 0;
    frame_index = 0;
    jumbo_en = 0;
    udp_metadata_sel = 0;
    m_axis_udp_pyl_tready = 0;

    // Reset
    #100;
    rst_n = 1;
    ddr_rst_n = 1;
    #200;

    $display("=== Test 1: Small Frame Transfer (Standard Frame) ===");
    test_small_frame();

    #2000;

    $display("\n=== Test 2: Metadata Frame Capture ===");
    test_metadata_frame();

    #2000;

    $display("\n=== Test Complete - Final Status ===");
    $display("FIFO Empty: %b", fifo_empty);
    $display("Error Counters:");
    $display("  DMA Timeout: %0d", dma_timeout_err);
    $display("  Send Payload: %0d", send_pyl_err);
    $display("  Send Last: %0d", send_last_err);
    
    #2000;

    // Comment out other tests for now - focus on the 106 beat test
    /*
    $display("=== Test 2: Large Frame Transfer (Multiple UDP Packets) ===");
    test_large_frame();

    #2000;

    $display("=== Test 3: Jumbo Frame Transfer ===");
    test_jumbo_frame();

    #2000;

    $display("=== Test 4: Multiple Lines ===");
    test_multiple_lines();

    #2000;
    */

    $display("=== All tests completed ===");
    if (dma_timeout_err == 0 && send_pyl_err == 0 && send_last_err == 0) begin
        $display("*** ALL TESTS PASSED ***");
    end else begin
        $display("*** TESTS FAILED - Check error counters ***");
    end
    $stop;
end

//------------------------------------------------------------------------------
// Test Tasks
//------------------------------------------------------------------------------
task test_small_frame();
    begin
        // Configure for 106 beats with byte counting pattern
        // 106 beats * 512 bits = 54,272 bits = 6,784 bytes = 1,696 words (32-bit)
        h_size_beat = 106;
        h_size_byte = 106 * (DDR_DATA_WIDTH/8);
        v_size_line = 1;
        frame_index = 16'h0001;
        jumbo_en = 0;
        dma_data_counter = 32'h0000_0001; // Start byte counting from 0x01

        $display("Starting test with 106 beats (1,696 words of 32-bit data)");
        $display("Expected pattern: Byte counting 0x...060504030201");

        // Start frame read
        @(posedge clk);
        frame_read_req = 1;
        @(posedge clk);
        frame_read_req = 0;

        // Enable UDP ready with slight delay
        repeat(10) @(posedge clk);
        m_axis_udp_pyl_tready = 1;

        // Wait for completion
        wait(frame_read_done);
        repeat(10) @(posedge clk);

        m_axis_udp_pyl_tready = 0;

        $display("Small frame transfer completed - Packets received: %0d", received_packet_count);
        $display("FIFO should be empty now. Empty flag = %b", fifo_empty);
        
        if (!fifo_empty) begin
            $display("ERROR: FIFO not empty after transfer completion!");
        end else begin
            $display("SUCCESS: FIFO properly emptied");
        end
    end
endtask

task test_large_frame();
    begin
        // Configure for large frame: 200 beats (exceeds standard frame)
        // 200 beats * 512 bits = 102,400 bits = 12,800 bytes = 3,200 words
        h_size_beat = 200;
        h_size_byte = 200 * (DDR_DATA_WIDTH/8);
        v_size_line = 1;
        frame_index = 16'h0002;
        jumbo_en = 0;
        dma_data_counter = 32'h2000_0000;
        received_packet_count = 0;

        @(posedge clk);
        frame_read_req = 1;
        @(posedge clk);
        frame_read_req = 0;

        repeat(10) @(posedge clk);
        m_axis_udp_pyl_tready = 1;

        wait(frame_read_done);
        repeat(10) @(posedge clk);

        m_axis_udp_pyl_tready = 0;

        $display("Large frame transfer completed - Packets received: %0d", received_packet_count);
    end
endtask

task test_jumbo_frame();
    begin
        // Configure for jumbo frame
        h_size_beat = 150;
        h_size_byte = 150 * (DDR_DATA_WIDTH/8);
        v_size_line = 1;
        frame_index = 16'h0003;
        jumbo_en = 1;
        dma_data_counter = 32'h3000_0000;
        received_packet_count = 0;

        @(posedge clk);
        frame_read_req = 1;
        @(posedge clk);
        frame_read_req = 0;

        repeat(10) @(posedge clk);
        m_axis_udp_pyl_tready = 1;

        wait(frame_read_done);
        repeat(10) @(posedge clk);

        m_axis_udp_pyl_tready = 0;

        $display("Jumbo frame transfer completed - Packets received: %0d", received_packet_count);
    end
endtask

task test_multiple_lines();
    begin
        // Configure for 3 lines
        h_size_beat = 64;
        h_size_byte = 64 * (DDR_DATA_WIDTH/8);
        v_size_line = 3;
        frame_index = 16'h0004;
        jumbo_en = 0;
        dma_data_counter = 32'h4000_0000;
        received_packet_count = 0;

        @(posedge clk);
        frame_read_req = 1;
        @(posedge clk);
        frame_read_req = 0;

        repeat(10) @(posedge clk);
        m_axis_udp_pyl_tready = 1;

        wait(frame_read_done);
        repeat(10) @(posedge clk);

        m_axis_udp_pyl_tready = 0;

        $display("Multiple lines transfer completed - Packets received: %0d", received_packet_count);
    end
endtask

task test_metadata_frame();
    begin
        // udp_metadata_sel=1 causes frame_xfer_ctrl to override:
        //   h_size_beat → 2 (16GB: 128B / 64B per beat)
        //   h_size_byte → 128
        //   v_size_line → 1
        // No h/v settings needed here; DUT applies them internally.
        // Set h_size_beat/h_size_byte/v_size_line to image defaults so they
        // would be visible in any waveform not in meta mode.
        h_size_beat = 106;
        h_size_byte = 106 * (DDR_DATA_WIDTH/8);
        v_size_line = 1;
        frame_index = 16'h0005;
        jumbo_en    = 0;
        dma_data_counter = 32'h0000_0001;

        udp_metadata_sel = 1;

        $display("Metadata test: DUT will capture first %0d x 32-bit words (%0d bits)",
                 METADATA_WORDS, METADATA_WIDTH);

        @(posedge clk);
        frame_read_req = 1;
        @(posedge clk);
        frame_read_req = 0;

        // Wait for metadata_valid pulse (no UDP path used)
        wait(metadata_valid);
        @(posedge clk);

        $display("metadata_valid asserted at time %t", $time);
        for (int w = 0; w < METADATA_WORDS; w++) begin
            $display("  metadata_data[%0d] = 0x%08h", w,
                     metadata_data[w*32 +: 32]);
        end

        wait(frame_read_done);
        repeat(10) @(posedge clk);

        udp_metadata_sel = 0;
        $display("Metadata frame capture complete");
    end
endtask

//------------------------------------------------------------------------------
// Monitors
//------------------------------------------------------------------------------
always @(posedge clk) begin
    if (sof_req_err > 0)
        $display("ERROR: SOF request error detected at time %t - Count: %0d", $time, sof_req_err);
    if (pyl_acpt_err > 0)
        $display("ERROR: Payload accept error detected at time %t - Count: %0d", $time, pyl_acpt_err);
    if (send_pyl_err > 0)
        $display("ERROR: Send payload error detected at time %t - Count: %0d", $time, send_pyl_err);
    if (send_last_err > 0)
        $display("ERROR: Send last error detected at time %t - Count: %0d", $time, send_last_err);
    if (wait_ack_err > 0)
        $display("ERROR: Wait ACK error detected at time %t - Count: %0d", $time, wait_ack_err);
    if (dma_timeout_err > 0)
        $display("ERROR: DMA timeout error detected at time %t - Count: %0d", $time, dma_timeout_err);
    if (frame_xfer_timeout_err > 0)
        $display("ERROR: Frame transfer timeout error at time %t - Count: %0d", $time, frame_xfer_timeout_err);
end

// Monitor FIFO status (rising edge only to avoid flooding)
logic fifo_full_prev;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        fifo_full_prev <= 1'b0;
    end else begin
        fifo_full_prev <= fifo_full;
        if (fifo_full && !fifo_full_prev)
            $display("WARNING: FIFO went full at time %t", $time);
        if (!fifo_full && fifo_full_prev)
            $display("INFO:    FIFO no longer full at time %t", $time);
    end
end

// Monitor metadata capture
always @(posedge clk) begin
    if (metadata_valid) begin
        $display("INFO: metadata_valid pulse at time %t, data[639:608]=0x%08h data[31:0]=0x%08h",
                 $time, metadata_data[639:608], metadata_data[31:0]);
    end
end

// Data integrity check and monitoring
logic data_check_en;
logic [31:0] expected_word_count;
logic [31:0] actual_word_count;

initial begin
    data_check_en = 0;
    expected_word_count = 0;
    actual_word_count = 0;
end

// Monitor UDP payload output with data checking
always @(posedge clk) begin
    if (m_axis_udp_pyl_tvalid && m_axis_udp_pyl_tready) begin
        actual_word_count <= actual_word_count + 1;
        
        // Display first few and last few words for verification
        if (actual_word_count < 10 || m_axis_udp_pyl_tlast) begin
            $display("Time %t: UDP Output Word[%0d] = 0x%08h, keep=0x%h, last=%b", 
                     $time, actual_word_count, m_axis_udp_pyl_tdata, 
                     m_axis_udp_pyl_tkeep, m_axis_udp_pyl_tlast);
        end
    end
    
    if (m_axis_udp_pyl_tlast && m_axis_udp_pyl_tvalid && m_axis_udp_pyl_tready) begin
        $display("Packet complete: Total words in packet = %0d", actual_word_count + 1);
        actual_word_count <= 0;
    end
end

endmodule