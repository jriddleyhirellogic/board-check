/*
 * @file      image_metadata_top.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      01/16/2026
 *
 * @brief     Top module of image metadata. It encapsulates APB register
 *            module and image metadata module as a top level.
 *
 * @section changelog
 * - 01/16/2026: Steven Knyazher - Initial implementation
 * - 02/03/2026: Saba Janamian- Updated based on the new changes in submodules
 * - 08/18/2026: Steven Knyazher - Replaced xtrig_low_time with expo_time
 *
 */

module image_metadata_top #(
    parameter integer APB_DATA_WIDTH              = 32,
    parameter integer APB_ADDR_WIDTH              = 32,
    parameter integer CAM_DATA_WIDTH              = 384,
    parameter integer METADATA_WIDTH              = 640,
    parameter integer CLOCK_FREQ_MHZ              = 50,
    parameter integer EXPO_TIME_WIDTH             = 22,
    parameter integer FRAME_CAPTURE_TIME_WIDTH    = 24,
    parameter integer FRAME_CAPTURE_AMOUNT_WIDTH  = 10,
    parameter integer DDR4_8GB_FRAME_INDEX_WIDTH  = 8,
    parameter integer DDR4_16GB_FRAME_INDEX_WIDTH = 9
)(
     // Input Pixel clock
    input  logic                                  pixel_clk,   // SLVSEC clock
    input  logic                                  pixel_rst_n, // SLVSEC resetn

    // APB Slave interface
    input  logic                                  pclk,     // APB clock
    input  logic                                  presetn,  // APB resetn
    input  logic                                  penable,  // APB enable
    input  logic                                  psel,     // APB periph select
    input  logic [APB_ADDR_WIDTH-1:0]             paddr,    // APB address bus
    input  logic                                  pwrite,   // APB write req
    input  logic [APB_DATA_WIDTH-1:0]             pwdata,   // APB write data
    output logic [APB_DATA_WIDTH-1:0]             prdata,   // APB read data
    output logic                                  pready,   // APB ready signal
    output logic                                  pslverr,  // APB error signal

    // Timestamp
    input logic [31:0]                            timestamp_sec,
    input logic [31:0]                            timestamp_nsec,

    // Trigger info (APB clock domain)
    input logic [1:0]                             trig_mode,
    input logic                                   cam_tout,
    input logic [FRAME_CAPTURE_TIME_WIDTH-1:0]    frame_capture_time,
    input logic [FRAME_CAPTURE_AMOUNT_WIDTH-1:0]  frame_capture_amount,

    // DDR4 buffer space index
    input logic                                   cam_mux_select,
    input logic [DDR4_8GB_FRAME_INDEX_WIDTH-1:0]  ddr4_8gb_frame_index,
    input logic [DDR4_16GB_FRAME_INDEX_WIDTH-1:0] ddr4_16gb_frame_index,

    // Cam input
    input  logic                                  frame_valid_in,
    input  logic                                  line_valid_in,
    input  logic [CAM_DATA_WIDTH-1:0]             cam_data_in,

    // Cam output
    output logic                                  frame_valid_out,
    output logic                                  line_valid_out,
    output logic [CAM_DATA_WIDTH-1:0]             cam_data_out
);

//------------------------------------------------------------------------------
// Internal Signals
//------------------------------------------------------------------------------
logic [METADATA_WIDTH-1:0]         net_metadata;
logic                              net_expo_time_valid;


//------------------------------------------------------------------------------
// Instances
//------------------------------------------------------------------------------
image_metadata #(
    .CAM_DATA_WIDTH             (CAM_DATA_WIDTH            ),
    .METADATA_WIDTH             (METADATA_WIDTH            )
) image_metadata_inst (
    .pclk                       (pclk                      ),
    .presetn                    (presetn                   ),
    .pixel_clk                  (pixel_clk                 ),
    .pixel_rst_n                (pixel_rst_n               ),
    .metadata_in                (net_metadata              ),
    .expo_time_valid            (net_expo_time_valid       ),
    .frame_valid_in             (frame_valid_in            ),
    .line_valid_in              (line_valid_in             ),
    .cam_data_in                (cam_data_in               ),
    .frame_valid_out            (frame_valid_out           ),
    .line_valid_out             (line_valid_out            ),
    .cam_data_out               (cam_data_out              )
);

image_metadata_apb_reg #(
    .APB_DATA_WIDTH             (APB_DATA_WIDTH            ),
    .APB_ADDR_WIDTH             (APB_ADDR_WIDTH            ),
    .METADATA_WIDTH             (METADATA_WIDTH            ),
    .CLOCK_FREQ_MHZ             (CLOCK_FREQ_MHZ            ),
    .EXPO_TIME_WIDTH            (EXPO_TIME_WIDTH           ),
    .FRAME_CAPTURE_TIME_WIDTH   (FRAME_CAPTURE_TIME_WIDTH  ),
    .FRAME_CAPTURE_AMOUNT_WIDTH (FRAME_CAPTURE_AMOUNT_WIDTH),
    .DDR4_8GB_FRAME_INDEX_WIDTH (DDR4_8GB_FRAME_INDEX_WIDTH),
    .DDR4_16GB_FRAME_INDEX_WIDTH(DDR4_16GB_FRAME_INDEX_WIDTH)
) image_metadata_apb_reg_inst (
    .pclk                       (pclk                      ),
    .presetn                    (presetn                   ),
    .penable                    (penable                   ),
    .psel                       (psel                      ),
    .paddr                      (paddr                     ),
    .pwrite                     (pwrite                    ),
    .pwdata                     (pwdata                    ),
    .prdata                     (prdata                    ),
    .pready                     (pready                    ),
    .pslverr                    (pslverr                   ),
    .timestamp_sec              (timestamp_sec             ),
    .timestamp_nsec             (timestamp_nsec            ),
    .trig_mode                  (trig_mode                 ),
    .cam_tout                   (cam_tout                  ),
    .frame_capture_time         (frame_capture_time        ),
    .frame_capture_amount       (frame_capture_amount      ),
    .cam_mux_select             (cam_mux_select            ),
    .ddr4_8gb_frame_index       (ddr4_8gb_frame_index      ),
    .ddr4_16gb_frame_index      (ddr4_16gb_frame_index     ),
    .expo_time_valid            (net_expo_time_valid       ),
    .metadata_out               (net_metadata              )
);

endmodule