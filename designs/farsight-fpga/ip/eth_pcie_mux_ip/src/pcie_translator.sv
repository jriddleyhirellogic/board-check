/*
 * @file      pcie_translator.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      03/10/2026
 *
 * @brief     Translates narrow 64-bit PCIe AXI read interface to a wider DDR4
 *            AXI read interface. Slave is in pcie_clk domain; master is in
 *            ddr_clk domain. CDC is handled via async FIFOs. A double-buffer
 *            prefetch scheme hides DDR read latency: while buf[0] drains to
 *            the PCIe slave, buf[1] prefetches the next sequential 256-byte
 *            chunk. On address mismatch both buffers are flushed and refetched.
 *
 * @section changelog
 * - 03/10/2026: Steven Knyazher - Initial implementation
 *
 */

module pcie_translator #(
    parameter DDR4_DATA_WIDTH = 256, // 256 or 512
    parameter DDR4_ADDR_WIDTH = 38,  // 38 or 39
    parameter PCIE_DATA_WIDTH = 64,
    parameter PCIE_ADDR_WIDTH = 32,
    parameter PCIE_MAX_BURST  = 32
) (
    // Clocks and resets
    input  logic                               pcie_clk,
    input  logic                               pcie_resetn,
    input  logic                               ddr_clk,
    input  logic                               ddr_resetn,

    // DDR address-space index
    input  logic [$clog2(DDR4_DATA_WIDTH)-1:0] index,

    // Slave AXI - pcie_clk domain
    input  logic [3:0]                         s_awid,
    input  logic [PCIE_ADDR_WIDTH-1:0]         s_awaddr,
    input  logic [7:0]                         s_awlen,
    input  logic [2:0]                         s_awsize,
    input  logic [1:0]                         s_awburst,
    input  logic                               s_awvalid,
    output logic                               s_awready,
    input  logic [PCIE_DATA_WIDTH-1:0]         s_wdata,
    input  logic [PCIE_DATA_WIDTH/8-1:0]       s_wstrb,
    input  logic                               s_wlast,
    input  logic                               s_wvalid,
    output logic                               s_wready,
    output logic [3:0]                         s_bid,
    output logic [1:0]                         s_bresp,
    output logic                               s_bvalid,
    input  logic                               s_bready,
    input  logic [3:0]                         s_arid,
    input  logic [PCIE_ADDR_WIDTH-1:0]         s_araddr,
    input  logic [7:0]                         s_arlen,
    input  logic [2:0]                         s_arsize,
    input  logic [1:0]                         s_arburst,
    input  logic                               s_arvalid,
    output logic                               s_arready,
    output logic [3:0]                         s_rid,
    output logic [PCIE_DATA_WIDTH-1:0]         s_rdata,
    output logic [1:0]                         s_rresp,
    output logic                               s_rlast,
    output logic                               s_rvalid,
    input  logic                               s_rready,

    // Master AXI - ddr_clk domain
    output logic [3:0]                         m_awid,
    output logic [DDR4_ADDR_WIDTH-1:0]         m_awaddr,
    output logic [7:0]                         m_awlen,
    output logic [2:0]                         m_awsize,
    output logic [1:0]                         m_awburst,
    output logic                               m_awvalid,
    input  logic                               m_awready,
    output logic [DDR4_DATA_WIDTH-1:0]         m_wdata,
    output logic [DDR4_DATA_WIDTH/8-1:0]       m_wstrb,
    output logic                               m_wlast,
    output logic                               m_wvalid,
    input  logic                               m_wready,
    input  logic [3:0]                         m_bid,
    input  logic [1:0]                         m_bresp,
    input  logic                               m_bvalid,
    output logic                               m_bready,
    output logic [3:0]                         m_arid,
    output logic [DDR4_ADDR_WIDTH-1:0]         m_araddr,
    output logic [7:0]                         m_arlen,
    output logic [2:0]                         m_arsize,
    output logic [1:0]                         m_arburst,
    output logic                               m_arvalid,
    input  logic                               m_arready,
    input  logic [3:0]                         m_rid,
    input  logic [DDR4_DATA_WIDTH-1:0]         m_rdata,
    input  logic [1:0]                         m_rresp,
    input  logic                               m_rlast,
    input  logic                               m_rvalid,
    output logic                               m_rready
);

    localparam int DDR_BURSTS      = PCIE_MAX_BURST * PCIE_DATA_WIDTH / DDR4_DATA_WIDTH;
    localparam int BUF_BITS        = PCIE_MAX_BURST * PCIE_DATA_WIDTH;
    localparam int PREFETCH_OFFSET = BUF_BITS / 8;
    localparam int INDEX_W         = $clog2(DDR4_DATA_WIDTH);
    localparam int FETCH_CNT_W     = $clog2(DDR_BURSTS);
    localparam int DRAIN_CNT_W     = $clog2(PCIE_MAX_BURST);
    localparam int OFFSET_BITS     = $clog2(PREFETCH_OFFSET);
    localparam int WORD_BITS_LEN   = $clog2(PCIE_DATA_WIDTH / 8);
    localparam int START_WORD_W    = OFFSET_BITS - WORD_BITS_LEN;
    localparam int SUB_W           = $clog2(DDR4_DATA_WIDTH / PCIE_DATA_WIDTH);

    localparam logic [DDR4_ADDR_WIDTH-1:0] PREFETCH_STEP =
        DDR4_ADDR_WIDTH'(PREFETCH_OFFSET);

    // ----------------------------------------------------------------
    // Req FIFO: pcie_clk → ddr_clk  { aligned_addr, arid, arlen, start_word }
    // ----------------------------------------------------------------
    localparam int REQ_W     = DDR4_ADDR_WIDTH + 4 + 8 + START_WORD_W;
    localparam int REQ_DEPTH = 4;

    logic             req_wr_en;
    logic             req_wr_full;
    logic [REQ_W-1:0] req_wr_data;
    logic             req_rd_en;
    logic             req_rd_empty;
    logic [REQ_W-1:0] req_rd_data;

    pcie_translator_fifo #(
        .WIDTH    (REQ_W),
        .DEPTH    (REQ_DEPTH)
    ) u_req_fifo (
        .wr_clk   (pcie_clk),
        .wr_rst_n (pcie_resetn),
        .wr_en    (req_wr_en),
        .wr_data  (req_wr_data),
        .full     (req_wr_full),
        .rd_clk   (ddr_clk),
        .rd_rst_n (ddr_resetn),
        .rd_en    (req_rd_en),
        .rd_data  (req_rd_data),
        .empty    (req_rd_empty)
    );

    // ----------------------------------------------------------------
    // Resp FIFO: ddr_clk → pcie_clk  { rdata, rid, rresp, first_sub, last_sub, rlast }
    // One entry = one DDR beat; pcie side unpacks into PCIE_DATA_WIDTH sub-words.
    // ----------------------------------------------------------------
    localparam int RESP_W     = DDR4_DATA_WIDTH + 4 + 2 + SUB_W + SUB_W + 1;
    localparam int RESP_DEPTH = 2 * DDR_BURSTS;

    logic              resp_wr_en;
    logic              resp_wr_full;
    logic [RESP_W-1:0] resp_wr_data;
    logic              resp_rd_empty;
    logic              resp_rd_en;
    logic [RESP_W-1:0] resp_rd_data;

    pcie_translator_fifo #(
        .WIDTH(RESP_W),
        .DEPTH(RESP_DEPTH)
    ) u_resp_fifo (
        .wr_clk   (ddr_clk),
        .wr_rst_n (ddr_resetn),
        .wr_en    (resp_wr_en),
        .wr_data  (resp_wr_data),
        .full     (resp_wr_full),
        .rd_clk   (pcie_clk),
        .rd_rst_n (pcie_resetn),
        .rd_en    (resp_rd_en),
        .rd_data  (resp_rd_data),
        .empty    (resp_rd_empty)
    );

    // ----------------------------------------------------------------
    // PCIe clock domain
    // ----------------------------------------------------------------

    // Write path: stubbed
    assign s_awready = '0;
    assign s_wready  = '0;
    assign s_bid     = '0;
    assign s_bresp   = '0;
    assign s_bvalid  = '0;
    assign m_awid    = '0;
    assign m_awaddr  = '0;
    assign m_awlen   = '0;
    assign m_awsize  = '0;
    assign m_awburst = '0;
    assign m_awvalid = '0;
    assign m_wdata   = '0;
    assign m_wstrb   = '0;
    assign m_wlast   = '0;
    assign m_wvalid  = '0;
    assign m_bready  = '0;

    logic [DDR4_ADDR_WIDTH-1:0] pcie_full_addr;
    assign pcie_full_addr = {5'b0, index[INDEX_W-1:0], s_araddr[24:0]};

    logic [DDR4_ADDR_WIDTH-1:0] pcie_aligned_addr;
    logic [START_WORD_W-1:0]    pcie_start_word;
    assign pcie_aligned_addr = {pcie_full_addr[DDR4_ADDR_WIDTH-1:OFFSET_BITS], {OFFSET_BITS{1'b0}}};
    assign pcie_start_word   = pcie_full_addr[OFFSET_BITS-1 : WORD_BITS_LEN];

    logic ar_pending;
    always_ff @(posedge pcie_clk, negedge pcie_resetn) begin
        if (~pcie_resetn) begin
            ar_pending <= 1'b0;
        end else begin
            if (s_arvalid && s_arready) begin
                ar_pending <= 1'b1;
            end else if (s_rvalid && s_rready && s_rlast) begin
                ar_pending <= 1'b0;
            end
        end
    end

    assign s_arready   = ~ar_pending && ~req_wr_full;
    assign req_wr_en   = s_arvalid && s_arready;
    assign req_wr_data = {pcie_aligned_addr, s_arid, s_arlen, pcie_start_word};

    // Holding register: latched once per DDR beat, drained one PCIe sub-word per cycle.
    logic [DDR4_DATA_WIDTH-1:0] h_data;
    logic [3:0]                 h_id;
    logic [1:0]                 h_rresp;
    logic [SUB_W-1:0]           h_last_sub;
    logic                       h_rlast;
    logic [SUB_W-1:0]           h_sub;
    logic                       h_valid;

    // Pre-pop on the last sub-word so next beat is ready without a bubble.
    // h_just_latched blocks the early pop on the first output cycle after a latch,
    // before rd_data has settled to the new FIFO head.
    logic h_just_latched;
    assign resp_rd_en = ~resp_rd_empty &&
                        (~h_valid || (h_valid && s_rready &&
                                      (h_sub == h_last_sub) && ~h_just_latched));

    always_ff @(posedge pcie_clk, negedge pcie_resetn) begin
        if (~pcie_resetn) begin
            h_valid        <= 1'b0;
            h_sub          <= '0;
            h_data         <= '0;
            h_id           <= '0;
            h_rresp        <= '0;
            h_last_sub     <= '0;
            h_rlast        <= 1'b0;
            h_just_latched <= 1'b0;
        end else if (~h_valid && ~resp_rd_empty) begin
            h_data         <= resp_rd_data[RESP_W-1                        -: DDR4_DATA_WIDTH];
            h_id           <= resp_rd_data[RESP_W-DDR4_DATA_WIDTH-1        -: 4];
            h_rresp        <= resp_rd_data[RESP_W-DDR4_DATA_WIDTH-5        -: 2];
            h_sub          <= resp_rd_data[RESP_W-DDR4_DATA_WIDTH-7        -: SUB_W];
            h_last_sub     <= resp_rd_data[RESP_W-DDR4_DATA_WIDTH-7-SUB_W -: SUB_W];
            h_rlast        <= resp_rd_data[0];
            h_valid        <= 1'b1;
            h_just_latched <= 1'b1;
        end else if (h_valid && s_rready) begin
            h_just_latched <= 1'b0;
            if (h_sub == h_last_sub) begin
                if (~resp_rd_empty && ~h_just_latched) begin
                    h_data     <= resp_rd_data[RESP_W-1                        -: DDR4_DATA_WIDTH];
                    h_id       <= resp_rd_data[RESP_W-DDR4_DATA_WIDTH-1        -: 4];
                    h_rresp    <= resp_rd_data[RESP_W-DDR4_DATA_WIDTH-5        -: 2];
                    h_sub      <= resp_rd_data[RESP_W-DDR4_DATA_WIDTH-7        -: SUB_W];
                    h_last_sub <= resp_rd_data[RESP_W-DDR4_DATA_WIDTH-7-SUB_W -: SUB_W];
                    h_rlast    <= resp_rd_data[0];
                    h_valid    <= 1'b1;
                end else begin
                    h_valid <= 1'b0;
                end
            end else begin
                h_sub <= h_sub + 1'b1;
            end
        end
    end

    assign s_rvalid = h_valid;
    assign s_rdata  = h_data[h_sub * PCIE_DATA_WIDTH +: PCIE_DATA_WIDTH];
    assign s_rid    = h_id;
    assign s_rresp  = h_rresp;
    assign s_rlast  = h_rlast && (h_sub == h_last_sub);

    // ----------------------------------------------------------------
    // DDR clock domain
    // ----------------------------------------------------------------

    logic [BUF_BITS-1:0]        buf_data[2];
    logic [DDR4_ADDR_WIDTH-1:0] buf_addr[2];
    logic [1:0]                 buf_rresp[2];
    logic                       buf_valid[2];

    logic [DDR4_ADDR_WIDTH-1:0] cur_addr;
    logic [3:0]                 cur_id;
    logic [7:0]                 cur_len;
    logic [START_WORD_W-1:0]    cur_start_word;

    // ----------------------------------------------------------------
    // Fetch + Drain SMs (ddr_clk) - merged to eliminate F_CHECK and D_IDLE latency cycles.
    // ----------------------------------------------------------------
    typedef enum logic [2:0] {
        F_IDLE,        // pop request; evaluate hit/miss; launch drain
        F_AR,          // assert m_arvalid for buf[0] fetch
        F_R,           // collect DDR R beats into buf[0]
        F_PREFETCH_AR, // assert m_arvalid for buf[1] prefetch
        F_PREFETCH_R,  // collect DDR R beats into buf[1]
        F_WAIT         // wait for drain SM to reach D_DONE
    } fetch_sm_t;
    fetch_sm_t fetch_sm;

    typedef enum logic [2:0] {
        D_IDLE,  // idle (reset / between requests)
        D_RUN,   // streaming buf[0] DDR beats into resp_fifo
        D_WAIT1, // overflow: waiting for buf[1]
        D_RUN1,  // overflow: streaming buf[1] DDR beats
        D_DONE   // done; F_WAIT will clear both SMs together
    } drain_sm_t;
    drain_sm_t drain_sm;

    logic [FETCH_CNT_W:0] fetch_beat;
    logic [FETCH_CNT_W:0] prefetch_beat;
    logic [FETCH_CNT_W:0] drain_word;

    logic [6:0]           drain_total;
    logic                 cur_overflow;
    logic [DRAIN_CNT_W:0] cur_overflow_end;
    assign drain_total      = 7'(cur_start_word) + 7'(cur_len);
    assign cur_overflow     = (drain_total >= 7'(PCIE_MAX_BURST));
    assign cur_overflow_end = drain_total[DRAIN_CNT_W:0] - (DRAIN_CNT_W+1)'(PCIE_MAX_BURST);

    logic [FETCH_CNT_W-1:0] drain_start_beat;
    logic [FETCH_CNT_W-1:0] drain_end_beat0;
    logic [FETCH_CNT_W-1:0] drain_end_beat1;
    logic [SUB_W-1:0]       drain_last_sub0;
    logic [SUB_W-1:0]       drain_last_sub1;

    assign drain_start_beat = FETCH_CNT_W'(cur_start_word[START_WORD_W-1:SUB_W]);
    assign drain_end_beat0  = cur_overflow ? FETCH_CNT_W'(DDR_BURSTS - 1)
                                           : FETCH_CNT_W'(drain_total[START_WORD_W-1:SUB_W]);
    assign drain_last_sub0  = cur_overflow ? {SUB_W{1'b1}} : SUB_W'(drain_total[SUB_W-1:0]);
    assign drain_end_beat1  = FETCH_CNT_W'(cur_overflow_end[DRAIN_CNT_W-1:SUB_W]);
    assign drain_last_sub1  = SUB_W'(cur_overflow_end[SUB_W-1:0]);

    logic [DDR4_ADDR_WIDTH-1:0] req_addr_c;
    logic [FETCH_CNT_W-1:0]     req_start_beat_c;

    assign req_addr_c       = req_rd_data[REQ_W-1 -: DDR4_ADDR_WIDTH];
    assign req_start_beat_c = req_rd_data[START_WORD_W-1:SUB_W];

    // Two-stage pipeline breaks the comb path rp_bin→FIFO mux→38b comparator→~2048 LSRAM EN,
    // which violated setup at 150 MHz. Stage 1 registers req_addr_c; stage 2 registers the hit bit.
    logic [DDR4_ADDR_WIDTH-1:0] req_addr_r;
    logic                       req_rd_data_valid_r;
    logic                       hit_buf0_r;
    logic                       hit_buf1_r;

    always_ff @(posedge ddr_clk, negedge ddr_resetn) begin
        if (~ddr_resetn) begin
            req_addr_r          <= '0;
            req_rd_data_valid_r <= 1'b0;
            hit_buf0_r          <= 1'b0;
            hit_buf1_r          <= 1'b0;
        end else begin
            req_addr_r          <= req_addr_c;
            req_rd_data_valid_r <= ~req_rd_empty;
            hit_buf0_r          <= buf_valid[0] && (buf_addr[0] == req_addr_c);
            hit_buf1_r          <= buf_valid[1] && (buf_addr[1] == req_addr_c);
        end
    end

    logic [DDR4_ADDR_WIDTH-1:0] fetch_addr;
    logic [DDR4_ADDR_WIDTH-1:0] m_araddr_r;
    logic                       m_arvalid_r;

    assign m_araddr  = m_araddr_r;
    assign m_arvalid = m_arvalid_r;
    assign m_arlen   = 8'(DDR_BURSTS - 1);
    assign m_arsize  = 3'($clog2(DDR4_DATA_WIDTH / 8));
    assign m_arburst = 2'b01;   // INCR
    assign m_arid    = 4'b0;

    assign m_rready = (fetch_sm == F_R) || (fetch_sm == F_PREFETCH_R);

    // ----------------------------------------------------------------
    // Fetch + Drain SM
    // ----------------------------------------------------------------
    always_ff @(posedge ddr_clk, negedge ddr_resetn) begin
        if (~ddr_resetn) begin
            fetch_sm       <= F_IDLE;
            drain_sm       <= D_IDLE;
            m_arvalid_r    <= 1'b0;
            m_araddr_r     <= '0;
            fetch_beat     <= '0;
            prefetch_beat  <= '0;
            fetch_addr     <= '0;
            cur_addr       <= '0;
            cur_id         <= '0;
            cur_len        <= '0;
            cur_start_word <= '0;
            drain_word     <= '0;
            buf_valid[0]   <= 1'b0;
            buf_valid[1]   <= 1'b0;
            buf_addr[0]    <= '0;
            buf_addr[1]    <= '0;
            buf_rresp[0]   <= '0;
            buf_rresp[1]   <= '0;
            req_rd_en      <= 1'b0;
            resp_wr_en     <= 1'b0;
            resp_wr_data   <= '0;
        end else begin
            req_rd_en  <= 1'b0;
            resp_wr_en <= 1'b0;

            // ------------------------------------------------------------
            // Fetch SM
            // ------------------------------------------------------------
            case (fetch_sm)

                F_IDLE: begin
                    if (req_rd_data_valid_r) begin
                        req_rd_en      <= 1'b1;
                        cur_addr       <= req_addr_c;
                        cur_id         <= req_rd_data[REQ_W-DDR4_ADDR_WIDTH-1 -: 4];
                        cur_len        <= req_rd_data[REQ_W-DDR4_ADDR_WIDTH-5 -: 8];
                        cur_start_word <= req_rd_data[START_WORD_W-1:0];

                        if (hit_buf0_r) begin
                            // buf[0] hit - launch drain immediately
                            fetch_beat <= DDR_BURSTS;
                            drain_word <= req_start_beat_c;
                            drain_sm   <= D_RUN;
                            if (~buf_valid[1] || buf_addr[1] != req_addr_r + PREFETCH_STEP) begin
                                buf_valid[1]  <= 1'b0;
                                fetch_addr    <= req_addr_c + PREFETCH_STEP;
                                m_araddr_r    <= req_addr_c + PREFETCH_STEP;
                                m_arvalid_r   <= 1'b1;
                                prefetch_beat <= '0;
                                fetch_sm      <= F_PREFETCH_AR;
                            end else begin
                                fetch_sm <= F_WAIT;
                            end

                        end else if (hit_buf1_r) begin
                            // buf[1] hit - promote + launch drain immediately
                            buf_data[0]   <= buf_data[1];
                            buf_addr[0]   <= buf_addr[1];
                            buf_rresp[0]  <= buf_rresp[1];
                            buf_valid[0]  <= 1'b1;
                            buf_valid[1]  <= 1'b0;
                            fetch_beat    <= DDR_BURSTS;
                            drain_word    <= req_start_beat_c;
                            drain_sm      <= D_RUN;
                            fetch_addr    <= req_addr_r + PREFETCH_STEP;
                            m_araddr_r    <= req_addr_r + PREFETCH_STEP;
                            m_arvalid_r   <= 1'b1;
                            prefetch_beat <= '0;
                            fetch_sm      <= F_PREFETCH_AR;

                        end else begin
                            // Miss - flush, start DDR fetch
                            buf_valid[0] <= 1'b0;
                            buf_valid[1] <= 1'b0;
                            fetch_addr   <= req_addr_c;
                            m_araddr_r   <= req_addr_c;
                            m_arvalid_r  <= 1'b1;
                            fetch_beat   <= '0;
                            fetch_sm     <= F_AR;
                        end
                    end
                end

                F_AR: begin
                    if (m_arready) begin
                        m_arvalid_r <= 1'b0;
                        drain_word  <= drain_start_beat;
                        drain_sm    <= D_RUN;
                        fetch_sm    <= F_R;
                    end
                end

                F_R: begin
                    if (m_rvalid) begin
                        buf_data[0][fetch_beat[FETCH_CNT_W-1:0] * DDR4_DATA_WIDTH
                                    +: DDR4_DATA_WIDTH] <= m_rdata;
                        buf_rresp[0] <= m_rresp;
                        fetch_beat   <= fetch_beat + 1'b1;
                        if (m_rlast) begin
                            buf_addr[0]   <= fetch_addr;
                            buf_valid[0]  <= 1'b1;
                            fetch_addr    <= fetch_addr + PREFETCH_STEP;
                            m_araddr_r    <= fetch_addr + PREFETCH_STEP;
                            m_arvalid_r   <= 1'b1;
                            prefetch_beat <= '0;
                            fetch_sm      <= F_PREFETCH_AR;
                        end
                    end
                end

                F_PREFETCH_AR: begin
                    if (m_arready) begin
                        m_arvalid_r <= 1'b0;
                        fetch_sm    <= F_PREFETCH_R;
                    end
                end

                F_PREFETCH_R: begin
                    if (m_rvalid) begin
                        buf_data[1][prefetch_beat[FETCH_CNT_W-1:0] * DDR4_DATA_WIDTH
                                    +: DDR4_DATA_WIDTH] <= m_rdata;
                        buf_rresp[1]  <= m_rresp;
                        prefetch_beat <= prefetch_beat + 1'b1;
                        if (m_rlast) begin
                            buf_addr[1]  <= fetch_addr;
                            buf_valid[1] <= 1'b1;
                            fetch_sm     <= F_WAIT;
                        end
                    end
                end

                F_WAIT: begin
                    if (drain_sm == D_DONE) begin
                        drain_sm <= D_IDLE;
                        fetch_sm <= F_IDLE;
                    end
                end

                default: begin
                    fetch_sm <= F_IDLE;
                end
            endcase

            // ------------------------------------------------------------
            // Drain SM (concurrent with fetch SM)
            // ------------------------------------------------------------
            case (drain_sm)

                D_IDLE: ; // fetch SM drives the transition out

                D_RUN: begin
                    if (~resp_wr_full && (drain_word < fetch_beat)) begin
                        resp_wr_en   <= 1'b1;
                        resp_wr_data <= {
                            buf_data[0][drain_word[FETCH_CNT_W-1:0] * DDR4_DATA_WIDTH
                                        +: DDR4_DATA_WIDTH],
                            cur_id,
                            buf_rresp[0],
                            (drain_word == drain_start_beat) ? cur_start_word[SUB_W-1:0]
                                                             : {SUB_W{1'b0}},
                            (drain_word == drain_end_beat0)  ? drain_last_sub0
                                                             : {SUB_W{1'b1}},
                            (~cur_overflow && drain_word == drain_end_beat0)
                        };
                        if (~cur_overflow && drain_word == drain_end_beat0) begin
                            drain_sm <= D_DONE;
                        end else if (cur_overflow && drain_word == drain_end_beat0) begin
                            drain_sm <= D_WAIT1;
                        end else begin
                            drain_word <= drain_word + 1'b1;
                        end
                    end
                end

                D_WAIT1: begin
                    if (buf_valid[1] && buf_addr[1] == cur_addr + PREFETCH_STEP) begin
                        drain_word <= '0;
                        drain_sm   <= D_RUN1;
                    end
                end

                D_RUN1: begin
                    if (~resp_wr_full) begin
                        resp_wr_en   <= 1'b1;
                        resp_wr_data <= {
                            buf_data[1][drain_word[FETCH_CNT_W-1:0] * DDR4_DATA_WIDTH
                                        +: DDR4_DATA_WIDTH],
                            cur_id,
                            buf_rresp[1],
                            {SUB_W{1'b0}},
                            (drain_word == drain_end_beat1) ? drain_last_sub1
                                                            : {SUB_W{1'b1}},
                            (drain_word == drain_end_beat1)
                        };
                        if (drain_word == drain_end_beat1) begin
                            drain_sm <= D_DONE;
                        end else begin
                            drain_word <= drain_word + 1'b1;
                        end
                    end
                end

                D_DONE: ; // F_WAIT clears both SMs together

                default: begin
                    drain_sm <= D_IDLE;
                end
            endcase
        end
    end

endmodule
