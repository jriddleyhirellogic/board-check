/*
 * @file      dma_write_apb_reg_ddr4_16gb.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      10/16/2025
 *
 * @brief     DMA Write APB Reg for DDR16 top module
 *
 * @section changelog
 * - 10/16/2025: Saba Janamian - Initial implementation
 *
 */

module dma_write_apb_reg_ddr4_16gb #(
    parameter integer APB_DATA_WIDTH    = 32,
    parameter integer APB_ADDR_WIDTH    = 32
)(
    // APB Slave interface
    input  logic                          pclk,     // APB clock
    input  logic                          presetn,  // APB resetn
    input  logic                          penable,  // APB enable
    input  logic                          psel,     // APB periph select
    input  logic [APB_ADDR_WIDTH-1:0]     paddr,    // APB address bus
    input  logic                          pwrite,   // APB write req
    input  logic [APB_DATA_WIDTH-1:0]     pwdata,   // APB write data
    output logic [APB_DATA_WIDTH-1:0]     prdata,   // APB read data
    output logic                          pready,   // APB ready signal
    output logic                          pslverr,  // APB error signal
    // DMA_CTRL_INTF
    output logic                          clear_index,
    output logic [13:0]                   h_size_byte, // (LINE_GAP)
    input  logic [8:0]                    frame_index,
    input  logic                          core_ready,
    input  logic                          frame_write_done,
    input  logic                          timeout_err
);

//------------------------------------------------------------------------------
// Local parameters
//------------------------------------------------------------------------------
localparam integer H_SIZE_WIDTH      = 14;
localparam integer FRAME_INDEX_WIDTH = 9;


//------------------------------------------------------------------------------
// DMA Write APB instance
//------------------------------------------------------------------------------
dma_write_apb_reg #(
    .APB_DATA_WIDTH   (APB_DATA_WIDTH   ),
    .APB_ADDR_WIDTH   (APB_ADDR_WIDTH   ),
    .H_SIZE_WIDTH     (H_SIZE_WIDTH     ),
    .FRAME_INDEX_WIDTH(FRAME_INDEX_WIDTH)

) dma_write_apb_reg_ddr4_16gb_inst (
    .pclk             (pclk             ),
    .presetn          (presetn          ),
    .penable          (penable          ),
    .psel             (psel             ),
    .paddr            (paddr            ),
    .pwrite           (pwrite           ),
    .pwdata           (pwdata           ),
    .prdata           (prdata           ),
    .pready           (pready           ),
    .pslverr          (pslverr          ),
    .clear_index      (clear_index      ),
    .h_size_byte      (h_size_byte      ),
    .frame_index      (frame_index      ),
    .core_ready       (core_ready       ),
    .frame_write_done (frame_write_done ),
    .timeout_err      (timeout_err      )
);

endmodule
