/*
 * @file      read_ddr_to_mtx_tb.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      07/17/2026
 * 
 * @brief     Read DDR to MTX Testbench. This testbench verifies the
 *            functionality of the DDR4 Arbiter to MTX path.
 
 * @section changelog
 * - 07/17/2026: Steven Knyazher - Initial implementation
 * 
 */

`timescale 1ns/1ps

module read_ddr_to_mtx_tb;

    //--------------------------------------------------------------------------
    // Parameters
    //--------------------------------------------------------------------------
    localparam int APB_DATA_WIDTH       = 32;
    localparam int APB_ADDR_WIDTH       = 32;
    localparam int MTX_DATA_WIDTH       = 32;
    localparam int DDR4_BURST_LEN_WIDTH = 8;
    localparam int DDR4_8GB_ADDR_WIDTH  = 38;
    localparam int DDR4_8GB_DATA_WIDTH  = 256;
    localparam int DDR4_16GB_ADDR_WIDTH = 39;
    localparam int DDR4_16GB_DATA_WIDTH = 512;

    // Clock periods (ns)
    localparam real PCLK_PERIOD    = 20.000;  // 50  MHz
    localparam real UDP_CLK_PERIOD = 10.000;  // 100 MHz
    localparam real DDR_CLK_PERIOD = 6.667;   // 150 MHz

    // APB peripheral base addresses
    localparam logic [APB_ADDR_WIDTH-1:0] DMA_READ_DDR4_8GB_BASE_ADDR       = 32'h70013000;
    localparam logic [APB_ADDR_WIDTH-1:0] DMA_READ_DDR4_16GB_BASE_ADDR      = 32'h70014000;
    localparam logic [APB_ADDR_WIDTH-1:0] DMA_READ_CTRL_DDR4_8GB_BASE_ADDR  = 32'h70006000;
    localparam logic [APB_ADDR_WIDTH-1:0] DMA_READ_CTRL_DDR4_16GB_BASE_ADDR = 32'h70007000;
    localparam logic [APB_ADDR_WIDTH-1:0] UDP_TX_BASE_ADDR                  = 32'h7000E000;

    // ETH1 UDP configuration
    localparam logic [15:0] ETH1_DST_PORT    = 16'h8931;
    localparam logic [15:0] ETH1_SRC_PORT    = 16'h04D2;
    localparam logic [31:0] ETH1_DST_IP      = 32'h0A650FC3;  // 10.101.15.195
    localparam logic [31:0] ETH1_SRC_IP      = 32'h0A650FC0;  // 10.101.15.192
    localparam logic [15:0] ETH1_DST_MAC_MSB = 16'h88A4;
    localparam logic [31:0] ETH1_DST_MAC_LSB = 32'hC25649ED;
    localparam logic [15:0] ETH1_SRC_MAC_MSB = 16'h0004;
    localparam logic [31:0] ETH1_SRC_MAC_LSB = 32'hA3123456;

    // DMA read ctrl APB register offsets (byte address = word index * 4)
    localparam logic [APB_ADDR_WIDTH-1:0] CLEAR_DMA_READ_CTRL_OFFSET   = 32'h00;
    localparam logic [APB_ADDR_WIDTH-1:0] DMA_READ_FRAME_INDEX_OFFSET  = 32'h04;
    localparam logic [APB_ADDR_WIDTH-1:0] FRAME_READ_DONE_COUNT_OFFSET = 32'h08;
    localparam logic [APB_ADDR_WIDTH-1:0] FRAME_READ_REQ_OFFSET        = 32'h0C;
    localparam logic [APB_ADDR_WIDTH-1:0] H_SIZE_BEAT_OFFSET           = 32'h10;
    localparam logic [APB_ADDR_WIDTH-1:0] H_SIZE_BYTE_OFFSET           = 32'h14;
    localparam logic [APB_ADDR_WIDTH-1:0] JUMBO_EN_OFFSET              = 32'h18;
    localparam logic [APB_ADDR_WIDTH-1:0] V_SIZE_LINE_OFFSET           = 32'h1C;
    localparam logic [APB_ADDR_WIDTH-1:0] RESET_DONE_COUNTER_OFFSET    = 32'h3C;
    localparam logic [APB_ADDR_WIDTH-1:0] UDP_METADATA_SEL_OFFSET      = 32'h40;

    // UDP TX APB register offsets
    localparam logic [APB_ADDR_WIDTH-1:0] UDP_DST_PORT_OFFSET = 32'h00;
    localparam logic [APB_ADDR_WIDTH-1:0] UDP_SRC_PORT_OFFSET = 32'h04;
    localparam logic [APB_ADDR_WIDTH-1:0] DST_IP_OFFSET       = 32'h08;
    localparam logic [APB_ADDR_WIDTH-1:0] SRC_IP_OFFSET       = 32'h0C;
    localparam logic [APB_ADDR_WIDTH-1:0] DST_MAC_MSB_OFFSET  = 32'h10;
    localparam logic [APB_ADDR_WIDTH-1:0] DST_MAC_LSB_OFFSET  = 32'h14;
    localparam logic [APB_ADDR_WIDTH-1:0] SRC_MAC_MSB_OFFSET  = 32'h18;
    localparam logic [APB_ADDR_WIDTH-1:0] SRC_MAC_LSB_OFFSET  = 32'h1C;
    localparam logic [APB_ADDR_WIDTH-1:0] UDP_MUX_SEL_OFFSET  = 32'h24;

    // UDP mux select encodings
    localparam logic [APB_DATA_WIDTH-1:0] UDP_MUX_SELECT_DDR4_8GB  = 32'd2;
    localparam logic [APB_DATA_WIDTH-1:0] UDP_MUX_SELECT_DDR4_16GB = 32'd3;

    // Frame geometry (matches software configuration)
    localparam int LINES_PER_FRAME       = 513;
    localparam int HORIZ_WIDTH_BYTE      = 832;
    localparam int HORIZ_WIDTH_BEAT_8GB  = 26;
    localparam int HORIZ_WIDTH_BEAT_16GB = 13;

    // Number of frames to transfer per DDR4 core (kept small for simulation)
    localparam int NUM_16GB_FRAMES = 2;
    localparam int NUM_8GB_FRAMES  = 2;

    //--------------------------------------------------------------------------
    // Clocks and resets
    //--------------------------------------------------------------------------
    logic udp_clk;
    logic udp_rst_n;
    logic ddr_clk;
    logic ddr_rst_n;
    logic pclk;
    logic presetn;

    //--------------------------------------------------------------------------
    // DUT I/O
    //--------------------------------------------------------------------------
    logic                                penable;
    logic                                psel;
    logic [APB_ADDR_WIDTH-1:0]           paddr;
    logic                                pwrite;
    logic [APB_DATA_WIDTH-1:0]           pwdata;
    logic [APB_DATA_WIDTH-1:0]           prdata;
    logic                                pready;
    logic                                pslverr;

    logic                                MRXACPT;
    logic                                MRXRDY;
    logic [MTX_DATA_WIDTH-1:0]           MRXDAT;
    logic                                MRXEOF;
    logic [$clog2(MTX_DATA_WIDTH/8)-1:0] MRXBYTEVALID;
    logic                                MRXSOF;

    logic                                MTXACPT;
    logic                                MTXRDY;
    logic [MTX_DATA_WIDTH-1:0]           MTXDAT;
    logic                                MTXEOF;
    logic [$clog2(MTX_DATA_WIDTH/8)-1:0] MTXBYTEVALID;
    logic                                MTXSOF;

    logic                                ddr4_8gb_arb_read_req;
    logic                                ddr4_8gb_arb_read_ack;
    logic [DDR4_BURST_LEN_WIDTH-1:0]     ddr4_8gb_arb_read_burst_len;
    logic [DDR4_8GB_ADDR_WIDTH-1:0]      ddr4_8gb_arb_read_start_addr;
    logic                                ddr4_8gb_arb_read_done;
    logic                                ddr4_8gb_arb_read_valid;
    logic [DDR4_8GB_DATA_WIDTH-1:0]      ddr4_8gb_arb_read_data;

    logic                                ddr4_16gb_arb_read_req;
    logic                                ddr4_16gb_arb_read_ack;
    logic [DDR4_BURST_LEN_WIDTH-1:0]     ddr4_16gb_arb_read_burst_len;
    logic [DDR4_16GB_ADDR_WIDTH-1:0]     ddr4_16gb_arb_read_start_addr;
    logic                                ddr4_16gb_arb_read_done;
    logic                                ddr4_16gb_arb_read_valid;
    logic [DDR4_16GB_DATA_WIDTH-1:0]     ddr4_16gb_arb_read_data;

    //--------------------------------------------------------------------------
    // DUT instance
    //--------------------------------------------------------------------------
    read_ddr_to_mtx #(
        .APB_DATA_WIDTH       (APB_DATA_WIDTH      ),
        .APB_ADDR_WIDTH       (APB_ADDR_WIDTH      ),
        .MTX_DATA_WIDTH       (MTX_DATA_WIDTH      ),
        .DDR4_BURST_LEN_WIDTH (DDR4_BURST_LEN_WIDTH),
        .DDR4_8GB_ADDR_WIDTH  (DDR4_8GB_ADDR_WIDTH ),
        .DDR4_8GB_DATA_WIDTH  (DDR4_8GB_DATA_WIDTH ),
        .DDR4_16GB_ADDR_WIDTH (DDR4_16GB_ADDR_WIDTH),
        .DDR4_16GB_DATA_WIDTH (DDR4_16GB_DATA_WIDTH)
    ) dut (
        .udp_clk                       (udp_clk                      ),
        .udp_rst_n                     (udp_rst_n                    ),
        .ddr_clk                       (ddr_clk                      ),
        .ddr_rst_n                     (ddr_rst_n                    ),
        .pclk                          (pclk                         ),
        .presetn                       (presetn                      ),

        .penable                       (penable                      ),
        .psel                          (psel                         ),
        .paddr                         (paddr                        ),
        .pwrite                        (pwrite                       ),
        .pwdata                        (pwdata                       ),
        .prdata                        (prdata                       ),
        .pready                        (pready                       ),
        .pslverr                       (pslverr                      ),

        .MRXACPT                       (MRXACPT                      ),
        .MRXRDY                        (MRXRDY                       ),
        .MRXDAT                        (MRXDAT                       ),
        .MRXEOF                        (MRXEOF                       ),
        .MRXBYTEVALID                  (MRXBYTEVALID                 ),
        .MRXSOF                        (MRXSOF                       ),

        .MTXACPT                       (MTXACPT                      ),
        .MTXRDY                        (MTXRDY                       ),
        .MTXDAT                        (MTXDAT                       ),
        .MTXEOF                        (MTXEOF                       ),
        .MTXBYTEVALID                  (MTXBYTEVALID                 ),
        .MTXSOF                        (MTXSOF                       ),

        .ddr4_8gb_arb_read_req         (ddr4_8gb_arb_read_req        ),
        .ddr4_8gb_arb_read_ack         (ddr4_8gb_arb_read_ack        ),
        .ddr4_8gb_arb_read_burst_len   (ddr4_8gb_arb_read_burst_len  ),
        .ddr4_8gb_arb_read_start_addr  (ddr4_8gb_arb_read_start_addr ),
        .ddr4_8gb_arb_read_done        (ddr4_8gb_arb_read_done       ),
        .ddr4_8gb_arb_read_valid       (ddr4_8gb_arb_read_valid      ),
        .ddr4_8gb_arb_read_data        (ddr4_8gb_arb_read_data       ),

        .ddr4_16gb_arb_read_req        (ddr4_16gb_arb_read_req       ),
        .ddr4_16gb_arb_read_ack        (ddr4_16gb_arb_read_ack       ),
        .ddr4_16gb_arb_read_burst_len  (ddr4_16gb_arb_read_burst_len ),
        .ddr4_16gb_arb_read_start_addr (ddr4_16gb_arb_read_start_addr),
        .ddr4_16gb_arb_read_done       (ddr4_16gb_arb_read_done      ),
        .ddr4_16gb_arb_read_valid      (ddr4_16gb_arb_read_valid     ),
        .ddr4_16gb_arb_read_data       (ddr4_16gb_arb_read_data      )
    );

    //--------------------------------------------------------------------------
    // Clock generation
    //--------------------------------------------------------------------------
    initial begin
        pclk = 1'b0;
        forever #(PCLK_PERIOD/2.0) pclk = ~pclk;
    end

    initial begin
        udp_clk = 1'b0;
        forever #(UDP_CLK_PERIOD/2.0) udp_clk = ~udp_clk;
    end

    initial begin
        ddr_clk = 1'b0;
        forever #(DDR_CLK_PERIOD/2.0) ddr_clk = ~ddr_clk;
    end

    //--------------------------------------------------------------------------
    // Reset generation (active low)
    //--------------------------------------------------------------------------
    initial begin
        presetn   = 1'b0;
        udp_rst_n = 1'b0;
        ddr_rst_n = 1'b0;

        repeat (10) @(posedge pclk);

        presetn   = 1'b1;
        udp_rst_n = 1'b1;
        ddr_rst_n = 1'b1;
    end

    //--------------------------------------------------------------------------
    // APB access tasks
    //--------------------------------------------------------------------------
    task automatic apb_write(input logic [APB_ADDR_WIDTH-1:0] base_addr,
                             input logic [APB_ADDR_WIDTH-1:0] offset,
                             input logic [APB_DATA_WIDTH-1:0] data);
        // SETUP phase
        @(posedge pclk);
        psel    <= 1'b1;
        penable <= 1'b0;
        pwrite  <= 1'b1;
        paddr   <= base_addr + offset;
        pwdata  <= data;
        // ACCESS phase
        @(posedge pclk);
        penable <= 1'b1;
        // Wait for slave ready
        do @(posedge pclk); while (!pready);
        // Return to IDLE
        psel    <= 1'b0;
        penable <= 1'b0;
        pwrite  <= 1'b0;
        paddr   <= '0;
        pwdata  <= '0;
    endtask

    task automatic apb_read(input  logic [APB_ADDR_WIDTH-1:0] base_addr,
                            input  logic [APB_ADDR_WIDTH-1:0] offset,
                            output logic [APB_DATA_WIDTH-1:0] data);
        // SETUP phase
        @(posedge pclk);
        psel    <= 1'b1;
        penable <= 1'b0;
        pwrite  <= 1'b0;
        paddr   <= base_addr + offset;
        // ACCESS phase
        @(posedge pclk);
        penable <= 1'b1;
        // Wait for slave ready and capture data
        do @(posedge pclk); while (!pready);
        data = prdata;
        // Return to IDLE
        psel    <= 1'b0;
        penable <= 1'b0;
        paddr   <= '0;
    endtask

    //--------------------------------------------------------------------------
    // Configure UDP core
    //--------------------------------------------------------------------------
    task automatic configure_udp(input logic [APB_ADDR_WIDTH-1:0] base_addr,
                                 input logic [15:0]               dst_port,
                                 input logic [15:0]               src_port,
                                 input logic [31:0]               dst_ip,
                                 input logic [31:0]               src_ip,
                                 input logic [15:0]               dst_mac_msb,
                                 input logic [31:0]               dst_mac_lsb,
                                 input logic [15:0]               src_mac_msb,
                                 input logic [31:0]               src_mac_lsb);
        logic [APB_DATA_WIDTH-1:0] rdata;
        // Configure UDP ports
        apb_write(base_addr, UDP_DST_PORT_OFFSET, dst_port);
        apb_read (base_addr, UDP_DST_PORT_OFFSET, rdata);
        apb_write(base_addr, UDP_SRC_PORT_OFFSET, src_port);
        apb_read (base_addr, UDP_SRC_PORT_OFFSET, rdata);
        // Configure IP addresses
        apb_write(base_addr, DST_IP_OFFSET, dst_ip);
        apb_read (base_addr, DST_IP_OFFSET, rdata);
        apb_write(base_addr, SRC_IP_OFFSET, src_ip);
        apb_read (base_addr, SRC_IP_OFFSET, rdata);
        // Configure destination MAC address
        apb_write(base_addr, DST_MAC_MSB_OFFSET, dst_mac_msb);
        apb_read (base_addr, DST_MAC_MSB_OFFSET, rdata);
        apb_write(base_addr, DST_MAC_LSB_OFFSET, dst_mac_lsb);
        apb_read (base_addr, DST_MAC_LSB_OFFSET, rdata);
        // Configure source MAC address
        apb_write(base_addr, SRC_MAC_MSB_OFFSET, src_mac_msb);
        apb_read (base_addr, SRC_MAC_MSB_OFFSET, rdata);
        apb_write(base_addr, SRC_MAC_LSB_OFFSET, src_mac_lsb);
        apb_read (base_addr, SRC_MAC_LSB_OFFSET, rdata);
    endtask

    //--------------------------------------------------------------------------
    // Configure UDP1 core
    //--------------------------------------------------------------------------
    task automatic configure_udp1();
        configure_udp(UDP_TX_BASE_ADDR,
                      ETH1_DST_PORT,
                      ETH1_SRC_PORT,
                      ETH1_DST_IP,
                      ETH1_SRC_IP,
                      ETH1_DST_MAC_MSB,
                      ETH1_DST_MAC_LSB,
                      ETH1_SRC_MAC_MSB,
                      ETH1_SRC_MAC_LSB);
    endtask

    //--------------------------------------------------------------------------
    // Reset DMA read ctrl
    //--------------------------------------------------------------------------
    task automatic reset_dma_read_ctrl(input logic [APB_ADDR_WIDTH-1:0] base_addr);
        apb_write(base_addr, CLEAR_DMA_READ_CTRL_OFFSET, 1'b1);
        #10us;
        apb_write(base_addr, CLEAR_DMA_READ_CTRL_OFFSET, 1'b0);
        #10us;
        apb_write(base_addr, RESET_DONE_COUNTER_OFFSET, 1'b1);
        #10us;
        apb_write(base_addr, RESET_DONE_COUNTER_OFFSET, 1'b0);
    endtask

    //--------------------------------------------------------------------------
    // Configure DMA read ctrl
    //--------------------------------------------------------------------------
    task automatic configure_dma_read_ctrl(input logic [APB_ADDR_WIDTH-1:0] base_addr,
                                           input logic [APB_DATA_WIDTH-1:0] v_size_line,
                                           input logic [APB_DATA_WIDTH-1:0] h_size_byte,
                                           input logic [APB_DATA_WIDTH-1:0] h_size_beat);
        apb_write(base_addr, V_SIZE_LINE_OFFSET, v_size_line);
        apb_write(base_addr, H_SIZE_BYTE_OFFSET, h_size_byte);
        apb_write(base_addr, H_SIZE_BEAT_OFFSET, h_size_beat);
    endtask

    //--------------------------------------------------------------------------
    // Set UDP read mux
    //--------------------------------------------------------------------------
    task automatic set_read_mux(input logic [APB_ADDR_WIDTH-1:0] base_addr,
                                input logic [APB_DATA_WIDTH-1:0] sel);
        apb_write(base_addr, UDP_MUX_SEL_OFFSET, sel);
    endtask

    //--------------------------------------------------------------------------
    // Transfer one frame via UDP
    //--------------------------------------------------------------------------
    task automatic xfer_frame_via_udp(input logic [APB_ADDR_WIDTH-1:0] base_addr,
                                      input logic [APB_DATA_WIDTH-1:0] frame_index);
        logic [APB_DATA_WIDTH-1:0] prev_read_count;
        logic [APB_DATA_WIDTH-1:0] read_count;
        apb_write(base_addr, UDP_METADATA_SEL_OFFSET, 1'b0);
        // Make sure the register is cleared
        apb_write(base_addr, FRAME_READ_REQ_OFFSET, 1'b0);
        apb_write(base_addr, DMA_READ_FRAME_INDEX_OFFSET, frame_index);
        apb_read (base_addr, FRAME_READ_DONE_COUNT_OFFSET, prev_read_count);
        // Send the read request
        apb_write(base_addr, FRAME_READ_REQ_OFFSET, 1'b1);
        // Wait for the frame read done count to advance
        do apb_read(base_addr, FRAME_READ_DONE_COUNT_OFFSET, read_count);
        while (read_count == prev_read_count);
        // Clear the register
        apb_write(base_addr, FRAME_READ_REQ_OFFSET, 1'b0);
    endtask

    //--------------------------------------------------------------------------
    // Frame data memories loaded from raw files
    //
    // The DDR4 read data returned to the DUT is sourced from raw frame files
    // (little-endian 32-bit words, as produced by the write-side capture). The
    // simulator runs from the "stimulus" directory while the recorded raw
    // frames live in the sibling "simulation" directory, so the defaults use a
    // relative path. Both may be overridden from the command line via
    // +DDR4_8GB_FRAME_FILE=<path> and +DDR4_16GB_FRAME_FILE=<path>.
    //--------------------------------------------------------------------------
    string ddr4_8gb_frame_file  = "../simulation/ddr4_8gb_frame_512.raw";
    string ddr4_16gb_frame_file = "../simulation/ddr4_16gb_frame_0.raw";

    // Beat memories loaded from the raw frame files
    logic [DDR4_8GB_DATA_WIDTH-1:0]  ddr4_8gb_frame_mem  [$];
    logic [DDR4_16GB_DATA_WIDTH-1:0] ddr4_16gb_frame_mem [$];

    // Running beat index into each frame memory. Reset to 0 at the start of
    // every frame transfer so each frame reads the raw file from the beginning
    // (a single raw file holds exactly one frame). This avoids index drift
    // across frames, which would make the tail beats of the previous frame
    // appear at the start of the next.
    int ddr4_8gb_beat_idx  = 0;
    int ddr4_16gb_beat_idx = 0;

    //--------------------------------------------------------------------------
    // DDR4 read arbiter models
    //
    // Emulate the upstream read arbiter for each DDR4 core. On each read
    // request (sampled on ddr_clk) the model returns a single-cycle ack, then
    // drives the requested number of valid read beats back to the DUT. The
    // requested burst length is (beats - 1), so it drives (burst_len + 1) valid
    // beats before pulsing done.
    //
    // The DUT (dma_read) captures read data combinationally on every cycle that
    // arb_read_valid is high (fifo_write_data = arb_read_valid ? arb_data_in),
    // so the data beat MUST be presented in the same cycle as valid. Each model
    // therefore drives arb_read_data and arb_read_valid together (blocking) from
    // the frame memory, advancing the beat index per accepted beat. This matches
    // the arbiter_response reference model in the dma_read IP testbench.
    //--------------------------------------------------------------------------
    task automatic ddr4_8gb_arb_model();
        int unsigned beats;
        forever begin
            @(posedge ddr_clk);
            if (ddr4_8gb_arb_read_req) begin
                // Latch the requested beat count (burst_len is beats - 1)
                beats = ddr4_8gb_arb_read_burst_len + 1;
                // Acknowledge the request for one cycle
                ddr4_8gb_arb_read_ack = 1'b1;
                @(posedge ddr_clk);
                ddr4_8gb_arb_read_ack = 1'b0;
                // Read latency before data is returned
                repeat (2) @(posedge ddr_clk);
                // Drive valid read beats, presenting file data in lockstep
                for (int unsigned i = 0; i < beats; i++) begin
                    ddr4_8gb_arb_read_valid = 1'b1;
                    if (ddr4_8gb_beat_idx < ddr4_8gb_frame_mem.size()) begin
                        ddr4_8gb_arb_read_data = ddr4_8gb_frame_mem[ddr4_8gb_beat_idx];
                        ddr4_8gb_beat_idx++;
                    end else begin
                        ddr4_8gb_arb_read_data = '0;
                    end
                    @(posedge ddr_clk);
                end
                ddr4_8gb_arb_read_valid = 1'b0;
                ddr4_8gb_arb_read_data  = '0;
                // Signal completion for one cycle
                ddr4_8gb_arb_read_done = 1'b1;
                @(posedge ddr_clk);
                ddr4_8gb_arb_read_done = 1'b0;
            end
        end
    endtask

    task automatic ddr4_16gb_arb_model();
        int unsigned beats;
        forever begin
            @(posedge ddr_clk);
            if (ddr4_16gb_arb_read_req) begin
                // Latch the requested beat count (burst_len is beats - 1)
                beats = ddr4_16gb_arb_read_burst_len + 1;
                // Acknowledge the request for one cycle
                ddr4_16gb_arb_read_ack = 1'b1;
                @(posedge ddr_clk);
                ddr4_16gb_arb_read_ack = 1'b0;
                // Read latency before data is returned
                repeat (2) @(posedge ddr_clk);
                // Drive valid read beats, presenting file data in lockstep
                for (int unsigned i = 0; i < beats; i++) begin
                    ddr4_16gb_arb_read_valid = 1'b1;
                    if (ddr4_16gb_beat_idx < ddr4_16gb_frame_mem.size()) begin
                        ddr4_16gb_arb_read_data = ddr4_16gb_frame_mem[ddr4_16gb_beat_idx];
                        ddr4_16gb_beat_idx++;
                    end else begin
                        ddr4_16gb_arb_read_data = '0;
                    end
                    @(posedge ddr_clk);
                end
                ddr4_16gb_arb_read_valid = 1'b0;
                ddr4_16gb_arb_read_data  = '0;
                // Signal completion for one cycle
                ddr4_16gb_arb_read_done = 1'b1;
                @(posedge ddr_clk);
                ddr4_16gb_arb_read_done = 1'b0;
            end
        end
    endtask

    //--------------------------------------------------------------------------
    // Frame data file loaders
    //
    // Each file is loaded once into a beat memory (little-endian 32-bit words
    // packed into DATA_WIDTH-wide beats). The arbiter models above stream the
    // beats to the DUT. The data content itself is not checked; only that the
    // exact recorded bytes are returned in order.
    //--------------------------------------------------------------------------

    // DDR4 8GB frame file loader
    initial begin
        int                             fd;
        int                             wcnt;
        logic [31:0]                    word;
        logic [DDR4_8GB_DATA_WIDTH-1:0] beat;

        ddr4_8gb_arb_read_data = '0;

        // Optional command-line override of the frame file path
        void'($value$plusargs("DDR4_8GB_FRAME_FILE=%s", ddr4_8gb_frame_file));

        // Load the raw frame file into the beat memory
        fd = $fopen(ddr4_8gb_frame_file, "rb");
        if (fd == 0) begin
            $display("[%0t] WARN: could not open %s (8GB read data will be zero)",
                     $time, ddr4_8gb_frame_file);
        end else begin
            wcnt = 0;
            beat = '0;
            while ($fread(word, fd) == 4) begin
                beat[wcnt*32 +: 32] = word;
                wcnt++;
                if (wcnt == DDR4_8GB_DATA_WIDTH/32) begin
                    ddr4_8gb_frame_mem.push_back(beat);
                    wcnt = 0;
                    beat = '0;
                end
            end
            if (wcnt != 0) ddr4_8gb_frame_mem.push_back(beat);
            $fclose(fd);
            $display("[%0t] Loaded %0d beats from %s",
                     $time, ddr4_8gb_frame_mem.size(), ddr4_8gb_frame_file);
        end
    end

    // DDR4 16GB frame file loader
    initial begin
        int                              fd;
        int                              wcnt;
        logic [31:0]                     word;
        logic [DDR4_16GB_DATA_WIDTH-1:0] beat;

        ddr4_16gb_arb_read_data = '0;

        // Optional command-line override of the frame file path
        void'($value$plusargs("DDR4_16GB_FRAME_FILE=%s", ddr4_16gb_frame_file));

        // Load the raw frame file into the beat memory
        fd = $fopen(ddr4_16gb_frame_file, "rb");
        if (fd == 0) begin
            $display("[%0t] WARN: could not open %s (16GB read data will be zero)",
                     $time, ddr4_16gb_frame_file);
        end else begin
            wcnt = 0;
            beat = '0;
            while ($fread(word, fd) == 4) begin
                beat[wcnt*32 +: 32] = word;
                wcnt++;
                if (wcnt == DDR4_16GB_DATA_WIDTH/32) begin
                    ddr4_16gb_frame_mem.push_back(beat);
                    wcnt = 0;
                    beat = '0;
                end
            end
            if (wcnt != 0) ddr4_16gb_frame_mem.push_back(beat);
            $fclose(fd);
            $display("[%0t] Loaded %0d beats from %s",
                     $time, ddr4_16gb_frame_mem.size(), ddr4_16gb_frame_file);
        end
    end

    //--------------------------------------------------------------------------
    // MTX transmit-side capture to pcap files
    //
    // Each transmitted MTX packet begins on the first MTXRDY cycle marked by
    // MTXSOF and ends on the MTXRDY cycle marked by MTXEOF. Every accepted beat
    // (MTXRDY && MTXACPT) contributes MTX_DATA_WIDTH/8 payload bytes in wire
    // (transmission) order, i.e. MTXDAT[7:0] first (this matches the octet swap
    // applied by udp_tx before the MAC). On the EOF beat the number of valid
    // bytes is taken from MTXBYTEVALID (0->4, 1->3, 2->2, 3->1), matching the
    // udp_tx MAC tkeep encoding. All packets belonging to one source frame are
    // written into a single little-endian pcap file (LINKTYPE_ETHERNET) opened
    // by the stimulus around each frame transfer.
    //--------------------------------------------------------------------------
    int         mtx_pcap_fd = 0;
    logic [7:0] mtx_pkt_bytes [$];

    // Separate pcap file that holds the responder (ARP/ICMP) request and reply
    // packets exchanged on the MRX/MTX paths.
    int         rsp_pcap_fd = 0;

    // Number of udp_clk idle cycles (MTXRDY low) used to declare a frame fully
    // drained. Must exceed the inter-packet frame gap (FRAME_GAP_DEFAULT = 1000
    // udp_clk cycles in udp_tx) so a within-frame gap is never mistaken for the
    // end of the frame.
    localparam int MTX_DRAIN_IDLE_CYCLES = 2000;

    // Emit a little-endian 32-bit value as four raw bytes
    task automatic pcap_wr32(input int fd, input logic [31:0] val);
        $fwrite(fd, "%c", val[7:0]);
        $fwrite(fd, "%c", val[15:8]);
        $fwrite(fd, "%c", val[23:16]);
        $fwrite(fd, "%c", val[31:24]);
    endtask

    // Emit a little-endian 16-bit value as two raw bytes
    task automatic pcap_wr16(input int fd, input logic [15:0] val);
        $fwrite(fd, "%c", val[7:0]);
        $fwrite(fd, "%c", val[15:8]);
    endtask

    // Open a pcap file, write the 24-byte global header, and return the fd
    function automatic int pcap_open(input string fname);
        int fd;
        fd = $fopen(fname, "wb");
        if (fd == 0) begin
            $display("[%0t] WARN: could not open %s for pcap capture", $time, fname);
        end else begin
            pcap_wr32(fd, 32'ha1b2c3d4); // magic (usec, little-endian)
            pcap_wr16(fd, 16'd2);        // version major
            pcap_wr16(fd, 16'd4);        // version minor
            pcap_wr32(fd, 32'd0);        // thiszone
            pcap_wr32(fd, 32'd0);        // sigfigs
            pcap_wr32(fd, 32'd65535);    // snaplen
            pcap_wr32(fd, 32'd1);        // network = LINKTYPE_ETHERNET
            $display("[%0t] Opened pcap capture %s", $time, fname);
        end
        return fd;
    endfunction

    // Open a new per-frame MTX pcap file
    task automatic open_pcap(input string fname);
        mtx_pkt_bytes.delete();
        mtx_pcap_fd = pcap_open(fname);
    endtask

    // Close the current pcap file (if open)
    task automatic close_pcap();
        if (mtx_pcap_fd != 0) begin
            $fclose(mtx_pcap_fd);
            mtx_pcap_fd = 0;
        end
    endtask

    // Write the accumulated packet bytes as a single pcap record
    task automatic write_pcap_packet();
        pcap_write_record(mtx_pcap_fd, mtx_pkt_bytes);
    endtask

    // Write a byte queue (network order) as a single pcap record to fd
    task automatic pcap_write_record(input int fd, ref logic [7:0] q[$]);
        longint unsigned ts_ns;
        logic [31:0]     ts_sec;
        logic [31:0]     ts_usec;
        int              len;
        len = q.size();
        if (fd != 0 && len > 0) begin
            ts_ns   = $time;                       // timescale time unit is 1ns
            ts_sec  = ts_ns / 1000000000;
            ts_usec = (ts_ns % 1000000000) / 1000;
            pcap_wr32(fd, ts_sec);
            pcap_wr32(fd, ts_usec);
            pcap_wr32(fd, len);                    // incl_len
            pcap_wr32(fd, len);                    // orig_len
            foreach (q[i]) begin
                $fwrite(fd, "%c", q[i]);
            end
        end
    endtask

    // Wait until the MTX transmit stream has been idle (MTXRDY low) for a
    // contiguous run of idle_cycles udp_clk cycles, i.e. the current frame's
    // packets have all been transmitted and captured.
    task automatic wait_mtx_drain(input int idle_cycles);
        int cnt;
        cnt = 0;
        while (cnt < idle_cycles) begin
            @(posedge udp_clk);
            if (MTXRDY && MTXACPT) cnt = 0;
            else                   cnt = cnt + 1;
        end
    endtask

    // MTX packet capture process: accumulate payload bytes for the packet in
    // flight and write each completed packet to the open pcap file.
    initial begin
        int nbytes;
        forever begin
            @(posedge udp_clk);
            if (MTXRDY && MTXACPT && mtx_pcap_fd != 0) begin
                // MTXSOF marks the first beat of a new packet
                if (MTXSOF) mtx_pkt_bytes.delete();
                // Number of valid payload bytes on this beat
                if (MTXEOF) begin
                    case (MTXBYTEVALID)
                        2'd0:    nbytes = 4;
                        2'd1:    nbytes = 3;
                        2'd2:    nbytes = 2;
                        default: nbytes = 1;
                    endcase
                end else begin
                    nbytes = MTX_DATA_WIDTH/8;
                end
                // Append bytes in wire (transmission) order: MTXDAT[7:0] first
                for (int b = 0; b < nbytes; b++) begin
                    mtx_pkt_bytes.push_back(MTXDAT[b*8 +: 8]);
                end
                // MTXEOF marks the last beat of the packet
                if (MTXEOF) write_pcap_packet();
            end
        end
    end

    //--------------------------------------------------------------------------
    // ARP / ICMP request injection on the MRX (MAC receive) path
    //
    // The responder core (rsp_top) terminates the MRX stream and, for a
    // matching ARP request or ICMP echo request addressed to the board, emits
    // the reply on the MTX path (muxed ahead of the UDP TX core). Bytes on
    // MRXDAT are in wire (network) order with MRXDAT[7:0] carrying the earliest
    // byte; the last beat of a packet encodes its valid byte count in
    // MRXBYTEVALID (0->4, 1->3, 2->2, 3->1), matching the width converter in
    // rsp_top.
    //--------------------------------------------------------------------------

    // Board (FPGA) and remote host addressing, derived from the UDP config
    localparam logic [47:0] BOARD_MAC = {ETH1_SRC_MAC_MSB, ETH1_SRC_MAC_LSB};
    localparam logic [31:0] BOARD_IP  = ETH1_SRC_IP;
    localparam logic [47:0] HOST_MAC  = {ETH1_DST_MAC_MSB, ETH1_DST_MAC_LSB};
    localparam logic [31:0] HOST_IP   = ETH1_DST_IP;

    // Response-wait timeout in udp_clk cycles (100 MHz -> 10 ns/cycle)
    localparam int MTX_RSP_TIMEOUT_CYCLES = 50000;

    // Ethernet minimum frame size. The CoreTSE MAC pads received runt frames up
    // to the 64-byte Ethernet minimum before presenting them on MRX, so short
    // frames such as a 42-byte ARP request arrive zero-padded. Frames are padded
    // for transmission only; the pcap still records the original unpadded bytes.
    localparam int MIN_MRX_FRAME_BYTES = 64;

    // Test pass/fail accounting
    int test_pass = 0;
    int test_fail = 0;

    // Push the low nbytes of val into q in network order (MSB first)
    task automatic push_n(ref logic [7:0] q[$], input logic [63:0] val, input int nbytes);
        for (int i = nbytes - 1; i >= 0; i--) q.push_back(val[i*8 +: 8]);
    endtask

    // Read a big-endian 16-bit field from a byte queue at byte offset off
    function automatic logic [15:0] be16(const ref logic [7:0] q[$], input int off);
        if (off + 1 < q.size()) return {q[off], q[off+1]};
        return 16'hFFFF;
    endfunction

    // Hex-dump a captured byte queue (up to the first 64 bytes) for debug
    task automatic dump_bytes(input string tag, const ref logic [7:0] q[$]);
        string line;
        int    n;
        n = q.size();
        if (n > 64) n = 64;
        $display("[%0t] %s captured %0d bytes%s:", $time, tag, q.size(),
                 (q.size() > 64) ? " (first 64 shown)" : "");
        line = "";
        for (int i = 0; i < n; i++) begin
            line = {line, $sformatf("%02x ", q[i])};
            if ((i % 16) == 15) begin
                $display("    %s", line);
                line = "";
            end
        end
        if (line != "") $display("    %s", line);
    endtask

    // Send a full packet (byte queue, network order) over the 32-bit MRX path.
    // MRXRDY is held continuously high for the whole packet; the data word only
    // advances on cycles where the responder accepts a beat (MRXACPT high), so
    // there is no idle bubble between beats.
    task automatic mrx_send_packet(ref logic [7:0] q[$]);
        logic [7:0]  tx[$];
        int          total;
        int          idx;
        int          rem;
        int          valid;
        logic [31:0] w;
        // Work on a local copy so the caller's queue (recorded to the pcap)
        // keeps its original, unpadded length. Runt frames are zero-padded up
        // to the Ethernet minimum, matching how the MAC presents them on MRX.
        tx = q;
        while (tx.size() < MIN_MRX_FRAME_BYTES) tx.push_back(8'h00);
        total = tx.size();
        idx   = 0;
        // Present the first beat
        @(posedge udp_clk);
        while (idx < total) begin
            rem   = total - idx;
            valid = (rem > 4) ? 4 : rem;
            w     = 32'd0;
            for (int b = 0; b < valid; b++) w[b*8 +: 8] = tx[idx + b];
            MRXDAT       <= w;
            MRXSOF       <= (idx == 0);
            MRXEOF       <= (rem <= 4);
            // bytevalid encodes valid bytes as (4 - valid), full beat -> 0
            MRXBYTEVALID <= 2'(4 - valid);
            MRXRDY       <= 1'b1;
            // Advance to the next beat only once this one is accepted
            do @(posedge udp_clk); while (!MRXACPT);
            idx += 4;
        end
        // Deassert after the final accepted beat
        MRXRDY       <= 1'b0;
        MRXSOF       <= 1'b0;
        MRXEOF       <= 1'b0;
        MRXBYTEVALID <= 2'd0;
        MRXDAT       <= 32'd0;
    endtask

    // Wait for one complete packet on the MTX path (SOF..EOF). Returns ok=0 on
    // timeout. Captured bytes (network order) are returned in resp. On timeout a
    // diagnostic summarises what the MTX stream actually did (beats seen, and
    // whether SOF/EOF were ever observed) so a capture-framing failure can be
    // told apart from a genuinely missing reply.
    task automatic mtx_wait_response(input string tag, output bit ok, ref logic [7:0] resp[$]);
        int cnt;
        int nbytes;
        bit in_pkt;
        int rdy_beats;
        int sof_seen;
        int eof_seen;
        resp.delete();
        in_pkt    = 1'b0;
        cnt       = 0;
        ok        = 1'b0;
        rdy_beats = 0;
        sof_seen  = 0;
        eof_seen  = 0;
        forever begin
            @(posedge udp_clk);
            cnt++;
            if (cnt > MTX_RSP_TIMEOUT_CYCLES) begin
                $display("[%0t] %s MTX capture timeout: %0d rdy-beats, sof_seen=%0d, eof_seen=%0d, in_pkt=%0b, partial=%0d bytes",
                         $time, tag, rdy_beats, sof_seen, eof_seen, in_pkt, resp.size());
                return;
            end
            if (MTXRDY && MTXACPT) begin
                rdy_beats++;
                if (MTXSOF) sof_seen++;
                if (MTXEOF) eof_seen++;
                if (MTXSOF) begin
                    resp.delete();
                    in_pkt = 1'b1;
                end
                if (in_pkt) begin
                    if (MTXEOF) begin
                        case (MTXBYTEVALID)
                            2'd0:    nbytes = 4;
                            2'd1:    nbytes = 3;
                            2'd2:    nbytes = 2;
                            default: nbytes = 1;
                        endcase
                    end else begin
                        nbytes = MTX_DATA_WIDTH/8;
                    end
                    for (int b = 0; b < nbytes; b++) resp.push_back(MTXDAT[b*8 +: 8]);
                    if (MTXEOF) begin
                        ok = 1'b1;
                        return;
                    end
                end
            end
        end
    endtask

    // Build an ARP request: host asks for the board's MAC (target IP = board IP)
    task automatic build_arp_request(ref logic [7:0] q[$]);
        q.delete();
        push_n(q, 48'hFFFFFFFFFFFF, 6); // dst MAC (broadcast)
        push_n(q, HOST_MAC,         6); // src MAC (host)
        push_n(q, 16'h0806,         2); // ethertype = ARP
        push_n(q, 16'h0001,         2); // HTYPE = Ethernet
        push_n(q, 16'h0800,         2); // PTYPE = IPv4
        push_n(q, 8'h06,            1); // HLEN
        push_n(q, 8'h04,            1); // PLEN
        push_n(q, 16'h0001,         2); // OPER = request
        push_n(q, HOST_MAC,         6); // sender MAC
        push_n(q, HOST_IP,          4); // sender IP
        push_n(q, 48'h000000000000, 6); // target MAC (unknown)
        push_n(q, BOARD_IP,         4); // target IP = board
    endtask

    // Build an ICMP echo (ping) request to the board with the given sequence.
    // The IPv4 header checksum is a placeholder (the responder does not validate
    // it on receive). The ICMP checksum is a one's-complement sum, so bumping
    // the sequence field up by 1 lowers the checksum by 1; it is derived from a
    // base value (valid for seq=1) so successive requests carry the correct,
    // decrementing checksum.
    task automatic build_ping_request(ref logic [7:0] q[$], input logic [15:0] seq);
        logic [15:0] icmp_cksum;
        q.delete();
        // ICMP checksum tracks the sequence: base (0x12fc at seq=1) minus the
        // sequence delta, with one's-complement end-around borrow.
        icmp_cksum = 16'h12fc - (seq - 16'd1);
        if (seq > 16'd1 + 16'h12fc) icmp_cksum -= 16'd1; // end-around borrow
        // Ethernet header
        push_n(q, BOARD_MAC, 6);            // dst MAC = board
        push_n(q, HOST_MAC,  6);            // src MAC = host
        push_n(q, 16'h0800,  2);            // ethertype = IPv4
        // IPv4 header
        push_n(q, 16'h4500,  2);            // version/IHL, DSCP/ECN
        push_n(q, 16'h0054,  2);            // total length = 84
        push_n(q, 16'h645c,  2);            // identification
        push_n(q, 16'h4000,  2);            // flags/fragment offset
        push_n(q, 8'h40,     1);            // TTL
        push_n(q, 8'h01,     1);            // protocol = ICMP
        push_n(q, 16'h0afd,  2);            // header checksum (placeholder)
        push_n(q, HOST_IP,   4);            // source IP = host
        push_n(q, BOARD_IP,  4);            // destination IP = board
        // ICMP echo request
        push_n(q, 8'h08,     1);            // type = echo request
        push_n(q, 8'h00,     1);            // code
        push_n(q, icmp_cksum, 2);           // checksum (decrements as seq rises)
        push_n(q, 16'h79d7,  2);            // identifier
        push_n(q, seq,       2);            // sequence number
        // 56 bytes of ICMP payload (16-byte timestamp area + 40-byte pattern)
        push_n(q, 64'hb4ad036900000000, 8);
        push_n(q, 64'heb41090000000000, 8);
        for (int i = 0; i < 40; i++) push_n(q, 8'h10 + i, 1);
    endtask

    // Send an ARP request and check for a valid ARP reply on MTX
    task automatic run_arp_test(input string tag);
        logic [7:0] req[$];
        logic [7:0] resp[$];
        bit         ok;
        bit         pass;
        build_arp_request(req);
        // The responder is cut-through: it can begin driving the reply on MTX
        // while the request is still being sent on MRX. Arm the MTX capture
        // concurrently with the send so the reply's SOF is never missed.
        fork
            mrx_send_packet(req);
            mtx_wait_response(tag, ok, resp);
        join
        // Record both the request and the reply into the responder pcap
        pcap_write_record(rsp_pcap_fd, req);
        if (ok) pcap_write_record(rsp_pcap_fd, resp);
        // Valid ARP reply: ethertype 0x0806 and opcode 0x0002
        pass = ok && (resp.size() >= 22) &&
               (be16(resp, 12) == 16'h0806) && (be16(resp, 20) == 16'h0002);
        if (pass) begin
            test_pass++;
            $display("[%0t] %s PASS: ARP reply received (%0d bytes)",
                     $time, tag, resp.size());
        end else begin
            test_fail++;
            if (!ok) $display("[%0t] %s FAIL: no ARP reply (timeout)", $time, tag);
            else     $display("[%0t] %s FAIL: unexpected reply (%0d bytes)",
                              $time, tag, resp.size());
            dump_bytes(tag, resp);
        end
    endtask

    // Send an ICMP echo request and check for a valid ICMP echo reply on MTX
    task automatic run_ping_test(input string tag, input logic [15:0] seq);
        logic [7:0] req[$];
        logic [7:0] resp[$];
        bit         ok;
        bit         pass;
        build_ping_request(req, seq);
        // The responder is cut-through: it can begin driving the reply on MTX
        // while the request is still being sent on MRX. Arm the MTX capture
        // concurrently with the send so the reply's SOF is never missed.
        fork
            mrx_send_packet(req);
            mtx_wait_response(tag, ok, resp);
        join
        // Record both the request and the reply into the responder pcap
        pcap_write_record(rsp_pcap_fd, req);
        if (ok) pcap_write_record(rsp_pcap_fd, resp);
        // Valid ICMP echo reply: ethertype 0x0800, IP protocol 0x01, ICMP type 0x00
        pass = ok && (resp.size() >= 35) &&
               (be16(resp, 12) == 16'h0800) && (resp[23] == 8'h01) && (resp[34] == 8'h00);
        if (pass) begin
            test_pass++;
            $display("[%0t] %s PASS: ICMP echo reply received (seq=%0d, %0d bytes)",
                     $time, tag, seq, resp.size());
        end else begin
            test_fail++;
            if (!ok) $display("[%0t] %s FAIL: no ICMP reply (seq=%0d, timeout)",
                              $time, tag, seq);
            else     $display("[%0t] %s FAIL: unexpected reply (seq=%0d, %0d bytes)",
                              $time, tag, seq, resp.size());
            dump_bytes(tag, resp);
        end
    endtask

    //--------------------------------------------------------------------------
    // Stimulus
    //--------------------------------------------------------------------------
    initial begin
        // Initialize APB inputs
        psel    = 1'b0;
        penable = 1'b0;
        pwrite  = 1'b0;
        paddr   = '0;
        pwdata  = '0;

        // MTX transmit-side accept (MAC ready to receive TX frames)
        MTXACPT = 1'b1;

        // MTX receive path idle (unused in this read test)
        MRXRDY       = 1'b0;
        MRXDAT       = '0;
        MRXEOF       = 1'b0;
        MRXBYTEVALID = '0;
        MRXSOF       = 1'b0;

        // Initialize DDR4 read arbiter handshake signals
        ddr4_8gb_arb_read_ack    = 1'b0;
        ddr4_8gb_arb_read_valid  = 1'b0;
        ddr4_8gb_arb_read_done   = 1'b0;

        ddr4_16gb_arb_read_ack   = 1'b0;
        ddr4_16gb_arb_read_valid = 1'b0;
        ddr4_16gb_arb_read_done  = 1'b0;

        // Wait for resets to be released
        wait (presetn && udp_rst_n && ddr_rst_n);
        repeat (5) @(posedge pclk);

        // Start the DDR4 read arbiter models for both cores
        fork
            ddr4_8gb_arb_model();
            ddr4_16gb_arb_model();
        join_none

        // Configure the UDP TX core
        configure_udp1();
        repeat (5) @(posedge pclk);

        // Reset the DMA read controllers for both DDR4 cores
        reset_dma_read_ctrl(DMA_READ_CTRL_DDR4_8GB_BASE_ADDR);
        reset_dma_read_ctrl(DMA_READ_CTRL_DDR4_16GB_BASE_ADDR);
        repeat (5) @(posedge pclk);

        // Configure the DMA read controllers (frame geometry)
        configure_dma_read_ctrl(DMA_READ_CTRL_DDR4_8GB_BASE_ADDR,
                                LINES_PER_FRAME, HORIZ_WIDTH_BYTE, HORIZ_WIDTH_BEAT_8GB);
        configure_dma_read_ctrl(DMA_READ_CTRL_DDR4_16GB_BASE_ADDR,
                                LINES_PER_FRAME, HORIZ_WIDTH_BYTE, HORIZ_WIDTH_BEAT_16GB);
        repeat (5) @(posedge pclk);

        //----------------------------------------------------------------------
        // Responder checks: one ARP request followed by three ICMP echo
        // requests, injected on the MRX path. Each reply is awaited on the MTX
        // path before the next request is sent. All request and reply packets
        // are captured into a single responder.pcap file.
        //----------------------------------------------------------------------
        $display("[%0t] Waiting for responder PHY init to complete...", $time);
        wait (dut.rsp_core_busy == 1'b0);
        repeat (5) @(posedge udp_clk);
        $display("[%0t] Responder ready (PHY init complete)", $time);

        rsp_pcap_fd = pcap_open("responder.pcap");

        $display("[%0t] SCENARIO 1: ARP request/reply", $time);
        run_arp_test("SCENARIO 1");

        $display("[%0t] SCENARIO 2: ICMP echo request #1", $time);
        run_ping_test("SCENARIO 2", 16'd1);

        $display("[%0t] SCENARIO 3: ICMP echo request #2", $time);
        run_ping_test("SCENARIO 3", 16'd2);

        $display("[%0t] SCENARIO 4: ICMP echo request #3", $time);
        run_ping_test("SCENARIO 4", 16'd3);

        if (rsp_pcap_fd != 0) begin
            $fclose(rsp_pcap_fd);
            rsp_pcap_fd = 0;
        end

        repeat (5) @(posedge pclk);

        // Transfer frames via UDP: 16GB frames first, then 8GB frames
        for (int index = 0; index < NUM_16GB_FRAMES + NUM_8GB_FRAMES; index++) begin
            if (index < NUM_16GB_FRAMES) begin
                // Restart the raw file at the beginning for this frame
                ddr4_16gb_beat_idx = 0;
                set_read_mux(UDP_TX_BASE_ADDR, UDP_MUX_SELECT_DDR4_16GB);
                open_pcap($sformatf("ddr4_16gb_frame_%0d.pcap", index));
                xfer_frame_via_udp(DMA_READ_CTRL_DDR4_16GB_BASE_ADDR, index);
                wait_mtx_drain(MTX_DRAIN_IDLE_CYCLES);
                close_pcap();
            end else begin
                // Restart the raw file at the beginning for this frame
                ddr4_8gb_beat_idx = 0;
                set_read_mux(UDP_TX_BASE_ADDR, UDP_MUX_SELECT_DDR4_8GB);
                open_pcap($sformatf("ddr4_8gb_frame_%0d.pcap", index - NUM_16GB_FRAMES));
                xfer_frame_via_udp(DMA_READ_CTRL_DDR4_8GB_BASE_ADDR, index - NUM_16GB_FRAMES);
                wait_mtx_drain(MTX_DRAIN_IDLE_CYCLES);
                close_pcap();
            end
        end

        repeat (20) @(posedge pclk);
        $display("[%0t] All frame transfers complete", $time);
        $display("[%0t] TEST SUMMARY: %0d passed, %0d failed",
                 $time, test_pass, test_fail);
        if (test_fail == 0) $display("[%0t] RESULT: PASS", $time);
        else                $display("[%0t] RESULT: FAIL", $time);
        $finish;
    end

    //--------------------------------------------------------------------------
    // VCD dump
    //--------------------------------------------------------------------------
    initial begin
        $dumpfile("read_ddr_to_mtx_tb.vcd");
        $dumpvars(0, read_ddr_to_mtx_tb);
    end

endmodule