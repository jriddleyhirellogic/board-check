/*
 * @file      pwr_region_step_down_bootseq.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Chase Whyte (cwhyte@turionspace.com)
 * @date      09/02/2025
 * 
 * @brief     State machine wrapper for step_down power region
 *            boots power sources in order of 2v2, 3v0, 4v0
 *            instantiates a power region manager and three state machines for each of the three power sources
 *            
 * 
 * @section changelog
 * - 09/02/2025: Chase Whyte - Initial implementation
 * 
 */
module pwr_region_step_down_bootseq # (
    parameter logic [31:0] WAIT_TIME_MULT_FACTOR = 32'd50 //multiply wait time in microseconds by 50 to convert to clock cycles. Can increase if power source
                                           //does not boot in time or decrease to improve simulation time
) (
    input  logic clk,
    input  logic rstn,
    input  logic step_down_start_boot,
    input  logic step_down_pwr_dwn,
    input  logic step_down_pgood_2v2,
    input  logic step_down_pgood_3v0,
    input  logic step_down_pgood_4v0,

    input  logic step_down_nfault_2v2,
    input  logic step_down_nfault_3v0,
    input  logic step_down_nfault_4v0,

    output logic step_down_en_2v2,
    output logic step_down_en_3v0,
    output logic step_down_en_4v0,

    output logic step_down_boot_succeeded,
    output logic step_down_boot_failed,
    output logic step_down_boot_done,
    output logic step_down_srcs_off,
    output logic step_down_latchup
);

localparam logic [31:0] STEP_DOWN_2V2_WAIT_TIME     = WAIT_TIME_MULT_FACTOR*25_000; //25 ms - set in timing.txt
localparam logic [31:0] STEP_DOWN_3V0_WAIT_TIME    = WAIT_TIME_MULT_FACTOR*25_000; //25 ms - set in timing.txt
localparam logic [31:0] STEP_DOWN_4V0_WAIT_TIME   = WAIT_TIME_MULT_FACTOR*25_000; //25 ms - set in timing.txt
localparam logic [31:0] STEP_DOWN_RETRY_TIME        = WAIT_TIME_MULT_FACTOR*200_000; //200 ms - set in timing.txt
localparam logic [31:0] NUM_STEP_DOWN_PWR_SRCS      = 32'd3;

logic step_down_2v2_latchup;
logic step_down_3v0_latchup;
logic step_down_4v0_latchup;

logic step_down_2v2_boot_succeeded;
logic step_down_3v0_boot_succeeded;
logic step_down_4v0_boot_succeeded;

logic step_down_2v2_boot_failed;
logic step_down_3v0_boot_failed;
logic step_down_4v0_boot_failed;

logic step_down_2v2_powered_dwn;
logic step_down_3v0_powered_dwn;
logic step_down_4v0_powered_dwn;

logic step_down_2v2_pwr_dwn;
logic step_down_3v0_pwr_dwn;
logic step_down_4v0_pwr_dwn;

logic step_down_boot_timeout;
logic step_down_2v2_start_boot;

assign step_down_latchup        = step_down_2v2_latchup || step_down_3v0_latchup || step_down_4v0_latchup;
                             
assign step_down_boot_succeeded = step_down_2v2_boot_succeeded && step_down_3v0_boot_succeeded && step_down_4v0_boot_succeeded;

assign step_down_boot_timeout   = step_down_2v2_boot_failed || step_down_3v0_boot_failed || step_down_4v0_boot_failed;

pwr_region_sm # (
    .RETRY_TIME  (STEP_DOWN_RETRY_TIME),
    .NUM_PWR_SRCS(NUM_STEP_DOWN_PWR_SRCS)
) pwr_region_sm_i (
    .clk,
    .rstn,
    .start_boot               (step_down_start_boot),
    .pwr_dwn                  (step_down_pwr_dwn),
    .latchup_occurred         (step_down_latchup),
    .boot_succeeded           (step_down_boot_succeeded),
    .boot_timeout             (step_down_boot_timeout),
    .pwr_srcs_powered_dwn     ({step_down_4v0_powered_dwn, step_down_3v0_powered_dwn, step_down_2v2_powered_dwn}),
    .start_first_pwr_src_boot (step_down_2v2_start_boot),
    .pwr_dwn_pwr_srcs         ({step_down_4v0_pwr_dwn, step_down_3v0_pwr_dwn, step_down_2v2_pwr_dwn}),
    .boot_failed              (step_down_boot_failed),
    .boot_done                (step_down_boot_done),
    .srcs_off                 (step_down_srcs_off)
);

//first power source is initated in state machine
pwr_src_bootseq # (
    .WAIT_TIME(STEP_DOWN_2V2_WAIT_TIME)
) pwr_src_bootseq_step_down_2v2 (
    .clk,
    .rstn,
    .start_boot       (step_down_2v2_start_boot),
    .pgood            (step_down_pgood_2v2),
    .nfault           (step_down_nfault_2v2),
    .pwr_dwn          (step_down_2v2_pwr_dwn),
    .pwr_en           (step_down_en_2v2),
    .boot_succeeded   (step_down_2v2_boot_succeeded),
    .boot_failed      (step_down_2v2_boot_failed),
    .powered_dwn      (step_down_2v2_powered_dwn),
    .latchup          (step_down_2v2_latchup)
);

//remaining power sources are turned on when previous power source in the boot sequence boots successfully
pwr_src_bootseq # (
    .WAIT_TIME(STEP_DOWN_3V0_WAIT_TIME)
) pwr_src_bootseq_step_down_3v0 (
    .clk,
    .rstn,
    .start_boot       (step_down_2v2_boot_succeeded),
    .pgood            (step_down_pgood_3v0),
    .nfault           (step_down_nfault_3v0),
    .pwr_dwn          (step_down_3v0_pwr_dwn),
    .pwr_en           (step_down_en_3v0),
    .boot_succeeded   (step_down_3v0_boot_succeeded),
    .boot_failed      (step_down_3v0_boot_failed),
    .powered_dwn      (step_down_3v0_powered_dwn),
    .latchup          (step_down_3v0_latchup)
);

pwr_src_bootseq # (
    .WAIT_TIME(STEP_DOWN_4V0_WAIT_TIME),
    .IGNORE_LATCHUP_ON_BOOT(1'b1)
) pwr_src_bootseq_step_down_4v0 (
    .clk,
    .rstn,
    .start_boot       (step_down_3v0_boot_succeeded),
    .pgood            (step_down_pgood_4v0),
    .nfault           (step_down_nfault_4v0),
    .pwr_dwn          (step_down_4v0_pwr_dwn),
    .pwr_en           (step_down_en_4v0),
    .boot_succeeded   (step_down_4v0_boot_succeeded),
    .boot_failed      (step_down_4v0_boot_failed),
    .powered_dwn      (step_down_4v0_powered_dwn),
    .latchup          (step_down_4v0_latchup)
);

endmodule
