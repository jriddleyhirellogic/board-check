/*
 * @file      slvs_ec_to_write_ddr.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      07/13/2026
 * 
 * @brief     SLVS EC to Write DDR Top-Level Module. This module receives SLVS-EC
 *            data from the camera and writes it to DDR memory.
 * 
 * @section changelog
 * - 07/13/2026: Steven Knyazher - Initial implementation
 * - 08/18/2026: Steven Knyazher - Added cam_tout camera model for the image
 *                                 metadata exposure time measurement
 * 
 */

module slvs_ec_to_write_ddr #(
    parameter APB_DATA_WIDTH       = 32,
    parameter APB_ADDR_WIDTH       = 32,
    parameter CAM_DATA_WIDTH       = 384,
    parameter DDR4_BURST_LEN_WIDTH = 8,
    parameter DDR4_8GB_ADDR_WIDTH  = 38,
    parameter DDR4_8GB_DATA_WIDTH  = 256,
    parameter DDR4_16GB_ADDR_WIDTH = 39,
    parameter DDR4_16GB_DATA_WIDTH = 512
)(
    input  logic                            pixel_clk,
    input  logic                            pixel_rst_n,
    input  logic                            ddr_clk,
    input  logic                            ddr_rst_n,
    input  logic                            pclk,
    input  logic                            presetn,

    input  logic                            pps_in,
    input  logic                            lvds_trig,

    input  logic                            cam_pwr_status,
    input  logic                            cam_tout,
    output logic                            xtrig,

    input  logic                            penable,
    input  logic                            psel,
    input  logic [APB_ADDR_WIDTH-1:0]       paddr,
    input  logic                            pwrite,
    input  logic [APB_DATA_WIDTH-1:0]       pwdata,
    output logic [APB_DATA_WIDTH-1:0]       prdata,
    output logic                            pready,
    output logic                            pslverr,

    input  logic                            slvs_ec_frame_valid,
    input  logic                            slvs_ec_line_valid,
    input  logic                            slvs_ec_ebd_valid,
    input  logic [CAM_DATA_WIDTH-1:0]       slvs_ec_data_out,

    output logic                            ddr4_8gb_arb_write_req,
    input  logic                            ddr4_8gb_arb_write_ack,
    output logic [DDR4_BURST_LEN_WIDTH-1:0] ddr4_8gb_arb_write_burst_len,
    output logic [DDR4_8GB_ADDR_WIDTH-1:0]  ddr4_8gb_arb_write_start_addr,
    input  logic                            ddr4_8gb_arb_write_done,
    output logic                            ddr4_8gb_arb_write_valid,
    output logic [DDR4_8GB_DATA_WIDTH-1:0]  ddr4_8gb_arb_write_data,

    output logic                            ddr4_16gb_arb_write_req,
    input  logic                            ddr4_16gb_arb_write_ack,
    output logic [DDR4_BURST_LEN_WIDTH-1:0] ddr4_16gb_arb_write_burst_len,
    output logic [DDR4_16GB_ADDR_WIDTH-1:0] ddr4_16gb_arb_write_start_addr,
    input  logic                            ddr4_16gb_arb_write_done,
    output logic                            ddr4_16gb_arb_write_valid,
    output logic [DDR4_16GB_DATA_WIDTH-1:0] ddr4_16gb_arb_write_data
);

//------------------------------------------------------------------------------
// Internal signals
//------------------------------------------------------------------------------
logic                      local_pps_in;
logic                      en_local_pps;
logic                      pps_out;
logic [31:0]               seconds;
logic [31:0]               nanoseconds;

logic                      pps_penable;
logic                      pps_psel;
logic [APB_ADDR_WIDTH-1:0] pps_paddr;
logic                      pps_pwrite;
logic [APB_DATA_WIDTH-1:0] pps_pwdata;
logic [APB_DATA_WIDTH-1:0] pps_prdata;
logic                      pps_pready;
logic                      pps_pslverr;

