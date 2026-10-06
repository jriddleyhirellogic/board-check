<!--
Generated from farsight-doc/04-section-sdd/pf-fpga-udp.tex at commit 81efafc.

Regenerate with:
  python3 <workspace>/docs/icd/tex2md.py \
      <workspace>/farsight-doc/04-section-sdd/pf-fpga-udp.tex > pf-fpga-udp.md

The design is the source of truth. Where the LaTeX source disagreed with the
RTL, the RTL was followed. Note that the register and command sections of
farsight-doc are stale relative to the firmware and were deliberately not
migrated.
-->

### UDP Export Data Architecture

![Farsight Avionics UDP Data Out Architecture](figures/farsight-udp-data-out-structure.png)

_Figure: Farsight Avionics UDP Data Out Architecture_

The UDP Export subsystem transfers frame data from DDR4 memory to the Ethernet MAC for transmission over UDP. It consists of two main components: the UDP DMA Controller (`udp_dmactrl_ip`) and the UDP TX IP (`udp_ip`). Both operate at 100 MHz in the UDP controller clock domain.

#### UDP DMA Controller

The UDP DMA Controller orchestrates frame data transfer from DDR4 memory to the UDP TX core. It consists of two submodules:

- **frame_xfer_ctrl**: Frame-level controller that requests entire image frames line-by-line
- **udp_dmactrl**: Packet-level controller that segments lines into UDP packets

**Frame Transfer Controller**

The `frame_xfer_ctrl` module manages the transfer of complete image frames from DDR4 memory. It receives frame parameters from software via APB registers and issues DMA read requests line-by-line.

Key parameters:

- **frame_index**: DDR4 frame buffer index to read from
- **h_size_beat**: Number of AXI4 beats per line (max 511)
- **h_size_byte**: Line stride in bytes for address calculation
- **v_size_line**: Number of lines per frame (max 8192)

The controller FSM states:

1. **IDLE**: Wait for `frame_read_req` from software
2. **CLEAR_DMA_FIFO**: Reset DMA FIFO before starting transfer
3. **WAIT_FOR_DMA_READY**: Wait for DMA Read module to be ready
4. **SET_BEAT_COUNTER**: Calculate burst size (splits lines >256 beats)
5. **READ_LINE_TRIG**: Request line read from UDP DMA controller
6. **WAIT_LINE_XFER_DONE**: Wait for line transfer completion
7. **CHECK_H_CHUNK**: Check if more horizontal chunks needed
8. **CHECK_V_COUNT**: Advance to next line or complete frame

**UDP DMA Controller**

The `udp_dmactrl` module segments line data into UDP packets and interfaces with the UDP TX core. It supports both standard (1500 byte) and jumbo (4000 byte) Ethernet frames.

Packet size limits:

- Standard frame: 363 words x 4 bytes + 6 bytes header = 1458 bytes payload (1500 byte total frame)
- Jumbo frame: 988 words x 4 bytes + 6 bytes header = 3958 bytes payload (4000 byte total frame)

Each UDP packet carries a 6-byte application header, placed immediately after
the standard 8-byte UDP header. The UDP header's own checksum field is left as
0x0000, which is legal for IPv4 and means the receiver does not verify it.

- 2 bytes: Packet start token ("PK" = 0x504B)
- 2 bytes: Line index within the frame
- 2 bytes: Packet sequence count within the line

The controller FSM states:

1. **IDLE**: Wait for line read request from frame controller
2. **CALC_UDP_PYL_SIZE**: Calculate packet payload size
3. **WAIT_FOR_DMA_ACK**: Wait for DMA Read acknowledgment
4. **SEND_SOF_REQ**: Request start of frame from UDP TX
5. **WAIT_FOR_PYL_ACPT**: Wait for UDP TX to accept payload
6. **SEND_FIRST**: Send checksum placeholder and start token
7. **SEND_SECOND**: Send line index and packet count
8. **SEND_PAYLOAD**: Stream DMA data to UDP TX
9. **SEND_LAST**: Send final word with `tlast` assertion
10. **WAIT_FOR_ACK**: Wait for UDP TX end-of-frame acknowledgment
11. **CHECK_FOR_CHUNK**: Check if more packets needed for current line

#### UDP DMA Controller APB Register Interface

the table below shows the UDP DMA Controller APB registers.

| **Offset** | **Name** | **Width** | **Access** | **Description** |
| --- | --- | --- | --- | --- |
| 0x00 | CLEAR | 1 bit | R/W | Reset controller and clear errors |
| 0x04 | FRAME_INDEX | 8 bits | R/W | Frame buffer index to read |
| 0x08 | FRAME_READ_DONE_COUNT | 32 bits | RO | Number of frames transferred |
| 0x0C | FRAME_READ_REQ | 1 bit | R/W | Trigger frame read (rising edge) |
| 0x10 | H_SIZE_BEAT | 9 bits | R/W | AXI4 beats per line |
| 0x14 | H_SIZE_BYTE | 14 bits | R/W | Line stride in bytes |
| 0x18 | JUMBO_EN | 1 bit | R/W | Enable jumbo frames (4000 bytes) |
| 0x1C | V_SIZE_LINE | 13 bits | R/W | Number of lines per frame |
| 0x20 | DMA_TIMEOUT_ERR | 32 bits | RO | DMA timeout error counter |
| 0x24 | PYL_ACPT_ERR | 32 bits | RO | Payload accept timeout counter |
| 0x28 | SEND_LAST_ERR | 32 bits | RO | Send last timeout counter |
| 0x2C | SEND_PYL_ERR | 32 bits | RO | Send payload timeout counter |
| 0x30 | SOF_REQ_ERR | 32 bits | RO | SOF request timeout counter |
| 0x34 | WAIT_ACK_ERR | 32 bits | RO | EOF ack timeout counter |
| 0x38 | FRAME_XFER_TIMEOUT_ERR | 32 bits | RO | Frame transfer timeout counter |
| 0x3C | RESET_DONE_COUNTER | 1 bit | R/W | Reset frame done counter |

