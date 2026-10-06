/*
 * @file      udp_tx.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      2/6/2025
 *
 * @brief     This module transmits UDP packets over Ethernet.
 *            The module has bin taylored to work with the PolarFire CORETSEMAC.
 *
 * @section changelog
 * - 11/11/2025: Saba Janamian - Initial implementation
 *
 */

`timescale 1ns/100ps

// -----------------------------------------------------------------------------
// Important: The first 2 bytes of the UDP Payload must be either 0 or be
//            the checksum of the payload. None 0 checksum will be evaluated
//            by most Linux socket libraries and will be dropped if incorrect.
// -----------------------------------------------------------------------------

module udp_tx #(
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

    // Back Pressure FIFO interface
    output logic         fifo_rst_n,
    output logic         fifo_write_en,
    output logic [31:0]  fifo_write_data,
    input  logic         fifo_write_full,
    output logic         fifo_read_en,
    input  logic         fifo_read_valid,
    input  logic [31:0]  fifo_read_data,
    input  logic         fifo_read_empty,

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
// MAC TX Back pressure handling Logic:
//
// The mac_mtxrdy_o_sig output indicates when data is ready to be transmitted
// to the MAC.
// This signal is asserted when the MAC is accepting
// data (mac_mtxacpt_i_sig) AND either:
//   - Valid data is available from the FIFO (fifo_read_valid), OR
//   - There is backpressured data being held that needs to be transmitted
//
// Simplified expression:
//   mac_mtxrdy_o_sig = mac_mtxacpt_i_sig & (fifo_read_valid | backpressure);
//
//
// Backpressure State Management:
//
// The backpressure register captures and holds data when the MAC temporarily
// stops accepting (mac_mtxacpt_i_sig deasserts) while valid FIFO data is
// present. This prevents data loss during MAC flow control events.
//
// Backpressure is asserted when:
//   - The MAC stops accepting (~mac_mtxacpt_i_sig) AND either:
//     - Valid FIFO data is present (fifo_read_valid), OR
//     - Backpressure is already active (maintaining hold state)
//
// Backpressure is released when:
//   - The MAC resumes accepting data (mac_mtxacpt_i_sig), allowing the held
//     data to be transmitted
//
// Simplified expression:
//   backpressure <= ~mac_mtxacpt_i_sig & (fifo_read_valid | backpressure);
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// Frame gap is the number of write cycles to wait after writing data to the PHY
// This must be at least 12 bytes worth of time.
// Gigabit Ethernet minimum transmit Inner package gap: 96 ns
// The Microchip PolarFire CoreTSE MAC cannot handle frame gaps less than
// 20 uSec.
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// This is the header of an Ethernet frame.
//
// # Fields
//
// *   [dst_mac] is the destination MAC address.
// *   [src_mac] is the source MAC address.
// *   [eth_type] indicates the protocol of the packet being sent.
//------------------------------------------------------------------------------

typedef struct packed {
    logic [47:0] dst_mac;
    logic [47:0] src_mac;
    logic [15:0] eth_type;
} eth_header_t;

//------------------------------------------------------------------------------
// According to RFC 791, an IP header has the following format
//
//  0                   1                   2                   3
//  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
// +---------------+---------------+---------------+---------------+
// |Version|  IHL  |     Type      |          Total Length         |
// +---------------+---------------+---------------+---------------+
// |         Identification        |Flags|     Fragment Offset     |
// +---------------+---------------+---------------+---------------+
// | Time to Live  |    Protocol   |        Header Checksum        |
// +---------------+---------------+---------------+---------------+
// |                       Source IP Address                       |
// +---------------+---------------+---------------+---------------+
// |                    Destination IP Address                     |
// +---------------+---------------+---------------+---------------+
//
// # Fields
//
// *   [version] indicates the format of internet header.
// *   [ihl] is the internet header length. This must be at least 5.
// *   [type_of_service] is the type and quality of service desired.
// *   [total_length] is the total length of packet including the header and
//     data.
// *   [identification] is  assigned to help with assembling fragments.
// *   [flags] is a set of control flags.
// *   [fragment_offset] indicates where in a datagram the fragment belongs.
// *   [time_to_live] the time (formally in seconds, practically in hops) that
//     the datagram is allowed to live.
// *   [protocol] the next level protocol to use.
// *   [hdr_checksum] is the checksum that verifies the validity of the
//     IP header.
// *   [src_ip] is the source IPv4 address.
// *   [dst_ip] is the destination IPv4 address.
//------------------------------------------------------------------------------
typedef struct packed {
    logic [3:0]  version;
    logic [3:0]  ihl;
    logic [7:0]  type_of_service;
    logic [15:0] total_length;
    logic [15:0] identification;
    logic [2:0]  flags;
    logic [12:0] fragment_offset;
    logic [7:0]  time_to_live;
    logic [7:0]  protocol;
    logic [15:0] hdr_checksum;
    logic [31:0] src_ip;
    logic [31:0] dst_ip;
} ip_header_t;

//------------------------------------------------------------------------------
// According to RFC 768, the UDP header has the following format
//
//  0      7 8     15 16    23 24    31
// +--------+--------+--------+--------+
// |   Source Port   |    Dest Port    |
// +--------+--------+--------+--------+
// |     Length      |    Checksum     |
// +--------+--------+--------+--------+
//
// # Fields
//
// *   [src_port] is the number of the source port.
// *   [dst_port] is the number of the destination port.
// *   [length] is the length of the packet in bytes inclufing this header.
// *   [checksum] is the UDP checksum.
//------------------------------------------------------------------------------
typedef struct packed {
    logic [15:0] src_port;
    logic [15:0] dst_port;
    logic [15:0] length;
    logic [15:0] checksum;
} udp_header_t;

//------------------------------------------------------------------------------
// MAC frame header consisting of all the eth, ip, and udp headers
//------------------------------------------------------------------------------
typedef struct packed {
    eth_header_t  eth;
    ip_header_t   iph;
    udp_header_t  udp;
} mac_header_t;


//------------------------------------------------------------------------------
// Constants
//------------------------------------------------------------------------------
localparam integer AXIS_DATA_WIDTH = 32;
localparam integer AXIS_KEEP_WIDTH = (AXIS_DATA_WIDTH/8);
localparam integer AXIS_USER_WIDTH = (AXIS_DATA_WIDTH/8);

localparam integer ETH_HDR_SIZE_BYTE = 14;
localparam integer IPH_HDR_SIZE_BYTE = 20;
localparam integer UDP_HDR_SIZE_BYTE = 8;

localparam integer ETH_HDR_SIZE_BIT  = ETH_HDR_SIZE_BYTE*8; // 112 bits
localparam integer IPH_HDR_SIZE_BIT  = IPH_HDR_SIZE_BYTE*8; // 160 bits
localparam integer UDP_HDR_SIZE_BIT  = UDP_HDR_SIZE_BYTE*8; // 64 bits

// MAC Header size 336 bits, 42 bytes
localparam integer MAC_HDR_WIDTH  = ETH_HDR_SIZE_BIT + IPH_HDR_SIZE_BIT + UDP_HDR_SIZE_BIT;


localparam integer FRAME_GAP_DEFAULT = 1000;

localparam integer MAX_TIMEOUT_COUNT = MAX_TIMEOUT_USEC * CLOCK_FREQ_MHZ;

localparam integer BAD_EOF_TOKEN = 32'hEFBADBAD;
//------------------------------------------------------------------------------
// Local Signals
//------------------------------------------------------------------------------

// Etherent Frame header parts
mac_header_t    mac_hdr;

// Eth header
logic [47:0]    dst_mac_addr_reg;
logic [47:0]    src_mac_addr_reg;

// IP header
logic [31:0]    dst_ip_addr_reg;
logic [31:0]    src_ip_addr_reg;

// UDP header
logic [15:0]    udp_src_port_reg;
logic [15:0]    udp_dst_port_reg;

// Payload size, will hold the total size of the payload in this packet
logic [15:0]    udp_pyl_size_reg;

logic           core_busy_reg; // Indicate if core can accept header values

logic [31:0]    iph_checksum_holder;

logic           mac_mtxacpt_i_sig;      // MAC tready
logic           mac_mtxrdy_o_sig;       // MAC tvalid
logic [31:0]    mac_mtxdat_o_sig;       // MAC tdata
logic           mac_mtxeof_o_sig;       // MAC tlast
logic [1:0]     mac_mtxbytevalid_o_sig; // MAC tkeep with modificaiton
logic           mac_mtxsof_o_sig;

// The PolarFire TSEMAC requires tlast and bytevalid to be sent one clock
// later after the last word
logic [1:0]     mac_mtxbytevalid_dly_reg;
logic [31:0]    mac_mtxdata_dly_reg;

logic           sof_req_reg;

logic [31:0]    wd_wait_timeout;
logic [31:0]    wd2_wait_timeout;

logic [31:0]    frame_gap_sync[2]; // [0:1]
logic [31:0]    frame_gap_reg;
logic [1:0]     clear_sync;
logic           clear_reg;

logic [31:0]    data_in_counter;
logic [31:0]    data_out_counter;

logic           fifo_read_en_reg;
logic           backpressure;
logic [31:0]    hdr_word_reg;

//------------------------------------------------------------------------------
// FSM states for UDP data send process
//------------------------------------------------------------------------------
typedef enum logic [3:0] {
    IDLE               = 4'd0,
    PREPARE            = 4'd1,
    CHECKSUM_CALC_P1   = 4'd2,
    CHECKSUM_CALC_P2   = 4'd3,
    SEND_HEADER        = 4'd4,
    SEND_PAYLOAD       = 4'd5,
    FLUSH_REM_BUFFER   = 4'd6,
    SEND_PAYLOAD_LAST  = 4'd7,
    FRAME_GAP_WAIT     = 4'd8,
    WD_TIMEOUT_ERR     = 4'd9 // Sends the eof signal to the MAC
} state_t;

state_t  curr_state;
state_t  next_state;

logic [31:0]  hdr_byte_idx;
logic [31:0]  gap_counter;

//------------------------------------------------------------------------------
// Continuous assignment
//------------------------------------------------------------------------------
// indicate when headers can be updated via core_busy_reg
assign core_busy            = core_busy_reg;

assign mac_mtxacpt_i_sig    = MTXACPT;
assign MTXRDY               = mac_mtxrdy_o_sig;
assign MTXDAT               = mac_mtxdat_o_sig;
assign MTXEOF               = mac_mtxeof_o_sig;
assign MTXBYTEVALID         = mac_mtxbytevalid_o_sig;
assign MTXSOF               = mac_mtxsof_o_sig;

//------------------------------------------------------------------------------
// Macros
//------------------------------------------------------------------------------
// Add descriptionl;
`define SWAP_VEC_OCTETS(vec, start_bit) \
    {vec[start_bit-8-24 +: 8], \
    vec[start_bit-8-16 +: 8], \
    vec[start_bit-8-8 +: 8], \
    vec[start_bit-8 +: 8]};

