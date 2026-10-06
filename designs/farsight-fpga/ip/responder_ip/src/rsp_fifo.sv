/*
 * @file      rsp_fifo.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      10/28/2025
 * 
 * @brief     Responder FIFO. This module buffers receive data and sends it to transmit data.
 *            The module has been taylored to work with the Responder.
 * 
 * @section changelog
 * - 10/28/2025: Steven Knyazher - Initial implementation
 * 
 */

`timescale 1ns/100ps

module rsp_fifo #(
    // Initialization configs
    parameter DATA_WIDTH = 128
) (
    // Input data clock
    input  logic                          clk,
    input  logic                          rst_n,

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
    output logic                          txsof
);

    localparam DEPTH = 16;
    localparam ADDR_WIDTH = $clog2(DEPTH);

    // FIFO storage
    logic [DATA_WIDTH-1:0]         data_mem      [DEPTH];
    logic                          eof_mem       [DEPTH];
    logic [$clog2(DATA_WIDTH/8):0] bytevalid_mem [DEPTH];
    logic                          sof_mem       [DEPTH];

    // Pointers
    logic [ADDR_WIDTH-1:0] wr_ptr;
    logic [ADDR_WIDTH-1:0] rd_ptr;
    logic [ADDR_WIDTH:0]   count;
    
    // Timeout counter for full condition
    logic [15:0] full_timeout_counter;
    logic timeout_reset;
    
    // Status signals
    logic empty;
    logic full;
    assign empty = (count == 0);
    assign full  = (count == DEPTH);
    
    // Timeout reset occurs when counter reaches all 1's
    assign timeout_reset = (full_timeout_counter == 16'hFFFF);
    
    // Write control
    logic wr_en;
    assign rxacpt = ~full;
    assign wr_en  = rxrdy && rxacpt;
    
    // Read control
    logic rd_en;
    assign txrdy = ~empty;
    assign rd_en = txacpt && txrdy;
    
    // Full timeout counter - counts when FIFO is full
    always_ff @(posedge clk, negedge rst_n) begin
        if (~rst_n) begin
            full_timeout_counter <= '0;
        end else if (timeout_reset) begin
            full_timeout_counter <= '0;
        end else if (full) begin
            full_timeout_counter <= full_timeout_counter + 1;
        end else begin
            full_timeout_counter <= '0;
        end
    end
    
    // FIFO write
    always_ff @(posedge clk, negedge rst_n) begin
        if (~rst_n) begin
            wr_ptr <= '0;
        end else if (timeout_reset) begin
            wr_ptr <= '0;
        end else if (wr_en) begin
            data_mem[wr_ptr]      <= rxdata;
            eof_mem[wr_ptr]       <= rxeof;
            bytevalid_mem[wr_ptr] <= rxbytevalid;
            sof_mem[wr_ptr]       <= rxsof;
            wr_ptr                <= wr_ptr + 1;
            if (wr_ptr == DEPTH-1) begin
                wr_ptr <= '0;
            end
        end
    end
    
    // FIFO read
    always_ff @(posedge clk, negedge rst_n) begin
        if (~rst_n) begin
            rd_ptr <= '0;
        end else if (timeout_reset) begin
            rd_ptr <= '0;
        end else if (rd_en) begin
            rd_ptr <= rd_ptr + 1;
            if (rd_ptr == DEPTH-1) begin
                rd_ptr <= '0;
            end
        end
    end
    
    // Count management
    always_ff @(posedge clk, negedge rst_n) begin
        if (~rst_n) begin
            count <= '0;
        end else if (timeout_reset) begin
            count <= '0;
        end else begin
            case ({wr_en, rd_en})
                2'b10:   count <= count + 1;
                2'b01:   count <= count - 1;
                default: count <= count;
            endcase
        end
    end
    
    // Output assignments
    assign txdata      = data_mem[rd_ptr];
    assign txsof       = sof_mem[rd_ptr];
    assign txeof       = eof_mem[rd_ptr];
    assign txbytevalid = bytevalid_mem[rd_ptr];

endmodule