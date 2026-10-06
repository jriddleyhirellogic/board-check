# Avionics firmware findings

Findings are ordered by verification impact and capability risk. Code behavior is treated as authoritative for the as-built design unless the finding recommends a firmware fix.

## AV-F-01 -- HIGH -- FAR-TMTC_SW_L4REQ-5/FAR-FPA_L5REQ-1 exposure maximum conflict

**Requirement/ICD claim:** FAR-TMTC_SW_L4REQ-5 states that the TMTC system maximum exposure setting is >= 5 seconds, and FAR-FPA_L5REQ-1 says the FPA shall support exposures >= 5 seconds (`reqs_list.txt:199-201`).

**Code behavior:** The code rejects `SENSOR_EXPO_USEC_SYS_REG` values above `(1u << 22)-1`, or 4,194,303 us (about 4.194 s) (`Camera/include/camera.h:76-88`, `Camera/src/register_callbacks.c:167-175`).

**Consequence:** The implemented maximum exposure setting does not satisfy a 5 s system requirement.

**Recommended disposition:** Needs a human decision: reword FAR-TMTC_SW_L4REQ-5/FAR-FPA_L5REQ-1 to 4.194 s, increase the firmware register width/limit, or accept the limit with rationale.

## AV-F-02 -- HIGH -- FAR-TMTC_SW_L4REQ-6 exposure-zero behavior is stale

**Requirement/ICD claim:** FAR-TMTC_SW_L4REQ-6 claims the TMTC system sets exposure to 0.05 microseconds when `REG_EXPOSURE_TIME` is written as 0, while its value column says 0.05 nanoseconds (`reqs_list.txt:200-200`).

**Code behavior:** The implemented register is `SENSOR_EXPO_USEC_SYS_REG`; value 0 is below `SENSOR_EXPO_USEC_MIN` and is rejected with `ERR_REG_INVALID_LIMIT` (`Camera/include/register.h:22`, `Camera/include/camera.h:76-88`, `Camera/src/register_callbacks.c:167-175`).

**Consequence:** A verification written from FAR-TMTC_SW_L4REQ-6 would test a nonexistent register and expect the opposite of implemented behavior.

**Recommended disposition:** Reword the requirement to the implemented register name and minimum exposure rule, or change firmware if zero-as-minimum is required.

## AV-F-03 -- HIGH -- Manual Imaging Mode and Streaming Mode requirements are stale

**Requirement/ICD claim:** FAR-L1REQ-12, FAR-L1REQ-11, FAR-TMTC_SW_L4REQ-15, FAR-TMTC_SW_L4REQ-11, FAR-TMTC_SW_L4REQ-9, FAR-TMTC_SW_L4REQ-1, FAR-AEPS_L3REQ-1, and FAR-AEPS_L3REQ-14 are written against Manual Imaging Mode or Streaming Mode (`reqs_list.txt:21-21`, `reqs_list.txt:140-153`, `reqs_list.txt:216-216`, `reqs_list.txt:259-259`).

**Code behavior:** The code defines only Low Power, Idle, Armed, Busy, Fault, and Transfer camera states (`Camera/include/camera_states.h:15-27`). Image capture is Armed-to-Busy by trigger, and frame offload is Transfer (`Camera/src/CameraStates/camera_armed_state.c:317-337`, `Camera/src/CameraStates/camera_transfer_state.c:49-100`).

**Consequence:** Mode-based verification cannot map those system requirements to implemented states without reinterpretation. Streaming as a continuous mode is not implemented.

**Recommended disposition:** Reword the system requirements to use Low Power, Idle, Armed, Busy, Transfer, and Fault vocabulary; create separate future requirements if streaming mode is required.

## AV-F-04 -- HIGH -- Update Mode TMTC disable conflicts with bootloader design

**Requirement/ICD claim:** FAR-TMTC_SW_L4REQ-7 says the TMTC System shall be disabled when in Update Mode (`reqs_list.txt:189-189`).

