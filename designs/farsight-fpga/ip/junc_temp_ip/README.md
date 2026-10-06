# HW Version IP

A read-only APB register bank that exposes FPGA die junction temperature to software from the TVS IP.

- **Read-only registers**: Write operations are accepted on the APB bus but have no effect

## Parameters

| Parameter        | Default | Description             |
|------------------|---------|-------------------------|
| `APB_DATA_WIDTH` | 32      | APB data bus width      |
| `APB_ADDR_WIDTH` | 32      | APB address bus width   |

## Ports

| Port      | Dir | Width | Description              |
|-----------|-----|-------|--------------------------|
| `pclk`    | in  | 1     | APB clock                |
| `presetn` | in  | 1     | APB active-low reset     |
| `penable` | in  | 1     | APB enable               |
| `psel`    | in  | 1     | APB peripheral select    |
| `paddr`   | in  | 32    | APB address bus          |
| `pwrite`  | in  | 1     | APB write request        |
| `pwdata`  | in  | 32    | APB write data           |
| `prdata`  | out | 32    | APB read data            |
| `pready`  | out | 1     | APB ready                |
| `pslverr` | out | 1     | APB slave error          |

## Register Map

| Offset | Name                 | Width | Access | Description                          |
|--------|----------------------|-------|--------|--------------------------------------|
| `0x00` | `JUNC_TEMP`          | 32    | R      | FPGA die junction temperature        |
