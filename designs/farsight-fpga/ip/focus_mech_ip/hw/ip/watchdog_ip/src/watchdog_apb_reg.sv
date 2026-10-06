/*
 * @file      watchdog_apb_reg.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      02/24/2026
 *
 * @brief     Watchdog APB Register IP. This module receives the timer count
 *            from the APB bus.
 *
 * @section changelog
 * - 02/24/2026: Steven Knyazher - Initial implementation
 * - 03/02/2026: Saba Janamian - Updated registers
 */

module watchdog_apb_reg #(
    parameter APB_DATA_WIDTH    = 32,
    parameter APB_ADDR_WIDTH    = 32,
    parameter CLOCK_FREQ_MHZ    = 50,
    parameter TIMER_COUNT_WIDTH = 27
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

    // Timer Control
    output logic                          wd_clear,
    output logic [TIMER_COUNT_WIDTH-1:0]  wd_timeout_val,
    output logic                          wd_refresh,

    // Timer Status
    input  logic                          wd_active
);

//------------------------------------------------------------------------------
// Register address definitions
//------------------------------------------------------------------------------
localparam integer ADDR_WD_CLEAR        = 'h0;
localparam integer ADDR_WD_TIMEOUT_MS   = 'h1;
localparam integer ADDR_WD_ACTIVE_STAT  = 'h2;

localparam integer CYCLES_PER_MS        = CLOCK_FREQ_MHZ * 1000;
//------------------------------------------------------------------------------
// Register space
//------------------------------------------------------------------------------
logic                         wd_clear_reg;
logic [TIMER_COUNT_WIDTH-1:0] wd_timeout_ms_reg;
logic                         wd_refresh_reg;
logic                         wd_active_reg;
//------------------------------------------------------------------------------
// APB write and read register logic
//------------------------------------------------------------------------------
always_ff @(posedge pclk, negedge presetn) begin
    if (~presetn) begin
        prdata             <= 'b0;
        pready             <= 'b0;
        pslverr            <= 'b0;
        wd_clear_reg       <= 'b0;
        wd_timeout_ms_reg  <= 'b0;
        wd_refresh_reg     <= 'b0;
        wd_active_reg      <= 'b0;
    end else begin

        pslverr            <= 'b0; // Not used
        wd_active_reg      <= wd_active;

        // APB Write operation
        if (psel && penable && pwrite && paddr[1:0] == 'b0) begin

            prdata  <= 'b0;
            pready  <= 'b1;  // Indicate done

            case (paddr[6:2])
                ADDR_WD_CLEAR: begin
                    wd_clear_reg       <= pwdata[0:0];
                    wd_refresh_reg     <= 'b0;
                end

                ADDR_WD_TIMEOUT_MS : begin
                    wd_timeout_ms_reg  <= pwdata[TIMER_COUNT_WIDTH-1:0];
                    wd_refresh_reg     <= 1'b1;
                end

                default: begin
                    pslverr        <= 'b0;
                    wd_refresh_reg <= 'b0;
                end
            endcase

        // APB READ operation
        end else if (psel && penable && !pwrite && paddr[1:0] == 'b0) begin
            pready <= 'b1; // Indicate done

            case (paddr[6:2])
                ADDR_WD_CLEAR: begin
                    prdata         <= {{(APB_DATA_WIDTH-1){1'b0}}, wd_clear_reg};
                    wd_refresh_reg <= 'b0;
                end

                ADDR_WD_TIMEOUT_MS : begin
                    prdata         <= {
                        {(APB_DATA_WIDTH-TIMER_COUNT_WIDTH){1'b0}}, 
                        wd_timeout_ms_reg};
                    wd_refresh_reg <= 'b0;
                end
                
                ADDR_WD_ACTIVE_STAT: begin
                    prdata <= {{(APB_DATA_WIDTH-1){1'b0}}, wd_active_reg};
                    wd_refresh_reg <= 'b0;
                end

                default: begin
                    pslverr        <= 'b0;
                    wd_refresh_reg <= 'b0;
                end
            endcase

        end else begin
            pready         <= 'b0;
            prdata         <= 'b0;
            pslverr        <= 'b0;
            wd_refresh_reg <= 'b0;
        end
    end
end

//------------------------------------------------------------------------------
// Output controler
//------------------------------------------------------------------------------
always_ff @(posedge pclk or negedge presetn) begin
    if(~presetn) begin
        wd_clear       <= 'b0;
        wd_timeout_val <= 'b0;      
        wd_refresh     <= 'b0;  
    end else begin
        wd_clear       <= wd_clear_reg;
        wd_timeout_val <= wd_timeout_ms_reg * CYCLES_PER_MS;
        wd_refresh     <= wd_refresh_reg;
    end
end

endmodule