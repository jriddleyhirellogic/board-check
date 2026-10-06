/*
 * @file      pwr_region_lvds_bootseq.sv
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
module pwr_region_lvds_bootseq # (
    parameter logic [31:0] WAIT_TIME_MULT_FACTOR = 32'd50 //multiply wait time in microseconds by 50 to convert to clock cycles. Can increase if power source
                                           //does not boot in time or decrease to improve simulation time
) (
    input  logic clk,
    input  logic rstn,
    input  logic lvds_pgood,
    input  logic lvds_start_boot,
    input  logic lvds_pwr_dwn,
    output logic lvds_en,
    output logic lvds_boot_succeeded,
    output logic lvds_boot_failed,
    output logic lvds_boot_done,
    output logic lvds_srcs_off,
    output logic lvds_latchup
);

localparam logic [31:0] LVDS_WAIT_TIME = WAIT_TIME_MULT_FACTOR*25_000; //25 ms - set in timing.txt
localparam logic [31:0] LVDS_RETRY_TIME    = WAIT_TIME_MULT_FACTOR*200_000; //200 ms - set in timing.txt

localparam logic [31:0] NUM_LVDS_PWR_SRCS  = 32'd1;

logic lvds_powered_dwn;
logic lvds_start_pwr_src_boot;
logic lvds_pwr_src_pwr_dwn;
logic lvds_boot_timeout;

//power region sm controlling the single power source
pwr_region_sm # (
    .RETRY_TIME  (LVDS_RETRY_TIME),
    .NUM_PWR_SRCS(NUM_LVDS_PWR_SRCS)
) pwr_region_sm_i (
    .clk,
    .rstn,
    .start_boot               (lvds_start_boot),
    .pwr_dwn                  (lvds_pwr_dwn),
    .latchup_occurred         (lvds_latchup),
    .boot_succeeded           (lvds_boot_succeeded),
    .boot_timeout             (lvds_boot_timeout),
    .pwr_srcs_powered_dwn     (lvds_powered_dwn),
    .start_first_pwr_src_boot (lvds_start_pwr_src_boot),
    .pwr_dwn_pwr_srcs         (lvds_pwr_src_pwr_dwn),
    .boot_failed              (lvds_boot_failed),
    .boot_done                (lvds_boot_done),
    .srcs_off                 (lvds_srcs_off)
);

//first power source is initated in state machine
pwr_src_bootseq # (
    .WAIT_TIME(LVDS_WAIT_TIME)
) pwr_src_bootseq_lvds (
    .clk,
    .rstn,
    .start_boot       (lvds_start_pwr_src_boot),
    .pgood            (lvds_pgood),
    .nfault           ('1),
    .pwr_dwn          (lvds_pwr_src_pwr_dwn),
    .pwr_en           (lvds_en),
    .boot_succeeded   (lvds_boot_succeeded),
    .boot_failed      (lvds_boot_timeout),
    .powered_dwn      (lvds_powered_dwn),
    .latchup          (lvds_latchup)
);



endmodule
