# ProASIC3 Housekeeper -- Low-Level Requirements

Scope: the FARSIGHT ProASIC3 (PA3) housekeeper FPGA design in
[`src/`](../../src). The PA3 sequences, monitors and protects the 33 power
sources of the FARSIGHT avionics board, reports power state to the PolarFire,
and passes the RS-422 payload bus through to the PolarFire.

These requirements were read from the RTL, not from prior documentation. Where
the Flow system requirements or [`docs/design/pa3-housekeeper.md`](../design/pa3-housekeeper.md)
disagree with the RTL, the RTL is recorded here and the disagreement is written
up in [`pa3-housekeeper-findings.md`](pa3-housekeeper-findings.md).

Conventions, identifier scheme and trace fields are defined in
[`README.md`](README.md).

## Areas

| Area | Scope | Count |
| --- | --- | ---: |
| `IMPL` | Device, build configuration, mitigation, tool-message disposition | 7 |
| `CLK` | Clock and reset | 4 |
| `IO` | Pin mapping, input conditioning, synchronisation | 7 |
| `SRC` | Per-power-source boot and fault behaviour | 11 |
| `REG` | Per-power-region boot and fault behaviour | 8 |
| `SEQ` | Inter-region boot sequencing | 10 |
| `SW` | Software-controlled region enable/disable | 7 |
| `LAT` | Latchup detection and response | 7 |
| `PDN` | Power-down sequencing | 5 |
| `TLM` | Status and failure reporting to the PolarFire | 9 |
| `UART` | RS-422 pass-through and failure broadcast | 9 |
| `PROT` | Discrete protection outputs | 3 |
| `OFFNOM` | Off-nominal and power-transition behaviour | 5 |
| `TEST` | Testability and debug access | 1 |
| `DRV` | Derived obligations (no area segment) | 5 |
| | **Total** | **98** |

