<!--
Generated from farsight-doc/04-section-sdd/pf-fpga-dma-write.tex at commit 81efafc.

Regenerate with:
  python3 <workspace>/docs/icd/tex2md.py \
      <workspace>/farsight-doc/04-section-sdd/pf-fpga-dma-write.tex > pf-fpga-dma-write.md

The design is the source of truth. Where the LaTeX source disagreed with the
RTL, the RTL was followed. Note that the register and command sections of
farsight-doc are stale relative to the firmware and were deliberately not
migrated.
-->

#### DMA Write

The DMA Write module transfers camera frame data from the SLVS-EC receiver to DDR4 memory. It operates across two clock domains: the pixel clock domain (79.2 MHz) for receiving camera data and the DDR4 user clock domain (150 MHz) for memory writes.

**Module Hierarchy**

The DMA Write IP consists of the following submodules:

- **dma_write_ddr4_16gb / dma_write_ddr4_8gb**: Top-level wrappers for each DDR4 bank
- **dma_write_ctrl**: Main controller instantiating the width converter and sub-controllers
- **wconv_4in_3out**: Width converter (384-bit to 512-bit)
- **dma_write_recv_ctrl**: Receive controller in pixel clock domain
- **dma_write_send_ctrl**: Send controller in DDR4 clock domain
- **COREFIFO**: Asynchronous FIFO for clock domain crossing

**Width Conversion**

The camera interface outputs 384-bit data (32 pixels x 12 bits). The `wconv_4in_3out` module converts this to 512-bit words for DDR4 using a 4:3 ratio (384x4 = 512x3):

- Cycle 0: Buffer 384 bits, no output
- Cycle 1: Output 512 bits (128 new + 384 buffered), buffer 256 bits
- Cycle 2: Output 512 bits (256 new + 256 buffered), buffer 128 bits
- Cycle 3: Output 512 bits (384 new + 128 buffered), buffer empty

**Receive Controller**

The `dma_write_recv_ctrl` operates in the pixel clock domain and counts the number of 512-bit chunks written to the FIFO per camera line. It detects the rising edge of `line_valid` to start counting and the falling edge to finalize the count. The chunk count is passed to the send controller via a handshake interface.

**Send Controller**

The `dma_write_send_ctrl` operates in the DDR4 clock domain and manages AXI4 burst writes to the arbiter. Key features:

- Supports burst lengths up to 256 beats (AXI4 maximum)
- Splits large line transfers into multiple bursts if needed
- Maintains frame and line address tracking
- Configurable line gap (`h_size_byte`) for memory stride
- 10 ms watchdog timeout for error detection

The send controller FSM states:

1. **IDLE**: Wait for `frame_valid`
2. **WAIT_VALID_CHUNK**: Wait for chunk count from receive controller
3. **SET_BEAT_COUNTER**: Calculate burst length
4. **WRITE_TRIG**: Assert `arb_write_req` and wait for `arb_write_ack`
5. **WRITING**: Stream data from FIFO to arbiter
6. **CHECK_REMAINING**: Check if more bursts needed for current line
7. **SET_NEXT_LINE_ADDR**: Advance to next line address

**Memory Address Mapping**

Frame data is organized in DDR4 memory using the following address structure:

- 16 GB DDR4: 9-bit frame index (512 frames), 25-bit frame address space (\sim32 MB per frame)
- 8 GB DDR4: 8-bit frame index (256 frames), 25-bit frame address space (\sim32 MB per frame)

#### DMA Write APB Register Interface

the table below shows the DMA Write APB registers.

| **Offset** | **Name** | **Width** | **Access** | **Description** |
| --- | --- | --- | --- | --- |
| 0x00 | CLEAR_INDEX | 1 bit | R/W | Reset frame index counter to 0 |
| 0x04 | H_SIZE_BYTE | 14 bits | R/W | Line stride in bytes (memory gap between lines) |
| 0x08 | FRAME_INDEX | 8/9 bits | RO | Current frame index being written |
| 0x0C | CORE_READY | 1 bit | RO | DMA core ready for new frame |
| 0x10 | FRAME_WRITE_DONE | 1 bit | RO | Pulse when frame write completes |
| 0x14 | TIMEOUT_ERR | 32 bits | RO | Timeout error counter |

_Table: DMA Write APB Register Map_
