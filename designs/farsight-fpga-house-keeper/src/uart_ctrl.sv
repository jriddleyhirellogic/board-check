/*
 * @file      uart_ctrl.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Chase Whyte (cwhyte@turionspace.com)
 * @date      08/14/2025
 * 
 * @brief     This module controls the UART module in PA3. It sends out error status of 
 *            pgood and nfault info at the moment of failure to payload bus every second
 *            otherwise, it forwards UART TX and RX directly to and from PolarFire and payload bus
 * 
 * @section changelog
 * - 08/14/2025: Chase Whyte - Initial implementation
 * 
 */

module uart_ctrl (
    input  logic              clk,
    input  logic              rstn,
    input  logic              failed,     //a failure event occurred such as latchup for failed boot of critical region
    input  logic              fpga_pgood, //fpga was successfully booted
    input  logic              step_down_pgood_2v2_on_fail,
    input  logic              step_down_pgood_3v0_on_fail,
    input  logic              step_down_pgood_4v0_on_fail,
    input  logic              step_down_nfault_2v2_on_fail,
    input  logic              step_down_nfault_3v0_on_fail,
    input  logic              step_down_nfault_4v0_on_fail,
    input  logic              ddr8_pgood_2v5_on_fail,
    input  logic              ddr8_pgood_1v2_on_fail,
    input  logic              ddr8_pgood_0v6_on_fail,
    input  logic              ddr8_nfault_2v5_on_fail,
    input  logic              ddr8_nfault_1v2_on_fail,
    input  logic              ddr16_pgood_2v5_on_fail,
    input  logic              ddr16_pgood_1v2_on_fail,
    input  logic              ddr16_pgood_0v6_on_fail,
    input  logic              ddr16_nfault_2v5_on_fail,
    input  logic              ddr16_nfault_1v2_on_fail,
    input  logic              fpga_nfault_1v0_on_fail,
    input  logic              fpga_pgood_1v0_on_fail,
    input  logic              fpga_pgood_1v0a_on_fail,
    input  logic              fpga_pgood_1v25a_on_fail,
    input  logic              fpga_pgood_1v8_on_fail,
    input  logic              fpga_pgood_1v8_imx_on_fail,
    input  logic              fpga_pgood_2v5a_on_fail,
    input  logic              fpga_pgood_3v3_b4_on_fail,
    input  logic              fpga_pgood_3v3_b5_on_fail,
    input  logic              lvds_pgood_on_fail,
    input  logic              rx_from_pf,                     //rx input from polarfire UART
    input  logic              rx_from_bus,                    //rx input from payload bus
    input  logic              pa3_tx,                         //tx from pa3 UART to bus (only used after failure)
    output logic              tx_to_pf,                       //tx from bus to PolarFire
    output logic              tx_to_bus,                      //tx to payload bus
    output logic [7:0]        uart_tx_data,             //input data to pa3 UART to send to payload bus, latched on tx_ready & !wen
    output logic              uart_wen,                       //active-low write enable
    output logic              uart_csn,                       //active-low cs qualifies oen and wen, set to 0 for embedded applications
    input  logic              tx_ready,                       //indicates transmit data is ready to send out

    output logic              uart_bit8,                     //setting to 1 uses all 8 bits, 0 uses 7
    output logic              uart_oen,                      //active-low uart read-enable, but we are ignoring RX
    output logic [12:0]       baud_val,               //defines baud rate: CLOCK_FREQ_IN_HZ/((baud_val + 1)*16)
    output logic              parity_en,                     //set to 0 to disable parity bit
    output logic              parity_oddneven,               //0 means even parity, but parity is disabled
    output logic              uart_rx                        //RX port of pa3 UART, driven to a 0 because not needed
);
localparam logic [31:0] SECOND           = 32'd50_000_000;
localparam logic [12:0] BAUD_RATE_NUM    = 13'd26;
localparam logic [31:0] CNTR_PRECISION   = 32'd18;         //cntr will increment every 2^(CNTR_PRECISION) clock cycles
localparam logic [31:0] CNTR_RESOLUTION  = 32'd8;          //# of bits to hold the number of time periods equal to 2^(CNTR_PRECISION) clock cycles that have elapsed

typedef enum logic [3:0] {
    IDLE                                 = 4'd0,
    START_CNTR                           = 4'd1,
    SEND_ERROR_STATUS_DE                 = 4'd2,
    SEND_ERROR_STATUS_AD                 = 4'd3,
    SEND_ERROR_STATUS_BE                 = 4'd4,
    SEND_ERROR_STATUS_EF                 = 4'd5,
    SEND_ERROR_STATUS_FPGA_PGOOD         = 4'd6,
    SEND_ERROR_STATUS_FPGA_NFAULT        = 4'd7,
    SEND_ERROR_STATUS_LVDS_PGOOD         = 4'd8,
    SEND_ERROR_STATUS_DDR16              = 4'd9,
    SEND_ERROR_STATUS_DDR8               = 4'd10,
    SEND_ERROR_STATUS_STEP_DOWN          = 4'd11,
    SEND_ERROR_STATUS_BA                 = 4'd12,
    SEND_ERROR_STATUS_DD                 = 4'd13,
    SEND_ERROR_STATUS_FE                 = 4'd14,
    SEND_ERROR_STATUS_ED                 = 4'd15
} uart_states;

