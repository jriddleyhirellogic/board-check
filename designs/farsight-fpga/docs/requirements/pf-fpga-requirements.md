# PolarFire FPGA -- Low-Level Requirements

Scope: FARSIGHT PolarFire FPGA behavior at external pins, firmware-visible registers and host-facing packet boundaries.

Conventions, identifier scheme and trace fields are defined in [`conventions.md`](../../../docs/requirements/conventions.md). This document is Class B under [`criticality.md`](../../../docs/requirements/criticality.md), so it specifies external interfaces, throughput, latency, ICD-visible register behavior and malformed-input responses rather than internal RTL or firmware structure.

## Design source

`Design:` lines in this document cite the **PolarFire fabric design** in this
repository, `farsight-fpga/`:

- `ip/` -- custom and generated fabric IP (SystemVerilog and Verilog sources).
- `bd/mpf500ts-fc1152m/` -- the Libero SmartDesign top-level integration.
- `constr/` -- pinout (`constr/common/pins.tcl`) and timing
  (`constr/mpf500ts-fc1152m/sdc/`) constraints.
- `synth.tcl` -- the synthesis and build flow.

Paths are relative to this repository unless prefixed. Two other trees are cited
by prefix where a requirement crosses a boundary:
`docs/schematics/` and `docs/icd/` are relative to the **workspace root**, and
`farsight-avionics-sw/` is the **flight firmware** that drives this fabric --
`Camera/` (the FreeRTOS application on the MIV_RV32 soft core) and `Bootloader/`.
The PolarFire firmware's own requirements and findings (`PFW-`, `DRV-PFW-`,
`PFW-F-`) are in that repository's `docs/requirements/`, not here.

> **Added 2026-09-17**, as [A-13](../../../docs/requirements/requirements-gap-analysis.md#a-13---name-the-design-source-in-every-requirement-document)
> action 1. The PolarFire *firmware* document was found to have been adjudicated
> in its entirety against `farsight-fpga/support/sw/`, a lab functional-test
> harness, rather than against the flight software. Nothing in either requirement
> set named its own design source, so there was no artefact against which the
> substitution could be checked.
>
> This document was audited for the same error on 2026-09-17 and **does not have
> it**: all 93 `Design:` file paths were resolved against the working tree and 92
> exist. The single failure was `PF-IO-05`, which cited a schematic filename with
> its middle elided (`CM-03545_..._sch_20260911_105755.json`) -- unresolvable
> mechanically, and superseded by a later export. It is corrected below.
>
> The audit is worth repeating rather than trusting, because the FPGA doc was
> trimmed in the same pass as the firmware doc and `support/` also held the
> FPGA-side scripts. See A-13 action 3: `gen_trace_matrix.py` should fail on a
> `Design:` path that does not exist, which would make this check automatic.

## Areas

| Area | Scope | Count |
| --- | --- | ---: |
| `BUILD` | Device/platform constraints and build-message disposition | 2 |
| `CLK` | External clocking and domain crossing | 1 |
| `IO` | Top-level external I/O | 5 |
| `CPU` | Soft processor: command link and application store | 2 |
| `APB` | Firmware-visible APB ICD and error semantics | 1 |
| `FDIR` | Camera fault response | 3 |
| `CAM` | Camera receive boundary | 1 |
| `MUX` | Frame-buffer routing | 4 |
| `TRIG` | Camera trigger interface | 5 |
| `DMAW` | DDR4 write performance and errors | 2 |
| `DMAR` | DDR4 read and packetization | 5 |
| `PCIE` | PCIe image export | 4 |
| `FOCUS` | Focus mechanism boundary | 7 |
| `VER` | FPGA image identification and reproducibility | 2 |
| `META` | Image metadata | 6 |
| `TEMP` | Temperature telemetry | 2 |
| `PPS` | Timekeeping | 6 |
| `ETH` | Ethernet responder | 7 |
| `UDP` | UDP image transmit | 4 |
| `XCVR` | SLVS-EC lane recovery and ingest rate | 4 |
| `SYS` | System data path | 3 |
| `DRV` | Derived obligations (no area segment) | 12 |
| | **Total** | **88** |

Of the 88 entries, 63 are functional requirements traced to a Jama parent, 21
are derived requirements carrying a `Source decision`, and 4 are design
constraints. All 21 derived requirements are pending independent review -- see
the [derived register](../../../docs/requirements/derived-register.md).

Two of the functional requirements, `PF-SYS-02` and `-03`, trace to Jama
requirements the corrected baseline dispositions `UNBUILT` (FAR-CDH_FPGA_L3REQ-11
and -25). Conventions parent rule 3 says not to trace to such a parent, because
the trace would read as implemented. By owner decision of 2026-10-02 an unbuilt
capability is traced instead and recorded `GAP`, so the Jama requirement shows
as failing rather than untraced until it is built, withdrawn or accepted. A
`DEFECT` parent -- malformed text, not a missing feature -- is still not traced;
FAR-CDH_FPGA_L3REQ-14 and -22 carry a note in [`jama.yaml`](jama.yaml) instead.

Eighteen requirements carry `Kind: Performance`. That count was 8 before
2026-09-17, and five of those eight were vendor datasheet minima or a duty cycle
rather than a FARSIGHT bound, so the document had traded away state-level depth
under the Class B grading without collecting the throughput and latency
requirements the grading buys. See
[A-12](../../../docs/requirements/requirements-gap-analysis.md#a-12---write-the-missing-performance-requirements---polarfire-fw-done),
which predicted this hole in this document and is now closed for it.

## Status summary

| Status | Meaning | Count |
| --- | --- | ---: |
| `OK` | Design satisfies the requirement | 53 |
| `GAP` | Design does not meet the requirement | 33 |
| `AMBIG` | Wording unclear or unverifiable as written | 1 |
| `DEFECT` | Design is internally inconsistent | 1 |

One `OK` entry, `PF-DMAW-10`, and one `AMBIG` entry, `DRV-PF-09`, are supported
by analysis and have **not been measured**. The status vocabulary has no
`UNMEASURED` value, which is why they cannot be recorded accurately here. See
A-12 item 1.

## BUILD -- Device/platform constraints

### PF-BUILD-06 *(design constraint)*
The flight FPGA implementation shall target the MPF500TS-FC1152M PolarFire board platform.
- **Constraint:** System-level FPGA device and package allocation decision
- **Design:** `synth.tcl:12`
- **Verify:** INSP
- **Rationale:** Pinout, resources, timing libraries and radiation analysis depend on the selected flight FPGA platform.
- **Status:** OK
- **Evidence:** The project is created for die `MPF500TS`, package `FC1152`,
  range `MIL` (`script/mpf500ts-fc1152m/proj_config.tcl:8-10`), the only
  supported board (`synth.tcl:12`); the retained build was built for that die
  and package at -55 to 125 C; and the flight-model schematic fits
  `MPF500TS-FC1152M` as U1 (`verification/analysis/test_insp_build.py`).
- **Note:** Corrected on 2026-10-02 from "MPF500T-FC1152M", which the design,
  the build and the board all contradict: they use the data-security (`S`)
  variant of the same die. Treated as a typo by owner decision.

### DRV-PF-10
The released FPGA image shall retain at least 20% unused fabric logic and
memory resources, and shall close static timing with non-negative worst-case
slack on every clock domain.
- **Source decision:** A single device was selected to carry the whole imaging
  data path -- camera receive, two DDR4 controllers, Ethernet, PCIe, the
  RISC-V soft core and the housekeeping interfaces -- so there is no second
  device to absorb growth, and any late change competes for the same fabric.
- **Imposes on:** FPGA design, timing closure, verification, system design
- **Design:** `synth.tcl`, `constr/mpf500ts-fc1152m/sdc/timing_user_constraints.sdc`
- **Kind:** Performance
- **Verify:** ANA
- **Rationale:** A flight FPGA is normally required to keep margin, and this set
  stated none -- neither a utilisation floor nor a slack floor -- so a build at
  99% utilisation with 0 ps slack satisfied every other requirement in this
  document. Margin is what absorbs the changes already queued against this
  design: ETH2 if `PF-F-02` is dispositioned as build, PCIe if `PF-F-22` is,
  and the CDC repairs of `DRV-PF-02` and `DRV-PF-03`, which add
  synchronisers and FIFOs rather than removing them. Timing slack is included
  in the same requirement because utilisation and slack trade against each
  other: a congested device closes timing only by replication, which consumes
  the very resource being measured.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Evidence:** By analysis of the retained build
  `20260923_124832_3a5321f5`, whose design sources match the current ones.
  Used: 4LUT 30.51%, DFF 24.56%, LSRAM 20.72%, uSRAM 7.86%, Math 4.32%, so
  every one has at least 20% free. The 17 clock domains with paths close at
  all three corners of the part's -55 to 125 C range, slow and fast process
  at low and high voltage: worst setup slack +0.115 ns (the 8 GB DDR4 user
  clock), worst hold +0.002 ns (the 50 MHz system clock). 99.95% of paths
  are constrained (`verification/analysis/test_ana_build.py`).
- **Note:** Re-adjudicated from `GAP` on 2026-10-01, on the build of commit
  `3a5321f5`. It holds for this design; a design change needs a new build.
  The slack is within each clock domain only: every crossing between domains
  is cut by an asynchronous clock group (`DRV-PF-03`), and every I/O port by
  a false path (`DRV-PF-06`). Whether these corners are the operational
  range's is `DRV-PF-05`'s.
- **Note:** 20% is a conventional figure, not a derived one, and is the weakest
  number in this document -- it should be confirmed or replaced by the systems
  owner rather than inherited. Asked as Q-05 in
  [`open-questions.md`](../../../docs/requirements/open-questions.md).
- **Note:** The slack clause depends on `DRV-PF-05`, which requires closure at
  worst-case PVT corners. Non-negative slack at the typical corner is not what
  this requires.

### PF-BUILD-23
The flight FPGA build shall keep the PolarFire system controller available in
operation, so that the device can be reprogrammed in orbit over its SPI
programming interface.
- **Parent:** FAR-CDH_FPGA_L3REQ-4
- **Design:** `script/mpf500ts-fc1152m/proj_config.tcl:19`, `synth.tcl:123`
- **Verify:** INSP
- **Rationale:** FAR-CDH_FPGA_L3REQ-4 requires in-orbit updates of the PolarFire's
  firmware. A new fabric image reaches the device only through its system
  controller, and a build that suspends the system controller leaves no route
  by which one can be programmed, whatever the board provides.
- **Status:** OK
- **Evidence:** By inspection. The project sets `SYSTEM_CONTROLLER_SUSPEND_MODE`
  to 0, `synth.tcl` passes it to the project, and the retained build records
  it as 0 (`verification/analysis/test_insp_build.py`).
- **Note:** This is the FPGA's share of FAR-CDH_FPGA_L3REQ-4 only. As built the
  board holds `SPI_EN` low through R174, a fitted 0 ohm to ground, which
  disables every SPI programming route (`HW-IF-12` `GAP`, `HW-F-08`). The
  firmware share -- rewriting the soft processor's application image -- is
  `PF-CPU-02`.

## CLK -- External clocking and domain crossing

### PF-CLK-02 *(design constraint)*
The FPGA fabric shall accept the board 50 MHz system clock as the primary control-plane clock.
- **Constraint:** System-level avionics clock distribution decision
- **Design:** `constr/mpf500ts-fc1152m/sdc/timing_user_constraints.sdc:17`
- **Verify:** ANA, HW
- **Rationale:** Firmware, APB control, PPS and focus timing all assume the avionics 50 MHz reference at the FPGA boundary.
- **Status:** OK
- **Evidence:** By analysis of the retained build
  `20260923_124832_3a5321f5`, whose design sources match the current ones.
  The user constraints declare `sys_clk_50mhz` at 20 ns on its port; it
  reaches the reference of `pll_sys_clk_50mhz` through a clock buffer; the
  timing analysis generates OUT0 from that reference at divide-by-1, 20 ns;
  and OUT0 clocks the focus mechanism, the PPS hierarchy, the interconnect
  and the APB peripherals (`verification/analysis/test_ana_build.py`).

### DRV-PF-02
Every signal crossing a clock domain boundary shall be transferred by a means
appropriate to the relationship between the two domains and to the width of the
signal.
- **Source decision:** The imaging path was implemented with multiple
  independent clock domains -- the 50 MHz control plane, a PLL-derived XCVR
  clock, a PLL-derived pixel clock, a divided XCVR control clock, and eight
  per-lane recovered receive clocks -- rather than resynchronising the sensor
  interface onto a single domain.
- **Imposes on:** FPGA design, verification, timing closure
- **Design:** `constr/mpf500ts-fc1152m/sdc/timing_user_constraints.sdc:56-68`
- **Verify:** ANA (CDC tool report), INSP
- **Rationale:** Eleven asynchronous groups are declared, so the crossing count
  is too large to leave to per-crossing judgement, and the correct treatment
  differs by case. A single-bit asynchronous crossing needs synchronisation
  against metastability; a multi-bit crossing cannot be synchronised bit-wise
  because the bits will not resolve on the same cycle, and needs a handshake,
  a gray code or a FIFO; a crossing between domains with a known phase
  relationship needs a timing constraint instead, and synchronising it would
  destroy the relationship it depends on.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** GAP
- **Evidence:** By analysis of the retained build
  `20260923_124832_3a5321f5`, whose design sources match the current ones,
  from Synplify's CDC report. Of 1495 crossings, 1410 are reported unsafe:
  1279 inside Microchip cores, and 131 in this design's own logic (58 in
  `cam_rx`, 29 in each DDR4 group, 5 in the focus mechanism, 4 each in UDP
  and the PCIe mux, 2 in PPS). 146 multi-bit registers are synchronised bit
  by bit through flip-flops, outside a FIFO, for example
  `wd_timeout_err_count_sync[0][31:0]`
  (`verification/analysis/test_ana_build.py`, failing as expected).
- **Evidence:** No reviewed crossing inventory exists. No tracked file is
  named for CDC or crossings, other than HDL and generated cores, and no
  document calls itself one; the 1495 crossings, between 100 pairs of clocks,
  are recorded only in Synplify's report, which classifies them but records no
  chosen means and no review (`verification/analysis/test_insp_build.py`,
  failing as expected).
- **Finding:** PF-F-47
- **Note:** Stated as an obligation rather than a mechanism. Acceptable means
  by case: single-bit asynchronous -- multi-stage flip-flop synchroniser;
  multi-bit asynchronous -- handshake, gray-coded, or FIFO transfer;
  phase-related or source-synchronous -- constrain and close in static timing,
  do not synchronise.

### DRV-PF-03
Every asynchronous clock crossing shall be covered by a timing constraint
specific to that crossing.
- **Source decision:** Same multi-domain architecture as `DRV-PF-02`.
- **Imposes on:** PolarFire FPGA design, timing closure, verification
- **Design:** `constr/mpf500ts-fc1152m/sdc/timing_user_constraints.sdc:5-7`
- **Verify:** ANA (CDC tool report)
- **Rationale:** "Specific to that crossing" is the operative phrase. The
  constraint file records that a blanket `set_clock_groups -asynchronous` was
  previously in place and "was hiding all CDC violations"; a blanket exemption
  makes the timing report clean without making the design correct. Per-crossing
  `set_max_delay` for synchronised paths and `false_path` only for genuinely
  unrelated domains is what produces analysable results.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** GAP
- **Evidence:** By analysis of the user constraints and the retained build
  `20260923_124832_3a5321f5`, whose design sources match the current ones.
  The file declares 23 asynchronous clock groups, each of one clock, which
  makes every clock asynchronous to every other; no `set_max_delay`,
  `set_false_path` or `set_multicycle_path` names a cell or pin. So all 1495
  crossings in Synplify's CDC report, over 100 clock pairs, are discharged
  by a blanket group. The file's header says the opposite: that the blanket
  groups were removed and per-crossing `set_max_delay` added
  (`verification/analysis/test_ana_build.py`, failing as expected).
- **Finding:** PF-F-46
- **Note:** The CDC analysis is a known open item, recorded in
  `docs/notes/farsight.md:22` as "CDC crossing are not fully analyzed (Steven).
  See Libero CDC report". This requirement is what makes that item closeable.

### DRV-PF-04
The total frequency error of each FPGA clock source shall be budgeted as the
sum of initial tolerance, temperature stability and aging over mission life.
- **Source decision:** The design derives all internal timing from free-running
  board oscillators with no temperature compensation, no calibration and, in
  local-PPS mode, no external discipline.
- **Imposes on:** PolarFire FPGA design, board design, ICD
- **Design:** `ip/pps_ip/src/pps_generator.sv:25`; `constr/mpf500ts-fc1152m/sdc/timing_user_constraints.sdc:17`
- **Verify:** ANA
- **Rationale:** Initial tolerance alone is not a flight number. Temperature
  stability typically dominates it, and aging adds a further drift that is
  monotonic over life rather than random.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** GAP
- **Evidence:** Partly met, by analysis of every primary clock in the retained
  build's constraints, followed to the board. On-board sources, read from their
  datasheets: the 50 MHz system clock (Y3, X35T-L7M) and the 148.5 MHz
  transceiver reference (Y8, XD35T-L7M) are each **+/-75 ppm** over -55 to
  +125 C, including 5 years' aging. Off-board: the PCIe reference is the host's
  (+/-300 ppm, PCIe Base Specification) and the Ethernet receive clock the link
  partner's (+/-100 ppm, IEEE 802.3). Not budgeted: the camera lane clocks,
  recovered from the sensor's oscillator on the camera board, which has no part
  number here; and the PolarFire's on-die RC oscillator, which clocks the
  transceivers' control logic, whose tolerance is in the PolarFire datasheet
  (`verification/analysis/test_ana_clocks.py`, failing as expected).
- **Note:** Six clock domains on this board are each driven by two alternative
  oscillator part numbers on one net. Where their stability specifications
  differ, the budget must be taken against the worse of the pair. See
  [`PF-F-19`](pf-fpga-findings.md).
- **Note:** By owner decision of 2026-10-02 the Xsis parts are the flight fit,
  and the budget is taken over 5 years and -55 to +125 C, their rated range;
  life and range are TBR until the programme defines them. The alternates are
  recorded but not flown: the ECS-3225MVQ (+/-65 ppm at 5 years) is rated only
  to -40 to +105 C, and the Renesas XL536 (+/-25 ppm, aging included for an
  unstated life) to -40 to +85 C.

### DRV-PF-07
Every timing requirement derived from a clock source shall be verified against
that source's total frequency error.
- **Source decision:** Same free-running oscillator architecture as `DRV-PF-04`.
- **Imposes on:** PolarFire FPGA design, PolarFire firmware, verification
- **Design:** `ip/pps_ip/src/pps_generator.sv:25`
- **Verify:** ANA
- **Rationale:** A budget that is computed but not applied changes nothing. The
  PPS timebase, the transceiver references and every firmware timeout are all
  derived from these oscillators and each needs checking against the budget of
  `DRV-PF-04`.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Finding:** PF-F-19
- **Status:** OK
- **Evidence:** By analysis. Every requirement in this document whose statement
  carries a time bound is either budgeted or excluded with a reason, and the
  analysis fails on any that is neither. Each budgeted bound is checked with
  the system clock's +/-75 ppm (`DRV-PF-04`) applied, and its margin recorded:
  `PF-FOCUS-08` +19.8 ns, `PF-FOCUS-10` +20.0 ns, `PF-DMAW-09` and `DRV-PF-08`
  missing even at the nominal frequency (their own findings), and
  `PF-FOCUS-09` meeting its bound only at the nominal frequency (`PF-F-53`). `PF-PPS-07`
  and `PF-TRIG-12` take the budget in their own analyses; `PF-XCVR-07` is bound
  in cycles (`verification/analysis/test_ana_clocks.py`).
- **Note:** Re-adjudicated from `GAP` on 2026-10-02 by owner decision. The
  shortfalls the budget finds belong to their own requirements, not to this
  one. Firmware timeouts, which the rationale names, are bounded in the
  firmware requirements and are not covered here.

### DRV-PF-05
Static timing analysis shall be closed at the worst-case process, voltage and
temperature corners of the operational range, for every clock domain.
- **Source decision:** The design adopted eleven asynchronous clock groups,
  PLL-derived clocks and high-speed transceiver interfaces, all of whose timing
  margins vary with process, voltage and temperature.
- **Imposes on:** PolarFire FPGA design, timing closure, verification, thermal analysis
- **Design:** `constr/mpf500ts-fc1152m/sdc/timing_user_constraints.sdc`
- **Verify:** ANA
- **Rationale:** A single-corner result is not a flight result, and both
  extremes must be checked rather than assuming the hot corner is worst. This
  compounds with `DRV-PF-03`: constraints that were recently rewritten to stop
  hiding CDC violations are only meaningful if they are then closed at corners.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** GAP
- **Evidence:** By analysis of the retained build
  `20260923_124832_3a5321f5`, whose design sources match the current ones.
  It was analysed at slow_lv_lt, fast_hv_lt and slow_lv_ht over the part's
  -55 to 125 C and 0.97 to 1.03 V, and every clock domain with paths closes
  at every corner. The operational range is still undefined, so these cannot
  be shown to be its worst corners
  (`verification/analysis/test_ana_build.py`, failing as expected).
- **Note:** Blocked on `HW-ENV-01` -- the operational range is not defined.

### DRV-PF-06
Source-synchronous and other timing-constrained external interfaces shall be constrained and closed in static timing analysis rather than synchronised.
- **Source decision:** The design uses external interfaces whose capture depends on a defined phase relationship rather than on a free-running local clock -- among them the ADC128S102 telemetry SPI links, which use a fly-by clocking arrangement, and the RGMII Ethernet interfaces.
- **Design:** constr/mpf500ts-fc1152m/sdc/timing_user_constraints.sdc
- **Imposes on:** PolarFire FPGA design, timing closure, board design, verification
- **Verify:** ANA
- **Rationale:** These interfaces are not asynchronous, so DRV-PF-02 does not apply to them, and synchronising them would destroy the phase relationship their capture depends on while adding latency the protocol may not tolerate. They need input and output delay constraints and a closed timing result instead. Recording the distinction explicitly stops a reviewer applying a blanket "synchronise every input" rule and stops the constrained interfaces being overlooked because they are not in the CDC report.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** GAP
- **Evidence:** By analysis of the retained build
  `20260923_124832_3a5321f5`, whose design sources match the current ones.
  None of the three interfaces is timed: the telemetry ADC SPI's 9 ports and
  the LVDT ADC SPI's 4 each have an input or output delay and a false path,
  and RGMII's 11 data and control ports have neither
  (`verification/analysis/test_ana_build.py`, failing as expected).
- **Finding:** PF-F-46
- **Note:** The constraint file's header says it adds RGMII I/O delay constraints; it does not. The telemetry ADC interfaces are recorded as still needing them -- docs/notes/farsight.md:26 states "TLM_ADC_SPI - adc128s102s fly by clocking / needs PF constraints".
- **Note:** The LVDT ADC, also an ADC128S102, is in the same state. Its four SPI ports are given input and output delays, but each goes through `apply_input_false_path_constraints` or `apply_output_false_path_constraints`. Those procedures also set `set_false_path` on the port, which overrides the delays, so the interface is never timed (`constr/mpf500ts-fc1152m/sdc/timing_user_constraints.sdc:23-51`, `:120`, `:184-186`).
  - SCLK is a fabric register toggled every 2 clocks, giving 12.5 MHz (`ip/focus_mech_ip/hw/ip/lvdt_ip/src/ADC128S102_DRIVER.sv:100-153`).
  - MISO is captured on the same 50 MHz edge that drives SCLK high. So the ADC has one SCLK half-period, 40 ns, from the falling edge it launches a bit on to the capture. Out of that come the board delay out and back, the ADC's DOUT access time and the input register's setup time.
  - Nothing in the build checks that budget.

## CPU -- Soft processor

### PF-CPU-01
The PolarFire design shall implement a soft processor that receives commands
on the TMTC serial interface and transmits its responses on it.
- **Parent:** FAR-CDH_FPGA_L3REQ-1
- **Design:** `bd/mpf500ts-fc1152m/riscv_hier/components/riscv_hier.tcl:186`, `bd/mpf500ts-fc1152m/top/components/top.tcl:652-653`, `bd/mpf500ts-fc1152m/top/components/top.tcl:813`, `bd/mpf500ts-fc1152m/top/components/top.tcl:891`
- **Verify:** INSP
- **Rationale:** FAR-CDH_FPGA_L3REQ-1 requires a softcore that processes and
  responds to commands. The commands arrive on the TMTC serial link, so the
  obligation on the fabric is a processor that can reach that link in both
  directions and be told when a command has arrived; what it does with a
  command is the firmware's (`PFW-*`).
- **Status:** OK
- **Evidence:** By inspection of the SmartDesign. `riscv_hier` instantiates a
  MIV_RV32 core. The TMTC UART (CORE16550) receives on `uart0_rx` and transmits
  on `uart0_tx`, which the board routes to the housekeeper's RS-422 bus
  pass-through; its register interface sits at 0x70000000 on the processor's
  APB, and its interrupt drives the processor's `tmtc_ext_irq`
  (`verification/analysis/test_insp_interfaces.py`).
- **Note:** FAR-CDH_FPGA_L3REQ-1 is allocated to hardware in the corrected
  baseline and `HW-FPGA-01` traces it to the fitted device. This requirement is
  the fabric's share: the device carries no processor until the design puts
  one there.

### PF-CPU-02
The soft processor shall be able to read, erase and program the board's
non-volatile flash, which holds its application image.
- **Parent:** FAR-CDH_FPGA_L3REQ-4
- **Design:** `bd/mpf500ts-fc1152m/top/components/top.tcl:387`, `bd/mpf500ts-fc1152m/top/components/top.tcl:628-631`, `bd/mpf500ts-fc1152m/top/components/top.tcl:874`, `constr/common/pins.tcl:290-293`
- **Verify:** INSP
- **Rationale:** FAR-CDH_FPGA_L3REQ-4 requires in-orbit updates of software.
  The flight bootloader takes the application image from the board flash and
  rewrites it on command (`farsight-avionics-sw/Bootloader/src/command.c`), so
  the fabric's obligation is a path from the processor to every line of that
  flash, through which any SPI command -- read, erase, program -- can be sent.
- **Status:** OK
- **Evidence:** By inspection. A CoreSPI master (`flash_spi_inst`) is an APB
  slave the processor reaches at 0x70018000 (`FLASH_SPI`); its clock, select
  and two data lines are the ports `nvm_spi_sck`, `nvm_spi_cs_n`,
  `nvm_spi_sio0` and `nvm_spi_sio1`, on pins K7, K3, L7 and L8, which the
  schematic connects to U63, an SST26LF064 SPI flash
  (`verification/analysis/test_insp_interfaces.py`).
- **Note:** The flash is on fabric I/O, not on the system controller's SPI, so
  it can hold the processor's software but cannot be the source of a fabric
  update (`HW-F-08`). Updating the fabric is `PF-BUILD-23`.

## APB -- Firmware-visible APB ICD and error semantics

### DRV-PF-01
The APB interface shall expose the peripheral slots defined in CM-01979
section 25.1.
- **Source decision:** The PolarFire integrates generated and custom APB slaves behind one firmware-visible interconnect.
- **Design:** bd/mpf500ts-fc1152m/top/components/top.tcl:847-899
- **Imposes on:** FPGA design, firmware, verification, ICD
- **Verify:** INSP
- **Rationale:** Firmware and verification need one stable memory map for control, telemetry and error handling.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Evidence:** By inspection of the SmartDesigns and the vendor cores' decode
  as built: 44 APB slots, each at 0x7000_0000 + AHB slave x 0x1_0000 + APB
  slot x 0x1000, one slave per slot. Every one is at the address the
  firmware's `*_BASE_ADDR` gives it (44 in the lab firmware, 39 in the flight
  firmware's `mem_map.h`); every peripheral class CM-01979 section 25.1 lists is
  on the bus; and each of the 24 addresses section 25.2 states agrees
  (`verification/analysis/test_insp_interfaces.py`).
- **Note:** Former identifier PF-APB-01.

### PF-APB-02
Every APB peripheral shall signal an invalid access to the bus master, rather
than returning data that cannot be distinguished from a valid read.
- **Parent:** FAR-TMTC_SW_L4REQ-24, FAR-L1REQ-19, FAR-L1REQ-21
- **Design:** `ip/image_metadata_ip/src/image_metadata_apb_reg.sv:407-410`, `ip/pps_ip/src/pps.sv:334-337`, `ip/dma_read_ctrl_ip/src/dma_read_ctrl_apb_reg.sv:122`, `:225-226`
- **Verify:** SIM
- **Rationale:** Error semantics must be common across the interconnect. A
  master cannot carry a different rule for each slave, so a per-peripheral
  convention is not a usable contract -- firmware has no way to tell a dummy
  read from real data unless the behaviour is uniform.
- **Status:** DEFECT
- **Note:** Not met. Several APB slaves return dummy data -- typically
  `DEADBEEF` -- while holding `pslverr` low, so an invalid access is
  indistinguishable from a valid one. See
  [`PF-F-10`](pf-fpga-findings.md), whose recommended disposition is to define
  common APB error semantics; this requirement is where that definition lands.
- **Evidence:** Simulated on each of the design's twelve APB slaves -- the
  register blocks of cam_fault_detector, cam_mux, cam_trig, dma_read_ctrl,
  dma_read, dma_write, hw_version, image_metadata, junc_temp, udp_tx and the
  focus watchdog, and pps -- and on CoreGPIO for the vendor cores. Each
  block's decode and register map were read from its RTL. No block raised
  `pslverr` for any access. Reads of an unmapped register returned 0, or
  `0xDEADBEEF` from image_metadata and pps; reads above each block's decode
  window returned the register they alias (hw_version its version,
  image_metadata its start flag); writes to an unmapped register completed.
  None of the twelve completed a misaligned read: `pready` never rose.
  CoreGPIO completed every access, without error
  (`verification/tests/test_pf_apb.py`, failing as expected).
- **Finding:** PF-F-10, PF-F-42
- **Note:** Replaces `PF-META-05` and `PF-PPS-05`, which stated the same
  behaviour for two of the roughly eighteen APB peripherals. Stating it
  per-peripheral both under-specified the interconnect and implied the other
  sixteen were exempt.

## IO -- Top-level external I/O

### PF-IO-01 *(design constraint)*
The top-level design shall accept the board-supplied 50 MHz system reference
clock as a single-ended input.
- **Constraint:** System-level avionics clock distribution decision; the same decision recorded by `PF-CLK-02`, seen at the pin rather than at the fabric
- **Design:** `constr/common/pins.tcl:13`
- **Verify:** INSP, HW
- **Rationale:** This is the reference from which the control plane, firmware
  timing, PPS and focus timing are all derived.
- **Status:** OK
- **Evidence:** Assigned to package pin T9 in the pinout constraint. The pin
  itself is controlled by the pinout definition and is verified by `PF-IO-05`,
  not fixed by this requirement. By inspection against the schematic: the
  port is LVCMOS33, built at T9, a clock-capable input (`CLKIN_W_3`), whose
  net is driven by single-output 50 MHz oscillators -- Y3, the flight X35T, or
  its alternate Y7 -- and it enters the fabric through a global clock buffer
  (`verification/analysis/test_insp_board.py`). The HW item is still to run.
- **Note:** Reclassified from functional on 2026-09-17. It previously cited
  `FAR-RS422_L3REQ-7` -- *"The RS422 debug interface to FARSIGHT shall be
  configurable by the user"* -- as its parent. A board clock input does not
  decompose an RS-422 baud-rate need; the link was a keyword match, not a
  decomposition, and is the pattern `conventions.md` parent rule 4 forbids. No
  system requirement specifies this clock, which makes it a design constraint
  like its neighbours `PF-CLK-02` and `PF-IO-02`.
### PF-IO-02 *(design constraint)*
The camera clock interface shall accept a 148.5 MHz differential reference
clock.
- **Constraint:** Camera ICD and board pinout allocation decision
- **Design:** `constr/common/pins.tcl:18-19`
- **Verify:** INSP, HW
- **Rationale:** The SLVS-EC receiver needs this reference to acquire the
  sensor stream; the frequency is fixed by the IMX531 interface definition.
- **Status:** OK
- **Evidence:** Assigned to package pins AG27/AG28 in the pinout constraint. By
  inspection against the schematic: the pair is built at AG27/AG28, the P and N
  of transceiver reference `XCVR_4A_REFCLK`, and both oscillator options --
  Y8, the flight XD35T, and its alternate Y9 -- are 148.5 MHz and drive their
  true output onto P and their complement onto N. The reference buffer is
  configured differential and feeds the camera receiver's CDR, whose
  transceivers both expect 148.5 MHz (`verification/analysis/test_insp_board.py`).
  The HW item is still to run.
### PF-IO-03
The top-level design shall expose eight differential camera data lanes.
- **Parent:** FAR-AB_L2REQ-7, FAR-L1REQ-31
- **Design:** constr/common/pins.tcl:116-131
- **Verify:** INSP, HW
- **Rationale:** The IMX531 SLVS-EC interface delivers the image stream over eight differential receive lanes.
- **Status:** OK
- **Evidence:** By inspection against the schematic: each of the eight lanes is
  a top-level P/N port pair, built on a transceiver receive P/N pin pair, on
  the board net of its own lane and polarity (`SLVS_EC_<n>_P/N`), reaching the
  one camera connector, J7, and connected into the camera receiver
  (`verification/analysis/test_insp_board.py`). The HW item is still to run.

### PF-IO-04
The top-level design shall expose both DDR4 memory interfaces at their assigned pin groups.
- **Parent:** FAR-CDH_FPGA_L3REQ-12, FAR-FB_L3REQ-3, FAR-FB_L3REQ-2
- **Design:** constr/common/pins.tcl:338-567
- **Verify:** INSP, HW
- **Rationale:** The image buffer architecture needs both DDR4 devices available at the board connector boundary.
- **Status:** OK
- **Evidence:** By inspection against the schematic. The 16 GB interface's 127
  signals and the 8 GB interface's 83 are top-level ports of their DDR4
  hierarchies, each built at its constrained pin, and each signal's board net
  reaches DRAM only (MT40A2G8AG), with terminations: the 16 GB group nine
  devices (U5-U13), the 8 GB group five (U14-U18), every device receiving the
  same 39 FPGA signals and no device shared between the interfaces. The
  interfaces' shield pins are all grounded
  (`verification/analysis/test_insp_board.py`). The HW item is still to run.
- **Note:** `pins.tcl` also places an external reference for each interface
  (`ddr4_r0_ext_ref` at AF4, `ddr4_r2_ext_ref` at B27), and the board brings a
  resistor divider from the bank's 1V2 to each. Neither is a port of the
  design, both pins are unassigned in the build, and the controller is
  configured for its internal reference (`VREF_CALIB_VALUE` 70.40 %). Harmless
  as built; the dividers and the two constraint entries serve nothing.

### PF-IO-05
Every top-level port shall be assigned to the package pin defined for it in the
avionics pinout definition.
- **Source decision:** The design is realised on a specific package, so the binding of top-level ports to package pins is carried by a constraint file outside the RTL and is not checked by compilation.
- **Imposes on:** FPGA design, hardware design
- **Design:** `constr/common/pins.tcl`; `verification/board/CM-03545.json` (CM-03543 rev 2)
- **Verify:** INSP
- **Rationale:** A pin assignment that is valid but wrong produces a build that
  programs successfully and does nothing, and neither synthesis nor simulation
  detects it. This requirement is what makes pin correctness verifiable now
  that individual interface requirements state the signal rather than the pin.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** GAP
- **Finding:** PF-F-48, PF-F-49, PF-F-51
- **Evidence:** Not met. Each of the 399 ports the retained build placed was
  compared with the schematic export's net on its pin (all 1152 PolarFire pins
  are in the export) and, for the 37 lines that run to the housekeeper, with
  the housekeeper's flight-model pinout at the far end. Every port is placed
  where the constraints put it, and 362 are on a net named for their signal
  (229 by naming convention, 25 on reviewed aliases, 94 DDR4 data bits swapped
  within their byte lane, 14 DDR4 shield pins on ground). Of the housekeeper
  lines, four are wrong: `lvds_pwr_en` (AC2) shares its line with the
  housekeeper's `fw_version[1]` output, so the two FPGAs drive each other
  (`PF-F-48`); and `pa3_fw_version[2:0]` (E5, C1, B1) reads the housekeeper's
  DDR4 failure-metadata outputs, not its version (`PF-F-49`)
  (`verification/analysis/test_insp_board.py`, failing as expected).
