/*
 * @file      dma_read.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      09/29/2025
 *
 * @brief     DMA Read controller FSM
 *
 * @section changelog
 * - 09/29/2025: Saba Janamian - Initial implementation
 *
 */

module dma_read #(
    parameter integer DDR4_CLOCK_FREQ_MHZ    = 150,
    parameter integer TIMEOUT_USEC           = 10_000, // 10 mSec
    parameter integer DDR_ADDR_WIDTH         = 38,
    parameter integer DDR_DATA_WIDTH         = 256,
    parameter integer DATA_OUT_WIDTH         = 32
)(
    input  logic                      ddr_clk,
    input  logic                      ddr_rst_n,
    input  logic                      ctrl_clk,
    input  logic                      ctrl_rst_n,
    // Controller read interface (controller clock domain)
    input  logic                      ctrl_info_valid,  // CDC
    input  logic [8:0]                ctrl_burst_count, // CDC
    input  logic [DDR_ADDR_WIDTH-1:0] ctrl_read_addr,  // CDC
    // DMA to Controller handshaking interface
    output logic                      dma_ready,
    input  logic                      dma_read_req,     // CDC
    output logic                      dma_read_ack,
    input  logic                      dma_fifo_clear,   // CDC
    // FIFO read interface (controller clock domain)
    input  logic                      m_axis_dma_tready, // DMA FIFO read enable
    output logic                      m_axis_dma_tvalid, // DMA FIFO data valid
    output logic [DATA_OUT_WIDTH-1:0] m_axis_dma_tdata,  // DMA FIFO data input
    // DMA to Arbiter interface
    output logic                      arb_read_req,
    input  logic                      arb_read_ack,
    output logic [7:0]                arb_read_burst_len,
    output logic [DDR_ADDR_WIDTH-1:0] arb_read_start_addr,
    input  logic                      arb_read_done,
    input  logic                      arb_read_valid,
    input  logic [DDR_DATA_WIDTH-1:0] arb_data_in,
    // FIFO (Write clock domain)
    output logic                      fifo_write_rst_n,
    output logic                      fifo_write_en,
    output logic [DDR_DATA_WIDTH-1:0] fifo_write_data,
    // FIFO (Read clock domain)
    output logic                      fifo_read_rst_n,
    output logic                      fifo_read_en,
    input  logic                      fifo_read_valid,
    input  logic [DATA_OUT_WIDTH-1:0] fifo_read_data,
    input  logic                      fifo_empty,
    // Control and Status signals
    input  logic                      clear, // CDC
    output logic                      timeout_err
);

//------------------------------------------------------------------------------
// Local Parameters
//------------------------------------------------------------------------------
localparam integer MAX_TIMEOUT_COUNT  = TIMEOUT_USEC * DDR4_CLOCK_FREQ_MHZ;

//------------------------------------------------------------------------------
// Internal signals
//------------------------------------------------------------------------------
logic [1:0]                           dma_read_req_curr;
logic                                 dma_read_req_prev;
logic                                 dma_read_req_re; // rising edge

logic [1:0]                           ctrl_info_valid_sync;

logic [8:0]                           ctrl_burst_count_sync[2]; // [0:1]
logic [8:0]                           ctrl_burst_count_reg;

logic [DDR_ADDR_WIDTH-1:0]            ctrl_read_addr_sync[2]; // [0:1]
logic [DDR_ADDR_WIDTH-1:0]            ctrl_read_addr_reg;

logic [1:0]                           fifo_rst_n_sync_ctrl_domain;
logic [1:0]                           fifo_rst_n_sync_ddr_domain;

logic [31:0]                          timeout_counter;
logic [1:0]                           clear_sync_ddr_domain;

logic [1:0]                           user_rst_n_sync_ctrl_domain;
logic [1:0]                           user_rst_n_sync_ddr_domain;

//------------------------------------------------------------------------------
// Controller FSM definition
//------------------------------------------------------------------------------

typedef enum logic [2:0] {
    IDLE             = 3'd0, // Idle waiting for signal to start the ddr read
    READ_TRIG        = 3'd1, // Send a read req to ddr and wait for ack
    READING          = 3'd2, // Wait for DDR4 done signal
    WAIT_EXPORT_DONE = 3'd3,  // Populate total beats and wait for receiver done
    CLEAR_STATE      = 3'd4
} state_t;

state_t curr_state;
state_t next_state;

//------------------------------------------------------------------------------
// Continous signals (DDR clock domain)
//------------------------------------------------------------------------------
always_comb begin
    fifo_write_rst_n = ddr_rst_n &
                       fifo_rst_n_sync_ddr_domain[1] &
                       user_rst_n_sync_ddr_domain[1];

    fifo_write_en    = arb_read_valid;
    fifo_write_data  = arb_read_valid ? arb_data_in : 'b0;
end

