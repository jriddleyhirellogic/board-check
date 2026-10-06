/*
 * @file      pwr_region_lvdt_bootseq.sv
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
module pwr_region_lvdt_bootseq # (
    parameter logic [31:0] WAIT_TIME_MULT_FACTOR = 32'd50 //multiply wait time in microseconds by 50 to convert to clock cycles. Can increase if power source
                                           //does not boot in time or decrease to improve simulation time
) (
    input  logic clk,
    input  logic rstn,
    input  logic lvdt_pgood,
    input  logic lvdt_start_boot,
    input  logic lvdt_pwr_dwn,
    output logic lvdt_en,
    output logic lvdt_boot_succeeded,
    output logic lvdt_boot_failed,
    output logic lvdt_boot_done,
    output logic lvdt_srcs_off,
    output logic lvdt_latchup,
    output logic lvdt_failure_metadata
);

localparam logic [31:0] LVDT_WAIT_TIME = WAIT_TIME_MULT_FACTOR*25_000; //25 ms - set in timing.txt
localparam logic [31:0] LVDT_RETRY_TIME    = WAIT_TIME_MULT_FACTOR*200_000; //200 ms - set in timing.txt

localparam logic [31:0] NUM_LVDT_PWR_SRCS  = 32'd1;

logic lvdt_powered_dwn;
logic lvdt_start_pwr_src_boot;
logic lvdt_pwr_src_pwr_dwn;
logic lvdt_boot_timeout;

//power region sm controlling the single power source
pwr_region_sm # (
    .RETRY_TIME  (LVDT_RETRY_TIME),
    .NUM_PWR_SRCS(NUM_LVDT_PWR_SRCS)
) pwr_region_sm_i (
    .clk,
    .rstn,
    .start_boot               (lvdt_start_boot),
    .pwr_dwn                  (lvdt_pwr_dwn),
    .latchup_occurred         (lvdt_latchup),
    .boot_succeeded           (lvdt_boot_succeeded),
    .boot_timeout             (lvdt_boot_timeout),
    .pwr_srcs_powered_dwn     (lvdt_powered_dwn),
    .start_first_pwr_src_boot (lvdt_start_pwr_src_boot),
    .pwr_dwn_pwr_srcs         (lvdt_pwr_src_pwr_dwn),
    .boot_failed              (lvdt_boot_failed),
    .boot_done                (lvdt_boot_done),
    .srcs_off                 (lvdt_srcs_off)
);

//first power source is initated in state machine
pwr_src_bootseq # (
    .WAIT_TIME(LVDT_WAIT_TIME)
) pwr_src_bootseq_lvdt (
    .clk,
    .rstn,
    .start_boot       (lvdt_start_pwr_src_boot),
    .pgood            (lvdt_pgood),
    .nfault           ('1),
    .pwr_dwn          (lvdt_pwr_src_pwr_dwn),
    .pwr_en           (lvdt_en),
    .boot_succeeded   (lvdt_boot_succeeded),
    .boot_failed      (lvdt_boot_timeout),
    .powered_dwn      (lvdt_powered_dwn),
    .latchup          (lvdt_latchup)
);

always_ff @(posedge clk) begin
    if(!rstn) begin
        lvdt_failure_metadata <= '0;
    end
    else begin
        if(lvdt_boot_failed) begin
            lvdt_failure_metadata <= '0;
        end
        else if(lvdt_latchup) begin
            lvdt_failure_metadata <= '1;
        end
    end
end

endmodule
