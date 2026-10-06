/*******************************************************************************
 * @file      dma_read_ctrl.sv
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      09/29/2025
 *
 * @brief     Controller FSM for requesting packets from DMA and forwarding to
 *            the UDP core.
 *
 * @section changelog
 * - 09/29/2025: Saba Janamian - Initial implementation
 *
*******************************************************************************/

module dma_read_ctrl #(
    parameter  integer CLOCK_FREQ_MHZ = 100,
    parameter  integer TIMEOUT_USEC   = 10_000, // 10 mSec
    parameter  integer IN_DATA_W      = 32,
    parameter  integer OUT_DATA_W     = 32,
    parameter  integer TKEEP_W        = OUT_DATA_W/8,
    parameter  integer METADATA_WIDTH = 640
)(
    input  logic                      clk,
    input  logic                      rst_n,
    input  logic                      clear,
    // frame_xfer_ctrl interface
    input  logic                      dma_ctrl_read_req, // (CDC)
    output logic                      dma_ctrl_read_ack,
    output logic                      dma_ctrl_read_done, // UDP done receiving packets
    input  logic [13:0]               dma_ctrl_pyl_size_word, // Num of 32 bits log2((2^16/4))(CDC)
    input  logic                      dma_ctrl_jumbo_en, // (CDC)
    input  logic [15:0]               dma_ctrl_line_index, // (CDC)
    // DMA Read info set interface
    output logic                      dma_read_req, // Send read req to DMA
    input  logic                      dma_read_ack, // (CDC)
    // DMA Read FIFO interface
    output logic                      s_axis_dma_tready, // DMA FIFO read enable
    input  logic                      s_axis_dma_tvalid, // DMA FIFO data valid (CDC)
    input  logic [IN_DATA_W-1:0]      s_axis_dma_tdata,  // DMA FIFO data input (CDC)
    // UDP IP Payload interface
    output logic                      m_axis_udp_pyl_tvalid,
    input  logic                      m_axis_udp_pyl_tready,
    output logic [OUT_DATA_W-1:0]     m_axis_udp_pyl_tdata,
    output logic [TKEEP_W-1:0]        m_axis_udp_pyl_tkeep,
    output logic                      m_axis_udp_pyl_tlast,
    // UDP IP Payload size interface
    output logic                      m_axis_udp_pyl_size_tvalid,
    input  logic                      m_axis_udp_pyl_size_tready,
    output logic [15:0]               m_axis_udp_pyl_size_tdata,
    // UDP IP Control interface
    output logic                      sof_req,
    input  logic                      eof_ack,
    input  logic                      pyl_acpt,
    input  logic                      core_busy,
    // Status signals
    output logic [31:0]               sof_req_err,
    output logic [31:0]               pyl_acpt_err,
    output logic [31:0]               send_pyl_err,
    output logic [31:0]               send_last_err,
    output logic [31:0]               wait_ack_err,
    output logic [31:0]               dma_timeout_err,
    // Metadata capture interface
    input  logic                      udp_metadata_sel,
    output logic [METADATA_WIDTH-1:0] metadata_data,
    output logic                      metadata_valid
);

//------------------------------------------------------------------------------
// Local parameters
//------------------------------------------------------------------------------
localparam integer MAX_TIMEOUT                 = CLOCK_FREQ_MHZ * TIMEOUT_USEC;
localparam logic [15:0] CHKSUM_PLACE_HOLDER    = 16'h0000; // Place holder
localparam logic [15:0] UDP_PKT_START_TOKEN    = 16'h504B; // ASCII 'PK'
// localparam logic [15:0] UDP_PKT_START_TOKEN = 16'h4B50; // 'PK' little endian


// Eth frame header + IPV4 header + UDP header total size
// 14 bytes         + 20 bytes    + 8 bytes = 42 bytes
//
// The UDP core requires 2 bytes of check sum and 2 bytes of extra UDP
// UDP payload start token for the first item.
// There is also 4 bytes of metadata which includes the 16 bit line index
// and 16 bits of UDP packet sequence count.
// Therefore all generated payload data must be less than
// TOTAL Eth Frame size + 2 extra start token + 4 bytes of metadata
// pluse header size (42 bytes).

// Standard frame: (363*4)+2+4+42 = 1500 Bytes
localparam integer MAX_STD_FRM      = 363;

// Jumbo frame   : (988*4)+2+4+42 = 4000 Bytes
localparam integer MAX_JMB_FRM      = 988;

// UDP packet start tocken size in bytes
localparam integer PKT_TOKEN_SIZE   = 6; // 2 Bytes start token + 4 Bytes info

// Time delay of FIFO empty signal
localparam FIFO_EMPTY_OFFSET_DELAY  = 4;

// Time delay of data valid
localparam DATA_OUT_OFFSET_DELAY    = 2;

// Number of 32-bit words in metadata
localparam integer METADATA_WORDS   = METADATA_WIDTH / IN_DATA_W; // 20 words

//------------------------------------------------------------------------------
// Internal signals
//------------------------------------------------------------------------------
logic [31:0]               timeout_counter; // Primary timeout counter
logic [31:0]               chunk;

logic [1:0]                clear_sync;

logic [1:0]                dma_read_ack_sync;

