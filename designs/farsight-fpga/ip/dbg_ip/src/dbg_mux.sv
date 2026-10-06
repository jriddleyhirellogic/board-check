/*
 * @file      dbg_mux.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      12/17/2025
 * 
 * @brief     Debug mux IP for multiplexing output debug gpios for testing purposes.
 * 
 * @section changelog
 * - 12/17/2025: Saba Janamian - Initial implementation
 * 
 */

module dbg_mux (
    output logic       dbg_gpio0,
    output logic       dbg_gpio1,
    output logic       dbg_gpio2,
    output logic       dbg_gpio3,
    output logic       dbg_gpio4,
    output logic       dbg_gpio5,
    output logic       dbg_gpio6,
    output logic       dbg_gpio7,
    output logic       dbg_gpio8,
    output logic       dbg_gpio9,
    output logic       dbg_gpio10,
    output logic       dbg_gpio11,
    output logic       dbg_gpio12,
    output logic       dbg_gpio13,

    input  logic       tlm_dbg_en,

    input  logic       spi_dbg_en,

    input  logic       stp_dbg_en,

    input  logic       cam_mux_output_en,

    input  logic       frame_valid,
    input  logic       line_valid,
    input  logic       ebd_valid,
    input  logic       cam_xtrig,
    input  logic       cam_tout,

    input  logic       mac_mtxacpt,
    input  logic       mac_mtxeof,
    input  logic       mac_mtxrdy,
    input  logic       mac_mtxsof,

    input  logic       ddr4_write_sel,

    input  logic       ddr4_8gb_write_ack,
    input  logic       ddr4_8gb_write_req,
    input  logic       ddr4_8gb_write_valid,
    input  logic       ddr4_8gb_write_done,

    input  logic       ddr4_16gb_write_ack,
    input  logic       ddr4_16gb_write_req,
    input  logic       ddr4_16gb_write_valid,
    input  logic       ddr4_16gb_write_done,

    input  logic [1:0] ddr4_read_sel,

    input  logic       ddr4_8gb_read_ack,
    input  logic       ddr4_8gb_read_req,
    input  logic       ddr4_8gb_read_valid,
    input  logic       ddr4_8gb_read_done,

    input  logic       ddr4_16gb_read_ack,
    input  logic       ddr4_16gb_read_req,
    input  logic       ddr4_16gb_read_valid,
    input  logic       ddr4_16gb_read_done,

    input logic        user_dbg_gpio,

    input logic        pri_stp_motor_vref_pwm,
    input logic        pri_stp_motor_step,
    input logic        pri_stp_motor_dir,
    input logic        pri_stp_motor_en,
    input logic        pri_stp_motor_fault_n,
    input logic        sec_stp_motor_vref_pwm,
    input logic        sec_stp_motor_step,
    input logic        sec_stp_motor_dir,
    input logic        sec_stp_motor_en,
    input logic        sec_stp_motor_fault_n,

    input logic        nvm_spi_dbg_clk,
    input logic        nvm_spi_dbg_miso,
    input logic        nvm_spi_dbg_mosi,
    input logic        nvm_spi_dbg_cs_n,

    input logic        uart_rx,
    input logic        uart_tx,

    input logic        pps_in,
    input logic        pps_out,

    input logic        cam_trig_irq,
    input logic        frame_read_done_irq,

    input logic        tlm_spi_dbg_sclk,
    input logic        tlm_spi_dbg_cs1_n,
    input logic        tlm_spi_dbg_cs2_n,
    input logic        tlm_spi_dbg_cs3_n,
    input logic        tlm_spi_dbg_cs4_n,
    input logic        tlm_spi_dbg_cs5_n,
    input logic        tlm_spi_dbg_cs6_n,
    input logic        tlm_spi_dbg_mosi,
    input logic        tlm_spi_dbg_miso
);

localparam logic [1:0] UDP_MUX_DISABLED          = 2'b00;
localparam logic [1:0] UDP_MUX_DBG_EN            = 2'b01;
localparam logic [1:0] UDP_MUX_UDP_FOR_DDR4_8GB  = 2'b10;
localparam logic [1:0] UDP_MUX_UDP_FOR_DDR4_16GB = 2'b11;

assign dbg_gpio13 = user_dbg_gpio;

