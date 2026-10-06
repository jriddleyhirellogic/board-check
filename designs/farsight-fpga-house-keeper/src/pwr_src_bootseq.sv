/*
 * @file      pwr_src_bootseq.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Chase Whyte (cwhyte@turionspace.com)
 * @date      09/02/2025
 * 
 * @brief     State machine for individual power sources
 *            controls enable of power source and monitors pgood and nfault signals from power source
 *            
 * 
 * @section changelog
 * - 09/02/2025: Chase Whyte - Initial implementation
 * 
 */
module pwr_src_bootseq # (
    parameter logic [31:0] WAIT_TIME         = 32'd500_000,
    parameter logic [31:0] LATCHUP_WAIT_TIME = 32'd125_000,
    parameter logic [31:0] PWR_DWN_WAIT_TIME = 32'd125_000,
    parameter logic        IGNORE_LATCHUP_ON_BOOT = 1'b0
) (
    input  logic clk,
    input  logic rstn,
    input  logic start_boot,
    input  logic pgood,
    input  logic nfault,
    input  logic pwr_dwn,
    output logic pwr_en,
    output logic boot_succeeded,
    output logic boot_failed,
    output logic powered_dwn,
    output logic latchup

);

localparam logic [31:0] CNTR_PRECISION = 32'd14; //cntr will increment every 2^(CNTR_PRECISION) clock cycles
localparam logic [31:0] CNTR_RESOLUTION = 32'd7; //# of bits to hold the number of time periods equal to 2^(CNTR_PRECISION) clock cycles that have elapsed
                                                 //7 and not 6: WAIT_TIME is 25 ms = 76 ticks, and a 6-bit cntr saturates at 63,
                                                 //so the boot timeout below could never fire in the flight build
localparam logic [31:0] CNTR_NFAULT_IGNORE_TIME = 32'd10000;

typedef enum logic [2:0] {
    POWER_OFF = 3'd0,
    BOOTING = 3'd1,
    BOOT_SUCCEEDED = 3'd2,
    BOOT_FAILED = 3'd3,
    POWERING_DOWN = 3'd4,
    LATCHUP = 3'd5
} boot_states;

boot_states curr_state /* synthesis syn_encoding="safe" */; 
boot_states curr_state_dv;

logic [CNTR_RESOLUTION-1:0]    cntr;         //state counter to keep track of time in each state/substate
logic                          clr;          //resets state counter
logic                          pgood_r1;
logic                          pwr_en_dv;
logic                          boot_aborted;


proasic3_counter # (
    .CNTR_RESOLUTION(CNTR_RESOLUTION),
    .CNTR_PRECISION (CNTR_PRECISION)
) proasic3_counter_i (
    .clk,
    .rstn,
    .clr,
    .cntr
);

assign latchup        = curr_state == LATCHUP;
assign boot_succeeded = curr_state == BOOT_SUCCEEDED;
assign boot_failed    = curr_state == BOOT_FAILED;
assign powered_dwn    = curr_state == POWER_OFF;

always_comb begin
    curr_state_dv = curr_state;
    clr           = '0;
    pwr_en_dv     = pwr_en;
    case(curr_state)
        POWER_OFF: begin
            clr        = '1;
            pwr_en_dv  = '0;
            if(start_boot && !pwr_dwn) begin
                curr_state_dv = BOOTING;
            end
        end
        BOOTING: begin
            pwr_en_dv = '1;
            if(!nfault && !IGNORE_LATCHUP_ON_BOOT) begin
                curr_state_dv = LATCHUP;
                clr           = '1;
            end
            else if(pwr_dwn) begin
                curr_state_dv = POWERING_DOWN;
                clr           = '1;
            end
            else if({pgood_r1, pgood} == 2'b01) begin
                curr_state_dv = BOOT_SUCCEEDED;
                clr = '1;
            end
            //rounded up, not truncated: a cntr tick is 0.32768 ms, and the floor
            //form fires at 24.904 ms -- before the 25 ms the source is allowed,
            //which fails a rail whose PGOOD rises at 24.9 ms once the 5 us glitch
            //filter has delayed the edge. Late is the safe side of a timeout.
            else if(cntr >= ((WAIT_TIME + (32'd1 << CNTR_PRECISION) - 32'd1) >> CNTR_PRECISION)) begin
                curr_state_dv = BOOT_FAILED;
            end
        end
        BOOT_SUCCEEDED: begin
            
            pwr_en_dv  = '1;
            if((!nfault || !pgood) && (!IGNORE_LATCHUP_ON_BOOT || (cntr >= (CNTR_NFAULT_IGNORE_TIME >> CNTR_PRECISION)))) begin
                curr_state_dv = LATCHUP;
                clr        = '1;
            end
            else if(pwr_dwn) begin
                curr_state_dv = POWERING_DOWN;
                clr           = '1;
            end
        end
        BOOT_FAILED: begin
            pwr_en_dv = '0;
            if(pwr_dwn) begin
                curr_state_dv = POWER_OFF;
            end
        end
        POWERING_DOWN: begin
            pwr_en_dv = '0;
            if((!pgood && !boot_aborted) || cntr >= (PWR_DWN_WAIT_TIME >> CNTR_PRECISION)) begin
                curr_state_dv = POWER_OFF;
            end
        end
        LATCHUP: begin
            pwr_en_dv = '0;
            if(cntr >= (LATCHUP_WAIT_TIME >> CNTR_PRECISION)) begin
                curr_state_dv = POWER_OFF;
            end
        end
        default: begin
            curr_state_dv = POWER_OFF;
        end
    endcase
end

always_ff @(posedge clk) begin
    if(!rstn) begin
        curr_state   <= POWER_OFF;
        pwr_en       <= '0;
        pgood_r1     <= '0;
        boot_aborted <= '0;
    end
    else begin
        curr_state   <= curr_state_dv;
        pwr_en       <= pwr_en_dv;
        pgood_r1     <= pgood;
        boot_aborted <= (curr_state_dv == POWERING_DOWN) && (curr_state == BOOTING || boot_aborted);
    end
end

endmodule
