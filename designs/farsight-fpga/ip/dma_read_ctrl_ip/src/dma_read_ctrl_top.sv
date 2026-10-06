module dma_read_ctrl_top #(
    parameter integer CLOCK_FREQ_MHZ    = 100,
    parameter integer TIMEOUT_USEC      = 10_000, // 10 mSec
    parameter integer DDR_ADDR_WIDTH    = 38,
    parameter integer DDR_DATA_WIDTH    = 256,
    parameter integer USABLE_ADDR_WIDTH = 33, // 2^30 * 2^3 = 8GB
    parameter integer FRAME_WIDTH       = 25, // 2^25 frame size (32Gbits)
    parameter integer FRAME_INDEX_WIDTH = USABLE_ADDR_WIDTH - FRAME_WIDTH, // 8
    parameter integer METADATA_WIDTH    = 640  // bits
)(
    input  logic                         clk,
    input  logic                         rst_n,
    // Control from RSICV APB Reg IP ports
    input  logic                         clear,
    input  logic                         frame_read_req,    // SW req read
    output logic                         frame_read_done,   // Ack frame read
    input  logic                         udp_metadata_sel,  // 0=UDP image, 1=metadata
    input  logic [8:0]                   h_size_beat,       // Can't be >511
    input  logic [13:0]                  h_size_byte,       // a.k.a LINE_GAP
    input  logic [12:0]                  v_size_line,       // Can't be >8192
    input  logic [FRAME_INDEX_WIDTH-1:0] frame_index,       // Index of frame
    input  logic                         jumbo_en,
    output logic [31:0]                  frame_xfer_timeout_err,
    // DMA read interface to frame_xfer
    input  logic                         dma_ready,        // DMA ready for next req
    output logic                         ctrl_info_valid,
    output logic [DDR_ADDR_WIDTH-1:0]    ctrl_read_addr,   // Line read Addr
    output logic [8:0]                   ctrl_burst_count, // Num of chunks to read
    output logic                         dma_fifo_clear,
    // DMA read interface to DMA to UDP controller
    output logic                         dma_read_req,      // Req read from DMA
    input  logic                         dma_read_ack,      // DMA read acept sig
    // DMA Read FIFO interface (dma_read_ctrl interface)
    output logic                         s_axis_dma_tready, // DMA FIFO read enable
    input  logic                         s_axis_dma_tvalid, // DMA FIFO data valid
    input  logic [31:0]                  s_axis_dma_tdata,  // DMA FIFO data input
    // UDP IP Payload interface (dma_read_ctrl interface)
    output logic                         m_axis_udp_pyl_tvalid,
    input  logic                         m_axis_udp_pyl_tready,
    output logic [31:0]                  m_axis_udp_pyl_tdata,
    output logic [3:0]                   m_axis_udp_pyl_tkeep,
    output logic                         m_axis_udp_pyl_tlast,
    // UDP IP Payload size interface (dma_read_ctrl interface)
    output logic                         m_axis_udp_pyl_size_tvalid,
    input  logic                         m_axis_udp_pyl_size_tready,
    output logic [15:0]                  m_axis_udp_pyl_size_tdata,
    // UDP IP Control interface (dma_read_ctrl interface)
    output logic                         sof_req,
    input  logic                         eof_ack,
    input  logic                         pyl_acpt,
    input  logic                         core_busy,
    // Status signals (dma_read_ctrl interface to APB reg)
    output logic [31:0]                  sof_req_err,
    output logic [31:0]                  pyl_acpt_err,
    output logic [31:0]                  send_pyl_err,
    output logic [31:0]                  send_last_err,
    output logic [31:0]                  wait_ack_err,
    output logic [31:0]                  dma_timeout_err,
    // Metadata capture interface
    output logic [METADATA_WIDTH-1:0]    metadata_data,
    output logic                         metadata_valid
);

//------------------------------------------------------------------------------
// Local parameters
//------------------------------------------------------------------------------
localparam integer IN_DATA_W         = 32;
localparam integer OUT_DATA_W        = 32;
localparam integer TKEEP_W           = OUT_DATA_W/8;

//------------------------------------------------------------------------------
// Internal signals
//------------------------------------------------------------------------------
logic          dma_ctrl_read_req;
logic          dma_ctrl_read_ack;
logic          dma_ctrl_read_done;
logic [13:0]   dma_ctrl_pyl_size_word;
logic [15:0]   dma_ctrl_line_index;

