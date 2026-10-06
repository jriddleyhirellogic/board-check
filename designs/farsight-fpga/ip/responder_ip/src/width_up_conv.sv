/*
 * @file      width_up_conv.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      10/28/2025
 * 
 * @brief     Width Up Converter. This design allows for converting the
 *            receive data up n times to transmit data.
 * 
 * @section changelog
 * - 10/28/2025: Steven Knyazher - Initial implementation
 * 
 */

module width_up_conv #(
    parameter RX_DATA_WIDTH = 32,
    parameter TX_DATA_WIDTH = 128
)(
    input  logic                               clk,
    input  logic                               rst_n,
    
    output logic                               rxacpt,
    input  logic                               rxrdy,
    input  logic [RX_DATA_WIDTH-1:0]           rxdata,
    input  logic                               rxeof,
    input  logic [$clog2(RX_DATA_WIDTH/8)-1:0] rxbytevalid,
    input  logic                               rxsof,

    input  logic                               txacpt,
    output logic                               txrdy,
    output logic [TX_DATA_WIDTH-1:0]           txdata,
    output logic                               txeof,
    output logic [$clog2(TX_DATA_WIDTH/8):0]   txbytevalid,
    output logic                               txsof
);

    `define SWAP_WRD_OCTETS(word) \
        {word[0 +: 8], word[8 +: 8], word[16 +: 8], word[24 +: 8]};

    localparam int RATIO = TX_DATA_WIDTH / RX_DATA_WIDTH;
    initial begin
        if (TX_DATA_WIDTH % RX_DATA_WIDTH != 0) begin
            $fatal("TX_DATA_WIDTH (%0d) must be an integer multiple of RX_DATA_WIDTH (%0d)", TX_DATA_WIDTH, RX_DATA_WIDTH);
        end
    end
    
    logic [$clog2(RX_DATA_WIDTH/8):0] rxbytevalid_corrected;
    assign rxbytevalid_corrected = RX_DATA_WIDTH/8 - rxbytevalid;

    logic [TX_DATA_WIDTH-1:0]         buffer;
    logic [$clog2(RATIO):0]           count;
    logic                             sof_pending;
    logic                             eof_pending;
    logic [$clog2(TX_DATA_WIDTH/8):0] last_bytevalid;
    
    logic [$clog2(RATIO):0]           next_count;
    logic                             tx_completing;
    logic                             rx_accepting;
    
    assign tx_completing = txrdy && txacpt;
    assign rx_accepting  = rxacpt && rxrdy;
    
    always_comb begin
        if (tx_completing && rx_accepting) begin
            next_count = 1;
        end else if (tx_completing) begin
            next_count = 0;
        end else if (rx_accepting) begin
            next_count = count + 1;
        end else begin
            next_count = count;
        end
    end
    
    assign rxacpt = (count < RATIO) || tx_completing;

    assign txrdy = (count == RATIO) || eof_pending;

    assign txdata      = buffer;
    assign txsof       = sof_pending;
    assign txeof       = eof_pending;
    assign txbytevalid = txeof ? last_bytevalid : (TX_DATA_WIDTH/8);

    always_ff @(posedge clk, negedge rst_n) begin
        if (~rst_n) begin
            count          <= 0;
            buffer         <= '0;
            sof_pending    <= 0;
            eof_pending    <= 0;
            last_bytevalid <= 0;
        end else begin
            if (tx_completing) begin
                buffer         <= '0;
                sof_pending    <= 0;
                eof_pending    <= 0;
                last_bytevalid <= 0;
            end
            
            if (rx_accepting) begin
                buffer[(RATIO-next_count)*RX_DATA_WIDTH +: RX_DATA_WIDTH] <= `SWAP_WRD_OCTETS(rxdata);
                
                if (tx_completing) begin
                    last_bytevalid <= rxbytevalid_corrected;
                end else begin
                    last_bytevalid <= last_bytevalid + rxbytevalid_corrected;
                end

                if (rxsof) begin
                    sof_pending <= 1'b1;
                end

                if (rxeof) begin
                    eof_pending <= 1'b1;
                end
            end
            
            count <= next_count;
        end
    end

endmodule