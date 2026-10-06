/*
 * @file      dma_read_ctrl_apb_reg.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      11/11/2025
 *
 * @brief
 *
 * @section changelog
 * - 11/11/2025: Saba Janamian - Initial implementation
 *
 */

module dma_read_ctrl_apb_reg #(
    parameter integer APB_DATA_WIDTH    = 32,
    parameter integer APB_ADDR_WIDTH    = 32,
    parameter integer FRAME_INDEX_WIDTH = 8,
    parameter integer METADATA_WIDTH    = 640
)(
    // APB Slave interface
    input  logic                         pclk,     // APB clock
    input  logic                         presetn,  // APB resetn
    input  logic                         penable,  // APB enable
    input  logic                         psel,     // APB periph select
    input  logic [APB_ADDR_WIDTH-1:0]    paddr,    // APB address bus
    input  logic                         pwrite,   // APB write req
    input  logic [APB_DATA_WIDTH-1:0]    pwdata,   // APB write data
    output logic [APB_DATA_WIDTH-1:0]    prdata,   // APB read data
    output logic                         pready,   // APB ready signal
    output logic                         pslverr,  // APB error signal
    // DMA_CTRL_INTF
    output logic                         clear,
    output logic [FRAME_INDEX_WIDTH-1:0] frame_index,
    input  logic                         frame_read_done, // CDC
    output logic                         frame_read_req,
    output logic                         frame_read_done_int,
    output logic                         udp_metadata_sel,
    output logic [8:0]                   h_size_beat,
    output logic [13:0]                  h_size_byte,
    output logic                         jumbo_en,
    output logic [12:0]                  v_size_line,
    // APB_REG_ERR_INTF
    input  logic [31:0]                  frame_xfer_timeout_err, // CDC
    input  logic [31:0]                  dma_timeout_err,        // CDC
    input  logic [31:0]                  pyl_acpt_err,           // CDC
    input  logic [31:0]                  send_last_err,          // CDC
    input  logic [31:0]                  send_pyl_err,           // CDC
    input  logic [31:0]                  sof_req_err,            // CDC
    input  logic [31:0]                  wait_ack_err,           // CDC
    // Metadata capture interface (from dma_read_ctrl, CDC)
    input  logic [METADATA_WIDTH-1:0]    metadata_data,
    input  logic                         metadata_valid
);

//------------------------------------------------------------------------------
// Register address definitions
//------------------------------------------------------------------------------

localparam integer ADDR_CLEAR                  = 'd0; // Clear UDP ctrl hardware
localparam integer ADDR_FRAME_INDEX            = 'd1;
localparam integer ADDR_FRAME_READ_DONE_COUNT  = 'd2;  // RO
localparam integer ADDR_FRAME_READ_REQ         = 'd3;
localparam integer ADDR_H_SIZE_BEAT            = 'd4;
localparam integer ADDR_H_SIZE_BYTE            = 'd5;
localparam integer ADDR_JUMBO_EN               = 'd6;
localparam integer ADDR_V_SIZE_LINE            = 'd7;
localparam integer ADDR_DMA_TIMEOUT_ERR        = 'd8;  // RO
localparam integer ADDR_PYL_ACPT_ERR           = 'd9;  // RO
localparam integer ADDR_SEND_LAST_ERR          = 'd10; // RO
localparam integer ADDR_SEND_PYL_ERR           = 'd11; // RO
localparam integer ADDR_SOF_REQ_ERR            = 'd12; // RO
localparam integer ADDR_WAIT_ACK_ERR           = 'd13; // RO
localparam integer ADDR_FRAME_XFER_TIMEOUT_ERR = 'd14; // RO
localparam integer ADDR_RESET_DONE_COUNTER     = 'd15;
localparam integer ADDR_UDP_METADATA_SEL       = 'd16;
localparam integer ADDR_FRAME_READ_DONE_INT    = 'd17; // R: latched IRQ, W1C: clear
localparam integer ADDR_METADATA_DATA_BASE     = 'd18; // 18..37 → 20 RO registers
localparam integer METADATA_WORDS              = METADATA_WIDTH / APB_DATA_WIDTH; // 20

localparam integer NUM_REGS                   = 64;
localparam integer REG_WIDTH                  = $clog2(NUM_REGS);

localparam integer UNUSED_FRAME_INDEX = APB_DATA_WIDTH - FRAME_INDEX_WIDTH;
//------------------------------------------------------------------------------
// Register space
//------------------------------------------------------------------------------
logic [APB_DATA_WIDTH-1:0] mem[NUM_REGS];


