`timescale 1ns/1ps

module dma_read_tb;

//------------------------------------------------------------------------------
// Parameters
//------------------------------------------------------------------------------
parameter DDR_ADDR_WIDTH  = 38;
parameter DDR_DATA_WIDTH  = 512;
parameter DATA_OUT_WIDTH  = 256;
parameter DDR_CLK_PERIOD  = 5;   // 200MHz
parameter CTRL_CLK_PERIOD = 20;  // 50MHz

//------------------------------------------------------------------------------
// DUT Signals
//------------------------------------------------------------------------------
logic                      ddr_clk;
logic                      ddr_rst_n;
logic                      ctrl_clk;
logic                      ctrl_rst_n;

// Controller read interface
logic                      ctrl_info_valid;
logic [8:0]                ctrl_burst_count;
logic [DDR_ADDR_WIDTH-1:0] ctrl_read_addr;

// DMA to Controller handshaking
logic                      dma_ready;
logic                      dma_read_req;
logic                      dma_read_ack;
logic                      dma_fifo_clear;

// FIFO read interface
logic                      m_axis_dma_tready;
logic                      m_axis_dma_tvalid;
logic [DATA_OUT_WIDTH-1:0] m_axis_dma_tdata;

// DMA to Arbiter interface
logic                      arb_read_req;
logic                      arb_read_ack;
logic [7:0]                arb_read_burst_len;
logic [DDR_ADDR_WIDTH-1:0] arb_read_start_addr;
logic                      arb_read_done;
logic                      arb_read_valid;
logic [DDR_DATA_WIDTH-1:0] arb_data_in;

// FIFO signals
logic                      fifo_write_rst_n;
logic                      fifo_write_en;
logic [DDR_DATA_WIDTH-1:0] fifo_write_data;
logic                      fifo_read_rst_n;
logic                      fifo_read_en;
logic                      fifo_read_valid;
logic [DATA_OUT_WIDTH-1:0] fifo_read_data;
logic                      fifo_empty;

//------------------------------------------------------------------------------
// Clock Generation
//------------------------------------------------------------------------------
initial begin
    ddr_clk = 0;
    forever #(DDR_CLK_PERIOD/2) ddr_clk = ~ddr_clk;
end

initial begin
    ctrl_clk = 0;
    forever #(CTRL_CLK_PERIOD/2) ctrl_clk = ~ctrl_clk;
end

//------------------------------------------------------------------------------
// DUT Instantiation
//------------------------------------------------------------------------------
dma_read #(
    .DDR_ADDR_WIDTH (DDR_ADDR_WIDTH),
    .DDR_DATA_WIDTH (DDR_DATA_WIDTH),
    .DATA_OUT_WIDTH (DATA_OUT_WIDTH)
) dut (
    .ddr_clk(ddr_clk),
    .ddr_rst_n(ddr_rst_n),
    .ctrl_clk(ctrl_clk),
    .ctrl_rst_n(ctrl_rst_n),

    .ctrl_info_valid(ctrl_info_valid),
    .ctrl_burst_count(ctrl_burst_count),
    .ctrl_read_addr(ctrl_read_addr),

    .dma_ready(dma_ready),
    .dma_read_req(dma_read_req),
    .dma_read_ack(dma_read_ack),
    .dma_fifo_clear(dma_fifo_clear),

    .m_axis_dma_tready(m_axis_dma_tready),
    .m_axis_dma_tvalid(m_axis_dma_tvalid),
    .m_axis_dma_tdata(m_axis_dma_tdata),

    .arb_read_req(arb_read_req),
    .arb_read_ack(arb_read_ack),
    .arb_read_burst_len(arb_read_burst_len),
    .arb_read_start_addr(arb_read_start_addr),
    .arb_read_done(arb_read_done),
    .arb_read_valid(arb_read_valid),
    .arb_data_in(arb_data_in),

    .fifo_write_rst_n(fifo_write_rst_n),
    .fifo_write_en(fifo_write_en),
    .fifo_write_data(fifo_write_data),
    .fifo_read_rst_n(fifo_read_rst_n),
    .fifo_read_en(fifo_read_en),
    .fifo_read_valid(fifo_read_valid),
    .fifo_read_data(fifo_read_data),
    .fifo_empty(fifo_empty)
);

//------------------------------------------------------------------------------
// Simple FIFO Model (for testing)
//------------------------------------------------------------------------------
logic [DDR_DATA_WIDTH-1:0] fifo_mem [0:511];
int fifo_wr_ptr = 0;
int fifo_rd_ptr = 0;
int fifo_count = 0;

always_ff @(posedge ddr_clk or negedge fifo_write_rst_n) begin
    if (!fifo_write_rst_n) begin
        fifo_wr_ptr <= 0;
    end else if (fifo_write_en) begin
        fifo_mem[fifo_wr_ptr] <= fifo_write_data;
        fifo_wr_ptr <= (fifo_wr_ptr + 1) % 512;
    end
end

always_ff @(posedge ctrl_clk or negedge fifo_read_rst_n) begin
    if (!fifo_read_rst_n) begin
        fifo_rd_ptr <= 0;
        fifo_read_valid <= 0;
        fifo_read_data <= 0;
    end else begin
        if (fifo_read_en && fifo_count > 0) begin
            fifo_read_valid <= 1;
            fifo_read_data <= fifo_mem[fifo_rd_ptr][DATA_OUT_WIDTH-1:0];
            fifo_rd_ptr <= (fifo_rd_ptr + 1) % 512;
        end else begin
            fifo_read_valid <= 0;
        end
    end
end

always_ff @(posedge ddr_clk) begin
    if (!fifo_write_rst_n || !fifo_read_rst_n) begin
        fifo_count <= 0;
    end else begin
        case ({fifo_write_en, fifo_read_en && (fifo_count > 0)})
            2'b10: fifo_count <= fifo_count + 1;
            2'b01: fifo_count <= fifo_count - 1;
            default: fifo_count <= fifo_count;
        endcase
    end
end

//------------------------------------------------------------------------------
// Reset Task
//------------------------------------------------------------------------------
task reset();
    ddr_rst_n = 0;
    ctrl_rst_n = 0;
    ctrl_info_valid = 0;
    ctrl_burst_count = 0;
    ctrl_read_addr = 0;
    fifo_empty = 0;
    dma_read_req = 0;
    dma_fifo_clear = 0;
    m_axis_dma_tready = 0;
    arb_read_ack = 0;
    arb_read_done = 0;
    arb_read_valid = 0;
    arb_data_in = 0;

    repeat(10) @(posedge ddr_clk);
    ddr_rst_n = 1;
    ctrl_rst_n = 1;
    repeat(10) @(posedge ddr_clk);
    $display("[%0t] Reset complete", $time);
endtask

//------------------------------------------------------------------------------
// Task: Configure DMA parameters
//------------------------------------------------------------------------------
task configure_dma(input [8:0] burst_cnt, input [DDR_ADDR_WIDTH-1:0] start_addr);
    @(posedge ctrl_clk);
    ctrl_info_valid = 1;
    ctrl_burst_count = burst_cnt;
    ctrl_read_addr = start_addr;
    @(posedge ctrl_clk);
    ctrl_info_valid = 0;
    $display("[%0t] Configured: burst_count=%0d, start_addr=0x%0h", $time, burst_cnt, start_addr);
endtask

//------------------------------------------------------------------------------
// Task: Simulate arbiter response
//------------------------------------------------------------------------------
task arbiter_response(input int burst_len);
    // Wait for read request
    wait(arb_read_req);
    repeat($urandom_range(1,5)) @(posedge ddr_clk);

    // Acknowledge request
    arb_read_ack = 1;
    @(posedge ddr_clk);
    arb_read_ack = 0;
    $display("[%0t] Arbiter acknowledged read request", $time);

    // Send data
    repeat($urandom_range(2,5)) @(posedge ddr_clk);
    for(int i = 0; i <= burst_len; i++) begin
        arb_read_valid = 1;
        arb_data_in = {2{$urandom(), $urandom()}};
        @(posedge ddr_clk);
    end
    arb_read_valid = 0;

    // Signal completion
    repeat(2) @(posedge ddr_clk);
    arb_read_done = 1;
    @(posedge ddr_clk);
    arb_read_done = 0;
    $display("[%0t] Arbiter completed transfer of %0d beats", $time, burst_len+1);
endtask

//------------------------------------------------------------------------------
// Task: Read data from FIFO
//------------------------------------------------------------------------------
task read_fifo_data(input int num_reads);
    fork
        begin
            for(int i = 0; i < num_reads; i++) begin
                @(posedge ctrl_clk);
                m_axis_dma_tready = 1;
                @(posedge ctrl_clk);
                if (m_axis_dma_tvalid) begin
                    $display("[%0t] Read data from FIFO: 0x%0h", $time, m_axis_dma_tdata);
                end
            end
            m_axis_dma_tready = 0;
        end
    join_none
endtask

//------------------------------------------------------------------------------
// Test Stimulus
//------------------------------------------------------------------------------
initial begin
    $display("========================================");
    $display("  DMA Read Controller Testbench");
    $display("========================================");

    reset();

    //----------------------------------------------------------------------
    // Test 1: Basic DMA Read Transaction
    //----------------------------------------------------------------------
    $display("\n[TEST 1] Basic DMA Read Transaction");
    configure_dma(9'd15, 38'h1000);

    fork
        begin
            @(posedge ddr_clk);
            wait(dma_ready);
            repeat(3) @(posedge ddr_clk);
            dma_read_req = 1;
            repeat(5) @(posedge ddr_clk);
            dma_read_req = 0;
        end
        arbiter_response(15);
    join

    // Wait for data and read from FIFO
    repeat(20) @(posedge ctrl_clk);
    read_fifo_data(16);

    // Signal receive done
    repeat(10) @(posedge ddr_clk);
    fifo_empty = 0;
    repeat(2) @(posedge ddr_clk);
    fifo_empty = 1;

    repeat(20) @(posedge ddr_clk);

    //----------------------------------------------------------------------
    // Test 2: Back-to-back transactions
    //----------------------------------------------------------------------
    $display("\n[TEST 2] Back-to-back DMA Transactions");

    for(int txn = 0; txn < 2; txn++) begin
        configure_dma(9'd7, 38'h2000 + (txn * 38'h100));

        fork
            begin
                @(posedge ddr_clk);
                wait(dma_ready);
                repeat(2) @(posedge ddr_clk);
                dma_read_req = 1;
                repeat(3) @(posedge ddr_clk);
                dma_read_req = 0;
            end
            arbiter_response(7);
        join

        repeat(15) @(posedge ctrl_clk);
        read_fifo_data(8);

        repeat(5) @(posedge ddr_clk);
        fifo_empty = 0;
        repeat(2) @(posedge ddr_clk);
        fifo_empty = 1;

        repeat(10) @(posedge ddr_clk);
    end

    //----------------------------------------------------------------------
    // Test 3: FIFO Clear
    //----------------------------------------------------------------------
    $display("\n[TEST 3] FIFO Clear Operation");
    dma_fifo_clear = 1;
    repeat(10) @(posedge ctrl_clk);
    dma_fifo_clear = 0;
    repeat(10) @(posedge ctrl_clk);
    $display("[%0t] FIFO Clear completed", $time);

    //----------------------------------------------------------------------
    // Test 4: Zero burst count
    //----------------------------------------------------------------------
    $display("\n[TEST 4] Zero Burst Count");
    configure_dma(9'd0, 38'h3000);

    fork
        begin
            @(posedge ddr_clk);
            wait(dma_ready);
            repeat(2) @(posedge ddr_clk);
            dma_read_req = 1;
            repeat(3) @(posedge ddr_clk);
            dma_read_req = 0;
        end
        arbiter_response(0);
    join

    repeat(10) @(posedge ddr_clk);
    fifo_empty = 0;
    repeat(2) @(posedge ddr_clk);
    fifo_empty = 1;

    repeat(20) @(posedge ddr_clk);

    //----------------------------------------------------------------------
    // Finish
    //----------------------------------------------------------------------
    repeat(50) @(posedge ddr_clk);
    $display("\n========================================");
    $display("  All Tests Completed");
    $display("========================================");
    $stop;
end

//------------------------------------------------------------------------------
// Timeout Watchdog
//------------------------------------------------------------------------------
initial begin
    #100us;
    $display("ERROR: Simulation timeout!");
    $stop;
end


endmodule