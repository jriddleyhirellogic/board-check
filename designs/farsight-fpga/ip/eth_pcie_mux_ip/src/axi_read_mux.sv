/*
 * @file      axi_read_mux.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      02/19/2026
 *
 * @brief     AXI mux that routes read transactions from one of two ports based
 *            on a 1-bit select signal, while the write channels are always
 *            passed through from port 0 unconditionally. The inactive slave's
 *            read transactions are accepted and answered with DEADBEEF so the
 *            bus does not hang.
 *
 * @section changelog
 * - 02/19/2026: Steven Knyazher - Initial implementation
 *
 */

module axi_read_mux #(
    parameter DATA_WIDTH = 256, // 256 or 512
    parameter ADDR_WIDTH = 38   // 38 or 39
) (
    // Clock and reset
    input  logic                      clk,
    input  logic                      resetn,

    // Config signals
    input  logic                      eth_pcie_sel,

    // AXI bus signals
    input  logic [3:0]                s0_awid,
    input  logic [ADDR_WIDTH-1:0]     s0_awaddr,
    input  logic [7:0]                s0_awlen,
    input  logic [2:0]                s0_awsize,
    input  logic [1:0]                s0_awburst,
    input  logic                      s0_awvalid,
    output logic                      s0_awready,
    input  logic [DATA_WIDTH-1:0]     s0_wdata,
    input  logic [DATA_WIDTH/8-1:0]   s0_wstrb,
    input  logic                      s0_wlast,
    input  logic                      s0_wvalid,
    output logic                      s0_wready,
    output logic [3:0]                s0_bid,
    output logic [1:0]                s0_bresp,
    output logic                      s0_bvalid,
    input  logic                      s0_bready,
    input  logic [3:0]                s0_arid,
    input  logic [ADDR_WIDTH-1:0]     s0_araddr,
    input  logic [7:0]                s0_arlen,
    input  logic [2:0]                s0_arsize,
    input  logic [1:0]                s0_arburst,
    input  logic                      s0_arvalid,
    output logic                      s0_arready,
    output logic [3:0]                s0_rid,
    output logic [DATA_WIDTH-1:0]     s0_rdata,
    output logic [1:0]                s0_rresp,
    output logic                      s0_rlast,
    output logic                      s0_rvalid,
    input  logic                      s0_rready,
    input  logic [3:0]                s1_awid,
    input  logic [ADDR_WIDTH-1:0]     s1_awaddr,
    input  logic [7:0]                s1_awlen,
    input  logic [2:0]                s1_awsize,
    input  logic [1:0]                s1_awburst,
    input  logic                      s1_awvalid,
    output logic                      s1_awready,
    input  logic [DATA_WIDTH-1:0]     s1_wdata,
    input  logic [DATA_WIDTH/8-1:0]   s1_wstrb,
    input  logic                      s1_wlast,
    input  logic                      s1_wvalid,
    output logic                      s1_wready,
    output logic [3:0]                s1_bid,
    output logic [1:0]                s1_bresp,
    output logic                      s1_bvalid,
    input  logic                      s1_bready,
    input  logic [3:0]                s1_arid,
    input  logic [ADDR_WIDTH-1:0]     s1_araddr,
    input  logic [7:0]                s1_arlen,
    input  logic [2:0]                s1_arsize,
    input  logic [1:0]                s1_arburst,
    input  logic                      s1_arvalid,
    output logic                      s1_arready,
    output logic [3:0]                s1_rid,
    output logic [DATA_WIDTH-1:0]     s1_rdata,
    output logic [1:0]                s1_rresp,
    output logic                      s1_rlast,
    output logic                      s1_rvalid,
    input  logic                      s1_rready,
    output logic [3:0]                m_awid,
    output logic [ADDR_WIDTH-1:0]     m_awaddr,
    output logic [7:0]                m_awlen,
    output logic [2:0]                m_awsize,
    output logic [1:0]                m_awburst,
    output logic                      m_awvalid,
    input  logic                      m_awready,
    output logic [DATA_WIDTH-1:0]     m_wdata,
    output logic [DATA_WIDTH/8-1:0]   m_wstrb,
    output logic                      m_wlast,
    output logic                      m_wvalid,
    input  logic                      m_wready,
    input  logic [3:0]                m_bid,
    input  logic [1:0]                m_bresp,
    input  logic                      m_bvalid,
    output logic                      m_bready,
    output logic [3:0]                m_arid,
    output logic [ADDR_WIDTH-1:0]     m_araddr,
    output logic [7:0]                m_arlen,
    output logic [2:0]                m_arsize,
    output logic [1:0]                m_arburst,
    output logic                      m_arvalid,
    input  logic                      m_arready,
    input  logic [3:0]                m_rid,
    input  logic [DATA_WIDTH-1:0]     m_rdata,
    input  logic [1:0]                m_rresp,
    input  logic                      m_rlast,
    input  logic                      m_rvalid,
    output logic                      m_rready
);

    logic [1:0] sel_sync;
    logic       sel;

    always_ff @(posedge clk, negedge resetn) begin
        if (~resetn)
            sel_sync <= 2'b00;
        else
            sel_sync <= {sel_sync[0], eth_pcie_sel};
    end

    assign sel = sel_sync[1];

    localparam logic [DATA_WIDTH-1:0] DUMMY_DATA = {(DATA_WIDTH/32){32'hDEAD_BEEF}};

    typedef enum logic {DUMMY_IDLE, DUMMY_BURST} dummy_sm_t;

    dummy_sm_t  s0_dsm, s1_dsm;
    logic [7:0] s0_dcnt, s1_dcnt;
    logic [3:0] s0_did,  s1_did;

    always_ff @(posedge clk, negedge resetn) begin
        if (~resetn) begin
            s0_dsm  <= DUMMY_IDLE;
            s0_dcnt <= '0;
            s0_did  <= '0;
        end else begin
            case (s0_dsm)
                DUMMY_IDLE:
                    if (sel && s0_arvalid) begin
                        s0_did  <= s0_arid;
                        s0_dcnt <= s0_arlen;
                        s0_dsm  <= DUMMY_BURST;
                    end
                DUMMY_BURST:
                    if (s0_rready) begin
                        if (s0_dcnt == '0) begin
                            s0_dsm <= DUMMY_IDLE;
                        end else begin
                            s0_dcnt <= s0_dcnt - 1;
                        end
                    end
            endcase
        end
    end

    always_ff @(posedge clk, negedge resetn) begin
        if (~resetn) begin
            s1_dsm  <= DUMMY_IDLE;
            s1_dcnt <= '0;
            s1_did  <= '0;
        end else begin
            case (s1_dsm)
                DUMMY_IDLE:
                    if (~sel && s1_arvalid) begin
                        s1_did  <= s1_arid;
                        s1_dcnt <= s1_arlen;
                        s1_dsm  <= DUMMY_BURST;
                    end
                DUMMY_BURST:
                    if (s1_rready) begin
                        if (s1_dcnt == '0) begin
                            s1_dsm <= DUMMY_IDLE;
                        end else begin
                            s1_dcnt <= s1_dcnt - 1;
                        end
                    end
            endcase
        end
    end

    assign m_awid     = s0_awid;
    assign m_awaddr   = s0_awaddr;
    assign m_awlen    = s0_awlen;
    assign m_awsize   = s0_awsize;
    assign m_awburst  = s0_awburst;
    assign m_awvalid  = s0_awvalid;
    assign s0_awready = m_awready;
    assign m_wdata    = s0_wdata;
    assign m_wstrb    = s0_wstrb;
    assign m_wlast    = s0_wlast;
    assign m_wvalid   = s0_wvalid;
    assign s0_wready  = m_wready;
    assign s0_bid     = m_bid;
    assign s0_bresp   = m_bresp;
    assign s0_bvalid  = m_bvalid;
    assign m_bready   = s0_bready;
    assign s1_awready = '0;
    assign s1_wready  = '0;
    assign s1_bid     = '0;
    assign s1_bresp   = '0;
    assign s1_bvalid  = '0;
    assign m_arid     = sel ? s1_arid    : s0_arid;
    assign m_araddr   = sel ? s1_araddr  : s0_araddr;
    assign m_arlen    = sel ? s1_arlen   : s0_arlen;
    assign m_arsize   = sel ? s1_arsize  : s0_arsize;
    assign m_arburst  = sel ? s1_arburst : s0_arburst;
    assign m_arvalid  = sel ? s1_arvalid : s0_arvalid;
    assign m_rready   = sel ? s1_rready  : s0_rready;
    assign s0_arready = sel ? (s0_dsm == DUMMY_IDLE) : m_arready;
    assign s0_rid     = sel ? s0_did     : m_rid;
    assign s0_rdata   = sel ? DUMMY_DATA : m_rdata;
    assign s0_rresp   = sel ? 2'b00      : m_rresp;
    assign s0_rlast   = sel ? (s0_dcnt == '0) : m_rlast;
    assign s0_rvalid  = sel ? (s0_dsm == DUMMY_BURST) : m_rvalid;
    assign s1_arready = sel ? m_arready : (s1_dsm == DUMMY_IDLE);
    assign s1_rid     = sel ? m_rid     : s1_did;
    assign s1_rdata   = sel ? m_rdata   : DUMMY_DATA;
    assign s1_rresp   = sel ? m_rresp   : 2'b00;
    assign s1_rlast   = sel ? m_rlast   : (s1_dcnt == '0);
    assign s1_rvalid  = sel ? m_rvalid  : (s1_dsm == DUMMY_BURST);

endmodule