Of the 98 entries, 63 are functional requirements traced to a Jama parent, 33
are derived requirements carrying a `Source decision`, and 2 are design
constraints -- `HK-IMPL-02` and `HK-IMPL-03` -- decided at system level and
labelled so that nobody hunts for a parent that was never meant to exist. All 33
derived requirements are pending independent review. Eighteen entries are
marked `Kind: Performance`; one of those still carries a `TBR` bound, and the
rest of the former TBRs carry values proposed to systems, most now confirmed
-- see [Systems answers, and what is still pending](#systems-answers-and-what-is-still-pending).
See [`conventions.md`](../../../docs/requirements/conventions.md).

## Status summary

| Status | Meaning | Count |
| --- | --- | ---: |
| `OK` | Design satisfies the requirement | 69 |
| `GAP` | Design does not meet the requirement | 29 |
| `AMBIG` | Wording unclear or unverifiable as written | 0 |
| `DEFECT` | Design is internally inconsistent | 0 |

The `GAP` count rose from 6 to 22 as the off-nominal, testability, timing,
reset and tool-disposition requirements were added. That is the point of adding them: the behaviour
was always undefined, and it is now visible rather than silent. Fifteen of the
twenty-two are `OFFNOM`, `TEST` or `DRV` requirements describing behaviour or
constraint the design does not yet have.

Three derived requirements -- `DRV-HK-03`, `DRV-HK-04` and `DRV-HK-05` -- carry
a `GAP` status because the constraint or reset style they require is absent from
the design. Like every derived requirement here they also await an independent
reviewer; see the
[derived register](../../../docs/requirements/derived-register.md).

Everything not `OK` is written up in
[`pa3-housekeeper-findings.md`](pa3-housekeeper-findings.md).

## Systems answers, and what is still pending

Values and readings were **proposed** to systems on 2026-09-29 (to Ryan
Strobel, who owns the FARSIGHT requirements in Jama), in answer to TBRs and
ambiguities in the FAR-PM_FPGA L4 set. **Avionics hardware (Dhruv) answered on
2026-10-01.** The requirements below are written, itemised and tested to the
answer where there is one, and to the proposal where there is not. Each
carries a note saying which.

Answered changes nothing in Jama by itself: the L4 wording is Ryan's to
change, and two rewordings were proposed back (L4REQ-6, L4REQ-14).

| Requirement | Value or reading | For | Answer, 2026-10-01 | Status |
| --- | --- | --- | --- | --- |
| `HK-IO-05` | Input filter 5 us +/-5 % | L4REQ-4, -5, -14, -17 | **Confirmed** | `OK` |
| `HK-UART-08` | Beacon every 1 s +/-5 % | L4REQ-15 | **Confirmed** | `OK` |
| `HK-UART-09` | First beacon within 1 s of the failure | L4REQ-15 | **Confirmed**: power is already off by then | `OK` |
| `HK-LAT-08` | Enables off within 10 us of the fault at the pin | L4REQ-14 | **Confirmed** for L4REQ-14, as "within 10 us of a falling edge on nFAULT ... as long as it remains low for 5 us +/- tolerance" -- proposed back as the L4REQ-14 wording. **Pending** for L4REQ-12 and -17, not addressed | `OK` |
| `HK-REG-05` | Region enables off within 10 us of a source failing | L4REQ-18 | **Pending**: not addressed | `GAP` on its hold |
| `HK-TLM-10` | Status change on the outputs within 1 us | L4REQ-28, -29 | **Confirmed** | `OK` |
| `HK-SRC-06` | Nominal boot time = the regulator's datasheet start-up with the fitted capacitor | L4REQ-11 | **Confirmed**, "either on the board schematic or in the testing that has been performed on the avionics board". **Pending**: that start-up means enable to PGOOD; values for the four rails without one; whether the per-source timeout is for SV1 | `GAP` |
| `HK-PROT-02` | Both IMX shorts on a latchup in any IMX supply | L4REQ-6 | **Answered, and the proposal was wrong**: the intent is to pull every IMX rail down as fast as possible on any of them latching. Rewording of L4REQ-6 proposed back | `OK` |
| `HK-SRC-01` | Per-source failure identity only in software-controlled regions | L4REQ-9, -30 | **Confirmed**: a failed hardware region leaves the PolarFire off | `GAP` (code 0, HK-F-06) |
| `HK-REG-01` | The PolarFire treats a single-bit region still low 1 s after it starts as failed | L4REQ-28 | **Pending**: "probably acceptable"; a PolarFire firmware obligation, for its owner to confirm | `OK` |
| `HK-SEQ-10` | Hardware boot complete within 6 s of reset release | L4REQ-8, -27 | **Pending**: a flight-software interface; for its owner | `OK` |
| `HK-IMPL-20` | CBE utilisation no more than 80 % per resource class at CDR | No Jama requirement | **Pending**: not answered | `GAP` |

`HK-PDN-07` is withdrawn on the 2026-10-01 answer (see Withdrawn). Still TBR
with no proposal: `HK-OFFNOM-08` (enables off after supply valid), whose value
comes from the device power-up specification and the board's supply ramp.

## Physical configuration reference

The design manages 33 power sources in 11 regions. Sources boot within a region
in the order listed; each source waits for the previous source in its region to
report success. "nFAULT" marks sources whose fault pin is wired; the remainder
have the `nfault` input of their source state machine tied to `1'b1`.

| Region | Boot order | nFAULT wired | Control | Design |
| --- | --- | --- | --- | --- |
| Step Down | 2V2, 3V0, 4V0 | all three | hardware | [`pwr_region_step_down_bootseq.sv:99-148`](../../src/pwr_region_step_down_bootseq.sv) |
| DDR8 | 2V5, 1V2, 0V6 | 2V5, 1V2 | hardware | [`pwr_region_ddr8_bootseq.sv:97-148`](../../src/pwr_region_ddr8_bootseq.sv) |
| DDR16 | 2V5, 1V2, 0V6 | 2V5, 1V2 | hardware | [`pwr_region_ddr16_bootseq.sv`](../../src/pwr_region_ddr16_bootseq.sv) |
| FPGA | 1V0, 1V0A, 1V25A, 1V8, 1V8_IMX, 2V5A, 3V3_B4, 3V3_B5 | 1V0 | hardware | [`pwr_region_fpga_bootseq.sv:139-266`](../../src/pwr_region_fpga_bootseq.sv) |
| LVDS | 3V3 | none | hardware | [`pwr_region_lvds_bootseq.sv`](../../src/pwr_region_lvds_bootseq.sv) |
| Eth1 | 1V0, 1V0A, 2V5A, 3V3 | none | software | [`pwr_region_eth1_bootseq.sv:103-166`](../../src/pwr_region_eth1_bootseq.sv) |
| Eth2 | 1V0, 1V0A, 2V5A, 3V3 | none | software | [`pwr_region_eth2_bootseq.sv`](../../src/pwr_region_eth2_bootseq.sv) |
| Stepper Pri | 28V0 | yes | software | [`pwr_region_stepper_pri_bootseq.sv`](../../src/pwr_region_stepper_pri_bootseq.sv) |
| Stepper Sec | 28V0 | yes | software | [`pwr_region_stepper_sec_bootseq.sv`](../../src/pwr_region_stepper_sec_bootseq.sv) |
| LVDT | 15V0 | none | software | [`pwr_region_lvdt_bootseq.sv`](../../src/pwr_region_lvdt_bootseq.sv) |
| IMX | 1V1, 1V8, 2V9, 3V3 | 1V1 | software | [`pwr_region_imx_bootseq.sv:104-167`](../../src/pwr_region_imx_bootseq.sv) |

## Derived timing constants

Every timer in the design is a `proasic3_counter`: a prescaler of
2^`CNTR_PRECISION` clock cycles driving a saturating `CNTR_RESOLUTION`-bit tick
counter ([`proasic3_counter.sv:30-51`](../../src/proasic3_counter.sv)). A
threshold is expressed as `TIME >> CNTR_PRECISION` ticks -- rounded up rather
than truncated for the boot timeout and the retry hold, so those err long --
so every interval is quantised to the prescaler period, and any threshold above
2^`CNTR_RESOLUTION`-1 can never be reached. All values below assume the
50 MHz clock and the synthesis defaults `PULSE_WIDTH = 250`,
`WAIT_TIME_MULT_FACTOR = 50` ([`top.sv:23-24`](../../src/top.sv)).

| Timer | Nominal | Prescaler | Threshold | Counter max | Realised | Reachable |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| Input glitch filter | 5 us | -- | 249 | 255 | 5.00 us | yes |
| Source boot timeout `WAIT_TIME` | 25 ms | 2^14 | 77, rounded up | 127 | 25.231 ms | yes |
| Source latchup hold `LATCHUP_WAIT_TIME` | 2.5 ms | 2^14 | 7 | 127 | 2.294 ms | yes |
| Source power-down timeout `PWR_DWN_WAIT_TIME` | 2.5 ms | 2^14 | 7 | 127 | 2.294 ms | yes |
| Region retry hold `RETRY_TIME` | 200 ms | 2^16 | 153, rounded up | 255 | 200.540 ms | yes |
| Start-up delay / heartbeat / broadcast `SECOND` | 1 s | 2^18 | 190 | 255 | 996.147 ms | yes |

The unreachable source boot timeout is finding
[`HK-F-01`](pa3-housekeeper-findings.md#hk-f-01) and is the reason six
requirements below carry `GAP` or `DEFECT`.

---

## IMPL -- Device, build configuration, mitigation

### HK-IMPL-01
The housekeeper shall be implemented on a Microsemi A3PE3000L-FG484M ProASIC3
device.
- **Parent:** FAR-AEPS_L3REQ-10
- **Design:** `constr/a3pe3000l-fg484m/io/fm/io_constraints.pdc:3`, `Makefile` `TARGET_BOARD`
- **Verify:** INSP
- **Status:** OK
- **Evidence:** Inspected in the flight build `fm_tmr` at commit `b67f8ad` (2026-10-01) (`test/inspect/build.py`): the
  synthesis project names part `A3PE3000L`, package `FBGA484`; place and route
  reports "Die: A3PE3000L Package: 484 FBGA" and junction temperature range
  `MIL`; and the programming file's own header says `extDie A3PE3000L`,
  `inPackage fg484`, `tempGrade MIL` -- the FG484M.

### HK-IMPL-02
All sequential logic in the flight build shall be implemented with triple
modular redundancy.
- **Constraint:** System-level radiation mitigation decision
- **Design:** `src/top.sv:20`, `src/top.sv:142-145`
- **Verify:** INSP
- **Note:** Reading `syn_radhardlevel="tmr"` in source does not verify this
  requirement; the attribute states an intent to the synthesiser and does not
  establish what the netlist contains. The criterion is that every sequential
  element in the synthesised netlist has a voted triplicate. An earlier
  criterion compared the sequential element count of two builds, which needed a
  non-delivered build to exist as a measurement reference and an arbitrary
  ratio to accommodate the voters; it is not used.
- **Rationale:** The ProASIC3 is flash-based, so its configuration memory does
  not upset and requires no scrubbing. Its flip-flops do upset, and TMR with
  voting is the available mitigation for a power-sequencing state machine whose
  corruption would mis-drive real rails.
- **Status:** OK
- **Evidence:** Inspected in the synthesised netlist of the flight build `fm_tmr` at commit `b67f8ad` (2026-10-01)
  (`test/inspect/build.py`): every one of its 6,519 flip-flops -- 6,369
  `DFN1`, 141 `DFN1C0`, 9 `DFN1P0`, and no latch or RAM -- is one of three
  whose `Q` outputs meet at one `MAJ3` voter, read from the netlist's
  connections rather than its instance names. The vendor CoreUART's 138 are
  among them. See [`HK-F-20`](pa3-housekeeper-findings.md#hk-f-20); voter
  refresh remains `HK-IMPL-10`'s.
- **Note:** Applied by a single `syn_radhardlevel="tmr"` attribute on `module
  top` (`src/top.sv:143`), enabled by `` `define TMR `` in the generated
  `src/build_variant.vh`, included at `src/top.sv:20`. In
  Synplify this propagates down the hierarchy unless a submodule overrides it;
  no submodule does, so the attribute nominally covers `health_monitor_io`,
  `health_monitor`, the 11 region modules, all 33 source state machines, the 51
  glitch filters, `dff_sync`, `reset_synchronizer`, `proasic3_counter` and
  `uart_ctrl`. The `make no-tmr` target comments the define out for a
  non-flight build.
- **Note:** **Known exclusions.** `UART0` is `Actel:DirectCore:COREUART:5.7.100`,
  instantiated from the block design rather than from `src/`
  (`bd/a3pe3000l-fg484m/components/UART0.tcl`). If it is delivered as a netlist
  or encrypted RTL it is a black box at synthesis and the attribute does not
  reach inside it -- leaving the IP that transmits the failure beacon
  unprotected. The clock network, the I/O pads and the `arstn` input are also
  not triplicated by TMR, so `ASIC_50MHZ_CLOCK` is common-mode to all three
  replicas. See [`HK-F-20`](pa3-housekeeper-findings.md#hk-f-20).
- **Note:** Status was previously **OK** on the strength of reading
  `syn_radhardlevel="tmr"` in source. That is not evidence. The attribute can be
  silently ineffective through wrong scope, an unsupported inference, or
  downstream optimisation, and nothing in the flow fails if it is. No synthesis
  report is retained, so the register-count check has never been performed and
  upset mitigation is unconfirmed. Retention of the report is
  clause 1.1 of the
  [FPGA Build and Disposition Plan](../../../docs/plans/fpga-build-and-disposition-plan.md).
- **Note:** This requirement absorbed `HK-IMPL-09`, which stated the report
  evidence as a separate requirement. Verifying this one necessarily produces
  that evidence, so the two were one requirement stated twice -- and because
  they carried different statuses, the pair read as OK and GAP simultaneously
  for the same property.

### HK-IMPL-03
Every state register in the design shall be synthesised with safe state
encoding.
- **Constraint:** System-level radiation mitigation decision
- **Design:** `src/pwr_region_sm.sv:51`, `src/pwr_src_bootseq.sv:50`, `src/uart_ctrl.sv:89`
- **Verify:** INSP
- **Rationale:** An upset into an unassigned encoding must return the state
  machine to a defined state rather than leave it stuck, because a power-region
  state machine stuck outside its encoding holds real rails in an
  indeterminate state.
- **Status:** GAP
- **Finding:** HK-F-31
- **Evidence:** Inspected in the synthesis report of the flight build `fm_tmr` at commit `b67f8ad` (2026-10-01)
  (`test/inspect/build.py`). Every encoding of the housekeeper's own state
  machines -- `curr_state` in `pwr_region_sm` and `pwr_src_bootseq`,
  `uart_state` in `uart_ctrl` -- carries Synplify's `MO195`, safe encoding
  with recovery to the reset state, and each enum state register in the source
  was extracted. The vendor UART's transmit state machine, `xmit_state`, is
  re-encoded one-hot without it. See
  [`HK-F-31`](pa3-housekeeper-findings.md#hk-f-31).
- **Note:** All three state machines carry `syn_encoding="safe"` and a `default`
  branch returning to `POWER_OFF`/`IDLE`
  (`src/pwr_region_sm.sv:174-176`, `src/pwr_src_bootseq.sv:139-141`,
  `src/uart_ctrl.sv:331`). `pwr_region_sm` declares seven states in a 3-bit
  encoding, leaving `3'd5` unassigned and covered by the default branch.

### HK-IMPL-04
The flight build shall contain no logic, conditional compilation or parameter
value whose purpose is to support simulation or test.
- **Source decision:** One source tree produces four synthesised variants, and its timing is scaled by a `WAIT_TIME_MULT_FACTOR` parameter that simulation is able to override.
- **Imposes on:** FPGA design, verification, build and release engineering
- **Design:** `src/top.sv:23-24`, `src/top.sv:142-145`, `synth_farsight_hk.tcl`, `Makefile`
- **Verify:** INSP
- **Rationale:** An accommodation left in the flight build means the thing
  verified is not the thing that flies. The failure is silent, because the
  accommodation usually makes simulation *easier* and so is never exercised in
  its flight form.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Evidence:** Inspected in the flight build `fm_tmr` at commit `b67f8ad` (2026-10-01) (`test/inspect/build.py`): the
  synthesis project sets no `-hdl_param` or `-hdl_define`; the manifest records
  a clean tree; `build_variant.vh` for `fm_tmr` defines only `TMR`; and the
  sources at that commit test no other compilation symbol and carry no
  `translate_off` or similar pragma. Parameters set inside the RTL are design,
  reviewed with it; what this checks is that the *build* sets nothing.
- **Evidence:** The only conditional compilation in `src/` is `` `define TMR ``,
  which selects a legitimate flight variant rather than a simulation
  accommodation -- see `HK-IMPL-02`. There are no `translate_off` pragmas, no
  `initial` blocks and no test-only ports. No build script overrides any timing
  parameter, so every synthesised variant uses the declared defaults.
- **Note:** The corresponding obligation on the verification side -- that the
  testbench exercise the flight parameter values rather than shortened ones -- is
  `VENV-02` in the [verification environment
  requirements](../../../docs/requirements/verification-environment-requirements.md),
  and it is **not** met. The testbench overrides
  `WAIT_TIME_MULT_FACTOR` from 50 to 3
  (`test/sim/pa3_health_monitor_io_tst_tb.sv:215`), which is the configuration
  in which the source boot timeout is reachable at all. See
  [`HK-F-01`](pa3-housekeeper-findings.md#hk-f-01). The design is clean; the
  divergence is introduced by verification.

### HK-IMPL-18
Each programming file shall identify the build variant it was produced from,
independently of where the file is stored.
- **Source decision:** The build produces four functionally different images
  from one source tree -- flight or engineering-model RS-422 pinout, crossed
  with TMR enabled or disabled -- selected by patching the working tree at build
  time rather than by a committed source difference.
- **Imposes on:** FPGA build and release engineering, configuration management
- **Design:** Not met. The variant is recorded only by the
  `programming_files/<variant>/` directory the file is filed under.
- **Verify:** INSP
- **Rationale:** Two of the four variants are unsafe to fly, and neither failure
  announces itself. An engineering-model image on the flight board swaps the
  RS-422 transmit and receive pins, which kills the payload link and sends the
  housekeeper failure broadcast out of the wrong pin -- the one diagnostic that
  matters when the PolarFire is already down. A no-TMR image on the flight board
  removes the radiation mitigation from a Class A part and behaves correctly
  until it is in orbit. Storage location is not identification: a directory is
  lost the first time a file is copied, emailed or attached to a release record.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** GAP
- **Evidence:** Inspected in the flight build `fm_tmr` at commit `b67f8ad` (2026-10-01) (`test/inspect/build.py`): the
  programming file's silicon signature (USERCODE) is empty, and so are its
  design-version fields. The file does contain the build directory's path,
  which happens to include `fm_tmr`, but a path is not an identifier: it
  changes with the build machine and nothing reads it.
- **Evidence:** All four images are built and filed. Their filenames differ only
  by build timestamp -- `farsight_hk_a3pe3000l-fg484m_<timestamp>_b049e8.pdb` --
  and all four carry the same commit id, `b049e8`.
- **Note:** The commit id cannot distinguish them by construction. `synth.tcl:70`
  takes it from `git rev-parse HEAD`, while the variants are produced by editing
  `src/top.sv` and `constr/a3pe3000l-fg484m/io/fm/io_constraints.pdc` in the working
  tree and restoring them from `.mkbak/` afterwards. The edits are never
  committed, so three of the four images carry a commit id describing source that
  does not produce them. See [`HK-F-22`](pa3-housekeeper-findings.md#hk-f-22).
- **Note:** Identifying the variant from the running device rather than from the
  file would be stronger, but is not currently possible: `fw_version` is a single
  bonded wire that reads 1 when the rails are up, per `HK-TLM-08` and
  [`HK-F-10`](pa3-housekeeper-findings.md#hk-f-10).
### HK-IMPL-10
The housekeeper shall remain tolerant to a single upset in its sequential logic
throughout the mission, rather than only until the first upset occurs.
- **Source decision:** Triple modular redundancy was adopted as the upset
  mitigation for a flash-based device whose configuration memory does not upset
  but whose flip-flops do.
- **Imposes on:** FPGA design, verification, radiation analysis
- **Design:** Not confirmed
- **Verify:** SIM
- **Note:** By fault injection -- inject an upset in one replica, then a second
  upset in a different replica, and confirm the voted output is still correct.
  Analysis of the voter topology supports this but does not replace it, so it
  is not carried as a second method; whether it is separately obligatory is a
  question for the plan.
- **Rationale:** Masking and refresh are not the same guarantee. If the voted
  value is not returned to the replicas by some means, the first upset leaves
  one replica permanently diverged; the design still masks that fault but has
  no remaining redundancy, so a second upset in either survivor produces a wrong
  output. Stated as continuous tolerance rather than as a voter topology because
  feedback refresh is one way to achieve it and periodic scrub or state re-init
  are others -- the requirement is the property, not the mechanism.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** GAP
- **Evidence:** The mechanism actually emitted for `syn_radhardlevel="tmr"` on
  the A3PE3000L has not been confirmed, so it is not known whether the design
  refreshes or masks only.
- **Note:** Verification must be by fault injection rather than by reading the
  attribute. An attribute states an intent to the synthesiser; it does not
  establish what the netlist does. The method belongs in the V&V plan; the
  obligation that the design hold the property belongs here.
- **Note:** This requirement has **no parent**, and that is a finding rather
  than an omission. The system baseline contains no requirement for tolerance to
  non-destructive single-event upsets. FAR-L1REQ-50 covers TID and FAR-L1REQ-49 covers
  *destructive* SEE; neither covers flip-flop upset, which is the hazard TMR
  exists to mitigate. See [`HK-F-23`](pa3-housekeeper-findings.md#hk-f-23).
---

---

### HK-IMPL-20
At CDR, the current best estimate (CBE) of the flight build's utilisation shall
be no more than 80 % of each resource class of the device, where for each
resource class r, CBE_r = (U_r / A_r) x 100 %: U_r is the use of class r
reported after place-and-route of the latest flight-configuration build (TMR
enabled, flight pinout), and A_r is what the device provides.
- **Source decision:** Triple modular redundancy was adopted across all
  sequential logic, which triples the register count and adds a voter to every
  replicated path, so the device's capacity becomes a design constraint rather
  than a background assumption.
- **Imposes on:** FPGA design, verification, programmatics
- **Design:** `src/top.sv:143`
- **Kind:** Performance
- **Verify:** INSP, ANA
- **Rationale:** A build that fits with no margin cannot absorb the changes this
  requirement set already asks for -- asynchronous reset on every register
  (`DRV-HK-05`), the recovery paths of `HK-OFFNOM-01` to `HK-OFFNOM-04`, and any
  fix arising from the open findings. Discovering the device is full at that
  point is discovering it too late, because the alternatives are removing
  mitigation or changing the part.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Finding:** HK-F-26
- **Status:** GAP
- **Evidence:** No utilisation figure is recorded anywhere in the repository, for
  either the TMR or the non-TMR build. `HK-F-20` separately records that TMR
  coverage itself is unverified, so neither the cost nor the extent of the
  mitigation is currently known.
- **Note:** The resource classes are core cells, RAM blocks, I/O and global
  clock networks. Per class rather than overall, so that a full core cannot be
  averaged against an empty RAM budget. Measured after place-and-route rather
  than synthesis, because the post-layout figure is the one that decides
  whether the design fits; on the TMR build, because the non-TMR build uses a
  third of the registers and would pass while saying nothing about what flies.
- **Note:** **Pending systems confirmation.** 80 % CBE at CDR is the margin
  policy proposed to systems on 2026-09-29; the margin was TBR and no Jama
  requirement carries it. Not addressed in the 2026-10-01 answer. Revisit this requirement and `VC-HK-0015` when the
  answer is in, and update
  [`tbr-register.md`](../../../docs/requirements/tbr-register.md).

## CLK -- Clock and reset

### HK-CLK-01
The housekeeper shall operate from a single 50 MHz free-running clock.
- **Source decision:** The board supplies the housekeeper a single free-running oscillator, and no PLL or clock-management block was instantiated in the device.
- **Imposes on:** FPGA design, hardware design, timing closure
- **Design:** `constr/a3pe3000l-fg484m/sdc/timing_user_constraints.sdc:5`, `src/top.sv:176`
- **Verify:** INSP, HW
- **Rationale:** A single free-running clock removes internal clock-domain crossings entirely, which for a Class A power sequencer is worth more than the flexibility a second domain would buy. Free-running matters because the housekeeper must keep sequencing while every other clock source on the board is still unpowered.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Evidence:** Inspected (`test/inspect/clock.py`): the SDC declares one
  `create_clock`, 20 ns on `clk`, and no generated clock. In the design as
  Verilator elaborates it (`fm_tmr`, vendor UART core included), every edge of
  all 223 clocked blocks' clocks traces back through the hierarchy to the
  top-level `clk` with no register or logic on the way -- no generated,
  derived or gated clock. The asynchronous resets trace to `arstn` or to the
  reset synchroniser's output register.
- **Note:** The SDC constrains `clk` to a 20.000 ns period. The schematic
  confirms pin `L4` is net `ASIC_50MHZ_CLOCK`.
- **Evidence:** The design is currently realised as a single clock domain. One
  clock and one asynchronous clock group are declared
  (`constr/a3pe3000l-fg484m/sdc/timing_user_constraints.sdc:5,:10`) and every
  flip-flop in `src/` is clocked by `clk`, so there is no internal clock-domain
  crossing to analyse today. That is a property of the current implementation,
  not a requirement; the obligation that binds if a second clock is introduced
  is `DRV-HK-07`.

### HK-CLK-03
The housekeeper shall accept an active-low asynchronous reset input.
- **Parent:** FAR-AB_L2REQ-9
- **Design:** `src/top.sv:75`, `src/health_monitor_io.sv:326-332`
- **Verify:** SIM
- **Finding:** HK-F-18
- **Status:** GAP
- **Evidence:** The port is `arstn`, schematic pin `P22`, net `PA3_RESET`. It
  is accepted asynchronously, but acted on synchronously: with the device
  booted and the clock stopped, `arstn` asserted between edges and held for
  1 us left all 32 outputs that were away from their reset state where they
  were; restarting the clock with reset held reached the reset state on every
  output (`verification/tests/test_hk_clk.py`). Every register behind the
  synchroniser is reset inside `always_ff @(posedge clk)` -- `DRV-HK-05`.

### HK-CLK-04
Reset shall be asserted asynchronously and released synchronously to the
housekeeper clock.
- **Source decision:** An asynchronous-assert, synchronous-release reset architecture was adopted, so that the design is held reset even with no clock running.
- **Imposes on:** FPGA design, timing closure, verification
- **Design:** `src/reset_synchronizer.sv:25-32`
- **Verify:** SIM
- **Rationale:** Asynchronous assertion guarantees the design is held reset
  even with no clock running; synchronous release guarantees every element
  leaves reset in a known relationship to the clock edge rather than
  metastably. The timing obligation that this creates is `DRV-HK-03`.
- **Evidence:** A shift-register synchroniser instantiated with `NUM_STAGES = 4`
  (`src/health_monitor_io.sv:326-328`), so the internal reset is held for four
  clock cycles after the external input releases. The module's header comment
  claims ten cycles and its default parameter is three; both are stale, see
  [`HK-F-08`](pa3-housekeeper-findings.md#hk-f-08). Depth is a design choice
  above the two stages a synchroniser needs, not a required figure.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Finding:** HK-F-18
- **Status:** GAP
- **Evidence:** Release is synchronous: released 3 ns and 13 ns into a clock
  period, the first enable asserted exactly 49,807,368 clocks after the next
  edge both times. Assertion is not asynchronous in effect: with the clock
  stopped, `arstn` asserted left `step_down_en_2v2` asserted
  (`verification/tests/test_hk_clk.py`). The synchroniser's own assertion is
  asynchronous; the registers it resets are not.

### HK-CLK-06
The flight build shall meet setup and hold timing at 50 MHz with positive slack
on every path.
- **Source decision:** The housekeeper was implemented as a single synchronous
  design on a board-supplied 50 MHz clock, so correctness depends on static
  timing closure rather than on any handshake.
- **Imposes on:** FPGA design, timing closure, verification
- **Design:** `constr/a3pe3000l-fg484m/sdc/timing_user_constraints.sdc:5`
- **Kind:** Performance
- **Verify:** ANA
- **Rationale:** Simulation cannot find a setup violation and the design has no
  mechanism that would tolerate one; a path that fails timing produces wrong
  sequencing intermittently and in flight. `DRV-HK-06` bounds the intervals the
  design produces against the reference frequency, which is a different question
  from whether the logic closes at that frequency at all.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Finding:** HK-F-26
- **Status:** GAP
- **Evidence:** `HK-F-16` records that timing constraints are essentially absent:
  the SDC declares the clock but leaves reset release and the synchroniser inputs
  unconstrained, so a closure report against it would not cover the paths that
  matter.

### DRV-HK-03
The reset release path shall be constrained and analysed as a synchronous
timing path, such that every sequential element in the design leaves reset on
the same clock edge.
- **Source decision:** An asynchronous-assert / synchronous-release reset
  architecture was adopted, and the synchronised `rstn` is distributed to
  essentially every sequential element in the design -- 33 source state
  machines, 11 region state machines, the glitch filters and the UART
  controller.
- **Imposes on:** FPGA design, timing closure, verification
- **Design:** `src/reset_synchronizer.sv:25-32`; `constr/a3pe3000l-fg484m/sdc/timing_user_constraints.sdc`
- **Verify:** ANA, SIM
- **Note:** The analysis evidence is the static timing report.
- **Rationale:** Two distinct exposures, both of which vary build to build.
  First, reset *deassertion* at an asynchronous clear pin is a recovery/removal
  check rather than a setup/hold check, and whether those checks are generated
  at all depends on the device, the tool and the flow -- a path that feeds an
  asynchronous flip-flop input can be silently left unanalysed. Second, `rstn`
  has near-total design fanout, so without a bounded path delay the tool is
  free to route it long; if it arrives after the clock edge at some elements,
  those elements leave reset one cycle late and the power-up sequence differs
  between builds of identical RTL.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** GAP
- **Note:** Its SIM half has no meaningful RTL form: in RTL `rstn` is one net
  with no delay, so every element leaves reset on the same edge by
  construction. What this guards against is routing skew, which exists only
  after place and route, so the simulation item (VC-HK-0115) calls for a
  gate-level simulation with SDF and is not yet written. `HK-CLK-04` shows the
  RTL half: the release acts on a clock edge at whatever phase it arrives.
- **Note:** Not currently constrained. The SDC contains only a `create_clock`
  and a `set_clock_groups`; there is no recovery/removal constraint, no
  `set_max_delay` and no maximum-skew bound on the reset network. Confirm that
  the Libero/Synplify flow for the A3PE3000L emits recovery and removal checks
  for the `arstn` clear pins of `reset_synchronizer`, and that they are
  reported as met rather than as unconstrained.
- **Note:** Within this design only `reset_synchronizer` uses an asynchronous
  reset (`src/reset_synchronizer.sv:25`); all other modules consume `rstn`
  synchronously inside `always_ff @(posedge clk)`. That makes the downstream
  fanout an ordinary synchronous path, which is exactly why it must be
  constrained as one rather than assumed safe.

### DRV-HK-04
Every asynchronous input path into the first stage of a synchroniser shall be
constrained with a maximum delay of less than one period of the receiving
clock.
- **Source decision:** 51 asynchronous external inputs -- PGOOD, nFAULT, the
  EPS eFuse discrete and the six PolarFire control lines -- are brought into the
  50 MHz domain through two-stage synchronisers rather than being sampled by a
  common clock.
- **Imposes on:** FPGA design, timing closure, verification
- **Design:** `src/dff_sync.sv:24-28`, `src/health_monitor_io.sv:334-354`, `:357-407`
- **Verify:** ANA, INSP
- **Note:** The analysis evidence is the static timing report.
- **Rationale:** The path from the input pin to the first synchroniser stage is
  otherwise unconstrained, so the tool may route it arbitrarily long and may
  place the two synchroniser stages far apart. A long first-stage path consumes
  the metastability settling budget that the second stage exists to provide, and
  for the multi-bit synchronised groups -- 45 PGOOD/nFAULT bits and 6 control
  bits captured together -- inter-bit skew above one clock period lets bits of
  the same sample land on different cycles. Bounding the path below one
  receiving clock period bounds both effects and makes the captured behaviour
  repeatable across builds of identical RTL.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** GAP
- **Note:** Not currently constrained. The SDC has no `set_max_delay` and no
  `set_input_delay` on any port. At 50 MHz the bound is < 20 ns. Note that the
  PGOOD and nFAULT groups are individually glitch-filtered afterwards
  (`HK-IO-05`), which tolerates skew on those bits; the six control inputs are
  **not** filtered (`HK-IO-06`), so they are the group most exposed to this.


### DRV-HK-05
Every register in the design shall be asynchronously reset to a defined state,
unless that register is individually recorded as an approved exception.
- **Source decision:** A synchronous reset style was adopted for the design
  body: only `reset_synchronizer` uses an asynchronous reset, and all 13 other
  modules apply `rstn` synchronously inside `always_ff @(posedge clk)`. A
  further 13 registers carry no reset at all.
- **Imposes on:** FPGA design, timing closure, verification, board design
- **Design:** `src/pwr_src_bootseq.sv:145-151`, `src/pwr_region_sm.sv:180-188`, `src/health_monitor.sv:510-521`, `src/health_monitor.sv:663`; contrast `src/reset_synchronizer.sv:25`
- **Verify:** SIM, INSP
- **Rationale:** A synchronously reset register cannot be cleared without a
  clock. If the 50 MHz reference stops, every such register holds its last value
  and reset cannot recover it, so the payload can be left with rails energised in
  a partial boot state and with latchup detection frozen. An asynchronous reset
  drives the register to its safe value -- `pwr_en` resets to 0 -- with no clock
  required.

  Stated over every register rather than over the power-related ones because the
  narrower scope is not safely decidable. It requires someone to classify each
  register as power-related or not, and that classification is unreliable in
  exactly the cases that matter: `eth1_ctrl_r1` and its five siblings
  (`src/health_monitor.sv:663`) are edge-detection history registers, which no
  reasonable reading calls power sequencing state, yet one powering up at 0 while
  its control input is already 1 synthesises a false rising edge -- the exact
  condition `HK-SEQ-05` uses to energise a region. A register that does not look
  like power state can still turn a rail on.

  The default also runs the right way. Under a scoped rule a register added later
  is outside it until someone notices; under this rule it is inside it until
  someone writes down why not. For a Class A power sequencer the burden belongs
  on the exception.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** GAP
- **Evidence:** Inspected in the elaborated design (`test/inspect/reset.py`):
  42 registers have an asynchronous reset -- the reset synchroniser's and the
  vendor UART core's -- and 84, every other register of the housekeeper's own
  modules, have none. No approved exception is recorded, so every one is
  listed.
- **Evidence:** Simulated, every register enumerated from the RTL and every
  instance read: 469 reached, 243 moved away from their reset value by a
  boot, and with the clock stopped and reset asserted exactly one returned to
  it -- `reset_synchronizer.rstn_r10`. The other 242 stayed where they were,
  among them all 22 `pwr_en` source enables that had been asserted
  (`verification/tests/test_hk_drv_reset.py`). Twelve registers have no reset
  branch at all in the RTL; the lint count of 13 in `HK-F-18` is of
  synthesised flip-flops.
- **Note:** An exception is a register whose reset genuinely costs more than it
  is worth -- deep datapath pipelining is the usual case, and this design has
  none. Recording one means naming the register, the reason, and an approver,
  under clause 2 of the [FPGA Build and Disposition
  Plan](../../../docs/plans/fpga-build-and-disposition-plan.md). "No issue with
  no set/reset" is not an exception record; it asserts the conclusion.
- **Note:** This subsumes the 13 registers that carry no reset at all
  (`src/health_monitor.sv:663` and three others), which were governed by no
  requirement. They are neither asynchronously reset nor recorded as exceptions.
  See [`HK-F-18`](pa3-housekeeper-findings.md#hk-f-18).
- **Note:** On the A3PE3000L the flip-flops have dedicated asynchronous
  clear/preset inputs, so this costs little or no additional logic. The common
  guidance to prefer synchronous reset is a modern Xilinx/Intel argument about
  packing into DSP and block-RAM primitives and does not transfer to this
  device.
- **Note:** Reset must remain asynchronous in assertion and synchronous in
  release, per `HK-CLK-04`. Extending async reset to the design body widens the
  recovery/removal analysis obligation of `DRV-HK-03` from the four
  synchroniser flip-flops to every reset flip-flop in the design -- that
  analysis becomes load-bearing rather than incidental.
- **Note:** Interaction with TMR (`HK-IMPL-02`) must be checked rather than
  assumed; voter behaviour around asynchronous resets is not automatically
  equivalent to the synchronous case.
- **Note:** **This requirement alone does not close
  [`HK-OFFNOM-04`](#hk-offnom-04).** It supplies the mechanism; nothing on the
  board can currently assert `arstn` on orbit. See
  [`HK-F-17`](pa3-housekeeper-findings.md#hk-f-17).

### DRV-HK-06
Every interval and rate derived from the 50 MHz reference shall meet its stated
tolerance across the full operating temperature range and the full mission life,
using the worst-case total frequency error of the fitted oscillator.
- **Source decision:** All timing in the housekeeper is counted from a single
  free-running board oscillator. There is no temperature compensation, no
  calibration path and no discipline from an external reference, so every
  interval inherits that oscillator's error directly.
- **Imposes on:** HK FPGA design, board design, verification, ICD
- **Design:** `src/health_monitor.sv:158`, `src/uart_ctrl.sv:64-65`, `src/top.sv:23-24`
- **Kind:** Performance
- **Verify:** ANA, HW
- **Rationale:** The oscillator's total frequency error is the sum of initial
  tolerance, temperature stability, and aging over life -- not initial tolerance
  alone. Every housekeeper interval scales with it: the 5 us glitch filter, the
  25 ms boot timeout, the 200 ms retry hold, the 1 s heartbeat and broadcast
  period, and the UART bit period. A tolerance stated only at nominal
  temperature on a new unit is not a flight tolerance.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** GAP
- **Note:** The tightest budget is the **UART bit rate**, because it is the only
  interval that must agree with an *external* party rather than merely be
  self-consistent. `BAUD_VAL` = 26 gives 50 MHz / (27 x 16) = 115,740.74 baud,
  already **+0.47 %** against the 115,200 required by `HK-UART-05` before any
  drift is added. Oscillator drift over temperature and life is small against
  that, of order +/-0.01 % for a typical XO, so the divisor choice dominates. The
  budget that must close is the housekeeper's total error *plus the bus
  receiver's*, against the receiver's tolerance. State that budget rather than
  assuming it.
- **Note:** The remaining intervals are self-referential -- a boot timeout and
  the rail it times are both measured in the same clock -- so drift shifts them
  together and the margins are wide. They are bounded by this requirement for
  completeness, not because they are at risk.
- **Note:** The fitted oscillator is not determined. `ASIC_50MHZ_CLOCK` is
  driven by two alternative parts, `Y10` (`ECS-3225MVQ-500-BP-TR`) and `Y6`
  (`X35T-L7M-50.000MHZ`). The worst case of the two governs until the stuff
  option is resolved. See [`HK-F-19`](pa3-housekeeper-findings.md#hk-f-19).
- **Note:** Both datasheets were read on 2026-10-01. Y6 is +/-75 ppm overall,
  including tolerance, temperature, supply, load and five years' ageing. Y10
  is +/-50 ppm over temperature plus 3 ppm a year of ageing, so +/-65 ppm at
  five years and +/-80 ppm at ten. Against the UART's +0.47 % divisor error
  either is under a fiftieth, so the UART budget is set by the divisor and
  the receiver; what is still missing is the receiver's tolerance and the
  mission life to age over.


### DRV-HK-07
Static timing analysis shall be closed at the worst-case process, voltage and
temperature corners of the range over which the housekeeper is required to
operate.
- **Source decision:** The housekeeper is the power sequencer, so it must
  function at the temperature at which the payload is commanded on -- which may
  be colder than the operational range of the subsystems it brings up.
- **Imposes on:** HK FPGA design, timing closure, verification, thermal analysis
- **Design:** `constr/a3pe3000l-fg484m/sdc/timing_user_constraints.sdc`
- **Verify:** ANA
- **Rationale:** A single-corner timing result is not a flight result. Both
  extremes must be checked rather than assuming the hot corner is worst: at low
  core voltage some technologies exhibit temperature inversion, where the cold
  corner is the slow one.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** GAP
- **Note:** Blocked on `HW-ENV-03` -- the range to close against is not defined.
  If the payload can be commanded on at the cold survival limit, this analysis
  must be run at the **survival** limit, not the operational one.
- **Note:** The device is an `A3PE3000L-FG484M`; the `M` suffix indicates an
  extended temperature grade, so there is likely margin. Device capability is
  not a substitute for a requirement, and no corner analysis evidence exists
  today. See also [`HK-F-16`](pa3-housekeeper-findings.md#hk-f-16), which notes
  the constraint file has no I/O timing at all.

---

## IO -- Pin mapping, input conditioning, synchronisation

### HK-IO-01
Every top-level port of the design shall be assigned to a physical pin, or be
named in an active constraint entry that records it as deliberately unplaced.
- **Source decision:** The design is realised on a specific package, so the binding of top-level ports to physical pins is carried by a constraint file outside the RTL and is not checked by compilation.
- **Imposes on:** FPGA design, hardware design
- **Design:** `constr/a3pe3000l-fg484m/io/fm/io_constraints.pdc`
- **Verify:** INSP
- **Rationale:** An unplaced port is silently tied off or left floating by the tools rather than reported as an error, so a port that is missing from the constraint file produces a build that looks successful and a pin that does nothing. Recording a port as deliberately unplaced distinguishes that decision from an omission.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Finding:** HK-F-24
- **Status:** GAP
- **Evidence:** Inspected (`test/inspect/pins.py`): all 131 port bits against
  the active `set_io` lines of both pinouts. `fw_version[0]` and
  `fw_version[2]` have no pin in either; nothing else is unplaced, and no
  constraint names a port the design does not have.
- **Note:** All 131 bit-level top-level ports appear in the PDC, but
  `fw_version[0]` and `fw_version[2]` appear only as commented-out entries with
  an empty `pinname` (`io_constraints.pdc:175,177`), so both are unplaced. A
  commented-out line is indistinguishable from an omission: it carries no
  statement that the port was meant to be left unplaced. Reworded from
  "explicitly recorded as unplaced", which no artefact could be checked against.
  See `HK-TLM-08` and `HK-F-24`.

### HK-IO-02
Every assigned pin shall correspond to a real pin of the A3PE3000L-FG484M.
- **Source decision:** As `HK-IO-01`. A pin name that is not a pin of the device is accepted by the constraint file and fails only at place and route, or silently leaves the port unplaced.
- **Imposes on:** FPGA design, hardware design
- **Design:** `constr/a3pe3000l-fg484m/io/fm/io_constraints.pdc`; `verification/board/CM-03545.json`
- **Verify:** INSP
- **Rationale:** A misplaced pin assignment is not caught by synthesis or by
  simulation; it produces a build that programs successfully and does nothing.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Evidence:** Inspected (`test/inspect/pins.py`): every assignment in both
  pinouts is one of the 484 balls of U2 in the flight schematic (CM-03543 rev
  2), and a user I/O ball by the vendor's pin name (`IO305PDB7V3`,
  `GFB0/IO274NPB7V0`). The device symbol stands in for the vendor's package
  pin list.
- **Note:** All 129 placed assignments resolve to real PA3 pins. Checked
  automatically by
  [`gen_trace_matrix.py`](../../../docs/requirements/gen_trace_matrix.py).

### HK-IO-08
Every assigned pin shall connect to the net implied by its port name.
- **Source decision:** Port naming is the only link between the RTL and the board; nothing in either artefact enforces that a port named for one net is assigned to that net.
- **Imposes on:** FPGA design, hardware design
- **Design:** `constr/a3pe3000l-fg484m/io/fm/io_constraints.pdc`; `verification/board/CM-03545.json`
- **Verify:** INSP
- **Rationale:** A pin that is real but wired to the wrong net is the same
  class of silent failure, and is the only way to catch a signal that the
  board does not actually route.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** GAP
- **Evidence:** Inspected against the flight schematic, CM-03543 rev 2
  (`test/inspect/pins.py`). "The net implied by its port name" is the transform
  written down there: the net on the pad or one series resistor beyond it;
  `PA3_TO_PF_MISCn` and `PF_TO_PA3_MISCn` named for their direction, so an
  output must be on the first and an input on the second; `debug[n]` on
  `BANK2_DEBUGn`; otherwise every word of the port name, with the region in
  the board's words (`ddr8` is `8GB`, `lvds` is `3V3_MISC`), in the net's
  name, which may add only a rail voltage, `ECC`, `VTT` or `PA3`; and three
  ports named for their source (`clk`, `arstn`, `imx_ctrl`), each with the net
  it must be on. Of 129 placed pins, four fail: `ddr8_en_0v6` and
  `ddr16_en_0v6` connect to nothing, `fw_version[1]` is an output on
  `PF_TO_PA3_MISC0` and `lvdt_ctrl` an input on `PA3_TO_PF_MISC16` (HK-F-24).
- **Note:** Two enable outputs resolve to unconnected single-pin nets -- see
  [`HK-F-02`](pa3-housekeeper-findings.md#hk-f-02). Two control nets carry a
  direction opposite to the RTL port direction -- see
  [`HK-F-07`](pa3-housekeeper-findings.md#hk-f-07) and
  [`HK-F-24`](pa3-housekeeper-findings.md#hk-f-24).



### HK-IO-09
Every output shall be held in its inactive state, by an internal pull of the
polarity that corresponds to inactive, from the moment the I/O ring is powered
until the design drives it. An output that has no inactive state to hold shall
be recorded as an approved exception.
- **Source decision:** The housekeeper's outputs are not driven by the design
  until configuration completes, so what each pin does in that window is set by
  the I/O constraint file rather than by the RTL.
- **Imposes on:** FPGA design
- **Design:** `constr/a3pe3000l-fg484m/io/fm/io_constraints.pdc`
- **Verify:** INSP
- **Rationale:** Between the I/O ring powering and the design driving the pin,
  nothing else defines the output. An enable that drifts high in that window
  energises a rail with no sequencing behind it, which is the one thing the
  power sequencer exists to prevent.

  Stated over every output, and in terms of the inactive state rather than of a
  pull-down, for two reasons. The polarity is not uniform: `imx_nshort_1v1` and
  `imx_nshort_1v8` are active low and reset high (`src/health_monitor.sv:678-680`),
  so *down* would assert a short across the IMX supplies -- the opposite of safe.
  And the hazard is not confined to enables: `pf_status_to_pf` carries
  `fpga_boot_succeeded` (`src/health_monitor_io.sv:320`), so a float high reports
  a booted FPGA region to the PolarFire before the housekeeper has run at all.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Finding:** HK-F-25
- **Status:** GAP
- **Evidence:** Inspected in both pinouts, with the flight board's pulls
  beside each failure (`test/inspect/pins.py`). The 14 unpulled outputs below
  fail, and the board adds no pull to any of them; nine of them have no
  inactive level and no approved exception yet. The board does hold every
  on-board regulator enable low through its own pull-down, beyond the series
  resistor -- a second, external guarantee for the enables this requirement
  does not count.
- **Evidence:** Of 74 placed outputs, 58 carry `RES_PULL "DOWN"`, 2 carry
  `RES_PULL "UP"` and 14 carry `"NONE"`. All 33 power enables and all 16 failure
  metadata bits are pulled down. The two `imx_nshort_*` outputs are pulled up,
  which matches their active-low sense and is the requirement met, not breached.
- **Note:** Three of the twelve `*_status_to_pf` outputs -- `pf_status_to_pf`,
  `step_down_status_to_pf` and `pa3_status_to_pf` -- carry no pull while the
  other nine carry a pull-down. All three are active-high health indications, so
  the omission is not a different decision, it is the same decision not taken.
  Raised as `HK-F-25`.
- **Note:** The remaining unpulled outputs are `heartbeat`, `fw_version[1]`, the
  seven `debug` bits and the two `rs422_ttl_*` pass-through pins. The first nine
  are candidates for a recorded exception: a stalled heartbeat and an unread
  debug pin are both fail-safe. The RS-422 pair is not a candidate, and each
  has a defined inactive level: the line to the PolarFire
  (`rs422_ttl_bus_to_farsight_pf`) is held low until the FPGA region has booted
  (`HK-UART-02`, required by FAR-PM_FPGA_L4REQ-3), so its pull is down; the line
  to the bus (`rs422_ttl_farsight_to_bus_pa3`) idles high (`HK-UART-10`), so its
  pull is up. Both are `"NONE"` today.
- **Note:** This covers only the window in which the FPGA is powered. It cannot
  cover the case where the housekeeper is unpowered, because an internal
  pull-down is a property of a powered I/O ring and does not exist then. That
  case is a hardware obligation and is stated as `HW-FPGA-10`.
- **Note:** Replaces the withdrawn `HK-IO-03`, which stated the LVCMOS33
  standard and demanded *no* internal pull resistor. The design does the
  opposite, deliberately and correctly. Rewritten again from "every power enable
  output shall be configured with an internal pull-down", which was true of the
  enables but said nothing about the other 41 outputs and could not express the
  `imx_nshort_*` polarity.

### HK-IO-04
Every input shall be captured by a means appropriate to its timing relationship
with the capturing clock.
- **Source decision:** The housekeeper takes 51 external inputs from comparators, eFuses and the PolarFire, none of which has a defined phase relationship to the 50 MHz clock.
- **Imposes on:** FPGA design, timing closure, verification
- **Design:** `src/health_monitor_io.sv:334-354` (6 control inputs), `src/health_monitor_io.sv:357-407` (45 PGOOD/nFAULT inputs), `src/dff_sync.sv:24-28`
- **Verify:** INSP, ANA
- **Rationale:** An input with no defined phase relationship to the capturing
  clock can violate setup or hold and go metastable, so it must be
  synchronised. An input that does have a defined relationship -- a
  source-synchronous or otherwise timing-constrained interface -- must instead
  be constrained and shown to close in static timing analysis. Synchronising
  the latter is not merely unnecessary: it destroys the phase relationship the
  interface depends on and adds latency the protocol may not tolerate.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Evidence:** Inspected in the elaborated design (`test/inspect/capture.py`):
  every input followed down the hierarchy. All 51 functional inputs and the
  reset reach logic only through the data input of a synchroniser -- `dff_sync`
  (2 stages) or `reset_synchronizer` (4) -- each confirmed a register chain;
  the two RS-422 inputs are read only by the continuous assignments that
  forward them (`uart_ctrl.sv:106,108`). No input is constrained, and none is
  unclassified.
- **Note:** Stated as an obligation rather than a mechanism, so that it remains
  correct if a constrained interface is ever added to this device. The two
  categories and their acceptable treatments:
  **(a) asynchronous** -- no defined phase relationship; synchronise before use.
  **(b) constrained** -- defined phase relationship; do not synchronise,
  constrain with input delay and close in static timing.
- **Evidence:** All 51 asynchronous functional inputs of this design fall in
  category (a) and are synchronised with a two-stage flip-flop synchroniser,
  which meets the metastability MTBF target for this device at 50 MHz. The
  housekeeper currently has no category (b) interface; the PolarFire does -- see
  `DRV-PF-06`.
- **Note:** The RS-422 pass-through inputs are in neither category: they are
  combinationally forwarded rather than captured, so no synchroniser applies.
  See `HK-UART-01`.

### HK-IO-05
Every PGOOD, nFAULT and EPS eFuse PGOOD input shall be filtered such that a
low-to-high or high-to-low transition is propagated only once the input has
been stable at the new level for 5 us +/-5 %: a level held for less than
4.75 us is not propagated, and one held for 5.25 us or more is.
- **Parent:** FAR-PM_FPGA_L4REQ-20, FAR-PM_FPGA_L4REQ-14, FAR-PM_FPGA_L4REQ-17, FAR-PM_FPGA_L4REQ-4, FAR-PM_FPGA_L4REQ-5
- **Design:** `src/top.sv:23`, `src/glitch_filter.sv:26`, `src/glitch_filter.sv:39-49`
- **Kind:** Performance
- **Verify:** SIM
- **Rationale:** Both transitions carry meaning and both must be qualified. A
  low-to-high transition on PGOOD declares a source booted (`HK-SRC-05`); a
  high-to-low transition on PGOOD or nFAULT declares a latchup (`HK-SRC-07`) or
  completes a power-down (`HK-SRC-11`). Filtering only one of the two would
  leave the other able to act on noise.
- **Status:** OK
- **Evidence:** The filter is symmetric by construction:
  `edge_det = d_in_r1 ^ d_in` (`src/glitch_filter.sv:26`) is an exclusive-or, so
  it fires on any transition, and low-to-high and high-to-low reset the counter
  identically. The output updates only once the counter reaches
  `PULSE_WIDTH-1` without an intervening edge. `PULSE_WIDTH = 250` at 50 MHz is
  exactly 5.00 us, in the middle of the band; sampling an asynchronous input
  moves it by one clock (0.4 %) and oscillator drift by far less. Measured on
  all 45 inputs, both directions, at the filter output: a 4.74 us pulse does
  not pass and a 5.26 us level does, with a pin-to-filter latency of 252
  clocks for every one (`verification/tests/test_hk_io_filter.py`). An
  earlier run of the same test at the exact threshold showed 249 clocks
  blocked and 250 passed.
- **Note:** This single mechanism is what implements the 5 us qualification
  required by FAR-PM_FPGA_L4REQ-20, FAR-PM_FPGA_L4REQ-14, FAR-PM_FPGA_L4REQ-17, FAR-PM_FPGA_L4REQ-4 and FAR-PM_FPGA_L4REQ-5.
- **Note:** **Confirmed by systems, 2026-10-01** (Dhruv, avionics hardware).
  The +/-5 % band was proposed on 2026-09-29 for the "(TBR) 5us" of
  FAR-PM_FPGA_L4REQ-4, -5 and -14 and the ">= 5 us" of -17. Previously "at
  least 5 us", which is one-sided and could not be tested against an
  oscillator that drifts. Either oscillator option (`DRV-HK-06`) is within
  +/-100 ppm over a long mission, which moves the threshold by under 0.5 ns.
  The Jama text still says "(TBR) 5us" until it is updated.
- **Note:** The filter output is not held at a safe value through reset. On
  reset `d_out` is loaded from `d_in_r1` (`src/glitch_filter.sv:36`), which is
  itself an unreset register (`src/glitch_filter.sv:51-53`), so the filtered
  value is indeterminate for the first cycles after reset rather than
  defaulting to a defined state. This is two of the 13 unreset registers in
  [`HK-F-18`](pa3-housekeeper-findings.md#hk-f-18).

### HK-IO-06
Every input by which the PolarFire commands a software-controlled power region
shall be filtered such that a low-to-high or high-to-low transition is
propagated only after the input has been stable at the new level for at least
5 us.
- **Source decision:** The PolarFire commands the software-controlled regions through a CoreGPIO output register, and the housekeeper acts on a rising edge of those lines.
- **Imposes on:** FPGA design, PolarFire firmware, verification
- **Design:** `src/health_monitor_io.sv:334-354`, `src/health_monitor_io.sv:745-784`
- **Kind:** Performance
- **Verify:** SIM, INSP
- **Rationale:** The housekeeper acts on these inputs in two ways, and a
  transient on either is consequential. A low-to-high transition arms a
  software-controlled region (`HK-SEQ-05`); a low level tears one down
  (`HK-SW-06`). Neither is a request the PolarFire made, so an unfiltered
  transient lets the housekeeper energise or de-energise real rails with no
  command behind it.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** GAP
- **Evidence:** The six inputs are `eth1_ctrl`, `eth2_ctrl`, `stepper_pri_ctrl`,
  `stepper_sec_ctrl`, `lvdt_ctrl` and `imx_ctrl`. On every one, a high pulse of
  one clock and of 249 clocks started its region, and a low pulse of each
  powered it down -- 24 of 24 (`verification/tests/test_hk_io_filter.py`).
- **Note:** Not implemented. The six are synchronised by `dff_sync` but are not
  glitch-filtered; the filtered set covers only PGOOD, nFAULT and the eFuse
  discrete. **Synchronising is not filtering** -- a two-stage synchroniser
  resolves metastability but propagates a clean 20 ns pulse faithfully, so a
  single-cycle transient is enough to arm or disarm a region.
- **Note:** The exposure is not uniform. A spurious edge on `stepper_pri_ctrl`
  or `stepper_sec_ctrl` energises a motor drive, which is a mechanism-damage
  risk rather than a recoverable power event, and it compounds
  [`HK-F-05`](pa3-housekeeper-findings.md#hk-f-05) because the interlock keys
  on `stepper_pri_boot_succeeded` rather than on the enable. A spurious edge on
  `imx_ctrl` powers the sensor unexpectedly.
- **Note:** The 5 us figure is taken from `HK-IO-05` rather than derived
  independently: the same `glitch_filter` module is already instantiated 51
  times for the PGOOD and nFAULT inputs, so reusing it here needs no new logic.
  The added latency is irrelevant at this level -- region boot takes
  milliseconds -- so there is no evident reason for the asymmetry. Confirm the
  figure is right for a command input rather than inheriting it by default. See
  [`HK-F-15`](pa3-housekeeper-findings.md#hk-f-15).

---

## SRC -- Per-power-source state machine

All requirements in this area are implemented once, in
[`pwr_src_bootseq.sv`](../../src/pwr_src_bootseq.sv), and instantiated 33 times.

### HK-SRC-01
Each power source shall be individually controllable, through an enable output
of its own. In a software-controlled region, which source failed, and whether
it failed to boot or latched up, shall be identifiable from that region's
outputs.
- **Parent:** FAR-PM_FPGA_L4REQ-9
- **Design:** `src/pwr_src_bootseq.sv:41-48`
- **Verify:** SIM
- **Rationale:** Per-source granularity is what allows a single failing rail to
  be identified and contained; a region-level abstraction alone cannot report
  which source failed, which FAR-PM_FPGA_L4REQ-30 requires for the
  software-controlled regions.
- **Finding:** HK-F-27
- **Status:** GAP
- **Evidence:** Every source has its own enable pin. The software-region half
  is `HK-TLM-03`'s, and fails with it: the first source's boot failure reads 0,
  the same as no failure (`verification/tests/test_hk_tlm_metadata.py`,
  [`HK-F-06`](pa3-housekeeper-findings.md#hk-f-06)).
- **Note:** Reworded from "individually controllable and individually
  observable, such that its enable, its boot outcome and its fault condition
  can be determined independently of every other source", which was `AMBIG`:
  its item asked for outputs that no other source drives, which only a
  dedicated fault pin per source could meet. Per-source failure identity is
  now required only in the software-controlled regions, as
  FAR-PM_FPGA_L4REQ-30 states it; in the hardware-controlled regions the region
  is the unit reported (`HK-REG-01`).
- **Note:** **Confirmed by systems, 2026-10-01** (Dhruv, avionics hardware).
  Scoping per-source failure identity to the software-controlled regions was
  proposed on 2026-09-29. The answer: a failed hardware-controlled region
  leaves the PolarFire off, so it has no use for the detail.
- **Note:** Implemented as a six-state machine -- `POWER_OFF`, `BOOTING`,
  `BOOT_SUCCEEDED`, `BOOT_FAILED`, `POWERING_DOWN`, `LATCHUP`. The state set is
  design detail recorded in
  [`docs/design/pa3-housekeeper.md`](../design/pa3-housekeeper.md); the
  requirement constrains the observable behaviour, not the encoding.

### HK-SRC-02
Following release of reset, every power source enable shall be deasserted,
regardless of the state the source was in when reset was asserted.
- **Parent:** FAR-PM_FPGA_L4REQ-9
- **Design:** `src/pwr_src_bootseq.sv:78-84`, `src/pwr_src_bootseq.sv:145-151`
- **Verify:** SIM
- **Rationale:** Reset must land every source in the same electrically safe
  condition, so that a reset taken at any point in the boot sequence produces a
  deterministic restart rather than leaving a region partially energised.
- **Status:** OK
- **Note:** Verify by asserting reset at multiple points across the boot
  sequence -- including mid-boot and post-latchup -- and confirming all 33
  enables are low. Implemented by returning each source to `POWER_OFF`, which
  drives its enable low; the state name is design detail.

### HK-SRC-03
A power source enable shall be asserted only after the housekeeper has
requested that source to boot and no power-down is in effect for it.
- **Parent:** FAR-PM_FPGA_L4REQ-8, FAR-PM_FPGA_L4REQ-9
- **Design:** `src/pwr_src_bootseq.sv:83-88`
- **Verify:** SIM
- **Finding:** HK-F-29 (fixed)
- **Status:** OK
- **Evidence:** No software enable asserted unrequested in 100 ms; a request
  asserted one; under a latched power-down with its cause removed, a request
  asserted nothing. IMX, withdrawn during its retry hold, asserted nothing as
  the hold ended, and requested again afterwards asserted `imx_en_1v1` at
  once. Withdrawn and requested again 5 ms into the hold, it kept `imx_en_1v1`
  off for 200.540 ms -- the full hold -- before the next attempt
  (`verification/tests/test_hk_src_attempt.py`). Before the `HK-F-29` fix the
  withdrawn region asserted `imx_en_1v1` for 20 ns as the hold ended.
- **Note:** Implemented as the `POWER_OFF` to `BOOTING` transition gated on `start_boot && !pwr_dwn`; the state names are design detail.

### HK-SRC-04
A power source enable shall be asserted from the start of its boot attempt
until the source is powered down, declared failed, or declared latched up.
- **Parent:** FAR-PM_FPGA_L4REQ-9
- **Design:** `src/pwr_src_bootseq.sv:80-82`, `:87-88`, `:109-111`, `:121-122`, `:127-130`, `:133-136`
- **Verify:** SIM
- **Status:** OK
- **Evidence:** Each enable rose once and was held until the event that ended
  its attempt: IMX 3V3 with its rail dead for 25.231 ms, to its timeout;
  Stepper Pri, faulted as it started, for 5.1 us, to its latchup; Eth1 1V0,
  booted, for 37.2 ms, to its power-down
  (`verification/tests/test_hk_src_attempt.py`).
- **Note:** Implemented by driving the enable high in `BOOTING` and `BOOT_SUCCEEDED` and low in all other states.

### HK-SRC-05
A power source shall be declared successfully booted only on a rising edge of
its filtered PGOOD input observed while its enable is asserted and its boot
attempt is in progress.
- **Parent:** FAR-PM_FPGA_L4REQ-20
- **Design:** `src/pwr_src_bootseq.sv:97-98`
- **Verify:** SIM
- **Status:** OK
- **Evidence:** IMX 1V8 with its PGOOD forced high before it was enabled, and
  Eth1 1V0A with its rail dead and its PGOOD pulsed while still off, were each
  declared failed at the 25.231 ms timeout, and the source after each never
  started; Eth2, booting normally alongside, booted
  (`verification/tests/test_hk_src_attempt.py`). The first case is what
  `HK-F-02` feared the board's DDR 0V6 rails present; the regulator datasheet
  shows they do not, because 0V6's PGOOD comes 4 ms after 1V2's.
- **Note:** The condition is `{pgood_r1, pgood} == 2'b01`, a strict rising
  edge, not a level. A source whose PGOOD is already high when `start_boot`
  arrives will never be declared booted. This is why
  [`HK-F-02`](pa3-housekeeper-findings.md#hk-f-02) depends on 0V6's PGOOD
  being late, which the TPS7H3302 guarantees only as a typical figure.

### HK-SRC-06
A power source shall be declared failed if it has not asserted a PGOOD rising
edge within 200 % of its nominal boot time after its enable is asserted. A
source's nominal boot time is the time from its enable being asserted to its
regulator asserting PGOOD, from the regulator's datasheet with the soft-start
or reference capacitor fitted on the board, or from board test where that has
been measured.
- **Parent:** FAR-PM_FPGA_L4REQ-11
- **Design:** `src/pwr_src_bootseq.sv:36`, `:105-107`, `src/pwr_region_ddr8_bootseq.sv:41-43`
- **Kind:** Performance
- **Verify:** SIM
- **Status:** GAP
- **Evidence:** DDR8's 2V5 source has a nominal time of 4.139 ms, so a bound
  of 8.278 ms. A PGOOD rise at its nominal time was declared a success, but
  with PGOOD held low its enable was still asserted at 8.378 ms: the design
  gives every source a flat 25 ms, and times out at 25.231 ms
  (`verification/tests/test_hk_src_06.py`). See
  [`HK-F-03`](pa3-housekeeper-findings.md#hk-f-03).
- **Note:** The nominal times are computed per rail in the board model,
  `verification/board/delays.yaml`, from each regulator's datasheet equation
  and the capacitor fitted, checked against the datasheets on 2026-10-01. They
  run from 1.217 ms (DDR8 1V2) to 6.6 ms (FPGA 3V3 B4); 200 % of them runs
  from about 2.4 ms to 13.2 ms. For the TPS54821 and TPS7H4003 the PGOOD
  threshold sits on the soft-start pin (1.4 V and 1.1 V), so enable to PGOOD
  is 2.3 and 1.8 times the soft-start time the datasheet headlines. Four
  are uncharacterised and carry a 3.0 ms placeholder: IMX 2V9 and 3V3 (off
  board) and both stepper supplies. Most LDO rails are 3.0 ms, read from a
  datasheet curve rather than an equation.
- **Note:** **Confirmed in part by systems, 2026-10-01** (Dhruv, avionics
  hardware): nominal is the datasheet start-up time, "either on the board
  schematic or in the testing that has been performed on the avionics board".
  **Still pending:** that start-up means enable to PGOOD rather than the
  soft-start ramp, which matters by a factor of 2.3 on the TPS54821 rails;
  the board test data, including the four uncharacterised rails; and whether
  a per-source timeout is wanted on SV1 or only on later units. Previously
  this requirement stated a flat 25 ms, which the design meets; it now
  follows its parent, which the design does not.
- **Note:** The flat 25 ms is implemented and was verified at the synthesis
  parameter values. It was previously unreachable in the flight configuration -- the
  threshold was `WAIT_TIME >> 14` = 76 ticks against a 6-bit counter
  saturating at 63, so no source could reach `BOOT_FAILED` by timeout. The
  counter is now 7 bits and the threshold is rounded up rather than truncated,
  which places the 0.32768 ms quantisation on the late side: the timeout fires
  at 25.231 ms. Truncation fires at 24.904 ms, which is before the 25 ms the
  source is allowed. See [`HK-F-01`](pa3-housekeeper-findings.md#hk-f-01).
- **Note:** This requirement previously stated a flat 25 ms for all 33
  sources, so the disagreement with its parent was between the two
  requirements. It is now between the requirement and the design. See
  [`HK-F-03`](pa3-housekeeper-findings.md#hk-f-03).

### HK-SRC-07
A power source that has been declared successfully booted shall be declared
latched up if its filtered nFAULT input goes low or its filtered PGOOD input
goes low.
- **Parent:** FAR-PM_FPGA_L4REQ-14, FAR-PM_FPGA_L4REQ-17
- **Design:** `src/pwr_src_bootseq.sv:109-115`
- **Verify:** SIM
- **Status:** OK
- **Evidence:** All 33 sources latched on PGOOD low after boot, and all 11 with
  an nFAULT pin latched on nFAULT low, each within 5.10 us; each hardware case
  on a boot of its own. Six modules, `verification/tests/test_hk_src_07_*.py`,
  one item each.

### HK-SRC-08
A power source shall be declared latched up during a boot attempt if its
filtered nFAULT input goes low, unless that source is configured to ignore
nFAULT while booting.
- **Parent:** FAR-PM_FPGA_L4REQ-14
- **Design:** `src/pwr_src_bootseq.sv:87-90`
- **Verify:** SIM
- **Status:** OK
- **Evidence:** nFAULT asserted during the attempt latched DDR8 2V5, IMX 1V1,
  Stepper Pri and Stepper Sec within 5.10 us; the exempt step-down 4V0, with
  nFAULT low for 0.5 ms of its attempt, held its enable and went on to boot
  (`verification/tests/test_hk_src_latch.py`).

### HK-SRC-09
The step-down 4V0 source shall ignore its nFAULT input while its boot attempt
is in progress.
- **Source decision:** The step-down 4V0 regulator asserts nFAULT transiently
  during its own ramp, so treating that as a latchup would fail the boot.
- **Imposes on:** FPGA design, verification
- **Rationale:** This is the named instance of the exception clause in
  `HK-SRC-08`, which declares a source latched up on a low nFAULT during boot
  "unless that source is configured to ignore nFAULT while booting". Stating it
  positively identifies which source is configured that way; the previous
  negative form restated `HK-SRC-08`'s exception as a separate prohibition.
- **Design:** `src/pwr_region_step_down_bootseq.sv:132-133`, `src/pwr_src_bootseq.sv:19`, `:89-90`
- **Verify:** SIM
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Evidence:** With nFAULT held low from the moment its enable rose, the 4V0
  source held its enable through its attempt, and latched 5.2 us after its
  PGOOD rose -- so it is ignored while booting, not unconnected
  (`verification/tests/test_hk_src_latch.py`).
- **Note:** `IGNORE_LATCHUP_ON_BOOT` is set on exactly one of the 33 sources.
  It suppresses the `BOOTING` to `LATCHUP` transition only. The same parameter
  also guards the `BOOT_SUCCEEDED` latchup test at `src/pwr_src_bootseq.sv:112-114`,
  but that guard has no effect: the threshold is
  `CNTR_NFAULT_IGNORE_TIME >> CNTR_PRECISION` = `10000 >> 14` = 0, so
  `cntr >= 0` is true on the first cycle and post-boot latchup detection is
  never actually masked. See
  [`HK-F-09`](pa3-housekeeper-findings.md#hk-f-09).

### HK-SRC-10
A power source declared latched up shall hold its enable deasserted for at
least 2 ms before it may be re-enabled.
- **Parent:** FAR-PM_FPGA_L4REQ-14, FAR-PM_FPGA_L4REQ-12
- **Design:** `src/pwr_src_bootseq.sv:133-136`, `src/pwr_src_bootseq.sv:17`
- **Kind:** Performance
- **Verify:** SIM
- **Rationale:** The hold must outlast the latched condition in the regulator
  so that the source restarts from a genuinely off state rather than
  re-triggering immediately.
- **Status:** OK
- **Evidence:** `LATCHUP_WAIT_TIME` is 125,000 cycles nominal; the realised
  interval is 7 ticks of 327.68 us = 2.294 ms. In simulation IMX 1V1, latched
  and its fault removed, ignored a request 1.9 ms later and re-asserted on one
  at 3.0 ms (`verification/tests/test_hk_src_latch.py`).

### HK-SRC-11
A power source being powered down shall be considered off when its filtered
PGOOD has gone low, or after at least 2 ms, whichever occurs first.
- **Parent:** FAR-PM_FPGA_L4REQ-4
- **Design:** `src/pwr_src_bootseq.sv:116-119`, `:127-132`
- **Kind:** Performance
- **Verify:** SIM
- **Rationale:** The timeout fallback prevents a stuck-high PGOOD from blocking
  the staged shutdown of HK-PDN-02, which would otherwise stall the teardown
  chain indefinitely.
- **Finding:** HK-F-28 (fixed)
- **Status:** OK
- **Evidence:** The timeout is 7 ticks of 327.68 us = 2.294 ms, counted from
  entry to `POWERING_DOWN`: the counter is cleared on that transition
  (`src/pwr_src_bootseq.sv:118`). On IMX, with 3V3's PGOOD forced high, 2V9
  began powering down 2.2938 ms after 3V3 -- the same whether IMX had been up
  for 10 ms or had only just booted -- and with 3V3's PGOOD falling normally,
  5.1 us after it fell, the 5 us filter
  (`verification/tests/test_hk_src_attempt.py`). Before the fix the counter
  ran from boot, and 2V9 followed 3V3 by 40 ns in both orderings (`HK-F-28`).
- **Note:** The parent states only the PGOOD condition. The timeout fallback is
  a design addition with no parent and is captured here so that it is verified
  rather than discovered.
- **Note:** The timeout is not only a fallback. 18 of the 33 sources are
  LT3065 LDOs, whose control circuitry shuts down with EN and releases the
  open-drain PGOOD, so the pull-up holds it high: their PGOOD never falls on
  power-down, and the timeout is the only way they are ever considered off
  (Dhruv, 2026-10-01; LT3065 datasheet, PWRGD). That made the counter not
  being cleared the whole of the power-down spacing for those rails, not an
  edge case.

---

## REG -- Per-power-region state machine

All requirements in this area are implemented once, in
[`pwr_region_sm.sv`](../../src/pwr_region_sm.sv), and instantiated 11 times.

### HK-REG-01
Each power region shall be independently controllable and independently
observable, such that its boot outcome and its fault condition can be
determined without reference to any other region. For a region that reports on
a single status bit, a status that has not risen within 1 s of the region
starting to boot shall mean the region has failed.
- **Parent:** FAR-PM_FPGA_L4REQ-8
- **Design:** `src/pwr_region_sm.sv:41-49`
- **Verify:** SIM
- **Rationale:** Per-region granularity is what allows a software-controlled
  region to be cycled without disturbing the rest of the payload, and what lets
  the PolarFire be told which region failed.
- **Status:** OK
- **Finding:** HK-F-27
- **Evidence:** LVDS, the one region where the rule matters: with its rail
  held dead it had made all four attempts, the last ending 698.6 ms after the
  FPGA region reported booted, and made none after; healthy, it reported
  booted 3.005 ms after the FPGA region (`verification/tests/test_hk_reg_observable.py`).
  So a status still low at 1 s is conclusive, and a working region is never
  called failed.
- **Note:** Step Down, FPGA and LVDS report on a single status bit, which
  cannot tell failed from still booting. For Step Down and FPGA it does not
  matter: if either fails, the PolarFire is unpowered. LVDS boots after the
  FPGA region and failing does not take the payload down, so the PolarFire has
  to decide, and the 1 s timeout is how. That is an obligation on the
  PolarFire firmware as well as on this design.
- **Note:** Previously `GAP`: the requirement asked for failed to read
  differently from booting at the pins, and LVDS's single bit reads 0 for both.
  The gating of every status output on the FPGA region is not counted: the
  PolarFire is only powered when that region has booted.
- **Note:** **Pending systems confirmation.** The 1 s rule is the answer
  proposed to systems on 2026-09-29 to whether "power rail status" in
  FAR-PM_FPGA_L4REQ-28 must tell a failed region from one still booting.
  Avionics hardware called it "probably acceptable" on 2026-10-01; it is an
  obligation on the PolarFire firmware, so its owner has to accept it. Revisit
  this requirement, `VC-HK-0043` and its test when the answer is in Jama.
- **Note:** Implemented as a seven-state machine per region. The state set is
  design detail recorded in
  [`docs/design/pa3-housekeeper.md`](../design/pa3-housekeeper.md); this
  requirement constrains observable behaviour, not the encoding.

### HK-REG-02
A region shall enable its power sources one at a time, in a fixed order, each
source starting only when the previous source in the region has been declared
successfully booted.
- **Parent:** FAR-PM_FPGA_L4REQ-8, FAR-PM_FPGA_L4REQ-27
- **Design:** `src/pwr_region_sm.sv:71`, `src/pwr_region_imx_bootseq.sv:109`, `:126`, `:142`, `:158`
- **Verify:** SIM
- **Status:** OK
- **Evidence:** On a nominal boot every multi-source region -- Step Down,
  DDR8, DDR16, FPGA, IMX, Eth1, Eth2 -- asserted its enables in table order,
  each after the previous source's PGOOD had risen and with every later
  enable still low. With DDR8's 1V2 rail held dead, 1V2 asserted, timed out
  25.2 ms later, and 0V6 never asserted
  (`verification/tests/test_hk_reg_sequence.py`).
- **Note:** The region state machine starts only the first source; each
  subsequent source takes the previous source's `boot_succeeded` as its own
  `start_boot`. The boot orders are listed in the configuration table above.

### HK-REG-03
A region shall be declared successfully booted only when every source in the
region reports success.
- **Parent:** FAR-PM_FPGA_L4REQ-8
- **Design:** `src/pwr_region_imx_bootseq.sv:78`, `src/pwr_region_step_down_bootseq.sv:74`, `src/pwr_region_sm.sv:110-112`
- **Verify:** SIM
- **Status:** OK
- **Evidence:** `pf_status_to_pf` and `imx_status_to_pf` each rose with every
  rail in their region already good. With IMX's 3V3 rail held dead, the other
  three sources came good on each of four attempts and `imx_status_to_pf`
  never rose (`verification/tests/test_hk_reg_sequence.py`). Checked on the
  two statuses not masked by the FPGA region at the moment they rise.

### HK-REG-04
A region shall re-attempt its boot sequence when any source in the region is
declared failed and fewer than three re-attempts have been used.
- **Parent:** FAR-PM_FPGA_L4REQ-19, FAR-PM_FPGA_L4REQ-18
- **Design:** `src/pwr_region_sm.sv:99-108`
- **Verify:** SIM
- **Status:** OK
- **Note:** Was unreachable in the flight configuration, because no source
  could report a boot failure and `boot_timeout` is the only input that moves
  a region out of `BOOTING` (`pwr_region_sm.sv:99`). Widening the source
  counter for `HK-SRC-06` made the retry path reachable, and it is now
  verified: with DDR8's 2V5 rail held out of regulation, the region
  re-attempts, enables rising at 1002.7, 1227.2, 1451.7 and 1676.1 ms after
  reset release. See [`HK-F-01`](pa3-housekeeper-findings.md#hk-f-01).

### HK-REG-05
Within 10 us of a source in the region being declared failed, a region
beginning a re-attempt shall deassert every enable in the region, and hold
them deasserted for 200 ms -1/+2 ms before re-enabling the first source.
- **Parent:** FAR-PM_FPGA_L4REQ-18
- **Design:** `src/pwr_region_sm.sv:116-126`, `src/pwr_region_ddr8_bootseq.sv:44`
- **Kind:** Performance
- **Verify:** SIM
- **Rationale:** The hold must outlast a regulator's soft-start and fault latch
  so that the retry begins from the same state as the first attempt, rather
  than from a partially-energised rail.
- **Finding:** HK-F-04 (fixed)
- **Status:** OK
- **Evidence:** Realised hold is 153 ticks of 1.31072 ms = 200.540 ms, the
  threshold rounded up rather than truncated. Measured in simulation at
  200.500 ms, which agrees to within the 0.1 ms sampling interval
  (`verification/tests/test_hk_reg_retry.py`).
- **Note:** Two departures from the parent, both closed. It was unreachable in
  the flight configuration; widening the source counter for `HK-SRC-06` made
  the retry path reachable. And it was 0.77 ms short of FAR-PM_FPGA_L4REQ-18's
  "at least 200 ms": truncating `RETRY_TIME >> 16` gave 152 ticks, 199.229 ms,
  inside this requirement's -1/+2 ms but not the parent's wording. Rounding up,
  as the source boot timeout already did, gives 200.540 ms, which meets both.
  See [`HK-F-04`](pa3-housekeeper-findings.md#hk-f-04).
- **Evidence:** The response clause is met. With DDR8's 1V2 source failing its
  first attempt and its 2V5 source up, the 2V5 enable fell 0.04 us after the
  1V2 source's own enable -- the moment it was declared failed, observable at
  the pins (`HK-SRC-04`) (`verification/tests/test_hk_response.py`).
- **Note:** **Pending systems confirmation.** The 10 us response is the value
  proposed to systems on 2026-09-29 for "immediately" in FAR-PM_FPGA_L4REQ-18.
  The 2026-10-01 answer confirmed 10 us for L4REQ-14 only and did not address
  -18. Revisit this requirement and `VC-HK-0116` when the answer is in Jama.
  The hold is not in question and is not pending.

### HK-REG-06
A region shall make at most four boot attempts before being declared failed.
- **Parent:** FAR-PM_FPGA_L4REQ-19
- **Design:** `src/pwr_region_sm.sv:37`, `src/pwr_region_sm.sv:99-102`
- **Verify:** SIM
- **Status:** OK
- **Note:** `NUM_RETRIES` is 3, giving one initial attempt plus three retries.
  Was unreachable in the flight configuration for the reason above; widening
  the source counter for `HK-SRC-06` made the retry path reachable. Verified:
  with a rail held out of regulation the region asserts its first enable
  exactly four times over 3.2 s and then stops, reporting `debug[2:0]` = 7,
  `ddr8_boot_failed`.

### HK-REG-08
A region shall be declared latched up for as long as any source within it is
declared latched up.
- **Parent:** FAR-PM_FPGA_L4REQ-14, FAR-PM_FPGA_L4REQ-12
- **Design:** `src/pwr_region_sm.sv:91-93`, `:131-133`, `:151-153`, `:168-173`
- **Verify:** SIM
- **Rationale:** Stating entry and exit as one continuous condition rather than
  two events avoids leaving the exit case unspecified, which is how a region
  ends up latched permanently on a transient.
- **Status:** OK
- **Evidence:** With IMX latched by its 1V1 nFAULT and the fault removed at
  once, a request 1.994 ms later -- inside the source's 2.294 ms hold -- was
  refused, and one at 2.594 ms was acted on in the same clock cycle
  (`verification/tests/test_hk_reg_latchup.py`).
- **Note:** Verified for one latched source. Once a source latches the region
  powers the others down, and every source has the same hold, so several
  sources latched together and clearing apart cannot be produced at the pins;
  the OR over sources is by construction (`pwr_region_imx_bootseq.sv:77`).
  Tested on a software region because a hardware-region latchup resets every
  region (`health_monitor.sv:722-723`), which is `HK-LAT-02`.

### HK-REG-09
A region declared latched up shall deassert every enable in the region.
- **Parent:** FAR-PM_FPGA_L4REQ-14, FAR-PM_FPGA_L4REQ-12
- **Design:** `src/pwr_region_sm.sv:169`
- **Verify:** SIM
- **Status:** OK
- **Evidence:** With IMX fully booted and its 1V1 nFAULT asserted, 1V1's
  enable fell and the three booted sources' enables fell 40 ns later, and
  none re-asserted while the region was latched
  (`verification/tests/test_hk_reg_latchup.py`).

---

## SEQ -- Inter-region boot sequencing

### HK-SEQ-01
The housekeeper shall wait 1 s +/-5 % after reset release before starting the
boot sequence.
- **Source decision:** A fixed delay after reset release was adopted in place of sensing that the input rail and the PolarFire configuration have settled.
- **Imposes on:** FPGA design, hardware design, verification
- **Design:** `src/health_monitor.sv:158`, `src/health_monitor.sv:507`, `:516-519`
- **Kind:** Performance
- **Verify:** SIM
- **Rationale:** The delay allows the upstream bus rail and the housekeeper's
  own supply to settle before any downstream rail is enabled, so that boot is
  not attempted into a still-ramping input.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Evidence:** Realised delay is 190 ticks of 5.24288 ms = 996.147 ms. The
  design documentation describes it as "wait 1 second"
  (`docs/design/pa3-housekeeper.md:105`).

### HK-SEQ-02
The housekeeper shall boot the hardware-controlled regions in the order
Step Down, DDR8, DDR16, FPGA, LVDS.
- **Parent:** FAR-PM_FPGA_L4REQ-8, FAR-PM_FPGA_L4REQ-27
- **Design:** `src/health_monitor.sv:518`, `src/health_monitor.sv:671-674`
- **Verify:** SIM
- **Status:** OK

### HK-SEQ-03
The DDR8 and LVDS regions shall begin booting only after the preceding region
has booted successfully.
- **Source decision:** A specific hardware-controlled boot order was chosen, in which a region's sources are enabled only once the preceding region reports success.
- **Imposes on:** FPGA design, hardware design, verification
- **Design:** `src/health_monitor.sv:671`, `:674`
- **Verify:** SIM
- **Rationale:** The step-down converters supply everything downstream and the
  FPGA rails supply the PolarFire, so neither successor may be energised if its
  predecessor did not come up. This is what makes those two regions critical.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Evidence:** With step-down's last rail dead, step-down made four attempts
  and DDR8 asserted nothing; with FPGA's last rail dead, FPGA made four and
  LVDS asserted nothing. Nominally each began 5 us after its predecessor's
  last rail came good (`verification/tests/test_hk_seq_critical.py`).

### HK-SEQ-09
The DDR16 and FPGA regions shall begin booting once the preceding region has
finished booting, whether it succeeded or failed.
- **Source decision:** As `HK-SEQ-03`, for the two regions whose predecessor need only have finished booting rather than succeeded.
- **Imposes on:** FPGA design, verification
- **Design:** `src/health_monitor.sv:672-673`
- **Verify:** SIM
- **Rationale:** A DDR bank that fails to boot costs frame-buffer capacity but
  does not prevent the payload operating, so the boot chain deliberately
  continues past it. This is what makes the DDR regions non-critical, and it is
  the counterpart to `HK-SEQ-03`.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Evidence:** With both DDR banks' 1V2 rails dead, DDR16 began 0.04 us after
  DDR8's fourth failed attempt ended, and FPGA 0.04 us after DDR16's
  (`verification/tests/test_hk_seq_noncritical.py`).
- **Note:** The distinction between the two rules is the whole
  critical/non-critical mechanism, and it is visible only in the choice of
  `boot_succeeded` against `boot_done`. Nothing in the Flow requirement set
  states it.

### HK-SEQ-04
The housekeeper shall begin the boot sequence exactly once per deassertion of
reset.
- **Source decision:** Recovery from a failed or completed boot is by reset or
  power cycle only; there is no re-boot path while reset stays deasserted.
- **Imposes on:** FPGA design, verification
- **Design:** `src/health_monitor.sv:516-519`
- **Verify:** SIM
- **Note:** Count the rising edges on the step-down enables between one reset
  deassertion and the next; expect exactly one.
- **Rationale:** A boot request that re-triggered would re-enable rails that are
  already up, or restart a region mid-teardown. Stated as *exactly once* rather
  than as a prohibition on restarting, because a prohibition is also satisfied by
  a housekeeper that never boots at all -- it constrains at-most-once and says
  nothing about at-least-once.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Evidence:** Implemented by a set-only `step_down_start_boot`; the internal
  signal is design detail.

### HK-SEQ-05
A software-controlled region shall start booting only on a rising edge of its
control input, and only while the FPGA region has booted successfully.
- **Parent:** FAR-PM_FPGA_L4REQ-26, FAR-PM_FPGA_L4REQ-23, FAR-PM_FPGA_L4REQ-22, FAR-PM_FPGA_L4REQ-21
- **Design:** `src/health_monitor.sv:560-596`
- **Verify:** SIM
- **Status:** OK
- **Evidence:** With every control input high from reset release, and IMX's
  toggled low-high before the FPGA region was up, nothing started in the
  100 ms after the FPGA region booted; a low-high edge on `imx_ctrl` then
  started IMX (`verification/tests/test_hk_seq_software.py`).
- **Note:** The rising-edge requirement is what implements FAR-PM_FPGA_L4REQ-12's recovery
  rule: after a software-region latchup the PolarFire must cycle the control
  line low then high to re-enable the region.

### HK-SEQ-06
A software-controlled region's start request shall be cleared once the region
reports done or latchup.
- **Source decision:** Software-controlled regions are armed by an edge rather than held by a level, so the start request is a latch that something must clear.
- **Imposes on:** FPGA design, PolarFire firmware, verification
- **Design:** `src/health_monitor.sv:563-564`, `:569-570`, `:575-576`, `:582-583`, `:588-589`, `:594-595`
- **Verify:** SIM
- **Rationale:** An edge-armed latch that is never cleared cannot be re-armed, so a region could be started once and never again after it is powered down. Clearing on done or latchup is what makes the software-controlled regions re-commandable across a mission.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Evidence:** Eth1, latched by its first rail and the rail restored, with
  `eth1_ctrl` held high, did not restart in 100 ms; a fresh low-high edge
  restarted it (`verification/tests/test_hk_seq_software.py`). Only the
  latchup branch is observable at the pins: a region leaves done only by being
  powered down, and raising its control again is itself a fresh edge.

### HK-SEQ-07
All software-controlled regions shall be held powered down while the FPGA
region has not booted successfully.
- **Parent:** FAR-PM_FPGA_L4REQ-21, FAR-PM_FPGA_L4REQ-3
- **Design:** `src/health_monitor.sv:545-550`
- **Verify:** SIM
- **Status:** OK
- **Evidence:** With every control input high from reset release, no software
  enable asserted before `pf_status_to_pf` rose, sampled every 0.1 ms
  (`verification/tests/test_hk_seq_software.py`).
- **Note:** Shares an RTL expression with `HK-SW-06` and `HK-PDN-03` (`src/health_monitor.sv:545-550`), but the three state different triggers -- FPGA region not booted, control input deasserted, and global power-down respectively -- and trace to different parents. They are not redundant.
### HK-SEQ-08
The housekeeper shall boot all hardware-controlled regions during the initial
boot sequence without any external request.
- **Parent:** FAR-PM_FPGA_L4REQ-27
- **Design:** `src/health_monitor.sv:516-519`, `:671-674`
- **Verify:** SIM
- **Status:** OK

---

### HK-SEQ-10
The hardware-controlled boot sequence shall complete within 6 s of reset release.
- **Parent:** FAR-PM_FPGA_L4REQ-8
- **Design:** `src/health_monitor.sv:507`, `:516-519`, `:671-674`
- **Kind:** Performance
- **Verify:** SIM
- **Rationale:** The PolarFire and the bus need to know how long to wait before
  treating the payload as failed rather than still booting. Without a stated
  bound each observer picks its own, and a slow but healthy boot is
  indistinguishable from a dead one.
- **Finding:** HK-F-26
- **Status:** OK
- **Evidence:** The worst case the design allows is 5.80 s: a 1 s initial wait
  (`HK-SEQ-01`), then four attempts per region (`HK-REG-06`) at the design's
  25 ms per source with a 200 ms hold between attempts (`HK-REG-05`), over
  regions of 3, 3, 3, 8 and 1 sources -- 4.80 s for the chain. No board
  produces that: it needs every source to take just under its timeout on every
  attempt. The slowest the board model can produce -- DDR8, DDR16 and LVDS each
  failing all four attempts on their last source -- completed
  3.175 s after reset release (`verification/tests/test_hk_seq_complete.py`).
- **Note:** If `HK-SRC-06` is met as now written -- 200 % of each source's
  nominal time rather than a flat 25 ms -- the analytic worst case falls well
  below 5.80 s, since no source's bound exceeds 13.2 ms.
- **Note:** **Pending systems confirmation.** 6 s is the value proposed to
  systems on 2026-09-29 for FAR-PM_FPGA_L4REQ-8 and -27; it was TBR, because
  the bound belongs to whoever waits for the payload. Avionics hardware
  referred it on 2026-10-01 to flight software, whose interface it is.
  Revisit this requirement, `VC-HK-0060` and its test when the answer is in
  Jama, and update
  [`tbr-register.md`](../../../docs/requirements/tbr-register.md).

## SW -- Software-controlled region enable/disable

### HK-SW-01
The housekeeper shall enable the IMX sensor power region on request from the
PolarFire.
- **Parent:** FAR-PM_FPGA_L4REQ-26
- **Design:** `src/health_monitor.sv:591-593`, `src/health_monitor.sv:545`
- **Verify:** SIM
- **Status:** OK
- **Evidence:** A rising edge on `imx_ctrl` booted IMX and left the 29 other
  enables unchanged, sampled every 0.05 ms (`verification/tests/test_hk_sw_request.py`).

### HK-SW-02
The housekeeper shall enable the LVDT power region on request from the
PolarFire.
- **Parent:** FAR-PM_FPGA_L4REQ-23
- **Design:** `src/health_monitor.sv:585-587`, `src/health_monitor.sv:546`
- **Verify:** SIM
- **Status:** OK
- **Evidence:** A rising edge on `lvdt_ctrl` booted LVDT and left the 32 other
  enables unchanged (`verification/tests/test_hk_sw_request.py`).

### HK-SW-03
The housekeeper shall enable each Ethernet power region independently on
request from the PolarFire.
- **Parent:** FAR-PM_FPGA_L4REQ-22, FAR-EDT_L3REQ-13
- **Design:** `src/health_monitor.sv:560-571`, `src/health_monitor.sv:549-550`
- **Verify:** SIM
- **Status:** OK
- **Evidence:** Eth1 requested with Eth2 down, then Eth2 with Eth1 up; each
  booted and left the 29 other enables unchanged
  (`verification/tests/test_hk_sw_request.py`).

### HK-SW-04
The housekeeper shall enable either the primary or the secondary stepper motor
power region on request from the PolarFire.
- **Parent:** FAR-PM_FPGA_L4REQ-25
- **Design:** `src/health_monitor.sv:572-584`, `src/health_monitor.sv:547-548`
- **Verify:** SIM
- **Status:** OK
- **Evidence:** Stepper Pri requested from down booted alone; withdrawn, then
  Stepper Sec requested from down booted alone
  (`verification/tests/test_hk_sw_request.py`).

### HK-SW-05
The housekeeper shall power down the secondary stepper motor region whenever
the primary stepper motor region has booted successfully.
- **Parent:** FAR-PM_FPGA_L4REQ-24
- **Design:** `src/health_monitor.sv:547`
- **Verify:** SIM
- **Status:** GAP
- **Evidence:** With the secondary booted and the primary requested, the
  secondary went down 5 us after the primary's PGOOD rose -- the interlock as
  worded works -- but both were enabled together for 3.005 ms, the primary's
  whole boot window (`verification/tests/test_hk_sw_down.py`). The test is
  written to the parent, as `HK-REG-05` is.
- **Note:** This is the only interlock between the two stepper regions and it
  is one-directional and non-instantaneous. It keys on
  `stepper_pri_boot_succeeded`, not on `stepper_pri_en`, so if the secondary is
  already enabled and the primary is commanded on, both enables are high for
  the whole of the primary's boot window. FAR-PM_FPGA_L4REQ-24 requires that the two are
  *never* enabled at the same time. See
  [`HK-F-05`](pa3-housekeeper-findings.md#hk-f-05).

### HK-SW-06
A software-controlled region shall power down whenever its control input is
deasserted.
- **Parent:** FAR-PM_FPGA_L4REQ-21
- **Design:** `src/health_monitor.sv:545-550`
- **Verify:** SIM
- **Status:** OK
- **Evidence:** IMX and Eth1, withdrawn, deasserted their enables one at a time
  in reverse boot order (`verification/tests/test_hk_sw_down.py`). When each
  source may begin is `HK-PDN-04`.

### HK-SW-07
A software-controlled region that has latched up shall be re-enabled only by a
low-then-high transition of its control input.
- **Parent:** FAR-PM_FPGA_L4REQ-12
- **Design:** `src/health_monitor.sv:560-596`, `src/pwr_region_sm.sv:168-173`
- **Verify:** SIM
- **Status:** OK
- **Evidence:** IMX latched by its 1V1 nFAULT, fault removed, `imx_ctrl` held
  high: nothing re-asserted in 100 ms; low then high re-enabled it
  (`verification/tests/test_hk_sw_down.py`).

---

## LAT -- Latchup detection and response

### HK-LAT-01
A latchup shall be declared when a filtered PGOOD goes low on a source that has
booted successfully, or a filtered nFAULT goes low on a source that is enabled.
- **Parent:** FAR-PM_FPGA_L4REQ-14, FAR-PM_FPGA_L4REQ-17
- **Design:** `src/pwr_src_bootseq.sv:87-90`, `:109-115`
- **Verify:** SIM
- **Status:** OK

### HK-LAT-02
A latchup in any hardware-controlled region shall latch a global critical
latchup condition.
- **Parent:** FAR-PM_FPGA_L4REQ-14, FAR-PM_FPGA_L4REQ-17
- **Design:** `src/health_monitor.sv:722-724`
- **Verify:** SIM
- **Rationale:** The hardware-controlled regions supply everything downstream,
  so a latchup in one cannot be contained by de-energising that region alone.
- **Status:** OK
- **Evidence:** The condition covers exactly the five hardware-controlled
  regions -- step down, DDR8, DDR16, FPGA and LVDS. Once set,
  `critical_latchup` is never cleared except by `rstn`. Verified for each of
  the five in turn: with the hardware chain booted, dropping the first
  source's PGOOD took every hardware enable outside that region down within
  0.1 ms (`verification/tests/test_hk_lat_global.py`).
- **Note:** **Boot-failure severity and latchup severity are not the same for
  these regions, and the asymmetry is easy to miss.** DDR8, DDR16 and LVDS are
  non-critical for a *boot failure* -- the boot chain continues past them and
  the PolarFire is told by telemetry (`HK-SEQ-03`). They are critical for a
  *latchup*, which takes the entire payload down until reset or power cycle.
  The design documentation's monitoring figure shows all three as
  telemetry-only, which is correct only for the boot-failure case
  (`docs/design/pa3-housekeeper.md:307-310`). See
  [`HK-F-14`](pa3-housekeeper-findings.md#hk-f-14).

### HK-LAT-03
A global critical latchup shall hold every power enable in the system
deasserted.
- **Parent:** FAR-PM_FPGA_L4REQ-14, FAR-PM_FPGA_L4REQ-17
- **Design:** `src/health_monitor.sv:250`, `:274`, `:299`, `:324`, `:356`, `:373`, `:397`, `:421`, `:440`, `:459`, `:477`
- **Verify:** SIM
- **Rationale:** A latchup in a hardware-controlled region can damage the
  board, so the response must be total and must persist -- "hold" rather than
  "deassert" is deliberate, because a subsequent boot request from the
  PolarFire must not be able to re-energise anything.
- **Status:** OK
- **Evidence:** With 32 of the 33 enables asserted -- all but Stepper Sec,
  which a booted Stepper Pri holds down -- a DDR8 latchup took all 33 low
  within 0.1 ms, and none re-asserted across 1.2 s sampled every 0.1 ms
  (`verification/tests/test_hk_lat_hold.py`). The enables are read from
  `top.sv`, not listed in the test.
- **Note:** Implemented by gating the reset of all 11 region instances with
  `rstn && !critical_latchup`; the reset gating is design detail.

### HK-LAT-04
Recovery from a global critical latchup shall require assertion of the external
reset input or a power cycle.
- **Parent:** FAR-PM_FPGA_L4REQ-14, FAR-PM_FPGA_L4REQ-17
- **Design:** `src/health_monitor.sv:695-701`, `:722-724`
- **Verify:** SIM
- **Status:** OK
- **Evidence:** The external reset input is the port `arstn`, schematic pin
  `P22`. It is driven only by a `KSC403J50SHLFG` pushbutton and a 4.7 kohm
  pull-up, so there is no on-orbit path to assert it -- see
  [`HK-F-17`](pa3-housekeeper-findings.md#hk-f-17).
- **Evidence:** After a DDR8 latchup the latch held through the fault being
  removed, every software control input toggled twice (at once and after the
  200 ms retry hold), and 1.2 s elapsing; no enable asserted. After `arstn`
  the first enable asserted 997.0 ms after release
  (`verification/tests/test_hk_lat_hold.py`). A universal negative: this shows
  the sequences tried did not clear it, not that none could.

### HK-LAT-05
A latchup in a software-controlled region shall power down only that region.
- **Parent:** FAR-PM_FPGA_L4REQ-12
- **Design:** `src/health_monitor.sv:722-724`, `src/pwr_region_sm.sv:168-173`
- **Verify:** SIM
- **Status:** OK
- **Note:** The software regions are absent from the `critical_latchup`
  condition, so their latchup is contained to the region.
- **Evidence:** All six software regions latched in turn in one boot, each
  by its first source losing PGOOD. Each time its own enables fell and none of
  the other enables on the device changed across 3.0 ms sampled every 0.05 ms
  (`verification/tests/test_hk_lat_sw_region.py`).

### HK-LAT-07
The housekeeper shall retain the PGOOD and nFAULT state of every
hardware-controlled source as sampled at the instant of the first failure.
- **Parent:** FAR-PM_FPGA_L4REQ-16, FAR-PM_FPGA_L4REQ-30, FAR-PM_FPGA_L4REQ-29
- **Design:** `src/health_monitor.sv:631-660`
- **Verify:** SIM
- **Rationale:** The first failure is the diagnostic one. Later failures are
  usually consequences of it, so a snapshot that kept updating would report the
  final state of a collapsing system rather than its initial cause.
- **Status:** OK
- **Evidence:** After a DDR16 latchup, the retained state of all 26 hardware
  PGOOD and nFAULT inputs, read from three beacons, matched the state at the
  failure bit for bit, although 20 of them had changed since
  (`verification/tests/test_hk_uart_beacon.py`). A second failure cannot be
  *declared* after a hardware latchup -- every region is held in reset -- so
  the first-fault-wins guard is shown as the inputs of one changing, not as a
  second declaration.
- **Evidence:** Guarded by `&& !failed`, so the snapshot is first-fault-wins.
  Triggered by FPGA or step-down boot failure, or latchup in step-down, DDR8,
  DDR16, FPGA or LVDS.

### HK-LAT-08
A declared latchup shall deassert the affected power enables within 10 us of
the fault first appearing at the input pin.
- **Parent:** FAR-PM_FPGA_L4REQ-14, FAR-PM_FPGA_L4REQ-17, FAR-PM_FPGA_L4REQ-12
- **Design:** `src/pwr_src_bootseq.sv:70`, `src/pwr_region_sm.sv:180-188`, `src/glitch_filter.sv:15`
- **Kind:** Performance
- **Verify:** SIM
- **Rationale:** Both parents require the housekeeper to act "immediately", which
  no test can pass or fail. Latchup protection exists to remove power before the
  part is damaged, so the bound is the whole obligation: a response correct in
  sequence but arbitrarily slow protects nothing. Kept separate from the 5 us
  filter of `HK-IO-05`, which bounds when the input is believed, not when the
  enable moves.
- **Finding:** HK-F-26
- **Status:** OK
- **Evidence:** The realised path is the 5 us filter (`PULSE_WIDTH = 250` at
  50 MHz), then the source state machine entering `LATCHUP`, then the region
  deasserting its enables -- a few clock cycles beyond the filter. Measured
  from the pin: an IMX latchup (1V8 rail dropped after boot) had all four IMX
  enables off 5.13 us later, and a DDR16 latchup (1V2 nFAULT) all three DDR16
  enables off 5.11 us later (`verification/tests/test_hk_response.py`).
- **Note:** Measured from the pin rather than, as previously worded, from the
  filtered transition, so that the bound covers the whole path from fault to
  enable, including the filter.
- **Note:** **Confirmed for FAR-PM_FPGA_L4REQ-14 by systems, 2026-10-01**
  (Dhruv, avionics hardware), who proposed the L4REQ-14 wording "within 10us
  of a falling edge on the nFAULT signal of any non-SW controlled power region
  as long as the nFAULT signal remains stably low for at least 5us +/-
  tolerance". That is this requirement's measurement: from the pin, filter
  included. **Still pending** for L4REQ-12 and -17, which the answer did not
  address; 10 us was proposed for all three on 2026-09-29. Revisit this
  requirement, `VC-HK-0008` and its test when the wording is in Jama, and
  update [`tbr-register.md`](../../../docs/requirements/tbr-register.md).

### HK-PDN-01
The housekeeper shall latch a global power-down request only when the filtered
EPS eFuse PGOOD goes low, when the FPGA region fails to boot, or when the
step-down region fails to boot.
- **Parent:** FAR-PM_FPGA_L4REQ-10, FAR-PM_FPGA_L4REQ-5
- **Design:** `src/health_monitor.sv:703-705`
- **Verify:** SIM
- **Status:** OK
- **Evidence:** Each route exercised on its own: the eFuse PGOOD low took all
  20 enables that were up down; an FPGA boot failure took step-down, DDR8
  and DDR16 down after its fourth attempt; a step-down boot failure set
  `debug[4]`, DDR16's power-down command, which nothing else sets while the
  FPGA region is unbooted. DDR8, LVDS and IMX failing to boot and Eth1
  latching up, together, latched nothing: all 17 sentinel enables and
  statuses stayed up (`verification/tests/test_hk_pdn_routes.py`).
- **Note:** Only the eFuse branch is reachable in the flight configuration; the
  two boot-failure branches depend on the timeout defeated by
  [`HK-F-01`](pa3-housekeeper-findings.md#hk-f-01).
- **Note:** "Only when" makes the list exhaustive, which is what excludes a boot
  failure or latchup in a *software-controlled* region from triggering a global
  power-down. That exclusion was previously stated separately as `HK-PDN-06`.
- **Note:** Shares an RTL expression with `HK-PDN-05` (`src/health_monitor.sv:703-705`).
  This one states what sets the latch; `HK-PDN-05` states that it stays set.
### HK-PDN-02
On a global power-down request the housekeeper shall deassert the regions'
enables in reverse boot order, each stage beginning only once every source in
the stage before it is off: its enable deasserted, and either its PGOOD low or
its power-down timeout (`HK-SRC-11`) elapsed.
- **Parent:** FAR-PM_FPGA_L4REQ-10
- **Design:** `src/health_monitor.sv:553-558`
- **Verify:** SIM
- **Finding:** HK-F-28 (fixed), HK-F-33 (fixed), HK-F-32 (fixed)
- **Status:** OK
- **Evidence:** With every software region up, the stages go down in order
  -- software, LVDS, FPGA, DDR16, DDR8, step-down -- each only once every
  source of the stage before it is off. The whole hardware power-down takes
  32.15 ms: LVDS began at 9.18 ms, after Eth1's and Eth2's last LT3065
  timeout; FPGA at 11.47 ms; DDR16 at 27.54 ms; DDR8 at 29.84 ms; step-down
  at 32.14 ms. With LVDT the only software region up, LVDS began at 2.299 ms,
  once LVDT's timeout had run (`verification/tests/test_hk_pdn_sequence.py`).
  Before the `HK-F-33` fix LVDS began on the same clock as LVDT, and before
  the `HK-F-28` fix the whole sequence took about 1 us.
  A global power-down arriving while a hardware region is still booting
  waits for it: with DDR8 2V5 up and 1V2 booting, DDR8 1V2 went at 0.005 ms,
  2V5 at 2.299 ms once 1V2's timeout had run, and step-down 4V0 at 2.304 ms,
  after 2V5's PGOOD. Before the `HK-F-32` fix all three went on one clock.
- **Note:** Reworded on 2026-10-01 from "its enable deasserted and its PGOOD
  low". 18 of the 33 sources are LT3065 LDOs, whose PGOOD stays high once
  disabled (`HK-SRC-11`), so the old wording could never be met on the board
  and the timeout is what is relied on.
- **Note:** Order is software regions, then LVDS, FPGA, DDR16, DDR8, step-down.
  Each gate is `start_pwr_dwn && !<next>_boot_done`, and because `boot_done`
  covers `POWERING_DOWN`, each stage waits for the previous one to finish
  powering down rather than merely to begin.

### HK-PDN-03
All software-controlled regions shall be powered down simultaneously at the
start of a global power-down.
- **Parent:** FAR-PM_FPGA_L4REQ-10
- **Design:** `src/health_monitor.sv:545-550`
- **Verify:** SIM
- **Status:** OK
- **Evidence:** With IMX, LVDT, Eth1, Eth2 and Stepper Pri up, all five began
  powering down on one clock, 5.2 us after the eFuse PGOOD fell, and every
  software enable was down before LVDS began
  (`verification/tests/test_hk_pdn_sequence.py`).
- **Note:** Read as each region *beginning* together; `HK-PDN-04` requires a
  region's own sources to go one at a time, so they cannot all fall at once.

### HK-PDN-04
Within a region, source enables shall be deasserted in reverse of their boot
order, each source beginning only once the source after it is off: its PGOOD
low, or its power-down timeout (`HK-SRC-11`) elapsed.
- **Parent:** FAR-PM_FPGA_L4REQ-10
- **Design:** `src/pwr_region_sm.sv:150-164`
- **Verify:** SIM
- **Finding:** HK-F-28 (fixed), HK-F-32 (fixed)
- **Status:** OK
- **Evidence:** Order within every region is correct, and every step waits
  for the source after it to be off. Where that source's PGOOD stays high once
  disabled -- every FPGA and Ethernet LT3065 rail, IMX 1V8, and DDR 0V6
  (`HK-F-02`) -- the next source began 2.294 ms later, on the timeout; where
  it falls -- IMX 3V3 and 2V9, DDR 1V2, step-down 4V0 and 3V0 -- about 5.1 us
  later, on the filter (`verification/tests/test_hk_pdn_sequence.py`). Before
  the `HK-F-28` fix 20
  steps began within 0.1 us of the source after them, and Eth1's and Eth2's
  first step waited only 1.309 ms.
  A region told to power down while still booting does the same: IMX
  withdrawn with 1V1, 1V8 and 2V9 up and 3V3 booting deasserted 3V3 at once,
  2V9 at 2.294 ms once 3V3's timeout had run, 1V8 5.2 us after 2V9's PGOOD
  fell, and 1V1 at 4.593 ms after 1V8's timeout. Before the `HK-F-32` fix all
  four went on one clock.
- **Note:** Reworded on 2026-10-01 from "has its PGOOD low", for the reason
  given under `HK-PDN-02`.

### HK-PDN-05
The global power-down request, once latched, shall remain latched until
reset.
- **Parent:** FAR-PM_FPGA_L4REQ-10
- **Design:** `src/health_monitor.sv:703-705`
- **Verify:** SIM
- **Status:** OK
- **Evidence:** After an eFuse power-down, with the eFuse PGOOD restored and
  every software control toggled twice, no enable asserted across 1.2 s --
  although step-down's start request is still asserted and would boot it on
  the next clock if the request cleared. After `arstn` the first enable
  asserted 997.0 ms after release (`verification/tests/test_hk_pdn_sequence.py`).
- **Note:** `start_pwr_dwn` is set-only. This is what makes FAR-PM_FPGA_L4REQ-10's "remain in a
  powered off state until power cycle" true, and it also means a momentary
  eFuse PGOOD dropout of 5 us permanently shuts the payload down.

---

## TLM -- Status and failure reporting to the PolarFire

### HK-TLM-01
The housekeeper shall report per-region boot status to the PolarFire on a
dedicated output per region.
- **Parent:** FAR-PM_FPGA_L4REQ-28, FAR-PM_FPGA_L4REQ-29, FAR-TMTC_SW_L4REQ-18
- **Design:** `src/health_monitor_io.sv:311-321`
- **Verify:** SIM, HW
- **Status:** OK
- **Evidence:** Eleven distinct outputs, one per region. Each software region
  withdrawn and requested in turn moved only its own status; with DDR8
  failed and the rest booted, only `ddr8_status_to_pf` read 0
  (`verification/tests/test_hk_tlm_status.py`). The FPGA region's status is
  excluded from "does not alter another's": it gates the rest by design
  (`HK-TLM-02`), before the PolarFire is powered to see it.
- **Note:** Ten region status outputs plus `pf_status_to_pf`. Schematic nets
  `R_<region>_PGOOD`.
- **Note:** Shares an RTL expression with `HK-TLM-02` and `HK-TLM-09` (`src/health_monitor_io.sv:311-321`). This one requires the outputs to exist, `HK-TLM-02` constrains them before the PolarFire is up, and `HK-TLM-09` states what the PolarFire can infer from them.
### HK-TLM-02
Every region status output shall be driven low while the FPGA region has not
booted successfully.
- **Parent:** FAR-PM_FPGA_L4REQ-3
- **Design:** `src/health_monitor_io.sv:311-321`
- **Verify:** SIM
- **Status:** OK
- **Evidence:** With the FPGA region never booting, step-down, DDR8 and DDR16
  were each fully enabled, and no region status rose across 2.2 s sampled
  every 0.1 ms (`verification/tests/test_hk_tlm_status.py`).

### HK-TLM-03
The housekeeper shall report, for each software-controlled region, which source
in that region failed and whether the failure was a boot failure or a latchup.
- **Parent:** FAR-PM_FPGA_L4REQ-30
- **Design:** `src/pwr_region_imx_bootseq.sv:169-191`, `src/pwr_region_eth1_bootseq.sv:169-188`
- **Verify:** SIM
- **Status:** GAP
- **Evidence:** Every source of every software region failed both ways and
  read back: each (source, kind) reads distinctly, as the encoding above
  says, but in all six regions the first source's boot failure reads 0 --
  the same as before anything failed (`verification/tests/test_hk_tlm_metadata.py`).
- **Note:** Previously `AMBIG`. The wording is clear -- report which source
  failed -- and an output that reads the same for "no failure" and "the first
  source failed to boot" does not meet it. The fix is the housekeeper's to
  choose: reserve 0 for no failure, or state that the metadata is valid only
  once the region's status has fallen. Either way the encoding belongs in the
  ICD, where it does not appear today.
- **Note:** Encoding for a four-source region is: 0-3 = boot failure of source
  0-3, 4-7 = latchup of source 0-3. The reset value is also 0, so
  "no failure" and "source 0 failed to boot" are indistinguishable. A consumer
  must qualify the metadata with the region status output. See
  [`HK-F-06`](pa3-housekeeper-findings.md#hk-f-06).

### HK-TLM-04
The failure metadata outputs shall be sized to the number of sources in their
region.
- **Source decision:** Failure metadata is reported as a per-region bus rather than as a single encoded fault word, so each bus width follows the number of sources in its region.
- **Imposes on:** FPGA design, PolarFire firmware
- **Design:** `src/top.sv:134-141`
- **Verify:** INSP
- **Rationale:** A fixed-width metadata bus would either truncate the larger regions or waste pins on the smaller ones. Sizing each bus to its region keeps every source individually identifiable, which is what lets the PolarFire report which source failed rather than only which region.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Evidence:** Inspected (`test/inspect/telemetry.py`): each metadata bus is
  as wide as its region's source index, plus one bit in a software-controlled
  region for boot failure or latchup (`HK-TLM-03`) -- DDR8 and DDR16 2 bits
  for 3 sources, Eth1, Eth2 and IMX 3 bits for 4, the steppers and LVDT 1 bit
  for 1. The criterion was reworded to say so: "no wider than needed to
  identify a source" alone would fail the 3-bit buses that HK-TLM-03 needs.
- **Note:** DDR8 and DDR16 carry 2 bits for 3 sources, Eth1, Eth2 and IMX carry
  3 bits for 4 sources, and the stepper and LVDT regions carry 1 bit for their
  single source. The two-bit DDR fields cannot express the full
  boot-failure/latchup encoding of HK-TLM-03 for three sources.

### HK-TLM-06
The housekeeper shall report to the PolarFire that it is powered and
configured.
- **Parent:** FAR-PM_FPGA_L4REQ-28
- **Design:** `src/health_monitor_io.sv:322`
- **Verify:** INSP
- **Rationale:** The PolarFire needs to distinguish "the housekeeper is absent
  or unpowered" from "the housekeeper is present and has something to say". A
  statically driven line does that, because an unpowered or unconfigured
  ProASIC3 leaves the output undriven.
- **Status:** GAP
- **Evidence:** The port is `pa3_status_to_pf`, pin `AA4`, reaching the
  PolarFire at `L5` as `pa3_pwr_status`. It is tied to constant `'1`, which
  matches CM-01979 section 17.4.17: "1 = ProASIC3 operational. Hardwired to 1
  whenever the PA3 is powered."
- **Note:** Reworded from "shall indicate that the housekeeper itself is alive",
  which a static line cannot do -- it cannot distinguish a running housekeeper
  from one held in reset. Liveness is `HK-TLM-07`, the toggling heartbeat on a
  separate pin, whose rationale states exactly that distinction -- though that
  pin drives LED D12, so the liveness it shows is to someone looking at the
  board, not to the PolarFire. Scoped to "powered and configured", this
  requirement, the design and the ICD agree.
- **Note:** A `GAP` for two reasons. The line is driven high from the moment
  the PA3 is configured, including while the FPGA region is not booted, which
  conflicts with FAR-PM_FPGA_L4REQ-3 and `HK-OFFNOM-02`. See
  [`HK-F-07`](pa3-housekeeper-findings.md#hk-f-07). And before configuration
  it floats: `RES_PULL "NONE"` in both pinouts, and no pull on either side of
  R865 on the board, so the PolarFire can read "operational" from an
  unconfigured housekeeper (`test/inspect/telemetry.py`; HK-F-25).

### HK-TLM-07
The housekeeper shall emit a heartbeat that toggles every 1 s +/-5 %.
- **Source decision:** A toggling output was adopted because no static status line can distinguish a running housekeeper from one held in reset or unconfigured.
- **Imposes on:** FPGA design, PolarFire firmware, verification
- **Design:** `src/health_monitor.sv:510-520`, `src/top.sv:130`
- **Kind:** Performance
- **Verify:** SIM
- **Rationale:** A toggling output lets an observer distinguish a running
  housekeeper from one held in reset or unconfigured, which no static status
  line can do.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Evidence:** Realised period 996.147 ms. Schematic pin `A5`, net
  `PA3_HEARTBEAT`. Measured: eleven consecutive intervals of 996.147 ms, with
  DDR8 failed from reset and, from 5.5 s, every region held down by a global
  latchup (`verification/tests/test_hk_tlm_heartbeat.py`).
- **Note:** The heartbeat is an output
  only; the PA3 has no heartbeat input from the PolarFire, so the
  "MON PolarFire FPGA Heartbeat" branch of the design documentation's
  monitoring figure is not implemented
  (`docs/design/pa3-housekeeper.md:299-303`).

### HK-TLM-08
The housekeeper shall report a firmware version number to the PolarFire.
- **Parent:** FAR-PM_FPGA_L4REQ-33
- **Design:** `src/health_monitor.sv:508`, `constr/.../io/fm/io_constraints.pdc:175-177`
- **Verify:** INSP
- **Status:** GAP
- **Evidence:** Inspected in the flight build `fm_tmr` at commit `b67f8ad` (2026-10-01) (`test/inspect/version.py`):
  `fw_version[0]` and `[2]` have no pin, `fw_version[1]` drives a
  PolarFire-to-housekeeper link (`PF_TO_PA3_MISC0`), and the manifest records
  no firmware version to compare the RTL's `3'd2` against.
- **Note:** `fw_version` is declared as 3 bits and assigned
  `fpga_boot_succeeded ? 3'd2 : 3'd0`, but only `fw_version[1]` is placed;
  bits 0 and 2 are commented out with an empty pin name. The interface is
  therefore a single wire that reads 1 when the FPGA rails are up. It conveys
  no version and cannot express any value other than 0 and 2. See
  [`HK-F-10`](pa3-housekeeper-findings.md#hk-f-10).

### HK-TLM-09
The housekeeper shall report region status such that the PolarFire can
determine which components are enabled.
- **Parent:** FAR-TMTC_SW_L4REQ-18
- **Design:** `src/health_monitor_io.sv:311-321`
- **Verify:** SIM
- **Finding:** HK-F-27
- **Status:** GAP
- **Evidence:** IMX off, and IMX with all four supplies enabled and its last
  attempting, gave identical readings of every region status output
  (`verification/tests/test_hk_tlm_status.py`).
- **Note:** The status outputs report *boot succeeded*, which is enablement
  plus health, not enablement alone. A region that is enabled but still booting
  reads 0.

---

### HK-TLM-10
A change in region boot status shall appear on the status outputs within 1 us of
the change occurring.
- **Parent:** FAR-PM_FPGA_L4REQ-28, FAR-PM_FPGA_L4REQ-29
- **Design:** `src/health_monitor_io.sv:311-321`
- **Kind:** Performance
- **Verify:** SIM
- **Rationale:** Both parents say what to report and neither says how quickly. A
  failure that takes an unbounded time to reach the status outputs cannot be
  acted on, and the PolarFire has no other view of region health.
- **Finding:** HK-F-26
- **Status:** OK
- **Evidence:** The status outputs are combinational functions of the region
  state, so the realised latency is a few clock cycles at most. Measured on IMX:
  its status output rose 0.04 us after its last PGOOD had passed the input
  filter, and fell 0.03 us after the dropped PGOOD had
  (`verification/tests/test_hk_response.py`). "The change occurring" is taken
  as the causing input passing the filter, whose pin-to-output latency of 252
  clocks is measured by `HK-IO-05`'s test.
- **Note:** **Confirmed by systems, 2026-10-01** (Dhruv, avionics hardware):
  1 us is acceptable for the PolarFire to learn a rail is down. Proposed on
  2026-09-29 for the reporting latency of FAR-PM_FPGA_L4REQ-28 and -29, which
  was TBR. The Jama text is unchanged until it is updated.

## UART -- RS-422 pass-through and failure broadcast

### HK-UART-01
The housekeeper shall forward the RS-422 receive line from the payload bus to
the PolarFire while the FPGA region has booted successfully.
- **Parent:** FAR-PM_FPGA_L4REQ-32
- **Design:** `src/uart_ctrl.sv:106`
- **Verify:** SIM
- **Status:** OK
- **Evidence:** With the FPGA region booted, 8N1 traffic at 115,200 baud on
  the bus input reached the PolarFire output transition for transition, at
  the same instant (`verification/tests/test_hk_uart_forward.py`).

### HK-UART-02
The housekeeper shall drive the RS-422 line to the PolarFire low while the FPGA
region has not booted successfully.
- **Source decision:** The housekeeper sits in the RS-422 path between the payload bus and the PolarFire, so it decides what the PolarFire sees while the FPGA region is down.
- **Imposes on:** FPGA design, PolarFire firmware
- **Design:** `src/uart_ctrl.sv:106`
- **Verify:** SIM
- **Rationale:** While the FPGA region is down the housekeeper owns the line, and an undriven input to an unpowered PolarFire is not a defined state. Driving it low gives the PolarFire a defined level at the moment it is brought up, and is the only level FAR-PM_FPGA_L4REQ-3 allows while the PolarFire is unpowered.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Evidence:** With the FPGA region down, none of 26 bus transitions reached
  the PolarFire, and the line was held at 0 throughout
  (`verification/tests/test_hk_uart_forward.py`).
- **Note:** `tx_to_pf = fpga_pgood ? rx_from_bus : '0`, where `fpga_pgood` is
  `fpga_boot_succeeded` (`src/health_monitor_io.sv:876`). A continuous low is a
  UART break, and the opposite direction idles high (`HK-UART-10`), which is
  why this was once recorded as `DEFECT`. It is not one. The low lasts only
  while the PolarFire is unpowered; the line is released to follow the bus,
  which idles high, as soon as the FPGA rails are up, and that is before the
  PolarFire has configured and its UART is running. The direction to the bus
  faces a receiver that is always powered, so the two are meant to differ. See
  [`HK-F-11`](pa3-housekeeper-findings.md#hk-f-11), withdrawn.

### HK-UART-03
The housekeeper shall forward the RS-422 transmit line from the PolarFire to
the payload bus while the FPGA region has booted successfully and no failure
has been latched.
- **Parent:** FAR-PM_FPGA_L4REQ-32
- **Design:** `src/uart_ctrl.sv:107-108`
- **Verify:** SIM
- **Rationale:** This is the payload's normal telemetry path. It is conditional
  on the FPGA region being up because the PolarFire cannot drive the line
  before then, and on no failure being latched because the housekeeper takes
  the line over in that case to send the beacon (`HK-UART-04`).
- **Status:** OK
- **Evidence:** Booted and unfailed, all 26 PolarFire transitions reached the
  bus; with a failure latched mid-transmission, none of the 89 after it did
  (`verification/tests/test_hk_uart_forward.py`).

### HK-UART-10
The housekeeper shall drive the RS-422 transmit line to the payload bus to the
UART idle level whenever it is not forwarding the PolarFire and not
transmitting the failure beacon.
- **Source decision:** As `HK-UART-02`, for the outbound direction: the housekeeper owns the transmit line whenever it is not forwarding the PolarFire.
- **Imposes on:** FPGA design, PolarFire firmware
- **Design:** `src/uart_ctrl.sv:108`
- **Verify:** SIM
- **Rationale:** An undriven or low line is not neutral. A continuously low
  UART line is a break condition, so the bus receiver would see framing errors
  rather than silence, and the release from break can consume the first
  character once real traffic starts.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Evidence:** Idle high with the FPGA region down and the PolarFire input
  toggling, and for 900 ms after a failure until the first beacon
  (`verification/tests/test_hk_uart_forward.py`).
- **Evidence:** `rx_from_pf_mux = fpga_pgood ? rx_from_pf : '1'`
  (`src/uart_ctrl.sv:108`) drives the idle high level when the FPGA region has
  not booted, and the module comment records the intent: "idle of UART should
  be high".
- **Note:** The opposite direction is held low rather than high when the FPGA
  region is not booted (`src/uart_ctrl.sv:106`), and that is correct: it faces
  the PolarFire, which is unpowered then, where this line faces the bus, which
  is not. See `HK-UART-02`.

### HK-UART-04
On a latched failure the housekeeper shall take control of the RS-422 transmit
line to the payload bus.
- **Parent:** FAR-PM_FPGA_L4REQ-31, FAR-PM_FPGA_L4REQ-15, FAR-PM_FPGA_L4REQ-16
- **Design:** `src/uart_ctrl.sv:107`, `src/health_monitor.sv:631-660`
- **Verify:** SIM
- **Status:** OK
- **Evidence:** The PolarFire was transmitting when the failure latched: all
  91 transitions before the latch were on the bus, none of the 89 after it,
  and the line was the housekeeper's from the latch
  (`verification/tests/test_hk_uart_forward.py`).

### HK-UART-05
The housekeeper shall transmit the failure status message at 115,200 baud
+/-2 %, 8 data bits, no parity, one stop bit.
- **Parent:** FAR-RS422_L3REQ-6
- **Design:** `src/uart_ctrl.sv:65`, `:109-115`
- **Kind:** Performance
- **Verify:** SIM, HW
- **Status:** OK
- **Evidence:** Measured across 42 characters of three messages: 115,740.7
  baud (+0.47 %), consecutive characters ten bits apart, every stop bit high,
  and the constant header and trailer decoded as 8N1
  (`verification/tests/test_hk_uart_beacon.py`).
- **Note:** `BAUD_VAL` is 26, giving 50 MHz / ((26+1) x 16) = 115,740.74 baud,
  which is +0.47% against the required 115,200 and so inside the +/-2%
  tolerance stated here. The +/-2% is the usual UART limit, set by the
  receiver's ability to sample the stop bit of a 10-bit character; the divisor
  error consumes about a quarter of it, leaving the rest for oscillator drift
  (`DRV-HK-06`) and for the receiver's own error.
- **Note:** CM-01979 section 17.1.1 gives the link as 115200 "default, but
  configurable". The housekeeper has no configuration path, and it shares the
  RS-422 lane with the PolarFire. See
  [`HK-F-21`](pa3-housekeeper-findings.md#hk-f-21).

### HK-UART-07
The failure status message shall report the PGOOD and nFAULT snapshot latched
at the first failure, not the live signal values.
- **Parent:** FAR-PM_FPGA_L4REQ-16
- **Design:** `src/uart_ctrl.sv:185-277`, `src/health_monitor.sv:631-660`
- **Verify:** SIM
- **Status:** OK
- **Evidence:** Every message after a DDR16 latchup read
  `DE AD BE EF FF 01 01 1D 1F 3F BA DD FE ED` -- the at-failure snapshot --
  although every rail had gone down and further faults had been asserted since
  (`verification/tests/test_hk_uart_beacon.py`).

### HK-UART-08
The failure status message shall repeat every 1 s +/-5 % until reset.
- **Parent:** FAR-PM_FPGA_L4REQ-15, FAR-PM_FPGA_L4REQ-16
- **Design:** `src/uart_ctrl.sv:133-138`, `:320-329`
- **Kind:** Performance
- **Verify:** SIM
- **Rationale:** Repetition is what makes the beacon useful: the bus may not be
  listening at the instant of failure, so the message must persist rather than
  be sent once.
- **Status:** OK
- **Evidence:** Realised period 996.147 ms, counted from the end of each
  message, so message to message is 997.186 ms -- measured over three, and
  nothing sent in the 1.2 s after reset (`verification/tests/test_hk_uart_beacon.py`).
- **Note:** **Confirmed by systems, 2026-10-01** (Dhruv, avionics hardware):
  +/-5 % is acceptable for the "every (TBR) second" of FAR-PM_FPGA_L4REQ-15.
  This requirement already stated it, so nothing here changed.

### HK-UART-09
The first failure status message shall be transmitted within 1 s +/-5 % of the
failure being latched.
- **Parent:** FAR-PM_FPGA_L4REQ-15
- **Design:** `src/uart_ctrl.sv:126-138`
- **Kind:** Performance
- **Verify:** SIM
- **Rationale:** Bounds how long the bus can be unaware that the payload has
  failed.
- **Status:** OK
- **Evidence:** Realised first-message latency 996.147 ms; measured 996.149 ms
  after a DDR16 latchup (`verification/tests/test_hk_uart_beacon.py`). That
  meets this requirement's 1 s +/-5 %.
- **Note:** **Confirmed by systems, 2026-10-01** (Dhruv, avionics hardware):
  a first message 1 s after the failure is acceptable, because the fault has
  already been cleared -- power removed -- by the time the message is sent.
  Proposed on 2026-09-29 for FAR-PM_FPGA_L4REQ-15, which is silent on it;
  it need not be immediate.
- **Note:** The state machine goes `IDLE` to `START_CNTR` on `failed` and only
  leaves `START_CNTR` once the counter reaches the one-second threshold, so the
  first message is delayed by a full period. The module's own comment at
  `uart_ctrl.sv:118` states "first message should be sent out immediately after
  failure". Code and comment disagree; see
  [`HK-F-12`](pa3-housekeeper-findings.md#hk-f-12). Formerly `DEFECT` on that
  disagreement; moved to `OK` because the requirement itself is met, and the
  comment is `HK-F-12`'s to settle.

---

## PROT -- Discrete protection outputs

### HK-PROT-01
The housekeeper shall provide an active-low short output for each of the IMX
1V1 and 1V8 supplies.
- **Parent:** FAR-PM_FPGA_L4REQ-6
- **Design:** `src/top.sv:127-128`, `src/health_monitor.sv:103-104`, `:677-692`
- **Verify:** INSP
- **Status:** OK
- **Evidence:** Inspected against the RTL, both pinouts and the schematic
  export of CM-03543 rev 2 (`test/inspect/protect.py`). Both are outputs of
  `top.sv`, passed through `health_monitor_io` and driven from one block in
  `health_monitor.sv`, the one acting on `imx_latchup`. FM and EM put them on
  `C3` and `A8` with a pull-up. On the board each reaches its rail through the
  same circuit: 33 ohm series resistor (R454, R452) to a control net pulled up
  to `3V3_ASIC` (R534, R556, 100 kohm); the gate of a P-FET (Q3, Q5,
  DMG1013UW) whose source is on `3V3_ASIC`; its drain, pulled down, on the
  gate of an N-FET (Q4, Q6, BSC026N04LS) whose source is on GND and whose
  drain reaches `1V1_IMX` or `1V8_IMX` through a 5 mohm resistor (R533,
  R553). Driving the output low shorts the rail: active low, and held
  released while the FPGA is unconfigured.
- **Note:** Schematic pins `C3` and `A8`, nets `R_1V1_IMX_nSHORT` and
  `R_1V8_IMX_nSHORT`. The N-FET symbol names drain pins 7 and 8 "S"; the
  connections are right, and the inspection follows nets rather than names.

### HK-PROT-02
Both IMX short outputs shall be asserted when a latchup occurs in any IMX
supply.
- **Parent:** FAR-PM_FPGA_L4REQ-6
- **Design:** `src/health_monitor.sv:683-686`
- **Verify:** SIM
- **Rationale:** The IMX531 has power-on and power-off ordering requirements
  between its rails. A latchup on any one of them takes that rail down out of
  sequence, which cannot be prevented; pulling every rail down as fast as
  possible minimises how long the rails are misaligned.
- **Status:** OK
- **Evidence:** Each IMX source -- 1V1, 1V8, 2V9 and 3V3 -- latched in turn
  on a boot of its own; every one asserted both shorts
  (`verification/tests/test_hk_prot.py`).
- **Note:** **Answered by systems, 2026-10-01** (Dhruv, avionics hardware),
  and the reading proposed on 2026-09-29 was wrong. That proposal took
  FAR-PM_FPGA_L4REQ-6's "with respective supplies" as per-supply -- the 1V1
  short only on a 1V1 latchup, the 1V8 short only on 1V8, neither on 2V9 or
  3V3 -- and this requirement was a `GAP` against it. The intent is to pull
  all the IMX rails down on any of them latching, which is what the design
  does. A rewording of L4REQ-6 to say so has been proposed back.
- **Note:** Reverts, in substance, to its original wording, "Both IMX short
  outputs shall be asserted when a latchup occurs anywhere in the IMX
  region", which was `AMBIG` only because nothing said it was the intent.

### HK-PROT-03
An IMX short output shall be released when the corresponding IMX supply enable
is next asserted.
- **Source decision:** A shorting output was adopted to discharge the IMX supplies, which makes the release condition a design choice rather than a stated need.
- **Imposes on:** FPGA design, hardware design, verification
- **Design:** `src/health_monitor.sv:687-690`
- **Verify:** SIM
- **Rationale:** The short must not persist once the supply is deliberately
  re-enabled, or the region could never recover.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** OK
- **Evidence:** After an IMX latchup, re-requested: each short released 20 ns
  after its own supply's enable rose -- 1V1's first, 1V8's 1.2 ms later, not
  with 1V1's (`verification/tests/test_hk_prot.py`).
- **Note:** Both outputs reset high (`health_monitor.sv:678-680`).

---

## OFFNOM -- Off-nominal and power-transition behaviour

The housekeeper is Class A in [`criticality.md`](../../../docs/requirements/criticality.md):
it is the power sequencer and the safe-mode actor, so off-nominal behaviour is
mandatory rather than optional here.

**None of these requirements is currently satisfied by the design.** They are
written because the behaviour is undefined, not because it is implemented.
Nominal behaviour gets exercised naturally; off-nominal behaviour only gets
tested if a requirement forces it. Each carries `Status: GAP` and needs a
design decision before it can be verified.

### HK-OFFNOM-01
The housekeeper shall hold every power enable output deasserted from the
moment the device begins configuration until its internal reset is released.
- **Source decision:** The ProASIC3 leaves its I/O in a high-impedance state until configuration completes, and the housekeeper drives 33 power enables directly.
- **Imposes on:** FPGA design, hardware design
- **Design:** Not implemented -- no requirement or explicit design provision
- **Verify:** SIM, HW
- **Rationale:** Between power application and configuration the ProASIC3 I/O
  are in their unconfigured state. Any enable that floats or glitches high in
  that window energises a rail before the sequencer exists, defeating the
  entire boot order.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** GAP
- **Note:** ProASIC3 is flash-based and live at power-up, which makes this
  window short -- but it is not zero, and nothing currently states what the
  outputs must do during it. Confirm the device's unconfigured I/O state and
  whether external pull-downs are fitted on the 31 enable nets.

### HK-OFFNOM-02
The housekeeper shall drive every output to the PolarFire to its inactive state
whenever the FPGA power region is not booted.
- **Parent:** FAR-PM_FPGA_L4REQ-3
- **Design:** `src/health_monitor_io.sv:311-322`, `src/top.sv:131-141`
- **Verify:** SIM
- **Rationale:** The housekeeper is powered from `28V0_EPS`, upstream of every
  rail it sequences, so it is alive and driving for at least a second before
  the PolarFire has power. Driving a logic high into an unpowered input
  forward-biases the ESD structure. The same holds after a power-down: once
  the FPGA region is down it stays down until a power cycle, with the
  housekeeper still running.
- **Status:** GAP
- **Evidence:** Watched through both windows -- reset release to FPGA region
  booted, and 5 ms after an eFuse power-down took it down with an IMX latchup
  recorded. `pa3_status_to_pf` is high in both; `imx_failure_metadata` holds
  the latchup code through the second. The RS-422 line to the PolarFire is held
  low in both, with the bus idling high (`verification/tests/test_hk_offnom.py`).
- **Note:** "Booted" is the FPGA region's rails in regulation as the
  housekeeper sees them, `fpga_boot_succeeded`. The housekeeper has no signal
  from the PolarFire saying it has configured, and for protecting the
  PolarFire's I/O the rails are what matter: once they are up, its I/O banks
  are powered.
- **Note:** Widened from "until the FPGA power region has booted successfully",
  which covered only the first window. The second is the one where failure
  metadata exists to be driven: DDR metadata latches only while the FPGA region
  is booted (`src/pwr_region_ddr8_bootseq.sv:149`) and software regions cannot
  fail before it. Absorbed the withdrawn `HK-TLM-05`.
- **Note:** The ten region status outputs, `fw_version` and the RS-422 line are
  correctly gated; the 16 failure metadata outputs and `pa3_status_to_pf` are
  not. See [`HK-F-07`](pa3-housekeeper-findings.md#hk-f-07).

### HK-OFFNOM-03
The housekeeper shall initiate a controlled shutdown if the bus input falls
below the minimum operating voltage of the step-down converters.
- **Source decision:** The housekeeper monitors the EPS eFuse PGOOD discrete only, so an input-rail collapse that does not trip the eFuse is not observed.
- **Imposes on:** FPGA design, hardware design
- **Design:** Not implemented -- only the eFuse PGOOD discrete is monitored
- **Verify:** SIM, HW
- **Rationale:** A slow bus droop is not the same event as an eFuse trip. The
  housekeeper currently learns about input problems only through
  `eps_efuse_pgood`; a brownout that stays above the eFuse threshold but below
  the converters' dropout produces undefined rail behaviour with no response.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** GAP
- **Evidence:** No undervoltage threshold, comparator or timer exists for the bus input. The housekeeper sees only the eFuse PGOOD discrete, which asserts on a trip rather than on a droop, so a slow decay produces no event until the eFuse has already opened.

### HK-OFFNOM-04
The housekeeper shall drive all power enables to their deasserted state on loss
of its input clock.
- **Source decision:** Every power enable is held by a register clocked from the 50 MHz input, so the enables retain their last value if that clock stops.
- **Imposes on:** FPGA design, hardware design, verification
- **Design:** Not implemented -- no clock monitor exists, and the enable
  registers are synchronously reset
- **Verify:** SIM, HW
- **Rationale:** Every timer, sequencer and fault response in the design is
  synchronous to the single 50 MHz clock. If it stops, the housekeeper freezes
  with its enables latched in whatever state they held -- including mid-boot,
  with rails partially energised. Latchup detection freezes with it, so the
  rails remain energised *and* the fault response that would protect them is
  dead. That combination is what damages hardware.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** GAP
- **Note:** Closing this needs three things together, and none of them is
  present: a safe reset value on the enable registers (this one **is**
  satisfied -- `pwr_en <= '0'`, `src/pwr_src_bootseq.sv:148`); registers that
  respond without a clock, which requires `DRV-HK-05`; and something able to
  assert reset when the clock is gone, which requires a board change -- see
  [`HK-F-17`](pa3-housekeeper-findings.md#hk-f-17).
- **Note:** The clock is external (`ASIC_50MHZ_CLOCK`, pin `L4`). Two
  oscillators, Y10 and Y6, drive that net through 33 ohm series resistors; if
  that is a stuff option rather than redundancy then the clock is a single
  point of failure. Confirm against the PDF schematic.



---

### HK-OFFNOM-08
Every power enable shall be deasserted within TBR of the housekeeper supply
reaching its operating range.
- **Parent:** FAR-PM_FPGA_L4REQ-3
- **Design:** `constr/a3pe3000l-fg484m/io/fm/io_constraints.pdc`; `src/health_monitor.sv:510-521`
- **Kind:** Performance
- **Verify:** HW
- **Rationale:** `HK-OFFNOM-01` requires the enables to be held deasserted from
  the moment the device begins to configure, but nothing bounds how long that
  takes. The window between supply valid and the design driving its pins is
  exactly where an uncommanded rail would be energised.
- **Finding:** HK-F-26
- **Status:** GAP
- **Evidence:** The A3PE3000L is flash-based and so is live early in the power-up
  sequence, which makes the realised figure small. It is not stated, and
  `HK-F-25` shows the PolarFire may sample housekeeper status inside this window.
- **Note:** The value is TBR and comes from the device power-up specification
  together with the board's supply ramp. Registered in
  [`tbr-register.md`](../../../docs/requirements/tbr-register.md).

## TEST -- Testability and debug access

Guide Section 5: test points, JTAG access and current monitoring cost almost nothing
at schematic stage and are impossible to add after layout.


### HK-TEST-02
The housekeeper shall expose the identity of the first critical fault on
external pins observable without JTAG.
- **Source decision:** Seven debug outputs were bonded out, and they are the only fault evidence available when the PolarFire is unpowered and the UART beacon cannot be read.
- **Imposes on:** FPGA design, verification, integration and test
- **Design:** `src/health_monitor.sv:707-721`, `constr/.../io/fm/io_constraints.pdc:182-188`
- **Verify:** SIM, HW
- **Rationale:** When a critical fault takes the payload down, the PolarFire is
  unpowered and the UART beacon is the only other evidence. A physical fault
  code allows a bench failure to be diagnosed without instrumenting the UART.
- **Reviewed by:** UNASSIGNED
- **Review date:** UNASSIGNED
- **Status:** GAP
- **Evidence:** DDR8 left to fail to boot: `debug[2:0]` read 7. DDR16 then
  latched up: it read 3, the first fault overwritten
  (`verification/tests/test_hk_test_debug.py`). That is the only reachable
  pair -- two *critical* faults cannot follow one another, since the first
  shuts everything down -- so read strictly as "first critical fault" the
  pins would be right; read as the first code the field records, they are not.
- **Evidence:** Seven pins are assigned -- `debug[6:0]` on `L22`, `L21`, `K19`,
  `H19`, `G19`, `F19`, `E19` (`io_constraints.pdc:182-188`) -- but only
  `debug[2:0]` carries a fault code. It encodes step-down latchup=1, DDR8
  latchup=2, DDR16 latchup=3, FPGA latchup=4, step-down boot failure=5, FPGA
  boot failure=6, DDR8 boot failure=7, with 0 meaning no fault seen yet.
- **Note:** Two reasons this is a `GAP` rather than merely undocumented.
  First, the code is **not first-fault-wins**. The `if`/`else if` chain at
  `src/health_monitor.sv:707-713` has no final `else`, so the field is
  overwritten by the highest-priority condition currently active and holds its
  last value once all conditions clear. It is sticky, not a first-fault latch,
  and so disagrees with the UART snapshot of `HK-LAT-07` which is latched at
  first failure. Two artefacts that are supposed to report the same event can
  report different ones.
  Second, `debug[6:3]` are not part of the fault code at all: `debug[3]` and
  `debug[4]` are set-only probes on `ddr16_nfault_1v2` and `ddr16_pwr_dwn`,
  and `debug[5]` and `debug[6]` track `step_down_en_2v2` and `ddr16_en_1v2`
  live (`src/health_monitor.sv:714-721`). Adjacent commented-out assignments
  show the field was being experimented with.
  Either specify the encoding properly or stop calling it a fault code.
- **Note:** Absorbed the withdrawn `HK-IO-07`.

---

## Traceability

Generated, not maintained here. See
[`trace-matrix.md`](../../../docs/requirements/trace-matrix.md), produced by
[`gen_trace_matrix.py`](../../../docs/requirements/gen_trace_matrix.py) from the
`Parent:` field of each requirement below.

A hand-written table previously stood here. It had drifted from the requirements
it summarised, so it is removed rather than corrected: two sources of truth for
the same links will always diverge again, and the stale one is indistinguishable
from the current one when read.

## Withdrawn

Identifiers are permanent and are retired in place, so that older links and
test names still resolve.

- `HK-OFFNOM-05` -- "Following an upset that corrupts a power region state
  machine, the housekeeper shall return that region to a defined state without
  external intervention." Withdrawn as a restatement of `HK-IMPL-10`, which
  requires the housekeeper to remain tolerant to a single upset in its
  sequential logic throughout the mission. Recovery of a region state machine is
  one instance of that obligation rather than a separate one, and stating it
  twice invites the two to be verified to different standards. The verification
  point the entry carried -- that tolerance is shown by fault injection into the
  state registers, not by reading the `syn_encoding` attribute -- is already
  carried by `HK-IMPL-10`.

- `HK-OFFNOM-06` -- "An upset that sets the global power-down latch shall be
  distinguishable, in telemetry, from a genuine eFuse or critical-region
  failure." Withdrawn. The hazard is real and is retained: `start_pwr_dwn` is
  set-only and cleared only by `rstn` (`src/health_monitor.sv:703-705`), so a
  single upset into that bit shuts the payload down until a power cycle the
  payload cannot command. That is recorded against `HK-PDN-05` and analysed in
  [`HK-F-17`](pa3-housekeeper-findings.md#hk-f-17), which sets it alongside the
  two other latches with the same property. What the entry added was a telemetry
  obligation for which no distinguishing mechanism exists or was proposed, so it
  could not be satisfied or verified as written. A requirement to tell the two
  cases apart should follow the decision about how, not precede it.

- `HK-OFFNOM-07` -- "The housekeeper shall reject a malformed or partial UART
  frame received from the bus without entering the failure broadcast state."
  Withdrawn as not a requirement on this design. The housekeeper forwards RS-422
  traffic rather than parsing it, and takes over the transmit line only on a
  latched failure, so there is no receive parser and nothing to reject. The entry
  asserted an obligation that no part of the design carries and marked it `OK`
  because nothing could violate it, which reads as verified behaviour where there
  is none. The observation it was recording -- that a pass-through has no command
  surface to attack -- belongs in the design description, not in a requirement.
  If a command interface is ever added to the housekeeper, the obligation becomes
  real and shall be raised under a new identifier.

- `HK-TLM-05` -- "The failure metadata outputs shall remain valid while the
  FPGA region is unbooted." Withdrawn: it contradicted its own parent. Its
  parent, FAR-PM_FPGA_L4REQ-3, allows a signal to the PolarFire to be driven
  high only while the PolarFire is booted, and the requirement asked for
  metadata to be driven exactly when it is not. Its rationale -- that metadata
  is "most needed exactly when the FPGA region is down" -- has no reader behind
  it: while the FPGA region is down the PolarFire is unpowered, and once the
  region has gone down it does not come back without a reset, which clears the
  metadata. The need its parent does state is carried by `HK-OFFNOM-02`, widened
  to cover every window in which the FPGA region is not booted.

- `HK-PDN-07` -- "A global power-down shall deassert every power enable within
  TBR of the power-down request being latched." Withdrawn on the 2026-10-01
  answer from avionics hardware (Dhruv) to FAR-PM_FPGA_L4REQ-5: no hold-up
  budget exists, board testing shows there is too little hold-up after the
  eFuse opens for a controlled shutdown to be feasible, and the same testing
  shows no supply on the board misbehaves under an uncontrolled one. The TBR
  had no value to take and nothing depends on it. The ordering requirements,
  `HK-PDN-02` and `HK-PDN-04`, stand: they also govern the critical-region
  boot-failure power-down of FAR-PM_FPGA_L4REQ-10, where the input rail is
  still up. `VC-HK-0073` is retired with it.


### Internal signal and a realised parameter value

- `HK-CLK-05` -- "Internal reset shall remain asserted for at least four clock
  cycles after the external reset input is released." Both halves are
  implementation. "Internal reset" is not observable at the housekeeper's pins,
  and "four clock cycles" is the `NUM_STAGES = 4` instantiation parameter
  restated as a requirement.

  The needs it was protecting are already stated. `HK-CLK-04` requires
  asynchronous assertion and synchronous release, which is what makes the
  release metastability-free. `DRV-HK-03` requires the release path to be
  constrained and analysed so that every sequential element leaves reset on the
  same clock edge. `HK-IO-04` requires every input to be captured by a means
  appropriate to its timing relationship with the clock. Synchroniser depth
  beyond the two stages a synchroniser needs is a design choice with no
  externally observable consequence, and the realised value is now recorded as
  evidence on `HK-CLK-04`.

### Negative form replaced by the positive need

- `HK-PDN-06` -- "A global power-down shall not be triggered by a boot failure
  or latchup in a software-controlled region." This was the exhaustiveness
  complement to `HK-PDN-01`, which enumerates what *does* set the latch.
  Changing `HK-PDN-01` to "only when" makes its list exhaustive and carries the
  same exclusion in one statement rather than two.

Four other requirements kept their identifiers and were reworded from a
prohibition to the property they were protecting: `HK-SEQ-04`, `HK-PDN-05`,
`HK-SRC-09` and `HK-TLM-05`. A prohibition is satisfied by a design that does
nothing, and is verified by not observing a failure, which is weaker evidence
than demonstrating the property holds. `HK-TLM-05` has since been withdrawn;
see above.

### Stated a realisation of a need already required elsewhere

- `HK-IO-07` -- "The housekeeper shall drive seven debug outputs reporting the
  first critical fault observed." The need is that the identity of the first
  critical fault be observable on pins without JTAG, which is `HK-TEST-02`. This
  restated that as a pin count.

  It was also wrong on both of its own terms. Only three of the seven outputs
  carry the fault code; `debug[6:3]` are unrelated ad-hoc probes, two of them
  tracking enables live. And the code is not "first" -- the priority chain has
  no final `else`, so it reports the highest-priority condition currently
  active rather than the first one seen.

  The two entries also disagreed about whether the design was acceptable: this
  one was `NEW` while `HK-TEST-02`, citing the same two lines of evidence, was
  `GAP`. The accurate evidence is now recorded on `HK-TEST-02`.

### Stated an implementation choice, and stated it wrongly

- `HK-IO-03` -- "All power-source interface I/O shall use the LVCMOS33 standard
  with no internal pull resistor." Two separate faults.

  The I/O standard is a design choice, not a need. Every one of the 131 assigned
  pins is LVCMOS33 because the interfaces are 3V3 CMOS; restating that as a
  requirement fixes an implementation detail that inspection of the PDC already
  confirms, and would have to be reworded rather than re-verified if a rail
  changed.

  The pull-resistor clause was worse: it was **false**, and it forbade the thing
  the design correctly does. 64 of the 131 pins carry `RES_PULL "DOWN"`,
  including all 33 power enables and all six software control inputs. A
  requirement demanding no internal pull resistor was contradicted by the very
  file it cited as its evidence, and it was marked `NEW` rather than `DEFECT`,
  so the contradiction was never surfaced.

  Had the design been changed to comply, every power enable would have floated
  until the ProASIC3 finished configuring -- energising rails with no sequencing
  behind them. The need that actually matters -- enables held inactive
  passively -- is stated as `HK-IO-09`. The equivalent obligation on the control
  inputs is `HW-FPGA-09`.

### Structural prohibition, not a need

- `HK-CLK-02` -- "The design shall contain exactly one clock domain." This
  constrained the topology of the netlist rather than anything observable at the
  housekeeper's pins. A second clock domain, correctly synchronised and
  constrained, would be indistinguishable from outside, so the statement
  forbade a design choice instead of requiring a behaviour. Its own note gave
  this away by recording that no crossing exists *therefore* none needs
  analysis -- an observation about the current design.

  The single 50 MHz clock is required by `HK-CLK-01`, and the fact that the
  design realises it as one domain is now evidence there. The obligation that
  survives -- that any future crossing be synchronised and constrained -- is
  `DRV-HK-07` in the
  [derived register](../../../docs/requirements/derived-register.md), stated so
  that it binds when a second clock is added rather than being deleted with the
  prohibition.

### Specifies the verification environment, not the housekeeper

Restated as `VENV-01` and `VENV-02` in
[`verification-environment-requirements.md`](../../../docs/requirements/verification-environment-requirements.md),
which specifies the testbench as an article in its own right. Neither can be
verified by inspecting or testing an FPGA, so neither belongs in this document.

- `HK-TEST-03` -- "The verification environment shall be able to force each
  PGOOD and nFAULT input independently, including to states the hardware cannot
  produce." Now `VENV-01`.
- `HK-TEST-04` -- "The verification environment shall exercise the design at its
  synthesis parameter values." Now `VENV-02`.

`HK-TEST-02` stays in this document: requiring the housekeeper to expose the
first critical fault on pins readable without JTAG is an attribute of the
delivered device, not of the testbench.

### Process obligation, moved to a plan

The following are withdrawn from this document and restated as clauses of the
[FPGA Build and Disposition Plan](../../../docs/plans/fpga-build-and-disposition-plan.md).
They constrain how the team works rather than what the housekeeper does, none
can be verified by inspecting or testing a delivered FPGA, and none decomposes a
system need. The engineering intent is unchanged; only the artefact carrying it
has changed.

- `HK-IMPL-06` -- build tool messages captured as a retained artefact.
  Restated as `BUILD-01`.
- `HK-IMPL-07` -- every message dispositioned before release. Restated as
  `BUILD-02`.
- `HK-IMPL-08` -- disposition record version controlled. Restated as
  `BUILD-04`.
- `HK-IMPL-15` -- no release with undispositioned static analysis violations.
  Restated as `BUILD-03`.
- `HK-IMPL-17` -- static analysis disposition record version controlled.
  Restated as `BUILD-04`.

These constrain the build rather than this design, and are held once for both
FPGAs in `build-requirements.md` in the governance repository, where they are
traced and verified like any other requirement.

Note that `HK-IMPL-02` depends on `BUILD-01`: its verification reads the
retained synthesis output for the delivered build. Moving capture out of this
document does not make it optional.

### Absorbed into the requirement it verified

- `HK-IMPL-09` -- "The flight build shall be shown by the synthesis report to
  have actually triplicated the sequential logic." This was the verification
  method for `HK-IMPL-02`, promoted to a requirement because `HK-IMPL-02`'s own
  `Verify: INSP` was satisfied by reading an attribute rather than confirming a
  result. Verifying `HK-IMPL-02` necessarily produces this evidence, so the two
  were one requirement stated twice. The redundancy was actively harmful: the
  pair carried different statuses, so the same property read **OK** in one entry
  and **GAP** in the other, and the OK gave false assurance that the housekeeper's
  sole radiation mitigation had been confirmed. `HK-IMPL-02` now carries the
  register-count check in its `Verify` field and is marked **GAP**.

### Disposition mechanism is not project scope

- `HK-IMPL-13` -- "A classification rule shall not auto-dispose messages
  reporting removed or optimised-away logic, unconstrained timing paths,
  inferred latches, black-box instantiation, or substitution of a requested
  implementation, unless that rule's rationale addresses that specific class."
- `HK-IMPL-19` -- "The disposition record shall identify the classification rule
  set, and its version, that was applied to the build."

  Both constrain *how* a message comes to be dispositioned. `HK-IMPL-07`
  already requires every message to be dispositioned as fixed or
  accepted-with-rationale, and `HK-IMPL-08` requires that record to be version
  controlled with the design. Whether a given disposition was reached by an
  engineer or by a rule does not change what the project must show, and the
  rule set is tooling this project does not own. The obligations on the rule set
  are recorded as `DRV-TOOL-01` in
  [`derived-register.md`](../../../docs/requirements/derived-register.md).

### Entailed by another requirement

- `HK-IMPL-11` -- "A build whose tool message set differs from the dispositioned
  set shall be treated as not released until the difference is dispositioned."
  `HK-IMPL-07` already requires every message to be dispositioned before
  release, so a build carrying a message outside the dispositioned set is
  already unreleasable. This restated that consequence as though it were an
  additional obligation. The diff mechanism it described is implementation, and
  is retained as a note on `HK-IMPL-07`.

### Constrains an artefact this project does not own

- `HK-IMPL-12` -- "Auto-disposition classification rules shall be version
  controlled." The rule set is authored and maintained outside the project as
  part of the tooling. This project can neither discharge nor verify the
  obligation, and stating it here implied an ownership that does not exist.
  Replaced by `HK-IMPL-19`, which requires the build record to name the rule set
  and version applied -- the part that is verifiable here.
- `HK-IMPL-14` -- "Each auto-disposition classification rule shall carry a
  rationale for why messages matching it require no engineering judgement."
  Same reason. The obligation is real and is recorded as a cross-boundary item
  in [`derived-register.md`](../../../docs/requirements/derived-register.md),
  addressed to the rule set owner rather than to this project.

### Restated a build capability rather than a flight need

- `HK-IMPL-05` -- "The design shall support an engineering-model pinout variant
  in which `rs422_ttl_bus_to_farsight_pa3` and `rs422_ttl_farsight_to_bus_pa3`
  are exchanged, without any RTL change." This stated that the design must
  accommodate a test board's wiring, which is configuration management rather
  than a requirement on the system that flies. It was also unfalsifiable: the
  PDC and the `Makefile` `em` target already exist, so nothing could fail it.
  The risk the variant actually creates -- four images that cannot be told
  apart -- is now carried by `HK-IMPL-18`, and the EM pinout appears there as
  evidence rather than as the requirement.

### Interface data now held in the ICD

- `HK-UART-06` -- "The failure status message shall be the 14-byte frame: header
  `DE AD BE EF`, FPGA PGOOD byte, FPGA nFAULT byte, LVDS PGOOD byte, DDR16 byte,
  DDR8 byte, step-down byte, trailer `BA DD FE ED`." The frame layout is
  interface data, not a statement of what the housekeeper must achieve. It is
  held in [CM-01979](../../../docs/icd/CM-01979_ICD_FLIGHT_SOFTWARE_FARSIGHT.md) section 15.6.1, which carries
  the same 14 bytes and additionally defines every rail bit within them -- detail
  this requirement only had in a note. The behaviour the frame serves is still
  required: `HK-UART-07` (latched rather than live status), `HK-UART-08` (repeat
  interval) and `HK-UART-09` (first-message latency).
### Merged into a single release gate

- `HK-IMPL-16` -- "Every static analysis violation shall be dispositioned
  before the build is released, as fixed, accepted-with-rationale, or
  accepted-with-rationale naming why the reported condition is not a defect in
  this design." Merged into `HK-IMPL-15`. Running the tool and dispositioning
  its output were stated as two requirements, but they are not independently
  satisfiable -- violations cannot be dispositioned unless the tool was run, so
  a single release gate covers both without becoming a compound statement.

### Internal mechanism; the observable consequence is stated elsewhere

- `HK-REG-07` -- "A region shall assert `boot_done` in `BOOT_SUCCEEDED`,
  `BOOT_FAILED` and `POWERING_DOWN`." `boot_done` is an internal handshake with
  no external observable. Its two real consequences are already required:
  boot-chain gating by `HK-SEQ-03`, and staged teardown by `HK-PDN-02`.
  Retained as design detail in
  [`docs/design/pa3-housekeeper.md`](../design/pa3-housekeeper.md).
- `HK-REG-10` -- "A region shall assert `boot_failed` only in `BOOT_FAILED`."
  Same reason; the distinction between "finished" and "failed" is visible only
  through `HK-SEQ-03`.

### Redundant; restated a subset of a broader requirement

- `HK-LAT-06` -- "The housekeeper shall not treat a latchup in the DDR8, DDR16
  or LVDS regions as recoverable." Those three are hardware-controlled regions,
  so `HK-LAT-02` already covers them; the statement restated a subset of it. It
  also turned on an undefined term, "recoverable", and was phrased as a
  negative, which is awkward to verify. The asymmetry it was highlighting --
  that these regions are non-critical for boot failure but critical for latchup
  -- is retained as a note on `HK-LAT-02`.

### Relocated to the requirement set that owns the obligation

- `HK-TEST-01` -- "The housekeeper FPGA shall provide JTAG programming and
  debug access on a dedicated connector." The obligation is on the board, not
  on the FPGA design, and `HW-TEST-01` states it for both devices citing both
  connectors. Retired to avoid two requirements against one connector.

### Merged into a boundary-observable requirement

- `HK-SRC-12` -- "A power source shall drive its enable output low while in
  `POWER_OFF`." Merged into `HK-SRC-02`, which now states the reset behaviour
  at the enable pin rather than through an internal state name.