logic                      capture_start;
logic                      capture_finish;
logic [1:0]                trig_mode;
logic [23:0]               frame_capture_time;
logic [9:0]                frame_capture_amount;

logic                      cam_trig_top_penable;
logic                      cam_trig_top_psel;
logic [APB_ADDR_WIDTH-1:0] cam_trig_top_paddr;
logic                      cam_trig_top_pwrite;
logic [APB_DATA_WIDTH-1:0] cam_trig_top_pwdata;
logic [APB_DATA_WIDTH-1:0] cam_trig_top_prdata;
logic                      cam_trig_top_pready;
logic                      cam_trig_top_pslverr;

logic                      cam_fault_detector_top_penable;
logic                      cam_fault_detector_top_psel;
logic [APB_ADDR_WIDTH-1:0] cam_fault_detector_top_paddr;
logic                      cam_fault_detector_top_pwrite;
logic [APB_DATA_WIDTH-1:0] cam_fault_detector_top_pwdata;
logic [APB_DATA_WIDTH-1:0] cam_fault_detector_top_prdata;
logic                      cam_fault_detector_top_pready;
logic                      cam_fault_detector_top_pslverr;

logic                      cam_flow_sync_frame_valid;
logic                      cam_flow_sync_line_or_ebd_valid;
logic [CAM_DATA_WIDTH-1:0] cam_flow_sync_data_out;

logic                      image_metadata_top_penable;
logic                      image_metadata_top_psel;
logic [APB_ADDR_WIDTH-1:0] image_metadata_top_paddr;
logic                      image_metadata_top_pwrite;
logic [APB_DATA_WIDTH-1:0] image_metadata_top_pwdata;
logic [APB_DATA_WIDTH-1:0] image_metadata_top_prdata;
logic                      image_metadata_top_pready;
logic                      image_metadata_top_pslverr;

logic                      image_metadata_top_frame_valid;
logic                      image_metadata_top_line_valid;
logic [CAM_DATA_WIDTH-1:0] image_metadata_top_data_out;

logic                      cam_mux_top_mux_select;

logic                      cam_mux_top_penable;
logic                      cam_mux_top_psel;
logic [APB_ADDR_WIDTH-1:0] cam_mux_top_paddr;
logic                      cam_mux_top_pwrite;
logic [APB_DATA_WIDTH-1:0] cam_mux_top_pwdata;
logic [APB_DATA_WIDTH-1:0] cam_mux_top_prdata;
logic                      cam_mux_top_pready;
logic                      cam_mux_top_pslverr;

logic                      dma_write_ddr4_8gb_penable;
logic                      dma_write_ddr4_8gb_psel;
logic [APB_ADDR_WIDTH-1:0] dma_write_ddr4_8gb_paddr;
logic                      dma_write_ddr4_8gb_pwrite;
logic [APB_DATA_WIDTH-1:0] dma_write_ddr4_8gb_pwdata;
logic [APB_DATA_WIDTH-1:0] dma_write_ddr4_8gb_prdata;
logic                      dma_write_ddr4_8gb_pready;
logic                      dma_write_ddr4_8gb_pslverr;

logic                      dma_write_ddr4_8gb_clear_index;
logic [13:0]               dma_write_ddr4_8gb_h_size_byte;
logic [7:0]                dma_write_ddr4_8gb_frame_index;
logic                      dma_write_ddr4_8gb_core_ready;
logic                      dma_write_ddr4_8gb_frame_write_done;
logic                      dma_write_ddr4_8gb_timeout_err;

logic                      ddr4_8gb_frame_valid;
logic                      ddr4_8gb_line_valid;
logic [CAM_DATA_WIDTH-1:0] ddr4_8gb_cam_data;

