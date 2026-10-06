/*
 * @file      rsp_top.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      11/25/2025
 * 
 * @brief     Responder Top. This module combines the Responder and Width Up and
 *            Down Converters.
 * 
 * @section changelog
 * - 11/25/2025: Steven Knyazher - Initial implementation
 * 
 */

`timescale 1ns/100ps

module rsp_top #(
    // Initialization configs
    parameter CLOCK_FREQ_MHZ   = 100,
    parameter PHY_INIT_USEC    = 100,
    parameter MAC_DATA_WIDTH   = 32,
    parameter RSP_DATA_WIDTH   = 128,
    parameter MAC_WIDTH        = 48,
    parameter IPV4_WIDTH       = 32
)(
    // Input data clock
    input  logic                                clk,
    input  logic                                rst_n,
    
    // Ethernet header
    input  logic                                src_mac_valid,
    input  logic [MAC_WIDTH-1:0]                src_mac_addr,
    
    // IPv4 header
    input  logic                                src_ipv4_valid,
    input  logic [IPV4_WIDTH-1:0]               src_ipv4_addr,

    // RX side
    output logic                                rxacpt,
    input  logic                                rxrdy,
    input  logic [MAC_DATA_WIDTH-1:0]           rxdata,
    input  logic                                rxeof,
    input  logic [$clog2(MAC_DATA_WIDTH/8)-1:0] rxbytevalid,
    input  logic                                rxsof,

    // TX side
    input  logic                                txacpt,
    output logic                                txrdy,
    output logic [MAC_DATA_WIDTH-1:0]           txdata,
    output logic                                txeof,
    output logic [$clog2(MAC_DATA_WIDTH/8)-1:0] txbytevalid,
    output logic                                txsof,

    // Control and status
    output logic                                core_busy
);

//------------------------------------------------------------------------------
// Internal signals
//------------------------------------------------------------------------------
logic                              rxacpt_rsp;
logic                              rxrdy_rsp;
logic [RSP_DATA_WIDTH-1:0]         rxdata_rsp;
logic                              rxeof_rsp;
logic [$clog2(RSP_DATA_WIDTH/8):0] rxbytevalid_rsp;
logic                              rxsof_rsp;

logic                              txacpt_rsp;
logic                              txrdy_rsp;
logic [RSP_DATA_WIDTH-1:0]         txdata_rsp;
logic                              txeof_rsp;
logic [$clog2(RSP_DATA_WIDTH/8):0] txbytevalid_rsp;
logic                              txsof_rsp;

//------------------------------------------------------------------------------
// Instances
//------------------------------------------------------------------------------
responder #(
    .CLOCK_FREQ_MHZ (CLOCK_FREQ_MHZ ),
    .PHY_INIT_USEC  (PHY_INIT_USEC  ),
    .DATA_WIDTH     (RSP_DATA_WIDTH ),
    .MAC_WIDTH      (MAC_WIDTH      ),
    .IPV4_WIDTH     (IPV4_WIDTH     )
) responder_inst (
    .clk            (clk            ),
    .rst_n          (rst_n          ),
    .src_mac_valid  (src_mac_valid  ),
    .src_mac_addr   (src_mac_addr   ),
    .src_ipv4_valid (src_ipv4_valid ),
    .src_ipv4_addr  (src_ipv4_addr  ),
    .rxacpt         (rxacpt_rsp     ),
    .rxrdy          (rxrdy_rsp      ),
    .rxdata         (rxdata_rsp     ),
    .rxeof          (rxeof_rsp      ),
    .rxbytevalid    (rxbytevalid_rsp),
    .rxsof          (rxsof_rsp      ),
    .txacpt         (txacpt_rsp     ),
    .txrdy          (txrdy_rsp      ),
    .txdata         (txdata_rsp     ),
    .txeof          (txeof_rsp      ),
    .txbytevalid    (txbytevalid_rsp),
    .txsof          (txsof_rsp      ),
    .core_busy      (core_busy      )
);

width_up_conv #(
    .RX_DATA_WIDTH (MAC_DATA_WIDTH ),
    .TX_DATA_WIDTH (RSP_DATA_WIDTH )
) width_up_conv_inst (
    .clk           (clk            ),
    .rst_n         (rst_n          ),
    .rxacpt        (rxacpt         ),
    .rxrdy         (rxrdy          ),
    .rxdata        (rxdata         ),
    .rxeof         (rxeof          ),
    .rxbytevalid   (rxbytevalid    ),
    .rxsof         (rxsof          ),
    .txacpt        (rxacpt_rsp     ),
    .txrdy         (rxrdy_rsp      ),
    .txdata        (rxdata_rsp     ),
    .txeof         (rxeof_rsp      ),
    .txbytevalid   (rxbytevalid_rsp),
    .txsof         (rxsof_rsp      )
);

width_down_conv #(
    .RX_DATA_WIDTH (RSP_DATA_WIDTH ),
    .TX_DATA_WIDTH (MAC_DATA_WIDTH )
) width_down_conv_inst (
    .clk           (clk            ),
    .rst_n         (rst_n          ),
    .rxacpt        (txacpt_rsp     ),
    .rxrdy         (txrdy_rsp      ),
    .rxdata        (txdata_rsp     ),
    .rxeof         (txeof_rsp      ),
    .rxbytevalid   (txbytevalid_rsp),
    .rxsof         (txsof_rsp      ),
    .txacpt        (txacpt         ),
    .txrdy         (txrdy          ),
    .txdata        (txdata         ),
    .txeof         (txeof          ),
    .txbytevalid   (txbytevalid    ),
    .txsof         (txsof          )
);

endmodule