/*
 * @file      pwr_region_stepper_pri_bootseq.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Chase Whyte (cwhyte@turionspace.com)
 * @date      09/02/2025
 * 
 * @brief     State machine wrapper for ddr8 power region
 *            Single power source
 *            instantiates a power region manager and one state machine for one power source
 *            
 * 
 * @section changelog
 * - 09/02/2025: Chase Whyte - Initial implementation
 * 
 */
module pwr_region_stepper_pri_bootseq # (
    parameter logic [31:0] WAIT_TIME_MULT_FACTOR = 32'd50 //multiply wait time in microseconds by 50 to convert to clock cycles. Can increase if power source
                                           //does not boot in time or decrease to improve simulation time
) (
    input  logic clk,
    input  logic rstn,
    input  logic stepper_pri_pgood,
    input  logic stepper_pri_nfault,
    input  logic stepper_pri_start_boot,
    input  logic stepper_pri_pwr_dwn,
    output logic stepper_pri_en,
    output logic stepper_pri_boot_succeeded,
    output logic stepper_pri_boot_failed,
    output logic stepper_pri_boot_done,
    output logic stepper_pri_srcs_off,
    output logic stepper_pri_latchup,
    output logic stepper_pri_failure_metadata
);

localparam logic [31:0] STEPPER_PRI_WAIT_TIME = WAIT_TIME_MULT_FACTOR*25_000; //25 ms - set in timing.txt
localparam logic [31:0] STEPPER_PRI_RETRY_TIME    = WAIT_TIME_MULT_FACTOR*200_000; //200 ms - set in timing.txt

localparam logic [31:0] NUM_STEPPER_PRI_PWR_SRCS  = 32'd1;

logic stepper_pri_powered_dwn;
logic stepper_pri_start_pwr_src_boot;
logic stepper_pri_pwr_src_pwr_dwn;
logic stepper_pri_boot_timeout;

//power region sm controlling the single power source
pwr_region_sm # (
    .RETRY_TIME  (STEPPER_PRI_RETRY_TIME),
    .NUM_PWR_SRCS(NUM_STEPPER_PRI_PWR_SRCS)
) pwr_region_sm_i (
    .clk,
    .rstn,
    .start_boot               (stepper_pri_start_boot),
    .pwr_dwn                  (stepper_pri_pwr_dwn),
    .latchup_occurred         (stepper_pri_latchup),
    .boot_succeeded           (stepper_pri_boot_succeeded),
    .boot_timeout             (stepper_pri_boot_timeout),
    .pwr_srcs_powered_dwn     (stepper_pri_powered_dwn),
    .start_first_pwr_src_boot (stepper_pri_start_pwr_src_boot),
    .pwr_dwn_pwr_srcs         (stepper_pri_pwr_src_pwr_dwn),
    .boot_failed              (stepper_pri_boot_failed),
    .boot_done                (stepper_pri_boot_done),
    .srcs_off                 (stepper_pri_srcs_off)
);

//first power source is initated in state machine
pwr_src_bootseq # (
    .WAIT_TIME(STEPPER_PRI_WAIT_TIME)
) pwr_src_bootseq_stepper_pri (
    .clk,
    .rstn,
    .start_boot       (stepper_pri_start_pwr_src_boot),
    .pgood            (stepper_pri_pgood),
    .nfault           (stepper_pri_nfault),
    .pwr_dwn          (stepper_pri_pwr_src_pwr_dwn),
    .pwr_en           (stepper_pri_en),
    .boot_succeeded   (stepper_pri_boot_succeeded),
    .boot_failed      (stepper_pri_boot_timeout),
    .powered_dwn      (stepper_pri_powered_dwn),
    .latchup          (stepper_pri_latchup)
);

always_ff @(posedge clk) begin
    if(!rstn) begin
        stepper_pri_failure_metadata <= '0;
    end
    else begin
        if(stepper_pri_boot_failed) begin
            stepper_pri_failure_metadata <= '0;
        end
        else if(stepper_pri_latchup) begin
            stepper_pri_failure_metadata <= '1;
        end
    end
end

endmodule
