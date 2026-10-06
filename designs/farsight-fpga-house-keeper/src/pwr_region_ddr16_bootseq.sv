/*
 * @file      pwr_region_ddr16_bootseq.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Chase Whyte (cwhyte@turionspace.com)
 * @date      09/02/2025
 * 
 * @brief     State machine wrapper for ddr16 power region
 *            boots power sources in order of 2v5, 1v2, and 0v6 
 *            instantiates a power region manager and three state machines for each of the three power sources
 *            
 * 
 * @section changelog
 * - 09/02/2025: Chase Whyte - Initial implementation
 * 
 */
module pwr_region_ddr16_bootseq # (
    parameter logic [31:0] WAIT_TIME_MULT_FACTOR = 32'd50 //multiply wait time in microseconds by 50 to convert to clock cycles. Can increase if power source
                                           //does not boot in time or decrease to improve simulation time
) (
    input  logic       clk,
    input  logic       rstn,
    input  logic       ddr16_pgood_2v5,
    input  logic       ddr16_pgood_1v2,
    input  logic       ddr16_pgood_0v6,
    input  logic       ddr16_nfault_2v5,
    input  logic       ddr16_nfault_1v2,
    input  logic       ddr16_start_boot,
    input  logic       ddr16_pwr_dwn,
    input  logic       fpga_boot_succeeded,
    output logic       ddr16_en_2v5,
    output logic       ddr16_en_1v2,
    output logic       ddr16_en_0v6,
    output logic       ddr16_boot_succeeded,
    output logic       ddr16_boot_failed,
    output logic       ddr16_boot_done,
    output logic       ddr16_srcs_off,
    output logic       ddr16_latchup,
    output logic [1:0] ddr16_failure_metadata
);

localparam logic [31:0] DDR16_2V5_WAIT_TIME = WAIT_TIME_MULT_FACTOR*25_000; //25 ms - set in timing.txt
localparam logic [31:0] DDR16_1V2_WAIT_TIME = WAIT_TIME_MULT_FACTOR*25_000; //25 ms - set in timing.txt
localparam logic [31:0] DDR16_0V6_WAIT_TIME = WAIT_TIME_MULT_FACTOR*25_000; //25 ms - set in timing.txt
localparam logic [31:0] DDR16_RETRY_TIME    = WAIT_TIME_MULT_FACTOR*200_000; //200 ms - set in timing.txt
localparam logic [31:0] NUM_DDR16_PWR_SRCS  = 32'd3;

logic ddr16_2v5_latchup;
logic ddr16_1v2_latchup;
logic ddr16_0v6_latchup;

logic ddr16_2v5_boot_succeeded;
logic ddr16_1v2_boot_succeeded;
logic ddr16_0v6_boot_succeeded;

logic ddr16_2v5_boot_failed;
logic ddr16_1v2_boot_failed;
logic ddr16_0v6_boot_failed;

logic ddr16_2v5_powered_dwn;
logic ddr16_1v2_powered_dwn;
logic ddr16_0v6_powered_dwn;

logic ddr16_2v5_pwr_dwn;
logic ddr16_1v2_pwr_dwn;
logic ddr16_0v6_pwr_dwn;

logic ddr16_boot_timeout;
logic ddr16_2v5_start_boot;

assign ddr16_latchup        = ddr16_2v5_latchup || ddr16_1v2_latchup || ddr16_0v6_latchup;
assign ddr16_boot_succeeded = ddr16_2v5_boot_succeeded && ddr16_1v2_boot_succeeded && ddr16_0v6_boot_succeeded;
assign ddr16_boot_timeout   = ddr16_2v5_boot_failed || ddr16_1v2_boot_failed || ddr16_0v6_boot_failed;

