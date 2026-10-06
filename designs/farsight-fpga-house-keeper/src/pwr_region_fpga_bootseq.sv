/*
 * @file      pwr_region_fpga_bootseq.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Chase Whyte (cwhyte@turionspace.com)
 * @date      09/02/2025
 * 
 * @brief     State machine wrapper for fpga power region
 *            boots power sources in order of 1v0, 1v0a, 1v25a, 1v8, 1v8 imx, 2v5a, 3v3 b4, 3v3 b5 
 *            instantiates a power region manager and eight state machines for each of the eight power sources
 *            
 * 
 * @section changelog
 * - 09/02/2025: Chase Whyte - Initial implementation
 * 
 */
module pwr_region_fpga_bootseq # (
    parameter logic [31:0] WAIT_TIME_MULT_FACTOR = 32'd50 //multiply wait time in microseconds by 50 to convert to clock cycles. Can increase if power source
                                           //does not boot in time or decrease to improve simulation time
) (
    input  logic clk,
    input  logic rstn,
    input  logic fpga_start_boot,
    input  logic fpga_pwr_dwn,
    input  logic fpga_pgood_1v0,
    input  logic fpga_pgood_1v0a,
    input  logic fpga_pgood_1v25a,
    input  logic fpga_pgood_1v8,
    input  logic fpga_pgood_1v8_imx,
    input  logic fpga_pgood_2v5a,
    input  logic fpga_pgood_3v3_b4,
    input  logic fpga_pgood_3v3_b5,
    input  logic fpga_nfault_1v0,
    output logic fpga_en_1v0,
    output logic fpga_en_1v0a,
    output logic fpga_en_1v25a,
    output logic fpga_en_1v8,
    output logic fpga_en_1v8_imx,
    output logic fpga_en_2v5a,
    output logic fpga_en_3v3_b4,
    output logic fpga_en_3v3_b5,
    output logic fpga_boot_succeeded,
    output logic fpga_boot_failed,
    output logic fpga_boot_done,
    output logic fpga_srcs_off,
    output logic fpga_latchup
);

localparam logic [31:0] FPGA_1V0_WAIT_TIME     = WAIT_TIME_MULT_FACTOR*25_000; //25 ms - set in timing.txt
localparam logic [31:0] FPGA_1V0A_WAIT_TIME    = WAIT_TIME_MULT_FACTOR*25_000; //25 ms - set in timing.txt
localparam logic [31:0] FPGA_1V25A_WAIT_TIME   = WAIT_TIME_MULT_FACTOR*25_000; //25 ms - set in timing.txt
localparam logic [31:0] FPGA_1V8_WAIT_TIME     = WAIT_TIME_MULT_FACTOR*25_000; //25 ms - set in timing.txt
localparam logic [31:0] FPGA_1V8_IMX_WAIT_TIME = WAIT_TIME_MULT_FACTOR*25_000; //25 ms - set in timing.txt
localparam logic [31:0] FPGA_2V5A_WAIT_TIME    = WAIT_TIME_MULT_FACTOR*25_000; //25 ms - set in timing.txt
localparam logic [31:0] FPGA_3V3_B4_WAIT_TIME  = WAIT_TIME_MULT_FACTOR*25_000; //25 ms - set in timing.txt
localparam logic [31:0] FPGA_3V3_B5_WAIT_TIME  = WAIT_TIME_MULT_FACTOR*25_000; //25 ms - set in timing.txt
localparam logic [31:0] FPGA_RETRY_TIME        = WAIT_TIME_MULT_FACTOR*200_000; //200 ms - set in timing.txt
localparam logic [31:0] NUM_FPGA_PWR_SRCS      = 32'd8;

logic fpga_1v0_latchup;
logic fpga_1v0a_latchup;
logic fpga_1v25a_latchup;
logic fpga_1v8_latchup;
logic fpga_1v8_imx_latchup;
logic fpga_2v5a_latchup;
logic fpga_3v3_b4_latchup;
logic fpga_3v3_b5_latchup;

logic fpga_1v0_boot_succeeded;
logic fpga_1v0a_boot_succeeded;
logic fpga_1v25a_boot_succeeded;
logic fpga_1v8_boot_succeeded;
logic fpga_1v8_imx_boot_succeeded;
logic fpga_2v5a_boot_succeeded;
logic fpga_3v3_b4_boot_succeeded;
logic fpga_3v3_b5_boot_succeeded;

logic fpga_1v0_boot_failed;
logic fpga_1v0a_boot_failed;
logic fpga_1v25a_boot_failed;
logic fpga_1v8_boot_failed;
logic fpga_1v8_imx_boot_failed;
logic fpga_2v5a_boot_failed;
logic fpga_3v3_b4_boot_failed;
logic fpga_3v3_b5_boot_failed;