_Table: UDP DMA Controller APB Register Map_

#### UDP TX IP

The UDP TX IP constructs complete Ethernet frames with IP and UDP headers, then transmits them to the PolarFire CoreTSE MAC. It accepts payload data via an AXI-Stream interface and network parameters via APB registers.

**Module Hierarchy**

The UDP TX IP consists of:

- **udp_tx_top**: Top-level wrapper containing the TX core and backpressure FIFO
- **udp_tx**: Main controller that constructs Ethernet/IP/UDP headers and manages MAC interface
- **udp_mux**: Multiplexer to select between DDR4 8 GB, DDR4 16 GB, or debug data sources
- **COREFIFO_MAC_BACKPRES**: FIFO for MAC backpressure handling

**Frame Construction**

The UDP TX core constructs a complete Ethernet frame with the following structure:

- **Ethernet Header** (14 bytes): Destination MAC, Source MAC, EtherType (0x0800 for IPv4)
- **IP Header** (20 bytes): Version 4, IHL 5, TTL 64, Protocol 17 (UDP), IP checksum calculated in hardware
- **UDP Header** (8 bytes): Source port, Destination port, Length, Checksum (set to 0)
- **Payload**: Data from UDP DMA Controller

The IP header checksum is calculated over two clock cycles using one's complement sum of all 16-bit header words.

**MAC Interface**

The UDP TX interfaces with the PolarFire CoreTSE MAC using the following signals:

- **MTXSOF**: Start of frame indicator
- **MTXRDY**: Data ready (valid)
- **MTXDAT**: 32-bit data output (byte-swapped for network byte order)
- **MTXEOF**: End of frame indicator
- **MTXBYTEVALID**: Valid bytes in last word
- **MTXACPT**: MAC ready to accept data (backpressure signal)

**Backpressure Handling**

The CoreTSE MAC may temporarily stop accepting data. The UDP TX handles this via:

- A FIFO buffer between payload input and MAC output
- Backpressure state tracking to hold data when MAC deasserts `MTXACPT`
- Automatic retry when MAC resumes accepting data

**Frame Gap**

A configurable frame gap (default 1000 clock cycles at 100 MHz = 10 us) is enforced between consecutive frames. The CoreTSE MAC requires a minimum gap of approximately 20 us for reliable operation.

**Timeout Protection**

The UDP TX implements a 10-second watchdog timeout (configurable via `MAX_TIMEOUT_USEC`). If any state exceeds the timeout, the core sends an error marker (0xEFBADBAD) with EOF and returns to IDLE.

**UDP TX FSM States**

1. **IDLE**: Wait for `sof_req` from DMA controller
2. **PREPARE**: Capture header values from registers
3. **CHECKSUM_CALC_P1**: Sum IP header words
4. **CHECKSUM_CALC_P2**: Compute one's complement checksum
5. **SEND_HEADER**: Transmit 42-byte header (10 words + 2 bytes)
6. **SEND_PAYLOAD**: Stream payload data to MAC
7. **FLUSH_REM_BUFFER**: Empty remaining FIFO data
8. **SEND_PAYLOAD_LAST**: Send final word with EOF
9. **FRAME_GAP_WAIT**: Wait for inter-frame gap
10. **WD_TIMEOUT_ERR**: Error recovery state

#### UDP MUX

The `udp_mux` module selects the data source for UDP transmission. the table below shows the available selections.

| **Value** | **Name** | **Description** |
| --- | --- | --- |
| 0b00 | DISABLED | UDP TX disabled, all outputs zero |
| 0b01 | DBG_EN | Debug static UDP mode for testing |
| 0b10 | UDP_FOR_DDR4_8GB | Route DDR4 8 GB data to UDP TX |
| 0b11 | UDP_FOR_DDR4_16GB | Route DDR4 16 GB data to UDP TX |

_Table: UDP MUX Selection Values_

#### UDP TX APB Register Interface

the table below shows the UDP TX APB registers for network configuration.

| **Offset** | **Name** | **Width** | **Access** | **Description** |
| --- | --- | --- | --- | --- |
| 0x00 | UDP_DST_PORT | 16 bits | R/W | UDP destination port |
| 0x04 | UDP_SRC_PORT | 16 bits | R/W | UDP source port |
| 0x08 | DST_IP | 32 bits | R/W | Destination IPv4 address |
| 0x0C | SRC_IP | 32 bits | R/W | Source IPv4 address |
| 0x10 | DST_MAC_MSB | 16 bits | R/W | Destination MAC [47:32] |
| 0x14 | DST_MAC_LSB | 32 bits | R/W | Destination MAC [31:0] |
| 0x18 | SRC_MAC_MSB | 16 bits | R/W | Source MAC [47:32] |
| 0x1C | SRC_MAC_LSB | 32 bits | R/W | Source MAC [31:0] |
| 0x20 | WD_TIMEOUT_ERR_COUNT | 32 bits | RO | Watchdog timeout counter |
| 0x24 | MUX_SEL | 2 bits | R/W | UDP MUX source select |
| 0x28 | UDP_CLR | 1 bit | R/W | Clear UDP TX core |
| 0x2C | FRAME_GAP | 32 bits | R/W | Inter-frame gap in clock cycles |

_Table: UDP TX APB Register Map_
