/*
 * @file      pcie_translator_tb.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      03/30/2026
 *
 * @brief     Testbench for pcie_translator.
 *            Compile with: pcie_translator_fifo.sv pcie_translator.sv pcie_translator_tb.sv
 *
 * Test cases
 *   TC1  Cold miss      – read 0x00000  → DDR fetches 0x000, prefetches 0x100    (2 ARs)
 *   TC2  Prefetch hit   – read 0x00100  → buf[1] promoted, DDR prefetches 0x200  (1 AR)
 *   TC3  Prefetch hit   – read 0x00200  → buf[1] promoted, DDR prefetches 0x300  (1 AR)
 *   TC4  Miss (gap)     – read 0x01000  → flush, DDR fetches 0x1000+0x1100       (2 ARs)
 *   TC5  buf[0] hit     – read 0x01000  → served from buf[0], no DDR AR           (0 ARs)
 *   TC6  Prefetch hit   – read 0x01100  → buf[1] promoted, DDR prefetches 0x1200 (1 AR)
 *   TC7  buf[0] hit+off – read 0x01108  → aligned 0x1100 hits buf[0], word off=1 (0 ARs)
 *   TC8  Prefetch hit   – read 0x01200  → buf[1] promoted, DDR prefetches 0x1300 (1 AR)
 *   TC9  buf[1] hit+off – read 0x01330  → aligned 0x1300 hits buf[1], word off=6 (1 AR)
 *   TC10 Miss+offset    – read 0x01528  → aligned 0x1500 miss, fetch+prefetch  (2 ARs)
 *   TC11 Overflow burst – read 0x01658  → buf[1] hit 0x1600, burst crosses into
 *                         0x1700; D_RUN drains buf[0][11..31], D_RUN1 buf[1][0..10] (1 AR)
 *
 * @section changelog
 * - 03/30/2026: Steven Knyazher - Initial implementation
 */

