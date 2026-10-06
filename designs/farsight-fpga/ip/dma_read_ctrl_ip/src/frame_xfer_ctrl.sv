/*
 * @file      frame_xfer_ctrl.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      10/01/2025
 *
 * @brief     This module is the engine for requesting a full image frame from
 *            the DMA read. It waits for the frame_read_req from the RISCV SW.
 *            Then it will request 1 line at a time from the DMA and waits until
 *            the line has been read by the consumer of the data (in this case)
 *            the UDP packetizer. It will continue requesting lines until all
 *            lines specified by the v_size_line has been specified. The line
 *            size is specified by the h_size_beat which is the number of burst
 *            beats to get the entire line of a frame. After reading the total
 *            number of requested beats the address of the next line will be
 *            increamented based on the provided h_size_byte.
 *            NOTE: h_size_beat * DDR_DATA_WIDTH must be divisible by 4
 *
 *
 * @section changelog
 * - 10/01/2025: Saba Janamian - Initial implementation
 *
 */

module frame_xfer_ctrl #(
    parameter integer CLOCK_FREQ_MHZ    = 100,
    parameter integer TIMEOUT_USEC      = 10_000, // 10 mSec
    parameter integer DDR_ADDR_WIDTH    = 38,
    parameter integer DDR_DATA_WIDTH    = 256,
    parameter integer FRAME_WIDTH       = 25,  // 25 bits of addr to store frame data
    parameter integer USABLE_ADDR_WIDTH = 33,  // 2^30 * 2^3 = 8GB
    parameter integer FRAME_INDEX_WIDTH = USABLE_ADDR_WIDTH - FRAME_WIDTH, // 8
    parameter integer METADATA_WIDTH    = 640  // bits
)(
    input  logic                         clk,
    input  logic                         rst_n,

    // APB and RSICV interface
    input  logic                         clear, // CDC
    input  logic                         frame_read_req, // Req read (CDC)
    output logic                         frame_read_done, // Ack frame read
    input  logic                         udp_metadata_sel, // 0=UDP image, 1=metadata (CDC)
    input  logic [8:0]                   h_size_beat, // Can't be >511 (CDC)
    input  logic [13:0]                  h_size_byte, // CDC (a.k.a LINE_GAP)
    input  logic [12:0]                  v_size_line, // Can't be >8192 (CDC)
    input  logic [FRAME_INDEX_WIDTH-1:0] frame_index, // Index of frame (CDC)
    output logic [31:0]                  timeout_err,

    // DMA Contrller interface
    output logic                         dma_ctrl_read_req, // Req line read to DMA
    input  logic                         dma_ctrl_read_ack, // (CDC)
    input  logic                         dma_ctrl_read_done, // (CDC)
    output logic [13:0]                  dma_ctrl_pyl_size_word, // Number of 32 bits
    output logic [15:0]                  dma_ctrl_line_index, // Current line index

    // DMA read interface
    input  logic                         dma_ready, // (CDC)
    output logic                         ctrl_info_valid,
    output logic [DDR_ADDR_WIDTH-1:0]    ctrl_read_addr, // Line read Addr
    output logic [8:0]                   ctrl_burst_count, // Num of chunks to read
    output logic                         dma_fifo_clear
);

//------------------------------------------------------------------------------
// Local parameters
//------------------------------------------------------------------------------
localparam MAX_TIMEOUT       = CLOCK_FREQ_MHZ * TIMEOUT_USEC;
localparam MAX_BURST_SIZE    = 256; // MAX 256 Beats for single AXI Burst req
localparam BYTES_IN_ONE_BEAT = DDR_DATA_WIDTH >> 3; // Divide by 8
localparam UNUSABLE_ADDR     = DDR_ADDR_WIDTH - USABLE_ADDR_WIDTH;

