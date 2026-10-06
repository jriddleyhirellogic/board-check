<!--
Generated from farsight-doc/04-section-sdd/pf-fpga-architecture.tex at commit 81efafc.

Regenerate with:
  python3 <workspace>/docs/icd/tex2md.py \
      <workspace>/farsight-doc/04-section-sdd/pf-fpga-architecture.tex > pf-fpga-architecture.md

The design is the source of truth. Where the LaTeX source disagreed with the
RTL, the RTL was followed. Note that the register and command sections of
farsight-doc are stale relative to the firmware and were deliberately not
migrated.
-->

## FPGA Design Document

This document describes the FARSIGHT FPGA architecture in details.

### Farsight PolarFire FPGA Chip

| **Category** | **Specification** | **Value** |
| --- | --- | --- |
| FPGA Fabric | Logic Elements (4LUT + DFF) | 481K |
|  | Math Blocks (18 x 18 MACC) | 1480 |
|  | LSRAM Blocks (20 Kb) | 1520 |
|  | uSRAM Blocks (64 x 12) | 4440 |
|  | Total RAM (Mb) | 33 |
|  | uPROM (Kb) | 513 |
|  | User DLLs/PLLs | 8 each |
| High-Speed I/O | 250 Mbps - 12.7 Gbps Transceiver Lanes | 24 |
|  | PCIe Gen 2 Endpoints/Root Ports | 2 |
| Total I/O | Total User I/O | 584 |

_Table: MPF500T FPGA Specifications [polarfire-mpf500t-fpga]_

In this section, we will review the main components of the FAV Hardware (FAV-HW).
The HW will consist of 32GB of DDR4 memory as volatile memory storage.
The DDR4 space will be soly used for buffering captured images from the camera.
The HW also consist of a radiation tolerant None Volatile memory of
size 64 MB with SPI interface. The external NVM will be used
for storing FAV parameters and critical TLM logs. There will be also two
radiation tolerant Ethernet PHY VSC8541RT used as redundancy backup.
The HW also will provide 148.5 MHz Ref clock for the XCVR usage and 50 MHz fabric
clock for the Programmable Logic clocking. The FARSIGHT target FPGA chip is
Microchip PolarFire radiation tolerant MPF500T. the table below
shows the MPF500T specification.

### FPGA Architecture

![Farsight Avionics Computer FPGA Architecture](figures/fav-architecture.png)

_Figure: Farsight Avionics Computer FPGA Architecture_

The FARSIGHT FPGA consists of the following main groups of design architecture:

1. **Camera control and data receiving**
2. **Data write and read to the DDR4 memory space pipeline**
3. **UDP Data export components**
4. **Ethernet MAC**
5. **Housekeeper**
6. **Focus Mechanism**
7. **Softcore RISC-V MiV32 processing system**

Each of these components will be discussed in detail in the following sections.
