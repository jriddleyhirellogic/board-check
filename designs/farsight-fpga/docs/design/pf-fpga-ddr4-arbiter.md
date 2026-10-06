<!--
Generated from farsight-doc/04-section-sdd/pf-fpga-ddr4-arbiter.tex at commit 81efafc.

Regenerate with:
  python3 <workspace>/docs/icd/tex2md.py \
      <workspace>/farsight-doc/04-section-sdd/pf-fpga-ddr4-arbiter.tex > pf-fpga-ddr4-arbiter.md

The design is the source of truth. Where the LaTeX source disagreed with the
RTL, the RTL was followed. Note that the register and command sections of
farsight-doc are stale relative to the firmware and were deliberately not
migrated.
-->

#### DDR AXI4 Arbiter

Each DDR4 memory bank has a dedicated DDR AXI4 Arbiter instance [ddr-axi4-arbiter-ug] that provides the AXI4 interface between the fabric logic and the DDR4 MIG. the table below shows the configuration for both arbiters.

| **Parameter** | **16 GB Arbiter** | **8 GB Arbiter** |
| --- | --- | --- |
| AXI Data Width | 512 bits | 256 bits |
| AXI Address Width | 39 bits | 38 bits |
| AXI ID Width | 4 bits | 4 bits |
| Read Channels | 1 | 1 |
| Write Channels | 1 | 1 |

_Table: DDR4 AXI4 Arbiter Configuration_

Each arbiter is configured with one read channel and one write channel. The write channel receives camera frame data from the DMA Write module, while the read channel serves DMA Read requests for data export via UDP or PCIe. The arbiter connects directly to the CoreDDR_LiteAXI wrapper of the DDR4 MIG, operating in the 150 MHz DDR4 user clock domain.

**DDR Arbiter Timing Waveform**

The diagram  show the signaling interface
Arbiter write channel and diagram  shows
signaling interface for Arbiter's read channel.
and read channel. For further information please refer to  [ddr-axi4-arbiter-ug].

![Timing Diagram for Writing into Memory [ddr-axi4-arbiter-ug]](figures/pf-arbiter-write-ch-waveform.png)

_Figure: Timing Diagram for Writing into Memory [ddr-axi4-arbiter-ug]_

![Timing Diagram for Reading from Memory [ddr-axi4-arbiter-ug]](figures/pf-arbiter-read-ch-waveform.png)

_Figure: Timing Diagram for Reading from Memory [ddr-axi4-arbiter-ug]_
