/*
 * @file      udp_mux.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      10/03/2025
 *
 * @brief     UDP to DMA Mux. This design uses multiple DDR banks (8GB and 16GB)
 *            This mux allows to select which DDR4 Bank data should flow
 *            through to the UDP controller.
 *
 * @section changelog
 * - 10/03/2025: Saba Janamian - Initial implementation
 *
 */

module udp_mux(
    input logic [1:0] mux_sel,

    // -------------------------------------------------------------------------
    // Image frame from DDR4 8GB
    // -------------------------------------------------------------------------
    input  logic [15:0]   ddr4_8gb_img_frame_udp_pyl_size,
    output logic          ddr4_8gb_img_frame_udp_pyl_size_ready,
    input  logic          ddr4_8gb_img_frame_udp_pyl_size_valid,

    // UDP Payload AXIS interface
    input  logic         ddr4_8gb_img_frame_s_udp_pyl_axis_tvalid,
    output logic         ddr4_8gb_img_frame_s_udp_pyl_axis_tready,
    input  logic [31:0]  ddr4_8gb_img_frame_s_udp_pyl_axis_tdata,
    input  logic [3:0]   ddr4_8gb_img_frame_s_udp_pyl_axis_tkeep,
    input  logic         ddr4_8gb_img_frame_s_udp_pyl_axis_tlast,

    output logic         ddr4_8gb_img_frame_eof_ack,
    output logic         ddr4_8gb_img_frame_pyl_acpt,
    output logic         ddr4_8gb_img_frame_core_busy,
    input  logic         ddr4_8gb_img_frame_sof_req,

    // -------------------------------------------------------------------------
    // Image frame from DDR4 16GB
    // -------------------------------------------------------------------------
    input  logic [15:0]  ddr4_16gb_img_frame_udp_pyl_size,
    output logic         ddr4_16gb_img_frame_udp_pyl_size_ready,
    input  logic         ddr4_16gb_img_frame_udp_pyl_size_valid,

    // UDP Payload AXIS interface
    input  logic         ddr4_16gb_img_frame_s_udp_pyl_axis_tvalid,
    output logic         ddr4_16gb_img_frame_s_udp_pyl_axis_tready,
    input  logic [31:0]  ddr4_16gb_img_frame_s_udp_pyl_axis_tdata,
    input  logic [3:0]   ddr4_16gb_img_frame_s_udp_pyl_axis_tkeep,
    input  logic         ddr4_16gb_img_frame_s_udp_pyl_axis_tlast,

    output logic         ddr4_16gb_img_frame_eof_ack,
    output logic         ddr4_16gb_img_frame_pyl_acpt,
    output logic         ddr4_16gb_img_frame_core_busy,
    input  logic         ddr4_16gb_img_frame_sof_req,

    // -------------------------------------------------------------------------
    // UDP out
    // -------------------------------------------------------------------------

    // UDP Payload size
    output  logic        udp_pyl_size_valid,
    input   logic        udp_pyl_size_ready,
    output  logic [15:0] udp_pyl_size,

    // UDP Payload AXIS interface
    output  logic        m_udp_pyl_axis_tvalid,
    input   logic        m_udp_pyl_axis_tready,
    output  logic [31:0] m_udp_pyl_axis_tdata,
    output  logic [3:0]  m_udp_pyl_axis_tkeep,
    output  logic        m_udp_pyl_axis_tlast,

    input logic          eof_ack,
    input logic          pyl_acpt,
    input logic          core_busy,
    output logic         sof_req
);

//------------------------------------------------------------------------------
// Local parameters
//------------------------------------------------------------------------------
localparam logic [1:0] DISABLED          = 2'b00;
localparam logic [1:0] UDP_FOR_DDR4_8GB  = 2'b01;
localparam logic [1:0] UDP_FOR_DDR4_16GB = 2'b10;