logic                      dma_write_ddr4_16gb_penable;
logic                      dma_write_ddr4_16gb_psel;
logic [APB_ADDR_WIDTH-1:0] dma_write_ddr4_16gb_paddr;
logic                      dma_write_ddr4_16gb_pwrite;
logic [APB_DATA_WIDTH-1:0] dma_write_ddr4_16gb_pwdata;
logic [APB_DATA_WIDTH-1:0] dma_write_ddr4_16gb_prdata;
logic                      dma_write_ddr4_16gb_pready;
logic                      dma_write_ddr4_16gb_pslverr;

logic                      dma_write_ddr4_16gb_clear_index;
logic [13:0]               dma_write_ddr4_16gb_h_size_byte;
logic [8:0]                dma_write_ddr4_16gb_frame_index;
logic                      dma_write_ddr4_16gb_core_ready;
logic                      dma_write_ddr4_16gb_frame_write_done;
logic                      dma_write_ddr4_16gb_timeout_err;

logic                      ddr4_16gb_frame_valid;
logic                      ddr4_16gb_line_valid;
logic [CAM_DATA_WIDTH-1:0] ddr4_16gb_cam_data;

//------------------------------------------------------------------------------
// APB address decoder
//------------------------------------------------------------------------------
localparam logic [APB_ADDR_WIDTH-1:0] PPS_BASE_ADDR                 = 32'h70015000;
localparam logic [APB_ADDR_WIDTH-1:0] CAM_TRIG_BASE_ADDR            = 32'h7000F000;
localparam logic [APB_ADDR_WIDTH-1:0] CAM_FAULT_DETECTOR_BASE_ADDR  = 32'h7001B000;
localparam logic [APB_ADDR_WIDTH-1:0] IMAGE_METADATA_BASE_ADDR      = 32'h7000C000;
localparam logic [APB_ADDR_WIDTH-1:0] CAM_MUX_BASE_ADDR             = 32'h7000B000;
localparam logic [APB_ADDR_WIDTH-1:0] DMA_WRITE_DDR4_8GB_BASE_ADDR  = 32'h70004000;
localparam logic [APB_ADDR_WIDTH-1:0] DMA_WRITE_DDR4_16GB_BASE_ADDR = 32'h70005000;

logic sel_pps;
logic sel_cam_trig;
logic sel_cam_fault_detector;
logic sel_image_metadata;
logic sel_cam_mux;
logic sel_dma_write_ddr4_8gb;
logic sel_dma_write_ddr4_16gb;

assign sel_pps                 = psel && (paddr[APB_ADDR_WIDTH-1:12] == PPS_BASE_ADDR[APB_ADDR_WIDTH-1:12]);
assign sel_cam_trig            = psel && (paddr[APB_ADDR_WIDTH-1:12] == CAM_TRIG_BASE_ADDR[APB_ADDR_WIDTH-1:12]);
assign sel_cam_fault_detector  = psel && (paddr[APB_ADDR_WIDTH-1:12] == CAM_FAULT_DETECTOR_BASE_ADDR[APB_ADDR_WIDTH-1:12]);
assign sel_image_metadata      = psel && (paddr[APB_ADDR_WIDTH-1:12] == IMAGE_METADATA_BASE_ADDR[APB_ADDR_WIDTH-1:12]);
assign sel_cam_mux             = psel && (paddr[APB_ADDR_WIDTH-1:12] == CAM_MUX_BASE_ADDR[APB_ADDR_WIDTH-1:12]);
assign sel_dma_write_ddr4_8gb  = psel && (paddr[APB_ADDR_WIDTH-1:12] == DMA_WRITE_DDR4_8GB_BASE_ADDR[APB_ADDR_WIDTH-1:12]);
assign sel_dma_write_ddr4_16gb = psel && (paddr[APB_ADDR_WIDTH-1:12] == DMA_WRITE_DDR4_16GB_BASE_ADDR[APB_ADDR_WIDTH-1:12]);

// PPS
assign pps_psel    = sel_pps;
assign pps_penable = penable;
assign pps_paddr   = paddr;
assign pps_pwrite  = pwrite;
assign pps_pwdata  = pwdata;

