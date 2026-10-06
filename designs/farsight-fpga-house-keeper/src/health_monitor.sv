/*
 * @file      health_monitor.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Chase Whyte (cwhyte@turionspace.com)
 * @date      08/14/2025
 * 
 * @brief     Short description of what this module does.
 * 
 * @section changelog
 * - 08/14/2025: Chase Whyte - Initial implementation
 * 
 */

module health_monitor # (
    parameter logic [31:0]                 WAIT_TIME_MULT_FACTOR = 32'd50

) (
    input  logic              clk,
    input  logic              rstn,
    input  logic              ddr16_nfault_2v5,
    input  logic              ddr16_nfault_1v2,
    input  logic              ddr16_pgood_2v5,
    input  logic              ddr16_pgood_1v2,
    input  logic              ddr16_pgood_0v6,
    input  logic              ddr8_nfault_2v5,
    input  logic              ddr8_nfault_1v2,
    input  logic              ddr8_pgood_2v5,
    input  logic              ddr8_pgood_1v2,
    input  logic              ddr8_pgood_0v6,
    input  logic              eth1_ctrl,
    input  logic              eth1_pgood_1v0,
    input  logic              eth1_pgood_1v0a,
    input  logic              eth1_pgood_2v5a,
    input  logic              eth1_pgood_3v3,
    input  logic              eth2_ctrl,
    input  logic              eth2_pgood_1v0,
    input  logic              eth2_pgood_1v0a,
    input  logic              eth2_pgood_2v5a,
    input  logic              eth2_pgood_3v3,
    input  logic              fpga_nfault_1v0,
    input  logic              fpga_pgood_1v0,
    input  logic              fpga_pgood_1v0a,
    input  logic              fpga_pgood_1v25a,
    input  logic              fpga_pgood_1v8,
    input  logic              fpga_pgood_1v8_imx,
    input  logic              fpga_pgood_2v5a,
    input  logic              fpga_pgood_3v3_b4,
    input  logic              fpga_pgood_3v3_b5,
    input  logic              imx_ctrl,
    input  logic              imx_nfault_1v1,
    input  logic              imx_pgood_1v1,
    input  logic              imx_pgood_1v8,
    input  logic              imx_pgood_2v9,
    input  logic              imx_pgood_3v3,
    input  logic              lvdt_ctrl,
    input  logic              lvdt_pgood,
    input  logic              lvds_pgood,
    input  logic              step_down_nfault_2v2,
    input  logic              step_down_nfault_3v0,
    input  logic              step_down_nfault_4v0,
    input  logic              step_down_pgood_2v2,
    input  logic              step_down_pgood_3v0,
    input  logic              step_down_pgood_4v0,
    input  logic              stepper_pri_ctrl,
    input  logic              stepper_pri_nfault,
    input  logic              stepper_pri_pgood,
    input  logic              stepper_sec_ctrl,
    input  logic              stepper_sec_nfault,
    input  logic              stepper_sec_pgood,
    output logic              ddr16_en_2v5,
    output logic              ddr16_en_1v2,
    output logic              ddr16_en_0v6,
    output logic              ddr8_en_2v5,
    output logic              ddr8_en_1v2,
    output logic              ddr8_en_0v6,
    output logic              eth1_en_1v0,
    output logic              eth1_en_1v0a,
    output logic              eth1_en_2v5a,
    output logic              eth1_en_3v3,
    output logic              eth2_en_1v0,
    output logic              eth2_en_1v0a,
    output logic              eth2_en_2v5a,
    output logic              eth2_en_3v3,
    output logic              fpga_en_1v0,
    output logic              fpga_en_1v0a,
    output logic              fpga_en_1v25a,
    output logic              fpga_en_1v8,
    output logic              fpga_en_1v8_imx,
    output logic              fpga_en_2v5a,
    output logic              fpga_en_3v3_b4,
    output logic              fpga_en_3v3_b5,
    output logic              imx_en_1v1,
    output logic              imx_en_1v8,
    output logic              imx_en_2v9,
    output logic              imx_en_3v3,
    output logic              lvdt_en,
    output logic              lvds_en,
    output logic              step_down_en_2v2,
    output logic              step_down_en_3v0,
    output logic              step_down_en_4v0,
    output logic              stepper_pri_en,
    output logic              stepper_sec_en,
    output logic              imx_nshort_1v1,
    output logic              imx_nshort_1v8,
    input  logic              eps_efuse_pgood,
    output logic              failed,
    output logic [2:0]        fw_version,
    output logic [6:0]        debug,
    output logic              heartbeat,
    output logic              step_down_boot_succeeded,
    output logic              ddr8_boot_succeeded,
    output logic              ddr16_boot_succeeded,
    output logic              fpga_boot_succeeded,
    output logic              lvds_boot_succeeded,
    output logic              eth1_boot_succeeded,
    output logic              eth2_boot_succeeded,
    output logic              stepper_pri_boot_succeeded,
    output logic              stepper_sec_boot_succeeded,
    output logic              lvdt_boot_succeeded,
    output logic              imx_boot_succeeded,
    output logic              step_down_pgood_2v2_on_fail,
    output logic              step_down_pgood_3v0_on_fail,
    output logic              step_down_pgood_4v0_on_fail,
    output logic              step_down_nfault_2v2_on_fail,
    output logic              step_down_nfault_3v0_on_fail,
    output logic              step_down_nfault_4v0_on_fail,
    output logic              ddr8_pgood_2v5_on_fail,
    output logic              ddr8_pgood_1v2_on_fail,
    output logic              ddr8_pgood_0v6_on_fail,
    output logic              ddr8_nfault_2v5_on_fail,
    output logic              ddr8_nfault_1v2_on_fail,
    output logic              ddr16_pgood_2v5_on_fail,
    output logic              ddr16_pgood_1v2_on_fail,
    output logic              ddr16_pgood_0v6_on_fail,
    output logic              ddr16_nfault_2v5_on_fail,
    output logic              ddr16_nfault_1v2_on_fail,
    output logic              fpga_nfault_1v0_on_fail,
    output logic              fpga_pgood_1v0_on_fail,
    output logic              fpga_pgood_1v0a_on_fail,
    output logic              fpga_pgood_1v25a_on_fail,
    output logic              fpga_pgood_1v8_on_fail,
    output logic              fpga_pgood_1v8_imx_on_fail,
    output logic              fpga_pgood_2v5a_on_fail,
    output logic              fpga_pgood_3v3_b4_on_fail,
    output logic              fpga_pgood_3v3_b5_on_fail,
    output logic              lvds_pgood_on_fail,
    output logic [1:0]        ddr8_failure_metadata,
    output logic [1:0]        ddr16_failure_metadata,
    output logic [2:0]        eth1_failure_metadata,
    output logic [2:0]        eth2_failure_metadata,
    output logic              stepper_pri_failure_metadata,
    output logic              stepper_sec_failure_metadata,
    output logic              lvdt_failure_metadata,
    output logic [2:0]        imx_failure_metadata
);
localparam logic [31:0] CNTR_PRECISION      = 32'd18;         //cntr will increment every 2^(CNTR_PRECISION) clock cycles
localparam logic [31:0] CNTR_RESOLUTION     = 32'd8;          //# of bits to hold the number of time periods equal to 2^(CNTR_PRECISION) clock cycles that have elapsed
localparam logic [31:0] SECOND              = 32'd50_000_000; //50mhz clock cycles in a second

