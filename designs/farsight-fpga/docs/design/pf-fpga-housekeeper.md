<!--
Generated from farsight-doc/04-section-sdd/pf-fpga-housekeeper.tex at commit 81efafc.

Regenerate with:
  python3 <workspace>/docs/icd/tex2md.py \
      <workspace>/farsight-doc/04-section-sdd/pf-fpga-housekeeper.tex > pf-fpga-housekeeper.md

The design is the source of truth. Where the LaTeX source disagreed with the
RTL, the RTL was followed. Note that the register and command sections of
farsight-doc are stale relative to the firmware and were deliberately not
migrated.
-->

#### PolarFire FPGA Housekeeper (HK) Architecture

![Farsight Avionics PolarFire FPGA Housekeeper Component](figures/farsight-pf-hk.png)

_Figure: Farsight Avionics PolarFire FPGA Housekeeper Component_

The PolarFire FPGA Housekeeper provides the interface between the RISC-V firmware
and the system power management.
the figure below shows the overral structure of the HK.
Its primary functions are:

- Receive power status signals from the ProASIC3 FPGA Housekeeper
- Control power enable signals for software-controlled power domains
- Provide miscellaneous inter-FPGA communication signals

The housekeeper hierarchy consists of two CoreGPIO instances accessible via APB:

- **gpi_hk_status**: 32-bit input GPIO for power status monitoring
- **gpo_hk_pwr_ctrl**: 32-bit output GPIO for power enable control

**Power Status GPIO (Input)**

the table below shows the power status input bits received from the ProASIC3 Housekeeper and other system status signals.

| **Bit** | **Name** | **Description** |
| --- | --- | --- |
| 0 | pa3_pwr_status | ProASIC3 power good status |
| 1 | step_down_pwr_status | Step-down regulator power good |
| 2 | ddr8gb_pwr_status | DDR4 8 GB power good |
| 3 | ddr16gb_pwr_status | DDR4 16 GB power good |
| 4 | pf_pwr_status | PolarFire power good |
| 5 | lvds_pwr_status | LVDS interface power good |
| 6 | eth1_pwr_status | Ethernet 1 PHY power good |
| 7 | eth2_pwr_status | Ethernet 2 PHY power good |
| 8 | stepper_pri_pwr_status | Primary stepper motor power good |
| 9 | stepper_sec_pwr_status | Secondary stepper motor power good |
| 10 | lvdt_pwr_status | LVDT sensor power good |
| 11 | cam_pwr_status | Camera power good (also controls SPI tri-state buffer) |
| 12-27 | pa3_to_pf_misc[0:15] | Miscellaneous ProASIC3 to PolarFire signals |
| 28 | Reserved | Tied to GND |
| 29-31 | pa3_fw_version[2:0] | ProASIC3 firmware version (3 bits) |

_Table: Housekeeper Power Status GPIO (Input)_

**Power Control GPIO (Output)**

the table below shows the power enable control bits that are sent to the ProASIC3 Housekeeper to control power domain enables.

| **Bit** | **Name** | **Default** | **Description** |
| --- | --- | --- | --- |
| 0 | lvds_pwr_en | 0 | LVDS interface power enable |
| 1 | eth1_pwr_en | 0 | Ethernet 1 PHY power enable |
| 2 | eth2_pwr_en | 0 | Ethernet 2 PHY power enable |
| 3 | stepper_pri_pwr_en | 0 | Primary stepper motor power enable |
| 4 | stepper_sec_pwr_en | 0 | Secondary stepper motor power enable |
| 5 | lvdt_pwr_en | 0 | LVDT sensor power enable |
| 6 | cam_pwr_en | 0 | Camera power enable |
| 7 | cam_osc_en | 0 | Camera oscillator enable |
| 8-31 | Reserved | 0 | Unused |

_Table: Housekeeper Power Control GPIO (Output)_

**Camera Power Interlocks**

The camera subsystem includes automatic interlocks based on the `cam_pwr_status` signal:

- **cam_spi_tribuff_en**: Directly driven by `cam_pwr_status`. The camera SPI signals are tri-stated when camera power is off.
- **cam_buff_en_n**: Inverted `cam_pwr_status`. The camera buffer is enabled (active low) only when camera power is good.

This ensures that camera communication interfaces are only active when the camera power domain is properly powered.