// Cam trig
assign cam_trig_top_psel    = sel_cam_trig;
assign cam_trig_top_penable = penable;
assign cam_trig_top_paddr   = paddr;
assign cam_trig_top_pwrite  = pwrite;
assign cam_trig_top_pwdata  = pwdata;

// Cam fault detector
assign cam_fault_detector_top_psel    = sel_cam_fault_detector;
assign cam_fault_detector_top_penable = penable;
assign cam_fault_detector_top_paddr   = paddr;
assign cam_fault_detector_top_pwrite  = pwrite;
assign cam_fault_detector_top_pwdata  = pwdata;

// Image metadata
assign image_metadata_top_psel    = sel_image_metadata;
assign image_metadata_top_penable = penable;
assign image_metadata_top_paddr   = paddr;
assign image_metadata_top_pwrite  = pwrite;
assign image_metadata_top_pwdata  = pwdata;

// Cam mux
assign cam_mux_top_psel    = sel_cam_mux;
assign cam_mux_top_penable = penable;
assign cam_mux_top_paddr   = paddr;
assign cam_mux_top_pwrite  = pwrite;
assign cam_mux_top_pwdata  = pwdata;

// DMA write DDR4 8GB
assign dma_write_ddr4_8gb_psel    = sel_dma_write_ddr4_8gb;
assign dma_write_ddr4_8gb_penable = penable;
assign dma_write_ddr4_8gb_paddr   = paddr;
assign dma_write_ddr4_8gb_pwrite  = pwrite;
assign dma_write_ddr4_8gb_pwdata  = pwdata;

// DMA write DDR4 16GB
assign dma_write_ddr4_16gb_psel    = sel_dma_write_ddr4_16gb;
assign dma_write_ddr4_16gb_penable = penable;
assign dma_write_ddr4_16gb_paddr   = paddr;
assign dma_write_ddr4_16gb_pwrite  = pwrite;
assign dma_write_ddr4_16gb_pwdata  = pwdata;

// Read-back / response mux
always_comb begin
    unique case (1'b1)
        sel_pps: begin
            prdata  = pps_prdata;
            pready  = pps_pready;
            pslverr = pps_pslverr;
        end

        sel_cam_trig: begin
            prdata  = cam_trig_top_prdata;
            pready  = cam_trig_top_pready;
            pslverr = cam_trig_top_pslverr;
        end
        
        sel_cam_fault_detector: begin
            prdata  = cam_fault_detector_top_prdata;
            pready  = cam_fault_detector_top_pready;
            pslverr = cam_fault_detector_top_pslverr;
        end

        sel_image_metadata: begin
            prdata  = image_metadata_top_prdata;
            pready  = image_metadata_top_pready;
            pslverr = image_metadata_top_pslverr;
        end

        sel_cam_mux: begin
            prdata  = cam_mux_top_prdata;
            pready  = cam_mux_top_pready;
            pslverr = cam_mux_top_pslverr;
        end

        sel_dma_write_ddr4_8gb: begin
            prdata  = dma_write_ddr4_8gb_prdata;
            pready  = dma_write_ddr4_8gb_pready;
            pslverr = dma_write_ddr4_8gb_pslverr;
        end
        
        sel_dma_write_ddr4_16gb: begin
            prdata  = dma_write_ddr4_16gb_prdata;
            pready  = dma_write_ddr4_16gb_pready;
            pslverr = dma_write_ddr4_16gb_pslverr;
        end

        default: begin
            prdata  = '0;
            pready  = 1'b1;
            pslverr = 1'b0;
        end
    endcase
end

//------------------------------------------------------------------------------
// PPS generator instance
//------------------------------------------------------------------------------
pps_generator #(
    .CLOCK_FREQ_MHZ (50),
    .POLARITY       (1 )
) pps_generator_inst (
    .clk     (pclk        ),
    .rst_n   (presetn     ),
    .pps_out (local_pps_in)
);

