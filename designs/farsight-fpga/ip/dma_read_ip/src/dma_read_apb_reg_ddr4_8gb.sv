/*
 * @file      dma_read_apb_reg_ddr4_8gb.sv
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

module dma_read_apb_reg_ddr4_8gb #(
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
    output logic                          clear,
    // APB_REG_ERR_INTF
    input  logic                          dma_timeout_err // CDC from DDR clk
);

dma_read_apb_reg #(
    .APB_DATA_WIDTH    (APB_DATA_WIDTH   ),
    .APB_ADDR_WIDTH    (APB_ADDR_WIDTH   )
) dma_read_apb_reg_ddr4_8gb_inst (
    .pclk            (pclk               ),
    .presetn         (presetn            ),
    .penable         (penable            ),
    .psel            (psel               ),
    .paddr           (paddr              ),
    .pwrite          (pwrite             ),
    .pwdata          (pwdata             ),
    .prdata          (prdata             ),
    .pready          (pready             ),
    .pslverr         (pslverr            ),
    .clear           (clear              ),
    .dma_timeout_err (dma_timeout_err    )
);


endmodule