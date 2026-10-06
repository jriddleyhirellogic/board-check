/*
 * @file      dma_read_apb_reg.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      11/11/2025
 *
 * @brief
 *
 * @section changelog
 * - 11/11/2025: Saba Janamian - Initial implementation
 *
 */

module dma_read_apb_reg #(
    parameter integer APB_DATA_WIDTH    = 32,
    parameter integer APB_ADDR_WIDTH    = 32
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
    output logic                          clear,
    // APB_REG_ERR_INTF
    input  logic                          dma_timeout_err // CDC from DDR clk
);

//------------------------------------------------------------------------------
// Register address definitions
//------------------------------------------------------------------------------

localparam integer ADDR_CLEAR                  = 'd0; // Clear UDP ctrl hardware
localparam integer ADDR_DMA_TIMEOUT_ERR        = 'd1;  // RO

//------------------------------------------------------------------------------
// Internal registers
//------------------------------------------------------------------------------
logic        dma_timeout_err_sync[2]; // [0:1]
logic        dma_timeout_err_reg;
logic        clear_reg;

//------------------------------------------------------------------------------
// APB write and read register logic
//------------------------------------------------------------------------------
always_ff @(posedge pclk or negedge presetn) begin
    if(~presetn) begin
        prdata        <= 'b0;
        pready        <= 'b0;
        pslverr       <= 'b0;
        clear_reg     <= 'b0;

    end else begin
        pslverr <= 'b0; // Not used

        // APB Write operation
        if(psel && penable && pwrite && paddr[1:0] == 'b0) begin
            prdata  <= 'b0;
            pready  <= 'b1;  // Indicate done

            case(paddr[6:2])
                ADDR_CLEAR: begin
                    clear_reg <= {31'b0, pwdata[0:0]};
                end

                ADDR_DMA_TIMEOUT_ERR: begin
                    // Read only
                end

                default: begin
                    pslverr <= 'b0;
                end
            endcase

        // APB READ operation
        end else if(psel && penable && !pwrite && paddr[1:0] == 'b0) begin
            pready  <= 'b1; // Indicate done

            case(paddr[6:2])
                ADDR_CLEAR: begin
                    prdata <= clear_reg;
                end

                ADDR_DMA_TIMEOUT_ERR: begin
                    prdata <= {31'b0, dma_timeout_err_reg};
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
        clear <= 'b0;
    end else begin
        clear <= clear_reg;
    end
end

//------------------------------------------------------------------------------
// CDC Synchronizer
//------------------------------------------------------------------------------
always_ff @(posedge pclk, negedge presetn) begin
    if(~presetn) begin
        dma_timeout_err_sync <= '{default: 1'b0};
        dma_timeout_err_reg  <= 'b0;
    end else begin
        dma_timeout_err_sync[0] <= dma_timeout_err;
        dma_timeout_err_sync[1] <= dma_timeout_err_sync[0];
        dma_timeout_err_reg     <= dma_timeout_err_sync[1];
    end
end

endmodule