- **Note:** The check now exists, as an analysis test rather than an extension
  of the housekeeper's `gen_trace_matrix.py`; the export it needed is complete.
  Where the schematic names a line generically (`PF_TO_PA3_MISC0`), the signal
  it carries is defined by the two FPGAs' pinouts, so it is checked at both
  ends.

## FDIR -- Camera fault response

### PF-FDIR-04
The camera fault detector shall latch a timeout fault when no frame-valid response arrives before the configured timeout.
- **Parent:** FAR-L1REQ-19, FAR-L1REQ-21
- **Design:** ip/cam_fault_detector_ip/src/cam_fault_detector.sv:74-88
- **Verify:** SIM, HW
- **Rationale:** A missing camera frame after trigger is an externally visible acquisition fault that firmware must report.
- **Status:** OK
- **Evidence:** Simulated on `cam_fault_detector_top` at the instance's
  parameters (50 MHz, 1000 us). A frame-valid 999 us after the trigger edge
  was not a fault. An unanswered trigger latched the fault 1,000,010 ns after
  the edge, which is the timeout plus the half clock to the first sampling
  edge. `FAULT` then read 1 through a late frame-valid, two answered
  captures and the end of the capture
  (`verification/tests/test_pf_fdir.py`).
- **Finding:** PF-F-25 -- flight software holds the clear asserted, which
  stops this fault from ever latching.

### PF-FDIR-05
The camera fault detector shall latch a power fault while capture is active and camera power status is low.
- **Parent:** FAR-L1REQ-19, FAR-L1REQ-21
- **Design:** ip/cam_fault_detector_ip/src/cam_fault_detector.sv:104-115
- **Verify:** SIM, HW
- **Rationale:** Firmware needs a distinct indication that image acquisition failed because the camera rail was unavailable.
- **Status:** GAP
- **Evidence:** Simulated on `cam_fault_detector_top`. A 1 us rail dip during
  capture latched the power fault and `FAULT` read 1; dips before a capture
  and after one finished did not. **But the indication is not distinct:**
  every register firmware can read, all 32 word addresses, reads the same
  after a power fault as after a timeout (`FAULT = 1`, the rest 0). The latch
  reaches firmware only through `fault = timeout_fault | pwr_fault`
  (`verification/tests/test_pf_fdir.py`, failing as expected).
- **Finding:** PF-F-24, and PF-F-25 as for `PF-FDIR-04`.
- **Note:** Re-adjudicated from `OK` on 2026-09-25, when the rationale was
  tested. The text alone ("shall latch a power fault") is met; the need it
  states is not.

### PF-FDIR-06
The camera fault detector shall report a fault whenever timeout or camera-power fault is latched.
- **Parent:** FAR-L1REQ-19, FAR-L1REQ-21
- **Design:** ip/cam_fault_detector_ip/src/cam_fault_detector.sv:123
- **Verify:** SIM, HW
- **Rationale:** Firmware needs one boundary status that summarizes camera acquisition failure.
- **Status:** OK
- **Evidence:** Simulated on `cam_fault_detector_top`, watching both source
  latches. For a timeout alone, a power fault alone and both together, the
  common `fault` and the `FAULT` register were 1 whenever a source latch was.
  Clear and re-arm returned `FAULT` to 0 each time, so no case passes on a
  report left over from the one before (`verification/tests/test_pf_fdir.py`).
