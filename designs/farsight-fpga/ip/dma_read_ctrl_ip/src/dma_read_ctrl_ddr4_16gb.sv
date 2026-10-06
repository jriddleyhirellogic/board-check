/*
 * @file      dma_read_ctrl_ddr4_16gb.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      11/11/2025
 *
 * @brief
 *
 * @section changelog
 * - 11/11/2025: Saba Janamian - Initial implementation
 *
 */


module dma_read_ctrl_ddr4_16gb #(
    parameter integer CLOCK_FREQ_MHZ    = 100,
    parameter integer TIMEOUT_USEC      = 10_000, // 10 mSec
    parameter integer DDR_ADDR_WIDTH    = 39,
    parameter integer DDR_DATA_WIDTH    = 512,
    parameter integer USABLE_ADDR_WIDTH = 34, // 2^30 * 2^4 = 16GB
    parameter integer FRAME_WIDTH       = 25, // 2^25 frame size (32Gbits)
    parameter integer FRAME_INDEX_WIDTH = USABLE_ADDR_WIDTH - FRAME_WIDTH, // 9
    parameter integer METADATA_WIDTH    = 640  // bits
)(
    input  logic                         udp_clk,
    input  logic                         udp_rst_n,
    // Control from RSICV APB Reg IP ports
    input  logic                         clear,             //
    input  logic                         frame_read_req,    // SW req read
    output logic                         frame_read_done,   // Ack frame read
    input  logic                         udp_metadata_sel,  // 0=UDP image, 1=metadata
    input  logic [8:0]                   h_size_beat,       // Can't be >511
    input  logic [13:0]                  h_size_byte,       // a.k.a LINE_GAP
    input  logic [12:0]                  v_size_line,       // Can't be >8192
    input  logic [FRAME_INDEX_WIDTH-1:0] frame_index,       // Index of frame
    input  logic                         jumbo_en,          //
    output logic [31:0]                  frame_xfer_timeout_err,
    // DMA read interface to frame_xfer
    input  logic                         dma_ready,       // DMA ready for next req
    output logic                         ctrl_info_valid,
    output logic [DDR_ADDR_WIDTH-1:0]    ctrl_read_addr,   // Line read Addr
    output logic [8:0]                   ctrl_burst_count, // Num of chunks to read
    output logic                         dma_fifo_clear,
    // DMA read interface to dma_read_ctrl
    output logic                         dma_read_req,      // Req read from DMA
    input  logic                         dma_read_ack,      // DMA read acept sig
    // DMA Read FIFO interface (dma_read_ctrl interface)
    output logic                         s_axis_dma_tready, // DMA FIFO read enable
    input  logic                         s_axis_dma_tvalid, // DMA FIFO data valid
    input  logic [31:0]                  s_axis_dma_tdata,  // DMA FIFO data input
    // UDP IP Payload interface (dma_read_ctrl interface)
    output logic                         m_axis_udp_pyl_tvalid,
    input  logic                         m_axis_udp_pyl_tready,
    output logic [31:0]                  m_axis_udp_pyl_tdata,
    output logic [3:0]                   m_axis_udp_pyl_tkeep,
    output logic                         m_axis_udp_pyl_tlast,
    // UDP IP Payload size interface (dma_read_ctrl interface)
    output logic                         m_axis_udp_pyl_size_tvalid,
    input  logic                         m_axis_udp_pyl_size_tready,
    output logic [15:0]                  m_axis_udp_pyl_size_tdata,
    // UDP IP Control interface (dma_read_ctrl interface)
    output logic                         sof_req,
    input  logic                         eof_ack,
    input  logic                         pyl_acpt,
    input  logic                         core_busy,
    // Status signals (dma_read_ctrl interface to APB reg)
    output logic [31:0]                  sof_req_err,
    output logic [31:0]                  pyl_acpt_err,
    output logic [31:0]                  send_pyl_err,
    output logic [31:0]                  send_last_err,
    output logic [31:0]                  wait_ack_err,
    output logic [31:0]                  dma_timeout_err,
    // Metadata capture interface
    output logic [METADATA_WIDTH-1:0]    metadata_data,
    output logic                         metadata_valid
);

