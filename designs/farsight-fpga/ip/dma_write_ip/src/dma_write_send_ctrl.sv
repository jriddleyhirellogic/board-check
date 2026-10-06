/*
 * @file      dma_write_send_ctrl.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      10/07/2025
 *
 * @brief     FSM for sending buffered data in a FIFO to Arbiter to be
 *            stored in DDR write.
 *
 * @section changelog
 * - 10/07/2025: Saba Janamian - Initial implementation
 *
 */

module dma_write_send_ctrl #(
    parameter integer CLOCK_FREQ_MHZ    = 150,
    parameter integer TIMEOUT_USEC      = 10_000, // 10 mSec
    // This included ECC, usable size is 33 bits for 8GB
    parameter integer DDR_ADDR_WIDTH    = 38,
    parameter integer DDR_DATA_WIDTH    = 256,
    parameter integer DIN_DOUT_RATIO    = 2, // 2 if DATA_WIDTH is 256, 1 if 512
    parameter integer FRAME_WIDTH       = 25, // 25 bits of addr to store frame
    parameter integer USABLE_ADDR_WIDTH = 33, // 2^30 * 2^3 = 8GB
    parameter integer FRAME_INDEX_WIDTH = USABLE_ADDR_WIDTH - FRAME_WIDTH // 8
)(
    // DDR4 clock domain
    input  logic                         ddr_clk,
    input  logic                         ddr_rst_n,
    // CAM interface
    input  logic                         frame_valid, // (CDC)
    input  logic                         line_valid,  // (CDC)
    // Recv Ctrl interface
    input  logic [9:0]                   chunk_count, // (CDC) (zero index)
    input  logic                         chunk_count_valid, // (CDC)
    output logic                         chunk_count_ack,
    // APB Reg interface
    input  logic                         clear_index, // (CDC)
    input  logic [13:0]                  h_size_byte, // (CDC) (a.k.a LINE_GAP)
    output logic [FRAME_INDEX_WIDTH-1:0] frame_index,
    output logic                         core_ready,
    output logic                         frame_write_done,
    output logic                         timeout_err,
    // FIFO interface
    output logic                         fifo_en,
    input  logic                         fifo_valid,
    input  logic [DDR_DATA_WIDTH-1:0]    fifo_data,
    // DMA to Arbiter interface
    output logic                         arb_write_req,
    input  logic                         arb_write_ack,
    output logic [7:0]                   arb_write_burst_len,
    output logic [DDR_ADDR_WIDTH-1:0]    arb_write_start_addr,
    input  logic                         arb_write_done,
    output logic                         arb_write_valid,
    output logic [DDR_DATA_WIDTH-1:0]    arb_write_data
);

//------------------------------------------------------------------------------
// Local parameters
//------------------------------------------------------------------------------
localparam MAX_TIMEOUT       = CLOCK_FREQ_MHZ * TIMEOUT_USEC;
localparam MAX_BURST_SIZE    = 256; // MAX 256 Beats for single AXI Burst req
localparam BYTES_IN_ONE_BEAT = DDR_DATA_WIDTH >> 3; // Divide by 8
localparam UNUSABLE_ADDR     = DDR_ADDR_WIDTH - USABLE_ADDR_WIDTH;

//------------------------------------------------------------------------------
// Internal signals
//------------------------------------------------------------------------------
logic                         frame_write_done_pulse;
logic                         frame_write_done_prev;
logic                         frame_write_done_curr;
logic [2:0]                   stretch_counter;

logic                         chunk_count_valid_sync;
logic                         chunk_count_valid_curr;
logic                         chunk_count_valid_prev;
logic                         chunk_count_valid_re; // Rising edge

logic [9:0]                   chunk_count_sync[2]; // [0:1]

logic                         frame_valid_curr;
logic                         frame_valid_prev;
logic                         frame_valid_status;

logic [1:0]                   line_valid_sync;