always_comb begin

    if(tlm_dbg_en) begin
        dbg_gpio0  = tlm_spi_dbg_sclk;
        dbg_gpio1  = tlm_spi_dbg_cs1_n;
        dbg_gpio2  = tlm_spi_dbg_cs2_n;
        dbg_gpio3  = tlm_spi_dbg_cs3_n;
        dbg_gpio4  = tlm_spi_dbg_cs4_n;
        dbg_gpio5  = tlm_spi_dbg_cs5_n;
        dbg_gpio6  = tlm_spi_dbg_cs6_n;
        dbg_gpio7  = tlm_spi_dbg_mosi;
        dbg_gpio8  = tlm_spi_dbg_miso;
        dbg_gpio9  = 1'b0;
        dbg_gpio10 = 1'b0;
        dbg_gpio11 = 1'b0;
        dbg_gpio12 = 1'b0;

    end else if(spi_dbg_en) begin
        dbg_gpio0  = nvm_spi_dbg_clk;
        dbg_gpio1  = nvm_spi_dbg_miso;
        dbg_gpio2  = nvm_spi_dbg_mosi;
        dbg_gpio3  = nvm_spi_dbg_cs_n;
        dbg_gpio4  = 1'b0;
        dbg_gpio5  = uart_rx;
        dbg_gpio6  = uart_tx;
        dbg_gpio7  = 1'b0;
        dbg_gpio8  = pps_in;
        dbg_gpio9  = pps_out;
        dbg_gpio10 = 1'b0;
        dbg_gpio11 = cam_trig_irq;
        dbg_gpio12 = frame_read_done_irq;

    end else if (stp_dbg_en) begin
        dbg_gpio0  = pri_stp_motor_vref_pwm;
        dbg_gpio1  = pri_stp_motor_step;
        dbg_gpio2  = pri_stp_motor_dir;
        dbg_gpio3  = pri_stp_motor_en;
        dbg_gpio4  = pri_stp_motor_fault_n;
        dbg_gpio5  = sec_stp_motor_vref_pwm;
        dbg_gpio6  = sec_stp_motor_step;
        dbg_gpio7  = sec_stp_motor_dir;
        dbg_gpio8  = sec_stp_motor_en;
        dbg_gpio9  = sec_stp_motor_fault_n;
        dbg_gpio10 = 1'b0;
        dbg_gpio11 = 1'b0;
        dbg_gpio12 = 1'b0;

    end else begin
        case (cam_mux_output_en)
            0: begin
                dbg_gpio0 = mac_mtxacpt;
                dbg_gpio1 = mac_mtxeof;
                dbg_gpio2 = mac_mtxrdy;
                dbg_gpio3 = mac_mtxsof;
                dbg_gpio4 = 1'b0;
            end
            1: begin
                dbg_gpio0 = frame_valid;
                dbg_gpio1 = line_valid;
                dbg_gpio2 = ebd_valid;
                dbg_gpio3 = cam_xtrig;
                dbg_gpio4 = cam_tout;
            end
            default: begin
                dbg_gpio0 = 1'b0;
                dbg_gpio1 = 1'b0;
                dbg_gpio2 = 1'b0;
                dbg_gpio3 = 1'b0;
                dbg_gpio4 = 1'b0;
            end
        endcase

        case (ddr4_write_sel)
            0: begin
                dbg_gpio5 = ddr4_8gb_write_ack;
                dbg_gpio6 = ddr4_8gb_write_req;
                dbg_gpio7 = ddr4_8gb_write_valid;
                dbg_gpio8 = ddr4_8gb_write_done;
            end
            1: begin
                dbg_gpio5 = ddr4_16gb_write_ack;
                dbg_gpio6 = ddr4_16gb_write_req;
                dbg_gpio7 = ddr4_16gb_write_valid;
                dbg_gpio8 = ddr4_16gb_write_done;
            end
            default: begin
                dbg_gpio5 = 1'b0;
                dbg_gpio6 = 1'b0;
                dbg_gpio7 = 1'b0;
                dbg_gpio8 = 1'b0;
            end
        endcase

        case(ddr4_read_sel)
            UDP_MUX_UDP_FOR_DDR4_8GB: begin
                dbg_gpio9  = ddr4_8gb_read_ack;
                dbg_gpio10 = ddr4_8gb_read_req;
                dbg_gpio11 = ddr4_8gb_read_valid;
                dbg_gpio12 = ddr4_8gb_read_done;
            end
            UDP_MUX_UDP_FOR_DDR4_16GB: begin
                dbg_gpio9  = ddr4_16gb_read_ack;
                dbg_gpio10 = ddr4_16gb_read_req;
                dbg_gpio11 = ddr4_16gb_read_valid;
                dbg_gpio12 = ddr4_16gb_read_done;
            end
            default: begin
                dbg_gpio9  = 1'b0;
                dbg_gpio10 = 1'b0;
                dbg_gpio11 = 1'b0;
                dbg_gpio12 = 1'b0;
            end
        endcase
    end
end

endmodule