// Metadata sizing: 128 bytes is the smallest multiple of both 64 and 32 that fits
// METADATA_WIDTH bits (640b = 80B). Beat count = 128/BYTES_IN_ONE_BEAT: 2 for 16GB, 4 for 8GB.
localparam integer METADATA_H_SIZE_BYTE = 128;
localparam integer METADATA_H_SIZE_BEAT = METADATA_H_SIZE_BYTE / BYTES_IN_ONE_BEAT;
localparam integer METADATA_V_SIZE_LINE = 1;

//------------------------------------------------------------------------------
// FSM state definition
//------------------------------------------------------------------------------
typedef enum logic [2:0] {
    IDLE                = 3'd0,
    CLEAR_DMA_FIFO      = 3'd1,
    WAIT_FOR_DMA_READY  = 3'd2,
    SET_BEAT_COUNTER    = 3'd3,
    READ_LINE_TRIG      = 3'd4,
    WAIT_LINE_XFER_DONE = 3'd5,
    CHECK_H_CHUNK       = 3'd6,
    CHECK_V_COUNT       = 3'd7
} state_t;

state_t curr_state;
state_t next_state;

//------------------------------------------------------------------------------
// Internal Signals
//------------------------------------------------------------------------------
logic [31:0]                  prm_wd_counter;

logic [1:0]                   clear_sync;

logic [1:0]                   frame_read_req_curr;
logic                         frame_read_req_prev;
logic                         frame_read_req_re;

logic [1:0]                   udp_metadata_sel_sync;
logic [8:0]                   h_size_beat_sync[2]; // [0:1]
logic [13:0]                  h_size_byte_sync[2]; // [0:1]
logic [12:0]                  v_size_line_sync[2]; // [0:1]
logic [FRAME_INDEX_WIDTH-1:0] frame_index_sync[2]; // [0:1]

logic [8:0]                   h_size_beat_eff;
logic [13:0]                  h_size_byte_eff;
logic [12:0]                  v_size_line_eff;

logic [1:0]                   dma_ready_sync;
logic [1:0]                   dma_ctrl_read_ack_sync;
logic [1:0]                   dma_ctrl_read_done_sync;

logic [FRAME_WIDTH-1:0]       read_addr_counter;
logic [31:0]                  beat_counter;
logic [31:0]                  line_counter;
logic [FRAME_WIDTH-1:0]       line_start_addr;

logic [1:0]                   pulse_stretch_counter;
logic                         frame_read_done_reg;
logic [1:0]                   frame_read_done_curr;
logic                         frame_read_done_prev;
logic                         frame_read_done_re;
logic [3:0]                   frame_read_done_stretch;

//------------------------------------------------------------------------------
// Continuous assignments
//------------------------------------------------------------------------------
assign dma_ctrl_line_index = line_counter;

assign h_size_beat_eff = udp_metadata_sel_sync[1] ? 9'(METADATA_H_SIZE_BEAT)  : h_size_beat_sync[1];
assign h_size_byte_eff = udp_metadata_sel_sync[1] ? 14'(METADATA_H_SIZE_BYTE) : h_size_byte_sync[1];
assign v_size_line_eff = udp_metadata_sel_sync[1] ? 13'(METADATA_V_SIZE_LINE) : v_size_line_sync[1];

//------------------------------------------------------------------------------
// Frame req rising edge detector
//------------------------------------------------------------------------------
always_ff @(posedge clk, negedge rst_n) begin
    if(~rst_n) begin
        frame_read_req_curr <= 2'b0;
        frame_read_req_prev <= 1'b0;
        frame_read_req_re   <= 1'b0;
    end else begin
        frame_read_req_curr <= {frame_read_req_curr[0], frame_read_req};
        frame_read_req_prev <= frame_read_req_curr[1];
        frame_read_req_re   <= (frame_read_req_curr[1]) & (~frame_read_req_prev);
    end
end

