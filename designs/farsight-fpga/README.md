# Farsight-FPGA

High-speed camera interface and image processing FPGA design for space applications.

**Target Device:** Microchip PolarFire MPF500TS (mpf500ts-fc1152m)  
**Camera Sensor:** Framos IMX531 series


## Overview

Farsight-FPGA provides gateware for interfacing with IMX53x camera sensors and streaming image data to a payload computer over Ethernet. The design handles high-speed camera data acquisition, DDR4 frame buffering, and UDP-based image transmission.

### Key Features

- **Camera Interface:** SLVSEC receiver for IMX531 camera sensors
- **Memory Management:** Dual DDR4 controllers (8GB + 16GB) with DMA engines for frame buffering
- **Network Stack:** Custom UDP/IP implementation for low-latency image streaming over Ethernet
- **Processing Core:** RISC-V MiV32 softcore processor for system control
- **Peripheral Support:** Focus mechanism control (stepper motor, LVDT), PPS timing, QSPI flash
- **Debug Infrastructure:** Hardware versioning, heartbeat monitor, and APB-based debug interface

## Getting Started

### Prerequisites

- Microchip Libero SoC Design Suite (2024 or later)
- Git with submodule support

### Clone and Initialize

```bash
git clone <repository-url>
cd farsight-fpga
git submodule update --init --recursive
```

### Build the FPGA Project

#### Using Makefile

The project includes a Makefile for automated builds. Ensure Libero is in your PATH, then run:

```bash
# Full build (synthesis, place and route, bitstream generation) with RISC-V sNVM initialization
make VERSION=2.0.1 BUILD=4

# Create Libero project only without synthesis and place and route
make no-synth VERSION=2.0.1 BUILD=4

# Full build without RISC-V sNVM initialization
make no-riscv-init VERSION=2.0.1 BUILD=4

# Show available targets
make help
```

##### Hardware version

`VERSION` and `BUILD` are required for every build target. They set the read-only
`BUILD_VERSION` register exposed by the `hw_version_ip` APB peripheral:

- `VERSION=<major>.<minor>.<fix>` — for example `2.0.1` (major `2`, minor `0`, fix `1`)
- `BUILD=<build>` — for example `4`

Each of the four fields is one byte and must be in the range `0-255`. They are packed into
the 32-bit `BUILD_VERSION` register as:

```
BUILD_VERSION = (major << 24) | (minor << 16) | (fix << 8) | build
```

The values are substituted into `ip/hw_version_ip/src/hw_version_apb_reg.sv` at build
time from the template in `ip/hw_version_ip/template/`, along with the git commit hash
and UTC build timestamp.

The Makefile will automatically check for Libero availability and invoke the build scripts. Build outputs are exported to `build/export_*` directories.

## Architecture

The design consists of hierarchical block modules under the [bd/](bd/) directory:

- **cam_rx_hier:** Camera receiver with SLVSEC deserializer and frame parser
- **dma_write_hier / dma_read_hier:** DMA engines for DDR4 frame write and read operations
- **udp_hier:** UDP/IP stack for Ethernet-based image transmission
- **eth1_hier / eth2_hier:** Dual Ethernet MAC controllers
- **riscv_hier:** RISC-V processor subsystem with APB peripherals
- **ddr4_8gb_hier / ddr4_16gb_hier:** DDR4 memory controllers and interfaces
- **rst_hier:** System reset and clock management
- **focus_mech:** Stepper motor and LVDT control for focus mechanism
- **pps_hier:** Pulse-per-second timing interface
- **hk_hier:** Housekeeping and monitoring

## Project Structure

```
farsight-fpga/
├── bd/                          # Block design TCL scripts (hierarchical modules)
├── build/                       # Build outputs (auto-generated projects and bitstreams)
├── constr/                      # Design constraints (I/O and timing)
│   ├── fp/                      # Floorplanning PDC files
│   ├── io/                      # Pin assignment PDC files
│   └── sdc/                     # Timing constraint SDC files
├── ip/                          # Custom IP cores (SystemVerilog/Verilog HDL)
├── riscv_init/                  # Contains initialization RISC-V hex file
├── script/                      # Build automation and utility scripts
├── support/                     # Support resources (software, Python tools)
│   ├── sw/                      # RISC-V firmware (C/C++ with CMake)
│   └── py-script/               # Python utilities (UDP receiver, etc.)
├── sim/                         # Simulation testbenches
├── synth.tcl                    # Main synthesis script
└── synth_farsight_avionics.tcl  # Top-level build wrapper
```

### Directory Details

- **bd/**: TCL scripts for generating hierarchical block designs using Libero SmartDesign
- **build/**: Auto-generated Libero projects and build artifacts. Bitstream and FlashPro job files are exported to `build/export_*` subdirectories
- **constr/**: Floorplanning (PDC), I/O constraints (PDC) and timing constraints (SDC). Pin assignments use a dictionary-based approach where `pins.tcl` maps port names to FPGA pins, enabling CSV-based pinout generation
- **ip/**: Custom HDL IP cores including DMA controllers, UDP stack, camera interface logic, and peripheral controllers
- **riscv_init/**: Hex file used to configure the RISC-V SRAM and initialize from sNVM
- **script/**: TCL and Python utilities for project configuration, build automation, and I/O generation
- **support/sw/**: Firmware for the RISC-V MiV32 softcore processor (C/C++ with CMake build system)
- **synth.tcl**: Core synthesis script that instantiates IPs, generates block designs, runs synthesis/place-and-route, and exports the final bitstream