**Code behavior:** The bootloader keeps a reduced TMTC dispatcher alive for version, echo, flash erase/read/write/reset, bootloader info, load-to-memory, start-app, and update commands (`Bootloader/src/command.c:51-127`). `UPDATE` clears the boot flag rather than disabling TMTC (`Bootloader/src/command.c:117-119`).

**Consequence:** The implemented update flow requires TMTC to remain enabled; disabling TMTC would prevent software update.

**Recommended disposition:** Reword FAR-TMTC_SW_L4REQ-7 to say nominal Camera TMTC is unavailable but bootloader update TMTC remains enabled.

## AV-F-05 -- HIGH -- Exposure 100 ns start/stop requirements are not demonstrated by firmware

**Requirement/ICD claim:** FAR-CDH_FPGA_L3REQ-17, FAR-CDH_FPGA_L3REQ-19, and FAR-CDH_FPGA_L3REQ-18 require exposure start or stop within <=100 ns (`reqs_list.txt:36-37`, `reqs_list.txt:96-97`).

**Code behavior:** Firmware programs trigger low time in 20 ns cycles after subtracting pedestal (`Camera/include/camera.h:208-217`, `Camera/src/CameraStates/camera_armed_state.c:207-246`) but commands acquisition through state events and hardware trigger IP (`Camera/src/command.c:273-292`, `Camera/src/CameraStates/camera_armed_state.c:317-324`).

**Consequence:** The code supports fine trigger pulse quantization, but it does not prove absolute integration start/stop latency from command, PPS, or external trigger detection.

**Recommended disposition:** Split into hardware timing requirements for trigger IP/sensor integration and firmware command-sequencing requirements; verify <=100 ns in FPGA/sensor hardware test.

## AV-F-06 -- LOW -- FAR-RS422_L3REQ-6 default baud-rate divisor yields approximately 115741 bps

**Requirement/ICD claim:** FAR-RS422_L3REQ-6 requires the RS422 Debug interface default baud rate to be 115200 (`reqs_list.txt:155-158`).

**Code behavior:** UART initialization calls `v_Set_UART_Divisor(..., BAUDRATE_115200)`, and the divisor macro is 27 for a 50 MHz clock (`Camera/src/hal/hal_uart16550.c:23-28`, `Camera/include/hal_uart16550.h:75-79`). By the documented formula `BR = F_PCLK/(16*DIVISOR)`, the configured rate is 50,000,000/(16*27) = 115,740.7 bps (`Camera/include/hal_uart16550.h:75-79`).

**Consequence:** The design intent is 115200 baud, but the integer divisor gives a nominal +0.47% rate error; hardware measurement is still needed for final verification.

**Recommended disposition:** Keep FAR-RS422_L3REQ-6; verify by hardware serial test.

## AV-F-07 -- MEDIUM -- Stale host tooling register and opcode constants

**Requirement/ICD claim:** Host scripts claim register IDs and bootloader opcodes that do not match firmware headers.

**Code behavior:** `bash/camera_capture.sh` uses network register IDs 42..51 and `NOOP_REG=62`, while the firmware uses IDs 37..46 (`bash/camera_capture.sh:70-83`, `Camera/include/register.h:60-71`). `scripts/SerialTest.py` has stale network/NOOP IDs (`scripts/SerialTest.py:56-69`). `Bootloader/bootloader.py` uses update opcodes 43..45, while the source enum uses 76..78 (`Bootloader/bootloader.py:51-54`, `Bootloader/include/command.h:68-72`).

**Consequence:** Ground tests using these scripts can write the wrong registers or fail to enter update flows.

**Recommended disposition:** Fix tooling to import or generate constants from firmware headers.

## AV-F-08 -- HIGH -- GET_METADATA frame-index stack overwrite

**Requirement/ICD claim:** The metadata command should retrieve metadata for a requested image frame.

**Code behavior:** `GET_METADATA` declares `uint16_t u32_Frame_Index` and then copies four bytes into it (`Camera/src/command.c:335-339`).

**Consequence:** The command can corrupt adjacent stack data and can truncate frame indexes.

