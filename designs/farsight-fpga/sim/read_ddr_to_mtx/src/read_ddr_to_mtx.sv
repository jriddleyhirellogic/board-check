/*
 * @file      read_ddr_to_mtx.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      07/17/2026
 * 
 * @brief     Read DDR to MTX Top-Level Module. This module reads data from DDR memory
 *            and sends it to the MTX interface.
 * 
 * @section changelog
 * - 07/17/2026: Steven Knyazher - Initial implementation
 * 
 */

module read_ddr_to_mtx #(
    parameter APB_DATA_WIDTH       = 32,
    parameter APB_ADDR_WIDTH       = 32,
    parameter MTX_DATA_WIDTH       = 32,
    parameter DDR4_BURST_LEN_WIDTH = 8,
    parameter DDR4_8GB_ADDR_WIDTH  = 38,
    parameter DDR4_8GB_DATA_WIDTH  = 256,
    parameter DDR4_16GB_ADDR_WIDTH = 39,
    parameter DDR4_16GB_DATA_WIDTH = 512
)(
    input  logic                                udp_clk,
    input  logic                                udp_rst_n,
    input  logic                                ddr_clk,
    input  logic                                ddr_rst_n,
    input  logic                                pclk,
    input  logic                                presetn,

    input  logic                                penable,
    input  logic                                psel,
    input  logic [APB_ADDR_WIDTH-1:0]           paddr,
    input  logic                                pwrite,
    input  logic [APB_DATA_WIDTH-1:0]           pwdata,
    output logic [APB_DATA_WIDTH-1:0]           prdata,
    output logic                                pready,
    output logic                                pslverr,

    output logic                                MRXACPT,
    input  logic                                MRXRDY,
    input  logic [MTX_DATA_WIDTH-1:0]           MRXDAT,
    input  logic                                MRXEOF,
    input  logic [$clog2(MTX_DATA_WIDTH/8)-1:0] MRXBYTEVALID,
    input  logic                                MRXSOF,

    input  logic                                MTXACPT,
    output logic                                MTXRDY,
    output logic [MTX_DATA_WIDTH-1:0]           MTXDAT,
    output logic                                MTXEOF,
    output logic [$clog2(MTX_DATA_WIDTH/8)-1:0] MTXBYTEVALID,
    output logic                                MTXSOF,

    output logic                                ddr4_8gb_arb_read_req,
    input  logic                                ddr4_8gb_arb_read_ack,
    output logic [DDR4_BURST_LEN_WIDTH-1:0]     ddr4_8gb_arb_read_burst_len,
    output logic [DDR4_8GB_ADDR_WIDTH-1:0]      ddr4_8gb_arb_read_start_addr,
    input  logic                                ddr4_8gb_arb_read_done,
    input  logic                                ddr4_8gb_arb_read_valid,
    input  logic [DDR4_8GB_DATA_WIDTH-1:0]      ddr4_8gb_arb_read_data,

    output logic                                ddr4_16gb_arb_read_req,
    input  logic                                ddr4_16gb_arb_read_ack,
    output logic [DDR4_BURST_LEN_WIDTH-1:0]     ddr4_16gb_arb_read_burst_len,
    output logic [DDR4_16GB_ADDR_WIDTH-1:0]     ddr4_16gb_arb_read_start_addr,
    input  logic                                ddr4_16gb_arb_read_done,
    input  logic                                ddr4_16gb_arb_read_valid,
    input  logic [DDR4_16GB_DATA_WIDTH-1:0]     ddr4_16gb_arb_read_data
);

//------------------------------------------------------------------------------
// Internal signals
//------------------------------------------------------------------------------
logic                                ddr4_8gb_axis_dma_fifo_tready;
logic                                ddr4_8gb_axis_dma_fifo_tvalid;
logic [MTX_DATA_WIDTH-1:0]           ddr4_8gb_axis_dma_fifo_tdata;

logic                                dma_read_ddr4_8gb_penable;
logic                                dma_read_ddr4_8gb_psel;
logic [APB_ADDR_WIDTH-1:0]           dma_read_ddr4_8gb_paddr;
logic                                dma_read_ddr4_8gb_pwrite;
logic [APB_DATA_WIDTH-1:0]           dma_read_ddr4_8gb_pwdata;
logic [APB_DATA_WIDTH-1:0]           dma_read_ddr4_8gb_prdata;
logic                                dma_read_ddr4_8gb_pready;
logic                                dma_read_ddr4_8gb_pslverr;

logic                                dma_read_ddr4_8gb_clear;
logic                                dma_read_ddr4_8gb_dma_timeout_err;

logic                                ddr4_8gb_dma_fifo_clear;
logic                                ddr4_8gb_dma_read_ack;
logic                                ddr4_8gb_dma_read_req;
logic                                ddr4_8gb_dma_ready;
logic [DDR4_BURST_LEN_WIDTH:0]       ddr4_8gb_ctrl_burst_count;
logic                                ddr4_8gb_ctrl_info_valid;
logic [DDR4_8GB_ADDR_WIDTH-1:0]      ddr4_8gb_ctrl_read_addr;

logic                                ddr4_16gb_axis_dma_fifo_tready;
logic                                ddr4_16gb_axis_dma_fifo_tvalid;
logic [MTX_DATA_WIDTH-1:0]           ddr4_16gb_axis_dma_fifo_tdata;

logic                                dma_read_ddr4_16gb_penable;
logic                                dma_read_ddr4_16gb_psel;
logic [APB_ADDR_WIDTH-1:0]           dma_read_ddr4_16gb_paddr;
logic                                dma_read_ddr4_16gb_pwrite;
logic [APB_DATA_WIDTH-1:0]           dma_read_ddr4_16gb_pwdata;
logic [APB_DATA_WIDTH-1:0]           dma_read_ddr4_16gb_prdata;
logic                                dma_read_ddr4_16gb_pready;
logic                                dma_read_ddr4_16gb_pslverr;

logic                                dma_read_ddr4_16gb_clear;
logic                                dma_read_ddr4_16gb_dma_timeout_err;

logic                                ddr4_16gb_dma_fifo_clear;
logic                                ddr4_16gb_dma_read_ack;
logic                                ddr4_16gb_dma_read_req;
logic                                ddr4_16gb_dma_ready;
logic [DDR4_BURST_LEN_WIDTH:0]       ddr4_16gb_ctrl_burst_count;
logic                                ddr4_16gb_ctrl_info_valid;
logic [DDR4_16GB_ADDR_WIDTH-1:0]     ddr4_16gb_ctrl_read_addr;

