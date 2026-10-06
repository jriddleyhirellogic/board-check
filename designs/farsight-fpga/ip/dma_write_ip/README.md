# DMA Write IP

A DDR4 write DMA engine that receives camera pixel data, packs it through a width converter (384 → 512 bits), buffers it in a cross-clock FIFO, and bursts it into DDR4 memory with computed frame/line addressing. The design spans two clock domains (pixel clock and DDR clock) with CDC synchronizers throughout. Two top-level variants are provided for 8 GB and 16 GB DDR4 configurations.

- **Frame-aware addressing**: Automatically computes DDR write addresses from frame index, line count, and configurable line gap
- **Width conversion**: 4:3 ratio converter packs 384-bit camera words into 512-bit DDR words
- **Timeout detection**: Configurable watchdog (default 10 ms) flags stalled writes via APB status register
- **Receive/send split**: Separate FSMs for counting incoming chunks (pixel domain) and bursting to DDR (DDR domain)

## Module Hierarchy

```
dma_write_ddr4_Xgb
├── dma_write_ctrl
│   ├── wconv_4in_3out          (384→512 bit width converter)
│   ├── dma_write_recv_ctrl     (pixel-domain chunk counter)
│   └── dma_write_send_ctrl     (DDR-domain burst controller)
└── COREFIFO_DMA_WR_Xgb        (cross-clock FIFO)
```

## FSM States

### dma_write_send_ctrl

| State               | Description                                                    |
|----------------------|----------------------------------------------------------------|
| `IDLE`               | Waiting for a complete line of data in the FIFO                |
| `WAIT_VALID_CHUNK`   | Waits for FIFO read data to become valid                       |
| `SET_BEAT_COUNTER`   | Calculates burst length (max 256 beats) for current transfer   |
| `WRITE_TRIG`         | Sends write request to arbiter                                 |
| `WRITING`            | Streaming data from FIFO to arbiter, monitors timeout          |
| `CHECK_REMAINING`    | Checks if more beats remain for current line                   |
| `SET_NEXT_LINE_ADDR` | Advances to next line address, increments frame index at frame end |

### dma_write_recv_ctrl

| State              | Description                                          |
|--------------------|------------------------------------------------------|
| `RECV_IDLE`        | Waiting for line_valid rising edge                   |
| `RECV_COUNT`       | Counting width-converter output chunks               |
| `WAIT_FOR_RECV_DONE` | Waiting for send-side acknowledgment              |
| `SEND_RECV_DONE`   | Handshake complete, return to idle                   |

### wconv_4in_3out

| State          | Description                                              |
|----------------|----------------------------------------------------------|
| `RECV_CHUNK_0` | Buffer 384 bits, no output                               |
| `RECV_CHUNK_1` | Output 512 bits (384 buffered + 128 new), buffer 256     |
| `RECV_CHUNK_2` | Output 512 bits (256 buffered + 256 new), buffer 128     |
| `RECV_CHUNK_3` | Output 512 bits (128 buffered + 384 new), buffer empty   |

## Variants

| Module                  | DDR Addr Width | DDR Data Width | Usable Addr | Frame Index Width |
|-------------------------|----------------|----------------|-------------|-------------------|
| `dma_write_ddr4_8gb`    | 38             | 256            | 33 (8 GB)   | 8                 |
| `dma_write_ddr4_16gb`   | 39             | 512            | 34 (16 GB)  | 9                 |

## Parameters (dma_write_send_ctrl)

| Parameter             | Default | Description                                |
|-----------------------|---------|--------------------------------------------|
| `DDR4_CLOCK_FREQ_MHZ` | 150     | DDR clock frequency in MHz                 |
| `TIMEOUT_USEC`        | 10000   | Write timeout in microseconds              |
| `DDR_ADDR_WIDTH`      | 38      | DDR address bus width                      |
| `DDR_DATA_WIDTH`      | 256     | DDR data bus width                         |
| `DIN_DOUT_RATIO`      | 2       | FIFO input-to-output width ratio           |
| `USABLE_ADDR_WIDTH`   | 33      | Addressable memory space width             |
| `FRAME_INDEX_WIDTH`   | 8       | Bits for frame index counter               |

## Ports (dma_write_ctrl)

| Port                   | Dir | Width            | Domain | Description                              |
|------------------------|-----|------------------|--------|------------------------------------------|
| `pixel_clk`            | in  | 1                | PIX    | Pixel clock                              |
| `pixel_rst_n`          | in  | 1                | PIX    | Pixel active-low reset                   |
| `ddr_clk`              | in  | 1                | DDR    | DDR clock                                |
| `ddr_rst_n`            | in  | 1                | DDR    | DDR active-low reset                     |
| `frame_valid`          | in  | 1                | PIX    | Camera frame valid                       |
| `line_valid`           | in  | 1                | PIX    | Camera line valid                        |
| `data_in`              | in  | 384              | PIX    | Camera pixel data                        |
| `clear_frame_index`    | in  | 1                | PIX    | Reset frame index to 0                   |
| `h_size_byte`          | in  | 14               | PIX    | Line gap / height size in bytes          |
| `arb_write_req`        | out | 1                | DDR    | Arbiter write request                    |
| `arb_write_ack`        | in  | 1                | DDR    | Arbiter write acknowledge                |
| `arb_write_burst_len`  | out | 16               | DDR    | Burst length to arbiter                  |
| `arb_write_start_addr` | out | `DDR_ADDR_WIDTH` | DDR    | Start address to arbiter                 |
| `arb_write_done`       | in  | 1                | DDR    | Arbiter write complete                   |
| `arb_write_ready`      | in  | 1                | DDR    | Arbiter ready for data                   |
| `arb_data_out`         | out | `DDR_DATA_WIDTH` | DDR    | Data to arbiter                          |
| `frame_index`          | out | `FRAME_INDEX_WIDTH` | DDR | Current frame index                      |
| `frame_write_done`     | out | 1                | DDR    | Frame write complete (pulse-stretched)   |
| `core_ready`           | out | 1                | DDR    | Controller idle and ready                |
| `timeout_err`          | out | 1                | DDR    | Timeout error flag                       |

## Register Map (dma_write_apb_reg)

| Offset | Name               | Width | Access | Description                                    |
|--------|--------------------|-------|--------|------------------------------------------------|
| `0x00` | `CLEAR_INDEX`      | 1     | R/W    | Write 1 to reset frame index counter           |
| `0x04` | `H_SIZE_BYTE`      | 14    | R/W    | Line gap / height size in bytes                |
| `0x08` | `FRAME_INDEX`      | 8/9   | R      | Current frame index (CDC synced)               |
| `0x0C` | `CORE_READY`       | 1     | R      | Controller ready status (CDC synced)           |
| `0x10` | `FRAME_WRITE_DONE` | 1     | R      | Frame write completion flag (CDC synced)       |
| `0x14` | `TIMEOUT_ERR`      | 1     | R      | Timeout error status (CDC synced)              |