//------------------------------------------------------------------------------
// PPS mux instance
//------------------------------------------------------------------------------
pps_mux pps_mux_inst (
    .en_local_pps (en_local_pps),
    .local_pps_in (local_pps_in),
    .extrn_pps_in (pps_in      ),
    .pps_out      (pps_out     )
);

//------------------------------------------------------------------------------
// PPS instance
//------------------------------------------------------------------------------
pps #(
    .CLOCK_PER      (20000        ), // sim: 1 "second" = 1 ms (DEFAULT_PPS_PERIOD = NS_PER_SEC/CLOCK_PER = 50000 ticks) so seconds increments on the sped-up pps_in
    .APB_DATA_WIDTH (32           ),
    .APB_ADDR_WIDTH (32           )
) pps_inst (
    .pclk         (pclk        ),
    .presetn      (presetn     ),
    .penable      (pps_penable ),
    .psel         (pps_psel    ),
    .paddr        (pps_paddr   ),
    .pwrite       (pps_pwrite  ),
    .pwdata       (pps_pwdata  ),
    .prdata       (pps_prdata  ),
    .pready       (pps_pready  ),
    .pslverr      (pps_pslverr ),
    .pps_in       (pps_out     ),
    .pps_out      (/*NC*/      ),
    .en_local_pps (en_local_pps),
    .seconds      (seconds     ),
    .nanoseconds  (nanoseconds )
);

//------------------------------------------------------------------------------
// Cam trig top instance
//------------------------------------------------------------------------------
cam_trig_top #(
    .APB_DATA_WIDTH (32),
    .APB_ADDR_WIDTH (32),
    .CLOCK_FREQ_MHZ (50)
) cam_trig_top_inst (
    .pclk                 (pclk                ),
    .presetn              (presetn             ),
    .penable              (cam_trig_top_penable),
    .psel                 (cam_trig_top_psel   ),
    .paddr                (cam_trig_top_paddr  ),
    .pwrite               (cam_trig_top_pwrite ),
    .pwdata               (cam_trig_top_pwdata ),
    .prdata               (cam_trig_top_prdata ),
    .pready               (cam_trig_top_pready ),
    .pslverr              (cam_trig_top_pslverr),
    .xtrig_clk            (pclk                ),
    .xtrig_rst_n          (presetn             ),
    .start                (capture_start       ),
    .finish               (capture_finish      ),
    .xtrig_int            (/*NC*/              ),
    .en                   (cam_pwr_status      ),
    .rtc_sec              (seconds             ),
    .rtc_nsec             (nanoseconds         ),
    .lvds_start           (lvds_trig           ),
    .xtrig                (xtrig               ),
    .xtrig_src_sel        (trig_mode           ),
    .frame_capture_time   (frame_capture_time  ),
    .frame_capture_amount (frame_capture_amount)
);

//------------------------------------------------------------------------------
// Cam fault detector top instance
//------------------------------------------------------------------------------
cam_fault_detector_top #(
    .APB_DATA_WIDTH (32  ),
    .APB_ADDR_WIDTH (32  ),
    .CLOCK_FREQ_MHZ (50  ),
    .TIMEOUT_US     (1000)
) cam_fault_detector_top_inst (
    .pclk                 (pclk                          ),
    .presetn              (presetn                       ),
    .penable              (cam_fault_detector_top_penable),
    .psel                 (cam_fault_detector_top_psel   ),
    .paddr                (cam_fault_detector_top_paddr  ),
    .pwrite               (cam_fault_detector_top_pwrite ),
    .pwdata               (cam_fault_detector_top_pwdata ),
    .prdata               (cam_fault_detector_top_prdata ),
    .pready               (cam_fault_detector_top_pready ),
    .pslverr              (cam_fault_detector_top_pslverr),
    .xtrig_clk            (pclk                          ),
    .xtrig_rst_n          (presetn                       ),
    .xtrig                (xtrig                         ),
    .frame_valid          (slvs_ec_frame_valid           ),
    .capture_start        (capture_start                 ),
    .capture_finish       (capture_finish                ),
    .cam_pwr_status       (cam_pwr_status                )
);

