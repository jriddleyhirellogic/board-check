/*******************************************************************************
 * @file      eth.c
 * @copyright Copyright (c) 2025 Turion Space. All rights reserved.
 * @author    Saba Janamian (sjanamian@turionspace.com)
 * @date      09/17/2025
 * 
 * @brief     Etherent MAC and Phy configuration functions
 * 
 * @section changelog
 * - 09/17/2025: Saba Janamian - Initial implementation
 * 
*******************************************************************************/

#include "eth.h"

//------------------------------------------------------------------------------
// Ethernet Core Initialization Function
//------------------------------------------------------------------------------
void eth_core_init_regs(eth_core_regs_t* regs, uint32_t base_address)
{
    regs->mac_config_1_reg =
        (volatile uint32_t*)(base_address + MAC_CONFIG_1_OFFSET);
    regs->mac_config_2_reg =
        (volatile uint32_t*)(base_address + MAC_CONFIG_2_OFFSET);
    regs->mac_max_frame_len_reg =
        (volatile uint32_t*)(base_address + MAC_MAX_FRAME_LEN_OFFSET);
    regs->mdio_mgmt_config_reg =
        (volatile uint32_t*)(base_address + MDIO_MGMT_CONFIG_OFFSET);
    regs->mdio_mgmt_command_reg =
        (volatile uint32_t*)(base_address + MDIO_MGMT_COMMAND_OFFSET);
    regs->mdio_mgmt_address_reg =
        (volatile uint32_t*)(base_address + MDIO_MGMT_ADDRESS_OFFSET);
    regs->mdio_mgmt_control_reg =
        (volatile uint32_t*)(base_address + MDIO_MGMT_CONTROL_OFFSET);
    regs->mdio_mgmt_status_reg =
        (volatile uint32_t*)(base_address + MDIO_MGMT_STATUS_OFFSET);
    regs->mdio_mgmt_indicators_reg =
        (volatile uint32_t*)(base_address + MDIO_MGMT_INDICATORS_OFFSET);
    regs->interface_control_reg =
        (volatile uint32_t*)(base_address + INTERFACE_CONTROL_OFFSET);
    regs->station_address_lower_reg =
        (volatile uint32_t*)(base_address + STATION_ADDRESS_LOWER_OFFSET);
    regs->station_address_higher_reg =
        (volatile uint32_t*)(base_address + STATION_ADDRESS_HIGHER_OFFSET);
    regs->mac_fifo_config_reg0 =
        (volatile uint32_t*)(base_address + MAC_FIFO_CONFIG_0_OFFSET);
    regs->mac_fifo_config_reg1 =
        (volatile uint32_t*)(base_address + MAC_FIFO_CONFIG_1_OFFSET);
    regs->mac_fifo_config_reg2 =
        (volatile uint32_t*)(base_address + MAC_FIFO_CONFIG_2_OFFSET);
    regs->mac_fifo_config_reg3 =
        (volatile uint32_t*)(base_address + MAC_FIFO_CONFIG_3_OFFSET);
    regs->mac_fifo_config_reg4 =
        (volatile uint32_t*)(base_address + MAC_FIFO_CONFIG_4_OFFSET);
    regs->mac_fifo_config_reg5 =
        (volatile uint32_t*)(base_address + MAC_FIFO_CONFIG_5_OFFSET);
    regs->frame_control_filter_reg =
        (volatile uint32_t*)(base_address + FRAME_CONTROL_FILTER_OFFSET);
    regs->mac_fifo_config_reg =
        regs->mac_fifo_config_reg5;  // Alias for backward compatibility
}

//------------------------------------------------------------------------------
// Eth PHY setup functions
//------------------------------------------------------------------------------
void phy_advertise(eth_core_regs_t* regs)
{
    uint32_t phy_reg = 0xFFFF;

    // Device Auto-Negotiation Advertisement, Address 4 (0x04)
    // The bits in address 4 in the main registers space control the ability to
    // notify other devices of the status of
    // its auto-negotiation feature.
    *(regs->mdio_mgmt_address_reg) = 0x0004;
    *(regs->mdio_mgmt_control_reg) = 0x1;
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;
    *(regs->mdio_mgmt_command_reg) = 0x1;
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;
    phy_reg                        = *(regs->mdio_mgmt_status_reg);
    *(regs->mdio_mgmt_command_reg) = 0x0;

    phy_reg &= ~(0x1E);  // 0b11100001

    *(regs->mdio_mgmt_address_reg) = 0x0004;
    *(regs->mdio_mgmt_control_reg) = phy_reg;
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;

    // 1000BASE-T Control, Address 9 (0x09)
    *(regs->mdio_mgmt_address_reg) = 0x0009;
    *(regs->mdio_mgmt_control_reg) = 0x1;
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;
    *(regs->mdio_mgmt_command_reg) = 0x1;
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;
    phy_reg                        = *(regs->mdio_mgmt_status_reg);
    *(regs->mdio_mgmt_command_reg) = 0x0;

    // Enable PHY is 1000BASE-T Full Duplex capable.
    phy_reg |= 0x200;  // 0b001000000000

    *(regs->mdio_mgmt_address_reg) = 0x0009;
    *(regs->mdio_mgmt_control_reg) = phy_reg;
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;
}