logic fpga_1v0_powered_dwn;
logic fpga_1v0a_powered_dwn;
logic fpga_1v25a_powered_dwn;
logic fpga_1v8_powered_dwn;
logic fpga_1v8_imx_powered_dwn;
logic fpga_2v5a_powered_dwn;
logic fpga_3v3_b4_powered_dwn;
logic fpga_3v3_b5_powered_dwn;

logic fpga_1v0_pwr_dwn;
logic fpga_1v0a_pwr_dwn;
logic fpga_1v25a_pwr_dwn;
logic fpga_1v8_pwr_dwn;
logic fpga_1v8_imx_pwr_dwn;
logic fpga_2v5a_pwr_dwn;
logic fpga_3v3_b4_pwr_dwn;
logic fpga_3v3_b5_pwr_dwn;

logic fpga_boot_timeout;
logic fpga_1v0_start_boot;

assign fpga_latchup        = fpga_1v0_latchup || fpga_1v0a_latchup || fpga_1v25a_latchup || fpga_1v8_latchup || 
                             fpga_1v8_imx_latchup || fpga_2v5a_latchup || fpga_3v3_b4_latchup || fpga_3v3_b5_latchup;
                             
assign fpga_boot_succeeded = fpga_1v0_boot_succeeded && fpga_1v0a_boot_succeeded && fpga_1v25a_boot_succeeded && fpga_1v8_boot_succeeded && 
                             fpga_1v8_imx_boot_succeeded && fpga_2v5a_boot_succeeded && fpga_3v3_b4_boot_succeeded && fpga_3v3_b5_boot_succeeded;

assign fpga_boot_timeout   = fpga_1v0_boot_failed || fpga_1v0a_boot_failed || fpga_1v25a_boot_failed || fpga_1v8_boot_failed || 
                             fpga_1v8_imx_boot_failed || fpga_2v5a_boot_failed || fpga_3v3_b4_boot_failed || fpga_3v3_b5_boot_failed;

pwr_region_sm # (
    .RETRY_TIME  (FPGA_RETRY_TIME),
    .NUM_PWR_SRCS(NUM_FPGA_PWR_SRCS)
) pwr_region_sm_i (
    .clk,
    .rstn,
    .start_boot               (fpga_start_boot),
    .pwr_dwn                  (fpga_pwr_dwn),
    .latchup_occurred         (fpga_latchup),
    .boot_succeeded           (fpga_boot_succeeded),
    .boot_timeout             (fpga_boot_timeout),
    .pwr_srcs_powered_dwn     ({fpga_3v3_b5_powered_dwn, fpga_3v3_b4_powered_dwn, fpga_2v5a_powered_dwn, fpga_1v8_imx_powered_dwn, 
                              fpga_1v8_powered_dwn, fpga_1v25a_powered_dwn, fpga_1v0a_powered_dwn, fpga_1v0_powered_dwn}),
    .start_first_pwr_src_boot (fpga_1v0_start_boot),
    .pwr_dwn_pwr_srcs         ({fpga_3v3_b5_pwr_dwn, fpga_3v3_b4_pwr_dwn, fpga_2v5a_pwr_dwn, fpga_1v8_imx_pwr_dwn, 
                              fpga_1v8_pwr_dwn, fpga_1v25a_pwr_dwn, fpga_1v0a_pwr_dwn, fpga_1v0_pwr_dwn}),
    .boot_failed              (fpga_boot_failed),
    .boot_done                (fpga_boot_done),
    .srcs_off                 (fpga_srcs_off)
);

//first power source is initated in state machine
pwr_src_bootseq # (
    .WAIT_TIME(FPGA_1V0_WAIT_TIME)
) pwr_src_bootseq_fpga_1v0 (
    .clk,
    .rstn,
    .start_boot       (fpga_1v0_start_boot),
    .pgood            (fpga_pgood_1v0),
    .nfault           (fpga_nfault_1v0),
    .pwr_dwn          (fpga_1v0_pwr_dwn),
    .pwr_en           (fpga_en_1v0),
    .boot_succeeded   (fpga_1v0_boot_succeeded),
    .boot_failed      (fpga_1v0_boot_failed),
    .powered_dwn      (fpga_1v0_powered_dwn),
    .latchup          (fpga_1v0_latchup)
);

