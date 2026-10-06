<!--
Generated from farsight-doc/04-section-sdd/pf-fpga-ddr4-mig.tex at commit 81efafc.

Regenerate with:
  python3 <workspace>/docs/icd/tex2md.py \
      <workspace>/farsight-doc/04-section-sdd/pf-fpga-ddr4-mig.tex > pf-fpga-ddr4-mig.md

The design is the source of truth. Where the LaTeX source disagreed with the
RTL, the RTL was followed. Note that the register and command sections of
farsight-doc are stale relative to the firmware and were deliberately not
migrated.
-->

#### DDR4 MIG

The FARSIGHT design uses two PolarFire DDR4 Memory Interface Generator (MIG) instances to interface with the external DDR4 memory banks. Each MIG instance includes a DDR4 PHY, memory controller, and an AXI4 interface wrapper (CoreDDR_LiteAXI) for fabric connectivity.

**DDR4 Memory Interface Configuration**

the table below summarizes the configuration parameters for both DDR4 memory interfaces. The 16 GB interface provides higher bandwidth with a wider data path, while the 8 GB interface uses a narrower configuration.

| **Parameter** | **16 GB** | **8 GB** |
| --- | --- | --- |
| DDR4 DQ Width | 64 bits | 32 bits |
| AXI Data Width | 512 bits | 256 bits |
| AXI Address Width | 39 bits | 38 bits |
| AXI ID Width | 4 bits | 4 bits |
| DDR Clock Frequency | 600 MHz (1200 MT/s) | 600 MHz (1200 MT/s) |
| User Clock Frequency | 150 MHz | 150 MHz |
| PLL Reference Clock | 50 MHz | 50 MHz |
| Row Address Width | 17 bits | 16 bits |
| Column Address Width | 10 bits | 10 bits |
| Bank Address / Bank Group | 2 / 2 bits | 2 / 2 bits |
| ECC | Enabled | Enabled |

_Table: DDR4 MIG Configuration Parameters_

**DDR4 Timing Parameters**

Both memory interfaces share common timing parameters optimized for DDR4-2400 operation, as shown in the table below.

| **Parameter** | **Value** | **Description** |
| --- | --- | --- |
| CAS Latency (CL) | 12 | Read latency in clock cycles |
| CAS Write Latency (CWL) | 11 | Write latency in clock cycles |
| tRCD | 13.75 ns | Row to Column Delay |
| tRP | 13.75 ns | Row Precharge Time |
| tRAS | 32 ns | Row Active Time |
| tRC | 45.75 ns | Row Cycle Time |
| tRFC | 350 ns | Refresh Cycle Time |
| tREFI | 7.8 us | Refresh Interval |
| tFAW | 46.7 ns | Four Activate Window |
| tWR | 15 ns | Write Recovery Time |

_Table: DDR4 Timing Parameters_
