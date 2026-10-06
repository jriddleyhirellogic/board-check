/*
 * @file      dma_read_ddr4_16gb.sv
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

module dma_read_ddr4_16gb #(
    parameter integer DDR4_CLOCK_FREQ_MHZ = 150,
    parameter integer TIMEOUT_USEC        = 10_000, // 10 mSec
    parameter integer DDR_ADDR_WIDTH      = 39,
    parameter integer DDR_DATA_WIDTH      = 512,
    parameter integer DATA_OUT_WIDTH      = 32
)(
    input  logic                      ddr_clk,
    input  logic                      ddr_rst_n,
    input  logic                      ctrl_clk,
    input  logic                      ctrl_rst_n,
    // Controller read interface (controller clock domain)
    input  logic                      ctrl_info_valid,  // CDC
    input  logic [8:0]                ctrl_burst_count, // CDC
    input  logic [DDR_ADDR_WIDTH-1:0] ctrl_read_addr,  // CDC
    // DMA to Controller handshaking interface
    output logic                      dma_ready,
    input  logic                      dma_read_req,     // CDC
    output logic                      dma_read_ack,
    input  logic                      dma_fifo_clear,   // CDC
    // FIFO read interface (controller clock domain)
    input  logic                      m_axis_dma_tready, // DMA FIFO read enable
    output logic                      m_axis_dma_tvalid, // DMA FIFO data valid
    output logic [DATA_OUT_WIDTH-1:0] m_axis_dma_tdata,  // DMA FIFO data input
    // DMA to Arbiter interface
    output logic                      arb_read_req,
    input  logic                      arb_read_ack,
    output logic [7:0]                arb_read_burst_len,
    output logic [DDR_ADDR_WIDTH-1:0] arb_read_start_addr,
    input  logic                      arb_read_done,
    input  logic                      arb_read_valid,
    input  logic [DDR_DATA_WIDTH-1:0] arb_data_in,
    // Control and Status signals
    input  logic                      clear, // CDC (APB clock domain)
    output logic                      timeout_err
);

//------------------------------------------------------------------------------
// Internal Signals
//------------------------------------------------------------------------------
// FIFO (Write clock domain)
logic                      fifo_write_rst_n;
logic                      fifo_write_en;
logic [DDR_DATA_WIDTH-1:0] fifo_write_data;
// FIFO (Read clock domain)
logic                      fifo_read_rst_n;
logic                      fifo_read_en;
logic                      fifo_read_valid;
logic [DATA_OUT_WIDTH-1:0] fifo_read_data;
logic                      fifo_empty;

//------------------------------------------------------------------------------
// DMA Read Controller instance
//------------------------------------------------------------------------------
dma_read #(
    .DDR4_CLOCK_FREQ_MHZ (DDR4_CLOCK_FREQ_MHZ  ),
    .TIMEOUT_USEC        (TIMEOUT_USEC         ),
    .DDR_ADDR_WIDTH      (DDR_ADDR_WIDTH       ),
    .DDR_DATA_WIDTH      (DDR_DATA_WIDTH       ),
    .DATA_OUT_WIDTH      (DATA_OUT_WIDTH       )
) dma_read_ddr4_16gb_inst (
    .ddr_clk             (ddr_clk              ),
    .ddr_rst_n           (ddr_rst_n            ),
    .ctrl_clk            (ctrl_clk             ),
    .ctrl_rst_n          (ctrl_rst_n           ),
    .ctrl_info_valid     (ctrl_info_valid      ),
    .ctrl_burst_count    (ctrl_burst_count     ),
    .ctrl_read_addr      (ctrl_read_addr       ),
    .dma_ready           (dma_ready            ),
    .dma_read_req        (dma_read_req         ),
    .dma_read_ack        (dma_read_ack         ),
    .dma_fifo_clear      (dma_fifo_clear       ),
    .m_axis_dma_tready   (m_axis_dma_tready    ),
    .m_axis_dma_tvalid   (m_axis_dma_tvalid    ),
    .m_axis_dma_tdata    (m_axis_dma_tdata     ),
    .arb_read_req        (arb_read_req         ),
    .arb_read_ack        (arb_read_ack         ),
    .arb_read_burst_len  (arb_read_burst_len   ),
    .arb_read_start_addr (arb_read_start_addr  ),
    .arb_read_done       (arb_read_done        ),
    .arb_read_valid      (arb_read_valid       ),
    .arb_data_in         (arb_data_in          ),
    .fifo_write_rst_n    (fifo_write_rst_n     ),
    .fifo_write_en       (fifo_write_en        ),
    .fifo_write_data     (fifo_write_data      ),
    .fifo_read_rst_n     (fifo_read_rst_n      ),
    .fifo_read_en        (fifo_read_en         ),
    .fifo_read_valid     (fifo_read_valid      ),
    .fifo_read_data      (fifo_read_data       ),
    .fifo_empty          (fifo_empty           ),
    .clear               (clear                ),
    .timeout_err         (timeout_err          )

);

//------------------------------------------------------------------------------
// DMA Read FIFO
//------------------------------------------------------------------------------
COREFIFO_DMA_READ_DDR4_16GB_C0 corefifo_dma_read_ddr4_16gb_inst (
    .WCLOCK             (ddr_clk              ),
    .WRESET_N           (fifo_write_rst_n     ),
    .WE                 (fifo_write_en        ),
    .DATA               (fifo_write_data      ),
    .RCLOCK             (ctrl_clk             ),
    .RRESET_N           (fifo_read_rst_n      ),
    .RE                 (fifo_read_en         ),
    .DVLD               (fifo_read_valid      ),
    .Q                  (fifo_read_data       ),
    .EMPTY              (fifo_empty           ),
    .FULL               (/* NC */             )
);

endmodule
