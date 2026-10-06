/*
 * @file      cam_mux_apb_reg.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      04/30/2026
 *
 * @brief     Camera MUX APB Register IP. This module receives controls from the
 *            APB bus.
 *
 * @section changelog
 * - 04/30/2026: Steven Knyazher - Initial implementation
 *
 */

module cam_mux_apb_reg #(
    parameter APB_DATA_WIDTH = 32,
    parameter APB_ADDR_WIDTH = 32
)(
    // APB Slave interface
    input  logic                       pclk,     // APB clock
    input  logic                       presetn,  // APB resetn
    input  logic                       penable,  // APB enable
    input  logic                       psel,     // APB periph select
    input  logic [APB_ADDR_WIDTH-1:0]  paddr,    // APB address bus
    input  logic                       pwrite,   // APB write req
    input  logic [APB_DATA_WIDTH-1:0]  pwdata,   // APB write data
    output logic [APB_DATA_WIDTH-1:0]  prdata,   // APB read data
    output logic                       pready,   // APB ready signal
    output logic                       pslverr,  // APB error signal

    // Control
    output logic                       mux_clear,

    // Cam status
    input  logic                       mux_enable,
    input  logic                       mux_select,
    input  logic                       ddr4_16gb_full,
    input  logic                       ddr4_8gb_full,
    input  logic                       mux_clear_ack
);

//------------------------------------------------------------------------------
// Register address definitions
//------------------------------------------------------------------------------
localparam integer ADDR_MUX_CLEAR      = 'h00;
localparam integer ADDR_MUX_ENABLE     = 'h01;
localparam integer ADDR_MUX_SELECT     = 'h02;
localparam integer ADDR_DDR4_16GB_FULL = 'h03;
localparam integer ADDR_DDR4_8GB_FULL  = 'h04;

//------------------------------------------------------------------------------
// Internal Register
//------------------------------------------------------------------------------
logic mux_clear_reg;

assign mux_clear = mux_clear_reg;

//------------------------------------------------------------------------------
// CDC Synchronizer registers
//------------------------------------------------------------------------------
logic [1:0] mux_enable_sync;
logic [1:0] mux_select_sync;
logic [1:0] ddr4_16gb_full_sync;
logic [1:0] ddr4_8gb_full_sync;
logic [1:0] mux_clear_ack_sync;

//------------------------------------------------------------------------------
// APB write and read register logic
//------------------------------------------------------------------------------
always_ff @(posedge pclk, negedge presetn) begin
    if (~presetn) begin
        prdata        <= 'b0;
        pready        <= 'b0;
        pslverr       <= 'b0;
        mux_clear_reg <= 'b0;
    end else begin
        pslverr <= 'b0; // Not used

        if (mux_clear_ack_sync[1]) begin
            mux_clear_reg <= 'b0;
        end

        // APB Write operation
        if (psel && penable && pwrite && paddr[1:0] == 'b0) begin
            prdata  <= 'b0;
            pready  <= 'b1;  // Indicate done

            case (paddr[6:2])
                ADDR_MUX_CLEAR: begin
                    mux_clear_reg <= {31'b0, pwdata[0:0]};
                end

                default: begin
                    pslverr <= 'b0;
                end
            endcase

        // APB READ operation
        end else if (psel && penable && !pwrite && paddr[1:0] == 'b0) begin
            pready <= 'b1; // Indicate done

            case (paddr[6:2])
                ADDR_MUX_CLEAR: begin
                    prdata <= {31'b0, mux_clear_reg};
                end

                ADDR_MUX_ENABLE: begin
                    prdata <= {31'b0, mux_enable_sync[1]};
                end

                ADDR_MUX_SELECT: begin
                    prdata <= {31'b0, mux_select_sync[1]};
                end

                ADDR_DDR4_16GB_FULL: begin
                    prdata <= {31'b0, ddr4_16gb_full_sync[1]};
                end

                ADDR_DDR4_8GB_FULL: begin
                    prdata <= {31'b0, ddr4_8gb_full_sync[1]};
                end

                default: begin
                    pslverr <= 'b0;
                end
            endcase

        end else begin
            pready  <= 'b0;
            prdata  <= 'b0;
            pslverr <= 'b0;
        end
    end
end

//------------------------------------------------------------------------------
// CDC Synchronizer
//------------------------------------------------------------------------------
always_ff @(posedge pclk, negedge presetn) begin
    if (~presetn) begin
        mux_enable_sync     <= 2'b0;
        mux_select_sync     <= 2'b0;
        ddr4_16gb_full_sync <= 2'b0;
        ddr4_8gb_full_sync  <= 2'b0;
        mux_clear_ack_sync  <= 2'b0;
    end else begin
        mux_enable_sync     <= {mux_enable_sync[0], mux_enable};
        mux_select_sync     <= {mux_select_sync[0], mux_select};
        ddr4_16gb_full_sync <= {ddr4_16gb_full_sync[0], ddr4_16gb_full};
        ddr4_8gb_full_sync  <= {ddr4_8gb_full_sync[0], ddr4_8gb_full};
        mux_clear_ack_sync  <= {mux_clear_ack_sync[0], mux_clear_ack};
    end
end

endmodule
