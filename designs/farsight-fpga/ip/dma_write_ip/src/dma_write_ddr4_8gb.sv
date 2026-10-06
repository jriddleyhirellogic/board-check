/*
 * @file      dma_write_ddr4_8gb.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      10/15/2025
 *
 * @brief     Top module for DMA Write 8GB DDR memory
 *
 * @section changelog
 * - 10/15/2025: Saba Janamian - Initial implementation
 *
 */

module dma_write_ddr4_8gb #(
    parameter integer CLOCK_FREQ_MHZ = 150,
    parameter integer TIMEOUT_USEC   = 10_000 // 10 mSec
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
    input  logic [383:0]                    cam_data_in,
    // APB Reg interface
    input  logic                            apb_reg_clear_index,
    input  logic [13:0]                     apb_reg_h_size_byte, // (LINE_GAP)
    output logic [7:0]                      apb_reg_frame_index,
    output logic                            apb_reg_core_ready,
    output logic                            apb_reg_frame_write_done,
    output logic                            apb_reg_timeout_err,
    // DMA to Arbiter interface
    output logic                            arb_write_req,
    input  logic                            arb_write_ack,
    output logic [7:0]                      arb_write_burst_len,
    output logic [37:0]                     arb_write_start_addr,
    input  logic                            arb_write_done,
    output logic                            arb_write_valid,
    output logic [255:0]                    arb_write_data
);

//------------------------------------------------------------------------------
// Local parameters (specific to 8GB DDR4)
//------------------------------------------------------------------------------
localparam integer CAM_DATA_WIDTH_IN = 384;
localparam integer DDR_ADDR_WIDTH    = 38;
localparam integer DDR_DATA_WIDTH    = 256;
localparam integer DIN_DOUT_RATIO    = 2; // 2 if DATA_WIDTH is 256, 1 if 512
localparam integer FRAME_WIDTH       = 25; // 25 bits of addr to store frame
localparam integer USABLE_ADDR_WIDTH = 33; // 2^30 * 2^3 = 8GB
localparam integer FRAME_INDEX_WIDTH = USABLE_ADDR_WIDTH - FRAME_WIDTH; // 8
localparam integer WCONV_DATA_OUT_WIDTH = 512;
//------------------------------------------------------------------------------
// Internal signals
//------------------------------------------------------------------------------
// FIFO interface
logic                            net_fifo_read_en;
logic                            net_fifo_valid;
logic [DDR_DATA_WIDTH-1:0]       net_fifo_data;

logic                            net_wconv_valid_out;
logic [WCONV_DATA_OUT_WIDTH-1:0] net_wconv_data_out;
//------------------------------------------------------------------------------
// DMA Write Controller instance
//------------------------------------------------------------------------------
dma_write_ctrl #(
    .CLOCK_FREQ_MHZ           (CLOCK_FREQ_MHZ          ),
    .TIMEOUT_USEC             (TIMEOUT_USEC            ),
    .CAM_DATA_WIDTH_IN        (CAM_DATA_WIDTH_IN       ),
    .DDR_ADDR_WIDTH           (DDR_ADDR_WIDTH          ),
    .DDR_DATA_WIDTH           (DDR_DATA_WIDTH          ),
    .DIN_DOUT_RATIO           (DIN_DOUT_RATIO          ),
    .FRAME_WIDTH              (FRAME_WIDTH             ),
    .USABLE_ADDR_WIDTH        (USABLE_ADDR_WIDTH       ),
    .FRAME_INDEX_WIDTH        (FRAME_INDEX_WIDTH       ),
    .WCONV_DATA_OUT_WIDTH     (WCONV_DATA_OUT_WIDTH    )
) dma_write_ctrl_8gb_ddr4_inst (
    // Pixel clock domain
    .pixel_clk                (pixel_clk               ),
    .pixel_rst_n              (pixel_rst_n             ),
    // DDR4 clock domain
    .ddr_clk                  (ddr_clk                 ),
    .ddr_rst_n                (ddr_rst_n               ),
    // Cam interface
    .cam_frame_valid          (cam_frame_valid         ),
    .cam_line_valid           (cam_line_valid          ),
    .cam_data_in              (cam_data_in             ),
    // WCONV interface
    .wconv_valid_out          (net_wconv_valid_out     ),
    .wconv_data_out           (net_wconv_data_out      ),
    // APB Reg interface
    .apb_reg_clear_index      (apb_reg_clear_index     ),
    .apb_reg_h_size_byte      (apb_reg_h_size_byte     ),
    .apb_reg_frame_index      (apb_reg_frame_index     ),
    .apb_reg_core_ready       (apb_reg_core_ready      ),
    .apb_reg_frame_write_done (apb_reg_frame_write_done),
    .apb_reg_timeout_err      (apb_reg_timeout_err     ),
    // FIFO interface
    .fifo_read_en             (net_fifo_read_en        ),
    .fifo_valid               (net_fifo_valid          ),
    .fifo_data                (net_fifo_data           ),
    // DMA to Arbiter interface
    .arb_write_req            (arb_write_req           ),
    .arb_write_ack            (arb_write_ack           ),
    .arb_write_burst_len      (arb_write_burst_len     ),
    .arb_write_start_addr     (arb_write_start_addr    ),
    .arb_write_done           (arb_write_done          ),
    .arb_write_valid          (arb_write_valid         ),
    .arb_write_data           (arb_write_data          )
);

//------------------------------------------------------------------------------
// FIFO instance
//------------------------------------------------------------------------------
COREFIFO_DMA_WR_8GB corefifo_dma_wr_8gb_inst(
    // FIFO Write interface
    .WCLOCK                  (pixel_clk               ),
    .WRESET_N                (pixel_rst_n             ),
    .WE                      (net_wconv_valid_out     ),
    .DATA                    (net_wconv_data_out      ),
    // FIFO Read interface
    .RCLOCK                  (ddr_clk                 ),
    .RRESET_N                (ddr_rst_n               ),
    .RE                      (net_fifo_read_en        ),
    .DVLD                    (net_fifo_valid          ),
    .Q                       (net_fifo_data           ),
    .EMPTY                   (/* NC */                ),
    .FULL                    (/* NC */                )
);

endmodule
