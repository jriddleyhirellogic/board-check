`timescale 1ns / 1ps

module dma_write_ddr4_8gb_tb;

//------------------------------------------------------------------------------
// Parameters
//------------------------------------------------------------------------------
parameter integer CLOCK_FREQ_MHZ = 150;
parameter integer TIMEOUT_USEC   = 10_000;

// Clock periods in ns
parameter real PIXEL_CLK_PERIOD = 1000.0 / 100.0;  // 10ns for 100MHz
parameter real DDR_CLK_PERIOD   = 1000.0 / 150.0;  // 6.67ns for 150MHz

// Camera frame parameters
parameter integer H_WIDTH_PIXELS     = 4512;
parameter integer PIXEL_WIDTH_BITS   = 12;
parameter integer CAM_DATA_WIDTH     = 384;
parameter integer PIXELS_PER_CYCLE   = CAM_DATA_WIDTH / PIXEL_WIDTH_BITS; //32pxl
parameter integer LINE_ACTIVE_CYCLES = 141;  // cam_line_valid high
parameter integer LINE_BLANK_CYCLES  = 160; // cam_line_valid low
parameter integer FRAME_START_DELAY  = 64;   // delay after frame_valid
parameter integer NUM_LINES          = 10;
parameter integer FRAME_BLANK_CYCLES = 1000;
parameter integer NUM_FRAMES         = 256;

//------------------------------------------------------------------------------
// Signals
//------------------------------------------------------------------------------
// Clocks and resets
logic             pixel_clk;
logic             pixel_rst_n;
logic             ddr_clk;
logic             ddr_rst_n;

// Camera interface
logic             cam_frame_valid;
logic             cam_line_valid;
logic [383:0]     cam_data_in;

// APB Register interface
logic             apb_reg_clear_index;
logic [13:0]      apb_reg_h_size_byte;
logic [7:0]       apb_reg_frame_index;
logic             apb_reg_core_ready;
logic             apb_reg_frame_write_done;
logic [31:0]      apb_reg_timeout_err;

// DMA to Arbiter interface
logic             arb_write_req;
logic             arb_write_ack;
logic [7:0]       arb_write_burst_len;
logic [37:0]      arb_write_start_addr;
logic             arb_write_done;
logic             arb_write_valid;
logic [255:0]     arb_write_data;

// Test variables
integer           frame_count;
integer           line_count;
integer           pixel_cycle_count;
logic [15:0]      byte_counter;  // Incrementing byte pattern

//------------------------------------------------------------------------------
// DUT Instantiation
//------------------------------------------------------------------------------
dma_write_ddr4_8gb #(
    .CLOCK_FREQ_MHZ (CLOCK_FREQ_MHZ),
    .TIMEOUT_USEC   (TIMEOUT_USEC)
) dut (
    .pixel_clk                (pixel_clk               ),
    .pixel_rst_n              (pixel_rst_n             ),
    .ddr_clk                  (ddr_clk                 ),
    .ddr_rst_n                (ddr_rst_n               ),
    .cam_frame_valid          (cam_frame_valid         ),
    .cam_line_valid           (cam_line_valid          ),
    .cam_data_in              (cam_data_in             ),
    .apb_reg_clear_index      (apb_reg_clear_index     ),
    .apb_reg_h_size_byte      (apb_reg_h_size_byte     ),
    .apb_reg_frame_index      (apb_reg_frame_index     ),
    .apb_reg_core_ready       (apb_reg_core_ready      ),
    .apb_reg_frame_write_done (apb_reg_frame_write_done),
    .apb_reg_timeout_err      (apb_reg_timeout_err     ),
    .arb_write_req            (arb_write_req           ),
    .arb_write_ack            (arb_write_ack           ),
    .arb_write_burst_len      (arb_write_burst_len     ),
    .arb_write_start_addr     (arb_write_start_addr    ),
    .arb_write_done           (arb_write_done          ),
    .arb_write_valid          (arb_write_valid         ),
    .arb_write_data           (arb_write_data          )
);

//------------------------------------------------------------------------------
// Clock Generation
//------------------------------------------------------------------------------
initial begin
    pixel_clk = 0;
    forever #(PIXEL_CLK_PERIOD/2) pixel_clk = ~pixel_clk;
end

initial begin
    ddr_clk = 0;
    forever #(DDR_CLK_PERIOD/2) ddr_clk = ~ddr_clk;
end

//------------------------------------------------------------------------------
// Reset Generation
//------------------------------------------------------------------------------
initial begin
    pixel_rst_n = 0;
    ddr_rst_n = 0;
    #100;
    pixel_rst_n = 1;
    ddr_rst_n = 1;
end

//------------------------------------------------------------------------------
// APB Register Configuration
//------------------------------------------------------------------------------
initial begin
    apb_reg_clear_index = 0;
    apb_reg_h_size_byte = 14'd6768;  // 4512 pixels * 12 bits / 8 = 6768 bytes

    // Wait for reset
    wait(pixel_rst_n && ddr_rst_n);
    #200;
end

//------------------------------------------------------------------------------
// Arbiter Response Model
//------------------------------------------------------------------------------
initial begin
    arb_write_ack = 0;
    arb_write_done = 0;

    forever begin
        @(posedge ddr_clk);

        // Respond to write request
        if (arb_write_req && !arb_write_ack) begin
            repeat($urandom_range(1, 5)) @(posedge ddr_clk);
            arb_write_ack = 1;
            @(posedge ddr_clk);
            arb_write_ack = 0;

            // Wait for burst to complete, then assert done
            wait(arb_write_valid);
            while(arb_write_valid) @(posedge ddr_clk);
            repeat($urandom_range(1, 3)) @(posedge ddr_clk);
            arb_write_done = 1;
            @(posedge ddr_clk);
            arb_write_done = 0;
        end
    end
end

//------------------------------------------------------------------------------
// Camera Frame Generator
//------------------------------------------------------------------------------
initial begin
    // Initialize signals
    cam_frame_valid = 0;
    cam_line_valid = 0;
    cam_data_in = 384'd0;
    frame_count = 0;
    line_count = 0;
    pixel_cycle_count = 0;
    byte_counter = 16'd0;

    // Wait for reset
    wait(pixel_rst_n);
    repeat(10) @(posedge pixel_clk);

    // Pulse clear_index
    @(posedge pixel_clk);
    apb_reg_clear_index = 1;
    @(posedge pixel_clk);
    apb_reg_clear_index = 0;
    repeat(10) @(posedge pixel_clk);

    // Generate 256 frames
    for (frame_count = 0; frame_count < NUM_FRAMES; frame_count++) begin
        $display("Starting Frame %0d at time %0t", frame_count, $time);

        // Assert frame valid
        @(posedge pixel_clk);
        cam_frame_valid = 1;

        // Wait for frame start delay
        repeat(FRAME_START_DELAY) @(posedge pixel_clk);

        // Generate lines
        for (line_count = 0; line_count < NUM_LINES; line_count++) begin
            // Assert line valid and generate pixel data
            @(posedge pixel_clk);
            cam_line_valid = 1;

            for (pixel_cycle_count = 0;
                pixel_cycle_count < LINE_ACTIVE_CYCLES;
                pixel_cycle_count++) begin
                // Generate byte incrementing pattern for cam_data_in[383:0]
                // Each cycle sends 384 bits = 48 bytes
                for (int i = 0; i < 48; i++) begin
                    cam_data_in[i*8 +: 8] = byte_counter[7:0];
                    byte_counter++;
                end

                @(posedge pixel_clk);
            end

            // Deassert line valid
            cam_line_valid = 0;

            // Line blanking period
            repeat(LINE_BLANK_CYCLES) @(posedge pixel_clk);
        end

        // Deassert frame valid
        cam_frame_valid = 0;

        // Frame blanking period
        repeat(FRAME_BLANK_CYCLES) @(posedge pixel_clk);
    end

    $display("All %0d frames completed at time %0t", NUM_FRAMES, $time);
    repeat(100) @(posedge pixel_clk);
    $stop;
end

//------------------------------------------------------------------------------
// Monitor
//------------------------------------------------------------------------------
initial begin
    integer write_count;
    write_count = 0;

    forever begin
        @(posedge ddr_clk);
        if (arb_write_valid) begin
            write_count++;
            if (write_count % 1000 == 0) begin
                $display("Time %0t: Write count = %0d, Frame Index = %0d",
                            $time, write_count, apb_reg_frame_index);
            end
        end

        if (apb_reg_frame_write_done) begin
            $display("Time %0t: Frame %0d write completed",
                        $time, apb_reg_frame_index);
        end
    end
end

endmodule
