/*
 * @file      cam_fault_detector_apb_reg.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      04/24/2026
 *
 * @brief     Camera Fault Detector APB Register IP. This module sends out the
 *            fault status of the camera on the APB bus.
 *
 * @section changelog
 * - 04/24/2026: Steven Knyazher - Initial implementation
 *
 */

module cam_fault_detector_apb_reg #(
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

    // Fault
    input  logic                       fault,
    output logic                       fault_clear
);

//------------------------------------------------------------------------------
// Register address definitions
//------------------------------------------------------------------------------
localparam integer ADDR_FAULT       = 'h00;
localparam integer ADDR_FAULT_CLEAR = 'h01;

//------------------------------------------------------------------------------
// Internal signals
//------------------------------------------------------------------------------
logic [1:0] fault_sync;
logic       fault_clear_reg;

//------------------------------------------------------------------------------
// CDC Synchronizer
//------------------------------------------------------------------------------
always_ff @(posedge pclk or negedge presetn) begin
    if(~presetn) begin
        fault_sync <= 2'b0;
    end else begin
        fault_sync <= {fault_sync[0], fault};
    end
end

//------------------------------------------------------------------------------
// APB write and read register logic
//------------------------------------------------------------------------------
always_ff @(posedge pclk or negedge presetn) begin
    if(~presetn) begin
        prdata          <= 'b0;
        pready          <= 'b0;
        pslverr         <= 'b0;
        fault_clear_reg <= 'b0;

    end else begin
        pslverr <= 'b0; // Not used

        // APB Write operation
        if(psel && penable && pwrite && paddr[1:0] == 'b0) begin
            prdata <= 'b0;
            pready <= 'b1;  // Indicate done

            case(paddr[6:2])
                ADDR_FAULT: begin
                    // Read only
                end

                ADDR_FAULT_CLEAR: begin
                    fault_clear_reg <= pwdata[0:0];
                end

                default: begin
                    pslverr <= 'b0;
                end
            endcase

        // APB READ operation
        end else if(psel && penable && !pwrite && paddr[1:0] == 'b0) begin
            pready  <= 'b1; // Indicate done

            case(paddr[6:2])
                ADDR_FAULT: begin
                    prdata <= {31'b0, fault_sync[1]};
                end

                ADDR_FAULT_CLEAR: begin
                    prdata <= {31'b0, fault_clear_reg};
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

assign fault_clear = fault_clear_reg;

endmodule