logic [1:0]                dma_ctrl_jumbo_en_sync;
logic                      dma_ctrl_jumbo_en_reg;

logic [1:0]                s_axis_dma_tvalid_sync;
logic [IN_DATA_W-1:0]      s_axis_dma_tdata_sync[2]; // [0:1]

logic                      dma_ctrl_read_req_curr;
logic                      dma_ctrl_read_req_prev;
logic                      dma_ctrl_read_req_re;

logic [15:0]               dma_ctrl_line_index_sync[2]; // [0:1]

logic [13:0]               dma_ctrl_pyl_size_word_sync[2]; // [0:1]

logic [15:0]               udp_pyl_size_byte_reg; // Counter for UDP Byte
logic [13:0]               udp_pyl_size_word_reg; // Counter for words xfer
logic [13:0]               max_pyl_size_word_reg; // Total number of req words

logic                      dma_ctrl_ready;
logic [15:0]               line_index;
logic [15:0]               pkt_count;

logic [1:0]                udp_metadata_sel_sync;
logic [5:0]                meta_word_count;
logic [METADATA_WIDTH-1:0] metadata_reg;
//------------------------------------------------------------------------------
// FSM state definition
//------------------------------------------------------------------------------
typedef enum logic [3:0] {
    CLEAR              = 4'd0,
    IDLE               = 4'd1,
    CALC_UDP_PYL_SIZE  = 4'd2,
    WAIT_FOR_DMA_ACK   = 4'd3,
    SEND_SOF_REQ       = 4'd4,
    WAIT_FOR_PYL_ACPT  = 4'd5,
    SEND_FIRST         = 4'd6,
    SEND_SECOND        = 4'd7,
    SEND_PAYLOAD       = 4'd8,
    SEND_LAST          = 4'd9,
    WAIT_FOR_ACK       = 4'd10,
    CHECK_FOR_CHUNK    = 4'd11,
    META_DRAIN         = 4'd12
} state_t;

state_t curr_state;
state_t next_state;

//------------------------------------------------------------------------------
// CDC Sync
//------------------------------------------------------------------------------
always_ff @(posedge clk, negedge rst_n) begin
    if(~rst_n) begin
        clear_sync                 <= 2'b0;
        dma_read_ack_sync          <= 2'b0;
        s_axis_dma_tvalid_sync     <= 2'b0;
        dma_ctrl_jumbo_en_sync      <= 2'b0;
        udp_metadata_sel_sync      <= 2'b0;
        s_axis_dma_tdata_sync      <= '{default: 1'b0};
        dma_ctrl_pyl_size_word_sync <= '{default: 1'b0};
        dma_ctrl_line_index_sync    <= '{default: 1'b0};

    end else begin
        clear_sync              <= {clear_sync[0]             , clear};
        dma_read_ack_sync       <= {dma_read_ack_sync[0]      , dma_read_ack};
        s_axis_dma_tvalid_sync  <= {s_axis_dma_tvalid_sync[0] , s_axis_dma_tvalid};
        dma_ctrl_jumbo_en_sync   <= {dma_ctrl_jumbo_en_sync[0]  , dma_ctrl_jumbo_en};
        udp_metadata_sel_sync   <= {udp_metadata_sel_sync[0]  , udp_metadata_sel};

        s_axis_dma_tdata_sync[0]      <= s_axis_dma_tdata;
        s_axis_dma_tdata_sync[1]      <= s_axis_dma_tdata_sync[0];

        dma_ctrl_pyl_size_word_sync[0] <= dma_ctrl_pyl_size_word;
        dma_ctrl_pyl_size_word_sync[1] <= dma_ctrl_pyl_size_word_sync[0];

        dma_ctrl_line_index_sync[0]    <= dma_ctrl_line_index;
        dma_ctrl_line_index_sync[1]    <= dma_ctrl_line_index_sync[0];
    end
end

//------------------------------------------------------------------------------
// Read Enable edge detector
//------------------------------------------------------------------------------
always_ff @(posedge clk, negedge rst_n) begin
    if(~rst_n) begin
        dma_ctrl_read_req_curr <= 'b0;
        dma_ctrl_read_req_prev <= 'b0;
        dma_ctrl_read_req_re   <= 'b0;
    end else begin
        dma_ctrl_read_req_curr <= dma_ctrl_read_req;
        dma_ctrl_read_req_prev <= dma_ctrl_read_req_curr;
        dma_ctrl_read_req_re <= (dma_ctrl_read_req_curr) && (~dma_ctrl_read_req_prev);
    end
end

//------------------------------------------------------------------------------
// Total packet size capture
//------------------------------------------------------------------------------
// The input is provided from the frame_xfer_ctrl and is only captured during
// IDLE state of the FSM.
always_ff @(posedge clk, negedge rst_n) begin
    if(~rst_n) begin
        max_pyl_size_word_reg <= 'b0;
        dma_ctrl_jumbo_en_reg  <= 'b0;
    end else begin
        if(dma_ctrl_ready) begin
            max_pyl_size_word_reg <= dma_ctrl_pyl_size_word_sync[1];
            dma_ctrl_jumbo_en_reg  <= dma_ctrl_jumbo_en_sync[1];
        end else begin
            max_pyl_size_word_reg <= max_pyl_size_word_reg;
            dma_ctrl_jumbo_en_reg  <= dma_ctrl_jumbo_en_reg;
        end
    end
