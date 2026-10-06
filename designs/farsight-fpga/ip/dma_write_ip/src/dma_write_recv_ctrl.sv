/*
 * @file      dma_write_recv_ctrl.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      10/06/2025
 *
 * @brief     This is a counter for the number of chunk of camera data begin
 *            transferred to the DMA write FIFO. The state machine will be idle
 *            unitl the rising edge of line valid from SLVSEC IP. It will
 *            increament as long as the WCONV IP chunk_valid signal is asserted.
 *            On the falling edge of the line valid will wait until the last
 *            chunk has been transferred, then it will wait until the ack comes
 *            back from send ctrl IP before moving back to idle waiting for the
 *            next rising edge of line valid.
 *
 * @section changelog
 * - 10/06/2025: Saba Janamian - Initial implementation
 *
 */

module dma_write_recv_ctrl (
    // Pixel clock domain
    input  logic         pixel_clk,
    input  logic         pixel_rst_n,

    // CAM interface
    input  logic         line_valid,         // Line valid from CAM
    input  logic         chunk_valid,        // From width converter

    // Control interface
    output logic [9:0]   chunk_count,       // write send ctrl (zero index)
    output logic         chunk_count_valid, // valid signal to write send ctrl
    input  logic         chunk_count_ack    // ack from write send ctrl
);

//------------------------------------------------------------------------------
// Internal signals
//------------------------------------------------------------------------------
logic        line_valid_curr;
logic        line_valid_prev;
logic        line_valid_re;  // Rising edge
logic        line_valid_fe;  // Faling edge

logic [9:0]  fifo_count_reg; // Counter for CAM data chunks to FIFO

logic [1:0]  chunk_count_ack_sync;

//------------------------------------------------------------------------------
// Controller FSM definition
//------------------------------------------------------------------------------
typedef enum logic [1:0] {
    RECV_IDLE          = 2'd0, // Idle waiting for line valid rising edge
    RECV_COUNT         = 2'd1, // Count input chunks
    WAIT_FOR_RECV_DONE = 2'd2, // Send the recv done pulse
    SEND_RECV_DONE     = 2'd3
} state_t;

state_t curr_state;
state_t next_state;

//------------------------------------------------------------------------------
// Data valid edge detector
//------------------------------------------------------------------------------
always_ff @(posedge pixel_clk, negedge pixel_rst_n) begin
    if (~pixel_rst_n) begin
        line_valid_curr <= 'b0;
        line_valid_prev <= 'b0;
        line_valid_re   <= 'b0;
        line_valid_fe   <= 'b0;
    end else begin
        line_valid_curr <= line_valid;
        line_valid_prev <= line_valid_curr;
        line_valid_re   <= line_valid_curr & (~line_valid_prev);
        line_valid_fe   <= (~line_valid_curr) & line_valid_prev;
    end
end

//------------------------------------------------------------------------------
// ACK sync
//------------------------------------------------------------------------------
always_ff @(posedge pixel_clk, negedge pixel_rst_n) begin
    if(~pixel_rst_n) begin
        chunk_count_ack_sync <= 2'b0;
    end else begin
        chunk_count_ack_sync <= {chunk_count_ack_sync[0], chunk_count_ack};
    end
end

//------------------------------------------------------------------------------
// Recv chunk counter FSM
//------------------------------------------------------------------------------
always_ff @(posedge pixel_clk, negedge pixel_rst_n) begin
    if(~pixel_rst_n) begin
        curr_state         <= RECV_IDLE;
        fifo_count_reg     <= 'b0;
        chunk_count        <= 'b0;
        chunk_count_valid  <= 'b0;

    end else begin

        curr_state <= next_state;

        if (curr_state == RECV_IDLE) begin
            fifo_count_reg     <= 'b0;
            chunk_count        <= 'b0;
            chunk_count_valid  <= 'b0;

        end else if (curr_state == RECV_COUNT) begin
            chunk_count        <= 'b0;
            chunk_count_valid  <= 'b0;

            if (chunk_valid) begin
                fifo_count_reg <= fifo_count_reg + 1;
            end else begin
                fifo_count_reg <= fifo_count_reg;
            end

        end else if (curr_state == WAIT_FOR_RECV_DONE) begin
            chunk_count        <= 'b0;
            chunk_count_valid  <= 'b0;

            if (chunk_valid) begin // Continue counting until the last chunk
                fifo_count_reg <= fifo_count_reg + 1;
            end else begin
                fifo_count_reg <= fifo_count_reg;
            end

        end else if (curr_state == SEND_RECV_DONE) begin
            chunk_count        <= fifo_count_reg;
            chunk_count_valid  <= 'b1;
            fifo_count_reg     <= fifo_count_reg;

        end else begin
            fifo_count_reg  <= 'b0;
        end

    end
end


always_comb begin

    next_state = curr_state;

    case(curr_state)

        RECV_IDLE: begin

            if(line_valid_re) begin
                next_state = RECV_COUNT;
            end else begin
                next_state = RECV_IDLE;
            end

        end

        RECV_COUNT: begin

            if(line_valid_fe) begin
                next_state = WAIT_FOR_RECV_DONE;
            end else begin
                next_state = RECV_COUNT;
            end

        end

        WAIT_FOR_RECV_DONE: begin

            if(~chunk_valid) begin // Have received all chunks
                next_state = SEND_RECV_DONE;
            end else begin
                next_state = WAIT_FOR_RECV_DONE;
            end

        end

        SEND_RECV_DONE: begin

            if(chunk_count_ack_sync[1]) begin
                next_state = RECV_IDLE;
            end else begin
                next_state = SEND_RECV_DONE;
            end

        end

        default: begin
            next_state = RECV_IDLE;
        end

    endcase
end

endmodule