logic                         start_pwr_dwn;
logic                         critical_latchup;

logic                         step_down_start_boot;
logic                         ddr8_start_boot;
logic                         ddr16_start_boot;
logic                         fpga_start_boot;
logic                         lvds_start_boot;
logic                         eth1_start_boot;
logic                         eth2_start_boot;
logic                         stepper_pri_start_boot;
logic                         stepper_sec_start_boot;
logic                         lvdt_start_boot;
logic                         imx_start_boot;

logic                         step_down_pwr_dwn;
logic                         ddr8_pwr_dwn;
logic                         ddr16_pwr_dwn;
logic                         fpga_pwr_dwn;
logic                         lvds_pwr_dwn;
logic                         eth1_pwr_dwn;
logic                         eth2_pwr_dwn;
logic                         stepper_pri_pwr_dwn;
logic                         stepper_sec_pwr_dwn;
logic                         lvdt_pwr_dwn;
logic                         imx_pwr_dwn;

logic                         step_down_boot_done;
logic                         step_down_srcs_off;
logic                         ddr8_boot_done;
logic                         ddr8_srcs_off;
logic                         ddr16_boot_done;
logic                         ddr16_srcs_off;
logic                         fpga_boot_done;
logic                         fpga_srcs_off;
logic                         lvds_boot_done;
logic                         lvds_srcs_off;
logic                         eth1_boot_done;
logic                         eth1_srcs_off;
logic                         eth2_boot_done;
logic                         eth2_srcs_off;
logic                         stepper_pri_boot_done;
logic                         stepper_pri_srcs_off;
logic                         stepper_sec_boot_done;
logic                         stepper_sec_srcs_off;
logic                         lvdt_boot_done;
logic                         lvdt_srcs_off;
logic                         imx_boot_done;
logic                         imx_srcs_off;