end

//------------------------------------------------------------------------------
// Populate UDP Payload size (fixed size)
//------------------------------------------------------------------------------

// As long as the UDP core isn't busy and accepting address it will be populated
always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        m_axis_udp_pyl_size_tvalid <= 'b0;
        m_axis_udp_pyl_size_tdata  <= 'b0;
    end else begin
        if (m_axis_udp_pyl_size_tready && ~core_busy) begin
            m_axis_udp_pyl_size_tvalid <= 'b1;
            // UDP Payload to the MAC always requre 2 bytes of checksum + 2
            // bytes of begining word.
            m_axis_udp_pyl_size_tdata  <= udp_pyl_size_byte_reg;
        end else begin
            m_axis_udp_pyl_size_tvalid <= 'b0;
            m_axis_udp_pyl_size_tdata  <= m_axis_udp_pyl_size_tdata;
        end
    end
end

assign metadata_data = metadata_reg;

//------------------------------------------------------------------------------
// Populate UDP Payload size (fixed size)
//------------------------------------------------------------------------------

always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        curr_state            <= IDLE;
        timeout_counter       <= 'b0;
        dma_read_req          <= 'b0;
        dma_ctrl_ready         <= 'b0;
        dma_ctrl_read_ack      <= 'b0;
        dma_ctrl_read_done     <= 'b0;
        udp_pyl_size_byte_reg <= 'b0;
        udp_pyl_size_word_reg <= 'b0;
        chunk                 <= 'b0;
        s_axis_dma_tready     <= 'b0;
        sof_req               <= 'b0;
        m_axis_udp_pyl_tvalid <= 'b0;
        m_axis_udp_pyl_tdata  <= 'b0;
        m_axis_udp_pyl_tkeep  <= 'b0;
        m_axis_udp_pyl_tlast  <= 'b0;
        line_index            <= 'b0;
        pkt_count             <= 'b0;
        sof_req_err           <= 'b0;
        pyl_acpt_err          <= 'b0;
        send_pyl_err          <= 'b0;
        send_last_err         <= 'b0;
        wait_ack_err          <= 'b0;
        dma_timeout_err       <= 'b0;
        metadata_valid        <= 'b0;
        meta_word_count       <= 'b0;
        metadata_reg          <= 'b0;

    end else begin

        curr_state <= next_state;

        if (curr_state == CLEAR) begin
            timeout_counter       <= 'b0;
            dma_read_req          <= 'b0;
            dma_ctrl_ready         <= 'b0;
            dma_ctrl_read_ack      <= 'b0;
            dma_ctrl_read_done     <= 'b0;
            udp_pyl_size_byte_reg <= 'b0;
            udp_pyl_size_word_reg <= 'b0;
            chunk                 <= 'b0;
            s_axis_dma_tready     <= 'b0;
            sof_req               <= 'b0;
            m_axis_udp_pyl_tvalid <= 'b0;
            m_axis_udp_pyl_tdata  <= 'b0;
            m_axis_udp_pyl_tkeep  <= 'b0;
            m_axis_udp_pyl_tlast  <= 'b0;
            line_index            <= 'b0;
            pkt_count             <= 'b0;
            sof_req_err           <= 'b0;
            pyl_acpt_err          <= 'b0;
            send_pyl_err          <= 'b0;
            send_last_err         <= 'b0;
            wait_ack_err          <= 'b0;
            dma_timeout_err       <= 'b0;
            metadata_valid        <= 'b0;
            meta_word_count       <= 'b0;

        end else if (curr_state == IDLE) begin
            timeout_counter       <= 'b0;
            dma_read_req          <= 'b0;
            dma_ctrl_ready         <= 'b1; // Set
            dma_ctrl_read_ack      <= 'b0; // Unset
            dma_ctrl_read_done     <= 'b0;
            udp_pyl_size_byte_reg <= 'b0;
            udp_pyl_size_word_reg <= 'b0;
            chunk                 <= 'b0;
            s_axis_dma_tready     <= 'b0;
            sof_req               <= 'b0;
            m_axis_udp_pyl_tvalid <= 'b0;
            m_axis_udp_pyl_tdata  <= 'b0;
            m_axis_udp_pyl_tkeep  <= 'b0;
            m_axis_udp_pyl_tlast  <= 'b0;
            line_index            <= 'b0;
            pkt_count             <= 'b0;
            sof_req_err           <= sof_req_err;  // Keep
            pyl_acpt_err          <= pyl_acpt_err;
            send_pyl_err          <= send_pyl_err;
            send_last_err         <= send_last_err;
            wait_ack_err          <= wait_ack_err;
            dma_timeout_err       <= dma_timeout_err;
            metadata_valid        <= 'b0;
            meta_word_count       <= 'b0;

        end else if (curr_state == CALC_UDP_PYL_SIZE) begin
            timeout_counter       <= 'b0;
            dma_read_req          <= 'b0;
            dma_ctrl_ready         <= 'b0; // Unset
            dma_ctrl_read_ack      <= 'b0;
            dma_ctrl_read_done     <= 'b0;
            chunk                 <= chunk;
            s_axis_dma_tready     <= 'b0;
            sof_req               <= 'b0;
            m_axis_udp_pyl_tvalid <= 'b0;
            m_axis_udp_pyl_tdata  <= 'b0;
            m_axis_udp_pyl_tkeep  <= 'b0;
            m_axis_udp_pyl_tlast  <= 'b0;
            line_index            <= dma_ctrl_line_index_sync[1]; // Update
            pkt_count             <= pkt_count; // Keep
            sof_req_err           <= sof_req_err;  // Keep
            pyl_acpt_err          <= pyl_acpt_err;
            send_pyl_err          <= send_pyl_err;
            send_last_err         <= send_last_err;
            wait_ack_err          <= wait_ack_err;
            dma_timeout_err       <= dma_timeout_err;

            if(dma_ctrl_jumbo_en_reg)
            begin
            // Jumbo Frame Calc
            if(max_pyl_size_word_reg > MAX_JMB_FRM) begin
                if((udp_pyl_size_word_reg+MAX_JMB_FRM) <= max_pyl_size_word_reg)
                begin
                    udp_pyl_size_word_reg <= udp_pyl_size_word_reg + MAX_JMB_FRM;
                    udp_pyl_size_byte_reg <= (MAX_JMB_FRM * 4) + PKT_TOKEN_SIZE;
                end else begin
                    // The last remaining chunks needs to be calculated here.
                    udp_pyl_size_word_reg <= udp_pyl_size_word_reg +
                            (max_pyl_size_word_reg - udp_pyl_size_word_reg);
                    udp_pyl_size_byte_reg <= (
                            (max_pyl_size_word_reg - udp_pyl_size_word_reg) * 4
                        ) + PKT_TOKEN_SIZE;

                end
            end else begin
                // The total requested size is smaller than max so just use it.
                udp_pyl_size_word_reg <= max_pyl_size_word_reg;
                udp_pyl_size_byte_reg <= (
                    max_pyl_size_word_reg * 4) + PKT_TOKEN_SIZE;
            end

            end else
            begin
            // Standard Frame Calc
            if(max_pyl_size_word_reg > MAX_STD_FRM) begin
                if((udp_pyl_size_word_reg+MAX_STD_FRM) <= max_pyl_size_word_reg)
                begin
                    udp_pyl_size_word_reg <= udp_pyl_size_word_reg + MAX_STD_FRM;
                    udp_pyl_size_byte_reg <= (MAX_STD_FRM * 4) + PKT_TOKEN_SIZE;
                end else begin
                    // The last remaining chunks needs to be calculated here.
                    udp_pyl_size_word_reg <= udp_pyl_size_word_reg +
                            (max_pyl_size_word_reg  - udp_pyl_size_word_reg);
                    udp_pyl_size_byte_reg <= (
                            (max_pyl_size_word_reg  - udp_pyl_size_word_reg) * 4
                        ) + PKT_TOKEN_SIZE;
                end
            end else begin
                // The total requested size is smaller than max so just use it.
                udp_pyl_size_word_reg <= max_pyl_size_word_reg;
                udp_pyl_size_byte_reg <= (
                    max_pyl_size_word_reg * 4) + PKT_TOKEN_SIZE;
            end
            end

        end else if (curr_state == WAIT_FOR_DMA_ACK) begin
            dma_read_req          <= 'b1;
            dma_ctrl_ready         <= 'b0;
            dma_ctrl_read_ack      <= 'b0;
            dma_ctrl_read_done     <= 'b0;
            udp_pyl_size_byte_reg <= udp_pyl_size_byte_reg;
            udp_pyl_size_word_reg <= udp_pyl_size_word_reg;
            chunk                 <= chunk;
            s_axis_dma_tready     <= 'b0;
            sof_req               <= 'b0;
            m_axis_udp_pyl_tvalid <= 'b0;
            m_axis_udp_pyl_tdata  <= 'b0;
            m_axis_udp_pyl_tkeep  <= 'b0;
            m_axis_udp_pyl_tlast  <= 'b0;
            line_index            <= line_index;  // Keep
            pkt_count             <= pkt_count;   // Keep
            sof_req_err           <= sof_req_err; // Keep
            pyl_acpt_err          <= pyl_acpt_err;
            send_pyl_err          <= send_pyl_err;
            send_last_err         <= send_last_err;
            wait_ack_err          <= wait_ack_err;

            if (timeout_counter >= MAX_TIMEOUT-1) begin
                timeout_counter   <= 'b0;
                dma_timeout_err   <= dma_timeout_err + 1;
            end else if (dma_read_ack_sync[1]) begin
                timeout_counter   <= 'b0;
                dma_timeout_err   <= dma_timeout_err;
            end else begin
                timeout_counter   <= timeout_counter + 1;
                dma_timeout_err   <= dma_timeout_err;
            end

        end else if (curr_state == SEND_SOF_REQ) begin
            dma_read_req          <= 'b0;
            dma_ctrl_ready         <= 'b0;
            dma_ctrl_read_ack      <= 'b1;
            dma_ctrl_read_done     <= 'b0;
            udp_pyl_size_byte_reg <= udp_pyl_size_byte_reg;
            udp_pyl_size_word_reg <= udp_pyl_size_word_reg;
            chunk                 <= chunk;
            s_axis_dma_tready     <= 'b0;
            sof_req               <= 'b1; // sending start of frame req to udp
            m_axis_udp_pyl_tvalid <= 'b0;
            m_axis_udp_pyl_tdata  <= 'b0;
            m_axis_udp_pyl_tkeep  <= 'b0;
            m_axis_udp_pyl_tlast  <= 'b0;
            line_index            <= line_index;
            pkt_count             <= pkt_count;
            pyl_acpt_err          <= pyl_acpt_err;
            send_pyl_err          <= send_pyl_err;
            send_last_err         <= send_last_err;
            wait_ack_err          <= wait_ack_err;
            dma_timeout_err       <= dma_timeout_err;

            if (timeout_counter >= MAX_TIMEOUT-1) begin
                timeout_counter   <= 'b0;
                sof_req_err       <= sof_req_err + 1;
            end else if (~core_busy) begin
                timeout_counter   <= 'b0;
                sof_req_err       <= sof_req_err;
            end else begin
                timeout_counter   <= timeout_counter + 1;
                sof_req_err       <= sof_req_err;
            end

        end else if (curr_state == WAIT_FOR_PYL_ACPT) begin
            dma_read_req          <= 'b0;
            dma_ctrl_ready         <= 'b0;
            dma_ctrl_read_ack      <= 'b0;
            dma_ctrl_read_done     <= 'b0;
            udp_pyl_size_byte_reg <= udp_pyl_size_byte_reg;
            udp_pyl_size_word_reg <= udp_pyl_size_word_reg;
            chunk                 <= chunk;
            s_axis_dma_tready     <= 1'b0;
            sof_req               <= 'b0; // Release sof
            m_axis_udp_pyl_tvalid <= 'b0;
            m_axis_udp_pyl_tdata  <= 'b0;
            m_axis_udp_pyl_tkeep  <= 'b0;
            m_axis_udp_pyl_tlast  <= 'b0;
            line_index            <= line_index;
            pkt_count             <= pkt_count;
            sof_req_err           <= sof_req_err;
            send_pyl_err          <= send_pyl_err;
            send_last_err         <= send_last_err;
            wait_ack_err          <= wait_ack_err;
            dma_timeout_err       <= dma_timeout_err;

            if (timeout_counter >= MAX_TIMEOUT-1) begin
                timeout_counter   <= 'b0;
                pyl_acpt_err      <= pyl_acpt_err + 1;
            end else if (pyl_acpt) begin
                timeout_counter   <= 'b0;
                pyl_acpt_err      <= pyl_acpt_err;
            end else begin
                timeout_counter   <= timeout_counter + 1;
                pyl_acpt_err      <= pyl_acpt_err;
            end

        end else if (curr_state == SEND_FIRST) begin
            // Sending a placeholder for UDP checksum and 2 first bytes of UDP
            timeout_counter       <= 'b0;
            s_axis_dma_tready     <= 'b0;
            dma_read_req          <= 'b0;
            dma_ctrl_ready         <= 'b0;
            dma_ctrl_read_ack      <= 'b0;
            dma_ctrl_read_done     <= 'b0;
            udp_pyl_size_byte_reg <= udp_pyl_size_byte_reg;
            udp_pyl_size_word_reg <= udp_pyl_size_word_reg;
            chunk                 <= chunk;
            sof_req               <= 'b0; // Release sof

            m_axis_udp_pyl_tvalid <= m_axis_udp_pyl_tready; // Only if UDP can accept the payload
            m_axis_udp_pyl_tdata  <= {CHKSUM_PLACE_HOLDER, UDP_PKT_START_TOKEN};
            if (m_axis_udp_pyl_tready) begin
                m_axis_udp_pyl_tkeep  <= 'b1111;
            end else begin
                m_axis_udp_pyl_tkeep  <= 'b0000;
            end

            m_axis_udp_pyl_tlast  <= 'b0;
            line_index            <= line_index;
            pkt_count             <= pkt_count;
            sof_req_err           <= sof_req_err;
            pyl_acpt_err          <= pyl_acpt_err;
            send_pyl_err          <= send_pyl_err;
            send_last_err         <= send_last_err;
            wait_ack_err          <= wait_ack_err;
            dma_timeout_err       <= dma_timeout_err;

        end else if (curr_state == SEND_SECOND) begin
            // Sending a placeholder for UDP checksum and 2 first bytes of UDP
            timeout_counter       <= 'b0;
            s_axis_dma_tready     <= 'b0;
            dma_read_req          <= 'b0;
            dma_ctrl_ready         <= 'b0;
            dma_ctrl_read_ack      <= 'b0;
            dma_ctrl_read_done     <= 'b0;
            udp_pyl_size_byte_reg <= udp_pyl_size_byte_reg;
            udp_pyl_size_word_reg <= udp_pyl_size_word_reg;
            chunk                 <= chunk;
            sof_req               <= 'b0;

            m_axis_udp_pyl_tvalid <= m_axis_udp_pyl_tready;
            m_axis_udp_pyl_tdata  <= {line_index, pkt_count};
            if (m_axis_udp_pyl_tready) begin
                m_axis_udp_pyl_tkeep  <= 'b1111;
            end else begin
                m_axis_udp_pyl_tkeep  <= 'b0000;
            end

            m_axis_udp_pyl_tlast  <= 'b0;
            line_index            <= line_index;
            pkt_count             <= pkt_count;
            sof_req_err           <= sof_req_err;
            pyl_acpt_err          <= pyl_acpt_err;
            send_pyl_err          <= send_pyl_err;
            send_last_err         <= send_last_err;
            wait_ack_err          <= wait_ack_err;
            dma_timeout_err       <= dma_timeout_err;

        end else if (curr_state == SEND_PAYLOAD) begin
            // Signal DMA to provide data as long as udp core is accepting data
            dma_read_req          <= 'b0;
            dma_ctrl_ready         <= 'b0;
            dma_ctrl_read_ack      <= 'b0;
            dma_ctrl_read_done     <= 'b0;
            udp_pyl_size_byte_reg <= udp_pyl_size_byte_reg;
            udp_pyl_size_word_reg <= udp_pyl_size_word_reg;
            sof_req               <= 'b0;

            m_axis_udp_pyl_tvalid <= s_axis_dma_tvalid_sync[1];
            m_axis_udp_pyl_tdata  <= s_axis_dma_tdata_sync[1];
            if (s_axis_dma_tvalid_sync[1]) begin
                m_axis_udp_pyl_tkeep  <= 'b1111;
            end else begin
                m_axis_udp_pyl_tkeep  <= 'b0000;
            end
            m_axis_udp_pyl_tlast  <= 'b0;
            line_index            <= line_index;
            pkt_count             <= pkt_count;
            sof_req_err           <= sof_req_err;
            pyl_acpt_err          <= pyl_acpt_err;
            send_pyl_err          <= send_pyl_err;
            send_last_err         <= send_last_err;
            wait_ack_err          <= wait_ack_err;

            if (m_axis_udp_pyl_tready && s_axis_dma_tvalid_sync[1]) begin
                timeout_counter   <= 'b0;       // Reset wd counter
                chunk             <= chunk + 1; // increament index counter
            end else if (timeout_counter >= MAX_TIMEOUT-1) begin
                timeout_counter   <= 'b0;       // Reset wd counter
                chunk             <= 'b0;
            end else begin
                timeout_counter   <= timeout_counter + 1; // Incr wd counter
                chunk             <= chunk;     // No increament
            end

            if (chunk >= (udp_pyl_size_word_reg-FIFO_EMPTY_OFFSET_DELAY)) begin
                // if this is one before last no more req to fifo
                s_axis_dma_tready     <= 'b0;
            end else begin
                s_axis_dma_tready     <= m_axis_udp_pyl_tready;
            end

            if (timeout_counter >= MAX_TIMEOUT-1) begin
                send_pyl_err          <= send_pyl_err + 1;
            end else begin
                send_pyl_err          <= send_pyl_err;
            end

        end else if (curr_state == SEND_LAST) begin
            dma_read_req          <= 'b0;
            dma_ctrl_ready         <= 'b0;
            dma_ctrl_read_ack      <= 'b0;
            dma_ctrl_read_done     <= 'b0;
            udp_pyl_size_byte_reg <= udp_pyl_size_byte_reg;
            udp_pyl_size_word_reg <= udp_pyl_size_word_reg;
            s_axis_dma_tready     <= 'b0; // No more pop from FIFO
            sof_req               <= 'b0;
            m_axis_udp_pyl_tvalid <= 'b1; // Keep it valid until captured by MAC

            if (s_axis_dma_tvalid_sync[1]) begin
                m_axis_udp_pyl_tdata  <= s_axis_dma_tdata_sync[1];
            end else begin
                // Extend the tdata value in case mac is not ready but fifo
                // is empty
                m_axis_udp_pyl_tdata  <= m_axis_udp_pyl_tdata;
            end
            m_axis_udp_pyl_tkeep  <= 4'b1111;
            m_axis_udp_pyl_tlast  <= 'b1; // Last chunk
            line_index            <= line_index;
            pkt_count             <= pkt_count;
            sof_req_err           <= sof_req_err;
            pyl_acpt_err          <= pyl_acpt_err;
            send_pyl_err          <= send_pyl_err;
            wait_ack_err          <= wait_ack_err;
            dma_timeout_err       <= dma_timeout_err;

            if (m_axis_udp_pyl_tready) begin
                timeout_counter   <= 'b0;       // Reset wd counter
                chunk             <= chunk + 1; // increament index counter
            end else if (timeout_counter >= MAX_TIMEOUT-1) begin
                timeout_counter   <= 'b0;       // Reset wd counter
                chunk             <= 'b0;
            end else begin
                timeout_counter   <= timeout_counter + 1; // Incr wd counter
                chunk             <= chunk;     // No increament
            end

            if (timeout_counter >= MAX_TIMEOUT-1) begin
                send_last_err     <= send_last_err + 1;
            end else begin
                send_last_err     <= send_last_err;
            end
        end else if (curr_state == WAIT_FOR_ACK) begin
            dma_read_req          <= 'b0;
            dma_ctrl_ready         <= 'b0;
            dma_ctrl_read_ack      <= 'b0;
            dma_ctrl_read_done     <= 'b0;
            udp_pyl_size_byte_reg <= udp_pyl_size_byte_reg;
            udp_pyl_size_word_reg <= udp_pyl_size_word_reg;
            chunk                 <= chunk;
            s_axis_dma_tready     <= 'b0;
            sof_req               <= 'b0;
            m_axis_udp_pyl_tvalid <= 'b0;
            m_axis_udp_pyl_tdata  <= 'b0;
            m_axis_udp_pyl_tkeep  <= 'b0;
            m_axis_udp_pyl_tlast  <= 'b0;
            line_index            <= line_index;
            pkt_count             <= pkt_count;
            sof_req_err           <= sof_req_err;
            pyl_acpt_err          <= pyl_acpt_err;
            send_pyl_err          <= send_pyl_err;
            send_last_err         <= send_last_err;
            dma_timeout_err       <= dma_timeout_err;

            if (timeout_counter >= MAX_TIMEOUT-1) begin
                timeout_counter   <= 'b0;
                wait_ack_err      <= wait_ack_err + 1;
            end else if (eof_ack) begin
                timeout_counter   <= 'b0;
                wait_ack_err      <= wait_ack_err;
            end else begin
                timeout_counter   <= timeout_counter + 1;
                wait_ack_err      <= wait_ack_err;
            end

        end else if (curr_state == CHECK_FOR_CHUNK) begin
            timeout_counter       <= 'b0;
            dma_read_req          <= 'b0;
            dma_ctrl_ready         <= 'b0;
            dma_ctrl_read_ack      <= 'b0;

            if (udp_pyl_size_word_reg >= max_pyl_size_word_reg) begin
                dma_ctrl_read_done     <= 'b1; // Set to indicate done xfer.
            end else begin
                dma_ctrl_read_done     <= 'b0; // Don't set! We are not done yet.
            end

            udp_pyl_size_byte_reg <= udp_pyl_size_byte_reg;
            udp_pyl_size_word_reg <= udp_pyl_size_word_reg;
            chunk                 <= chunk;
            s_axis_dma_tready     <= 'b0;
            sof_req               <= 'b0;
            m_axis_udp_pyl_tvalid <= 'b0;
            m_axis_udp_pyl_tdata  <= 'b0;
            m_axis_udp_pyl_tkeep  <= 'b0;
            m_axis_udp_pyl_tlast  <= 'b0;
            line_index            <= line_index;
            pkt_count             <= pkt_count + 1; // Increament packet count
            sof_req_err           <= sof_req_err;
            pyl_acpt_err          <= pyl_acpt_err;
            send_pyl_err          <= send_pyl_err;
            send_last_err         <= send_last_err;
            dma_timeout_err       <= dma_timeout_err;


        end else if (curr_state == META_DRAIN) begin
            dma_read_req          <= 'b0;
            dma_ctrl_ready         <= 'b0;
            dma_ctrl_read_ack      <= 'b0;
            udp_pyl_size_byte_reg <= udp_pyl_size_byte_reg;
            udp_pyl_size_word_reg <= udp_pyl_size_word_reg;
            chunk                 <= 'b0;
            s_axis_dma_tready     <= 'b1;  // Drain FIFO
            sof_req               <= 'b0;
            m_axis_udp_pyl_tvalid <= 'b0;
            m_axis_udp_pyl_tdata  <= 'b0;
            m_axis_udp_pyl_tkeep  <= 'b0;
            m_axis_udp_pyl_tlast  <= 'b0;
            line_index            <= line_index;
            pkt_count             <= pkt_count;
            sof_req_err           <= sof_req_err;
            pyl_acpt_err          <= pyl_acpt_err;
            send_pyl_err          <= send_pyl_err;
            send_last_err         <= send_last_err;
            wait_ack_err          <= wait_ack_err;
            dma_timeout_err       <= dma_timeout_err;
            timeout_counter       <= 'b0;

            if (s_axis_dma_tvalid_sync[1]) begin
                meta_word_count <= meta_word_count + 1;
                if (meta_word_count < METADATA_WORDS) begin
                    metadata_reg[meta_word_count * IN_DATA_W +: IN_DATA_W] <= s_axis_dma_tdata_sync[1];
                end
                if (meta_word_count == METADATA_WORDS - 1) begin
                    metadata_valid <= 1'b1;
                end
                dma_ctrl_read_done <= (meta_word_count >= max_pyl_size_word_reg - 1);
            end else begin
                meta_word_count   <= meta_word_count;
                metadata_valid    <= metadata_valid;
                dma_ctrl_read_done <= 'b0;
            end

        end else begin
            timeout_counter       <= 'b0;
            dma_read_req          <= 'b0;
            dma_ctrl_ready         <= 'b0;
            dma_ctrl_read_ack      <= 'b0;
            dma_ctrl_read_done     <= 'b0;
            udp_pyl_size_byte_reg <= 'b0;
            udp_pyl_size_word_reg <= 'b0;
            chunk                 <= 'b0;
            s_axis_dma_tready     <= 'b0;
            sof_req               <= 'b0;
            m_axis_udp_pyl_tvalid <= 'b0;
            m_axis_udp_pyl_tdata  <= 'b0;
            m_axis_udp_pyl_tkeep  <= 'b0;
            m_axis_udp_pyl_tlast  <= 'b0;
            line_index            <= line_index;
            pkt_count             <= pkt_count;
            sof_req_err           <= sof_req_err;
            pyl_acpt_err          <= pyl_acpt_err;
            send_pyl_err          <= send_pyl_err;
            send_last_err         <= send_last_err;
            wait_ack_err          <= wait_ack_err;
            dma_timeout_err       <= dma_timeout_err;
            metadata_valid        <= 'b0;
            meta_word_count       <= 'b0;

        end
    end