logic [1:0]                   clear_index_curr;
logic                         clear_index_prev;
logic                         clear_index_re;

logic [13:0]                  h_size_byte_sync[2];
logic [13:0]                  h_size_byte_reg;

// Keeps the total number of chunks in one line
logic [9:0]                   max_chunk_count;

// Keeps track of total beats sent for a single cam line
logic [31:0]                  total_beat;

// Keeps track of how many chunks have been sent in each burst request
logic [31:0]                  beat_counter;

// Keeps the start address of each line
logic [FRAME_WIDTH-1:0]       line_start_addr;

// The current frame being written to the
logic [FRAME_INDEX_WIDTH-1:0] frame_counter;

// Primary Watchdog counter
logic [31:0]                  prm_wd_counter;

//------------------------------------------------------------------------------
// FSM state definition
//------------------------------------------------------------------------------
typedef enum logic [2:0] {
    IDLE               = 3'd0, // Idle waiting for Frame valid
    WAIT_VALID_CHUNK   = 3'd1, // Idle waiting for data valid falling edge
    SET_BEAT_COUNTER   = 3'd2, // Set start address of next burst
    WRITE_TRIG         = 3'd3, // Send a write req to ddr adn wait for ack
    WRITING            = 3'd4, // Write to ddr
    CHECK_REMAINING    = 3'd5, // Check if more data needs to be sent
    SET_NEXT_LINE_ADDR = 3'd6 // Set the next line address
} state_t;

state_t curr_state;
state_t next_state;

//------------------------------------------------------------------------------
// Continuous signals
//------------------------------------------------------------------------------
// Forwards fifo_valid signal to ARB
assign arb_write_valid = fifo_valid;
assign arb_write_data  = fifo_valid ? fifo_data : 'b0;

//------------------------------------------------------------------------------
// Write DDR Arbiter FSM
//------------------------------------------------------------------------------

