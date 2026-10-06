/*
 * @file      slvs_ec_to_write_ddr_tb.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      07/13/2026
 * 
 * @brief     SLVS-EC to Write DDR Testbench. This testbench verifies the
 *            functionality of the SLVS-EC to DDR4 Arbiter path.
 
 * @section changelog
 * - 07/13/2026: Steven Knyazher - Initial implementation
 * - 08/18/2026: Steven Knyazher - Added cam_tout camera model for the image
 *                                 metadata exposure time measurement, and
 *                                 xtrig_low_time is now programmed in
 *                                 clock cycles
 * 
 */

`timescale 1ns/1ps

module slvs_ec_to_write_ddr_tb;

    //--------------------------------------------------------------------------
    // Parameters
    //--------------------------------------------------------------------------
    localparam int APB_DATA_WIDTH       = 32;
    localparam int APB_ADDR_WIDTH       = 32;
    localparam int CAM_DATA_WIDTH       = 384;
    localparam int DDR4_BURST_LEN_WIDTH = 8;
    localparam int DDR4_8GB_ADDR_WIDTH  = 38;
    localparam int DDR4_8GB_DATA_WIDTH  = 256;
    localparam int DDR4_16GB_ADDR_WIDTH = 39;
    localparam int DDR4_16GB_DATA_WIDTH = 512;

    // Clock periods (ns)
    localparam real PCLK_PERIOD      = 20.000;  // 50   MHz
    localparam real PIXEL_CLK_PERIOD = 12.626;  // 79.2 MHz
    localparam real DDR_CLK_PERIOD   = 6.667;   // 150  MHz

    // DMA write register offsets
    localparam logic [APB_ADDR_WIDTH-1:0] CLEAR_INDEX_OFFSET = 32'h0;
    localparam logic [APB_ADDR_WIDTH-1:0] H_SIZE_BYTE_OFFSET = 32'h4;

    // Camera MUX register offsets
    localparam logic [APB_ADDR_WIDTH-1:0] MUX_CLEAR_OFFSET = 32'h0;

    // PPS register offsets
    localparam logic [APB_ADDR_WIDTH-1:0] TRIGGER_TIME_JAM_OFFSET    = 32'h0;
    localparam logic [APB_ADDR_WIDTH-1:0] LOAD_SECONDS_OFFSET        = 32'h4;
    localparam logic [APB_ADDR_WIDTH-1:0] PPS_RX_DELAY_OFFSET        = 32'h8;
    localparam logic [APB_ADDR_WIDTH-1:0] EN_LOCAL_PPS_SOURCE_OFFSET = 32'hC;

    // Cam trig register offsets
    localparam logic [APB_ADDR_WIDTH-1:0] XTRIG_LOW_TIME_OFFSET       = 32'h0;
    localparam logic [APB_ADDR_WIDTH-1:0] FRAME_CAPTURE_TIME_OFFSET   = 32'h4;
    localparam logic [APB_ADDR_WIDTH-1:0] FRAME_CAPTURE_AMOUNT_OFFSET = 32'h8;
    localparam logic [APB_ADDR_WIDTH-1:0] XTRIG_START_OFFSET          = 32'hC;
    localparam logic [APB_ADDR_WIDTH-1:0] XTRIG_SRC_SEL_OFFSET        = 32'h10;
    localparam logic [APB_ADDR_WIDTH-1:0] SCHEDULER_TIME_SEC_OFFSET   = 32'h14;
    localparam logic [APB_ADDR_WIDTH-1:0] SCHEDULER_TIME_MSEC_OFFSET  = 32'h18;
    localparam logic [APB_ADDR_WIDTH-1:0] CAM_TRIG_BUSY_OFFSET        = 32'h1C;

    // Cam fault detector register offsets
    localparam logic [APB_ADDR_WIDTH-1:0] FAULT_OFFSET       = 32'h0;
    localparam logic [APB_ADDR_WIDTH-1:0] FAULT_CLEAR_OFFSET = 32'h4;

    // PPS start time: DATETIME_TO_UNIX(2026, 6, 15, 21, 26, 00)
    localparam logic [APB_DATA_WIDTH-1:0] PPS_START_TIME = 32'd1781558760;

    // Cam trig stimulus values
    localparam logic [APB_DATA_WIDTH-1:0] XTRIG_LOW_TIME_CYCLES   = 32'd5000; // 100 us at 50 MHz
    localparam logic [APB_DATA_WIDTH-1:0] FRAME_CAPTURE_TIME_USEC = 32'd1500;
    localparam logic [APB_DATA_WIDTH-1:0] FRAME_CAPTURE_AMOUNT    = 32'd2;
    localparam logic [APB_DATA_WIDTH-1:0] XTRIG_SRC_SEL_MANUAL    = 32'd0;
    localparam logic [APB_DATA_WIDTH-1:0] XTRIG_SRC_SEL_SCHEDULER = 32'd1;
    localparam logic [APB_DATA_WIDTH-1:0] XTRIG_SRC_SEL_LVDS      = 32'd2;
    // PPS_SCHEDULER: DATETIME_TO_UNIX(2026, 6, 15, 21, 26, 10)
    localparam logic [APB_DATA_WIDTH-1:0] PPS_SCHEDULER_TIME_SEC  = 32'd1781558770;
    localparam logic [APB_DATA_WIDTH-1:0] PPS_SCHEDULER_TIME_MSEC = 32'd0;

    // Horizontal line width
    localparam int HORIZ_WIDTH_BYTE = 832;

    // PPS pulse timing
    localparam time PPS_HIGH_TIME = 142us;
    localparam time PPS_LOW_TIME  = 858us;

    // APB peripheral base addresses
    localparam logic [APB_ADDR_WIDTH-1:0] PPS_BASE_ADDR                 = 32'h70015000;
    localparam logic [APB_ADDR_WIDTH-1:0] CAM_TRIG_BASE_ADDR            = 32'h7000F000;
    localparam logic [APB_ADDR_WIDTH-1:0] CAM_FAULT_DETECTOR_BASE_ADDR  = 32'h7001B000;
    localparam logic [APB_ADDR_WIDTH-1:0] IMAGE_METADATA_BASE_ADDR      = 32'h7000C000;
    localparam logic [APB_ADDR_WIDTH-1:0] CAM_MUX_BASE_ADDR             = 32'h7000B000;
    localparam logic [APB_ADDR_WIDTH-1:0] DMA_WRITE_DDR4_8GB_BASE_ADDR  = 32'h70004000;
    localparam logic [APB_ADDR_WIDTH-1:0] DMA_WRITE_DDR4_16GB_BASE_ADDR = 32'h70005000;


    //--------------------------------------------------------------------------
    // Clocks and resets
    //--------------------------------------------------------------------------
    logic pixel_clk;
    logic pixel_rst_n;
    logic ddr_clk;
    logic ddr_rst_n;
    logic pclk;
    logic presetn;

    //--------------------------------------------------------------------------
    // DUT I/O
    //--------------------------------------------------------------------------
    logic                            pps_in;
    logic                            lvds_trig;

    logic                            cam_pwr_status;
    logic                            cam_tout;
    logic                            xtrig;

    logic                            penable;
    logic                            psel;
    logic [APB_ADDR_WIDTH-1:0]       paddr;
    logic                            pwrite;
    logic [APB_DATA_WIDTH-1:0]       pwdata;
    logic [APB_DATA_WIDTH-1:0]       prdata;
    logic                            pready;
    logic                            pslverr;

    logic                            slvs_ec_frame_valid;
    logic                            slvs_ec_line_valid;
    logic                            slvs_ec_ebd_valid;
    logic [CAM_DATA_WIDTH-1:0]       slvs_ec_data_out;

    logic                            ddr4_8gb_arb_write_req;
    logic                            ddr4_8gb_arb_write_ack;
    logic [DDR4_BURST_LEN_WIDTH-1:0] ddr4_8gb_arb_write_burst_len;
    logic [DDR4_8GB_ADDR_WIDTH-1:0]  ddr4_8gb_arb_write_start_addr;
    logic                            ddr4_8gb_arb_write_done;
    logic                            ddr4_8gb_arb_write_valid;
    logic [DDR4_8GB_DATA_WIDTH-1:0]  ddr4_8gb_arb_write_data;

    logic                            ddr4_16gb_arb_write_req;
    logic                            ddr4_16gb_arb_write_ack;
    logic [DDR4_BURST_LEN_WIDTH-1:0] ddr4_16gb_arb_write_burst_len;
    logic [DDR4_16GB_ADDR_WIDTH-1:0] ddr4_16gb_arb_write_start_addr;
    logic                            ddr4_16gb_arb_write_done;
    logic                            ddr4_16gb_arb_write_valid;
    logic [DDR4_16GB_DATA_WIDTH-1:0] ddr4_16gb_arb_write_data;

    //--------------------------------------------------------------------------
    // DUT instance
    //--------------------------------------------------------------------------
    slvs_ec_to_write_ddr #(
        .APB_DATA_WIDTH       (APB_DATA_WIDTH      ),
        .APB_ADDR_WIDTH       (APB_ADDR_WIDTH      ),
        .CAM_DATA_WIDTH       (CAM_DATA_WIDTH      ),
        .DDR4_BURST_LEN_WIDTH (DDR4_BURST_LEN_WIDTH),
        .DDR4_8GB_ADDR_WIDTH  (DDR4_8GB_ADDR_WIDTH ),
        .DDR4_8GB_DATA_WIDTH  (DDR4_8GB_DATA_WIDTH ),
        .DDR4_16GB_ADDR_WIDTH (DDR4_16GB_ADDR_WIDTH),
        .DDR4_16GB_DATA_WIDTH (DDR4_16GB_DATA_WIDTH)
    ) dut (
        .pixel_clk                      (pixel_clk                     ),
        .pixel_rst_n                    (pixel_rst_n                   ),
        .ddr_clk                        (ddr_clk                       ),
        .ddr_rst_n                      (ddr_rst_n                     ),
        .pclk                           (pclk                          ),
        .presetn                        (presetn                       ),

        .pps_in                         (pps_in                        ),
        .lvds_trig                      (lvds_trig                     ),

        .cam_pwr_status                 (cam_pwr_status                ),
        .cam_tout                       (cam_tout                      ),
        .xtrig                          (xtrig                         ),

        .penable                        (penable                       ),
        .psel                           (psel                          ),
        .paddr                          (paddr                         ),
        .pwrite                         (pwrite                        ),
        .pwdata                         (pwdata                        ),
        .prdata                         (prdata                        ),
        .pready                         (pready                        ),
        .pslverr                        (pslverr                       ),

        .slvs_ec_frame_valid            (slvs_ec_frame_valid           ),
        .slvs_ec_line_valid             (slvs_ec_line_valid            ),
        .slvs_ec_ebd_valid              (slvs_ec_ebd_valid             ),
        .slvs_ec_data_out               (slvs_ec_data_out              ),

        .ddr4_8gb_arb_write_req         (ddr4_8gb_arb_write_req        ),
        .ddr4_8gb_arb_write_ack         (ddr4_8gb_arb_write_ack        ),
        .ddr4_8gb_arb_write_burst_len   (ddr4_8gb_arb_write_burst_len  ),
        .ddr4_8gb_arb_write_start_addr  (ddr4_8gb_arb_write_start_addr ),
        .ddr4_8gb_arb_write_done        (ddr4_8gb_arb_write_done       ),
        .ddr4_8gb_arb_write_valid       (ddr4_8gb_arb_write_valid      ),
        .ddr4_8gb_arb_write_data        (ddr4_8gb_arb_write_data       ),

        .ddr4_16gb_arb_write_req        (ddr4_16gb_arb_write_req       ),
        .ddr4_16gb_arb_write_ack        (ddr4_16gb_arb_write_ack       ),
        .ddr4_16gb_arb_write_burst_len  (ddr4_16gb_arb_write_burst_len ),
        .ddr4_16gb_arb_write_start_addr (ddr4_16gb_arb_write_start_addr),
        .ddr4_16gb_arb_write_done       (ddr4_16gb_arb_write_done      ),
        .ddr4_16gb_arb_write_valid      (ddr4_16gb_arb_write_valid     ),
        .ddr4_16gb_arb_write_data       (ddr4_16gb_arb_write_data      )
    );

    //--------------------------------------------------------------------------
    // Clock generation
    //--------------------------------------------------------------------------
    initial begin
        pclk = 1'b0;
        forever #(PCLK_PERIOD/2.0) pclk = ~pclk;
    end

    initial begin
        pixel_clk = 1'b0;
        forever #(PIXEL_CLK_PERIOD/2.0) pixel_clk = ~pixel_clk;
    end

    initial begin
        ddr_clk = 1'b0;
        forever #(DDR_CLK_PERIOD/2.0) ddr_clk = ~ddr_clk;
    end

    //--------------------------------------------------------------------------
    // Reset generation (active low)
    //--------------------------------------------------------------------------
    initial begin
        presetn     = 1'b0;
        pixel_rst_n = 1'b0;
        ddr_rst_n   = 1'b0;

        repeat (10) @(posedge pclk);

        presetn     = 1'b1;
        pixel_rst_n = 1'b1;
        ddr_rst_n   = 1'b1;
    end

    //--------------------------------------------------------------------------
    // APB access tasks
    //--------------------------------------------------------------------------
    task automatic apb_write(input logic [APB_ADDR_WIDTH-1:0] base_addr,
                             input logic [APB_ADDR_WIDTH-1:0] offset,
                             input logic [APB_DATA_WIDTH-1:0] data);
        // SETUP phase
        @(posedge pclk);
        psel    <= 1'b1;
        penable <= 1'b0;
        pwrite  <= 1'b1;
        paddr   <= base_addr + offset;
        pwdata  <= data;
        // ACCESS phase
        @(posedge pclk);
        penable <= 1'b1;
        // Wait for slave ready
        do @(posedge pclk); while (!pready);
        // Return to IDLE
        psel    <= 1'b0;
        penable <= 1'b0;
        pwrite  <= 1'b0;
        paddr   <= '0;
        pwdata  <= '0;
    endtask

    task automatic apb_read(input  logic [APB_ADDR_WIDTH-1:0] base_addr,
                            input  logic [APB_ADDR_WIDTH-1:0] offset,
                            output logic [APB_DATA_WIDTH-1:0] data);
        // SETUP phase
        @(posedge pclk);
        psel    <= 1'b1;
        penable <= 1'b0;
        pwrite  <= 1'b0;
        paddr   <= base_addr + offset;
        // ACCESS phase
        @(posedge pclk);
        penable <= 1'b1;
        // Wait for slave ready and capture data
        do @(posedge pclk); while (!pready);
        data = prdata;
        // Return to IDLE
        psel    <= 1'b0;
        penable <= 1'b0;
        paddr   <= '0;
    endtask

    //--------------------------------------------------------------------------
    // Reset write index
    //--------------------------------------------------------------------------
    task automatic reset_write_index();
        reset_dma_write(DMA_WRITE_DDR4_8GB_BASE_ADDR);
        reset_dma_write(DMA_WRITE_DDR4_16GB_BASE_ADDR);
        cam_mux_clear();
    endtask

    //--------------------------------------------------------------------------
    // Reset DMA write
    //--------------------------------------------------------------------------
    task automatic reset_dma_write(input logic [APB_ADDR_WIDTH-1:0] base_addr);
        logic [APB_DATA_WIDTH-1:0] rdata;
        apb_write(base_addr, CLEAR_INDEX_OFFSET, 1'b1);
        #10us;
        apb_read(base_addr, CLEAR_INDEX_OFFSET, rdata);
    endtask

    //--------------------------------------------------------------------------
    // Camera MUX clear
    //--------------------------------------------------------------------------
    task automatic cam_mux_clear();
        apb_write(CAM_MUX_BASE_ADDR, MUX_CLEAR_OFFSET, 1'b1);
        #10us;
    endtask

    //--------------------------------------------------------------------------
    // Configure DMA write
    //--------------------------------------------------------------------------
    task automatic configure_dma_write(input logic [APB_ADDR_WIDTH-1:0] base_addr,
                                       input logic [APB_DATA_WIDTH-1:0] h_size_byte);
        logic [APB_DATA_WIDTH-1:0] rdata;
        apb_write(base_addr, H_SIZE_BYTE_OFFSET, h_size_byte);
        apb_read(base_addr, H_SIZE_BYTE_OFFSET, rdata);
    endtask

    //--------------------------------------------------------------------------
    // PPS generator
    //--------------------------------------------------------------------------
    task automatic pps_gen();
        forever begin
            pps_in = 1'b1;
            #(PPS_HIGH_TIME);
            pps_in = 1'b0;
            #(PPS_LOW_TIME);
        end
    endtask

    //--------------------------------------------------------------------------
    // Configure PPS
    //--------------------------------------------------------------------------
    task automatic configure_pps(input logic [APB_ADDR_WIDTH-1:0] base_addr,
                                 input logic [APB_DATA_WIDTH-1:0] load_seconds,
                                 input logic [APB_DATA_WIDTH-1:0] pps_rx_delay,
                                 input logic [APB_DATA_WIDTH-1:0] en_local_pps_source);
        logic [APB_DATA_WIDTH-1:0] rdata;
        apb_write(base_addr, LOAD_SECONDS_OFFSET, load_seconds);
        apb_read(base_addr, LOAD_SECONDS_OFFSET, rdata);
        apb_write(base_addr, PPS_RX_DELAY_OFFSET, pps_rx_delay);
        apb_read(base_addr, PPS_RX_DELAY_OFFSET, rdata);
        apb_write(base_addr, EN_LOCAL_PPS_SOURCE_OFFSET, en_local_pps_source);
        apb_read(base_addr, EN_LOCAL_PPS_SOURCE_OFFSET, rdata);
    endtask

    //--------------------------------------------------------------------------
    // Start PPS
    //--------------------------------------------------------------------------
    task automatic pps_start(input logic [APB_ADDR_WIDTH-1:0] base_addr);
        apb_write(base_addr, TRIGGER_TIME_JAM_OFFSET, 1'b1);
    endtask

    //--------------------------------------------------------------------------
    // Configure camera trigger
    //--------------------------------------------------------------------------
    task automatic configure_trig(input logic [APB_ADDR_WIDTH-1:0] base_addr,
                                  input logic [APB_DATA_WIDTH-1:0] xtrig_low_time,
                                  input logic [APB_DATA_WIDTH-1:0] frame_capture_time,
                                  input logic [APB_DATA_WIDTH-1:0] frame_capture_amount,
                                  input logic [APB_DATA_WIDTH-1:0] xtrig_src_sel,
                                  input logic [APB_DATA_WIDTH-1:0] scheduler_time_sec,
                                  input logic [APB_DATA_WIDTH-1:0] scheduler_time_msec);
        logic [APB_DATA_WIDTH-1:0] rdata;
        apb_write(base_addr, XTRIG_LOW_TIME_OFFSET, xtrig_low_time);
        apb_read(base_addr, XTRIG_LOW_TIME_OFFSET, rdata);
        apb_write(base_addr, FRAME_CAPTURE_TIME_OFFSET, frame_capture_time);
        apb_read(base_addr, FRAME_CAPTURE_TIME_OFFSET, rdata);
        apb_write(base_addr, FRAME_CAPTURE_AMOUNT_OFFSET, frame_capture_amount);
        apb_read(base_addr, FRAME_CAPTURE_AMOUNT_OFFSET, rdata);
        apb_write(base_addr, SCHEDULER_TIME_SEC_OFFSET, scheduler_time_sec);
        apb_read(base_addr, SCHEDULER_TIME_SEC_OFFSET, rdata);
        apb_write(base_addr, SCHEDULER_TIME_MSEC_OFFSET, scheduler_time_msec);
        apb_read(base_addr, SCHEDULER_TIME_MSEC_OFFSET, rdata);
        apb_write(base_addr, XTRIG_SRC_SEL_OFFSET, xtrig_src_sel);
        apb_read(base_addr, XTRIG_SRC_SEL_OFFSET, rdata);
    endtask

    //--------------------------------------------------------------------------
    // Capture camera trigger
    //--------------------------------------------------------------------------
    task automatic trig_capture(input logic [APB_ADDR_WIDTH-1:0] base_addr);
        logic [APB_DATA_WIDTH-1:0] rdata;
        apb_write(base_addr, XTRIG_START_OFFSET, 1'b0);
        apb_write(base_addr, XTRIG_START_OFFSET, 1'b1);
        apb_read(base_addr, XTRIG_START_OFFSET, rdata);
    endtask

    //--------------------------------------------------------------------------
    // Read camera trigger busy status
    //--------------------------------------------------------------------------
    task automatic trig_busy(input  logic [APB_ADDR_WIDTH-1:0] base_addr,
                             output logic                      busy);
        logic [APB_DATA_WIDTH-1:0] rdata;
        apb_read(base_addr, CAM_TRIG_BUSY_OFFSET, rdata);
        busy = rdata[0];
    endtask

    //--------------------------------------------------------------------------
    // SLVS-EC signal generator
    //
    // Triggered by the DUT xtrig output. On each xtrig low->high pulse it
    // emits one frame: a frame-valid assertion, 4 embedded-data (EBD) lines,
    // 64 all-ones lines, then 68 lines carrying a 12-bit incrementing pattern
    // that continues across lines. When gen_slvs_ec_en is low the trigger is
    // observed but no frame is produced (used to force a camera timeout fault).
    //--------------------------------------------------------------------------
    bit gen_slvs_ec_en = 1'b1;

    task automatic gen_slvs_ec();
        localparam int NUM_CHUNKS = CAM_DATA_WIDTH / 12;
        logic [11:0]               cnt;
        logic [CAM_DATA_WIDTH-1:0] word;
        int                        i;

        forever begin
            // Wait for xtrig to pulse low then return high
            @(negedge xtrig);
            @(posedge xtrig);

            // Skip frame production when disabled (simulate no camera response)
            if (!gen_slvs_ec_en) continue;

            // 50us after xtrig rising edge: assert frame valid
            #50us;
            slvs_ec_frame_valid <= 1'b1;

            // 150us later: start embedded data (EBD) lines
            #150us;

            // 4 EBD lines: ebd_valid high for 17 pixel_clk cycles, 1.5us apart,
            // carrying a known pattern
            repeat (4) begin
                @(posedge pixel_clk);
                slvs_ec_data_out  <= {NUM_CHUNKS{12'hEBD}};
                slvs_ec_ebd_valid <= 1'b1;
                repeat (17) @(posedge pixel_clk);
                slvs_ec_ebd_valid <= 1'b0;
                slvs_ec_data_out  <= '0;
                #1.5us;
            end

            // 64 lines: line_valid high for 17 cycles with all-ones data,
            // 1.5us apart
            repeat (64) begin
                @(posedge pixel_clk);
                slvs_ec_data_out   <= '1;
                slvs_ec_line_valid <= 1'b1;
                repeat (17) @(posedge pixel_clk);
                slvs_ec_line_valid <= 1'b0;
                slvs_ec_data_out   <= '0;
                #1.5us;
            end

            // 544 lines: line_valid high for 17 cycles with a 12-bit incrementing
            // pattern (chunk[i] = cnt++) that advances every valid cycle and
            // continues across lines, 1.5us apart
            cnt = 12'h000;
            repeat (544) begin
                @(posedge pixel_clk);
                slvs_ec_line_valid <= 1'b1;
                repeat (17) begin
                    word = '0;
                    for (i = 0; i < NUM_CHUNKS; i++) begin
                        word[12*i +: 12] = cnt;
                        cnt = cnt + 1'b1;
                    end
                    slvs_ec_data_out <= word;
                    @(posedge pixel_clk);
                end
                slvs_ec_line_valid <= 1'b0;
                slvs_ec_data_out   <= '0;
                #1.5us;
            end

            // 10 pixel_clk cycles after the last line: deassert frame valid
            repeat (10) @(posedge pixel_clk);
            slvs_ec_frame_valid <= 1'b0;
        end
    endtask

    //--------------------------------------------------------------------------
    // Camera TOUT generator
    //
    // Models the camera's TOUT pin, which the image metadata block uses to
    // measure exposure time (the low duration of cam_tout, in microseconds).
    //
    //   - Held low until cam_pwr_status asserts, then driven high (idle).
    //   - Goes low CAM_TOUT_XTRIG_DELAY_CYC pclk cycles after xtrig falls,
    //     marking the start of the exposure.
    //   - Stays low until CAM_TOUT_FRAME_DELAY_CYC pixel_clk cycles into
    //     frame_valid, then returns high to mark the end of the exposure.
    //
    // Because cam_tout rises after frame_valid does, the metadata block latches
    // an exposure time that belongs to the frame currently being read out.
    //--------------------------------------------------------------------------
    localparam int  CAM_TOUT_XTRIG_DELAY_CYC = 5;   // pclk cycles after xtrig falls
    localparam int  CAM_TOUT_FRAME_DELAY_CYC = 20;  // pixel_clk cycles into frame_valid
    localparam time CAM_TOUT_FRAME_TIMEOUT   = 2ms; // give up waiting for a frame

    task automatic gen_cam_tout();
        forever begin
            // Camera holds TOUT low while unpowered
            cam_tout = 1'b0;
            wait (cam_pwr_status);
            @(posedge pclk);
            cam_tout <= 1'b1;

            // Run the exposure model until camera power is cut
            fork
                begin : tout_model
                    forever begin
                        // xtrig falling edge starts the exposure
                        @(negedge xtrig);
                        repeat (CAM_TOUT_XTRIG_DELAY_CYC) @(posedge pclk);
                        cam_tout <= 1'b0;

                        // Exposure ends a few cycles into the frame readout.
                        // Bound the wait so a suppressed frame (camera timeout
                        // scenario) does not desync the model.
                        fork
                            begin
                                @(posedge slvs_ec_frame_valid);
                                repeat (CAM_TOUT_FRAME_DELAY_CYC) @(posedge pixel_clk);
                            end
                            #(CAM_TOUT_FRAME_TIMEOUT);
                        join_any
                        disable fork;

                        cam_tout <= 1'b1;
                    end
                end
                begin : pwr_monitor
                    @(negedge cam_pwr_status);
                end
            join_any
            disable fork;
        end
    endtask

    //--------------------------------------------------------------------------
    // DDR4 write arbiter model
    //
    // Emulates the downstream write arbiter for one DDR4 core. On each write
    // request (sampled on ddr_clk) it returns a single-cycle ack, then counts
    // valid write beats. The requested burst length is (beats - 1), so it
    // waits for (burst_len + 1) valid beats before pulsing done.
    //--------------------------------------------------------------------------
    task automatic ddr4_arb_model(
        ref logic                            req,
        ref logic                            ack,
        ref logic [DDR4_BURST_LEN_WIDTH-1:0] burst_len,
        ref logic                            valid,
        ref logic                            done);
        int unsigned beats;
        forever begin
            // Wait for a write request sampled on ddr_clk
            @(posedge ddr_clk);
            if (req) begin
                // Latch the requested beat count (burst_len is beats - 1)
                beats = burst_len + 1;
                // Acknowledge the request for one cycle
                ack = 1'b1;
                @(posedge ddr_clk);
                ack = 1'b0;
                // Count the valid write beats
                for (int unsigned i = 0; i < beats; i++) begin
                    do @(posedge ddr_clk); while (!valid);
                end
                // Signal completion for one cycle
                done = 1'b1;
                @(posedge ddr_clk);
                done = 1'b0;
            end
        end
    endtask

    //--------------------------------------------------------------------------
    // Frame data capture to raw files
    //
    // frame_num advances on each slvs_ec_frame_valid rising edge. Write beats
    // are captured (LSB 32-bit word first) into ddr4_<core>_frame_<n>.raw for
    // the frame currently being written. The frame number only advances at the
    // start of the next frame, so trailing write beats that occur after
    // slvs_ec_frame_valid deasserts are still captured into the correct file.
    //--------------------------------------------------------------------------
    int ddr4_8gb_fd  = 0;
    int ddr4_16gb_fd = 0;
    int frame_num    = -1;

    // Names of the most recently created raw capture files (used to delete a
    // file that was created while exercising the camera fault-detector).
    string ddr4_8gb_last_file  = "";
    string ddr4_16gb_last_file = "";

    // Running count of write beats accepted by each DDR4 core (used by the
    // scenario checks to verify where frames were routed).
    int ddr4_8gb_beats  = 0;
    int ddr4_16gb_beats = 0;

    // Frame counter: advance on each frame-valid rising edge
    initial begin
        forever begin
            @(posedge slvs_ec_frame_valid);
            frame_num = frame_num + 1;
        end
    end

    // Write one write-data beat as raw little-endian 32-bit words
    task automatic write_beat(input int                              fd,
                              input logic [DDR4_16GB_DATA_WIDTH-1:0] data,
                              input int                              n_words);
        for (int w = 0; w < n_words; w++) begin
            $fwrite(fd, "%u", data[w*32 +: 32]);
        end
    endtask

    // DDR4 8GB write data capture
    //
    // 8GB frame files are named starting from index 512 (independent of the
    // shared frame_num), so they do not continue from where the 16GB capture
    // left off.
    //
    // Each beat is placed in the raw file at its frame-relative byte address so
    // that every camera line lands on its HORIZ_WIDTH_BYTE stride boundary. The
    // DMA writes line N at frame-relative address N*HORIZ_WIDTH_BYTE, so a line
    // (e.g. the metadata line) that writes fewer than a full line of beats
    // still leaves the following line correctly aligned. This matches how the
    // read side reads the frame back by line stride; a plain contiguous append
    // would drop the inter-line gaps and shift every subsequent line.
    initial begin
        int     cur_frame;
        int     ddr4_8gb_file_idx;
        longint frame_base;
        longint burst_addr;
        int     beat_in_burst;
        longint byte_off;
        cur_frame         = -1;
        ddr4_8gb_file_idx = 512;
        frame_base        = 0;
        burst_addr        = 0;
        beat_in_burst     = 0;
        forever begin
            @(posedge ddr_clk);
            if (ddr4_8gb_arb_write_valid) begin
                if (frame_num != cur_frame) begin
                    if (ddr4_8gb_fd != 0) begin
                        $fclose(ddr4_8gb_fd);
                        ddr4_8gb_fd = 0;
                    end
                    cur_frame = frame_num;
                    // Do not create a raw file for a frame that is dropped
                    // because the DDR4 8GB core is full.
                    if (!dut.cam_mux_top_inst.cam_mux_inst.ddr4_8gb_full) begin
                        ddr4_8gb_last_file = $sformatf("ddr4_8gb_frame_%0d.raw", ddr4_8gb_file_idx);
                        ddr4_8gb_fd = $fopen(ddr4_8gb_last_file, "wb");
                        ddr4_8gb_file_idx = ddr4_8gb_file_idx + 1;
                    end
                    // Latch the frame base address; per-beat file offsets are
                    // taken relative to it so line 0 starts at file offset 0.
                    frame_base    = ddr4_8gb_arb_write_start_addr;
                    burst_addr    = ddr4_8gb_arb_write_start_addr;
                    beat_in_burst = 0;
                end
                if (ddr4_8gb_fd != 0) begin
                    // A new burst starts whenever the arbiter start address
                    // changes; beats within a burst increment by one beat.
                    if (ddr4_8gb_arb_write_start_addr != burst_addr) begin
                        burst_addr    = ddr4_8gb_arb_write_start_addr;
                        beat_in_burst = 0;
                    end
                    byte_off = (ddr4_8gb_arb_write_start_addr - frame_base) +
                               (beat_in_burst * (DDR4_8GB_DATA_WIDTH/8));
                    void'($fseek(ddr4_8gb_fd, byte_off, 0));
                    write_beat(ddr4_8gb_fd, ddr4_8gb_arb_write_data, DDR4_8GB_DATA_WIDTH/32);
                    beat_in_burst  = beat_in_burst + 1;
                    ddr4_8gb_beats = ddr4_8gb_beats + 1;
                end
            end
        end
    end

    // DDR4 16GB write data capture
    //
    // Each beat is placed at its frame-relative byte address (see the 8GB
    // capture above) so every camera line lands on its HORIZ_WIDTH_BYTE stride
    // boundary, matching how the read side reads the frame back by line stride.
    initial begin
        int     cur_frame;
        longint frame_base;
        longint burst_addr;
        int     beat_in_burst;
        longint byte_off;
        cur_frame     = -1;
        frame_base    = 0;
        burst_addr    = 0;
        beat_in_burst = 0;
        forever begin
            @(posedge ddr_clk);
            if (ddr4_16gb_arb_write_valid) begin
                if (frame_num != cur_frame) begin
                    if (ddr4_16gb_fd != 0) begin
                        $fclose(ddr4_16gb_fd);
                        ddr4_16gb_fd = 0;
                    end
                    cur_frame = frame_num;
                    // Do not create a raw file for a frame that is dropped
                    // because the DDR4 16GB core is full.
                    if (!dut.cam_mux_top_inst.cam_mux_inst.ddr4_16gb_full) begin
                        ddr4_16gb_last_file = $sformatf("ddr4_16gb_frame_%0d.raw", cur_frame);
                        ddr4_16gb_fd = $fopen(ddr4_16gb_last_file, "wb");
                    end
                    // Latch the frame base address; per-beat file offsets are
                    // taken relative to it so line 0 starts at file offset 0.
                    frame_base    = ddr4_16gb_arb_write_start_addr;
                    burst_addr    = ddr4_16gb_arb_write_start_addr;
                    beat_in_burst = 0;
                end
                if (ddr4_16gb_fd != 0) begin
                    // A new burst starts whenever the arbiter start address
                    // changes; beats within a burst increment by one beat.
                    if (ddr4_16gb_arb_write_start_addr != burst_addr) begin
                        burst_addr    = ddr4_16gb_arb_write_start_addr;
                        beat_in_burst = 0;
                    end
                    byte_off = (ddr4_16gb_arb_write_start_addr - frame_base) +
                               (beat_in_burst * (DDR4_16GB_DATA_WIDTH/8));
                    void'($fseek(ddr4_16gb_fd, byte_off, 0));
                    write_beat(ddr4_16gb_fd, ddr4_16gb_arb_write_data, DDR4_16GB_DATA_WIDTH/32);
                    beat_in_burst   = beat_in_burst + 1;
                    ddr4_16gb_beats = ddr4_16gb_beats + 1;
                end
            end
        end
    end

    //--------------------------------------------------------------------------
    // Read fault status
    //--------------------------------------------------------------------------
    task automatic read_fault(input  logic [APB_ADDR_WIDTH-1:0] base_addr,
                              output logic                      fault);
        logic [APB_DATA_WIDTH-1:0] rdata;
        apb_read(base_addr, FAULT_OFFSET, rdata);
        fault = rdata[0];
    endtask

    //--------------------------------------------------------------------------
    // Clear fault
    //--------------------------------------------------------------------------
    task automatic clear_fault(input logic [APB_ADDR_WIDTH-1:0] base_addr);
        apb_write(base_addr, FAULT_CLEAR_OFFSET, 1'b1);
        #10us;
        apb_write(base_addr, FAULT_CLEAR_OFFSET, 1'b0);
    endtask

    //--------------------------------------------------------------------------
    // Check that the write beats captured since a snapshot match the expected
    // routing (whether each DDR4 core should have received data).
    //--------------------------------------------------------------------------
    task automatic check_route(input string tag,
                               input int    before_8gb,
                               input int    before_16gb,
                               input bit    exp_8gb,
                               input bit    exp_16gb);
        int d8, d16;
        bit pass;
        d8   = ddr4_8gb_beats  - before_8gb;
        d16  = ddr4_16gb_beats - before_16gb;
        pass = ((d8 > 0) == exp_8gb) && ((d16 > 0) == exp_16gb);
        if (pass)
            $display("[%0t] %s PASS: 8GB=%0d beats, 16GB=%0d beats",
                     $time, tag, d8, d16);
        else
            $display("[%0t] %s FAIL: 8GB=%0d beats (expected %0s), 16GB=%0d beats (expected %0s)",
                     $time, tag, d8, exp_8gb ? "some" : "none",
                     d16, exp_16gb ? "some" : "none");
    endtask

    //--------------------------------------------------------------------------
    // Pulse the LVDS external trigger
    //--------------------------------------------------------------------------
    task automatic lvds_pulse();
        @(posedge pclk);
        lvds_trig <= 1'b1;
        repeat (4) @(posedge pclk);
        lvds_trig <= 1'b0;
    endtask

    //--------------------------------------------------------------------------
    // Wait for a capture to run to completion (busy asserts then deasserts)
    //--------------------------------------------------------------------------
    task automatic wait_capture();
        logic busy;
        // Wait for the capture to start (busy asserts)
        do begin
            trig_busy(CAM_TRIG_BASE_ADDR, busy);
            #100us;
        end while (!busy);
        // Wait for the capture to complete (busy deasserts)
        do begin
            trig_busy(CAM_TRIG_BASE_ADDR, busy);
            #500us;
        end while (busy);
    endtask

    //--------------------------------------------------------------------------
    // Configure and run one trigger/capture for a given trigger source
    //
    //   XTRIG_SRC_SEL_MANUAL    -> START register write
    //   XTRIG_SRC_SEL_SCHEDULER -> fires when the RTC reaches the scheduled time
    //   XTRIG_SRC_SEL_LVDS      -> LVDS external trigger pulse
    //--------------------------------------------------------------------------
    task automatic run_trigger(input logic [APB_DATA_WIDTH-1:0] src_sel,
                               input logic [APB_DATA_WIDTH-1:0] sched_sec,
                               input logic [APB_DATA_WIDTH-1:0] sched_msec);
        configure_trig(
            CAM_TRIG_BASE_ADDR,
            XTRIG_LOW_TIME_CYCLES,
            FRAME_CAPTURE_TIME_USEC,
            FRAME_CAPTURE_AMOUNT,
            src_sel,
            sched_sec,
            sched_msec);
        repeat (5) @(posedge pclk);
        #100us;

        case (src_sel)
            XTRIG_SRC_SEL_MANUAL: trig_capture(CAM_TRIG_BASE_ADDR);
            XTRIG_SRC_SEL_LVDS:   lvds_pulse();
            default:              /* scheduler fires automatically */;
        endcase

        wait_capture();
        #100us;
    endtask

    //--------------------------------------------------------------------------
    // Stimulus
    //--------------------------------------------------------------------------
    initial begin
        logic busy;
        logic fault;
        int   b8;
        int   b16;
        string prev_8gb_file;
        string prev_16gb_file;
        // Initialize APB and misc inputs
        psel                = 1'b0;
        penable             = 1'b0;
        pwrite              = 1'b0;
        paddr               = '0;
        pwdata              = '0;

        pps_in              = 1'b0;
        lvds_trig           = 1'b0;
        cam_pwr_status      = 1'b0;
        cam_tout            = 1'b0;

        slvs_ec_frame_valid = 1'b0;
        slvs_ec_line_valid  = 1'b0;
        slvs_ec_ebd_valid   = 1'b0;
        slvs_ec_data_out    = '0;

        ddr4_8gb_arb_write_ack  = 1'b0;
        ddr4_8gb_arb_write_done = 1'b0;

        ddr4_16gb_arb_write_ack  = 1'b0;
        ddr4_16gb_arb_write_done = 1'b0;

        // Wait for resets to be released
        wait (presetn && pixel_rst_n && ddr_rst_n);
        repeat (5) @(posedge pclk);

        // Start the free-running PPS input, the SLVS-EC frame generator, and
        // the DDR4 write arbiter models for both cores
        fork
            pps_gen();
            gen_slvs_ec();
            gen_cam_tout();
            ddr4_arb_model(
                ddr4_8gb_arb_write_req,
                ddr4_8gb_arb_write_ack,
                ddr4_8gb_arb_write_burst_len,
                ddr4_8gb_arb_write_valid,
                ddr4_8gb_arb_write_done);
            ddr4_arb_model(
                ddr4_16gb_arb_write_req,
                ddr4_16gb_arb_write_ack,
                ddr4_16gb_arb_write_burst_len,
                ddr4_16gb_arb_write_valid,
                ddr4_16gb_arb_write_done);
        join_none

        // Assert camera power status
        cam_pwr_status = 1'b1;
        repeat (5) @(posedge pclk);

        // Reset DMA write indices for both DDR4 cores and clear camera MUX
        reset_write_index();
        repeat (5) @(posedge pclk);

        // Configure DMA write horizontal line width for both DDR4 cores
        configure_dma_write(DMA_WRITE_DDR4_8GB_BASE_ADDR, HORIZ_WIDTH_BYTE);
        configure_dma_write(DMA_WRITE_DDR4_16GB_BASE_ADDR, HORIZ_WIDTH_BYTE);
        repeat (5) @(posedge pclk);

        // Configure and start PPS
        configure_pps(PPS_BASE_ADDR, PPS_START_TIME, 3, 0);
        pps_start(PPS_BASE_ADDR);
        repeat (5) @(posedge pclk);

        #100us;

        //----------------------------------------------------------------------
        // Scenario 1: Manual trigger (baseline)
        //----------------------------------------------------------------------
        $display("[%0t] SCENARIO 1: Manual Trigger", $time);
        b8 = ddr4_8gb_beats; b16 = ddr4_16gb_beats;
        run_trigger(XTRIG_SRC_SEL_MANUAL, PPS_SCHEDULER_TIME_SEC, PPS_SCHEDULER_TIME_MSEC);
        check_route("SCENARIO 1", b8, b16, 1'b0, 1'b1); // default route: 16GB

        //----------------------------------------------------------------------
        // Scenario 2: Scheduler (PPS) trigger
        //
        // Schedule for a future RTC second so the trigger waits until the RTC
        // counts up to the scheduled time before firing.
        //----------------------------------------------------------------------
        $display("[%0t] SCENARIO 2: PPS/Scheduler Trigger", $time);
        b8 = ddr4_8gb_beats; b16 = ddr4_16gb_beats;
        run_trigger(XTRIG_SRC_SEL_SCHEDULER, PPS_SCHEDULER_TIME_SEC, PPS_SCHEDULER_TIME_MSEC);
        check_route("SCENARIO 2", b8, b16, 1'b0, 1'b1); // default route: 16GB

        //----------------------------------------------------------------------
        // Scenario 3: LVDS external trigger
        //----------------------------------------------------------------------
        $display("[%0t] SCENARIO 3: LVDS Trigger", $time);
        b8 = ddr4_8gb_beats; b16 = ddr4_16gb_beats;
        run_trigger(XTRIG_SRC_SEL_LVDS, PPS_SCHEDULER_TIME_SEC, PPS_SCHEDULER_TIME_MSEC);
        check_route("SCENARIO 3", b8, b16, 1'b0, 1'b1); // default route: 16GB

        //----------------------------------------------------------------------
        // Scenario 4: 16GB full -> route frames to the 8GB DDR4 core
        //
        // Force the MUX to report the 16GB core full and select the 8GB core.
        // The routing is latched at frame start, so force before triggering
        // and release once the capture completes.
        //----------------------------------------------------------------------
        $display("[%0t] SCENARIO 4: Force MUX route to 8GB (16GB full)", $time);
        b8 = ddr4_8gb_beats; b16 = ddr4_16gb_beats;
        force dut.cam_mux_top_inst.cam_mux_inst.ddr4_16gb_full = 1'b1;
        force dut.cam_mux_top_inst.cam_mux_inst.mux_select_reg  = 1'b0; // DDR4_8GB
        run_trigger(XTRIG_SRC_SEL_MANUAL, PPS_SCHEDULER_TIME_SEC, PPS_SCHEDULER_TIME_MSEC);
        release dut.cam_mux_top_inst.cam_mux_inst.ddr4_16gb_full;
        release dut.cam_mux_top_inst.cam_mux_inst.mux_select_reg;
        check_route("SCENARIO 4", b8, b16, 1'b1, 1'b0); // routed to 8GB only
        cam_mux_clear();
        repeat (5) @(posedge pclk);

        //----------------------------------------------------------------------
        // Scenario 5: Both cores full -> drop all frames
        //
        // Force both full flags and disable MUX forwarding so nothing is
        // written to either DDR4 core.
        //----------------------------------------------------------------------
        $display("[%0t] SCENARIO 5: Force MUX to drop all (both full)", $time);
        b8 = ddr4_8gb_beats; b16 = ddr4_16gb_beats;
        force dut.cam_mux_top_inst.cam_mux_inst.ddr4_16gb_full = 1'b1;
        force dut.cam_mux_top_inst.cam_mux_inst.ddr4_8gb_full   = 1'b1;
        force dut.cam_mux_top_inst.cam_mux_inst.mux_enable_reg  = 1'b0;
        run_trigger(XTRIG_SRC_SEL_MANUAL, PPS_SCHEDULER_TIME_SEC, PPS_SCHEDULER_TIME_MSEC);
        release dut.cam_mux_top_inst.cam_mux_inst.ddr4_16gb_full;
        release dut.cam_mux_top_inst.cam_mux_inst.ddr4_8gb_full;
        release dut.cam_mux_top_inst.cam_mux_inst.mux_enable_reg;
        check_route("SCENARIO 5", b8, b16, 1'b0, 1'b0); // dropped: neither core
        cam_mux_clear();
        repeat (5) @(posedge pclk);

        //----------------------------------------------------------------------
        // Scenario 6: Camera timeout fault
        //
        // Disable the frame generator so the DUT never sees frame_valid after
        // a trigger; the fault detector should flag a timeout (TIMEOUT_US=1000).
        //----------------------------------------------------------------------
        $display("[%0t] SCENARIO 6: Camera timeout fault", $time);
        gen_slvs_ec_en = 1'b0;
        configure_trig(
            CAM_TRIG_BASE_ADDR,
            XTRIG_LOW_TIME_CYCLES,
            FRAME_CAPTURE_TIME_USEC,
            FRAME_CAPTURE_AMOUNT,
            XTRIG_SRC_SEL_MANUAL,
            PPS_SCHEDULER_TIME_SEC,
            PPS_SCHEDULER_TIME_MSEC);
        repeat (5) @(posedge pclk);
        trig_capture(CAM_TRIG_BASE_ADDR);
        #1100us; // wait past the 1 ms timeout window
        read_fault(CAM_FAULT_DETECTOR_BASE_ADDR, fault);
        if (fault) $display("[%0t] SCENARIO 6 PASS: Timeout fault asserted", $time);
        else       $display("[%0t] SCENARIO 6 FAIL: Timeout fault not asserted", $time);
        clear_fault(CAM_FAULT_DETECTOR_BASE_ADDR);
        gen_slvs_ec_en = 1'b1;
        repeat (5) @(posedge pclk);

        //----------------------------------------------------------------------
        // Scenario 7: Camera power fault
        //
        // Drop cam_pwr_status while a capture is in progress; the fault
        // detector should flag a power fault. Dropping power also gates the
        // trigger, so restore power afterwards rather than waiting for the
        // capture to finish.
        //----------------------------------------------------------------------
        $display("[%0t] SCENARIO 7: Camera power fault", $time);
        // Snapshot the last-created raw file names so any file produced by the
        // partial frame during this fault scenario can be removed afterwards.
        prev_8gb_file  = ddr4_8gb_last_file;
        prev_16gb_file = ddr4_16gb_last_file;
        configure_trig(
            CAM_TRIG_BASE_ADDR,
            XTRIG_LOW_TIME_CYCLES,
            FRAME_CAPTURE_TIME_USEC,
            FRAME_CAPTURE_AMOUNT,
            XTRIG_SRC_SEL_MANUAL,
            PPS_SCHEDULER_TIME_SEC,
            PPS_SCHEDULER_TIME_MSEC);
        repeat (5) @(posedge pclk);
        trig_capture(CAM_TRIG_BASE_ADDR);
        // Wait for the capture to start (busy asserts)
        do begin
            trig_busy(CAM_TRIG_BASE_ADDR, busy);
            #100us;
        end while (!busy);
        cam_pwr_status = 1'b0; // cut camera power mid-capture
        #500us;
        read_fault(CAM_FAULT_DETECTOR_BASE_ADDR, fault);
        if (fault) $display("[%0t] SCENARIO 7 PASS: Power fault asserted", $time);
        else       $display("[%0t] SCENARIO 7 FAIL: Power fault not asserted", $time);
        cam_pwr_status = 1'b1; // restore camera power
        clear_fault(CAM_FAULT_DETECTOR_BASE_ADDR);
        repeat (5) @(posedge pclk);

        // Remove the partial/faulty raw file(s) created during this scenario.
        if (ddr4_16gb_last_file != prev_16gb_file) begin
            if (ddr4_16gb_fd != 0) begin
                $fclose(ddr4_16gb_fd);
                ddr4_16gb_fd = 0;
            end
            void'($system($sformatf("rm -f %s", ddr4_16gb_last_file)));
            $display("[%0t] SCENARIO 7: removed fault-scenario raw file %s",
                     $time, ddr4_16gb_last_file);
        end
        if (ddr4_8gb_last_file != prev_8gb_file) begin
            if (ddr4_8gb_fd != 0) begin
                $fclose(ddr4_8gb_fd);
                ddr4_8gb_fd = 0;
            end
            void'($system($sformatf("rm -f %s", ddr4_8gb_last_file)));
            $display("[%0t] SCENARIO 7: removed fault-scenario raw file %s",
                     $time, ddr4_8gb_last_file);
        end

        #100us;

        // Close any open raw capture files
        if (ddr4_8gb_fd  != 0) $fclose(ddr4_8gb_fd);
        if (ddr4_16gb_fd != 0) $fclose(ddr4_16gb_fd);

        // Finish simulation and flush the VCD file
        $finish;
    end

    //--------------------------------------------------------------------------
    // VCD dump
    //--------------------------------------------------------------------------
    initial begin
        $dumpfile("slvs_ec_to_write_ddr_tb.vcd");
        $dumpvars(0, slvs_ec_to_write_ddr_tb);
    end

endmodule