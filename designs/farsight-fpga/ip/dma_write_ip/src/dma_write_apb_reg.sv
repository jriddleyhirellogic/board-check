/*
 * @file      dma_write_apb_reg.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      10/15/2025
 *
 * @brief     DMA Write APB Reg
 *
 * @section changelog
 * - 10/15/2025: Saba Janamian - Initial implementation
 *
 */

module dma_write_apb_reg #(
    parameter integer APB_DATA_WIDTH    = 32,
    parameter integer APB_ADDR_WIDTH    = 32,
    parameter integer H_SIZE_WIDTH      = 14,
    parameter integer FRAME_INDEX_WIDTH = 8
)(
    // APB Slave interface
    input  logic                          pclk,     // APB clock
    input  logic                          presetn,  // APB resetn
    input  logic                          penable,  // APB enable
    input  logic                          psel,     // APB periph select
    input  logic [APB_ADDR_WIDTH-1:0]     paddr,    // APB address bus
    input  logic                          pwrite,   // APB write req
    input  logic [APB_DATA_WIDTH-1:0]     pwdata,   // APB write data
    output logic [APB_DATA_WIDTH-1:0]     prdata,   // APB read data
    output logic                          pready,   // APB ready signal
    output logic                          pslverr,  // APB error signal
    // DMA_CTRL_INTF
    output logic                          clear_index,
    output logic [H_SIZE_WIDTH-1:0]       h_size_byte, // (LINE_GAP)
    input  logic [FRAME_INDEX_WIDTH-1:0]  frame_index,
    input  logic                          core_ready,
    input  logic                          frame_write_done,
    input  logic                          timeout_err
);

//------------------------------------------------------------------------------
// Register address definitions
//------------------------------------------------------------------------------

localparam integer ADDR_CLEAR_INDEX           = 'd0;
localparam integer ADDR_H_SIZE_BYTE           = 'd1;
localparam integer ADDR_FRAME_INDEX           = 'd2;
localparam integer ADDR_CORE_READY            = 'd3;
localparam integer ADDR_FRAME_WRITE_DONE      = 'd4;
localparam integer ADDR_TIMEOUT_ERR           = 'd5;

localparam integer NUM_REGS                   = 8; // Can only be 8, 16, 32

//------------------------------------------------------------------------------
// Register space
//------------------------------------------------------------------------------
logic [APB_DATA_WIDTH-1:0] mem[NUM_REGS];

//------------------------------------------------------------------------------
// Internal registers
//------------------------------------------------------------------------------
logic [FRAME_INDEX_WIDTH-1:0] frame_index_sync[2];
logic                         core_ready_sync[2];
logic                         frame_write_done_sync[2];
logic                         timeout_err_sync[2];

//------------------------------------------------------------------------------
// CDC Synchronizer
//------------------------------------------------------------------------------
always_ff @(posedge pclk or negedge presetn) begin
    if(~presetn) begin
        frame_index_sync      <= '{default: 1'b0};
        core_ready_sync       <= '{default: 1'b0};
        frame_write_done_sync <= '{default: 1'b0};
        timeout_err_sync      <= '{default: 1'b0};
    end else begin
        frame_index_sync[0]      <= frame_index;
        frame_index_sync[1]      <= frame_index_sync[0];

        core_ready_sync[0]       <= core_ready;
        core_ready_sync[1]       <= core_ready_sync[0];

        frame_write_done_sync[0] <= frame_write_done;
        frame_write_done_sync[1] <= frame_write_done_sync[0];

        timeout_err_sync[0]      <= timeout_err;
        timeout_err_sync[1]      <= timeout_err_sync[0];
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

        // Input signals to Mem
        mem[ADDR_FRAME_INDEX     ] <= frame_index_sync[1];
        mem[ADDR_CORE_READY      ] <= core_ready_sync[1];
        mem[ADDR_FRAME_WRITE_DONE] <= frame_write_done_sync[1];
        mem[ADDR_TIMEOUT_ERR     ] <= {31'b0, timeout_err_sync[1]};

        // APB Write operation
        if(psel && penable && pwrite && paddr[1:0] == 'b0) begin
            prdata  <= 'b0;
            pready  <= 'b1;  // Indicate done

            case(paddr[6:2])
                ADDR_CLEAR_INDEX: begin
                    mem[ADDR_CLEAR_INDEX] <= {31'b0, pwdata[0:0]};
                end

                ADDR_H_SIZE_BYTE: begin
                    mem[ADDR_H_SIZE_BYTE] <= {
                        {(APB_DATA_WIDTH-H_SIZE_WIDTH){1'b0}},
                        pwdata[H_SIZE_WIDTH-1:0]
                    };
                end

                default: begin
                    pslverr <= 'b0;
                end
            endcase

        // APB READ operation
        end else if(psel && penable && !pwrite && paddr[1:0] == 'b0) begin
            pready  <= 'b1; // Indicate done

            case(paddr[6:2])
                ADDR_CLEAR_INDEX: begin
                    prdata <= {31'b0, mem[ADDR_CLEAR_INDEX][0:0]};
                end

                ADDR_H_SIZE_BYTE: begin
                    prdata <= {
                        {(APB_DATA_WIDTH-H_SIZE_WIDTH){1'b0}},
                        mem[ADDR_H_SIZE_BYTE][H_SIZE_WIDTH-1:0]
                    };
                end

                ADDR_FRAME_INDEX: begin // RO
                    prdata <= {
                        {(APB_DATA_WIDTH-FRAME_INDEX_WIDTH){1'b0}},
                        mem[ADDR_FRAME_INDEX][FRAME_INDEX_WIDTH-1:0]
                    };
                end

                ADDR_CORE_READY: begin // RO
                    prdata <= {31'b0, mem[ADDR_CORE_READY][0:0]};
                end

                ADDR_FRAME_WRITE_DONE: begin // RO
                    prdata <= {31'b0, mem[ADDR_FRAME_WRITE_DONE][0:0]};
                end

                ADDR_TIMEOUT_ERR: begin // RO
                    prdata <= mem[ADDR_TIMEOUT_ERR];
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
// Output controler
//------------------------------------------------------------------------------
always_ff @(posedge pclk or negedge presetn) begin
    if(~presetn) begin
        clear_index <= 'b0;
        h_size_byte <= 'b0;
    end else begin
        clear_index                <= mem[ADDR_CLEAR_INDEX][0:0];
        h_size_byte                <= mem[ADDR_H_SIZE_BYTE][H_SIZE_WIDTH-1:0];
    end
end

endmodule