//------------------------------------------------------------------------------
// MUX
//------------------------------------------------------------------------------
always_comb begin
    case(mux_sel)

        DISABLED: begin
            // Make all out going to udp_tx zero
            udp_pyl_size_valid    = 'b0;
            udp_pyl_size          = 'b0;
            m_udp_pyl_axis_tvalid = 'b0;
            m_udp_pyl_axis_tdata  = 'b0;
            m_udp_pyl_axis_tkeep  = 'b0;
            m_udp_pyl_axis_tlast  = 'b0;
            sof_req               = 'b0;

            // From udp_tx ip to dma_ddr4_8gb_to_udp_ctrl ip
            ddr4_8gb_img_frame_udp_pyl_size_ready     = 'b0;
            ddr4_8gb_img_frame_s_udp_pyl_axis_tready  = 'b0;
            ddr4_8gb_img_frame_eof_ack                = 'b0;
            ddr4_8gb_img_frame_pyl_acpt               = 'b0;
            ddr4_8gb_img_frame_core_busy              = 'b0;

            // From udp_tx ip to dma_ddr4_16gb_to_udp_ctrl ip
            ddr4_16gb_img_frame_udp_pyl_size_ready    = 'b0;
            ddr4_16gb_img_frame_s_udp_pyl_axis_tready = 'b0;
            ddr4_16gb_img_frame_eof_ack               = 'b0;
            ddr4_16gb_img_frame_pyl_acpt              = 'b0;
            ddr4_16gb_img_frame_core_busy             = 'b0;
        end

        UDP_FOR_DDR4_8GB: begin
            // From dma_ddr4_8gb_to_udp_ctrl to udp_tx
            udp_pyl_size_valid    = ddr4_8gb_img_frame_udp_pyl_size_valid;
            udp_pyl_size          = ddr4_8gb_img_frame_udp_pyl_size;
            m_udp_pyl_axis_tvalid = ddr4_8gb_img_frame_s_udp_pyl_axis_tvalid;
            m_udp_pyl_axis_tdata  = ddr4_8gb_img_frame_s_udp_pyl_axis_tdata;
            m_udp_pyl_axis_tkeep  = ddr4_8gb_img_frame_s_udp_pyl_axis_tkeep;
            m_udp_pyl_axis_tlast  = ddr4_8gb_img_frame_s_udp_pyl_axis_tlast;
            sof_req               = ddr4_8gb_img_frame_sof_req;

            // From udp_tx ip to dma_ddr4_8gb_to_udp_ctrl ip
            ddr4_8gb_img_frame_udp_pyl_size_ready     = udp_pyl_size_ready;
            ddr4_8gb_img_frame_s_udp_pyl_axis_tready  = m_udp_pyl_axis_tready;
            ddr4_8gb_img_frame_eof_ack                = eof_ack;
            ddr4_8gb_img_frame_pyl_acpt               = pyl_acpt;
            ddr4_8gb_img_frame_core_busy              = core_busy;

            // From udp_tx ip to dma_ddr4_16gb_to_udp_ctrl ip
            ddr4_16gb_img_frame_udp_pyl_size_ready    = 'b0;
            ddr4_16gb_img_frame_s_udp_pyl_axis_tready = 'b0;
            ddr4_16gb_img_frame_eof_ack               = 'b0;
            ddr4_16gb_img_frame_pyl_acpt              = 'b0;
            ddr4_16gb_img_frame_core_busy             = 'b0;
        end

        UDP_FOR_DDR4_16GB: begin
            // From dma_ddr4_16gb_to_udp_ctrl to udp_tx
            udp_pyl_size_valid    = ddr4_16gb_img_frame_udp_pyl_size_valid;
            udp_pyl_size          = ddr4_16gb_img_frame_udp_pyl_size;
            m_udp_pyl_axis_tvalid = ddr4_16gb_img_frame_s_udp_pyl_axis_tvalid;
            m_udp_pyl_axis_tdata  = ddr4_16gb_img_frame_s_udp_pyl_axis_tdata;
            m_udp_pyl_axis_tkeep  = ddr4_16gb_img_frame_s_udp_pyl_axis_tkeep;
            m_udp_pyl_axis_tlast  = ddr4_16gb_img_frame_s_udp_pyl_axis_tlast;
            sof_req               = ddr4_16gb_img_frame_sof_req;

            // From udp_tx ip to dma_ddr4_8gb_to_udp_ctrl ip
            ddr4_8gb_img_frame_udp_pyl_size_ready    = 'b0;
            ddr4_8gb_img_frame_s_udp_pyl_axis_tready = 'b0;
            ddr4_8gb_img_frame_eof_ack               = 'b0;
            ddr4_8gb_img_frame_pyl_acpt              = 'b0;
            ddr4_8gb_img_frame_core_busy             = 'b0;

            // From udp_tx ip to dma_ddr4_16gb_to_udp_ctrl ip
            ddr4_16gb_img_frame_udp_pyl_size_ready    = udp_pyl_size_ready;
            ddr4_16gb_img_frame_s_udp_pyl_axis_tready = m_udp_pyl_axis_tready;
            ddr4_16gb_img_frame_eof_ack               = eof_ack;
            ddr4_16gb_img_frame_pyl_acpt              = pyl_acpt;
            ddr4_16gb_img_frame_core_busy             = core_busy;
        end

        default: begin
            // Make all out going to udp_tx zero
            udp_pyl_size_valid    = 'b0;
            udp_pyl_size          = 'b0;
            m_udp_pyl_axis_tvalid = 'b0;
            m_udp_pyl_axis_tdata  = 'b0;
            m_udp_pyl_axis_tkeep  = 'b0;
            m_udp_pyl_axis_tlast  = 'b0;
            sof_req               = 'b0;

            // From udp_tx ip to dma_ddr4_8gb_to_udp_ctrl ip
            ddr4_8gb_img_frame_udp_pyl_size_ready     = 'b0;
            ddr4_8gb_img_frame_s_udp_pyl_axis_tready  = 'b0;
            ddr4_8gb_img_frame_eof_ack                = 'b0;
            ddr4_8gb_img_frame_pyl_acpt               = 'b0;
            ddr4_8gb_img_frame_core_busy              = 'b0;

            // From udp_tx ip to dma_ddr4_16gb_to_udp_ctrl ip
            ddr4_16gb_img_frame_udp_pyl_size_ready    = 'b0;
            ddr4_16gb_img_frame_s_udp_pyl_axis_tready = 'b0;
            ddr4_16gb_img_frame_eof_ack               = 'b0;
            ddr4_16gb_img_frame_pyl_acpt              = 'b0;
            ddr4_16gb_img_frame_core_busy             = 'b0;
        end
    endcase
end

endmodule