//------------------------------------------------------------------------------
// DMA to udp top DDR4 16GB inst
//------------------------------------------------------------------------------
dma_read_ctrl_top #(
    .CLOCK_FREQ_MHZ             (CLOCK_FREQ_MHZ            ),
    .TIMEOUT_USEC               (TIMEOUT_USEC              ),
    .DDR_ADDR_WIDTH             (DDR_ADDR_WIDTH            ),
    .DDR_DATA_WIDTH             (DDR_DATA_WIDTH            ),
    .USABLE_ADDR_WIDTH          (USABLE_ADDR_WIDTH         ),
    .FRAME_WIDTH                (FRAME_WIDTH               ),
    .FRAME_INDEX_WIDTH          (FRAME_INDEX_WIDTH         ),
    .METADATA_WIDTH             (METADATA_WIDTH            )
) dma_read_ctrl_top_16gb_inst(
    .clk                        (udp_clk                   ),
    .rst_n                      (udp_rst_n                 ),
    .clear                      (clear                     ),
    .frame_read_req             (frame_read_req            ),
    .frame_read_done            (frame_read_done           ),
    .udp_metadata_sel           (udp_metadata_sel          ),
    .h_size_beat                (h_size_beat               ),
    .h_size_byte                (h_size_byte               ),
    .v_size_line                (v_size_line               ),
    .frame_index                (frame_index               ),
    .frame_xfer_timeout_err     (frame_xfer_timeout_err    ),
    .jumbo_en                   (jumbo_en                  ),
    .dma_ready                  (dma_ready                 ),
    .ctrl_info_valid            (ctrl_info_valid           ),
    .ctrl_read_addr             (ctrl_read_addr            ),
    .ctrl_burst_count           (ctrl_burst_count          ),
    .dma_fifo_clear             (dma_fifo_clear            ),
    .dma_read_req               (dma_read_req              ),
    .dma_read_ack               (dma_read_ack              ),
    .s_axis_dma_tready          (s_axis_dma_tready         ),
    .s_axis_dma_tvalid          (s_axis_dma_tvalid         ),
    .s_axis_dma_tdata           (s_axis_dma_tdata          ),
    .m_axis_udp_pyl_tvalid      (m_axis_udp_pyl_tvalid     ),
    .m_axis_udp_pyl_tready      (m_axis_udp_pyl_tready     ),
    .m_axis_udp_pyl_tdata       (m_axis_udp_pyl_tdata      ),
    .m_axis_udp_pyl_tkeep       (m_axis_udp_pyl_tkeep      ),
    .m_axis_udp_pyl_tlast       (m_axis_udp_pyl_tlast      ),
    .m_axis_udp_pyl_size_tvalid (m_axis_udp_pyl_size_tvalid),
    .m_axis_udp_pyl_size_tready (m_axis_udp_pyl_size_tready),
    .m_axis_udp_pyl_size_tdata  (m_axis_udp_pyl_size_tdata ),
    .sof_req                    (sof_req                   ),
    .eof_ack                    (eof_ack                   ),
    .pyl_acpt                   (pyl_acpt                  ),
    .core_busy                  (core_busy                 ),
    .sof_req_err                (sof_req_err               ),
    .pyl_acpt_err               (pyl_acpt_err              ),
    .send_pyl_err               (send_pyl_err              ),
    .send_last_err              (send_last_err             ),
    .wait_ack_err               (wait_ack_err              ),
    .dma_timeout_err            (dma_timeout_err           ),
    .metadata_data              (metadata_data             ),
    .metadata_valid             (metadata_valid            )
);

endmodule