//power region sm controlling the three power sources: 2v5, 1v2, 0v6. Power sources boot in that order.
//
pwr_region_sm # (
    .RETRY_TIME  (DDR16_RETRY_TIME),
    .NUM_PWR_SRCS(NUM_DDR16_PWR_SRCS)
) pwr_region_sm_i (
    .clk,
    .rstn,
    .start_boot               (ddr16_start_boot),
    .pwr_dwn                  (ddr16_pwr_dwn),
    .latchup_occurred         (ddr16_latchup),
    .boot_succeeded           (ddr16_boot_succeeded),
    .boot_timeout             (ddr16_boot_timeout),
    .pwr_srcs_powered_dwn     ({ddr16_0v6_powered_dwn, ddr16_1v2_powered_dwn, ddr16_2v5_powered_dwn}),
    .start_first_pwr_src_boot (ddr16_2v5_start_boot),
    .pwr_dwn_pwr_srcs         ({ddr16_0v6_pwr_dwn, ddr16_1v2_pwr_dwn, ddr16_2v5_pwr_dwn}),
    .boot_failed              (ddr16_boot_failed),
    .boot_done                (ddr16_boot_done),
    .srcs_off                 (ddr16_srcs_off)
);

//first power source is initated in state machine
pwr_src_bootseq # (
    .WAIT_TIME(DDR16_2V5_WAIT_TIME)
) pwr_src_bootseq_ddr16_2v5 (
    .clk,
    .rstn,
    .start_boot       (ddr16_2v5_start_boot),
    .pgood            (ddr16_pgood_2v5),
    .nfault           (ddr16_nfault_2v5),
    .pwr_dwn          (ddr16_2v5_pwr_dwn),
    .pwr_en           (ddr16_en_2v5),
    .boot_succeeded   (ddr16_2v5_boot_succeeded),
    .boot_failed      (ddr16_2v5_boot_failed),
    .powered_dwn      (ddr16_2v5_powered_dwn),
    .latchup          (ddr16_2v5_latchup)
);

//remaining power sources are turned on when previous power source in the boot sequence boots successfully
pwr_src_bootseq # (
    .WAIT_TIME(DDR16_1V2_WAIT_TIME)
) pwr_src_bootseq_ddr16_1v2 (
    .clk,
    .rstn,
    .start_boot       (ddr16_2v5_boot_succeeded),
    .pgood            (ddr16_pgood_1v2),
    .nfault           (ddr16_nfault_1v2),
    .pwr_dwn          (ddr16_1v2_pwr_dwn),
    .pwr_en           (ddr16_en_1v2),
    .boot_succeeded   (ddr16_1v2_boot_succeeded),
    .boot_failed      (ddr16_1v2_boot_failed),
    .powered_dwn      (ddr16_1v2_powered_dwn),
    .latchup          (ddr16_1v2_latchup)
);

pwr_src_bootseq # (
    .WAIT_TIME(DDR16_0V6_WAIT_TIME)
) pwr_src_bootseq_ddr16_0v6 (
    .clk,
    .rstn,
    .start_boot       (ddr16_1v2_boot_succeeded),
    .pgood            (ddr16_pgood_0v6),
    .nfault           ('1),
    .pwr_dwn          (ddr16_0v6_pwr_dwn),
    .pwr_en           (ddr16_en_0v6),
    .boot_succeeded   (ddr16_0v6_boot_succeeded),
    .boot_failed      (ddr16_0v6_boot_failed),
    .powered_dwn      (ddr16_0v6_powered_dwn),
    .latchup          (ddr16_0v6_latchup)
);

always_ff @(posedge clk) begin
    if(!rstn) begin
        ddr16_failure_metadata <= '0;
    end
    else if(fpga_boot_succeeded) begin
        if(ddr16_2v5_boot_failed)
            ddr16_failure_metadata <= 2'd1;
        else if(ddr16_1v2_boot_failed)
            ddr16_failure_metadata <= 2'd2;
        else if(ddr16_0v6_boot_failed)
            ddr16_failure_metadata <= 2'd3;
    end
end


endmodule