logic                         step_down_boot_failed;
logic                         ddr8_boot_failed;
logic                         ddr16_boot_failed;
logic                         fpga_boot_failed;
logic                         lvds_boot_failed;
logic                         eth1_boot_failed;
logic                         eth2_boot_failed;
logic                         stepper_pri_boot_failed;
logic                         stepper_sec_boot_failed;
logic                         lvdt_boot_failed;
logic                         imx_boot_failed;

logic                         step_down_latchup;
logic                         ddr8_latchup;
logic                         ddr16_latchup;
logic                         fpga_latchup;
logic                         lvds_latchup;
logic                         eth1_latchup;
logic                         eth2_latchup;
logic                         stepper_pri_latchup;
logic                         stepper_sec_latchup;
logic                         lvdt_latchup;
logic                         imx_latchup;

logic                         eth1_ctrl_r1;
logic                         eth2_ctrl_r1;
logic                         stepper_pri_ctrl_r1;
logic                         stepper_sec_ctrl_r1;
logic                         lvdt_ctrl_r1;
logic                         imx_ctrl_r1;

logic [CNTR_RESOLUTION-1:0]   cntr;
logic                         clr;


//power state machine controlling step down converter region
pwr_region_step_down_bootseq # (
    .WAIT_TIME_MULT_FACTOR (WAIT_TIME_MULT_FACTOR)
) step_down_conv_sm (
    .clk,
    .rstn(rstn && !critical_latchup),
    .step_down_start_boot,
    .step_down_pwr_dwn,
    .step_down_pgood_2v2,
    .step_down_pgood_3v0,
    .step_down_pgood_4v0,
    .step_down_nfault_2v2,
    .step_down_nfault_3v0,
    .step_down_nfault_4v0,
    .step_down_en_2v2,
    .step_down_en_3v0,
    .step_down_en_4v0,
    .step_down_boot_succeeded,
    .step_down_boot_failed,
    .step_down_boot_done,
    .step_down_srcs_off,
    .step_down_latchup
);

