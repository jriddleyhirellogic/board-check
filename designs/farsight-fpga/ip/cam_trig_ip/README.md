# Camera Trigger IP

A camera trigger generator with APB interface for controlling IMX sensor XTRIG timing. The module generates a precise periodic trigger pulse with configurable low-time, frame period, and frame count. Timing values are programmed in microseconds via APB registers and converted to clock cycles internally. The `START` register auto-clears when the capture sequence finishes.

- **Active-low trigger**: `xtrig` is high in IDLE, pulled low for the configured low-time each frame period
- **Finite or infinite capture**: Set `frame_capture_amount = 0` for continuous streaming
- **ctrl_valid/ctrl_ready handshake**: Register values are forwarded to the trigger core only when it is ready (IDLE)
- **busy**: held high from `start` until `finish`; readable via APB `BUSY` register
- **xtrig_int**: 4-cycle pulse on `pclk` when a capture sequence starts; connect to RISC-V interrupt input

## FSM States

| State              | Description                                              |
|--------------------|----------------------------------------------------------|
| `OFF`              | Module disabled (`en = 0`), xtrig deasserted             |
| `IDLE`             | Enabled, waiting for `start`, xtrig held high            |
| `XTRIG_LOW_PERIOD` | Trigger low phase (duration = `xtrig_low_time` us)       |
| `XTRIG_HIGH_PERIOD`| Trigger high phase (duration = `frame_capture_time - xtrig_low_time` us) |
| `DONE`             | All frames captured, `finish` pulses for 1 cycle         |

## Parameters

| Parameter        | Default | Description                     |
|------------------|---------|---------------------------------|
| `APB_DATA_WIDTH` | 32      | APB data bus width              |
| `APB_ADDR_WIDTH` | 32      | APB address bus width           |
| `CLOCK_FREQ_MHZ` | 50      | Trigger clock frequency in MHz  |

## Ports

| Port                   | Dir | Width | Description                                 |
|------------------------|-----|-------|---------------------------------------------|
| `pclk`                 | in  | 1     | APB clock                                   |
| `presetn`              | in  | 1     | APB active-low reset                        |
| `penable`              | in  | 1     | APB enable                                  |
| `psel`                 | in  | 1     | APB peripheral select                       |
| `paddr`                | in  | 32    | APB address bus                             |
| `pwrite`               | in  | 1     | APB write request                           |
| `pwdata`               | in  | 32    | APB write data                              |
| `prdata`               | out | 32    | APB read data                               |
| `pready`               | out | 1     | APB ready                                   |
| `pslverr`              | out | 1     | APB slave error                             |
| `xtrig_clk`            | in  | 1     | Trigger clock domain                        |
| `xtrig_rst_n`          | in  | 1     | Trigger active-low reset                    |
| `en`                   | in  | 1     | Module enable (OFF → IDLE)                  |
| `rtc_sec`              | in  | 32    | RTC seconds (scheduler mode)                |
| `rtc_nsec`             | in  | 32    | RTC nanoseconds (scheduler mode)            |
| `lvds_start`           | in  | 1     | LVDS trigger input (LVDS mode)              |
| `xtrig`                | out | 1     | Camera trigger output (active-low pulse)    |
| `start`                | out | 1     | Capture start pulse                         |
| `finish`               | out | 1     | Capture complete (1-cycle pulse)            |
| `xtrig_int`            | out | 1     | Interrupt to RISC-V: 4-cycle pulse on start |
| `xtrig_low_time`       | out | 28    | Current low-time value (clock cycle count)  |
| `frame_capture_time`   | out | 24    | Current frame period value (us)             |
| `frame_capture_amount` | out | 10    | Current frame count value                   |

## Register Map

| Offset | Name                   | Width | Access | Description                                              |
|--------|------------------------|-------|--------|----------------------------------------------------------|
| `0x00` | `XTRIG_LOW_TIME`       | 22    | R/W    | Trigger low-time in microseconds                         |
| `0x04` | `FRAME_CAPTURE_TIME`   | 24    | R/W    | Total frame period in microseconds                       |
| `0x08` | `FRAME_CAPTURE_AMOUNT` | 10    | R/W    | Number of frames to capture (0 = infinite)               |
| `0x0C` | `START`                | 1     | R/W    | Write 1 to begin capture sequence (auto-clears on finish)|
| `0x10` | `XTRIG_SRC_SEL`        | 2     | R/W    | Trigger source: `0`=manual, `1`=scheduler, `2`=LVDS      |
| `0x14` | `SCHEDULER_TIME_SEC`   | 32    | R/W    | RTC seconds value to trigger on (scheduler mode)         |
| `0x18` | `SCHEDULER_TIME_MSEC`  | 10    | R/W    | RTC milliseconds value to trigger on (scheduler mode)    |
| `0x1C` | `BUSY`                 | 1     | R      | 1 while capture sequence is running                      |