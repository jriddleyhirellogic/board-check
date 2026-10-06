# Camera MUX IP

A camera data multiplexer that automatically routes camera frames to DDR4 16 GB first, then DDR4 8 GB, then stops. The IP consists of two submodules instantiated under `cam_mux_top`:

- **`cam_mux_apb_reg`** — APB slave register file for software control and status readback
- **`cam_mux`** — 6-state Mealy FSM that performs the actual data routing

## Automated Routing Sequence

After a `mux_clear`, the MUX starts automatically and routes frames in order:

1. **DDR4 16 GB** — 512 frames (9-bit counter saturates at 511 + the triggering frame)
2. **DDR4 8 GB** — 256 frames (8-bit counter saturates at 255 + the triggering frame)
3. **Stopped** — `mux_enable` deasserts, FSM returns to IDLE

A new `mux_clear` resets all counters and full flags and restarts the sequence from step 1.

## mux_clear Handshake

`mux_clear` uses a 4-phase handshake to safely cross the APB ↔ pixel clock boundary:

1. SW writes `1` to `MUX_CLEAR` register — register holds the value
2. `cam_mux` detects the rising edge (after CDC sync), clears all state, asserts `mux_clear_ack`
3. APB reg detects `mux_clear_ack` (after CDC sync), clears `MUX_CLEAR` register back to `0`
4. `cam_mux` detects the falling edge of `mux_clear`, deasserts `mux_clear_ack`

SW can poll `MUX_CLEAR` and wait for it to read back `0` to confirm the clear completed.

## Reset Behavior

`pixel_rst_n` is tied to camera transceiver lock and asserts frequently. To prevent frame counters and routing state from being wiped on every transceiver reset:

- **Reset on `pixel_rst_n`**: CDC synchronizer stages, `mux_clear_ack` (handshake signals only)
- **Persists through `pixel_rst_n`**: `mux_enable`, `mux_select`, frame counters, full flags
- **Power-on state**: All persistent registers initialize to `0` via `initial` blocks (mirrors FPGA post-bitstream FF state)

## FSM States

| State                      | Description                                               |
|----------------------------|-----------------------------------------------------------|
| `IDLE`                     | MUX disabled, all outputs deasserted                      |
| `WAIT_FRAME_START`         | Enabled, waiting for `frame_valid_in` rising edge         |
| `FWD_TO_DDR4_8GB`          | Forwarding frame data to DDR4 8 GB output                 |
| `FWD_TO_DDR4_16GB`         | Forwarding frame data to DDR4 16 GB output                |
| `WAIT_FRAME_END_DDR4_8GB`  | Switch/disable requested, draining current frame to 8 GB  |
| `WAIT_FRAME_END_DDR4_16GB` | Switch/disable requested, draining current frame to 16 GB |

## Parameters

| Parameter        | Default | Description                        |
|------------------|---------|------------------------------------|
| `APB_DATA_WIDTH` | 32      | APB data bus width (bits)          |
| `APB_ADDR_WIDTH` | 32      | APB address bus width (bits)       |
| `DATA_WIDTH`     | 384     | Width of the pixel data bus (bits) |

## Top-Level Ports (`cam_mux_top`)

### APB Slave Interface

| Port       | Dir | Width            | Description         |
|------------|-----|------------------|---------------------|
| `pclk`     | in  | 1                | APB clock           |
| `presetn`  | in  | 1                | APB active-low reset|
| `penable`  | in  | 1                | APB enable          |
| `psel`     | in  | 1                | APB peripheral select|
| `paddr`    | in  | `APB_ADDR_WIDTH` | APB address         |
| `pwrite`   | in  | 1                | APB write strobe    |
| `pwdata`   | in  | `APB_DATA_WIDTH` | APB write data      |
| `prdata`   | out | `APB_DATA_WIDTH` | APB read data       |
| `pready`   | out | 1                | APB ready           |
| `pslverr`  | out | 1                | APB error           |

### Camera Interface

| Port                        | Dir | Width        | Description                       |
|-----------------------------|-----|--------------|-----------------------------------|
| `pixel_clk`                 | in  | 1            | Pixel clock                       |
| `pixel_rst_n`               | in  | 1            | Active-low reset (transceiver lock)|
| `frame_valid_in`            | in  | 1            | Frame valid from camera pipeline  |
| `line_valid_in`             | in  | 1            | Line valid from camera pipeline   |
| `cam_data_in`               | in  | `DATA_WIDTH` | Pixel data from camera pipeline   |
| `mux_enable`                | out | 1            | Current MUX enable state          |
| `mux_select`                | out | 1            | Current destination (0=8GB, 1=16GB)|
| `ddr4_8gb_frame_valid_out`  | out | 1            | Frame valid to DDR4 8 GB path     |
| `ddr4_8gb_line_valid_out`   | out | 1            | Line valid to DDR4 8 GB path      |
| `ddr4_8gb_cam_data_out`     | out | `DATA_WIDTH` | Pixel data to DDR4 8 GB path      |
| `ddr4_16gb_frame_valid_out` | out | 1            | Frame valid to DDR4 16 GB path    |
| `ddr4_16gb_line_valid_out`  | out | 1            | Line valid to DDR4 16 GB path     |
| `ddr4_16gb_cam_data_out`    | out | `DATA_WIDTH` | Pixel data to DDR4 16 GB path     |

## Register Map

APB byte address = `localparam_value × 4` (address decoded on `paddr[6:2]`).

| Byte Addr | Name             | Access | Description                                              |
|-----------|------------------|--------|----------------------------------------------------------|
| `0x00`    | `MUX_CLEAR`      | R/W    | Write `1` to clear state and start routing. Self-clears to `0` via ack handshake. Poll for `0` to confirm completion. |
| `0x04`    | `MUX_ENABLE`     | R      | Current MUX enable state (CDC-synced from pixel clock domain) |
| `0x08`    | `MUX_SELECT`     | R      | Current destination select (CDC-synced): `0`=8 GB, `1`=16 GB |
| `0x0C`    | `DDR4_16GB_FULL` | R      | DDR4 16 GB full flag (CDC-synced)                        |
| `0x10`    | `DDR4_8GB_FULL`  | R      | DDR4 8 GB full flag (CDC-synced)                         |