`define SWAP_WRD_OCTETS(word) \
    {word[0 +: 8], word[8 +: 8], word[16 +: 8], word[24 +: 8]};

//------------------------------------------------------------------------------
// CDC Sync
//------------------------------------------------------------------------------
always_ff @(posedge clk, negedge rst_n) begin
    if(~rst_n) begin
        frame_gap_sync <= '{default: 1'b0};
        clear_sync     <= 2'b0;

    end else begin
        frame_gap_sync[0] <= frame_gap;
        frame_gap_sync[1] <= frame_gap_sync[0];

        if (frame_gap_sync[1] == 0) begin
            frame_gap_reg <= FRAME_GAP_DEFAULT;
        end else begin
            frame_gap_reg <= frame_gap_sync[1];
        end

        clear_sync <= {clear_sync[0], clear};
        clear_reg  <= clear_sync[1];
    end
end


//------------------------------------------------------------------------------
// Updating header info
//------------------------------------------------------------------------------

always_ff @(posedge clk, negedge rst_n) begin
    if(~rst_n) begin
        eth_hdr_ready      <= 'b0;
        iph_hdr_ready      <= 'b0;
        udp_hdr_ready      <= 'b0;
        udp_pyl_size_ready <= 'b0;
        udp_pyl_size_reg   <= 'b0;
        sof_req_reg        <= 'b0;
        dst_mac_addr_reg   <= 'b0;
        src_mac_addr_reg   <= 'b0;
        dst_ip_addr_reg    <= 'b0;
        src_ip_addr_reg    <= 'b0;
        udp_src_port_reg   <= 'b0;
        udp_dst_port_reg   <= 'b0;
    end else begin
        // Indicating we can accpet new header info if needed.
        if(~core_busy_reg) begin
            eth_hdr_ready      <= 1'b1;
            iph_hdr_ready      <= 1'b1;
            udp_hdr_ready      <= 1'b1;
            udp_pyl_size_ready <= 1'b1;
        end else begin
            eth_hdr_ready      <= 1'b0;
            iph_hdr_ready      <= 1'b0;
            udp_hdr_ready      <= 1'b0;
            udp_pyl_size_ready <= 1'b0;
        end

        if (eth_hdr_valid) begin
            dst_mac_addr_reg <= dst_mac_addr;
            src_mac_addr_reg <= src_mac_addr;
        end else begin
            dst_mac_addr_reg <= dst_mac_addr_reg;
            src_mac_addr_reg <= src_mac_addr_reg;
        end

        if (iph_hdr_valid) begin
            dst_ip_addr_reg <= dst_ip_addr;
            src_ip_addr_reg <= src_ip_addr;
        end else begin
            dst_ip_addr_reg <= dst_ip_addr_reg;
            src_ip_addr_reg <= src_ip_addr_reg;
        end

        if(udp_hdr_valid) begin
            udp_src_port_reg <= udp_src_port;
            udp_dst_port_reg <= udp_dst_port;
        end else begin
            udp_src_port_reg <= udp_src_port_reg;
            udp_dst_port_reg <= udp_dst_port_reg;
        end

        if(udp_pyl_size_valid) begin
            udp_pyl_size_reg <= udp_pyl_size;
        end else begin
            udp_pyl_size_reg <= udp_pyl_size_reg;
        end

        sof_req_reg <= sof_req;
    end
end


//------------------------------------------------------------------------------
// Capturing Last word for End of Frame request
//------------------------------------------------------------------------------
always_ff @(posedge clk, negedge rst_n) begin
    if(~rst_n) begin
        mac_mtxbytevalid_dly_reg <= 2'b0;
        mac_mtxdata_dly_reg      <= 32'b0;
    end else begin

        // If s_axis_udp_pyl_tlast && ~s_axis_udp_pyl_tvalid
        // that is a bug and will be ignored. The core will timeout in
        // that case.

        if (s_axis_udp_pyl_tlast && s_axis_udp_pyl_tvalid) begin
            mac_mtxbytevalid_dly_reg  <=
                s_axis_udp_pyl_tkeep == 4'b1111 ? 2'b00 :
                s_axis_udp_pyl_tkeep == 4'b1110 ? 2'b01 :
                s_axis_udp_pyl_tkeep == 4'b1100 ? 2'b10 :
                s_axis_udp_pyl_tkeep == 4'b1000 ? 2'b11 :
                2'b0;
            mac_mtxdata_dly_reg       <= s_axis_udp_pyl_tdata;
        end else begin
            mac_mtxbytevalid_dly_reg  <= mac_mtxbytevalid_dly_reg;
            mac_mtxdata_dly_reg       <= mac_mtxdata_dly_reg;
        end

    end
end

//------------------------------------------------------------------------------
// UDP FSM Sequential logic
//------------------------------------------------------------------------------
always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        curr_state  <= IDLE;
    end else begin
        curr_state  <= next_state;
    end
end

//------------------------------------------------------------------------------
// UDP FSM Combinational logic
//------------------------------------------------------------------------------

always_comb begin

    next_state = curr_state;

    case(curr_state)

        IDLE: begin
            if (sof_req_reg) begin
                next_state         = PREPARE;
            end else begin
                next_state         = IDLE;
            end
        end

        PREPARE: begin
            next_state             = CHECKSUM_CALC_P1;
        end

        CHECKSUM_CALC_P1: begin
            next_state             = CHECKSUM_CALC_P2;
        end

        CHECKSUM_CALC_P2: begin
            next_state             = SEND_HEADER;
        end

        SEND_HEADER: begin
            if (wd_wait_timeout-1 == 0) begin
                next_state          = WD_TIMEOUT_ERR;
            end else if(hdr_byte_idx < 10) begin
                next_state          = SEND_HEADER;
            end else begin
                next_state          = SEND_PAYLOAD;
            end
        end

        SEND_PAYLOAD: begin
            if (wd_wait_timeout-1 == 0) begin
                next_state          = WD_TIMEOUT_ERR;
            end else if(s_axis_udp_pyl_tlast) begin
                next_state          = FLUSH_REM_BUFFER;
            end else begin
                next_state          = SEND_PAYLOAD;
            end
        end

        FLUSH_REM_BUFFER: begin
            if (wd_wait_timeout-1 == 0) begin
                next_state         = WD_TIMEOUT_ERR;
            end else if(mac_mtxacpt_i_sig && fifo_read_empty && ~fifo_read_valid) begin
                next_state         = SEND_PAYLOAD_LAST;
            end else begin
                next_state         = FLUSH_REM_BUFFER;
            end
        end

        SEND_PAYLOAD_LAST: begin
            if (wd_wait_timeout-1 == 0) begin
                next_state         = WD_TIMEOUT_ERR;
            end else if(mac_mtxacpt_i_sig) begin
                next_state         = FRAME_GAP_WAIT;
            end else begin
                next_state         = SEND_PAYLOAD_LAST;
            end
        end

        FRAME_GAP_WAIT: begin
            if(gap_counter < frame_gap_reg) begin
                next_state          = FRAME_GAP_WAIT;
            end else begin
                next_state          = IDLE;
            end
        end

        WD_TIMEOUT_ERR: begin
            if (mac_mtxacpt_i_sig) begin
                next_state         = IDLE;
            end else if (wd2_wait_timeout-1 == 0) begin
                // We at least gave it a chance and it still failed
                next_state         = IDLE;
            end else begin
                next_state         = WD_TIMEOUT_ERR;
            end
        end

        default: begin
            next_state             = IDLE;
        end

    endcase
end

//------------------------------------------------------------------------------
// Asynchronous outputs
//------------------------------------------------------------------------------

always_comb begin

    case(curr_state)

        IDLE: begin

            // Only start the frame transfer if valid header for eth, iph and udp
            // has been provided
            mac_mtxsof_o_sig       = 1'b0;
            mac_mtxrdy_o_sig       = 1'b0;
            mac_mtxdat_o_sig       = 32'b0;
            mac_mtxeof_o_sig       = 1'b0;
            mac_mtxbytevalid_o_sig = 2'b0;

            fifo_write_en          = 1'b0;
            fifo_write_data        = 32'b0;
            fifo_read_en           = 1'b0;

        end

        PREPARE: begin

            mac_mtxsof_o_sig       = 1'b0;
            mac_mtxrdy_o_sig       = 1'b0;
            mac_mtxdat_o_sig       = 32'b0;
            mac_mtxeof_o_sig       = 1'b0;
            mac_mtxbytevalid_o_sig = 2'b0;

            fifo_write_en          = 1'b0;
            fifo_write_data        = 32'b0;
            fifo_read_en           = 1'b0;

        end

        CHECKSUM_CALC_P1: begin

            mac_mtxsof_o_sig       = 1'b0;
            mac_mtxrdy_o_sig       = 1'b0;
            mac_mtxdat_o_sig       = 32'b0;
            mac_mtxeof_o_sig       = 1'b0;
            mac_mtxbytevalid_o_sig = 2'b0;

            fifo_write_en          = 1'b0;
            fifo_write_data        = 32'b0;
            fifo_read_en           = 1'b0;

        end

        CHECKSUM_CALC_P2: begin

            mac_mtxsof_o_sig       = 1'b0;
            mac_mtxrdy_o_sig       = 1'b0;
            mac_mtxdat_o_sig       = 32'b0;
            mac_mtxeof_o_sig       = 1'b0;
            mac_mtxbytevalid_o_sig = 2'b0;

            fifo_write_en          = 1'b0;
            fifo_write_data        = 32'b0;
            fifo_read_en           = 1'b0;

        end

        SEND_HEADER: begin

            mac_mtxrdy_o_sig   = mac_mtxacpt_i_sig && ~backpressure && (hdr_byte_idx < 10);

            if(mac_mtxacpt_i_sig && hdr_byte_idx == 0) begin
                mac_mtxsof_o_sig   = 1'b1; // Indicate start of the frame
                mac_mtxdat_o_sig   = `SWAP_VEC_OCTETS(mac_hdr, MAC_HDR_WIDTH-(hdr_byte_idx * 32));
            end else if (mac_mtxacpt_i_sig && hdr_byte_idx < 10) begin
                mac_mtxsof_o_sig   = 1'b0; // Indicate start of the frame
                mac_mtxdat_o_sig   = `SWAP_VEC_OCTETS(mac_hdr, MAC_HDR_WIDTH-(hdr_byte_idx * 32));
            end else begin
                mac_mtxsof_o_sig   = 1'b0;
                mac_mtxdat_o_sig   = 32'b0;
            end

            mac_mtxeof_o_sig       = 1'b0;
            mac_mtxbytevalid_o_sig = 2'b0;

            fifo_write_en          = 1'b0;
            fifo_write_data        = 32'b0;
            fifo_read_en           = 1'b0;

        end

        SEND_PAYLOAD: begin

            mac_mtxrdy_o_sig = mac_mtxacpt_i_sig & (fifo_read_valid | backpressure);
            mac_mtxdat_o_sig = `SWAP_WRD_OCTETS(fifo_read_data); // Swap octates

            mac_mtxsof_o_sig         = 1'b0;
            mac_mtxeof_o_sig         = 1'b0;
            mac_mtxbytevalid_o_sig   = 2'b0;

            // The last word will be sent to the MAC separatly from the FIFO
            // when FIFO is empty and to provide the EOF signal to the MAC
            if (s_axis_udp_pyl_tlast) begin
                fifo_write_en        = 1'b0;
                fifo_write_data      = 32'b0;
            end else begin
                if(~fifo_write_full) begin
                    fifo_write_en    = s_axis_udp_pyl_tvalid;
                    fifo_write_data  = s_axis_udp_pyl_tdata;
                end else begin
                    fifo_write_en    = 1'b0;
                    fifo_write_data  = 32'b0;
                end
            end

            // Keep reading as long as the fifo is not empty
            if (~fifo_read_empty) begin
                fifo_read_en         = mac_mtxacpt_i_sig & fifo_read_en_reg;
            end else begin
                fifo_read_en         = 1'b0;
            end

        end

        FLUSH_REM_BUFFER: begin

            mac_mtxrdy_o_sig = mac_mtxacpt_i_sig & (fifo_read_valid | backpressure);
            mac_mtxdat_o_sig = `SWAP_WRD_OCTETS(fifo_read_data); // Swap octates

            mac_mtxsof_o_sig       = 1'b0;
            mac_mtxeof_o_sig       = 1'b0;
            mac_mtxbytevalid_o_sig = 2'b0;

            fifo_write_en          = 1'b0;
            fifo_write_data        = 32'b0;

            // Keep reading until the FIFO becomes empty
            if (~fifo_read_empty) begin
                fifo_read_en        = mac_mtxacpt_i_sig;
            end else begin
                fifo_read_en        = 1'b0;
            end

        end

        SEND_PAYLOAD_LAST: begin

            mac_mtxsof_o_sig       = 1'b0;
            mac_mtxrdy_o_sig       = mac_mtxacpt_i_sig;
            mac_mtxdat_o_sig       = `SWAP_WRD_OCTETS(mac_mtxdata_dly_reg); // Swap octates
            mac_mtxeof_o_sig       = mac_mtxacpt_i_sig;
            mac_mtxbytevalid_o_sig = mac_mtxbytevalid_dly_reg;

            fifo_read_en           = 1'b0;
            fifo_write_en          = 1'b0;
            fifo_write_data        = 32'b0;

        end

        FRAME_GAP_WAIT: begin

            mac_mtxsof_o_sig       = 1'b0;
            mac_mtxrdy_o_sig       = 1'b0;
            mac_mtxdat_o_sig       = 32'b0;
            mac_mtxeof_o_sig       = 1'b0;
            mac_mtxbytevalid_o_sig = 2'b0;

            fifo_write_en          = 1'b0;
            fifo_write_data        = 32'b0;
            fifo_read_en           = 1'b0;

        end

        WD_TIMEOUT_ERR: begin

            mac_mtxsof_o_sig       = 1'b0;
            mac_mtxrdy_o_sig       = 1'b1;
            mac_mtxdat_o_sig       = `SWAP_WRD_OCTETS(BAD_EOF_TOKEN); // Swap octates
            mac_mtxeof_o_sig       = 1'b1;
            mac_mtxbytevalid_o_sig = 2'b0; // All 4 bytes valid indicator

            fifo_write_en          = 1'b0;
            fifo_write_data        = 32'b0;
            fifo_read_en           = 1'b0;

        end

        default: begin

            mac_mtxsof_o_sig       = 1'b0;
            mac_mtxrdy_o_sig       = 1'b0;
            mac_mtxdat_o_sig       = 32'b0;
            mac_mtxeof_o_sig       = 1'b0;
            mac_mtxbytevalid_o_sig = 2'b0;

            fifo_write_en          = 1'b0;
            fifo_write_data        = 32'b0;
            fifo_read_en           = 1'b0;

        end

    endcase
end

//------------------------------------------------------------------------------
// Control/Status Signals Block
//------------------------------------------------------------------------------
always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        core_busy_reg         <= 1'b1;
        pyl_acpt              <= 1'b0;
        eof_ack               <= 1'b0;
        fifo_rst_n            <= 1'b0;
        s_axis_udp_pyl_tready <= 1'b0;
    end else begin
        if (curr_state == IDLE) begin
            core_busy_reg         <= 1'b0;
            pyl_acpt              <= 1'b0;
            eof_ack               <= 1'b0;
            fifo_rst_n            <= 1'b0; // Keep fifo in reset when idle
            s_axis_udp_pyl_tready <= 1'b0;

        end else if (curr_state == PREPARE) begin
            core_busy_reg         <= 1'b1; // Disable receiving further header changes
            pyl_acpt              <= 1'b0;
            eof_ack               <= 1'b0;
            fifo_rst_n            <= 1'b1; // Release fifo reset
            s_axis_udp_pyl_tready <= 1'b0;

        end else if (curr_state == CHECKSUM_CALC_P1) begin
            core_busy_reg         <= 1'b1;
            pyl_acpt              <= 1'b0;
            eof_ack               <= 1'b0;
            fifo_rst_n            <= 1'b1;
            s_axis_udp_pyl_tready <= 1'b0;

        end else if (curr_state == CHECKSUM_CALC_P2) begin
            core_busy_reg         <= 1'b1;
            pyl_acpt              <= 1'b0;
            eof_ack               <= 1'b0;
            fifo_rst_n            <= 1'b1;
            s_axis_udp_pyl_tready <= 1'b0;

        end else if (curr_state == SEND_HEADER) begin
            core_busy_reg         <= 1'b1;
            pyl_acpt              <= 1'b0;
            eof_ack               <= 1'b0;
            fifo_rst_n            <= 1'b1;
            s_axis_udp_pyl_tready <= 1'b0;

        end else if (curr_state == SEND_PAYLOAD) begin
            core_busy_reg         <= 1'b1;
            pyl_acpt              <= 1'b1; // Accepting payload now
            eof_ack               <= 1'b0;
            fifo_rst_n            <= 1'b1;
            s_axis_udp_pyl_tready <= (~fifo_write_full);

        end else if (curr_state == FLUSH_REM_BUFFER) begin
            core_busy_reg         <= 1'b1;
            pyl_acpt              <= 1'b0; // Release
            eof_ack               <= 1'b0;
            fifo_rst_n            <= 1'b1;
            s_axis_udp_pyl_tready <= 1'b0; // Release

        end else if (curr_state == SEND_PAYLOAD_LAST) begin
            core_busy_reg         <= 1'b1;
            pyl_acpt              <= 1'b0; // Release
            eof_ack               <= 1'b0;
            fifo_rst_n            <= 1'b1;
            s_axis_udp_pyl_tready <= 1'b0; // Release

        end else if (curr_state == FRAME_GAP_WAIT) begin
            core_busy_reg         <= 1'b1;
            pyl_acpt              <= 1'b0; // No more payload is accepted
            fifo_rst_n            <= 1'b1;
            s_axis_udp_pyl_tready <= 1'b0;

            if (gap_counter >= frame_gap_reg-1) begin
                eof_ack           <= 1'b1;
            end else begin
                eof_ack           <= 1'b0;
            end

        end else if (curr_state == WD_TIMEOUT_ERR) begin
            core_busy_reg         <= 1'b0; // Releasing core busy
            pyl_acpt              <= 1'b0;
            eof_ack               <= 1'b1; // Ending this package send due to timeout
            fifo_rst_n            <= 1'b1;
            s_axis_udp_pyl_tready <= 1'b0; // No more ready for accepting udp payload

        end else begin
            // We should never be here
            core_busy_reg         <= 1'b0;
            pyl_acpt              <= 1'b0;
            eof_ack               <= 1'b0;
            fifo_rst_n            <= 1'b0;
            s_axis_udp_pyl_tready <= 1'b0;
        end
    end
end

//------------------------------------------------------------------------------
// MAC Header Signals Block
//------------------------------------------------------------------------------
always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        mac_hdr.eth.dst_mac         <= 48'b0;
        mac_hdr.eth.src_mac         <= 48'b0;
        mac_hdr.eth.eth_type        <= 16'b0; // Const
        mac_hdr.iph.version         <=  4'b0; // Const
        mac_hdr.iph.ihl             <=  4'b0; // Const
        mac_hdr.iph.type_of_service <=  8'b0; // Const
        mac_hdr.iph.total_length    <= 16'b0;
        mac_hdr.iph.identification  <= 16'b0; // Const
        mac_hdr.iph.flags           <=  3'b0; // Const
        mac_hdr.iph.fragment_offset <= 13'b0; // Const
        mac_hdr.iph.time_to_live    <=  8'b0; // Const
        mac_hdr.iph.protocol        <=  8'b0; // Const
        mac_hdr.iph.hdr_checksum    <= 16'b0;
        mac_hdr.iph.src_ip          <= 32'b0;
        mac_hdr.iph.dst_ip          <= 32'b0;
        mac_hdr.udp.src_port        <= 16'b0;
        mac_hdr.udp.dst_port        <= 16'b0;
        mac_hdr.udp.length          <= 16'b0;
        mac_hdr.udp.checksum        <= 16'b0; // Const
    end else begin
        // MAC header constant values that won't change during the run time
        mac_hdr.eth.eth_type        <= ETH_TYPE;
        mac_hdr.iph.version         <= IP_VERSION;
        mac_hdr.iph.ihl             <= IP_IHL;
        mac_hdr.iph.type_of_service <= IP_TOS;
        mac_hdr.iph.identification  <= IP_ID;
        mac_hdr.iph.flags           <= IP_FLAGS;
        mac_hdr.iph.fragment_offset <= IP_FRAG_OFFSET;
        mac_hdr.iph.time_to_live    <= IP_TTL;
        mac_hdr.iph.protocol        <= IP_PROTOCOL;
        mac_hdr.udp.checksum        <= 16'b0; // UDP checksum won't be calculated

//------------------------------------------------------------------------------
// Sequential FSM States - MAC Header
//------------------------------------------------------------------------------
        if (curr_state == IDLE) begin
            mac_hdr.eth.dst_mac       <= 48'b0;
            mac_hdr.eth.src_mac       <= 48'b0;
            mac_hdr.iph.total_length  <= 16'b0;
            mac_hdr.iph.hdr_checksum  <= 16'b0;
            mac_hdr.iph.src_ip        <= 32'b0;
            mac_hdr.iph.dst_ip        <= 32'b0;
            mac_hdr.udp.src_port      <= 16'b0;
            mac_hdr.udp.dst_port      <= 16'b0;
            mac_hdr.udp.length        <= 16'b0;

        end else if (curr_state == PREPARE) begin
            // Etherent Frame
            mac_hdr.eth.dst_mac       <= dst_mac_addr_reg;
            mac_hdr.eth.src_mac       <= src_mac_addr_reg;

            // IP Header
            mac_hdr.iph.total_length  <= IPH_HDR_SIZE_BYTE + UDP_HDR_SIZE_BYTE + udp_pyl_size_reg;
            mac_hdr.iph.hdr_checksum  <= 16'h0; // Calculated in the CHECKSUM_CALC state
            mac_hdr.iph.src_ip        <= src_ip_addr_reg;
            mac_hdr.iph.dst_ip        <= dst_ip_addr_reg;

            // UDP Header
            mac_hdr.udp.src_port      <= udp_src_port_reg;
            mac_hdr.udp.dst_port      <= udp_dst_port_reg;
            mac_hdr.udp.length        <= UDP_HDR_SIZE_BYTE + udp_pyl_size_reg;

        end else if (curr_state == CHECKSUM_CALC_P1) begin
            mac_hdr.eth.dst_mac       <= mac_hdr.eth.dst_mac;
            mac_hdr.eth.src_mac       <= mac_hdr.eth.src_mac;
            mac_hdr.iph.total_length  <= mac_hdr.iph.total_length;
            mac_hdr.iph.hdr_checksum  <= 16'h0;
            mac_hdr.iph.src_ip        <= mac_hdr.iph.src_ip;
            mac_hdr.iph.dst_ip        <= mac_hdr.iph.dst_ip;
            mac_hdr.udp.src_port      <= mac_hdr.udp.src_port;
            mac_hdr.udp.dst_port      <= mac_hdr.udp.dst_port;
            mac_hdr.udp.length        <= mac_hdr.udp.length;

        end else if (curr_state == CHECKSUM_CALC_P2) begin
            mac_hdr.eth.dst_mac       <= mac_hdr.eth.dst_mac;
            mac_hdr.eth.src_mac       <= mac_hdr.eth.src_mac;
            mac_hdr.iph.total_length  <= mac_hdr.iph.total_length;
            mac_hdr.iph.hdr_checksum  <= (~((iph_checksum_holder & 16'hFFFF) + (iph_checksum_holder >> 16)) & 16'hFFFF);
            mac_hdr.iph.src_ip        <= mac_hdr.iph.src_ip;
            mac_hdr.iph.dst_ip        <= mac_hdr.iph.dst_ip;
            mac_hdr.udp.src_port      <= mac_hdr.udp.src_port;
            mac_hdr.udp.dst_port      <= mac_hdr.udp.dst_port;
            mac_hdr.udp.length        <= mac_hdr.udp.length;

        end else if (curr_state == SEND_HEADER) begin
            mac_hdr.eth.dst_mac       <= mac_hdr.eth.dst_mac;
            mac_hdr.eth.src_mac       <= mac_hdr.eth.src_mac;
            mac_hdr.iph.total_length  <= mac_hdr.iph.total_length;
            mac_hdr.iph.hdr_checksum  <= mac_hdr.iph.hdr_checksum;
            mac_hdr.iph.src_ip        <= mac_hdr.iph.src_ip;
            mac_hdr.iph.dst_ip        <= mac_hdr.iph.dst_ip;
            mac_hdr.udp.src_port      <= mac_hdr.udp.src_port;
            mac_hdr.udp.dst_port      <= mac_hdr.udp.dst_port;
            mac_hdr.udp.length        <= mac_hdr.udp.length;

        end else begin
            // We should never be here
            mac_hdr.eth.dst_mac       <= 48'b0;
            mac_hdr.eth.src_mac       <= 48'b0;
            mac_hdr.iph.total_length  <= 16'b0;
            mac_hdr.iph.hdr_checksum  <= 16'b0;
            mac_hdr.iph.src_ip        <= 32'b0;
            mac_hdr.iph.dst_ip        <= 32'b0;
            mac_hdr.udp.src_port      <= 16'b0;
            mac_hdr.udp.dst_port      <= 16'b0;
            mac_hdr.udp.length        <= 16'b0;
        end
    end
end

//------------------------------------------------------------------------------
// Main FSM Data Path Block (Remaining Signals)
//------------------------------------------------------------------------------
always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        wd_timeout_err_count         <= 32'b0;
        wd_wait_timeout             <= MAX_TIMEOUT_COUNT;
        wd2_wait_timeout            <= MAX_TIMEOUT_COUNT;
        hdr_byte_idx                <= 32'b0;
        gap_counter                 <= 32'b0;
        iph_checksum_holder         <= 32'b0;
        data_in_counter             <= 32'b0;
        data_out_counter            <= 32'b0;
        fifo_read_en_reg            <= 1'b0;
        backpressure                <= 1'b0;
    end else begin
//------------------------------------------------------------------------------
// Sequential FSM States - Data Path
//------------------------------------------------------------------------------
        if (curr_state == IDLE) begin
            // Only clearing error counts when IDLE
            if (clear_reg) begin
                wd_timeout_err_count  <= 32'b0;
            end else begin
                wd_timeout_err_count  <= wd_timeout_err_count;
            end

            wd_wait_timeout           <= MAX_TIMEOUT_COUNT;
            wd2_wait_timeout          <= MAX_TIMEOUT_COUNT;
            hdr_byte_idx              <= 32'b0;
            gap_counter               <= 32'b0;
            iph_checksum_holder       <= 32'b0;
            data_in_counter           <= 32'b0;
            data_out_counter          <= 32'b0;
            fifo_read_en_reg          <= 1'b0;
            backpressure              <= 1'b0;

        end else if (curr_state == PREPARE) begin
            wd_timeout_err_count      <= wd_timeout_err_count;
            wd_wait_timeout           <= MAX_TIMEOUT_COUNT;
            wd2_wait_timeout          <= MAX_TIMEOUT_COUNT;
            hdr_byte_idx              <= 32'b0;
            gap_counter               <= 32'b0;
            iph_checksum_holder       <= 32'b0;
            data_in_counter           <= 32'b0;
            data_out_counter          <= 32'b0;
            fifo_read_en_reg          <= 1'b0;
            backpressure              <= 1'b0;

        end else if (curr_state == CHECKSUM_CALC_P1) begin
            wd_timeout_err_count      <= wd_timeout_err_count;
            wd_wait_timeout           <= MAX_TIMEOUT_COUNT;
            wd2_wait_timeout          <= MAX_TIMEOUT_COUNT;
            hdr_byte_idx              <= 32'b0;
            gap_counter               <= 32'b0;

            iph_checksum_holder       <= (
                {mac_hdr.iph.version, mac_hdr.iph.ihl, mac_hdr.iph.type_of_service} + // 16
                {mac_hdr.iph.total_length} +                                          // 16
                {mac_hdr.iph.identification} +                                        // 16
                {mac_hdr.iph.flags, mac_hdr.iph.fragment_offset} +                    // 16
                {mac_hdr.iph.time_to_live, mac_hdr.iph.protocol} +                    // 16
                {mac_hdr.iph.src_ip[31:16]} +                                         // 16
                {mac_hdr.iph.src_ip[15:0]} +                                          // 16
                {mac_hdr.iph.dst_ip[31:16]} +                                         // 16
                {mac_hdr.iph.dst_ip[15:0]});                                          // 16

            data_in_counter           <= 32'b0;
            data_out_counter          <= 32'b0;
            fifo_read_en_reg          <= 1'b0;
            backpressure              <= 1'b0;

        end else if (curr_state == CHECKSUM_CALC_P2) begin
            wd_timeout_err_count      <= wd_timeout_err_count;
            wd_wait_timeout           <= MAX_TIMEOUT_COUNT;
            wd2_wait_timeout          <= MAX_TIMEOUT_COUNT;
            hdr_byte_idx              <= 32'b0;
            gap_counter               <= 32'b0;
            iph_checksum_holder       <= 32'b0;
            data_in_counter           <= 32'b0;
            data_out_counter          <= 32'b0;
            fifo_read_en_reg          <= 1'b0;
            backpressure              <= 1'b0;
            hdr_word_reg              <= 32'b0;

        end else if (curr_state == SEND_HEADER) begin
            wd_timeout_err_count      <= wd_timeout_err_count;
            wd2_wait_timeout          <= MAX_TIMEOUT_COUNT;
            iph_checksum_holder       <= 32'b0;

            if(mac_mtxacpt_i_sig) begin
                wd_wait_timeout       <= MAX_TIMEOUT_COUNT;
            end else begin
                wd_wait_timeout       <= wd_wait_timeout - 1;
            end

            if (backpressure) begin
                hdr_byte_idx          <= hdr_byte_idx;     // Keep the prev val
            end else if(mac_mtxacpt_i_sig) begin
                hdr_byte_idx          <= hdr_byte_idx + 1;
            end else begin
                hdr_byte_idx          <= hdr_byte_idx;     // Keep the prev val
            end

            data_in_counter           <= 32'b0;
            data_out_counter          <= 32'b0;
            fifo_read_en_reg          <= 1'b0;
            backpressure              <= ~mac_mtxacpt_i_sig;

        end else if (curr_state == SEND_PAYLOAD) begin
            wd_timeout_err_count      <= wd_timeout_err_count;
            wd2_wait_timeout          <= MAX_TIMEOUT_COUNT;
            hdr_byte_idx              <= 32'b0;
            gap_counter               <= 32'b0;
            iph_checksum_holder       <= 32'b0;

            if(mac_mtxacpt_i_sig && s_axis_udp_pyl_tvalid) begin
                wd_wait_timeout       <= MAX_TIMEOUT_COUNT;
            end else begin
                wd_wait_timeout       <= wd_wait_timeout - 1;
            end

            if (s_axis_udp_pyl_tvalid && (~fifo_write_full)) begin
                data_in_counter       <= data_in_counter + 1;
            end else begin
                data_in_counter       <= data_in_counter;
            end

            if (mac_mtxrdy_o_sig) begin
                data_out_counter      <= data_out_counter + 1;
            end else begin
                data_out_counter      <= data_out_counter;
            end

            fifo_read_en_reg          <= mac_mtxacpt_i_sig;
            backpressure              <= ~mac_mtxacpt_i_sig & (fifo_read_valid | backpressure);
            hdr_word_reg              <= 32'b0;

        end else if (curr_state == FLUSH_REM_BUFFER) begin
            wd_timeout_err_count      <= wd_timeout_err_count;
            wd2_wait_timeout          <= MAX_TIMEOUT_COUNT;
            hdr_byte_idx              <= 32'b0;
            gap_counter               <= 32'b0;
            iph_checksum_holder       <= 32'b0;

            if(mac_mtxacpt_i_sig) begin
                wd_wait_timeout       <= MAX_TIMEOUT_COUNT;
            end else begin
                wd_wait_timeout       <= wd_wait_timeout - 1;
            end

            if (s_axis_udp_pyl_tvalid && (~fifo_write_full)) begin
                data_in_counter       <= data_in_counter + 1;
            end else begin
                data_in_counter       <= data_in_counter;
            end

            if (mac_mtxrdy_o_sig) begin
                data_out_counter      <= data_out_counter + 1;
            end else begin
                data_out_counter      <= data_out_counter;
            end

            backpressure              <= ~mac_mtxacpt_i_sig & (fifo_read_valid | backpressure);

        end else if (curr_state == SEND_PAYLOAD_LAST) begin
            wd_timeout_err_count      <= wd_timeout_err_count;
            wd2_wait_timeout          <= MAX_TIMEOUT_COUNT;
            hdr_byte_idx              <= 32'b0;
            gap_counter               <= 32'b0;
            iph_checksum_holder       <= 32'b0;

            if(mac_mtxacpt_i_sig) begin
                wd_wait_timeout       <= MAX_TIMEOUT_COUNT;
            end else begin
                wd_wait_timeout       <= wd_wait_timeout - 1;
            end

            data_in_counter           <= data_in_counter;

            if (mac_mtxrdy_o_sig) begin
                data_out_counter      <= data_out_counter + 1;
            end else begin
                data_out_counter      <= data_out_counter;
            end

            backpressure              <= ~mac_mtxacpt_i_sig;

        end else if (curr_state == FRAME_GAP_WAIT) begin
            wd_timeout_err_count      <= wd_timeout_err_count;
            wd_wait_timeout           <= MAX_TIMEOUT_COUNT;
            wd2_wait_timeout          <= MAX_TIMEOUT_COUNT;
            hdr_byte_idx              <= 32'b0;
            iph_checksum_holder       <= 32'b0;
            data_in_counter           <= data_in_counter;
            data_out_counter          <= data_out_counter;
            gap_counter               <= gap_counter + 1;

        end else if (curr_state == WD_TIMEOUT_ERR) begin
            // We will be here when the CORETESE does not receive the tlast or
            // its fifo is filled up
            wd_wait_timeout           <= MAX_TIMEOUT_COUNT;
            hdr_byte_idx              <= 32'b0;
            gap_counter               <= 32'b0;
            iph_checksum_holder       <= 32'b0;
            data_in_counter           <= data_in_counter;
            data_out_counter          <= data_out_counter;

            if (mac_mtxacpt_i_sig) begin
                wd_timeout_err_count  <= wd_timeout_err_count + 1; // Increament watchdog error counter
                wd2_wait_timeout      <= MAX_TIMEOUT_COUNT;
            end else begin
                wd2_wait_timeout      <= wd2_wait_timeout - 1;
                wd_timeout_err_count  <= wd_timeout_err_count;
            end

        end else begin
            // We should never be here
            wd_timeout_err_count      <= 32'b0;
            wd_wait_timeout           <= MAX_TIMEOUT_COUNT;
            wd2_wait_timeout          <= MAX_TIMEOUT_COUNT;
            hdr_byte_idx              <= 32'b0;
            gap_counter               <= 32'b0;
            iph_checksum_holder       <= 32'b0;
            data_in_counter           <= 32'b0;
            data_out_counter          <= 32'b0;
        end
    end
end

endmodule
