# PolarFire firmware -- Low-Level Requirements

Scope: FARSIGHT PolarFire embedded RISC-V firmware behavior at FPGA registers, camera/PHY interfaces and host-facing image-transfer boundaries.

Conventions, identifier scheme and trace fields are defined in [`conventions.md`](../../../docs/requirements/conventions.md). This document is Class B under [`criticality.md`](../../../docs/requirements/criticality.md), so it specifies external interfaces, throughput, latency, ICD-visible register behavior and malformed-input responses rather than internal RTL or firmware structure.

## Design source

Design evidence cites the **flight firmware**:

- `farsight-avionics-sw/Camera/` -- the application, a FreeRTOS build running on the
  MIV_RV32 soft core instantiated in the PolarFire fabric
  (`Camera/include/FreeRTOSConfig.h:33-34`, 50 MHz, 1 ms tick).
- `farsight-avionics-sw/Bootloader/` -- the boot and image-load path.
- `farsight-avionics-sw/utils/` -- the host-side receiver and converter.

Paths are relative to the workspace root, not to this repository.

> **Re-adjudicated 2026-09-17.** Every requirement in this document previously
> cited `farsight-fpga/support/sw/`. That tree is the **lab functional-test
> harness** -- its own README describes it as "FPGA SW functional test support"
> that exports frames "to a lab computer" -- and it has since been deleted from
> the repository. It is not the flight software. The two trees target the same
> soft core and implement overlapping scope, which is why the substitution went
> unnoticed: `main.c`, `eth.c`, `pps.c` and `util.c` exist in both.
>
> The decisive check is the ICD. CM-01979 is titled *FLIGHT SOFTWARE*, and every
> register it defines -- `SENSOR_EXPO_USEC_SYS_REG`, `BOOT_COUNT_SYS_REG`,
> `UPDATE_NET_ADDRESS` and the rest -- appears in `Camera/` and in **no** file of
> the deleted harness.
>
> The two implementations are not close. The harness runs a linear `main()` that
> powers the camera up, captures, and streams every stored frame in an infinite
> loop with compile-time constants for every parameter. The flight application
> runs four FreeRTOS tasks behind a six-state mode machine, boots into low power
> with the sensor off, takes commands over RS-422 with CRC and ACK/NAK, and
> drives capture and egress from host-writable registers. Adjudicating the flight
> design against the harness therefore understated it substantially: of the 30
> findings raised against this firmware, **11 were artefacts of the harness** and
> are withdrawn below. Three survive in a different and more serious form, and
> four new ones are raised that the harness could not have exposed.
>
> This is recorded rather than quietly corrected because the failure is
> instructive: nothing in the requirement set named its own design source, so
> there was no artefact against which the substitution could be checked. See
> [A-13](../../../docs/requirements/requirements-gap-analysis.md#a-13---name-the-design-source-in-every-requirement-document).

## Areas

| Area | Scope | Count |
| --- | --- | ---: |
| `MEM` | Firmware-visible memory map | 1 |
| `DMA` | Frame-buffer control | 6 |
| `INIT` | Startup external behavior | 11 |
| `ETH` | Ethernet MAC/PHY behavior | 6 |
| `UDP` | UDP network configuration and transfer | 8 |
| `CAM` | Camera configuration and trigger control | 14 |
| `PPS` | PPS time initialization | 3 |
| `TLM` | Image metadata and telemetry | 8 |
| `ERR` | Error handling | 5 |
| `HOST` | Host wire-contract utilities | 5 |
| `DRV` | Derived obligations (no area segment) | 1 |
| | **Total** | **68** |

Of the 68 entries, 36 are functional requirements traced to a Jama parent, 31 are
derived requirements carrying a `Source decision`, and 1 is a design constraint.
All 31 derived requirements are pending independent review.

The derived count fell by one against the previous adjudication: `PFW-PPS-01`
had been derived because the harness compiled its epoch in, and the flight
design commands it, so the requirement now has a real parent.

Thirteen entries carry `Kind: Performance`. See [Performance coverage](#performance-coverage).

## Status summary

| Status | Meaning | Count |
| --- | --- | ---: |
| `OK` | Design satisfies the requirement | 53 |
| `GAP` | Design does not meet the requirement | 10 |
| `AMBIG` | Wording unclear or unverifiable as written | 3 |
| `DEFECT` | Design is internally inconsistent | 2 |

The shift from the previous adjudication is large, and almost all of it is the
source correction rather than any change to the design:

| Status | Against the harness | Against flight |
| --- | ---: | ---: |
| `OK` | 39 | **53** |
| `GAP` | 19 | **10** |
| `AMBIG` | 3 | 3 |
| `DEFECT` | 7 | **2** |

The flight firmware satisfies a substantial set of obligations the harness did
not implement: command ingestion with ACK/NAK, a six-state mode machine that
boots into low power, request-addressed and bounds-checked transfer,
register-driven imaging parameters, and a bounded transfer timeout that lands in
a fault state. Fourteen requirements moved to `OK` on that basis.

What remains `GAP` or `DEFECT` is a shorter and more pointed list than before,
and none of it is incidental: no Ethernet command path, no over-temperature
threshold or response, no reporting of the DMA and UDP error registers, a
metadata read with no completion check, a station MAC that disagrees with a
source MAC defaulting to zero, a frame-rate ceiling below the system
requirement, a PPS lock indicator stubbed to always-true, and a host converter
that does not decode the metadata record the firmware emits.

## Performance coverage

Class B buys interface and performance requirements in exchange for giving up
state-level depth. The ten performance requirements added on 2026-09-17 are
retained and re-adjudicated here; several improved against the flight design,
which implements bounded timeouts the harness lacked.

| Requirement | Bounds | Status |
| --- | --- | --- |
| `PFW-DMA-17` | Frame-read completion timeout | OK |
| `PFW-INIT-19` | Reset to capture-ready | AMBIG |
| `PFW-ETH-14` | Autonegotiation abandon time | AMBIG |
| `PFW-UDP-13` | Image egress rate | OK |
| `PFW-UDP-14` | End-to-end datagram delivery | GAP |
| `PFW-CAM-39` | Minimum admitted frame period | OK |
| `PFW-CAM-40` | Maximum admitted frame rate | GAP |
| `PFW-TLM-15` | Image timestamp accuracy | GAP |
| `PFW-TLM-16` | Telemetry response latency | OK |
| `PFW-ERR-10` | Over-temperature detection to power-off | GAP |

Two remain `AMBIG` because the design states its bound in units the requirement
cannot be compared against -- a poll count rather than a time. An `UNMEASURED`
status value remains proposed but not adopted; see
[A-12](../../../docs/requirements/requirements-gap-analysis.md#a-12---write-the-missing-performance-requirements----polarfire-fw-done).

## MEM -- Firmware-visible memory map

### PFW-MEM-06
The firmware platform shall run timing services from a 50 MHz soft-core clock reference.
- **Constraint:** PolarFire soft-core clocking decision shared with FPGA timing
- **Design:** `farsight-avionics-sw/Camera/include/FreeRTOSConfig.h:33`
- **Verify:** ANA, HW
- **Rationale:** Startup delays, PPS programming and peripheral timeouts are calibrated from the processor clock.
- **Status:** OK
- **Evidence:** `configCPU_CLOCK_HZ` is 50000000 and `configTICK_RATE_HZ` is 1000
  (`Camera/include/FreeRTOSConfig.h:33-34`), so one scheduler tick is 1 ms and
  every `vTaskDelay()` in this document converts directly to milliseconds.

## DMA -- Frame-buffer control

### DRV-PFW-01
Firmware shall clear the camera mux when resetting DDR4 write indices.
- **Source decision:** The frame-buffer reset sequence shares state between DMA write controllers and the FPGA camera mux.
- **Design:** `farsight-avionics-sw/Camera/src/camera.c:341-348`, `farsight-avionics-sw/Camera/src/camera.c:550`
- **Imposes on:** firmware, FPGA design, verification
- **Verify:** SIM, HW
- **Rationale:** A write-index reset without a matching mux reset leaves firmware and FPGA buffer ownership out of sync.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Evidence:** `cam_mux_clear()` asserts `MUX_CLEAR`, waits 10 ms and reads the
  register back (`Camera/src/camera.c:341-348`); it is called from
  `v_Reset_Camera_Buffer()` alongside the write-index reset
  (`Camera/src/camera.c:550`).
- **Note:** Re-adjudicated from `DEFECT`. The previous `DEFECT` rested on
  `PFW-F-12`, "`MUX_CLEAR` is never deasserted", which was a property of the
  harness. The flight sequence pairs the mux clear with the index reset. The
  readback value at `Camera/src/camera.c:347` is still discarded, which is a
  weaker observation and is folded into `PFW-F-31`.
- **Note:** Former identifier PFW-DMA-03.

### PFW-DMA-04
Firmware shall configure each DDR4 read controller for the image geometry
defined in CM-01979 section 4.2.1.
- **Parent:** FAR-CDH_FPGA_L3REQ-26, FAR-TMTC_SW_L4REQ-3
- **Design:** `farsight-avionics-sw/Camera/src/camera.c:313-321`, `farsight-avionics-sw/Camera/src/camera.c:520-528`
- **Verify:** SIM, HW
- **Rationale:** The read path must reproduce the stored image frame dimensions for UDP and PCIe export.
- **Evidence:** `configure_udp_dmactrl()` programs `V_SIZE_LINE`, `H_SIZE_BYTE`
  and `H_SIZE_BEAT` (`Camera/src/camera.c:520-528`). The geometry is 4581 lines
  of 6784 bytes, 212 beats on the 8GB path and 106 on the 16GB path
  (`Camera/src/camera.c:313-321`, `Camera/include/camera.h:129`,
  `Camera/include/camera.h:132-135`).
- **Status:** OK

### PFW-DMA-14
Firmware shall detect frame-read completion before starting the next frame.
- **Source decision:** Frame-read completion is signalled by a dedicated FPGA
  interrupt, which places completion handling in an ISR and event queue rather
  than in a polling loop.
- **Imposes on:** FPGA design, verification
- **Design:** `farsight-avionics-sw/Camera/src/camera.c:861-868`, `farsight-avionics-sw/Camera/src/CameraStates/camera_transfer_state.c:80-89`
- **Verify:** SIM, HW
- **Rationale:** A transfer loop must not start the next frame until the current frame has completed.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Evidence:** `v_UDP_Transfer_Handler()` clears `FRAME_READ_DONE_IRQ` on both
  buffers and posts `UDP_TRANSFER_COMPLETE` (`Camera/src/camera.c:861-868`). The
  transfer state advances the frame index only on that event
  (`Camera/src/CameraStates/camera_transfer_state.c:80-89`).
- **Note:** Re-adjudicated from `DEFECT`, and the requirement itself is rewritten.
  It previously read "shall wait for the frame-read completion counter to
  advance", with a source decision asserting that completion "is exposed only as
  an incrementing counter, with no completion interrupt". That is false of the
  flight design: `FRAME_READ_DONE_IRQ` exists and is used. The old wording
  specified the harness's polling mechanism rather than the obligation, which is
  what made it look like a defect. `PFW-F-07` is withdrawn.

### PFW-DMA-15
Firmware shall report a DMA read timeout in telemetry.
- **Parent:** FAR-L1REQ-19, FAR-L1REQ-21
- **Design:** `farsight-avionics-sw/Camera/include/dma_read_reg.h:13-16`, `farsight-avionics-sw/Camera/include/udp_dmactrl_reg.h:47-80`
- **Verify:** SIM, HW
- **Rationale:** Transfer fault telemetry must be collected before a later frame hides the failing buffer path.
- **Status:** GAP
- **Finding:** PFW-F-05
- **Evidence:** `TIMEOUT_ERR_DMA_READ` is defined
  (`Camera/include/dma_read_reg.h:13-16`) and is never read anywhere in the
  application. The same applies to the UDP DMA control error registers
  `DMA_TIMEOUT_ERR`, `PYL_ACPT_ERR`, `SEND_LAST_ERR`, `SEND_PYL_ERR`,
  `SOF_REQ_ERR`, `WAIT_ACK_ERR` and `FRAME_XFER_TIMEOUT_ERR`
  (`Camera/include/udp_dmactrl_reg.h:47-80`). A transfer that times out is
  caught by the 500 ms state-machine timer of `PFW-DMA-17` and reported only as
  a transition to fault state; the register that says *which* path failed is
  never sampled.
- **Note:** Reworded. The previous statement -- "shall read the corresponding DMA
  read timeout status after each frame transfer" -- was satisfied literally by
  the harness's dead store while defeating the purpose. The obligation is to
  report, not to read.

### PFW-DMA-16
The transfer sequence shall address frames in an order that matches the FPGA
capture fill order.
- **Source decision:** Capture fills the 16GB buffer before the 8GB buffer, so
  the frame index space is ordered by the FPGA fill order.
- **Imposes on:** FPGA design, ground segment, verification
- **Design:** `farsight-avionics-sw/Camera/src/CameraStates/camera_transfer_state.c:103-125`, `farsight-avionics-sw/Camera/src/camera.c:421-438`
- **Verify:** HW
- **Rationale:** A frame index requested by the host must resolve to the same
  physical frame the capture wrote, or stored imagery is returned mislabelled.
- **Evidence:** `v_Transfer_Frame()` maps indices below 512 to the 16GB
  controller and indices from 512 to 767 to the 8GB controller, subtracting the
  offset (`Camera/src/CameraStates/camera_transfer_state.c:103-125`).
  `v_Fetch_Metadata()` applies the identical mapping
  (`Camera/src/camera.c:421-438`). Capacities are 512 and 256
  (`Camera/include/camera.h:139-141`).
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Note:** Reworded. The previous statement -- "the continuous transfer loop
  shall drain the 16GB buffer before the 8GB buffer" -- described the harness's
  infinite drain loop, which does not exist in flight. Transfers are
  request-addressed, so the obligation is that the index mapping match the fill
  order, not that a loop run in a fixed direction.

### PFW-DMA-12
Firmware shall program the frame index before asserting a frame read request.
- **Source decision:** The FPGA frame-read controller latches the frame index at request assertion rather than offering a separate index-commit strobe.
- **Imposes on:** FPGA design, verification
- **Design:** `farsight-avionics-sw/Camera/src/camera.c:377-395`
- **Verify:** SIM
- **Rationale:** The FPGA read controller samples the target frame index when the request is made.
- **Evidence:** `xfer_frame_via_udp()` writes `DMA_READ_FRAME_INDEX` before
  raising `FRAME_READ_REQ` (`Camera/src/camera.c:384-388`), and the same order is
  used for metadata reads (`Camera/src/camera.c:397-409`).
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK

### PFW-DMA-17
Firmware shall abandon a frame read that has not completed within 1 s +/-10%.
- **Parent:** FAR-L1REQ-19
- **Design:** `farsight-avionics-sw/Camera/src/CameraStates/camera_transfer_state.c:44`, `farsight-avionics-sw/Camera/src/CameraStates/camera_transfer_state.c:70-71`, `farsight-avionics-sw/Camera/src/CameraStates/camera_transfer_state.c:92-94`
- **Kind:** Performance
- **Verify:** SIM, HW
- **Rationale:** The completion interrupt is the only evidence that a frame read
  finished, so without a time bound the transfer state cannot tell a slow frame
  from a stopped one. The bound comes from the nominal read: one frame is
  4581 x 6784 bytes = 248.6 Mbit, which occupies 249 ms at the 1000BASE-T line
  rate the PHY is configured for.
- **Evidence:** `UDP_TRANSFER_TIMEOUT` is 500 ticks = 500 ms at the 1 ms tick
  (`Camera/src/CameraStates/camera_transfer_state.c:44`). The timer is started
  on entry and restarted for each frame
  (`camera_transfer_state.c:70-71`, `:85-86`), and expiry posts
  `CAMERA_TIMER_EXPIRED`, which transitions to `Camera_Fault_State`
  (`camera_transfer_state.c:92-94`). Abandoning at 500 ms satisfies a bound of
  1 s.
- **Status:** OK
- **Note:** Re-adjudicated from `GAP`. The margin deserves review rather than
  acceptance: 500 ms against a 249 ms nominal transfer is roughly 2x, which is
  thin for a bound whose expiry drops the payload into fault state. Raised as
  `PFW-F-32`.

## INIT -- Startup external behavior

### PFW-INIT-05
Startup firmware shall initialize the TMTC UART at the ICD base address.
- **Parent:** FAR-RS422_L3REQ-5, FAR-RS422_L3REQ-6
- **Design:** `farsight-avionics-sw/Camera/src/hw_init.c:85-87`, `farsight-avionics-sw/Camera/src/hw_init.c:98`
- **Verify:** HW
- **Rationale:** The command and telemetry UART must be ready before the payload can be commanded locally.
- **Evidence:** `v_Hw_Init()` sets the instance base to `TMTC_UART_BASE_ADDR`,
  calls `v_Init_UART()` and registers the instance for the serial task
  (`Camera/src/hw_init.c:85-98`).
- **Status:** OK

### PFW-INIT-06
The TMTC UART shall operate at 115200 baud +/-2 % after initialization.
- **Parent:** FAR-RS422_L3REQ-6
- **Design:** `farsight-avionics-sw/Camera/include/hal_uart16550.h:79`
- **Kind:** Performance
- **Verify:** HW
- **Rationale:** Ground and integration equipment use 115200 baud for the TMTC serial interface.
- **Evidence:** `BAUDRATE_115200` is the divisor 27
  (`Camera/include/hal_uart16550.h:79`), consistent with the 50 MHz reference of
  `PFW-MEM-06`.
- **Status:** OK
- **Note:** The divisor is an integer, so the realised rate is
  50 MHz / (27 x 16) = 115,740.74 baud, **+0.47 %** against 115200. That is
  within the +/-2 % stated here but is not the nominal figure, so the tolerance
  is part of the requirement rather than an implicit allowance. The housekeeper
  drives the same link from the same 50 MHz reference and carries the matching
  tolerance in `HK-UART-05`. See `AV-F-06`, which raises the same divisor error
  against `FAR-RS422_L3REQ-6`.

### PFW-INIT-07
The flight path shall present the TMTC UART for command ingestion.
- **Parent:** FAR-TMTC_SW_L4REQ-43
- **Design:** `farsight-avionics-sw/Camera/src/main.c:60-65`, `farsight-avionics-sw/Camera/src/hal/serial_comm.c:134-166`, `farsight-avionics-sw/Camera/src/serial_sm.c:53`
- **Verify:** INSP
- **Rationale:** FAR-TMTC_SW_L4REQ-43 requires bidirectional command and telemetry over the interface.
- **Status:** OK
- **Evidence:** `main()` creates `v_Serial_Comm_Task`
  (`Camera/src/main.c:60-65`). The UART receive ISR feeds every byte to
  `v_Update_Serial_SM()` (`Camera/src/hal/serial_comm.c:145`), which runs the
  framing state machine (`Camera/src/serial_sm.c:53`) and posts a completed
  message to the task, which calls `Execute_Command()`
  (`Camera/src/hal/serial_comm.c:74-80`). The path is live.
- **Note:** Re-adjudicated from `GAP`. The `GAP` rested on `PFW-F-01`, which
  reported the UART left initialized with `test_uart()` commented out and no
  parser -- true of the harness, false of flight. `PFW-F-01` is withdrawn for
  RS-422 and re-raised narrowly for Ethernet as `PFW-F-33`.

### PFW-INIT-11
Startup firmware shall initialize the SLVS-EC SPI controller before camera register access.
- **Source decision:** Camera register access is carried over the SLVS-EC SPI controller, placing controller bring-up ahead of sensor configuration.
- **Imposes on:** FPGA design, verification
- **Design:** `farsight-avionics-sw/Camera/src/camera.c:263`, `farsight-avionics-sw/Camera/src/camera.c:632`
- **Verify:** HW
- **Rationale:** The image sensor cannot be configured until its SPI control bus is live.
- **Evidence:** `SPI_init()` is called on `SLVSEC_SPI_BASE_ADDR` during camera
  instance initialization (`Camera/src/camera.c:263`), ahead of `init_slvsec()`
  (`Camera/src/camera.c:632`).
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK

### PFW-INIT-13
Startup firmware shall power on ETH1 before Ethernet MAC and PHY initialization.
- **Source decision:** ETH1 rail power is under firmware GPIO control, which puts rail enable inside the firmware startup sequence.
- **Imposes on:** hardware design, verification
- **Design:** `farsight-avionics-sw/Camera/src/camera.c:272`, `farsight-avionics-sw/Camera/src/camera.c:291`
- **Verify:** HW
- **Rationale:** The PHY and MAC initialization sequence needs the ETH1 rail available.
- **Evidence:** `ETH1_PWR_EN` is driven high (`Camera/src/camera.c:272`) before
  `init_eth1()` is called (`Camera/src/camera.c:291`).
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK

### PFW-INIT-14
Firmware shall power on the camera before enabling the camera oscillator.
- **Source decision:** The camera oscillator is enabled separately from camera power, so firmware owns the ordering between them.
- **Imposes on:** hardware design, verification
- **Design:** `farsight-avionics-sw/Camera/src/camera.c:350-375`
- **Verify:** HW
- **Rationale:** The oscillator must not drive an unpowered camera interface.
- **Evidence:** `v_Enable_Camera_Power()` orders the two GPIOs in both
  directions: powering down deasserts `CAM_OSC_EN` first
  (`Camera/src/camera.c:356`), and powering up asserts it after the rail
  (`Camera/src/camera.c:373`).
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Note:** Rescoped from "Startup firmware shall..." to "Firmware shall...".
  In flight the camera is powered down at boot and powered up on a mode command,
  so the ordering obligation applies at every transition, not only at startup.

### PFW-INIT-15
Startup firmware shall initialize CoreTSE before PHY initialization.
- **Source decision:** PHY configuration is reached through the MAC MDIO interface, so CoreTSE bring-up precedes PHY access.
- **Imposes on:** FPGA design, verification
- **Design:** `farsight-avionics-sw/Camera/src/camera.c:446-457`, `farsight-avionics-sw/Camera/src/eth.c:19-61`
- **Verify:** HW
- **Rationale:** PHY MDIO configuration depends on the MAC register interface being initialized.
- **Evidence:** `init_eth1()` maps the CoreTSE register block, including the MDIO
  management registers, before PHY configuration is attempted
  (`Camera/src/eth.c:19-61`).
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Note:** Flagged for the A-04 trim. The obligation restates how an MDIO bus is
  reached rather than an externally observable behaviour, which is the
  "stop at the boundary where ownership changes" test in `conventions.md`.

### PFW-INIT-16
Firmware shall select Ethernet egress rather than PCIe egress by default.
- **Source decision:** Ethernet was selected as the default image egress path in preference to the available PCIe path.
- **Imposes on:** system design, ground segment, verification
- **Design:** `farsight-avionics-sw/Camera/include/gpio_pin_def.h:9`
- **Verify:** HW
- **Rationale:** The as-built flight path exports imagery over Ethernet unless commanded otherwise.
- **Evidence:** `ETH_PCIE_SEL` is defined (`Camera/include/gpio_pin_def.h:9`) and
  the egress path used by the transfer state is UDP over Ethernet
  throughout. No PCIe transfer path is implemented in the application.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Finding:** PFW-F-19

### PFW-INIT-17
Firmware shall hold image capture until a start command is received.
- **Parent:** FAR-TMTC_SW_L4REQ-16, FAR-AB_L2REQ-2
- **Design:** `farsight-avionics-sw/Camera/src/CameraStates/camera_low_power_state.c:33-37`, `farsight-avionics-sw/Camera/src/command.c:273-292`
- **Verify:** HW
- **Rationale:** FAR-TMTC_SW_L4REQ-16 makes capture command-triggered and FAR-AB_L2REQ-2 requires initialization into Low-Power Mode; both require a command gate ahead of acquisition.
- **Status:** OK
- **Evidence:** The mode machine enters `Camera_Low_Power_State`, whose
  `ENTRANCE` handler powers the camera down
  (`Camera/src/CameraStates/camera_low_power_state.c:33-37`). Capture requires
  `START_ACQ_SYS_CMD`, which is rejected with `ERR_CMD_INVALID_MODE` unless the
  machine is in `CAMERA_ARMED_STATE` and rejected with `ERR_REG_INVALID_LIMIT`
  if the trigger is not programmable (`Camera/src/command.c:273-292`). Reaching
  armed requires two commanded transitions, low power to idle to armed
  (`Camera/src/command.c:148-184`).
- **Note:** Re-adjudicated from `GAP`; `PFW-F-02` is withdrawn. It reported that
  startup "configures trigger registers, calls `trig_capture()` ... without a
  mode state machine", which describes the harness.

### PFW-INIT-18
Firmware shall transfer stored frames when a transfer is requested.
- **Parent:** FAR-CDH_FPGA_L3REQ-12, FAR-CDH_FPGA_L3REQ-26, FAR-L1REQ-22
- **Design:** `farsight-avionics-sw/Camera/src/command.c:294-318`, `farsight-avionics-sw/Camera/src/CameraStates/camera_transfer_state.c:60-94`
- **Verify:** HW
- **Rationale:** FAR-CDH_FPGA_L3REQ-12 and FAR-L1REQ-22 make image egress request-driven.
- **Status:** OK
- **Evidence:** `XFER_BUFF_SYS_CMD` carries a starting index and a frame count,
  validates them with `u8_Check_Frame_Bounds()`, rejects a request made outside
  low-power, idle or armed state with `ERR_CMD_INVALID_MODE`
  (`Camera/src/command.c:294-318`), and drives the transfer state over exactly
  that range (`Camera/src/CameraStates/camera_transfer_state.c:60-94`).
- **Note:** Re-adjudicated from `GAP`; `PFW-F-04` is withdrawn. It reported
  transfers as neither request-addressed nor bounds-checked, which was the
  harness's fixed 0..511 / 0..255 loop.

### PFW-INIT-19
Firmware shall reach capture-ready within 30 s +/-20% of processor reset.
- **Source decision:** Bring-up is paced by fixed firmware delays and a
  link-negotiation poll rather than by readiness indications from the camera and
  PHY, which puts the whole startup duration under firmware control.
- **Imposes on:** operations, system design, verification
- **Design:** `farsight-avionics-sw/Camera/src/camera.c:622-630`, `farsight-avionics-sw/Camera/src/util.c:128-141`, `farsight-avionics-sw/Camera/src/eth.c:115`
- **Kind:** Performance
- **Verify:** HW
- **Rationale:** Startup duration is an operations parameter: it sets how long
  after a power cycle or an upset the payload is unable to answer, and therefore
  how long a pass must be held open before a capture can be commanded.
- **Evidence:** Not measured. In flight the boundary is different from the
  harness: the payload answers commands as soon as the serial task is running,
  and the camera bring-up delays are incurred on the commanded transition out of
  low power rather than at reset. Those delays total at least 2.2 s -- 1 s
  asserting camera reset and 1 s after releasing it
  (`Camera/src/camera.c:626-629`), plus two 100 ms waits in the standby
  transition (`Camera/src/util.c:132`, `:137`). PHY autonegotiation is
  additional and its duration is unknown; see `PFW-ETH-14`.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** AMBIG
- **Note:** The requirement needs splitting as well as measuring. "Capture-ready"
  conflates two distinct instants in the flight design -- command-responsive, and
  able to expose -- which are separated by an operator decision of unbounded
  length. Closing `PFW-ETH-14` bounds the first; the second is not a firmware
  property at all.

## ETH -- Ethernet MAC/PHY behavior

### PFW-ETH-04
Firmware shall program the Ethernet station MAC address from the network ICD.
- **Parent:** FAR-EDT_L3REQ-11, FAR-CDH_FPGA_L3REQ-20, FAR-EDT_L3REQ-2
- **Design:** `farsight-avionics-sw/Camera/src/eth.c:330-333`, `farsight-avionics-sw/Camera/src/register.c:98-100`
- **Verify:** SIM, HW
- **Rationale:** The FPGA responder and external network must agree on the source MAC used by payload Ethernet.
- **Evidence:** The CoreTSE station address is hardcoded to `0x6060603C` /
  `0xB1C00000` (`Camera/src/eth.c:330-333`), while the UDP core's source MAC is
  taken from `SRC_MAC_ADDRESS_0_3_SYS_REG` and `SRC_MAC_ADDRESS_4_5_SYS_REG`,
  which initialize to **zero** (`Camera/src/register.c:98-100`). The two are
  never reconciled.
- **Status:** DEFECT
- **Finding:** PFW-F-08
- **Note:** The defect survives the source correction and is worse than reported.
  Against the harness the two blocks disagreed on two non-zero constants. In
  flight the station address is a constant and the UDP source MAC is a
  host-writable register whose reset value is zero, so until the host writes all
  eight network registers and issues `UPDATE_NET_ADDRESS`, frames are emitted
  with an all-zero source MAC that does not match the station address.

### PFW-ETH-10
PHY initialization shall select RGMII mode.
- **Source decision:** The board routes the FPGA-to-PHY connection as RGMII.
- **Imposes on:** hardware design, FPGA design, verification
- **Design:** `farsight-avionics-sw/Camera/src/eth.c:222`
- **Verify:** HW
- **Rationale:** The board connection between FPGA and PHY uses RGMII signaling.
- **Evidence:** The MAC interface selection writes `0x1000`, commented "MAC
  interface selection to RGMII" (`Camera/src/eth.c:222`).
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK

### PFW-ETH-11
PHY initialization shall request a PHY software reset after configuration writes.
- **Source decision:** PHY mode changes are applied by register write and latched by software reset rather than by pin strapping.
- **Imposes on:** verification
- **Design:** `farsight-avionics-sw/Camera/src/eth.c:242-253`
- **Verify:** HW
- **Rationale:** The PHY must latch mode changes before Ethernet traffic is expected.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK

### PFW-ETH-12
PHY initialization shall bound autonegotiation wait time.
- **Source decision:** Autonegotiation is bounded by a firmware timeout rather than by a hardware link-up indication.
- **Imposes on:** verification, operations
- **Design:** `farsight-avionics-sw/Camera/src/eth.c:115`, `farsight-avionics-sw/Camera/src/eth.c:155-158`
- **Verify:** HW
- **Rationale:** Firmware must not hang forever when Ethernet link partner negotiation fails.
- **Evidence:** The poll limit is `copper_aneg_timeout = 1000000u`
  (`Camera/src/eth.c:115`), decremented once per status read
  (`Camera/src/eth.c:157`), with the loop exiting on completion or exhaustion
  (`Camera/src/eth.c:158`).
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Note:** `OK` records only that a bound exists. Whether it is the right bound
  is `PFW-ETH-14`, which cannot be closed until it is expressed in seconds.

### PFW-ETH-13
Firmware shall support image egress on each of the two Ethernet interfaces.
- **Parent:** FAR-EDT_L3REQ-13
- **Design:** `farsight-avionics-sw/Camera/src/camera.c:272`, `farsight-avionics-sw/Camera/src/camera.c:291`, `farsight-avionics-sw/Camera/include/gpio_pin_def.h:38`
- **Verify:** INSP
- **Rationale:** FAR-EDT_L3REQ-13 requires redundant Ethernet; redundancy is only realised if either interface can carry image egress.
- **Evidence:** Only ETH1 is powered and initialized (`Camera/src/camera.c:272`,
  `:291`). `gpio_pin_def.h` defines `ETH1_PWR_EN` and `ETH1_PWR_STATUS` with no
  ETH2 counterpart (`Camera/include/gpio_pin_def.h:38`, `:53`). This is
  consistent with `PF-F-02`, which reports the fabric tying ETH2 control, reset
  and MDC low.
- **Finding:** PFW-F-15
- **Status:** GAP

### PFW-ETH-14
PHY initialization shall abandon autonegotiation after 10 s +/-20%.
- **Source decision:** The autonegotiation bound was implemented as a status-poll
  count rather than as an elapsed interval, so the bound has to be restated in
  units of time before anyone outside firmware can review or verify it.
- **Imposes on:** verification, operations
- **Design:** `farsight-avionics-sw/Camera/src/eth.c:115`, `farsight-avionics-sw/Camera/src/eth.c:157-158`
- **Kind:** Performance
- **Verify:** HW
- **Rationale:** `PFW-ETH-12` requires that a bound exist; this states what it
  is. IEEE 802.3 Clause 28 autonegotiation completes in a few seconds on a
  healthy copper link, so a bound near 10 s distinguishes a slow negotiation
  from an absent link partner without stalling bring-up.
- **Evidence:** The as-built bound is a loop count of 1,000,000
  (`Camera/src/eth.c:115`), decremented once per status poll
  (`Camera/src/eth.c:157`). Each iteration performs several MDIO transactions of
  unmeasured duration, so the realised timeout in seconds cannot be derived from
  the source and has never been measured. Carried across from the harness
  unchanged.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** AMBIG
- **Note:** `AMBIG` because compliance is not determinable: the requirement's
  bound is in seconds and the design's bound is in poll iterations, and no
  conversion exists. One measurement closes it either way.

## UDP -- UDP network configuration and transfer

### PFW-UDP-05
Firmware shall configure the destination MAC address from the network ICD.
- **Parent:** FAR-EDT_L3REQ-11, FAR-CDH_FPGA_L3REQ-20
- **Design:** `farsight-avionics-sw/Camera/src/camera.c:459-508`, `farsight-avionics-sw/Camera/src/register.c:103-105`
- **Verify:** SIM, HW
- **Rationale:** The Ethernet frame destination must match the ground receiver on the payload subnet.
- **Evidence:** `update_network_addresses()` reads
  `DST_MAC_ADDRESS_0_3_SYS_REG` and `DST_MAC_ADDRESS_4_5_SYS_REG` and writes
  them to the UDP core (`Camera/src/camera.c:459-508`), invoked by the
  `UPDATE_NET_ADDRESS` command (`Camera/src/command.c:415-417`). The registers
  reset to zero (`Camera/src/register.c:103-105`), which matches the ICD.
- **Status:** OK
- **Note:** Re-adjudicated from `GAP`. The `GAP` recorded hardcoded constants in
  the harness. The flight design implements the host-writable model the ICD
  documents, which also withdraws `PFW-F-29`.

### PFW-UDP-06
Firmware shall configure the source MAC address from the network ICD.
- **Parent:** FAR-EDT_L3REQ-11, FAR-CDH_FPGA_L3REQ-20
- **Design:** `farsight-avionics-sw/Camera/src/camera.c:459-508`, `farsight-avionics-sw/Camera/src/register.c:98-100`
- **Verify:** SIM, HW
- **Rationale:** The source MAC must match the payload Ethernet identity advertised on the network.
- **Evidence:** Configured from `SRC_MAC_ADDRESS_0_3_SYS_REG` and
  `SRC_MAC_ADDRESS_4_5_SYS_REG` (`Camera/src/camera.c:459-508`). The mechanism
  is correct; the value it produces does not agree with the CoreTSE station
  address, which is the subject of `PFW-ETH-04`.
- **Status:** OK
- **Note:** Re-adjudicated from `DEFECT`. The inconsistency is real but belongs
  to one requirement, not two; `PFW-ETH-04` carries it.

### PFW-UDP-09
Firmware shall select the UDP 16GB-buffer source before 16GB frame transfers.
- **Source decision:** Frame egress source selection is a firmware-programmed mux in the FPGA UDP path rather than an automatic follower of the drain sequence.
- **Imposes on:** FPGA design, verification
- **Design:** `farsight-avionics-sw/Camera/src/CameraStates/camera_transfer_state.c:103-125`, `farsight-avionics-sw/Camera/include/udp_core_reg.h:73`
- **Verify:** SIM, HW
- **Rationale:** The FPGA UDP mux must point at the buffer holding the requested frame.
- **Evidence:** `v_Transfer_Frame()` selects `UDP_MUX_SELECT_DDR4_16GB` and calls
  `set_read_mux()` before `xfer_frame_via_udp()`
  (`Camera/src/CameraStates/camera_transfer_state.c:103-125`).
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK

### PFW-UDP-10
Firmware shall select the UDP 8GB-buffer source before 8GB frame transfers.
- **Source decision:** As `PFW-UDP-09`. The same firmware-programmed mux selects the 8GB buffer.
- **Imposes on:** FPGA design, verification
- **Design:** `farsight-avionics-sw/Camera/src/CameraStates/camera_transfer_state.c:103-125`, `farsight-avionics-sw/Camera/include/udp_core_reg.h:72`
- **Verify:** SIM, HW
- **Rationale:** The FPGA UDP mux must point at the smaller buffer when the requested frame lives there.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK

### PFW-UDP-11
Firmware shall accept commands over each Ethernet interface.
- **Parent:** FAR-EDT_L3REQ-3
- **Design:** `farsight-avionics-sw/Camera/src/eth.c:19-61`
- **Verify:** INSP
- **Rationale:** FAR-EDT_L3REQ-3 requires command ingestion over each Ethernet interface.
- **Evidence:** `eth.c` implements MAC and PHY initialization only. No UDP
  receive path, command decoder or ingress queue exists in the application; the
  only command path is RS-422 (`PFW-INIT-07`).
- **Finding:** PFW-F-33
- **Status:** GAP
- **Note:** This is the part of the withdrawn `PFW-F-01` that survives against
  the flight design, re-raised narrowly as `PFW-F-33`. It is also the firmware
  half of FAR-EDT_L3REQ-3, dispositioned `CONFLICT`.

### PFW-UDP-12
Firmware shall transfer frames without firmware-level retransmission.
- **Source decision:** Reliable delivery was placed in the host receiver rather than in flight firmware; firmware transmits each frame once.
- **Imposes on:** ground segment, system design, verification
- **Design:** `farsight-avionics-sw/Camera/src/CameraStates/camera_transfer_state.c:60-94`
- **Verify:** ANA
- **Rationale:** The host receiver, not the soft-core firmware, handles missing UDP packets in the as-built contract.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** AMBIG
- **Evidence:** No retransmission, acknowledgement or loss-reporting logic exists
  in the transfer path. The statement asserts an absence, so no observation can
  fail it. Reword as the obligation that actually matters -- that the host
  recovers loss, which is `PFW-UDP-14` -- or withdraw it and state the delivery
  contract on the host side.

### PFW-UDP-13
Firmware shall sustain an image egress rate of at least 200 Mbit/s while
draining the frame buffers over Ethernet.
- **Source decision:** The system-level offload rate is unavailable as a parent.
  FAR-L1REQ-59 is dispositioned `DEFECT` in the corrected baseline -- its
  statement reads "200 mb/second", which is readable as millibits, megabits or
  megabytes -- so the firmware-side rate obligation is carried here until that
  requirement is repaired.
- **Imposes on:** system design, ground segment, verification
- **Design:** `farsight-avionics-sw/Camera/src/CameraStates/camera_transfer_state.c:80-89`, `farsight-avionics-sw/Camera/include/camera.h:129`
- **Kind:** Performance
- **Verify:** ANA, HW
- **Rationale:** Egress rate sets how long the payload is occupied after a
  capture, and therefore how soon it can capture again. Filling both buffers
  takes about 11 s and emptying them takes minutes, so the drain, not the
  capture, sizes a contact window.
- **Evidence:** Analysis only; not measured. One frame is 4581 x 6784 bytes =
  31.08 MB = 248.6 Mbit (`Camera/include/camera.h:126-129`), which occupies
  249 ms at the 1000BASE-T line rate the PHY is configured for
  (`Camera/src/eth.c:102-103`). The transfer state adds a fixed `vTaskDelay(100)`
  = 100 ms per frame (`Camera/src/CameraStates/camera_transfer_state.c:82`),
  giving 349 ms per frame and an effective 712 Mbit/s -- compliant, with about
  3.5x margin. That delay is 29% of the per-frame budget and adds 77 s to a full
  768-frame drain, which takes 4.5 min against a 3.2 min floor. It carries the
  comment "this is so the flight computer can keep up. Revisit."
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Note:** 200 Mbit/s is the corrected wording proposed for FAR-L1REQ-59 in
  [`Flow-Requirements-CORRECTED-2026-09-11.xlsx`](../../../docs/Flow-Requirements-CORRECTED-2026-09-11.xlsx)
  and inherits that requirement's TBR on the value; see
  [`tbr-register.md`](../../../docs/requirements/tbr-register.md) entry FAR-L1REQ-59.
  Re-parent to FAR-L1REQ-59 once the unit ambiguity is repaired, at which point
  it stops being derived. The `@todo` on the 100 ms delay is the one place the
  flight code concedes that this number was never analysed.

### PFW-UDP-14
The image egress path shall deliver at least 99.999% (TBR) of transmitted
datagrams to the host receiver over a full frame-buffer drain.
- **Source decision:** Reliable delivery was placed in the host receiver and
  implemented as concealment -- a missing packet is zero-filled rather than
  retransmitted (`PFW-UDP-12`, `PFW-HOST-09`) -- which makes the tolerable loss
  rate an image-quality parameter that only the ground segment can set.
- **Imposes on:** ground segment, image quality analysis, system design, verification
- **Design:** `farsight-avionics-sw/utils/receiver.py:40`, `farsight-avionics-sw/utils/receiver.py:291-293`, `farsight-avionics-sw/Camera/src/CameraStates/camera_transfer_state.c:60-94`
- **Kind:** Performance
- **Verify:** HW
- **Rationale:** A design that neither retransmits nor reports loss has conceded
  loss, and a conceded loss with no budget is unbounded image degradation that
  no test can fail.
- **Evidence:** No budget exists and no loss measurement is retained. A frame is
  4581 lines at 5 datagrams per line (`utils/receiver.py:28`) = 22,905
  datagrams, so a drain of 768 frames carries 17.6 M datagrams; at 99.999% that
  is 0.23 lost datagrams per frame, each concealing one fifth of one image line.
  The receiver zero-fills after a 10 ms wait (`utils/receiver.py:40`,
  `:291-293`) and its `out_of_order` statistic is never incremented
  (`PFW-F-25`), so loss is concealed at both ends of the path.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** GAP
- **Note:** The 99.999% figure is TBR and registered in
  [`tbr-register.md`](../../../docs/requirements/tbr-register.md). The owner is
  the image quality analysis, not firmware.

## CAM -- Camera configuration and trigger control

### PFW-CAM-05
Firmware shall hold camera reset asserted for 1 s +/-5%.
- **Source decision:** Sensor reset interval was fixed in firmware rather than derived from a sensor ready indication.
- **Imposes on:** verification, camera vendor data
- **Design:** `farsight-avionics-sw/Camera/src/camera.c:622-627`
- **Kind:** Performance
- **Verify:** HW
- **Rationale:** The image sensor needs a stable reset interval before SPI configuration.
- **Evidence:** `cam_reset()` drives `CAM_XCLR_N` low and calls
  `vTaskDelay(1000)` = 1000 ms at the 1 ms tick (`Camera/src/camera.c:624-626`).
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK

### PFW-CAM-06
Firmware shall wait 1 s +/-5% after releasing camera reset before sensor configuration.
- **Source decision:** As `PFW-CAM-05`. The post-release settling interval was likewise fixed at 1 s.
- **Imposes on:** verification, camera vendor data
- **Design:** `farsight-avionics-sw/Camera/src/camera.c:628-629`
- **Kind:** Performance
- **Verify:** HW
- **Rationale:** The image sensor needs oscillator and internal logic settling time after reset release.
- **Evidence:** `CAM_XCLR_N` is released and followed by `vTaskDelay(1000)`
  (`Camera/src/camera.c:628-629`). The line carries the comment "was 1000",
  indicating the value has been changed at least once with no recorded reason.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK

### PFW-CAM-07
Camera initialization shall place the sensor in standby before applying the configuration sequence.
- **Source decision:** Sensor configuration is applied while the sensor is in standby rather than while streaming.
- **Imposes on:** verification
- **Design:** `farsight-avionics-sw/Camera/src/camera.c:632-641`, `farsight-avionics-sw/Camera/src/util.c:128-141`
- **Verify:** HW
- **Rationale:** The sensor configuration registers must be written while the sensor is not actively streaming.
- **Evidence:** `init_slvsec()` begins with
  `set_standby_and_master_mode(0x01)` (`Camera/src/camera.c:632-641`), which sets
  the STANDBY and XMSTA bits with 100 ms settling between them
  (`Camera/src/util.c:128-141`).
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK

### PFW-CAM-18
Camera initialization shall configure exposure timing from the mission imaging profile.
- **Parent:** FAR-CDH_FPGA_L3REQ-15, FAR-L1REQ-31
- **Design:** `farsight-avionics-sw/Camera/src/register_callbacks.c:167-175`, `farsight-avionics-sw/Camera/include/camera.h:87-88`
- **Verify:** ANA, HW
- **Rationale:** Exposure timing drives image brightness and must match the approved imaging profile rather than an arbitrary register value.
- **Evidence:** Exposure is host-writable through `SENSOR_EXPO_USEC_SYS_REG`,
  validated against `SENSOR_EXPO_USEC_MIN` and `SENSOR_EXPO_USEC_MAX`
  (`Camera/src/register_callbacks.c:167-175`). The bounds are derived from the
  sensor pedestal and the 22-bit register width
  (`Camera/include/camera.h:87-88`), and firmware inverts the pedestal so the
  register means the exposure actually integrated rather than the trigger pulse
  width (`Camera/include/camera.h:195-226`).
- **Status:** OK
- **Finding:** PFW-F-11
- **Note:** Re-adjudicated from `GAP`. The `GAP` recorded a fixed SHS constant in
  the harness. `PFW-F-11` is narrowed rather than withdrawn: the 100 ns
  accuracy claim of FAR-CDH_FPGA_L3REQ-14 remains unevidenced, and that parent
  is dispositioned `DEFECT`.

### PFW-CAM-19
Camera initialization shall configure external trigger mode.
- **Parent:** FAR-CDH_FPGA_L3REQ-15, FAR-FPA_L5REQ-2, FAR-L1REQ-28
- **Design:** `farsight-avionics-sw/Camera/src/camera.c:654`, `farsight-avionics-sw/Camera/src/util.c:440-446`
- **Verify:** HW
- **Rationale:** The FPGA trigger generator, not free-running sensor timing, controls science exposure start.
- **Evidence:** `init_slvsec()` calls `set_trig_mode_timing(0x02, 0x01)`
  (`Camera/src/camera.c:654`), selecting TRIGMODE 2 (fast trigger) and
  TRIGTIMING 1 (`Camera/src/util.c:440-446`).
- **Status:** OK

### PFW-CAM-21
Camera initialization shall configure the sensor output bit depth for RAW12 export.
- **Parent:** FAR-CDH_FPGA_L3REQ-15, FAR-L1REQ-2, FAR-L1REQ-1
- **Design:** `farsight-avionics-sw/Camera/src/register_callbacks.c:121-129`, `farsight-avionics-sw/Camera/src/camera.c:651-655`
- **Verify:** SIM, HW
- **Rationale:** The downstream packing and host conversion assume 12-bit samples.
- **Evidence:** `Set_Sensor_Bit_Depth()` accepts only
  `CAMERA_DEPTH_TWELVE_BITS` and returns `ERR_REG_INVALID_LIMIT` for anything
  else (`Camera/src/register_callbacks.c:121-129`), and the value is applied via
  `set_adbit()` and `set_odbit()` (`Camera/src/camera.c:651`, `:655`).
- **Status:** OK

### PFW-CAM-23
Camera initialization shall configure analog gain from the mission imaging profile.
- **Parent:** FAR-CDH_FPGA_L3REQ-15, FAR-L1REQ-33
- **Design:** `farsight-avionics-sw/Camera/src/register_callbacks.c:132-140`, `farsight-avionics-sw/Camera/src/camera.c:198-204`
- **Verify:** SIM, HW
- **Rationale:** Gain affects image calibration and must be traceable to the commanded imaging profile.
- **Evidence:** Host-writable and bounds-checked against `SENSOR_GAIN_MAX` = 480
  tenths of a dB (`Camera/src/register_callbacks.c:132-140`,
  `Camera/include/camera.h:69-70`), applied by `v_Apply_Gain()`
  (`Camera/src/camera.c:198-204`).
- **Status:** OK
- **Note:** Re-adjudicated from `GAP`, which recorded the harness's fixed `0x00F0`.

### PFW-CAM-24
Camera initialization shall configure black level from the mission imaging profile.
- **Parent:** FAR-CDH_FPGA_L3REQ-15, FAR-L1REQ-33
- **Design:** `farsight-avionics-sw/Camera/src/register_callbacks.c:143-151`, `farsight-avionics-sw/Camera/include/camera.h:73-74`
- **Verify:** SIM, HW
- **Rationale:** Black-level offset affects image calibration and must be traceable to the commanded imaging profile.
- **Evidence:** Host-writable and bounds-checked against `SENSOR_BLO_MAX` = 4095
  (`Camera/src/register_callbacks.c:143-151`, `Camera/include/camera.h:73-74`).
- **Status:** OK
- **Note:** Re-adjudicated from `GAP`, which recorded the harness's fixed `0x00F0`.

### PFW-CAM-28
Trigger configuration shall reject a request that exceeds total stored-frame capacity.
- **Parent:** FAR-FB_L3REQ-2, FAR-L1REQ-30
- **Design:** `farsight-avionics-sw/Camera/src/register_callbacks.c:197-205`, `farsight-avionics-sw/Camera/include/camera.h:139-141`
- **Verify:** SIM
- **Rationale:** Firmware must prevent a command from overwriting unread frames.
- **Evidence:** `Set_Sensor_Images_Per_Trigger()` rejects a count below 1 or
  above `TOTAL_FRAME_CAPTURE_AMOUNT` = 768 with `ERR_REG_INVALID_LIMIT`
  (`Camera/src/register_callbacks.c:197-205`, `Camera/include/camera.h:139-141`).
- **Status:** OK

### PFW-CAM-29
Trigger configuration shall reject a request whose frame period is too short for exposure and DDR4 write time.
- **Parent:** FAR-CDH_FPGA_L3REQ-24, FAR-L1REQ-29
- **Design:** `farsight-avionics-sw/Camera/src/register_callbacks.c:218-237`
- **Verify:** SIM
- **Rationale:** A capture cadence faster than image writeout corrupts frame storage.
- **Evidence:** `Set_Frame_Capture_Time()` rejects any period below
  `exposure + u32_Min_Frame_Time_usec()` and above the 24-bit register maximum
  (`Camera/src/register_callbacks.c:218-237`).
- **Status:** OK

### PFW-CAM-37
Firmware shall reset the image sensor after the camera is powered on and before
the sensor configuration sequence is applied.
- **Parent:** FAR-TMTC_SW_L4REQ-48
- **Design:** `farsight-avionics-sw/Camera/src/camera.c:622-630`, `farsight-avionics-sw/Camera/src/camera.c:632`
- **Verify:** SIM, HW
- **Rationale:** FAR-TMTC_SW_L4REQ-48 requires the FPA configuration to be reset after power-on.
  Carried by its own requirement because `PFW-CAM-05` and `PFW-CAM-06` state only
  the reset and settling intervals.
- **Status:** OK
- **Evidence:** `cam_reset()` drives `CAM_XCLR_N` low, waits, releases and waits
  again (`Camera/src/camera.c:622-630`), ahead of `init_slvsec()`
  (`Camera/src/camera.c:632`).

### PFW-CAM-38
Firmware shall command the image sensor between standby and operating modes.
- **Parent:** FAR-TMTC_SW_L4REQ-47
- **Design:** `farsight-avionics-sw/Camera/src/util.c:128-141`, `farsight-avionics-sw/Camera/src/camera.c:632`
- **Verify:** SIM, HW
- **Rationale:** FAR-TMTC_SW_L4REQ-47 requires sensor modes to be managed. Configuration writes
  are only accepted in standby and imaging only proceeds in operating mode.
- **Status:** OK
- **Evidence:** `set_standby_and_master_mode()` sets the STANDBY and XMSTA bits
  with 100 ms settling between them, records the state in `b_Sensor_In_Standby`,
  and on the transition out of standby resets DDR4 and clears the camera fault
  because XTRIG is asserted during the transition (`Camera/src/util.c:128-141`).
- **Note:** The harness's duplicated `set_standby_and_master_mode(0x00)` call,
  raised as part of `PFW-F-26`, does not appear in the flight sequence.

### PFW-CAM-39
Trigger configuration shall admit a frame period no shorter than the exposure
plus the frame write time of the line period in effect.
- **Parent:** FAR-CDH_FPGA_L3REQ-24
- **Design:** `farsight-avionics-sw/Camera/src/register_callbacks.c:218-237`, `farsight-avionics-sw/Camera/src/camera.c:573-576`
- **Kind:** Performance
- **Verify:** SIM
- **Rationale:** This is the measurable bound beneath `PFW-CAM-29`, which states
  only that a too-short period is rejected without saying what "too short"
  means. A cadence faster than the sensor can be retriggered and the row data
  written to DDR4 overwrites a frame that is still being stored.
- **Evidence:** The floor is `u32_Exposure_usec + u32_Min_Frame_Time_usec()`
  (`Camera/src/register_callbacks.c:224`), where the minimum frame time is
  derived from the line period currently programmed
  (`Camera/src/camera.c:573-576`) rather than from a hand-written constant.
  `FRAME_TIME_USEC(0xE3)` is 14,310 us and `FRAME_TIME_USEC(0xF7)` is 15,571 us.
- **Status:** OK
- **Note:** Reworded against the flight design, which bounds the period by
  exposure rather than by the trigger-low pulse width. The flight formulation is
  the better one: it tracks the line period actually programmed, and the header
  records that hand-written constants had previously "drift[ed] from the HMAX
  they were supposed to match" (`Camera/include/camera.h:151-160`).

### PFW-CAM-40
Trigger configuration shall admit a commanded frame rate of at least 70 frames
per second at RAW12 bit depth, sustainable for at least 5 s.
- **Parent:** FAR-FPA_L5REQ-5
- **Design:** `farsight-avionics-sw/Camera/include/camera.h:147-148`, `farsight-avionics-sw/Camera/include/camera.h:163-181`, `farsight-avionics-sw/Camera/src/register_callbacks.c:218-237`
- **Kind:** Performance
- **Verify:** ANA, HW
- **Rationale:** FAR-FPA_L5REQ-5 states the frame rate as a system capability.
  Capability in the sensor and the fabric is not sufficient on its own: the rate
  is only available if firmware will accept a command asking for it.
- **Evidence:** The requirement cannot be met at any exposure. The sensor's rate
  is derived from the line period as
  `fps = SENSOR_DEFAULT_FPS x SENSOR_DEFAULT_HMAX / HMAX`
  (`Camera/include/camera.h:163-181`); at the 16GB line period `DDR4_16GB_HMAX`
  = 0xE3 this yields **69.88 fps**, a minimum frame period of 14,310 us, before
  any exposure is added (`Camera/include/camera.h:147-148`). The admission check
  then requires `period >= exposure + min_frame_time`
  (`Camera/src/register_callbacks.c:224`), so the admitted ceiling is 69.67 fps
  at the minimum 43 us exposure and 67.52 fps at the 500 us default
  (`Camera/include/defaults.h:16`). On the 8GB line period the ceiling is
  64.22 fps.
- **Status:** GAP
- **Finding:** PFW-F-30
- **Note:** FAR-FPA_L5REQ-5 carries a TBR on both the rate and the 5 s duration;
  see [`tbr-register.md`](../../../docs/requirements/tbr-register.md) entry FAR-FPA_L5REQ-5.
  The TBR does not defer the finding: the shortfall is present at any required
  rate above 69.88 fps, and the margin is 0.17%, which is within the range a
  line-period change could recover.

## PPS -- PPS time initialization

### PFW-PPS-01
Firmware shall load PPS seconds from a commanded mission time.
- **Parent:** FAR-TMTC_SW_L4REQ-45
- **Design:** `farsight-avionics-sw/Camera/src/command.c:216-225`, `farsight-avionics-sw/Camera/src/pps.c:16-19`
- **Verify:** SIM, HW
- **Rationale:** Image metadata timestamps need an epoch that operations can set, since a compiled-in epoch is only correct for the mission the build was made for.
- **Evidence:** `SET_TIME_SYS_CMD` copies whole seconds from the command payload
  and calls `v_PPS_Load_Seconds()` followed by `v_PPS_Start()`
  (`Camera/src/command.c:216-225`, `Camera/src/pps.c:16-19`). No compile-time
  epoch constant exists in the flight application.
- **Status:** OK
- **Note:** Re-adjudicated from `GAP` and reworded. The previous statement --
  "shall load startup PPS seconds from the mission start-time constant" -- wrote
  the harness's compile-time `PPS_START_TIME` into the requirement, so the
  requirement itself specified the defect. `PFW-F-03` is withdrawn for the time
  epoch. The obligation is that the epoch be commandable, which flight meets.

### PFW-PPS-03
Firmware shall enable the local PPS source when no external PPS is disciplining time.
- **Source decision:** The local PPS generator was selected as the fallback time reference.
- **Imposes on:** system design, operations, verification
- **Design:** `farsight-avionics-sw/Camera/src/pps.c:26-29`
- **Verify:** HW
- **Rationale:** Image timestamps need a running time base whether or not an external reference is present.
- **Evidence:** `v_PPS_Enable_Local_PPS_Source()` writes `EN_LOCAL_PPS_SOURCE`
  (`Camera/src/pps.c:26-29`).
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK

### PFW-PPS-04
Firmware shall request a PPS time jam after programming PPS time registers.
- **Source decision:** PPS time registers are committed by an explicit jam request rather than taking effect on write.
- **Imposes on:** FPGA design, verification
- **Design:** `farsight-avionics-sw/Camera/src/pps.c:11-14`, `farsight-avionics-sw/Camera/src/command.c:216-225`
- **Verify:** HW
- **Rationale:** The PPS block must latch startup time at a PPS boundary before image timestamps are trusted.
- **Evidence:** `v_PPS_Start()` writes `TRIGGER_TIME_JAM = 1`
  (`Camera/src/pps.c:11-14`) and is called immediately after
  `v_PPS_Load_Seconds()` in the `SET_TIME_SYS_CMD` handler
  (`Camera/src/command.c:216-225`).
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK

## TLM -- Image metadata and telemetry

### PFW-TLM-02
Firmware shall copy the FPGA build version into image metadata.
- **Parent:** FAR-TMTC_SW_L4REQ-49, FAR-AB_L2REQ-6, FAR-CDH_FPGA_L3REQ-21
- **Design:** `farsight-avionics-sw/Camera/src/hw_version.c`, `farsight-avionics-sw/Camera/include/image_metadata.h:100-103`
- **Verify:** SIM
- **Rationale:** Each image product needs the FPGA image version that generated it.
- **Evidence:** The metadata block reserves a `VERSION` word
  (`Camera/include/image_metadata.h:100-103`) and the hardware version is read at
  startup by `v_Read_Version_Info()` (`Camera/src/main.c:46-47`).
- **Status:** OK

### PFW-TLM-08
Firmware shall report camera temperature on request.
- **Parent:** FAR-TMTC_SW_L4REQ-50, FAR-L1REQ-15, FAR-L1REQ-20, FAR-AB_L2REQ-1
- **Design:** `farsight-avionics-sw/Camera/src/command.c:473-485`
- **Verify:** HW
- **Rationale:** Camera thermal telemetry is needed to assess image quality and protect the detector.
- **Evidence:** `GET_CAMERA_TEMP` (0x2B) reads the sensor temperature and returns
  it in the response, rejecting the request outside armed or busy state
  (`Camera/src/command.c:473-485`).
- **Status:** OK
- **Note:** Reworded from "shall read ... through the sensor SPI temperature
  register path", which specified the mechanism rather than the obligation. The
  protective *action* on that value is `PFW-ERR-08` and remains absent.

### PFW-TLM-10
Firmware shall report FPGA junction temperature on request.
- **Parent:** FAR-TMTC_SW_L4REQ-50, FAR-L1REQ-15, FAR-L1REQ-20
- **Design:** `farsight-avionics-sw/Camera/src/command.c:487-492`
- **Verify:** HW
- **Rationale:** FPGA thermal telemetry is needed to assess fabric margin.
- **Evidence:** `GET_FPGA_TEMP` (0x2C) reads the junction temperature and returns
  it in the response (`Camera/src/command.c:487-492`).
- **Status:** OK
- **Note:** Reworded. The previous statement tied the read to capture completion,
  which was the harness's linear flow; in flight it is request-driven.

### PFW-TLM-11
Firmware shall report camera fault status.
- **Parent:** FAR-L1REQ-19, FAR-L1REQ-21, FAR-L1REQ-15
- **Design:** `farsight-avionics-sw/Camera/src/camera.c:849-853`, `farsight-avionics-sw/Camera/src/util.c:136-140`
- **Verify:** HW
- **Rationale:** A frame product needs fault context from the acquisition interval.
- **Evidence:** `check_fault()` reads `CAM_FAULT`
  (`Camera/src/camera.c:849-853`) and `clear_fault()` clears it on the standby
  exit transition (`Camera/src/util.c:136-140`). The value reaches the host only
  through the aggregate telemetry block of `PFW-TLM-14`; no dedicated fault
  response exists.
- **Status:** GAP
- **Finding:** PFW-F-05

### PFW-TLM-13
Metadata retrieval shall copy one 20-word metadata block from the selected DDR4 read controller.
- **Source decision:** Image metadata was defined as a fixed 20-word in-band record carried at the head of the first image row.
- **Imposes on:** ground segment, FPGA design, verification
- **Design:** `farsight-avionics-sw/Camera/src/camera.c:397-419`, `farsight-avionics-sw/Camera/include/udp_dmactrl_reg.h:98`
- **Verify:** SIM
- **Rationale:** The host-visible metadata record has a fixed 80-byte length.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Finding:** PFW-F-13
- **Status:** DEFECT
- **Evidence:** `get_metadata()` asserts `FRAME_READ_REQ`, waits a fixed
  `vTaskDelay(5)` = 5 ms, then copies `METADATA_WORD_COUNT` = 20 words
  (`Camera/src/camera.c:397-419`, `Camera/include/udp_dmactrl_reg.h:98`). The
  defect survives the source correction: the fixed delay is not a completion
  check, and `FRAME_READ_DONE_IRQ` -- which the transfer path uses for exactly
  this purpose (`PFW-DMA-14`) -- is not used here. A metadata read that takes
  longer than 5 ms returns a mixture of the current and previous frame.

### PFW-TLM-14
Firmware shall return status and health telemetry in response to a request.
- **Parent:** FAR-L1REQ-15
- **Design:** `farsight-avionics-sw/Camera/src/command.c:511-514`, `farsight-avionics-sw/Camera/src/tlm_adc.c:88-123`
- **Verify:** HW
- **Rationale:** FAR-L1REQ-15 makes telemetry request/response.
- **Evidence:** `GET_ALL_TLM` (0x32) returns a 96-byte telemetry block
  (`Camera/src/command.c:511-514`) assembled from the ADC channels sampled by
  `u32_Read_TLM()` (`Camera/src/tlm_adc.c:88-123`). `GET_CAMERA_STATE` (0x2D)
  and the PPS frequency and phase error words are also available on request
  (`Camera/src/command.c:494-509`).
- **Status:** OK
- **Note:** Re-adjudicated from `GAP`. The `GAP` rested on `PFW-F-01`.
  Scaling and units of the returned block remain undefined, which is
  `PFW-F-14` and is not closed by this.

### PFW-TLM-15
Image metadata shall carry a capture timestamp accurate to 1 ms (TBR) of the
exposure start it labels.
- **Source decision:** Timestamp accuracy depends on a PPS lock indication that
  the firmware does not evaluate, which places the accuracy obligation on
  firmware rather than on the time source.
- **Imposes on:** ground segment, system design, image quality analysis, verification
- **Design:** `farsight-avionics-sw/Camera/src/pps.c:41-44`, `farsight-avionics-sw/Camera/src/pps.c:31-38`, `farsight-avionics-sw/Camera/include/image_metadata.h:88-96`
- **Kind:** Performance
- **Verify:** ANA, HW
- **Rationale:** The timestamp is what makes an image usable for correlating an
  observation with a pointing solution and an orbit state. Metadata carries a
  seconds field and a nanosecond sub-second field, so the record advertises
  nanosecond resolution; resolution is not accuracy.
- **Evidence:** No accuracy is stated or verified. `b_PPS_Is_Locked()` is a stub
  that returns `1` unconditionally (`Camera/src/pps.c:41-44`), so no caller can
  distinguish a disciplined time base from a free-running one. The PPS block
  does expose `FREQUENCY_ERROR` and `PHASE_ERROR`
  (`Camera/src/pps.c:31-38`), and those are returned in telemetry, but nothing
  compares them against a threshold. `v_PPS_Set_Rx_Delay()` is called with an
  undocumented constant.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** GAP
- **Finding:** PFW-F-34
- **Note:** The natural parent is FAR-CDH_FPGA_L3REQ-14, "knowledge of exposure
  start and stop to an accuracy of 100 ns", but it is dispositioned `DEFECT`
  (`AV-F-05`) and conventions forbid tracing to it. The 1 ms figure is TBR.

### PFW-TLM-16
Firmware shall return requested status and health telemetry within 1 s (TBR) of
the request.
- **Parent:** FAR-L1REQ-15
- **Design:** `farsight-avionics-sw/Camera/src/main.c:60-65`, `farsight-avionics-sw/Camera/src/hal/serial_comm.c:74-80`
- **Kind:** Performance
- **Verify:** HW
- **Rationale:** `PFW-TLM-14` requires telemetry on request; a request/response
  interface with no deadline cannot be distinguished from one that has stopped
  answering, which is precisely the condition an operator queries telemetry to
  diagnose.
- **Evidence:** Not measured, but the path is bounded by construction: the
  command task is a dedicated FreeRTOS task at `COMM_TASK_PRIORITY`
  (`Camera/src/main.c:60-65`) that dequeues a completed message and responds
  synchronously (`Camera/src/hal/serial_comm.c:74-80`). The dominant term is the
  115200 baud line itself -- a 96-byte telemetry block plus framing is about
  10 ms -- so the requirement is met with three orders of magnitude of margin
  unless a higher-priority task starves the queue.
- **Status:** OK
- **Note:** Re-adjudicated from `GAP`; there was no request/response path in the
  harness to bound. `OK` here rests on analysis, not measurement, which is the
  `UNMEASURED` gap in the status vocabulary noted under
  [A-12](../../../docs/requirements/requirements-gap-analysis.md#a-12---write-the-missing-performance-requirements----polarfire-fw-done).
  The 1 s figure is TBR.

## ERR -- Error handling

### PFW-ERR-01
Trigger configuration shall return an error when requested stored frames exceed buffer capacity.
- **Parent:** FAR-FB_L3REQ-2, FAR-L1REQ-30
- **Design:** `farsight-avionics-sw/Camera/src/register_callbacks.c:197-205`, `farsight-avionics-sw/Camera/src/command.c:294-318`
- **Verify:** SIM
- **Rationale:** Malformed capture requests must fail before corrupting stored images.
- **Evidence:** `Set_Sensor_Images_Per_Trigger()` returns
  `ERR_REG_INVALID_LIMIT` outside 1..768
  (`Camera/src/register_callbacks.c:197-205`), and `XFER_BUFF_SYS_CMD`
  bounds-checks index and count with `u8_Check_Frame_Bounds()`
  (`Camera/src/command.c:294-318`).
- **Status:** OK

### PFW-ERR-02
Trigger configuration shall return an error when requested capture timing is invalid.
- **Parent:** FAR-CDH_FPGA_L3REQ-24, FAR-L1REQ-29
- **Design:** `farsight-avionics-sw/Camera/src/register_callbacks.c:218-237`
- **Verify:** SIM
- **Rationale:** Malformed timing requests must fail before a cadence that the buffer cannot sustain is started.
- **Evidence:** `Set_Frame_Capture_Time()` returns `ERR_REG_INVALID_LIMIT` both
  below the exposure-plus-frame-time floor and above the 24-bit register maximum
  (`Camera/src/register_callbacks.c:218-237`). Register writes are only
  committed to the table when the callback returns `NO_ERROR`
  (`Camera/src/register.c:243-247`).
- **Status:** OK

### PFW-ERR-03
Firmware shall handle trigger-configuration failure before starting capture.
- **Parent:** FAR-CDH_FPGA_L3REQ-24
- **Design:** `farsight-avionics-sw/Camera/src/command.c:273-292`
- **Verify:** INSP, HW
- **Rationale:** A rejected capture setup must not be followed by an acquisition using stale or partial trigger state.
- **Evidence:** `START_ACQ_SYS_CMD` checks `b_Trigger_Is_Ready()` and returns
  `ERR_REG_INVALID_LIMIT` rather than posting the capture event
  (`Camera/src/command.c:273-292`). The comment records the reasoning: firing
  would "capture at the settings of an earlier burst".
- **Status:** OK
- **Note:** Re-adjudicated from `DEFECT`; `PFW-F-06` is withdrawn. It reported
  `configure_trig()`'s return value discarded by the startup path, which was the
  harness.

### PFW-ERR-08
Firmware shall power off the FPA when temperature or fault telemetry crosses the protection threshold.
- **Parent:** FAR-AB_L2REQ-1
- **Design:** `farsight-avionics-sw/Camera/src/register.c:61`, `farsight-avionics-sw/Camera/src/command.c:473-485`
- **Verify:** HW
- **Rationale:** Thermal or camera fault detection must lead to a protective response, not only telemetry.
- **Finding:** PFW-F-05, PFW-F-14
- **Status:** GAP
- **Evidence:** No protective action exists. Temperature is readable on request
  but nothing compares it against a threshold, and no code path powers the FPA
  off autonomously. `SENSOR_OVER_TEMP_KEL_SYS_REG` -- the register that would
  hold the threshold, and which CM-01979 defines -- is **commented out** of the
  register table (`Camera/src/register.c:61`), so a host attempting to set a
  limit receives `ERR_REG_INVALID_ADDR`.

### PFW-ERR-10
Firmware shall power off the FPA within 5 s (TBR) of camera temperature
exceeding the FPA protection threshold.
- **Parent:** FAR-AB_L2REQ-1
- **Design:** `farsight-avionics-sw/Camera/src/register.c:61`, `farsight-avionics-sw/Camera/src/command.c:473-485`
- **Kind:** Performance
- **Verify:** ANA, HW
- **Rationale:** `PFW-ERR-08` requires the power-off; this bounds how long the
  detector may sit above its limit first, which is the quantity that determines
  whether the response protects anything.
- **Evidence:** Neither the threshold nor the response time exists. Camera
  temperature is sampled only when a host asks for it
  (`Camera/src/command.c:473-485`), so there is no periodic sampling interval to
  bound detection time even if a threshold were defined.
- **Status:** GAP
- **Finding:** PFW-F-05, PFW-F-14
- **Note:** [`criticality.md`](../../../docs/requirements/criticality.md) grades
  FPA over-temperature power-off **Class A**. `PFW-ERR-08` and this requirement
  are the PolarFire firmware's share of a Class A function sitting in a Class B
  document, and the split between firmware, avionics and hardware has never been
  written down. Recorded in
  [`derived-register.md`](../../../docs/requirements/derived-register.md).

## HOST -- Host wire-contract utilities

### PFW-HOST-06
The host UDP receiver shall parse the FARSIGHT image payload header before row data.
- **Source decision:** The image payload was defined as a FARSIGHT-specific header ahead of row data rather than a standard container.
- **Imposes on:** ground segment, verification
- **Design:** `farsight-avionics-sw/utils/receiver.py:135-152`, `farsight-avionics-sw/utils/receiver.py:115-133`
- **Verify:** INSP
- **Rationale:** The host must recover line and packet sequence context from each datagram.
- **Evidence:** `extract_sequence_numbers()` skips the 2-byte start marker and
  unpacks the line and packet sequence numbers before returning the payload
  (`utils/receiver.py:135-152`).
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK

### PFW-HOST-09
The host UDP receiver shall zero-fill a missing packet after the packet wait timeout.
- **Source decision:** Lost packets are concealed by zero-fill after a timeout rather than retransmitted.
- **Imposes on:** ground segment, image quality analysis, verification
- **Design:** `farsight-avionics-sw/utils/receiver.py:40`, `farsight-avionics-sw/utils/receiver.py:282-301`
- **Verify:** SIM
- **Rationale:** A partial UDP loss should degrade image data locally rather than block frame reconstruction.
- **Evidence:** `PACKET_WAIT_TIME` is 10 ms (`utils/receiver.py:40`), after which
  missing packets in a line are replaced with zero payloads
  (`utils/receiver.py:282-301`).
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK

### PFW-HOST-10
The host UDP receiver shall finalize an incomplete frame after the frame timeout.
- **Source decision:** Incomplete frames are finalized on a timeout rather than held pending completion.
- **Imposes on:** ground segment, verification
- **Design:** `farsight-avionics-sw/utils/receiver.py:41`, `farsight-avionics-sw/utils/receiver.py:369-372`, `farsight-avionics-sw/utils/receiver.py:432`
- **Verify:** SIM
- **Rationale:** The receive tool must return control after a bad transfer instead of waiting indefinitely.
- **Evidence:** `FRAME_TIMEOUT` is 2.0 s (`utils/receiver.py:41`); expiry is
  tested by elapsed time against the frame start (`utils/receiver.py:369-372`)
  and forces finalization (`utils/receiver.py:432`).
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK

### PFW-HOST-12
The host converter shall decode FARSIGHT RAW12 packing into pixels.
- **Source decision:** RAW12 pixels are packed on the wire and unpacked by the host converter rather than transmitted unpacked.
- **Imposes on:** ground segment, verification
- **Design:** `farsight-avionics-sw/utils/converter.py:30-68`
- **Verify:** SIM
- **Rationale:** The archived image product must reverse the FPGA wire packing exactly.
- **Evidence:** `unpack_payload()` reads big-endian 32-bit words and extracts
  eight 12-bit pixels from each group of three words
  (`utils/converter.py:30-68`).
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK

### PFW-HOST-13
The host converter shall interpret the first image row metadata region as 20 metadata words.
- **Source decision:** The first image row carries the metadata record in band, so the converter must strip it before interpreting pixels.
- **Imposes on:** ground segment, image quality analysis, verification
- **Design:** `farsight-avionics-sw/utils/converter.py`
- **Verify:** SIM
- **Rationale:** The converter must extract the in-band metadata record before interpreting image pixels.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** GAP
- **Finding:** PFW-F-35
- **Evidence:** The flight-side converter has **no metadata handling at all** --
  no occurrence of "metadata" appears in `utils/converter.py`. The firmware
  writes a 20-word record into the head of the first image row
  (`PFW-TLM-13`), and the delivered converter treats those 80 bytes as pixel
  data. Every image product is therefore both mislabelled in its first pixels
  and stripped of the metadata the record was created to carry.
- **Note:** Re-adjudicated from `DEFECT` to `GAP`, and the finding changes
  identity. `PFW-F-21` reported that the converter's metadata comment and its
  decoding disagreed on byte order; that code existed only in the deleted
  harness tool and `PFW-F-21` is withdrawn. The flight tool does not have the
  byte-order bug because it does not have the feature.

## Appendix A -- firmware register map

The consolidated MMIO and peripheral register map that was here has moved to
section 25.2 of [CM-01979](../../../docs/icd/CM-01979_ICD_FLIGHT_SOFTWARE_FARSIGHT.md), which is the source of
truth for interface data. Requirements in this document cite it rather than
repeating it.

## Withdrawn

### Withdrawn on re-adjudication against the flight source, 2026-09-17

None. Every requirement survived the source correction -- the obligations were
right, and it was the design evidence beneath them that was wrong. What changed
is how many are met, and the wording of seven requirements that had specified
the harness's mechanism rather than the obligation: `PFW-DMA-14`, `PFW-DMA-15`,
`PFW-DMA-16`, `PFW-PPS-01`, `PFW-TLM-08`, `PFW-TLM-10` and `PFW-CAM-39`.

That is worth recording as evidence about the requirements rather than about the
firmware. A requirement that states an obligation survives a change of design
source; a requirement that states a mechanism does not. Those seven were the
retroactive-derivation smell of `conventions.md` section 5 -- rationale and
statement describing the implementation -- and they are exactly the seven that
had to be rewritten.

### Interface data now held in the ICD

- `PFW-MEM-05` -- "The firmware platform shall map the APB3 peripheral window at
  base address 0x70000000." Held in [CM-01979](../../../docs/icd/CM-01979_ICD_FLIGHT_SOFTWARE_FARSIGHT.md)
  section 25.2.
- `PFW-DMA-01` -- "Firmware shall configure each DDR4 write DMA controller for a
  6784-byte image row." Held in section 4.2.1, which derives the figure: 4512
  pixels at 12 bits packed is 6768 bytes, plus 16 bytes of alignment padding.
- `PFW-UDP-01`, `PFW-UDP-02`, `PFW-UDP-03`, `PFW-UDP-04` -- destination UDP port
  35121, source port 1234, destination IPv4 10.101.15.195 and source IPv4
  10.101.15.192. These four stated hardcoded constants as though they were the
  interface contract. They are not. CM-01979 sections 17.4.48 to 17.4.51 define
  the endpoint as four host-writable registers with a reset value of zero,
  latched into the UDP core by the `UPDATE_NET_ADDRESS` command. The values in
  `main.c` are startup defaults, and the requirements mistook a configurable
  interface for a fixed one. See [`PFW-F-22`](pf-firmware-findings.md#pfw-f-22).

Identifiers below are retired in place to preserve traceability from older links.

### Build configuration or flow fact; not an external Class B behavior.
- `PFW-BUILD-01` -- Build configuration or flow fact; not an external Class B behavior.
- `PFW-BUILD-02` -- Build configuration or flow fact; not an external Class B behavior.
- `PFW-BUILD-03` -- Build configuration or flow fact; not an external Class B behavior.
- `PFW-BUILD-04` -- Build configuration or flow fact; not an external Class B behavior.
- `PFW-BUILD-05` -- Build configuration or flow fact; not an external Class B behavior.
- `PFW-BUILD-06` -- Build configuration or flow fact; not an external Class B behavior.
- `PFW-BUILD-07` -- Build configuration or flow fact; not an external Class B behavior.

### Detailed sensor-register programming moved to the ICD appendix or imaging profile.
- `PFW-CAM-01` -- Detailed sensor-register programming moved to the ICD appendix or imaging profile.
- `PFW-CAM-02` -- Detailed sensor-register programming moved to the ICD appendix or imaging profile.
- `PFW-CAM-03` -- Detailed sensor-register programming moved to the ICD appendix or imaging profile.
- `PFW-CAM-04` -- Detailed sensor-register programming moved to the ICD appendix or imaging profile.
- `PFW-CAM-08` -- Detailed sensor-register programming moved to the ICD appendix or imaging profile.
- `PFW-CAM-09` -- Detailed sensor-register programming moved to the ICD appendix or imaging profile.
- `PFW-CAM-10` -- Detailed sensor-register programming moved to the ICD appendix or imaging profile.
- `PFW-CAM-11` -- Detailed sensor-register programming moved to the ICD appendix or imaging profile.
- `PFW-CAM-12` -- Detailed sensor-register programming moved to the ICD appendix or imaging profile.
- `PFW-CAM-13` -- Detailed sensor-register programming moved to the ICD appendix or imaging profile.
- `PFW-CAM-14` -- Detailed sensor-register programming moved to the ICD appendix or imaging profile.
- `PFW-CAM-15` -- Detailed sensor-register programming moved to the ICD appendix or imaging profile.
- `PFW-CAM-16` -- Detailed sensor-register programming moved to the ICD appendix or imaging profile.
- `PFW-CAM-17` -- Detailed sensor-register programming moved to the ICD appendix or imaging profile.
- `PFW-CAM-20` -- Detailed sensor-register programming moved to the ICD appendix or imaging profile.
- `PFW-CAM-22` -- Detailed sensor-register programming moved to the ICD appendix or imaging profile.
- `PFW-CAM-25` -- Detailed sensor-register programming moved to the ICD appendix or imaging profile.
- `PFW-CAM-26` -- Detailed sensor-register programming moved to the ICD appendix or imaging profile.
- `PFW-CAM-27` -- Detailed sensor-register programming moved to the ICD appendix or imaging profile.
- `PFW-CAM-31` -- Detailed sensor-register programming moved to the ICD appendix or imaging profile.
- `PFW-CAM-32` -- Detailed sensor-register programming moved to the ICD appendix or imaging profile.
- `PFW-CAM-33` -- Detailed sensor-register programming moved to the ICD appendix or imaging profile.
- `PFW-CAM-35` -- Detailed sensor-register programming moved to the ICD appendix or imaging profile.
- `PFW-CAM-36` -- Detailed sensor-register programming moved to the ICD appendix or imaging profile.

### Host utility implementation detail; wire-contract behavior is retained at a higher level.
- `PFW-HOST-01` -- Host utility implementation detail; wire-contract behavior is retained at a higher level.
- `PFW-HOST-02` -- Host utility implementation detail; wire-contract behavior is retained at a higher level.
- `PFW-HOST-03` -- Host utility implementation detail; wire-contract behavior is retained at a higher level.
- `PFW-HOST-04` -- Host utility implementation detail; wire-contract behavior is retained at a higher level.
- `PFW-HOST-05` -- Host utility implementation detail; wire-contract behavior is retained at a higher level.
- `PFW-HOST-07` -- Host utility implementation detail; wire-contract behavior is retained at a higher level.
- `PFW-HOST-08` -- Host utility implementation detail; wire-contract behavior is retained at a higher level.
- `PFW-HOST-11` -- Host utility implementation detail; wire-contract behavior is retained at a higher level.
- `PFW-HOST-14` -- Host utility implementation detail; wire-contract behavior is retained at a higher level.
- `PFW-HOST-15` -- Host utility implementation detail; wire-contract behavior is retained at a higher level.
- `PFW-HOST-16` -- Host utility implementation detail; wire-contract behavior is retained at a higher level.
- `PFW-HOST-18` -- Host utility implementation detail; wire-contract behavior is retained at a higher level.

### Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PFW-INIT-01` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PFW-INIT-02` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PFW-INIT-03` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PFW-INIT-04` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PFW-INIT-08` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PFW-INIT-09` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PFW-INIT-10` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PFW-INIT-12` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PFW-ETH-01` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PFW-ETH-02` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PFW-ETH-05` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PFW-ETH-06` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PFW-ETH-07` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PFW-ETH-08` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PFW-ETH-09` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PFW-TLM-01` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PFW-TLM-03` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PFW-TLM-04` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PFW-TLM-05` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PFW-TLM-06` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PFW-TLM-07` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PFW-TLM-09` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PFW-ERR-04` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PFW-ERR-05` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PFW-ERR-06` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PFW-ERR-07` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PFW-ERR-09` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.

### Over-specified design detail; not an external Class B requirement.
- `PFW-DMA-02` -- Over-specified design detail; not an external Class B requirement.
- `PFW-DMA-05` -- Over-specified design detail; not an external Class B requirement.
- `PFW-DMA-06` -- Over-specified design detail; not an external Class B requirement.
- `PFW-DMA-07` -- Over-specified design detail; not an external Class B requirement.
- `PFW-DMA-08` -- Over-specified design detail; not an external Class B requirement.
- `PFW-DMA-09` -- Over-specified design detail; not an external Class B requirement.
- `PFW-DMA-11` -- Over-specified design detail; not an external Class B requirement.
- `PFW-DMA-13` -- Over-specified design detail; not an external Class B requirement.

### Register field or programming detail moved to the consolidated ICD appendix.
- `PFW-TLM-12` -- Register field or programming detail moved to the consolidated ICD appendix.

### Register-map detail moved to the consolidated ICD appendix.
- `PFW-MEM-01` -- Register-map detail moved to the consolidated ICD appendix.
- `PFW-MEM-02` -- Register-map detail moved to the consolidated ICD appendix.
- `PFW-MEM-03` -- Register-map detail moved to the consolidated ICD appendix.
- `PFW-MEM-04` -- Register-map detail moved to the consolidated ICD appendix.
### Retained at higher interface level
- `PFW-ETH-03` -- Retained behavior is covered by a higher-level interface requirement or the ICD appendix.
- `PFW-UDP-07` -- Retained behavior is covered by a higher-level interface requirement or the ICD appendix.
- `PFW-UDP-08` -- Retained behavior is covered by a higher-level interface requirement or the ICD appendix.
- `PFW-DMA-10` -- Retained behavior is covered by a higher-level interface requirement or the ICD appendix.
- `PFW-CAM-30` -- Retained behavior is covered by a higher-level interface requirement or the ICD appendix.
- `PFW-CAM-34` -- Retained behavior is covered by a higher-level interface requirement or the ICD appendix.
- `PFW-PPS-02` -- Retained behavior is covered by a higher-level interface requirement or the ICD appendix.
- `PFW-HOST-17` -- Retained behavior is covered by a higher-level interface requirement or the ICD appendix.