- **Finding:** PF-F-25 -- flight software never reads this report.

## CAM -- Camera receive boundary

### PF-CAM-04
The camera receive conditioning path shall extend frame-valid through the configured end-of-frame guard interval.
- **Parent:** FAR-SA_L3REQ-1, FAR-CDH_FPGA_L3REQ-27, FAR-CDH_FPGA_L3REQ-19, FAR-AB_L2REQ-7
- **Design:** ip/cam_flow_sync_ip/src/cam_flow_sync.sv:98-115, ip/cam_flow_sync_ip/src/cam_flow_sync.sv:130-149
- **Verify:** SIM, HW
- **Rationale:** The DDR write path needs a stable frame boundary while trailing embedded data clears the receive path.
- **Status:** OK
- **Evidence:** Simulated on `cam_flow_sync` at the instance's parameters
  (`EXTEND_CYCLES = 10`) on the 79.2 MHz pixel clock. For input frames of 200,
  5 and 1 clocks, the conditioned frame-valid rose 3 clocks after the input
  and fell 13 clocks after it: 3 clocks of pipeline and 10 of guard, so it was
  high for exactly the input time plus 10 clocks. An embedded-data beat on
  every clock of each guard interval, 30 in all, left the block intact while
  the conditioned frame was still up (`verification/tests/test_pf_cam.py`).
  With the guard built one clock short, the test fails on every frame.
- **Note:** The block's latency is 3 clocks for frame-valid and 2 for line,
  embedded-data and pixel data. A line beat on the *first* clock of an input
  frame therefore leaves the block one clock before the conditioned frame
  rises, and nothing downstream gates it (`image_metadata.sv:114`). Whether
  the SLVS-EC receiver ever raises line-valid on frame-valid's first clock
  is a property of the encrypted receiver, which this simulation cannot
  observe; `HW-PF-CAM-04` sees the real one.

## MUX -- Frame-buffer routing

### PF-MUX-04
The camera mux shall route each accepted frame to one selected DDR4 write path.
- **Parent:** FAR-CDH_FPGA_L3REQ-13
- **Design:** ip/cam_mux_ip/src/cam_mux.sv:93-138, ip/cam_mux_ip/src/cam_mux.sv:163-187
- **Verify:** SIM
- **Rationale:** A frame duplicated to both memories or dropped from both memories breaks image-buffer accounting.
- **Status:** OK
- **Evidence:** Simulated on `cam_mux_top` at the instance's parameters, with
  a frame and beat number on every line beat. Frames sent before the first
  clear reached neither path. After it, frames 1-512 arrived whole and in
  order on the 16GB path and the next 20 on the 8GB path, with neither
  frame-valid nor a beat on the other path and never both frame-valids up
  together (`verification/tests/test_pf_mux.py`).
- **Note:** The first frame after the mux (re)starts -- after a clear, or when
  it switches to the 8GB buffer -- is forwarded only once its registered edge
  detect has seen it rise. **Its first two pixel clocks are not forwarded.** A
  frame with a beat on every clock arrived as beats 2-7 of 0-7. Once
  forwarding, the mux stays in its forwarding state between frames and every
  clock passes. Image data starts well after frame-valid (metadata is inserted
  first, `PF-META-09`), so this loses nothing today. But the margin is two
  clocks, and no requirement records it.

### PF-MUX-05
The camera mux shall defer a select or disable change until the current frame boundary.
- **Parent:** FAR-CDH_FPGA_L3REQ-13
- **Design:** ip/cam_mux_ip/src/cam_mux.sv:190-213
- **Verify:** SIM
- **Rationale:** Changing the write destination mid-frame corrupts the stored image.
- **Status:** OK
- **Evidence:** Simulated on `cam_mux_top`. The only select or enable change
  firmware can make is a clear, which enables the mux and selects 16GB; the
  others are the mux's own, at the end of a frame (`PF-MUX-08`, `-09`). A
  clear 100 clocks into a 400-clock frame: while forwarding to 16GB, that
  frame and the next went to 16GB; while forwarding to 8GB, that frame
  finished whole on 8GB and the next went to 16GB; while disabled, that frame
  went nowhere, not even in part, and the next went to 16GB
  (`verification/tests/test_pf_mux.py`).

### PF-MUX-08
The camera mux shall switch routing from the 16GB DDR4 buffer to the 8GB DDR4 buffer after the 16GB buffer is full.
- **Parent:** FAR-FB_L3REQ-2
- **Design:** ip/cam_mux_ip/src/cam_mux.sv:285-303
- **Verify:** SIM
- **Rationale:** The larger memory is filled first so the total frame capacity is used before capture stops.
- **Status:** OK
- **Evidence:** Simulated on `cam_mux_top`. "Full" is a frame count: 512
  frames for the 16GB buffer, the width of its DMA frame index. After 511
  frames the 16GB buffer did not read full and 16GB was still selected. After
  the 512th it read full with 8GB selected, and frames 513 onward all arrived
  whole on the 8GB path, none on the 16GB (`verification/tests/test_pf_mux.py`).

### PF-MUX-09
The camera mux shall stop accepting frames after the 8GB DDR4 buffer is full.
- **Parent:** FAR-FB_L3REQ-2
- **Design:** ip/cam_mux_ip/src/cam_mux.sv:285-303
- **Verify:** SIM
- **Rationale:** Continuing to write after both buffers are full would overwrite stored imagery.
- **Status:** OK
- **Evidence:** Simulated on `cam_mux_top`. After 767 frames (512 + 255) the
  mux was enabled and the 8GB buffer not full. After the 768th it read full
  and the mux disabled, and 40 further frames produced no frame-valid clock
  and no beat on either path (`verification/tests/test_pf_mux.py`).

## TRIG -- Camera trigger interface

### PF-TRIG-05
The camera trigger output shall remain inactive-high except for the commanded active-low trigger interval.
- **Parent:** FAR-FPA_L5REQ-2
- **Design:** ip/cam_trig_ip/src/cam_trig.sv:126-127
- **Verify:** SIM, INSP, HW
- **Rationale:** The camera expects an active-low trigger pulse and must not see spurious low pulses between exposures.
- **Status:** OK
- **Evidence:** Simulated on `cam_trig_top` at the instance's parameters. Three
  commands were run: 1 clock x 3 frames of 10 us, 500 clocks x 4 of 50 us, and
  49,999 clocks x 2 of 2 ms. Each gave exactly its number of low pulses, each
  exactly N x 20 ns wide (20 ns, 10 us, 999,980 ns) and exactly a frame
  period apart. `xtrig` was high at every other moment from `en` onward: 9
  falling edges for 9 commanded frames (`verification/tests/test_pf_trig.py`).
- **Note:** Before `en` (camera power-good) the output is **low**. That is
  outside "between exposures", and it is the right level towards an unpowered
  sensor. The low-to-high step at `en` is the edge the camera fault detector
  treats as a trigger (`PF-F-25`).
- **Evidence:** By inspection to the sensor connector: the trigger reaches J7
  pin 67 through U59, a non-inverting SN74LVC244 channel, and a series
  resistor. U59's enable is an FPGA output pulled up to disabled and driven
  from camera power-good, the same signal that enables `cam_trig`, so the
  sensor sees nothing until it is powered. As the buffer opens, `xtrig` is
  still low for one to two clocks -- 20 to 40 ns of uncommanded low at the
  connector -- but the sensor's reset, on the same buffer, is held low then by
  the camera GPO's reset value and flight software, so it cannot start an
  exposure (`verification/analysis/test_insp_board.py`).
- **Note:** The FPGA does not guard its own configuration. A low time of 0
  clocks wraps its comparison (`timer_cnt >= xtrig_low_cycles - 1`,
  `cam_trig.sv:141`, `:194`) and holds `xtrig` low for 2^32 clocks, about 86 s;
  simulated, it was still low after 1 ms. A low time longer than the frame
  period wraps the high period the same way. Flight software excludes both
  (`register_callbacks.c:169`, `camera_armed_state.c:188`). The IP README
  still describes `XTRIG_LOW_TIME` in microseconds; the RTL and flight
  software use 20 ns clocks.

### PF-TRIG-07
The camera trigger generator shall support continuous acquisition when the requested frame count is zero.
- **Parent:** FAR-L1REQ-27, FAR-L1REQ-30
- **Design:** ip/cam_trig_ip/src/cam_trig.sv:181-215
- **Verify:** SIM
- **Rationale:** Ground operations need an unbounded acquisition mode for checkout and calibration.
- **Status:** GAP
- **Evidence:** Simulated on `cam_trig_top`. With a frame count of 0 the
  generator triggers continuously: 100 triggers in 2 ms at a 20 us period.
  **But nothing stops it.** After each of `START` written 0, a frame count of
  1, a source of none, an interrupt clear and `en` low, it went on triggering
  every 20 us (`verification/tests/test_pf_trig.py`, failing as expected).
- **Finding:** PF-F-27
- **Note:** Re-adjudicated from `OK` on 2026-09-25 against VC-PF-0033, which
  reads the requirement as a sequence that runs "until another control input
  stops" it. An unbounded mode for checkout and calibration that only a reset
  of the whole 50 MHz fabric can end is not one ground operations can use.

### PF-TRIG-11
The camera trigger source selector shall select manual, scheduled-PPS or synchronized-LVDS start according to the ICD values.
- **Parent:** FAR-L1REQ-28, FAR-TMTC_SW_L4REQ-16, FAR-TMTC_SW_L4REQ-10
- **Design:** ip/cam_trig_ip/src/cam_trig_top.sv:130-160
- **Verify:** SIM, HW
- **Rationale:** The trigger mode selected by firmware must map to the commanded acquisition source.
- **Status:** GAP
- **ICD:** CM-01979 section 5.5.21, `TRIG_MODE_SYS_REG`, is the only ICD table
  that defines trigger-mode values: `COMMAND` 0, `EXT_GPIO` 1, `PARAM_UPDATE`
  2, `TIME` 3. Flight software writes it into `XTRIG_SRC_SEL` verbatim
  (`farsight-avionics-sw` `Camera/include/camera.h:24-35`).
- **Evidence:** All three sources are implemented and selected by `xtrig_src_sel`
  (`ip/cam_trig_ip/src/cam_trig_top.sv:152-160`): `2'b00` manual, `2'b01`
  scheduled against the PPS real-time clock, `2'b10` LVDS synchronised through a
  three-stage synchroniser, with any other encoding holding `start` deasserted.
  Simulated against the ICD's values, each value was tried with each of the
  three stimuli:
  - `COMMAND` (0) started on a manual `START`, as it should.
  - `EXT_GPIO` (1) started on the PPS time passing the schedule, not on an
    external edge.
  - `PARAM_UPDATE` (2) started on an LVDS edge.
  - `TIME` (3) started on nothing.

  (`verification/tests/test_pf_trig.py`, failing as expected.)
- **Finding:** PF-F-26
- **Note:** Re-adjudicated from `GAP`, which was recorded with no reason. The
  mechanism the requirement describes exists. What cannot be checked is the
  operative phrase "according to the ICD values": no ICD section is cited here,
  so there is nothing to compare the encodings against. Marked `AMBIG` because
  the requirement is unverifiable as written rather than unmet -- cite the ICD
  table that fixes the encoding, and this becomes decidable.
- **Note:** Re-adjudicated from `AMBIG` to `GAP` on 2026-09-25. The ICD table
  was identified as CM-01979 section 5.5.21, cited above, and the FPGA's
  encoding disagrees with it for three of its four values.

### PF-TRIG-12
The camera trigger output edge shall occur within 100 ns of its commanded time,
measured at the FPGA trigger pin, for every trigger source, over the operational
temperature range and mission life.
- **Parent:** FAR-CDH_FPGA_L3REQ-19, FAR-CDH_FPGA_L3REQ-17
- **Design:** `ip/cam_trig_ip/src/cam_trig.sv:84-85`, `ip/cam_trig_ip/src/cam_trig_top.sv:130-160`, `ip/pps_ip/src/pps.sv:258-266`
- **Kind:** Performance
- **Verify:** ANA, HW
- **Rationale:** FAR-CDH_FPGA_L3REQ-19 states 100 ns and no requirement in this
  document carried it, so the trigger path was specified behaviourally --
  `PF-TRIG-05` for polarity, `PF-TRIG-07` for count, `PF-TRIG-11` for source --
  with nothing bounding accuracy. The three sources do not have the same error:
  the scheduled source inherits PPS and oscillator error, the LVDS source
  inherits synchroniser sampling uncertainty, and the manual source inherits
  APB write latency. A single budget covering all three is what makes the
  parent verifiable, and "for every trigger source" is the operative phrase.
  FAR-CDH_FPGA_L3REQ-17 is a second parent because its "start ... within
  100 ns of trigger detection" is the same bound on the LVDS source, whose
  commanded time is the detected edge; its "stop" is `PF-TRIG-13`.
- **Status:** GAP
- **Finding:** PF-F-08, PF-F-54
- **Evidence:** Not met, by analysis per source, with the 50 MHz clock's
  +/-75 ppm (`DRV-PF-04`). **Manual:** the edge is 3 cycles, 60 ns, after the
  APB write that commands it. **LVDS:** 60 to 80 ns after the input edge,
  through the three-stage synchroniser. **Scheduled:** 60 to 80 ns after the
  RTC reads the commanded time, plus the RTC's own error. Free-running (no
  external PPS, or the local source), the RTC drifts 75 ns per ms, so the
  20 ns left is gone 0.27 ms after a time jam. With an external PPS the RTC's
  rate is re-measured every second; the loop is bounded by iterating its
  update arithmetic as `pps.sv` computes it, across -75 to +75 ppm, and
  checked against `PF-PPS-02`'s simulation. Settled, the RTC is within 69 ns
  of true time, so the scheduled edge is up to 149 ns after its commanded
  time: 49 ns over. Until it settles -- about 71 s after power-up or a change
  in the clock's offset -- the RTC is off by up to 75 us (`PF-F-54`). None of
  the figures include the pin paths, which the build does not time (`PF-F-46`)
  (`verification/analysis/test_ana_clocks.py`, failing as expected).
- **Note:** The settled 69 ns assumes `pps_rx_delay` is 2, the synchroniser's
  latency. Flight software sets it from a ground command, with no fixed value;
  each count it differs from 2 moves the RTC 20 ns. Worst-case analysis, not
  an offset-clock simulation, is the method for clock tolerance (PF V&V plan,
  VVP-PF-005).
- **Note:** **The parent is under `REVIEW` and this requirement adopts one of
  the two readings being decided.** The corrected baseline dispositions
  FAR-CDH_FPGA_L3REQ-19 `REVIEW` because it does not say whether the
  100 ns governs *commanded latency* or *absolute integration start*: the sensor
  adds a fixed pedestal of `GMRWT*HMAX/74.25MHz + 1.665 us`, about 41.6 us at the
  8 GB line rate, so on the absolute reading the design misses by roughly 400x.
  Findings `AV-F-05` and `PFW-F-11` refer.
  This requirement deliberately takes the **commanded-latency** reading, and says
  so in its statement by fixing the measurement point at the FPGA trigger pin.
  The absolute reading cannot be an obligation on this document at all -- the
  pedestal is a sensor property that no FPGA behaviour can influence, so writing
  it here would create a requirement the design cannot meet by any change. If
  the review decides on the absolute reading, the obligation belongs at system
  level and this requirement stays as the FPGA's share of it.
- **Note:** `GAP` is not in conflict with the baseline's observation that
  "commanded quantisation is 20 ns and is compliant". That is true of the manual
  source in isolation. This requirement is scoped "for every trigger source ...
  over the operational temperature range and mission life", and the scheduled
  source inherits the unbounded PPS error of `PF-PPS-09`, so the set is not
  shown compliant even though one member of it is.
- **Note:** No longer blocked on `DRV-PF-04` and `PF-PPS-09` (2026-10-02): the
  system clock is budgeted at +/-75 ppm and the local PPS accuracy stated. The
  open contributors are the disciplined RTC's residual and the pin paths.
  Formerly: the oscillator contribution could not be budgeted until a
  frequency-error figure existed, and `PF-PPS-09` was blocked on Q-06 in
  [`open-questions.md`](../../../docs/requirements/open-questions.md). This
  requirement was written then rather than deferred because it is what made them consequential --
  `DRV-PF-07` requires every clock-derived timing requirement to be checked
  against the budget, and this is the requirement that needs checking.
- **Note:** FAR-CDH_FPGA_L3REQ-14 states the matching 100 ns *knowledge*
  obligation -- reporting exposure time to the host rather than controlling it --
  and is dispositioned `DEFECT`, so it is correctly absent from the `Parent`
  field. That obligation is partly discharged by `PF-META-03`, which reports
  trigger-low duration at microsecond resolution. **Microsecond resolution
  cannot express a 100 ns accuracy**, so if FAR-CDH_FPGA_L3REQ-14 is repaired
  rather than withdrawn, `PF-META-03` and the CM-01979 section 17.4 field it
  cites both need rework. Recorded here so the dependency is not lost with the
  parent.

### PF-TRIG-13
The camera trigger output shall end each exposure pulse within 100 ns of the
commanded exposure duration after the pulse began, measured at the FPGA trigger
pin, over the operational temperature range and mission life.
- **Parent:** FAR-CDH_FPGA_L3REQ-17
- **Design:** `ip/cam_trig_ip/src/cam_trig.sv:84`, `ip/cam_trig_ip/src/cam_trig.sv:126`, `ip/cam_trig_ip/src/cam_trig.sv:193-196`
- **Kind:** Performance
- **Verify:** ANA, HW
- **Rationale:** FAR-CDH_FPGA_L3REQ-17 requires exposure to start *and stop*
  within 100 ns. The start is bounded by `PF-TRIG-12`; nothing bounded the
  stop. The FPGA times the stop itself, by counting its own clock for the
  commanded duration, so the stop edge inherits that clock's frequency error
  over the whole exposure, which no other requirement carries.
- **Status:** GAP
- **Evidence:** Not met, by analysis with the 50 MHz clock's +/-75 ppm
  (`DRV-PF-04`). The pulse is exactly the commanded number of 20 ns cycles, so
  quantisation adds nothing, but its length in time is off by the clock's
  error: +/-75 ns per ms of exposure. The 100 ns bound holds only up to
  1.333 ms; at the longest the register can command, 5.37 s, the stop is
  +/-403 us off (`verification/analysis/test_ana_clocks.py`, failing as
  expected).
- **Note:** The parent is under `REVIEW` for the same commanded-versus-absolute
  question as FAR-CDH_FPGA_L3REQ-19, and this requirement takes the reading
  `PF-TRIG-12` takes: the bound applies at the FPGA pin, to what the FPGA
  commands. On that reading the gap is the oscillator's, and meeting it would
  need the duration measured against a disciplined time base rather than
  counted on the free-running clock.

## DMAW -- DDR4 write performance and errors
### PF-DMAW-10
Each DDR4 bank shall sustain 17.4 Gbit/s sustained image write bandwidth while
it is the selected write destination, without frame loss.
- **Parent:** FAR-FB_L3REQ-1, FAR-FPA_L5REQ-5
- **Design:** `ip/dma_write_ip/src/dma_write_send_ctrl.sv`
- **Kind:** Performance
- **Verify:** ANA, SIM
- **Rationale:** This is what FAR-FB_L3REQ-1 actually requires -- "write speed at least as
  fast as frames are transferred from the FPA". Burst length, beat count and
  FIFO depth are the implementation choices made to achieve it and belong in
  the design documentation. FAR-FB_L3REQ-1 states the *relation* but no number;
  FAR-FPA_L5REQ-5 supplies the frame rate that turns it into one, which is why
  both are cited.
