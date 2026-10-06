/*
 * @file      pwr_region_imx_bootseq.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Chase Whyte (cwhyte@turionspace.com)
 * @date      09/02/2025
 * 
 * @brief     State machine wrapper for ddr8 power region
 *            boots power sources in order of 1v0, 1v0a, 2v9, 3v3,
 *            instantiates a power region manager and four state machines for each of the four power sources
 *            
 * 
 * @section changelog
 * - 09/02/2025: Chase Whyte - Initial implementation
 * 
 */
module pwr_region_imx_bootseq # (
    parameter logic [31:0] WAIT_TIME_MULT_FACTOR = 32'd50 //multiply wait time in microseconds by 50 to convert to clock cycles. Can increase if power source
                                           //does not boot in time or decrease to improve simulation time
) (
    input  logic       clk,
    input  logic       rstn,
    input  logic       imx_nfault_1v1,
    input  logic       imx_pgood_1v1,
    input  logic       imx_pgood_1v8,
    input  logic       imx_pgood_2v9,
    input  logic       imx_pgood_3v3,
    input  logic       imx_start_boot,
    input  logic       imx_pwr_dwn,
    output logic       imx_en_1v1,
    output logic       imx_en_1v8,
    output logic       imx_en_2v9,
    output logic       imx_en_3v3,
    output logic       imx_boot_succeeded,
    output logic       imx_boot_failed,
    output logic       imx_boot_done,
    output logic       imx_srcs_off,
    output logic       imx_latchup,
    output logic [2:0] imx_failure_metadata
);

localparam logic [31:0] IMX_1V1_WAIT_TIME = WAIT_TIME_MULT_FACTOR*25_000; //25 ms - set in timing.txt
localparam logic [31:0] IMX_1V8_WAIT_TIME = WAIT_TIME_MULT_FACTOR*25_000; //25 ms - set in timing.txt
localparam logic [31:0] IMX_2V9_WAIT_TIME = WAIT_TIME_MULT_FACTOR*25_000; //25 ms - set in timing.txt
localparam logic [31:0] IMX_3V3_WAIT_TIME = WAIT_TIME_MULT_FACTOR*25_000; //25 ms - set in timing.txt
localparam logic [31:0] IMX_RETRY_TIME    = WAIT_TIME_MULT_FACTOR*200_000; //200 ms - set in timing.txt

localparam logic [31:0] NUM_IMX_PWR_SRCS  = 32'd4;

logic imx_1v1_latchup;
logic imx_1v8_latchup;
logic imx_2v9_latchup;
logic imx_3v3_latchup;

logic imx_1v1_boot_succeeded;
logic imx_1v8_boot_succeeded;
logic imx_2v9_boot_succeeded;
logic imx_3v3_boot_succeeded;

logic imx_1v1_boot_failed;
logic imx_1v8_boot_failed;
logic imx_2v9_boot_failed;
logic imx_3v3_boot_failed;

logic imx_1v1_powered_dwn;
logic imx_1v8_powered_dwn;
logic imx_2v9_powered_dwn;
logic imx_3v3_powered_dwn;

logic imx_1v1_pwr_dwn;
logic imx_1v8_pwr_dwn;
logic imx_2v9_pwr_dwn;
logic imx_3v3_pwr_dwn;

logic imx_boot_timeout;
logic imx_1v1_start_boot;

assign imx_latchup        = imx_1v1_latchup || imx_1v8_latchup || imx_2v9_latchup || imx_3v3_latchup;
assign imx_boot_succeeded = imx_1v1_boot_succeeded && imx_1v8_boot_succeeded && imx_2v9_boot_succeeded && imx_3v3_boot_succeeded;
assign imx_boot_timeout   = imx_1v1_boot_failed || imx_1v8_boot_failed || imx_2v9_boot_failed || imx_3v3_boot_failed;

