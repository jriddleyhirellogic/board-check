/*
 * @file      pwr_region_sm.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Chase Whyte (cwhyte@turionspace.com)
 * @date      08/14/2025
 * 
 * @brief     State machine controlling each of the power regions with variable number of power sources
 *            boots power sources in order from LSB to MSB of pgood/nfault/enable
 *            boot process resets and retries booting from first power source if any power source fails to boot
 *            
 * 
 * @section changelog
 * - 08/14/2025: Chase Whyte - Initial implementation
 * 
 */

module pwr_region_sm # (
    parameter integer unsigned RETRY_TIME                             = 32'd10_000_000,
    parameter integer unsigned NUM_PWR_SRCS                           = 32'd3 //number of power sources in the power region
) (
    input  logic                    clk,
    input  logic                    rstn,
    input  logic                    start_boot,               //initiates boot process of power region
    input  logic                    pwr_dwn,                  //powers down sources in reverse order and holds in power off state
    input  logic                    latchup_occurred,         //a latchup occurred in one or more of the power sources in the power region
    input  logic                    boot_succeeded,           //indicates that boot process succeeded for all power sources in the power region
    input  logic                    boot_timeout,             //indicates that boot process timed out/failed for one of the power sources in the power region during boot
    input  logic [NUM_PWR_SRCS-1:0] pwr_srcs_powered_dwn,     //indicates which power source has finished powering down/is in power off state
    output logic [NUM_PWR_SRCS-1:0] pwr_dwn_pwr_srcs,         //power down control for each power source in the power rgion
    output logic                    start_first_pwr_src_boot, //starts boot process of the power region with first power source

    output logic                    boot_done,                //indicates that boot process has finished (success or fail) or region is still powering down
    output logic                    boot_failed,              //indicates that boot process has failed after {NUM_RETRIES} retries
    output logic                    srcs_off
);

localparam integer unsigned NUM_RETRIES     = 32'd3;
localparam integer unsigned CNTR_PRECISION  = 32'd16; //cntr will increment every 2^(CNTR_PRECISION) clock cycles
localparam integer unsigned CNTR_RESOLUTION = 32'd8;  //# of bits to hold the number of time periods equal to 2^(CNTR_PRECISION) clock cycles that have elapsed

typedef enum logic [2:0] {
    POWER_OFF =      3'd0,
    BOOTING =        3'd1,
    RETRY =          3'd2,
    BOOT_SUCCEEDED = 3'd3,
    BOOT_FAILED =    3'd4,
    POWERING_DOWN =  3'd6,
    LATCHUP =        3'd7
} boot_states;

boot_states                      curr_state, curr_state_dv /* synthesis syn_encoding="safe" */;

logic [CNTR_RESOLUTION-1:0]      cntr;          //state counter to keep track of time in each state/substate
logic                            clr;           //resets state counter
logic [$clog2(NUM_RETRIES)-1:0]  retry_cntr;    //keeps track of current number of retries
logic [$clog2(NUM_RETRIES)-1:0]  retry_cntr_dv;

proasic3_counter # (
    .CNTR_RESOLUTION(CNTR_RESOLUTION),
    .CNTR_PRECISION (CNTR_PRECISION)
) proasic3_counter_i (
    .clk,
    .rstn,
    .clr,
    .cntr
);

assign boot_failed              = curr_state == BOOT_FAILED;
assign srcs_off                 = &pwr_srcs_powered_dwn;
assign boot_done                = curr_state == BOOT_FAILED || curr_state == BOOT_SUCCEEDED || curr_state == POWERING_DOWN;
assign start_first_pwr_src_boot = curr_state == BOOTING;

always_comb begin
    curr_state_dv     = curr_state;
    clr               = '0;
    retry_cntr_dv     = retry_cntr;
    pwr_dwn_pwr_srcs  = '0;

    case(curr_state)
        //power off state before booting and after powering down
        POWER_OFF: begin
            retry_cntr_dv    = '0;
            pwr_dwn_pwr_srcs = '1;
            if(start_boot && !pwr_dwn) begin
                curr_state_dv = BOOTING;
            end
        end
        //attempts to boot all power sources in order
        BOOTING: begin
            clr = '1;
            if(latchup_occurred) begin
                curr_state_dv = LATCHUP;
            end
            else if(pwr_dwn) begin
                curr_state_dv = POWERING_DOWN;
            end
            //if boot times out for any power source and we have already tried to boot 
            //NUM_RETRIES + 1 times, this is a fail, otherwise retry
            else if(boot_timeout) begin
                if(retry_cntr == NUM_RETRIES) begin
                    curr_state_dv = BOOT_FAILED;
                end
                else begin
                    retry_cntr_dv = retry_cntr + 1'b1;
                    
                    curr_state_dv = RETRY;
                end
            end
            //boot succeeded if all power sources booted successfully
            else if(boot_succeeded) begin
                curr_state_dv = BOOT_SUCCEEDED;
            end
        end
        //retry state entered if one of the power sources fails to boot, sets all enables low 
        //and waits here for RETRY_TIME before restarting boot
        RETRY: begin
            pwr_dwn_pwr_srcs = '1;
            if(cntr >= ((RETRY_TIME + (32'd1 << CNTR_PRECISION) - 32'd1) >> CNTR_PRECISION)) begin
                if(pwr_dwn) begin
                    curr_state_dv = POWER_OFF;
                end
                else begin
                    curr_state_dv = BOOTING;
                end
            end
        end
        //continues to drive enable high as long as pgood and nfault are both high on all power sources
        //else move to latchup state
        //move to power down state if power region is powered down
        BOOT_SUCCEEDED: begin
            if(latchup_occurred) begin
                curr_state_dv = LATCHUP;
            end
            else if(pwr_dwn) begin
                curr_state_dv = POWERING_DOWN;
            end
        end
        //set power enables low and wait until power down to move to power off state
        BOOT_FAILED: begin
            pwr_dwn_pwr_srcs = '1;
            if(pwr_dwn) begin
                curr_state_dv = POWER_OFF;
            end
        end
        //power down power sources in reverse order (MSB to LSB) 
        //move to latchup state if nfault on any power sources or pgood negative edge on 
        //any power source not currently being powered down (not equal to boot index)
        //waits for pgood to be low before moving onto next power source, moves to power off state
        //after all power sources have finished powering down
        POWERING_DOWN: begin
            if(latchup_occurred) begin
                curr_state_dv = LATCHUP;
            end
            else begin
                pwr_dwn_pwr_srcs[NUM_PWR_SRCS-1] = '1;
                for(integer unsigned i = 1; i < NUM_PWR_SRCS; i++) begin
                    if(pwr_srcs_powered_dwn[i]) begin
                        pwr_dwn_pwr_srcs[i-1] = '1;
                    end
                end
                if(&pwr_srcs_powered_dwn) begin
                    curr_state_dv = POWER_OFF;
                end
            end
        end
        //sets all enables low immediately and waits for power sources to reset to power off state after 
        //counter timeout or pgood is low and nfault is high
        LATCHUP: begin
            pwr_dwn_pwr_srcs = '1;
            if(!latchup_occurred) begin
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
        curr_state <= POWER_OFF;
        retry_cntr <= '0;
    end
    else begin
        curr_state <= curr_state_dv;
        retry_cntr <= retry_cntr_dv;
    end
end
endmodule