**Recommended disposition:** Fix the firmware local type to `uint32_t` or copy only two bytes with a deliberate interface definition.

## AV-F-09 -- MEDIUM -- Transfer invalid-count error is unreachable

**Requirement/ICD claim:** The Camera error list defines `ERR_XFER_INVALID_NUM` for an invalid frame count (`Camera/include/errors.h:28-32`).

**Code behavior:** `u8_Check_Frame_Bounds()` checks `starting_index >= TOTAL` before `starting_index > TOTAL`, making the invalid-number branch unreachable; it also permits zero frame count (`Camera/src/command.c:609-623`).

**Consequence:** A zero-frame transfer can be accepted, and one enumerated error cannot be verified.

**Recommended disposition:** Fix the bounds helper to validate `n_frames` as 1..remaining capacity or remove the stale error.

## AV-F-10 -- HIGH -- GET_CAMERA_TEMP mode guard is always true

**Requirement/ICD claim:** Temperature reads are expected to be mode-limited in related register behavior.

**Code behavior:** `GET_CAMERA_TEMP` uses `if( u8_Current_Camera_State == CAMERA_ARMED_STATE | CAMERA_BUSY_STATE )`; C precedence makes this expression true for all practical states, so the error branch is unreachable (`Camera/src/command.c:473-485`).

**Consequence:** The command may read the camera over SPI while unpowered or in an unintended state.

**Recommended disposition:** Fix the condition to a bitmask test such as `(state & (CAMERA_ARMED_STATE | CAMERA_BUSY_STATE)) != 0` and decide whether Transfer should be allowed.

## AV-F-11 -- MEDIUM -- Image-height mismatch across firmware and host tools

**Requirement/ICD claim:** The image interface should have one authoritative frame geometry.

**Code behavior:** Firmware configures `LINES_PER_FRAME=4581` (`Camera/include/camera.h:124-129`), and `utils/receiver.py` also uses 4581 lines (`utils/receiver.py:23-29`), but `utils/converter.py` uses 4577 lines (`utils/converter.py:11-13`).

**Consequence:** Converted images can be cropped, misaligned, or interpreted with the wrong byte count.

**Recommended disposition:** Choose the authoritative height and update the inconsistent tool or document separate raw/cropped products.

## AV-F-12 -- HIGH -- Nonvolatile register persistence is not implemented

**Requirement/ICD claim:** FAR-TMTC_SW_L4REQ-42, FAR-TMTC_SW_L4REQ-36, FAR-TMTC_SW_L4REQ-37, and FAR-TMTC_SW_L4REQ-38 require nonvolatile register loading, backup, and update persistence (`reqs_list.txt:107-107`, `reqs_list.txt:123-126`, `reqs_list.txt:188-188`).

**Code behavior:** The register table initializes hard-coded defaults in RAM and successful writes update RAM only (`Camera/src/register.c:44-116`, `Camera/src/register.c:226-247`). Network updates configure hardware but do not persist to flash (`Camera/src/command.c:415-417`).

**Consequence:** Power cycling or register reset loses user configuration despite system persistence requirements.

**Recommended disposition:** Reword requirements for SV scope if persistence is not required, or implement flash-backed register storage.

## AV-F-13 -- HIGH -- Telemetry and event logging commands are stubs

**Requirement/ICD claim:** FAR-TMTC_SW_L4REQ-35, FAR-TMTC_SW_L4REQ-30, and FAR-TMTC_SW_L4REQ-26 require historical telemetry or event logging (`reqs_list.txt:100-100`, `reqs_list.txt:124-127`).

**Code behavior:** `CONF_EVENT_LOG_SYS_CMD`, `EN_TL_CHAN_LOG_SYS_CMD`, and `XFER_LOG_SYS_CMD` have empty command cases returning success (`Camera/src/command.c:361-368`).

**Consequence:** The system can acknowledge logging commands without recording or returning logs.

**Recommended disposition:** Implement logging, remove/stub-gate opcodes with an error, or reword requirements as not in scope.

## AV-F-14 -- MEDIUM -- Gateway and subnet-mask requirements lack registers

