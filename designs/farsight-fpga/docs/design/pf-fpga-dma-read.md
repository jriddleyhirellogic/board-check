<!--
Generated from farsight-doc/04-section-sdd/pf-fpga-dma-read.tex at commit 81efafc.

Regenerate with:
  python3 <workspace>/docs/icd/tex2md.py \
      <workspace>/farsight-doc/04-section-sdd/pf-fpga-dma-read.tex > pf-fpga-dma-read.md

The design is the source of truth. Where the LaTeX source disagreed with the
RTL, the RTL was followed. Note that the register and command sections of
farsight-doc are stale relative to the firmware and were deliberately not
migrated.
-->

#### DMA Read for UDP export

The DMA Read module transfers frame data from DDR4 memory to downstream
consumers (UDP export). It operates across two clock domains:
the DDR4 user clock domain (150 MHz) for memory reads and the UDP controller clock
domain (100 MHz) for data output.

**Module Hierarchy**

The DMA Read IP consists of the following submodules:

- **dma_read_ddr4_16gb / dma_read_ddr4_8gb**: Top-level wrappers for each DDR4 bank
- **dma_read_ctrl**: Main controller handling AXI4 read transactions and FIFO management
- **COREFIFO**: Asynchronous FIFO for clock domain crossing and width conversion (512-bit to 32-bit for 16 GB, 256-bit to 32-bit for 8 GB)

**Controller Interface**

The DMA Read module receives read requests from an external controller (e.g., UDP export logic) via a handshake interface:

- **ctrl_info_valid**: Controller asserts to indicate valid address/burst parameters
- **ctrl_burst_count**: Number of AXI4 beats to read (9 bits, up to 512 beats)
- **ctrl_read_addr**: DDR4 start address for the read operation
- **dma_read_req**: Controller requests a DMA read transaction
- **dma_ready**: DMA signals it is ready to accept a new request
- **dma_read_ack**: DMA acknowledges the read request

**Read Controller FSM**

The `dma_read_ctrl` operates in the DDR4 clock domain with the following states:

1. **IDLE**: Wait for `dma_read_req` rising edge, capture burst parameters
2. **READ_TRIG**: Assert `arb_read_req` and wait for `arb_read_ack`
3. **READING**: Stream data from arbiter to FIFO until `arb_read_done`
4. **WAIT_EXPORT_DONE**: Wait for FIFO to empty (data consumed by controller)
5. **CLEAR_STATE**: Reset state when clear signal is asserted

**Data Flow**

Read data flows through an asynchronous FIFO that provides:

- Clock domain crossing from DDR4 clock (150 MHz) to UDP controller clock (100 MHz)
- Width conversion from DDR4 data width (512/256 bits) to 32-bit AXI-Stream output
- Buffering to decouple DDR4 burst reads from downstream consumption rate

The output uses an AXI-Stream interface (`m_axis_dma_tvalid`, `m_axis_dma_tready`, `m_axis_dma_tdata`) for flow-controlled data transfer to the export logic.

**FIFO Management**

The FIFO can be cleared via two mechanisms:

- **dma_fifo_clear**: Per-transaction FIFO clear from the controller
- **clear**: Global clear from APB register (also resets timeout error counter)

Both clear signals are synchronized across clock domains before asserting the FIFO reset.

**Timeout Protection**

The controller implements a 10 ms watchdog timeout during READ_TRIG, READING, and WAIT_EXPORT_DONE states. If a timeout occurs, the FSM returns to IDLE and increments the `timeout_err` counter. This prevents the DMA from stalling indefinitely due to arbiter or downstream issues.

#### DMA Read APB Register Interface

the table below shows the DMA Read APB registers.

| **Offset** | **Name** | **Width** | **Access** | **Description** |
| --- | --- | --- | --- | --- |
| 0x00 | CLEAR | 1 bit | R/W | Reset DMA Read controller and clear timeout error counter |
| 0x04 | DMA_TIMEOUT_ERR | 32 bits | RO | Timeout error counter |

_Table: DMA Read APB Register Map_
