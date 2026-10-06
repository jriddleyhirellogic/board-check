/*
 * @file      udp_tx_top.sv
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

module udp_tx_top #(
        // Initialization configs
    parameter integer CLOCK_FREQ_MHZ       = 100,
    parameter integer MAX_TIMEOUT_USEC     = 10_000_000, // 10 sec timeout

    // Etherent frame parameters
    parameter logic [15:0] ETH_TYPE        = 16'h0800,

    // IP header parameters
    parameter logic [3:0]  IP_VERSION      = 4'h4,
    parameter logic [3:0]  IP_IHL          = 4'h5,
    parameter logic [7:0]  IP_TOS          = 8'h00,
    parameter logic [15:0] IP_ID           = 16'h0001,
    parameter logic [2:0]  IP_FLAGS        = 3'h0,
    parameter logic [12:0] IP_FRAG_OFFSET  = 13'h0,
    parameter logic [7:0]  IP_TTL          = 8'h40,
    parameter logic [7:0]  IP_PROTOCOL     = 8'h11
)(
    // Input data clock
    input  logic        clk,
    input  logic        rst_n,

    // Eth header
    input  logic        eth_hdr_valid,
    output logic        eth_hdr_ready,
    input  logic [47:0] dst_mac_addr,
    input  logic [47:0] src_mac_addr,

    // IP header
    input  logic        iph_hdr_valid,
    output logic        iph_hdr_ready,
    input  logic [31:0] dst_ip_addr,
    input  logic [31:0] src_ip_addr,

    // UDP header
    input  logic         udp_hdr_valid,
    output logic         udp_hdr_ready,
    input  logic [15:0]  udp_src_port,
    input  logic [15:0]  udp_dst_port,

    // UDP Payload size
    input  logic         udp_pyl_size_valid,
    output logic         udp_pyl_size_ready,
    input  logic [15:0]  udp_pyl_size,

    // UDP Payload AXIS interface
    input  logic         s_axis_udp_pyl_tvalid,
    output logic         s_axis_udp_pyl_tready,
    input  logic [31:0]  s_axis_udp_pyl_tdata,
    input  logic [3:0]   s_axis_udp_pyl_tkeep,
    input  logic         s_axis_udp_pyl_tlast,

    // MAC Tx interface
    input  logic         MTXACPT,      // MAC tready
    output logic         MTXRDY,       // MAC tvalid
    output logic [31:0]  MTXDAT,       // MAC tdata
    output logic         MTXEOF,       // MAC tlast
    output logic [1:0]   MTXBYTEVALID, // MAC tkeep with modificaiton
    output logic         MTXSOF,

    // Control and Status
    input  logic         sof_req,   // User request to start a new frame
    output logic         eof_ack,   // Indicates end of frame has been reached and sent
    output logic         pyl_acpt,  // Indicates if core is acepting payload state
    output logic         core_busy, // Indicates core won't accept header changes

    // APB Setup and Status interface
    input  logic         clear,                 // CDC
    output logic [31:0]  wd_timeout_err_count,
    input  logic [31:0]  frame_gap              // CDC
);

//------------------------------------------------------------------------------
// Internal signals
//------------------------------------------------------------------------------
// Back Pressure FIFO interface
logic         fifo_rst_n;
logic         fifo_write_en;
logic [31:0]  fifo_write_data;
logic         fifo_write_full;
logic         fifo_read_en;
logic         fifo_read_valid;
logic [31:0]  fifo_read_data;
logic         fifo_read_empty;

//------------------------------------------------------------------------------
// UDP Tx instance
//------------------------------------------------------------------------------
udp_tx #(
    .CLOCK_FREQ_MHZ   (CLOCK_FREQ_MHZ  ),
    .MAX_TIMEOUT_USEC (MAX_TIMEOUT_USEC),
    .ETH_TYPE         (ETH_TYPE        ),
    .IP_VERSION       (IP_VERSION      ),
    .IP_IHL           (IP_IHL          ),
    .IP_TOS           (IP_TOS          ),
    .IP_ID            (IP_ID           ),
    .IP_FLAGS         (IP_FLAGS        ),
    .IP_FRAG_OFFSET   (IP_FRAG_OFFSET  ),
    .IP_TTL           (IP_TTL          ),
    .IP_PROTOCOL      (IP_PROTOCOL     )
)udp_tx_inst(
    .clk                      (clk                      ),
    .rst_n                    (rst_n                    ),
    .eth_hdr_valid            (eth_hdr_valid            ),
    .eth_hdr_ready            (eth_hdr_ready            ),
    .dst_mac_addr             (dst_mac_addr             ),
    .src_mac_addr             (src_mac_addr             ),
    .iph_hdr_valid            (iph_hdr_valid            ),
    .iph_hdr_ready            (iph_hdr_ready            ),
    .dst_ip_addr              (dst_ip_addr              ),
    .src_ip_addr              (src_ip_addr              ),
    .udp_hdr_valid            (udp_hdr_valid            ),
    .udp_hdr_ready            (udp_hdr_ready            ),
    .udp_src_port             (udp_src_port             ),
    .udp_dst_port             (udp_dst_port             ),
    .udp_pyl_size_valid       (udp_pyl_size_valid       ),
    .udp_pyl_size_ready       (udp_pyl_size_ready       ),
    .udp_pyl_size             (udp_pyl_size             ),
    .s_axis_udp_pyl_tvalid    (s_axis_udp_pyl_tvalid    ),
    .s_axis_udp_pyl_tready    (s_axis_udp_pyl_tready    ),
    .s_axis_udp_pyl_tdata     (s_axis_udp_pyl_tdata     ),
    .s_axis_udp_pyl_tkeep     (s_axis_udp_pyl_tkeep     ),
    .s_axis_udp_pyl_tlast     (s_axis_udp_pyl_tlast     ),
    .MTXACPT                  (MTXACPT                  ),
    .MTXRDY                   (MTXRDY                   ),
    .MTXDAT                   (MTXDAT                   ),
    .MTXEOF                   (MTXEOF                   ),
    .MTXBYTEVALID             (MTXBYTEVALID             ),
    .MTXSOF                   (MTXSOF                   ),
    .fifo_rst_n               (fifo_rst_n               ),
    .fifo_write_en            (fifo_write_en            ),
    .fifo_write_data          (fifo_write_data          ),
    .fifo_write_full          (fifo_write_full          ),
    .fifo_read_en             (fifo_read_en             ),
    .fifo_read_valid          (fifo_read_valid          ),
    .fifo_read_data           (fifo_read_data           ),
    .fifo_read_empty          (fifo_read_empty          ),
    .sof_req                  (sof_req                  ),
    .eof_ack                  (eof_ack                  ),
    .pyl_acpt                 (pyl_acpt                 ),
    .core_busy                (core_busy                ),
    .clear                    (clear                    ),
    .wd_timeout_err_count     (wd_timeout_err_count     ),
    .frame_gap                (frame_gap                )
);


//------------------------------------------------------------------------------
// FIFO instance
//------------------------------------------------------------------------------
COREFIFO_MAC_BACKPRES corefifo_mac_backpres_inst (
    .WCLOCK   (clk            ),
    .WRESET_N (fifo_rst_n     ),
    .WE       (fifo_write_en  ),
    .DATA     (fifo_write_data),
    .RCLOCK   (clk            ),
    .RRESET_N (fifo_rst_n     ),
    .RE       (fifo_read_en   ),
    .DVLD     (fifo_read_valid),
    .Q        (fifo_read_data ),
    .EMPTY    (fifo_read_empty),
    .FULL     (fifo_write_full)
);

endmodule