//------------------------------------------------------------------------------
// Frame xfer controller instance
//------------------------------------------------------------------------------
frame_xfer_ctrl #(
    .CLOCK_FREQ_MHZ                (CLOCK_FREQ_MHZ            ),
    .TIMEOUT_USEC                  (TIMEOUT_USEC              ),
    .DDR_ADDR_WIDTH                (DDR_ADDR_WIDTH            ),
    .DDR_DATA_WIDTH                (DDR_DATA_WIDTH            ),
    .FRAME_WIDTH                   (FRAME_WIDTH               ),
    .USABLE_ADDR_WIDTH             (USABLE_ADDR_WIDTH         ),
    .FRAME_INDEX_WIDTH             (FRAME_INDEX_WIDTH         ),
    .METADATA_WIDTH                (METADATA_WIDTH            )
) frame_xfer_ctrl_inst (
    .clk                           (clk                       ),
    .rst_n                         (rst_n                     ),
    // APB and RSICV interface
    .clear                         (clear                     ),
    .frame_read_req                (frame_read_req            ),
    .frame_read_done               (frame_read_done           ),
    .udp_metadata_sel              (udp_metadata_sel          ),
    .h_size_beat                   (h_size_beat               ),
    .h_size_byte                   (h_size_byte               ),
    .v_size_line                   (v_size_line               ),
    .frame_index                   (frame_index               ),
    .timeout_err                   (frame_xfer_timeout_err    ),
    // DMA Contrller interface
    .dma_ctrl_read_req              (dma_ctrl_read_req          ),
    .dma_ctrl_read_ack              (dma_ctrl_read_ack          ),
    .dma_ctrl_read_done             (dma_ctrl_read_done         ),
    .dma_ctrl_pyl_size_word         (dma_ctrl_pyl_size_word     ),
    .dma_ctrl_line_index            (dma_ctrl_line_index        ),
    // DMA read interface
    .dma_ready                     (dma_ready                 ),
    .ctrl_info_valid               (ctrl_info_valid           ),
    .ctrl_read_addr                (ctrl_read_addr            ),
    .ctrl_burst_count              (ctrl_burst_count          ),
    .dma_fifo_clear                (dma_fifo_clear            )
);

//------------------------------------------------------------------------------
// DMA to UDP controller instance
//------------------------------------------------------------------------------
dma_read_ctrl #(
    .CLOCK_FREQ_MHZ                (CLOCK_FREQ_MHZ            ),
    .TIMEOUT_USEC                  (TIMEOUT_USEC              ),
    .IN_DATA_W                     (IN_DATA_W                 ),
    .OUT_DATA_W                    (OUT_DATA_W                ),
    .TKEEP_W                       (TKEEP_W                   ),
    .METADATA_WIDTH                (METADATA_WIDTH            )
) dma_read_ctrl_inst (
    .clk                           (clk                       ),
    .rst_n                         (rst_n                     ),
    .clear                         (clear                     ),
    // frame_xfer_ctrl interface
    .dma_ctrl_read_req              (dma_ctrl_read_req          ),
    .dma_ctrl_read_ack              (dma_ctrl_read_ack          ),
    .dma_ctrl_read_done             (dma_ctrl_read_done         ),
    .dma_ctrl_pyl_size_word         (dma_ctrl_pyl_size_word     ),
    .dma_ctrl_jumbo_en              (jumbo_en                  ),
    .dma_ctrl_line_index            (dma_ctrl_line_index        ),
    // DMA Read info set interface
    .dma_read_req                  (dma_read_req              ),
    .dma_read_ack                  (dma_read_ack              ),
    // DMA Read FIFO interface
    .s_axis_dma_tready             (s_axis_dma_tready         ),
    .s_axis_dma_tvalid             (s_axis_dma_tvalid         ),
    .s_axis_dma_tdata              (s_axis_dma_tdata          ),
    // UDP IP Payload interface
    .m_axis_udp_pyl_tvalid         (m_axis_udp_pyl_tvalid     ),
    .m_axis_udp_pyl_tready         (m_axis_udp_pyl_tready     ),
    .m_axis_udp_pyl_tdata          (m_axis_udp_pyl_tdata      ),
    .m_axis_udp_pyl_tkeep          (m_axis_udp_pyl_tkeep      ),
    .m_axis_udp_pyl_tlast          (m_axis_udp_pyl_tlast      ),
    // UDP IP Payload size interface
    .m_axis_udp_pyl_size_tvalid    (m_axis_udp_pyl_size_tvalid),
    .m_axis_udp_pyl_size_tready    (m_axis_udp_pyl_size_tready),
    .m_axis_udp_pyl_size_tdata     (m_axis_udp_pyl_size_tdata ),
    // UDP IP Control interface
    .sof_req                       (sof_req                   ),
    .eof_ack                       (eof_ack                   ),
    .pyl_acpt                      (pyl_acpt                  ),
    .core_busy                     (core_busy                 ),
    // Status signals
    .sof_req_err                   (sof_req_err               ),
    .pyl_acpt_err                  (pyl_acpt_err              ),
    .send_pyl_err                  (send_pyl_err              ),
    .send_last_err                 (send_last_err             ),
    .wait_ack_err                  (wait_ack_err              ),
    .dma_timeout_err               (dma_timeout_err           ),
    // Metadata capture interface
    .udp_metadata_sel              (udp_metadata_sel          ),
    .metadata_data                 (metadata_data             ),
    .metadata_valid                (metadata_valid            )
);


endmodule
