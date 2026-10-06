/*
 * @file      image_metadata_apb_reg.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      01/14/2026
 *
 * @brief
 *
 * @section changelog
 * - 01/14/2026: Steven Knyazher - Initial implementation
 * - 02/02/2026: Saba Janamian - Updated to support new reformated Metadata
 * - 08/18/2026: Steven Knyazher - Added cam_tout CDC sync and exposure time
 *                                 measurement from the cam_tout low duration,
 *                                 and CDC sync for the DDR4 frame index buses,
 *                                 which come from the ddr_clk domain
 *
 */

module image_metadata_apb_reg #(
    parameter integer APB_DATA_WIDTH              = 32,
    parameter integer APB_ADDR_WIDTH              = 32,
    parameter integer METADATA_WIDTH              = 640,
    parameter integer CLOCK_FREQ_MHZ              = 50,
    parameter integer EXPO_TIME_WIDTH             = 22,
    parameter integer FRAME_CAPTURE_TIME_WIDTH    = 24,
    parameter integer FRAME_CAPTURE_AMOUNT_WIDTH  = 10,
    parameter integer DDR4_8GB_FRAME_INDEX_WIDTH  = 8,
    parameter integer DDR4_16GB_FRAME_INDEX_WIDTH = 9
)(
    // APB Slave interface
    input  logic                                  pclk,     // APB clock
    input  logic                                  presetn,  // APB resetn
    input  logic                                  penable,  // APB enable
    input  logic                                  psel,     // APB periph select
    input  logic [APB_ADDR_WIDTH-1:0]             paddr,    // APB address bus
    input  logic                                  pwrite,   // APB write req
    input  logic [APB_DATA_WIDTH-1:0]             pwdata,   // APB write data
    output logic [APB_DATA_WIDTH-1:0]             prdata,   // APB read data
    output logic                                  pready,   // APB ready signal
    output logic                                  pslverr,  // APB error signal

    // Timestamp
    input logic [31:0]                            timestamp_sec,
    input logic [31:0]                            timestamp_nsec,

    // Trigger info
    input  logic [1:0]                            trig_mode,
    input  logic                                  cam_tout,
    input  logic [FRAME_CAPTURE_TIME_WIDTH-1:0]   frame_capture_time,
    input  logic [FRAME_CAPTURE_AMOUNT_WIDTH-1:0] frame_capture_amount,

    // DDR4 buffer space index
    input logic                                   cam_mux_select,
    input logic [DDR4_8GB_FRAME_INDEX_WIDTH-1:0]  ddr4_8gb_frame_index,
    input logic [DDR4_16GB_FRAME_INDEX_WIDTH-1:0] ddr4_16gb_frame_index,

    // Exposure time measurement status
    output logic                                  expo_time_valid,

    // Metadata
    output logic [METADATA_WIDTH-1:0]             metadata_out // Data out
);


//------------------------------------------------------------------------------
// Local parameters
//------------------------------------------------------------------------------
localparam logic CAM_MUX_SEL_DDR4_8GB         = 1'b0;
localparam logic CAM_MUX_SEL_DDR4_16GB        = 1'b1;
localparam logic [23:0] DDR4_8GB_ADDR_OFFSET  = {22'b0, 2'b10};
localparam logic [22:0] DDR4_16GB_ADDR_OFFSET = {22'b0, 1'b0};
localparam logic [31:0] METADATA_START_FLAG   = 32'h4D455441; // ASCII META
localparam logic [31:0] METADATA_SIZE_BYTES   = 20 * 4; // 80B

// Exposure time measurement (cam_tout low duration)
localparam integer CYCLES_PER_US      = CLOCK_FREQ_MHZ;
localparam integer HALF_CYCLES_PER_US = CYCLES_PER_US / 2;
localparam integer SUB_US_CNT_WIDTH   = (CYCLES_PER_US > 1) ? $clog2(CYCLES_PER_US) : 1;

//------------------------------------------------------------------------------
// Register address definitions
//------------------------------------------------------------------------------

