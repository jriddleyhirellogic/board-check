# Camera Fault Detector IP

Monitors camera health and latches a fault flag under two conditions: `frame_valid` failing to arrive within a configurable timeout after `xtrig` rises, or `cam_pwr_status` dropping low at any point between `capture_start` and `capture_finish`. The fault is clearable via an APB register write. CDC synchronizers are included for `frame_valid` and `fault_clear`, which cross into the trigger clock domain.

- **Timeout fault**: starts counting on the rising edge of `xtrig`; latches if `frame_valid` does not assert within `TIMEOUT_US` microseconds
- **Power fault**: latches if `cam_pwr_status` deasserts while a capture is in progress
- **Clearable**: write `1` to `FAULT_CLEAR` to deassert both fault latches; write `0` to re-arm

## Parameters

| Parameter        | Default | Description                                         |
|------------------|---------|-----------------------------------------------------|
| `APB_DATA_WIDTH` | 32      | APB data bus width                                  |
| `APB_ADDR_WIDTH` | 32      | APB address bus width                               |
| `CLOCK_FREQ_MHZ` | 50      | Trigger clock frequency in MHz                      |
| `TIMEOUT_US`     | 1000    | Timeout window for `frame_valid` after `xtrig` (µs) |

## Ports

| Port             | Dir | Width | Description                                      |
|------------------|-----|-------|--------------------------------------------------|
| `pclk`           | in  | 1     | APB clock                                        |
| `presetn`        | in  | 1     | APB active-low reset                             |
| `penable`        | in  | 1     | APB enable                                       |
| `psel`           | in  | 1     | APB peripheral select                            |
| `paddr`          | in  | 32    | APB address bus                                  |
| `pwrite`         | in  | 1     | APB write request                                |
| `pwdata`         | in  | 32    | APB write data                                   |
| `prdata`         | out | 32    | APB read data                                    |
| `pready`         | out | 1     | APB ready                                        |
| `pslverr`        | out | 1     | APB slave error                                  |
| `xtrig_clk`      | in  | 1     | Trigger clock domain (for fault detector core)   |
| `xtrig_rst_n`    | in  | 1     | Trigger active-low reset                         |
| `xtrig`          | in  | 1     | Camera trigger input                             |
| `frame_valid`    | in  | 1     | Frame valid from camera (async to `xtrig_clk`)   |
| `capture_start`  | in  | 1     | Capture window open                              |
| `capture_finish` | in  | 1     | Capture window close                             |
| `cam_pwr_status` | in  | 1     | Camera power status (must stay high during capture) |

## Register Map

| Offset  | Name          | Width | Access | Description                                        |
|---------|---------------|-------|--------|----------------------------------------------------|
| `0x00`  | `FAULT`       | 1     | R      | `[0]` = fault status (timeout fault OR power fault) |
| `0x04`  | `FAULT_CLEAR` | 1     | R/W    | `[0]` = write `1` to clear faults, write `0` to re-arm |