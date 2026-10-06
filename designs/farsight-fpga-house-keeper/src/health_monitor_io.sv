/*
 * @file      health_monitor_io.sv
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

module health_monitor_io #(
    parameter logic [31:0]                                PULSE_WIDTH           = 32'd250,  
    parameter logic [31:0]                                WAIT_TIME_MULT_FACTOR = 32'd50
) (

    input  logic        clk,       //ASIC 50MHz clock
    input  logic        arstn,
    output logic        rstn,
    input  logic        eps_efuse_pgood,
    input  logic        ddr16_nfault_2v5,
    input  logic        ddr16_nfault_1v2,
    input  logic        ddr16_pgood_2v5,
    input  logic        ddr16_pgood_1v2,
    input  logic        ddr16_pgood_0v6,
    input  logic        ddr8_nfault_2v5,
    input  logic        ddr8_nfault_1v2,
    input  logic        ddr8_pgood_2v5,
    input  logic        ddr8_pgood_1v2,
    input  logic        ddr8_pgood_0v6,
    input  logic        eth1_ctrl,
    input  logic        eth1_pgood_1v0,
    input  logic        eth1_pgood_1v0a,
    input  logic        eth1_pgood_2v5a,
    input  logic        eth1_pgood_3v3,
    input  logic        eth2_ctrl,
    input  logic        eth2_pgood_1v0,
    input  logic        eth2_pgood_1v0a,
    input  logic        eth2_pgood_2v5a,
    input  logic        eth2_pgood_3v3,
    input  logic        fpga_nfault_1v0,
    input  logic        fpga_pgood_1v0,
    input  logic        fpga_pgood_1v0a,
    input  logic        fpga_pgood_1v25a,
    input  logic        fpga_pgood_1v8,
    input  logic        fpga_pgood_1v8_imx,
    input  logic        fpga_pgood_2v5a,
    input  logic        fpga_pgood_3v3_b4,
    input  logic        fpga_pgood_3v3_b5,
    input  logic        imx_ctrl,
    input  logic        imx_nfault_1v1,
    input  logic        imx_pgood_1v1,
    input  logic        imx_pgood_1v8,
    input  logic        imx_pgood_2v9,
    input  logic        imx_pgood_3v3,
    input  logic        lvdt_ctrl,
    input  logic        lvdt_pgood,
    input  logic        lvds_pgood,
    input  logic        step_down_nfault_2v2,
    input  logic        step_down_nfault_3v0,
    input  logic        step_down_nfault_4v0,
    input  logic        step_down_pgood_2v2,
    input  logic        step_down_pgood_3v0,
    input  logic        step_down_pgood_4v0,
    input  logic        stepper_pri_ctrl,
    input  logic        stepper_pri_nfault,
    input  logic        stepper_pri_pgood,
    input  logic        stepper_sec_ctrl,
    input  logic        stepper_sec_nfault,
    input  logic        stepper_sec_pgood,
    output logic        ddr16_en_2v5,
    output logic        ddr16_en_1v2,
    output logic        ddr16_en_0v6,
    output logic        ddr8_en_2v5,
    output logic        ddr8_en_1v2,
    output logic        ddr8_en_0v6,
    output logic        eth1_en_1v0,
    output logic        eth1_en_1v0a,
    output logic        eth1_en_2v5a,
    output logic        eth1_en_3v3,
    output logic        eth2_en_1v0,
    output logic        eth2_en_1v0a,
    output logic        eth2_en_2v5a,
    output logic        eth2_en_3v3,
    output logic        fpga_en_1v0,
    output logic        fpga_en_1v0a,
    output logic        fpga_en_1v25a,
    output logic        fpga_en_1v8,
    output logic        fpga_en_1v8_imx,
    output logic        fpga_en_2v5a,
    output logic        fpga_en_3v3_b4,
    output logic        fpga_en_3v3_b5,
    output logic        imx_en_1v1,
    output logic        imx_en_1v8,
    output logic        imx_en_2v9,
    output logic        imx_en_3v3,
    output logic        lvdt_en,
    output logic        lvds_en,
    output logic        step_down_en_2v2,
    output logic        step_down_en_3v0,
    output logic        step_down_en_4v0,
    output logic        stepper_pri_en,
    output logic        stepper_sec_en,
    output logic        imx_nshort_1v1,
    output logic        imx_nshort_1v8,

    output logic        pf_status_to_pf,
    output logic        step_down_status_to_pf,
    output logic        ddr16_status_to_pf,
    output logic        ddr8_status_to_pf,
    output logic        stepper_pri_status_to_pf,
    output logic        stepper_sec_status_to_pf,
    output logic        lvdt_status_to_pf,
    output logic        imx_status_to_pf,
    output logic        lvds_status_to_pf,
    output logic        eth2_status_to_pf,
    output logic        eth1_status_to_pf,
    output logic        pa3_status_to_pf,

    output logic        rs422_ttl_farsight_to_bus_pa3,
    input  logic        rs422_ttl_bus_to_farsight_pa3,
    input  logic        rs422_ttl_farsight_to_bus_pf,
    output logic        rs422_ttl_bus_to_farsight_pf,

    input  logic        uart_tx_from_pa3,

    output logic [7:0]  uart_tx_data,
    output logic        uart_wen,
    output logic        uart_csn,
    input  logic        tx_ready,
       
    output logic        uart_bit8,
    output logic        uart_oen,
    output logic [12:0] baud_val,
    output logic        parity_en,
    output logic        parity_oddneven,
    output logic        uart_rx,

    output logic [2:0]  fw_version,
    output logic [6:0]  debug,
    output logic        heartbeat,
    output logic [1:0]  ddr8_failure_metadata,
    output logic [1:0]  ddr16_failure_metadata,
    output logic [2:0]  eth1_failure_metadata,
    output logic [2:0]  eth2_failure_metadata,
    output logic        stepper_pri_failure_metadata,
    output logic        stepper_sec_failure_metadata,
    output logic        lvdt_failure_metadata,
    output logic [2:0]  imx_failure_metadata
);

localparam logic [31:0] NUM_SW_CTRL_REGIONS = 32'd6;

logic                    failed;
logic                    imx_ctrl_sync;
logic                    lvdt_ctrl_sync;
logic                    stepper_sec_ctrl_sync;
logic                    stepper_pri_ctrl_sync;
logic                    eth2_ctrl_sync;
logic                    eth1_ctrl_sync;
logic                    imx_pgood_3v3_sync;
logic                    imx_pgood_3v3_gf;
logic                    imx_pgood_2v9_sync;
logic                    imx_pgood_2v9_gf;
logic                    imx_pgood_1v8_sync;
logic                    imx_pgood_1v8_gf;
logic                    imx_pgood_1v1_sync;
logic                    imx_pgood_1v1_gf;
logic                    imx_nfault_1v1_sync;
logic                    imx_nfault_1v1_gf;

logic                    lvdt_pgood_gf;
logic                    lvdt_pgood_sync;

logic                    stepper_sec_pgood_gf;
logic                    stepper_sec_pgood_sync;

logic                    stepper_sec_nfault_gf;
logic                    stepper_sec_nfault_sync;

logic                    stepper_pri_pgood_gf;
logic                    stepper_pri_pgood_sync;

logic                    stepper_pri_nfault_gf;
logic                    stepper_pri_nfault_sync;


logic                    eth2_pgood_3v3_gf;
logic                    eth2_pgood_3v3_sync;
logic                    eth2_pgood_2v5a_gf;
logic                    eth2_pgood_2v5a_sync;
logic                    eth2_pgood_1v0a_gf;
logic                    eth2_pgood_1v0a_sync;
logic                    eth2_pgood_1v0_gf;
logic                    eth2_pgood_1v0_sync;

logic                    eth1_pgood_3v3_gf;
logic                    eth1_pgood_3v3_sync;
logic                    eth1_pgood_2v5a_gf;
logic                    eth1_pgood_2v5a_sync;
logic                    eth1_pgood_1v0a_gf;
logic                    eth1_pgood_1v0a_sync;
logic                    eth1_pgood_1v0_gf;
logic                    eth1_pgood_1v0_sync;

logic                    lvds_pgood_gf;
logic                    lvds_pgood_sync;

logic                    fpga_nfault_1v0_gf;
logic                    fpga_pgood_1v0_gf;
logic                    fpga_pgood_1v0a_gf;
logic                    fpga_pgood_1v25a_gf;
logic                    fpga_pgood_1v8_gf;
logic                    fpga_pgood_1v8_imx_gf;
logic                    fpga_pgood_2v5a_gf;
logic                    fpga_pgood_3v3_b4_gf;
logic                    fpga_pgood_3v3_b5_gf;

logic                    fpga_nfault_1v0_sync;
logic                    fpga_pgood_1v0_sync;
logic                    fpga_pgood_1v0a_sync;
logic                    fpga_pgood_1v25a_sync;
logic                    fpga_pgood_1v8_sync;
logic                    fpga_pgood_1v8_imx_sync;
logic                    fpga_pgood_2v5a_sync;
logic                    fpga_pgood_3v3_b4_sync;
logic                    fpga_pgood_3v3_b5_sync;

logic                    ddr16_pgood_2v5_gf;
logic                    ddr16_pgood_1v2_gf;
logic                    ddr16_pgood_0v6_gf;
logic                    ddr16_pgood_2v5_sync;
logic                    ddr16_pgood_1v2_sync;
logic                    ddr16_pgood_0v6_sync;
logic                    ddr16_nfault_2v5_gf;
logic                    ddr16_nfault_1v2_gf;
logic                    ddr16_nfault_2v5_sync;
logic                    ddr16_nfault_1v2_sync;

logic                    ddr8_pgood_2v5_gf;
logic                    ddr8_pgood_1v2_gf;
logic                    ddr8_pgood_0v6_gf;
logic                    ddr8_pgood_2v5_sync;
logic                    ddr8_pgood_1v2_sync;
logic                    ddr8_pgood_0v6_sync;
logic                    ddr8_nfault_2v5_gf;
logic                    ddr8_nfault_1v2_gf;
logic                    ddr8_nfault_2v5_sync;
logic                    ddr8_nfault_1v2_sync;

logic                    step_down_pgood_2v2_gf;
logic                    step_down_pgood_3v0_gf;
logic                    step_down_pgood_4v0_gf;
logic                    step_down_pgood_2v2_sync;
logic                    step_down_pgood_3v0_sync;
logic                    step_down_pgood_4v0_sync;

logic                    step_down_nfault_2v2_gf;
logic                    step_down_nfault_3v0_gf;
logic                    step_down_nfault_4v0_gf;
logic                    step_down_nfault_2v2_sync;
logic                    step_down_nfault_3v0_sync;
logic                    step_down_nfault_4v0_sync;

logic                    eps_efuse_pgood_sync;
logic                    eps_efuse_pgood_gf;

logic                    step_down_boot_succeeded;
logic                    ddr8_boot_succeeded;
logic                    ddr16_boot_succeeded;
logic                    fpga_boot_succeeded;
logic                    lvds_boot_succeeded;
logic                    eth1_boot_succeeded;
logic                    eth2_boot_succeeded;
logic                    stepper_pri_boot_succeeded;
logic                    stepper_sec_boot_succeeded;
logic                    lvdt_boot_succeeded;
logic                    imx_boot_succeeded;

logic              step_down_pgood_2v2_on_fail;
logic              step_down_pgood_3v0_on_fail;
logic              step_down_pgood_4v0_on_fail;
logic              step_down_nfault_2v2_on_fail;
logic              step_down_nfault_3v0_on_fail;
logic              step_down_nfault_4v0_on_fail;
logic              ddr8_pgood_2v5_on_fail;
logic              ddr8_pgood_1v2_on_fail;
logic              ddr8_pgood_0v6_on_fail;
logic              ddr8_nfault_2v5_on_fail;
logic              ddr8_nfault_1v2_on_fail;
logic              ddr16_pgood_2v5_on_fail;
logic              ddr16_pgood_1v2_on_fail;
logic              ddr16_pgood_0v6_on_fail;
logic              ddr16_nfault_2v5_on_fail;
logic              ddr16_nfault_1v2_on_fail;
logic              fpga_nfault_1v0_on_fail;
logic              fpga_pgood_1v0_on_fail;
logic              fpga_pgood_1v0a_on_fail;
logic              fpga_pgood_1v25a_on_fail;
logic              fpga_pgood_1v8_on_fail;
logic              fpga_pgood_1v8_imx_on_fail;
logic              fpga_pgood_2v5a_on_fail;
logic              fpga_pgood_3v3_b4_on_fail;
logic              fpga_pgood_3v3_b5_on_fail;
logic              lvds_pgood_on_fail;

//assign always_on_pwr_status = rh_pgood & sense_pgood;

assign ddr16_status_to_pf       = fpga_boot_succeeded ? ddr16_boot_succeeded: '0;
assign ddr8_status_to_pf        = fpga_boot_succeeded ? ddr8_boot_succeeded: '0;
assign eth1_status_to_pf        = fpga_boot_succeeded ? eth1_boot_succeeded: '0;
assign eth2_status_to_pf        = fpga_boot_succeeded ? eth2_boot_succeeded: '0;
assign lvdt_status_to_pf        = fpga_boot_succeeded ? lvdt_boot_succeeded: '0;
assign lvds_status_to_pf        = fpga_boot_succeeded ? lvds_boot_succeeded: '0;
assign imx_status_to_pf         = fpga_boot_succeeded ? imx_boot_succeeded: '0;
assign stepper_pri_status_to_pf = fpga_boot_succeeded ? stepper_pri_boot_succeeded: '0;
assign stepper_sec_status_to_pf = fpga_boot_succeeded ? stepper_sec_boot_succeeded: '0;
assign pf_status_to_pf          = fpga_boot_succeeded;
assign step_down_status_to_pf   = fpga_boot_succeeded ? step_down_boot_succeeded: '0;
assign pa3_status_to_pf         = '1;

//reset synchronizer to handle async assertion and sync release of reset
//extends reset duration to at least 4 clock cycles
reset_synchronizer # (
    .NUM_STAGES(4)
) reset_synchronizer_i (
    .clk,
    .arstn,
    .rstn
);

dff_sync # (
    .BWIDTH(NUM_SW_CTRL_REGIONS)
) dff_sync_sw_ctrl (
    .clk,
    .d_in ({
            eth1_ctrl,
            eth2_ctrl,
            stepper_pri_ctrl,
            stepper_sec_ctrl,
            lvdt_ctrl,
            imx_ctrl
    }),
    .d_out({
            eth1_ctrl_sync,
            eth2_ctrl_sync,
            stepper_pri_ctrl_sync,
            stepper_sec_ctrl_sync,
            lvdt_ctrl_sync,
            imx_ctrl_sync
    })
);

//double flip flop synchronizer on all pgood and nfault inputs
dff_sync # (
    .BWIDTH(45)
) dff_sync_pgood_nfault (
    .clk,
    .d_in ({
            step_down_pgood_2v2, 
            step_down_pgood_3v0, 
            step_down_pgood_4v0,
            step_down_nfault_2v2,
            step_down_nfault_3v0,
            step_down_nfault_4v0,
            ddr16_nfault_2v5,
            ddr16_nfault_1v2,
            ddr16_pgood_2v5,
            ddr16_pgood_1v2,
            ddr16_pgood_0v6,
            ddr8_nfault_2v5,
            ddr8_nfault_1v2,
            ddr8_pgood_2v5,
            ddr8_pgood_1v2,
            ddr8_pgood_0v6,
            eth1_pgood_1v0,
            eth1_pgood_1v0a,
            eth1_pgood_2v5a,
            eth1_pgood_3v3,
            eth2_pgood_1v0,
            eth2_pgood_1v0a,
            eth2_pgood_2v5a,
            eth2_pgood_3v3,
            fpga_nfault_1v0,
            fpga_pgood_1v0,
            fpga_pgood_1v0a,
            fpga_pgood_1v25a,
            fpga_pgood_1v8,
            fpga_pgood_1v8_imx,
            fpga_pgood_2v5a,
            fpga_pgood_3v3_b4,
            fpga_pgood_3v3_b5,
            imx_nfault_1v1,
            imx_pgood_1v1,
            imx_pgood_1v8,
            imx_pgood_2v9,
            imx_pgood_3v3,
            lvdt_pgood,
            lvds_pgood,
            stepper_pri_nfault,
            stepper_pri_pgood,
            stepper_sec_nfault,
            stepper_sec_pgood,
            eps_efuse_pgood
    }),
    .d_out({
            step_down_pgood_2v2_sync, 
            step_down_pgood_3v0_sync, 
            step_down_pgood_4v0_sync,
            step_down_nfault_2v2_sync,
            step_down_nfault_3v0_sync,
            step_down_nfault_4v0_sync,
            ddr16_nfault_2v5_sync,
            ddr16_nfault_1v2_sync,
            ddr16_pgood_2v5_sync,
            ddr16_pgood_1v2_sync,
            ddr16_pgood_0v6_sync,
            ddr8_nfault_2v5_sync,
            ddr8_nfault_1v2_sync,
            ddr8_pgood_2v5_sync,
            ddr8_pgood_1v2_sync,
            ddr8_pgood_0v6_sync,
            eth1_pgood_1v0_sync,
            eth1_pgood_1v0a_sync,
            eth1_pgood_2v5a_sync,
            eth1_pgood_3v3_sync,
            eth2_pgood_1v0_sync,
            eth2_pgood_1v0a_sync,
            eth2_pgood_2v5a_sync,
            eth2_pgood_3v3_sync,
            fpga_nfault_1v0_sync,
            fpga_pgood_1v0_sync,
            fpga_pgood_1v0a_sync,
            fpga_pgood_1v25a_sync,
            fpga_pgood_1v8_sync,
            fpga_pgood_1v8_imx_sync,
            fpga_pgood_2v5a_sync,
            fpga_pgood_3v3_b4_sync,
            fpga_pgood_3v3_b5_sync,
            imx_nfault_1v1_sync,
            imx_pgood_1v1_sync,
            imx_pgood_1v8_sync,
            imx_pgood_2v9_sync,
            imx_pgood_3v3_sync,
            lvdt_pgood_sync,
            lvds_pgood_sync,
            stepper_pri_nfault_sync,
            stepper_pri_pgood_sync,
            stepper_sec_nfault_sync,
            stepper_sec_pgood_sync,
            eps_efuse_pgood_sync
    })
);

glitch_filter glitch_filter_step_down_pgood_2v2_sync (
    .clk,
    .rstn,
    .d_in(step_down_pgood_2v2_sync),
    .d_out(step_down_pgood_2v2_gf)
);
glitch_filter glitch_filter_step_down_pgood_3v0_sync (
    .clk,
    .rstn,
    .d_in(step_down_pgood_3v0_sync),
    .d_out(step_down_pgood_3v0_gf)
);
glitch_filter glitch_filter_step_down_pgood_4v0_sync (
    .clk,
    .rstn,
    .d_in(step_down_pgood_4v0_sync),
    .d_out(step_down_pgood_4v0_gf)
);
glitch_filter glitch_filter_step_down_nfault_2v2_sync (
    .clk,
    .rstn,
    .d_in(step_down_nfault_2v2_sync),
    .d_out(step_down_nfault_2v2_gf)
);
glitch_filter glitch_filter_step_down_nfault_3v0_sync (
    .clk,
    .rstn,
    .d_in(step_down_nfault_3v0_sync),
    .d_out(step_down_nfault_3v0_gf)
);
glitch_filter glitch_filter_step_down_nfault_4v0_sync (
    .clk,
    .rstn,
    .d_in(step_down_nfault_4v0_sync),
    .d_out(step_down_nfault_4v0_gf)
);
glitch_filter glitch_filter_ddr16_nfault_2v5_sync (
    .clk,
    .rstn,
    .d_in(ddr16_nfault_2v5_sync),
    .d_out(ddr16_nfault_2v5_gf)
);
glitch_filter glitch_filter_ddr16_nfault_1v2_sync (
    .clk,
    .rstn,
    .d_in(ddr16_nfault_1v2_sync),
    .d_out(ddr16_nfault_1v2_gf)
);
glitch_filter glitch_filter_ddr16_pgood_2v5_sync (
    .clk,
    .rstn,
    .d_in(ddr16_pgood_2v5_sync),
    .d_out(ddr16_pgood_2v5_gf)
);
glitch_filter glitch_filter_ddr16_pgood_1v2_sync (
    .clk,
    .rstn,
    .d_in(ddr16_pgood_1v2_sync),
    .d_out(ddr16_pgood_1v2_gf)
);
glitch_filter glitch_filter_ddr16_pgood_0v6_sync (
    .clk,
    .rstn,
    .d_in(ddr16_pgood_0v6_sync),
    .d_out(ddr16_pgood_0v6_gf)
);
glitch_filter glitch_filter_ddr8_nfault_2v5_sync (
    .clk,
    .rstn,
    .d_in(ddr8_nfault_2v5_sync),
    .d_out(ddr8_nfault_2v5_gf)
);
glitch_filter glitch_filter_ddr8_nfault_1v2_sync (
    .clk,
    .rstn,
    .d_in(ddr8_nfault_1v2_sync),
    .d_out(ddr8_nfault_1v2_gf)
);
glitch_filter glitch_filter_ddr8_pgood_2v5_sync (
    .clk,
    .rstn,
    .d_in(ddr8_pgood_2v5_sync),
    .d_out(ddr8_pgood_2v5_gf)
);
glitch_filter glitch_filter_ddr8_pgood_1v2_sync (
    .clk,
    .rstn,
    .d_in(ddr8_pgood_1v2_sync),
    .d_out(ddr8_pgood_1v2_gf)
);
glitch_filter glitch_filter_ddr8_pgood_0v6_sync (
    .clk,
    .rstn,
    .d_in(ddr8_pgood_0v6_sync),
    .d_out(ddr8_pgood_0v6_gf)
);
glitch_filter glitch_filter_eth1_pgood_1v0_sync (
    .clk,
    .rstn,
    .d_in(eth1_pgood_1v0_sync),
    .d_out(eth1_pgood_1v0_gf)
);
glitch_filter glitch_filter_eth1_pgood_1v0a_sync (
    .clk,
    .rstn,
    .d_in(eth1_pgood_1v0a_sync),
    .d_out(eth1_pgood_1v0a_gf)
);
glitch_filter glitch_filter_eth1_pgood_2v5a_sync (
    .clk,
    .rstn,
    .d_in(eth1_pgood_2v5a_sync),
    .d_out(eth1_pgood_2v5a_gf)
);
glitch_filter glitch_filter_eth1_pgood_3v3_sync (
    .clk,
    .rstn,
    .d_in(eth1_pgood_3v3_sync),
    .d_out(eth1_pgood_3v3_gf)
);
glitch_filter glitch_filter_eth2_pgood_1v0_sync (
    .clk,
    .rstn,
    .d_in(eth2_pgood_1v0_sync),
    .d_out(eth2_pgood_1v0_gf)
);
glitch_filter glitch_filter_eth2_pgood_1v0a_sync (
    .clk,
    .rstn,
    .d_in(eth2_pgood_1v0a_sync),
    .d_out(eth2_pgood_1v0a_gf)
);
glitch_filter glitch_filter_eth2_pgood_2v5a_sync (
    .clk,
    .rstn,
    .d_in(eth2_pgood_2v5a_sync),
    .d_out(eth2_pgood_2v5a_gf)
);
glitch_filter glitch_filter_eth2_pgood_3v3_sync (
    .clk,
    .rstn,
    .d_in(eth2_pgood_3v3_sync),
    .d_out(eth2_pgood_3v3_gf)
);
glitch_filter glitch_filter_fpga_nfault_1v0_sync (
    .clk,
    .rstn,
    .d_in(fpga_nfault_1v0_sync),
    .d_out(fpga_nfault_1v0_gf)
);
glitch_filter glitch_filter_fpga_pgood_1v0_sync (
    .clk,
    .rstn,
    .d_in(fpga_pgood_1v0_sync),
    .d_out(fpga_pgood_1v0_gf)
);
glitch_filter glitch_filter_fpga_pgood_1v0a_sync (
    .clk,
    .rstn,
    .d_in(fpga_pgood_1v0a_sync),
    .d_out(fpga_pgood_1v0a_gf)
);
glitch_filter glitch_filter_fpga_pgood_1v25a_sync (
    .clk,
    .rstn,
    .d_in(fpga_pgood_1v25a_sync),
    .d_out(fpga_pgood_1v25a_gf)
);
glitch_filter glitch_filter_fpga_pgood_1v8_sync (
    .clk,
    .rstn,
    .d_in(fpga_pgood_1v8_sync),
    .d_out(fpga_pgood_1v8_gf)
);
glitch_filter glitch_filter_fpga_pgood_1v8_imx_sync (
    .clk,
    .rstn,
    .d_in(fpga_pgood_1v8_imx_sync),
    .d_out(fpga_pgood_1v8_imx_gf)
);
glitch_filter glitch_filter_fpga_pgood_2v5a_sync (
    .clk,
    .rstn,
    .d_in(fpga_pgood_2v5a_sync),
    .d_out(fpga_pgood_2v5a_gf)
);
glitch_filter glitch_filter_fpga_pgood_3v3_b4_sync (
    .clk,
    .rstn,
    .d_in(fpga_pgood_3v3_b4_sync),
    .d_out(fpga_pgood_3v3_b4_gf)
);
glitch_filter glitch_filter_fpga_pgood_3v3_b5_sync (
    .clk,
    .rstn,
    .d_in(fpga_pgood_3v3_b5_sync),
    .d_out(fpga_pgood_3v3_b5_gf)
);
glitch_filter glitch_filter_imx_nfault_1v1_sync (
    .clk,
    .rstn,
    .d_in(imx_nfault_1v1_sync),
    .d_out(imx_nfault_1v1_gf)
);
glitch_filter glitch_filter_imx_pgood_1v1_sync (
    .clk,
    .rstn,
    .d_in(imx_pgood_1v1_sync),
    .d_out(imx_pgood_1v1_gf)
);
glitch_filter glitch_filter_imx_pgood_1v8_sync (
    .clk,
    .rstn,
    .d_in(imx_pgood_1v8_sync),
    .d_out(imx_pgood_1v8_gf)
);
glitch_filter glitch_filter_imx_pgood_2v9_sync (
    .clk,
    .rstn,
    .d_in(imx_pgood_2v9_sync),
    .d_out(imx_pgood_2v9_gf)
);
glitch_filter glitch_filter_imx_pgood_3v3_sync (
    .clk,
    .rstn,
    .d_in(imx_pgood_3v3_sync),
    .d_out(imx_pgood_3v3_gf)
);
glitch_filter glitch_filter_lvdt_pgood_sync (
    .clk,
    .rstn,
    .d_in(lvdt_pgood_sync),
    .d_out(lvdt_pgood_gf)
);
glitch_filter glitch_filter_lvds_pgood_sync (
    .clk,
    .rstn,
    .d_in(lvds_pgood_sync),
    .d_out(lvds_pgood_gf)
);
glitch_filter glitch_filter_stepper_pri_nfault_sync (
    .clk,
    .rstn,
    .d_in(stepper_pri_nfault_sync),
    .d_out(stepper_pri_nfault_gf)
);
glitch_filter glitch_filter_stepper_pri_pgood_sync (
    .clk,
    .rstn,
    .d_in(stepper_pri_pgood_sync),
    .d_out(stepper_pri_pgood_gf)
);
glitch_filter glitch_filter_stepper_sec_nfault_sync (
    .clk,
    .rstn,
    .d_in(stepper_sec_nfault_sync),
    .d_out(stepper_sec_nfault_gf)
);
glitch_filter glitch_filter_stepper_sec_pgood_sync (
    .clk,
    .rstn,
    .d_in(stepper_sec_pgood_sync),
    .d_out(stepper_sec_pgood_gf)
);

glitch_filter glitch_filter_eps_efuse_pgood_sync (
    .clk,
    .rstn,
    .d_in(eps_efuse_pgood_sync),
    .d_out(eps_efuse_pgood_gf)
);


health_monitor # (
    .WAIT_TIME_MULT_FACTOR (WAIT_TIME_MULT_FACTOR)
) health_monitor_i (
    .clk,
    .rstn,
    .ddr16_nfault_2v5     (ddr16_nfault_2v5_gf),
    .ddr16_nfault_1v2     (ddr16_nfault_1v2_gf),
    .ddr16_pgood_2v5      (ddr16_pgood_2v5_gf),
    .ddr16_pgood_1v2      (ddr16_pgood_1v2_gf),
    .ddr16_pgood_0v6      (ddr16_pgood_0v6_gf),
    .ddr8_nfault_2v5      (ddr8_nfault_2v5_gf),
    .ddr8_nfault_1v2      (ddr8_nfault_1v2_gf),
    .ddr8_pgood_2v5       (ddr8_pgood_2v5_gf),
    .ddr8_pgood_1v2       (ddr8_pgood_1v2_gf),
    .ddr8_pgood_0v6       (ddr8_pgood_0v6_gf),
    .eth1_ctrl            (eth1_ctrl_sync),
    .eth1_pgood_1v0       (eth1_pgood_1v0_gf),
    .eth1_pgood_1v0a      (eth1_pgood_1v0a_gf),
    .eth1_pgood_2v5a      (eth1_pgood_2v5a_gf),
    .eth1_pgood_3v3       (eth1_pgood_3v3_gf),
    .eth2_ctrl            (eth2_ctrl_sync),
    .eth2_pgood_1v0       (eth2_pgood_1v0_gf),
    .eth2_pgood_1v0a      (eth2_pgood_1v0a_gf),
    .eth2_pgood_2v5a      (eth2_pgood_2v5a_gf),
    .eth2_pgood_3v3       (eth2_pgood_3v3_gf),
    .fpga_nfault_1v0      (fpga_nfault_1v0_gf),
    .fpga_pgood_1v0       (fpga_pgood_1v0_gf),
    .fpga_pgood_1v0a      (fpga_pgood_1v0a_gf),
    .fpga_pgood_1v25a     (fpga_pgood_1v25a_gf),
    .fpga_pgood_1v8       (fpga_pgood_1v8_gf),
    .fpga_pgood_1v8_imx   (fpga_pgood_1v8_imx_gf),
    .fpga_pgood_2v5a      (fpga_pgood_2v5a_gf),
    .fpga_pgood_3v3_b4    (fpga_pgood_3v3_b4_gf),
    .fpga_pgood_3v3_b5    (fpga_pgood_3v3_b5_gf),
    .imx_ctrl             (imx_ctrl_sync),
    .imx_nfault_1v1       (imx_nfault_1v1_gf),
    .imx_pgood_1v1        (imx_pgood_1v1_gf),
    .imx_pgood_1v8        (imx_pgood_1v8_gf),
    .imx_pgood_2v9        (imx_pgood_2v9_gf),
    .imx_pgood_3v3        (imx_pgood_3v3_gf),
    .lvdt_ctrl            (lvdt_ctrl_sync),
    .lvdt_pgood           (lvdt_pgood_gf),
    .lvds_pgood           (lvds_pgood_gf),
    .step_down_nfault_2v2 (step_down_nfault_2v2_gf),
    .step_down_nfault_3v0 (step_down_nfault_3v0_gf),
    .step_down_nfault_4v0 (step_down_nfault_4v0_gf),
    .step_down_pgood_2v2  (step_down_pgood_2v2_gf),
    .step_down_pgood_3v0  (step_down_pgood_3v0_gf),
    .step_down_pgood_4v0  (step_down_pgood_4v0_gf),
    .stepper_pri_ctrl     (stepper_pri_ctrl_sync),
    .stepper_pri_nfault   (stepper_pri_nfault_gf),
    .stepper_pri_pgood    (stepper_pri_pgood_gf),
    .stepper_sec_ctrl     (stepper_sec_ctrl_sync),
    .stepper_sec_nfault   (stepper_sec_nfault_gf),
    .stepper_sec_pgood    (stepper_sec_pgood_gf),
    .ddr16_en_2v5,
    .ddr16_en_1v2,
    .ddr16_en_0v6,
    .ddr8_en_2v5,
    .ddr8_en_1v2,
    .ddr8_en_0v6,
    .eth1_en_1v0,
    .eth1_en_1v0a,
    .eth1_en_2v5a,
    .eth1_en_3v3,
    .eth2_en_1v0,
    .eth2_en_1v0a,
    .eth2_en_2v5a,
    .eth2_en_3v3,
    .fpga_en_1v0,
    .fpga_en_1v0a,
    .fpga_en_1v25a,
    .fpga_en_1v8,
    .fpga_en_1v8_imx,
    .fpga_en_2v5a,
    .fpga_en_3v3_b4,
    .fpga_en_3v3_b5,
    .imx_en_1v1,
    .imx_en_1v8,
    .imx_en_2v9,
    .imx_en_3v3,
    .lvdt_en,
    .lvds_en,
    .step_down_en_2v2,
    .step_down_en_3v0,
    .step_down_en_4v0,
    .stepper_pri_en,
    .stepper_sec_en,
    .imx_nshort_1v1,
    .imx_nshort_1v8,
    .eps_efuse_pgood(eps_efuse_pgood_gf),
    .failed,
    .fw_version,
    .debug,
    .heartbeat,
    .step_down_boot_succeeded,
    .ddr8_boot_succeeded,
    .ddr16_boot_succeeded,
    .fpga_boot_succeeded,
    .lvds_boot_succeeded,
    .eth1_boot_succeeded,
    .eth2_boot_succeeded,
    .stepper_pri_boot_succeeded,
    .stepper_sec_boot_succeeded,
    .lvdt_boot_succeeded,
    .imx_boot_succeeded,
    .step_down_pgood_2v2_on_fail,
    .step_down_pgood_3v0_on_fail,
    .step_down_pgood_4v0_on_fail,
    .step_down_nfault_2v2_on_fail,
    .step_down_nfault_3v0_on_fail,
    .step_down_nfault_4v0_on_fail,
    .ddr8_pgood_2v5_on_fail,
    .ddr8_pgood_1v2_on_fail,
    .ddr8_pgood_0v6_on_fail,
    .ddr8_nfault_2v5_on_fail,
    .ddr8_nfault_1v2_on_fail,
    .ddr16_pgood_2v5_on_fail,
    .ddr16_pgood_1v2_on_fail,
    .ddr16_pgood_0v6_on_fail,
    .ddr16_nfault_2v5_on_fail,
    .ddr16_nfault_1v2_on_fail,
    .fpga_nfault_1v0_on_fail,
    .fpga_pgood_1v0_on_fail,
    .fpga_pgood_1v0a_on_fail,
    .fpga_pgood_1v25a_on_fail,
    .fpga_pgood_1v8_on_fail,
    .fpga_pgood_1v8_imx_on_fail,
    .fpga_pgood_2v5a_on_fail,
    .fpga_pgood_3v3_b4_on_fail,
    .fpga_pgood_3v3_b5_on_fail,
    .lvds_pgood_on_fail,
    .ddr8_failure_metadata,
    .ddr16_failure_metadata,
    .eth1_failure_metadata,
    .eth2_failure_metadata,
    .stepper_pri_failure_metadata,
    .stepper_sec_failure_metadata,
    .lvdt_failure_metadata,
    .imx_failure_metadata
);

uart_ctrl uart_ctrl_i (
    .clk,
    .rstn,
    .failed,
    .fpga_pgood              (fpga_boot_succeeded),
    .step_down_pgood_2v2_on_fail,
    .step_down_pgood_3v0_on_fail,
    .step_down_pgood_4v0_on_fail,
    .step_down_nfault_2v2_on_fail,
    .step_down_nfault_3v0_on_fail,
    .step_down_nfault_4v0_on_fail,
    .ddr8_pgood_2v5_on_fail,
    .ddr8_pgood_1v2_on_fail,
    .ddr8_pgood_0v6_on_fail,
    .ddr8_nfault_2v5_on_fail,
    .ddr8_nfault_1v2_on_fail,
    .ddr16_pgood_2v5_on_fail,
    .ddr16_pgood_1v2_on_fail,
    .ddr16_pgood_0v6_on_fail,
    .ddr16_nfault_2v5_on_fail,
    .ddr16_nfault_1v2_on_fail,
    .fpga_nfault_1v0_on_fail,
    .fpga_pgood_1v0_on_fail,
    .fpga_pgood_1v0a_on_fail,
    .fpga_pgood_1v25a_on_fail,
    .fpga_pgood_1v8_on_fail,
    .fpga_pgood_1v8_imx_on_fail,
    .fpga_pgood_2v5a_on_fail,
    .fpga_pgood_3v3_b4_on_fail,
    .fpga_pgood_3v3_b5_on_fail,
    .lvds_pgood_on_fail,
    .rx_from_pf              (rs422_ttl_farsight_to_bus_pf),
    .rx_from_bus             (rs422_ttl_bus_to_farsight_pa3),
    .pa3_tx                  (uart_tx_from_pa3),
    .tx_to_pf                (rs422_ttl_bus_to_farsight_pf),
    .tx_to_bus               (rs422_ttl_farsight_to_bus_pa3),
    .uart_tx_data,
    .uart_wen,
    .uart_csn,
    .tx_ready,
    .uart_bit8,
    .uart_oen,
    .baud_val,
    .parity_en,
    .parity_oddneven,
    .uart_rx
);

endmodule
