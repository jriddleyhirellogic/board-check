/*
 * @file      pwr_region_eth2_bootseq.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Chase Whyte (cwhyte@turionspace.com)
 * @date      09/02/2025
 * 
 * @brief     State machine wrapper for ddr8 power region
 *            boots power sources in order of 1v0, 1v0a, 2v5a, 3v3,
 *            instantiates a power region manager and four state machines for each of the four power sources
 *            
 * 
 * @section changelog
 * - 09/02/2025: Chase Whyte - Initial implementation
 * 
 */
module pwr_region_eth2_bootseq # (
    parameter logic [31:0] WAIT_TIME_MULT_FACTOR = 32'd50 //multiply wait time in microseconds by 50 to convert to clock cycles. Can increase if power source
                                           //does not boot in time or decrease to improve simulation time
) (
    input  logic       clk,
    input  logic       rstn,
    input  logic       eth2_pgood_1v0,
    input  logic       eth2_pgood_1v0a,
    input  logic       eth2_pgood_2v5a,
    input  logic       eth2_pgood_3v3,
    input  logic       eth2_start_boot,
    input  logic       eth2_pwr_dwn,
    output logic       eth2_en_1v0,
    output logic       eth2_en_1v0a,
    output logic       eth2_en_2v5a,
    output logic       eth2_en_3v3,
    output logic       eth2_boot_succeeded,
    output logic       eth2_boot_failed,
    output logic       eth2_boot_done,
    output logic       eth2_srcs_off,
    output logic       eth2_latchup,
    output logic [2:0] eth2_failure_metadata
);

localparam logic [31:0] ETH2_1V0_WAIT_TIME = WAIT_TIME_MULT_FACTOR*25_000; //25 ms - set in timing.txt
localparam logic [31:0] ETH2_1V0A_WAIT_TIME = WAIT_TIME_MULT_FACTOR*25_000; //25 ms - set in timing.txt
localparam logic [31:0] ETH2_2V5A_WAIT_TIME = WAIT_TIME_MULT_FACTOR*25_000; //25 ms - set in timing.txt
localparam logic [31:0] ETH2_3V3_WAIT_TIME = WAIT_TIME_MULT_FACTOR*25_000; //25 ms - set in timing.txt
localparam logic [31:0] ETH2_RETRY_TIME    = WAIT_TIME_MULT_FACTOR*200_000; //200 ms - set in timing.txt

localparam logic [31:0] NUM_ETH2_PWR_SRCS  = 32'd4;

logic eth2_1v0_latchup;
logic eth2_1v0a_latchup;
logic eth2_2v5a_latchup;
logic eth2_3v3_latchup;

logic eth2_1v0_boot_succeeded;
logic eth2_1v0a_boot_succeeded;
logic eth2_2v5a_boot_succeeded;
logic eth2_3v3_boot_succeeded;

logic eth2_1v0_boot_failed;
logic eth2_1v0a_boot_failed;
logic eth2_2v5a_boot_failed;
logic eth2_3v3_boot_failed;

logic eth2_1v0_powered_dwn;
logic eth2_1v0a_powered_dwn;
logic eth2_2v5a_powered_dwn;
logic eth2_3v3_powered_dwn;

logic eth2_1v0_pwr_dwn;
logic eth2_1v0a_pwr_dwn;
logic eth2_2v5a_pwr_dwn;
logic eth2_3v3_pwr_dwn;

logic eth2_boot_timeout;
logic eth2_1v0_start_boot;

assign eth2_latchup        = eth2_1v0_latchup || eth2_1v0a_latchup || eth2_2v5a_latchup || eth2_3v3_latchup;
assign eth2_boot_succeeded = eth2_1v0_boot_succeeded && eth2_1v0a_boot_succeeded && eth2_2v5a_boot_succeeded && eth2_3v3_boot_succeeded;
assign eth2_boot_timeout   = eth2_1v0_boot_failed || eth2_1v0a_boot_failed || eth2_2v5a_boot_failed || eth2_3v3_boot_failed;

