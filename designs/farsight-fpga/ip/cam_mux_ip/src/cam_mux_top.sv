/*
 * @file      cam_mux_top.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      04/30/2026
 *
 * @brief     Top module of camera MUX module. It encapsulates APB register
 *            module and camera MUX module as a top level.
 *
 * @section changelog
 * - 04/30/2026: Steven Knyazher - Initial implementation
 *
 */

module cam_mux_top #(
    parameter APB_DATA_WIDTH = 32,
    parameter APB_ADDR_WIDTH = 32,
    parameter DATA_WIDTH     = 384
)(
    // APB Slave interface
    input  logic                      pclk,     // APB clock
    input  logic                      presetn,  // APB resetn
    input  logic                      penable,  // APB enable
    input  logic                      psel,     // APB periph select
    input  logic [APB_ADDR_WIDTH-1:0] paddr,    // APB address bus
    input  logic                      pwrite,   // APB write req
    input  logic [APB_DATA_WIDTH-1:0] pwdata,   // APB write data
    output logic [APB_DATA_WIDTH-1:0] prdata,   // APB read data
    output logic                      pready,   // APB ready signal
    output logic                      pslverr,  // APB error signal

    // Clock and Reset
    input  logic                      pixel_clk,
    input  logic                      pixel_rst_n,

    // Cam input interface
    input  logic                      frame_valid_in,
    input  logic                      line_valid_in,
    input  logic [DATA_WIDTH-1:0]     cam_data_in,

    // Cam status
    output logic                      mux_enable, // Active high
    output logic                      mux_select, // 0 for 8GB, 1 for 16 GB

    // Cam to DDR4 8GB
    output logic                      ddr4_8gb_frame_valid_out,
    output logic                      ddr4_8gb_line_valid_out,
    output logic [DATA_WIDTH-1:0]     ddr4_8gb_cam_data_out,

    // Cam to DDR4 16GB
    output logic                      ddr4_16gb_frame_valid_out,
    output logic                      ddr4_16gb_line_valid_out,
    output logic [DATA_WIDTH-1:0]     ddr4_16gb_cam_data_out
);

//------------------------------------------------------------------------------
// Internal signals
//------------------------------------------------------------------------------
logic mux_clear;
logic mux_clear_ack;
logic ddr4_16gb_full;
logic ddr4_8gb_full;

//------------------------------------------------------------------------------
// Instances
//------------------------------------------------------------------------------
cam_mux_apb_reg #(
    .APB_DATA_WIDTH       (APB_DATA_WIDTH      ),
    .APB_ADDR_WIDTH       (APB_ADDR_WIDTH      )
) cam_mux_apb_reg_inst (
    .pclk                 (pclk                ),
    .presetn              (presetn             ),
    .penable              (penable             ),
    .psel                 (psel                ),
    .paddr                (paddr               ),
    .pwrite               (pwrite              ),
    .pwdata               (pwdata              ),
    .prdata               (prdata              ),
    .pready               (pready              ),
    .pslverr              (pslverr             ),
    .mux_clear            (mux_clear           ),
    .mux_enable           (mux_enable          ),
    .mux_select           (mux_select          ),
    .ddr4_16gb_full       (ddr4_16gb_full      ),
    .ddr4_8gb_full        (ddr4_8gb_full       ),
    .mux_clear_ack        (mux_clear_ack       )
);

cam_mux #(
    .DATA_WIDTH                (DATA_WIDTH               )
) cam_mux_inst ( 
    .pixel_clk                 (pixel_clk                ),
    .pixel_rst_n               (pixel_rst_n              ),
    .frame_valid_in            (frame_valid_in           ),
    .line_valid_in             (line_valid_in            ),
    .cam_data_in               (cam_data_in              ),
    .mux_clear                 (mux_clear                ),
    .mux_enable                (mux_enable               ),
    .mux_select                (mux_select               ),
    .ddr4_16gb_full            (ddr4_16gb_full           ),
    .ddr4_8gb_full             (ddr4_8gb_full            ),
    .mux_clear_ack             (mux_clear_ack            ),
    .ddr4_8gb_frame_valid_out  (ddr4_8gb_frame_valid_out ),
    .ddr4_8gb_line_valid_out   (ddr4_8gb_line_valid_out  ),
    .ddr4_8gb_cam_data_out     (ddr4_8gb_cam_data_out    ),
    .ddr4_16gb_frame_valid_out (ddr4_16gb_frame_valid_out),
    .ddr4_16gb_line_valid_out  (ddr4_16gb_line_valid_out ),
    .ddr4_16gb_cam_data_out    (ddr4_16gb_cam_data_out   )
);

endmodule