logic                       rx_from_pf_mux;
uart_states                 uart_state  /* synthesis syn_encoding="safe" */; 
uart_states                 uart_state_dv;
logic [CNTR_RESOLUTION-1:0] fail_broadcast_cntr;     //keeps track of how long it has been since last message finished
logic                       clr;
logic [7:0]                 uart_tx_data_dv;
logic                       uart_wen_dv; //wen must be low only when tx_ready is low and only for a clock cycle per transaction

proasic3_counter # (
    .CNTR_RESOLUTION(CNTR_RESOLUTION),
    .CNTR_PRECISION (CNTR_PRECISION)
) proasic3_counter_i (
    .clk,
    .rstn,
    .clr,
    .cntr(fail_broadcast_cntr)
);

assign tx_to_pf        = fpga_pgood ? rx_from_bus : '0;
assign tx_to_bus       = failed ? pa3_tx : rx_from_pf_mux; //if failure, hijack tx to bus, else forward PolarFire TX or 0 if fpga not booted
assign rx_from_pf_mux  = fpga_pgood ? rx_from_pf : '1;     //idle of UART should be high 
assign uart_oen        = '0;
assign uart_csn        = '0;
assign uart_bit8       = '1;
assign parity_en       = '0;
assign parity_oddneven = '0;
assign uart_rx         = '0;
assign baud_val        = BAUD_RATE_NUM;

