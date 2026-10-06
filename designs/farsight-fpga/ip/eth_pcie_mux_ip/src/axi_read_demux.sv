/*
 * @file      axi_read_demux.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      03/10/2026
 *
 * @brief     AXI demux that routes read transactions from one port to two ports
 *            based on a 1-bit select register, while write transactions to
 *            addresses 0x00 and 0x08 configure internal control registers.
 *            Write transactions are not forwarded to downstream ports.
 *
 *            Register map (DATA_WIDTH=64, byte-addressed):
 *              0x00 [0]    - ddr4_sel: 0=route to m0(8GB), 1=route to m1(16GB)
 *              0x08 [8:0]  - ddr4_index: [7:0] -> ddr4_8gb_index, [8:0] -> ddr4_16gb_index
 *
 * @section changelog
 * - 03/10/2026: Steven Knyazher - Initial implementation
 *
 */

module axi_read_demux #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 32
) (
    // Clock and reset
    input  logic                      clk,
    input  logic                      resetn,

    // Config signals
    output logic [7:0]                ddr4_8gb_index,
    output logic [8:0]                ddr4_16gb_index,

    // AXI bus signals
    input  logic [3:0]                s_awid,
    input  logic [ADDR_WIDTH-1:0]     s_awaddr,
    input  logic [7:0]                s_awlen,
    input  logic [2:0]                s_awsize,
    input  logic [1:0]                s_awburst,
    input  logic                      s_awvalid,
    output logic                      s_awready,
    input  logic [DATA_WIDTH-1:0]     s_wdata,
    input  logic [DATA_WIDTH/8-1:0]   s_wstrb,
    input  logic                      s_wlast,
    input  logic                      s_wvalid,
    output logic                      s_wready,
    output logic [3:0]                s_bid,
    output logic [1:0]                s_bresp,
    output logic                      s_bvalid,
    input  logic                      s_bready,
    input  logic [3:0]                s_arid,
    input  logic [ADDR_WIDTH-1:0]     s_araddr,
    input  logic [7:0]                s_arlen,
    input  logic [2:0]                s_arsize,
    input  logic [1:0]                s_arburst,
    input  logic                      s_arvalid,
    output logic                      s_arready,
    output logic [3:0]                s_rid,
    output logic [DATA_WIDTH-1:0]     s_rdata,
    output logic [1:0]                s_rresp,
    output logic                      s_rlast,
    output logic                      s_rvalid,
    input  logic                      s_rready,
    output logic [3:0]                m0_awid,
    output logic [ADDR_WIDTH-1:0]     m0_awaddr,
    output logic [7:0]                m0_awlen,
    output logic [2:0]                m0_awsize,
    output logic [1:0]                m0_awburst,
    output logic                      m0_awvalid,
    input  logic                      m0_awready,
    output logic [DATA_WIDTH-1:0]     m0_wdata,
    output logic [DATA_WIDTH/8-1:0]   m0_wstrb,
    output logic                      m0_wlast,
    output logic                      m0_wvalid,
    input  logic                      m0_wready,
    input  logic [3:0]                m0_bid,
    input  logic [1:0]                m0_bresp,
    input  logic                      m0_bvalid,
    output logic                      m0_bready,
    output logic [3:0]                m0_arid,
    output logic [ADDR_WIDTH-1:0]     m0_araddr,
    output logic [7:0]                m0_arlen,
    output logic [2:0]                m0_arsize,
    output logic [1:0]                m0_arburst,
    output logic                      m0_arvalid,
    input  logic                      m0_arready,
    input  logic [3:0]                m0_rid,
    input  logic [DATA_WIDTH-1:0]     m0_rdata,
    input  logic [1:0]                m0_rresp,
    input  logic                      m0_rlast,
    input  logic                      m0_rvalid,
    output logic                      m0_rready,
    output logic [3:0]                m1_awid,
    output logic [ADDR_WIDTH-1:0]     m1_awaddr,
    output logic [7:0]                m1_awlen,
    output logic [2:0]                m1_awsize,
    output logic [1:0]                m1_awburst,
    output logic                      m1_awvalid,
    input  logic                      m1_awready,
    output logic [DATA_WIDTH-1:0]     m1_wdata,
    output logic [DATA_WIDTH/8-1:0]   m1_wstrb,
    output logic                      m1_wlast,
    output logic                      m1_wvalid,
    input  logic                      m1_wready,
    input  logic [3:0]                m1_bid,
    input  logic [1:0]                m1_bresp,
    input  logic                      m1_bvalid,
    output logic                      m1_bready,
    output logic [3:0]                m1_arid,
    output logic [ADDR_WIDTH-1:0]     m1_araddr,
    output logic [7:0]                m1_arlen,
    output logic [2:0]                m1_arsize,
    output logic [1:0]                m1_arburst,
    output logic                      m1_arvalid,
    input  logic                      m1_arready,
    input  logic [3:0]                m1_rid,
    input  logic [DATA_WIDTH-1:0]     m1_rdata,
    input  logic [1:0]                m1_rresp,
    input  logic                      m1_rlast,
    input  logic                      m1_rvalid,
    output logic                      m1_rready
);

    localparam logic [ADDR_WIDTH-1:0] ADDR_SEL   = ADDR_WIDTH'('h00);
    localparam logic [ADDR_WIDTH-1:0] ADDR_INDEX = ADDR_WIDTH'('h08);

    //--------------------------------------------------------------------------
    // Write-path state machine - captures config registers, does not forward
    //--------------------------------------------------------------------------
    typedef enum logic [1:0] {
        WR_IDLE,
        WR_DATA, 
        WR_RESP
    } wr_sm_t;
    wr_sm_t wr_sm;

    logic       ddr4_sel;
    logic [8:0] ddr4_index;

    logic [3:0]            wr_id;
    logic [ADDR_WIDTH-1:0] wr_addr;

    always_ff @(posedge clk, negedge resetn) begin
        if (~resetn) begin
            wr_sm      <= WR_IDLE;
            ddr4_sel   <= 1'b0;
            ddr4_index <= '0;
            wr_id      <= '0;
            wr_addr    <= '0;
        end else begin
            case (wr_sm)
                WR_IDLE: begin
                    if (s_awvalid) begin
                        wr_id   <= s_awid;
                        wr_addr <= s_awaddr;
                        wr_sm   <= WR_DATA;
                    end
                end

                WR_DATA: begin
                    if (s_wvalid) begin
                        case (wr_addr[3:0])
                            ADDR_SEL[3:0]:   ddr4_sel   <= s_wdata[0];
                            ADDR_INDEX[3:0]: ddr4_index <= s_wdata[8:0];
                            default: ;
                        endcase
                        wr_sm <= WR_RESP;
                    end
                end

                WR_RESP: begin
                    if (s_bready) begin
                        wr_sm <= WR_IDLE;
                    end
                end

                default: begin
                    wr_sm <= WR_IDLE;
                end
            endcase
        end
    end

    assign ddr4_8gb_index    = ddr4_index[7:0];
    assign ddr4_16gb_index   = ddr4_index[8:0];

    // Write-channel slave responses
    assign s_awready  = (wr_sm == WR_IDLE);
    assign s_wready   = (wr_sm == WR_DATA);
    assign s_bid      = wr_id;
    assign s_bresp    = 2'b00;
    assign s_bvalid   = (wr_sm == WR_RESP);

    // Write channels to m0/m1 - not forwarded downstream
    assign m0_awid    = '0;
    assign m0_awaddr  = '0;
    assign m0_awlen   = '0;
    assign m0_awsize  = '0;
    assign m0_awburst = '0;
    assign m0_awvalid = '0;
    assign m0_wdata   = '0;
    assign m0_wstrb   = '0;
    assign m0_wlast   = '0;
    assign m0_wvalid  = '0;
    assign m0_bready  = '0;
    assign m1_awid    = '0;
    assign m1_awaddr  = '0;
    assign m1_awlen   = '0;
    assign m1_awsize  = '0;
    assign m1_awburst = '0;
    assign m1_awvalid = '0;
    assign m1_wdata   = '0;
    assign m1_wstrb   = '0;
    assign m1_wlast   = '0;
    assign m1_wvalid  = '0;
    assign m1_bready  = '0;

    //--------------------------------------------------------------------------
    // Read-path demux - routed by ddr4_sel
    //--------------------------------------------------------------------------
    assign m0_arid    = s_arid;
    assign m0_araddr  = s_araddr;
    assign m0_arlen   = s_arlen;
    assign m0_arsize  = s_arsize;
    assign m0_arburst = s_arburst;
    assign m0_arvalid = s_arvalid & ~ddr4_sel;
    assign m0_rready  = s_rready & ~ddr4_sel;
    assign m1_arid    = s_arid;
    assign m1_araddr  = s_araddr;
    assign m1_arlen   = s_arlen;
    assign m1_arsize  = s_arsize;
    assign m1_arburst = s_arburst;
    assign m1_arvalid = s_arvalid & ddr4_sel;
    assign m1_rready  = s_rready & ddr4_sel;
    assign s_arready  = ddr4_sel ? m1_arready : m0_arready;
    assign s_rid      = ddr4_sel ? m1_rid : m0_rid;
    assign s_rdata    = ddr4_sel ? m1_rdata : m0_rdata;
    assign s_rresp    = ddr4_sel ? m1_rresp : m0_rresp;
    assign s_rlast    = ddr4_sel ? m1_rlast : m0_rlast;
    assign s_rvalid   = ddr4_sel ? m1_rvalid : m0_rvalid;

endmodule