logic                                ddr4_8gb_axis_udp_pyl_tvalid;
logic                                ddr4_8gb_axis_udp_pyl_tready;
logic [MTX_DATA_WIDTH-1:0]           ddr4_8gb_axis_udp_pyl_tdata;
logic [(MTX_DATA_WIDTH/8)-1:0]       ddr4_8gb_axis_udp_pyl_tkeep;
logic                                ddr4_8gb_axis_udp_pyl_tlast;
logic                                ddr4_8gb_axis_udp_pyl_size_tvalid;
logic                                ddr4_8gb_axis_udp_pyl_size_tready;
logic [15:0]                         ddr4_8gb_axis_udp_pyl_size_tdata;

logic                                dma_read_ctrl_ddr4_8gb_penable;
logic                                dma_read_ctrl_ddr4_8gb_psel;
logic [APB_ADDR_WIDTH-1:0]           dma_read_ctrl_ddr4_8gb_paddr;
logic                                dma_read_ctrl_ddr4_8gb_pwrite;
logic [APB_DATA_WIDTH-1:0]           dma_read_ctrl_ddr4_8gb_pwdata;
logic [APB_DATA_WIDTH-1:0]           dma_read_ctrl_ddr4_8gb_prdata;
logic                                dma_read_ctrl_ddr4_8gb_pready;
logic                                dma_read_ctrl_ddr4_8gb_pslverr;

logic                                dma_read_ctrl_ddr4_8gb_clear;
logic                                dma_read_ctrl_ddr4_8gb_frame_read_req;
logic                                dma_read_ctrl_ddr4_8gb_frame_read_done;
logic                                dma_read_ctrl_ddr4_8gb_frame_read_int;
logic                                dma_read_ctrl_ddr4_8gb_udp_metadata_sel;
logic [8:0]                          dma_read_ctrl_ddr4_8gb_h_size_beat;
logic [13:0]                         dma_read_ctrl_ddr4_8gb_h_size_byte;
logic [12:0]                         dma_read_ctrl_ddr4_8gb_v_size_line;
logic [7:0]                          dma_read_ctrl_ddr4_8gb_frame_index;
logic                                dma_read_ctrl_ddr4_8gb_jumbo_en;
logic [639:0]                        dma_read_ctrl_ddr4_8gb_metadata_data;
logic                                dma_read_ctrl_ddr4_8gb_metadata_valid;
logic                                dma_read_ctrl_ddr4_8gb_sof_req;
logic                                dma_read_ctrl_ddr4_8gb_eof_ack;
logic                                dma_read_ctrl_ddr4_8gb_pyl_acpt;
logic                                dma_read_ctrl_ddr4_8gb_core_busy;

logic                                ddr4_16gb_axis_udp_pyl_tvalid;
logic                                ddr4_16gb_axis_udp_pyl_tready;
logic [MTX_DATA_WIDTH-1:0]           ddr4_16gb_axis_udp_pyl_tdata;
logic [(MTX_DATA_WIDTH/8)-1:0]       ddr4_16gb_axis_udp_pyl_tkeep;
logic                                ddr4_16gb_axis_udp_pyl_tlast;
logic                                ddr4_16gb_axis_udp_pyl_size_tvalid;
logic                                ddr4_16gb_axis_udp_pyl_size_tready;
logic [15:0]                         ddr4_16gb_axis_udp_pyl_size_tdata;

logic                                dma_read_ctrl_ddr4_16gb_penable;
logic                                dma_read_ctrl_ddr4_16gb_psel;
logic [APB_ADDR_WIDTH-1:0]           dma_read_ctrl_ddr4_16gb_paddr;
logic                                dma_read_ctrl_ddr4_16gb_pwrite;
logic [APB_DATA_WIDTH-1:0]           dma_read_ctrl_ddr4_16gb_pwdata;
logic [APB_DATA_WIDTH-1:0]           dma_read_ctrl_ddr4_16gb_prdata;
logic                                dma_read_ctrl_ddr4_16gb_pready;
logic                                dma_read_ctrl_ddr4_16gb_pslverr;

logic                                dma_read_ctrl_ddr4_16gb_clear;
logic                                dma_read_ctrl_ddr4_16gb_frame_read_req;
logic                                dma_read_ctrl_ddr4_16gb_frame_read_done;
logic                                dma_read_ctrl_ddr4_16gb_frame_read_int;
logic                                dma_read_ctrl_ddr4_16gb_udp_metadata_sel;
logic [8:0]                          dma_read_ctrl_ddr4_16gb_h_size_beat;
logic [13:0]                         dma_read_ctrl_ddr4_16gb_h_size_byte;
logic [12:0]                         dma_read_ctrl_ddr4_16gb_v_size_line;
logic [8:0]                          dma_read_ctrl_ddr4_16gb_frame_index;
logic                                dma_read_ctrl_ddr4_16gb_jumbo_en;
logic [639:0]                        dma_read_ctrl_ddr4_16gb_metadata_data;
logic                                dma_read_ctrl_ddr4_16gb_metadata_valid;
logic                                dma_read_ctrl_ddr4_16gb_sof_req;
logic                                dma_read_ctrl_ddr4_16gb_eof_ack;
logic                                dma_read_ctrl_ddr4_16gb_pyl_acpt;
logic                                dma_read_ctrl_ddr4_16gb_core_busy;

logic                                udp_tx_axis_udp_pyl_tready;
logic                                udp_tx_axis_udp_pyl_tvalid;
logic [MTX_DATA_WIDTH-1:0]           udp_tx_axis_udp_pyl_tdata;
logic [(MTX_DATA_WIDTH/8)-1:0]       udp_tx_axis_udp_pyl_tkeep;
logic                                udp_tx_axis_udp_pyl_tlast;
logic                                udp_tx_axis_udp_pyl_size_tvalid;
logic                                udp_tx_axis_udp_pyl_size_tready;
logic [15:0]                         udp_tx_axis_udp_pyl_size_tdata;

logic                                udp_tx_sof_req;
logic                                udp_tx_eof_ack;
logic                                udp_tx_pyl_acpt;
logic                                udp_tx_core_busy;
logic [1:0]                          udp_tx_mux_sel;
logic                                udp_tx_clear;
logic [31:0]                         udp_tx_wd_timeout_err_count;
logic [31:0]                         udp_tx_frame_gap;
logic [15:0]                         udp_dst_port;
logic [15:0]                         udp_src_port;
logic                                udp_hdr_valid;
logic                                udp_hdr_ready;
logic [31:0]                         dst_ip_addr;
logic [31:0]                         src_ip_addr;
logic                                iph_hdr_valid;
logic                                iph_hdr_ready;
logic [47:0]                         dst_mac_addr;
logic [47:0]                         src_mac_addr;
logic                                eth_hdr_valid;
logic                                eth_hdr_ready;
         