end

always_comb begin

    next_state = curr_state;

    case(curr_state)

        CLEAR: begin
            if (clear_sync[1]) begin
                next_state = CLEAR;
            end else begin
                next_state = IDLE;
            end
        end

        IDLE: begin
            if (clear_sync[1]) begin
                next_state = CLEAR;
            end else if (dma_ctrl_read_req_re) begin
                next_state = CALC_UDP_PYL_SIZE;
            end else begin
                next_state = IDLE;
            end
        end

        CALC_UDP_PYL_SIZE: begin
            if (clear_sync[1]) begin
                next_state = CLEAR;
            end else begin
                next_state = WAIT_FOR_DMA_ACK;
            end
        end

        WAIT_FOR_DMA_ACK: begin
            if (clear_sync[1]) begin
                next_state = CLEAR;
            end else if (timeout_counter >= MAX_TIMEOUT-1) begin
                next_state = IDLE;
            end else if (dma_read_ack_sync[1]) begin
                if (udp_metadata_sel_sync[1]) begin
                    next_state = META_DRAIN;
                end else begin
                    next_state = SEND_SOF_REQ;
                end
            end else begin
                next_state = WAIT_FOR_DMA_ACK;
            end
        end

        META_DRAIN: begin
            if (clear_sync[1]) begin
                next_state = CLEAR;
            end else if (s_axis_dma_tvalid_sync[1] &&
                         meta_word_count >= max_pyl_size_word_reg - 1) begin
                next_state = IDLE;
            end else begin
                next_state = META_DRAIN;
            end
        end

        SEND_SOF_REQ: begin
            if (clear_sync[1]) begin
                next_state = CLEAR;
            end else if (timeout_counter >= MAX_TIMEOUT-1) begin
                next_state = IDLE;
            end else if (~core_busy) begin
                next_state = WAIT_FOR_PYL_ACPT;
            end else begin
                next_state = SEND_SOF_REQ;
            end
        end

        WAIT_FOR_PYL_ACPT: begin
            if (clear_sync[1]) begin
                next_state = CLEAR;
            end else if (timeout_counter >= MAX_TIMEOUT-1) begin
                next_state = IDLE;
            end else if (pyl_acpt) begin
                next_state = SEND_FIRST;
            end else begin
                next_state = WAIT_FOR_PYL_ACPT;
            end
        end

        SEND_FIRST: begin
            // Wait until UDP can accpet the first word of payload
            if (m_axis_udp_pyl_tready) begin
                next_state = SEND_SECOND;
            end else begin
                next_state = SEND_FIRST;
            end
        end

        SEND_SECOND: begin
            if (m_axis_udp_pyl_tready) begin
                next_state = SEND_PAYLOAD;
            end else begin
                next_state = SEND_SECOND;
            end
        end

        SEND_PAYLOAD: begin
            if (clear_sync[1]) begin
                next_state = CLEAR;
            end else if (timeout_counter >= MAX_TIMEOUT-1) begin
                next_state = IDLE;
            end else if (chunk == (udp_pyl_size_word_reg-DATA_OUT_OFFSET_DELAY) &&
                         m_axis_udp_pyl_tready &&
                         s_axis_dma_tvalid_sync[1]) begin
                next_state = SEND_LAST;
            end else begin
                next_state = SEND_PAYLOAD;
            end
        end

        SEND_LAST: begin
            if (clear_sync[1]) begin
                next_state = CLEAR;
            end else if (timeout_counter >= MAX_TIMEOUT-1) begin
                next_state = IDLE;
            end else if (chunk == (udp_pyl_size_word_reg-1) &&
                         m_axis_udp_pyl_tready) begin
                next_state = WAIT_FOR_ACK;
            end else begin
                next_state = SEND_LAST;
            end
        end

        WAIT_FOR_ACK: begin
            if (clear_sync[1]) begin
                next_state = CLEAR;
            end else if (timeout_counter >= MAX_TIMEOUT-1) begin
                next_state = IDLE;
            end else if (eof_ack) begin
                next_state = CHECK_FOR_CHUNK;
            end else begin
                next_state = WAIT_FOR_ACK;
            end
        end

        CHECK_FOR_CHUNK: begin
            if (clear_sync[1]) begin
                next_state = CLEAR;
            end else if (udp_pyl_size_word_reg >= max_pyl_size_word_reg) begin
                next_state = IDLE;
            end else begin
                next_state = CALC_UDP_PYL_SIZE;
            end
        end

        default: begin
            next_state = IDLE;
        end

    endcase
end

endmodule