//power state machine controlling ddr8 region
pwr_region_ddr8_bootseq # (
    .WAIT_TIME_MULT_FACTOR (WAIT_TIME_MULT_FACTOR)
) ddr8_sm (
    .clk,
    .rstn(rstn && !critical_latchup),
    .ddr8_pgood_2v5,
    .ddr8_pgood_1v2,
    .ddr8_pgood_0v6,
    .ddr8_nfault_2v5,
    .ddr8_nfault_1v2,
    .ddr8_start_boot,
    .ddr8_pwr_dwn,
    .fpga_boot_succeeded,
    .ddr8_en_2v5,
    .ddr8_en_1v2,
    .ddr8_en_0v6,
    .ddr8_boot_succeeded,
    .ddr8_boot_failed,
    .ddr8_boot_done,
    .ddr8_srcs_off,
    .ddr8_latchup,
    .ddr8_failure_metadata
);

//power state machine controlling ddr16 region
pwr_region_ddr16_bootseq # (
    .WAIT_TIME_MULT_FACTOR (WAIT_TIME_MULT_FACTOR)
) ddr16_sm (
    .clk,
    .rstn(rstn && !critical_latchup),
    .ddr16_pgood_2v5,
    .ddr16_pgood_1v2,
    .ddr16_pgood_0v6,
    .ddr16_nfault_2v5,
    .ddr16_nfault_1v2,
    .ddr16_start_boot,
    .ddr16_pwr_dwn,
    .fpga_boot_succeeded,
    .ddr16_en_2v5,
    .ddr16_en_1v2,
    .ddr16_en_0v6,
    .ddr16_boot_succeeded,
    .ddr16_boot_failed,
    .ddr16_boot_done,
    .ddr16_srcs_off,
    .ddr16_latchup,
    .ddr16_failure_metadata
);

//power state machine controlling fpga region
pwr_region_fpga_bootseq # (
    .WAIT_TIME_MULT_FACTOR (WAIT_TIME_MULT_FACTOR)
) fpga_sm (
    .clk,
    .rstn(rstn && !critical_latchup),
    .fpga_start_boot,
    .fpga_pwr_dwn,
    .fpga_pgood_1v0,
    .fpga_pgood_1v0a,
    .fpga_pgood_1v25a,
    .fpga_pgood_1v8,
    .fpga_pgood_1v8_imx,
    .fpga_pgood_2v5a,
    .fpga_pgood_3v3_b4,
    .fpga_pgood_3v3_b5,
    .fpga_nfault_1v0,
    .fpga_en_1v0,
    .fpga_en_1v0a,
    .fpga_en_1v25a,
    .fpga_en_1v8,
    .fpga_en_1v8_imx,
    .fpga_en_2v5a,
    .fpga_en_3v3_b4,
    .fpga_en_3v3_b5,
    .fpga_boot_succeeded,
    .fpga_boot_failed,
    .fpga_boot_done,
    .fpga_srcs_off,
    .fpga_latchup
);

//power state machine controlling lvds region
pwr_region_lvds_bootseq # (
    .WAIT_TIME_MULT_FACTOR (WAIT_TIME_MULT_FACTOR)
) lvds_sm (
    .clk,
    .rstn(rstn && !critical_latchup),
    .lvds_pgood,
    .lvds_start_boot,
    .lvds_pwr_dwn,
    .lvds_en,
    .lvds_boot_succeeded,
    .lvds_boot_failed,
    .lvds_boot_done,
    .lvds_srcs_off,
    .lvds_latchup
);

//power state machine controlling eth1 region
pwr_region_eth1_bootseq # (
    .WAIT_TIME_MULT_FACTOR (WAIT_TIME_MULT_FACTOR)
) eth1_sm (
    .clk,
    .rstn(rstn && !critical_latchup),
    .eth1_pgood_1v0,
    .eth1_pgood_1v0a,
    .eth1_pgood_2v5a,
    .eth1_pgood_3v3,
    .eth1_start_boot,
    .eth1_pwr_dwn,
    .eth1_en_1v0,
    .eth1_en_1v0a,
    .eth1_en_2v5a,
    .eth1_en_3v3,
    .eth1_boot_succeeded,
    .eth1_boot_failed,
    .eth1_boot_done,
    .eth1_srcs_off,
    .eth1_latchup,
    .eth1_failure_metadata
);

