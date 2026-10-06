/*
 * @file      pcie_translator_fifo.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      03/30/2026
 *
 * @brief     Async FIFO - gray-code pointers with rd_clk-domain read memory.
 *
 * @section changelog
 * - 03/30/2026: Steven Knyazher - Initial implementation
 *
 */

module pcie_translator_fifo #(
    parameter int WIDTH = 8,
    parameter int DEPTH = 16
) (
    input  logic             wr_clk,
    input  logic             wr_rst_n,
    input  logic             wr_en,
    input  logic [WIDTH-1:0] wr_data,
    output logic             full,

    input  logic             rd_clk,
    input  logic             rd_rst_n,
    input  logic             rd_en,
    output logic [WIDTH-1:0] rd_data,
    output logic             empty
);

    localparam ADDR_W = $clog2(DEPTH);
    localparam PTR_W  = ADDR_W + 1;

    logic [WIDTH-1:0] wr_mem [0:DEPTH-1];

    // Written by the copy engine; all reads are in rd_clk domain — no cross-domain data hazard.
    logic [WIDTH-1:0] rd_mem [0:DEPTH-1];

    logic [PTR_W-1:0] wp_bin;
    logic [PTR_W-1:0] wp_gray;

    logic [PTR_W-1:0] rp_bin;
    logic [PTR_W-1:0] rp_gray;

    logic [PTR_W-1:0] wp_sync0;
    logic [PTR_W-1:0] wp_sync1;
    logic [PTR_W-1:0] rp_sync0;
    logic [PTR_W-1:0] rp_sync1;

    logic [PTR_W-1:0] copy_ptr;
    // Delayed one cycle so empty de-asserts only after rd_mem is written,
    // preventing a write-then-read hazard on the LSRAM B port.
    logic [PTR_W-1:0] copy_ptr_d;

    logic [PTR_W-1:0] wp_sync1_bin;

    always_ff @(posedge wr_clk, negedge wr_rst_n) begin
        if (~wr_rst_n) begin
            wp_bin  <= '0;
            wp_gray <= '0;
        end else if (wr_en && ~full) begin
            wr_mem[wp_bin[ADDR_W-1:0]] <= wr_data;
            wp_bin                     <= wp_bin + 1'b1;
            wp_gray                    <= (wp_bin + 1'b1) ^ ((wp_bin + 1'b1) >> 1);
        end
    end

    // Registered output; copy_ptr_d ensures rd_mem is stable before rd_data is consumed.
    always_ff @(posedge rd_clk, negedge rd_rst_n) begin
        if (~rd_rst_n) begin
            rd_data <= '0;
        end else begin
            rd_data <= rd_mem[rp_bin[ADDR_W-1:0]];
        end
    end

    always_ff @(posedge rd_clk, negedge rd_rst_n) begin
        if (~rd_rst_n) begin
            rp_bin  <= '0;
            rp_gray <= '0;
        end else if (rd_en && ~empty) begin
            rp_bin  <= rp_bin + 1'b1;
            rp_gray <= (rp_bin + 1'b1) ^ ((rp_bin + 1'b1) >> 1);
        end
    end

    always_ff @(posedge rd_clk, negedge rd_rst_n) begin
        if (~rd_rst_n) begin
            { wp_sync1, wp_sync0 } <= '0;
        end else begin
            { wp_sync1, wp_sync0 } <= { wp_sync0, wp_gray };
        end
    end

    always_ff @(posedge wr_clk, negedge wr_rst_n) begin
        if (~wr_rst_n) begin
            { rp_sync1, rp_sync0 } <= '0;
        end else begin
            { rp_sync1, rp_sync0 } <= { rp_sync0, rp_gray };
        end
    end

    always_comb begin
        wp_sync1_bin[PTR_W-1] = wp_sync1[PTR_W-1];
        for (int i = PTR_W-2; i >= 0; i--) begin
            wp_sync1_bin[i] = wp_sync1_bin[i+1] ^ wp_sync1[i];
        end
    end

    // Copy engine: forwards wr_mem → rd_mem one entry per rd_clk cycle.
    // wp_sync1 guarantees wr_mem[copy_ptr] has been stable for ≥2 rd_clk cycles.
    always_ff @(posedge rd_clk, negedge rd_rst_n) begin
        if (~rd_rst_n) begin
            copy_ptr   <= '0;
            copy_ptr_d <= '0;
        end else begin
            copy_ptr_d <= copy_ptr;
            if (copy_ptr != wp_sync1_bin) begin
                rd_mem[copy_ptr[ADDR_W-1:0]] <= wr_mem[copy_ptr[ADDR_W-1:0]];
                copy_ptr                     <= copy_ptr + 1'b1;
            end
        end
    end

    // full: wr_clk domain, gray-code MSB-invert comparison
    // empty: rd_clk domain, binary rp_bin vs copy_ptr_d (no CDC needed)
    assign full  = (wp_gray == {~rp_sync1[PTR_W-1:PTR_W-2], rp_sync1[PTR_W-3:0]});
    assign empty = (rp_bin == copy_ptr_d);

endmodule