//------------------------------------------------------------------------------
// Internal registers
//------------------------------------------------------------------------------
logic [1:0]  frame_read_done_curr;
logic        frame_read_done_prev;
logic        frame_read_done_re;
logic [31:0] frame_read_done_counter;
logic        reset_done_counter;
logic        frame_read_done_int_clear;

logic [31:0] frame_xfer_timeout_err_sync[2]; // [0:1]
logic [31:0] dma_timeout_err_sync[2];
logic [31:0] pyl_acpt_err_sync[2];
logic [31:0] send_last_err_sync[2];
logic [31:0] send_pyl_err_sync[2];
logic [31:0] sof_req_err_sync[2];
logic [31:0] wait_ack_err_sync[2];

logic [1:0]  metadata_valid_sync;
logic        metadata_valid_prev;
logic        metadata_valid_re;
//------------------------------------------------------------------------------
// APB write and read register logic
//------------------------------------------------------------------------------
always_ff @(posedge pclk or negedge presetn) begin
    if(~presetn) begin
        prdata        <= 'b0;
        pready        <= 'b0;
        pslverr       <= 'b0;
        mem           <= '{default: 1'b0};

    end else begin
        pslverr <= 'b0; // Not used
        frame_read_done_int_clear <= 'b0; // Default: deassert W1C pulse every cycle

        // Input signals to Mem
        mem[ADDR_DMA_TIMEOUT_ERR]        <= dma_timeout_err_sync[1];
        mem[ADDR_PYL_ACPT_ERR]           <= pyl_acpt_err_sync[1];
        mem[ADDR_SEND_LAST_ERR]          <= send_last_err_sync[1];
        mem[ADDR_SEND_PYL_ERR]           <= send_pyl_err_sync[1];
        mem[ADDR_SOF_REQ_ERR]            <= sof_req_err_sync[1];
        mem[ADDR_WAIT_ACK_ERR]           <= wait_ack_err_sync[1];
        mem[ADDR_FRAME_XFER_TIMEOUT_ERR] <= frame_xfer_timeout_err_sync[1];
        mem[ADDR_FRAME_READ_DONE_COUNT]  <= frame_read_done_counter;

        // Latch metadata_data into registers on rising edge of synced valid
        if (metadata_valid_re) begin
            for (int i = 0; i < METADATA_WORDS; i++) begin
                mem[ADDR_METADATA_DATA_BASE + i] <=
                    metadata_data[i * APB_DATA_WIDTH +: APB_DATA_WIDTH];
            end
        end

        // APB Write operation
        if(psel && penable && pwrite && paddr[1:0] == 'b0) begin
            prdata  <= 'b0;
            pready  <= 'b1;  // Indicate done

            case(paddr[7:2])
                ADDR_CLEAR: begin
                    mem[ADDR_CLEAR]          <= {31'b0, pwdata[0:0]};
                end

                ADDR_FRAME_INDEX: begin
                    mem[ADDR_FRAME_INDEX] <= {
                        {UNUSED_FRAME_INDEX{1'b0}},
                        pwdata[FRAME_INDEX_WIDTH-1:0]};
                end

                ADDR_FRAME_READ_DONE_COUNT: begin
                    // Read only
                end

                ADDR_FRAME_READ_REQ: begin
                    mem[ADDR_FRAME_READ_REQ] <= {31'b0, pwdata[0:0]};
                end

                ADDR_H_SIZE_BEAT: begin
                    mem[ADDR_H_SIZE_BEAT]    <= {23'b0, pwdata[8:0]};
                end

                ADDR_H_SIZE_BYTE: begin
                    mem[ADDR_H_SIZE_BYTE]    <= {18'b0, pwdata[13:0]};
                end

                ADDR_JUMBO_EN: begin
                    mem[ADDR_JUMBO_EN]       <= {31'b0, pwdata[0:0]};
                end

                ADDR_V_SIZE_LINE: begin
                    mem[ADDR_V_SIZE_LINE]    <= {18'b0, pwdata[12:0]};
                end

                ADDR_DMA_TIMEOUT_ERR: begin
                    // Read only
                end

                ADDR_PYL_ACPT_ERR: begin
                    // Read only
                end

                ADDR_SOF_REQ_ERR: begin
                    // Read only
                end

                ADDR_SEND_LAST_ERR: begin
                    // Read only
                end

                ADDR_SEND_PYL_ERR: begin
                    // Read only
                end

                ADDR_WAIT_ACK_ERR: begin
                    // Read only
                end

                ADDR_FRAME_XFER_TIMEOUT_ERR: begin
                    // Read only
                end

                ADDR_RESET_DONE_COUNTER: begin
                    mem[ADDR_RESET_DONE_COUNTER] <= {31'b0, pwdata[0:0]};
                end

                ADDR_UDP_METADATA_SEL: begin
                    mem[ADDR_UDP_METADATA_SEL]   <= {31'b0, pwdata[0:0]};
                end

                ADDR_FRAME_READ_DONE_INT: begin
                    // Write-1-to-clear the latched interrupt. Nothing stored
                    // in mem; pulse the clear signal for the latch below.
                    frame_read_done_int_clear <= pwdata[0];
                end

                default: begin
                    pslverr <= 'b0;
                end
            endcase

        // APB READ operation
        end else if(psel && penable && !pwrite && paddr[1:0] == 'b0) begin
            pready  <= 'b1; // Indicate done

            case(paddr[7:2])
                ADDR_CLEAR: begin
                    prdata <= {31'b0, mem[ADDR_CLEAR][0:0]};
                end

                ADDR_FRAME_INDEX: begin
                    prdata <= {
                        {UNUSED_FRAME_INDEX{1'b0}},
                        mem[ADDR_FRAME_INDEX][FRAME_INDEX_WIDTH-1:0]};
                end

                ADDR_FRAME_READ_DONE_COUNT: begin
                    prdata <= mem[ADDR_FRAME_READ_DONE_COUNT];
                end

                ADDR_FRAME_READ_REQ: begin
                    prdata <= {31'b0, mem[ADDR_FRAME_READ_REQ][0:0]};
                end

                ADDR_H_SIZE_BEAT: begin
                    prdata <= {23'b0, mem[ADDR_H_SIZE_BEAT][8:0]};
                end

                ADDR_H_SIZE_BYTE: begin
                    prdata <= {18'b0, mem[ADDR_H_SIZE_BYTE][13:0]};
                end

                ADDR_JUMBO_EN: begin
                    prdata <= {31'b0, mem[ADDR_JUMBO_EN][0:0]};
                end

                ADDR_V_SIZE_LINE: begin
                    prdata <= {18'b0, mem[ADDR_V_SIZE_LINE][12:0]};
                end

                ADDR_DMA_TIMEOUT_ERR: begin
                    prdata <= mem[ADDR_DMA_TIMEOUT_ERR];
                end

                ADDR_PYL_ACPT_ERR: begin
                    prdata <= mem[ADDR_PYL_ACPT_ERR];
                end

                ADDR_SOF_REQ_ERR: begin
                    prdata <= mem[ADDR_SOF_REQ_ERR];
                end

                ADDR_SEND_LAST_ERR: begin
                    prdata <= mem[ADDR_SEND_LAST_ERR];
                end

                ADDR_SEND_PYL_ERR: begin
                    prdata <= mem[ADDR_SEND_PYL_ERR];
                end

                ADDR_WAIT_ACK_ERR: begin
                    prdata <= mem[ADDR_WAIT_ACK_ERR];
                end

                ADDR_FRAME_XFER_TIMEOUT_ERR: begin
                    prdata <= mem[ADDR_FRAME_XFER_TIMEOUT_ERR];
                end

                ADDR_RESET_DONE_COUNTER: begin
                    prdata <= {31'b0, mem[ADDR_RESET_DONE_COUNTER][0:0]};
                end

                ADDR_UDP_METADATA_SEL: begin
                    prdata <= {31'b0, mem[ADDR_UDP_METADATA_SEL][0:0]};
                end

                ADDR_FRAME_READ_DONE_INT: begin
                    prdata <= {31'b0, frame_read_done_int};
                end

                default: begin
                    // Metadata data range (RO): addresses 18..37
                    if (paddr[7:2] >= ADDR_METADATA_DATA_BASE &&
                        paddr[7:2] <  ADDR_METADATA_DATA_BASE + METADATA_WORDS) begin
                        prdata <= mem[paddr[7:2]];
                    end else begin
                        pslverr <= 'b0;
                    end
                end
            endcase

        end else begin
            pready             <= 'b0;
            prdata             <= 'b0;
            pslverr            <= 'b0;
        end
    end
end

//------------------------------------------------------------------------------
// Output controler
//------------------------------------------------------------------------------
always_ff @(posedge pclk or negedge presetn) begin
    if(~presetn) begin
        clear            <= 'b0;
        frame_index      <= 'b0;
        frame_read_req   <= 'b0;
        udp_metadata_sel <= 'b0;
        h_size_beat      <= 'b0;
        h_size_byte      <= 'b0;
        jumbo_en         <= 'b0;
        v_size_line      <= 'b0;

    end else begin

        clear                     <= mem[ADDR_CLEAR];
        frame_index               <= mem[ADDR_FRAME_INDEX];
        frame_read_req            <= mem[ADDR_FRAME_READ_REQ];
        udp_metadata_sel          <= mem[ADDR_UDP_METADATA_SEL];
        h_size_beat               <= mem[ADDR_H_SIZE_BEAT];
        h_size_byte               <= mem[ADDR_H_SIZE_BYTE];
        jumbo_en                  <= mem[ADDR_JUMBO_EN];
        v_size_line               <= mem[ADDR_V_SIZE_LINE];

    end
end

always_ff @(posedge pclk, negedge presetn) begin
    if(~presetn) begin
        frame_read_done_curr    <= 'b0;
        frame_read_done_prev    <= 'b0;
        frame_read_done_counter <= 'b0;
        frame_read_done_re      <= 'b0;
        reset_done_counter      <= 'b0;
    end else begin
        frame_read_done_curr <= {frame_read_done_curr[0], frame_read_done};
        frame_read_done_prev <= frame_read_done_curr[1];
        frame_read_done_re   <= frame_read_done_curr[1] & (~frame_read_done_prev);
        reset_done_counter   <= mem[ADDR_RESET_DONE_COUNTER][0:0];

        if (reset_done_counter) begin
            frame_read_done_counter <= 'b0;
        end else if(frame_read_done_re) begin
            frame_read_done_counter <= frame_read_done_counter + 1;
        end else begin
            frame_read_done_counter <= frame_read_done_counter;
        end
    end
end

// frame_read_done_int: sticky interrupt, set on rising edge of frame_read_done,
//                      held until firmware acknowledges via write-1-to-clear
//                      (ADDR_FRAME_READ_DONE_INT). A set event takes priority
//                      over a simultaneous clear so no event is lost.
always_ff @(posedge pclk, negedge presetn) begin
    if(~presetn) begin
        frame_read_done_int     <= 'b0;
    end else begin
        if (frame_read_done_re) begin
            frame_read_done_int <= 'b1;
        end else if (frame_read_done_int_clear) begin
            frame_read_done_int <= 'b0;
        end
    end
end

//------------------------------------------------------------------------------
// CDC Sync
//------------------------------------------------------------------------------
always_ff @(posedge pclk, negedge presetn) begin
    if(~presetn) begin
        frame_xfer_timeout_err_sync    <= '{default: 1'b0};
        dma_timeout_err_sync           <= '{default: 1'b0};
        pyl_acpt_err_sync              <= '{default: 1'b0};
        send_last_err_sync             <= '{default: 1'b0};
        send_pyl_err_sync              <= '{default: 1'b0};
        sof_req_err_sync               <= '{default: 1'b0};
        wait_ack_err_sync              <= '{default: 1'b0};
        metadata_valid_sync            <= 2'b0;
        metadata_valid_prev            <= 1'b0;
        metadata_valid_re              <= 1'b0;

    end else begin

        frame_xfer_timeout_err_sync[0] <= frame_xfer_timeout_err;
        frame_xfer_timeout_err_sync[1] <= frame_xfer_timeout_err_sync[0];
        dma_timeout_err_sync[0]        <= dma_timeout_err;
        dma_timeout_err_sync[1]        <= dma_timeout_err_sync[0];
        pyl_acpt_err_sync[0]           <= pyl_acpt_err;
        pyl_acpt_err_sync[1]           <= pyl_acpt_err_sync[0];
        send_last_err_sync[0]          <= send_last_err;
        send_last_err_sync[1]          <= send_last_err_sync[0];
        send_pyl_err_sync[0]           <= send_pyl_err;
        send_pyl_err_sync[1]           <= send_pyl_err_sync[0];
        sof_req_err_sync[0]            <= sof_req_err;
        sof_req_err_sync[1]            <= sof_req_err_sync[0];
        wait_ack_err_sync[0]           <= wait_ack_err;
        wait_ack_err_sync[1]           <= wait_ack_err_sync[0];

        metadata_valid_sync[0]         <= metadata_valid;
        metadata_valid_sync[1]         <= metadata_valid_sync[0];
        metadata_valid_prev            <= metadata_valid_sync[1];
        metadata_valid_re              <= metadata_valid_sync[1] & ~metadata_valid_prev;

    end
end


endmodule