//------------------------------------------------------------------------------
// Continous signals (Controller clock domain)
//------------------------------------------------------------------------------
always_comb begin
    fifo_read_rst_n   = ctrl_rst_n &
                        fifo_rst_n_sync_ctrl_domain[1] &
                        user_rst_n_sync_ctrl_domain[1];

    fifo_read_en      = m_axis_dma_tready;
    m_axis_dma_tvalid = fifo_read_valid;
    m_axis_dma_tdata  = fifo_read_valid ? fifo_read_data : 'b0;
end

//------------------------------------------------------------------------------
// FIFO Clear CDC Sync (Controller clock domain)
//------------------------------------------------------------------------------
always_ff @(posedge ctrl_clk, negedge ctrl_rst_n) begin
    if(~ctrl_rst_n) begin
        fifo_rst_n_sync_ctrl_domain  <= 2'b0;
        user_rst_n_sync_ctrl_domain  <= 2'b0;

    end else begin
        fifo_rst_n_sync_ctrl_domain  <= {
            fifo_rst_n_sync_ctrl_domain[0], ~dma_fifo_clear}; // Negated

        user_rst_n_sync_ctrl_domain  <= {
                user_rst_n_sync_ctrl_domain[0], ~clear}; // Negated
    end
end

//------------------------------------------------------------------------------
// Read enable rising edge detector
//------------------------------------------------------------------------------
always_ff @(posedge ddr_clk, negedge ddr_rst_n) begin
    if(~ddr_rst_n) begin
        dma_read_req_curr <= 2'b0;
        dma_read_req_prev <= 1'b0;
        dma_read_req_re   <= 1'b0;

    end else begin
        dma_read_req_curr <= {dma_read_req_curr[0], dma_read_req};
        dma_read_req_prev <= dma_read_req_curr[1];
        dma_read_req_re   <= (dma_read_req_curr[1]) & (~dma_read_req_prev);

    end
end

//------------------------------------------------------------------------------
// CDC Sync to ddr clock domain
//------------------------------------------------------------------------------
always_ff @(posedge ddr_clk, negedge ddr_rst_n) begin

    if(~ddr_rst_n) begin
        ctrl_info_valid_sync        <= 2'b0;
        ctrl_burst_count_sync       <= '{default: 1'b0};
        ctrl_read_addr_sync         <= '{default: 1'b0};
        clear_sync_ddr_domain       <= 2'b0;
        fifo_rst_n_sync_ddr_domain  <= 2'b0;
        user_rst_n_sync_ddr_domain  <= 2'b0;

        end else begin

            ctrl_info_valid_sync        <= {
                    ctrl_info_valid_sync[0], ctrl_info_valid};

            ctrl_burst_count_sync[0]    <= ctrl_burst_count;
            ctrl_burst_count_sync[1]    <= ctrl_burst_count_sync[0];

            ctrl_read_addr_sync[0]      <= ctrl_read_addr;
            ctrl_read_addr_sync[1]      <= ctrl_read_addr_sync[0];

            clear_sync_ddr_domain       <= {clear_sync_ddr_domain[0], clear};
            user_rst_n_sync_ddr_domain  <= {
                user_rst_n_sync_ddr_domain[0], ~clear}; // Negated

            fifo_rst_n_sync_ddr_domain  <= {
                fifo_rst_n_sync_ddr_domain[0], ~dma_fifo_clear}; // Negated
    end
end

//------------------------------------------------------------------------------
// Control capture registers
//------------------------------------------------------------------------------
always_ff @(posedge ddr_clk, negedge ddr_rst_n) begin
    if(~ddr_rst_n) begin
        ctrl_burst_count_reg  <= 0;
        ctrl_read_addr_reg    <= 0;
    end else begin
        // Only capture ctrl values when valid and ready are both asserted
        if(ctrl_info_valid_sync[1]) begin
            ctrl_burst_count_reg    <= ctrl_burst_count_sync[1];
            ctrl_read_addr_reg      <= ctrl_read_addr_sync[1];
        end else begin
            ctrl_burst_count_reg    <= ctrl_burst_count_reg;
            ctrl_read_addr_reg      <= ctrl_read_addr_reg;

        end
    end
end

