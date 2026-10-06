/*
 * @file      dma_read_ctrl_apb_reg_ddr4_8gb.sv
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

module dma_read_ctrl_apb_reg_ddr4_8gb #(
    parameter integer APB_DATA_WIDTH    = 32,
    parameter integer APB_ADDR_WIDTH    = 32,
    parameter integer FRAME_INDEX_WIDTH = 8,
    parameter integer METADATA_WIDTH    = 640
)(
    // APB Slave interface
    input  logic                         pclk,     // APB clock
    input  logic                         presetn,  // APB resetn
    input  logic                         penable,  // APB enable
    input  logic                         psel,     // APB periph select
    input  logic [APB_ADDR_WIDTH-1:0]    paddr,    // APB address bus
    input  logic                         pwrite,   // APB write req
    input  logic [APB_DATA_WIDTH-1:0]    pwdata,   // APB write data
    output logic [APB_DATA_WIDTH-1:0]    prdata,   // APB read data
    output logic                         pready,   // APB ready signal
    output logic                         pslverr,  // APB error signal
    // DMA_CTRL_INTF
    output logic                         clear,
    output logic [FRAME_INDEX_WIDTH-1:0] frame_index,
    input  logic                         frame_read_done,
    output logic                         frame_read_req,
    output logic                         frame_read_done_int,
    output logic                         udp_metadata_sel,
    output logic [8:0]                   h_size_beat,
    output logic [13:0]                  h_size_byte,
    output logic                         jumbo_en,
    output logic [12:0]                  v_size_line,
    // APB_REG_ERR_INTF
    input  logic [31:0]                  frame_xfer_timeout_err,
    input  logic [31:0]                  dma_timeout_err,
    input  logic [31:0]                  pyl_acpt_err,
    input  logic [31:0]                  send_last_err,
    input  logic [31:0]                  send_pyl_err,
    input  logic [31:0]                  sof_req_err,
    input  logic [31:0]                  wait_ack_err,
    // Metadata capture interface
    input  logic [METADATA_WIDTH-1:0]    metadata_data,
    input  logic                         metadata_valid
);

dma_read_ctrl_apb_reg #(
    .APB_DATA_WIDTH    (APB_DATA_WIDTH   ),
    .APB_ADDR_WIDTH    (APB_ADDR_WIDTH   ),
    .FRAME_INDEX_WIDTH (FRAME_INDEX_WIDTH),
    .METADATA_WIDTH    (METADATA_WIDTH   )
) dma_read_ctrl_apb_reg_ddr4_8gb_inst0 (
    .pclk                   (pclk                  ),
    .presetn                (presetn               ),
    .penable                (penable               ),
    .psel                   (psel                  ),
    .paddr                  (paddr                 ),
    .pwrite                 (pwrite                ),
    .pwdata                 (pwdata                ),
    .prdata                 (prdata                ),
    .pready                 (pready                ),
    .pslverr                (pslverr               ),
    .clear                  (clear                 ),
    .frame_index            (frame_index           ),
    .frame_read_done        (frame_read_done       ),
    .frame_read_req         (frame_read_req        ),
    .frame_read_done_int    (frame_read_done_int   ),
    .udp_metadata_sel       (udp_metadata_sel      ),
    .h_size_beat            (h_size_beat           ),
    .h_size_byte            (h_size_byte           ),
    .jumbo_en               (jumbo_en              ),
    .v_size_line            (v_size_line           ),
    .frame_xfer_timeout_err (frame_xfer_timeout_err),
    .dma_timeout_err        (dma_timeout_err       ),
    .pyl_acpt_err           (pyl_acpt_err          ),
    .send_last_err          (send_last_err         ),
    .send_pyl_err           (send_pyl_err          ),
    .sof_req_err            (sof_req_err           ),
    .wait_ack_err           (wait_ack_err          ),
    .metadata_data          (metadata_data         ),
    .metadata_valid         (metadata_valid        )
);

endmodule