**Requirement/ICD claim:** FAR-EDT_L3REQ-9 and FAR-EDT_L3REQ-8 require gateway and subnet mask parameters (`reqs_list.txt:186-187`).

**Code behavior:** The implemented communication registers include source/destination MAC, source/destination IP, and source/destination ports only (`Camera/include/register.h:60-67`, `Camera/src/register.c:98-110`).

**Consequence:** Network configuration verification against gateway/subnet parameters cannot be performed on current firmware.

**Recommended disposition:** Reword requirements for raw Ethernet/UDP endpoint configuration or add registers if routing is required.

## AV-F-15 -- HIGH -- Transfer cancellation and streaming are unsupported

**Requirement/ICD claim:** FAR-TMTC_SW_L4REQ-22 and FAR-TMTC_SW_L4REQ-21 require cancellation; FAR-L1REQ-11/FAR-TMTC_SW_L4REQ-11/FAR-TMTC_SW_L4REQ-1 require streaming behavior (`reqs_list.txt:141-153`, `reqs_list.txt:213-217`).

**Code behavior:** `STOP_ACQ_SYS_CMD` is a no-op (`Camera/src/command.c:294-295`), transfer state handles only entry, completion, timeout, and default (`Camera/src/CameraStates/camera_transfer_state.c:49-100`), and no Streaming state exists (`Camera/include/camera_states.h:15-27`).

**Consequence:** Long transfers or acquisitions cannot be cancelled by command, and streaming requirements are unmet.

**Recommended disposition:** Reword for finite buffered transfers or implement cancel/stream commands.

## AV-F-16 -- HIGH -- Direct non-buffered image transfer is unsupported

**Requirement/ICD claim:** FAR-CDH_FPGA_L3REQ-11 and FAR-CDH_FPGA_L3REQ-25 require direct transfer from sensor when frame buffer is disabled (`reqs_list.txt:91-102`).

**Code behavior:** All image transfer code reads frame indexes from DDR4-backed UDP DMA control blocks (`Camera/src/command.c:309-333`, `Camera/src/CameraStates/camera_transfer_state.c:103-124`).

**Consequence:** The design cannot satisfy a non-buffered image-transfer verification.

**Recommended disposition:** Reword to buffered transfer only or implement a direct data path.

## AV-F-17 -- MEDIUM -- PPS lock check is hard-coded true

**Requirement/ICD claim:** PPS-trigger behavior relies on lock qualification.

**Code behavior:** Trigger configuration checks `b_PPS_Is_Locked()`, but that function always returns 1 (`Camera/src/CameraStates/camera_armed_state.c:193-205`, `Camera/src/pps.c:41-44`).

**Consequence:** PPS-trigger captures can be armed without a real lock indication.

**Recommended disposition:** Connect the function to hardware lock status or document that no lock detector exists.

## AV-F-18 -- MEDIUM -- Capture start delay register has no effect

**Requirement/ICD claim:** FAR-TMTC_SW_L4REQ-9 describes a configurable countdown/delay trigger behavior (`reqs_list.txt:153-153`).

**Code behavior:** `CAP_START_DLY_USEC_SYS_REG` accepts all values, but trigger configuration reads only exposure, frame count, frame period, trigger mode, capture seconds, and capture milliseconds (`Camera/src/register_callbacks.c:254-257`, `Camera/src/CameraStates/camera_armed_state.c:124-129`, `Camera/src/CameraStates/camera_armed_state.c:240-246`).

**Consequence:** Users can write a delay value that never changes acquisition timing.

**Recommended disposition:** Remove the register/requirement or wire it to trigger hardware.

## AV-F-19 -- MEDIUM -- Focus status registers return undefined values

**Requirement/ICD claim:** Focus telemetry registers should report requested and computed focus distance.

**Code behavior:** `Get_Requested_Focus_Distance()` and `Get_Computed_Focus_Distance()` return `NO_ERROR` without writing the output pointer (`Camera/src/register_callbacks.c:50-62`).

**Consequence:** Register reads can return stale caller-initialized data while claiming success.