- **Status:** OK
- **Evidence:** Analysis only; not measured. One frame is 4581 lines
  (`farsight-avionics-sw/Camera/include/camera.h:125`) x 6784 bytes
  (`farsight-avionics-sw/Camera/include/camera.h:129`) = 31.08 MB = 248.6 Mbit,
  the same frame size used by `PFW-UDP-13`. At the 70 FPS of FAR-FPA_L5REQ-5 that
  is **17.40 Gbit/s**. The 16 GB interface presents a 512-bit AXI port at 137.5 MHz
  = 70.4 Gbit/s (4.05x margin; its user clock is 137.5 MHz, not the 150 MHz the
  design document gives -- `PF-F-28`); the 8 GB interface presents 256 bits at 150 MHz
  = 38.4 Gbit/s (2.21x margin) -- `docs/design/pf-fpga-ddr4-mig.md:24-29`. Both
  clear the requirement at the AXI boundary with margin for DRAM efficiency
  derating.
- **Evidence:** Simulated at the DMA boundary, per bank. The DUT is the DMA
  write SmartDesign as the build generates it, including its COREFIFO clock
  crossing, at the bank's real clocks. It was fed the camera's line timing
  (a line every 3.1185 us) for a 200-line steady-state window at 17.73
  Gbit/s, with 6912-byte lines, more than the 6784 of a real line. Every byte
  was written once, in order, at its line address. The worst time from a
  line's end to its write completing was 1,567 ns (8GB) and 918 ns (16GB)
  of the 3,118 ns line period (`verification/tests/test_pf_dmaw_rate.py`).
  The same test passes under QuestaSim with the vendor's precompiled PolarFire
  library, which it is qualified against. **The arbiter is ideal**, taking a beat every clock. This shows the DMA
  path sustains the rate; it does not show the DDR4 controller and memory
  do. That is the analysis and hardware's to establish.
- **Note:** Replaced the `[TBR: rate not stated by the parent]` marker on
  2026-09-17. The rate was never unknowable -- it is frame size times frame rate,
  and both numbers were already in the workspace. The TBR recorded that no
  parent stated the product, not that it could not be computed.
