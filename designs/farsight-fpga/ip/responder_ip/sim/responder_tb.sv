/*
 * @file      responder_tb.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      10/28/2025
 * 
 * @brief     Responder Testbench.
 * 
 * @section changelog
 * - 10/28/2025: Steven Knyazher - Initial implementation
 * 
 */

`timescale 1ns/100ps

module responder_tb;

    // Parameters
    localparam int CLOCK_FREQ_MHZ = 50;
    localparam int PHY_INIT_USEC  = 100;
    localparam int DATA_WIDTH     = 128;
    localparam int MAC_WIDTH      = 48;
    localparam int IPV4_WIDTH     = 32;

    // DUT signals
    logic                          clk;
    logic                          rst_n;
    logic                          src_mac_valid;
    logic [MAC_WIDTH-1:0]          src_mac_addr;
    logic                          src_ipv4_valid;
    logic [IPV4_WIDTH-1:0]         src_ipv4_addr;
    logic                          rxacpt;
    logic                          rxrdy;
    logic [DATA_WIDTH-1:0]         rxdata;
    logic                          rxeof;
    logic [$clog2(DATA_WIDTH/8):0] rxbytevalid;
    logic                          rxsof;
    logic                          txacpt;
    logic                          txrdy;
    logic [DATA_WIDTH-1:0]         txdata;
    logic                          txeof;
    logic [$clog2(DATA_WIDTH/8):0] txbytevalid;
    logic                          txsof;
    logic                          core_busy;

    // Instantiate DUT
    responder #(
        // Initialization configs
        .CLOCK_FREQ_MHZ (CLOCK_FREQ_MHZ),
        .PHY_INIT_USEC  (PHY_INIT_USEC),
        .DATA_WIDTH     (DATA_WIDTH),
        .MAC_WIDTH      (MAC_WIDTH),
        .IPV4_WIDTH     (IPV4_WIDTH)
    ) dut (
        // Input data clock
        .clk            (clk),
        .rst_n          (rst_n),

        // Ethernet header
        .src_mac_valid  (src_mac_valid),
        .src_mac_addr   (src_mac_addr),
        
        // IPv4 header
        .src_ipv4_valid (src_ipv4_valid),
        .src_ipv4_addr  (src_ipv4_addr),

        // RX side
        .rxacpt         (rxacpt),
        .rxrdy          (rxrdy),
        .rxdata         (rxdata),
        .rxeof          (rxeof),
        .rxbytevalid    (rxbytevalid),
        .rxsof          (rxsof),

        // TX side
        .txacpt         (txacpt),
        .txrdy          (txrdy),
        .txdata         (txdata),
        .txeof          (txeof),
        .txbytevalid    (txbytevalid),
        .txsof          (txsof),

        .core_busy      (core_busy)
    );

    localparam time CP = 20ns;

    // Clock generation
    initial clk = 0;
    always #(CP/2) clk = ~clk;

    // Reset
    initial begin
        rst_n = 0;
        #(CP*5);
        rst_n = 1;
    end

    // RX stimulus task
    task send_rx_word(
        input logic [DATA_WIDTH-1:0] data,
        input logic                  sof,
        input logic                  eof,
        input int                    valid_bytes
    );
        begin
            // Drive inputs
            rxdata      = data;
            rxsof       = sof;
            rxeof       = eof;
            rxbytevalid = valid_bytes;
            rxrdy       = 1'b1;

            // Wait until rxacpt goes high while rxrdy is asserted
            forever begin
                @(posedge clk);
                if (rxacpt) begin
                    // Word accepted, now deassert control
                    rxrdy       = 1'b0;
                    rxsof       = 1'b0;
                    rxeof       = 1'b0;
                    rxbytevalid = 0;
                    break;
                end
            end

            // Once accepted, deassert rxrdy and control signals
            rxrdy       = 1'b0;
            rxsof       = 1'b0;
            rxeof       = 1'b0;
            rxbytevalid = 0;
        end
    endtask

    // TX monitor
    always_ff @(posedge clk) begin
        if (rst_n && txrdy && txacpt) begin
            $display("[%0t] TX word: %h sof=%0b eof=%0b bytevalid=%0d",
                     $time, txdata, txsof, txeof, txbytevalid);
        end
    end

    // TX accept always ready
    initial txacpt = 1'b1;

    // Set RX to 0s initially
    initial rxrdy = 1'b0;
    initial rxdata = 'b0;
    initial rxeof = 1'b0;
    initial rxbytevalid = 'b0;
    initial rxsof = 1'b0;

    // Set source MAC and IPv4 addresses
    initial src_mac_valid  = 1'b1;
    initial src_ipv4_valid = 1'b1;
    initial src_mac_addr   = 48'h0004A3123456;
    initial src_ipv4_addr  = 32'h0A650FC0;

    // Test sequence
    initial begin
        // Wait for reset
        wait(rst_n);
        @(posedge clk);

        #100100
        @(posedge clk);
        
        $display("[%0t] Starting test...", $time);
        
        send_rx_word(128'hffffffffffff00249b8beb3608060001, 1'b1, 1'b0, 16);
        send_rx_word(128'h08000604000100249b8beb360a650fc3, 1'b0, 1'b0, 16);
        send_rx_word(128'h0000000000000A650FC0000000000000, 1'b0, 1'b1, 10);
        
        repeat (5) @(posedge clk);

        send_rx_word(128'h0004A312345600249b8beb3608004500, 1'b1, 1'b0, 16);
        send_rx_word(128'h0054645c400040010afd0a650fc30A65, 1'b0, 1'b0, 16);
        send_rx_word(128'h0FC0080012fb79d70002b4ad03690000, 1'b0, 1'b0, 16);
        send_rx_word(128'h0000eb41090000000000101112131415, 1'b0, 1'b0, 16);
        send_rx_word(128'h161718191a1b1c1d1e1f202122232425, 1'b0, 1'b0, 16);
        send_rx_word(128'h262728292a2b2c2d2e2f303132333435, 1'b0, 1'b0, 16);
        send_rx_word(128'h36370000000000000000000000000000, 1'b0, 1'b1, 2);

        // Finish
        repeat (10) @(posedge clk);
        $display("[%0t] Test completed.", $time);
    end

endmodule