//every second, this state machine should cycle through and send out pgood/nfault data of HW regions to payload bus
//first message should be sent out immediately after failure
always_comb begin
    uart_state_dv    = uart_state;
    uart_tx_data_dv  = '0;
    uart_wen_dv      = '1;
    clr              = '0;
    case(uart_state)
        //sits here until failure is detected
        IDLE: begin
            clr = '1;
            if(failed) begin
                uart_state_dv = START_CNTR;
            end
        end
        //wait for a second in START_CNTR state before sending again (except on first send)
        START_CNTR: begin
            if(fail_broadcast_cntr >= (SECOND >> CNTR_PRECISION)) begin
                uart_state_dv = SEND_ERROR_STATUS_DE;
                clr           = '1;
            end
        end
        //sends 0xDE
        SEND_ERROR_STATUS_DE: begin
            uart_tx_data_dv = 8'hDE;
            if(tx_ready) begin
                uart_wen_dv = '0;
                if(!uart_wen) begin
                    uart_wen_dv = '1;
                    uart_state_dv = SEND_ERROR_STATUS_AD;
                end
            end
        end
        //sends 0xEF
        SEND_ERROR_STATUS_AD: begin
            uart_tx_data_dv = 8'hAD;
            if(tx_ready) begin
                uart_wen_dv = '0;
                if(!uart_wen) begin
                    uart_wen_dv = '1;
                    uart_state_dv = SEND_ERROR_STATUS_BE;
                end
            end
        end
        //sends 0xBE
        SEND_ERROR_STATUS_BE: begin
            uart_tx_data_dv = 8'hBE;
            if(tx_ready) begin
                uart_wen_dv = '0;
                if(!uart_wen) begin
                    uart_wen_dv = '1;
                    uart_state_dv = SEND_ERROR_STATUS_EF;
                end
            end
        end
        //sends 0xEF
        SEND_ERROR_STATUS_EF: begin
            uart_tx_data_dv = 8'hEF;
            if(tx_ready) begin
                uart_wen_dv = '0;
                if(!uart_wen) begin
                    uart_wen_dv = '1;
                    uart_state_dv = SEND_ERROR_STATUS_FPGA_PGOOD;
                end
            end
        end
        //sends pgood of all FPGA power sources
        SEND_ERROR_STATUS_FPGA_PGOOD: begin
            uart_tx_data_dv = {
                                fpga_pgood_3v3_b5_on_fail,
                                fpga_pgood_3v3_b4_on_fail,
                                fpga_pgood_2v5a_on_fail,
                                fpga_pgood_1v8_imx_on_fail,
                                fpga_pgood_1v8_on_fail,
                                fpga_pgood_1v25a_on_fail,
                                fpga_pgood_1v0a_on_fail,
                                fpga_pgood_1v0_on_fail
                              };
            if(tx_ready) begin
                uart_wen_dv = '0;
                if(!uart_wen) begin
                    uart_wen_dv = '1;
                    uart_state_dv = SEND_ERROR_STATUS_FPGA_NFAULT;
                end
            end
        end
        //sends nfault of FPGA 1v0 power source
        SEND_ERROR_STATUS_FPGA_NFAULT: begin
            uart_tx_data_dv = {
                                7'd0,
                                fpga_nfault_1v0_on_fail
                              };
            if(tx_ready) begin
                uart_wen_dv = '0;
                if(!uart_wen) begin
                    uart_wen_dv = '1;
                    uart_state_dv = SEND_ERROR_STATUS_LVDS_PGOOD;
                end
            end
        end
         //sends pgood of LVDS
        SEND_ERROR_STATUS_LVDS_PGOOD: begin
            uart_tx_data_dv = {
                                7'd0,
                                lvds_pgood_on_fail
                              };
            if(tx_ready) begin
                uart_wen_dv = '0;
                if(!uart_wen) begin
                    uart_wen_dv = '1;
                    uart_state_dv = SEND_ERROR_STATUS_DDR16;
                end
            end
        end
        //sends pgood of ddr16 and nfault of ddr16 on first 5 bits, remaing are 0
        SEND_ERROR_STATUS_DDR16: begin
            uart_tx_data_dv = {
                                3'd0,
                                ddr16_pgood_0v6_on_fail,
                                ddr16_pgood_1v2_on_fail,
                                ddr16_pgood_2v5_on_fail,
                                ddr16_nfault_1v2_on_fail,
                                ddr16_nfault_2v5_on_fail
                              };
            if(tx_ready) begin
                uart_wen_dv = '0;
                if(!uart_wen) begin
                    uart_wen_dv = '1;
                    uart_state_dv = SEND_ERROR_STATUS_DDR8;
                end
            end
        end
        //sends pgood of ddr8 and nfault of ddr8 on first 5 bits, remaing are 0
        SEND_ERROR_STATUS_DDR8: begin
            uart_tx_data_dv = {
                                3'd0,
                                ddr8_pgood_0v6_on_fail,
                                ddr8_pgood_1v2_on_fail,
                                ddr8_pgood_2v5_on_fail,
                                ddr8_nfault_1v2_on_fail,
                                ddr8_nfault_2v5_on_fail
                              };
            if(tx_ready) begin
                uart_wen_dv = '0;
                if(!uart_wen) begin
                    uart_wen_dv = '1;
                    uart_state_dv = SEND_ERROR_STATUS_STEP_DOWN;
                end
            end
        end
        //sends pgood of step_down and nfault of step_down on first 6 bits, remaing are 0
        SEND_ERROR_STATUS_STEP_DOWN: begin
            uart_tx_data_dv = {
                                2'd0,
                                step_down_pgood_4v0_on_fail,
                                step_down_pgood_3v0_on_fail,
                                step_down_pgood_2v2_on_fail,
                                step_down_nfault_4v0_on_fail,
                                step_down_nfault_3v0_on_fail,
                                step_down_nfault_2v2_on_fail
                              };
            if(tx_ready) begin
                uart_wen_dv = '0;
                if(!uart_wen) begin
                    uart_wen_dv = '1;
                    uart_state_dv = SEND_ERROR_STATUS_BA;
                end
            end
        end
        //sends 0xBA
        SEND_ERROR_STATUS_BA: begin
            uart_tx_data_dv = 8'hBA;
            if(tx_ready) begin
                uart_wen_dv = '0;
                if(!uart_wen) begin
                    uart_wen_dv = '1;
                    uart_state_dv = SEND_ERROR_STATUS_DD;
                end
            end
        end
        //sends 0xDD
        SEND_ERROR_STATUS_DD: begin
            uart_tx_data_dv = 8'hDD;
            if(tx_ready) begin
                uart_wen_dv = '0;
                if(!uart_wen) begin
                    uart_wen_dv = '1;
                    uart_state_dv = SEND_ERROR_STATUS_FE;
                end
            end
        end
        //sends 0xFE
        SEND_ERROR_STATUS_FE: begin
            uart_tx_data_dv = 8'hFE;
            if(tx_ready) begin
                uart_wen_dv = '0;
                if(!uart_wen) begin
                    uart_wen_dv = '1;
                    uart_state_dv = SEND_ERROR_STATUS_ED;
                end
            end
        end
        //sends 0xED
        SEND_ERROR_STATUS_ED: begin
            uart_tx_data_dv = 8'hED;
            if(tx_ready) begin
                uart_wen_dv = '0;
                if(!uart_wen) begin
                    uart_wen_dv = '1;
                    uart_state_dv = START_CNTR;
                    clr = '1;
                end
            end
        end
        default: uart_state_dv = IDLE;
    endcase
end

always_ff @(posedge clk) begin
    if(!rstn) begin
        uart_state             <= IDLE;
        uart_tx_data           <= '0;
        uart_wen               <= '1;
    end
    else begin
        uart_state             <= uart_state_dv;
        uart_tx_data           <= uart_tx_data_dv;
        uart_wen               <= uart_wen_dv;
    end
end


endmodule
