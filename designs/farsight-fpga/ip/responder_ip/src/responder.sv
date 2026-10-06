/*
 * @file      responder.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      10/28/2025
 * 
 * @brief     Responder. This module receives and responds to traffic over Ethernet.
 *            The module has been taylored to work with the PolarFire CORETSE MAC.
 * 
 * @section changelog
 * - 10/28/2025: Steven Knyazher - Initial implementation
 * 
 */

`timescale 1ns/100ps

module responder #(
    // Initialization configs
    parameter CLOCK_FREQ_MHZ = 100,
    parameter PHY_INIT_USEC  = 100,
    parameter DATA_WIDTH     = 128,
    parameter MAC_WIDTH      = 48,
    parameter IPV4_WIDTH     = 32
)(
    // Input data clock
    input  logic                          clk,
    input  logic                          rst_n,
    
    // Ethernet header
    input  logic                          src_mac_valid,
    input  logic [MAC_WIDTH-1:0]          src_mac_addr,
    
    // IPv4 header
    input  logic                          src_ipv4_valid,
    input  logic [IPV4_WIDTH-1:0]         src_ipv4_addr,

    // RX side
    output logic                          rxacpt,
    input  logic                          rxrdy,
    input  logic [DATA_WIDTH-1:0]         rxdata,
    input  logic                          rxeof,
    input  logic [$clog2(DATA_WIDTH/8):0] rxbytevalid,
    input  logic                          rxsof,

    // TX side
    input  logic                          txacpt,
    output logic                          txrdy,
    output logic [DATA_WIDTH-1:0]         txdata,
    output logic                          txeof,
    output logic [$clog2(DATA_WIDTH/8):0] txbytevalid,
    output logic                          txsof,

    // Control and status
    output logic                          core_busy
);

//------------------------------------------------------------------------------
// Widths & Constants
//------------------------------------------------------------------------------

// Power Up
localparam POWER_UP_CYCLES = CLOCK_FREQ_MHZ * PHY_INIT_USEC;

// Ethernet Widths
localparam ETHERTYPE_WIDTH = 16;

// ARP Widths
localparam HW_TYPE_WIDTH  = 16;
localparam PRO_TYPE_WIDTH = 16;
localparam HW_SIZE_WIDTH  = 8;
localparam PRO_SIZE_WIDTH = 8;
localparam OPCODE_WIDTH   = 16;

// IPv4 Widths
localparam VER_WIDTH        = 4;
localparam IHL_WIDTH        = 4;
localparam DSCP_WIDTH       = 6;
localparam ECN_WIDTH        = 2;
localparam TOT_LEN_WIDTH    = 16;
localparam ID_WIDTH         = 16;
localparam FLAGS_WIDTH      = 3;
localparam FRAG_OFF_WIDTH   = 13;
localparam TTL_WIDTH        = 8;
localparam PRO_WIDTH        = 8;
localparam HDR_CHKSUM_WIDTH = 16;

// ICMP Widths
localparam ICMP_TYPE_WIDTH    = 8;
localparam ICMP_CODE_WIDTH    = 8;
localparam ICMP_CHKSUM_WIDTH  = 16;
localparam ICMP_ID_WIDTH      = 16;
localparam ICMP_SEQ_NUM_WIDTH = 16;

// Ethernet Constants
localparam logic [MAC_WIDTH-1:0]       BROADCAST_MAC  = 48'hffffffffffff;
localparam logic [ETHERTYPE_WIDTH-1:0] ARP_ETHERTYPE  = 16'h0806;
localparam logic [ETHERTYPE_WIDTH-1:0] IPV4_ETHERTYPE = 16'h0800;

// ARP Constants
localparam logic [HW_TYPE_WIDTH-1:0]  HW_TYPE        = 16'h0001;
localparam logic [PRO_TYPE_WIDTH-1:0] PRO_TYPE       = 16'h0800;
localparam logic [HW_SIZE_WIDTH-1:0]  HW_SIZE        = 8'h06;
localparam logic [PRO_SIZE_WIDTH-1:0] PRO_SIZE       = 8'h04;
localparam logic [OPCODE_WIDTH-1:0]   OPCODE_REQUEST = 16'h0001;
localparam logic [OPCODE_WIDTH-1:0]   OPCODE_REPLY   = 16'h0002;

// IPv4 Constants  
localparam logic [VER_WIDTH-1:0]        IPV4_VER            = 4'h4;
localparam logic [IHL_WIDTH-1:0]        IPV4_IHL            = 4'h5;
localparam logic [DSCP_WIDTH-1:0]       IPV4_DSCP           = 6'h0;
localparam logic [ECN_WIDTH-1:0]        IPV4_ECN            = 2'h0;
localparam logic [ID_WIDTH-1:0]         IPV4_ID             = 16'h0;
localparam logic [FLAGS_WIDTH-1:0]      IPV4_FLAGS          = 3'h0;
localparam logic [FRAG_OFF_WIDTH-1:0]   IPV4_FRAG_OFF       = 13'h0;
localparam logic [TTL_WIDTH-1:0]        IPV4_TTL            = 8'h40;
localparam logic [PRO_WIDTH-1:0]        IPV4_PRO_ICMP       = 8'h01;
localparam logic [HDR_CHKSUM_WIDTH-1:0] IPV4_TMP_HDR_CHKSUM = 16'h8501;     // Total of all IPv4 constants

// ICMP Constants
localparam logic [ICMP_TYPE_WIDTH-1:0] ICMP_TYPE_REQUEST = 8'h08;
localparam logic [ICMP_TYPE_WIDTH-1:0] ICMP_TYPE_REPLY   = 8'h00;
localparam logic [ICMP_CODE_WIDTH-1:0] ICMP_CODE         = 8'h00;

//------------------------------------------------------------------------------
// Local Signals
//------------------------------------------------------------------------------

// Registers for IOs
logic [MAC_WIDTH-1:0]         src_mac_addr_reg;
logic [IPV4_WIDTH-1:0]        src_ipv4_addr_reg;
logic                         core_busy_reg;

// Packet data
logic [MAC_WIDTH-1:0]         src_mac;
logic [IPV4_WIDTH-1:0]        src_ipv4;
logic [TOT_LEN_WIDTH-1:0]     ipv4_tot_len;
logic [HDR_CHKSUM_WIDTH-1:0]  ipv4_hdr_chksum;
logic [ICMP_CHKSUM_WIDTH-1:0] icmp_req_chksum;
logic [ICMP_CHKSUM_WIDTH-1:0] icmp_rep_chksum;

// Power up init counter
logic [31:0]                  init_counter;

//------------------------------------------------------------------------------
// FIFO signals
//------------------------------------------------------------------------------
logic [DATA_WIDTH-1:0]         rxdata_fifo;
logic                          rxeof_fifo;
logic [$clog2(DATA_WIDTH/8):0] rxbytevalid_fifo;
logic                          rxsof_fifo;
logic                          rxrdy_fifo;
logic                          rxacpt_fifo;
logic [DATA_WIDTH-1:0]         txdata_fifo;
logic                          txeof_fifo;
logic [$clog2(DATA_WIDTH/8):0] txbytevalid_fifo;
logic                          txsof_fifo;
logic                          txrdy_fifo;
logic                          txacpt_fifo;

//------------------------------------------------------------------------------
// Buffer RX signals when valid
//------------------------------------------------------------------------------
logic [DATA_WIDTH-1:0]         rxdata_valid;
logic                          rxeof_valid;
logic [$clog2(DATA_WIDTH/8):0] rxbytevalid_valid;
logic                          rxsof_valid;

//------------------------------------------------------------------------------
// FSM states for Responder
//------------------------------------------------------------------------------
typedef enum logic [3:0] {
    POWER_UP          = 4'd0,
    IDLE              = 4'd1,
    ETH_HDR           = 4'd2,
    ARP_RCV           = 4'd3,
    ARP_VALID         = 4'd4,
    ETH_ARP_HDR_SEND  = 4'd5,
    ARP_SEND          = 4'd6,
    ARP_FINISH        = 4'd7,
    IPV4_HDR          = 4'd8,
    IPV4_PING_VALID   = 4'd9,
    ETH_IPV4_HDR_SEND = 4'd10,
    IPV4_HDR_SEND     = 4'd11,
    IPV4_PING_SEND    = 4'd12,
    IPV4_PING_FINISH  = 4'd13,
    DROP_PKT          = 4'd14
} e_state_t;

e_state_t  e_curr_state;
e_state_t  e_next_state;

//------------------------------------------------------------------------------
// Continuous assignment
//------------------------------------------------------------------------------
assign core_busy = core_busy_reg;

//------------------------------------------------------------------------------
// IPv4 header checksum
//------------------------------------------------------------------------------
function automatic logic [HDR_CHKSUM_WIDTH-1:0] ipv4_chksum_calc(
    input logic [TOT_LEN_WIDTH-1:0]    tot_len,
    input logic [IPV4_WIDTH-1:0]       src_ipv4,
    input logic [IPV4_WIDTH-1:0]       dst_ipv4,
    input logic [HDR_CHKSUM_WIDTH-1:0] tmp_chksum
);
    logic [31:0] tmp1, tmp2, tmp3;
    begin
        tmp1 = tmp_chksum + tot_len;                                                // First pair of additions
        tmp1 = (tmp1 & 16'hFFFF) + (tmp1 >> 16);                                    // Fold carry
        tmp2 = src_ipv4[IPV4_WIDTH-1:IPV4_WIDTH/2] + src_ipv4[IPV4_WIDTH/2-1:0];    // Second pair of additions
        tmp2 = (tmp2 & 16'hFFFF) + (tmp2 >> 16);                                    // Fold carry
        tmp3 = dst_ipv4[IPV4_WIDTH-1:IPV4_WIDTH/2] + dst_ipv4[IPV4_WIDTH/2-1:0];    // Third pair of additions
        tmp3 = (tmp3 & 16'hFFFF) + (tmp3 >> 16);                                    // Fold carry
        tmp1 = tmp1 + tmp2;                                                         // Combine first two results
        tmp1 = (tmp1 & 16'hFFFF) + (tmp1 >> 16);                                    // Fold carry
        tmp1 = tmp1 + tmp3;                                                         // Add final result
        tmp1 = (tmp1 & 16'hFFFF) + (tmp1 >> 16);                                    // Fold carry
        return ~tmp1[15:0];                                                         // One's complement of the sum
    end
endfunction

//------------------------------------------------------------------------------
// ICMP checksum for ping reply
//------------------------------------------------------------------------------
function automatic logic [ICMP_CHKSUM_WIDTH-1:0] icmp_ping_chksum(input logic [ICMP_CHKSUM_WIDTH-1:0] icmp_req_chksum);
    logic [16:0] tmp;                                   // 17 bits to hold carry or underflow
    begin
        tmp = icmp_req_chksum + 17'h0800;               // Add the difference
        tmp = (tmp & 16'hFFFF) + (tmp >> 16);           // Fold carry if any
        return tmp[15:0];
    end
endfunction

//------------------------------------------------------------------------------
// Updating header info
//------------------------------------------------------------------------------
always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        src_mac_addr_reg  <= 'b0;
        src_ipv4_addr_reg <= 'b0;
    end else begin
        if (src_mac_valid) begin
            src_mac_addr_reg <= src_mac_addr;
        end else begin
            src_mac_addr_reg <= src_mac_addr_reg;
        end
        
        if (src_ipv4_valid) begin
            src_ipv4_addr_reg <= src_ipv4_addr;
        end else begin
            src_ipv4_addr_reg <= src_ipv4_addr_reg;
        end
    end
end

//------------------------------------------------------------------------------
// Responder FSM
//------------------------------------------------------------------------------
always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        e_curr_state      <= POWER_UP;
        init_counter      <= 'b0;
        core_busy_reg     <= 1'b1;
        src_mac           <= 'b0;
        src_ipv4          <= 'b0;
        ipv4_tot_len      <= 'b0;
        ipv4_hdr_chksum   <= 'b0;
        icmp_req_chksum   <= 'b0;
        icmp_rep_chksum   <= 'b0;
        rxacpt            <= 'b0;
        txrdy             <= 'b0;
        txdata            <= 'b0;
        txeof             <= 'b0;
        txbytevalid       <= 'b0;
        txsof             <= 'b0;
        rxdata_valid      <= 'b0;
        rxeof_valid       <= 'b0;
        rxbytevalid_valid <= 'b0;
        rxsof_valid       <= 'b0;
        rxdata_fifo       <= 'b0;
        rxeof_fifo        <= 'b0;
        rxbytevalid_fifo  <= 'b0;
        rxsof_fifo        <= 'b0;
        rxrdy_fifo        <= 'b0;
        txacpt_fifo       <= 'b0;

    end else begin
        // Update state
        e_curr_state <= e_next_state;

        if (rxrdy && rxacpt && rxacpt_fifo) begin
            rxdata_valid      <= rxdata;
            rxeof_valid       <= rxeof;
            rxbytevalid_valid <= rxbytevalid;
            rxsof_valid       <= rxsof;
            if (e_curr_state != DROP_PKT) begin
                rxdata_fifo      <= rxdata;
                rxeof_fifo       <= rxeof;
                rxbytevalid_fifo <= rxbytevalid;
                rxsof_fifo       <= rxsof;
                rxrdy_fifo       <= rxrdy;
            end else begin
                rxdata_fifo      <= 'b0;
                rxeof_fifo       <= 'b0;
                rxbytevalid_fifo <= 'b0;
                rxsof_fifo       <= 'b0;
                rxrdy_fifo       <= 'b0;
            end
        end else begin
            rxdata_valid      <= rxdata_valid;
            rxeof_valid       <= rxeof_valid;
            rxbytevalid_valid <= rxbytevalid_valid;
            rxsof_valid       <= rxsof_valid;
            rxdata_fifo       <= 'b0;
            rxeof_fifo        <= 'b0;
            rxbytevalid_fifo  <= 'b0;
            rxsof_fifo        <= 'b0;
            rxrdy_fifo        <= 'b0;
        end

//------------------------------------------------------------------------------
// Sequential FSM States
//------------------------------------------------------------------------------        
        if (e_curr_state == POWER_UP) begin
            init_counter    <= init_counter + 1;
            core_busy_reg   <= 1'b1;
            src_mac         <= 'b0;
            src_ipv4        <= 'b0;
            ipv4_tot_len    <= 'b0;
            ipv4_hdr_chksum <= 'b0;
            icmp_req_chksum <= 'b0;
            icmp_rep_chksum <= 'b0;
            rxacpt          <= 'b0;
            txrdy           <= 'b0;
            txdata          <= 'b0;
            txeof           <= 'b0;
            txbytevalid     <= 'b0;
            txsof           <= 'b0;
            txacpt_fifo     <= 'b0;
                
        end else if (e_curr_state == IDLE) begin
            init_counter    <= 'b0;
            src_mac         <= 'b0;
            src_ipv4        <= 'b0;
            ipv4_tot_len    <= 'b0;
            ipv4_hdr_chksum <= 'b0;
            icmp_req_chksum <= 'b0;
            icmp_rep_chksum <= 'b0;
            rxacpt          <= 1'b1;
            txrdy           <= 'b0;
            txdata          <= 'b0;
            txeof           <= 'b0;
            txbytevalid     <= 'b0;
            txsof           <= 'b0;
            txacpt_fifo     <= 'b0;

            if (rxrdy && rxacpt && rxacpt_fifo) begin
                core_busy_reg <= 1'b1;
            end else begin
                core_busy_reg <= 1'b0;
            end

        end else if (e_curr_state == ETH_HDR) begin
            init_counter    <= 'b0;
            core_busy_reg   <= 1'b1;
            src_ipv4        <= 'b0;
            ipv4_tot_len    <= 'b0;
            ipv4_hdr_chksum <= 'b0;
            icmp_req_chksum <= 'b0;
            icmp_rep_chksum <= 'b0;
            txrdy           <= 'b0;
            txdata          <= 'b0;
            txeof           <= 'b0;
            txbytevalid     <= 'b0;
            txsof           <= 'b0;
            txacpt_fifo     <= 'b0;

            if (rxeof_valid) begin
                rxacpt <= 1'b0;
            end else begin
                rxacpt <= 1'b1;
            end

            src_mac   <= rxdata_valid[DATA_WIDTH-MAC_WIDTH-1-:MAC_WIDTH];

        end else if (e_curr_state == ARP_RCV) begin
            init_counter    <= 'b0;
            core_busy_reg   <= 1'b1;
            src_mac         <= src_mac;
            ipv4_tot_len    <= 'b0;
            ipv4_hdr_chksum <= 'b0;
            icmp_req_chksum <= 'b0;
            icmp_rep_chksum <= 'b0;
            txrdy           <= 'b0;
            txdata          <= 'b0;
            txeof           <= 'b0;
            txbytevalid     <= 'b0;
            txsof           <= 'b0;
            txacpt_fifo     <= 'b0;

            if (rxeof_valid) begin
                rxacpt <= 1'b0;
            end else begin
                rxacpt <= 1'b1;
            end
            
            src_ipv4 <= rxdata_valid[DATA_WIDTH-PRO_TYPE_WIDTH-HW_SIZE_WIDTH-PRO_SIZE_WIDTH-OPCODE_WIDTH-MAC_WIDTH-1-:IPV4_WIDTH];
            
        end else if (e_curr_state == ARP_VALID) begin
            init_counter    <= 'b0;
            core_busy_reg   <= 1'b1;
            src_mac         <= src_mac;
            src_ipv4        <= src_ipv4;
            ipv4_tot_len    <= 'b0;
            ipv4_hdr_chksum <= 'b0;
            icmp_req_chksum <= 'b0;
            icmp_rep_chksum <= 'b0;
            txrdy           <= 'b0;
            txdata          <= 'b0;
            txeof           <= 'b0;
            txbytevalid     <= 'b0;
            txsof           <= 'b0;
            txacpt_fifo     <= 'b0;

            if (rxeof_valid) begin
                rxacpt <= 1'b0;
            end else begin
                rxacpt <= 1'b1;
            end
            
        end else if (e_curr_state == ETH_ARP_HDR_SEND) begin
            init_counter    <= 'b0;
            core_busy_reg   <= 1'b1;
            src_mac         <= src_mac;
            src_ipv4        <= src_ipv4;
            ipv4_tot_len    <= 'b0;
            ipv4_hdr_chksum <= 'b0;
            icmp_req_chksum <= 'b0;
            icmp_rep_chksum <= 'b0;

            if (rxeof_valid) begin
                rxacpt <= 1'b0;
            end else begin
                rxacpt <= 1'b1;
            end
            
            if (txacpt && ~txrdy) begin
                txrdy       <= 1'b1;
                txdata      <= {src_mac, src_mac_addr_reg, ARP_ETHERTYPE, HW_TYPE};
                txeof       <= 1'b0;
                txbytevalid <= DATA_WIDTH/8;
                txsof       <= 1'b1;
                txacpt_fifo <= 1'b1;
            end else begin
                txrdy       <= 'b0;
                txdata      <= 'b0;
                txeof       <= 'b0;
                txbytevalid <= 'b0;
                txsof       <= 'b0;
                txacpt_fifo <= 'b0;
            end
            
        end else if (e_curr_state == ARP_SEND) begin
            init_counter    <= 'b0;
            core_busy_reg   <= 1'b1;
            src_mac         <= src_mac;
            src_ipv4        <= src_ipv4;
            ipv4_tot_len    <= 'b0;
            ipv4_hdr_chksum <= 'b0;
            icmp_req_chksum <= 'b0;
            icmp_rep_chksum <= 'b0;

            if (rxeof_valid) begin
                rxacpt <= 1'b0;
            end else begin
                rxacpt <= 1'b1;
            end
            
            if (txacpt && ~txrdy) begin
                txrdy       <= 1'b1;
                txdata      <= {PRO_TYPE, HW_SIZE, PRO_SIZE, OPCODE_REPLY, src_mac_addr_reg, src_ipv4_addr_reg};
                txeof       <= 1'b0;
                txbytevalid <= DATA_WIDTH/8;
                txsof       <= 1'b0;
                txacpt_fifo <= 1'b1;
            end else begin
                txrdy       <= 'b0;
                txdata      <= 'b0;
                txeof       <= 'b0;
                txbytevalid <= 'b0;
                txsof       <= 'b0;
                txacpt_fifo <= 'b0;
            end

        end else if (e_curr_state == ARP_FINISH) begin
            init_counter    <= 'b0;
            core_busy_reg   <= 1'b1;
            src_mac         <= src_mac;
            src_ipv4        <= src_ipv4;
            ipv4_tot_len    <= 'b0;
            ipv4_hdr_chksum <= 'b0;
            icmp_req_chksum <= 'b0;
            icmp_rep_chksum <= 'b0;

            if (rxeof_valid) begin
                rxacpt <= 1'b0;
            end else begin
                rxacpt <= 1'b1;
            end
            
            if (txacpt && ~txrdy) begin
                txrdy       <= 1'b1;
                txdata      <= {src_mac, src_ipv4, 48'b0};
                txeof       <= 1'b1;
                txbytevalid <= (MAC_WIDTH+IPV4_WIDTH)/8;
                txsof       <= 1'b0;
                txacpt_fifo <= 1'b1;
            end else begin
                txrdy       <= 'b0;
                txdata      <= 'b0;
                txeof       <= 'b0;
                txbytevalid <= 'b0;
                txsof       <= 'b0;
                txacpt_fifo <= 'b0;
            end

        end else if (e_curr_state == IPV4_HDR) begin
            init_counter    <= 'b0;
            core_busy_reg   <= 1'b1;
            src_mac         <= src_mac;
            ipv4_hdr_chksum <= 'b0;
            icmp_req_chksum <= 'b0;
            icmp_rep_chksum <= 'b0;
            txrdy           <= 'b0;
            txdata          <= 'b0;
            txeof           <= 'b0;
            txbytevalid     <= 'b0;
            txsof           <= 'b0;
            txacpt_fifo     <= 'b0;
            
            if (rxeof_valid) begin
                rxacpt <= 1'b0;
            end else begin
                rxacpt <= 1'b1;
            end
            
            ipv4_tot_len <= rxdata_valid[DATA_WIDTH-1-:TOT_LEN_WIDTH];
            src_ipv4     <= rxdata_valid[DATA_WIDTH-TOT_LEN_WIDTH-ID_WIDTH-FLAGS_WIDTH-FRAG_OFF_WIDTH-
                                         TTL_WIDTH-PRO_WIDTH-HDR_CHKSUM_WIDTH-1-:IPV4_WIDTH];
            
        end else if (e_curr_state == IPV4_PING_VALID) begin
            init_counter    <= 'b0;
            core_busy_reg   <= 1'b1;
            src_mac         <= src_mac;
            src_ipv4        <= src_ipv4;
            ipv4_tot_len    <= ipv4_tot_len;
            icmp_rep_chksum <= 'b0;
            txrdy           <= 'b0;
            txdata          <= 'b0;
            txeof           <= 'b0;
            txbytevalid     <= 'b0;
            txsof           <= 'b0;
            txacpt_fifo     <= 'b0;

            if (rxeof_valid) begin
                rxacpt <= 1'b0;
            end else begin
                rxacpt <= 1'b1;
            end
            
            ipv4_hdr_chksum <= ipv4_chksum_calc(ipv4_tot_len, src_ipv4_addr_reg, src_ipv4, IPV4_TMP_HDR_CHKSUM);
            icmp_req_chksum <= rxdata_valid[DATA_WIDTH-IPV4_WIDTH/2-ICMP_TYPE_WIDTH-ICMP_CODE_WIDTH-1-:ICMP_CHKSUM_WIDTH];

          end else if (e_curr_state == ETH_IPV4_HDR_SEND) begin
            init_counter    <= 'b0;
            core_busy_reg   <= 1'b1;
            src_mac         <= src_mac;
            src_ipv4        <= src_ipv4;
            ipv4_tot_len    <= ipv4_tot_len;
            ipv4_hdr_chksum <= ipv4_hdr_chksum;
            icmp_req_chksum <= icmp_req_chksum;

            if (rxeof_valid) begin
                rxacpt <= 1'b0;
            end else begin
                rxacpt <= 1'b1;
            end

            icmp_rep_chksum <= icmp_ping_chksum(icmp_req_chksum);

            if (txacpt && ~txrdy) begin
                txrdy       <= 1'b1;
                txdata      <= {src_mac, src_mac_addr_reg, IPV4_ETHERTYPE, IPV4_VER, IPV4_IHL, IPV4_DSCP, IPV4_ECN};
                txeof       <= 1'b0;
                txbytevalid <= DATA_WIDTH/8;
                txsof       <= 1'b1;
                txacpt_fifo <= 1'b1;
            end else begin
                txrdy       <= 'b0;
                txdata      <= 'b0;
                txeof       <= 'b0;
                txbytevalid <= 'b0;
                txsof       <= 'b0;
                txacpt_fifo <= 'b0;
            end

          end else if (e_curr_state == IPV4_HDR_SEND) begin
            init_counter    <= 'b0;
            core_busy_reg   <= 1'b1;
            src_mac         <= src_mac;
            src_ipv4        <= src_ipv4;
            ipv4_tot_len    <= ipv4_tot_len;
            ipv4_hdr_chksum <= ipv4_hdr_chksum;
            icmp_req_chksum <= icmp_req_chksum;
            icmp_rep_chksum <= icmp_rep_chksum;

            if (rxeof_valid) begin
                rxacpt <= 1'b0;
            end else begin
                rxacpt <= 1'b1;
            end

            if (txacpt && ~txrdy) begin
                txrdy       <= 1'b1;
                txdata      <= {ipv4_tot_len, IPV4_ID, IPV4_FLAGS, IPV4_FRAG_OFF, IPV4_TTL, IPV4_PRO_ICMP,
                                ipv4_hdr_chksum, src_ipv4_addr_reg, src_ipv4[IPV4_WIDTH-1:IPV4_WIDTH/2]};
                txeof       <= 1'b0;
                txbytevalid <= DATA_WIDTH/8;
                txsof       <= 1'b0;
                txacpt_fifo <= 1'b1;
            end else begin
                txrdy       <= 'b0;
                txdata      <= 'b0;
                txeof       <= 'b0;
                txbytevalid <= 'b0;
                txsof       <= 'b0;
                txacpt_fifo <= 'b0;
            end

        end else if (e_curr_state == IPV4_PING_SEND) begin
            init_counter    <= 'b0;
            core_busy_reg   <= 1'b1;
            src_mac         <= src_mac;
            src_ipv4        <= src_ipv4;
            ipv4_tot_len    <= ipv4_tot_len;
            ipv4_hdr_chksum <= ipv4_hdr_chksum;
            icmp_req_chksum <= icmp_req_chksum;
            icmp_rep_chksum <= icmp_rep_chksum;

            if (rxeof_valid) begin
                rxacpt <= 1'b0;
            end else begin
                rxacpt <= 1'b1;
            end

            if (txacpt && ~txrdy) begin
                txrdy       <= txrdy_fifo;
                txdata      <= {src_ipv4[IPV4_WIDTH/2-1:0], ICMP_TYPE_REPLY, ICMP_CODE, icmp_rep_chksum,
                                txdata_fifo[DATA_WIDTH-IPV4_WIDTH/2-ICMP_TYPE_WIDTH-ICMP_CODE_WIDTH-ICMP_CHKSUM_WIDTH-1:0]};
                txeof       <= txeof_fifo;
                txbytevalid <= txbytevalid_fifo;
                txsof       <= txsof_fifo;
                txacpt_fifo <= 1'b1;
            end else begin
                txrdy       <= 'b0;
                txdata      <= 'b0;
                txeof       <= 'b0;
                txbytevalid <= 'b0;
                txsof       <= 'b0;
                txacpt_fifo <= 'b0;
            end

        end else if (e_curr_state == IPV4_PING_FINISH) begin
            init_counter    <= 'b0;
            core_busy_reg   <= 1'b1;
            src_mac         <= src_mac;
            src_ipv4        <= src_ipv4;
            ipv4_tot_len    <= ipv4_tot_len;
            ipv4_hdr_chksum <= ipv4_hdr_chksum;
            icmp_req_chksum <= icmp_req_chksum;
            icmp_rep_chksum <= icmp_rep_chksum;

            if (rxeof_valid) begin
                rxacpt <= 1'b0;
            end else begin
                rxacpt <= 1'b1;
            end

            if (txacpt && ~txrdy) begin
                txrdy       <= txrdy_fifo;
                txdata      <= txdata_fifo;
                txeof       <= txeof_fifo;
                txbytevalid <= txbytevalid_fifo;
                txsof       <= txsof_fifo;
                txacpt_fifo <= 1'b1;
            end else begin
                txrdy       <= 'b0;
                txdata      <= 'b0;
                txeof       <= 'b0;
                txbytevalid <= 'b0;
                txsof       <= 'b0;
                txacpt_fifo <= 'b0;
            end

        end else if (e_curr_state == DROP_PKT) begin
            init_counter    <= 'b0;
            core_busy_reg   <= 'b1;
            src_mac         <= 'b0;
            src_ipv4        <= 'b0;
            ipv4_tot_len    <= 'b0;
            ipv4_hdr_chksum <= 'b0;
            icmp_req_chksum <= 'b0;
            icmp_rep_chksum <= 'b0;
            txrdy           <= 'b0;
            txdata          <= 'b0;
            txeof           <= 'b0;
            txbytevalid     <= 'b0;
            txsof           <= 'b0;

            if (rxeof_valid) begin
                rxacpt <= 1'b0;
            end else begin
                rxacpt <= 1'b1;
            end

            if (txrdy_fifo) begin
                txacpt_fifo <= 1'b1;
            end else begin
                txacpt_fifo <= 'b0;
            end
            
        end else begin
            // We should never be here
            init_counter    <= 'b0;
            core_busy_reg   <= 'b0;
            src_mac         <= 'b0;
            src_ipv4        <= 'b0;
            ipv4_tot_len    <= 'b0;
            ipv4_hdr_chksum <= 'b0;
            icmp_req_chksum <= 'b0;
            icmp_rep_chksum <= 'b0;
            rxacpt          <= 'b0;
            txrdy           <= 'b0;
            txdata          <= 'b0;
            txeof           <= 'b0;
            txbytevalid     <= 'b0;
            txsof           <= 'b0;
            txacpt_fifo     <= 'b0;
        end
        
    end
end

always_comb begin

    e_next_state = POWER_UP;
    
    case(e_curr_state)
        
        POWER_UP: begin
            if (init_counter <= POWER_UP_CYCLES-1) begin
                e_next_state = POWER_UP;
            end else begin
                e_next_state = IDLE;
            end
        end
        
        IDLE: begin
            // When valid data is detected, make sure that it's the start of frame, else drop the
            // packet. If data isn't valid, stay in idle state.
            if (rxrdy && rxacpt && rxacpt_fifo) begin
                if (rxsof && ~rxeof) begin
                    e_next_state = ETH_HDR;
                end else begin
                    e_next_state = DROP_PKT;
                end
            end else begin
                e_next_state = IDLE;
            end
        end

        ETH_HDR: begin
            // Make sure destination MAC address equals to the board's source MAC address when
            // EtherType is equal to IPv4, or make sure destination MAC address is a broadcast when
            // EtherType is equal to ARP. If both are false, drop the packet.
            if (rxrdy && rxacpt && rxacpt_fifo) begin
                if ((rxdata_valid[DATA_WIDTH-1-:MAC_WIDTH] == src_mac_addr_reg) &&
                    (rxdata_valid[DATA_WIDTH-(2*MAC_WIDTH)-1-:ETHERTYPE_WIDTH] == IPV4_ETHERTYPE) && ~rxeof) begin
                    e_next_state = IPV4_HDR;
                end else if ((rxdata_valid[DATA_WIDTH-1-:MAC_WIDTH] == BROADCAST_MAC) &&
                             (rxdata_valid[DATA_WIDTH-(2*MAC_WIDTH)-1-:ETHERTYPE_WIDTH] == ARP_ETHERTYPE) && ~rxeof) begin
                    e_next_state = ARP_RCV;
                end else begin
                    e_next_state = DROP_PKT;
                end
            end else begin
                e_next_state = ETH_HDR;
            end
        end

        ARP_RCV: begin
            // Make sure operation code equals to ARP request, else drop the packet.
            if (rxrdy && rxacpt && rxacpt_fifo) begin
                if ((rxdata_valid[DATA_WIDTH-PRO_TYPE_WIDTH-HW_SIZE_WIDTH-PRO_SIZE_WIDTH-1-:OPCODE_WIDTH] == OPCODE_REQUEST) && ~rxeof) begin
                    e_next_state = ARP_VALID;
                end else begin
                    e_next_state = DROP_PKT;
                end
            end else begin
                e_next_state = ARP_RCV;
            end
        end

        ARP_VALID: begin
            // Make sure target IPv4 address equals to the board's source IPv4 address, else drop the packet.
            if (rxrdy && rxacpt && rxacpt_fifo) begin
                if (rxdata_valid[DATA_WIDTH-MAC_WIDTH-1-:IPV4_WIDTH] == src_ipv4_addr_reg) begin
                    e_next_state = ETH_ARP_HDR_SEND;
                end else begin
                    e_next_state = DROP_PKT;
                end
            end else begin
                e_next_state = ARP_VALID;
            end
        end

        ETH_ARP_HDR_SEND: begin
            // ARP packet has been verified, continue sending the ARP reply.
            if (txacpt && txrdy) begin
                e_next_state = ARP_SEND;
            end else begin
                e_next_state = ETH_ARP_HDR_SEND;
            end
        end

        ARP_SEND: begin
            // ARP packet has been verified, continue sending the ARP reply.
            if (txacpt && txrdy) begin
                e_next_state = ARP_FINISH;
            end else begin
                e_next_state = ARP_SEND;
            end
        end

        ARP_FINISH: begin
            // Finish sending the ARP reply and go back to idle state when the request packet has been fully read.
            if (txacpt && txrdy) begin
                if ((rxeof_valid && ~rxacpt) && (~txrdy_fifo && ~txacpt_fifo)) begin
                    e_next_state = IDLE;
                end else begin
                    e_next_state = DROP_PKT;
                end
            end else begin
                e_next_state = ARP_FINISH;
            end
        end

        IPV4_HDR: begin
            // Make sure protocol equals to ICMP and first half of destination IPv4 address equals to the board's
            // source IPv4 address, else drop the packet.
            if (rxrdy && rxacpt && rxacpt_fifo) begin
                if ((rxdata_valid[DATA_WIDTH-TOT_LEN_WIDTH-ID_WIDTH-FLAGS_WIDTH-FRAG_OFF_WIDTH-TTL_WIDTH-1-:PRO_WIDTH] == IPV4_PRO_ICMP) &&
                    (rxdata_valid[DATA_WIDTH-TOT_LEN_WIDTH-ID_WIDTH-FLAGS_WIDTH-FRAG_OFF_WIDTH-TTL_WIDTH-PRO_WIDTH-HDR_CHKSUM_WIDTH-
                                  IPV4_WIDTH-1-:IPV4_WIDTH/2] == src_ipv4_addr_reg[IPV4_WIDTH-1:IPV4_WIDTH/2]) && ~rxeof) begin
                    e_next_state = IPV4_PING_VALID;
                end else begin
                    e_next_state = DROP_PKT;
                end
            end else begin
                e_next_state = IPV4_HDR;
            end
        end

        IPV4_PING_VALID: begin
            // Make sure second half of destination IPv4 address equals to the board's
            // source IPv4 address and ICMP type equals to echo request, else drop the packet.
            if (rxrdy && rxacpt && rxacpt_fifo) begin
                if ((rxdata_valid[DATA_WIDTH-1-:IPV4_WIDTH/2] == src_ipv4_addr_reg[IPV4_WIDTH/2-1:0]) &&
                    (rxdata_valid[DATA_WIDTH-IPV4_WIDTH/2-1-:ICMP_TYPE_WIDTH] == ICMP_TYPE_REQUEST)) begin
                    e_next_state = ETH_IPV4_HDR_SEND;
                end else begin
                    e_next_state = DROP_PKT;
                end
            end else begin
                e_next_state = IPV4_PING_VALID;
            end
        end

        ETH_IPV4_HDR_SEND: begin
            // IPv4 ping packet has been verified, continue sending the IPv4 ping reply.
            if (txacpt && txrdy) begin
                e_next_state = IPV4_HDR_SEND;
            end else begin
                e_next_state = ETH_IPV4_HDR_SEND;
            end
        end

        IPV4_HDR_SEND: begin
            // IPv4 ping packet has been verified, continue sending the IPv4 ping reply.
            if (txacpt && txrdy) begin
                e_next_state = IPV4_PING_SEND;
            end else begin
                e_next_state = IPV4_HDR_SEND;
            end
        end

        IPV4_PING_SEND: begin
            // IPv4 ping packet has been verified, continue sending the IPv4 ping reply.
            if (txacpt && txrdy) begin
                if (txeof) begin
                    e_next_state = IDLE;
                end else begin
                    e_next_state = IPV4_PING_FINISH;
                end
            end else begin
                e_next_state = IPV4_PING_SEND;
            end
        end

        IPV4_PING_FINISH: begin
            // Finish sending the IPv4 ping reply and go back to idle state when the request packet has been fully read.
            if (txacpt && txrdy && txeof) begin
                e_next_state = IDLE;
            end else begin
                e_next_state = IPV4_PING_FINISH;
            end
        end

        DROP_PKT: begin
            if (rxeof_valid && ~txrdy_fifo) begin
                e_next_state = IDLE;
            end else begin
                e_next_state = DROP_PKT;
            end
        end

        default: begin
            e_next_state = IDLE;
        end
        
    endcase
end

//------------------------------------------------------------------------------
// Responder FIFO instantiation
//------------------------------------------------------------------------------
rsp_fifo #(
    .DATA_WIDTH(DATA_WIDTH)
) dut (
    .clk         (clk),
    .rst_n       (rst_n),
    
    .rxsof       (rxsof_fifo),
    .rxeof       (rxeof_fifo),
    .rxdata      (rxdata_fifo),
    .rxbytevalid (rxbytevalid_fifo),
    .rxrdy       (rxrdy_fifo),
    .rxacpt      (rxacpt_fifo),
    
    .txsof       (txsof_fifo),
    .txeof       (txeof_fifo),
    .txdata      (txdata_fifo),
    .txbytevalid (txbytevalid_fifo),
    .txrdy       (txrdy_fifo),
    .txacpt      (txacpt_fifo)
);

endmodule