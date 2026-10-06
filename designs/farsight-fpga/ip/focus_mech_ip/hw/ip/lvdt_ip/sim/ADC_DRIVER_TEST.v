//////////////////////////////////////////////////////////////////////
// Created by Microsemi SmartDesign Wed Dec 11 14:15:58 2024
// Testbench Template
// This is a basic testbench that instantiates your design with basic 
// clock and reset pins connected.  If your design has special
// clock/reset or testbench driver requirements then you should 
// copy this file and modify it. 
//////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////////
// Company: <Name>
//
// File: ADC_DRIVER_TEST.v
// File history:
//      <Revision number>: <Date>: <Comments>
//      <Revision number>: <Date>: <Comments>
//      <Revision number>: <Date>: <Comments>
//
// Description: 
//
// <Description here>
//
// Targeted device: <Family::PolarFireSoC> <Die::MPFS095T> <Package::FCSG325>
// Author: <Name>
//
/////////////////////////////////////////////////////////////////////////////////////////////////// 

`timescale 1ns/100ps

module ADC_DRIVER_TEST;

parameter SYSCLK_PERIOD = 10;// 100MHZ

reg SYSCLK;
reg NSYSRESET;

wire o_spi_clk;
wire o_spi_cs;
wire o_spi_mosi;

initial
begin
    SYSCLK = 1'b0;
    NSYSRESET = 1'b0;
end

//////////////////////////////////////////////////////////////////////
// Reset Pulse
//////////////////////////////////////////////////////////////////////
initial
begin
    #(SYSCLK_PERIOD * 10 )
        NSYSRESET = 1'b1;
end


//////////////////////////////////////////////////////////////////////
// Clock Driver
//////////////////////////////////////////////////////////////////////
always @(SYSCLK)
begin
    #(SYSCLK_PERIOD / 2.0) SYSCLK <= !SYSCLK;
end


//////////////////////////////////////////////////////////////////////
// Instantiate Unit Under Test:  ADC128S102_DRIVER
//////////////////////////////////////////////////////////////////////
ADC128S102_DRIVER #(.CHANNEL_COUNT(5), .SPI_CLK_DIV(8)) ADC128S102_DRIVER_0 (
    // Inputs
    .i_clk(SYSCLK),
    .i_res(NSYSRESET),
    .i_data_ready(2**5 - 1),
    .lvdt_adc_spi_miso(0),

    // Outputs
    .o_data( ),
    .o_data_valid( ),
    .o_spi_clk(o_spi_clk),
    .o_spi_cs(o_spi_cs),
    .o_spi_mosi(o_spi_mosi)

    // Inouts

);

endmodule