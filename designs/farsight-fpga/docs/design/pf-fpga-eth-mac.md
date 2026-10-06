<!--
Generated from farsight-doc/04-section-sdd/pf-fpga-eth-mac.tex at commit 81efafc.

Regenerate with:
  python3 <workspace>/docs/icd/tex2md.py \
      <workspace>/farsight-doc/04-section-sdd/pf-fpga-eth-mac.tex > pf-fpga-eth-mac.md

The design is the source of truth. Where the LaTeX source disagreed with the
RTL, the RTL was followed. Note that the register and command sections of
farsight-doc are stale relative to the firmware and were deliberately not
migrated.
-->

### Ethernet MAC

![Farsight Avionics Ethernet MAC Architecture](figures/farsight-eth-mac-architecture.png)

_Figure: Farsight Avionics Ethernet MAC Architecture_

The Farsight Avionics board includes two Ethernet interfaces (ETH1 and ETH2) based on Microchip VSC8541XMV-05 Gigabit Ethernet PHYs [vsc8541-datasheet]. The FPGA provides MAC layer functionality via the PolarFire CoreTSE IP [coretse-handbook], with RGMII-to-GMII conversion for PHY interfacing.

#### Ethernet Hierarchy Components

Each Ethernet interface consists of the following components:

- **CoreTSE MAC**: Microchip CoreTSE v4.0.124 Triple-Speed Ethernet MAC IP
- **PF_RGMII_TO_GMII**: PolarFire RGMII to GMII bridge IP (v1.3.109)
- **CoreGPIO (Control)**: GPIO output for PHY control signals
- **CoreGPIO (Status)**: GPIO input for PHY status signals
- **BIBUF**: Bidirectional buffer for MDIO interface

#### CoreTSE MAC Configuration

the table below shows the CoreTSE MAC configuration parameters.

| **Parameter** | **Value** |
| --- | --- |
| Interface Mode | GMII (not TBI) |
| MDIO PHY Address | 18 |
| Max Packet Size | 8192 bytes (jumbo frame support) |
| Statistics Counters | Enabled |
| Wake-on-LAN | Disabled |
| SLIP Mode | Disabled |

_Table: CoreTSE ETH1 MAC Configuration_

#### RGMII to GMII Bridge

The PF_RGMII_TO_GMII IP converts between the 4-bit RGMII interface (to the external PHY) and the 8-bit GMII interface (to the CoreTSE MAC). The bridge is configured with:

- Clock-to-data alignment: Aligned
- RX clock source: Global clock network

#### Ethernet MAC Clock Domains

The Ethernet subsystem operates across two clock domains:

- **APB Clock (50 MHz)**: Used for register access to CoreTSE MAC, control GPIO, and status GPIO
- **MAC Data Clock (100 MHz)**: Used for the MAC TX/RX data interfaces (MTXCLK, MRXCLK)

#### PHY Control GPIO Interface

The Ethernet PHY is controlled via a CoreGPIO instance accessible from the RISC-V firmware. the table below shows the control GPIO output bits.

| **Bit** | **Name** | **Default** | **Description** |
| --- | --- | --- | --- |
| 0 | eth1_phy_rst_n | 0 | PHY active-low reset |
| 1 | eth1_ctrl_comma_mode | 0 | PHY comma mode control |
| 2 | eth1_ctrl_clk_squelch_in | 0 | PHY clock squelch input |

_Table: Ethernet PHY Control GPIO (Output)_

#### PHY Status GPIO Interface

PHY status signals are read via a separate CoreGPIO instance. the table below shows the status GPIO input bits.

| **Bit** | **Name** | **Description** |
| --- | --- | --- |
| 0 | eth1_stat_fastlink_fail | Fast link failure indicator |
| 1 | eth1_stat_mdint | Management data interrupt |
| 2 | eth1_stat_rcvrd_clk | Recovered clock status |
| 3 | eth1_stat_clkout | PHY clock output status |

_Table: Ethernet PHY Status GPIO (Input)_

#### Etherent MAC Data Interface

The CoreTSE MAC provides separate TX and RX data interfaces for fabric connectivity:

**Transmit Interface (from UDP TX IP)**

- **MTXSOF**: Start of frame indicator
- **MTXRDY**: Data valid signal
- **MTXDAT**: 32-bit transmit data
- **MTXEOF**: End of frame indicator
- **MTXBYTEVALID**: Valid bytes in last word (2 bits)
- **MTXACPT**: MAC ready to accept data (backpressure)

**Receive Interface**

- **MRXSOF**: Start of frame indicator
- **MRXRDY**: Data valid signal
- **MRXDAT**: 32-bit receive data
- **MRXEOF**: End of frame indicator
- **MRXBYTEVALID**: Valid bytes in last word (2 bits)
- **MRXACPT**: Fabric ready to accept data

- The ETH1 MAC is dedicated to image data transfer and is controlled exclusively by the FPGA gateware (UDP TX IP). It is not directly accessible from the RISC-V firmware.
- The MAC supports Gigabit Ethernet (1000 Mbps), however due to MAC FIFO handshaking constraints in the current design, the effective data rate is limited to approximately 800 Mbps.
- The PHY control and status GPIO interfaces are accessible from the RISC-V firmware for PHY initialization and monitoring.