//power region sm controlling the three power sources: 1v0, 1v0a, 2v9. Power sources boot in that order.
//
//assign debug = {imx_en_2v9, imx_pgood_2v9, imx_en_3v3, imx_pgood_3v3, imx_2v9_boot_succeeded, imx_3v3_boot_failed, imx_3v3_pwr_dwn};
pwr_region_sm # (
    .RETRY_TIME  (IMX_RETRY_TIME),
    .NUM_PWR_SRCS(NUM_IMX_PWR_SRCS)
) pwr_region_sm_i (
    .clk,
    .rstn,
    .start_boot               (imx_start_boot),
    .pwr_dwn                  (imx_pwr_dwn),
    .latchup_occurred         (imx_latchup),
    .boot_succeeded           (imx_boot_succeeded),
    .boot_timeout             (imx_boot_timeout),
    .pwr_srcs_powered_dwn     ({imx_3v3_powered_dwn, imx_2v9_powered_dwn, imx_1v8_powered_dwn, imx_1v1_powered_dwn}),
    .start_first_pwr_src_boot (imx_1v1_start_boot),
    .pwr_dwn_pwr_srcs         ({imx_3v3_pwr_dwn, imx_2v9_pwr_dwn, imx_1v8_pwr_dwn, imx_1v1_pwr_dwn}),
    .boot_failed              (imx_boot_failed),
    .boot_done                (imx_boot_done),
    .srcs_off                 (imx_srcs_off)
);

//first power source is initated in state machine
pwr_src_bootseq # (
    .WAIT_TIME(IMX_1V1_WAIT_TIME)
) pwr_src_bootseq_imx_1v1 (
    .clk,
    .rstn,
    .start_boot       (imx_1v1_start_boot),
    .pgood            (imx_pgood_1v1),
    .nfault           (imx_nfault_1v1),
    .pwr_dwn          (imx_1v1_pwr_dwn),
    .pwr_en           (imx_en_1v1),
    .boot_succeeded   (imx_1v1_boot_succeeded),
    .boot_failed      (imx_1v1_boot_failed),
    .powered_dwn      (imx_1v1_powered_dwn),
    .latchup          (imx_1v1_latchup)
);

//remaining power sources are turned on when previous power source in the boot sequence boots successfully
pwr_src_bootseq # (
    .WAIT_TIME(IMX_1V8_WAIT_TIME)
) pwr_src_bootseq_imx_1v8 (
    .clk,
    .rstn,
    .start_boot       (imx_1v1_boot_succeeded),
    .pgood            (imx_pgood_1v8),
    .nfault           ('1),
    .pwr_dwn          (imx_1v8_pwr_dwn),
    .pwr_en           (imx_en_1v8),
    .boot_succeeded   (imx_1v8_boot_succeeded),
    .boot_failed      (imx_1v8_boot_failed),
    .powered_dwn      (imx_1v8_powered_dwn),
    .latchup          (imx_1v8_latchup)
);

pwr_src_bootseq # (
    .WAIT_TIME(IMX_2V9_WAIT_TIME)
) pwr_src_bootseq_imx_2v9 (
    .clk,
    .rstn,
    .start_boot       (imx_1v8_boot_succeeded),
    .pgood            (imx_pgood_2v9),
    .nfault           ('1),
    .pwr_dwn          (imx_2v9_pwr_dwn),
    .pwr_en           (imx_en_2v9),
    .boot_succeeded   (imx_2v9_boot_succeeded),
    .boot_failed      (imx_2v9_boot_failed),
    .powered_dwn      (imx_2v9_powered_dwn),
    .latchup          (imx_2v9_latchup)
);

pwr_src_bootseq # (
    .WAIT_TIME(IMX_3V3_WAIT_TIME)
) pwr_src_bootseq_imx_3v3 (
    .clk,
    .rstn,
    .start_boot       (imx_2v9_boot_succeeded),
    .pgood            (imx_pgood_3v3),
    .nfault           ('1),
    .pwr_dwn          (imx_3v3_pwr_dwn),
    .pwr_en           (imx_en_3v3),
    .boot_succeeded   (imx_3v3_boot_succeeded),
    .boot_failed      (imx_3v3_boot_failed),
    .powered_dwn      (imx_3v3_powered_dwn),
    .latchup          (imx_3v3_latchup)
);

always_ff @(posedge clk) begin
    if(!rstn) begin
        imx_failure_metadata <= '0;
    end
    else begin
        if(imx_1v1_boot_failed)
            imx_failure_metadata <= 3'd0;
        else if(imx_1v8_boot_failed)
            imx_failure_metadata <= 3'd1;
        else if(imx_2v9_boot_failed)
            imx_failure_metadata <= 3'd2;
        else if(imx_3v3_boot_failed)
            imx_failure_metadata <= 3'd3;
        else if(imx_1v1_latchup)
            imx_failure_metadata <= 3'd4;
        else if(imx_1v8_latchup)
            imx_failure_metadata <= 3'd5;
        else if(imx_2v9_latchup)
            imx_failure_metadata <= 3'd6;
        else if(imx_3v3_latchup)
            imx_failure_metadata <= 3'd7;
    end
end


endmodule
