/*
 * @file      dma_write_ctrl.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      10/15/2025
 *
 * @brief     General DMA write controller top module
 *
 * @section changelog
 * - 10/15/2025: Saba Janamian - Initial implementation
 *
 */

module dma_write_ctrl #(
    parameter integer CLOCK_FREQ_MHZ    = 150,
    parameter integer TIMEOUT_USEC      = 10_000, // 10 mSec
    parameter integer CAM_DATA_WIDTH_IN = 384,
    parameter integer DDR_ADDR_WIDTH    = 38,
    parameter integer DDR_DATA_WIDTH    = 256,
    parameter integer DIN_DOUT_RATIO    = 2, // 2 if DATA_WIDTH is 256, 1 if 512
    parameter integer FRAME_WIDTH       = 25, // 25 bits of addr to store frame
    parameter integer USABLE_ADDR_WIDTH = 33, // 2^30 * 2^3 = 8GB
    parameter integer FRAME_INDEX_WIDTH = USABLE_ADDR_WIDTH - FRAME_WIDTH, // 8,
    parameter integer WCONV_DATA_OUT_WIDTH = 512

)(
    // Pixel clock domain
    input  logic                            pixel_clk,
    input  logic                            pixel_rst_n,
    // DDR4 clock domain
    input  logic                            ddr_clk,
    input  logic                            ddr_rst_n,
    // Cam interface
    input  logic                            cam_frame_valid,
    input  logic                            cam_line_valid,
    input  logic [CAM_DATA_WIDTH_IN-1:0]    cam_data_in,
    // WCONV interface
    output logic                            wconv_valid_out,
    output logic [WCONV_DATA_OUT_WIDTH-1:0] wconv_data_out,
    // APB Reg interface
    input  logic                            apb_reg_clear_index,
    input  logic [13:0]                     apb_reg_h_size_byte,
    output logic [FRAME_INDEX_WIDTH-1:0]    apb_reg_frame_index,
    output logic                            apb_reg_core_ready,
    output logic                            apb_reg_frame_write_done,
    output logic                            apb_reg_timeout_err,
    // FIFO interface
    output logic                            fifo_read_en,
    input  logic                            fifo_valid,
    input  logic [DDR_DATA_WIDTH-1:0]       fifo_data,
    // DMA to Arbiter interface
    output logic                            arb_write_req,
    input  logic                            arb_write_ack,
    output logic [7:0]                      arb_write_burst_len,
    output logic [DDR_ADDR_WIDTH-1:0]       arb_write_start_addr,
    input  logic                            arb_write_done,
    output logic                            arb_write_valid,
    output logic [DDR_DATA_WIDTH-1:0]       arb_write_data
);

//------------------------------------------------------------------------------
// Internal signals
//------------------------------------------------------------------------------
logic [9:0]                      net_chunk_count;
logic                            net_chunk_count_valid;
logic                            net_chunk_count_ack;

//------------------------------------------------------------------------------
// Width Converter instance (Converts 384 bits to 512 bits)
//------------------------------------------------------------------------------
wconv_4in_3out #(
    .DWIDTH_IN  (CAM_DATA_WIDTH_IN   ),
    .DWIDTH_OUT (WCONV_DATA_OUT_WIDTH)
) wconv_4in_3out_inst (
    .clk        (pixel_clk           ),
    .rst_n      (pixel_rst_n         ),
    .valid_in   (cam_line_valid      ),
    .data_in    (cam_data_in         ),
    .valid_out  (wconv_valid_out     ),
    .data_out   (wconv_data_out      )
);


//------------------------------------------------------------------------------
// DMA receive controller instance
//------------------------------------------------------------------------------
dma_write_recv_ctrl dma_write_recv_ctrl_inst (
    .pixel_clk         (pixel_clk            ),
    .pixel_rst_n       (pixel_rst_n          ),
    // CAM interface
    .line_valid        (cam_line_valid       ),
    .chunk_valid       (wconv_valid_out      ),
    // Control interface
    .chunk_count       (net_chunk_count      ),
    .chunk_count_valid (net_chunk_count_valid),
    .chunk_count_ack   (net_chunk_count_ack  )
);

//------------------------------------------------------------------------------
// DMA send controller instance
//------------------------------------------------------------------------------
dma_write_send_ctrl #(
    .CLOCK_FREQ_MHZ       (CLOCK_FREQ_MHZ       ),
    .TIMEOUT_USEC         (TIMEOUT_USEC         ),
    .DDR_ADDR_WIDTH       (DDR_ADDR_WIDTH       ),
    .DDR_DATA_WIDTH       (DDR_DATA_WIDTH       ),
    .DIN_DOUT_RATIO       (DIN_DOUT_RATIO       ),
    .FRAME_WIDTH          (FRAME_WIDTH          ),
    .USABLE_ADDR_WIDTH    (USABLE_ADDR_WIDTH    ),
    .FRAME_INDEX_WIDTH    (FRAME_INDEX_WIDTH    )
) dma_write_send_ctrl_inst (
    // DDR4 clock domain
    .ddr_clk              (ddr_clk              ),
    .ddr_rst_n            (ddr_rst_n            ),
    // CAM interface
    .frame_valid          (cam_frame_valid      ),
    .line_valid           (cam_line_valid       ),
    // Recv Ctrl interface
    .chunk_count          (net_chunk_count      ),
    .chunk_count_valid    (net_chunk_count_valid),
    .chunk_count_ack      (net_chunk_count_ack  ),
    // APB Reg interface
    .clear_index          (apb_reg_clear_index  ),
    .h_size_byte          (apb_reg_h_size_byte  ),
    .frame_index          (apb_reg_frame_index  ),
    .core_ready           (apb_reg_core_ready   ),
    .frame_write_done     (apb_reg_frame_write_done),
    .timeout_err          (apb_reg_timeout_err  ),
    // FIFO interface
    .fifo_en              (fifo_read_en         ),
    .fifo_valid           (fifo_valid           ),
    .fifo_data            (fifo_data            ),
    // DMA to Arbiter interface
    .arb_write_req        (arb_write_req        ),
    .arb_write_ack        (arb_write_ack        ),
    .arb_write_burst_len  (arb_write_burst_len  ),
    .arb_write_start_addr (arb_write_start_addr ),
    .arb_write_done       (arb_write_done       ),
    .arb_write_valid      (arb_write_valid      ),
    .arb_write_data       (arb_write_data       )
);

endmodule
