# PolarFire FPGA Requirements Findings

Findings are ordered by priority and compare the Flow baseline plus design documents against the as-built RTL, constraints, and Libero SmartDesign integration.

## PF-F-01 -- HIGH

- **Claim:** `FAR-CDH_FPGA_L3REQ-11` requires the system to support non-buffered direct transfer of image data.
- **Actual RTL/design:** The as-built image path stores camera frames in DDR4 before export: the camera mux generates DDR4 valid signals, DMA write issues AXI writes, and frame export reads chunks from DDR4.
- **Evidence:** `ip/cam_mux_ip/src/cam_mux.sv:116-151`; `ip/dma_write_ip/src/dma_write_send_ctrl.sv:264-284`; `ip/dma_read_ctrl_ip/src/frame_xfer_ctrl.sv:328-358`
- **Consequence:** A direct sensor-to-egress mode is not evidenced; latency and memory-use assumptions in Flow are invalid for the FPGA.
- **Recommended disposition:** Human decision: reword `FAR-CDH_FPGA_L3REQ-11`/`FAR-CDH_FPGA_L3REQ-25` for buffered FPGA operation or add a new direct-streaming design feature.
- **Update (2026-10-02):** Both are now traced, by owner decision, to requirements that fail rather than left untraced: `PF-SYS-02` (direct transfer with the frame buffer disabled) and `PF-SYS-03` (at the fastest export interface's rate), both `GAP`, verified by the data-path trace that finds no path around DDR4 (`verification/analysis/test_ana_trace.py`).

## PF-F-02 -- HIGH

- **Claim:** `FAR-EDT_L3REQ-13` requires redundant Gigabit Ethernet connectivity and `FAR-EDT_L3REQ-3` requires TMTC over each Ethernet interface.
- **Actual RTL/design:** ETH2 top-level control/reset/MDC outputs are tied low; only ETH2 power enable/status reach housekeeper logic.
- **Evidence:** `bd/mpf500ts-fc1152m/top/components/top.tcl:231-234`; `bd/mpf500ts-fc1152m/top/components/top.tcl:731-732`
- **Consequence:** ETH2 is not a redundant communications path in the current FPGA build.
- **Recommended disposition:** Human decision: change the design to implement ETH2 or reword or withdraw the redundancy and TMTC requirements.

## PF-F-03 -- HIGH

- **Claim:** `docs/design/pf-fpga-eth-mac.md` says the board includes two Ethernet interfaces and the FPGA provides MAC functionality for PHY interfacing.
- **Actual RTL/design:** The SmartDesign ties ETH2 MAC control outputs low and does not instantiate an ETH2 MAC data path equivalent to ETH1.
- **Evidence:** `docs/design/pf-fpga-eth-mac.md:20`; `bd/mpf500ts-fc1152m/top/components/top.tcl:231-234`
- **Consequence:** The design documentation overstates implemented Ethernet capability.
- **Recommended disposition:** Reword the design documentation unless ETH2 is implemented.

## PF-F-04 -- HIGH

- **Claim:** `FAR-SERDES_L3REQ-2` requires two separate PCIe interfaces and the architecture documentation lists two PCIe endpoints/root ports.
- **Actual RTL/design:** The as-built PCIe custom logic provides a single read-oriented PCIe translator path that rejects write functionality.
- **Evidence:** `docs/design/pf-fpga-architecture.md:30`; `ip/eth_pcie_mux_ip/src/pcie_translator.sv:175-191`
- **Consequence:** Host-interface redundancy or topology requirements cannot be verified from this build.
- **Recommended disposition:** Human decision: identify the intended PCIe topology owner and either update the top-level integration or reword the parent requirement.

## PF-F-05 -- HIGH

- **Claim:** `FAR-L1REQ-20`/`FAR-AB_L2REQ-1` require internal temperature monitoring and thermal-protection action.
- **Actual RTL/design:** The custom junction-temperature IP continuously enables TVS and latches channel 3, but no custom RTL threshold compare or protective action was found.
- **Evidence:** `ip/junc_temp_ip/src/junc_temp.sv:42-52`; `ip/junc_temp_ip/src/junc_temp_apb_reg.sv:50-58`
- **Consequence:** FPGA telemetry can report temperature, but automatic over-temperature mitigation is not implemented in the reviewed gateware.
- **Recommended disposition:** Human decision: allocate thermal-limit enforcement to software/housekeeper or add FPGA trip logic.

## PF-F-06 -- HIGH

- **Claim:** `FAR-TMTC_SW_L4REQ-9` calls for a countdown timer that begins when the FPA transitions to Exposure Trigger Mode.
- **Actual RTL/design:** The trigger top selects manual, scheduler, or LVDS start sources; the scheduler path compares against RTC seconds/milliseconds rather than implementing a mode-transition countdown timer.
- **Evidence:** `ip/cam_trig_ip/src/cam_trig_top.sv:130-160`; `ip/cam_trig_ip/src/cam_trig_apb_reg.sv:207-224`
- **Consequence:** Test procedures based on countdown semantics will not match the RTL.
- **Recommended disposition:** Human decision: reword `FAR-TMTC_SW_L4REQ-9` to absolute-time scheduled triggering or add countdown semantics.

## PF-F-07 -- MEDIUM

- **Claim:** `docs/design/pf-fpga-camera-control.md` says all camera timing parameters are microseconds and `XTRIG_LOW_TIME` is a 15-bit microsecond field.
- **Actual RTL/design:** The RTL declares `xtrig_low_time` as 28 bits and uses it directly as clock cycles.
- **Evidence:** `docs/design/pf-fpga-camera-control.md:135`; `docs/design/pf-fpga-camera-control.md:162`; `ip/cam_trig_ip/src/cam_trig_apb_reg.sv:35`; `ip/cam_trig_ip/src/cam_trig.sv:84`
- **Consequence:** Exposure-trigger low-pulse programming is unit-inconsistent between documentation and hardware.
- **Recommended disposition:** Reword the documentation and parent verification cases to use clock cycles, or change the RTL register conversion.

## PF-F-08 -- MEDIUM

- **Claim:** `FAR-CDH_FPGA_L3REQ-14`/`FAR-CDH_FPGA_L3REQ-17`/`FAR-CDH_FPGA_L3REQ-19`/`FAR-CDH_FPGA_L3REQ-18` require precise external exposure timing knowledge/control.
- **Actual RTL/design:** The trigger path uses APB-configured counters and synchronized external sources, but no design artifact proves the 100 ns exposure-timing accuracy budget end to end.
- **Evidence:** `ip/cam_trig_ip/src/cam_trig.sv:84-85`; `ip/cam_trig_ip/src/cam_trig_top.sv:130-160`; `ip/pps_ip/src/pps.sv:258-266`
- **Consequence:** Timing-accuracy claims require analysis or hardware characterization beyond static RTL inspection.
- **Recommended disposition:** Reword requirements with FPGA-clock-domain quantization and add timing-analysis/HW verification.

## PF-F-09 -- MEDIUM

- **Claim:** UDP design documentation states the default 1000-cycle frame gap is 10 us and also says CoreTSE requires approximately 20 us.
- **Actual RTL/design:** The RTL defaults to 1000 cycles at 100 MHz when the APB frame-gap register is zero.
- **Evidence:** `docs/design/pf-fpga-udp.md:152`; `ip/udp_ip/src/udp_tx.sv:265`; `ip/udp_ip/src/udp_tx.sv:381-389`; `ip/udp_ip/src/udp_tx.sv:574-580`
- **Consequence:** Default operation may violate the documented MAC reliability gap.
- **Recommended disposition:** Change the default to at least 2000 cycles or document why 1000 cycles is acceptable.

## PF-F-10 -- MEDIUM

- **Claim:** `FAR-TMTC_SW_L4REQ-24`/`FAR-L1REQ-19`/`FAR-L1REQ-21` imply error reporting for invalid or failed commanded behavior.
- **Actual RTL/design:** Several APB slaves return dummy data or no error while holding `pslverr` low on invalid accesses.
- **Evidence:** `ip/dma_read_ctrl_ip/src/dma_read_ctrl_apb_reg.sv:122`; `ip/dma_read_ctrl_ip/src/dma_read_ctrl_apb_reg.sv:225-226`; `ip/image_metadata_ip/src/image_metadata_apb_reg.sv:407-410`; `ip/pps_ip/src/pps.sv:334-337`
- **Consequence:** Bus masters cannot reliably distinguish invalid register accesses from valid dummy reads.
- **Recommended disposition:** Human decision: define common APB error semantics; then update RTL or accept dummy-read behavior with rationale.
- **Simulation (2026-10-01):** `verification/tests/test_pf_apb.py` ran an unmapped read, an unmapped write and a read above the decode window on all twelve of the design's APB slaves, and on CoreGPIO. None raised `pslverr`. Unmapped reads returned 0, or `0xDEADBEEF` from `image_metadata_apb_reg` and `pps`. Reads above the window returned the register they alias: every block decodes only `paddr[6:2]` or similar, so each register appears again every 128 bytes (64 for `pps`, 256 for `dma_read_ctrl_apb_reg`). CoreGPIO ties `PSLVERR` to 0, so the vendor cores do no better. The behaviour is uniform, but uniformly silent.

## PF-F-11 -- MEDIUM

- **Claim:** DMA-read/UDP documentation omits metadata-mode and frame-read-done interrupt registers.
- **Actual RTL/design:** The APB register file implements `UDP_METADATA_SEL`, `FRAME_READ_DONE_INT`, and 20 metadata data registers at word indices 16..37.
- **Evidence:** `ip/dma_read_ctrl_ip/src/dma_read_ctrl_apb_reg.sv:75-78`; `ip/dma_read_ctrl_ip/src/dma_read_ctrl_apb_reg.sv:301-312`; `ip/dma_read_ctrl_ip/src/dma_read_ctrl_apb_reg.sv:356-392`
- **Consequence:** Software and verification teams may miss implemented control/status behavior.
- **Recommended disposition:** Update design documentation and Flow-derived low-level requirements.

## PF-F-12 -- MEDIUM

- **Claim:** Image metadata comments and testbench labels describe sensor bit depth as read-only/fixed.
- **Actual RTL/design:** The APB register file writes `ADDR_SENSOR_BIT_DEPTH_REG` with `pwdata` and reads it back from memory.
- **Evidence:** `ip/image_metadata_ip/src/image_metadata_apb_reg.sv:88`; `ip/image_metadata_ip/src/image_metadata_apb_reg.sv:285-286`; `ip/image_metadata_ip/src/image_metadata_apb_reg.sv:343-344`
- **Consequence:** Metadata bit-depth behavior is ambiguous for software and verification.
- **Recommended disposition:** Decide whether sensor bit depth is configurable; update RTL or comments/tests accordingly.

## PF-F-13 -- MEDIUM

- **Claim:** The top-level constraints classify `lvdt_gain_switch` as an input pin.
- **Actual RTL/design:** The timing constraints treat `lvdt_gain_switch` as an output port driven from the 50 MHz domain.
- **Evidence:** `constr/common/pins.tcl:185`; `constr/mpf500ts-fc1152m/sdc/timing_user_constraints.sdc:195`
- **Consequence:** Board-level direction and timing intent disagree for the LVDT gain-control signal.
- **Recommended disposition:** Human decision: confirm schematic direction and correct either PDC or SDC/top-level port direction.

## PF-F-14 -- LOW

- **Claim:** Heartbeat output intent is unclear because the direct heartbeat instance output is marked unused.
- **Actual RTL/design:** The design still has an external heartbeat pin assignment and debug/heartbeat observable paths.
- **Evidence:** `bd/mpf500ts-fc1152m/top/components/top.tcl:315`; `constr/common/pins.tcl:298`; `ip/hbeat_runner/src/hbeat_runner.sv:1-24`
- **Consequence:** It is unclear which heartbeat net is intended for flight observability.
- **Recommended disposition:** Reword documentation and remove unused direct heartbeat logic if not used.

## PF-F-15 -- LOW

- **Claim:** `xcvr_disparity_correction` comments reference lane RX ready and older first-lock implementation names.
- **Actual RTL/design:** The module ports use lane valid/calibrating flags and the reset-control FSM uses the current internal calibration/valid naming.
- **Evidence:** `ip/xcvr_disparity_correction/src/xcvr_disparity_correction.v:16-48`; `ip/xcvr_disparity_correction/src/xcvr_disparity_correction.v:524-615`
- **Consequence:** Comments can mislead verification authors about the intended lane-readiness predicate.
- **Recommended disposition:** Update comments to match implemented ports and FSM behavior.

## PF-F-16 -- LOW

- **Claim:** The focus mechanism IP tree contains mixed target-part comments and generated-template text.
- **Actual RTL/design:** The active focus mechanism SmartDesign is integrated into the MPF500TS top hierarchy despite comments referencing other PolarFire devices.
- **Evidence:** `ip/focus_mech_ip/hw/ip/focus_mech_ip/components/focus_mech.tcl:1-20`; `bd/mpf500ts-fc1152m/top/components/top.tcl:817-899`
- **Consequence:** Generated comments reduce confidence in manual design review but do not by themselves prove functional error.
- **Recommended disposition:** Clean generated comments in documentation; do not change RTL behavior solely for this.

## PF-F-17 -- LOW

- **Claim:** The IMX531 detailed design document contains explicit `NEED-REQ` markers.
- **Actual RTL/design:** The FPGA design drives only the implemented camera control pins and does not close those sensor-document requirement gaps in RTL.
- **Evidence:** `docs/design/00-imx531-detailed-spec.md:308-309`; `docs/design/00-imx531-detailed-spec.md:476`; `bd/mpf500ts-fc1152m/top/components/top.tcl:559-585`
- **Consequence:** Sensor-control requirements are incomplete for downstream verification planning.
- **Recommended disposition:** Create Flow requirements for the marked sensor pin states or document why they are outside FPGA scope.

## PF-F-18 -- LOW

- **Claim:** Vendor-core behaviors such as CoreGPIO, CorePWM, CoreTSE, DDR4, PCIe, and SLVS-EC are used by integration Tcl but are not defined in custom RTL.
- **Actual RTL/design:** The custom IP requirements can cite wrappers and interconnect, but vendor IP register/latency/error behavior must come from vendor documentation or generated core settings.
- **Evidence:** `bd/mpf500ts-fc1152m/top/components/top.tcl:847-899`; `synth.tcl:180-319`
- **Consequence:** Some low-level verification requirements remain unverifiable from custom RTL alone.
- **Recommended disposition:** Add vendor-core evidence packages or mark those checks as vendor-IP assumptions.


## PF-F-19 -- MEDIUM

- **Claim:** `PF-PPS-07` requires the local PPS generator to produce a 1 Hz pulse at 50 % duty cycle. `FAR-TMTC_SW_L4REQ-49` requires telemetry that correlates with image captures.
- **Actual RTL/design:** `pps_generator.sv` toggles on a fixed count of exactly 25,000,000 cycles, so the output period is exactly 50,000,000 clock cycles and its accuracy equals the board oscillator's accuracy one for one. No accuracy, stability or drift figure is stated in any requirement.
- **Evidence:** `ip/pps_ip/src/pps_generator.sv:25`, `ip/pps_ip/src/pps_generator.sv:37-48`
- **Consequence:** The payload's fallback time source has undefined accuracy. At a typical uncompensated +/-100 ppm the local PPS errs by +/-100 us/s, accumulating to roughly +/-0.5 s per 90-minute orbit and +/-8.6 s per day free-running. Image time-correlation accuracy is therefore unbounded whenever external PPS is unavailable, and FAR-TMTC_SW_L4REQ-49 states no accuracy against which to judge it.
- **Related:** Six clock domains on this board are each driven by two alternative oscillator part numbers on one net, with no stability specification recorded for either. See `HK-F-19` in the housekeeper findings for the full table.
- **Recommended disposition:** State the required time-correlation accuracy on FAR-TMTC_SW_L4REQ-49, budget the oscillator total error as initial tolerance plus temperature stability plus aging over life, and state the resulting local-PPS accuracy on `PF-PPS-09`. Take the budget against the worse of the two fitted alternatives until the stuff option is resolved.
- **Update (2026-10-02):** The budget now exists, read from the parts' datasheets (`verification/analysis/test_ana_clocks.py`). By owner decision the Xsis parts are the flight fit, over 5 years and -55 to +125 C (TBR): X35T-L7M (50 MHz) and XD35T-L7M (148.5 and 100 MHz) are each +/-75 ppm including 5-year aging, so the local PPS is +/-75 ppm, about +/-6.5 s per day free-running (`PF-PPS-09` now `OK`). The alternates are narrower-range commercial parts: ECS-3225MVQ-500-BP, +/-50 ppm plus 3 ppm a year, -40 to +105 C; Renesas XLL536, +/-25 ppm including aging over an unstated life, -40 to +85 C. Fitting either would take that net outside the operating range. The required time-correlation accuracy (Q-06) is still open.


## PF-F-20 -- HIGH

- **Claim:** `FAR-FB_L3REQ-4` requires the frame buffer to have "a read speed at least as fast as the highest speed data transfer interface to the bus" and `FAR-FB_L3REQ-1` requires "a write speed at least as fast as frames are transferred from the FPA". Twenty PolarFire requirements cite one or both as a parent.
- **Actual RTL/design:** **No requirement in the PolarFire set states a data rate.** Of the twenty requirements claiming to decompose FAR-FB_L3REQ-4 or FAR-FB_L3REQ-1, none constrains throughput: they cover mux routing, timeout flags, packet framing, sequence numbering and metadata block size. Searching the requirement set for `throughput`, `bandwidth`, `sustain`, `Gbps`, `Mbit` or `FPS` returns nothing.
- **Evidence:** `ip/dma_write_ip/src/dma_write_send_ctrl.sv`; `ip/dma_read_ctrl_ip/src/frame_xfer_ctrl.sv`; requirement set `pf-fpga-requirements.md`
- **Consequence:** The two requirements that came closest -- `PF-DMAW-08` and `PF-DMAR-15`, each requiring bursts of no more than 256 AXI beats -- were acting as proxies for throughput while not actually constraining it. 256 beats is the AXI4 protocol maximum, so both restated a bus limit rather than a FARSIGHT need. The traceability table showed FAR-FB_L3REQ-4 and FAR-FB_L3REQ-1 as covered when the property they care about was unconstrained.
- **Related:** The two DDR4 banks have different data bus widths, 64-bit and 32-bit, so read and write margins differ per bank and neither FAR-FB_L3REQ-4 nor FAR-FB_L3REQ-1 says which bank it applies to. See `HW-F-05`.
- **Recommended disposition:** Human decision. Set the required rates -- the sensor output rate for write, and the intended egress interface for read -- then verify by analysis. Opened as `PF-DMAW-10` and `PF-DMAR-24`, both `GAP` and both TBR on the rate. `PF-DMAW-08` and `PF-DMAR-15` are withdrawn.


## PF-F-21 -- MEDIUM

- **Claim:** `PF-VER-01` required the hardware-version registers to expose build version, git hash **and build time**. `FAR-AB_L2REQ-6`/`FAR-CDH_FPGA_L3REQ-21` require version information to be reported on request.
- **Actual RTL/design:** `synth.tcl` generates `hw_version_apb_reg.sv` from a template on every build, substituting wall-clock UTC seconds into `BUILD_TIME_UTC_SEC`, a `localparam` in synthesised RTL. The generated file currently reads `32'd1788304854`.
- **Evidence:** `synth.tcl:162-175`; `ip/hw_version_ip/template/hw_version_apb_reg.sv.template:51`; `ip/hw_version_ip/src/hw_version_apb_reg.sv:51`
- **Consequence:** **The programming file is not reproducible.** Two builds from identical source, with the same toolchain and configuration, differ -- because a constant inside the design changed. That removes the ability to confirm bit-for-bit that the image about to be flown is the image that was verified, and it means any diff between two programming files is uninformative: a timestamp difference is indistinguishable from a design change.
- **Assessment:** The timestamp also adds nothing that the commit identifier does not already provide. A git hash identifies the source exactly; a build time only says when the tools were run, which is a property of the build event rather than of the image. It belongs in the retained build artefact (clause 1 of the [FPGA Build and Disposition Plan](../../../docs/plans/fpga-build-and-disposition-plan.md)), where it is recorded without altering what is synthesised.
- **Counter-argument considered:** A timestamp can distinguish two builds from the same commit -- for example a rebuild under a different tool version. That is a real need, but a timestamp is the wrong answer to it: the tool version should be captured in the build artefact, and any deliberate build identifier should be an input to the build rather than a side effect of when it ran.
- **Note:** The generated file is correctly excluded from source control (`.gitignore:35`), so it does not produce spurious repository diffs. The defect is confined to the bitstream.
- **Minor observation:** `BUILD_TIME_UTC_SEC` is declared `integer`, which is signed 32-bit, so the field misreports after 2038-01-19. That is outside the mission life and cosmetic given the field is read-only, but it is another argument against carrying wall-clock time in the design.
- **Recommended disposition:** Remove the build timestamp from the version register bank and from `synth.tcl`. Retain build version and commit identifier. Opened as `PF-VER-02`.

## PF-F-22 -- MEDIUM

- **Claim:** `PF-PCIE-07`, `PF-PCIE-08` and `PF-PCIE-09` specify the PCIe image-export path and are all adjudicated `OK`. `PF-PCIE-07` routes reads "under firmware or host selection control". CM-01979 describes PCIe as the "primary data transfer" interface (`docs/icd/CM-01979_ICD_FLIGHT_SOFTWARE_FARSIGHT.md:498`) and lists it as an egress option in the Transfer state (`:583`).
- **Actual RTL/design:** The FPGA side is present and correct. **No FARSIGHT-side software configures it.** `farsight-avionics-sw/Camera/src/camera.c:258` initialises the `eth_pcie_mux` GPIO instance and no write to `ETH_PCIE_SEL` follows anywhere in the flight build; `GPIO_init` clears the port, so the line sits at its reset value, which routes egress to Ethernet.
- **Evidence:** `farsight-avionics-sw/Camera/src/camera.c:258` (init, no subsequent write); `farsight-avionics-sw/Camera/include/gpio_pin_def.h:9` (`ETH_PCIE_SEL GPIO_0`, defined and unused); no occurrence of `ETH_PCIE_SEL` or `eth_pcie_mux` in `farsight-avionics-sw/Bootloader/`; `farsight-avionics-sw/Camera/src/command.c:227-231` -- `REG_WRITE_SYS_CMD` indexes a TMTC register table with no PCIe entry.
- **Programme position (2026-09-17):** PCIe **is flight functionality**. The intent is that it is enabled later, in **payload software**, and explicitly **not** in PolarFire firmware. This finding is therefore *not* a descope question and *not* a defect in the FPGA design. It records a **cross-boundary obligation that no artefact currently carries**.
- **Consequence:** The obligation to enable PCIe egress is allocated to a team outside this requirement set, and nothing in the set says so. That is the failure mode the [derived register](../../../docs/requirements/derived-register.md) exists to prevent -- an obligation handed to someone else at design time and rediscovered later as a finding. Until it is recorded, `PF-PCIE-07`/`-08`/`-09` read as satisfied flight capability while no software exercises them.
- **The control split is the substantive issue.** "Payload software owns PCIe" is not sufficient on its own, because the PCIe read path is not fully host-driven. Three controls select what a PCIe read returns, and only one of them is reachable from the host:
  - `s_araddr[24:0]` -- offset within the 32 MB frame slot. **Host-supplied** over PCIe (`ip/eth_pcie_mux_ip/src/pcie_translator.sv:194`).
  - `index` -- the DDR4 frame index. An **input port to the translator**, driven from the FARSIGHT side, not from the PCIe address (`ip/eth_pcie_mux_ip/src/pcie_translator.sv:33`, `:194`).
  - `ddr4_sel` -- which bank, 8 GB or 16 GB. A **register written over the block's AXI slave**, not a PCIe-visible control (`ip/eth_pcie_mux_ip/src/axi_read_demux.sv:13`, `:162`).
  - `ETH_PCIE_SEL` -- egress routing. A **PolarFire GPIO**, which payload software cannot write directly.
- **Recommended disposition:** Record the obligation rather than close the finding. Specifically: (1) add a derived requirement carrying the payload-software obligation, with `Imposes on` naming payload software, and register it in the derived register; (2) decide and record which side sets `ETH_PCIE_SEL`, `index` and `ddr4_sel` when PCIe is the active egress -- if any of them must be set by PolarFire firmware, then the "not PFW" allocation needs qualifying and a PFW requirement follows; (3) fill CM-01979 section 22, which is a one-line stub reading "Details on PCIe data transfer will be included in future releases" (`:2554-2555`) -- payload software cannot implement against it as written, and it is the interface definition they will need.
- **Correction (2026-09-29):** Two of the four controls above are misdescribed. `index` and `ddr4_sel` are **host-written over PCIe**. Both are registers in `axi_read_demux`, set by writes to its AXI slave, and that slave is driven by the PCIe block's `AXI_0_MASTER` (`bd/mpf500ts-fc1152m/top/components/top.tcl:872`), which carries the host's BAR accesses: BAR0 (64 KB, AXI `0x0300_0000`) and BAR2 (32 MB, AXI `0x1000_0000`) (`bd/mpf500ts-fc1152m/pcie_hier/components/PF_PCIE_C0.tcl:30-56`). A host write ending `0x0` sets the bank, one ending `0x8` the frame index (`ip/eth_pcie_mux_ip/src/axi_read_demux.sv:159-166`); the translator's `index` port is wired from that register, not from the FARSIGHT side. `verification/tests/test_pf_pcie.py` shows it: host writes through that port selected each bank and frame, and every read then came from them. So of the four, only `ETH_PCIE_SEL` is outside the host's reach, and point (2) of the disposition reduces to deciding who sets it. How the demux decodes these writes is `PF-F-30`.
- **Note:** Downgraded from HIGH to MEDIUM on 2026-09-17. It was raised as a capability conflict on the reading that PCIe might not be flown. That reading was wrong: the corrected baseline `KEEP`s `FAR-SERDES_L3REQ-2` and `-3`, the hard block is instantiated, bespoke RTL exists, and the programme confirms PCIe is flight. The remaining issue is unrecorded allocation, not missing capability.

## PF-F-23 -- LOW

- **Claim:** `PF-PPS-02` requires the PPS discipline logic to ignore external PPS periods outside the accepted tolerance window, because "glitches or missed pulses must not corrupt mission time". `PF-PPS-04` requires a time-jam to load "on the next PPS edge".
- **Actual RTL/design:** The discipline logic applies the window correctly. The time-jam does not: an armed jam loads on **any** rising edge at the discipline input, and the window test is never applied to it (`if(pps_in_posedge && set_time)`). A glitch, or an edge from switching the PPS source mux while its inputs differ, that arrives while a jam is armed sets mission time on a false second boundary.
- **Evidence:** `ip/pps_ip/src/pps.sv:209-215` (the jam: no window condition); `ip/pps_ip/src/pps.sv:124-127` (the window, applied only to the discipline). In simulation, `verification/tests/test_pf_pps_discipline.py` shows every out-of-window edge from a 10 us glitch to a 1.501 s period rejected by the discipline, and `verification/tests/test_pf_pps_jam_irq.py` shows the jam loading on the first rising edge after arming.
- **Consequence:** The exposure is bounded. It needs a false edge in the interval between firmware arming a jam and the next true PPS edge, which is at most about one second, so it is unlikely. But when it happens the corruption persists: `seconds` is loaded from `load_seconds` on the false boundary, and the design's second then runs from that point. The discipline loop pulls the phase back only gradually, and never corrects a wrong seconds value.
- **Why PF-PPS-02 is not failed on it:** `PF-PPS-02` is scoped to the *discipline* logic, which does ignore the edge. `PF-PPS-04` says "the next PPS edge" without saying the edge must be a valid one. Together the two requirements leave the jam's behaviour on an invalid edge unspecified, and the RTL follows `PF-PPS-04` literally.
- **Recommended disposition:** Human decision. Either gate the jam on the same window as the discipline (`pps.sv:209`), noting that a jam then cannot be taken from the first edge after a long outage, or accept the exposure and say so on `PF-PPS-04`. In either case, state on `PF-PPS-04` which edges a jam may load on.

## PF-F-24 -- MEDIUM

- **Claim:** `PF-FDIR-05` requires the camera fault detector to latch a power fault while capture is active and camera power is low. Its rationale is that "firmware needs a **distinct** indication that image acquisition failed because the camera rail was unavailable". `PF-FDIR-04` latches a timeout fault for a trigger with no frame.
- **Actual RTL/design:** Both latches exist, but firmware sees only their OR. The detector has one output, `fault = timeout_fault | pwr_fault`. The register block synchronises that one bit into `FAULT[0]`, and nothing else in the register map depends on which latch set it.
- **Evidence:** `ip/cam_fault_detector_ip/src/cam_fault_detector.sv:104-108` (the power latch) and `:123` (the OR); `ip/cam_fault_detector_ip/src/cam_fault_detector_apb_reg.sv:97` (the one bit); `ip/cam_fault_detector_ip/README.md` register map (`FAULT` = "timeout fault OR power fault"). In simulation, `verification/tests/test_pf_fdir.py::test_PF_FDIR_05_power_fault_latches` read all 32 decoded word addresses after a power fault and after a timeout, and got identical values: `FAULT = 1`, everything else 0.
- **Consequence:** Firmware cannot tell a camera that lost its rail from one that was powered and never answered a trigger. Those need different responses: one points at the power path and the housekeeper, the other at the camera or its link. `HW-PF-FDIR-05` expects a power fault "rather than a timeout" and cannot pass either.
- **Recommended disposition:** Human decision. Either expose the two latches as separate bits, keeping `FAULT[0]` as their OR so existing software still reads a summary, or reword the rationale of `PF-FDIR-05` if a common fault is enough and the distinction comes from the housekeeper's power telemetry instead.

## PF-F-25 -- HIGH

- **Claim:** `PF-FDIR-04`, `-05` and `-06` specify a camera fault detector whose report firmware acts on (`FAR-L1REQ-19`, `FAR-L1REQ-21`). The RTL meets all three at unit level.
- **Actual RTL/design:** Three things combine so that in the flight build the detector latches a spurious fault once and never reports a real one:
  1. **A spurious timeout at camera power-up.** `cam_trig` drives `xtrig` high in every state except `OFF` and the exposure low period. It leaves `OFF` when `en` rises, and `en` is the camera power-good (`cam_rx_hier` `cam_en` ← `hk_hier` `cam_spi_tribuff_en` = `cam_pwr_status`). So the first camera power-up after reset is an `xtrig` rising edge with no capture. No frame answers it, and the detector latches a timeout 1 ms later. Flight software knows: its comment reads "clear fault as XTRIG gets asserted in the process".
  2. **The clear is left asserted.** The register map says write 1 to clear and write 0 to re-arm. The RTL holds both latches clear for as long as `FAULT_CLEAR` reads 1, and it also stops the timeout counter. Flight software's `clear_fault()` writes 1 and nothing ever writes 0. So after the sensor first leaves standby, neither fault can latch again.
  3. **The report is never read.** `check_fault()` is defined and never called.
- **Evidence:** `ip/cam_trig_ip/src/cam_trig.sv:126` and `:181-184`; `bd/mpf500ts-fc1152m/cam_rx_hier/components/cam_rx_hier.tcl:390` (`cam_en` to `cam_trig`) and `:397` (`xtrig` to the detector); `bd/mpf500ts-fc1152m/top/components/top.tcl:557-558`; `bd/mpf500ts-fc1152m/hk_hier/components/hk_hier.tcl:161`; `ip/cam_fault_detector_ip/src/cam_fault_detector.sv:74-75` and `:104-105` (clear has priority, as a level). In `farsight-avionics-sw` at `e6e90180` (local `main`, 2026-08-27): `Camera/src/camera.c:849-858` (`check_fault()`, `clear_fault()`), `Camera/src/util.c:136-140` (the only call, and the comment). In simulation, `verification/tests/test_pf_fdir.py::test_characterise_flight_clear_leaves_detector_inert` shows point 1, and shows that with `FAULT_CLEAR` left at 1 an unanswered trigger and a rail dip during capture both leave `FAULT = 0`.
- **Consequence:** **The camera FDIR does nothing in flight.** A missing frame or a lost camera rail during acquisition goes unreported, and `PF-FDIR-04`/`-05`/`-06` read as met while nothing uses them. A simulation of the unit cannot show this; it takes the FPGA's wiring and the flight software together.
- **Related:** `cam_trig` never returns to `OFF`. After the camera rail drops, `xtrig` continues to be driven high, and pulsed on each capture, into an unpowered sensor. Whether that back-powers it is a board question for the camera interface.
- **Recommended disposition:** Human decision, across the FPGA/software boundary, like `PF-F-22`. In software: follow the clear with a write of 0, and read `FAULT` at the end of each capture. In the FPGA: consider making `FAULT_CLEAR` self-clearing, so a write of 1 can't leave the detector disabled, and consider not starting the timeout on the `OFF` → `IDLE` edge. Whichever is chosen, record the obligation on the software side where it is allocated.

## PF-F-26 -- HIGH

- **Claim:** `PF-TRIG-11` requires the trigger source selector to select manual, scheduled-PPS or synchronised-LVDS start "according to the ICD values". CM-01979 section 5.5.21, `TRIG_MODE_SYS_REG`, is the only ICD table that defines trigger-mode values: `COMMAND` 0 (a `START_ACQ_SYS_CMD`), `EXT_GPIO` 1 (a GPIO rising edge), `PARAM_UPDATE` 2 (an imaging-parameter write), `TIME` 3 (a configured delay after entering `MANUAL_MODE` or `STREAM_MODE`).
- **Actual RTL/design:** Three artefacts use three different numberings for the same register:
  - The **FPGA** decodes `XTRIG_SRC_SEL` as 0 manual, 1 scheduled against the PPS clock, 2 LVDS edge, 3 none.
  - **Flight software** numbers its `Trigger_Mode_t` `SW_TRIGGER` 0, `PPS_TRIGGER` 1, `EXT_TRIGGER` 2. It rejects values above 2 and writes the accepted value into `XTRIG_SRC_SEL` verbatim. Its comment says "the numbering is fixed by the FPGA and cannot be reassigned".
  - The **ICD** follows neither. It also defines `TIME` as a delay *relative* to a mode transition, whereas the FPGA's scheduler waits for an *absolute* PPS time.
- **Evidence:** `ip/cam_trig_ip/src/cam_trig_top.sv:153-163`; `farsight-avionics-sw` at `e6e90180`: `Camera/include/camera.h:24-35`, `Camera/src/register_callbacks.c:177-191`, `Camera/src/CameraStates/camera_armed_state.c:240-247`; CM-01979 revWIP section 5.5.21 (the PDF and the `docs/current` DOCX agree). In simulation, `verification/tests/test_pf_trig.py::test_PF_TRIG_11_source_select_icd_values` applied each ICD value with each of the three start stimuli: `COMMAND` started on `START` as specified, `EXT_GPIO` on the PPS schedule, `PARAM_UPDATE` on an LVDS edge, and `TIME` on nothing.
- **Consequence:** A host that commands trigger modes per the ICD gets a different acquisition trigger from the one it asked for:
  - **`EXT_GPIO`** selects the PPS scheduler. It fires at whatever time the scheduler registers hold, which flight software programs from its capture time regardless of mode, so at once if that time has passed. The external edge the host is waiting on is ignored.
  - **`PARAM_UPDATE`** arms the external trigger instead.
  - **`TIME`** is refused by software.

  Only `COMMAND` works as documented.
- **Recommended disposition:** Human decision, across the ICD, flight software and FPGA. The ICD is the host contract, so either correct CM-01979 section 5.5.21 to the numbering the design implements (and define `TIME` as the absolute PPS schedule), or have software translate the ICD values rather than pass them through. Cite the section on `PF-TRIG-11` once it is settled; it is cited there now as the table tested against.

## PF-F-27 -- MEDIUM

- **Claim:** `PF-TRIG-07` requires continuous acquisition when the requested frame count is zero, "for checkout and calibration". VC-PF-0033 reads that as a sequence that runs until another control input stops it.
- **Actual RTL/design:** A zero count runs continuously and **cannot be stopped**:
  - The FSM leaves `XTRIG_HIGH_PERIOD` only for `XTRIG_LOW_PERIOD` while the count is 0, and never returns to `OFF` from any state.
  - New settings, including `START`, are taken only in `IDLE`, which a continuous run never reaches.
  - `en` is used only to leave `OFF`.
  - The block's resets are the global 50 MHz system reset, shared with the processor and the rest of the fabric.
- **Evidence:** `ip/cam_trig_ip/src/cam_trig.sv:98`, `:181-216`; `ip/cam_trig_ip/src/cam_trig_apb_reg.sv:207-225`; `bd/mpf500ts-fc1152m/top/components/top.tcl:560`. In simulation, `verification/tests/test_pf_trig.py::test_PF_TRIG_07_zero_count_continuous` ran 100 triggers in 2 ms. The generator then kept triggering every 20 us after each of: `START` written 0, a frame count of 1, a source of none, an interrupt clear, and `en` low.
- **Consequence:** Continuous acquisition ends only with a fabric reset, and it keeps filling the frame buffer until the camera mux disables at 768 frames (`PF-MUX-09`). Flight software cannot enter the mode today: `IMG_PER_TRIGGER_SYS_REG` rejects values below 1 (`register_callbacks.c:195-200`), and `STOP_ACQ_SYS_CMD` is marked "@todo - is this going to be implemented?" (`command.c:294`). So the requirement describes a mode that neither software nor ground can use safely.
- **Related:** `cam_trig` also keeps triggering after camera power-good drops, for the same reason (`PF-F-25`).
- **Recommended disposition:** Human decision. Either add a stop to the trigger generator (for example, `START` written 0, or `en` low, returning it to `IDLE`/`OFF`) and implement `STOP_ACQ_SYS_CMD`, or withdraw `PF-TRIG-07` if unbounded acquisition is not needed.

## PF-F-28 -- MEDIUM

- **Claim:** `PF-DMAW-09` requires the write DMA to flag a stalled write within 10 ms +/-5%. The DMAs of both banks are configured for a 150 MHz DDR clock, and the design document gives both DDR4 interfaces a 600 MHz DDR clock and a 150 MHz user clock.
- **Actual RTL/design:** The two banks do not run at the same clock.
  - The 8GB bank's `PF_DDR4_C2` is configured `CLOCK_DDR:600.0`, `CLOCK_USER:150.0`.
  - The 16GB bank's `PF_DDR4_C0` is configured `CLOCK_DDR:550.0`, `CLOCK_USER:137.5`, and the build's derived constraints generate its user clock as 50 MHz x 11 / 4 = 137.5 MHz.
  - Every block on the 16GB user clock that counts time assumes 150 MHz: the write DMA (`CLOCK_FREQ_MHZ:150`) and the read DMA (`DDR4_CLOCK_FREQ_MHZ:150`). Both have `TIMEOUT_USEC:10000`.
- **Evidence:** `bd/mpf500ts-fc1152m/ddr4_16gb_hier/components/PF_DDR4_C0.tcl` and `ddr4_8gb_hier/components/PF_DDR4_C2.tcl` (`CLOCK_DDR`, `CLOCK_USER`); `constraint/top_derived_constraints.sdc:48-55` in build `20260923_124832_3a5321f5`; `bd/mpf500ts-fc1152m/ddr4_16gb_hier/components/dma_write_ddr4_16gb_hier.tcl:68-70`, `dma_read_ddr4_16gb_hier.tcl:106-111`; `docs/design/pf-fpga-ddr4-mig.md:24-29`. In simulation, `verification/tests/test_pf_dmaw.py` measured the 16GB write DMA flagging a stall 1,500,000 clocks, **10.909 ms**, after it began, against 10.000 ms on the 8GB bank.
- **Consequence:**
  - **Write DMA:** the 16GB bank's stall flag comes at 10.909 ms, outside `PF-DMAW-09`'s 10.5 ms.
  - **Read DMA:** its 10 ms timeout on the same clock is 10.909 ms too. `verification/tests/test_pf_dmar.py` measured it: the 16GB read DMA flags a request never acknowledged, a read never completed and a FIFO never drained each at **10.909 ms**, against 10.000 ms on the 8GB bank (`PF-DMAR-08`).
  - **Bandwidth:** the 16GB AXI port is 512 bits at 137.5 MHz, 70.4 Gbit/s rather than 76.8. `PF-DMAW-10`'s margin is 4.05x rather than 4.41x, still ample.
  - **Documentation:** the design document is wrong on the 16GB interface's clocks and data rate (1100 MT/s, not 1200).
- **Recommended disposition:** Human decision.
  - **If 550 MHz is deliberate** (a timing or board-margin choice for the 64-bit interface), configure the 16GB DMAs for 137.5 MHz. `CLOCK_FREQ_MHZ` is an integer: 137 or 138 gives 9.96 or 10.04 ms, both inside the tolerance; a count given directly in cycles would be exact.
  - **If 550 MHz is not deliberate,** return the 16GB PF_DDR4 to 600 MHz.

  In either case correct `pf-fpga-ddr4-mig.md`.

## PF-F-29 -- HIGH

- **Claim:** `PF-DMAR-23` requires one 20-word metadata block for each metadata-mode read, and `PF-DMAR-16` requires frame-read-done after the final requested line; its rationale is "one completion indication for each image or metadata read request".
- **Actual RTL/design:** A metadata read exposes its block and **never completes**.
  - `frame_xfer_ctrl` requests the read, then waits in `READ_LINE_TRIG` for `dma_ctrl_read_ack` before it will look for `dma_ctrl_read_done`.
  - `dma_read_ctrl` raises `dma_ctrl_read_ack` only in `SEND_SOF_REQ`. A metadata read goes `WAIT_FOR_DMA_ACK` -> `META_DRAIN` -> `IDLE` and never enters it.
  - So the done pulse from `META_DRAIN` arrives while `frame_xfer_ctrl` is still waiting for the ack, and is lost. By the RTL, `frame_xfer_ctrl` then stays in `READ_LINE_TRIG` until its 10 ms watchdog returns it to `IDLE`, counting a frame-transfer timeout, without frame-read-done. (The simulation does not run the 10 ms.)
  - Until then it ignores new read requests, which it takes only in `IDLE`.
- **Evidence:** `ip/dma_read_ctrl_ip/src/dma_read_ctrl.sv:446-449` (the only `dma_ctrl_read_ack <= 'b1`), `:731-762`, `:831-856`; `ip/dma_read_ctrl_ip/src/frame_xfer_ctrl.sv:360-408`, `:515-536`. In simulation, `verification/tests/test_pf_dmar.py`, on the read SmartDesign with its real COREFIFO under QuestaSim, on both banks:
  - A metadata read of frame 7 exposed frame 7's 20 words, with one metadata-valid pulse, and raised no frame-read-done in 50 us; `FRAME_READ_DONE_COUNT` did not move. Image reads before it completed normally.
  - A second metadata read, of frame 9, 50 us later exposed nothing: no metadata-valid pulse, registers still frame 7's.
  - `frame_xfer_ctrl` was in `READ_LINE_TRIG` for the whole read.
  - With `dma_ctrl_read_ack` raised in `META_DRAIN` (a scratch copy; the RTL is unchanged), both reads complete, each with its own block and one frame-read-done.
- **Consequence:** Flight software does not wait for completion. `get_metadata` (`farsight-avionics-sw/Camera/src/camera.c:397-419`) waits `vTaskDelay(5)`, 5 ms at 1 kHz, then reads the registers, so it gets its block. But every metadata fetch leaves the bank's read controller busy for 10 ms and counts a frame-transfer timeout. An image or metadata read requested within 5 ms of the fetch returning is silently dropped, and a metadata read that is dropped returns the *previous* frame's metadata with nothing to show it is stale.
- **Recommended disposition:** Fix in `dma_read_ctrl`: acknowledge a metadata read as an image read is acknowledged, for example by driving `dma_ctrl_read_ack` in `META_DRAIN`. Rerun `test_pf_dmar.py`; `PF-DMAR-16` and `PF-DMAR-23` then close.

## PF-F-30 -- MEDIUM

- **Claim:** `PF-PCIE-08` requires the PCIe path to reject write transactions, because it "must not modify flight image memory". VC-PF-0049 reads that as: a host write reaches no DDR4 write port, and has no read-side effect.
- **Actual RTL/design:** No write reaches DDR4: `axi_read_demux` does not forward writes, and the translators tie `s_awready` low. But writes are **not rejected**. The demux takes every write as a write to one of its two control registers.
  - **Decode on 4 bits.** The register is chosen by `awaddr[3:0]` alone: any address ending `0x0` sets the bank select from bit 0, any ending `0x8` sets the frame index from bits 8:0. Every other write is answered OKAY and ignored. The register map documents two registers, at `0x00` and `0x08`, but they alias every 16 bytes across both BARs, including the 32 MB BAR2 image window.
  - **One beat per burst.** The write state machine takes one data beat, answers, and returns to idle, ignoring `awlen` and `wlast`. A burst gets its B response after its first beat, which AXI forbids, and its remaining beats are never accepted.
- **Evidence:** `ip/eth_pcie_mux_ip/src/axi_read_demux.sv:123-124`, `:159-166`, `:187-191`; `ip/eth_pcie_mux_ip/src/pcie_translator.sv:176`. In simulation, `verification/tests/test_pf_pcie.py` on `eth_pcie_mux_hier` as the build generates it, with 8GB frame 7 selected:
  - Single-beat writes to 0x2000, 0x1234_5678, 0x100, 0x108 and 0x1FF_FFF0, none of them a control address, were each answered OKAY. After each, a read of 8GB frame 7 offset 0x2000 returned 16GB frame 7, 8GB frame 90, 16GB frame 7, 8GB frame 255 and 16GB frame 7 respectively.
  - A 4-beat write to 0x3000 was answered after its first beat; beats 2-4 were not accepted in 2000 clocks.
  - No write-channel valid reached either DDR4 port.
- **Consequence:**
  - **Aliasing:** any host write, for example a stray write into the BAR2 image window, silently changes which bank and frame later reads return, with an OKAY response.
  - **Bursts:** a host write of more than 8 bytes arrives as a burst and leaves the PCIe block's AXI write channel waiting for a `wready` that never comes. PCIe ordering does not let a later read pass a posted write, so this probably stalls the host's reads behind it until the FPGA is reset. The hard block was not simulated, so that part is inferred.

  Neither touches image memory, which is the rationale of `PF-PCIE-08`.
- **Recommended disposition:** Human decision with the payload-software owner (`PF-F-22`), since they will write these registers.
  - Decode the full register address, and answer writes to anything else with SLVERR.
  - Take a burst to its `wlast` before answering, and answer SLVERR if it is longer than one beat.
  - Or record that the host writes only single-beat, 8-byte-aligned values to BAR0 + 0x0 and + 0x8, in CM-01979 section 22, and accept the aliasing.

## PF-F-31 -- LOW

- **Claim:** The focus watchdog's TIMEOUT_MS register is written in milliseconds and reads back all 27 bits written, up to 134,217,727 ms.
- **Actual RTL/design:** The count the watchdog runs is TIMEOUT_MS x 50,000, and it is held in 27 bits (`TIMER_COUNT_WIDTH`). So only 1 to 2,684 ms program the lease written; a larger value wraps silently to a shorter one. By the RTL (not simulated), 0 does not expire at once: the counter wraps and runs 2^27 cycles, 2.68 s.
- **Evidence:** `ip/focus_mech_ip/hw/ip/watchdog_ip/src/watchdog_apb_reg.sv:87`, `:144`; `ip/focus_mech_ip/hw/ip/watchdog_ip/src/watchdog.sv:112-120`. In simulation, `verification/tests/test_pf_focus.py`: TIMEOUT_MS 2684 programmed 134,200,000 cycles (2,684 ms); 2685 programmed 32,272 cycles (0.6 ms); 3000 programmed 15,782,272 cycles (315.6 ms).
- **Consequence:** None today: flight software writes 100 ms (`farsight-avionics-sw/Camera/include/hal_stepper.h:99`). A later lease above 2,684 ms would silently be far shorter, and the mechanism would stop mid-move.
- **Recommended disposition:** Record the valid range, 1 to 2,684 ms, in the register description. Or saturate at the maximum, or widen the count.

## PF-F-32 -- MEDIUM

- **Claim:** `PF-VER-01`'s rationale is that the commit identifier in the image ties it to its source exactly: "given it, the source is known exactly".
- **Actual RTL/design:** The registers carry whatever commit the build supplies, and the build supplies `HEAD`: `set commit_id [string range [exec git rev-parse HEAD] 0 7]`. Nothing checks for uncommitted changes, so an image built from a modified working tree reports the commit it was modified from. The same identifier names the Libero project and export directories, so the build artefact makes the same claim.
- **Evidence:** `synth.tcl:86-91`, `:162-175`; no `git status` or `git diff` anywhere in `synth.tcl` or `script/common/`. The simulation of `PF-VER-01` (`verification/tests/test_pf_ver.py`) generated the registers from this checkout while `script/common/download.tcl` had uncommitted changes, and they read back `757dbfb6`, HEAD's identifier, which does not contain those changes.
- **Consequence:** For an image built from a clean tree the identifier is exact. For one built from a modified tree, it points at source that is not what was built, and nothing in the image or the build's name says so. That undoes the property `PF-VER-01` exists for, and it is also how a verified image and a flown image could differ with the same identifier.
- **Minor observation:** The identifier is the first 8 hex digits, 32 bits, of the commit. Within one repository that is unambiguous in practice, and `git rev-parse` resolves it, but it is an abbreviation rather than the full identifier.
- **Recommended disposition:** Human decision with release engineering. Either `synth.tcl` refuses to build from a modified tree (with an explicit override for development builds), or it marks such builds, for example with a dirty bit in the version register and a `-dirty` suffix on the project name, so that a flight image is only ever one with no mark.

## PF-F-33 -- HIGH

- **Claim:** `PF-META-02` requires the metadata block to carry a reflected IEEE CRC32 covering its payload, so that the receiver can detect corruption in transit.
- **Actual RTL/design:** The CRC is the right algorithm over the right words, but of the block **one clock earlier** than the block it is sent with, and the block changes every clock.
  - `crc32_result` is combinational over the register array `mem`, and is registered into `mem[0x13]` a clock later. So in any one clock, the CRC word covers the previous clock's payload.
  - The payload includes `TIMESTAMP_SUBSEC_NSEC`, which is copied from the live RTC every clock. The RTC's nanoseconds advance about 20 ns every 50 MHz tick.
  - The block is snapshot into the CDC FIFO at an arbitrary clock, so the CRC it carries always covers a nanosecond value 20 ns older than the one it carries.
- **Evidence:** `ip/image_metadata_ip/src/image_metadata_apb_reg.sv:147-153`, `:244`, `:250`, `:428`; `ip/image_metadata_ip/src/image_metadata.sv:144`; `bd/mpf500ts-fc1152m/cam_rx_hier/components/cam_rx_hier.tcl:486` and `bd/mpf500ts-fc1152m/top/components/top.tcl:821` (the timestamp is `pps_hier`'s `nanoseconds`); `ip/pps_ip/src/pps.sv:231-234`. In simulation, `verification/tests/test_pf_meta.py`, on `image_metadata_top` with its real CDC FIFO under QuestaSim:
  - **Live RTC, as built:** in four records with different payloads, the CRC field never matched the reflected IEEE CRC32 of words 1-18 sent with it.
  - **RTC frozen:** in the same four records, it matched every time. So the algorithm, coverage and byte order are right, and the stale snapshot is the cause.
- **Consequence:** Every metadata record in the image stream fails its own integrity check. A receiver that checks the CRC rejects all metadata. One that does not check it has no integrity check, which is what the CRC was added to provide.
- **Recommended disposition:** Fix in `image_metadata_apb_reg`: compute the CRC over the same snapshot that is sent. For example, freeze the payload into a holding register on the write request, and compute and append the CRC from that register before the FIFO write. Or snapshot the timestamp once per frame, at the trigger, which would also make `TIMESTAMP_*` the time of the image rather than the time of the copy.

## PF-F-34 -- MEDIUM

- **Claim:** CM-01979 (revWIP) section 23.2 defines `BUFF_WRITE_INDEX` (byte 0x28) as "Frame index within the DDR4 device that holds this frame", 0x0-0x1FF on the 16 GB device and 0x0-0xFF on the 8 GB device. It says "there is no single 0-767 index space".
- **Actual RTL/design:** On the 8 GB device, the field is `{24'b10, index}`: 0x200 plus the index, a single 0-0x2FF space with the 8 GB device in its top third. The 16 GB device's field is its index alone. The single space is the one `GET_METADATA` uses: its `IMAGE_INDEX` is 0x0000-0x2FF, "same addressing as XFER_BUFF_SYS_CMD" (CM-01979 revWIP 17.3.2.34). So the ICD contradicts itself, and the RTL follows the command interface, not section 23.2.
- **Evidence:** `ip/image_metadata_ip/src/image_metadata_apb_reg.sv:70`, `:261-267`. In simulation, `verification/tests/test_pf_meta.py`: with the 8 GB device selected, a DMA index input of 5 gave `BUFF_WRITE_INDEX` 0x206, and 255 gave 0x200; with the 16 GB device, 300 gave 0x12D and 511 gave 0.
- **Note:** The field reports the DMA's frame index plus one, wrapping at the device's last frame. The DMA reports the last frame written (`ip/dma_write_ip/src/dma_write_send_ctrl.sv:164`), so plus one is the frame being written. That is `PF-META-04`'s to confirm on hardware.
- **Consequence:** A host decoding the in-band metadata by section 23.2 reads 8 GB frames as indices 0x200-0x2FF, which section 23.2 says do not exist. A host using the command interface's numbering decodes it correctly.
- **Recommended disposition:** Human decision on the ICD: make section 23.2 and 17.3.2.34 agree. If the single 0-0x2FF space is intended, as the RTL and the command interface have it, correct 23.2; if not, change the RTL.

## PF-F-35 -- MEDIUM

- **Claim:** `PF-ETH-07` requires an ICMP echo reply for each accepted echo request, echoing its identifier, sequence and data.
- **Actual RTL/design:** The responder loses data from requests larger than about 1 KB when the MAC delivers words faster than the reply drains.
  - The reply drains more slowly than a back-to-back request arrives, so the responder's 16-entry FIFO fills partway through a large request.
  - While it is full, the responder still raises `rxacpt` to the 32-to-128-bit width converter: in each state `rxacpt` depends only on whether the frame has ended. The converter completes the handshake and discards the beat, and the responder does not capture it, because its own capture is gated by the FIFO's `rxacpt`.
- **Evidence:** `ip/responder_ip/src/responder.sv:291` (capture gated by the FIFO), `:640-653` and the other `rxacpt <=` assignments (not gated); `ip/responder_ip/src/width_up_conv.sv:60`, `:75`; `ip/responder_ip/src/rsp_fifo.sv:71`. In simulation, `verification/tests/test_pf_eth.py`, with CORETSE's receive FIFO interface modelled from its user guide:
  - Echo requests of 0 to 64 data bytes were answered correctly.
  - A 1472-byte request, the largest standard one, delivered a word a clock: the reply was 1422 bytes against 1518, with an IP total length of 1500 and a wrong ICMP checksum. 95 beats were sent and 89 reached the FIFO, which was full for 39 clocks: the 6 missing beats are the 96 missing bytes. 1200 bytes also failed; 800 did not.
  - The same requests at line rate, a word every three clocks, were answered whole up to 1472.
- **Consequence:** A large ping to the payload interface gets a malformed reply, which the host discards, if the MAC delivers the request back-to-back. CORETSE's user guide shows its receive interface delivering a word every clock (figure 3-2); whether it does so in this configuration depends on its FIFO settings, which firmware writes. Small pings, including the default 56-byte one, are answered correctly either way.
- **Recommended disposition:** Fix in `responder.sv`: raise `rxacpt` only when the FIFO can take the beat, so that the MAC is held off rather than dropped. Confirm on hardware with `ping -s 1472`.

## PF-F-36 -- LOW

- **Claim:** `PF-ETH-02` to `PF-ETH-07` define what the Ethernet responder accepts and answers: ARP requests for the local address, and local ICMP echo requests.
- **Actual RTL/design:** Its parsing differs from a host's in five ways, none of which a requirement covers:
  - **Unicast ARP requests are dropped.** ARP is accepted only with a broadcast destination MAC. Hosts send unicast requests to confirm a cached entry (Linux, for example, before falling back to broadcast), so each confirmation goes unanswered.
  - **The ARP header is not validated.** A request with hardware type 6 was answered as if it were type 1.
  - **The IPv4 header checksum is not checked.** An echo request with a bad header checksum was answered.
  - **Fragments are answered.** A first fragment (MF set) of an echo request was answered as a whole request. A request with IP options was dropped.
  - **The request's FCS is echoed.** The MAC keeps the FCS of each received frame (CFG2 0x7217, RX CRC DISABLE clear), and the responder copies the frame to the end, so every echo reply carries 4 bytes beyond its IP total length. Receivers treat them as padding.
- **Evidence:** `ip/responder_ip/src/responder.sv:787-799`, `:804`, `:862-879`; `farsight-avionics-sw/Camera/src/eth.c` (`tse_init`). Each is a characterisation in `verification/tests/test_pf_eth.py`.
- **Consequence:** Interoperability rather than correctness: a slower ARP cache refresh, and replies to malformed or fragmented requests that a host would drop.
- **Recommended disposition:** Decide which of these the responder should handle, and either fix or record them as accepted behaviour.

## PF-F-37 -- MEDIUM

- **Claim:** `PF-UDP-16` requires the UDP transmitter to emit an error datagram on watchdog timeout, so that "the host must receive a visible end-of-transfer indication when the payload stream stalls".
- **Actual RTL/design:** On timeout the transmitter does not emit a datagram. It ends the frame it was sending with one word, `0xEFBADBAD`, and EOF. The frame keeps the IP total length and UDP length of the datagram it cut short, so it is shorter than its own headers say.
  - A receiver's MAC accepts it: the CORETSE appends a valid FCS to whatever it is given.
  - A receiver's IP layer then drops it as truncated, so no UDP socket, and so no host application reading the image stream, ever sees the error word. Only a raw packet capture shows it.
  - After the error, the transmitter returns to `IDLE` without its inter-packet gap, so the next datagram can follow at once.
  - The watchdog is 10 s (`MAX_TIMEOUT_USEC:10000000` at 100 MHz).
- **Evidence:** `ip/udp_ip/src/udp_tx.sv:582-590` (`WD_TIMEOUT_ERR` returns to `IDLE`), `:772-779` (the token, with EOF); `bd/mpf500ts-fc1152m/udp_hier/components/udp_hier.tcl:172`. In simulation, `verification/tests/test_pf_udp.py`, on `udp_hier` under QuestaSim: the source stalled 12 words into a datagram of IP total length 194. Its frame was 92 bytes, ending `ef ba db ad`, with the IP total length still 194 and the UDP length 174. The watchdog error count read 1. To avoid simulating a billion clocks, the watchdog counter was set 20 us from its limit once the stall began.
- **Consequence:** A stalled image transfer looks to the host like a missing datagram, not an error: the indication the requirement exists for is not delivered to the application. Firmware can still read `WD_TIMEOUT_ERR_COUNT` over APB.
- **Recommended disposition:** Human decision with the host software owner. Either end the cut-short frame and then send a well-formed error datagram (its own headers, with lengths that match), or fix up the cut-short frame's lengths and checksum. Restore the inter-packet gap after an error. Consider whether 10 s is the watchdog wanted: the DDR4 read controller feeding it gives up after 10 ms.

## PF-F-38 -- MEDIUM

- **Claim:** Both LVDT lock-in chains configure `DECIMATOR` with `DECIMATION_RATIO:5`. The notch filters after it were designed for that rate. At 91.9 kS/s per coil divided by 5, that is 18.38 kS/s, and the notches sit on 6.10 kHz. That is twice the 3.05 kHz excitation, where the mixer puts its unwanted product.
- **Actual RTL/design:** The decimator emits one sample in every **4** inputs, and it emits the sample before the last one.
  - `sample_counter += 1` is a blocking assignment, so the comparison with `DECIMATION_RATIO - 1` on the following line sees the value already incremented. The counter reaches 4 on the fourth valid input, not the fifth.
  - `o_data_stored <= i_data_stored` copies the register before this clock's non-blocking update, so the output is the third of the four inputs.
  - The decimated rate is therefore 22.98 kS/s. At that rate the three notch filters sit at 7.57, 7.62 and 7.68 kHz, not 6.10 kHz. Attenuation of the 6.10 kHz product, relative to DC, falls from about 188 dB to about 63 dB. The -3 dB corner of the remaining filter chain also widens, from about 1.9 kHz to 2.3 kHz.
- **Evidence:** `ip/focus_mech_ip/hw/ip/lvdt_ip/src/DECIMATOR.sv:74-82`; `ip/focus_mech_ip/hw/ip/lvdt_ip/components/LOCK_IN_CHAIN.tcl:189-191`, `:203`.
  - A Verilator 5.052 testbench on `DECIMATOR` alone, with `DECIMATION_RATIO=5` and 40 valid inputs numbered 1 to 40, produced 10 outputs: samples 3, 7, 11 ... 39, each after the 4th, 8th ... 40th input.
  - The filter frequencies come from the `LOCK_IN_CHAIN.tcl` coefficients, evaluated at 50 MHz / 544 per coil (`LVDT_READOUT.tcl:100-101`, `:243-244`) and divided by 4 and by 5.
  - A floating-point model of the whole chain measured the effect on position. It used the real sample instants for ADC channels 3 and 7, 12-bit quantisation and the flight projection (`farsight-avionics-sw/Camera/src/hal/hal_lvdt.c:145-163`), with 4,000 reads at random times, converted at the x1-gain calibration slope of 1.15e-3 per um.

    | Secondary phase vs primary | As built (/4), rms / peak | As designed (/5), rms / peak |
    | --- | --- | --- |
    | 0 deg | 0.28 / 1.1 um | 0.07 / 0.14 um |
    | 15 deg | 0.40 / 0.75 um | 0.05 / 0.08 um |
    | 30 deg | 0.67 / 1.1 um | 0.06 / 0.13 um |
    | 60 deg | 1.8 / 2.9 um | 0.12 / 0.24 um |

    These figures are at about 1000 um. The error is proportional to the reading, so at 100 um it is about a tenth as large.
- **Consequence:** It adds noise to each reading, not a fixed error.
  - The decimator does not change the chain's DC gain. The projection is a ratio, and the calibration tables absorb any static term, so mean position is unaffected. Fixing it should not need the LVDT recalibrated.
  - What it adds is a 6.1 kHz ripple on each I/Q snapshot, so each single position read has a random error. Firmware settles fine focus on consecutive single reads within +/-5 um (`farsight-avionics-sw/Camera/src/Focus_States/Fine_Focus_State.c:92`). A 1-3 um peak error uses up a real share of that window near the ends of travel.
  - About 1 read in 8 is worse. The primary and secondary registers update 272 clocks apart (4 ADC frames), so a read in that window pairs results from different decimated samples. The intended rejection makes that harmless; the as-built ripple does not.
  - This is a GAP against `DRV-PF-12`.
- **Recommended disposition:** Fix `DECIMATOR.sv`:
  - Use a non-blocking increment and compare against the counter's next value, or compare with `DECIMATION_RATIO - 1` before incrementing.
  - Copy the current input, not the stored one, to the output.
  - Then confirm on hardware that the 6.1 kHz component in the I/Q registers is gone, and that the position read at a fixed mechanism position has the same mean as before. Do not set `DECIMATION_RATIO:6` to compensate: it would also keep the stale-sample behaviour.
- **Update (2026-10-05):** Now reproduced by the suite. `verification/analysis/test_ana_budgets.py` computes 187.6 dB at /5 and 62.7 dB at /4 from the configured coefficients and the RTL, and `verification/tests/test_pf_lvdt.py` simulates `LVDT_READOUT` as built with a datasheet ADC model: 62.6 to 62.7 dB on all four I/Q outputs, outputs at 22.95 kS/s. With the decimator corrected as recommended below, the same simulation measures 112 to 128 dB.
- **Open question:** The phase between the secondary and primary voltages at the ADC is not documented. It sets how large this error is, from about 0.3 to 1.8 um rms at full stroke. Measure it on the flight-model board, or read it off the I/Q registers at a few positions.

## PF-F-39 -- LOW

- **Claim:** The first band-pass section of each LVDT lock-in chain, `BANDPASS_1_2`, is a (1 + z^-1)^2 numerator: B0 = B2 = 32768 and B1 = 65536, in Q15. Every other section in `LOCK_IN_CHAIN` uses 32768 for its unity coefficients.
- **Actual RTL/design:** `BANDPASS_1_2` is configured with `B0:32786`. 32786 is 32768 with its last two digits swapped. With it, the double zero at Nyquist moves just inside the unit circle, to radius 0.9997.
- **Evidence:** `ip/focus_mech_ip/hw/ip/lvdt_ip/components/LOCK_IN_CHAIN.tcl:29-32`. Its gain at the 3.05 kHz excitation changes by less than 0.1 %. The same constant is in both coils' chains, so it cancels in the projection.
- **Minor observation:** The board ties ADC inputs IN0-IN3 to `V_LVDT_P` and IN4-IN7 to `V_LVDT_S` (`verification/board/CM-03545.json`, U54). The driver scans all eight channels but only uses channels 3 and 7 (`LVDT_READOUT.tcl:243-244`). The other six results are discarded, along with three quarters of the ADC's throughput. They could be averaged in, or the scan cut to two channels, for 4x the per-coil sample rate.
- **Consequence:** Negligible effect on position. Recorded so that the coefficient is confirmed as intended, or corrected, before the filter design is reused.
- **Recommended disposition:** Confirm with the filter designer, and correct to 32768 if it is a typo. Record a decision on whether the unused ADC channels are intended.

## PF-F-40 -- MEDIUM

- **Claim:** `PF-XCVR-03` requires the SLVS-EC correction path to flag a lane after a bounded run of consecutive disparity errors, 16 as built, so that "a persistently unhealthy lane must be visible before corrupted image data is accepted silently".
- **Actual RTL/design:** Each lane counts its errors in its own recovered clock, 118.8 MHz, and at the 16th raises its flag for **one** lane clock, 8.4 ns. The flag crosses to the 50 MHz `P_CLK` domain through a plain two-flop synchroniser, which samples every 20 ns, so a single flag is caught only when a `P_CLK` edge happens to fall inside it. Outside the block, the flag is visible only as the receiver reset and its interrupt, which the `P_CLK` state machine drives.
- **Evidence:** `ip/xcvr_disparity_correction/src/xcvr_disparity_correction.v:223-237` (lane 0; the other seven are the same), `:446`; the lane clock period, 8.41751 ns, is in the build's derived constraints (`constraint/top_derived_constraints.sdc` in build `20260923_124832_3a5321f5`). In simulation, `verification/tests/test_pf_xcvr.py`, at the build's clocks: a run of 16 errors raised its lane's flag 40 times in 40 and reset the receiver 8 times; runs of 32, which raise two flags, 13 times in 24; runs of 48 to 160 every time. In hardware the lane clocks and `P_CLK` are unrelated, so whether a given flag is caught is chance, about 42% for one flag.
- **Consequence:** A burst of 16 to about 47 disparity errors, enough to corrupt image data, usually passes without a receiver reset or an interrupt. A persistent fault, which raises a flag every 16 lane clocks, is caught within a few flags.
- **Recommended disposition:** Fix in the correction block: stretch each lane flag until `P_CLK` has seen it (a toggle or a handshake synchroniser), or make it sticky until the state machine clears it.

## PF-F-41 -- LOW

- **Claim:** `PF-XCVR-07` now requires the receiver reset to be held for at least 32 cycles of the 50 MHz system clock, 640 ns (TBR); the block's `RST_CNT_CLKS` is 32 and its comments say "32 clock cycles". The requirement's evidence line said "32 receiver-clock cycles".
- **Actual RTL/design:** The reset is held for **31** system clocks, 620 ns. In `s_RST_CNT` the counter starts at 0 and the reset is released on the edge where it reads `RST_CNT_CLKS - 1`, so it is low for `RST_CNT_CLKS - 1` clocks. The clock is `P_CLK`, 50 MHz, not a receiver clock.
- **Evidence:** `ip/xcvr_disparity_correction/src/xcvr_disparity_correction.v:768-782`. In simulation, `verification/tests/test_pf_xcvr.py`: every reset, six across three lanes, was low for 620 ns.
- **Consequence:** Probably none: an asynchronous reset of 620 ns is likely ample. But the minimum the transceiver's `PCS_ARST_N` needs is not documented in what is on hand, so that is not shown.
- **Recommended disposition:** Release on `RST_CNT_CLKS` rather than `RST_CNT_CLKS - 1`, or set `RST_CNT_CLKS` to 33. Settle the TBR from the PolarFire transceiver user guide.

## PF-F-42 -- LOW

- **Claim:** `PF-APB-02` requires every APB peripheral to signal an invalid access to the bus master.
- **Actual RTL/design:** Every one of the design's APB slaves answers only when `paddr[1:0]` is 0. Both its read and its write branch test for it, and nothing else raises `pready`. A misaligned access, a byte or halfword access to any byte but the first, is never completed, and APB has no timeout: the bridge, and the processor behind it, wait for good.
- **Evidence:** the same test in each of the twelve blocks, e.g. `ip/cam_mux_ip/src/cam_mux_apb_reg.sv:84`, `:99`. In simulation, `verification/tests/test_pf_apb.py`: a read at offset 2 got no `pready` in 32 clocks from all twelve. CoreGPIO completed it.
- **Consequence:** Latent. Flight firmware makes byte and halfword accesses only to CoreGPIO instances (`farsight-avionics-sw/Camera/src/hal/core_gpio.c`, `hal/hal_stepper.c`), and `REG_READ_SYS_CMD` indexes a register table rather than taking an address. But one sub-word access to any of these blocks, from a future driver or a debugger, hangs the processor until it is reset.
- **Recommended disposition:** Fold into `PF-F-10`'s common APB semantics: complete every access, and answer a misaligned one with `pslverr`.

## PF-F-43 -- MEDIUM

- **Claim:** `PF-DMAR-24` requires each DDR4 bank to sustain 8.0 Gbit/s of reads to the active egress interface, which is PCIe, Gen2 x2.
- **Actual RTL/design:** The PCIe read path cannot carry 8.0 Gbit/s even from an ideal memory.
  - `pcie_translator` accepts one read at a time: `s_arready` stays low from a read's acceptance until its last beat leaves.
  - Each read is answered about 95 ns, 14 to 16 clocks at 150 MHz, after it is accepted, even when its data is already prefetched: through the request FIFO, the two-stage hit pipeline, the response FIFO and the holding register.
  - So every 256-byte read costs its 213 ns of data plus that 95 ns, about 6.7 Gbit/s. 8.0 Gbit/s needs the turnaround under about 43 ns, or more than one read in flight.
- **Evidence:** `ip/eth_pcie_mux_ip/src/pcie_translator.sv:200-214`. In simulation, `verification/tests/test_pf_dmar_rate.py`, on `eth_pcie_mux_hier` as built with an ideal DDR4 and the fastest legal host: 6.68 Gbit/s from the 8 GB bank and 6.70 from the 16 GB bank, over 64 KB, every word correct.
- **Consequence:** PCIe export of a frame takes at least 20% longer than `PF-DMAR-24` assumes, before DDR4 efficiency and any concurrent capture traffic. A 31 MB frame takes about 37 ms rather than 31 ms.
- **Recommended disposition:** Human decision with the PCIe owner (`PF-F-22`): accept several reads in flight (the request FIFO is already 4 deep, `REQ_DEPTH`), or shorten the turnaround, or restate the egress rate the read path is required to sustain.

## PF-F-44 -- MEDIUM

- **Claim:** `PF-XCVR-08` requires the SLVS-EC correction path to interrupt firmware after it releases the receiver reset, so that "firmware and telemetry need an observable indication that a lane recovery event occurred". The block's own header says the interrupt is how software learns to release the camera from reset at first lock, and to reset the camera over I2C after a disparity error.
- **Actual RTL/design:** The block raises `RX_RST_CONTROL_INTERRUPT_O` for one clock after each reset, as intended, but `cam_rx_hier` marks that output unused. It reaches neither an interrupt controller nor a register, so firmware is never told that the receiver was reset, at first lock or after a lane fault.
- **Evidence:** `ip/xcvr_disparity_correction/src/xcvr_disparity_correction.v:768-796`; `bd/mpf500ts-fc1152m/cam_rx_hier/components/cam_rx_hier.tcl:343` (`sd_mark_pins_unused ... RX_RST_CONTROL_INTERRUPT_O`). Recorded by `verification/analysis/test_ana_budgets.py`. In simulation the block pulses it after every reset (`verification/tests/test_pf_xcvr.py`).
- **Consequence:** Lane recoveries are invisible to firmware and telemetry. The camera-side responses the block's design expects of software, the I2C reset after a disparity error and the release at first lock, have nothing to trigger them. With `PF-F-40`, a short error burst is not even seen by the block.
- **Recommended disposition:** Connect the interrupt to the processor's interrupt controller or to a sticky status bit firmware reads, and give firmware its handler; or record that lane recovery is deliberately hardware-only and withdraw `PF-XCVR-08`.

## PF-F-45 -- MEDIUM

- **Claim:** `PF-PCIE-10` requires 8.0 Gbit/s of image payload at the PCIe boundary, and `PF-DMAR-24` sizes the DDR4 read rate to the same 8.0 Gbit/s, as "PCIe Gen2 x2 payload".
- **Actual RTL/design:** No design can meet it. Gen2 x2 signals 5.0 GT/s on each of 2 lanes; after 8b10b coding that is 8.0 Gbit/s, and every byte of every TLP travels in it. Each TLP spends at least 20 bytes on framing, sequence number, header and LCRC, before DLLPs, so payload is always under 8.0 Gbit/s: 7.961 Gbit/s at the largest payload the standard allows, 4096 bytes, and about 7.4 Gbit/s at 256.
- **Evidence:** `bd/mpf500ts-fc1152m/pcie_hier/components/PF_PCIE_C0.tcl:29`, `:61` (Gen2, x2); the PCIe base specification's TLP format. Recorded by `verification/analysis/test_ana_budgets.py`.
- **Consequence:** Both requirements fail by definition, whatever the design does, so neither can tell a good PCIe path from a bad one. The read path's real shortfall, 6.7 Gbit/s against what the link can carry (`PF-F-43`), is hidden behind an impossible bound.
- **Recommended disposition:** Restate both as a payload rate the link can carry, derived from the configured maximum payload size and the host's read pattern, or as a fraction of the link's data rate, and say what export time it must support.

## PF-F-46 -- HIGH

- **Claim:** `DRV-PF-03` requires every asynchronous crossing to have a timing constraint of its own, and `DRV-PF-06` requires the timing-constrained external interfaces to be constrained and closed. The user constraint file's header says it meets both: "Removed blanket set_clock_groups -asynchronous (was hiding all CDC violations)", "Added per-crossing set_max_delay for CDC paths with 2-FF synchronizers", "Added RGMII I/O delay constraints".
- **Actual RTL/design:** None of the three is true.
  - **Blanket groups.** The file declares 23 asynchronous clock groups, each of one clock. A one-clock group makes that clock asynchronous to every other, so together they cut every path between clock domains out of the timing analysis: all 1495 crossings Synplify reports, over 100 clock pairs.
  - **No per-crossing constraints.** No `set_max_delay`, `set_false_path` or `set_multicycle_path` in the file names a cell or pin; `set_max_delay` appears only in the header.
  - **No I/O timed.** Every one of the 121 ports given an input or output delay is passed through `apply_input_false_path_constraints` or `apply_output_false_path_constraints`, which also set a false path on it, so none is timed: the telemetry ADC SPI's 9 ports and the LVDT ADC SPI's 4 among them. RGMII's 11 data and control ports have no delay at all; only its receive clock is declared.
- **Evidence:** `constr/mpf500ts-fc1152m/sdc/timing_user_constraints.sdc:4-9`, `:23-51`, `:58-88`, `:238`, `:244`; the timing analysis's own constraints, `designer/top/timing_analysis.sdc` in build `20260923_124832_3a5321f5`. Recorded by `verification/analysis/test_ana_build.py`.
- **Consequence:** The build's clean timing result, met at every corner, says nothing about any clock crossing or any external interface: they were never analysed. The header would lead a reviewer to the opposite conclusion.
- **Recommended disposition:** Replace the one-clock groups with constraints per crossing: `set_max_delay -datapath_only` to the first synchroniser stage for synchronised paths, and false paths only between genuinely unrelated domains. Give the SPI and RGMII interfaces real input and output delays without the false paths. Correct the header to say what the file does.

## PF-F-47 -- MEDIUM

- **Claim:** `DRV-PF-02` requires every crossing to use a transfer means that suits it: a synchroniser for one asynchronous bit, and a handshake, gray code or FIFO for several.
- **Actual RTL/design:** Synplify's CDC report on the retained build marks 1410 of 1495 crossings unsafe. 1279 are inside Microchip cores, which their own constraints and documentation must answer for. **131 are in this design's own logic**: 58 in `cam_rx`, 29 in each DDR4 group, 5 in the focus mechanism, 4 each in UDP and the PCIe mux, 2 in PPS. Separately, **146 multi-bit registers are synchronised bit by bit** through flip-flops outside a FIFO, for example `udp_tx_apb_reg`'s `wd_timeout_err_count_sync[0][31:0]` and its port and address registers.
- **Evidence:** `synthesis/top_cdc.csv` in build `20260923_124832_3a5321f5`. Recorded by `verification/analysis/test_ana_build.py`, which lists the categories and blocks.
- **Consequence:** A counter or address crossing bit by bit can be captured with some bits from before a change and some from after, as a value that never existed. Where the source changes only while the destination ignores it, as for configuration registers written before use, that is safe by protocol, but the design does not record which crossings rely on that.
- **Recommended disposition:** Review the 131 and 146 against the means `DRV-PF-02` lists. Fix the live ones, such as counters, with a gray code or a handshake; for the quasi-static ones, record the protocol that makes them safe beside the crossing, where a CDC waiver can cite it.

## PF-F-48 -- HIGH

- **Claim:** `PF-IO-05` requires every top-level port to be on the package pin defined for it. The PolarFire puts `lvds_pwr_en`, an output, on AC2 (`constr/common/pins.tcl`; `bd/mpf500ts-fc1152m/hk_hier/components/hk_hier.tcl:193`, bit 0 of `gpo_hk_pwr_ctrl`).
- **Actual RTL/design:** On the flight-model board, AC2 runs through a 33 ohm resistor (R898) to housekeeper pin AB8, which the housekeeper's flight-model pinout drives as `fw_version[1]`, an output at 8 mA (`farsight-fpga-house-keeper/constr/a3pe3000l-fg484m/io/fm/io_constraints.pdc:176`). The housekeeper sets it to 1 once the PolarFire has booted (`farsight-fpga-house-keeper/src/health_monitor.sv:486`). Flight firmware never writes `LVDS_PWR_EN` (`farsight-avionics-sw/Camera/include/gpio_pin_def.h:37`, defined and unused), so the PolarFire holds the line at the GPIO's reset value, 0. **From PolarFire boot onwards, the two FPGAs drive opposite levels into each other through 33 ohms.** The PolarFire's request also reaches no input: the housekeeper has no LVDS control from the PolarFire, and switches LVDS power itself (`health_monitor.sv:535`).
- **Evidence:** Schematic export `verification/board/CM-03545.json` (CM-03543 rev 2), nets `R_PF_TO_PA3_MISC0` and `PF_TO_PA3_MISC0`; the retained build's pin report (AC2, `lvds_pwr_en`, output). Recorded by `verification/analysis/test_insp_board.py`.
- **Consequence:** Sustained contention between two flight FPGAs, limited only by the 33 ohm series resistor and the drivers' impedance: tens of milliamps, above the housekeeper's 8 mA drive rating, for the whole mission. Neither design alone shows it; only the two pinouts against the board do.
- **Recommended disposition:** Decide what `PF_TO_PA3_MISC0` carries. If it is the PolarFire's LVDS power request, remove `fw_version[1]` from the housekeeper's pinout and give it an input; if it is the housekeeper's version, make the PolarFire's pin an input. Until then, constrain one side's pin as an input.

## PF-F-49 -- MEDIUM

- **Claim:** The PolarFire reads the housekeeper's firmware version on `pa3_fw_version[2:0]` (E5, C1, B1), into bits 31:29 of `gpi_hk_status` (`bd/mpf500ts-fc1152m/hk_hier/components/hk_hier.tcl:199`).
- **Actual RTL/design:** Those pins are lines `PA3_TO_PF_MISC0` to `MISC2`, which the housekeeper's flight-model pinout drives as `ddr8_failure_metadata[0]`, `ddr8_failure_metadata[1]` and `ddr16_failure_metadata[0]` (`farsight-fpga-house-keeper/constr/a3pe3000l-fg484m/io/fm/io_constraints.pdc:63-65`). The housekeeper's `fw_version` has one pinned bit, `[1]`, and that is on the PolarFire's `lvds_pwr_en` line (`PF-F-48`); `[0]` and `[2]` are commented out (`:175`, `:177`).
- **Evidence:** Schematic export nets `PA3_TO_PF_MISC0`-`2`; the retained build's pin report. Recorded by `verification/analysis/test_insp_board.py`.
- **Consequence:** What the PolarFire reports as the housekeeper's version is DDR4 failure status, and the housekeeper's version reaches the PolarFire nowhere. A reader of `GPI_HK_STATUS` gets a plausible small number that means something else.
- **Recommended disposition:** Define the PolarFire-housekeeper line allocation once, in an interface document both pinouts cite, and rename or reassign the PolarFire's ports to match it.

## PF-F-50 -- MEDIUM

- **Claim:** `PF-ETH-09` requires the unused ETH2 outputs to be held inactive.
- **Actual RTL/design:** The four ETH2 control outputs are tied low (`bd/mpf500ts-fc1152m/top/components/top.tcl:231-234`), but the other seven PolarFire lines into the ETH2 PHY, `TX_CTL`, `GTX_CLK`, `TXD[3:0]` and `MDIO` (Y5, W6, Y6, Y7, AB2, AB5, AC4), have no top-level port. `constr/common/pins.tcl:249`, `:257-262` define them; `io_constraints.pdc` does not apply them. Libero configures unused user I/O as "Input Buffer Disabled, Output Buffer Tristated, Weak Pull-up" (`designer/top/top_pinrpt_boardlayout.rpt` in the retained build).
- **Evidence:** Schematic export, U4 (VSC8541) pins 33, 37, 38, 40-42, 50; the retained build's pin report (those pins `Unassigned`). Recorded by `verification/analysis/test_insp_board.py`.
- **Consequence:** Seven PHY inputs float, held only by the FPGA's weak pull-ups to the 3.3 V bank. While ETH2 is unpowered, which is its normal state, those pull-ups feed current into the PHY's unpowered I/O through its protection diodes.
- **Recommended disposition:** Bring the seven pins to top-level ports and tie them low, as the control outputs are, or set them to weak pull-down in the I/O constraints.

## PF-F-51 -- LOW

- **Claim:** `constr/common/pins.tcl` records a `DIRECTION` for each signal, and `apply_pin_constraints` passes it to `set_io` (`constr/common/apply_pin_constr.tcl:33-55`).
- **Actual RTL/design:** Four are wrong: `cam_miso` is given OUTPUT and `cam_mosi` INPUT, the reverse of the design and the board; `lvdt_gain_switch` and `lvdt_pwr_en` are given INPUT and are outputs. The build accepts them without an error or warning (`designer/top/top_layout_log.log` in the retained build, "0 error(s) and 0 warning(s)") and places the ports as the design declares them. The schematic also names `lvdt_pwr_en`'s line `PA3_TO_PF_MISC16`, though the PolarFire drives it into the housekeeper's `lvdt_ctrl` input.
- **Evidence:** `constr/common/pins.tcl:78`, `:136`, `:138`, `:185`; the retained build's pin report. Recorded by `verification/analysis/test_insp_board.py`.
- **Consequence:** None in the programmed device. The constraint file and the schematic net name mislead a reviewer comparing the pinout by hand, which is the review `PF-IO-05` relies on until its automated check is accepted.
- **Recommended disposition:** Correct the four `DIRECTION` attributes, and the net name at the next schematic revision.

## PF-F-52 -- LOW

- **Claim:** `PF-META-01` requires the metadata record to use the CM-01979 format, field names included.
- **Actual RTL/design:** The field at 0x40 is `VERSION` in the RTL (`ip/image_metadata_ip/src/image_metadata_apb_reg.sv:100`) and in both firmware headers (`support/sw/src/include/image_metadata.h:101`, `farsight-avionics-sw/Camera/include/image_metadata.h:101`), and `PF_FPGA_VERSION` in CM-01979 section 23.2 and the host converter (`support/py-script/recv_conv/converter.py`). Offsets, widths and order agree everywhere.
- **Evidence:** Recorded by `verification/analysis/test_insp_interfaces.py`.
- **Consequence:** A reader matching the firmware's register names to the ICD finds no `PF_FPGA_VERSION` and has to infer it.
- **Recommended disposition:** Rename the register `PF_FPGA_VERSION` in the RTL's register map and regenerate the headers, or rename it in the ICD.

## PF-F-53 -- LOW

- **Claim:** `PF-FOCUS-08`, `-09` and `-10` give the stepper pin timing as 3.0 us between steps, 1.5 us step-low and 0.3 us direction setup, and say each minimum is "imposed by the device datasheet".
- **Actual RTL/design:** The step-low time is exactly 75 cycles of the 50 MHz system clock (`const_step_min_dt` 150 less `const_step_fall` 75, `ip/focus_mech_ip/hw/ip/stepper_ip/src/STEP_DIR.sv:44-45`), so it meets 1.5 us only at the nominal frequency. With the clock +75 ppm fast, the limit of its budget (`DRV-PF-04`), it is 1.499887 us, 0.11 ns short. The numbers are also not the datasheet's. The DRV8434 (TI SLOSE47A, May 2022, section 6.6) requires at most 500 kHz (a 2.0 us period), 970 ns STEP high and low, and 200 ns DIR or MODEx setup and hold. The design meets every one of those with the clock fast: 3.02 us period, 1.52 us high, 1.50 us low, 320 ns setup and hold, so at least 120 ns of margin.
- **Evidence:** `verification/analysis/test_ana_budgets.py` (`PF-FOCUS-08` to `-10`), which reads the driver's minima from the datasheet; `verification/analysis/test_ana_clocks.py` (`DRV-PF-07`).
- **Consequence:** None at the driver. The requirement as written cannot be met under the clock budget, and its bounds read as device limits when they are design margins of about 1.5 times the device limits, with nothing recording why that margin was chosen.
- **Related:** The driver's other timing is sequenced by flight software through plain CoreGPIO bits, with no FPGA interlock against STEP: MODEx setup and hold, the 1.2 ms wake time after nSLEEP, the 5 us enable time, and the 20 to 40 us nSLEEP fault-reset pulse (`ip/focus_mech_ip/hw/ip/stepper_ip/components/STEPPER_DRIVER.tcl:185-191`). Flight software sets the mode at state entry with the motor stopped, and waits 5 ticks after enabling (`farsight-avionics-sw/Camera/src/Focus_States/Idle_State.c:38-40`). No FPGA requirement allocates these, and none is needed if software keeps that ownership.
- **Recommended disposition:** Restate `PF-FOCUS-08` to `-10` from the datasheet minima with a stated margin, citing SLOSE47A section 6.6, and add the hold time it also requires. Or keep 1.5 us and make the step-low time 76 cycles (`const_step_fall` 74, or `const_step_min_dt` 151).

## PF-F-54 -- MEDIUM

- **Claim:** `PF-TRIG-12` requires a scheduled trigger within 100 ns of its commanded time, and with an external PPS the RTC is disciplined to it every second (`ip/pps_ip/src/pps.sv`).
- **Actual RTL/design:** The loop corrects phase each second, but its frequency estimate is an exponential average that takes in one eighth of each new period (`pps.sv:144`, `:151`), starting from the nominal 50,000,000 clocks. With the clock off nominal, every second's phase correction is undone by the lagging frequency estimate, so the RTC's error shrinks by only an eighth a second.
  - From power-up, or after the clock's offset changes (temperature, ageing, a PPS outage), the RTC starts up to 75 us off at +/-75 ppm and takes about 71 s to settle.
  - Settled, it is still up to 69 ns behind at some offsets: a clock that is behind is corrected only after the edge is detected, about five clocks late, so the loop settles a few clocks late where the period's fraction holds it there.
- **Evidence:** `verification/analysis/test_ana_clocks.py` (`PF-TRIG-12`), which iterates the loop's update equations, each cited, across -75 to +75 ppm, and checks them against the simulation of `PF-PPS-02`.
- **Consequence:** For about a minute after power-up, scheduled triggers can land tens of microseconds from their commanded time, and nothing says when the RTC has settled: firmware's `b_PPS_Is_Locked()` returns 1 unconditionally (`PFW-F-34`). Settled, the scheduled source is 49 ns outside `PF-TRIG-12`.
- **Recommended disposition:** Expose a settled indication -- for example the phase error within a few clocks for N consecutive seconds -- and have firmware hold scheduled triggers until it is set. Seed the average from the first accepted period rather than the nominal, or widen its update weight while the phase error is large, to shorten the settling. Decide whether 100 ns is the bound for the scheduled source, given the 60-80 ns trigger path it shares with the others.

## Disposition gate

The following findings represent capability or ownership conflicts and must not be auto-corrected without a named owner decision:
- PF-F-01
- PF-F-02
- PF-F-04
- PF-F-05
- PF-F-06
- PF-F-10
- PF-F-13
- PF-F-19
- PF-F-20
- PF-F-21
- PF-F-22
- PF-F-24
- PF-F-25
- PF-F-26
- PF-F-27
- PF-F-28
- PF-F-29
- PF-F-30
- PF-F-32
- PF-F-33
- PF-F-34
- PF-F-35
- PF-F-37
- PF-F-40
- PF-F-43
- PF-F-44
- PF-F-45
- PF-F-46
- PF-F-48
- PF-F-49