logic                                udp_tx_mtxacpt;
logic                                udp_tx_mtxrdy;
logic [MTX_DATA_WIDTH-1:0]           udp_tx_mtxdat;
logic                                udp_tx_mtxeof;
logic [$clog2(MTX_DATA_WIDTH/8)-1:0] udp_tx_mtxbytevalid;
logic                                udp_tx_mtxsof;

logic                                udp_tx_penable;
logic                                udp_tx_psel;
logic [APB_ADDR_WIDTH-1:0]           udp_tx_paddr;
logic                                udp_tx_pwrite;
logic [APB_DATA_WIDTH-1:0]           udp_tx_pwdata;
logic [APB_DATA_WIDTH-1:0]           udp_tx_prdata;
logic                                udp_tx_pready;
logic                                udp_tx_pslverr;
         
logic                                rsp_core_busy;

logic                                rsp_mtxacpt;
logic                                rsp_mtxrdy;
logic [MTX_DATA_WIDTH-1:0]           rsp_mtxdat;
logic                                rsp_mtxeof;
logic [$clog2(MTX_DATA_WIDTH/8)-1:0] rsp_mtxbytevalid;
logic                                rsp_mtxsof;

//------------------------------------------------------------------------------
// APB address decoder
//------------------------------------------------------------------------------
localparam logic [APB_ADDR_WIDTH-1:0] DMA_READ_DDR4_8GB_BASE_ADDR       = 32'h70013000;
localparam logic [APB_ADDR_WIDTH-1:0] DMA_READ_DDR4_16GB_BASE_ADDR      = 32'h70014000;
localparam logic [APB_ADDR_WIDTH-1:0] DMA_READ_CTRL_DDR4_8GB_BASE_ADDR  = 32'h70006000;
localparam logic [APB_ADDR_WIDTH-1:0] DMA_READ_CTRL_DDR4_16GB_BASE_ADDR = 32'h70007000;
localparam logic [APB_ADDR_WIDTH-1:0] UDP_TX_BASE_ADDR                  = 32'h7000E000;

logic sel_dma_read_ddr4_8gb;
logic sel_dma_read_ddr4_16gb;
logic sel_dma_read_ctrl_ddr4_8gb;
logic sel_dma_read_ctrl_ddr4_16gb;
logic sel_udp_tx;

assign sel_dma_read_ddr4_8gb       = psel && (paddr[APB_ADDR_WIDTH-1:12] == DMA_READ_DDR4_8GB_BASE_ADDR[APB_ADDR_WIDTH-1:12]);
assign sel_dma_read_ddr4_16gb      = psel && (paddr[APB_ADDR_WIDTH-1:12] == DMA_READ_DDR4_16GB_BASE_ADDR[APB_ADDR_WIDTH-1:12]);
assign sel_dma_read_ctrl_ddr4_8gb  = psel && (paddr[APB_ADDR_WIDTH-1:12] == DMA_READ_CTRL_DDR4_8GB_BASE_ADDR[APB_ADDR_WIDTH-1:12]);
assign sel_dma_read_ctrl_ddr4_16gb = psel && (paddr[APB_ADDR_WIDTH-1:12] == DMA_READ_CTRL_DDR4_16GB_BASE_ADDR[APB_ADDR_WIDTH-1:12]);
assign sel_udp_tx                  = psel && (paddr[APB_ADDR_WIDTH-1:12] == UDP_TX_BASE_ADDR[APB_ADDR_WIDTH-1:12]);

// DMA read DDR4 8GB
assign dma_read_ddr4_8gb_psel    = sel_dma_read_ddr4_8gb;
assign dma_read_ddr4_8gb_penable = penable;
assign dma_read_ddr4_8gb_paddr   = paddr;
assign dma_read_ddr4_8gb_pwrite  = pwrite;
assign dma_read_ddr4_8gb_pwdata  = pwdata;

// DMA read DDR4 16GB
assign dma_read_ddr4_16gb_psel    = sel_dma_read_ddr4_16gb;
assign dma_read_ddr4_16gb_penable = penable;
assign dma_read_ddr4_16gb_paddr   = paddr;
assign dma_read_ddr4_16gb_pwrite  = pwrite;
assign dma_read_ddr4_16gb_pwdata  = pwdata;

// DMA read ctrl DDR4 8GB
assign dma_read_ctrl_ddr4_8gb_psel    = sel_dma_read_ctrl_ddr4_8gb;
assign dma_read_ctrl_ddr4_8gb_penable = penable;
assign dma_read_ctrl_ddr4_8gb_paddr   = paddr;
assign dma_read_ctrl_ddr4_8gb_pwrite  = pwrite;
assign dma_read_ctrl_ddr4_8gb_pwdata  = pwdata;

// DMA read ctrl DDR4 16GB
assign dma_read_ctrl_ddr4_16gb_psel    = sel_dma_read_ctrl_ddr4_16gb;
assign dma_read_ctrl_ddr4_16gb_penable = penable;
assign dma_read_ctrl_ddr4_16gb_paddr   = paddr;
assign dma_read_ctrl_ddr4_16gb_pwrite  = pwrite;
assign dma_read_ctrl_ddr4_16gb_pwdata  = pwdata;

// UDP tx
assign udp_tx_psel    = sel_udp_tx;
assign udp_tx_penable = penable;
assign udp_tx_paddr   = paddr;
assign udp_tx_pwrite  = pwrite;
assign udp_tx_pwdata  = pwdata;