//------------------------------------------------------------------------------
// Pulse streacher (From UDP fast clock domain to APB slow clock domain)
//------------------------------------------------------------------------------
always_ff @(posedge clk, negedge rst_n) begin
    if(~rst_n) begin
        frame_read_done_curr    <= 'b0;
        frame_read_done_prev    <= 'b0;
        frame_read_done_re      <= 'b0;
        frame_read_done_stretch <= 'b0;
        pulse_stretch_counter   <= 'b0;
    end else begin
        frame_read_done_curr    <= {frame_read_done_curr[0], frame_read_done_reg};
        frame_read_done_prev    <= frame_read_done_curr[1];
        frame_read_done_re  <= (frame_read_done_curr[1]) & (~frame_read_done_prev);

        if (frame_read_done_re) begin
            pulse_stretch_counter <= 2'h3;
        end else if (pulse_stretch_counter != 2'h0) begin
            pulse_stretch_counter <= pulse_stretch_counter - 1;
        end

        frame_read_done_stretch <= (
            pulse_stretch_counter != 0) || frame_read_done_re;

        frame_read_done <= frame_read_done_stretch;
    end
end

//------------------------------------------------------------------------------
// CDC Sync
//------------------------------------------------------------------------------
always_ff @(posedge clk, negedge rst_n) begin
    if(~rst_n) begin
        clear_sync             <= 2'b0;
        dma_ready_sync         <= 2'b0;
        dma_ctrl_read_ack_sync  <= 2'b0;
        dma_ctrl_read_done_sync <= 2'b0;
        udp_metadata_sel_sync  <= 2'b0;
        h_size_beat_sync       <= '{default: 1'b0};
        h_size_byte_sync       <= '{default: 1'b0};
        v_size_line_sync       <= '{default: 1'b0};
        frame_index_sync       <= '{default: 1'b0};

    end else begin

        clear_sync             <= {clear_sync[0], clear};

        dma_ready_sync         <= {dma_ready_sync[0], dma_ready     };
        dma_ctrl_read_ack_sync  <= {dma_ctrl_read_ack_sync[0], dma_ctrl_read_ack};
        dma_ctrl_read_done_sync <= {dma_ctrl_read_done_sync[0], dma_ctrl_read_done};
        udp_metadata_sel_sync  <= {udp_metadata_sel_sync[0], udp_metadata_sel};

        h_size_beat_sync[0]    <= h_size_beat;
        h_size_beat_sync[1]    <= h_size_beat_sync[0];

        h_size_byte_sync[0]    <= h_size_byte;
        h_size_byte_sync[1]    <= h_size_byte_sync[0];

        v_size_line_sync[0]    <= v_size_line;
        v_size_line_sync[1]    <= v_size_line_sync[0];

        frame_index_sync[0]    <= frame_index;
        frame_index_sync[1]    <= frame_index_sync[0];
    end
end

