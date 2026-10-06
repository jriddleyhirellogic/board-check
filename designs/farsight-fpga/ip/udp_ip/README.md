# UDP IP

A UDP transmit engine that constructs full Ethernet/IPv4/UDP packets from payload sources and drives them out through the PolarFire CORETSE MAC interface. Payload data is selected via a 3-input mux (debug generator, DDR4 8 GB DMA, DDR4 16 GB DMA), and the MAC TX output is arbitrated between the UDP TX path and an ARP responder. A back-pressure FIFO absorbs MAC stalls, and a watchdog flags stuck transfers.

- **Full packet construction**: Builds Ethernet, IPv4, and UDP headers with correct checksums per RFC 791
- **Payload mux**: Selects between debug static generator, DDR4 8 GB, and DDR4 16 GB frame sources
- **MAC TX arbitration**: UDP has priority; ARP takes over only when UDP is idle
- **Back-pressure handling**: Integrated FIFO absorbs MAC TX stalls with configurable frame gap (min 20 us for CoreTSE)
- **Debug mode**: On-the-fly pattern generator supporting standard (1500 B) and jumbo (4000 B) frames

## Module Hierarchy

```
udp_tx_top
├── udp_tx                      (packet construction + watchdog)
└── COREFIFO_MAC_BACKPRES       (back-pressure FIFO)

udp_mux                         (payload source selector)
mtx_mux                         (MAC TX arbiter: UDP vs ARP)
udp_tx_apb_reg                  (APB register interface)
```

## FSM States

### mtx_mux (MAC TX arbiter)

| State        | Description                                       |
|--------------|---------------------------------------------------|
| `UDP_ACTIVE` | UDP TX owns the MAC, ARP requests queued          |
| `ARP_DRAIN`  | Draining UDP pipeline before handing off to ARP   |
| `ARP_ACTIVE` | ARP responder owns the MAC                        |
| `ARP_ABORT`  | Forcefully ends ARP if UDP becomes busy           |

## Parameters (udp_tx)

| Parameter        | Default    | Description                              |
|------------------|------------|------------------------------------------|
| `CLOCK_FREQ_MHZ` | 100        | Clock frequency in MHz                   |
| `TIMEOUT_SEC`    | 10         | Watchdog timeout in seconds              |
| `ETH_TYPE`       | `16'h0800` | EtherType (IPv4)                         |
| `IP_VER`         | `4'h4`     | IP version                               |
| `IP_IHL`         | `4'h5`     | IP header length (5 words)               |
| `IP_TTL`         | `8'h40`    | Time to live                             |
| `IP_PROTOCOL`    | `8'h11`    | Protocol (0x11 = UDP)                    |

## Ports (udp_tx_top)

| Port                   | Dir | Width | Description                              |
|------------------------|-----|-------|------------------------------------------|
| `clk`                  | in  | 1     | Clock                                    |
| `rst_n`                | in  | 1     | Active-low reset                         |
| `eth_hdr_valid`        | in  | 1     | Ethernet header config valid             |
| `eth_hdr_ready`        | out | 1     | Ready to accept Ethernet header          |
| `dst_mac`              | in  | 48    | Destination MAC address                  |
| `src_mac`              | in  | 48    | Source MAC address                       |
| `ip_hdr_valid`         | in  | 1     | IP header config valid                   |
| `ip_hdr_ready`         | out | 1     | Ready to accept IP header                |
| `dst_ip`               | in  | 32    | Destination IP address                   |
| `src_ip`               | in  | 32    | Source IP address                        |
| `udp_hdr_valid`        | in  | 1     | UDP header config valid                  |
| `udp_hdr_ready`        | out | 1     | Ready to accept UDP header               |
| `dst_port`             | in  | 16    | UDP destination port                     |
| `src_port`             | in  | 16    | UDP source port                          |
| `payload_size`         | in  | 16    | Payload size in bytes                    |
| `payload_tvalid`       | in  | 1     | AXIS payload valid                       |
| `payload_tready`       | out | 1     | AXIS payload ready                       |
| `payload_tdata`        | in  | 32    | AXIS payload data                        |
| `payload_tkeep`        | in  | 4     | AXIS payload byte enables                |
| `payload_tlast`        | in  | 1     | AXIS payload last                        |
| `sof_req`              | in  | 1     | Start of frame request                   |
| `eof_ack`              | out | 1     | End of frame acknowledgment              |
| `pyl_acpt`             | out | 1     | Payload accepted                         |
| `core_busy`            | out | 1     | TX core busy                             |
| `MTXACPT`              | in  | 1     | MAC TX accept                            |
| `MTXRDY`               | out | 1     | MAC TX ready                             |
| `MTXDAT`               | out | 32    | MAC TX data                              |
| `MTXEOF`               | out | 1     | MAC TX end of frame                      |
| `MTXBYTEVALID`         | out | 4     | MAC TX valid bytes                       |
| `MTXSOF`               | out | 1     | MAC TX start of frame                    |
| `clear`                | in  | 1     | Software clear                           |
| `frame_gap`            | in  | 32    | Inter-frame gap (clock cycles)           |
| `wd_timeout_err_count` | out | 32    | Watchdog timeout error counter           |

## Register Map (udp_tx_apb_reg)

| Offset | Name                   | Width | Access | Description                                   |
|--------|------------------------|-------|--------|-----------------------------------------------|
| `0x00` | `UDP_DST_PORT`         | 16    | R/W    | UDP destination port                          |
| `0x04` | `UDP_SRC_PORT`         | 16    | R/W    | UDP source port                               |
| `0x08` | `DST_IP`               | 32    | R/W    | Destination IPv4 address                      |
| `0x0C` | `SRC_IP`               | 32    | R/W    | Source IPv4 address                           |
| `0x10` | `DST_MAC_MSB`          | 16    | R/W    | Destination MAC [47:32]                       |
| `0x14` | `DST_MAC_LSB`          | 32    | R/W    | Destination MAC [31:0]                        |
| `0x18` | `SRC_MAC_MSB`          | 16    | R/W    | Source MAC [47:32]                            |
| `0x1C` | `SRC_MAC_LSB`          | 32    | R/W    | Source MAC [31:0]                             |
| `0x20` | `WD_TIMEOUT_ERR_COUNT` | 32    | R      | Watchdog timeout error count                  |
| `0x24` | `MUX_SEL`              | 2     | R/W    | Payload mux select (0=Disabled, 1=8GB, 2=16GB)|
| `0x28` | `UDP_CLR`              | 1     | R/W    | Clear controller state                        |
| `0x2C` | `FRAME_GAP`            | 32    | R/W    | MAC TX inter-frame gap (clock cycles)         |