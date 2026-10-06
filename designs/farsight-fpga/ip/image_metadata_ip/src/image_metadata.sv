/*
 * @file      image_metadata.sv
 * @copyright Copyright (c) 2026 Turion Space. All rights reserved.
 * @author    Steven Knyazher (sknyazher@turionspace.com)
 * @date      01/14/2026
 *
 * @brief     Send image metadata when rising edge of frame valid is detected
 *
 * @section changelog
 * - 01/14/2026: Steven Knyazher - Initial implementation
 * - 02/03/2026: Saba Janamian - Updated the FSM
 * - 08/18/2026: Steven Knyazher - Wait for expo_time_valid before latching
 *                                 metadata so the exposure time reported
 *                                 belongs to the frame being sent, and only
 *                                 insert the metadata once per frame
 *
 */

module image_metadata #(
    parameter integer CAM_DATA_WIDTH     = 384,
    parameter integer METADATA_WIDTH     = 640
)(
    // Input APB clock
    input  logic                              pclk,        // APB clock
    input  logic                              presetn,     // APB resetn

    // Input Pixel clock
    input  logic                              pixel_clk,   // SLVSEC clock
    input  logic                              pixel_rst_n, // SLVSEC resetn

    // Metadata from APB registers
    input  logic [METADATA_WIDTH-1:0]         metadata_in,

    // Exposure time measurement status
    input  logic                              expo_time_valid,

    // Cam input
    input  logic                              frame_valid_in,
    input  logic                              line_valid_in,
    input  logic [CAM_DATA_WIDTH-1:0]         cam_data_in,

    // Cam output
    output logic                              frame_valid_out,
    output logic                              line_valid_out,
    output logic [CAM_DATA_WIDTH-1:0]         cam_data_out
);

//------------------------------------------------------------------------------
// Local parameters
//------------------------------------------------------------------------------
localparam logic   MUX_SEL_CAM_DATAOUT      = 1'b0;
localparam logic   MUX_SEL_METADATA_OUT     = 1'b1;
localparam integer TIMEOUT_DELAY_CLK_CYCLE  = 100;
// CDC timing: ~120ns minimum for write request to cross to pclk domain,
// complete the FIFO write, and data to appear on read side.
// At 12.626ns pixel_clk period, need at least 10 cycles. Using 15 cycles to be
// safe.
localparam integer FIFO_SYNC_WAIT_CLK_CYCLE = 15;

// Metadata chunking parameters
// Chunk 0: First CAM_DATA_WIDTH bits of metadata
// Chunk 1: Remaining (METADATA_WIDTH - CAM_DATA_WIDTH) bits, zero-padded
localparam integer CHUNK1_DATA_WIDTH = METADATA_WIDTH - CAM_DATA_WIDTH;
localparam integer CHUNK1_PAD_WIDTH  = CAM_DATA_WIDTH - CHUNK1_DATA_WIDTH;
//------------------------------------------------------------------------------
// FSM states
//------------------------------------------------------------------------------
typedef enum logic [2:0] {
    IDLE                 = 'd0,
    PULL_METADATA        = 'd1,
    POP_CDC_FIFO         = 'd2,
    READ_METADATA        = 'd3,
    SEND_METADATA_CHUNK0 = 'd4,
    SEND_METADATA_CHUNK1 = 'd5
} state_t;

state_t curr_state;
state_t next_state;

//------------------------------------------------------------------------------
// Internal signals
//------------------------------------------------------------------------------
logic [CAM_DATA_WIDTH-1:0] metadata_out;
logic [METADATA_WIDTH-1:0] metadata_cdc;
logic                      metadata_valid;

logic                      frame_valid_prev;
logic                      frame_valid_curr;
logic                      frame_valid_rising_edge;
logic                      frame_valid_falling_edge;

logic                      write_en_req_cdc;
logic [1:0]                write_en_req_curr;
logic                      write_en_req_prev;

logic [1:0]                expo_time_valid_sync;

logic                      metadata_sent;

logic                      fifo_write_en;
logic [3:0]                fifo_write_wait_counter;
logic                      fifo_read_en;
logic                      fifo_read_valid;
logic                      fifo_empty;
logic                      sel_mux;

logic [31:0]               timout_counter;
logic                      has_timeout_err;