void phy_autonegotiation(eth_core_regs_t* regs)
{
    uint32_t          phy_reg = 0xFFFF;
    uint16_t          autoneg_complete;
    volatile uint32_t copper_aneg_timeout = 1000000u;
    volatile uint32_t sgmii_aneg_timeout  = 100000u;
    uint8_t           copper_link_up;

    // Extended/GPIO Register Page Access, Address 31 (0x1F)
    *(regs->mdio_mgmt_address_reg) = 0x001F;
    *(regs->mdio_mgmt_control_reg) = 0x1;
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;

    // Registers 0–15 are not affected by the state of the extended page
    // register access. (see VSC8540-05 section 4.3)
    *(regs->mdio_mgmt_address_reg) = 0x0000;  // Mode Control
    *(regs->mdio_mgmt_control_reg) = 0x1;
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;
    *(regs->mdio_mgmt_command_reg) = 0x1;
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;
    phy_reg                        = *(regs->mdio_mgmt_status_reg);
    *(regs->mdio_mgmt_command_reg) = 0x0;

    phy_reg |= 0x1200;  // 0b0001001000000000
    // Bit 9: Restart autonegotiation
    // Bit 12: Autonegotiation enable
    *(regs->mdio_mgmt_address_reg) = 0x0000;  // Mode Control
    *(regs->mdio_mgmt_control_reg) = phy_reg;
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;

    do {
        // Mode Status, Address 1 (0x01)
        *(regs->mdio_mgmt_address_reg) = 0x0001;
        *(regs->mdio_mgmt_control_reg) = 0x1;
        while (*(regs->mdio_mgmt_indicators_reg) != 0)
            ;
        *(regs->mdio_mgmt_command_reg) = 0x1;
        while (*(regs->mdio_mgmt_indicators_reg) != 0)
            ;
        phy_reg                        = *(regs->mdio_mgmt_status_reg);
        *(regs->mdio_mgmt_command_reg) = 0x0;
        autoneg_complete               = phy_reg & 0x0020u;
        --copper_aneg_timeout;
    } while (!autoneg_complete && (copper_aneg_timeout != 0u));

    for (volatile uint32_t i = 0; i < 100000; i++)
        ;

    *(regs->mdio_mgmt_address_reg) = 0x0001;
    *(regs->mdio_mgmt_control_reg) = 0x1;
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;
    *(regs->mdio_mgmt_command_reg) = 0x1;
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;
    phy_reg                        = *(regs->mdio_mgmt_status_reg);
    *(regs->mdio_mgmt_command_reg) = 0x0;

    copper_link_up = phy_reg & 0x0004;  // Link status
}

