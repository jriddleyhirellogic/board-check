/*
 * @file      udp_tx_apb_reg.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      11/11/2025
 *
 * @brief
 *
 * @section changelog
 * - 11/11/2025: Saba Janamian - Initial implementation
 * - 04/13/2025: Steven Knyazher - Added CDC between APB and UDP clocks
 *
 */

module udp_tx_apb_reg #(
    parameter integer APB_DATA_WIDTH = 32,
    parameter integer APB_ADDR_WIDTH = 32
)(
    // APB Slave interface
    input  logic                       pclk,      // APB clock
    input  logic                       presetn,   // APB resetn
    input  logic                       penable,   // APB enable
    input  logic                       psel,      // APB periph select
    input  logic [APB_ADDR_WIDTH-1:0]  paddr,     // APB address bus
    input  logic                       pwrite,    // APB write req
    input  logic [APB_DATA_WIDTH-1:0]  pwdata,    // APB write data
    output logic [APB_DATA_WIDTH-1:0]  prdata,    // APB read data
    output logic                       pready,    // APB ready signal
    output logic                       pslverr,   // APB error signal

    // Destination clock and reset
    input  logic                       udp_clk,   // UDP clock
    input  logic                       udp_rst_n, // UDP reset

    // UDP HEADER
    output logic [15:0]                udp_dst_port,
    output logic [15:0]                udp_src_port,
    output logic                       udp_hdr_valid,
    input logic                        udp_hdr_ready,

    // IPH HEADER
    output logic [31:0]                dst_ip_addr,
    output logic [31:0]                src_ip_addr,
    output logic                       iph_hdr_valid,
    input  logic                       iph_hdr_ready,

    // ETH HEADER
    output logic [47:0]                dst_mac_addr,
    output logic [47:0]                src_mac_addr,
    output logic                       eth_hdr_valid,
    input  logic                       eth_hdr_ready,

    // udp_tx core status
    input  logic [31:0]                wd_timeout_err_count,

    // UDP Control
    output logic [1:0]                 mux_sel,
    output logic                       udp_clr,
    output logic [31:0]                frame_gap

);

//------------------------------------------------------------------------------
// Register address definitions
//------------------------------------------------------------------------------
localparam integer ADDR_UDP_DST_PORT               = 'h00;
localparam integer ADDR_UDP_SRC_PORT               = 'h01;
localparam integer ADDR_DST_IP                     = 'h02;
localparam integer ADDR_SRC_IP                     = 'h03;
localparam integer ADDR_DST_MAC_MSB                = 'h04;
localparam integer ADDR_DST_MAC_LSB                = 'h05;
localparam integer ADDR_SRC_MAC_MSB                = 'h06;
localparam integer ADDR_SRC_MAC_LSB                = 'h07;
localparam integer ADDR_WD_TIMEOUT_ERR_COUNT       = 'h08;
localparam integer ADDR_MUX_SEL                    = 'h09;
localparam integer ADDR_UDP_CLR                    = 'h0A;
localparam integer ADDR_FRAME_GAP                  = 'h0B;

localparam integer NUM_REGS                 = 32; // Can only be 8, 16, 32
localparam integer REG_WIDTH                = $clog2(NUM_REGS);

//------------------------------------------------------------------------------
// Register space
//------------------------------------------------------------------------------
logic [APB_DATA_WIDTH-1:0] mem[NUM_REGS];

//------------------------------------------------------------------------------
// CDC: udp_clk inputs -> pclk domain
//------------------------------------------------------------------------------
logic        udp_hdr_ready_sync[2];
logic        iph_hdr_ready_sync[2];
logic        eth_hdr_ready_sync[2];
logic [31:0] wd_timeout_err_count_sync[2];