localparam integer ADDR_METADATA_START_FLAG_REG       = 32'h0;  // RO Flag indicating start of Metadata
localparam integer ADDR_METADATA_SIZE_BYTES_REG       = 32'h1;  // RO Total number of bytes in metadata excluding flag
localparam integer ADDR_SENSOR_PXL_READOUT_FORMAT_REG = 32'h2;  // RW Sensor frame output format (updated by firmware)
localparam integer ADDR_SENSOR_READ_DIR_REG           = 32'h3;  // RW Sensor readout direction (updated by firmware)
localparam integer ADDR_SENSOR_BIT_DEPTH_REG          = 32'h4;  // RO Sensor image bit-depth (fix to 0 to indicate 12-bits width)
localparam integer ADDR_SENSOR_GAIN_REG               = 32'h5;  // RW Sensor gain in dB(x10) (updated by firmware)
localparam integer ADDR_SENSOR_BLO_REG                = 32'h6;  // RW Black level offset value (updated by firmware)
localparam integer ADDR_SENSOR_EXPO_USEC_REG          = 32'h7;  // RO Exposure time in microseconds (updated by FPGA)
localparam integer ADDR_SENSOR_TRIG_MODE_REG          = 32'h8;  // RO Image trigger mode configuration (updated by FPGA)
localparam integer ADDR_SENSOR_TEMP_RAW_REG           = 32'h9;  // RW Raw sensor temperature reading (updated by firmware)
localparam integer ADDR_BUFF_WRITE_INDEX_REG          = 32'hA;  // RO DDR4 frame buffer write pointer index (updated by FPGA)
localparam integer ADDR_FOCUS_REQ_DIST_M_REG          = 32'hB;  // RW Requested focus distance (updated by firmware)
localparam integer ADDR_FOCUS_COMP_DIST_M_REG         = 32'hC;  // RW Computed focus distance from LVDT (updated by firmware)
localparam integer ADDR_FOCUS_LVDT_POS_NM_REG         = 32'hD;  // RW LVDT sensor position in nanometers (updated by firmware)
localparam integer ADDR_TIMESTAMP_UNIX_EPOCH_SEC_REG  = 32'hE;  // RO Unix epoch timestamp in seconds (updated by FPGA)
localparam integer ADDR_TIMESTAMP_SUBSEC_NSEC_REG     = 32'hF;  // RO Sub-second timestamp in nanoseconds (updated by FPGA)
localparam integer ADDR_VERSION_REG                   = 32'h10; // RW Subsystem version info
localparam integer ADDR_RESERVED_PADDING0_REG         = 32'h11; // RO Fixed to 0
localparam integer ADDR_RESERVED_PADDING1_REG         = 32'h12; // RO Fixed to 0
localparam integer ADDR_METADATA_CRC32_REG            = 32'h13; // RO CRC32 of all registers except the flag (updated by FPGA)

localparam integer NUM_REGS = 32;  // Can only be 8, 16, 32

//------------------------------------------------------------------------------
// Register space
//------------------------------------------------------------------------------
logic [APB_DATA_WIDTH-1:0] mem[NUM_REGS];

//------------------------------------------------------------------------------
// CRC32 computation (IEEE 802.3, polynomial 0x04C11DB7, reflected)
//------------------------------------------------------------------------------