//------------------------------------------------------------------------------
// Continuous signals
//------------------------------------------------------------------------------
assign frame_valid_out = frame_valid_in;
assign line_valid_out  = sel_mux ? metadata_valid : line_valid_in;
assign cam_data_out    = sel_mux ? metadata_out   : cam_data_in;

//------------------------------------------------------------------------------
// Edge detectors
//------------------------------------------------------------------------------
// Pixel Clock Domain
always_ff @(posedge pixel_clk, negedge pixel_rst_n) begin
    if (~pixel_rst_n) begin
        frame_valid_prev         <= 1'b0;
        frame_valid_curr         <= 1'b0;
        frame_valid_rising_edge  <= 1'b0;
        frame_valid_falling_edge <= 1'b0;
    end else begin
        frame_valid_prev         <= frame_valid_curr;
        frame_valid_curr         <= frame_valid_in;
        frame_valid_rising_edge  <= (frame_valid_curr) && (~frame_valid_prev);
        frame_valid_falling_edge <= (~frame_valid_curr) && (frame_valid_prev);
    end
end

// APB Clock Domain
always_ff @(posedge pclk, negedge presetn) begin
    if (~presetn) begin
        fifo_write_en      <= 1'b0;
        write_en_req_curr  <= 2'b0;
        write_en_req_prev  <= 1'b0;
    end else begin
        write_en_req_curr  <= {write_en_req_curr[0], write_en_req_cdc};
        write_en_req_prev  <= write_en_req_curr[1];
        fifo_write_en      <= write_en_req_curr[1] && (~write_en_req_prev);
    end
end

//------------------------------------------------------------------------------
// CDC Sync
//------------------------------------------------------------------------------
always_ff @(posedge pixel_clk, negedge pixel_rst_n) begin
    if (~pixel_rst_n) begin
        expo_time_valid_sync <= 2'b0;
    end else begin
        expo_time_valid_sync <= {expo_time_valid_sync[0], expo_time_valid};
    end
end

//------------------------------------------------------------------------------
// FSM
//------------------------------------------------------------------------------