//------------------------------------------------------------------------------
// Frame requester FSM
//------------------------------------------------------------------------------
always_ff @(posedge clk, negedge rst_n) begin
    if(~rst_n) begin
        curr_state            <= IDLE;
        frame_read_done_reg   <= 1'b0;
        dma_ctrl_read_req      <= 1'b0;
        dma_fifo_clear        <= 1'b0;
        ctrl_info_valid       <= 1'b0;
        ctrl_read_addr        <= 'b0;
        read_addr_counter     <= 'b0;
        ctrl_burst_count      <= 'b0;
        beat_counter          <= 'b0;
        dma_ctrl_pyl_size_word <= 'b0;
        line_counter          <= 'b0;
        line_start_addr       <= 'b0;
        prm_wd_counter        <= 'b0;
        timeout_err           <= 'b0;
    end else begin

        curr_state <= next_state;

        if (curr_state == IDLE) begin
            frame_read_done_reg   <= 1'b0;
            dma_ctrl_read_req      <= 1'b0;
            dma_fifo_clear        <= 1'b0;
            ctrl_info_valid       <= 1'b1; // Set
            ctrl_read_addr        <= {
                {UNUSABLE_ADDR{1'b0}},
                frame_index_sync[1],
                {FRAME_WIDTH{1'b0}}};
            read_addr_counter     <= 'b0;
            ctrl_burst_count      <= 'b0;
            beat_counter          <= 'b0;
            dma_ctrl_pyl_size_word <= 'b0;
            line_counter          <= 'b0;
            line_start_addr       <= 'b0;
            prm_wd_counter        <= 'b0;

            if (clear_sync[1]) begin
                timeout_err       <= 'b0;
            end else begin
                timeout_err       <= timeout_err;
            end

        end else if (curr_state == CLEAR_DMA_FIFO) begin
            frame_read_done_reg   <= 1'b0;
            dma_ctrl_read_req      <= 1'b0;
            dma_fifo_clear        <= 1'b1; // Reset DMA FIFO on new frame read req
            ctrl_info_valid       <= 1'b0;
            ctrl_read_addr        <= ctrl_read_addr;
            read_addr_counter     <= 'b0;
            ctrl_burst_count      <= 'b0;
            beat_counter          <= 'b0;
            dma_ctrl_pyl_size_word <= 'b0;
            line_counter          <= 'b0;
            line_start_addr       <= 'b0;
            timeout_err           <= timeout_err; // Keep

            if (prm_wd_counter < 4) begin
                prm_wd_counter    <= prm_wd_counter + 1;
            end else begin
                prm_wd_counter    <= 'b0;
            end

        end else if (curr_state == WAIT_FOR_DMA_READY) begin
            frame_read_done_reg   <= 1'b0;
            dma_ctrl_read_req      <= 1'b0;
            dma_fifo_clear        <= 1'b0;
            ctrl_info_valid       <= 1'b1; // Set
            ctrl_read_addr        <= {
                {UNUSABLE_ADDR{1'b0}},
                frame_index_sync[1],
                read_addr_counter};
            read_addr_counter     <= read_addr_counter;
            ctrl_burst_count      <= ctrl_burst_count;
            beat_counter          <= beat_counter;
            dma_ctrl_pyl_size_word <= dma_ctrl_pyl_size_word;
            line_counter          <= line_counter;
            line_start_addr       <= line_start_addr;

            if(dma_ready_sync[1]) begin
                prm_wd_counter  <= 0;
                timeout_err     <= timeout_err;
            end else if (prm_wd_counter >= MAX_TIMEOUT-1) begin
                prm_wd_counter  <= 0;
                timeout_err     <= timeout_err + 1;
            end else begin
                prm_wd_counter  <= prm_wd_counter + 1;
                timeout_err     <= timeout_err;
            end

        end else if (curr_state == SET_BEAT_COUNTER) begin
            frame_read_done_reg <= 1'b0;
            dma_ctrl_read_req    <= 1'b0;
            dma_fifo_clear      <= 1'b0;
            ctrl_info_valid     <= 1'b1; // Keep
            ctrl_read_addr      <= ctrl_read_addr;
            read_addr_counter   <= read_addr_counter;
            ctrl_burst_count    <= ctrl_burst_count;
            line_counter        <= line_counter;
            line_start_addr     <= line_start_addr;
            prm_wd_counter      <= 0;
            timeout_err         <= timeout_err;

            if(h_size_beat_eff > MAX_BURST_SIZE) begin
                // Since h_size_beat is greater than max burst size need
                // to increament by max burst size.

                if((beat_counter + MAX_BURST_SIZE) <= h_size_beat_eff) begin
                    beat_counter          <= beat_counter + MAX_BURST_SIZE;

                     // Multiply by data width divide by 32 (=2^5, 4 bytes)
                    dma_ctrl_pyl_size_word <= (
                        (beat_counter + MAX_BURST_SIZE) * DDR_DATA_WIDTH) >> 5;

                end else begin
                    // The last remaining chunks needs to be calculated here.
                    beat_counter <= beat_counter +
                                    (h_size_beat_eff - beat_counter);

                    // Multiply by data width divide by 32 (4 bytes)
                    dma_ctrl_pyl_size_word <= (
                        (
                            beat_counter + (h_size_beat_eff - beat_counter)
                        ) * DDR_DATA_WIDTH) >> 5;
                end

            end else begin
                // The total beats is smaller than max so just use it.
                beat_counter <= h_size_beat_eff;

                // Multiply by data width divide by 32 (4 bytes)
                dma_ctrl_pyl_size_word <= (
                    h_size_beat_eff * DDR_DATA_WIDTH) >> 5;
            end

        end else if (curr_state == READ_LINE_TRIG) begin
            frame_read_done_reg   <= 1'b0;
            dma_ctrl_read_req      <= 1'b1; // Set line read trig
            dma_fifo_clear        <= 1'b0;
            ctrl_info_valid       <= 1'b1;
            ctrl_read_addr        <= ctrl_read_addr;
            read_addr_counter     <= read_addr_counter;
            ctrl_burst_count      <= beat_counter; // Set
            beat_counter          <= beat_counter;
            dma_ctrl_pyl_size_word <= dma_ctrl_pyl_size_word;
            line_counter          <= line_counter;
            line_start_addr       <= line_start_addr;

            if(dma_ctrl_read_ack_sync[1]) begin
                prm_wd_counter    <= 0;
                timeout_err       <= timeout_err;
            end else if (prm_wd_counter >= MAX_TIMEOUT-1) begin
                prm_wd_counter    <= 0;
                timeout_err       <= timeout_err + 1;
            end else begin
                prm_wd_counter    <= prm_wd_counter + 1;
                timeout_err       <= timeout_err;
            end

        end else if (curr_state == WAIT_LINE_XFER_DONE) begin
            frame_read_done_reg   <= 1'b0;
            dma_ctrl_read_req      <= 1'b0;
            dma_fifo_clear        <= 1'b0;
            ctrl_info_valid       <= 1'b1;
            ctrl_read_addr        <= ctrl_read_addr;
            read_addr_counter     <= read_addr_counter;
            beat_counter          <= beat_counter;
            dma_ctrl_pyl_size_word <= dma_ctrl_pyl_size_word;
            line_counter          <= line_counter;
            line_start_addr       <= line_start_addr;

            if(dma_ctrl_read_done_sync[1]) begin
                prm_wd_counter    <= 0;
                timeout_err       <= timeout_err;
            end else if (prm_wd_counter >= MAX_TIMEOUT-1) begin
                prm_wd_counter    <= 0;
                timeout_err       <= timeout_err + 1;
            end else begin
                prm_wd_counter    <= prm_wd_counter + 1;
                timeout_err       <= timeout_err;
            end

        end else if (curr_state == CHECK_H_CHUNK) begin
            frame_read_done_reg   <= 1'b0;
            dma_ctrl_read_req      <= 1'b0;
            dma_fifo_clear        <= 1'b0;
            ctrl_info_valid       <= 1'b1;
            ctrl_read_addr        <= ctrl_read_addr;
            beat_counter          <= beat_counter;
            dma_ctrl_pyl_size_word <= dma_ctrl_pyl_size_word;
            line_counter          <= line_counter;
            line_start_addr       <= line_start_addr;
            prm_wd_counter        <= 0;
            timeout_err           <= timeout_err;

            if(beat_counter < h_size_beat_eff) begin
                // We have NOT transferred all the required beats yet
                read_addr_counter <= read_addr_counter +
                                        (BYTES_IN_ONE_BEAT * beat_counter);
            end else begin
                read_addr_counter <= read_addr_counter;
            end

        end else if (curr_state == CHECK_V_COUNT) begin
            dma_ctrl_read_req      <= 1'b0;
            dma_fifo_clear        <= 1'b0;
            ctrl_info_valid       <= 1'b1;
            ctrl_read_addr        <= ctrl_read_addr;
            dma_ctrl_pyl_size_word <= dma_ctrl_pyl_size_word;
            prm_wd_counter        <= 0;
            timeout_err           <= timeout_err;

            if((line_counter+1) < v_size_line_eff) begin
                frame_read_done_reg <= 1'b0; // Not done yet. Still more to read
                line_counter        <= line_counter + 1;
                line_start_addr     <= line_start_addr + h_size_byte_eff;
                read_addr_counter   <= line_start_addr + h_size_byte_eff;
                beat_counter        <= beat_counter;
            end else begin
                // We have read the entire frame
                frame_read_done_reg <= 1'b1; // Done reading entire one frame
                line_counter        <= 0;
                line_start_addr     <= 0;
                read_addr_counter   <= 0;
                beat_counter        <= 0; // Reset the beat counter
            end

        end else begin
            frame_read_done_reg   <= 1'b0;
            dma_ctrl_read_req      <= 1'b0;
            dma_fifo_clear        <= 1'b0;
            ctrl_info_valid       <= 1'b0;
            ctrl_read_addr        <= 'b0;
            read_addr_counter     <= 'b0;
            ctrl_burst_count      <= 'b0;
            beat_counter          <= 'b0;
            dma_ctrl_pyl_size_word <= 'b0;
            line_counter          <= 'b0;
            line_start_addr       <= 'b0;
            prm_wd_counter        <= 'b0;
            timeout_err           <= 'b0;
        end
    end
end


always_comb begin
    next_state = curr_state;

    case(curr_state)
        IDLE: begin
            if(clear_sync[1]) begin
                next_state = IDLE;
            end else if(frame_read_req_re) begin
                next_state = CLEAR_DMA_FIFO;
            end else begin
                next_state = IDLE;
            end
        end

        CLEAR_DMA_FIFO: begin
            if(clear_sync[1]) begin
                next_state = IDLE;
            end else if (prm_wd_counter < 4) begin
                next_state = CLEAR_DMA_FIFO;
            end else begin
                next_state = WAIT_FOR_DMA_READY;
            end
        end

        WAIT_FOR_DMA_READY: begin
            if(clear_sync[1]) begin
                next_state = IDLE;
            end else if(dma_ready_sync[1]) begin
                next_state = SET_BEAT_COUNTER;
            end else if (prm_wd_counter >= MAX_TIMEOUT-1) begin
                next_state = IDLE;
            end else begin
                next_state = WAIT_FOR_DMA_READY;
            end
        end

        SET_BEAT_COUNTER: begin
            if(clear_sync[1]) begin
                next_state = IDLE;
            end else begin
                next_state = READ_LINE_TRIG;
            end
        end

        READ_LINE_TRIG: begin
            if(clear_sync[1]) begin
                next_state = IDLE;
            end else if(dma_ctrl_read_ack_sync[1]) begin
                next_state = WAIT_LINE_XFER_DONE;
            end else if (prm_wd_counter >= MAX_TIMEOUT-1) begin
                next_state = IDLE;
            end else begin
                next_state = READ_LINE_TRIG;
            end
        end

        WAIT_LINE_XFER_DONE: begin
            if(clear_sync[1]) begin
                next_state = IDLE;
            end else if(dma_ctrl_read_done_sync[1]) begin
                next_state = CHECK_H_CHUNK;
            end else if (prm_wd_counter >= MAX_TIMEOUT-1) begin
                next_state = IDLE;
            end else begin
                next_state = WAIT_LINE_XFER_DONE;
            end
        end

        CHECK_H_CHUNK: begin
            if(clear_sync[1]) begin
                next_state = IDLE;
            end else if(beat_counter >= h_size_beat_eff) begin
                next_state = CHECK_V_COUNT;
            end else begin
                next_state = WAIT_FOR_DMA_READY;
            end
        end

        CHECK_V_COUNT: begin
            if(clear_sync[1]) begin
                next_state = IDLE;
            end else if((line_counter+1) >= v_size_line_eff) begin
                next_state = IDLE;
            end else begin
                next_state = WAIT_FOR_DMA_READY;
            end
        end

        default: begin
            next_state = IDLE;
        end

    endcase
end
endmodule