//power state machine controlling eth2 region
pwr_region_eth2_bootseq # (
    .WAIT_TIME_MULT_FACTOR (WAIT_TIME_MULT_FACTOR)
) eth2_sm (
    .clk,
    .rstn(rstn && !critical_latchup),
    .eth2_pgood_1v0,
    .eth2_pgood_1v0a,
    .eth2_pgood_2v5a,
    .eth2_pgood_3v3,
    .eth2_start_boot,
    .eth2_pwr_dwn,
    .eth2_en_1v0,
    .eth2_en_1v0a,
    .eth2_en_2v5a,
    .eth2_en_3v3,
    .eth2_boot_succeeded,
    .eth2_boot_failed,
    .eth2_boot_done,
    .eth2_srcs_off,
    .eth2_latchup,
    .eth2_failure_metadata
);

//power state machine controlling stepper pri region
pwr_region_stepper_pri_bootseq # (
    .WAIT_TIME_MULT_FACTOR (WAIT_TIME_MULT_FACTOR)
) stepper_pri_sm (
    .clk,
    .rstn(rstn && !critical_latchup),
    .stepper_pri_pgood,
    .stepper_pri_nfault,
    .stepper_pri_start_boot,
    .stepper_pri_pwr_dwn,
    .stepper_pri_en,
    .stepper_pri_boot_succeeded,
    .stepper_pri_boot_failed,
    .stepper_pri_boot_done,
    .stepper_pri_srcs_off,
    .stepper_pri_latchup,
    .stepper_pri_failure_metadata
);

//power state machine controlling stepper sec region
pwr_region_stepper_sec_bootseq # (
    .WAIT_TIME_MULT_FACTOR (WAIT_TIME_MULT_FACTOR)
) stepper_sec_sm (
    .clk,
    .rstn(rstn && !critical_latchup),
    .stepper_sec_pgood,
    .stepper_sec_nfault,
    .stepper_sec_start_boot,
    .stepper_sec_pwr_dwn,
    .stepper_sec_en,
    .stepper_sec_boot_succeeded,
    .stepper_sec_boot_failed,
    .stepper_sec_boot_done,
    .stepper_sec_srcs_off,
    .stepper_sec_latchup,
    .stepper_sec_failure_metadata
);

//power state machine controlling lvdt region
pwr_region_lvdt_bootseq # (
    .WAIT_TIME_MULT_FACTOR (WAIT_TIME_MULT_FACTOR)
) lvdt_sm (
    .clk,
    .rstn(rstn && !critical_latchup),
    .lvdt_pgood,
    .lvdt_start_boot,
    .lvdt_pwr_dwn,
    .lvdt_en,
    .lvdt_boot_succeeded,
    .lvdt_boot_failed,
    .lvdt_boot_done,
    .lvdt_srcs_off,
    .lvdt_latchup,
    .lvdt_failure_metadata
);

//power state machine controlling imx region
pwr_region_imx_bootseq # (
    .WAIT_TIME_MULT_FACTOR (WAIT_TIME_MULT_FACTOR)
) imx_sm (
    .clk,
    .rstn(rstn && !critical_latchup),
    .imx_nfault_1v1,
    .imx_pgood_1v1,
    .imx_pgood_1v8,
    .imx_pgood_2v9,
    .imx_pgood_3v3,
    .imx_start_boot,
    .imx_pwr_dwn,
    .imx_en_1v1,
    .imx_en_1v8,
    .imx_en_2v9,
    .imx_en_3v3,
    .imx_boot_succeeded,
    .imx_boot_failed,
    .imx_boot_done,
    .imx_srcs_off,
    .imx_latchup,
    .imx_failure_metadata
);

proasic3_counter # (
    .CNTR_RESOLUTION(CNTR_RESOLUTION),
    .CNTR_PRECISION (CNTR_PRECISION)
) proasic3_counter_i (
    .clk,
    .rstn,
    .clr,
    .cntr
);