// Read-back / response mux
always_comb begin
    unique case (1'b1)
        sel_dma_read_ddr4_8gb: begin
            prdata  = dma_read_ddr4_8gb_prdata;
            pready  = dma_read_ddr4_8gb_pready;
            pslverr = dma_read_ddr4_8gb_pslverr;
        end
        
        sel_dma_read_ddr4_16gb: begin
            prdata  = dma_read_ddr4_16gb_prdata;
            pready  = dma_read_ddr4_16gb_pready;
            pslverr = dma_read_ddr4_16gb_pslverr;
        end

        sel_dma_read_ctrl_ddr4_8gb: begin
            prdata  = dma_read_ctrl_ddr4_8gb_prdata;
            pready  = dma_read_ctrl_ddr4_8gb_pready;
            pslverr = dma_read_ctrl_ddr4_8gb_pslverr;
        end
        
        sel_dma_read_ctrl_ddr4_16gb: begin
            prdata  = dma_read_ctrl_ddr4_16gb_prdata;
            pready  = dma_read_ctrl_ddr4_16gb_pready;
            pslverr = dma_read_ctrl_ddr4_16gb_pslverr;
        end
        
        sel_udp_tx: begin
            prdata  = udp_tx_prdata;
            pready  = udp_tx_pready;
            pslverr = udp_tx_pslverr;
        end

        default: begin
            prdata  = '0;
            pready  = 1'b1;
            pslverr = 1'b0;
        end
    endcase
end

//------------------------------------------------------------------------------
// DMA read DDR4 8GB instance
//------------------------------------------------------------------------------
dma_read_ddr4_8gb #(
    .DDR4_CLOCK_FREQ_MHZ (150  ),
    .TIMEOUT_USEC        (10000),
    .DDR_ADDR_WIDTH      (38   ),
    .DDR_DATA_WIDTH      (256  ),
    .DATA_OUT_WIDTH      (32   )
) dma_read_ddr4_8gb_inst (
    .ddr_clk             (ddr_clk                          ),
    .ddr_rst_n           (ddr_rst_n                        ),
    .ctrl_clk            (udp_clk                          ),
    .ctrl_rst_n          (udp_rst_n                        ),
    .ctrl_info_valid     (ddr4_8gb_ctrl_info_valid         ),
    .ctrl_burst_count    (ddr4_8gb_ctrl_burst_count        ),
    .ctrl_read_addr      (ddr4_8gb_ctrl_read_addr          ),
    .dma_ready           (ddr4_8gb_dma_ready               ),
    .dma_read_req        (ddr4_8gb_dma_read_req            ),
    .dma_read_ack        (ddr4_8gb_dma_read_ack            ),
    .dma_fifo_clear      (ddr4_8gb_dma_fifo_clear          ),
    .m_axis_dma_tready   (ddr4_8gb_axis_dma_fifo_tready    ),
    .m_axis_dma_tvalid   (ddr4_8gb_axis_dma_fifo_tvalid    ),
    .m_axis_dma_tdata    (ddr4_8gb_axis_dma_fifo_tdata     ),
    .arb_read_req        (ddr4_8gb_arb_read_req            ),
    .arb_read_ack        (ddr4_8gb_arb_read_ack            ),
    .arb_read_burst_len  (ddr4_8gb_arb_read_burst_len      ),
    .arb_read_start_addr (ddr4_8gb_arb_read_start_addr     ),
    .arb_read_done       (ddr4_8gb_arb_read_done           ),
    .arb_read_valid      (ddr4_8gb_arb_read_valid          ),
    .arb_data_in         (ddr4_8gb_arb_read_data           ),
    .clear               (dma_read_ddr4_8gb_clear          ),
    .timeout_err         (dma_read_ddr4_8gb_dma_timeout_err)
);

//------------------------------------------------------------------------------
// DMA read APB reg DDR4 8GB instance
//------------------------------------------------------------------------------
dma_read_apb_reg_ddr4_8gb #(
    .APB_DATA_WIDTH (32),
    .APB_ADDR_WIDTH (32)
) dma_read_apb_reg_ddr4_8gb_inst (
    .pclk            (pclk                             ),
    .presetn         (presetn                          ),
    .penable         (dma_read_ddr4_8gb_penable        ),
    .psel            (dma_read_ddr4_8gb_psel           ),
    .paddr           (dma_read_ddr4_8gb_paddr          ),
    .pwrite          (dma_read_ddr4_8gb_pwrite         ),
    .pwdata          (dma_read_ddr4_8gb_pwdata         ),
    .prdata          (dma_read_ddr4_8gb_prdata         ),
    .pready          (dma_read_ddr4_8gb_pready         ),
    .pslverr         (dma_read_ddr4_8gb_pslverr        ),
    .clear           (dma_read_ddr4_8gb_clear          ),
    .dma_timeout_err (dma_read_ddr4_8gb_dma_timeout_err)
);

//------------------------------------------------------------------------------
// DMA read DDR4 16GB instance
//------------------------------------------------------------------------------
dma_read_ddr4_16gb #(
    .DDR4_CLOCK_FREQ_MHZ (150  ),
    .TIMEOUT_USEC        (10000),
    .DDR_ADDR_WIDTH      (39   ),
    .DDR_DATA_WIDTH      (512  ),
    .DATA_OUT_WIDTH      (32   )
) dma_read_ddr4_16gb_inst (
    .ddr_clk             (ddr_clk                           ),
    .ddr_rst_n           (ddr_rst_n                         ),
    .ctrl_clk            (udp_clk                           ),
    .ctrl_rst_n          (udp_rst_n                         ),
    .ctrl_info_valid     (ddr4_16gb_ctrl_info_valid         ),
    .ctrl_burst_count    (ddr4_16gb_ctrl_burst_count        ),
    .ctrl_read_addr      (ddr4_16gb_ctrl_read_addr          ),
    .dma_ready           (ddr4_16gb_dma_ready               ),
    .dma_read_req        (ddr4_16gb_dma_read_req            ),
    .dma_read_ack        (ddr4_16gb_dma_read_ack            ),
    .dma_fifo_clear      (ddr4_16gb_dma_fifo_clear          ),
    .m_axis_dma_tready   (ddr4_16gb_axis_dma_fifo_tready    ),
    .m_axis_dma_tvalid   (ddr4_16gb_axis_dma_fifo_tvalid    ),
    .m_axis_dma_tdata    (ddr4_16gb_axis_dma_fifo_tdata     ),
    .arb_read_req        (ddr4_16gb_arb_read_req            ),
    .arb_read_ack        (ddr4_16gb_arb_read_ack            ),
    .arb_read_burst_len  (ddr4_16gb_arb_read_burst_len      ),
    .arb_read_start_addr (ddr4_16gb_arb_read_start_addr     ),
    .arb_read_done       (ddr4_16gb_arb_read_done           ),
    .arb_read_valid      (ddr4_16gb_arb_read_valid          ),
    .arb_data_in         (ddr4_16gb_arb_read_data           ),
    .clear               (dma_read_ddr4_16gb_clear          ),
    .timeout_err         (dma_read_ddr4_16gb_dma_timeout_err)
);

//------------------------------------------------------------------------------
// DMA read APB reg DDR4 16GB instance
//------------------------------------------------------------------------------
dma_read_apb_reg_ddr4_16gb #(
    .APB_DATA_WIDTH (32),
    .APB_ADDR_WIDTH (32)
) dma_read_apb_reg_ddr4_16gb_inst (
    .pclk            (pclk                              ),
    .presetn         (presetn                           ),
    .penable         (dma_read_ddr4_16gb_penable        ),
    .psel            (dma_read_ddr4_16gb_psel           ),
    .paddr           (dma_read_ddr4_16gb_paddr          ),
    .pwrite          (dma_read_ddr4_16gb_pwrite         ),
    .pwdata          (dma_read_ddr4_16gb_pwdata         ),
    .prdata          (dma_read_ddr4_16gb_prdata         ),
    .pready          (dma_read_ddr4_16gb_pready         ),
    .pslverr         (dma_read_ddr4_16gb_pslverr        ),
    .clear           (dma_read_ddr4_16gb_clear          ),
    .dma_timeout_err (dma_read_ddr4_16gb_dma_timeout_err)
);

