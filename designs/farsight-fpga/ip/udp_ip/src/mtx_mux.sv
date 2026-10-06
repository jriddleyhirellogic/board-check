/*
 * @file      mtx_mux.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      12/22/2025
 *
 * @brief     Muxing the MAC Tx output between ARP Responder and UDP Tx core
 *
 * @section changelog
 * - 12/22/2025: Saba Janamian - Initial implementation
 *
 */

module mtx_mux(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        udp_core_busy,
    input  logic        arp_core_busy,

    input  logic [1:0]  udp_txbytevalid,
    input  logic [31:0] udp_txdata,
    input  logic        udp_txeof,
    input  logic        udp_txrdy,
    input  logic        udp_txsof,
    output logic        udp_txacpt,

    input  logic [1:0]  arp_txbytevalid,
    input  logic [31:0] arp_txdata,
    input  logic        arp_txeof,
    input  logic        arp_txrdy,
    input  logic        arp_txsof,
    output logic        arp_txacpt,

    output logic [1:0]  MTXBYTEVALID,
    output logic [31:0] MTXDAT,
    output logic        MTXEOF,
    output logic        MTXRDY,
    output logic        MTXSOF,
    input  logic        MTXACPT
);

//------------------------------------------------------------------------------
// FSM States
//------------------------------------------------------------------------------
typedef enum logic [1:0] {
    UDP_ACTIVE = 'd0,
    ARP_DRAIN  = 'd1,
    ARP_ACTIVE = 'd2,
    ARP_ABORT  = 'd3
 } state_t;

state_t curr_state;
state_t next_state;

//------------------------------------------------------------------------------
// Register to track if we're in the middle of an ARP packet
//------------------------------------------------------------------------------
logic arp_packet_active;

//------------------------------------------------------------------------------
// FSM sequential logic
//------------------------------------------------------------------------------
always_ff @(posedge clk, negedge rst_n) begin
    if(~rst_n) begin
        curr_state           <= UDP_ACTIVE;
        MTXBYTEVALID         <= 'b0;
        MTXDAT               <= 'b0;
        MTXEOF               <= 'b0;
        MTXRDY               <= 'b0;
        MTXSOF               <= 'b0;
        arp_txacpt           <= 'b0;
        udp_txacpt           <= 'b0;
        arp_packet_active    <= 'b0;

    end else begin

        curr_state <= next_state;

        if (arp_txsof) begin
            arp_packet_active <= 1'b1;
        end else if (arp_txeof) begin
            arp_packet_active <= 1'b0;
        end

        if (curr_state == UDP_ACTIVE) begin
            MTXBYTEVALID     <= udp_txbytevalid;
            MTXDAT           <= udp_txdata;
            MTXEOF           <= udp_txeof;
            MTXRDY           <= udp_txrdy;
            MTXSOF           <= udp_txsof;
            udp_txacpt       <= MTXACPT;
            arp_txacpt       <= 'b1;

        end else if (curr_state == ARP_DRAIN) begin
            MTXBYTEVALID     <= 'b0;
            MTXDAT           <= 'b0;
            MTXEOF           <= 'b0;
            MTXRDY           <= 'b0;
            MTXSOF           <= 'b0;
            arp_txacpt       <= 'b1;
            udp_txacpt       <= 'b0;

        end else if (curr_state == ARP_ACTIVE) begin
            MTXBYTEVALID     <= arp_txbytevalid;
            MTXDAT           <= arp_txdata;
            MTXEOF           <= arp_txeof;
            MTXRDY           <= arp_txrdy;
            MTXSOF           <= arp_txsof;
            arp_txacpt       <= MTXACPT;
            udp_txacpt       <= 'b0;

        end else if (curr_state == ARP_ABORT) begin
            MTXBYTEVALID     <= arp_txbytevalid;
            MTXDAT           <= arp_txdata;
            MTXEOF           <= 1'b1;
            MTXRDY           <= arp_txrdy;
            MTXSOF           <= arp_txsof;
            arp_txacpt       <= MTXACPT;
            udp_txacpt       <= 'b0;

        end else begin
            MTXBYTEVALID     <= 'b0;
            MTXDAT           <= 'b0;
            MTXEOF           <= 'b0;
            MTXRDY           <= 'b0;
            MTXSOF           <= 'b0;
            arp_txacpt       <= 'b0;
            udp_txacpt       <= 'b0;

        end
    end
end

//------------------------------------------------------------------------------
// FSM combinational logic
//------------------------------------------------------------------------------
always_comb begin

    next_state = curr_state;

    case(curr_state)

        UDP_ACTIVE: begin
            if (~udp_core_busy && arp_core_busy) begin
                if (arp_txsof || arp_packet_active) begin
                    next_state = ARP_DRAIN;
                end else begin
                    next_state = ARP_ACTIVE;
                end
            end else begin
                next_state = UDP_ACTIVE;
            end
        end

        ARP_DRAIN: begin
            if (udp_core_busy) begin
                next_state = UDP_ACTIVE;
            end else if (arp_txeof) begin
                next_state = ARP_ACTIVE;
            end else if (~arp_core_busy) begin
                next_state = UDP_ACTIVE;
            end else begin
                next_state = ARP_DRAIN;
            end
        end

        ARP_ACTIVE: begin
            if (udp_core_busy && arp_core_busy) begin
                next_state = ARP_ABORT;
            end else if (arp_core_busy) begin
                next_state = ARP_ACTIVE;
            end else begin
                next_state = UDP_ACTIVE;
            end
        end

        ARP_ABORT: begin
            next_state = UDP_ACTIVE;
        end

        default: begin
            next_state = UDP_ACTIVE;
        end

    endcase
end

endmodule