//------------------------------------------------------------------------------
// Cam flow sync instance
//------------------------------------------------------------------------------
cam_flow_sync #(
    .DATA_WIDTH    (384),
    .EXTEND_CYCLES (10 )
) cam_flow_sync_inst (
    .clk                   (pixel_clk                      ),
    .rst_n                 (pixel_rst_n                    ),
    .frame_valid_in        (slvs_ec_frame_valid            ),
    .line_valid_in         (slvs_ec_line_valid             ),
    .ebd_valid_in          (slvs_ec_ebd_valid              ),
    .data_in               (slvs_ec_data_out               ),
    .frame_valid_out       (cam_flow_sync_frame_valid      ),
    .line_or_ebd_valid_out (cam_flow_sync_line_or_ebd_valid),
    .data_out              (cam_flow_sync_data_out         )
);

//------------------------------------------------------------------------------
// Image metadata top instance
//------------------------------------------------------------------------------
image_metadata_top #(
    .APB_DATA_WIDTH              (32 ),
    .APB_ADDR_WIDTH              (32 ),
    .CAM_DATA_WIDTH              (384),
    .METADATA_WIDTH              (640),
    .CLOCK_FREQ_MHZ              (50 ),
    .EXPO_TIME_WIDTH             (22 ),
    .FRAME_CAPTURE_TIME_WIDTH    (24 ),
    .FRAME_CAPTURE_AMOUNT_WIDTH  (10 ),
    .DDR4_8GB_FRAME_INDEX_WIDTH  (8  ),
    .DDR4_16GB_FRAME_INDEX_WIDTH (9  )
) image_metadata_top_inst (
    .pixel_clk             (pixel_clk                      ),
    .pixel_rst_n           (pixel_rst_n                    ),
    .pclk                  (pclk                           ),
    .presetn               (presetn                        ),
    .penable               (image_metadata_top_penable     ),
    .psel                  (image_metadata_top_psel        ),
    .paddr                 (image_metadata_top_paddr       ),
    .pwrite                (image_metadata_top_pwrite      ),
    .pwdata                (image_metadata_top_pwdata      ),
    .prdata                (image_metadata_top_prdata      ),
    .pready                (image_metadata_top_pready      ),
    .pslverr               (image_metadata_top_pslverr     ),
    .timestamp_sec         (seconds                        ),
    .timestamp_nsec        (nanoseconds                    ),
    .trig_mode             (trig_mode                      ),
    .cam_tout              (cam_tout                       ),
    .frame_capture_time    (frame_capture_time             ),
    .frame_capture_amount  (frame_capture_amount           ),
    .cam_mux_select        (cam_mux_top_mux_select         ),
    .ddr4_8gb_frame_index  (dma_write_ddr4_8gb_frame_index ),
    .ddr4_16gb_frame_index (dma_write_ddr4_16gb_frame_index),
    .frame_valid_in        (cam_flow_sync_frame_valid      ),
    .line_valid_in         (cam_flow_sync_line_or_ebd_valid),
    .cam_data_in           (cam_flow_sync_data_out         ),
    .frame_valid_out       (image_metadata_top_frame_valid ),
    .line_valid_out        (image_metadata_top_line_valid  ),
    .cam_data_out          (image_metadata_top_data_out    )
);