always_ff @(posedge ddr_clk, negedge ddr_rst_n) begin
    if (~ddr_rst_n) begin

        curr_state             <= IDLE;

        chunk_count_ack        <= 'b0;
        frame_write_done_pulse <= 'b0;
        core_ready             <= 'b0;
        fifo_en                <= 'b0;
        arb_write_req          <= 'b0;
        arb_write_burst_len    <= 'b0;
        arb_write_start_addr   <= 'b0;
        total_beat             <= 'b0;
        beat_counter           <= 'b0;
        line_start_addr        <= 'b0;
        max_chunk_count        <= 'b0;
        prm_wd_counter         <= 'b0;
        timeout_err            <= 'b0;

    end else begin

        curr_state <= next_state;

        if (curr_state == IDLE) begin
            chunk_count_ack        <= 'b0;
            frame_write_done_pulse <= 'b0;
            frame_index            <= frame_counter - 1;
            core_ready             <= ~frame_valid_status;
            fifo_en                <= 'b0;
            arb_write_req          <= 'b0;
            arb_write_burst_len    <= 'b0;
            total_beat             <= 'b0;
            beat_counter           <= 'b0;
            line_start_addr        <= 'b0;
            max_chunk_count        <= 'b0;
            prm_wd_counter         <= 'b0;
            timeout_err            <= timeout_err;

            if (clear_index_re) begin
                frame_counter        <= 'b0;
                arb_write_start_addr <= 'b0;
            end else begin
                frame_counter        <= frame_counter;
                arb_write_start_addr <= {
                    {UNUSABLE_ADDR{1'b0}},
                    frame_counter,
                    {FRAME_WIDTH{1'b0}}
                };
            end

        end else if (curr_state == WAIT_VALID_CHUNK) begin
            chunk_count_ack        <= 'b0;
            frame_index            <= frame_index;
            core_ready             <= 'b0;
            fifo_en                <= 'b0;
            arb_write_req          <= 'b0;
            arb_write_burst_len    <= arb_write_burst_len;
            arb_write_start_addr   <= arb_write_start_addr;
            total_beat             <= total_beat;
            beat_counter           <= 'b0;
            line_start_addr        <= line_start_addr;
            prm_wd_counter         <= prm_wd_counter + 1;

            if (~frame_valid_status) begin
                frame_counter          <= frame_counter + 1;
                frame_write_done_pulse <= 'b1; // Set
            end else begin
                frame_counter          <= frame_counter;
                frame_write_done_pulse <= 'b0;
            end

            if(chunk_count_valid_re) begin
                // Capture the requested chunk size
                // chunk_count is zero based. Need to increament by 1.
                max_chunk_count  <= ((chunk_count_sync[1] + 1) * DIN_DOUT_RATIO);
            end else begin
                max_chunk_count  <= 'b0;
            end

            if (prm_wd_counter >= MAX_TIMEOUT-1) begin
                timeout_err      <= 1'b1;
            end else begin
                timeout_err      <= timeout_err;
            end

        end else if (curr_state == SET_BEAT_COUNTER) begin
            chunk_count_ack        <= 'b0; // Set
            frame_counter          <= frame_counter;
            frame_write_done_pulse <= 'b0;
            frame_index            <= frame_index;
            core_ready             <= 'b0;
            fifo_en                <= 'b0;
            arb_write_req          <= 'b0;
            arb_write_burst_len    <= arb_write_burst_len;
            arb_write_start_addr   <= arb_write_start_addr;
            beat_counter           <= 'b0;
            line_start_addr        <= line_start_addr;
            max_chunk_count        <= max_chunk_count;
            prm_wd_counter         <= 'b0;
            timeout_err            <= timeout_err;

            // If the max_chunk_count is greater than max burst size need
            // to increament by max burst size
            if (max_chunk_count > MAX_BURST_SIZE) begin
                if ((total_beat + MAX_BURST_SIZE) <= max_chunk_count) begin
                    total_beat <= total_beat + MAX_BURST_SIZE;
                end else begin
                    total_beat <= total_beat + (max_chunk_count - total_beat);
                end
            end else begin
                total_beat <= max_chunk_count;
            end

        end else if (curr_state == WRITE_TRIG) begin
            chunk_count_ack        <= 'b0;
            frame_counter          <= frame_counter;
            frame_write_done_pulse <= 'b0;
            frame_index            <= frame_index;
            core_ready             <= 'b0;
            fifo_en                <= 'b0;
            arb_write_start_addr   <= arb_write_start_addr;
            total_beat             <= total_beat;
            beat_counter           <= 'b0;
            line_start_addr        <= line_start_addr;
            max_chunk_count        <= max_chunk_count;

            if (arb_write_ack) begin
                arb_write_req      <= 'b0; // If ack stop the write req
            end else begin
                arb_write_req      <= 'b1; // Continue the write req
            end

            if (total_beat == 0) begin
                arb_write_burst_len  <= total_beat;
            end else begin
                // AXI Burst len is always 1 less than total burst request
                arb_write_burst_len  <= total_beat - 1;
            end

            if (arb_write_ack) begin
                prm_wd_counter       <= 'b0; // wd reset to 0
            end else begin
                prm_wd_counter       <= prm_wd_counter + 1;
            end

            if (prm_wd_counter >= MAX_TIMEOUT-1) begin
                timeout_err      <= 1'b1;
            end else begin
                timeout_err      <= timeout_err;
            end

        end else if (curr_state == WRITING) begin

            chunk_count_ack        <= 'b1; // Set
            frame_counter          <= frame_counter;
            frame_write_done_pulse <= 'b0;
            frame_index            <= frame_index;
            core_ready             <= 'b0;
            arb_write_req          <= 'b0;
            arb_write_burst_len    <= arb_write_burst_len;
            arb_write_start_addr   <= arb_write_start_addr;
            total_beat             <= total_beat;
            line_start_addr        <= line_start_addr;
            max_chunk_count        <= max_chunk_count;

            if (beat_counter <= (total_beat-1)) begin
                beat_counter <= beat_counter + 1;
                fifo_en      <= 'b1;
            end else begin
                beat_counter <= beat_counter;
                fifo_en      <= 'b0;
            end

            if (arb_write_done) begin
                prm_wd_counter <= 'b0; // wd reset to 0
            end else begin
                prm_wd_counter <= prm_wd_counter + 1;
            end

            if (prm_wd_counter >= MAX_TIMEOUT-1) begin
                timeout_err    <= 1'b1;
            end else begin
                timeout_err    <= timeout_err;
            end

        end else if (curr_state == CHECK_REMAINING) begin

            chunk_count_ack        <= 'b0;
            frame_counter          <= frame_counter;
            frame_write_done_pulse <= 'b0;
            frame_index            <= frame_index;
            core_ready             <= 'b0;
            fifo_en                <= 'b0;
            arb_write_req          <= 'b0;
            arb_write_burst_len    <= arb_write_burst_len;
            total_beat             <= total_beat;
            beat_counter           <= 'b0;
            line_start_addr        <= line_start_addr;
            max_chunk_count        <= max_chunk_count;
            prm_wd_counter         <= 'b0;
            timeout_err            <= timeout_err;

            if (total_beat < max_chunk_count) begin
                // We have NOT transferred all the required beats yet
                arb_write_start_addr <= arb_write_start_addr +
                                            (BYTES_IN_ONE_BEAT * beat_counter);
            end else begin
                arb_write_start_addr <= arb_write_start_addr;
            end

        end else if (curr_state == SET_NEXT_LINE_ADDR) begin
            chunk_count_ack        <= 'b0;
            frame_counter          <= frame_counter;
            frame_write_done_pulse <= 'b0;
            frame_index            <= frame_index;
            core_ready             <= 'b0;
            fifo_en                <= 'b0;
            arb_write_req          <= 'b0;
            arb_write_burst_len    <= arb_write_burst_len;
            arb_write_start_addr   <= {{UNUSABLE_ADDR{1'b0}},
                                        frame_counter,
                                        {line_start_addr + h_size_byte_reg}};
            total_beat             <= total_beat;
            beat_counter           <= 'b0;
            line_start_addr        <= line_start_addr + h_size_byte_reg;
            max_chunk_count        <= max_chunk_count;
            prm_wd_counter         <= 'b0;
            timeout_err            <= timeout_err;

        end else begin
            chunk_count_ack        <= 'b0;
            frame_counter          <= 'b0;
            frame_write_done_pulse <= 'b0;
            frame_index            <= 'b0;
            core_ready             <= 'b0;
            fifo_en                <= 'b0;
            arb_write_req          <= 'b0;
            arb_write_burst_len    <= 'b0;
            arb_write_start_addr   <= 'b0;
            total_beat             <= 'b0;
            beat_counter           <= 'b0;
            line_start_addr        <= 'b0;
            max_chunk_count        <= 'b0;
            prm_wd_counter         <= 'b0;
            timeout_err            <= timeout_err;
        end
    end
end

always_comb begin

    next_state = curr_state;

    case(curr_state)

        IDLE: begin
            if (frame_valid_status) begin
                next_state = WAIT_VALID_CHUNK;
            end else begin
                next_state = IDLE;
            end
        end

        WAIT_VALID_CHUNK: begin
            if (chunk_count_valid_re) begin
                next_state = SET_BEAT_COUNTER;
            end else if (~frame_valid_status) begin
                next_state = IDLE;
            end else if (prm_wd_counter >= MAX_TIMEOUT-1) begin
                next_state = IDLE;
            end else begin
                next_state = WAIT_VALID_CHUNK;
            end
        end

        SET_BEAT_COUNTER: begin
            next_state = WRITE_TRIG;
        end

        WRITE_TRIG: begin
            if (arb_write_ack) begin
                next_state = WRITING;
            end else if (prm_wd_counter >= MAX_TIMEOUT-1) begin
                next_state = IDLE;
            end else begin
                next_state = WRITE_TRIG;
            end
        end

        WRITING: begin
            if (arb_write_done) begin
                next_state = CHECK_REMAINING;
            end else if (prm_wd_counter >= MAX_TIMEOUT-1) begin
                next_state = IDLE;
            end else begin
                next_state = WRITING;
            end
        end

        CHECK_REMAINING: begin
            if (total_beat < max_chunk_count) begin
                next_state = SET_BEAT_COUNTER;
            end else begin
                next_state = SET_NEXT_LINE_ADDR;
            end
        end

        SET_NEXT_LINE_ADDR: begin
            next_state = WAIT_VALID_CHUNK;
        end

    endcase
end

//------------------------------------------------------------------------------
// Edge detector
//------------------------------------------------------------------------------
always_ff @(posedge ddr_clk, negedge ddr_rst_n) begin

    if (~ddr_rst_n) begin

        chunk_count_valid_sync <= 'b0;
        chunk_count_valid_curr <= 'b0;
        chunk_count_valid_prev <= 'b0;
        chunk_count_valid_re   <= 'b0;

        frame_valid_curr       <= 'b0;
        frame_valid_prev       <= 'b0;
        frame_valid_status     <= 'b0;

        clear_index_curr       <= 'b0;
        clear_index_prev       <= 'b0;
        clear_index_re         <= 'b0;

    end else begin

        chunk_count_valid_sync <= chunk_count_valid;
        chunk_count_valid_curr <= chunk_count_valid_sync;
        chunk_count_valid_prev <= chunk_count_valid_curr;
        chunk_count_valid_re   <= chunk_count_valid_curr &
                                    (~chunk_count_valid_prev);

        frame_valid_curr      <= frame_valid;
        frame_valid_prev      <= frame_valid_curr;
        frame_valid_status    <= frame_valid_prev;

        clear_index_curr       <= {clear_index_curr[0], clear_index};
        clear_index_prev       <= clear_index_curr[1];
        clear_index_re         <= clear_index_curr[1] & (~clear_index_prev);

    end

end

//------------------------------------------------------------------------------
// CDC Synchronizer
//------------------------------------------------------------------------------
always_ff @(posedge ddr_clk, negedge ddr_rst_n) begin
    if(~ddr_rst_n) begin

        chunk_count_sync    <= '{default: 1'b0};
        line_valid_sync     <= 2'b0;
        h_size_byte_sync    <= '{default: 1'b0};
        h_size_byte_reg     <= 'b0;
    end else begin

        chunk_count_sync[0] <= chunk_count;
        chunk_count_sync[1] <= chunk_count_sync[0];

        line_valid_sync     <= {line_valid_sync[0], line_valid};

        h_size_byte_sync[0] <= h_size_byte;
        h_size_byte_sync[1] <= h_size_byte_sync[0];
        h_size_byte_reg     <= h_size_byte_sync[1];

    end
end

//------------------------------------------------------------------------------
// Pulse streatcher for frame_write_done signal going to APB reg
//------------------------------------------------------------------------------
always_ff @(posedge ddr_clk, negedge ddr_rst_n) begin
    if (~ddr_rst_n) begin
        frame_write_done_prev <= 'b0;
        frame_write_done_curr <= 'b0;
        stretch_counter       <= 'b0;
        frame_write_done      <= 'b0;
    end else begin

        frame_write_done_curr <= frame_write_done_pulse;
        frame_write_done_prev <= frame_write_done_curr;

        if (frame_write_done_curr && (~frame_write_done_prev)) begin
            frame_write_done <= 'b1;
            stretch_counter  <= 'd7;

        end else begin

            if (stretch_counter > 0) begin
                stretch_counter  <= stretch_counter - 1;
                frame_write_done <= 'b1;
            end else begin
                frame_write_done <= 'b0;
            end

        end
    end
end

endmodule
