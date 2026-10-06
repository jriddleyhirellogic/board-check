#ifndef UDP_CORE_REG
#define UDP_CORE_REG
//------------------------------------------------------------------------------
// UDP registers
//------------------------------------------------------------------------------
// 'h0
#define UDP_DST_PORT_REG_OFFSET 0u
#define UDP_DST_PORT_OFFSET UDP_DST_PORT_REG_OFFSET
#define UDP_DST_PORT_MASK 0xFFFFFFFFu
#define UDP_DST_PORT_SHIFT 0u
// 'h1
#define UDP_SRC_PORT_REG_OFFSET 4u
#define UDP_SRC_PORT_OFFSET UDP_SRC_PORT_REG_OFFSET
#define UDP_SRC_PORT_MASK 0xFFFFFFFFu
#define UDP_SRC_PORT_SHIFT 0u
// 'h2
#define DST_IP_REG_OFFSET 8u
#define DST_IP_OFFSET DST_IP_REG_OFFSET
#define DST_IP_MASK 0xFFFFFFFFu
#define DST_IP_SHIFT 0u
// 'h3
#define SRC_IP_REG_OFFSET 12u
#define SRC_IP_OFFSET SRC_IP_REG_OFFSET
#define SRC_IP_MASK 0xFFFFFFFFu
#define SRC_IP_SHIFT 0u
// 'h4
#define DST_MAC_MSB_REG_OFFSET 16u
#define DST_MAC_MSB_OFFSET DST_MAC_MSB_REG_OFFSET
#define DST_MAC_MSB_MASK 0xFFFFFFFFu
#define DST_MAC_MSB_SHIFT 0u
// 'h5
#define DST_MAC_LSB_REG_OFFSET 20u
#define DST_MAC_LSB_OFFSET DST_MAC_LSB_REG_OFFSET
#define DST_MAC_LSB_MASK 0xFFFFFFFFu
#define DST_MAC_LSB_SHIFT 0u
// 'h6
#define SRC_MAC_MSB_REG_OFFSET 24u
#define SRC_MAC_MSB_OFFSET SRC_MAC_MSB_REG_OFFSET
#define SRC_MAC_MSB_MASK 0xFFFFFFFFu
#define SRC_MAC_MSB_SHIFT 0u
// 'h7
#define SRC_MAC_LSB_REG_OFFSET 28u
#define SRC_MAC_LSB_OFFSET SRC_MAC_LSB_REG_OFFSET
#define SRC_MAC_LSB_MASK 0xFFFFFFFFu
#define SRC_MAC_LSB_SHIFT 0u
// 'h8
#define WD_TIMEOUT_ERR_COUNT_REG_OFFSET 32u
#define WD_TIMEOUT_ERR_COUNT_OFFSET WD_TIMEOUT_ERR_COUNT_REG_OFFSET
#define WD_TIMEOUT_ERR_COUNT_MASK 0xFFFFFFFFu
#define WD_TIMEOUT_ERR_COUNT_SHIFT 0u
// 'h9
#define UDP_MUX_SEL_REG_OFFSET 36u
#define UDP_MUX_SEL_OFFSET UDP_MUX_SEL_REG_OFFSET
#define UDP_MUX_SEL_MASK 0xFFFFFFFFu
#define UDP_MUX_SEL_SHIFT 0u
// 'hA
#define UDP_CLEAR_REG_OFFSET 40u
#define UDP_CLEAR_OFFSET UDP_CLEAR_REG_OFFSET
#define UDP_CLEAR_MASK 0xFFFFFFFFu
#define UDP_CLEAR_SHIFT 0u
// 'hB
#define FRAME_GAP_REG_OFFSET 44u
#define FRAME_GAP_OFFSET FRAME_GAP_REG_OFFSET
#define FRAME_GAP_MASK 0xFFFFFFFFu
#define FRAME_GAP_SHIFT 0u


//------------------------------------------------------------------------------
// Constants
//------------------------------------------------------------------------------
#define UDP_MUX_DISABLE 0
#define UDP_MUX_SELECT_DDR4_8GB 1
#define UDP_MUX_SELECT_DDR4_16GB 2
#endif