**Recommended disposition:** Implement the callbacks or mark the registers unimplemented.

## AV-F-20 -- MEDIUM -- Flash wait loops can hang forever

**Requirement/ICD claim:** Nonvolatile memory management should fail deterministically.

**Code behavior:** `v_Wait_For_Write_Enable()` and `v_Wait_For_Not_Busy()` poll status in unbounded loops (`Bootloader/src/flash.c:186-201`).

**Consequence:** A flash fault can permanently hang bootloader or application command processing.

**Recommended disposition:** Add timeout/error reporting or document a hardware-level guarantee.

## AV-F-21 -- MEDIUM -- Flash sector-base helper formulas are internally inconsistent

**Requirement/ICD claim:** Flash geometry helpers should compute sector base addresses.

**Code behavior:** The 64K and 32K helpers multiply base address by sector by size, and the 8K helper multiplies by base zero (`Bootloader/src/flash.c:203-219`).

**Consequence:** Any caller would compute invalid flash addresses; current update flow mostly accepts raw addresses so the defect may be latent.

**Recommended disposition:** Fix helper formulas before use or remove unused helpers.

## AV-F-22 -- LOW -- Bootloader timeout wording differs from ICD

**Requirement/ICD claim:** The ICD describes an approximately 8 second bootloader timeout.

**Code behavior:** The bootloader code defines a 10 second timeout and also delays 2 seconds plus 5 seconds before entering the timed loop (`Bootloader/src/main.c:21-23`, `Bootloader/src/main.c:56-100`, `../docs/icd/CM-01979_ICD_FLIGHT_SOFTWARE_FARSIGHT.md:632-638`).

**Consequence:** Operators may expect a shorter update-entry window than the firmware provides.

**Recommended disposition:** Reword ICD/requirements to the implemented timing or change boot sequence timing.

## AV-F-23 -- LOW -- SENSOR_TEMP_KEL_SYS_REG units are ambiguous

**Requirement/ICD claim:** The register name implies Kelvin temperature.

**Code behavior:** The read callback computes `(raw - 51.784) / 1.3125` without a Kelvin offset (`Camera/src/register_callbacks.c:71-87`).

**Consequence:** Verification cannot determine whether Celsius, Kelvin, or raw-derived units are expected.

**Recommended disposition:** Rename/reword units or correct the conversion.

## Disposition gate

The following items must not be auto-corrected because they are capability conflicts or real firmware defects requiring a named owner:
- AV-F-01 (HIGH) -- FAR-TMTC_SW_L4REQ-5/FAR-FPA_L5REQ-1 exposure maximum conflict
- AV-F-02 (HIGH) -- FAR-TMTC_SW_L4REQ-6 exposure-zero behavior is stale
- AV-F-03 (HIGH) -- Manual Imaging Mode and Streaming Mode requirements are stale
- AV-F-04 (HIGH) -- Update Mode TMTC disable conflicts with bootloader design
- AV-F-05 (HIGH) -- Exposure 100 ns start/stop requirements are not demonstrated by firmware
- AV-F-08 (HIGH) -- GET_METADATA frame-index stack overwrite
- AV-F-09 (MEDIUM) -- Transfer invalid-count error is unreachable
- AV-F-10 (HIGH) -- GET_CAMERA_TEMP mode guard is always true
- AV-F-12 (HIGH) -- Nonvolatile register persistence is not implemented
- AV-F-13 (HIGH) -- Telemetry and event logging commands are stubs
- AV-F-15 (HIGH) -- Transfer cancellation and streaming are unsupported
- AV-F-16 (HIGH) -- Direct non-buffered image transfer is unsupported
- AV-F-17 (MEDIUM) -- PPS lock check is hard-coded true
- AV-F-18 (MEDIUM) -- Capture start delay register has no effect
- AV-F-19 (MEDIUM) -- Focus status registers return undefined values
- AV-F-20 (MEDIUM) -- Flash wait loops can hang forever
- AV-F-21 (MEDIUM) -- Flash sector-base helper formulas are internally inconsistent
