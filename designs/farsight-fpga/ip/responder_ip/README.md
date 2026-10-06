# Responder IP

An Ethernet responder that handles ARP and ICMP ping requests, tailored for the PolarFire CORETSE MAC. The core processes packets on an internal 128-bit bus and uses width converters to interface with the 32-bit MAC data path. A built-in FIFO buffers received data with a timeout mechanism to prevent deadlock when the FIFO stays full.

- **ARP responder**: Replies to ARP requests with the configured source MAC address
- **ICMP ping responder**: Replies to IPv4 echo requests with correct IPv4 and ICMP checksums
- **Width conversion**: 32-bit MAC ↔ 128-bit internal bus via up/down converters with byte-order swapping

## Module Hierarchy

```
rsp_top
├── width_up_conv       (32→128 bit, RX path from MAC)
├── responder           (128-bit packet processing + rsp_fifo)
└── width_down_conv     (128→32 bit, TX path to MAC)
```

## FSM States (responder)

| State                | Description                                          |
|----------------------|------------------------------------------------------|
| `POWER_UP`           | PHY initialization delay                             |
| `IDLE`               | Waiting for incoming packets                         |
| `ETH_HDR`            | Parsing Ethernet header (EtherType dispatch)         |
| `ARP_RCV`            | Receiving ARP payload                                |
| `ARP_VALID`          | Validating ARP request targets this IP               |
| `ETH_ARP_HDR_SEND`   | Sending Ethernet header for ARP reply                |
| `ARP_SEND`           | Sending ARP reply payload                            |
| `ARP_FINISH`         | ARP reply complete                                   |
| `IPV4_HDR`           | Parsing IPv4 header                                  |
| `IPV4_PING_VALID`    | Validating ICMP echo request targets this IP         |
| `ETH_IPV4_HDR_SEND`  | Sending Ethernet header for ICMP reply               |
| `IPV4_HDR_SEND`      | Sending IPv4 header with recomputed checksum         |
| `IPV4_PING_SEND`     | Sending ICMP echo reply payload from FIFO            |
| `IPV4_PING_FINISH`   | ICMP reply complete                                  |
| `DROP_PKT`           | Draining unrecognized or invalid packet              |

## Parameters (rsp_top)

| Parameter        | Default | Description                              |
|------------------|---------|------------------------------------------|
| `CLOCK_FREQ_MHZ` | 100     | Clock frequency in MHz                   |
| `PHY_INIT_USEC`  | 100     | PHY initialization delay in microseconds |
| `MAC_DATA_WIDTH` | 32      | MAC interface data width                 |
| `RSP_DATA_WIDTH` | 128     | Internal responder data width            |
| `MAC_WIDTH`      | 48      | MAC address width                        |
| `IPV4_WIDTH`     | 32      | IPv4 address width                       |

## Ports (rsp_top)

| Port              | Dir | Width            | Description                              |
|-------------------|-----|------------------|------------------------------------------|
| `clk`             | in  | 1                | Clock                                    |
| `rst_n`           | in  | 1                | Active-low reset                         |
| `rxacpt`          | out | 1                | RX accept to MAC                         |
| `rxrdy`           | in  | 1                | RX data ready from MAC                   |
| `rxdata`          | in  | `MAC_DATA_WIDTH` | RX data from MAC                         |
| `rxeof`           | in  | 1                | RX end of frame                          |
| `rxbytevalid`     | in  | 4                | RX valid bytes in last word              |
| `rxsof`           | in  | 1                | RX start of frame                        |
| `txacpt`          | in  | 1                | TX accept from MAC                       |
| `txrdy`           | out | 1                | TX data ready to MAC                     |
| `txdata`          | out | `MAC_DATA_WIDTH` | TX data to MAC                           |
| `txeof`           | out | 1                | TX end of frame                          |
| `txbytevalid`     | out | 4                | TX valid bytes in last word              |
| `txsof`           | out | 1                | TX start of frame                        |
| `src_mac_valid`   | in  | 1                | Source MAC address valid strobe          |
| `src_mac`         | in  | 48               | Source MAC address                       |
| `src_ipv4_valid`  | in  | 1                | Source IPv4 address valid strobe         |
| `src_ipv4`        | in  | 32               | Source IPv4 address                      |
| `core_busy`       | out | 1                | Core is processing a packet              |

## Register Map

This module has no software-accessible registers.