//------------------------------------------------------------------------------
// DMA read ctrl DDR4 8GB instance
//------------------------------------------------------------------------------
dma_read_ctrl_ddr4_8gb #(
    .CLOCK_FREQ_MHZ    (100  ),
    .TIMEOUT_USEC      (10000),
    .DDR_ADDR_WIDTH    (38   ),
    .DDR_DATA_WIDTH    (256  ),
    .USABLE_ADDR_WIDTH (33   ),
    .FRAME_WIDTH       (25   ),
    .FRAME_INDEX_WIDTH (8    ),
    .METADATA_WIDTH    (640  )
) dma_read_ctrl_ddr4_8gb_inst (
    .udp_clk                    (udp_clk                                ),
    .udp_rst_n                  (udp_rst_n                              ),
    .clear                      (dma_read_ctrl_ddr4_8gb_clear           ),
    .frame_read_req             (dma_read_ctrl_ddr4_8gb_frame_read_req  ),
    .frame_read_done            (dma_read_ctrl_ddr4_8gb_frame_read_done ),
    .udp_metadata_sel           (dma_read_ctrl_ddr4_8gb_udp_metadata_sel),
    .h_size_beat                (dma_read_ctrl_ddr4_8gb_h_size_beat     ),
    .h_size_byte                (dma_read_ctrl_ddr4_8gb_h_size_byte     ),
    .v_size_line                (dma_read_ctrl_ddr4_8gb_v_size_line     ),
    .frame_index                (dma_read_ctrl_ddr4_8gb_frame_index     ),
    .jumbo_en                   (dma_read_ctrl_ddr4_8gb_jumbo_en        ),
    .frame_xfer_timeout_err     (/*NC*/                                 ),
    .dma_ready                  (ddr4_8gb_dma_ready                     ),
    .ctrl_info_valid            (ddr4_8gb_ctrl_info_valid               ),
    .ctrl_read_addr             (ddr4_8gb_ctrl_read_addr                ),
    .ctrl_burst_count           (ddr4_8gb_ctrl_burst_count              ),
    .dma_fifo_clear             (ddr4_8gb_dma_fifo_clear                ),
    .dma_read_req               (ddr4_8gb_dma_read_req                  ),
    .dma_read_ack               (ddr4_8gb_dma_read_ack                  ),
    .s_axis_dma_tready          (ddr4_8gb_axis_dma_fifo_tready          ),
    .s_axis_dma_tvalid          (ddr4_8gb_axis_dma_fifo_tvalid          ),
    .s_axis_dma_tdata           (ddr4_8gb_axis_dma_fifo_tdata           ),
    .m_axis_udp_pyl_tvalid      (ddr4_8gb_axis_udp_pyl_tvalid           ),
    .m_axis_udp_pyl_tready      (ddr4_8gb_axis_udp_pyl_tready           ),
    .m_axis_udp_pyl_tdata       (ddr4_8gb_axis_udp_pyl_tdata            ),
    .m_axis_udp_pyl_tkeep       (ddr4_8gb_axis_udp_pyl_tkeep            ),
    .m_axis_udp_pyl_tlast       (ddr4_8gb_axis_udp_pyl_tlast            ),
    .m_axis_udp_pyl_size_tvalid (ddr4_8gb_axis_udp_pyl_size_tvalid      ),
    .m_axis_udp_pyl_size_tready (ddr4_8gb_axis_udp_pyl_size_tready      ),
    .m_axis_udp_pyl_size_tdata  (ddr4_8gb_axis_udp_pyl_size_tdata       ),
    .sof_req                    (dma_read_ctrl_ddr4_8gb_sof_req         ),
    .eof_ack                    (dma_read_ctrl_ddr4_8gb_eof_ack         ),
    .pyl_acpt                   (dma_read_ctrl_ddr4_8gb_pyl_acpt        ),
    .core_busy                  (dma_read_ctrl_ddr4_8gb_core_busy       ),
    .sof_req_err                (/*NC*/                                 ),
    .pyl_acpt_err               (/*NC*/                                 ),
    .send_pyl_err               (/*NC*/                                 ),
    .send_last_err              (/*NC*/                                 ),
    .wait_ack_err               (/*NC*/                                 ),
    .dma_timeout_err            (/*NC*/                                 ),
    .metadata_data              (dma_read_ctrl_ddr4_8gb_metadata_data   ),
    .metadata_valid             (dma_read_ctrl_ddr4_8gb_metadata_valid  )
);

//------------------------------------------------------------------------------
// DMA read ctrl APB reg DDR4 8GB instance
//------------------------------------------------------------------------------
dma_read_ctrl_apb_reg_ddr4_8gb #(
    .APB_DATA_WIDTH    (32 ),
    .APB_ADDR_WIDTH    (32 ),
    .FRAME_INDEX_WIDTH (8  ),
    .METADATA_WIDTH    (640)
) dma_read_ctrl_apb_reg_ddr4_8gb_inst (
    .pclk                   (pclk                                   ),
    .presetn                (presetn                                ),
    .penable                (dma_read_ctrl_ddr4_8gb_penable         ),
    .psel                   (dma_read_ctrl_ddr4_8gb_psel            ),
    .paddr                  (dma_read_ctrl_ddr4_8gb_paddr           ),
    .pwrite                 (dma_read_ctrl_ddr4_8gb_pwrite          ),
    .pwdata                 (dma_read_ctrl_ddr4_8gb_pwdata          ),
    .prdata                 (dma_read_ctrl_ddr4_8gb_prdata          ),
    .pready                 (dma_read_ctrl_ddr4_8gb_pready          ),
    .pslverr                (dma_read_ctrl_ddr4_8gb_pslverr         ),
    .clear                  (dma_read_ctrl_ddr4_8gb_clear           ),
    .frame_index            (dma_read_ctrl_ddr4_8gb_frame_index     ),
    .frame_read_done        (dma_read_ctrl_ddr4_8gb_frame_read_done ),
    .frame_read_done_int    (dma_read_ctrl_ddr4_8gb_frame_read_int  ),
    .frame_read_req         (dma_read_ctrl_ddr4_8gb_frame_read_req  ),
    .udp_metadata_sel       (dma_read_ctrl_ddr4_8gb_udp_metadata_sel),
    .h_size_beat            (dma_read_ctrl_ddr4_8gb_h_size_beat     ),
    .h_size_byte            (dma_read_ctrl_ddr4_8gb_h_size_byte     ),
    .jumbo_en               (dma_read_ctrl_ddr4_8gb_jumbo_en        ),
    .v_size_line            (dma_read_ctrl_ddr4_8gb_v_size_line     ),
    .frame_xfer_timeout_err (/*NC*/                                 ),
    .dma_timeout_err        (/*NC*/                                 ),
    .pyl_acpt_err           (/*NC*/                                 ),
    .send_last_err          (/*NC*/                                 ),
    .send_pyl_err           (/*NC*/                                 ),
    .sof_req_err            (/*NC*/                                 ),
    .wait_ack_err           (/*NC*/                                 ),
    .metadata_data          (dma_read_ctrl_ddr4_8gb_metadata_data   ),
    .metadata_valid         (dma_read_ctrl_ddr4_8gb_metadata_valid  )
);

