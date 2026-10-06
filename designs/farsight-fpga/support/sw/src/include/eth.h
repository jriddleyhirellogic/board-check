#ifndef ETH_H
#define ETH_H

//------------------------------------------------------------------------------
// Ethernet Core Driver - Configurable Base Address
//------------------------------------------------------------------------------

#include <stdint.h>

// The following configuration steps is taken from VSC8541 data sheet
// Register offset definitions (relative to base address)
#define MAC_CONFIG_1_OFFSET 0x0000
#define MAC_CONFIG_2_OFFSET 0x0004
#define MAC_MAX_FRAME_LEN_OFFSET 0x0010
#define MDIO_MGMT_CONFIG_OFFSET 0x0020
#define MDIO_MGMT_COMMAND_OFFSET 0x0024
#define MDIO_MGMT_ADDRESS_OFFSET 0x0028
#define MDIO_MGMT_CONTROL_OFFSET 0x002C
#define MDIO_MGMT_STATUS_OFFSET 0x0030
#define MDIO_MGMT_INDICATORS_OFFSET 0x0034
#define INTERFACE_CONTROL_OFFSET 0x0038
#define STATION_ADDRESS_LOWER_OFFSET 0x0040
#define STATION_ADDRESS_HIGHER_OFFSET 0x0044
#define MAC_FIFO_CONFIG_0_OFFSET 0x0048
#define MAC_FIFO_CONFIG_1_OFFSET 0x004C
#define MAC_FIFO_CONFIG_2_OFFSET 0x0050
#define MAC_FIFO_CONFIG_3_OFFSET 0x0054
#define MAC_FIFO_CONFIG_4_OFFSET 0x0058
#define MAC_FIFO_CONFIG_5_OFFSET 0x005C
#define FRAME_CONTROL_FILTER_OFFSET 0x01C0

// Ethernet core struct
typedef struct {
    volatile uint32_t* mdio_mgmt_address_reg;
    volatile uint32_t* mdio_mgmt_command_reg;
    volatile uint32_t* mdio_mgmt_control_reg;
    volatile uint32_t* mdio_mgmt_status_reg;
    volatile uint32_t* mdio_mgmt_indicators_reg;
    volatile uint32_t* mac_fifo_config_reg;
    volatile uint32_t* mac_config_1_reg;
    volatile uint32_t* mac_config_2_reg;
    volatile uint32_t* mac_max_frame_len_reg;
    volatile uint32_t* station_address_lower_reg;
    volatile uint32_t* station_address_higher_reg;
    volatile uint32_t* mac_fifo_config_reg0;
    volatile uint32_t* mac_fifo_config_reg1;
    volatile uint32_t* mac_fifo_config_reg2;
    volatile uint32_t* mac_fifo_config_reg3;
    volatile uint32_t* mac_fifo_config_reg4;
    volatile uint32_t* mac_fifo_config_reg5;
    volatile uint32_t* frame_control_filter_reg;
    volatile uint32_t* mdio_mgmt_config_reg;
    volatile uint32_t* interface_control_reg;
} eth_core_regs_t;

void eth_core_init_regs(eth_core_regs_t* regs, uint32_t base_address);
void phy_advertise(eth_core_regs_t* regs);
void phy_autonegotiation(eth_core_regs_t* regs);
void phy_init(eth_core_regs_t* regs);
void tse_init(eth_core_regs_t* regs);

#endif
