# Camera Flow Sync IP

A pipeline register stage for camera SLVSEC output synchronization. This module registers the output signals of the SLVSEC IP, combines `line_valid` and `ebd_valid` (embedding valid) into a single valid signal, and outputs everything as registered signals. The double-registering solves pixel clock domain timing when sending signals down to the rest of the pipeline. `frame_valid_out` is additionally extended by `EXTEND_CYCLES` cycles on its falling edge so downstream logic has guaranteed overlap with the last active data.

## Architecture

```
                    ┌─────────────────────────────────────────────────────┐
                    │                  cam_flow_sync                      │
                    │                                                     │
  frame_valid_in ──►│─► [Reg] ──► [Reg] ──► [FE] ──► [FSM] ──► frame_valid_out
                    │                                   ▲                │
                    │                            EXTEND_CYCLES           │
                    │                                                     │
   line_valid_in ──►│─► [Reg] ─┐                                         │
                    │          ├─► [OR] ──► [Reg] ──► line_or_ebd_valid_out
    ebd_valid_in ──►│─► [Reg] ─┘                                         │
                    │                                                     │
      data_in[N] ──►│─► [Reg] ──► [Reg] ──►  data_out[N]                │
                    │                                                     │
                    └─────────────────────────────────────────────────────┘
                       clk ▲         rst_n ▲
```

- **2-cycle rising-edge latency**: `frame_valid_out` asserts 2 cycles after `frame_valid_in`
- **Trailing extension**: `frame_valid_out` is held high for `EXTEND_CYCLES` additional cycles after the falling edge of `frame_valid_in` is detected
- **Valid merging**: `line_or_ebd_valid_out = line_valid_reg | ebd_valid_reg`

## Parameters

| Parameter       | Default | Description                                                      |
|-----------------|---------|------------------------------------------------------------------|
| `DATA_WIDTH`    | 384     | Width of the pixel data bus (bits)                               |
| `EXTEND_CYCLES` | 10      | Number of cycles to hold `frame_valid_out` high after falling edge |

## Ports

| Port                    | Dir | Width        | Description                                                        |
|-------------------------|-----|--------------|--------------------------------------------------------------------|
| `clk`                   | in  | 1            | Pixel clock                                                        |
| `rst_n`                 | in  | 1            | Active-low asynchronous reset                                      |
| `frame_valid_in`        | in  | 1            | Frame valid from SLVSEC                                            |
| `line_valid_in`         | in  | 1            | Line valid from SLVSEC                                             |
| `ebd_valid_in`          | in  | 1            | Embedded data valid from SLVSEC                                    |
| `data_in`               | in  | `DATA_WIDTH` | Pixel data from SLVSEC                                             |
| `frame_valid_out`       | out | 1            | Registered frame valid, extended by `EXTEND_CYCLES` on falling edge |
| `line_or_ebd_valid_out` | out | 1            | Registered (line_valid OR ebd_valid)                               |
| `data_out`              | out | `DATA_WIDTH` | Registered pixel data                                              |

## Register Map

This module has no software-accessible registers. It is a purely datapath element.