//------------------------------------------------------------------------------
// DMA read ctrl DDR4 16GB instance
//------------------------------------------------------------------------------
dma_read_ctrl_ddr4_16gb #(
    .CLOCK_FREQ_MHZ    (100  ),
    .TIMEOUT_USEC      (10000),
    .DDR_ADDR_WIDTH    (39   ),
    .DDR_DATA_WIDTH    (512  ),
    .USABLE_ADDR_WIDTH (34   ),
    .FRAME_WIDTH       (25   ),
    .FRAME_INDEX_WIDTH (9    ),
    .METADATA_WIDTH    (640  )
) dma_read_ctrl_ddr4_16gb_inst (
    .udp_clk                    (udp_clk                                 ),
    .udp_rst_n                  (udp_rst_n                               ),
    .clear                      (dma_read_ctrl_ddr4_16gb_clear           ),
    .frame_read_req             (dma_read_ctrl_ddr4_16gb_frame_read_req  ),
    .frame_read_done            (dma_read_ctrl_ddr4_16gb_frame_read_done ),
    .udp_metadata_sel           (dma_read_ctrl_ddr4_16gb_udp_metadata_sel),
    .h_size_beat                (dma_read_ctrl_ddr4_16gb_h_size_beat     ),
    .h_size_byte                (dma_read_ctrl_ddr4_16gb_h_size_byte     ),
    .v_size_line                (dma_read_ctrl_ddr4_16gb_v_size_line     ),
    .frame_index                (dma_read_ctrl_ddr4_16gb_frame_index     ),
    .jumbo_en                   (dma_read_ctrl_ddr4_16gb_jumbo_en        ),
    .frame_xfer_timeout_err     (/*NC*/                                  ),
    .dma_ready                  (ddr4_16gb_dma_ready                     ),
    .ctrl_info_valid            (ddr4_16gb_ctrl_info_valid               ),
    .ctrl_read_addr             (ddr4_16gb_ctrl_read_addr                ),
    .ctrl_burst_count           (ddr4_16gb_ctrl_burst_count              ),
    .dma_fifo_clear             (ddr4_16gb_dma_fifo_clear                ),
    .dma_read_req               (ddr4_16gb_dma_read_req                  ),
    .dma_read_ack               (ddr4_16gb_dma_read_ack                  ),
    .s_axis_dma_tready          (ddr4_16gb_axis_dma_fifo_tready          ),
    .s_axis_dma_tvalid          (ddr4_16gb_axis_dma_fifo_tvalid          ),
    .s_axis_dma_tdata           (ddr4_16gb_axis_dma_fifo_tdata           ),
    .m_axis_udp_pyl_tvalid      (ddr4_16gb_axis_udp_pyl_tvalid           ),
    .m_axis_udp_pyl_tready      (ddr4_16gb_axis_udp_pyl_tready           ),
    .m_axis_udp_pyl_tdata       (ddr4_16gb_axis_udp_pyl_tdata            ),
    .m_axis_udp_pyl_tkeep       (ddr4_16gb_axis_udp_pyl_tkeep            ),
    .m_axis_udp_pyl_tlast       (ddr4_16gb_axis_udp_pyl_tlast            ),
    .m_axis_udp_pyl_size_tvalid (ddr4_16gb_axis_udp_pyl_size_tvalid      ),
    .m_axis_udp_pyl_size_tready (ddr4_16gb_axis_udp_pyl_size_tready      ),
    .m_axis_udp_pyl_size_tdata  (ddr4_16gb_axis_udp_pyl_size_tdata       ),
    .sof_req                    (dma_read_ctrl_ddr4_16gb_sof_req         ),
    .eof_ack                    (dma_read_ctrl_ddr4_16gb_eof_ack         ),
    .pyl_acpt                   (dma_read_ctrl_ddr4_16gb_pyl_acpt        ),
    .core_busy                  (dma_read_ctrl_ddr4_16gb_core_busy       ),
    .sof_req_err                (/*NC*/                                  ),
    .pyl_acpt_err               (/*NC*/                                  ),
    .send_pyl_err               (/*NC*/                                  ),
    .send_last_err              (/*NC*/                                  ),
    .wait_ack_err               (/*NC*/                                  ),
    .dma_timeout_err            (/*NC*/                                  ),
    .metadata_data              (dma_read_ctrl_ddr4_16gb_metadata_data   ),
    .metadata_valid             (dma_read_ctrl_ddr4_16gb_metadata_valid  )
);

//------------------------------------------------------------------------------
// DMA read ctrl APB reg DDR4 16GB instance
//------------------------------------------------------------------------------
dma_read_ctrl_apb_reg_ddr4_16gb #(
    .APB_DATA_WIDTH    (32 ),
    .APB_ADDR_WIDTH    (32 ),
    .FRAME_INDEX_WIDTH (9  ),
    .METADATA_WIDTH    (640)
) dma_read_ctrl_apb_reg_ddr4_16gb_inst (
    .pclk                   (pclk                                    ),
    .presetn                (presetn                                 ),
    .penable                (dma_read_ctrl_ddr4_16gb_penable         ),
    .psel                   (dma_read_ctrl_ddr4_16gb_psel            ),
    .paddr                  (dma_read_ctrl_ddr4_16gb_paddr           ),
    .pwrite                 (dma_read_ctrl_ddr4_16gb_pwrite          ),
    .pwdata                 (dma_read_ctrl_ddr4_16gb_pwdata          ),
    .prdata                 (dma_read_ctrl_ddr4_16gb_prdata          ),
    .pready                 (dma_read_ctrl_ddr4_16gb_pready          ),
    .pslverr                (dma_read_ctrl_ddr4_16gb_pslverr         ),
    .clear                  (dma_read_ctrl_ddr4_16gb_clear           ),
    .frame_index            (dma_read_ctrl_ddr4_16gb_frame_index     ),
    .frame_read_done        (dma_read_ctrl_ddr4_16gb_frame_read_done ),
    .frame_read_done_int    (dma_read_ctrl_ddr4_16gb_frame_read_int  ),
    .frame_read_req         (dma_read_ctrl_ddr4_16gb_frame_read_req  ),
    .udp_metadata_sel       (dma_read_ctrl_ddr4_16gb_udp_metadata_sel),
    .h_size_beat            (dma_read_ctrl_ddr4_16gb_h_size_beat     ),
    .h_size_byte            (dma_read_ctrl_ddr4_16gb_h_size_byte     ),
    .jumbo_en               (dma_read_ctrl_ddr4_16gb_jumbo_en        ),
    .v_size_line            (dma_read_ctrl_ddr4_16gb_v_size_line     ),
    .frame_xfer_timeout_err (/*NC*/                                  ),
    .dma_timeout_err        (/*NC*/                                  ),
    .pyl_acpt_err           (/*NC*/                                  ),
    .send_last_err          (/*NC*/                                  ),
    .send_pyl_err           (/*NC*/                                  ),
    .sof_req_err            (/*NC*/                                  ),
    .wait_ack_err           (/*NC*/                                  ),
    .metadata_data          (dma_read_ctrl_ddr4_16gb_metadata_data   ),
    .metadata_valid         (dma_read_ctrl_ddr4_16gb_metadata_valid  )
);