//remaining power sources are turned on when previous power source in the boot sequence boots successfully
pwr_src_bootseq # (
    .WAIT_TIME(FPGA_1V0A_WAIT_TIME)
) pwr_src_bootseq_fpga_1v0a (
    .clk,
    .rstn,
    .start_boot       (fpga_1v0_boot_succeeded),
    .pgood            (fpga_pgood_1v0a),
    .nfault           ('1),
    .pwr_dwn          (fpga_1v0a_pwr_dwn),
    .pwr_en           (fpga_en_1v0a),
    .boot_succeeded   (fpga_1v0a_boot_succeeded),
    .boot_failed      (fpga_1v0a_boot_failed),
    .powered_dwn      (fpga_1v0a_powered_dwn),
    .latchup          (fpga_1v0a_latchup)
);

pwr_src_bootseq # (
    .WAIT_TIME(FPGA_1V25A_WAIT_TIME)
) pwr_src_bootseq_fpga_1v25a (
    .clk,
    .rstn,
    .start_boot       (fpga_1v0a_boot_succeeded),
    .pgood            (fpga_pgood_1v25a),
    .nfault           ('1),
    .pwr_dwn          (fpga_1v25a_pwr_dwn),
    .pwr_en           (fpga_en_1v25a),
    .boot_succeeded   (fpga_1v25a_boot_succeeded),
    .boot_failed      (fpga_1v25a_boot_failed),
    .powered_dwn      (fpga_1v25a_powered_dwn),
    .latchup          (fpga_1v25a_latchup)
);

pwr_src_bootseq # (
    .WAIT_TIME(FPGA_1V8_WAIT_TIME)
) pwr_src_bootseq_fpga_1v8 (
    .clk,
    .rstn,
    .start_boot       (fpga_1v25a_boot_succeeded),
    .pgood            (fpga_pgood_1v8),
    .nfault           ('1),
    .pwr_dwn          (fpga_1v8_pwr_dwn),
    .pwr_en           (fpga_en_1v8),
    .boot_succeeded   (fpga_1v8_boot_succeeded),
    .boot_failed      (fpga_1v8_boot_failed),
    .powered_dwn      (fpga_1v8_powered_dwn),
    .latchup          (fpga_1v8_latchup)
);

pwr_src_bootseq # (
    .WAIT_TIME(FPGA_1V8_IMX_WAIT_TIME)
) pwr_src_bootseq_fpga_1v8_imx (
    .clk,
    .rstn,
    .start_boot       (fpga_1v8_boot_succeeded),
    .pgood            (fpga_pgood_1v8_imx),
    .nfault           ('1),
    .pwr_dwn          (fpga_1v8_imx_pwr_dwn),
    .pwr_en           (fpga_en_1v8_imx),
    .boot_succeeded   (fpga_1v8_imx_boot_succeeded),
    .boot_failed      (fpga_1v8_imx_boot_failed),
    .powered_dwn      (fpga_1v8_imx_powered_dwn),
    .latchup          (fpga_1v8_imx_latchup)
);

pwr_src_bootseq # (
    .WAIT_TIME(FPGA_2V5A_WAIT_TIME)
) pwr_src_bootseq_fpga_2v5a (
    .clk,
    .rstn,
    .start_boot       (fpga_1v8_imx_boot_succeeded),
    .pgood            (fpga_pgood_2v5a),
    .nfault           ('1),
    .pwr_dwn          (fpga_2v5a_pwr_dwn),
    .pwr_en           (fpga_en_2v5a),
    .boot_succeeded   (fpga_2v5a_boot_succeeded),
    .boot_failed      (fpga_2v5a_boot_failed),
    .powered_dwn      (fpga_2v5a_powered_dwn),
    .latchup          (fpga_2v5a_latchup)
);

pwr_src_bootseq # (
    .WAIT_TIME(FPGA_3V3_B4_WAIT_TIME)
) pwr_src_bootseq_fpga_3v3_b4 (
    .clk,
    .rstn,
    .start_boot       (fpga_2v5a_boot_succeeded),
    .pgood            (fpga_pgood_3v3_b4),
    .nfault           ('1),
    .pwr_dwn          (fpga_3v3_b4_pwr_dwn),
    .pwr_en           (fpga_en_3v3_b4),
    .boot_succeeded   (fpga_3v3_b4_boot_succeeded),
    .boot_failed      (fpga_3v3_b4_boot_failed),
    .powered_dwn      (fpga_3v3_b4_powered_dwn),
    .latchup          (fpga_3v3_b4_latchup)
);

pwr_src_bootseq # (
    .WAIT_TIME(FPGA_3V3_B5_WAIT_TIME)
) pwr_src_bootseq_fpga_3v3_b5 (
    .clk,
    .rstn,
    .start_boot       (fpga_3v3_b4_boot_succeeded),
    .pgood            (fpga_pgood_3v3_b5),
    .nfault           ('1),
    .pwr_dwn          (fpga_3v3_b5_pwr_dwn),
    .pwr_en           (fpga_en_3v3_b5),
    .boot_succeeded   (fpga_3v3_b5_boot_succeeded),
    .boot_failed      (fpga_3v3_b5_boot_failed),
    .powered_dwn      (fpga_3v3_b5_powered_dwn),
    .latchup          (fpga_3v3_b5_latchup)
);

endmodule
