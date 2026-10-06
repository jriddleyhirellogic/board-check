# PolarFire firmware requirements findings

Findings are ordered by priority. Requirement claims cite the Flow baseline
export; code behavior cites the **flight firmware** at
`farsight-avionics-sw/Camera/` and `farsight-avionics-sw/Bootloader/`, and the
host tools at `farsight-avionics-sw/utils/`.

> **Re-adjudicated 2026-09-17.** Findings `PFW-F-01` through `PFW-F-29` were
> raised against `farsight-fpga/support/sw/`, which is the lab functional-test
> harness and not the flight software. See the design-source note in
> [`pf-firmware-requirements.md`](pf-firmware-requirements.md#design-source).
>
> **Eleven findings are withdrawn** as artefacts of the harness:
> `PFW-F-01` (in part), `PFW-F-02`, `PFW-F-03` (in part), `PFW-F-04`,
> `PFW-F-06`, `PFW-F-07`, `PFW-F-12`, `PFW-F-21`, `PFW-F-22`, `PFW-F-26` and
> `PFW-F-29`. Each carries a withdrawal note in place; identifiers are retained.
>
> **Three survive in a different and more serious form:** `PFW-F-08`,
> `PFW-F-13` and `PFW-F-30`.
>
> **Five are newly raised** against the flight design, which the harness could
> not have exposed: `PFW-F-31` to `PFW-F-35`.
>
> The original **Claim** and **Code** text of `PFW-F-01` to `PFW-F-29` is left
> unedited, including its `support/sw` citations. Those citations record what was
> actually examined when the finding was raised, and rewriting them would destroy
> the audit trail. Read the re-adjudication note at the end of each finding for
> its status against the flight source; the summary table is at the foot of this
> document.
>
> The net effect is that the flight firmware is substantially better than the
> previous adjudication recorded -- it implements command ingestion, mode
> control, request-addressed transfer and register-driven imaging parameters --
> and that the defects which remain are concentrated in fault response, time
> integrity and the host contract.

## PFW-F-01 -- HIGH -- Command interface not implemented in main firmware path

- **Claim:** The system shall support bus command ingestion, responses, valid command execution, mode commands, RS422 TMTC, and Ethernet TMTC (`reqs_list.txt:111`, `reqs_list.txt:121`, `reqs_list.txt:128`-`reqs_list.txt:131`, `reqs_list.txt:133`, `reqs_list.txt:166`, `reqs_list.txt:257`).
- **Code:** Firmware initializes UART but leaves `test_uart()` commented out and contains no command parser; the only UART loop is a disabled echo/test helper (`support/sw/src/main.c:116`-`support/sw/src/main.c:124`, `support/sw/src/main.c:679`-`support/sw/src/main.c:704`).
- **Consequence:** User commands, ACK/NAK responses, and TMTC telemetry interfaces cannot be verified against the baseline.
- **Disposition:** Human decision: either add the command interface or reword/retire the command-interface requirements for this firmware build.
- **Re-adjudicated 2026-09-17 -- PARTLY WITHDRAWN.** The RS-422 half is wrong.
  The flight application runs a dedicated `v_Serial_Comm_Task`
  (`Camera/src/main.c:60-65`); the UART ISR feeds every byte to the framing
  state machine (`Camera/src/hal/serial_comm.c:145`, `Camera/src/serial_sm.c:53`),
  which validates a CRC32 and posts complete messages to `Execute_Command()`
  (`Camera/src/hal/serial_comm.c:74-80`). Commands carry opcodes, are answered
  with an error byte, and unknown opcodes return `ERR_CMD_INVALID_OPCODE`
  (`Camera/src/command.c:519-521`). `PFW-INIT-07`, `PFW-TLM-14` and `PFW-TLM-16`
  are now `OK`. The Ethernet half survives and is re-raised as `PFW-F-33`.

## PFW-F-02 -- HIGH -- Firmware starts autonomous capture instead of defaulting to low-power/mode control

- **Claim:** The system shall have deterministic modes, initialize into Low-Power Mode, and perform imaging through commanded/manual/streaming modes (`reqs_list.txt:93`, `reqs_list.txt:138`-`reqs_list.txt:142`, `reqs_list.txt:149`-`reqs_list.txt:150`, `reqs_list.txt:209`-`reqs_list.txt:210`).
- **Code:** Startup waits, configures trigger registers, calls `trig_capture()`, waits for capture completion, and enters an infinite transfer loop without a mode state machine (`support/sw/src/main.c:232`-`support/sw/src/main.c:263`, `support/sw/src/main.c:264`-`support/sw/src/main.c:296`).
- **Consequence:** The as-built behavior conflicts with low-power default and command-gated imaging requirements.
- **Disposition:** Human decision: align requirements to autonomous bring-up behavior or implement the required mode manager.
- **Re-adjudicated 2026-09-17 -- WITHDRAWN.** The flight application implements
  a six-state mode machine -- low power, idle, armed, busy, transfer, fault
  (`Camera/include/camera_states.h:15-27`) -- and enters low power with the
  camera powered down (`Camera/src/CameraStates/camera_low_power_state.c:33-37`).
  Capture requires `START_ACQ_SYS_CMD` and is rejected outside armed state
  (`Camera/src/command.c:273-277`). Mode transitions are themselves validated:
  armed is reachable only from idle (`Camera/src/command.c:163-164`).
  `PFW-INIT-17` is now `OK`.

## PFW-F-03 -- HIGH -- User-configurable imaging and communication parameters are hard-coded

- **Claim:** Users shall be able to update imager parameters, frame/sequence parameters, trigger method, gain/black level, exposure, and communication interfaces (`reqs_list.txt:7`, `reqs_list.txt:135`-`reqs_list.txt:148`, `reqs_list.txt:162`-`reqs_list.txt:164`, `reqs_list.txt:182`-`reqs_list.txt:188`).
- **Code:** Ports, IPs, MACs, timing, capture amount, PPS time, gain, black level, and frame geometry are compile-time constants or fixed startup writes (`support/sw/src/main.c:32`-`support/sw/src/main.c:50`, `support/sw/src/main.c:181`-`support/sw/src/main.c:214`, `support/sw/src/main.c:234`-`support/sw/src/main.c:241`, `support/sw/src/util.c:385`-`support/sw/src/util.c:397`).
- **Consequence:** Parameter update requirements are not satisfied by the current firmware.
- **Disposition:** Reword as fixed bring-up defaults or add a persistent user-parameter service.
- **Re-adjudicated 2026-09-17 -- LARGELY WITHDRAWN.** Imaging and network
  parameters are host-writable registers in flight, each validated by a callback
  that rejects out-of-range values: exposure
  (`Camera/src/register_callbacks.c:167-175`), gain (`:132-140`), black level
  (`:143-151`), bit depth (`:121-129`), frame period (`:218-237`), images per
  trigger (`:197-205`). The network endpoint is eight registers latched by
  `UPDATE_NET_ADDRESS` (`Camera/src/camera.c:459-508`). The PPS epoch is
  commanded by `SET_TIME_SYS_CMD` (`Camera/src/command.c:216-225`), not compiled
  in. What survives is narrower and is carried by `PFW-F-31`: registers live in
  RAM only, so every parameter reverts to its default on reset.

## PFW-F-04 -- HIGH -- Frame transfers are not request-addressed, cancelable, direct, or clearable

- **Claim:** The system shall transfer images upon request, support direct transfer, cancel transfers, read addressed frame-buffer sections, clear addressed frame-buffer regions, and start streaming upon request (`reqs_list.txt:90`-`reqs_list.txt:102`, `reqs_list.txt:112`, `reqs_list.txt:213`-`reqs_list.txt:216`).
- **Code:** The main loop automatically transfers fixed frame indexes 0..511 from DDR4 16GB and 0..255 from DDR4 8GB; no request decoder, direct sensor path, cancel path, or frame-buffer clear command appears in scope (`support/sw/src/main.c:264`-`support/sw/src/main.c:296`, `support/sw/src/main.c:471`-`support/sw/src/main.c:490`).
- **Consequence:** Required transfer control semantics are absent.
- **Disposition:** Fix firmware if this is flight behavior; otherwise split these requirements by supported interface and mark unsupported ones not applicable.
- **Re-adjudicated 2026-09-17 -- WITHDRAWN.** `XFER_BUFF_SYS_CMD` takes a
  starting index and a frame count, validates them with
  `u8_Check_Frame_Bounds()`, and rejects a request made in the wrong mode
  (`Camera/src/command.c:294-318`). The transfer state machine walks exactly the
  requested range (`Camera/src/CameraStates/camera_transfer_state.c:60-94`).
  `PFW-INIT-18` is now `OK`. Cancellation remains unimplemented and is folded
  into `PFW-F-31`.

## PFW-F-05 -- HIGH -- Fault and temperature values are sampled but not reported or acted upon

- **Claim:** The system shall detect faults, report faults in health/status telemetry, provide telemetry upon request, monitor temperatures, and power off the FPA on over-temperature (`reqs_list.txt:143`-`reqs_list.txt:144`, `reqs_list.txt:171`, `reqs_list.txt:228`-`reqs_list.txt:229`).
- **Code:** Firmware reads camera temperature, FPGA junction temperature, and camera fault status into local/global variables but does not threshold, power down, log, or report them through a user interface (`support/sw/src/main.c:247`-`support/sw/src/main.c:263`, `support/sw/src/main.c:645`-`support/sw/src/main.c:662`).
- **Consequence:** Fault containment and health reporting requirements are not satisfied.
- **Disposition:** Add fault policy and telemetry reporting, or reword requirements to raw metadata sampling only.

## PFW-F-06 -- HIGH -- `configure_trig()` rejects invalid inputs but startup ignores the result

- **Claim:** Firmware shall manage imaging sequences and valid command execution (`reqs_list.txt:103`, `reqs_list.txt:128`-`reqs_list.txt:131`).
- **Code:** `configure_trig()` returns `-1` when capacity or timing checks fail, but startup calls it without checking the return value before capture (`support/sw/src/main.c:232`-`support/sw/src/main.c:241`, `support/sw/src/main.c:555`-`support/sw/src/main.c:574`).
- **Consequence:** A failed trigger configuration can be followed by a capture attempt with stale or partial trigger state.
- **Disposition:** Fix firmware to check and handle the return code before `trig_capture()`.
- **Re-adjudicated 2026-09-17 -- WITHDRAWN.** `START_ACQ_SYS_CMD` checks
  `b_Trigger_Is_Ready()` and returns `ERR_REG_INVALID_LIMIT` instead of posting
  the capture event (`Camera/src/command.c:278-286`). The in-code comment states
  the reasoning: firing would "capture at the settings of an earlier burst".
  `PFW-ERR-03` is now `OK`.

## PFW-F-07 -- HIGH -- Frame transfer wait can spin forever

- **Claim:** Transfers shall be manageable by firmware and cancelable by the bus (`reqs_list.txt:101`, `reqs_list.txt:213`).
- **Code:** `xfer_frame_via_udp()` waits while `FRAME_READ_DONE_COUNT` equals the sampled value and implements no timeout despite reading timeout error registers later (`support/sw/src/main.c:480`-`support/sw/src/main.c:490`, `support/sw/src/main.c:276`-`support/sw/src/main.c:292`).
- **Consequence:** A stuck DMA read can permanently hang the firmware in the transfer loop.
- **Disposition:** Fix firmware with a timeout, error report, and cancellation path.
- **Re-adjudicated 2026-09-17 -- WITHDRAWN.** The flight design does not poll for
  completion at all: the FPGA raises `FRAME_READ_DONE_IRQ`, handled by
  `v_UDP_Transfer_Handler()`, which posts `UDP_TRANSFER_COMPLETE`
  (`Camera/src/camera.c:861-868`). The transfer state arms a 500 ms timer for
  every frame and transitions to fault state on expiry
  (`Camera/src/CameraStates/camera_transfer_state.c:44`, `:70-71`, `:92-94`).
  The busy-wait this finding describes is present only as commented-out code
  (`Camera/src/camera.c:390-391`). `PFW-DMA-14` and `PFW-DMA-17` are now `OK`.
  The 2x margin between the 500 ms bound and the 249 ms nominal transfer is
  raised separately as `PFW-F-32`.

## PFW-F-08 -- HIGH -- CoreTSE station MAC disagrees with UDP source MAC

- **Claim:** The system shall support Ethernet image transfer and configurable MAC addressing (`reqs_list.txt:184`, `reqs_list.txt:194`, `reqs_list.txt:196`).
- **Code:** CoreTSE station address is programmed as `0x6060603C`/`0xB1C00000`, while the UDP core source MAC is programmed as `0x0004`/`0xA3123456` (`support/sw/src/eth.c:330`-`support/sw/src/eth.c:333`, `support/sw/src/main.c:36`-`support/sw/src/main.c:39`, `support/sw/src/main.c:393`-`support/sw/src/main.c:397`).
- **Consequence:** Ethernet source identity is ambiguous and may break switching, filtering, or protocol verification.
- **Disposition:** Human decision: select one MAC ownership model and make both blocks consistent.
- **Re-adjudicated 2026-09-17 -- SURVIVES, WORSE.** Against the harness this was
  a disagreement between two non-zero constants. In flight the CoreTSE station
  address is still hardcoded to `0x6060603C` / `0xB1C00000`
  (`Camera/src/eth.c:330-333`), while the UDP source MAC now comes from
  `SRC_MAC_ADDRESS_*_SYS_REG`, which reset to **zero**
  (`Camera/src/register.c:98-100`). Nothing initialises them from the station
  address and nothing reconciles the two. Until the host writes all eight
  network registers and issues `UPDATE_NET_ADDRESS`, the payload emits frames
  with an all-zero source MAC. A zero source MAC is not merely inconsistent: it
  is invalid for learning bridges and is commonly dropped outright.

## PFW-F-09 -- HIGH -- Nonvolatile state, register persistence, and logging are absent

- **Claim:** TMTC shall load/update nonvolatile registers, manage NVM, back up critical state, record events, increment boot/error/frame counts, and back up IP configuration (`reqs_list.txt:100`, `reqs_list.txt:107`, `reqs_list.txt:116`, `reqs_list.txt:123`-`reqs_list.txt:127`, `reqs_list.txt:180`-`reqs_list.txt:181`, `reqs_list.txt:188`).
- **Code:** Scoped firmware has no NVM driver usage, no boot-count update, no event log, and no nonvolatile counter update in `main.c` (`support/sw/src/main.c:1`-`support/sw/src/main.c:704`).
- **Consequence:** Reset persistence and auditability requirements are not met.
- **Disposition:** Add NVM-backed state management or assign these requirements to another subsystem with evidence.
- **Re-adjudicated 2026-09-17 -- SURVIVES.** Confirmed against the flight source:
  the register table is a RAM-only static array
  (`Camera/src/register.c:23`, `:39-116`) with no flash load or save path, and
  no event log exists. Detail and the affected ICD registers are carried by
  `PFW-F-31`.

## PFW-F-10 -- HIGH -- Focus mechanism control is absent

- **Claim:** TMTC/C&DH firmware shall configure and actuate focus distance, provide a default 80 km focus position, and control to +/-5% (`reqs_list.txt:94`, `reqs_list.txt:106`, `reqs_list.txt:122`, `reqs_list.txt:145`, `reqs_list.txt:225`-`reqs_list.txt:226`).
- **Code:** The scoped firmware contains camera, DMA, PPS, Ethernet, GPIO, and SPI setup but no focus actuator registers, commands, defaults, or control loop (`support/sw/src/main.c:127`-`support/sw/src/main.c:214`, `support/sw/src/main.c:317`-`support/sw/src/main.c:349`).
- **Consequence:** Focus requirements cannot be verified against this firmware.
- **Disposition:** Identify the owning firmware/hardware item or implement focus support.
- **Re-adjudicated 2026-09-17 -- WITHDRAWN.** The flight application implements
  focus control: a dedicated `v_Focus_Task` (`Camera/src/main.c:67-72`), a focus
  state machine and seven state handlers (`Camera/src/focus_sm.c`,
  `Camera/src/Focus_States/`, 816 lines in total), LVDT position sensing and a
  PID loop (`Camera/include/pid.h`, `Camera/include/lvdt.h`), and a
  `HALT_FOCUS_SYS_CMD` opcode (`Camera/include/command.h:31`). None of this
  existed in the harness.

## PFW-F-11 -- MEDIUM -- Exposure timing limits and 100 ns accuracy are not evidenced

- **Claim:** Avionics shall know/control exposure start/stop to 100 ns and support specific min/max/resolution exposure settings (`reqs_list.txt:36`-`reqs_list.txt:38`, `reqs_list.txt:84`, `reqs_list.txt:96`-`reqs_list.txt:97`, `reqs_list.txt:199`-`reqs_list.txt:202`).
- **Code:** Firmware writes fixed SHS, VMAX, HMAX, trigger low, and capture-time values but includes no conversion proof to 100 ns behavior and no user exposure register path (`support/sw/src/main.c:41`-`support/sw/src/main.c:42`, `support/sw/src/main.c:324`-`support/sw/src/main.c:338`, `support/sw/src/util.c:209`-`support/sw/src/util.c:220`, `support/sw/src/util.c:331`-`support/sw/src/util.c:348`).
- **Consequence:** Exposure capability may exist in sensor/FPGA timing, but firmware evidence is insufficient.
- **Disposition:** Reword requirements with measurable register/timebase definitions or add analysis evidence.

## PFW-F-12 -- MEDIUM -- `MUX_CLEAR` is never deasserted

- **Claim:** Firmware shall reset/clear DMA and mux state deterministically as part of frame-buffer setup (`reqs_list.txt:89`, `reqs_list.txt:117`).
- **Code:** `cam_mux_clear()` writes `MUX_CLEAR=1` and delays but does not write it back to 0; neighboring clear/reset pulses deassert their clear bits (`support/sw/src/main.c:428`-`support/sw/src/main.c:432`, `support/sw/src/main.c:421`-`support/sw/src/main.c:425`, `support/sw/src/main.c:450`-`support/sw/src/main.c:459`).
- **Consequence:** The mux can remain held in clear/reset if the hardware interprets the bit level-sensitively.
- **Disposition:** Fix firmware unless hardware documentation proves write-one self-clear behavior.
- **Re-adjudicated 2026-09-17 -- WITHDRAWN.** `cam_mux_clear()` asserts
  `MUX_CLEAR`, waits 10 ms and reads the register back
  (`Camera/src/camera.c:341-348`), and is called from `v_Reset_Camera_Buffer()`
  alongside the write-index reset (`Camera/src/camera.c:550`). `DRV-PFW-01` is
  now `OK`. That the readback value is discarded is folded into `PFW-F-31`.

## PFW-F-13 -- MEDIUM -- Metadata retrieval does not wait for completion

- **Claim:** Imagery and time-correlated telemetry shall be managed together (`reqs_list.txt:89`, `reqs_list.txt:99`).
- **Code:** `get_metadata()` samples `FRAME_READ_DONE_COUNT` but never compares it; it waits a fixed 5 ms before copying 20 words (`support/sw/src/main.c:501`-`support/sw/src/main.c:516`).
- **Consequence:** Metadata can be stale or from the wrong frame under latency variation.
- **Disposition:** Fix firmware to wait on the completion counter or document a guaranteed hardware latency.
- **Re-adjudicated 2026-09-17 -- SURVIVES.** `get_metadata()` asserts
  `FRAME_READ_REQ`, waits a fixed `vTaskDelay(5)` = 5 ms, and copies the 20-word
  block (`Camera/src/camera.c:397-419`). The fixed delay is not a completion
  check. The sharper point in the flight design is that the correct mechanism is
  already present and used elsewhere: the frame transfer path waits on
  `FRAME_READ_DONE_IRQ` (`Camera/src/camera.c:861-868`). The metadata path does
  not use it.

## PFW-F-14 -- MEDIUM -- Temperature telemetry scaling and limit thresholds are undefined

- **Claim:** Health telemetry shall support state-of-health evaluation and temperature-limit actions (`reqs_list.txt:98`, `reqs_list.txt:171`, `reqs_list.txt:228`-`reqs_list.txt:229`).
- **Code:** Camera temperature is stored as a raw byte in `SENSOR_TEMP_RAW`, and FPGA junction temperature is read as a raw word with no units, scaling, or threshold comparison (`support/sw/src/main.c:645`-`support/sw/src/main.c:657`, `support/sw/src/include/image_metadata.h:58`-`support/sw/src/include/image_metadata.h:62`, `support/sw/src/include/junc_temp.h:4`-`support/sw/src/include/junc_temp.h:8`).
- **Consequence:** Verification cannot prove thermal margins or over-temperature response.
- **Disposition:** Define units/limits and implement threshold handling.

## PFW-F-15 -- MEDIUM -- Redundant Ethernet is not implemented in the scoped firmware

- **Claim:** FARSIGHT Avionics shall have redundant Ethernet interfaces (`reqs_list.txt:195`).
- **Code:** Startup powers, resets, initializes, and uses ETH1 only (`support/sw/src/main.c:146`-`support/sw/src/main.c:158`, `support/sw/src/main.c:305`-`support/sw/src/main.c:315`).
- **Consequence:** Single-port firmware behavior cannot satisfy redundant-interface requirements.
- **Disposition:** Add ETH2 support or reassign redundancy to another artifact.

## PFW-F-16 -- MEDIUM -- Gateway and subnet mask parameters are missing

- **Claim:** The user shall be able to set gateway and subnet mask parameters (`reqs_list.txt:186`-`reqs_list.txt:187`).
- **Code:** UDP setup writes destination/source port, destination/source IP, and MAC words only; no gateway or subnet-mask registers are touched (`support/sw/src/main.c:359`-`support/sw/src/main.c:397`).
- **Consequence:** Network-interface configuration requirements are incomplete for the as-built register set.
- **Disposition:** Reword if UDP core is static L2/L3 only, or add registers and command plumbing.
- **Re-adjudicated 2026-09-17 -- SURVIVES, NARROWED.** `GATEWAY_SYS_REG` (0x89)
  and `SUBNET_MASK_SYS_REG` (0x8D) are defined
  (`Camera/include/reg_address.h:67-68`) but are not initialised in the register
  table, so they are unreadable and unwritable in the same way as the registers
  listed in `PFW-F-31`. The parameters exist in the address map and not in the
  implementation.

## PFW-F-17 -- MEDIUM -- Version information is not provided upon request and is not a C&DH firmware string

- **Claim:** Avionics shall provide version information upon request and a unique C&DH firmware version string (`reqs_list.txt:158`-`reqs_list.txt:159`).
- **Code:** Firmware reads FPGA `BUILD_VERSION`, `BUILD_GIT_HASH`, and `BUILD_TIME_UTC_SEC`, but only copies `BUILD_VERSION` to image metadata; no request path or firmware string is implemented (`support/sw/src/main.c:671`-`support/sw/src/main.c:676`, `support/sw/src/include/hw_version.h:4`-`support/sw/src/include/hw_version.h:20`).
- **Consequence:** Baseline version-query behavior is not available.
- **Disposition:** Add a version telemetry command and distinguish FPGA build ID from firmware build ID.
- **Re-adjudicated 2026-09-17 -- PARTLY WITHDRAWN.** Version information is
  available on request: `GET_VERSION_SYS_CMD` (0x00) returns a `Version_t`
  (`Camera/src/command.c:141`), populated at startup by `v_Read_Version_Info()`
  (`Camera/src/main.c:46-47`). Whether the returned string matches the C&DH
  firmware-string format the ICD specifies has not been re-verified and is the
  part that survives.

## PFW-F-18 -- MEDIUM -- Image identifier uniqueness is not shown in firmware

- **Claim:** Imagery shall include unique identifiers for individual frames (`reqs_list.txt:154`).
- **Code:** Transfer requests use fixed frame indexes and metadata copies 20 raw words; no firmware-generated unique identifier is visible in the scoped source (`support/sw/src/main.c:264`-`support/sw/src/main.c:296`, `support/sw/src/main.c:500`-`support/sw/src/main.c:516`).
- **Consequence:** Frame-to-frame uniqueness cannot be verified from firmware alone.
- **Disposition:** Identify a metadata word owned by FPGA logic or add explicit firmware-generated frame IDs.

## PFW-F-19 -- MEDIUM -- PCIe data-transfer requirements lack firmware support evidence

- **Claim:** Avionics shall provide two PCIe interfaces and PCIe shall be transmit-only (`reqs_list.txt:175`-`reqs_list.txt:177`, `reqs_list.txt:191`).
- **Code:** Firmware selects Ethernet at startup; the host-side PCIe converter only strips alignment padding from a raw file and is not firmware PCIe control evidence (`support/sw/src/main.c:204`-`support/sw/src/main.c:208`, `support/sw/src/main.c:635`-`support/sw/src/main.c:638`, `support/py-script/recv_conv/converter_pcie.py:15`-`support/py-script/recv_conv/converter_pcie.py:18`).
- **Consequence:** PCIe requirements remain unverified for the soft-core firmware.
- **Disposition:** Reassign to FPGA datapath/host artifacts or add firmware-controlled PCIe behavior.

## PFW-F-20 -- MEDIUM -- IMX sensor enable is automatic rather than request-mediated

- **Claim:** The housekeeper FPGA shall enable the IMX sensor upon request from the PolarFire FPGA (`reqs_list.txt:231`).
- **Code:** PolarFire firmware drives `CAM_PWR_EN` and `CAM_OSC_EN` during startup with no explicit request/ack protocol to the housekeeper (`support/sw/src/main.c:160`-`support/sw/src/main.c:168`, `support/sw/src/include/gpio_pin_def.h:47`-`support/sw/src/include/gpio_pin_def.h:50`).
- **Consequence:** The interface contract may be correct electrically but not traceable to a request/response requirement.
- **Disposition:** Reword as GPIO control or document the GPIO write as the request.
- **Re-adjudicated 2026-09-17 -- WITHDRAWN.** Sensor power is request-mediated in
  flight. The payload boots with the camera powered down
  (`Camera/src/CameraStates/camera_low_power_state.c:33-37`) and the rail is
  enabled only on the commanded transition into idle
  (`Camera/src/CameraStates/camera_idle_state.c:40`). The automatic power-up this
  finding describes was the harness's linear startup.

## PFW-F-21 -- LOW -- Host metadata endian comment contradicts code

- **Claim:** Host documentation/commentary should describe metadata decoding consistently.
- **Code:** `converter.py` says metadata is little-endian but unpacks each word with big-endian `'>I'` (`support/py-script/recv_conv/converter.py:96`-`support/py-script/recv_conv/converter.py:111`).
- **Consequence:** Test tooling or requirements may implement the wrong byte order.
- **Disposition:** Fix the host comment or, if the comment is correct, fix the decoder.
- **Re-adjudicated 2026-09-17 -- WITHDRAWN.** The contradicting comment and
  decode existed only in the deleted harness tool. The flight-side converter
  `farsight-avionics-sw/utils/converter.py` contains no metadata handling of any
  kind, so there is no byte-order disagreement to report. The absence is a
  larger problem than the inconsistency was, and is raised as `PFW-F-35`.

## PFW-F-22 -- LOW -- CMake processor string disagrees with compiler architecture flags

- **Claim:** Build configuration should identify the target consistently.
- **Code:** The toolchain file reports processor `rv32i`, while compiler flags use `rv32im` (`support/sw/cmake/riscv_toolchain.cmake:86`-`support/sw/cmake/riscv_toolchain.cmake:89`, `support/sw/cmake/riscv_flags.cmake:19`-`support/sw/cmake/riscv_flags.cmake:24`).
- **Consequence:** Build metadata may mislead requirement and tool qualification evidence.
- **Disposition:** Reword the CMake processor string or document why it is informational only.
- **Re-adjudicated 2026-09-17 -- WITHDRAWN.** The CMake processor string belonged
  to the harness build, which no longer exists. The flight application is built
  from `Camera/release/` and `Camera/bootloader_release/` makefiles.

## PFW-F-23 -- LOW -- DMA read clear offset alias is malformed

- **Claim:** Register definitions should provide unambiguous symbolic names for verification.
- **Code:** `CLEAR_DMA_READ_CTRL_OFFSET` aliases undefined `CLEAR_REG_OFFSET`, while the used token-paste form relies on `CLEAR_DMA_READ_CTRL_REG_OFFSET` (`support/sw/src/include/dma_read_ctrl_reg.h:6`-`support/sw/src/include/dma_read_ctrl_reg.h:10`, `support/sw/lib/mpf_platform_driver/hal/hal.h:73`-`support/sw/lib/mpf_platform_driver/hal/hal.h:87`).
- **Consequence:** A future use of the non-`_REG_OFFSET` alias will fail or resolve incorrectly.
- **Disposition:** Fix the header alias.

## PFW-F-24 -- LOW -- Host image dimension documentation is inconsistent

- **Claim:** Host README says PNG output is `4512x4581`, and converter CLI description says `4512x4512` (`support/py-script/recv_conv/README.md:354`-`support/py-script/recv_conv/README.md:358`, `support/py-script/recv_conv/converter.py:210`-`support/py-script/recv_conv/converter.py:230`).
- **Code:** Converter removes row 0 metadata and rows 1-4 EBD, producing rows 5-4580 as the image (`support/py-script/recv_conv/converter.py:131`-`support/py-script/recv_conv/converter.py:139`).
- **Consequence:** Verification may assert the wrong output image height.
- **Disposition:** Fix host documentation and CLI help text.

## PFW-F-25 -- LOW -- Host receiver `out_of_order` statistic is never incremented

- **Claim:** Receiver statistics imply out-of-order packet tracking.
- **Code:** `packet_loss_stats` includes `out_of_order`, but packet processing paths do not increment it (`support/py-script/recv_conv/receiver.py:52`-`support/py-script/recv_conv/receiver.py:59`, `support/py-script/recv_conv/receiver.py:213`-`support/py-script/recv_conv/receiver.py:305`).
- **Consequence:** Receiver diagnostics understate or omit packet ordering issues.
- **Disposition:** Fix host statistic handling or remove the unused field.

## PFW-F-26 -- LOW -- Dead or unused bring-up code remains in scope

- **Claim:** Verification baseline should avoid relying on unused behavior.
- **Code:** `cam_stat` is declared but not initialized, `sgmii_aneg_timeout` is declared but unused, `set_pattern_gen()` is not called, and `capture_and_view.py` builds an unused `converter_cmd` list (`support/sw/src/main.c:64`-`support/sw/src/main.c:73`, `support/sw/src/eth.c:113`-`support/sw/src/eth.c:117`, `support/sw/src/main.c:344`, `support/sw/src/util.c:418`-`support/sw/src/util.c:428`, `support/py-script/recv_conv/capture_and_view.py:342`-`support/py-script/recv_conv/capture_and_view.py:360`).
- **Consequence:** Dead code can be mistaken for implemented requirements.
- **Disposition:** Remove dead code or mark it explicitly as non-flight/test-only.
- **Re-adjudicated 2026-09-17 -- WITHDRAWN.** The duplicated
  `set_standby_and_master_mode()` call and the commented-out `test_udp_dbg()`
  block were harness artefacts. The flight `init_slvsec()` sequence
  (`Camera/src/camera.c:632-670`) does not contain them.

## PFW-F-27 -- LOW -- Timer register field definitions appear internally inconsistent

- **Claim:** Register headers should define bit fields consistently.
- **Code:** `TIMER_CONTROL`, `TIMER_ENABLE`, `TIMER_MODE`, and `TIMER_INT_ENABLE` share offset 8 but use full `0xFFFFFFFF` masks with different shifts; the application does not use `TIMER_BASE_ADDR` (`support/sw/src/include/timer.h:16`-`support/sw/src/include/timer.h:38`, `support/sw/lib/mpf_platform_config/fpga_design_config/fpga_design_config.h:87`).
- **Consequence:** Timer IP verification based on this header may be ambiguous.
- **Disposition:** Confirm the timer register spec and correct field masks if needed.

## PFW-F-28 -- LOW -- Host environment checker is not automation-friendly

- **Claim:** Host checker is described as a one-step setup checker.
- **Code:** `check_env.sh` prompts on `/dev/tty`, which fails in non-interactive automation (`support/py-script/recv_conv/check_env.sh:93`-`support/py-script/recv_conv/check_env.sh:112`, `support/py-script/recv_conv/check_env.sh:143`-`support/py-script/recv_conv/check_env.sh:180`).
- **Consequence:** CI or scripted validation can hang or fail unexpectedly.
- **Disposition:** Add a non-interactive flag or document interactive-only use.

## PFW-F-29 -- MEDIUM -- Network endpoint is configurable in the ICD but fixed in firmware

**The network endpoint is a configurable interface that firmware treats as fixed.**

**Expected.** CM-01979 sections 17.4.44 to 17.4.51 define the UDP endpoint as
eight host-writable registers -- source and destination MAC, source and
destination IPv4 address, source and destination port -- each with a reset value
of zero, each latched into the UDP core only when the `UPDATE_NET_ADDRESS`
command is issued. All eight are marked `IMPLEMENTED = Yes`.

**Actual.** `support/sw/src/main.c:32`-`:38` hold the endpoint as compile-time
constants -- destination port 35121, source port 1234, destination IPv4
10.101.15.195, source IPv4 10.101.15.192 -- and apply them during startup at
`:372`-`:393`.

**Why it matters.** Both statements can be true at once: the constants are
startup defaults and the registers still work. The defect is that nothing
records which is the contract. Four requirements, `PFW-UDP-01` to `PFW-UDP-04`,
stated the constants as though the addresses were fixed by design. A reader of
the requirement set would have concluded the payload cannot be re-addressed
without a firmware rebuild, which is the opposite of what the ICD offers the
integrator.

The operational consequence is in the reset values. The ICD says the registers
reset to zero, so if the host relies on the documented model -- write the
endpoint, issue `UPDATE_NET_ADDRESS` -- it inherits whatever `main.c` last
applied rather than a defined state, and the two models disagree silently about
what the endpoint is after a reset.

**Disposition.** Needs an owner decision on which model is the contract. If the
registers are the contract, the `main.c` constants should be documented as
defaults and the ICD reset values corrected to match them. If the constants are
the contract, the registers should be marked `IMPLEMENTED = No` and the
`UPDATE_NET_ADDRESS` command withdrawn. `PFW-UDP-01` to `PFW-UDP-04` are
withdrawn either way; they stated interface data rather than behaviour.
- **Re-adjudicated 2026-09-17 -- WITHDRAWN.** The flight design implements
  exactly the model the ICD documents: eight host-writable network registers,
  reset to zero (`Camera/src/register.c:98-105`), latched into the UDP core by
  `update_network_addresses()` when `UPDATE_NET_ADDRESS` is issued
  (`Camera/src/camera.c:459-508`, `Camera/src/command.c:415-417`). `PFW-UDP-05`
  and `PFW-UDP-06` are now `OK`. The zero reset value is not benign, however --
  see the restatement of `PFW-F-08`.

## PFW-F-30 -- HIGH -- Frame rate ceiling is below the system requirement

**The sensor line period in use cannot reach the required frame rate, and the
admission check subtracts further from it.**

**Expected.** FAR-FPA_L5REQ-5 requires a maximum frame rate of at least 70 FPS
at maximum bit depth, sustainable for at least 5 seconds (TBR).

**Actual.** The flight firmware derives the frame rate from the sensor line
period rather than storing it as a constant
(`Camera/include/camera.h:163-181`):

```c
fps = SENSOR_DEFAULT_FPS * SENSOR_DEFAULT_HMAX / hmax
```

With `SENSOR_DEFAULT_HMAX` = 0xD1 and `SENSOR_DEFAULT_FPS_CENTI` = 7590, the
16GB line period `DDR4_16GB_HMAX` = 0xE3 yields **69.88 FPS** -- a minimum frame
period of 14,310 us -- before any exposure is added
(`Camera/include/camera.h:147-148`). The 8GB line period 0xF7 yields 64.22 FPS.

`Set_Frame_Capture_Time()` then requires
(`Camera/src/register_callbacks.c:224`):

```c
if( u32_Capture_Time_usec < u32_Exposure_usec + u32_Min_Frame_Time_usec() )
    return ERR_REG_INVALID_LIMIT;
```

so the admitted ceiling is **69.67 FPS** at the 43 us minimum exposure and
**67.52 FPS** at the 500 us default (`Camera/include/defaults.h:16`). A 70 FPS
cadence is rejected at every exposure and on both buffers.

**Why it matters.** The shortfall from the line period alone is 0.17%, which is
small enough to be recoverable by a line-period change and small enough to have
been missed by inspection. Two readings need separating, and they have different
fixes:

- If 0xE3 was chosen for DDR4 write bandwidth, then the frame-rate requirement
  and the buffer bandwidth are in direct conflict and one of them has to move.
  That is a system-level decision, not a firmware one.
- If 0xE3 was chosen to give margin against an unrelated constraint, the
  requirement may be reachable at a slightly shorter line period.

Separately, the exposure term makes the ceiling depend on a user-settable
parameter, so the maximum achievable frame rate is not a fixed property of the
payload and no single number can be quoted to operations without also quoting
the exposure it assumes.

**Why it was not caught.** Until `PFW-CAM-39` and `PFW-CAM-40` were written on
2026-09-17, no requirement stated the frame cadence at all. `PFW-CAM-29`
required only that a too-short period be rejected, and was adjudicated `OK`
because the check exists. Nobody compared the value the check enforces against
the rate the system asks for. That is the failure mode a missing performance
requirement produces: the behaviour is verified and the number is never checked.

**Note on the earlier version of this finding.** As first raised on 2026-09-17
against the lab harness, this finding reported a 65.4 FPS cap caused by the
trigger-low interval being added to the frame write time. That mechanism is
specific to the harness, whose check was
`frame_capture_time < xtrig_low_time_usec + DDR4_16GB_FRAME_TIME` with a
hardcoded 70 FPS constant. The flight formulation is materially better
engineered -- the rate is derived from HMAX, and the header records that
hand-written constants had previously "drift[ed] from the HMAX they were
supposed to match" (`Camera/include/camera.h:151-160`). The conclusion survives
the correction; every number in it changed.

**Disposition.** Human decision, and it needs the sensor and frame-buffer owners
rather than firmware alone: confirm what fixes `DDR4_16GB_HMAX` at 0xE3, then
either change the line period or raise FAR-FPA_L5REQ-5 as unmet. Its TBR does
not defer this -- the gap is present at any required rate above 69.88 FPS.

## PFW-F-31 -- MEDIUM -- Register state is volatile and several ICD registers are disabled

**The register interface is RAM-only, and registers the ICD defines are commented
out of the table.**

**Claim:** CM-01979 defines the register space as the payload's configuration
and health interface; FAR-TMTC_SW_L4REQ-50 and FAR-L1REQ-15 require telemetry for state-of-health
evaluation, and FAR-TMTC_SW_L4REQ-42/FAR-TMTC_SW_L4REQ-36/FAR-TMTC_SW_L4REQ-37/FAR-TMTC_SW_L4REQ-38 require nonvolatile state and register
persistence.

**Code:** The register table is a static array in RAM
(`Camera/src/register.c:23`) initialised to defaults at every boot
(`Camera/src/register.c:39-116`). There is no flash load or save path. Every
commanded setting -- exposure, gain, black level, frame period, and the entire
network endpoint -- reverts on reset.

Several registers the ICD defines are present in `reg_address.h` and
`register.h` but commented out of the initialisation table, so reads and writes
return `ERR_REG_INVALID_ADDR`:

| Register | ICD REG_ID | Line |
| --- | --- | --- |
| `SENSOR_OVER_TEMP_KEL_SYS_REG` | 0x07 | `Camera/src/register.c:61` |
| `ERROR_COUNT_SYS_REG` | 0x0B | `Camera/src/register.c:67` |
| `BOOT_COUNT_SYS_REG` | 0x0C | `Camera/src/register.c:68` |
| `UPTIME_MSEC_SYS_REG` | 0x0D | `Camera/src/register.c:69` |
| `WDOG_TIMEOUT_MSEC_SYS_REG` | 0x0F | `Camera/src/register.c:71` |

**Consequence:** The over-temperature threshold register is the one that matters
most -- it is the mechanism by which `PFW-ERR-08` and `PFW-ERR-10` would be
satisfied, and it is disabled, so a Class A protection cannot be configured even
by a host that knows to try. Boot count, uptime and error count are the ordinary
means of satisfying FAR-TMTC_SW_L4REQ-50 and FAR-L1REQ-15. These five are the firmware half of the 19
`IMPLEMENTED = No` registers already listed in
[`tbr-register.md`](../../../docs/requirements/tbr-register.md).

Two smaller observations are folded in here rather than raised separately: the
`MUX_CLEAR` readback at `Camera/src/camera.c:347` is discarded, and no transfer
cancellation path exists, so a transfer can only be ended by completing or by
the 500 ms timeout.

**Disposition.** Decide per register: implement, or mark `IMPLEMENTED = No` in
the ICD with a recorded reason. Volatility of the register table is a separate
programmatic decision and should be raised against FAR-TMTC_SW_L4REQ-42 and FAR-TMTC_SW_L4REQ-37.

## PFW-F-32 -- LOW -- Frame transfer timeout has about 2x margin over the nominal transfer

**Claim:** `PFW-DMA-17` requires a bounded frame-read abandon time.

**Code:** `UDP_TRANSFER_TIMEOUT` is 500 ticks = 500 ms
(`Camera/src/CameraStates/camera_transfer_state.c:44`), and expiry transitions
the payload into `Camera_Fault_State`
(`Camera/src/CameraStates/camera_transfer_state.c:92-94`).

**Consequence:** One frame is 248.6 Mbit and occupies 249 ms at the 1000BASE-T
line rate, so the bound sits at roughly 2x the nominal transfer time. That is
thin for a timeout whose expiry drops the payload out of the transfer and into
fault state, and it is not derived from anything recorded. Any condition that
slows egress -- link renegotiation, a congested receiver, a retry in the fabric
-- risks a spurious fault during otherwise healthy operation.

**Disposition.** Confirm the intended margin by measurement, or state the bound
as a requirement with a recorded rationale. Note the interaction with
`PFW-UDP-13`: the fixed 100 ms inter-frame delay carries the comment "this is so
the flight computer can keep up", which suggests the receiver has already been
observed to be the limiting element.

## PFW-F-33 -- MEDIUM -- No command ingestion over Ethernet

**Claim:** FAR-EDT_L3REQ-3 requires command ingestion and telemetry transfer over
each Ethernet interface connected to the PolarFire. FAR-EDT_L3REQ-3 is dispositioned
`CONFLICT` on the same point.

**Code:** `Camera/src/eth.c` implements MAC and PHY initialization only
(`Camera/src/eth.c:19-61`, `:111-260`). There is no UDP receive path, no
ingress queue and no command decoder on the Ethernet side. The only command
path is RS-422 (`Camera/src/serial_sm.c:53`).

**Consequence:** `PFW-UDP-11` is `GAP`. Ethernet is transmit-only in the flight
build, so the redundancy intent of FAR-EDT_L3REQ-13 and the command intent of
FAR-EDT_L3REQ-3 both rest entirely on the RS-422 link.

**Disposition.** Human decision: implement Ethernet command ingestion, or
disposition FAR-EDT_L3REQ-3 and FAR-EDT_L3REQ-3 as not met by this build. This is the
narrow part of the withdrawn `PFW-F-01` that survives against the flight source.

## PFW-F-34 -- MEDIUM -- PPS lock is reported as always locked

**Claim:** Image timestamps are only meaningful if the time base is disciplined;
FAR-CDH_FPGA_L3REQ-13 requires time correlation of imagery.

**Code:** `b_PPS_Is_Locked()` returns the literal `1`
(`Camera/src/pps.c:41-44`):

```c
uint8_t b_PPS_Is_Locked(void)
{
    return 1;
}
```

The PPS block does expose real quality indicators -- `u32_Get_PPS_Freq_Error()`
and `u32_Get_PPS_Phase_Error()` (`Camera/src/pps.c:31-38`) -- and both are
returned in telemetry (`Camera/src/command.c:503-507`). Nothing compares either
against a threshold, and nothing consumes the lock indication.

**Consequence:** Any caller asking whether time is trustworthy is told yes,
unconditionally, including immediately after boot and before `SET_TIME_SYS_CMD`
has ever been issued. Image metadata timestamps therefore carry no indication of
validity, which is the evidence `PFW-TLM-15` needs and cannot get.

**Disposition.** Fix firmware: derive the lock indication from the frequency and
phase error registers against a stated threshold, and make the threshold a
requirement. The threshold is a systems decision, not a firmware one.

## PFW-F-35 -- MEDIUM -- Host converter does not decode the image metadata record

**Claim:** Firmware writes a 20-word metadata record into the head of the first
image row (`PFW-TLM-13`), and CM-01979 defines that record as part of the image
product.

**Code:** `farsight-avionics-sw/utils/converter.py` contains no metadata
handling -- the string "metadata" does not appear in the file.
`unpack_payload()` treats the entire payload, including the first row, as packed
pixel data (`utils/converter.py:30-68`).

**Consequence:** Every converted image product is affected twice. The first 80
bytes of the first row are metadata interpreted as pixels, so the top-left of
every image is corrupt; and the metadata itself -- timestamp, version, sensor
temperature, frame index -- is discarded, so the archived product cannot be
correlated with the capture that produced it. `PFW-HOST-13` is `GAP`.

**Disposition.** Implement metadata extraction in the flight-side converter. The
withdrawn `PFW-F-21` described a byte-order inconsistency in the harness tool's
implementation of exactly this feature; that implementation is the obvious
starting point, and its byte order needs settling against CM-01979 rather than
copying.

## Disposition gate

Do not auto-correct these without a named owner decision because they are
capability conflicts or real firmware bugs: PFW-F-05, PFW-F-08, PFW-F-09,
PFW-F-11, PFW-F-13, PFW-F-14, PFW-F-15, PFW-F-16, PFW-F-17, PFW-F-18,
PFW-F-19, PFW-F-30, PFW-F-31, PFW-F-33, PFW-F-34, PFW-F-35.

## Re-adjudication status, 2026-09-17

| Finding | Outcome against the flight source |
| --- | --- |
| PFW-F-01 | Partly withdrawn -- RS-422 command path exists; Ethernet half re-raised as PFW-F-33 |
| PFW-F-02 | Withdrawn -- six-state mode machine, boots into low power |
| PFW-F-03 | Largely withdrawn -- parameters are register-driven; volatility carried by PFW-F-31 |
| PFW-F-04 | Withdrawn -- transfers are request-addressed and bounds-checked |
| PFW-F-05 | Survives -- telemetry is returned on request, but no fault response acts on it |
| PFW-F-06 | Withdrawn -- trigger-readiness is checked before capture |
| PFW-F-07 | Withdrawn -- completion is interrupt-driven with a 500 ms bound |
| PFW-F-08 | Survives, worse -- station MAC constant vs source MAC defaulting to zero |
| PFW-F-09 | Survives -- RAM-only register table, no logging |
| PFW-F-10 | Withdrawn -- focus control is implemented |
| PFW-F-11 | Survives -- 100 ns exposure accuracy still unevidenced; parent is DEFECT |
| PFW-F-12 | Withdrawn -- mux clear is paired with the write-index reset |
| PFW-F-13 | Survives -- metadata read still has no completion check |
| PFW-F-14 | Survives -- telemetry scaling and thermal limits still undefined |
| PFW-F-15 | Survives -- only ETH1 is brought up |
| PFW-F-16 | Survives, narrowed -- gateway and subnet registers defined but disabled |
| PFW-F-17 | Partly withdrawn -- version is returned on request; string format unverified |
| PFW-F-18 | **Not re-verified** -- image identifier uniqueness |
| PFW-F-19 | Survives -- no firmware PCIe transfer path |
| PFW-F-20 | Withdrawn -- sensor power is request-mediated |
| PFW-F-21 | Withdrawn -- superseded by PFW-F-35 |
| PFW-F-22 | Withdrawn -- harness build artefact |
| PFW-F-23 | **Not re-verified** -- DMA read clear offset alias |
| PFW-F-24 | **Not re-verified** -- host image dimension documentation |
| PFW-F-25 | Survives -- `out_of_order` still never incremented (`utils/receiver.py`) |
| PFW-F-26 | Withdrawn -- dead bring-up code was the harness |
| PFW-F-27 | **Not re-verified** -- timer register field definitions |
| PFW-F-28 | **Not re-verified** -- host environment checker |
| PFW-F-29 | Withdrawn -- network endpoint is host-writable as the ICD specifies |
| PFW-F-30 | Survives, restated -- 69.88 FPS ceiling, different mechanism |
| PFW-F-31 to PFW-F-35 | Newly raised against the flight source |

Five findings are marked **not re-verified**. They are low-severity items whose
claims rest on artefacts that were not re-examined in this pass, and they should
not be read as either confirmed or withdrawn until they are.