always_ff @(posedge pclk or negedge presetn) begin
    if (~presetn) begin
        udp_hdr_ready_sync        <= '{default: 1'b0};
        iph_hdr_ready_sync        <= '{default: 1'b0};
        eth_hdr_ready_sync        <= '{default: 1'b0};
        wd_timeout_err_count_sync <= '{default: 1'b0};
    end else begin
        udp_hdr_ready_sync[0]        <= udp_hdr_ready;
        udp_hdr_ready_sync[1]        <= udp_hdr_ready_sync[0];
        iph_hdr_ready_sync[0]        <= iph_hdr_ready;
        iph_hdr_ready_sync[1]        <= iph_hdr_ready_sync[0];
        eth_hdr_ready_sync[0]        <= eth_hdr_ready;
        eth_hdr_ready_sync[1]        <= eth_hdr_ready_sync[0];
        wd_timeout_err_count_sync[0] <= wd_timeout_err_count;
        wd_timeout_err_count_sync[1] <= wd_timeout_err_count_sync[0];
    end
end

//------------------------------------------------------------------------------
// Output controler (pclk domain)
//------------------------------------------------------------------------------
logic [15:0] udp_dst_port_src;
logic [15:0] udp_src_port_src;
logic        udp_hdr_valid_src;
logic [31:0] dst_ip_addr_src;
logic [31:0] src_ip_addr_src;
logic        iph_hdr_valid_src;
logic [47:0] dst_mac_addr_src;
logic [47:0] src_mac_addr_src;
logic        eth_hdr_valid_src;
logic [1:0]  mux_sel_src;
logic        udp_clr_src;
logic [31:0] frame_gap_src;

//------------------------------------------------------------------------------
// CDC: pclk inputs -> udp_clk domain
//------------------------------------------------------------------------------
logic [15:0] udp_dst_port_sync[2];
logic [15:0] udp_src_port_sync[2];
logic        udp_hdr_valid_sync[2];
logic [31:0] dst_ip_addr_sync[2];
logic [31:0] src_ip_addr_sync[2];
logic        iph_hdr_valid_sync[2];
logic [47:0] dst_mac_addr_sync[2];
logic [47:0] src_mac_addr_sync[2];
logic        eth_hdr_valid_sync[2];
logic [1:0]  mux_sel_sync[2];
logic        udp_clr_sync[2];
logic [31:0] frame_gap_sync[2];

always_ff @(posedge udp_clk or negedge udp_rst_n) begin
    if (~udp_rst_n) begin
        udp_dst_port_sync  <= '{default: 1'b0};
        udp_src_port_sync  <= '{default: 1'b0};
        udp_hdr_valid_sync <= '{default: 1'b0};
        dst_ip_addr_sync   <= '{default: 1'b0};
        src_ip_addr_sync   <= '{default: 1'b0};
        iph_hdr_valid_sync <= '{default: 1'b0};
        dst_mac_addr_sync  <= '{default: 1'b0};
        src_mac_addr_sync  <= '{default: 1'b0};
        eth_hdr_valid_sync <= '{default: 1'b0};
        mux_sel_sync       <= '{default: 1'b0};
        udp_clr_sync       <= '{default: 1'b0};
        frame_gap_sync     <= '{default: 1'b0};
    end else begin
        udp_dst_port_sync[0]  <= udp_dst_port_src;
        udp_dst_port_sync[1]  <= udp_dst_port_sync[0];
        udp_src_port_sync[0]  <= udp_src_port_src;
        udp_src_port_sync[1]  <= udp_src_port_sync[0];
        udp_hdr_valid_sync[0] <= udp_hdr_valid_src;
        udp_hdr_valid_sync[1] <= udp_hdr_valid_sync[0];
        dst_ip_addr_sync[0]   <= dst_ip_addr_src;
        dst_ip_addr_sync[1]   <= dst_ip_addr_sync[0];
        src_ip_addr_sync[0]   <= src_ip_addr_src;
        src_ip_addr_sync[1]   <= src_ip_addr_sync[0];
        iph_hdr_valid_sync[0] <= iph_hdr_valid_src;
        iph_hdr_valid_sync[1] <= iph_hdr_valid_sync[0];
        dst_mac_addr_sync[0]  <= dst_mac_addr_src;
        dst_mac_addr_sync[1]  <= dst_mac_addr_sync[0];
        src_mac_addr_sync[0]  <= src_mac_addr_src;
        src_mac_addr_sync[1]  <= src_mac_addr_sync[0];
        eth_hdr_valid_sync[0] <= eth_hdr_valid_src;
        eth_hdr_valid_sync[1] <= eth_hdr_valid_sync[0];
        mux_sel_sync[0]       <= mux_sel_src;
        mux_sel_sync[1]       <= mux_sel_sync[0];
        udp_clr_sync[0]       <= udp_clr_src;
        udp_clr_sync[1]       <= udp_clr_sync[0];
        frame_gap_sync[0]     <= frame_gap_src;
        frame_gap_sync[1]     <= frame_gap_sync[0];
    end
