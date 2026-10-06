/*
 * @file      width_down_conv.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      10/28/2025
 * 
 * @brief     Width Down Converter. This design allows for converting the
 *            receive data down n times to transmit data.
 * 
 * @section changelog
 * - 10/28/2025: Steven Knyazher - Initial implementation
 * 
 */

module width_down_conv #(
    parameter RX_DATA_WIDTH = 128,
    parameter TX_DATA_WIDTH = 32
)(
    input  logic                               clk,
    input  logic                               rst_n,
    
    output logic                               rxacpt,
    input  logic                               rxrdy,
    input  logic [RX_DATA_WIDTH-1:0]           rxdata,
    input  logic                               rxeof,
    input  logic [$clog2(RX_DATA_WIDTH/8):0]   rxbytevalid,
    input  logic                               rxsof,

    input  logic                               txacpt,
    output logic                               txrdy,
    output logic [TX_DATA_WIDTH-1:0]           txdata,
    output logic                               txeof,
    output logic [$clog2(TX_DATA_WIDTH/8)-1:0] txbytevalid,
    output logic                               txsof
);

    `define SWAP_WRD_OCTETS(word) \
        {word[0 +: 8], word[8 +: 8], word[16 +: 8], word[24 +: 8]};

    localparam int RATIO = RX_DATA_WIDTH / TX_DATA_WIDTH;
    initial begin
        if (RX_DATA_WIDTH % TX_DATA_WIDTH != 0) begin
            $fatal("RX_DATA_WIDTH (%0d) must be an integer multiple of TX_DATA_WIDTH (%0d)", RX_DATA_WIDTH, TX_DATA_WIDTH);
        end
    end

    logic [RX_DATA_WIDTH-1:0]         buffer;
    logic [TX_DATA_WIDTH-1:0]         swapped_data;
    logic [$clog2(RATIO):0]           count;
    logic [$clog2(RATIO):0]           max_count;
    logic                             sof_pending;
    logic                             eof_pending;
    logic [$clog2(RX_DATA_WIDTH/8):0] remaining_bytes;
    
    logic [$clog2(RATIO):0]           next_count;
    logic                             tx_completing;
    logic                             rx_accepting;
    logic [$clog2(TX_DATA_WIDTH/8):0] current_bytevalid;
    
    assign tx_completing = txrdy && txacpt;
    assign rx_accepting  = rxacpt && rxrdy;
    
    always_comb begin
        if (rx_accepting && tx_completing && (count == max_count)) begin
            next_count = 1;
        end else if (rx_accepting) begin
            next_count = 1;
        end else if (tx_completing && (count == max_count)) begin
            next_count = 0;
        end else if (tx_completing) begin
            next_count = count + 1;
        end else begin
            next_count = count;
        end
    end
    
    assign rxacpt       = (count == 0) || (tx_completing && (count == max_count));

    assign txrdy        = (count > 0) && (count <= max_count);

    assign swapped_data = (count > 0) ? buffer[(RATIO-count)*TX_DATA_WIDTH +: TX_DATA_WIDTH] : '0;
    assign txdata       = `SWAP_WRD_OCTETS(swapped_data);
    assign txsof        = sof_pending && (count == 1);
    assign txeof        = eof_pending && (count == max_count);
    
    always_comb begin
        if (txeof) begin
            current_bytevalid = remaining_bytes - (count-1) * (TX_DATA_WIDTH/8);
            if (current_bytevalid > TX_DATA_WIDTH/8) begin
                current_bytevalid = TX_DATA_WIDTH/8;
            end
        end else begin
            current_bytevalid = TX_DATA_WIDTH/8;
        end
    end
    
    assign txbytevalid = TX_DATA_WIDTH/8 - current_bytevalid;

    always_ff @(posedge clk, negedge rst_n) begin
        if (~rst_n) begin
            count           <= 0;
            max_count       <= 0;
            buffer          <= '0;
            sof_pending     <= 0;
            eof_pending     <= 0;
            remaining_bytes <= 0;
        end else begin
            if (rx_accepting) begin
                buffer          <= rxdata;
                remaining_bytes <= rxbytevalid;
                sof_pending     <= rxsof;
                eof_pending     <= rxeof;
                
                if (rxeof) begin
                    max_count <= (rxbytevalid + TX_DATA_WIDTH/8 - 1) / (TX_DATA_WIDTH/8);
                end else begin
                    max_count <= RATIO;
                end
            end
            
            count <= next_count;
        end
    end

endmodule