- **Note:** The margins differ by 2x between the two banks because their AXI
  data widths differ, so the 8 GB buffer is the sizing case. Peak AXI bandwidth
  is an upper bound: it does not account for refresh, bank conflicts or
  read/write turnaround, which is why `Verify` retains `SIM`.
  See [`HW-F-05`](../../../docs/requirements/hardware-findings.md#hw-f-05).
- **Note:** Worded *per bank* deliberately. FAR-FB_L3REQ-1 is dispositioned
  `REWORD` in the corrected baseline against exactly this defect -- it "is
  written as if there were one frame buffer and does not say which bank it
  applies to" -- and its proposed statement is *"Each frame buffer bank shall
  have a write bandwidth at least equal to the rate at which frames are
  transferred from the FPA."* This requirement is written to decompose the
  proposed statement, so applying that reword will not invalidate it.
- **Note:** Replaces `PF-DMAW-08`, which required each burst to contain no more
  than 256 AXI beats. That restated the AXI4 protocol bound rather than a
  FARSIGHT need, was not observable at the FPGA boundary, and did not constrain
  throughput.

### PF-DMAW-09
The DDR4 write DMA shall flag a stalled write transfer within 10 ms +/-5%.
- **Parent:** FAR-L1REQ-19
- **Design:** ip/dma_write_ip/src/dma_write_send_ctrl.sv:15-24, ip/dma_write_ip/src/dma_write_send_ctrl.sv:60-63
- **Kind:** Performance
- **Verify:** SIM, ANA
- **Rationale:** A stalled write path must be reported before the next image acquisition hides the failure.
- **Status:** GAP
- **Evidence:** Simulated on `dma_write_ctrl` for each bank, with the
  parameters read from the build and each bank at its PF_DDR4 user clock from
  the derived constraints.
  - **8GB bank, 150 MHz:** flagged exactly 10.000 ms after a request that was
    never acknowledged, and 10.000 ms after a burst that was acknowledged and
    never finished.
  - **16GB bank, 137.5 MHz:** flagged **10.909 ms** after each of the same two
    stalls, outside 10.5 ms.
  - **Control:** with every write answered and the frame closed, neither
    bank flagged in 11 ms.

  (`verification/tests/test_pf_dmaw.py`, failing as expected on the 16GB bank.)
- **Finding:** PF-F-28
- **Note:** Re-adjudicated from `OK` on 2026-09-25. The implementation counts
  1,500,000 cycles, which is 10.0 ms only at 150 MHz. That holds for the 8GB
  bank, whose `PF_DDR4_C2` user clock is 150 MHz. The 16GB bank's
  `PF_DDR4_C0` runs its DRAM at 550 MHz, so its user clock is 137.5 MHz
  (`CLOCK_USER:137.5`; derived constraint `-multiply_by 11 -divide_by 4`),
  and 1,500,000 cycles of it is 10.909 ms.
- **Note:** The flag is sticky: nothing but a reset of the DDR clock domain
  clears it (`dma_write_send_ctrl.sv`, `timeout_err <= timeout_err` in every
  state).

## DMAR -- DDR4 read and packetization

### PF-DMAR-08
The DDR4 read DMA shall flag a timeout when read request, active read or export completion waits exceed the configured timeout.
- **Parent:** FAR-L1REQ-19, FAR-L1REQ-21
- **Design:** ip/dma_read_ip/src/dma_read.sv:255-306
- **Verify:** SIM
- **Rationale:** A hung read path must fail visibly rather than leaving firmware waiting indefinitely.
- **Status:** GAP
- **Evidence:** Simulated on `dma_read` for each bank, with the parameters its
  SmartDesign instance sets and each bank at its PF_DDR4 user clock. Each of the
  three waits was held in turn: a request never acknowledged, a read
  acknowledged and never completed, and a completed read whose FIFO never
  drained.
  - **8GB bank, 150 MHz:** flagged 10.000 ms into each wait, and the flag
    cleared on `clear`.
  - **16GB bank, 137.5 MHz:** flagged **10.909 ms** into each wait.

  The requirement states no tolerance, so the test applies `PF-DMAW-09`'s
  +/-5% for the same 10 ms watchdog, and 10.909 ms is outside it
  (`verification/tests/test_pf_dmar.py`, failing as expected on the 16GB bank).
- **Finding:** PF-F-28
- **Note:** Re-adjudicated from `OK` on 2026-09-29. The watchdog counts
  `DDR4_CLOCK_FREQ_MHZ` x `TIMEOUT_USEC` = 1,500,000 cycles, 10.0 ms only at
  150 MHz, and the 16GB bank's user clock is 137.5 MHz. The export-completion
  wait is timed from the acknowledge, not from the read's end: the counter
  runs from the acknowledge until the FIFO empties.

### PF-DMAR-24
Each DDR4 bank shall sustain 8.0 Gbit/s sustained read bandwidth to the active
egress interface without underrun.
- **Parent:** FAR-FB_L3REQ-4
- **Design:** `ip/dma_read_ctrl_ip/src/frame_xfer_ctrl.sv`
- **Kind:** Performance
- **Verify:** ANA, SIM
- **Rationale:** This is what FAR-FB_L3REQ-4 actually requires -- "read speed at least as
  fast as the highest speed data transfer interface to the bus". Chunking and
  burst length are implementation choices made to achieve it.
- **Status:** GAP
- **Evidence:** The highest speed egress interface is **PCIe**, not Ethernet:
  Gen2 x2 carries 8.0 Gbit/s of payload against 1 Gbit/s for 1000BASE-T. Read
  bandwidth clears that in isolation -- 76.8 Gbit/s on the 16 GB bank and
  38.4 Gbit/s on the 8 GB bank (`docs/design/pf-fpga-ddr4-mig.md:24-29`) -- but
  the requirement is not shown met under concurrent capture. With the
  17.4 Gbit/s write stream of `PF-DMAW-10` active, the 8 GB bank carries
  25.4 Gbit/s against 38.4 Gbit/s of AXI bandwidth: a 1.51x margin before
  refresh, bank conflicts, read/write turnaround and DRAM efficiency derating.
- **Evidence:** Simulated at the DDR4 controller boundary, per bank:
  `eth_pcie_mux_hier` as the build generates it, at the build's clocks, with
  an ideal DDR4 (a beat every clock, a read accepted the clock after it is
  presented) and the fastest legal PCIe host (back-to-back 256-byte
  sequential reads, each presented with the last beat of the one before).
  Over 64 KB of a frame the read path delivered **6.68 Gbit/s** from the 8
  GB bank and **6.70 Gbit/s** from the 16 GB bank, under 8.0, with every
  word correct. A read's 32 beats come back to back in 213 ns, but each read
  is answered 87-107 ns after it is accepted, and `pcie_translator` takes
  one at a time. DDR4 read latency up to about 130 ns is hidden by its
  prefetch; 267 ns brings it to 6.06 Gbit/s
  (`verification/tests/test_pf_dmar_rate.py`, failing as expected).
- **Finding:** PF-F-43
- **Note:** So the requirement is not met even before concurrent capture or
  DDR4 efficiency is counted: the read path itself cannot reach 8.0 Gbit/s.
  Like `PF-DMAW-10`'s, the simulation is a boundary model and says nothing
  of the controller and DRAM.
- **Note:** Whether export is ever concurrent with capture is itself unstated.
  If the two are mutually exclusive by operating mode the margin is 4.8x and
  this closes on analysis; if they overlap, 1.51x is not acceptable by
  inspection. That question has to be answered before this can be adjudicated
  `OK`, and it is a system-level question rather than an FPGA one.
- **Note:** Revised 2026-09-17. This requirement briefly targeted 1 Gbit/s
  against Ethernet, on the reading that the PCIe path was unreachable in the
  flight build. The programme has since confirmed PCIe **is** flight
  functionality, enabled later in payload software, so the "highest speed
  interface" of FAR-FB_L3REQ-4 is PCIe and the target is 8x higher. See
  [`PF-F-22`](pf-fpga-findings.md) and `PF-PCIE-10`, which states the same rate
  at the PCIe boundary rather than at the DDR4 ports.
- **Note:** Replaces `PF-DMAR-15`, which required line reads to be split into
  chunks of no more than 256 AXI beats -- an internal AXI protocol bound rather
  than a FARSIGHT need.
- **Note:** Worded *per bank* deliberately, for the same reason as
  `PF-DMAW-10`. FAR-FB_L3REQ-4 is dispositioned `REWORD` because "the two banks
  have different data bus widths, 64-bit against 32-bit, so they have materially
  different sustained bandwidth", and its proposed statement is *"Each frame
  buffer bank shall have a read bandwidth at least equal to the sustained rate
  of the highest speed data transfer interface to the bus."* This requirement
  decomposes the proposed statement, so the reword will not invalidate it.
  Note that the proposed statement says **sustained** rate, which is what makes
  "the highest speed interface" answerable at all -- and the answer is currently
  Ethernet, per `PF-F-22`.

### PF-DMAR-16
The frame-transfer controller shall assert frame-read-done after the final requested line.
- **Parent:** FAR-CDH_FPGA_L3REQ-12, FAR-TMTC_SW_L4REQ-3
- **Design:** ip/dma_read_ctrl_ip/src/frame_xfer_ctrl.sv:437-449
- **Verify:** SIM
- **Rationale:** Firmware needs one completion indication for each image or metadata read request.
- **Status:** GAP
- **Evidence:** Simulated on the read SmartDesign as the build generates it,
  with its real COREFIFO, under QuestaSim, for each bank.
  - **Image reads of 1, 2 and 5 lines:** frame-read-done rose once, 135 ns
    after the last packet of the last line, and `FRAME_READ_DONE_COUNT` went
    up by one.
  - **A metadata read,** one line of 128 bytes: no frame-read-done within
    50 us, and the count did not move.

  (`verification/tests/test_pf_dmar.py`, failing as expected on both banks.)
- **Finding:** PF-F-29
- **Note:** Re-adjudicated from `OK` on 2026-09-29. The requirement names no
  mode; its rationale covers metadata reads, and a metadata read requests one
  line.

### PF-DMAR-18
The Ethernet image stream shall limit each packet payload to the configured standard or jumbo payload word count.
- **Parent:** FAR-L1REQ-22, FAR-CDH_FPGA_L3REQ-20
- **Design:** ip/dma_read_ctrl_ip/src/dma_read_ctrl.sv:88-95
- **Verify:** SIM
- **Rationale:** Payload sizing must respect the selected network MTU while keeping line reconstruction deterministic.
- **Status:** OK
- **Note:** The current standard and jumbo limits are 363 and 988 32-bit payload words.
- **Evidence:** Simulated on the read SmartDesign as the build generates it,
  with its real COREFIFO, under QuestaSim, for each bank. A 6784-byte line
  (1696 words) went out as 363, 363, 363, 363 and 244 payload words in standard
  mode and 988 and 708 in jumbo. The size channel gave 4 x words + 6 bytes for
  each packet. Each packet carried the `PK` token and its packet index, and the
  payload matched memory word for word (`verification/tests/test_pf_dmar.py`).

### PF-DMAR-23
The DDR4 read controller shall expose one 20-word metadata block for each metadata-mode read.
- **Parent:** FAR-TMTC_SW_L4REQ-49, FAR-CDH_FPGA_L3REQ-2
- **Design:** ip/dma_read_ctrl_ip/src/dma_read_ctrl.sv:731-760
- **Verify:** SIM
- **Rationale:** Firmware expects a fixed-size metadata block to copy into the host-visible image product.
- **Status:** GAP
- **Evidence:** Simulated on the read SmartDesign as the build generates it,
  with its real COREFIFO, under QuestaSim, for each bank.
  - **First metadata read, frame 7:** registers 18-37 held frame 7's 20
    words, after one metadata-valid pulse and no UDP packet. The read never
    completed.
  - **Second metadata read, frame 9, 50 us later:** no metadata-valid pulse;
    the registers still held frame 7's block.

  (`verification/tests/test_pf_dmar.py`, failing as expected on both banks.)
- **Finding:** PF-F-29
- **Note:** Re-adjudicated from `OK` on 2026-09-29. The block is exposed
  correctly once, but the frame-transfer controller then stays busy until its
  10 ms watchdog, so a metadata read inside that window exposes nothing, and
  its caller reads the previous block.

## PCIE -- PCIe image export

### PF-PCIE-07
The PCIe/DDR read demux shall route reads to the selected DDR4 memory.
- **Parent:** FAR-TMTC_SW_L4REQ-3
- **Design:** ip/eth_pcie_mux_ip/src/axi_read_demux.sv:217-239
- **Verify:** SIM
- **Rationale:** PCIe export must address either image buffer under firmware or host selection control.
- **Finding:** PF-F-22
- **Status:** OK
- **Evidence:** Simulated on `eth_pcie_mux_hier` as the build generates it, at
  the build's clocks, with the host's AXI master and a DDR4 slave per bank
  modelled. The host selected six bank and frame pairs by its own writes,
  including frame 255 of 8GB and frame 511 of 16GB, and read each. Every DDR
  read request went to the selected bank's port and none to the other, and
  every word returned was the selected bank's, at the selected frame and
  offset (`verification/tests/test_pf_pcie.py`).
- **Note:** The "firmware or host selection control" this requirement names is
  not yet exercised by any software. PCIe is flight functionality, but its
  enablement is allocated to **payload software** and is not yet implemented;
  the obligation is carried by `DRV-PF-11` and recorded in the
  [derived register](../../../docs/requirements/derived-register.md). See
  [`PF-F-22`](pf-fpga-findings.md), which also records that `index` and
  `ddr4_sel` are driven from the FARSIGHT side rather than by the host, so the
  owning side for those two controls still needs deciding. The same note applies
  to `PF-PCIE-08` and `PF-PCIE-09`.

### PF-PCIE-08
The PCIe translator shall reject write transactions.
- **Parent:** FAR-SERDES_L3REQ-3
- **Design:** ip/eth_pcie_mux_ip/src/pcie_translator.sv:175-191
- **Verify:** SIM
- **Rationale:** The PCIe path is an image-export interface and must not modify flight image memory.
- **Finding:** PF-F-22, PF-F-30
- **Status:** GAP
- **Evidence:** Simulated on `eth_pcie_mux_hier` as the build generates it.
  - **No DDR4 write:** no write-channel valid reached either bank's port
    across every write in the test. The rationale holds.
  - **Writes are not rejected.** Each single-beat write was answered OKAY and
    taken as a control write, decoded on address bits 3:0 alone. Writes to
    0x2000, 0x1234_5678, 0x100, 0x108 and 0x1FF_FFF0 each changed the bank
    or frame that the next read returned.
  - **A 4-beat write** was answered after its first beat, and its other three
    beats were never taken.

  (`verification/tests/test_pf_pcie.py`, failing as expected.)
- **Note:** Re-adjudicated from `OK` on 2026-09-29. The translator does refuse
  writes (`s_awready` tied low), but in the build no write reaches it:
  `axi_read_demux` in front of it answers them all.

### PF-PCIE-09
The PCIe translator shall align DDR read addresses to the configured prefetch chunk.
- **Parent:** FAR-SERDES_L3REQ-4
- **Design:** ip/eth_pcie_mux_ip/src/pcie_translator.sv:193-199
- **Verify:** SIM
- **Rationale:** Aligned prefetch keeps host reads deterministic across DDR burst boundaries.
- **Finding:** PF-F-22
- **Status:** OK
- **Note:** The current implementation aligns to a 256-byte chunk.
- **Evidence:** Simulated on `eth_pcie_mux_hier` as the build generates it,
  for each bank. Eight reads per bank from unaligned offsets, of 1 to 32
  words, three of them running into the next chunk. Every DDR read was one
  256-byte chunk at a 256-byte-aligned address (8 beats on 8GB, 4 on 16GB),
  including the next-chunk prefetch, and every word returned matched memory
  at its exact offset (`verification/tests/test_pf_pcie.py`).
- **Note:** The prefetch does not stop at the frame or the bank. A read in
  the last chunk of 16GB frame 511 prefetches `0x4_0000_0000`, past the end
  of the bank. The host cannot address it, so its data is never returned;
  what the DDR4 controller does with an address past its end was not
  simulated.
- **Note:** This requirement traces to `FAR-SERDES_L3REQ-4`, which is a *rate*
  requirement -- ">= 5 Gbps/lane" -- and is satisfied here by an address-alignment
  obligation. Alignment contributes to sustained rate but does not bound it, so
  the parent's rate is carried by `PF-PCIE-10` rather than by this requirement.
- **Note:** `FAR-SERDES_L3REQ-4` as written cannot fail. The IP is configured
  `Gen2 (5.0 Gbps)` (`bd/mpf500ts-fc1152m/pcie_hier/components/PF_PCIE_C0.tcl:29`),
  and 5.0 GT/s per lane is the PCIe Gen2 line rate by definition of the
  standard, so the requirement is met by selecting the generation. It should be
  proposed for reword to a sustained payload-throughput statement, which is what
  `PF-PCIE-10` decomposes.

### PF-PCIE-10
The PCIe image-export path shall sustain 8.0 Gbit/s of image payload at the
PCIe boundary while a frame read is in progress.
- **Parent:** FAR-SERDES_L3REQ-4
- **Design:** `ip/eth_pcie_mux_ip/src/pcie_translator.sv`, `ip/eth_pcie_mux_ip/src/pcie_translator_fifo.sv`, `bd/mpf500ts-fc1152m/pcie_hier/components/PF_PCIE_C0.tcl:29`, `:61`
- **Kind:** Performance
- **Verify:** ANA, HW
- **Rationale:** `FAR-SERDES_L3REQ-4` states ">= 5 Gbps/lane", which is the PCIe
  Gen2 line rate and is therefore satisfied by selecting Gen2 in the IP
  configuration -- a bound that cannot fail is not a bound. What the mission
  needs from this interface is sustained *payload* throughput, which the
  standard does not give: line rate is signalling, and useful rate is set by
  8b/10b coding, TLP overhead, the prefetch chunking of `PF-PCIE-09` and DDR4
  arbitration against the concurrent write stream. This requirement carries the
  parent's intent in the quantity that can actually fail.
- **Evidence:** By analysis. Gen2 x2 is 5.0 GT/s on each of 2 lanes, 8.0
  Gbit/s after 8b10b coding, and that 8.0 Gbit/s carries every byte of every
  TLP. Each TLP spends at least 20 bytes on framing, sequence number, header
  and LCRC, so even at the largest payload the standard allows, 4096 bytes,
  payload is 7.961 Gbit/s (`verification/analysis/test_ana_budgets.py`,
  failing as expected).
- **Finding:** PF-F-45
- **Status:** GAP
- **Finding:** PF-F-22
- **Evidence:** Not demonstrated. The configuration supports it in principle --
  Gen2 at 5.0 GT/s on x2 lanes is 10 GT/s raw, or **8.0 Gbit/s** of payload
  after 8b/10b -- and the DDR4 read ports clear that comfortably in isolation:
  76.8 Gbit/s on the 16 GB bank (9.6x) and 38.4 Gbit/s on the 8 GB bank (4.8x).
  **The margin that matters is against concurrent capture.** With the
  17.4 Gbit/s write stream of `PF-DMAW-10` active, the 8 GB bank carries
  25.4 Gbit/s of combined traffic against 38.4 Gbit/s of AXI bandwidth -- a
  1.51x margin before DRAM efficiency derating, refresh, bank conflicts and
  read/write turnaround are taken into account. That is not a margin that can be
  accepted by inspection, which is why `Verify` is `ANA, HW`.
- **Note:** `GAP` rather than `AMBIG` because no software currently exercises
  the path, so the figure cannot be measured on the present build. PCIe
  enablement is allocated to payload software -- see `DRV-PF-11` and
  [`PF-F-22`](pf-fpga-findings.md). The requirement is written now rather than
  deferred precisely so the gap is visible in the trace matrix instead of living
  only in a finding.
- **Note:** Whether both lanes are active needs confirming before this number is
  accepted. The core is configured `x2`
  (`bd/mpf500ts-fc1152m/pcie_hier/components/PF_PCIE_C0.tcl:61`) and both lane
  pin pairs are wired at the top level
  (`bd/mpf500ts-fc1152m/top/components/top.tcl:802-805`), which is consistent
  with x2. If the link trains at x1, the figure halves to 4.0 Gbit/s.

### DRV-PF-11
The PCIe image-export path shall be enabled, and its frame index, bank
selection and egress routing set, by an external agent before a PCIe image
read is issued.
- **Source decision:** The PCIe read path was implemented so that the host
  supplies only the offset within a frame, while frame index, bank selection and
  egress routing are set from the FARSIGHT side. PCIe enablement was then
  allocated to payload software, to be added in a later increment, and
  explicitly not to PolarFire firmware.
- **Imposes on:** payload software, PolarFire firmware, system design, verification
- **Design:** `ip/eth_pcie_mux_ip/src/pcie_translator.sv:33`, `:194`, `ip/eth_pcie_mux_ip/src/axi_read_demux.sv:13`, `:162`, `farsight-avionics-sw/Camera/include/gpio_pin_def.h:9`
- **Verify:** INSP, HW
- **Rationale:** PCIe is flight functionality whose enabling software does not
  exist yet, in a component outside this requirement set. Without this
  requirement the obligation is recorded nowhere: `PF-PCIE-07`, `-08`, `-09` and
  `PF-PCIE-10` describe a path, and the reader is left to assume some software
  drives it. That is exactly the handover the derived register exists to catch,
  and catching it at decision time is the entire point.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Finding:** PF-F-22
- **Status:** GAP
- **Evidence:** Not met. No FARSIGHT-side software writes `ETH_PCIE_SEL`
  (`farsight-avionics-sw/Camera/src/camera.c:258` initialises the GPIO and never
  writes it), and the payload-software increment that is to own PCIe is not yet
  written.
- **Evidence:** By inspection: the frame offset is the PCIe read address, and
  bank and frame index are registers the host writes over a PCIe BAR
  (`axi_read_demux.sv:162-163`, driven from `pcie_hier_inst:AXI_0_MASTER`,
  `top.tcl:872`), so those three have an agent and a path. `ETH_PCIE_SEL` does
  not: flight firmware initialises its GPIO (`camera.c:258`) and writes it
  nowhere, and only the lab functional-test firmware sets it
  (`support/sw/src/main.c:642`) (`verification/analysis/test_insp_interfaces.py`,
  failing as expected).
- **Note:** **"Payload software" does not by itself close this.** Of the four
  controls that determine what a PCIe read returns, only the intra-frame offset
  is host-supplied. `index` is a translator input port, `ddr4_sel` is written
  over the block's AXI slave, and `ETH_PCIE_SEL` is a PolarFire GPIO that
  payload software cannot write directly. Whichever side is made responsible for
  those three, the allocation needs stating -- and if any of them falls to
  PolarFire firmware, a matching `PFW-` requirement follows and the "not PFW"
  allocation needs qualifying.
- **Note:** CM-01979 section 22, the PCIe data transfer interface definition, is
  a one-line stub (`docs/icd/CM-01979_ICD_FLIGHT_SOFTWARE_FARSIGHT.md:2554-2555`).
  Payload software cannot implement against it as written. Filling it is a
  prerequisite for discharging this requirement, not a documentation tidy-up.

## FOCUS -- Focus mechanism boundary

### PF-FOCUS-01
The focus mechanism interface shall suppress both physical step outputs while the watchdog is inactive.
- **Source decision:** A watchdog was adopted to bound stepper motion if firmware stops servicing the focus interface.
- **Design:** ip/focus_mech_ip/hw/ip/focus_mech_ip/components/focus_mech.tcl:490-495
- **Verify:** SIM, HW
- **Rationale:** The mechanism must not move without an active firmware watchdog lease.
- **Imposes on:** FPGA design, PolarFire firmware, verification
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Evidence:** Simulated on `focus_mech` as the build generates it, at 50
  MHz, driven over its APB ports as flight software drives it (arming,
  refresh, the 4,882,813 step overflow), and measured at the pads, past the
  watchdog's AND gates. Both motors were commanded at full speed. Never
  armed: 66 steps commanded per motor in 200 us, none at either pin. Armed:
  all 66 reached each pin. After the lease expired: 66 commanded, none at
  either pin (`verification/tests/test_pf_focus.py`).

### PF-FOCUS-08
The stepper pin interface shall provide at least 3.0 us between step assertions.
- **Source decision:** The DRV8434 stepper driver was selected; its step-pulse timing minima are imposed by the device datasheet, not by any FARSIGHT need.
- **Design:** ip/focus_mech_ip/hw/ip/stepper_ip/src/STEP_DIR.sv:39-47, ip/focus_mech_ip/hw/ip/stepper_ip/src/STEP_DIR.sv:106-177
- **Kind:** Performance
- **Verify:** SIM, ANA, HW
- **Rationale:** The stepper driver needs a minimum interval to recognize distinct movement commands.
- **Imposes on:** FPGA design, verification, board design
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Note:** The current implementation uses 150 cycles at 50 MHz, or 3.0 us.
- **Evidence:** Simulated on `focus_mech` as the build generates it, at 50
  MHz, driven over its APB ports as flight software drives it (arming,
  refresh, the 4,882,813 step overflow), and measured at the pads, past the
  watchdog's AND gates. Across full-speed motion both ways, slow motion, and
  38 direction reversals per motor, 138 steps each, the shortest time
  between step assertions was 3.020 us on each motor
  (`verification/tests/test_pf_focus.py`). By analysis, 151 cycles are
  3.019774 us with the clock +75 ppm fast (`DRV-PF-04`), +19.8 ns over the
  bound, and +1020 ns over the DRV8434's own 2.0 us (500 kHz) minimum period
  (SLOSE47A section 6.6; `verification/analysis/test_ana_budgets.py`).
- **Finding:** PF-F-53

### PF-FOCUS-09
The stepper pin interface shall hold each step-low interval for at least 1.5 us.
- **Source decision:** The DRV8434 stepper driver was selected; its step-pulse timing minima are imposed by the device datasheet.
- **Design:** ip/focus_mech_ip/hw/ip/stepper_ip/src/STEP_DIR.sv:41-47, ip/focus_mech_ip/hw/ip/stepper_ip/src/STEP_DIR.sv:86-105
- **Kind:** Performance
- **Verify:** SIM, ANA, HW
- **Rationale:** The stepper driver needs a minimum pulse width at the external pin.
- **Imposes on:** FPGA design, verification, board design
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** GAP
- **Note:** The current implementation uses 75 cycles at 50 MHz, or 1.5 us.
- **Evidence:** Simulated on `focus_mech` as the build generates it, at 50
  MHz, driven over its APB ports as flight software drives it (arming,
  refresh, the 4,882,813 step overflow), and measured at the pads, past the
  watchdog's AND gates. Over the same motion as `PF-FOCUS-08`, the shortest
  step-low interval was 1.500 us on each motor, and the shortest step-high
  1.520 us (`verification/tests/test_pf_focus.py`). By analysis with the
  system clock's +/-75 ppm (`DRV-PF-04`), the 75 cycles are 1.499887 us when
  the clock is fast, 0.11 ns short. Against the DRV8434's own 970 ns step-low
  and step-high minima (SLOSE47A section 6.6) the margin is +530 ns and +550 ns
  (`verification/analysis/test_ana_budgets.py`, failing as expected).
- **Note:** The margin is zero. The low interval is exactly 75 cycles, so it
  meets 1.5 us at 50 MHz and falls below it if the clock runs at all fast.
- **Note:** Re-adjudicated from `OK` on 2026-10-02 by owner decision. The bound
  as written is missed under the clock budget, though the driver is not at
  risk; the 1.5 us is a design margin over the datasheet's 970 ns, not the
  datasheet's figure.
- **Finding:** PF-F-53

### PF-FOCUS-10
The stepper pin interface shall provide at least 0.3 us of direction setup before a step pulse.
- **Source decision:** The DRV8434 stepper driver was selected; its direction-setup minimum is imposed by the device datasheet.
- **Design:** ip/focus_mech_ip/hw/ip/stepper_ip/src/STEP_DIR.sv:40-47, ip/focus_mech_ip/hw/ip/stepper_ip/src/STEP_DIR.sv:67-85
- **Kind:** Performance
- **Verify:** SIM, ANA, HW
- **Rationale:** The stepper driver needs direction stable before motion is commanded.
- **Imposes on:** FPGA design, verification, board design
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Note:** The current implementation uses 15 cycles at 50 MHz, or 0.3 us.
- **Evidence:** Simulated on `focus_mech` as the build generates it, at 50
  MHz, driven over its APB ports as flight software drives it (arming,
  refresh, the 4,882,813 step overflow), and measured at the pads, past the
  watchdog's AND gates. Over 38 direction reversals per motor, including
  reversals written just after a step, the shortest time from a direction
  change to the next step was 0.380 us on each motor. The shortest from a
  step to a direction change after it was 0.320 us
  (`verification/tests/test_pf_focus.py`). By analysis, the setup and the
  hold are each at least 16 cycles, 320 ns with the clock +75 ppm fast
  (`DRV-PF-04`): +20.0 ns over the bound, and +120 ns over the DRV8434's own
  200 ns DIR setup and hold minima (SLOSE47A section 6.6;
  `verification/analysis/test_ana_budgets.py`).
- **Note:** The datasheet's setup and hold apply to the MODEx pins too. Those
  are not timed by the FPGA; flight software sets the mode with the motor
  stopped (`PF-F-53`).
- **Finding:** PF-F-53

### PF-FOCUS-12
The focus watchdog shall reload its timeout when firmware clears or refreshes it.
- **Source decision:** Same watchdog decision as PF-FOCUS-01.
- **Design:** ip/focus_mech_ip/hw/ip/watchdog_ip/src/watchdog.sv:66-86
- **Verify:** SIM
- **Rationale:** Firmware must extend a valid focus-control lease without toggling the mechanism outputs.
- **Imposes on:** FPGA design, PolarFire firmware
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Evidence:** Simulated on `focus_mech` as the build generates it, at 50
  MHz, driven over its APB ports as flight software drives it (arming,
  refresh, the 4,882,813 step overflow), and measured at the pads, past the
  watchdog's AND gates. With a 2 ms lease, a refresh 1.5 ms in moved the
  expiry to exactly 2.000 ms after the refresh; a clear (CLEAR = 1, then 0)
  1.55 ms in moved it to exactly 2.000 ms after the clear. A refresh after
  expiry did not make the watchdog active again: only arming does
  (`verification/tests/test_pf_focus.py`).

### PF-FOCUS-13
The focus watchdog shall report inactive when its programmed timeout expires.
- **Source decision:** Same watchdog decision as PF-FOCUS-01.
- **Design:** ip/focus_mech_ip/hw/ip/watchdog_ip/src/watchdog.sv:112-120
- **Verify:** SIM, HW
- **Rationale:** Expired focus authority must remove motion permission at the external step outputs.
- **Imposes on:** FPGA design, PolarFire firmware
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Evidence:** Simulated on `focus_mech` as the build generates it, at 50
  MHz, driven over its APB ports as flight software drives it (arming,
  refresh, the 4,882,813 step overflow), and measured at the pads, past the
  watchdog's AND gates. Leases of 1, 2, 5 and 100 ms, the last the flight
  value, each went inactive exactly on time, and the status register read
  active after arming and inactive after expiry
  (`verification/tests/test_pf_focus.py`).
- **Note:** The timeout register holds milliseconds in 27 bits, but their
  product with 50,000 cycles is also held in 27 bits, so only 1 to 2,684 ms
  program correctly. TIMEOUT_MS 2685 programs 0.6 ms, and 3000 programs
  315.6 ms. Flight software writes 100. See `PF-F-31`.

### DRV-PF-12
The LVDT readout shall attenuate the component at twice the excitation frequency by at least 90 dB (TBR), relative to its DC response, in the I and Q outputs of both coils.
- **Source decision:** LVDT position is measured by synchronous (I/Q) demodulation in the fabric. Mixing the coil signal with the excitation puts a component at twice the excitation frequency onto every I/Q output, at the same amplitude as the wanted DC term. The firmware reads single snapshots of those outputs and does no averaging of its own (`farsight-avionics-sw/Camera/src/hal/hal_lvdt.c:119-127`, `:250-263`).
- **Design:** ip/focus_mech_ip/hw/ip/lvdt_ip/components/LOCK_IN_CHAIN.tcl:69-298, ip/focus_mech_ip/hw/ip/lvdt_ip/src/DECIMATOR.sv:60-93, ip/focus_mech_ip/hw/ip/lvdt_ip/components/SIN_COS_GEN.tcl:14-16
- **Kind:** Performance
- **Verify:** SIM, ANA
- **Rationale:** Whatever survives of the 2f component goes straight into each position read as noise, as a fraction of the reading.
  - The worst case is a ripple of 2 x the attenuation ratio of the reading, when primary and secondary ripples arrive in antiphase.
  - Keeping that under 0.1 um at the 1150 um end of travel needs a ratio of 4.3e-5, about 87 dB. 90 dB adds a small margin.
  - 0.1 um is a fifth of the 0.5 um rms single-read budget proposed in `DRV-PFW-02`, so the FPGA filter is not the dominant term.
  - The bound is TBR because it inherits from `DRV-PFW-02`, which is itself proposed, not baselined.
- **Imposes on:** PolarFire FPGA design, PolarFire firmware, verification
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** GAP
- **Evidence:** Not met, by analysis and by simulation of `LVDT_READOUT` as built.
  - The excitation is 50 MHz / 2^14 = 3051.76 Hz, so the component is at 6103.5 Hz.
  - With the decimator as designed (/5, 18.38 kS/s), the band-stop and low-pass sections attenuate 6103.5 Hz by 187.6 dB relative to DC.
  - The decimator as built divides by 4 (`PF-F-38`), giving 22.98 kS/s. There the same coefficients attenuate it by 62.7 dB (`verification/analysis/test_ana_budgets.py`, failing as expected).
  - Simulated on `LVDT_READOUT` as the build generates it, with a datasheet model of the ADC128S102 on its SPI pins applying a sine at the excitation frequency to each coil's channel: the 2f component in the four I/Q outputs is 62.6 to 62.7 dB below each coil's DC response, the outputs update at 22.95 kS/s, and each coil is sampled at 91.9 kS/s (`verification/tests/test_pf_lvdt.py`, failing as expected).
  - With `DECIMATOR.sv` corrected as `PF-F-38` recommends, the same simulation measured 112 to 128 dB, so the requirement is met by that fix.
- **Open question:** The 0.1 um allocation assumes 1 um of mechanism travel moves the focal plane 1 um. Firmware assumes that too: its thin-lens model maps target range straight to LVDT microns (`farsight-avionics-sw/Camera/src/focus.c:196-228`). Optics should confirm it.

### PF-FOCUS-16
The PolarFire design shall give firmware control of each focus stepper
driver's step, direction, enable, sleep, microstep-mode, decay, off-time and
current-reference inputs.
- **Parent:** FAR-CDH_FPGA_L3REQ-23
- **Design:** `ip/focus_mech_ip/hw/ip/stepper_ip/components/STEPPER_DRIVER.tcl:180-200`, `ip/focus_mech_ip/hw/ip/focus_mech_ip/components/focus_mech.tcl:491-562`, `bd/mpf500ts-fc1152m/top/components/top.tcl:747-768`
- **Verify:** INSP
- **Rationale:** FAR-CDH_FPGA_L3REQ-23 requires firmware to manage actuation of
  the focus mechanism. Firmware reaches the two DRV8434 drivers only through
  the fabric, so every driver input it must set has to be driven from
  something firmware can write: a register, or the step generator it
  programs.
- **Status:** OK
- **Evidence:** By inspection. On both motors, each driver input pin traces
  back through its output buffer (and, for step, the watchdog's AND gate) to a
  `STEPPER_DRIVER` output, which is a bit of the APB GPIO `STEPPER_CONTROLS`,
  the step generator fed by `STEPPER_OUT` and `STEPPER_OVERFLOW`, or the
  `VREF_PWM` generator; each of those APB slaves is on the processor's bus
  (`verification/analysis/test_insp_interfaces.py`). Step and direction are
  also simulated driven over APB, under `PF-FOCUS-07` to `-10`
  (`verification/tests/test_pf_focus.py`).
- **Note:** The corrected baseline dispositions FAR-CDH_FPGA_L3REQ-23
  `UNBUILT`, on the grounds that focus actuation "is not implemented in the
  scoped PolarFire firmware". That scope was the lab test harness
  (`farsight-fpga/support/sw`), which A-13 found the firmware set had been
  adjudicated against in error. The flight firmware does actuate focus
  (`farsight-avionics-sw/Camera/src/Focus_States/`,
  `Camera/src/hal/hal_stepper.c`), and the fabric half is built, so the
  disposition should be revisited.

## VER -- FPGA image identification

### PF-VER-01
The hardware-version APB registers shall expose the build version and the source
control commit identifier of the image.
- **Parent:** FAR-AB_L2REQ-6, FAR-CDH_FPGA_L3REQ-21
- **Design:** `ip/hw_version_ip/template/hw_version_apb_reg.sv.template:39-51`, `synth.tcl:162-175`
- **Verify:** SIM, HW
- **Rationale:** Version and commit identifier are what tie a running image back
  to the source that produced it. The commit identifier does this completely --
  given it, the source is known exactly.
- **Status:** OK
- **Evidence:** The register block was generated by the build's own procs
  (`proj::copy_template`, `proj::update_build_params`) run under `tclsh` with
  the arguments `synth.tcl` passes, then simulated and read over APB. For
  three builds -- version 2.0.1.4 with this checkout's commit as
  `synth.tcl:88` derives it, 255.255.255.255 with `00a1b2c3`, and 0.0.0.1 with
  `fedcba98` -- `0x00` read back the version one byte per field and `0x04` the
  commit, exactly. Writes changed neither (`verification/tests/test_pf_ver.py`).
- **Finding:** PF-F-32
- **Note:** Re-adjudicated from `GAP` on 2026-09-30. It was `GAP` because the
  block also exposes a build time, which this requirement does not ask for.
  That is not a failure to expose the version and commit, and the build
  time's harm, a bitstream that cannot be reproduced, is `PF-VER-02`'s. What
  does weaken this requirement's rationale is the build's, not the
  registers': `synth.tcl` takes the commit from `HEAD` without checking for
  uncommitted changes, so an image built from a modified tree names a commit
  that is not its source (`PF-F-32`).
- **Note:** The build timestamp was removed from this requirement. It is
  currently implemented -- `BUILD_TIME_UTC_SEC` at register offset `0x08`,
  populated from wall-clock time by `synth.tcl:175` -- and it should be removed
  from the design. It adds nothing to identification that the commit identifier
  does not already provide, and it makes the bitstream non-reproducible: see
  `PF-VER-02` and [`PF-F-21`](pf-fpga-findings.md).

### PF-VER-02
Two builds of the same source, with the same toolchain and the same build
configuration, shall produce identical programming files.
- **Source decision:** The build injects wall-clock time into a synthesised `localparam`, so two builds of identical source produce different netlists.
- **Imposes on:** FPGA design, build and release engineering
- **Design:** `synth.tcl:162-175`
- **Verify:** INSP
- **Rationale:** Reproducibility is what lets a programming file be checked
  against the source it claims to come from. Without it there is no way to tell
  whether two images differ because the design changed or because they were
  built at different times, and no way to confirm that the image about to be
  flown is the one that was verified.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** GAP
- **Evidence:** Not met, by inspection. `synth.tcl:86` takes the wall-clock
  time, `:175` passes it to the version block's template, where it becomes the
  synthesised constant `BUILD_TIME_UTC_SEC`
  (`ip/hw_version_ip/template/hw_version_apb_reg.sv.template:51`), which is
  read over APB (`:102`) and so kept in the netlist: two builds a second apart
  differ. Only one programming file is retained for any commit, so no byte
  comparison has been made (`verification/analysis/test_insp_build.py`,
  failing as expected).
- **Note:** Not met. `synth.tcl:175` injects wall-clock time into
  `BUILD_TIME_UTC_SEC`, which is a `localparam` in synthesised RTL, so every
  build produces a different netlist and a different programming file from
  identical source. Removing the timestamp is the fix; the build time belongs
  in the retained build artefact (clause 1 of the [FPGA Build and Disposition
  Plan](../../../docs/plans/fpga-build-and-disposition-plan.md)), where it is recorded without
  altering the image.
- **Note:** A second potential source of variation needs checking rather than assuming: both FPGA builds create a timestamped Libero project directory (`synth.tcl:64-71`). Whether Libero embeds the project or design name in the programming file determines whether that also defeats reproducibility. Confirm before closing.
- **Note:** The housekeeper does not have this defect: its `fw_version` is a constant (`src/health_monitor.sv:486`) and no build metadata is synthesised into its RTL.
## META -- Image metadata

### PF-META-01
The image metadata block shall use the host-visible format defined in
CM-01979 section 17.4.
- **Parent:** FAR-CDH_FPGA_L3REQ-2
- **Design:** ip/image_metadata_ip/src/image_metadata_apb_reg.sv:68-73
- **Verify:** SIM, INSP
- **Rationale:** The host converter and archive pipeline need a fixed metadata header contract.
- **Status:** GAP
- **Evidence:** Simulated on `image_metadata_top`, the block `cam_rx_hier`
  instantiates, with its real CDC FIFO, under QuestaSim, at the build's
  clocks, with the RTC, the sensor's `cam_tout` and frame, and firmware's
  register writes modelled, and read at `cam_data_out`. For four frames
  across both devices and the three trigger modes, the record was two beats,
  20 words in ICD order, with the second beat's spare 128 bits zero: the
  start flag, the size 0x50, the trigger mode, both padding words zero, and
  each of the ten firmware fields at its offset. `BUFF_WRITE_INDEX` is not:
  on the 8 GB device it read 0x206 for index 5 and 0x200 for 255, where
  section 23.2 gives 0x0-0xFF (`verification/tests/test_pf_meta.py`, failing
  as expected).
- **Evidence:** By inspection against section 23.2: the RTL register map, the
  lab and flight firmware headers and the host converter each have the 20
  fields at their offsets and widths, the RTL packs them in that order into
  its 640-bit output, and the start flag and size are the ICD's. The field at
  0x40 is named `VERSION` in the RTL and both firmware headers and
  `PF_FPGA_VERSION` in the ICD and the converter
  (`verification/analysis/test_insp_interfaces.py`, failing as expected;
  `PF-F-52`).
- **Finding:** PF-F-34, PF-F-52
- **Note:** Re-adjudicated from `OK` on 2026-10-01. The 8 GB encoding
  matches the command interface's single 0-0x2FF frame space, which section
  23.2 says does not exist; the ICD contradicts itself (`PF-F-34`).
- **Note:** In CM-01979 revWIP the metadata layout is section 23.2, "Image
  metadata"; section 17.4 is the register map. This requirement, `PF-
  META-03` and `PF-META-04` cite 17.4, and their items with them. The tests
  use 23.2. The citations should be corrected.

### PF-META-02
The image metadata block shall include a reflected IEEE CRC32 covering the metadata payload.
- **Source decision:** A CRC was added over the metadata payload to detect corruption in transit; no parent requirement asks for metadata integrity checking.
- **Design:** ip/image_metadata_ip/src/image_metadata_apb_reg.sv:116-153
- **Verify:** SIM
- **Rationale:** The receiver needs an integrity check for metadata transported inside the image stream.
- **Imposes on:** FPGA design, host tooling, ICD
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** GAP
- **Evidence:** Simulated on `image_metadata_top`, the block `cam_rx_hier`
  instantiates, with its real CDC FIFO, under QuestaSim, at the build's
  clocks, with the RTC, the sensor's `cam_tout` and frame, and firmware's
  register writes modelled, and read at `cam_data_out`. With the RTC live,
  as built, in four records with different payloads the CRC word never
  equalled the reflected IEEE CRC32 of the 18 words sent with it, and it
  changed with the payload. With the RTC frozen, it equalled it every time:
  the algorithm and coverage are right, and the CRC is of the block one
  clock before the one sent (`verification/tests/test_pf_meta.py`, failing
  as expected).
- **Finding:** PF-F-33
- **Note:** Re-adjudicated from `OK` on 2026-10-01. The CRC covers words
  1-18, the block without its start flag and without itself, little-endian
  bytes. Section 23.2 does not say what it covers; it should.

### PF-META-03
The image metadata block shall report camera trigger-low duration with
microsecond resolution, in the field defined by CM-01979 section 17.4.
- **Parent:** FAR-TMTC_SW_L4REQ-49
- **Design:** ip/image_metadata_ip/src/image_metadata_apb_reg.sv:181-217
- **Verify:** SIM, HW
- **Rationale:** Exposure timing in the science product must be traceable to the actual trigger observed by FPGA logic.
- **Status:** OK
- **Evidence:** Simulated on `image_metadata_top`, the block `cam_rx_hier`
  instantiates, with its real CDC FIFO, under QuestaSim, at the build's
  clocks, with the RTC, the sensor's `cam_tout` and frame, and firmware's
  register writes modelled, and read at `cam_data_out`. `cam_tout` held low
  for 1.0, 10.4, 10.6, 99.7, 1000.0 and 4321.3 us gave `SENSOR_EXPO_USEC`
  (byte 0x1C) 1, 10, 11, 100, 1000 and 4321: the low time rounded to the
  nearest microsecond (`verification/tests/test_pf_meta.py`).

### PF-META-04
The image metadata block shall report the DDR frame index associated with the
stored image, in the field defined by CM-01979 section 17.4.
- **Parent:** FAR-CDH_FPGA_L3REQ-3
- **Design:** ip/image_metadata_ip/src/image_metadata_apb_reg.sv:260-267
- **Verify:** HW
- **Rationale:** Ground processing needs the metadata to identify the buffer location of the image it describes.
- **Status:** OK


### PF-META-09
The image pipeline shall insert one metadata record ahead of camera image data.
- **Parent:** FAR-TMTC_SW_L4REQ-49, FAR-CDH_FPGA_L3REQ-2
- **Design:** ip/image_metadata_ip/src/image_metadata.sv:229-321
- **Verify:** SIM, HW
- **Rationale:** The host expects metadata in-band with each image product.
- **Status:** OK
- **Note:** The current implementation emits two 384-bit metadata chunks before camera pass-through resumes.
- **Evidence:** Simulated on `image_metadata_top`, the block `cam_rx_hier`
  instantiates, with its real CDC FIFO, under QuestaSim, at the build's
  clocks, with the RTC, the sensor's `cam_tout` and frame, and firmware's
  register writes modelled, and read at `cam_data_out`. For three frames of
  four lines, each with the first line one line period (3.1 us) after frame
  valid, there was exactly one record per frame, 303 ns after frame valid,
  and every beat of every image line arrived intact after it
  (`verification/tests/test_pf_meta.py`).
- **Note:** The record needs about 330 ns, 26 pixel clocks, after frame
  valid. A first line that comes sooner is overwritten: at 300 ns one image
  beat was lost, and at 200 and 100 ns the record landed inside the first
  line and two beats were lost. How soon the sensor's first line follows
  frame start is for the hardware item to measure.

### PF-META-10
The FPGA shall detect the end of each exposure, the rising edge of the sensor's
exposure output, within 100 ns of that edge reaching the FPGA pin.
- **Parent:** FAR-CDH_FPGA_L3REQ-18
- **Design:** `ip/image_metadata_ip/src/image_metadata_apb_reg.sv:163-172`, `ip/image_metadata_ip/src/image_metadata_apb_reg.sv:181-217`
- **Kind:** Performance
- **Verify:** ANA, HW
- **Rationale:** FAR-CDH_FPGA_L3REQ-18 requires exposure stop detected within
  100 ns. The sensor, not the FPGA, ends integration and signals it on its
  exposure output (`cam_tout`); the FPGA's share is how late it recognises
  that edge, which is set by its synchroniser and clock.
- **Status:** OK
- **Evidence:** By analysis. `cam_tout` passes a two-stage synchroniser on the
  50 MHz clock, and the rise is acted on -- the measured exposure latched -- on
  the edge after it is seen: 40 to 60 ns after the pin, or up to 80 ns when
  the first stage resolves late, with the clock +/-75 ppm (`DRV-PF-04`)
  changing that by 6 ps. Margin 20 ns
  (`verification/analysis/test_ana_clocks.py`).
- **Note:** The figure excludes the input path from pin to synchroniser, which
  the build does not time (`PF-F-46`). The parent is under `REVIEW`; this
  requirement reads "detect" as the FPGA recognising the sensor's own stop
  signal, the only stop the FPGA can observe.

## TEMP -- Temperature telemetry

### PF-TEMP-01
The FPGA junction-temperature monitor shall remain enabled during normal operation.
- **Parent:** FAR-L1REQ-20
- **Design:** ip/junc_temp_ip/src/junc_temp.sv:42-52
- **Verify:** HW
- **Rationale:** Thermal telemetry must be available without a separate enable command.
- **Status:** OK

### PF-TEMP-02
The FPGA junction-temperature APB register shall update only from valid temperature-monitor samples.
- **Parent:** FAR-L1REQ-20
- **Design:** ip/junc_temp_ip/src/junc_temp_apb_reg.sv:50-58
- **Verify:** HW
- **Rationale:** Firmware needs temperature telemetry free of samples from unrelated monitor channels.
- **Status:** OK

## PPS -- Timekeeping

### PF-PPS-02
The PPS discipline logic shall ignore external PPS periods outside the accepted tolerance window.
- **Parent:** FAR-TMTC_SW_L4REQ-49
- **Design:** ip/pps_ip/src/pps.sv:124-145
- **Verify:** SIM, HW
- **Rationale:** Glitches or missed pulses must not corrupt mission time.
- **Status:** OK
- **Evidence:** Simulated on `pps_hier` as the build generates it. Three
  10 us glitches, a 0.499 s period and a 1.501 s period were each rejected:
  the phase and frequency errors stayed 0, `pps_out` kept rising exactly 1 s
  apart, and `nanoseconds` ran on at 20 ns a clock straight through every
  edge. A control edge 0.900 s later was accepted, and its frequency error was
  exactly the predicted -625,000 clocks
  (`verification/tests/test_pf_pps_discipline.py`).
- **Finding:** PF-F-23 -- an armed time-jam is not subject to this window.
- **Note:** The current accepted window is +/-50% of the nominal PPS period.

### PF-PPS-04
The PPS time-jam command shall load the requested time on the next PPS edge.
- **Parent:** FAR-TMTC_SW_L4REQ-49
- **Design:** ip/pps_ip/src/pps.sv:209-215, ip/pps_ip/src/pps.sv:258-266
- **Verify:** SIM, HW
- **Rationale:** Ground-set time must align to the external or local one-pulse-per-second boundary.
- **Status:** OK
- **Evidence:** Simulated on `pps_hier`. While armed, the time did not load
  over 20 us with no edge, or on a falling edge. It loaded three clocks after
  the next rising edge, which is the synchroniser latency: `seconds` took the
  requested value and `nanoseconds` took the 7-clock receive delay as 140 ns.
  A second rising edge did not reload it
  (`verification/tests/test_pf_pps_jam_irq.py`). Only the external source was
  exercised; `PF-PPS-08` shows the local source reaching the same input.
- **Finding:** PF-F-23 -- the edge a jam loads on may be a glitch.


### PF-PPS-06
The PPS interface shall raise an interrupt on an external PPS rising edge.
- **Parent:** FAR-GPOI_TMTC_L3REQ-3
- **Design:** ip/pps_ip/src/pps.sv:352-364
- **Verify:** SIM, INSP, HW
- **Rationale:** Firmware needs a boundary event to correlate image acquisition time.
- **Status:** OK
- **Evidence:** Simulated on `pps_hier`. Three external rising edges raised
  the interrupt three times, each 50 ns after its edge. It stays set until
  written clear, and a held-high input does not set it again. Selecting the
  local source -- a rising edge at the discipline input -- does not raise it,
  and external edges still do with the local source selected
  (`verification/tests/test_pf_pps_jam_irq.py`).
- **Evidence:** By inspection to the bus connector: pin N4 is driven by
  receiver U56 (SN65LVDS32) from the bus pair, with `PPS_P` on its
  non-inverting input and `PPS_N` on its inverting one, from J1 pins 3 and 4.
  So a rising edge of the bus PPS is a rising edge at the PPS block, and the
  interrupt marks the bus PPS's leading edge
  (`verification/analysis/test_insp_board.py`).

### PF-PPS-07
The local PPS generator shall produce a 1 Hz pulse with 50% duty cycle.
- **Parent:** FAR-TMTC_SW_L4REQ-49
- **Design:** ip/pps_ip/src/pps_generator.sv:14-50
- **Kind:** Performance
- **Verify:** SIM, ANA
- **Rationale:** The payload needs a fallback timing source when external PPS is unavailable.
- **Status:** OK
- **Evidence:** Simulated on `pps_hier` with the local source selected: low
  for exactly 500,000,000 ns, then high for exactly 500,000,000 ns, with a
  falling-to-falling period of exactly 1 s -- 50,000,000 clocks of 20 ns. The
  discipline input followed it edge for edge
  (`verification/tests/test_pf_pps_local.py`). This is in clock time; the
  accuracy of the clock is `PF-PPS-09`.

### PF-PPS-08
The PPS mux shall select either local or external PPS according to the firmware control bit.
- **Parent:** FAR-TMTC_SW_L4REQ-49
- **Design:** ip/pps_ip/src/pps_mux.sv:1-9
- **Verify:** SIM, INSP, HW
- **Rationale:** Firmware must choose the timing source without rewiring the board.
- **Status:** OK
- **Evidence:** Simulated on `pps_hier`. With the control bit clear, the
  discipline input changed exactly when the external input did, and not at the
  local generator's falling edge. With it set, it changed exactly at the local
  generator's rising edge, and at none of the external input's
  (`verification/tests/test_pf_pps_local.py`).
- **Evidence:** By inspection to the bus connector: the mux's external input is
  pin N4, the bus PPS through receiver U56, uninverted, from J1 pins 3 and 4
  (`verification/analysis/test_insp_board.py`).

### PF-PPS-09
The local PPS generator output shall have a stated frequency accuracy across the full operating temperature range and the full mission life.
- **Parent:** FAR-TMTC_SW_L4REQ-49
- **Design:** ip/pps_ip/src/pps_generator.sv:25, :37-48
- **Kind:** Performance
- **Verify:** ANA, HW
- **Rationale:** PF-PPS-07 requires a 1 Hz pulse at 50 % duty but states no accuracy, so the requirement is met by any pulse that is approximately periodic. The generator toggles on a fixed count of exactly 25,000,000 cycles, so the output period is 50,000,000 clock cycles and its accuracy is that of the board oscillator, one for one. This is the payload's fallback time source when external PPS is unavailable, and image time-correlation depends on it.
- **Status:** OK
- **Evidence:** By analysis. The generator counts a fixed 50 x 10^6 cycles of
  the 50 MHz system clock, so its accuracy is that clock's: **+/-75 ppm** over
  -55 to +125 C and 5 years, from the flight oscillator's datasheet (Y3,
  X35T-L7M, overall accuracy including 5-year aging). That is +/-75 us per
  second, +/-0.41 s per 90-minute orbit and +/-6.5 s per day free-running
  (`verification/analysis/test_ana_clocks.py`). The HW item is still to run.
- **Note:** Re-adjudicated from `GAP` on 2026-10-02 by owner decision: the
  accuracy is now stated. Mission life and operating range are TBR (`DRV-PF-04`).
  Whether +/-75 ppm is good enough is still Q-06's to answer.
- **Note:** For a typical uncompensated oscillator at +/-100 ppm total error, the local PPS is in error by +/-100 us per second. Free-running, that accumulates to roughly +/-0.5 s over a 90-minute orbit and +/-8.6 s per day. Whether that is acceptable depends on the time-correlation accuracy the mission needs from FAR-TMTC_SW_L4REQ-49, which is not currently stated either.
- **Note:** The missing figure is now asked as Q-06 in
  [`open-questions.md`](../../../docs/requirements/open-questions.md), with a
  named owner field, rather than left as an observation here. It cannot be
  derived from below: the generator's accuracy is the board oscillator's, one
  for one, so the number has to come from the mission. `PF-TRIG-12` depends on
  the same answer.

## ETH -- Ethernet responder

### PF-ETH-02
The Ethernet responder shall accept IPv4 frames addressed to the local MAC address.
- **Parent:** FAR-EDT_L3REQ-2
- **Design:** `ip/responder_ip/src/responder.sv:782-799`
- **Verify:** SIM, HW
- **Rationale:** The payload Ethernet interface must ignore traffic for other devices on the network.
- **Status:** OK
- **Evidence:** Simulated on `rsp_top` at the parameters `udp_hier` gives
  it, at 100 MHz, between models of CORETSE's receive and transmit FIFO
  interfaces built from its user guide, with every received frame padded to
  60 bytes and carrying its FCS, as flight firmware's MAC configuration
  leaves it. An echo request to the local MAC was answered; the same frame
  to another unicast MAC, and to the broadcast MAC, was not
  (`verification/tests/test_pf_eth.py`).

### PF-ETH-04
The Ethernet responder shall drop ARP packets that are not requests for the local IPv4 address.
- **Parent:** FAR-EDT_L3REQ-2
- **Design:** `ip/responder_ip/src/responder.sv:801-825`
- **Verify:** SIM
- **Rationale:** Malformed or irrelevant ARP traffic must not change the payload network response.
- **Status:** OK
- **Evidence:** Simulated on `rsp_top` at the parameters `udp_hier` gives
  it, at 100 MHz, between models of CORETSE's receive and transmit FIFO
  interfaces built from its user guide, with every received frame padded to
  60 bytes and carrying its FCS, as flight firmware's MAC configuration
  leaves it. A request for another address, a request for 0.0.0.0 and an ARP
  reply naming the local address got nothing. A request for the local
  address after them was answered correctly
  (`verification/tests/test_pf_eth.py`).
- **Finding:** PF-F-36
- **Note:** Two requests for the local address are handled unlike a host
  would: a unicast request (dropped) and one with a non-Ethernet hardware
  type (answered as Ethernet). See `PF-F-36`.

### PF-ETH-05
The Ethernet responder shall drop IPv4 packets that are not local ICMP echo requests.
- **Parent:** FAR-EDT_L3REQ-2
- **Design:** `ip/responder_ip/src/responder.sv:858-887`
- **Verify:** SIM
- **Rationale:** The hardware responder only owns the ping service and must reject unsupported protocols.
- **Status:** OK
- **Evidence:** Simulated on `rsp_top` at the parameters `udp_hier` gives
  it, at 100 MHz, between models of CORETSE's receive and transmit FIFO
  interfaces built from its user guide, with every received frame padded to
  60 bytes and carrying its FCS, as flight firmware's MAC configuration
  leaves it. UDP, TCP, an ICMP echo reply and an ICMP timestamp request to
  the local address, echo requests to three other addresses (including one
  differing only in the first octet and one only in the last), and IPv6 to
  the local MAC all got nothing. A local echo request after them was
  answered (`verification/tests/test_pf_eth.py`).
- **Finding:** PF-F-36
- **Note:** An echo request with a bad IPv4 header checksum, and a first
  fragment of one, were answered; one with IP options was dropped. See
  `PF-F-36`.

### PF-ETH-06
The Ethernet responder shall generate ARP replies for accepted ARP requests.
- **Parent:** FAR-EDT_L3REQ-2
- **Design:** `ip/responder_ip/src/responder.sv:431-515`
- **Verify:** SIM, HW
- **Rationale:** Ground equipment needs hardware-level address resolution before higher-level image transfer.
- **Status:** OK
- **Evidence:** Simulated on `rsp_top` at the parameters `udp_hier` gives
  it, at 100 MHz, between models of CORETSE's receive and transmit FIFO
  interfaces built from its user guide, with every received frame padded to
  60 bytes and carrying its FCS, as flight firmware's MAC configuration
  leaves it. Three requests for the local address each got a reply addressed
  to the requester, with hardware type 1, protocol 0x0800, sizes 6 and 4,
  opcode 2, the local MAC and address as sender and the requester's as
  target (`verification/tests/test_pf_eth.py`).

### PF-ETH-07
The Ethernet responder shall generate ICMP echo replies for accepted echo requests.
- **Parent:** FAR-EDT_L3REQ-2
- **Design:** `ip/responder_ip/src/responder.sv:571-704`
- **Verify:** SIM, HW
- **Rationale:** Ping response is the basic health check for the payload Ethernet path.
- **Status:** GAP
- **Evidence:** Simulated on `rsp_top` at the parameters `udp_hier` gives
  it, at 100 MHz, between models of CORETSE's receive and transmit FIFO
  interfaces built from its user guide, with every received frame padded to
  60 bytes and carrying its FCS, as flight firmware's MAC configuration
  leaves it. Echo requests of 0, 1, 18, 56, 57 and 64 data bytes each got a
  reply with the addresses swapped, a valid IPv4 header checksum, type 0, a
  valid ICMP checksum, and the request's identifier, sequence and data. A
  1472-byte request, delivered a word a clock, got a 1422-byte reply with 96
  bytes of data missing and a wrong checksum. At line rate it was answered
  whole (`verification/tests/test_pf_eth.py`, failing as expected).
- **Finding:** PF-F-35, PF-F-36
- **Note:** Re-adjudicated from `OK` on 2026-10-01. Each reply also carries
  the request's 4 FCS bytes after its IP datagram (`PF-F-36`).
- **Note:** The responder is configured `CLOCK_FREQ_MHZ:50` and clocked at
  100 MHz, so its PHY start-up wait, `PHY_INIT_USEC:100`, is 50 us. It is
  the only use of the clock parameter.

### PF-ETH-09
The top-level design shall hold unused ETH2 control outputs inactive.
- **Parent:** FAR-EDT_L3REQ-13, FAR-EDT_L3REQ-3
- **Design:** `bd/mpf500ts-fc1152m/top/components/top.tcl:231-234`
- **Verify:** INSP, HW
- **Rationale:** The unused Ethernet path must not drive an uncommanded PHY interface.
- **Finding:** PF-F-02, PF-F-50
- **Status:** GAP
- **Evidence:** Not met, by inspection of every PolarFire line into the ETH2
  PHY (U4, VSC8541) on the flight-model schematic. The four control outputs,
  `eth2_phy_rst_n`, `eth2_phy_mdc`, `eth2_ctrl_comma_mode` and
  `eth2_ctrl_clk_squelch_in`, are tied low (`top.tcl:231-234`), which holds the
  PHY in reset and drives nothing high into it while its rails are off. The
  other seven, `TX_CTL`, `GTX_CLK`, `TXD[3:0]` and `MDIO`, have no port and are
  left as unused I/O, which Libero tristates with a weak pull-up: floating, and
  pulled up into an unpowered PHY (`verification/analysis/test_insp_board.py`,
  failing as expected; `PF-F-50`).
- **Note:** Evidence corrected on 2026-10-02. It said the control outputs are
  not tied; they are, and the gap is the pins that are not ports.

### PF-ETH-10
The top-level design shall expose ETH2 power enable and status only through the housekeeper hierarchy.
- **Parent:** FAR-EDT_L3REQ-13, FAR-EDT_L3REQ-3
- **Design:** `bd/mpf500ts-fc1152m/top/components/top.tcl:731-732`
- **Verify:** INSP, HW
- **Rationale:** ETH2 is not a PolarFire-controlled network path in this baseline and must remain under housekeeper ownership.
- **Finding:** PF-F-02
- **Status:** OK
- **Evidence:** By inspection. Both lines connect only to `hk_hier`
  (`top.tcl:731-732`): the enable is bit 2 of `gpo_hk_pwr_ctrl`, the status
  bit 7 of `gpi_hk_status` (`hk_hier.tcl:166-167`). Neither reaches
  `eth1_hier`, `udp_hier` or `eth_pcie_mux_hier`. On the board the enable runs
  through a 33 ohm resistor to the housekeeper's `eth2_ctrl` input, which gates
  the ETH2 rails, and the status comes from its `eth2_status_to_pf` output, so
  the PolarFire requests and observes, and the housekeeper owns the rails
  (`verification/analysis/test_insp_board.py`). The HW item is still to run.
- **Note:** Re-adjudicated from `GAP` on 2026-10-02 by owner decision. The
  earlier evidence, that the lines are exposed at the top level rather than
  routed through the housekeeper, is contradicted by the design: they are top-
  level ports because they leave the package, and both run to the housekeeper.

## UDP -- UDP image transmit

### PF-UDP-04
The UDP mux shall disable all transmit sources for disabled or invalid selections.
- **Parent:** FAR-CDH_FPGA_L3REQ-20
- **Design:** `ip/udp_ip/src/udp_mux.sv:82-115`, `ip/udp_ip/src/udp_mux.sv:167-190`
- **Verify:** SIM
- **Rationale:** Malformed firmware selection values must not leak image data from an unintended buffer.
- **Status:** OK
- **Evidence:** Simulated on `udp_hier` as the build generates it, under
  QuestaSim, at 100 MHz, between models of the two DDR4 read controllers
  (speaking `dma_read_ctrl`'s protocol) and of CORETSE's transmit interface,
  with firmware's configuration written over APB. With both banks' read
  controllers waiting to send, selections 0 and 3 each held for 100 us sent
  no frame to the MAC and gave neither controller any handshake. Selection 1
  afterwards sent the 8 GB controller's datagrams
  (`verification/tests/test_pf_udp.py`).

### PF-UDP-15
The UDP transmitter shall enforce a configurable inter-packet gap.
- **Parent:** FAR-CDH_FPGA_L3REQ-20
- **Design:** `ip/udp_ip/src/udp_tx.sv:265`, `ip/udp_ip/src/udp_tx.sv:381-389`, `ip/udp_ip/src/udp_tx.sv:574-580`
- **Verify:** SIM, ANA
- **Rationale:** A bounded gap prevents receiver overrun while allowing firmware to tune throughput.
- **Evidence:** The current implementation uses the APB frame-gap value or a default of 1000 cycles.
- **Status:** OK
- **Evidence:** Simulated on `udp_hier` as the build generates it, under
  QuestaSim, at 100 MHz, between models of the two DDR4 read controllers
  (speaking `dma_read_ctrl`'s protocol) and of CORETSE's transmit interface,
  with firmware's configuration written over APB. Between successive
  datagrams at the MAC interface, FRAME_GAP 500 gave 5.1 us and 3000 gave
  30.1 us; FRAME_GAP 0 applied the 1000-cycle default, 10.1 us
  (`verification/tests/test_pf_udp.py`).
- **Note:** Re-adjudicated from `DEFECT` on 2026-10-01. Configurability is
  all this requires, and it is met. The default is too short for the MAC,
  which is `DRV-PF-08`'s to carry: it fails there, at 10.1 us against 20 us.


### DRV-PF-08
The UDP transmitter shall not emit successive datagrams closer together than
20 us, at any configured inter-packet gap setting including the default.
- **Source decision:** The inter-packet gap was made a firmware-writable APB
  register with a hardware default applied when the register reads zero, which
  places the reset-state gap under FPGA control rather than firmware control.
- **Imposes on:** FPGA design, PolarFire firmware, verification
- **Design:** `ip/udp_ip/src/udp_tx.sv:265`, `ip/udp_ip/src/udp_tx.sv:574-580`
- **Kind:** Performance
- **Verify:** SIM, ANA
- **Rationale:** The Microchip CoreTSE MAC needs approximately 20 us between
  frames for reliable transmission. `PF-UDP-15` requires only that the gap be
  *configurable*, which is structurally incapable of catching a non-compliant
  value -- and the shipped default is non-compliant. `conventions.md` section 4
  rule 4 says defaults are not contracts; the corollary is that when a default
  can violate a hardware constraint, the constraint needs its own requirement.
  Stated as a floor rather than a value so firmware keeps the freedom to trade
  throughput against receiver margin above it.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Finding:** PF-F-09
- **Status:** GAP
- **Evidence:** Not met at the default. The RTL applies 1000 cycles at 100 MHz
  = 10 us when the APB register reads zero (`ip/udp_ip/src/udp_tx.sv:265`),
  which is half the required gap. Any configured value of 2000 cycles or more
  complies. See [`PF-F-09`](pf-fpga-findings.md), whose recommended disposition
  is to change the default to at least 2000 cycles.
- **Evidence:** Simulated on `udp_hier` as the build generates it, under
  QuestaSim, at 100 MHz, between models of the two DDR4 read controllers
  (speaking `dma_read_ctrl`'s protocol) and of CORETSE's transmit interface,
  with firmware's configuration written over APB. The shortest gap between
  successive datagrams was 10.1 us at the default, as flown (flight firmware
  never writes FRAME_GAP), and 20.08, 25.08 and 50.08 us at 2000, 2500 and
  5000 (`verification/tests/test_pf_udp.py`, failing as expected).
- **Note:** After a watchdog timeout the transmitter returns to idle without
  its gap (`PF-F-37`), so even a compliant setting does not bound the gap
  there.
- **Note:** Derived rather than functional because the 20 us figure comes from
  the CoreTSE ICD, not from a FARSIGHT need. `conventions.md` forbids restating
  a vendor field encoding as a requirement -- that is why `PF-UDP-13` was
  withdrawn -- but a vendor *timing minimum* the FPGA must respect is an
  obligation on this design, in the same way the DRV8434 minima are carried by
  `PF-FOCUS-08` through `PF-FOCUS-10`.

### DRV-PF-09
The UDP image transmit path shall sustain an egress rate of at least
200 Mbit/s measured at the Ethernet boundary while draining a frame buffer.
- **Source decision:** The system-level offload rate is unavailable as a parent.
  FAR-L1REQ-59 is dispositioned `DEFECT` in the corrected baseline -- its
  statement reads "200 mb/second", which is readable as millibits, megabits or
  megabytes -- so the FPGA-side rate obligation is carried here until that
  requirement is repaired.
- **Imposes on:** FPGA design, PolarFire firmware, system design, verification
- **Design:** `ip/udp_ip/src/udp_tx.sv`, `ip/dma_read_ctrl_ip/src/frame_xfer_ctrl.sv`
- **Kind:** Performance
- **Verify:** ANA, HW
- **Rationale:** Egress rate sets how long the payload is occupied after a
  capture and therefore how soon it can capture again, so it sizes a contact
  window. The FPGA side of that budget is distinct from the firmware side:
  `PFW-UDP-13` bounds what firmware must achieve given a working transmitter,
  while this bounds what the transmitter must deliver given the gap of
  `DRV-PF-08`. Stating only the firmware half would leave the inter-packet gap
  free to consume the entire margin without violating anything.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** AMBIG
- **Evidence:** Analysis supports compliance; not measured, and the two are not
  interchangeable for a rate at the pin. At a 1460-byte payload the 20 us floor
  of `DRV-PF-08` permits about 584 Mbit/s, and the compliant 2000-cycle setting
  permits about 292 Mbit/s -- both above 200 Mbit/s, but the 10 us default is
  what the design currently ships and the margin at the default is untested.
- **Note:** Recorded `AMBIG` rather than `OK` because the status vocabulary has
  no `UNMEASURED` value. This is the gap A-12 opened and it is still unfixed --
  see [A-12](../../../docs/requirements/requirements-gap-analysis.md#a-12---write-the-missing-performance-requirements---polarfire-fw-done)
  item 1. Without it, a performance requirement verified by `HW` will be
  adjudicated `OK` on analysis alone, which is precisely the failure this
  requirement set is trying to stop.
- **Note:** This requirement and `PFW-UDP-13` must be repaired together when
  FAR-L1REQ-59 is fixed. Both name it as their blockage; neither should outlive
  it as derived.

### PF-UDP-16
The UDP transmitter shall emit an error datagram on watchdog timeout.
- **Parent:** FAR-L1REQ-21
- **Design:** `ip/udp_ip/src/udp_tx.sv:269`, `ip/udp_ip/src/udp_tx.sv:772-779`, `ip/udp_ip/src/udp_tx.sv:1213-1229`
- **Verify:** SIM
- **Rationale:** The host must receive a visible end-of-transfer indication when the payload stream stalls.
- **Evidence:** The current error payload word is `0xEFBADBAD`.
- **Status:** GAP
- **Evidence:** Simulated on `udp_hier` as the build generates it, under
  QuestaSim, at 100 MHz, between models of the two DDR4 read controllers
  (speaking `dma_read_ctrl`'s protocol) and of CORETSE's transmit interface,
  with firmware's configuration written over APB. A read controller stalled
  mid-datagram past the watchdog. The transmitter ended that frame with
  `0xEFBADBAD` and counted the error, but the frame kept the cut-short
  datagram's lengths: 92 bytes against an IP total length of 194. A
  receiver's IP layer drops it, so no host application sees the error
  (`verification/tests/test_pf_udp.py`, failing as expected).
- **Finding:** PF-F-37
- **Note:** Re-adjudicated from `OK` on 2026-10-01. The watchdog is 10 s;
  the simulation set its counter near the limit once the stall began, rather
  than run a billion clocks.

### PF-UDP-05
The UDP mux shall route only the selected DDR4 image source to the Ethernet transmitter.
- **Parent:** FAR-CDH_FPGA_L3REQ-20
- **Design:** `ip/udp_ip/src/udp_mux.sv:117-140`, `ip/udp_ip/src/udp_mux.sv:142-165`
- **Verify:** SIM
- **Rationale:** Firmware selection of a buffer must not leak packets from the inactive image source.
- **Status:** OK
- **Evidence:** Simulated on `udp_hier` as the build generates it, under
  QuestaSim, at 100 MHz, between models of the two DDR4 read controllers
  (speaking `dma_read_ctrl`'s protocol) and of CORETSE's transmit interface,
  with firmware's configuration written over APB. With both controllers
  waiting, selection 1 sent the 8 GB controller's three datagrams and
  selection 2 the 16 GB controller's three; every data word in each came
  from the selected bank, and the other controller got no handshake
  (`verification/tests/test_pf_udp.py`).

## XCVR -- SLVS-EC lane recovery

### PF-XCVR-03
The SLVS-EC receiver correction path shall flag a lane after a bounded run of consecutive disparity errors.
- **Parent:** FAR-L1REQ-19
- **Design:** `ip/xcvr_disparity_correction/src/xcvr_disparity_correction.v:187`, `ip/xcvr_disparity_correction/src/xcvr_disparity_correction.v:224-414`
- **Verify:** SIM
- **Rationale:** A persistently unhealthy lane must be visible before corrupted image data is accepted silently.
- **Evidence:** The current default threshold is 16 consecutive disparity-error samples.
- **Status:** GAP
- **Evidence:** Simulated on `XCVR_DISPARITY_CORRECTION` at the parameters
  `cam_rx_hier` gives it, with `P_CLK_I` at 50 MHz and each lane's recovered
  clock at 118.8 MHz, the build's derived constraint, each at its own phase.
  Runs of 15 errors on every lane never reset the receiver. Runs of 16, five
  on every lane at stepped phases, raised the lane's flag every time, 40 of
  40, but only 8 reset the receiver: the flag is high for one 8.4 ns lane
  clock, and the 50 MHz domain samples it every 20 ns. Runs of 32 were acted
  on 13 times in 24, runs of 48 to 160 every time
  (`verification/tests/test_pf_xcvr.py`, failing as expected).
- **Finding:** PF-F-40
- **Note:** Re-adjudicated from `OK` on 2026-10-01. The flag is visible
  outside the block only as the receiver reset and its interrupt, so a flag
  that does not reach them does not make the lane visible.

### PF-XCVR-07
The SLVS-EC receiver correction path shall reset the camera lane receiver after a qualifying lane-error condition, holding the reset for at least 32 cycles of the 50 MHz system clock, 640 ns (TBR).
- **Parent:** FAR-AB_L2REQ-7
- **Design:** `ip/xcvr_disparity_correction/src/xcvr_disparity_correction.v:768-782`
- **Verify:** SIM, HW
- **Rationale:** Automatic receiver reset is the available recovery response for sustained lane disparity.
- **Evidence:** The current reset pulse is 32 receiver-clock cycles.
- **Status:** GAP
- **Evidence:** Simulated on `XCVR_DISPARITY_CORRECTION` at the parameters
  `cam_rx_hier` gives it, with `P_CLK_I` at 50 MHz and each lane's recovered
  clock at 118.8 MHz, the build's derived constraint, each at its own phase.
  400 consecutive errors on lanes 0, 3 and 7 each reset the receiver, raised
  the interrupt and released the reset. Every reset was low for 31 system
  clocks, 620 ns, under the 32 required
  (`verification/tests/test_pf_xcvr.py`, failing as expected).
- **Finding:** PF-F-41
- **Note:** The pulse length was added on 2026-10-01; the requirement stated
  none. It is TBR pending the PolarFire transceiver user guide's minimum for
  `PCS_ARST_N`, which is not in the IP vault; the SLVS-EC receiver's user
  guide and CoreReset's handbook state none. 32 is the design's own
  `RST_CNT_CLKS`.
- **Note:** The evidence line above is wrong in two ways: the pulse is
  counted in system clocks, not receiver clocks, and it is 31 of them, not
  32.

### PF-XCVR-08
The SLVS-EC receiver correction path shall interrupt firmware after releasing receiver reset.
- **Parent:** FAR-L1REQ-21
- **Design:** `ip/xcvr_disparity_correction/src/xcvr_disparity_correction.v:791-796`
- **Verify:** ANA, HW
- **Rationale:** Firmware and telemetry need an observable indication that a lane recovery event occurred.
- **Status:** GAP
- **Evidence:** By analysis of the RTL and the SmartDesign. In the block the
  interrupt does follow the release: `RX_RST_CONTROL_O` is released on
  leaving `s_RST_CNT`, and `RX_RST_CONTROL_INTERRUPT_O` pulses in the next
  state, `s_REG_RST`, one clock later. But `cam_rx_hier` marks the interrupt
  output unused (`bd/mpf500ts-
  fc1152m/cam_rx_hier/components/cam_rx_hier.tcl:343`): it is connected to
  nothing, so firmware is never interrupted
  (`verification/analysis/test_ana_budgets.py`, failing as expected).
- **Finding:** PF-F-44
- **Note:** Re-adjudicated from `OK` on 2026-10-01.

### PF-XCVR-09
The SLVS-EC receive path shall sustain 17.4 Gbit/s aggregate pixel ingest across
the eight camera lanes without loss of frame data.
- **Parent:** FAR-AB_L2REQ-7, FAR-FPA_L5REQ-5
- **Design:** `ip/xcvr_disparity_correction/src/xcvr_disparity_correction.v`, `ip/cam_flow_sync_ip/src/cam_flow_sync.sv`
- **Kind:** Performance
- **Verify:** ANA, HW
- **Rationale:** The XCVR area specified three lane *error recovery* behaviours
  and no lane *rate*, so the receive path could be shown to detect and recover
  from disparity errors without anything establishing that it keeps up with the
  sensor in the first place. Ingest rate is the first thing in the imaging chain
  that can fail to meet FAR-FPA_L5REQ-5, and a shortfall here is unrecoverable
  downstream -- no buffer or egress margin compensates for pixels never received.
- **Status:** OK
- **Evidence:** Analysis only; not measured. The requirement is the same
  31.08 MB frame at 70 FPS that sizes `PF-DMAW-10` = 17.40 Gbit/s of payload.
  The link provides eight lanes at 4.752 Gbps
  (`docs/design/pf-fpga-camera-control.md:32`) = 38.02 Gbit/s raw, which after
  8b/10b line coding is 30.4 Gbit/s of payload -- 1.75x margin.
- **Note:** The margin is stated against the line rate, not against the sensor.
  Whether the IMX531 emits 70 FPS at maximum bit depth is FAR-FPA_L5REQ-5's own
  `(TBR)` and is not resolved here; this requirement bounds only what the FPGA
  boundary must accept.
- **Note:** FAR-FPA_L5REQ-5 is dispositioned `UNADJUDICATED` in the corrected
  baseline -- *"Not settled by reading design artefacts. Needs test, analysis or
  measurement"* -- with the action "Schedule test or analysis". The analysis in
  this requirement and in `PF-DMAW-10` is part of what that action was waiting
  for: it establishes that the FPGA ingest and buffer-write paths carry 70 FPS
  with margin, so the remaining question is the sensor's, not the FPGA's. Offer
  it back when the parent is adjudicated.

## SYS -- System data path

### PF-SYS-01
The image export path shall buffer camera frames in DDR4 before Ethernet or PCIe export.
- **Parent:** FAR-CDH_FPGA_L3REQ-13, FAR-FB_L3REQ-2
- **Design:** `ip/cam_mux_ip/src/cam_mux.sv:116-151`, `ip/dma_write_ip/src/dma_write_send_ctrl.sv:264-284`, `ip/dma_read_ctrl_ip/src/frame_xfer_ctrl.sv:328-358`
- **Verify:** ANA
- **Rationale:** DDR4 decouples camera ingest timing from later host and network egress timing.
- **Status:** OK
- **Evidence:** By a trace of the top-level SmartDesign's connections. The
  camera receiver's pixel data and its frame and line valids go only to the
  two DDR4 groups; the debug mux receives valid strobes, never pixels. The
  UDP transmitter's image streams and handshakes, and the PCIe mux's DDR4
  ports, connect only to the same two groups. So every exported frame has
  been through DDR4 (`verification/analysis/test_ana_trace.py`).
- **Note:** Re-adjudicated from `GAP` on 2026-10-01. The design does what
  this requirement says; that it contradicts two unbuilt system requirements
  remains `PF-F-01`'s.
- **Note:** This requirement **contradicts** FAR-CDH_FPGA_L3REQ-11 and FAR-CDH_FPGA_L3REQ-25, which require imagery to be transferred directly from the sensor with the frame buffer bypassed. It previously cited both as parents, which was backwards -- a requirement cannot decompose a need it negates. Both are dispositioned UNBUILT in the corrected system baseline; the contradiction is recorded in `PF-F-01`.

### PF-SYS-02
The image export path shall transfer camera frames directly from the sensor to
Ethernet or PCIe export, bypassing DDR4, when the frame buffer is disabled.
- **Parent:** FAR-CDH_FPGA_L3REQ-11
- **Design:** `ip/cam_mux_ip/src/cam_mux.sv:116-151`, `bd/mpf500ts-fc1152m/top/components/top.tcl:576-579`, `bd/mpf500ts-fc1152m/top/components/top.tcl:817-819`
- **Verify:** ANA
- **Rationale:** FAR-CDH_FPGA_L3REQ-11 requires images transferred directly from
  the IMX531 when the frame buffer is disabled. The corrected baseline
  dispositions it `UNBUILT`. It is traced here so that the absence is a
  failing requirement rather than an untraced one, until it is built,
  withdrawn or accepted.
- **Status:** GAP
- **Finding:** PF-F-01
- **Evidence:** Not met, by a trace of the top-level SmartDesign's connections:
  camera pixel data reaches only the two DDR4 groups, and the Ethernet and PCIe
  paths take image data only from them. There is no path around DDR4, and no
  control that disables the frame buffer (`verification/analysis/test_ana_trace.py`,
  failing as expected).
- **Note:** If the bypass is built, `PF-SYS-01` must be qualified to apply while
  the frame buffer is enabled; as written the two cannot both be met in a
  bypass mode.

### PF-SYS-03
The direct transfer of camera frames shall carry imagery at the rate of the
fastest export interface.
- **Parent:** FAR-CDH_FPGA_L3REQ-25
- **Design:** `bd/mpf500ts-fc1152m/top/components/top.tcl:576-579`, `bd/mpf500ts-fc1152m/top/components/top.tcl:817-819`
- **Kind:** Performance
- **Verify:** ANA
- **Rationale:** FAR-CDH_FPGA_L3REQ-25 requires direct transfer from the sensor
  to the payload controller as fast as the fastest data interface to the bus.
  The corrected baseline dispositions it `UNBUILT`, together with
  FAR-CDH_FPGA_L3REQ-11; it is traced here so that the absence fails.
- **Status:** GAP
- **Finding:** PF-F-01
- **Evidence:** Not met: there is no direct path (`PF-SYS-02`), so there is no
  rate to analyse (`verification/analysis/test_ana_trace.py`, failing as
  expected).

## Appendix A -- FPGA interface ICD

The consolidated APB peripheral map that was here has moved to section 25.1 of
[CM-01979](../../../docs/icd/CM-01979_ICD_FLIGHT_SOFTWARE_FARSIGHT.md), which is the source of truth for interface
data. Requirements in this document cite it rather than repeating it.

The host-visible register map -- what the payload bus sees over TMTC -- is
section 17.4 of the same document. The two are different interfaces: a `REG_ID`
in 17.4 is a TMTC index, while an address in 25.1 is a physical APB address.

## Withdrawn

### Process obligation, moved to a plan

The following are withdrawn from this document and restated as clauses of the
[FPGA Build and Disposition Plan](../../../docs/plans/fpga-build-and-disposition-plan.md).
See `HK-IMPL-06` for the reasoning; the plan covers both FPGAs, and clause 5
records why each keeps its own captured artefact and disposition record.

- `PF-BUILD-12` -- build tool messages captured. Plan clause 1.
- `PF-BUILD-13` -- every message dispositioned before release. Plan clause 2.
- `PF-BUILD-15` -- disposition record version controlled. Plan clause 4.
- `PF-BUILD-19` -- no release with undispositioned static analysis violations.
  Plan clause 3.
- `PF-BUILD-21` -- static analysis disposition record version controlled. Plan
  clause 4.

### Disposition mechanism is not project scope

- `PF-BUILD-17` -- "A classification rule shall not auto-dispose messages
  reporting removed or optimised-away logic, unconstrained timing paths,
  inferred latches, black-box instantiation, or substitution of a requested
  implementation, unless that rule's rationale addresses that specific class."
- `PF-BUILD-22` -- "The disposition record shall identify the classification rule
  set, and its version, that was applied to the build."

  Both constrain *how* a message comes to be dispositioned. See `HK-IMPL-13` for
  the reasoning; `PF-BUILD-13` and `PF-BUILD-15` carry what the project needs.

### Entailed by another requirement

- `PF-BUILD-16` -- "A build whose tool message set differs from the dispositioned
  set shall be treated as not released until the difference is dispositioned."
  `PF-BUILD-13` already requires every message to be dispositioned before
  release, so this restated a consequence as an additional obligation.

### Constrains an artefact this project does not own

- `PF-BUILD-14` -- "Auto-disposition classification rules shall be version
  controlled." Replaced by `PF-BUILD-22`; see `HK-IMPL-12` for the reasoning.
- `PF-BUILD-18` -- "Each auto-disposition classification rule shall carry a
  rationale for why messages matching it require no engineering judgement."
  Recorded as a cross-boundary obligation in
  [`derived-register.md`](../../../docs/requirements/derived-register.md).

### Interface data now held in the ICD

- `PF-DMAR-17` -- "The Ethernet image stream shall start each application payload
  with token 0x504B." Held in [CM-01979](../../../docs/icd/CM-01979_ICD_FLIGHT_SOFTWARE_FARSIGHT.md) section
  4.2.1 as the Start Marker field.
- `PF-DMAR-21` -- "The Ethernet image stream shall place line and packet sequence
  numbers in the second UDP payload word." Same section, which defines both
  fields and their byte order.

### Restates a published protocol, not a FARSIGHT need

- `PF-UDP-09` -- "The UDP transmitter shall calculate IPv4 total length from IP
  header, UDP header and payload byte count." This is the definition of the IPv4
  total length field in RFC 791. FARSIGHT does not get to choose it.
- `PF-UDP-10` -- "The UDP transmitter shall set the UDP checksum field to zero."
  RFC 768 permits a zero checksum on IPv4 to mean "not computed". Whether
  FARSIGHT *should* omit it is a real question -- the ICD records it as an
  outstanding FSW request -- but that is a design decision to adjudicate, not a
  requirement satisfied by restating the field encoding.
- `PF-UDP-12` -- "The UDP transmitter shall emit a 42-byte Ethernet/IP/UDP header
  before payload bytes." 42 bytes is 14 Ethernet plus 20 IPv4 plus 8 UDP, all
  fixed by the standards.
- `PF-UDP-13` -- "The UDP transmitter shall encode the final-word byte-valid
  value according to the CoreTSE ICD." Already deferred to a vendor document by
  its own wording; the Microchip CoreTSE ICD is the source of truth.

### Merged into a single release gate

- `PF-BUILD-20` -- "Every static analysis violation shall be dispositioned
  before the build is released, as fixed, accepted-with-rationale, or
  accepted-with-rationale naming why the reported condition is not a defect in
  this design." Merged into `PF-BUILD-19`, for the reason given there: the two
  obligations are not independently satisfiable.

### Internal protocol bound, not a FARSIGHT need

- `PF-DMAW-08` -- "Each DDR4 write DMA burst shall contain no more than 256 AXI
  beats." 256 beats is the AXI4 protocol maximum for an incrementing burst, so
  the statement restated a bus limit rather than a requirement, was not
  observable at the FPGA boundary, and did not constrain the throughput its
  parent FAR-FB_L3REQ-1 is about. Replaced by `PF-DMAW-10`.
- `PF-DMAR-15` -- "The frame-transfer controller shall split line reads into
  chunks of no more than 256 AXI beats." Same reasoning. Replaced by
  `PF-DMAR-24`.

### Consolidated into a single interconnect requirement

- `PF-META-05` and `PF-PPS-05` -- "The ... APB interface shall return a defined
  error pattern for invalid reads." Stated per-peripheral for two of roughly
  eighteen APB slaves, which under-specified the interconnect and implied the
  rest were exempt. Replaced by `PF-APB-02`.

Identifiers below are retired in place to preserve traceability from older links.

### Build configuration or flow fact; not an external Class B behavior.
- `PF-BUILD-01` -- Build configuration or flow fact; not an external Class B behavior.
- `PF-BUILD-02` -- Build configuration or flow fact; not an external Class B behavior.
- `PF-BUILD-03` -- Build configuration or flow fact; not an external Class B behavior.
- `PF-BUILD-04` -- Build configuration or flow fact; not an external Class B behavior.
- `PF-BUILD-05` -- Build configuration or flow fact; not an external Class B behavior.
- `PF-BUILD-07` -- Build configuration or flow fact; not an external Class B behavior.
- `PF-BUILD-08` -- Build configuration or flow fact; not an external Class B behavior.
- `PF-BUILD-09` -- Build configuration or flow fact; not an external Class B behavior.
- `PF-BUILD-10` -- Build configuration or flow fact; not an external Class B behavior.
- `PF-BUILD-11` -- Build configuration or flow fact; not an external Class B behavior.

### Internal clocking or timing-analysis detail; retained in design evidence.
- `PF-CLK-01` -- Internal clocking or timing-analysis detail; retained in design evidence.
- `PF-CLK-03` -- Internal clocking or timing-analysis detail; retained in design evidence.
- `PF-CLK-04` -- Internal clocking or timing-analysis detail; retained in design evidence.
- `PF-CLK-05` -- Internal clocking or timing-analysis detail; retained in design evidence.
- `PF-CLK-06` -- Internal clocking or timing-analysis detail; retained in design evidence.
- `PF-CLK-07` -- Internal clocking or timing-analysis detail; retained in design evidence.
- `PF-CLK-08` -- Internal clocking or timing-analysis detail; retained in design evidence.
- `PF-CLK-09` -- Internal clocking or timing-analysis detail; retained in design evidence.

### Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-FDIR-01` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-FDIR-02` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-FDIR-03` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-FDIR-07` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-CAM-02` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-CAM-03` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-MUX-01` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-MUX-02` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-MUX-03` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-MUX-06` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-TRIG-01` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-TRIG-02` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-TRIG-03` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-TRIG-04` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-TRIG-06` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-TRIG-10` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-DMAW-03` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-DMAW-04` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-DMAW-05` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-DMAW-06` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-DMAW-07` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-DMAW-10` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-DMAW-13` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-DMAR-04` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-DMAR-05` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-DMAR-06` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-DMAR-07` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-DMAR-09` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-DMAR-11` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-DMAR-12` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-DMAR-13` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-DMAR-14` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-DMAR-19` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-DMAR-22` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-PCIE-01` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-PCIE-03` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-PCIE-04` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-PCIE-05` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-PCIE-06` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-PCIE-10` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-PCIE-11` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-PCIE-12` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-FOCUS-02` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-FOCUS-03` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-FOCUS-06` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-FOCUS-07` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-FOCUS-11` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-FOCUS-15` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-META-06` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-META-07` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-META-08` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-ETH-01` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-ETH-08` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-UDP-02` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-UDP-03` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-UDP-07` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-UDP-08` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-UDP-11` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-UDP-14` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-XCVR-02` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-XCVR-04` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-XCVR-05` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.
- `PF-XCVR-06` -- Internal module behavior verified only by unit-level evidence; moved to design documentation.

### Over-specified design detail; not an external Class B requirement.
- `PF-DBG-01` -- Over-specified design detail; not an external Class B requirement.
- `PF-DBG-02` -- Over-specified design detail; not an external Class B requirement.
- `PF-DBG-03` -- Over-specified design detail; not an external Class B requirement.
- `PF-DBG-04` -- Over-specified design detail; not an external Class B requirement.
- `PF-DBG-05` -- Over-specified design detail; not an external Class B requirement.
- `PF-DBG-06` -- Over-specified design detail; not an external Class B requirement.
- `PF-DBG-08` -- Over-specified design detail; not an external Class B requirement.

### Register field or programming detail moved to the consolidated ICD appendix.
- `PF-MUX-10` -- Register field or programming detail moved to the consolidated ICD appendix.
- `PF-TRIG-08` -- Register field or programming detail moved to the consolidated ICD appendix.
- `PF-DMAW-01` -- Register field or programming detail moved to the consolidated ICD appendix.
- `PF-DMAW-02` -- Register field or programming detail moved to the consolidated ICD appendix.
- `PF-DMAR-01` -- Register field or programming detail moved to the consolidated ICD appendix.
- `PF-DMAR-02` -- Register field or programming detail moved to the consolidated ICD appendix.
- `PF-DMAR-03` -- Register field or programming detail moved to the consolidated ICD appendix.
- `PF-DMAR-10` -- Register field or programming detail moved to the consolidated ICD appendix.
- `PF-FOCUS-14` -- Register field or programming detail moved to the consolidated ICD appendix.
- `PF-PPS-01` -- Register field or programming detail moved to the consolidated ICD appendix.
- `PF-UDP-01` -- Register field or programming detail moved to the consolidated ICD appendix.
### Retained at higher interface level
- `PF-FDIR-08` -- Retained behavior is covered by a higher-level interface requirement or the ICD appendix.
- `PF-CAM-01` -- Retained behavior is covered by a higher-level interface requirement or the ICD appendix.
- `PF-MUX-07` -- Retained behavior is covered by a higher-level interface requirement or the ICD appendix.
- `PF-MUX-11` -- Retained behavior is covered by a higher-level interface requirement or the ICD appendix.
- `PF-TRIG-09` -- Retained behavior is covered by a higher-level interface requirement or the ICD appendix.
- `PF-TRIG-12` -- Retained behavior is covered by a higher-level interface requirement or the ICD appendix.
- `PF-DBG-07` -- Retained behavior is covered by a higher-level interface requirement or the ICD appendix.
- `PF-DMAW-11` -- Retained behavior is covered by a higher-level interface requirement or the ICD appendix.
- `PF-DMAW-12` -- Retained behavior is covered by a higher-level interface requirement or the ICD appendix.
- `PF-DMAR-20` -- Retained behavior is covered by a higher-level interface requirement or the ICD appendix.
- `PF-PCIE-02` -- Retained behavior is covered by a higher-level interface requirement or the ICD appendix.
- `PF-FOCUS-04` -- Retained behavior is covered by a higher-level interface requirement or the ICD appendix.
- `PF-FOCUS-05` -- Retained behavior is covered by a higher-level interface requirement or the ICD appendix.
- `PF-PPS-03` -- Retained behavior is covered by a higher-level interface requirement or the ICD appendix.
- `PF-ETH-03` -- Retained behavior is covered by a higher-level interface requirement or the ICD appendix.
- `PF-UDP-06` -- Retained behavior is covered by a higher-level interface requirement or the ICD appendix.
- `PF-XCVR-01` -- Retained behavior is covered by a higher-level interface requirement or the ICD appendix.
