///////////////////////////////////////////////////////////////////////////////////////////////////
// Company: <Name>
//
// File: ADC_DRIVER.sv
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

//`timescale <time_units> / <precision>

module ADC128S102_DRIVER

    #(  
        parameter   CHANNEL_COUNT = 2,
        parameter   SPI_CLK_DIV   = 8
    )

    (
        input i_clk,
        input i_res,

        output [13 * CHANNEL_COUNT - 1: 0] o_data,
        output reg [CHANNEL_COUNT - 1  : 0] o_data_valid,
        input [CHANNEL_COUNT - 1 : 0] i_data_ready,
        
        output o_spi_clk,
        output o_spi_cs,
        output o_spi_mosi,
        input lvdt_adc_spi_miso    
    );

localparam ACC_REG_MAX = SPI_CLK_DIV / 2 - 1;

reg [12 : 0] o_data_stored [CHANNEL_COUNT - 1 : 0];

genvar j;
generate
for(j = 0; j < CHANNEL_COUNT; j += 1)
begin
    assign o_data[j * 13 + 12 : j*13] = o_data_stored[j];
end
endgenerate


reg spi_clk;
reg spi_cs;
reg spi_mosi;
reg [$clog2(ACC_REG_MAX) : 0] acc_reg;

assign o_spi_clk = spi_clk;
assign o_spi_mosi = spi_mosi;
assign o_spi_cs = spi_cs;

reg [12 : 0] sample_storage;

reg [4 : 0] spi_clk_counter;
reg [2 : 0] channel_counter, last_channel;

wire [15 : 0] mosi_data;

assign mosi_data = {11'b0, channel_counter[0], channel_counter[1], channel_counter[2], 2'b0};

always @(posedge i_clk)
begin

    if (i_res == 0)
    begin

        spi_clk <= 1;
        acc_reg <= 0;
        spi_clk_counter <= 0;
        last_channel <= 0;
        channel_counter <= 1;
        sample_storage <= 0;
        spi_mosi <= 0;
        spi_cs <= 1;

        for(int i = 0; i < CHANNEL_COUNT; i += 1)
        begin
            o_data_stored[i] <= 0;

            o_data_valid[i] <= 0;
        end

    
    end
    else
    begin   
    
        if (acc_reg < ACC_REG_MAX)
            acc_reg <= acc_reg + 1;
        else
        begin
    
            acc_reg <= 0;
            spi_clk <= ~spi_clk;

            if(spi_clk)
            begin

                if(spi_clk_counter == 16)
                begin

                    spi_cs <= 1;
                    spi_clk_counter <= 0;
                    spi_mosi <= 0;

                end
                else if(spi_clk_counter <= 15)
                begin

                    spi_mosi <= mosi_data[spi_clk_counter];
                    spi_cs <= 0;
                    spi_clk_counter += 1;

                end

            end

            if (!spi_clk)
            begin

                if(spi_clk_counter >= 4)
                    sample_storage[16 - spi_clk_counter] <= lvdt_adc_spi_miso;

                if(spi_clk_counter == 0)
                begin
                    
                    o_data_stored[last_channel] <= sample_storage;
                    
                    o_data_valid[last_channel] <= 1;

                    if (channel_counter >= CHANNEL_COUNT - 1)
                        channel_counter <= 0;
                    else
                        channel_counter <= channel_counter + 1;

                    last_channel <= channel_counter;

                end

            end
        end

        for(int i = 0; i < CHANNEL_COUNT; i += 1)
        begin
            if(o_data_valid[i] == 1 && i_data_ready[i])
                o_data_valid[i] <= 0;
        end

    end
end


endmodule