always_ff @(posedge pixel_clk, negedge pixel_rst_n) begin
    if (~pixel_rst_n) begin
        curr_state                <= IDLE;
        write_en_req_cdc          <= 1'b0;
        fifo_write_wait_counter   <= 'b0;
        fifo_read_en              <= 1'b0;
        metadata_valid            <= 1'b0;
        metadata_out              <= 1'b0;
        metadata_sent             <= 1'b1;
        sel_mux                   <= MUX_SEL_CAM_DATAOUT;
        timout_counter            <= 'b0;
        has_timeout_err           <= 1'b0;

    end else begin

        curr_state <= next_state;

        if (curr_state == IDLE) begin
            write_en_req_cdc         <= 1'b0;
            fifo_write_wait_counter  <= 'b0;
            fifo_read_en             <= 1'b0;
            metadata_valid           <= 1'b0;
            metadata_out             <= 1'b0;
            sel_mux                  <= MUX_SEL_CAM_DATAOUT;
            timout_counter           <= 'b0;
            has_timeout_err          <= 1'b0;

            if (frame_valid_rising_edge) begin
                metadata_sent <= 1'b0;
            end

        end else if (curr_state == PULL_METADATA) begin
            write_en_req_cdc         <= 1'b1; // Set
            fifo_write_wait_counter  <= fifo_write_wait_counter + 1; // Incr
            fifo_read_en             <= 1'b0;
            metadata_valid           <= 1'b0;
            metadata_out             <= 1'b0;
            sel_mux                  <= MUX_SEL_CAM_DATAOUT;
            timout_counter           <= 'b0;
            has_timeout_err          <= 1'b0;

        end else if (curr_state == POP_CDC_FIFO) begin
            write_en_req_cdc         <= 1'b0; // Reset
            fifo_write_wait_counter  <= 'b0;  // Reset back to 0
            fifo_read_en             <= 1'b1; // Set
            metadata_valid           <= 1'b0;
            metadata_out             <= 1'b0;
            sel_mux                  <= MUX_SEL_CAM_DATAOUT;
            timout_counter           <= 'b0;
            has_timeout_err          <= 1'b0;

        end else if (curr_state == READ_METADATA) begin
            write_en_req_cdc         <= 1'b0;
            fifo_write_wait_counter  <= 'b0;
            fifo_read_en             <= 1'b0; // Reset - read was initiated in POP_CDC_FIFO
            metadata_valid           <= 1'b0;
            metadata_out             <= 1'b0;
            sel_mux                  <= MUX_SEL_CAM_DATAOUT;
            timout_counter           <= timout_counter + 1;

            if (timout_counter >= TIMEOUT_DELAY_CLK_CYCLE) begin
                has_timeout_err      <= 1'b1;
            end else begin
                has_timeout_err      <= 1'b0;
            end

        end else if (curr_state == SEND_METADATA_CHUNK0) begin
            write_en_req_cdc         <= 1'b0;
            fifo_write_wait_counter  <= 'b0;
            fifo_read_en             <= 1'b0; // Reset
            metadata_valid           <= 1'b1; // Set
            
            if (has_timeout_err) begin
                metadata_out         <= '1; // All F for failure
            end else begin
                metadata_out         <= metadata_cdc[0 +: CAM_DATA_WIDTH]; // Chunk 0
            end
            
            sel_mux                  <= MUX_SEL_METADATA_OUT; // Set
            timout_counter           <= 'b0;
            has_timeout_err          <= has_timeout_err; // Keep

        end else if (curr_state == SEND_METADATA_CHUNK1) begin
            write_en_req_cdc         <= 1'b0;
            fifo_write_wait_counter  <= 'b0;
            fifo_read_en             <= 1'b0;
            metadata_valid           <= 1'b1; // Keep
            metadata_sent            <= 1'b1;
            
            if (has_timeout_err) begin
                metadata_out         <= '1; // All F for failure
            end else begin
                metadata_out         <= {
                    {CHUNK1_PAD_WIDTH{1'b0}}, 
                    metadata_cdc[CAM_DATA_WIDTH +: CHUNK1_DATA_WIDTH]}; // Chunk 1
            end

            sel_mux                  <= MUX_SEL_METADATA_OUT; // Keep
            timout_counter           <= 'b0;
            has_timeout_err          <= has_timeout_err; // Keep

        end else begin
            write_en_req_cdc         <= 1'b0;
            fifo_write_wait_counter  <= 'b0;
            fifo_read_en             <= 1'b0;
            metadata_valid           <= 1'b0;
            metadata_out             <= 1'b0;
            metadata_sent            <= 1'b1;
            sel_mux                  <= MUX_SEL_CAM_DATAOUT;
            timout_counter           <= 'b0;
            has_timeout_err          <= 1'b0;

        end
    end
end

always_comb begin
    next_state = curr_state;

    case(curr_state)

        IDLE: begin
            if (expo_time_valid_sync[1] && ~metadata_sent) begin
                next_state = PULL_METADATA;
            end else begin
                next_state = IDLE;
            end
        end

        PULL_METADATA: begin
            if (fifo_write_wait_counter >= FIFO_SYNC_WAIT_CLK_CYCLE) begin
                next_state = POP_CDC_FIFO;
            end else begin
                next_state = PULL_METADATA;
            end
        end

        POP_CDC_FIFO: begin
            next_state = READ_METADATA;
        end


        READ_METADATA: begin
            if (fifo_read_valid && fifo_empty) begin
                next_state = SEND_METADATA_CHUNK0;
            end else if (timout_counter >= TIMEOUT_DELAY_CLK_CYCLE) begin
                next_state = IDLE;
            end else begin
                next_state = READ_METADATA;
            end
        end

        SEND_METADATA_CHUNK0: begin
            next_state = SEND_METADATA_CHUNK1;
        end

        SEND_METADATA_CHUNK1: begin
            next_state = IDLE;
        end

        default: begin
            next_state = IDLE;
        end

    endcase
end

//------------------------------------------------------------------------------
// FIFO instance
//------------------------------------------------------------------------------
COREFIFO_METADATA_CDC corefifo_metadata_cdc_inst(
    // FIFO Write interface
    .WCLOCK                  (pclk           ),
    .WRESET_N                (presetn        ),
    .WE                      (fifo_write_en  ),
    .DATA                    (metadata_in    ),
    // FIFO Read interface
    .RCLOCK                  (pixel_clk      ),
    .RRESET_N                (pixel_rst_n    ),
    .RE                      (fifo_read_en   ),
    .DVLD                    (fifo_read_valid),
    .Q                       (metadata_cdc   ),
    .EMPTY                   (fifo_empty     ),
    .FULL                    (/* NC */       )
);

endmodule