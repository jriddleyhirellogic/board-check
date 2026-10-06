# DMA Read IP

A DDR4 read DMA controller that transfers burst data from DDR4 memory through a cross-clock FIFO and out via an AXI-Stream interface. The design uses a 5-state FSM with arbiter handshaking, CDC synchronization between DDR and control clock domains, and a configurable timeout for detecting stalled transactions. Two top-level variants are provided for 8 GB and 16 GB DDR4 configurations.

- **Dual clock domain**: DDR clock (150 MHz) and control clock with 2-stage CDC synchronizers
- **Arbiter handshaking**: Requests memory access via `arb_read_req`/`arb_read_ack` protocol
- **Timeout detection**: Configurable watchdog (default 10 ms) flags stalled reads via APB-readable status register
- **AXI-Stream output**: `m_axis_dma_tvalid`/`tready`/`tdata` for downstream consumption

## FSM States

| State              | Description                                                     |
|--------------------|-----------------------------------------------------------------|
| `IDLE`             | Ready, waiting for `dma_read_req` rising edge                   |
| `READ_TRIG`        | Sends read request to arbiter, starts timeout counter           |
| `READING`          | Arbiter active, FIFO filling, monitors for done or timeout      |
| `WAIT_EXPORT_DONE` | Read complete, waiting for FIFO to drain empty                  |
| `CLEAR_STATE`      | Clears all outputs when software issues a clear command         |

## Variants

| Module                 | DDR Addr Width | DDR Data Width | FIFO IP                             |
|------------------------|----------------|----------------|--------------------------------------|
| `dma_read_ddr4_8gb`    | 38             | 256            | `COREFIFO_DMA_READ_DDR4_8GB_C0`     |
| `dma_read_ddr4_16gb`   | 39             | 512            | `COREFIFO_DMA_READ_DDR4_16GB_C0`    |

## Parameters (dma_read)

| Parameter            | Default | Description                              |
|----------------------|---------|------------------------------------------|
| `DDR4_CLOCK_FREQ_MHZ`| 150     | DDR clock frequency in MHz               |
| `TIMEOUT_USEC`       | 10000   | Read timeout in microseconds             |
| `DDR_ADDR_WIDTH`     | 38      | DDR address bus width                    |
| `DDR_DATA_WIDTH`     | 256     | DDR data bus width                       |
| `DATA_OUT_WIDTH`     | 32      | AXI-Stream output data width             |

## Ports (dma_read)

| Port                  | Dir | Width            | Domain | Description                              |
|-----------------------|-----|------------------|--------|------------------------------------------|
| `ddr_clk`             | in  | 1                | DDR    | DDR clock                                |
| `ddr_rst_n`           | in  | 1                | DDR    | DDR active-low reset                     |
| `ctrl_clk`            | in  | 1                | CTRL   | Control clock                            |
| `ctrl_rst_n`          | in  | 1                | CTRL   | Control active-low reset                 |
| `ctrl_info_valid`     | in  | 1                | CTRL   | Burst config valid strobe                |
| `ctrl_burst_count`    | in  | 16               | CTRL   | Number of beats per burst                |
| `ctrl_read_addr`      | in  | `DDR_ADDR_WIDTH` | CTRL   | DDR start address                        |
| `dma_ready`           | out | 1                | DDR    | Controller is idle and ready             |
| `dma_read_req`        | in  | 1                | DDR    | Request a DMA read                       |
| `dma_read_ack`        | out | 1                | DDR    | Read acknowledged                        |
| `dma_fifo_clear`      | in  | 1                | CTRL   | FIFO clear request                       |
| `arb_read_req`        | out | 1                | DDR    | Arbiter read request                     |
| `arb_read_ack`        | in  | 1                | DDR    | Arbiter read acknowledge                 |
| `arb_read_burst_len`  | out | 16               | DDR    | Burst length to arbiter                  |
| `arb_read_start_addr` | out | `DDR_ADDR_WIDTH` | DDR    | Start address to arbiter                 |
| `arb_read_done`       | in  | 1                | DDR    | Arbiter read complete                    |
| `arb_read_valid`      | in  | 1                | DDR    | Arbiter data valid                       |
| `arb_data_in`         | in  | `DDR_DATA_WIDTH` | DDR    | Data from arbiter                        |
| `m_axis_dma_tready`   | in  | 1                | CTRL   | AXI-Stream ready                         |
| `m_axis_dma_tvalid`   | out | 1                | CTRL   | AXI-Stream valid                         |
| `m_axis_dma_tdata`    | out | `DATA_OUT_WIDTH` | CTRL   | AXI-Stream data                          |
| `timeout_err`         | out | 1                | DDR    | Timeout error flag                       |
| `clear`               | in  | 1                | CTRL   | Software clear command                   |

## Register Map (dma_read_apb_reg)

| Offset | Name              | Width | Access | Description                          |
|--------|-------------------|-------|--------|--------------------------------------|
| `0x00` | `CLEAR`           | 1     | W      | Write 1 to clear controller state    |
| `0x04` | `DMA_TIMEOUT_ERR` | 1     | R      | Timeout error status (CDC synced)    |