assign clr        = (cntr >= (SECOND >> CNTR_PRECISION));
assign fw_version = fpga_boot_succeeded ? 3'd2 : '0;

always_ff @(posedge clk) begin
    if(!rstn) begin
        heartbeat            <= '0;
        step_down_start_boot <= '0;
    end
    else begin
        if(cntr >= (SECOND >> CNTR_PRECISION)) begin
            heartbeat            <= ~heartbeat;
            step_down_start_boot <= '1;
        end
    end
end

always_ff @(posedge clk) begin
    if(!rstn) begin
        step_down_pwr_dwn      <= '0;
        ddr8_pwr_dwn           <= '0;
        ddr16_pwr_dwn          <= '0;
        fpga_pwr_dwn           <= '0;
        lvds_pwr_dwn           <= '0;
        eth1_start_boot        <= '0;
        eth1_pwr_dwn           <= '0;
        eth2_start_boot        <= '0;
        eth2_pwr_dwn           <= '0;
        stepper_pri_start_boot <= '0;
        stepper_pri_pwr_dwn    <= '0;
        stepper_sec_start_boot <= '0;
        stepper_sec_pwr_dwn    <= '0;
        lvdt_start_boot        <= '0;
        lvdt_pwr_dwn           <= '0;
        imx_start_boot         <= '0;
        imx_pwr_dwn            <= '0;
    end 
    else begin
        //sw controlled power regions
        imx_pwr_dwn         <= !imx_ctrl || !fpga_boot_succeeded || start_pwr_dwn;
        lvdt_pwr_dwn        <= !lvdt_ctrl || !fpga_boot_succeeded || start_pwr_dwn;
        stepper_sec_pwr_dwn <= !stepper_sec_ctrl || !fpga_boot_succeeded || start_pwr_dwn || stepper_pri_boot_succeeded;
        stepper_pri_pwr_dwn <= !stepper_pri_ctrl || !fpga_boot_succeeded || start_pwr_dwn;
        eth1_pwr_dwn        <= !eth1_ctrl || !fpga_boot_succeeded || start_pwr_dwn;
        eth2_pwr_dwn        <= !eth2_ctrl || !fpga_boot_succeeded || start_pwr_dwn;

        //hw controlled power regions
        step_down_pwr_dwn <= start_pwr_dwn && ddr8_srcs_off;
        ddr8_pwr_dwn      <= start_pwr_dwn && ddr16_srcs_off;
        ddr16_pwr_dwn     <= start_pwr_dwn && fpga_srcs_off;
        fpga_pwr_dwn      <= start_pwr_dwn && lvds_srcs_off;
        lvds_pwr_dwn      <= start_pwr_dwn && &{eth1_srcs_off, eth2_srcs_off, stepper_pri_srcs_off, 
                                          stepper_sec_srcs_off, lvdt_srcs_off, imx_srcs_off};

        if(fpga_boot_succeeded && {eth1_ctrl_r1, eth1_ctrl} == 2'b01) begin
            eth1_start_boot <= '1;
        end
        else if(eth1_boot_done || eth1_latchup) begin
            eth1_start_boot <= '0;
        end
        if(fpga_boot_succeeded && {eth2_ctrl_r1, eth2_ctrl} == 2'b01) begin
            eth2_start_boot <= '1;
        end
        else if(eth2_boot_done || eth2_latchup) begin
            eth2_start_boot <= '0;
        end
        if(fpga_boot_succeeded && {stepper_pri_ctrl_r1, stepper_pri_ctrl} == 2'b01) begin
            stepper_pri_start_boot <= '1;
        end
        else if(stepper_pri_boot_done || stepper_pri_latchup) begin
            stepper_pri_start_boot <= '0;
        end
        
        if(fpga_boot_succeeded && {stepper_sec_ctrl_r1, stepper_sec_ctrl} == 2'b01) begin
            stepper_sec_start_boot <= '1;
        end
        else if(stepper_sec_boot_done || stepper_sec_latchup) begin
            stepper_sec_start_boot <= '0;
        end
        if(fpga_boot_succeeded && {lvdt_ctrl_r1, lvdt_ctrl} == 2'b01) begin
            lvdt_start_boot <= '1;
        end
        else if(lvdt_boot_done || lvdt_latchup) begin
            lvdt_start_boot <= '0;
        end
        if(fpga_boot_succeeded && {imx_ctrl_r1, imx_ctrl} == 2'b01) begin
            imx_start_boot <= '1;
        end
        else if(imx_boot_done || imx_latchup) begin
            imx_start_boot <= '0;
        end
    end
end


always_ff @(posedge clk) begin
    if(!rstn) begin
        failed                             <= '0;
        step_down_pgood_2v2_on_fail        <= '0;
        step_down_pgood_3v0_on_fail        <= '0;
        step_down_pgood_4v0_on_fail        <= '0;
        step_down_nfault_2v2_on_fail       <= '0;
        step_down_nfault_3v0_on_fail       <= '0;
        step_down_nfault_4v0_on_fail       <= '0;
        ddr8_pgood_2v5_on_fail             <= '0;
        ddr8_pgood_1v2_on_fail             <= '0;
        ddr8_pgood_0v6_on_fail             <= '0;
        ddr8_nfault_2v5_on_fail            <= '0;
        ddr8_nfault_1v2_on_fail            <= '0;
        ddr16_pgood_2v5_on_fail            <= '0;
        ddr16_pgood_1v2_on_fail            <= '0;
        ddr16_pgood_0v6_on_fail            <= '0;
        ddr16_nfault_2v5_on_fail           <= '0;
        ddr16_nfault_1v2_on_fail           <= '0;
        fpga_nfault_1v0_on_fail            <= '0;
        fpga_pgood_1v0_on_fail             <= '0;
        fpga_pgood_1v0a_on_fail            <= '0;
        fpga_pgood_1v25a_on_fail           <= '0;
        fpga_pgood_1v8_on_fail             <= '0;
        fpga_pgood_1v8_imx_on_fail         <= '0;
        fpga_pgood_2v5a_on_fail            <= '0;
        fpga_pgood_3v3_b4_on_fail          <= '0;
        fpga_pgood_3v3_b5_on_fail          <= '0;
        lvds_pgood_on_fail                 <= '0;
    end 
    else if((fpga_boot_failed || step_down_boot_failed || step_down_latchup || ddr8_latchup || ddr16_latchup || fpga_latchup || lvds_latchup) && !failed) begin
        step_down_pgood_2v2_on_fail        <= step_down_pgood_2v2 ;
        step_down_pgood_3v0_on_fail        <= step_down_pgood_3v0 ;
        step_down_pgood_4v0_on_fail        <= step_down_pgood_4v0 ;
        step_down_nfault_2v2_on_fail       <= step_down_nfault_2v2;
        step_down_nfault_3v0_on_fail       <= step_down_nfault_3v0;
        step_down_nfault_4v0_on_fail       <= step_down_nfault_4v0;
        ddr8_pgood_2v5_on_fail             <= ddr8_pgood_2v5      ;
        ddr8_pgood_1v2_on_fail             <= ddr8_pgood_1v2      ;
        ddr8_pgood_0v6_on_fail             <= ddr8_pgood_0v6      ;
        ddr8_nfault_2v5_on_fail            <= ddr8_nfault_2v5     ;
        ddr8_nfault_1v2_on_fail            <= ddr8_nfault_1v2     ;
        ddr16_pgood_2v5_on_fail            <= ddr16_pgood_2v5     ;
        ddr16_pgood_1v2_on_fail            <= ddr16_pgood_1v2     ;
        ddr16_pgood_0v6_on_fail            <= ddr16_pgood_0v6     ;
        ddr16_nfault_2v5_on_fail           <= ddr16_nfault_2v5    ;
        ddr16_nfault_1v2_on_fail           <= ddr16_nfault_1v2    ;
        fpga_nfault_1v0_on_fail            <= fpga_nfault_1v0     ;
        fpga_pgood_1v0_on_fail             <= fpga_pgood_1v0      ;
        fpga_pgood_1v0a_on_fail            <= fpga_pgood_1v0a     ;
        fpga_pgood_1v25a_on_fail           <= fpga_pgood_1v25a    ;
        fpga_pgood_1v8_on_fail             <= fpga_pgood_1v8      ;
        fpga_pgood_1v8_imx_on_fail         <= fpga_pgood_1v8_imx  ;
        fpga_pgood_2v5a_on_fail            <= fpga_pgood_2v5a     ;
        fpga_pgood_3v3_b4_on_fail          <= fpga_pgood_3v3_b4   ;
        fpga_pgood_3v3_b5_on_fail          <= fpga_pgood_3v3_b5   ;
        lvds_pgood_on_fail                 <= lvds_pgood          ;

        failed                             <= '1;
    end
end

always_ff @(posedge clk) begin
    eth1_ctrl_r1        <= eth1_ctrl;
    eth2_ctrl_r1        <= eth2_ctrl;
    stepper_pri_ctrl_r1 <= stepper_pri_ctrl;
    stepper_sec_ctrl_r1 <= stepper_sec_ctrl;
    lvdt_ctrl_r1        <= lvdt_ctrl;
    imx_ctrl_r1         <= imx_ctrl;

    ddr8_start_boot     <= step_down_boot_succeeded;
    ddr16_start_boot    <= ddr8_boot_done;
    fpga_start_boot     <= ddr16_boot_done;
    lvds_start_boot     <= fpga_boot_succeeded;
end

always_ff @(posedge clk) begin
    if(!rstn) begin
        imx_nshort_1v1 <= '1;
        imx_nshort_1v8 <= '1;
    end
    else begin
        if(imx_latchup) begin
            imx_nshort_1v1 <= '0;
            imx_nshort_1v8 <= '0;
        end
        else begin
            if(imx_en_1v1)  imx_nshort_1v1 <= '1;
            if(imx_en_1v8)  imx_nshort_1v8 <= '1;
        end
    end
end


always_ff @(posedge clk) begin
    
    if(!rstn) begin
        start_pwr_dwn      <= '0;
        debug              <= '0;
        critical_latchup   <= '0;
    end
    else begin
        if(!eps_efuse_pgood || fpga_boot_failed || step_down_boot_failed) begin
            start_pwr_dwn <= '1;
        end

        if(step_down_latchup) debug[2:0] <= 3'd1;
        else if(ddr8_latchup) debug[2:0] <= 3'd2;
        else if(ddr16_latchup) debug[2:0] <= 3'd3;
        else if(fpga_latchup) debug[2:0] <= 3'd4;
        else if(step_down_boot_failed) debug[2:0] <= 3'd5;
        else if(fpga_boot_failed) debug[2:0] <= 3'd6;
        else if(ddr8_boot_failed) debug[2:0] <= 3'd7;
        // //if(~&step_down_nfault || ~& ddr8_nfault || ~& ddr16_nfault || ~&fpga_nfault) debug[3] <= '1;
        // //debug[5:4] <= debug_sm[5][3:2];
        if(!ddr16_nfault_1v2)
            debug[3]   <= '1;
        debug[5]   <= step_down_en_2v2;
        if(ddr16_pwr_dwn)
            debug[4]   <= ddr16_pwr_dwn;
        debug[6]   <= ddr16_en_1v2;
        if(step_down_latchup || ddr8_latchup || ddr16_latchup || fpga_latchup || lvds_latchup) begin
            critical_latchup <= '1;
        end
    end
end

endmodule
