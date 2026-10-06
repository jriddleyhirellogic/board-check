/*
 * @file      junc_temp_apb_reg.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      05/15/2026
 * 
 * @brief     The read-only APB register in this module gets updated once there
 *            is a valid junction temperature data signal.
 *
 * @section changelog
 * - 05/15/2026: Steven Knyazher - Initial implementation
 * 
 */

module junc_temp_apb_reg #(
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

    // TVS interface
    input  logic                          tvs_valid,
    input  logic [15:0]                   tvs_value,
    input  logic [1:0]                    tvs_channel
);

//------------------------------------------------------------------------------
// Register address definitions
//------------------------------------------------------------------------------
localparam integer ADDR_JUNC_TEMP = 'd0; // RO

//------------------------------------------------------------------------------
// TVS capture: latch temperature on the rising edge of valid for channel 3 only
//------------------------------------------------------------------------------
localparam logic [1:0] TVS_TEMP_CH = 2'b11; // Channel 3 = junction temperature

logic        tvs_valid_d;
logic [15:0] junc_temp;

always_ff @(posedge pclk or negedge presetn) begin
    if (~presetn) begin
        tvs_valid_d <= 1'b0;
        junc_temp   <= 16'b0;
    end else begin
        tvs_valid_d <= tvs_valid;
        if ((tvs_valid && ~tvs_valid_d) && (tvs_channel == TVS_TEMP_CH)) begin
            junc_temp <= tvs_value;
        end
    end
end

//------------------------------------------------------------------------------
// APB write and read register logic
//------------------------------------------------------------------------------
always_ff @(posedge pclk or negedge presetn) begin
    if(~presetn) begin
        prdata  <= 'b0;
        pready  <= 'b0;
        pslverr <= 'b0;

    end else begin
        pslverr <= 'b0; // Not used

        // APB Write operation
        if(psel && penable && pwrite && paddr[1:0] == 'b0) begin
            prdata <= 'b0;
            pready <= 'b1;  // Indicate done

            case(paddr[6:2])
                ADDR_JUNC_TEMP: begin
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
                ADDR_JUNC_TEMP: begin
                    prdata <= APB_DATA_WIDTH'(junc_temp);
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

endmodule