void phy_init(eth_core_regs_t* regs)
{
    volatile uint32_t phy_reg  = 0xFFFF;
    volatile uint32_t temp_reg = 0xFFFF;
    volatile uint16_t id1      = 0;
    volatile uint16_t id2      = 0;

    // Select page 0
    *(regs->mdio_mgmt_address_reg) = 0x001F;
    *(regs->mdio_mgmt_control_reg) = 0x0000;
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;
    *(regs->mdio_mgmt_command_reg) = 0x1;
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;
    temp_reg                       = *(regs->mdio_mgmt_status_reg);
    *(regs->mdio_mgmt_command_reg) = 0x0;

    // Read PHY ID
    *(regs->mdio_mgmt_address_reg) = 0x0002;
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;
    *(regs->mdio_mgmt_command_reg) = 0x1;
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;
    id1                            = *(regs->mdio_mgmt_status_reg);
    *(regs->mdio_mgmt_command_reg) = 0x0;

    *(regs->mdio_mgmt_address_reg) = 0x0003;
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;
    *(regs->mdio_mgmt_command_reg) = 0x1;
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;
    id2                            = *(regs->mdio_mgmt_status_reg);
    *(regs->mdio_mgmt_command_reg) = 0x0;

    // Select page 0
    *(regs->mdio_mgmt_address_reg) = 0x001F;
    *(regs->mdio_mgmt_control_reg) = 0x0000;
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;

    // Extended PHY Control 1, Address 23 (0x17)
    *(regs->mdio_mgmt_address_reg) = 0x0017;
    *(regs->mdio_mgmt_control_reg) =
        0x1000;  // MAC interface selection to RGMII
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;
    *(regs->mdio_mgmt_command_reg) = 0x1;
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;
    temp_reg                       = *(regs->mdio_mgmt_status_reg);
    *(regs->mdio_mgmt_command_reg) = 0x0;

    // // Extended PHY Control 1, Address 24 (0x18)
    // *(regs->mdio_mgmt_address_reg) = 0x0017;
    // *(regs->mdio_mgmt_control_reg) = 0x10;  // Enable Jumno Frame
    // while (*(regs->mdio_mgmt_indicators_reg) != 0)
    //     ;
    // *(regs->mdio_mgmt_command_reg) = 0x1;
    // while (*(regs->mdio_mgmt_indicators_reg) != 0)
    //     ;
    // temp_reg                       = *(regs->mdio_mgmt_status_reg);
    // *(regs->mdio_mgmt_command_reg) = 0x0;

    // Mode Control, Address 0 (0x00)
    *(regs->mdio_mgmt_address_reg) = 0x0000;
    *(regs->mdio_mgmt_command_reg) = 0x1;
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;
    phy_reg                        = *(regs->mdio_mgmt_status_reg);
    *(regs->mdio_mgmt_command_reg) = 0x0;

    // SW reset
    *(regs->mdio_mgmt_address_reg) = 0x0000;
    phy_reg                        = phy_reg | 0x8000;
    *(regs->mdio_mgmt_control_reg) = phy_reg;
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;

    // Wait for soft reset to complete
    do {
        *(regs->mdio_mgmt_address_reg) = 0x0000;
        *(regs->mdio_mgmt_command_reg) = 0x1;
        while (*(regs->mdio_mgmt_indicators_reg) != 0)
            ;
        temp_reg                       = *(regs->mdio_mgmt_status_reg);
        *(regs->mdio_mgmt_command_reg) = 0x0;
    } while (0 != (temp_reg & 0x8000U));

    // For RGMII mode: configure register 20E2 (to access register 20E2,
    // register 31 must be set to 2).
    // Set bit 11 to 0 and set RX_CLK delay and TX_CLK delay accordingly
    // through bit [6:4] and/or bit [2:0]
    // respectively.

    // Select page 2
    *(regs->mdio_mgmt_address_reg) = 0x001F;
    *(regs->mdio_mgmt_control_reg) = 0x0002;
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;

    // Adjust MAC interface slew rate - default is 111 but recommended for
    // 3.3V i/o is 100. this is an extra step that is being done for the RTPF
    // evaluation kit, as this uses 3.3V pins (bank 4 : ethernet phy pins)
    // Adjust MAC interface slew rate
    *(regs->mdio_mgmt_address_reg) = 0x001B;
    *(regs->mdio_mgmt_command_reg) = 0x1;
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;
    temp_reg                       = *(regs->mdio_mgmt_status_reg);
    *(regs->mdio_mgmt_command_reg) = 0x0;

    temp_reg = temp_reg & 0xFF1FU;
    temp_reg = temp_reg | 0x0080U;

    *(regs->mdio_mgmt_address_reg) = 0x001B;
    *(regs->mdio_mgmt_control_reg) = temp_reg;
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;

    // Select back page 0
    *(regs->mdio_mgmt_address_reg) = 0x001F;
    *(regs->mdio_mgmt_control_reg) = 0x0000;
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;

    *(regs->mdio_mgmt_address_reg) = 0x0001;
    while (*(regs->mdio_mgmt_indicators_reg) != 0)
        ;
    *(regs->mdio_mgmt_command_reg) = 0x1;
    temp_reg                       = *(regs->mdio_mgmt_status_reg);
    *(regs->mdio_mgmt_command_reg) = 0x0;
}

//------------------------------------------------------------------------------
// Microchip CoreTSE IP Initialization
//------------------------------------------------------------------------------
void tse_init(eth_core_regs_t* regs)
{
    uint32_t tse_reg = 0xFFFF;
    uint32_t phy_reg = 0x0;
    uint32_t temp    = 0x0;

    tse_reg = *(regs->mac_fifo_config_reg);

    *(regs->mac_config_1_reg) = 0x80000000;  // Soft Reset
    *(regs->mac_config_1_reg) = 0x00000005;  // Tx and Rx enable
    *(regs->mac_config_2_reg) =
        0x00007217;  // Full Duplex, CRC, len checking, enable zero padding
    // *(regs->mac_config_2_reg) =
    //     0x00007233;  // Full Duplex, CRC, len checking, Huge Frame
    *(regs->mac_max_frame_len_reg) = 0x00001000;  // Maximum frame size
    *(regs->station_address_lower_reg) =
        0x6060603C;  // Destination address lower
    *(regs->station_address_higher_reg) =
        0xB1C00000;  // Destination address higher
    *(regs->mac_fifo_config_reg0)     = 0x0000FF00;
    *(regs->mac_fifo_config_reg1)     = 0x0FFF0000;
    *(regs->mac_fifo_config_reg2)     = 0x04000180;
    *(regs->mac_fifo_config_reg3)     = 0x0680FFFF;
    *(regs->mac_fifo_config_reg4)     = 0x00000000;
    *(regs->mac_fifo_config_reg5)     = 0x0003FFFF;
    *(regs->frame_control_filter_reg) = 0x0000000F;
    *(regs->mdio_mgmt_config_reg)     = 0x0007;  // Source clock divided by 28
    *(regs->interface_control_reg)    = 0x4;     // Clear all MDIO counters
}