//power region sm controlling the three power sources: 1v0, 1v0a, 2v5a. Power sources boot in that order.
//
pwr_region_sm # (
    .RETRY_TIME  (ETH2_RETRY_TIME),
    .NUM_PWR_SRCS(NUM_ETH2_PWR_SRCS)
) pwr_region_sm_i (
    .clk,
    .rstn,
    .start_boot               (eth2_start_boot),
    .pwr_dwn                  (eth2_pwr_dwn),
    .latchup_occurred         (eth2_latchup),
    .boot_succeeded           (eth2_boot_succeeded),
    .boot_timeout             (eth2_boot_timeout),
    .pwr_srcs_powered_dwn     ({eth2_3v3_powered_dwn, eth2_2v5a_powered_dwn, eth2_1v0a_powered_dwn, eth2_1v0_powered_dwn}),
    .start_first_pwr_src_boot (eth2_1v0_start_boot),
    .pwr_dwn_pwr_srcs         ({eth2_3v3_pwr_dwn, eth2_2v5a_pwr_dwn, eth2_1v0a_pwr_dwn, eth2_1v0_pwr_dwn}),
    .boot_failed              (eth2_boot_failed),
    .boot_done                (eth2_boot_done),
    .srcs_off                 (eth2_srcs_off)
);

//first power source is initated in state machine
pwr_src_bootseq # (
    .WAIT_TIME(ETH2_1V0_WAIT_TIME)
) pwr_src_bootseq_eth2_1v0 (
    .clk,
    .rstn,
    .start_boot       (eth2_1v0_start_boot),
    .pgood            (eth2_pgood_1v0),
    .nfault           ('1),
    .pwr_dwn          (eth2_1v0_pwr_dwn),
    .pwr_en           (eth2_en_1v0),
    .boot_succeeded   (eth2_1v0_boot_succeeded),
    .boot_failed      (eth2_1v0_boot_failed),
    .powered_dwn      (eth2_1v0_powered_dwn),
    .latchup          (eth2_1v0_latchup)
);

//remaining power sources are turned on when previous power source in the boot sequence boots successfully
pwr_src_bootseq # (
    .WAIT_TIME(ETH2_1V0A_WAIT_TIME)
) pwr_src_bootseq_eth2_1v0a (
    .clk,
    .rstn,
    .start_boot       (eth2_1v0_boot_succeeded),
    .pgood            (eth2_pgood_1v0a),
    .nfault           ('1),
    .pwr_dwn          (eth2_1v0a_pwr_dwn),
    .pwr_en           (eth2_en_1v0a),
    .boot_succeeded   (eth2_1v0a_boot_succeeded),
    .boot_failed      (eth2_1v0a_boot_failed),
    .powered_dwn      (eth2_1v0a_powered_dwn),
    .latchup          (eth2_1v0a_latchup)
);

pwr_src_bootseq # (
    .WAIT_TIME(ETH2_2V5A_WAIT_TIME)
) pwr_src_bootseq_eth2_2v5a (
    .clk,
    .rstn,
    .start_boot       (eth2_1v0a_boot_succeeded),
    .pgood            (eth2_pgood_2v5a),
    .nfault           ('1),
    .pwr_dwn          (eth2_2v5a_pwr_dwn),
    .pwr_en           (eth2_en_2v5a),
    .boot_succeeded   (eth2_2v5a_boot_succeeded),
    .boot_failed      (eth2_2v5a_boot_failed),
    .powered_dwn      (eth2_2v5a_powered_dwn),
    .latchup          (eth2_2v5a_latchup)
);

pwr_src_bootseq # (
    .WAIT_TIME(ETH2_3V3_WAIT_TIME)
) pwr_src_bootseq_eth2_3v3 (
    .clk,
    .rstn,
    .start_boot       (eth2_2v5a_boot_succeeded),
    .pgood            (eth2_pgood_3v3),
    .nfault           ('1),
    .pwr_dwn          (eth2_3v3_pwr_dwn),
    .pwr_en           (eth2_en_3v3),
    .boot_succeeded   (eth2_3v3_boot_succeeded),
    .boot_failed      (eth2_3v3_boot_failed),
    .powered_dwn      (eth2_3v3_powered_dwn),
    .latchup          (eth2_3v3_latchup)
);

always_ff @(posedge clk) begin
    if(!rstn) begin
        eth2_failure_metadata <= '0;
    end
    else begin
        if(eth2_1v0_boot_failed)
            eth2_failure_metadata <= 3'd0;
        else if(eth2_1v0a_boot_failed)
            eth2_failure_metadata <= 3'd1;
        else if(eth2_2v5a_boot_failed)
            eth2_failure_metadata <= 3'd2;
        else if(eth2_3v3_boot_failed)
            eth2_failure_metadata <= 3'd3;
        else if(eth2_1v0_latchup)
            eth2_failure_metadata <= 3'd4;
        else if(eth2_1v0a_latchup)
            eth2_failure_metadata <= 3'd5;
        else if(eth2_2v5a_latchup)
            eth2_failure_metadata <= 3'd6;
        else if(eth2_3v3_latchup)
            eth2_failure_metadata <= 3'd7;
    end
end


endmodule