//------------------------------------------------------------------------------
// Cam mux top instance
//------------------------------------------------------------------------------
cam_mux_top #(
    .APB_DATA_WIDTH (32 ),
    .APB_ADDR_WIDTH (32 ),
    .DATA_WIDTH     (384)
) cam_mux_top_inst (
    .pclk                      (pclk                          ),
    .presetn                   (presetn                       ),
    .penable                   (cam_mux_top_penable           ),
    .psel                      (cam_mux_top_psel              ),
    .paddr                     (cam_mux_top_paddr             ),
    .pwrite                    (cam_mux_top_pwrite            ),
    .pwdata                    (cam_mux_top_pwdata            ),
    .prdata                    (cam_mux_top_prdata            ),
    .pready                    (cam_mux_top_pready            ),
    .pslverr                   (cam_mux_top_pslverr           ),
    .pixel_clk                 (pixel_clk                     ),
    .pixel_rst_n               (pixel_rst_n                   ),
    .frame_valid_in            (image_metadata_top_frame_valid),
    .line_valid_in             (image_metadata_top_line_valid ),
    .cam_data_in               (image_metadata_top_data_out   ),
    .mux_enable                (/*NC*/                        ),
    .mux_select                (cam_mux_top_mux_select        ),
    .ddr4_8gb_frame_valid_out  (ddr4_8gb_frame_valid          ),
    .ddr4_8gb_line_valid_out   (ddr4_8gb_line_valid           ),
    .ddr4_8gb_cam_data_out     (ddr4_8gb_cam_data             ),
    .ddr4_16gb_frame_valid_out (ddr4_16gb_frame_valid         ),
    .ddr4_16gb_line_valid_out  (ddr4_16gb_line_valid          ),
    .ddr4_16gb_cam_data_out    (ddr4_16gb_cam_data            )
);

//------------------------------------------------------------------------------
// DMA write DDR4 8GB instance
//------------------------------------------------------------------------------
dma_write_ddr4_8gb #(
    .CLOCK_FREQ_MHZ (150  ),
    .TIMEOUT_USEC   (10000)
) dma_write_ddr4_8gb_inst (
    .pixel_clk                (pixel_clk                          ),
    .pixel_rst_n              (pixel_rst_n                        ),
    .ddr_clk                  (ddr_clk                            ),
    .ddr_rst_n                (ddr_rst_n                          ),
    .cam_frame_valid          (ddr4_8gb_frame_valid               ),
    .cam_line_valid           (ddr4_8gb_line_valid                ),
    .cam_data_in              (ddr4_8gb_cam_data                  ),
    .apb_reg_clear_index      (dma_write_ddr4_8gb_clear_index     ),
    .apb_reg_h_size_byte      (dma_write_ddr4_8gb_h_size_byte     ),
    .apb_reg_frame_index      (dma_write_ddr4_8gb_frame_index     ),
    .apb_reg_core_ready       (dma_write_ddr4_8gb_core_ready      ),
    .apb_reg_frame_write_done (dma_write_ddr4_8gb_frame_write_done),
    .apb_reg_timeout_err      (dma_write_ddr4_8gb_timeout_err     ),
    .arb_write_req            (ddr4_8gb_arb_write_req             ),
    .arb_write_ack            (ddr4_8gb_arb_write_ack             ),
    .arb_write_burst_len      (ddr4_8gb_arb_write_burst_len       ),
    .arb_write_start_addr     (ddr4_8gb_arb_write_start_addr      ),
    .arb_write_done           (ddr4_8gb_arb_write_done            ),
    .arb_write_valid          (ddr4_8gb_arb_write_valid           ),
    .arb_write_data           (ddr4_8gb_arb_write_data            )
);

//------------------------------------------------------------------------------
// DMA write APB reg DDR4 8GB instance
//------------------------------------------------------------------------------
dma_write_apb_reg_ddr4_8gb #(
    .APB_DATA_WIDTH (32),
    .APB_ADDR_WIDTH (32)
) dma_write_apb_reg_ddr4_8gb_inst (
    .pclk             (pclk                               ),
    .presetn          (presetn                            ),
    .penable          (dma_write_ddr4_8gb_penable         ),
    .psel             (dma_write_ddr4_8gb_psel            ),
    .paddr            (dma_write_ddr4_8gb_paddr           ),
    .pwrite           (dma_write_ddr4_8gb_pwrite          ),
    .pwdata           (dma_write_ddr4_8gb_pwdata          ),
    .prdata           (dma_write_ddr4_8gb_prdata          ),
    .pready           (dma_write_ddr4_8gb_pready          ),
    .pslverr          (dma_write_ddr4_8gb_pslverr         ),
    .clear_index      (dma_write_ddr4_8gb_clear_index     ),
    .h_size_byte      (dma_write_ddr4_8gb_h_size_byte     ),
    .frame_index      (dma_write_ddr4_8gb_frame_index     ),
    .core_ready       (dma_write_ddr4_8gb_core_ready      ),
    .frame_write_done (dma_write_ddr4_8gb_frame_write_done),
    .timeout_err      (dma_write_ddr4_8gb_timeout_err     )
);

