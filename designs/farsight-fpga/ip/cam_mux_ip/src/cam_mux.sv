/*
 * @file      cam_mux.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      10/17/2025
 *
 * @brief     MUX with 2 clk cycle latency for Frame valid to redirect the CAM
 *            output to either DDR4 8GB or DDR4 16GB memory space.
 *
 * @section changelog
 * - 10/17/2025: Saba Janamian - Initial implementation
 * - 04/30/2026: Steven Knyazher - Added automated switching between the two DDR4
 *
 */

module cam_mux #(
    parameter DATA_WIDTH = 384
)(
    // Clock and Reset
    input  logic                  pixel_clk,
    input  logic                  pixel_rst_n,

    // Cam input interface
    input  logic                  frame_valid_in,
    input  logic                  line_valid_in,
    input  logic [DATA_WIDTH-1:0] cam_data_in,

    // APB Reg control interface
    input  logic                  mux_clear,

    // Cam status
    output logic                  mux_enable,
    output logic                  mux_select,
    output logic                  ddr4_16gb_full,
    output logic                  ddr4_8gb_full,
    output logic                  mux_clear_ack,

    // Cam to DDR4 8GB
    output logic                  ddr4_8gb_frame_valid_out,
    output logic                  ddr4_8gb_line_valid_out,
    output logic [DATA_WIDTH-1:0] ddr4_8gb_cam_data_out,

    // Cam to DDR4 16GB
    output logic                  ddr4_16gb_frame_valid_out,
    output logic                  ddr4_16gb_line_valid_out,
    output logic [DATA_WIDTH-1:0] ddr4_16gb_cam_data_out
);

//------------------------------------------------------------------------------
// Local parameters
//------------------------------------------------------------------------------
localparam logic DDR4_8GB  = 1'b0;
localparam logic DDR4_16GB = 1'b1;

//------------------------------------------------------------------------------
// Internal signals
//------------------------------------------------------------------------------
logic       frame_valid_in_curr;
logic       frame_valid_in_prev;
logic       frame_valid_in_re;
logic       frame_valid_in_fe;

logic [1:0] mux_clear_sync;
logic       mux_clear_sync_d;

logic       mux_enable_reg;
logic       mux_select_reg;

logic [8:0] ddr4_16gb_cnt;
logic [7:0] ddr4_8gb_cnt;

logic       en;
logic       sel;

//------------------------------------------------------------------------------
// FSM States Definition
//------------------------------------------------------------------------------
typedef enum logic [2:0] {
    IDLE                      = 3'd0,
    WAIT_FRAME_START          = 3'd1,
    FWD_TO_DDR4_8GB           = 3'd2,
    FWD_TO_DDR4_16GB          = 3'd3,
    WAIT_FRAME_END_DDR4_8GB   = 3'd4,
    WAIT_FRAME_END_DDR4_16GB  = 3'd5
} state_t;

state_t curr_state;
state_t next_state;

//------------------------------------------------------------------------------
// Registered MUX outputs (for CDC between pixel clk and DDR4 clocks)
//------------------------------------------------------------------------------
always_ff @(posedge pixel_clk, negedge pixel_rst_n) begin
    if (~pixel_rst_n) begin
        ddr4_8gb_frame_valid_out   <= 'b0;
        ddr4_8gb_line_valid_out    <= 'b0;
        ddr4_8gb_cam_data_out      <= 'b0;

        ddr4_16gb_frame_valid_out  <= 'b0;
        ddr4_16gb_line_valid_out   <= 'b0;
        ddr4_16gb_cam_data_out     <= 'b0;

    end else if (~en) begin
        ddr4_8gb_frame_valid_out   <= 'b0;
        ddr4_8gb_line_valid_out    <= 'b0;
        ddr4_8gb_cam_data_out      <= 'b0;

        ddr4_16gb_frame_valid_out  <= 'b0;
        ddr4_16gb_line_valid_out   <= 'b0;
        ddr4_16gb_cam_data_out     <= 'b0;

    end else if (sel == DDR4_8GB) begin
        ddr4_8gb_frame_valid_out   <= frame_valid_in;
        ddr4_8gb_line_valid_out    <= line_valid_in;
        ddr4_8gb_cam_data_out      <= cam_data_in;

        ddr4_16gb_frame_valid_out  <= 'b0;
        ddr4_16gb_line_valid_out   <= 'b0;
        ddr4_16gb_cam_data_out     <= 'b0;

    end else if (sel == DDR4_16GB) begin
        ddr4_8gb_frame_valid_out   <= 'b0;
        ddr4_8gb_line_valid_out    <= 'b0;
        ddr4_8gb_cam_data_out      <= 'b0;

        ddr4_16gb_frame_valid_out  <= frame_valid_in;
        ddr4_16gb_line_valid_out   <= line_valid_in;
        ddr4_16gb_cam_data_out     <= cam_data_in;

    end else begin
        ddr4_8gb_frame_valid_out   <= 'b0;
        ddr4_8gb_line_valid_out    <= 'b0;
        ddr4_8gb_cam_data_out      <= 'b0;

        ddr4_16gb_frame_valid_out  <= 'b0;
        ddr4_16gb_line_valid_out   <= 'b0;
        ddr4_16gb_cam_data_out     <= 'b0;
    end
end

//------------------------------------------------------------------------------
// Mealy FSM logic
//------------------------------------------------------------------------------
always_ff @(posedge pixel_clk, negedge pixel_rst_n) begin
    if (~pixel_rst_n) begin
        curr_state  <= IDLE;
    end else begin
        curr_state  <= next_state;
    end
end