`timescale 1ns/1ps

module pcie_translator_tb;

    // ================================================================
    // Parameters
    // ================================================================
    localparam int DDR4_DATA_WIDTH = 256;
    localparam int DDR4_ADDR_WIDTH = 38;
    localparam int PCIE_DATA_WIDTH = 64;
    localparam int PCIE_ADDR_WIDTH = 32;
    localparam int PCIE_MAX_BURST  = 32;

    localparam int DDR_BURSTS = PCIE_MAX_BURST * PCIE_DATA_WIDTH / DDR4_DATA_WIDTH; // 8
    localparam int DDR_LANES  = DDR4_DATA_WIDTH / PCIE_DATA_WIDTH;                  // 4

    localparam real PCIE_HALF = 2.0;   //  4 ns → 250 MHz
    localparam real DDR_HALF  = 3.75;   //  7.5 ns → 150 MHz

    // ================================================================
    // Clocks and resets
    // ================================================================
    logic pcie_clk = 1'b0, pcie_resetn = 1'b0;
    logic ddr_clk  = 1'b0, ddr_resetn  = 1'b0;

    always #PCIE_HALF pcie_clk = ~pcie_clk;
    always #DDR_HALF  ddr_clk  = ~ddr_clk;

    initial begin
        #20;
        pcie_resetn = 1'b1;
        ddr_resetn  = 1'b1;
    end

    // ================================================================
    // DUT interface signals
    // ================================================================

    // DDR address index (all zero → no address space offset)
    logic [7:0] index = '0;   // $clog2(256) = 8 bits

    // Slave AXI – AR channel (pcie_clk domain)
    logic [3:0]  s_arid    = '0;
    logic [31:0] s_araddr  = '0;
    logic [7:0]  s_arlen   = '0;
    logic [2:0]  s_arsize  = '0;
    logic [1:0]  s_arburst = '0;
    logic        s_arvalid = '0;
    logic        s_arready;

    // Slave AXI – R channel (pcie_clk domain)
    logic [3:0]  s_rid;
    logic [63:0] s_rdata;
    logic [1:0]  s_rresp;
    logic        s_rlast;
    logic        s_rvalid;
    logic        s_rready  = '0;

    // Slave AXI – write channel (stubbed out, tied to 0)
    logic [3:0]  s_awid    = '0;
    logic [31:0] s_awaddr  = '0;
    logic [7:0]  s_awlen   = '0;
    logic [2:0]  s_awsize  = '0;
    logic [1:0]  s_awburst = '0;
    logic        s_awvalid = '0;
    logic        s_awready;
    logic [63:0] s_wdata   = '0;
    logic [7:0]  s_wstrb   = '0;
    logic        s_wlast   = '0;
    logic        s_wvalid  = '0;
    logic        s_wready;
    logic [3:0]  s_bid;
    logic [1:0]  s_bresp;
    logic        s_bvalid;
    logic        s_bready  = '0;

    // Master AXI – AR channel (ddr_clk domain)
    logic [3:0]   m_arid;
    logic [37:0]  m_araddr;
    logic [7:0]   m_arlen;
    logic [2:0]   m_arsize;
    logic [1:0]   m_arburst;
    logic         m_arvalid;
    logic         m_arready = '0;

    // Master AXI – R channel (ddr_clk domain, driven by DDR model)
    logic [3:0]   m_rid    = '0;
    logic [255:0] m_rdata  = '0;
    logic [1:0]   m_rresp  = '0;
    logic         m_rlast  = '0;
    logic         m_rvalid = '0;
    logic         m_rready;

    // Master AXI – write channel (stubbed, not used by DUT)
    logic [3:0]   m_awid;
    logic [37:0]  m_awaddr;
    logic [7:0]   m_awlen;
    logic [2:0]   m_awsize;
    logic [1:0]   m_awburst;
    logic         m_awvalid;
    logic         m_awready = '0;
    logic [255:0] m_wdata;
    logic [31:0]  m_wstrb;
    logic         m_wlast;
    logic         m_wvalid;
    logic         m_wready  = '0;
    logic [3:0]   m_bid     = '0;
    logic [1:0]   m_bresp   = '0;
    logic         m_bvalid  = '0;
    logic         m_bready;

    // ================================================================
    // DUT
    // ================================================================
    pcie_translator #(
        .DDR4_DATA_WIDTH (DDR4_DATA_WIDTH),
        .DDR4_ADDR_WIDTH (DDR4_ADDR_WIDTH),
        .PCIE_DATA_WIDTH (PCIE_DATA_WIDTH),
        .PCIE_ADDR_WIDTH (PCIE_ADDR_WIDTH),
        .PCIE_MAX_BURST  (PCIE_MAX_BURST)
    ) dut (.*);

    // ================================================================
    // Watchdog
    // ================================================================
    initial begin
        #500_000;
        $display("[TB] TIMEOUT");
        $finish;
    end

    // ================================================================
    // Result tracking
    // ================================================================
    int pass_cnt  = 0;
    int fail_cnt  = 0;
    int ddr_ar_cnt = 0;   // incremented by DDR model each time an AR is accepted

    task automatic chk(input string msg, input logic ok);
        if (ok) begin $display("  PASS  %s", msg); pass_cnt++; end
        else    begin $display("  FAIL  %s", msg); fail_cnt++; end
    endtask

    // ================================================================
    // Expected data helper
    //   Computes the byte address of beat word_idx, finds which 256B DDR
    //   block owns it, then applies the DDR model formula: (A>>4) + word_in_block.
    //   Handles both normal (single-buffer) and overflow (cross-buffer) bursts.
    //
    //   DDR model: word W fetched from block base A → value = (A>>4) + W
    // ================================================================
    function automatic logic [63:0] exp_word(
        input logic [31:0] araddr,
        input int          word_idx
    );
        logic [DDR4_ADDR_WIDTH-1:0] full_addr;
        logic [DDR4_ADDR_WIDTH-1:0] beat_addr;    // byte address of this specific beat
        logic [DDR4_ADDR_WIDTH-1:0] aligned_addr; // 256B block that owns beat_addr
        int buf_bytes, word_bytes, within_buf;
        word_bytes   = PCIE_DATA_WIDTH / 8;                                  // 8
        buf_bytes    = PCIE_MAX_BURST * PCIE_DATA_WIDTH / 8;                 // 256
        full_addr    = {13'b0, araddr[24:0]};
        beat_addr    = full_addr + DDR4_ADDR_WIDTH'(word_idx * word_bytes);  // byte addr of beat
        aligned_addr = (beat_addr / buf_bytes) * buf_bytes;                  // 256B boundary
        within_buf   = int'(beat_addr % buf_bytes) / word_bytes;             // word index in block
        return 64'(aligned_addr >> 4) + 64'(within_buf);
    endfunction

    // ================================================================
    // Task: drive one PCIe AR transaction and wait for handshake
    // ================================================================
    task automatic ar_send(
        input logic [31:0] addr,
        input logic [3:0]  id,
        input logic [7:0]  len     // arlen = beats - 1
    );
        @(posedge pcie_clk);
        s_araddr  = addr;
        s_arid    = id;
        s_arlen   = len;
        s_arsize  = 3'd3;    // 8 bytes / beat
        s_arburst = 2'b01;   // INCR
        s_arvalid = 1'b1;
        // Wait for arready (DUT asserts combinatorially when not busy)
        do @(posedge pcie_clk); while (!s_arready);
        s_arvalid = 1'b0;
    endtask

    // ================================================================
    // Task: receive PCIe R burst and verify each beat
    // ================================================================
    task automatic r_recv(
        input logic [31:0] araddr,
        input logic [3:0]  exp_rid,
        input logic [7:0]  len        // arlen = beats - 1
    );
        int   beat    = 0;
        logic ok      = 1'b1;
        string msg;

        s_rready = 1'b1;
        while (beat <= int'(len)) begin
            @(posedge pcie_clk);
            if (s_rvalid) begin
                $display("  [beat %2d] data=0x%016h  exp=0x%016h  rid=%0d  rlast=%0b  %s",
                         beat, s_rdata, exp_word(araddr, beat), s_rid, s_rlast,
                         (s_rdata === exp_word(araddr, beat)) ? "OK" : "MISMATCH");
                // Data
                if (s_rdata !== exp_word(araddr, beat)) begin
                    ok = 1'b0;
                end
                // ID
                if (s_rid !== exp_rid) begin
                    $display("  [beat %2d] rid mismatch: got=%0d  exp=%0d", beat, s_rid, exp_rid);
                    ok = 1'b0;
                end
                // Response
                if (s_rresp !== 2'b00) begin
                    $display("  [beat %2d] rresp got=%0b (expected 00)", beat, s_rresp);
                    ok = 1'b0;
                end
                // rlast position
                if (beat <  int'(len) &&  s_rlast) begin
                    $display("  [beat %2d] spurious rlast", beat); ok = 1'b0;
                end
                if (beat == int'(len) && !s_rlast) begin
                    $display("  [beat %2d] rlast missing",  beat); ok = 1'b0;
                end
                beat++;
            end
        end
        s_rready = 1'b0;

        $sformat(msg, "addr=0x%05h  id=%0d  %0d beats", araddr, exp_rid, int'(len)+1);
        chk(msg, ok);
    endtask

    // ================================================================
    // DDR4 slave model (ddr_clk domain)
    //
    //   Accepts each AR in order with a 1-cycle arready pulse, then
    //   sends DDR_BURSTS R beats.  The DUT holds m_rready high for the
    //   entire burst once it enters F_R / F_PREFETCH_R, so beats are
    //   sent back-to-back without additional flow-control checks.
    //
    //   Data pattern: beat B, lane L at address A
    //       m_rdata[L*64 +: 64] = (A >> 4) + (B * DDR_LANES + L)
    //   This makes each 64-bit PCIe word W uniquely = (A>>4) + W,
    //   matching the exp_word() function above.
    // ================================================================
    logic [DDR4_ADDR_WIDTH-1:0] ddr_ar_addr_q;

    initial begin
        @(posedge ddr_resetn);
        @(posedge ddr_clk);

        forever begin
            // ---- Wait for AR valid ----
            while (!m_arvalid) @(posedge ddr_clk);
            ddr_ar_addr_q = m_araddr;
            ddr_ar_cnt++;
            $display("  [DDR #%0d] addr=0x%0h  arlen=%0d  t=%0t",
                     ddr_ar_cnt, m_araddr, m_arlen, $time);

            // ---- Accept: 1-cycle arready ----
            m_arready = 1'b1;
            @(posedge ddr_clk);
            m_arready = 1'b0;

            // ---- Wait for DUT to assert m_rready (F_R or F_PREFETCH_R) ----
            while (!m_rready) @(posedge ddr_clk);

            // ---- Send DDR_BURSTS beats back-to-back ----
            // m_rready stays high throughout a burst in this design.
            for (int b = 0; b < DDR_BURSTS; b++) begin
                for (int lane = 0; lane < DDR_LANES; lane++) begin
                    m_rdata[lane*PCIE_DATA_WIDTH +: PCIE_DATA_WIDTH] =
                        64'(ddr_ar_addr_q >> 4) + 64'(b * DDR_LANES + lane);
                end
                m_rresp  = 2'b00;
                m_rlast  = (b == DDR_BURSTS - 1);
                m_rvalid = 1'b1;
                @(posedge ddr_clk);   // beat latched by DUT at this edge
            end
            m_rvalid = 1'b0;
            m_rlast  = 1'b0;
        end
    end

    // ================================================================
    // Test sequence
    // ================================================================
    initial begin
        @(posedge pcie_resetn);
        repeat (3) @(posedge pcie_clk);

        // --------------------------------------------------------
        // TC1: Cold miss – addr 0x00000
        //   DUT fetches 0x000 (buf[0]), prefetches 0x100 (buf[1])
        //   Expected DDR ARs after: 2
        // --------------------------------------------------------
        $display("\n[TC1] Cold miss: addr=0x00000");
        fork
            ar_send(32'h0000_0000, 4'h0, 8'd31);
            r_recv (32'h0000_0000, 4'h0, 8'd31);
        join
        chk("TC1: 2 DDR ARs (fetch 0x000 + prefetch 0x100)", ddr_ar_cnt == 2);

        // --------------------------------------------------------
        // TC2: Prefetch hit – addr 0x00100 (was buf[1])
        //   DUT promotes buf[1]→buf[0], prefetches 0x200
        //   Expected DDR ARs after: 3
        // --------------------------------------------------------
        $display("\n[TC2] Prefetch hit: addr=0x00100");
        fork
            ar_send(32'h0000_0100, 4'h1, 8'd31);
            r_recv (32'h0000_0100, 4'h1, 8'd31);
        join
        chk("TC2: 1 new DDR AR (prefetch 0x200)", ddr_ar_cnt == 3);

        // --------------------------------------------------------
        // TC3: Prefetch hit – addr 0x00200 (was buf[1])
        //   DUT promotes buf[1]→buf[0], prefetches 0x300
        //   Expected DDR ARs after: 4
        // --------------------------------------------------------
        $display("\n[TC3] Prefetch hit: addr=0x00200");
        fork
            ar_send(32'h0000_0200, 4'h2, 8'd31);
            r_recv (32'h0000_0200, 4'h2, 8'd31);
        join
        chk("TC3: 1 new DDR AR (prefetch 0x300)", ddr_ar_cnt == 4);

        // --------------------------------------------------------
        // TC4: Miss (address gap) – addr 0x01000
        //   buf[0]=0x200, buf[1]=0x300 → neither matches → flush
        //   DUT fetches 0x1000 (buf[0]), prefetches 0x1100 (buf[1])
        //   Expected DDR ARs after: 6
        // --------------------------------------------------------
        $display("\n[TC4] Miss (gap): addr=0x01000");
        fork
            ar_send(32'h0000_1000, 4'h3, 8'd31);
            r_recv (32'h0000_1000, 4'h3, 8'd31);
        join
        chk("TC4: 2 new DDR ARs (fetch 0x1000 + prefetch 0x1100)", ddr_ar_cnt == 6);

        // --------------------------------------------------------
        // TC5: buf[0] hit + buf[1] already correct – addr 0x01000
        //   buf[0]=0x1000, buf[1]=0x1100 → buf[0] hit, no new DDR AR
        //   Expected DDR ARs after: still 6
        // --------------------------------------------------------
        $display("\n[TC5] buf[0] hit (re-read): addr=0x01000");
        fork
            ar_send(32'h0000_1000, 4'h4, 8'd31);
            r_recv (32'h0000_1000, 4'h4, 8'd31);
        join
        chk("TC5: 0 new DDR ARs (buf[0] hit, buf[1] already 0x1100)", ddr_ar_cnt == 6);

        // --------------------------------------------------------
        // TC6: Prefetch hit – addr 0x01100 (was buf[1])
        //   DUT promotes buf[1]→buf[0], prefetches 0x1200
        //   Expected DDR ARs after: 7
        // --------------------------------------------------------
        $display("\n[TC6] Prefetch hit: addr=0x01100");
        fork
            ar_send(32'h0000_1100, 4'h5, 8'd0);
            r_recv (32'h0000_1100, 4'h5, 8'd0);
        join
        chk("TC6: 1 new DDR AR (prefetch 0x1200)", ddr_ar_cnt == 7);

        // --------------------------------------------------------
        // TC7: buf[0] hit with offset – addr 0x1108
        //   aligned(0x1108) = 0x1100 → buf[0] hit; start_word = 0x08/8 = 1
        //   buf[1]=0x1200 already correct → no new DDR AR
        //   Returns 1 beat = word[1] of buf[0] (data at 0x1108)
        //   Expected DDR ARs after: still 7
        // --------------------------------------------------------
        $display("\n[TC7] buf[0] hit (offset): addr=0x01108");
        fork
            ar_send(32'h0000_1108, 4'h6, 8'd0);
            r_recv (32'h0000_1108, 4'h6, 8'd0);
        join
        chk("TC7: 0 new DDR ARs (aligned 0x1100 hits buf[0], word offset=1)", ddr_ar_cnt == 7);

        // --------------------------------------------------------
        // TC8: Prefetch hit – addr 0x1200
        //   buf[0]=0x1100, buf[1]=0x1200 → buf[1] hit → promote, prefetch 0x1300
        //   Expected DDR ARs after: 8
        // --------------------------------------------------------
        $display("\n[TC8] Prefetch hit: addr=0x01200");
        fork
            ar_send(32'h0000_1200, 4'h7, 8'd31);
            r_recv (32'h0000_1200, 4'h7, 8'd31);
        join
        chk("TC8: 1 new DDR AR (buf[1] promoted to buf[0], prefetch 0x1300)", ddr_ar_cnt == 8);

        // --------------------------------------------------------
        // TC9: buf[1] hit with offset – addr 0x01330
        //   buf[0]=0x1200, buf[1]=0x1300 → aligned(0x1330)=0x1300 → buf[1] hit
        //   start_word = 0x30/8 = 6 → drain word 6 of promoted buf[0]
        //   Promotes buf[1]→buf[0], prefetches 0x1400 (buf[1])
        //   Expected DDR ARs after: 9
        // --------------------------------------------------------
        $display("\n[TC9] buf[1] hit (offset): addr=0x01330");
        fork
            ar_send(32'h0000_1330, 4'h8, 8'd0);
            r_recv (32'h0000_1330, 4'h8, 8'd0);
        join
        chk("TC9: 1 new DDR AR (buf[1] promoted, prefetch 0x1400, word offset=6)", ddr_ar_cnt == 9);

        // --------------------------------------------------------
        // TC10: Miss with offset – addr 0x01528
        //   buf[0]=0x1300, buf[1]=0x1400 → aligned(0x1528)=0x1500 → full miss
        //   start_word = 0x28/8 = 5 → drain words 5..12 (8 beats)
        //   DUT fetches 0x1500 (buf[0]), prefetches 0x1600 (buf[1])
        //   Expected DDR ARs after: 11
        // --------------------------------------------------------
        $display("\n[TC10] Miss (offset): addr=0x01528");
        fork
            ar_send(32'h0000_1528, 4'h9, 8'd7);
            r_recv (32'h0000_1528, 4'h9, 8'd7);
        join
        chk("TC10: 2 new DDR ARs (fetch 0x1500 + prefetch 0x1600, word offset=5)", ddr_ar_cnt == 11);

        // --------------------------------------------------------
        // TC11: Overflow burst – addr 0x01658, arlen=31 (32 beats)
        //   buf[0]=0x1500, buf[1]=0x1600 → aligned(0x1658)=0x1600 → buf[1] hit
        //   start_word=11, overflow: 11+31=42 >= 32; overflow_end=42-32=10
        //   D_RUN  : buf[0] words 11..31  (21 beats, no rlast)
        //   D_WAIT1: wait for buf[1]=0x1700 to be fetched (1 new DDR AR)
        //   D_RUN1 : buf[1] words  0..10  (11 beats, rlast on last)
        //   Expected DDR ARs after: 12
        // --------------------------------------------------------
        $display("\n[TC11] Overflow burst: addr=0x01658  arlen=31");
        fork
            ar_send(32'h0000_1658, 4'ha, 8'd31);
            r_recv (32'h0000_1658, 4'ha, 8'd31);
        join
        chk("TC11: 1 new DDR AR (0x1700), cross-buffer drain buf[0][11..31]+buf[1][0..10]",
            ddr_ar_cnt == 12);

        // --------------------------------------------------------
        $display("\n==========================================");
        $display("  %0d passed,  %0d failed", pass_cnt, fail_cnt);
        $display(fail_cnt == 0 ? "  ALL TESTS PASSED" : "  FAILURES DETECTED");
        $display("==========================================\n");
        $finish;
    end

endmodule