//------------------------------------------------------------------------------
// DMA write DDR4 16GB instance
//------------------------------------------------------------------------------
dma_write_ddr4_16gb #(
    .CLOCK_FREQ_MHZ (150  ),
    .TIMEOUT_USEC   (10000)
) dma_write_ddr4_16gb_inst (
    .pixel_clk                (pixel_clk                           ),
    .pixel_rst_n              (pixel_rst_n                         ),
    .ddr_clk                  (ddr_clk                             ),
    .ddr_rst_n                (ddr_rst_n                           ),
    .cam_frame_valid          (ddr4_16gb_frame_valid               ),
    .cam_line_valid           (ddr4_16gb_line_valid                ),
    .cam_data_in              (ddr4_16gb_cam_data                  ),
    .apb_reg_clear_index      (dma_write_ddr4_16gb_clear_index     ),
    .apb_reg_h_size_byte      (dma_write_ddr4_16gb_h_size_byte     ),
    .apb_reg_frame_index      (dma_write_ddr4_16gb_frame_index     ),
    .apb_reg_core_ready       (dma_write_ddr4_16gb_core_ready      ),
    .apb_reg_frame_write_done (dma_write_ddr4_16gb_frame_write_done),
    .apb_reg_timeout_err      (dma_write_ddr4_16gb_timeout_err     ),
    .arb_write_req            (ddr4_16gb_arb_write_req             ),
    .arb_write_ack            (ddr4_16gb_arb_write_ack             ),
    .arb_write_burst_len      (ddr4_16gb_arb_write_burst_len       ),
    .arb_write_start_addr     (ddr4_16gb_arb_write_start_addr      ),
    .arb_write_done           (ddr4_16gb_arb_write_done            ),
    .arb_write_valid          (ddr4_16gb_arb_write_valid           ),
    .arb_write_data           (ddr4_16gb_arb_write_data            )
);

//------------------------------------------------------------------------------
// DMA write APB reg DDR4 16GB instance
//------------------------------------------------------------------------------
dma_write_apb_reg_ddr4_16gb #(
    .APB_DATA_WIDTH (32),
    .APB_ADDR_WIDTH (32)
) dma_write_apb_reg_ddr4_16gb_inst (
    .pclk             (pclk                                ),
    .presetn          (presetn                             ),
    .penable          (dma_write_ddr4_16gb_penable         ),
    .psel             (dma_write_ddr4_16gb_psel            ),
    .paddr            (dma_write_ddr4_16gb_paddr           ),
    .pwrite           (dma_write_ddr4_16gb_pwrite          ),
    .pwdata           (dma_write_ddr4_16gb_pwdata          ),
    .prdata           (dma_write_ddr4_16gb_prdata          ),
    .pready           (dma_write_ddr4_16gb_pready          ),
    .pslverr          (dma_write_ddr4_16gb_pslverr         ),
    .clear_index      (dma_write_ddr4_16gb_clear_index     ),
    .h_size_byte      (dma_write_ddr4_16gb_h_size_byte     ),
    .frame_index      (dma_write_ddr4_16gb_frame_index     ),
    .core_ready       (dma_write_ddr4_16gb_core_ready      ),
    .frame_write_done (dma_write_ddr4_16gb_frame_write_done),
    .timeout_err      (dma_write_ddr4_16gb_timeout_err     )
);

endmodule