always_comb begin

    next_state = curr_state;
    en = 'b0;
    sel = 'b0;

    case(curr_state)
        IDLE: begin
            en  = 'b0;
            sel = 'b0;

            if (mux_enable_reg) begin
                next_state = WAIT_FRAME_START;
            end else begin
                next_state = IDLE;
            end
        end

        WAIT_FRAME_START: begin
            if (~mux_enable_reg) begin
                next_state = IDLE;
                en         = 'b0;
                sel        = 'b0;
            end else if (frame_valid_in_re && (mux_select_reg == DDR4_8GB)) begin
                next_state = FWD_TO_DDR4_8GB;
                en         = 'b1;
                sel        = DDR4_8GB;
            end else if (frame_valid_in_re && (mux_select_reg == DDR4_16GB)) begin
                next_state = FWD_TO_DDR4_16GB;
                en         = 'b1;
                sel        = DDR4_16GB;
            end else begin
                next_state = WAIT_FRAME_START;
                en         = 'b0;
                sel        = 'b0;
            end
        end

        FWD_TO_DDR4_8GB: begin
            en         = 'b1;
            sel        = DDR4_8GB;

            if (~mux_enable_reg) begin
                next_state = WAIT_FRAME_END_DDR4_8GB;
            end else if (mux_select_reg == DDR4_16GB) begin
                next_state = WAIT_FRAME_END_DDR4_8GB;
            end else begin
                next_state = FWD_TO_DDR4_8GB;
            end
        end

        FWD_TO_DDR4_16GB: begin
                en         = 'b1;
                sel        = DDR4_16GB;

            if (~mux_enable_reg) begin
                next_state = WAIT_FRAME_END_DDR4_16GB;
            end else if (mux_select_reg == DDR4_8GB) begin
                next_state = WAIT_FRAME_END_DDR4_16GB;
            end else begin
                next_state = FWD_TO_DDR4_16GB;
            end
        end

        WAIT_FRAME_END_DDR4_8GB: begin
            en         = 'b1;
            sel        = DDR4_8GB;

            if (~frame_valid_in_prev) begin
                next_state = IDLE;
            end else begin
                next_state = WAIT_FRAME_END_DDR4_8GB;
            end
        end

        WAIT_FRAME_END_DDR4_16GB: begin
            en         = 'b1;
            sel        = DDR4_16GB;

            if (~frame_valid_in_prev) begin
                next_state = IDLE;
            end else begin
                next_state = WAIT_FRAME_END_DDR4_16GB;
            end
        end

        default: begin
            next_state = IDLE;
            en         = 'b0;
            sel        = 'b0;
        end
    endcase

end

//------------------------------------------------------------------------------
// CDC Synchornizer
//------------------------------------------------------------------------------
always_ff @(posedge pixel_clk, negedge pixel_rst_n) begin
    if (~pixel_rst_n) begin
        mux_clear_sync <= 2'b0;
    end else begin
        mux_clear_sync <= {mux_clear_sync[0], mux_clear};
    end
end

//------------------------------------------------------------------------------
// Cam status
//------------------------------------------------------------------------------
always_ff @(posedge pixel_clk, negedge pixel_rst_n) begin
    if (~pixel_rst_n) begin
        mux_clear_sync_d <= 'b0;
        mux_clear_ack    <= 'b0;
        mux_enable_reg   <= 1'b0;
        mux_select_reg   <= 1'b0;
        ddr4_16gb_full   <= 1'b0;
        ddr4_8gb_full    <= 1'b0;
        ddr4_16gb_cnt    <= '0;
        ddr4_8gb_cnt     <= '0;
    end else begin
        mux_clear_sync_d <= mux_clear_sync[1];

        if (~mux_clear_sync_d && mux_clear_sync[1]) begin
            mux_enable_reg <= 'b1;
            mux_select_reg <= 'b1;
            ddr4_16gb_full <= 'b0;
            ddr4_8gb_full  <= 'b0;
            ddr4_16gb_cnt  <= 'b0;
            ddr4_8gb_cnt   <= 'b0;
            mux_clear_ack  <= 1'b1;
        end else if (mux_clear_sync_d && ~mux_clear_sync[1]) begin
            mux_clear_ack  <= 1'b0;
        end else begin
            if (frame_valid_in_fe) begin
                if (sel == DDR4_16GB) begin
                    if (&ddr4_16gb_cnt) begin
                        ddr4_16gb_full <= 'b1;
                        mux_enable_reg <= 'b1;
                        mux_select_reg <= DDR4_8GB;
                    end else begin
                        ddr4_16gb_cnt  <= ddr4_16gb_cnt + 1'b1;
                        ddr4_16gb_full <= 'b0;
                    end
                end else begin
                    if (&ddr4_8gb_cnt) begin
                        ddr4_8gb_full  <= 'b1;
                        mux_enable_reg <= 'b0;
                        mux_select_reg <= 'b0;
                    end else begin
                        ddr4_8gb_cnt   <= ddr4_8gb_cnt + 1'b1;
                        ddr4_8gb_full  <= 'b0;
                    end
                end
            end
        end
    end
end

assign mux_enable = mux_enable_reg;
assign mux_select = mux_select_reg;

//------------------------------------------------------------------------------
// Edge detector
//------------------------------------------------------------------------------
always_ff @(posedge pixel_clk, negedge pixel_rst_n) begin
    if (~pixel_rst_n) begin
        frame_valid_in_curr <= 1'b0;
        frame_valid_in_prev <= 1'b0;
        frame_valid_in_re   <= 1'b0;
        frame_valid_in_fe   <= 1'b0;
    end else begin
        frame_valid_in_curr <= frame_valid_in;
        frame_valid_in_prev <= frame_valid_in_curr;
        frame_valid_in_re   <= frame_valid_in_curr & (~frame_valid_in_prev);
        frame_valid_in_fe   <= (~frame_valid_in_curr) & frame_valid_in_prev;
    end
end

endmodule