end

//------------------------------------------------------------------------------
// APB write and read register logic
//------------------------------------------------------------------------------
always_ff @(posedge pclk or negedge presetn) begin
    if(~presetn) begin
        prdata        <= 'b0;
        pready        <= 'b0;
        pslverr       <= 'b0;
        mem           <= '{default: 1'b0};

    end else begin
        pslverr <= 'b0; // Not used

        // Read only registers update
        mem[ADDR_WD_TIMEOUT_ERR_COUNT] <= wd_timeout_err_count_sync[1];

        // APB Write operation
        if(psel && penable && pwrite && paddr[1:0] == 'b0) begin
            prdata  <= 'b0;
            pready  <= 'b1;  // Indicate done

            case(paddr[6:2])
                ADDR_UDP_DST_PORT: begin
                    mem[ADDR_UDP_DST_PORT] <= {16'b0, pwdata[15:0]};
                end

                ADDR_UDP_SRC_PORT: begin
                    mem[ADDR_UDP_SRC_PORT] <= {16'b0, pwdata[15:0]};
                end

                ADDR_DST_IP: begin
                    mem[ADDR_DST_IP]       <= pwdata[31:0];
                end

                ADDR_SRC_IP: begin
                    mem[ADDR_SRC_IP]       <= pwdata[31:0];
                end

                ADDR_DST_MAC_MSB: begin
                    mem[ADDR_DST_MAC_MSB]  <= pwdata[15:0];
                end

                ADDR_DST_MAC_LSB: begin
                    mem[ADDR_DST_MAC_LSB]  <= pwdata[31:0];
                end

                ADDR_SRC_MAC_MSB: begin
                    mem[ADDR_SRC_MAC_MSB]  <= pwdata[15:0];
                end

                ADDR_SRC_MAC_LSB: begin
                    mem[ADDR_SRC_MAC_LSB]  <= pwdata[31:0];
                end

                ADDR_WD_TIMEOUT_ERR_COUNT: begin
                    // Read only
                end

                ADDR_MUX_SEL: begin
                    mem[ADDR_MUX_SEL]       <= pwdata[1:0];
                end

                ADDR_UDP_CLR: begin
                    mem[ADDR_UDP_CLR]      <= pwdata[0:0];
                end

                ADDR_FRAME_GAP: begin
                    mem[ADDR_FRAME_GAP]     <= pwdata[31:0];
                end

                default: begin
                    pslverr                 <= 'b0;
                end
            endcase

        // APB READ operation
        end else if(psel && penable && !pwrite && paddr[1:0] == 'b0) begin
            pready <= 'b1; // Indicate done

            case(paddr[6:2])
                ADDR_UDP_DST_PORT: begin
                    prdata <= {16'b0, mem[ADDR_UDP_DST_PORT][15:0]};
                end

                ADDR_UDP_SRC_PORT: begin
                    prdata <= {16'b0, mem[ADDR_UDP_SRC_PORT][15:0]};
                end

                ADDR_DST_IP: begin
                    prdata <= mem[ADDR_DST_IP];
                end

                ADDR_SRC_IP: begin
                    prdata <= mem[ADDR_SRC_IP];
                end

                ADDR_DST_MAC_MSB: begin
                    prdata <= {16'b0, mem[ADDR_DST_MAC_MSB][15:0]};
                end

                ADDR_DST_MAC_LSB: begin
                    prdata <= mem[ADDR_DST_MAC_LSB];
                end

                ADDR_SRC_MAC_MSB: begin
                    prdata <= {16'b0, mem[ADDR_SRC_MAC_MSB][15:0]};
                end

                ADDR_SRC_MAC_LSB: begin
                    prdata <= mem[ADDR_SRC_MAC_LSB];
                end

                ADDR_WD_TIMEOUT_ERR_COUNT: begin
                    prdata <= mem[ADDR_WD_TIMEOUT_ERR_COUNT];
                end

                ADDR_MUX_SEL: begin
                    prdata <= {30'b0, mem[ADDR_MUX_SEL][1:0]};
                end

                ADDR_UDP_CLR: begin
                    prdata <= {31'b0, mem[ADDR_UDP_CLR][0:0]};
                end

                ADDR_FRAME_GAP: begin
                    prdata <= mem[ADDR_FRAME_GAP];
                end

                default: begin
                    pslverr    <= 'b0;
                end
            endcase

        end else begin
            pready             <= 'b0;
            prdata             <= 'b0;
            pslverr            <= 'b0;
        end
    end
end

//------------------------------------------------------------------------------
// Output controler (pclk domain)
//------------------------------------------------------------------------------
always_ff @(posedge pclk or negedge presetn) begin
    if(~presetn) begin
        udp_dst_port_src  <= 'b0;
        udp_src_port_src  <= 'b0;
        udp_hdr_valid_src <= 'b0;
        dst_ip_addr_src   <= 'b0;
        src_ip_addr_src   <= 'b0;
        iph_hdr_valid_src <= 'b0;
        dst_mac_addr_src  <= 'b0;
        src_mac_addr_src  <= 'b0;
        eth_hdr_valid_src <= 'b0;
        mux_sel_src       <= 'b0;
        udp_clr_src       <= 'b0;
        frame_gap_src     <= 'b0;

    end else begin

        mux_sel_src       <= mem[ADDR_MUX_SEL][1:0];
        udp_clr_src       <= mem[ADDR_UDP_CLR][0];
        frame_gap_src     <= mem[ADDR_FRAME_GAP];

        if(udp_hdr_ready_sync[1]) begin
            udp_dst_port_src  <= mem[ADDR_UDP_DST_PORT][15:0];
            udp_src_port_src  <= mem[ADDR_UDP_SRC_PORT][15:0];
            udp_hdr_valid_src <= 1'b1;
        end

        if(iph_hdr_ready_sync[1]) begin
            dst_ip_addr_src   <= mem[ADDR_DST_IP];
            src_ip_addr_src   <= mem[ADDR_SRC_IP];
            iph_hdr_valid_src <= 1'b1;
        end

        if(eth_hdr_ready_sync[1]) begin
            dst_mac_addr_src  <= {mem[ADDR_DST_MAC_MSB][15:0], mem[ADDR_DST_MAC_LSB]};
            src_mac_addr_src  <= {mem[ADDR_SRC_MAC_MSB][15:0], mem[ADDR_SRC_MAC_LSB]};
            eth_hdr_valid_src <= 1'b1;
        end

    end
end

//------------------------------------------------------------------------------
// Output port assignments from udp_clk CDC
//------------------------------------------------------------------------------
assign udp_dst_port  = udp_dst_port_sync[1];
assign udp_src_port  = udp_src_port_sync[1];
assign udp_hdr_valid = udp_hdr_valid_sync[1];
assign dst_ip_addr   = dst_ip_addr_sync[1];
assign src_ip_addr   = src_ip_addr_sync[1];
assign iph_hdr_valid = iph_hdr_valid_sync[1];
assign dst_mac_addr  = dst_mac_addr_sync[1];
assign src_mac_addr  = src_mac_addr_sync[1];
assign eth_hdr_valid = eth_hdr_valid_sync[1];
assign mux_sel       = mux_sel_sync[1];
assign udp_clr       = udp_clr_sync[1];
assign frame_gap     = frame_gap_sync[1];

endmodule