//------------------------------------------------------------------------------
// UDP mux instance
//------------------------------------------------------------------------------
udp_mux udp_mux_inst (
    .mux_sel                                   (udp_tx_mux_sel                         ),
    .ddr4_8gb_img_frame_udp_pyl_size           (ddr4_8gb_axis_udp_pyl_size_tdata       ),
    .ddr4_8gb_img_frame_udp_pyl_size_ready     (ddr4_8gb_axis_udp_pyl_size_tready      ),
    .ddr4_8gb_img_frame_udp_pyl_size_valid     (ddr4_8gb_axis_udp_pyl_size_tvalid      ),
    .ddr4_8gb_img_frame_s_udp_pyl_axis_tvalid  (ddr4_8gb_axis_udp_pyl_tvalid           ),
    .ddr4_8gb_img_frame_s_udp_pyl_axis_tready  (ddr4_8gb_axis_udp_pyl_tready           ),
    .ddr4_8gb_img_frame_s_udp_pyl_axis_tdata   (ddr4_8gb_axis_udp_pyl_tdata            ),
    .ddr4_8gb_img_frame_s_udp_pyl_axis_tkeep   (ddr4_8gb_axis_udp_pyl_tkeep            ),
    .ddr4_8gb_img_frame_s_udp_pyl_axis_tlast   (ddr4_8gb_axis_udp_pyl_tlast            ),
    .ddr4_8gb_img_frame_eof_ack                (dma_read_ctrl_ddr4_8gb_eof_ack         ),
    .ddr4_8gb_img_frame_pyl_acpt               (dma_read_ctrl_ddr4_8gb_pyl_acpt        ),
    .ddr4_8gb_img_frame_core_busy              (dma_read_ctrl_ddr4_8gb_core_busy       ),
    .ddr4_8gb_img_frame_sof_req                (dma_read_ctrl_ddr4_8gb_sof_req         ),
    .ddr4_16gb_img_frame_udp_pyl_size          (ddr4_16gb_axis_udp_pyl_size_tdata      ),
    .ddr4_16gb_img_frame_udp_pyl_size_ready    (ddr4_16gb_axis_udp_pyl_size_tready     ),
    .ddr4_16gb_img_frame_udp_pyl_size_valid    (ddr4_16gb_axis_udp_pyl_size_tvalid     ),
    .ddr4_16gb_img_frame_s_udp_pyl_axis_tvalid (ddr4_16gb_axis_udp_pyl_tvalid          ),
    .ddr4_16gb_img_frame_s_udp_pyl_axis_tready (ddr4_16gb_axis_udp_pyl_tready          ),
    .ddr4_16gb_img_frame_s_udp_pyl_axis_tdata  (ddr4_16gb_axis_udp_pyl_tdata           ),
    .ddr4_16gb_img_frame_s_udp_pyl_axis_tkeep  (ddr4_16gb_axis_udp_pyl_tkeep           ),
    .ddr4_16gb_img_frame_s_udp_pyl_axis_tlast  (ddr4_16gb_axis_udp_pyl_tlast           ),
    .ddr4_16gb_img_frame_eof_ack               (dma_read_ctrl_ddr4_16gb_eof_ack        ),
    .ddr4_16gb_img_frame_pyl_acpt              (dma_read_ctrl_ddr4_16gb_pyl_acpt       ),
    .ddr4_16gb_img_frame_core_busy             (dma_read_ctrl_ddr4_16gb_core_busy      ),
    .ddr4_16gb_img_frame_sof_req               (dma_read_ctrl_ddr4_16gb_sof_req        ),
    .udp_pyl_size_valid                        (udp_tx_axis_udp_pyl_size_tvalid        ),
    .udp_pyl_size_ready                        (udp_tx_axis_udp_pyl_size_tready        ),
    .udp_pyl_size                              (udp_tx_axis_udp_pyl_size_tdata         ),
    .m_udp_pyl_axis_tvalid                     (udp_tx_axis_udp_pyl_tvalid             ),
    .m_udp_pyl_axis_tready                     (udp_tx_axis_udp_pyl_tready             ),
    .m_udp_pyl_axis_tdata                      (udp_tx_axis_udp_pyl_tdata              ),
    .m_udp_pyl_axis_tkeep                      (udp_tx_axis_udp_pyl_tkeep              ),
    .m_udp_pyl_axis_tlast                      (udp_tx_axis_udp_pyl_tlast              ),
    .eof_ack                                   (udp_tx_eof_ack                         ),
    .pyl_acpt                                  (udp_tx_pyl_acpt                        ),
    .core_busy                                 (udp_tx_core_busy                       ),
    .sof_req                                   (udp_tx_sof_req                         )
);

