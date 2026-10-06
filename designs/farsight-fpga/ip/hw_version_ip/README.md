# HW Version IP

A read-only APB register bank that exposes FPGA build metadata to software. The source file is generated at build time from a template, with placeholders (`@AUTO UPDATE AT BUILD@`) replaced by the actual build version, git hash, and UTC timestamp.

- **Read-only registers**: Write operations are accepted on the APB bus but have no effect
- **Build-time generation**: `template/hw_version_apb_reg.sv.template` is processed during the build to produce `src/hw_version_apb_reg.sv`

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
| `0x00` | `BUILD_VERSION`      | 32    | R      | FPGA build version number            |
| `0x04` | `BUILD_GIT_HASH`     | 32    | R      | Git commit hash (truncated to 32-bit)|
| `0x08` | `BUILD_TIME_UTC_SEC` | 32    | R      | Build timestamp (seconds since epoch)|