// CRC32 over a single byte (reflected algorithm using 0xEDB88320)
function automatic logic [31:0] crc32_byte(
    input logic [31:0] crc_in,
    input logic [7:0]  data_byte
);
    logic [31:0] crc;
    crc = crc_in ^ {24'b0, data_byte};
    for (integer i = 0; i < 8; i++) begin
        if (crc[0])
            crc = (crc >> 1) ^ 32'hEDB88320;
        else
            crc = crc >> 1;
    end
    return crc;
endfunction

// CRC32 over a 32-bit word (little-endian byte order)
function automatic logic [31:0] crc32_word(
    input logic [31:0] crc_in,
    input logic [31:0] data_word
);
    logic [31:0] crc;
    crc = crc32_byte(crc_in, data_word[7:0]);
    crc = crc32_byte(crc,    data_word[15:8]);
    crc = crc32_byte(crc,    data_word[23:16]);
    crc = crc32_byte(crc,    data_word[31:24]);
    return crc;
endfunction

// Combinational CRC32 over registers 0x1 to 0x12 (excludes flag and CRC)
logic [31:0] crc32_result;
always_comb begin
    logic [31:0] crc;
    crc = 32'hFFFFFFFF;
    for (integer i = ADDR_METADATA_SIZE_BYTES_REG; i <= ADDR_RESERVED_PADDING1_REG; i++) begin
        crc = crc32_word(crc, mem[i]);
    end
    crc32_result = crc ^ 32'hFFFFFFFF;
end

//------------------------------------------------------------------------------
// CDC Sync
//------------------------------------------------------------------------------
logic [1:0]                             cam_mux_select_sync;
logic [DDR4_8GB_FRAME_INDEX_WIDTH-1:0]  ddr4_8gb_frame_index_sync[2];
logic [DDR4_16GB_FRAME_INDEX_WIDTH-1:0] ddr4_16gb_frame_index_sync[2];

// cam_tout comes from an external (asynchronous) source. cam_tout_sync[1] is the
// synchronized value, cam_tout_sync[2] is a delayed copy used for edge detection.
logic [2:0] cam_tout_sync;
logic       cam_tout_low;
logic       cam_tout_rise;
logic       cam_tout_fall;

assign cam_tout_low  = ~cam_tout_sync[1];
assign cam_tout_rise = cam_tout_sync[1] & ~cam_tout_sync[2];
assign cam_tout_fall = ~cam_tout_sync[1] & cam_tout_sync[2];

//------------------------------------------------------------------------------
// Exposure time measurement
//------------------------------------------------------------------------------
logic [SUB_US_CNT_WIDTH-1:0] sub_us_cnt;
logic [EXPO_TIME_WIDTH-1:0]  expo_us_cnt;
logic [EXPO_TIME_WIDTH-1:0]  expo_time;

always_ff @(posedge pclk or negedge presetn) begin
    if(~presetn) begin
        cam_tout_sync   <= '1; // cam_tout idles high
        sub_us_cnt      <= 'b0;
        expo_us_cnt     <= 'b0;
        expo_time       <= 'b0;
        expo_time_valid <= 1'b0;
    end else begin
        cam_tout_sync <= {cam_tout_sync[1:0], cam_tout};

        if (cam_tout_low) begin
            if (sub_us_cnt == (CYCLES_PER_US - 1)) begin
                sub_us_cnt <= 'b0;
                if (~&expo_us_cnt) begin
                    expo_us_cnt <= expo_us_cnt + 1'b1;
                end
            end else begin
                sub_us_cnt <= sub_us_cnt + 1'b1;
            end
        end else begin
            sub_us_cnt  <= 'b0;
            expo_us_cnt <= 'b0;
        end

        // Round to nearest microsecond and latch at the end of the low period
        if (cam_tout_rise) begin
            expo_time <= ((sub_us_cnt >= HALF_CYCLES_PER_US) && (~&expo_us_cnt)) ?
                         expo_us_cnt + 1'b1 : expo_us_cnt;
        end

        // expo_time_valid drops as soon as a new exposure starts and is raised
        // again once the measurement for that exposure has been latched.
        if (cam_tout_fall) begin
            expo_time_valid <= 1'b0;
        end else if (cam_tout_rise) begin
            expo_time_valid <= 1'b1;
        end
    end
end

//------------------------------------------------------------------------------
// APB write and read register logic
//------------------------------------------------------------------------------
always_ff @(posedge pclk or negedge presetn) begin
    if(~presetn) begin
        prdata                     <= 'b0;
        pready                     <= 'b0;
        pslverr                    <= 'b0;
        mem                        <= '{default: 1'b0};
        cam_mux_select_sync        <= 'b0;
        ddr4_8gb_frame_index_sync  <= '{default: 1'b0};
        ddr4_16gb_frame_index_sync <= '{default: 1'b0};

    end else begin

        pslverr <= 'b0; // Not used

        // Hardware-driven RO register assignments
        mem[ADDR_METADATA_START_FLAG_REG]      <= METADATA_START_FLAG;
        mem[ADDR_METADATA_SIZE_BYTES_REG]      <= METADATA_SIZE_BYTES;
        mem[ADDR_SENSOR_TRIG_MODE_REG]         <= trig_mode;
        mem[ADDR_RESERVED_PADDING0_REG]        <= 'b0;
        mem[ADDR_RESERVED_PADDING1_REG]        <= 'b0;
        mem[ADDR_METADATA_CRC32_REG]           <= crc32_result;

        mem[ADDR_SENSOR_EXPO_USEC_REG]         <= {
            {(APB_DATA_WIDTH-EXPO_TIME_WIDTH){1'b0}}, expo_time};

        mem[ADDR_TIMESTAMP_UNIX_EPOCH_SEC_REG] <= timestamp_sec;
        mem[ADDR_TIMESTAMP_SUBSEC_NSEC_REG]    <= timestamp_nsec;

        cam_mux_select_sync           <= {cam_mux_select_sync[0], cam_mux_select};
        
        ddr4_8gb_frame_index_sync[0]  <= ddr4_8gb_frame_index;
        ddr4_8gb_frame_index_sync[1]  <= ddr4_8gb_frame_index_sync[0];

        ddr4_16gb_frame_index_sync[0] <= ddr4_16gb_frame_index;
        ddr4_16gb_frame_index_sync[1] <= ddr4_16gb_frame_index_sync[0];

        if (cam_mux_select_sync[1] == CAM_MUX_SEL_DDR4_8GB) begin
            mem[ADDR_BUFF_WRITE_INDEX_REG]   <= (ddr4_8gb_frame_index_sync[1] == {DDR4_8GB_FRAME_INDEX_WIDTH{1'b1}}) ?
                                                {DDR4_8GB_ADDR_OFFSET, {DDR4_8GB_FRAME_INDEX_WIDTH{1'b0}}} :
                                                {DDR4_8GB_ADDR_OFFSET, ddr4_8gb_frame_index_sync[1] + 1'b1};
        end else begin
            mem[ADDR_BUFF_WRITE_INDEX_REG]   <= (ddr4_16gb_frame_index_sync[1] == {DDR4_16GB_FRAME_INDEX_WIDTH{1'b1}}) ?
                                                {DDR4_16GB_ADDR_OFFSET, {DDR4_16GB_FRAME_INDEX_WIDTH{1'b0}}} :
                                                {DDR4_16GB_ADDR_OFFSET, ddr4_16gb_frame_index_sync[1] + 1'b1};
        end

        // APB Write operation (RW registers only)
        if(psel && penable && pwrite && paddr[1:0] == 'b0) begin
            prdata  <= 'b0;
            pready  <= 'b1;  // Indicate done

            case(paddr[6:2])

                ADDR_SENSOR_PXL_READOUT_FORMAT_REG: begin
                    mem[ADDR_SENSOR_PXL_READOUT_FORMAT_REG] <= pwdata;
                end

                ADDR_SENSOR_READ_DIR_REG: begin
                    mem[ADDR_SENSOR_READ_DIR_REG] <= pwdata;
                end

                ADDR_SENSOR_BIT_DEPTH_REG: begin
                    mem[ADDR_SENSOR_BIT_DEPTH_REG] <= pwdata;
                end

                ADDR_SENSOR_GAIN_REG: begin
                    mem[ADDR_SENSOR_GAIN_REG] <= pwdata;
                end

                ADDR_SENSOR_BLO_REG: begin
                    mem[ADDR_SENSOR_BLO_REG] <= pwdata;
                end

                ADDR_SENSOR_TEMP_RAW_REG: begin
                    mem[ADDR_SENSOR_TEMP_RAW_REG] <= pwdata;
                end

                ADDR_FOCUS_REQ_DIST_M_REG: begin
                    mem[ADDR_FOCUS_REQ_DIST_M_REG] <= pwdata;
                end

                ADDR_FOCUS_COMP_DIST_M_REG: begin
                    mem[ADDR_FOCUS_COMP_DIST_M_REG] <= pwdata;
                end

                ADDR_FOCUS_LVDT_POS_NM_REG: begin
                    mem[ADDR_FOCUS_LVDT_POS_NM_REG] <= pwdata;
                end

                ADDR_VERSION_REG: begin
                    mem[ADDR_VERSION_REG] <= pwdata;
                end

                default: begin
                    pslverr <= 'b0;
                end
            endcase

        // APB READ operation (all registers readable)
        end else if(psel && penable && !pwrite && paddr[1:0] == 'b0) begin
            pready  <= 'b1; // Indicate done

            case(paddr[6:2])
                ADDR_METADATA_START_FLAG_REG: begin
                    prdata <= mem[ADDR_METADATA_START_FLAG_REG];
                end

                ADDR_METADATA_SIZE_BYTES_REG: begin
                    prdata <= mem[ADDR_METADATA_SIZE_BYTES_REG];
                end

                ADDR_SENSOR_PXL_READOUT_FORMAT_REG: begin
                    prdata <= mem[ADDR_SENSOR_PXL_READOUT_FORMAT_REG];
                end

                ADDR_SENSOR_READ_DIR_REG: begin
                    prdata <= mem[ADDR_SENSOR_READ_DIR_REG];
                end

                ADDR_SENSOR_BIT_DEPTH_REG: begin
                    prdata <= mem[ADDR_SENSOR_BIT_DEPTH_REG];
                end

                ADDR_SENSOR_GAIN_REG: begin
                    prdata <= mem[ADDR_SENSOR_GAIN_REG];
                end

                ADDR_SENSOR_BLO_REG: begin
                    prdata <= mem[ADDR_SENSOR_BLO_REG];
                end

                ADDR_SENSOR_EXPO_USEC_REG: begin
                    prdata <= mem[ADDR_SENSOR_EXPO_USEC_REG];
                end

                ADDR_SENSOR_TRIG_MODE_REG: begin
                    prdata <= mem[ADDR_SENSOR_TRIG_MODE_REG];
                end

                ADDR_SENSOR_TEMP_RAW_REG: begin
                    prdata <= mem[ADDR_SENSOR_TEMP_RAW_REG];
                end

                ADDR_BUFF_WRITE_INDEX_REG: begin
                    prdata <= mem[ADDR_BUFF_WRITE_INDEX_REG];
                end

                ADDR_FOCUS_REQ_DIST_M_REG: begin
                    prdata <= mem[ADDR_FOCUS_REQ_DIST_M_REG];
                end

                ADDR_FOCUS_COMP_DIST_M_REG: begin
                    prdata <= mem[ADDR_FOCUS_COMP_DIST_M_REG];
                end

                ADDR_FOCUS_LVDT_POS_NM_REG: begin
                    prdata <= mem[ADDR_FOCUS_LVDT_POS_NM_REG];
                end

                ADDR_TIMESTAMP_UNIX_EPOCH_SEC_REG: begin
                    prdata <= mem[ADDR_TIMESTAMP_UNIX_EPOCH_SEC_REG];
                end

                ADDR_TIMESTAMP_SUBSEC_NSEC_REG: begin
                    prdata <= mem[ADDR_TIMESTAMP_SUBSEC_NSEC_REG];
                end

                ADDR_VERSION_REG: begin
                    prdata <= mem[ADDR_VERSION_REG];
                end

                ADDR_RESERVED_PADDING0_REG: begin
                    prdata <= mem[ADDR_RESERVED_PADDING0_REG];
                end

                ADDR_RESERVED_PADDING1_REG: begin
                    prdata <= mem[ADDR_RESERVED_PADDING1_REG];
                end

                ADDR_METADATA_CRC32_REG: begin
                    prdata <= mem[ADDR_METADATA_CRC32_REG];
                end

                default: begin
                    pslverr <= 'b0;
                    prdata  <= 'hdeadbeef;
                end
            endcase

        end else begin
            pready          <= 'b0;
            prdata          <= 'b0;
            pslverr         <= 'b0;
        end
    end
end

//------------------------------------------------------------------------------
// Metadata vector update
//------------------------------------------------------------------------------
always_ff @(posedge pclk or negedge presetn) begin
    if(~presetn) begin
        metadata_out <= '{default: 1'b0};
    end else begin
        metadata_out <= {mem[19], mem[18], mem[17], mem[16],
                         mem[15], mem[14], mem[13], mem[12],
                         mem[11], mem[10], mem[9],  mem[8],
                         mem[7],  mem[6],  mem[5],  mem[4],
                         mem[3],  mem[2],  mem[1],  mem[0]
                        };
    end
end

endmodule