//------------------------------------------------------------------------------
// UDP tx top instance
//------------------------------------------------------------------------------
udp_tx_top #(
    .CLOCK_FREQ_MHZ   (100     ),
    .MAX_TIMEOUT_USEC (10000000),
    .ETH_TYPE         (16'h0800),
    .IP_VERSION       (4'h4    ),
    .IP_IHL           (4'h5    ),
    .IP_TOS           (8'h00   ),
    .IP_ID            (16'h0001),
    .IP_FLAGS         (3'h0    ),
    .IP_FRAG_OFFSET   (13'h0   ),
    .IP_TTL           (8'h40   ),
    .IP_PROTOCOL      (8'h11   )
) udp_tx_top_inst (
    .clk                   (udp_clk                        ),
    .rst_n                 (udp_rst_n                      ),
    .eth_hdr_valid         (eth_hdr_valid                  ),
    .eth_hdr_ready         (eth_hdr_ready                  ),
    .dst_mac_addr          (dst_mac_addr                   ),
    .src_mac_addr          (src_mac_addr                   ),
    .iph_hdr_valid         (iph_hdr_valid                  ),
    .iph_hdr_ready         (iph_hdr_ready                  ),
    .dst_ip_addr           (dst_ip_addr                    ),
    .src_ip_addr           (src_ip_addr                    ),
    .udp_hdr_valid         (udp_hdr_valid                  ),
    .udp_hdr_ready         (udp_hdr_ready                  ),
    .udp_src_port          (udp_src_port                   ),
    .udp_dst_port          (udp_dst_port                   ),
    .udp_pyl_size_valid    (udp_tx_axis_udp_pyl_size_tvalid),
    .udp_pyl_size_ready    (udp_tx_axis_udp_pyl_size_tready),
    .udp_pyl_size          (udp_tx_axis_udp_pyl_size_tdata ),
    .s_axis_udp_pyl_tvalid (udp_tx_axis_udp_pyl_tvalid     ),
    .s_axis_udp_pyl_tready (udp_tx_axis_udp_pyl_tready     ),
    .s_axis_udp_pyl_tdata  (udp_tx_axis_udp_pyl_tdata      ),
    .s_axis_udp_pyl_tkeep  (udp_tx_axis_udp_pyl_tkeep      ),
    .s_axis_udp_pyl_tlast  (udp_tx_axis_udp_pyl_tlast      ),
    .MTXACPT               (udp_tx_mtxacpt                 ),
    .MTXRDY                (udp_tx_mtxrdy                  ),
    .MTXDAT                (udp_tx_mtxdat                  ),
    .MTXEOF                (udp_tx_mtxeof                  ),
    .MTXBYTEVALID          (udp_tx_mtxbytevalid            ),
    .MTXSOF                (udp_tx_mtxsof                  ),
    .sof_req               (udp_tx_sof_req                 ),
    .eof_ack               (udp_tx_eof_ack                 ),
    .pyl_acpt              (udp_tx_pyl_acpt                ),
    .core_busy             (udp_tx_core_busy               ),
    .clear                 (udp_tx_clear                   ),
    .wd_timeout_err_count  (udp_tx_wd_timeout_err_count    ),
    .frame_gap             (udp_tx_frame_gap               )
);

//------------------------------------------------------------------------------
// UDP tx APB reg instance
//------------------------------------------------------------------------------
udp_tx_apb_reg #(
    .APB_DATA_WIDTH (32),
    .APB_ADDR_WIDTH (32)
) udp_tx_apb_reg_inst (
    .pclk                 (pclk                       ),
    .presetn              (presetn                    ),
    .penable              (udp_tx_penable             ),
    .psel                 (udp_tx_psel                ),
    .paddr                (udp_tx_paddr               ),
    .pwrite               (udp_tx_pwrite              ),
    .pwdata               (udp_tx_pwdata              ),
    .prdata               (udp_tx_prdata              ),
    .pready               (udp_tx_pready              ),
    .pslverr              (udp_tx_pslverr             ),
    .udp_clk              (udp_clk                    ),
    .udp_rst_n            (udp_rst_n                  ),
    .udp_dst_port         (udp_dst_port               ),
    .udp_src_port         (udp_src_port               ),
    .udp_hdr_valid        (udp_hdr_valid              ),
    .udp_hdr_ready        (udp_hdr_ready              ),
    .dst_ip_addr          (dst_ip_addr                ),
    .src_ip_addr          (src_ip_addr                ),
    .iph_hdr_valid        (iph_hdr_valid              ),
    .iph_hdr_ready        (iph_hdr_ready              ),
    .dst_mac_addr         (dst_mac_addr               ),
    .src_mac_addr         (src_mac_addr               ),
    .eth_hdr_valid        (eth_hdr_valid              ),
    .eth_hdr_ready        (eth_hdr_ready              ),
    .wd_timeout_err_count (udp_tx_wd_timeout_err_count),
    .mux_sel              (udp_tx_mux_sel             ),
    .udp_clr              (udp_tx_clear               ),
    .frame_gap            (udp_tx_frame_gap           )
);

//------------------------------------------------------------------------------
// Rsp top instance
//------------------------------------------------------------------------------
rsp_top #(
    .CLOCK_FREQ_MHZ (100),
    .PHY_INIT_USEC  (100),
    .MAC_DATA_WIDTH (32 ),
    .RSP_DATA_WIDTH (128),
    .MAC_WIDTH      (48 ),
    .IPV4_WIDTH     (32 )
) rsp_top_inst (
    .clk            (udp_clk         ),
    .rst_n          (udp_rst_n       ),
    .src_mac_valid  (eth_hdr_valid   ),
    .src_mac_addr   (src_mac_addr    ),
    .src_ipv4_valid (iph_hdr_valid   ),
    .src_ipv4_addr  (src_ip_addr     ),
    .rxacpt         (MRXACPT         ),
    .rxrdy          (MRXRDY          ),
    .rxdata         (MRXDAT          ),
    .rxeof          (MRXEOF          ),
    .rxbytevalid    (MRXBYTEVALID    ),
    .rxsof          (MRXSOF          ),
    .txacpt         (rsp_mtxacpt     ),
    .txrdy          (rsp_mtxrdy      ),
    .txdata         (rsp_mtxdat      ),
    .txeof          (rsp_mtxeof      ),
    .txbytevalid    (rsp_mtxbytevalid),
    .txsof          (rsp_mtxsof      ),
    .core_busy      (rsp_core_busy   )
);

//------------------------------------------------------------------------------
// MTX mux instance
//------------------------------------------------------------------------------
mtx_mux mtx_mux_inst (
    .clk             (udp_clk            ),
    .rst_n           (udp_rst_n          ),
    .udp_core_busy   (udp_tx_core_busy   ),
    .arp_core_busy   (rsp_core_busy      ),
    .udp_txbytevalid (udp_tx_mtxbytevalid),
    .udp_txdata      (udp_tx_mtxdat      ),
    .udp_txeof       (udp_tx_mtxeof      ),
    .udp_txrdy       (udp_tx_mtxrdy      ),
    .udp_txsof       (udp_tx_mtxsof      ),
    .udp_txacpt      (udp_tx_mtxacpt     ),
    .arp_txbytevalid (rsp_mtxbytevalid   ),
    .arp_txdata      (rsp_mtxdat         ),
    .arp_txeof       (rsp_mtxeof         ),
    .arp_txrdy       (rsp_mtxrdy         ),
    .arp_txsof       (rsp_mtxsof         ),
    .arp_txacpt      (rsp_mtxacpt        ),
    .MTXBYTEVALID    (MTXBYTEVALID       ),
    .MTXDAT          (MTXDAT             ),
    .MTXEOF          (MTXEOF             ),
    .MTXRDY          (MTXRDY             ),
    .MTXSOF          (MTXSOF             ),
    .MTXACPT         (MTXACPT            )
);

endmodule