//------------------------------------------------------------------------------
// MOOR FSM Sequential block
//------------------------------------------------------------------------------
always_ff @(posedge ddr_clk, negedge ddr_rst_n) begin
    if(~ddr_rst_n) begin
        curr_state          <= IDLE;
        dma_ready           <= 1'b0;
        dma_read_ack        <= 1'b0;
        arb_read_req        <= 1'b0;
        arb_read_burst_len  <= 'b0;
        arb_read_start_addr <= 'b0;
        timeout_counter     <= 'b0;
        timeout_err         <= 'b0;

    end else begin

        curr_state <= next_state;

        if(curr_state == IDLE) begin
            dma_ready       <= 1'b1;
            arb_read_req    <= 1'b0;
            dma_read_ack    <= 1'b0;
            timeout_counter <= 'b0;
            timeout_err     <= timeout_err;

            if(dma_read_req_re) begin
                if(ctrl_burst_count_reg == 0) begin
                    arb_read_burst_len  <= ctrl_burst_count_reg;
                end else begin
                    // AXI burst len is always 1 less than the total burst req
                    arb_read_burst_len  <= ctrl_burst_count_reg-1;
                end
                arb_read_start_addr     <= ctrl_read_addr_reg;
            end else begin
                arb_read_burst_len  <= 0;
                arb_read_start_addr <= 0;
            end

        end else if(curr_state == READ_TRIG) begin
            dma_ready           <= 1'b0;
            dma_read_ack        <= 1'b0;
            arb_read_burst_len  <= arb_read_burst_len;
            arb_read_start_addr <= arb_read_start_addr;

            if (timeout_counter >= MAX_TIMEOUT_COUNT-1) begin
                arb_read_req    <= 1'b0;
                timeout_counter <= 'b0;
                timeout_err     <= 1'b1;

            end else if(arb_read_ack) begin
                arb_read_req    <= 1'b0;
                timeout_counter <= 'b0;
                timeout_err     <= timeout_err;

            end else begin
                arb_read_req    <= 1'b1;
                timeout_counter <= timeout_counter + 1;
                timeout_err     <= timeout_err;
            end

        end else if (curr_state == READING) begin
            dma_ready           <= 1'b0;
            dma_read_ack        <= 1'b1;
            arb_read_req        <= 1'b0;
            arb_read_burst_len  <= arb_read_burst_len;
            arb_read_start_addr <= arb_read_start_addr;
            timeout_counter     <= timeout_counter + 1;

            if (timeout_counter >= MAX_TIMEOUT_COUNT-1) begin
                timeout_counter <= 'b0;
                timeout_err     <= 1'b1;
            end else begin
                timeout_counter <= timeout_counter + 1;
                timeout_err     <= timeout_err;
            end

        end else if (curr_state == WAIT_EXPORT_DONE) begin
            dma_ready           <= 1'b0;
            dma_read_ack        <= 1'b1;
            arb_read_req        <= 1'b0;
            arb_read_burst_len  <= arb_read_burst_len;
            arb_read_start_addr <= arb_read_start_addr;

            if (timeout_counter >= MAX_TIMEOUT_COUNT-1) begin
                timeout_counter <= 'b0;
                timeout_err     <= 1'b1;
            end else begin
                timeout_counter <= timeout_counter + 1;
                timeout_err     <= timeout_err;
            end

        end else if (curr_state == CLEAR_STATE) begin
            dma_ready           <= 1'b0;
            dma_read_ack        <= 1'b0;
            arb_read_req        <= 1'b0;
            arb_read_burst_len  <= 'b0;
            arb_read_start_addr <= 'b0;
            timeout_counter     <= 'b0;
            timeout_err         <= 'b0;

        end else begin
            dma_ready           <= 1'b0;
            dma_read_ack        <= 1'b0;
            arb_read_req        <= 1'b0;
            arb_read_burst_len  <= 0;
            arb_read_start_addr <= 0;
            timeout_counter     <= 'b0;
            timeout_err         <= 'b0;

        end

    end
end

//------------------------------------------------------------------------------
// MOOR FSM Combinational block
//------------------------------------------------------------------------------
always_comb begin

    next_state = curr_state;

    case(curr_state)

        IDLE: begin
            if (clear_sync_ddr_domain[1]) begin
                next_state = CLEAR_STATE;
            end else if(dma_read_req_re) begin
                next_state = READ_TRIG;
            end else begin
                next_state = IDLE;
            end
        end

        READ_TRIG: begin
            if (clear_sync_ddr_domain[1]) begin
                next_state = CLEAR_STATE;
            end else if(arb_read_ack) begin
                next_state = READING;
            end else if (timeout_counter >= MAX_TIMEOUT_COUNT-1) begin
                next_state = IDLE;
            end else begin
                next_state = READ_TRIG;
            end
        end

        READING: begin
            if (clear_sync_ddr_domain[1]) begin
                next_state = CLEAR_STATE;
            end else if(arb_read_done) begin
                next_state = WAIT_EXPORT_DONE;
            end else if (timeout_counter >= MAX_TIMEOUT_COUNT-1) begin
                next_state = IDLE;
            end else begin
                next_state = READING;
            end
        end

        WAIT_EXPORT_DONE: begin
            if (clear_sync_ddr_domain[1]) begin
                next_state = CLEAR_STATE;
            end else if (fifo_empty) begin
                next_state = IDLE;
            end else if (timeout_counter >= MAX_TIMEOUT_COUNT-1) begin
                next_state = IDLE;
            end else begin
                next_state = WAIT_EXPORT_DONE;
            end
        end

        CLEAR_STATE: begin
            if (clear_sync_ddr_domain[1]) begin
                next_state = CLEAR_STATE;
            end else begin
                next_state = IDLE;
            end
        end

        default: begin
            next_state = IDLE;
        end

    endcase
end

endmodule
