# ProASIC3 Housekeeper -- Requirements vs Design Findings

Every point at which the Flow system requirements, the design documentation in
[`docs/design/pa3-housekeeper.md`](../design/pa3-housekeeper.md), the schematic,
and the RTL in [`src/`](../../src) disagree.

The RTL is treated as the source of truth for *what the design does*. It is not
treated as the source of truth for *what the design should do*: where the RTL
appears to defeat its own stated intent, that is recorded as a defect against
the design, not as a correction to the requirement.

## Summary

| ID | Severity | Subject |
| --- | --- | --- |
| [HK-F-01](#hk-f-01) | **HIGH** | Power source boot timeout is unreachable in the flight build — *design fixed; recurrence guard open* |
| [HK-F-02](#hk-f-02) | MEDIUM | DDR 0V6 enable outputs are not connected; the rail self-enables — *was HIGH: boot does not stall, VTT runs from 1V2* |
| [HK-F-03](#hk-f-03) | MEDIUM | FAR-PM_FPGA_L4REQ-11 specifies a per-source proportional timeout; the design uses a flat 25 ms |
| [HK-F-04](#hk-f-04) | LOW | Retry hold is 199.229 ms against a requirement of "at least 200ms" — *design fixed* |
| [HK-F-05](#hk-f-05) | **HIGH** | Stepper motor interlock does not prevent simultaneous enable |
| [HK-F-06](#hk-f-06) | MEDIUM | Failure metadata value 0 is ambiguous, and the DDR fields are too narrow |
| [HK-F-07](#hk-f-07) | MEDIUM | Outputs to the PolarFire are driven before the PolarFire is powered |
| [HK-F-08](#hk-f-08) | LOW | `reset_synchronizer` documentation and default disagree with use |
| [HK-F-09](#hk-f-09) | MEDIUM | Post-boot nFAULT ignore window evaluates to zero |
| [HK-F-10](#hk-f-10) | MEDIUM | Firmware version interface is one bit wide and reports no version |
| [HK-F-11](#hk-f-11) | WITHDRAWN | RS-422 line to the PolarFire is driven to a break condition when idle — *withdrawn: the low is required by FAR-PM_FPGA_L4REQ-3* |
| [HK-F-12](#hk-f-12) | LOW | First failure broadcast is delayed one second, contradicting its own comment |
| [HK-F-13](#hk-f-13) | MEDIUM | FAR-AB_L2REQ-1 over-temperature power-off is allocated to hardware with no implementation |
| [HK-F-14](#hk-f-14) | LOW | Design documentation monitoring figure describes unimplemented behaviour |
| [HK-F-15](#hk-f-15) | MEDIUM | Software control inputs bypass the glitch filter; a transient can energise a stepper drive |
| [HK-F-16](#hk-f-16) | **HIGH** | Timing constraints are essentially absent; reset release and synchroniser inputs are unconstrained |
| [HK-F-17](#hk-f-17) | **HIGH** | No on-orbit reset path; the housekeeper reset is a pushbutton, and clock loss is unrecoverable |
| [HK-F-18](#hk-f-18) | **HIGH** | 154 missing-async-reset lint findings dispositioned without rationale; 13 registers have no reset at all |
| [HK-F-19](#hk-f-19) | MEDIUM | Six clock domains carry two alternative oscillator parts; no stability budget is stated anywhere |
| [HK-F-20](#hk-f-20) | LOW | TMR coverage is verified, UART core included; voter refresh and the common-mode clock remain — *was MEDIUM* |
| [HK-F-21](#hk-f-21) | MEDIUM | ICD calls the RS-422 link configurable; the housekeeper rate is fixed, and both FPGAs share the lane |
| [HK-F-22](#hk-f-22) | **HIGH** | Four bitstreams are indistinguishable; two of them are unsafe to fly — *fixed for the file; device-side identification not possible in this toolchain* |
| [HK-F-23](#hk-f-23) | MEDIUM | No system requirement for single-event upset tolerance; TMR mitigates a hazard nothing states |
| [HK-F-24](#hk-f-24) | **HIGH** | PA3/PolarFire discrete interface disagrees at both ends: one net contended, one undriven, three misread |
| [HK-F-25](#hk-f-25) | MEDIUM | Three health indications to the PolarFire have no pull; before configuration they can report healthy |
| [HK-F-26](#hk-f-26) | MEDIUM | Response times are unbounded across the requirement set; four system requirements say "immediately" |
| [HK-F-27](#hk-f-27) | MEDIUM | Three regions report on a single bit; a failed LVDS region is indistinguishable from one still booting — *proposed: a 1 s timeout at the PolarFire, pending systems* |
| [HK-F-28](#hk-f-28) | **HIGH** | The power-down timeout is not restarted, so a booted source is declared off at once and the staged shutdown collapses into 1 us — *design fixed* |
| [HK-F-29](#hk-f-29) | MEDIUM | A region withdrawn during its retry hold pulses its first enable for one clock on the way out — *design fixed* |
| [HK-F-30](#hk-f-30) | MEDIUM | The PolarFire UART transmit line into the housekeeper floats while the PolarFire configures, and is forwarded to the bus |
| [HK-F-31](#hk-f-31) | LOW | The CoreUART transmit state machine is encoded one-hot without safe recovery |
| [HK-F-32](#hk-f-32) | MEDIUM | A region powered down part-way through its boot drops every started source at once, and the stage after it does not wait — *design fixed* |
| [HK-F-33](#hk-f-33) | LOW | The LVDS power-down gate omits LVDT, so LVDS can power down with LVDT still up — *design fixed* |

---

## HK-F-01

**Power source boot timeout is unreachable in the flight build.**

**Severity:** HIGH

**Claimed.** FAR-PM_FPGA_L4REQ-11: "The housekeeper FPGA shall consider a boot attempt of a
power source a fail if it does not boot within 200% of its nominal boot time."
FAR-PM_FPGA_L4REQ-19: at most four boot attempts. FAR-PM_FPGA_L4REQ-18: enables low for at least 200 ms then
restart. The design documentation repeats this at
`docs/design/pa3-housekeeper.md:87-88`.

**Actual.** The boot timeout comparison is
`cntr >= (WAIT_TIME >> CNTR_PRECISION)` at `src/pwr_src_bootseq.sv:105`.

- `WAIT_TIME` is `WAIT_TIME_MULT_FACTOR * 25_000` = `50 * 25_000` = 1,250,000
  clock cycles (`src/pwr_region_ddr8_bootseq.sv:41`, and the equivalent line in
  every other region).
- `CNTR_PRECISION` is 14, so the threshold is `1_250_000 >> 14` = **76 ticks**
  (`src/pwr_src_bootseq.sv:35`).
- `CNTR_RESOLUTION` is 6, so `cntr` is `logic [5:0]` and the counter saturates
  at **63** (`src/pwr_src_bootseq.sv:36`, `src/proasic3_counter.sv:47-48`).

63 is less than 76, so the comparison is never true and `BOOTING` never
transitions to `BOOT_FAILED`.

**Consequence.** A power source that fails to assert a PGOOD rising edge stays
in `BOOTING` **forever, with its enable held high**
(`src/pwr_src_bootseq.sv:88`). Because `boot_timeout` is the only input that
drives the region state machine out of `BOOTING`
(`src/pwr_region_sm.sv:99`), the following are all unreachable in the flight
configuration:

- region `RETRY` and the 200 ms retry hold (FAR-PM_FPGA_L4REQ-18)
- the four-attempt limit (FAR-PM_FPGA_L4REQ-19)
- region `BOOT_FAILED` (FAR-PM_FPGA_L4REQ-11)
- `start_pwr_dwn` via `fpga_boot_failed` or `step_down_boot_failed`
  (`src/health_monitor.sv:703`), so the controlled shutdown on critical boot
  failure required by FAR-PM_FPGA_L4REQ-10 never runs
- the `failed` flag via either boot-failure term
  (`src/health_monitor.sv:631`), so the UART failure broadcast of FAR-PM_FPGA_L4REQ-15/FAR-PM_FPGA_L4REQ-16 is
  raised only by a latchup, never by a boot failure
- `debug[2:0]` codes 5, 6 and 7 (`src/health_monitor.sv:711-713`)

Latchup detection is unaffected and still works, because it does not depend on
this counter.

**Why it was not caught.** The existing testbench instantiates the design with
`WAIT_TIME_MULT_FACTOR = 3` (`test/sim/pa3_health_monitor_io_tst_tb.sv:215`).
That gives a threshold of `75_000 >> 14` = 4 ticks, which is reachable, so the
timeout works in simulation and only fails in the build that flies. This is the
single strongest argument for a verification framework that exercises the
synthesis configuration.

**Disposition: FIXED in the design.** `CNTR_RESOLUTION` in `pwr_src_bootseq`
is now 7, so the threshold fits, and the threshold is rounded up rather than
truncated.

Both changes were needed. Widening the counter alone leaves the comparison at
`76` ticks, which fires at **24.904 ms** -- before the 25 ms the source is
allowed. A rail whose PGOOD rises at 24.9 ms is then declared failed, because
the 5 us glitch filter of `HK-IO-05` delays the edge past the threshold. That
was not predicted; it was found by
`verification/tests/test_hk_src_06.py::test_HK_SRC_06_fail_after_25ms`, which
had been widened first and immediately failed its boot-success half. Rounding
up gives `77` ticks = **25.231 ms**, which puts the quantisation on the safe
side: a timeout that fires late gives a source slightly more than the
requirement promises, where one that fires early can fail a rail that was
about to come good.

Changing `CNTR_PRECISION` instead was considered and rejected. Coarser
(14 -> 15) makes the threshold fit in 6 bits at 38 ticks, but quantises
`LATCHUP_WAIT_TIME` and `PWR_DWN_WAIT_TIME` to 3 ticks = **1.966 ms**, below
the 2 ms both are required to hold (`HK-SRC-10`, `HK-SRC-11`). Finer
(14 -> 13) makes the threshold 152 ticks against a maximum of 63, which is
worse than the original.

**Still open: the recurrence guard.** No elaboration-time check connects a
threshold to the width of the counter it is compared against, and the same
class of error is latent in every timer in the design. An audit found the
others in range for the values in `timing.txt` today -- `health_monitor`
`SECOND` 190 of 255, `uart_ctrl` `SECOND` 190 of 255, `pwr_region_sm`
`RETRY_TIME` 152 of 255, `pwr_src_bootseq` `LATCHUP_WAIT_TIME` and
`PWR_DWN_WAIT_TIME` 7 of 127 -- but `timing.txt` is applied to the RTL at
build time, so any of them could go out of range on an edit, silently, with no
simulation failure at development parameter values. **Needs a named owner.**

---

## HK-F-02

**DDR 0V6 enable outputs are not connected; the rail self-enables.**

**Severity:** MEDIUM -- *was HIGH; the predicted boot stall is ruled out by
the regulator datasheet (2026-10-01), the loss of control is not*

**Claimed.** The RTL treats 0V6 as the third bootable source of each DDR region:
`NUM_DDR8_PWR_SRCS` is 3 (`src/pwr_region_ddr8_bootseq.sv:45`), the region
drives `ddr8_en_0v6` and waits for a rising edge on `ddr8_pgood_0v6`
(`src/pwr_region_ddr8_bootseq.sv:130-136`). The region table at
`docs/design/pa3-housekeeper.md:44` lists a 0.40 ms nominal boot time for it.

**Actual.** In the flight schematic
(`docs/schematics/CM-03545_ASSY__PCB__AVIONICS__FARSIGHT__FLIGHT_MODEL_sch_20260911_105755.json`):

- `ddr8_en_0v6` is assigned to PA3 pin `N18`
  (`constr/a3pe3000l-fg484m/io/fm/io_constraints.pdc`), which sits on net
  `NetU2_N18` -- an auto-named net with exactly one pin on it. The output is
  unconnected.
- `ddr16_en_0v6` is assigned to pin `D1`, on net `NetU2_D1`, likewise a
  single-pin net.
- The 0V6 VTT regulators are `U40` (8 GB) and `U37` (16 GB), both
  TPS7H3302MDAPTSEP. `U40` pin 20 `EN` sits on net `NetR441_1`, whose only
  other connection is `R441` pin 1. `R441` is an `AC0603FR-070RL`, a **0 ohm**
  resistor, whose pin 2 is on net `2V5_8GB`. `U37`/`R946` are identical against
  `2V5_16GB`.
- The PGOOD inputs *are* wired: `0V6_VTT_8GB_PGOOD` runs from `U40` pin 22 to
  PA3 pin `T18`, and `0V6_VTT_16GB_PGOOD` from `U37` pin 22 to PA3 pin `C7`.

So each 0V6 VTT rail is hard-enabled from its own 2V5 rail. The housekeeper
cannot control it, only observe it.

**Consequence, as first written.** By the time the region state machine reaches its 0V6 step --
after 2V5 and then 1V2 have each booted -- `0V6_VTT_*_PGOOD` will already be
high. HK-SRC-05 requires a **rising edge**, not a level
(`src/pwr_src_bootseq.sv:97`), so no edge will be seen and the 0V6 source will
never report success. Combined with HK-F-01 the source then sits in `BOOTING`
indefinitely, the region never reports `boot_succeeded`, and
`ddr8_status_to_pf` / `ddr16_status_to_pf` stay low
(`src/health_monitor_io.sv:311-312`) -- telling the PolarFire that the DDR is
unusable even though the hardware is fine.

Note that the boot chain still advances, because `ddr16_start_boot` and
`fpga_start_boot` are gated on `boot_done`, not `boot_succeeded`
(`src/health_monitor.sv:672-673`) -- but `boot_done` is also never asserted
without a timeout, so in the flight configuration the chain stalls at DDR8 and
**the FPGA rails are never enabled at all**. This should be confirmed on
hardware before being accepted, since the payload evidently does boot; the
most likely explanations are that the 0V6 PGOOD is genuinely late, or that the
0ohm enable strap is a schematic-capture artefact. Either way the design and the
schematic do not agree.

**Checked against the datasheet, 2026-10-01: the stall does not happen.**
EN and VDD come from 2V5, but the VTT output is supplied from `VLDOIN` and
regulated to half of `VDDQSNS`, and both are on the 1V2 rail. VTT cannot rise
before 1V2 does, and the TPS7H3302 asserts PGOOD 4 ms (typical) after VTT
enters its window (datasheet 7.3.5, `tPG(delay)`). The region reaches its 0V6
step about 5 us after 1V2's PGOOD, so 0V6's PGOOD rises roughly 4 ms into
0V6's attempt: a rising edge, inside the 25 ms timeout. The board model has
done this since 2026-10-01, and DDR8 and DDR16 boot in every test that boots
them. That is the "PGOOD is genuinely late" explanation above, and it is why
the payload boots.

**What remains.** The housekeeper still cannot control or remove 0V6, and the
design and schematic still disagree about it. The boot depends on a delay the
datasheet gives only as typical, with no minimum; it would take a 0V6 PGOOD
less than 5 us after 1V2's to miss the edge, so the margin is wide, but it is
not specified. The board model gives 0V6 a nominal of 4 ms after 1V2 for this reason.

**Recommended disposition.** Needs a hardware/FPGA joint decision. Options: change
HK-SRC-05 to accept a PGOOD level rather than an edge for sources that
self-enable; remove 0V6 from the region source list and monitor it separately;
or change the schematic so the PA3 actually controls the rail. **Needs a named
owner.**

**Power-down.** The same wiring means 0V6's PGOOD cannot fall before 1V2's or
2V5's, and 0V6 is first down, so the 1V2 source can never power down on 0V6's
PGOOD and depends on the 2.294 ms fallback. Until `HK-F-28` was fixed that
fallback did not wait at all; it now does, so every DDR power-down spends the
full 2.294 ms on 0V6 (measured: DDR16 1V2 2.2938 ms after 0V6).

---

## HK-F-03

**FAR-PM_FPGA_L4REQ-11 specifies a per-source proportional timeout; the design uses a flat
25 ms.**

**Severity:** MEDIUM

**Claimed.** FAR-PM_FPGA_L4REQ-11: fail "if it does not boot within 200% of its nominal boot
time". `docs/design/pa3-housekeeper.md:87`: "If a power source fails to assert
PGOOD within twice the expected boot time".

**Actual.** Every one of the 33 sources is given the same
`WAIT_TIME_MULT_FACTOR * 25_000` = 25 ms window. There is no per-source value
anywhere in `src/`.

**Consequence.** The nominal boot times in the region table at
`docs/design/pa3-housekeeper.md:39-71` span 0.40 ms to 5.1 ms. Twice those
values would be 0.8 ms to 10.2 ms; the design uses 25 ms uniformly, which is
between 2.5x and 62x the nominal time depending on the source. The requirement
as written is not implemented, and no source is detected as slow within the
window the requirement intends.

**Recommended disposition.** Reword the requirement to state a flat timeout and
justify the value, or parameterise the timeout per source. Rewording is the
cheaper option and matches the design intent, but note that a flat 25 ms
substantially weakens fault detection on the fastest rails. Correct
`docs/design/pa3-housekeeper.md:87` either way.

**Update, 2026-09-29.** Systems were asked where the nominal boot times are
defined, with a proposed answer: each regulator's datasheet start-up time with
the capacitor fitted, which the board model already computes per rail. Pending
their confirmation, `HK-SRC-06` now follows its parent -- 200 % of that nominal
time -- instead of stating 25 ms, and is `GAP`. Rewording the parent to a
flat timeout, the cheaper option above, is no longer the one being asked for.

**Update, 2026-10-01.** Avionics hardware confirmed the datasheet start-up
time, "either on the board schematic or in the testing that has been
performed on the avionics board". Checking the board model against the
datasheets the same day showed "start-up" needs pinning down: on the
TPS54821 PGOOD waits for the soft-start pin to reach 1.4 V, so enable to
PGOOD is 2.3 times the soft-start time. Taking enable to PGOOD, DDR8's 2V5
source has a nominal of 4.139 ms and a bound of 8.278 ms, and the design
waits 25.231 ms (`verification/tests/test_hk_src_06.py`). Still open: the
enable-to-PGOOD reading, the board test data, and whether a per-source
timeout is wanted on SV1 or only on later units.

---

## HK-F-04

**Retry hold is 199.229 ms against a requirement of "at least 200ms".**

**Severity:** LOW

**Claimed.** FAR-PM_FPGA_L4REQ-18: "shall immediately set all power enable signals in the power
region low for at least 200ms".

**Actual.** `RETRY_TIME` is `WAIT_TIME_MULT_FACTOR * 200_000` = 10,000,000
cycles (`src/pwr_region_ddr8_bootseq.sv:44`). The region counter has
`CNTR_PRECISION` 16, so the threshold is `10_000_000 >> 16` = 152 ticks
(`src/pwr_region_sm.sv:38`, `:118`). 152 x 65,536 = 9,961,472 cycles =
**199.229 ms** at 50 MHz.

**Consequence.** The realised hold is 771 us short of the stated minimum. This
is a quantisation artefact of the prescaled counter, not a design error, and is
almost certainly immaterial -- but as written the requirement is not met.

**Disposition: FIXED in the design.** The threshold is rounded up rather than
truncated, `(RETRY_TIME + 2^16 - 1) >> 16` = 153 ticks = **200.540 ms**
(`src/pwr_region_sm.sv:118`), as the source boot timeout already was under
`HK-F-01`: a hold that ends late gives the rail more off-time than promised,
where one that ends early breaks the requirement. Measured at 200.500 ms by
`verification/tests/test_hk_reg_retry.py`, within its 0.1 ms sampling. Every
region's hold is 1.31 ms longer; a region that fails all four attempts takes
702.5 ms rather than 698.6 ms. Rewording FAR-PM_FPGA_L4REQ-18 was the
alternative. The general point stands: every interval in the design is
quantised, and the requirements should state realised values with
tolerances rather than round nominal figures. See the derived timing table in
[`pa3-housekeeper-requirements.md`](pa3-housekeeper-requirements.md#derived-timing-constants).

---

## HK-F-05

**Stepper motor interlock does not prevent simultaneous enable.**

**Severity:** HIGH

**Claimed.** FAR-PM_FPGA_L4REQ-24: "The housekeeper FPGA shall **never** have the primary
stepper motor and the secondary stepper motor enabled at the same time."

**Actual.** The only interlock is one term in the secondary region's power-down
expression, at `src/health_monitor.sv:547`:

```
stepper_sec_pwr_dwn <= !stepper_sec_ctrl || !fpga_boot_succeeded
                       || start_pwr_dwn || stepper_pri_boot_succeeded;
```

There is no corresponding term in `stepper_pri_pwr_dwn`
(`src/health_monitor.sv:548`).

**Consequence.** Three ways both enables can be high simultaneously:

1. The interlock keys on `stepper_pri_boot_succeeded`, not on
   `stepper_pri_en`. While the primary is in `BOOTING` its enable is already
   high (`src/pwr_src_bootseq.sv:88`) but it has not yet succeeded, so the
   secondary is not commanded down. Both enables are high for the whole
   primary boot window.
2. Even once the term asserts, the secondary takes a further clock cycle to
   register `pwr_dwn` (`src/health_monitor.sv:547`), then must transit
   `BOOT_SUCCEEDED` to `POWERING_DOWN` and drive its enable low
   (`src/pwr_src_bootseq.sv:116-128`). The enable overlap is several cycles
   even in the clean case.
3. If the primary never succeeds -- which, per HK-F-01, is the outcome of any
   primary boot problem -- the interlock never asserts at all and the secondary
   stays enabled indefinitely alongside a primary stuck in `BOOTING` with its
   enable high.

Given that these are the two redundant drives of the same focus mechanism, a
simultaneous enable is a mechanism-damage risk, not just a power-budget one.

**Measured.** `verification/tests/test_hk_sw_down.py` boots the secondary,
then requests the primary: both enables are high for **3.005 ms**, from the
primary's enable until 5 us after its PGOOD rises -- the primary's whole boot
window, as above. The interlock itself acts as worded; the overlap is the
defect.

**Recommended disposition.** Change the design. The interlock should be
combinational on the enables themselves, and should be symmetric, so that
neither region can assert its enable while the other's is asserted. **Needs a
named owner.**

---

## HK-F-06

**Failure metadata value 0 is ambiguous, and the DDR fields are too narrow.**

**Severity:** MEDIUM

**Claimed.** FAR-PM_FPGA_L4REQ-30: "The housekeeper FPGA shall report which power source failed
inside a SW-controlled power region to the PolarFire FPGA."

**Actual.** For a four-source region the encoding is 0-3 = boot failure of
source 0-3 and 4-7 = latchup of source 0-3
(`src/pwr_region_imx_bootseq.sv:169-191`,
`src/pwr_region_eth1_bootseq.sv:169-188`). The reset value is `'0`
(`src/pwr_region_imx_bootseq.sv:171`).

Two problems:

1. **0 is overloaded.** "No failure has occurred" and "source 0 failed to boot"
   are the same code. A consumer must qualify the field with the region's
   status output to tell them apart, and nothing in the requirements says so.
2. **The DDR fields are too narrow.** `ddr8_failure_metadata` and
   `ddr16_failure_metadata` are 2 bits (`src/top.sv:134-135`) for regions with
   three sources. Two bits cannot carry the six codes the scheme needs. The
   DDR regions are also hardware-controlled, so FAR-PM_FPGA_L4REQ-30 does not strictly apply to
   them, but the ports exist and are routed to real pins
   (`R_PA3_TO_PF_MISC0` through `MISC3`), so something is being reported and it
   is not documented what.

**Recommended disposition.** Reserve 0 for "no failure" and shift the source
codes up by one, or require consumers to gate on the status output and state
that explicitly in the requirement. Separately, either widen the DDR metadata
fields or document what the two bits mean. Also record the encodings in the
ICD -- they appear nowhere outside the RTL.

---

## HK-F-07

**Outputs to the PolarFire are driven before the PolarFire is powered.**

**Severity:** MEDIUM

**Claimed.** FAR-PM_FPGA_L4REQ-3: "The housekeeper FPGA shall only drive signals high to the
PolarFire FPGA while the PolarFire is booted."

**Actual.** The ten region status outputs are correctly gated on
`fpga_boot_succeeded` (`src/health_monitor_io.sv:311-321`), and so are
`fw_version` (assigned 0 until `fpga_boot_succeeded`,
`src/health_monitor.sv:508`) and the RS-422 line to the PolarFire
(`src/uart_ctrl.sv:106`). Two groups are not:

- **`pa3_status_to_pf` is tied to constant `'1`**
  (`src/health_monitor_io.sv:322`). It is high from configuration onward.
- **The 16 failure metadata outputs are ungated.** They pass from
  `health_monitor` straight to the top-level pins
  (`src/health_monitor_io.sv:862-869`, `src/top.sv:134-141`) with no
  `fpga_boot_succeeded` term.

`heartbeat`, listed here previously, is not one of them: it drives LED D12
through R921 and does not reach the PolarFire.

**Consequence.** The PA3 is powered from an always-on rail and configures
before the FPGA region boots, so it will be driving logic-high into
unpowered PolarFire I/O for at least the first second of every power-up. On the
PolarFire side these are inputs with 33 ohm series resistors and, on some nets,
pull-downs to ground (for example `R986` on `R_PF_TO_PA3_MISC1`), so the
current is limited -- but FAR-PM_FPGA_L4REQ-3 exists precisely to avoid this and the design
does not meet it.

The same happens after a power-down, and there it lasts until the next power
cycle. Once the FPGA region has gone down it does not come back without a
reset, and any failure metadata recorded before the power-down stays driven
into the unpowered PolarFire for the rest of that time.

**Measured.** `verification/tests/test_hk_offnom.py` watches every housekeeper
output whose net reaches the PolarFire in the schematic, from reset release
until the FPGA region boots, and for 5 ms after an eFuse power-down takes it
down with an IMX latchup recorded. `pa3_status_to_pf` is high in both windows
and `imx_failure_metadata` holds the latchup code through the second.

**Separate observation, same area.** Two nets carry a direction in their name
that is the reverse of the RTL port direction:

- `lvdt_ctrl` is an *input* to the PA3 (pin `AA3`) but sits on net
  `R_PA3_TO_PF_MISC16`.
- `fw_version[1]` is an *output* of the PA3 (pin `AB8`) but sits on net
  `PF_TO_PA3_MISC0`.

Superseded by [`HK-F-24`](#hk-f-24), which resolved both against the repaired
schematic export: the first net has no driver and the second has two.

**Recommended disposition.** Gate the metadata outputs and `pa3_status_to_pf`
on `fpga_boot_succeeded`. The metadata registers need not change -- gating the
pins is enough, and the values are still there once the region is booted.
`HK-OFFNOM-02` is the requirement this closes.

---

## HK-F-08

**`reset_synchronizer` documentation and default disagree with use.**

**Severity:** LOW

**Claimed.** `src/reset_synchronizer.sv:7-8`: "outputs a synchronous active-low
reset for 10 clock cycles". The module default is `NUM_STAGES = 3`
(`src/reset_synchronizer.sv:15`).

**Actual.** It is instantiated with `NUM_STAGES = 4`
(`src/health_monitor_io.sv:326-328`), giving four cycles, not ten and not
three.

**Recommended disposition.** Correct the header comment. Low risk, but the
comment is the only statement of intent and it is wrong by a factor of 2.5.

---

## HK-F-09

**Post-boot nFAULT ignore window evaluates to zero.**

**Severity:** MEDIUM

**Claimed.** `src/pwr_src_bootseq.sv:39` defines
`CNTR_NFAULT_IGNORE_TIME = 32'd10000`, and `:112` uses it to suppress latchup
detection for a period after a source with `IGNORE_LATCHUP_ON_BOOT` reaches
`BOOT_SUCCEEDED`. The evident intent is to mask a settling transient for
10,000 clock cycles, that is 200 us.

**Actual.** The guard is
`(!IGNORE_LATCHUP_ON_BOOT || (cntr >= (CNTR_NFAULT_IGNORE_TIME >> CNTR_PRECISION)))`.
`CNTR_PRECISION` is 14, so `10000 >> 14` = **0**, and `cntr >= 0` is true on
the first cycle in the state. The guard therefore has no effect: the step-down
4V0 source has exactly the same post-boot latchup sensitivity as every other
source.

**Consequence.** Whatever settling transient motivated the parameter is not
masked. Since the input is glitch-filtered to 5 us anyway
(HK-IO-05), a short transient would be rejected regardless, so the practical
impact is probably nil -- but the code does not do what it says.

**What the board says about the transient.** Every regulator nFAULT on the
board is a TLV4H290 comparator (100 ns response) on the output of an OPA4H014
current-sense amplifier, not a regulator fault pin, so nFAULT is an
over-current flag. Whether inrush into a rail's output capacitance holds it
low for more than 5 us at turn-on depends on the comparator threshold against
the inrush current, which the schematic sets and nobody has stated. The
step-down 4V0 exemption (`HK-SRC-09`) suggests it does on that rail, and if
the current stays high for a while after PGOOD -- a motor-drive load coming
up, say -- a post-boot window would be the guard against it. That is a
question for avionics hardware, and it decides which disposition below is
right.

**Recommended disposition.** Either remove the dead parameter and the guard, or
fix the scaling so it expresses a real interval. Same root cause as HK-F-01: a
threshold computed by right-shifting a cycle count without checking that the
result is representable.

---

## HK-F-10

**Firmware version interface is one bit wide and reports no version.**

**Severity:** MEDIUM

**Claimed.** FAR-PM_FPGA_L4REQ-33: "The housekeeper FPGA shall report a FW version number to
PolarFire FPGA."

**Actual.** `fw_version` is declared `logic [2:0]` and assigned
`fpga_boot_succeeded ? 3'd2 : '0` (`src/health_monitor.sv:107`, `:508`). In the
pinout, only `fw_version[1]` is placed, at `AB8`; `fw_version[0]` and
`fw_version[2]` are commented out with an empty pin name
(`constr/a3pe3000l-fg484m/io/fm/io_constraints.pdc:175-177`).

**Consequence.** Because the only value ever driven is `3'd2` = `3'b010`, the
unplaced bits are always 0 and the single routed bit does carry the whole
value -- so today the interface happens to work. It works by coincidence. Any
future version number that is not 0 or 2 will be silently truncated to whatever
bit 1 happens to be, and the PolarFire cannot detect that it has been. The
signal also conflates two ideas: it is simultaneously the version number and
the "FPGA rails are up" flag, and `pf_status_to_pf` already carries the latter
(`src/health_monitor_io.sv:320`).

**Recommended disposition.** Either route all three bits and define a real
version enumeration, or narrow the port to one bit, rename it to what it
actually means, and reword FAR-PM_FPGA_L4REQ-33 to match. Do not leave a three-bit port with
two unplaced bits.

---

## HK-F-11

**RS-422 line to the PolarFire is driven to a break condition when idle --
*withdrawn: the low is what FAR-PM_FPGA_L4REQ-3 requires*.**

**Severity:** WITHDRAWN (was MEDIUM)

**Withdrawn.** The analysis below mistook when the low happens. `fpga_pgood`
in `uart_ctrl` is `fpga_boot_succeeded` (`src/health_monitor_io.sv:876`), so
the line is held low only while the FPGA region's rails are not all up -- that
is, while the PolarFire is unpowered. FAR-PM_FPGA_L4REQ-3 forbids driving a
signal high into it then, so `'0` is the only level allowed, and changing it to
`'1` as recommended would have broken that requirement. The line is released
to follow the bus, which idles high, as soon as the rails are up, and that is
before the PolarFire has configured and its UART is running, so its receiver
never sees the break. The other direction idles high because it faces the bus,
which is always powered. `HK-UART-02` is `OK`, and its test now requires the
low.

A different defect sits on the same interface and is recorded as
[`HK-F-30`](#hk-f-30): the PolarFire's transmit line into the housekeeper has
no pull at either end, and floats while the PolarFire configures.

The original entry follows, unchanged.

**Claimed.** FAR-PM_FPGA_L4REQ-32: "The housekeeper FPGA shall forward all UART communication
from the bus to the PolarFire FPGA in the case that the PolarFire FPGA is
currently booted." The design is otherwise careful about idle levels.

**Actual.** `src/uart_ctrl.sv:106-108`:

```
assign tx_to_pf       = fpga_pgood ? rx_from_bus : '0;
assign rx_from_pf_mux = fpga_pgood ? rx_from_pf  : '1;  //idle of UART should be high
```

The PolarFire-to-bus direction is deliberately forced to the idle high level
when the PolarFire is not up, and the comment says so. The bus-to-PolarFire
direction is forced **low** in the same condition.

**Consequence.** A continuously low UART receive line is a break condition. At
the moment the PolarFire finishes booting, its UART receiver sees the line
release from a long break, which typically surfaces as a framing error and may
consume the first character. The asymmetry looks unintentional given that the
adjacent line gets it right.

**Recommended disposition.** Change `'0` to `'1`. Then add a requirement
stating the idle level of both directions explicitly, because nothing in the
Flow set currently constrains it.

---

## HK-F-12

**First failure broadcast is delayed one second, contradicting its own
comment.**

**Severity:** LOW

**Claimed.** `src/uart_ctrl.sv:117-118`: "every second, this state machine
should cycle through and send out pgood/nfault data of HW regions to payload
bus. first message should be sent out immediately after failure."
`src/uart_ctrl.sv:132`: "wait for a second in START_CNTR state before sending
again (except on first send)".

**Actual.** `IDLE` clears the counter and moves to `START_CNTR` on `failed`
(`src/uart_ctrl.sv:126-131`). `START_CNTR` waits unconditionally for the
one-second threshold before sending (`:133-138`). There is no bypass for the
first message.

**Consequence.** The bus learns about a critical failure 996 ms later than the
code claims. Immaterial for a once-per-second beacon, but the comment is
misleading and someone will eventually trust it.

**Measured.** 996.149 ms from a DDR16 latchup to the first start bit
(`verification/tests/test_hk_uart_beacon.py`). That meets `HK-UART-09`'s
1 s +/-5 %, so the requirement is `OK`; what remains is the comment.

**Recommended disposition.** Correct both comments. Avionics hardware
confirmed on 2026-10-01 that a first message 1 s after the failure is
acceptable -- the fault has been cleared by removing power before the message
is sent -- so the immediate send the comment describes is not wanted. The
realised behaviour is still worth stating in FAR-PM_FPGA_L4REQ-15, which is
silent on first-message latency.

---

## HK-F-13

**FAR-AB_L2REQ-1 over-temperature power-off is allocated to hardware with no
implementation.**

**Severity:** MEDIUM

**Claimed.** FAR-AB_L2REQ-1: "The board shall power off the FPA in the event that
operating temperatures are exceeded."

**Actual.** The PA3 has no temperature input. Its complete input list is at
`src/top.sv:22-81`: clocks, reset, PGOOD, nFAULT, the six software control
lines and the RS-422 pass-through. There is no thermal sensor, no ADC and no
threshold anywhere in `src/`.

**Consequence.** FAR-AB_L2REQ-1 is written as a board-level requirement ("the board") but
the only agent that can cut FPA power is the housekeeper, via the IMX region.
Today the only way the FPA is powered off for thermal reasons is if the
PolarFire deasserts `imx_ctrl` on its own thermal telemetry -- which is a
PolarFire firmware behaviour, not a board behaviour, and is not what FAR-AB_L2REQ-1 says.

**Recommended disposition.** Reallocate FAR-AB_L2REQ-1 to the PolarFire firmware and
reword it to name the actor and the mechanism, or add a temperature input to
the housekeeper. This is a requirements-allocation decision, not a design
change. **Needs a named owner.**

---

## HK-F-14

**Design documentation monitoring figure describes unimplemented behaviour.**

**Severity:** LOW

These are already recorded at `docs/design/pa3-housekeeper.md:295-312` and are
repeated here so the requirement set has a single index of disagreements. All
four remain true against the current RTL:

- PolarFire heartbeat monitoring is not implemented; `heartbeat` is an output
  only (`src/top.sv:130`) and the PA3 has no heartbeat input.
- The figure names the Ethernet regions ETH0 and ETH1; the design calls them
  Eth1 and Eth2 (`src/top.sv:39`, `:44`).
- The figure shows DDR8, DDR16 and LVDS as telemetry-only. That is correct for
  a boot failure but wrong for a latchup, which asserts `critical_latchup` and
  takes the whole payload down (`src/health_monitor.sv:722-724`). See
  `HK-LAT-02`.
- The PolarFire Power Controller lifeline carries no messages.

**Recommended disposition.** Redraw the figure, or delete it and rely on the
power-up and power-down sequence diagrams above it, which are accurate.

---

## HK-F-15

**Software control inputs bypass the glitch filter; a transient can energise a
stepper drive.**

**Severity:** MEDIUM

**Claimed.** `docs/design/pa3-housekeeper.md:34-35` states "All PGOOD and NFAULT
inputs pass through a 5 us glitch filter to reject transient noise", which is
accurate as far as it goes. Nothing in the Flow set constrains the control
inputs.

**Actual.** The six PolarFire control inputs -- `eth1_ctrl`, `eth2_ctrl`,
`stepper_pri_ctrl`, `stepper_sec_ctrl`, `lvdt_ctrl` and `imx_ctrl` -- are passed
through a two-stage synchroniser only (`src/health_monitor_io.sv:334-354`) and
are handed to `health_monitor` unfiltered
(`src/health_monitor_io.sv:745-784`). The glitch-filtered set covers the 45
PGOOD/nFAULT signals and the eFuse discrete, and excludes these six.

**Synchronisation is not qualification.** A two-stage synchroniser resolves
metastability; it then propagates a clean single-cycle pulse faithfully. A
20 ns transient is therefore sufficient to be acted on.

**Measured.** `verification/tests/test_hk_io_filter.py`: on each of the six
control inputs a one-clock high pulse -- 20 ns -- starts its region, and a
one-clock low pulse powers it down. The stepper drives included.

**Consequence.** The housekeeper acts on these inputs in two ways, and a
transient on either is consequential:

- a **rising edge** arms a software-controlled region
  (`src/health_monitor.sv:560-596`);
- a **low level** tears one down (`src/health_monitor.sv:545-550`).

Neither corresponds to a command the PolarFire issued.

The exposure is not uniform across the six, and this is why the finding is not
LOW:

- **`stepper_pri_ctrl` / `stepper_sec_ctrl`** -- a spurious edge energises a
  motor drive. That is a mechanism-damage risk, not a recoverable power event;
  the focus mechanism is the only moving part in the payload. It also compounds
  [`HK-F-05`](#hk-f-05): the interlock that is supposed to prevent both motors
  being driven keys on `stepper_pri_boot_succeeded` rather than on the enable,
  so a spurious edge on the secondary while the primary is booting drives both.
- **`imx_ctrl`** -- a spurious edge powers the image sensor unexpectedly,
  outside any commanded sequence.
- **`eth1_ctrl` / `eth2_ctrl` / `lvdt_ctrl`** -- recoverable, and the original
  LOW assessment holds for these three.

**Mitigating factors.** The lines cross the board from the PolarFire through
33 ohm series resistors and are short; they are far less exposed than the PGOOD
lines, which run from switching regulators. Three of the six have confirmed
pull-downs (R986-R988), so they are defined while the PolarFire is unpowered.

**Recommended disposition.** Apply the existing 5 us glitch filter of
`HK-IO-05` to the six control inputs. The added latency is irrelevant at this
level, since region boot takes milliseconds, so there is no evident reason for
the asymmetry -- it reads as an oversight rather than a decision. If it was a
decision, it needs a rationale recorded against `HK-IO-06`.

**Note on the requirement.** `HK-IO-06` previously read "The software control
inputs from the PolarFire shall not be glitch-filtered", which stated the
current implementation as though it were intent and would have obliged an
implementer not to fix it. It has been reworded to require qualification, and
now carries `GAP`.

---

## HK-F-16

**Timing constraints are essentially absent; reset release and synchroniser
inputs are unconstrained.**

**Severity:** HIGH

**Actual.** The entire timing constraint set for the housekeeper is ten lines
(`constr/a3pe3000l-fg484m/sdc/timing_user_constraints.sdc`):

```
create_clock -name {clk} -period 20.000 [ get_ports { clk } ]
set_clock_groups -name {clk_grp_clk_in_50mhz} -asynchronous -group [ get_clocks {clk} ]
```

There is no `set_input_delay` on any of the 51 asynchronous inputs, no
`set_output_delay` on any of the 63 outputs, no `set_max_delay` on any path,
and nothing addressing recovery/removal on the reset network. The
`set_clock_groups -asynchronous` names the design's only clock, so it groups
`clk` against nothing.

**Consequence.** Two specific exposures, both of which change build to build
without any RTL change:

1. **Reset release may not be analysed at all.** `reset_synchronizer` is the
   one module using an asynchronous reset (`src/reset_synchronizer.sv:25`);
   `arstn` drives the clear pins of its flip-flops. Deassertion at a clear pin
   is a recovery/removal check rather than setup/hold, and whether those checks
   are emitted depends on device, tool and flow. A path feeding an asynchronous
   flip-flop input can be silently left unanalysed and still report clean
   timing.

2. **Reset arrival is unbounded across a near-total fanout.** The synchronised
   `rstn` reaches essentially every sequential element -- 33 source state
   machines, 11 region state machines, 51 glitch filters and the UART
   controller. With no bound on that network's delay, elements can leave reset
   on different clock edges. Since `HK-SEQ-01` starts the boot sequence from a
   counter that begins at reset release, a skewed release changes the power-up
   sequence itself.

The same gap covers the synchroniser inputs: an unconstrained path into the
first stage of `dff_sync` can be routed long enough to consume the
metastability settling budget that the second stage exists to provide, and
inter-bit skew across a multi-bit synchronised group can exceed one clock
period, letting bits of the same sample land on different cycles. The six
PolarFire control inputs are the most exposed, because unlike PGOOD and nFAULT
they are not glitch-filtered afterwards (`HK-IO-06`).

**Why this matters more here than on a typical design.** The housekeeper is
Class A: it sequences every rail on the board and it is the safe-mode actor.
"Behaviour varies between builds of identical RTL" is not an inconvenience in
that role -- it means a verification campaign run against one build does not
necessarily apply to the build that flies. It is the same class of problem as
[`HK-F-01`](#hk-f-01), where the flight configuration and the simulated
configuration diverged.

**Recommended disposition.** Change the design. Add, at minimum:

- recovery and removal constraints on the `arstn` clear pins, and confirmation
  in the timing report that they are analysed and met rather than excluded;
- a bound on the `rstn` network such that all elements leave reset on one edge;
- `set_max_delay` below one clock period, that is < 20 ns, on every path into
  the first stage of a synchroniser;
- `set_input_delay` / `set_output_delay` on the external interfaces, so that
  the I/O timing is characterised rather than assumed.

Tracked as `DRV-HK-03` and `DRV-HK-04`. **Needs a named owner.**

---

## HK-F-17

**No on-orbit reset path; the housekeeper reset is a pushbutton, and clock loss
is unrecoverable.**

**Severity:** HIGH

**Claimed.** FAR-AB_L2REQ-9: "FARSIGHT Avionics shall safely reset upon user request."

**Actual.** `PA3_RESET` (PA3 pin `P22`) has exactly three connections in the
flight schematic:

| Designator | Part | Role |
| --- | --- | --- |
| `R358` | `ERJ-2RKF4701X`, 4.7 kohm | Pull-up to `3V3_ASIC` |
| `SW1` | `KSC403J50SHLFG` | Tactile pushbutton to GND |
| `U2E` pin `P22` | A3PE3000L | The reset input |

There is no PolarFire GPIO, no bus discrete, no supervisor and no watchdog on
that net. The housekeeper's reset is a **manual pushbutton**. On orbit, nothing
can assert it.

**Consequence.** The housekeeper cannot be reset in flight. The only recovery is
for the spacecraft bus to remove 28 V at connector `J5`, power-cycling the whole
payload. That may be an acceptable answer for a payload -- but it is currently
implicit. No requirement states it, so no one has agreed to it and nothing
verifies that the bus can actually do it on demand.

This interacts with three other findings and turns each of them from
"recoverable" into "power cycle only":

- **Clock loss** (`HK-OFFNOM-04`). With the clock stopped, every enable holds
  its last value and the fault response is frozen. Asynchronous resets
  (`DRV-HK-05`) would give a mechanism to force the enables safe -- but with no
  way to assert `arstn`, that mechanism has no trigger.
- **The set-only power-down latch** (`HK-PDN-05`). `start_pwr_dwn` is never
  cleared except by `rstn`, so a single upset into that bit shuts the payload
  down permanently.
- **Latched critical latchup** (`HK-LAT-04`). `critical_latchup` is cleared only
  by `rstn`.

In all three cases the requirement set says "recovery requires reset or a power
cycle", which reads as though two options exist. Only one does.

**The clock itself.** `ASIC_50MHZ_CLOCK` is driven by two oscillators -- `Y10`
(`ECS-3225MVQ-500-BP-TR`) and `Y6` (`X35T-L7M-50.000MHZ`), both 50 MHz -- each
through a 33 ohm series resistor onto the same net. Two push-pull CMOS outputs
driving one node would contend; through 33 ohm each they would produce roughly
mid-rail, which the input reads as indeterminate. This is almost certainly a
stuff option rather than redundancy. The JSON export carries no fitted/DNP
field, so it must be confirmed against the PDF schematic. If it is a stuff
option, the housekeeper clock is a single point of failure feeding a Class A
function with no on-orbit reset.

**Recommended disposition.** Needs a named owner and a decision between:

1. **Accept.** Declare that payload recovery is by bus power cycle, write that
   as a requirement, and verify the bus can command it. Cheapest, and may be
   correct -- but it must be stated rather than assumed.
2. **Add a reset path.** Route a PolarFire GPIO or a bus discrete to
   `PA3_RESET`. Board change.
3. **Add a clock monitor.** An independent detector that asserts `PA3_RESET`
   on loss of the 50 MHz reference. Board change, and the only option that
   closes `HK-OFFNOM-04` autonomously.

Options 2 and 3 both require `DRV-HK-05` to be effective, since a
synchronously-reset register cannot respond without a clock.

Separately, confirm the oscillator arrangement.

---

## HK-F-18

**154 missing-async-reset lint findings dispositioned without rationale; 13 registers
have no reset at all.**

**Severity:** HIGH

**Actual.** `lint_waivers.tcl` contains 230 entries. They are not evenly
distributed:

| Tag | Count | Meaning |
| --- | ---: | --- |
| `FLP_NO_ASRT` | **154** | Flip-flop has no asynchronous reset |
| `OTP_UC_INST` | 14 | Unconnected instance output |
| `OTP_NO_RGTM` | 14 | Output not registered |
| `FLP_NO_SRST` | **13** | Flip-flop has **no set or reset at all** |
| `CAS_NR_DEFX` | 12 | Case without default |
| others | 23 | |

**The 154 async-reset findings are dispositioned with two comments, neither of which is
a rationale:**

- 84 x `why would we need an async reset`
- 70 x `we don't need async resets`

The lint tool raised the exact concern recorded in `DRV-HK-05` -- that a
synchronously reset register cannot be cleared without a clock -- 154 times, and
it was dismissed rather than answered. The answer, established in
`HK-OFFNOM-04` and [`HK-F-17`](#hk-f-17), is that if the 50 MHz reference stops
the enables hold their last value, latchup detection freezes, and nothing on
orbit can assert `arstn` to recover it.

**The 13 registers with no reset whatsoever are more concerning than the 154.**
All but three sit in one unreset `always_ff` block at
`src/health_monitor.sv:663`:

| Register | Role |
| --- | --- |
| `ddr8_start_boot`, `ddr16_start_boot`, `fpga_start_boot`, `lvds_start_boot` | **The inter-region boot chain sequencing signals** |
| `eth1_ctrl_r1`, `eth2_ctrl_r1`, `imx_ctrl_r1`, `lvdt_ctrl_r1`, `stepper_pri_ctrl_r1`, `stepper_sec_ctrl_r1` | Previous-value registers for rising-edge detection on the software control lines |

These power up in an indeterminate state. Two consequences follow:

- A `*_start_boot` register powering up asserted could present a spurious boot
  request to a region.
- A `*_ctrl_r1` register powering up at 0 while its control input is already 1
  synthesises a false rising edge, which is the exact condition
  `HK-SEQ-05` uses to start a software-controlled region.

Both are in practice masked, but **by accident rather than by design**: the
region state machines are themselves held in reset, and `reset_synchronizer`
holds `rstn` asserted for four clock cycles
(`src/health_monitor_io.sv:326-328`), by which time these registers have been
clocked to their intended values. That mitigation depends on the clock running
-- the one condition under which it is most needed. The comment, "No
issue with no set/reset," asserts the conclusion without showing this.

**Measured.** `verification/tests/test_hk_clk.py` boots the device, stops the
clock, and asserts `arstn` between edges: all 32 outputs that were away from
their reset state stay there for as long as the clock is stopped, and reach
it within a few clocks of it restarting. `HK-CLK-03` and `HK-CLK-04` are `GAP`
on this -- the reset *input* is asynchronous, and nothing it resets is. Register
by register (`verification/tests/test_hk_drv_reset.py`): of 469 register
instances, 243 moved in a boot, and with the clock stopped reset returned one
of them -- the synchroniser's own.

**Consequence.** Two distinct problems. First, the specific one: unreset
sequencing registers in a Class A power sequencer, protected only incidentally.
Second, the systemic one: a 230-entry disposition record governed by no
requirement,
in which the single largest category was cleared with a rhetorical question. A
disposition is a decision record; "why would we need an async reset" records that
the question was asked and not answered.

**Recommended disposition.** Three actions, and they are separable:

1. Reset the 13 unreset registers explicitly. Cheap, and removes an accidental
   dependency on reset duration. `DRV-HK-05` now requires this: it applies to
   every register, so a register with no reset is neither compliant nor an
   approved exception.
2. Re-adjudicate the 154 `FLP_NO_ASRT` entries against `DRV-HK-05`. Because that
   requirement now covers every register rather than the power-related ones, an
   entry is cleared only by converting the register to asynchronous reset or by
   recording it as an approved exception with a rationale that addresses clock
   loss. The count is a symptom: the tool asked the right question 154 times.
3. Bring the record under clause 2 of the [FPGA Build and Disposition
   Plan](../../../docs/plans/fpga-build-and-disposition-plan.md), so that every entry carries a
   rationale and a named owner, and so that a new warning cannot inherit a
   previous build's approval.

**Needs a named owner.**

---

## HK-F-19

**Six clock domains carry two alternative oscillator parts; no stability budget
is stated anywhere.**

**Severity:** MEDIUM

**Actual.** Every clock domain on the avionics board is driven by **two
different oscillator part numbers connected to the same net**, each through a
33 ohm series resistor:

| Net / function | Part A | Part B |
| --- | --- | --- |
| `ASIC_50MHZ_CLOCK` -- **housekeeper** | `Y10` ECS-3225MVQ-500-BP-TR | `Y6` X35T-L7M-50.000MHZ |
| 50 MHz -- **PolarFire** (`FPGA BANK4`) | `Y7` ECS-3225MVQ-500-BP-TR | `Y3` X35T-L7M-50.000MHZ |
| ETH1 50 MHz | `Y4` ECS-3225MVQ-500-BP-TR | `Y1` X35T-L7M-50.000MHZ |
| ETH2 50 MHz | `Y5` ECS-3225MVQ-500-BP-TR | `Y2` X35T-L7M-50.000MHZ |
| 100 MHz -- XCVR0/1 | `Y11` XLL536100.000000I | `Y12` XD35T-L7M-100.000MHZ |
| 148.5 MHz -- XCVR4/5 | `Y9` XLL536148.500000I | `Y8` XD35T-L7M-148.500MHZ |

Two push-pull CMOS outputs driving one node would contend; through 33 ohm each
they would settle near mid-rail, which the receiving input reads as
indeterminate. The consistency of the pattern across all six domains indicates
this is a deliberate **second-source or stuff option** -- populate one part or
the other -- rather than redundancy. The JSON export carries no fitted/DNP
field, so this must be confirmed against the PDF schematic.

**Consequence.** Three distinct issues, in increasing order of importance:

1. **No stability specification is recorded anywhere.** Neither requirement set
   states initial tolerance, temperature stability or aging for any clock. Every
   timing requirement in both FPGAs is therefore stated against a nominal
   frequency with no error budget. See `DRV-HK-06` and `DRV-PF-04`.

2. **The two alternatives may not have equal stability.** They are different
   manufacturers and different part families. If one is specified to a tighter
   stability than the other, the timing budget differs depending on which is
   fitted -- so two units built from the same drawing can behave differently.
   Either the budget must be taken against the worse of the pair, or the two
   parts must be constrained to a common specification.

3. **There is no clock redundancy.** If this is a stuff option, each domain has
   a single point of failure. For the housekeeper that compounds
   [`HK-F-17`](#hk-f-17): the clock is a single point of failure feeding a
   Class A function, the enables freeze on clock loss, and no on-orbit reset
   path exists to recover it.

**Where it actually bites.** For the housekeeper, drift is not the dominant
error term -- the UART divisor already contributes +0.47 % against nominal
115200, against a typical oscillator drift of order +/-0.01 %. The intervals are
otherwise self-referential and have wide margins. For the **PolarFire it is the
dominant term**: the local PPS generator divides the oscillator by exactly
50,000,000, so its 1 Hz accuracy equals the oscillator's accuracy one for one,
and at +/-100 ppm that is +/-0.5 s per orbit free-running.

**Datasheets read, 2026-10-01.** For the housekeeper's pair: `Y6`
X35T-L7M is +/-75 ppm overall, including initial tolerance, temperature,
supply, load and five years' ageing; `Y10` ECS-3225MVQ-500-BP is +/-50 ppm
over temperature plus 3 ppm a year, so +/-65 ppm at five years and +/-80 ppm
at ten. Neither moves any housekeeper interval by more than 0.01 %, so for
the housekeeper the UART divisor still dominates. The worse of the two
depends on the mission life, which is the number still missing.

**Recommended disposition.** Confirm the stuff option against the PDF
schematic. Record the stability specification of both alternatives, take the
budget against the worse, and state the resulting tolerance on every derived
timing requirement. If clock redundancy was intended rather than second
sourcing, the arrangement does not provide it and needs rework.

---

## HK-F-20

**TMR coverage is unverified, and the UART core is likely excluded.**

**Severity:** LOW -- *was MEDIUM. Gaps 1 and 2 below are closed by inspecting
the flight build (2026-10-02); gap 3 and the common-mode clock remain.*

**Update, 2026-10-02.** The synthesised netlist of the flight build
(`fm_tmr`, commit `b67f8ad`) was inspected (`test/inspect/build.py`,
`HK-IMPL-02`): every one of its 6,519 flip-flops is one of three whose outputs
meet at one `MAJ3` majority voter, found from the netlist's structure rather
than from instance names. The CoreUART is synthesised from RTL, not consumed
as a black box, and its 138 flip-flops are triplicated with the rest -- gap 1
does not exist. Triplication is verified directly, which is stronger than the
register-count comparison proposed in gap 2. `HK-IMPL-02` is `OK`. Gap 3,
whether the voters refresh the replicas, is not settled by the structure
alone and stays with `HK-IMPL-10`.

**Claimed.** TMR is the only mitigation the housekeeper carries against
flip-flop upset, via `HK-IMPL-02` and `HK-IMPL-10`. It has no parent requirement
-- see [`HK-F-23`](#hk-f-23). FAR-L1REQ-49 was previously cited here, but it covers
*destructive* SEE, which is what the glitch filters and power-down FDIR address;
it does not cover the non-destructive upset that TMR mitigates.

**Actual.** The design contains exactly one radiation-hardening attribute:
`syn_radhardlevel="tmr"` on `module top` (`src/top.sv:143`), enabled by
`` `define TMR `` in the generated `src/build_variant.vh`, included at
`src/top.sv:20`. No submodule overrides it, so it nominally
propagates across the whole hierarchy.

Three gaps follow.

**1. The CoreUART is probably not covered.** `UART0` is
`Actel:DirectCore:COREUART:5.7.100`, instantiated from the block design
(`bd/a3pe3000l-fg484m/components/UART0.tcl`) rather than from `src/`. DirectCore
IP is typically delivered as a netlist or as encrypted RTL; in either case
Synplify treats it as a black box and a module-level attribute on `top` does not
reach inside it.

That matters more than it first appears. The CoreUART is the transmitter for
the failure status beacon -- the mechanism of `HK-UART-04` through
`HK-UART-08`, and the payload's only remaining voice after a critical fault has
powered the PolarFire down. It is the one block that must keep working when
everything else has failed, and it is plausibly the one block without upset
mitigation.

**2. Nobody has verified that triplication occurred.** `syn_radhardlevel` is an
attribute, not a guarantee. It can be silently ineffective -- wrong scope, an
inference the tool does not support, or downstream optimisation -- and no stage
of the flow fails if it is. No synthesis report is retained
(clause 1 of the [FPGA Build and Disposition Plan](../../../docs/plans/fpga-build-and-disposition-plan.md)),
so there is no evidence either way. The check is cheap: the
`fm_tmr` build should show roughly three times the register count of the `fm`
build across 44 state machines and 51 glitch filters.

**3. Voter refresh is unconfirmed.** If the voted value is not fed back into
the replicas, the first upset leaves one replica permanently diverged. The
output stays correct but the redundancy is spent, and a second upset in either
survivor produces a wrong result. Whether Synplify's TMR for this device
refreshes or only masks has not been established.

**What TMR does not cover in any case.** The clock network, the I/O pads and
the `arstn` input are not triplicated. `ASIC_50MHZ_CLOCK` is therefore
common-mode to all three replicas -- an upset or failure there defeats the
redundancy entirely, which compounds [`HK-F-19`](#hk-f-19) (single-sourced
clock) and [`HK-F-17`](#hk-f-17) (no on-orbit reset).

**Recommended disposition.** Three separable actions:

1. Determine whether CoreUART is synthesised as RTL or consumed as a netlist.
   If it is a black box, decide whether the beacon path needs mitigation -- a
   TMR'd replacement, or an accepted risk with rationale.
2. Retain the synthesis report and compare `fm_tmr` against `fm` register
   counts. This is the verification method of `HK-IMPL-02`, which is marked
   **GAP** until the comparison is performed.
3. Confirm the voter topology and verify by fault injection rather than by
   reading the attribute. Opened as `HK-IMPL-10`.

## Disposition gate

The following cannot be resolved by rewording a requirement. Each is a genuine
conflict between what the requirements ask for and what the design does, and
each needs a named owner and one of: change the design, formally withdraw the
requirement, or accept the gap with written rationale.

| ID | Subject | Owner |
| --- | --- | --- |
| HK-F-01 | Boot timeout unreachable; retry, boot-failure and critical shutdown paths all dead in the flight build | UNASSIGNED |
| HK-F-02 | DDR 0V6 enables unconnected; the housekeeper cannot control or remove the rail, and boot relies on a typical-only PGOOD delay | UNASSIGNED |
| HK-F-05 | Stepper interlock does not satisfy FAR-PM_FPGA_L4REQ-24's "never" | UNASSIGNED |
| HK-F-13 | FAR-AB_L2REQ-1 allocated to hardware that cannot implement it | UNASSIGNED |
| HK-F-15 | Unfiltered control inputs; a transient can energise a stepper drive | UNASSIGNED |
| HK-F-16 | Reset release and synchroniser inputs unconstrained; behaviour varies build to build | UNASSIGNED |
| HK-F-17 | No on-orbit reset path; clock loss and latched faults recoverable only by bus power cycle | UNASSIGNED |
| HK-F-18 | 154 async-reset entries without rationale; 13 unreset sequencing registers | UNASSIGNED |
| HK-F-21 | ICD calls the RS-422 link configurable; housekeeper rate is fixed, shared lane | UNASSIGNED |
| HK-F-22 | Four indistinguishable bitstreams; two unsafe to fly | UNASSIGNED |
| HK-F-23 | No SEU requirement in the baseline; TMR adequacy cannot be assessed | UNASSIGNED |
| HK-F-24 | PA3/PolarFire discrete interface: contention, undriven net, and three misread signals | UNASSIGNED |
| HK-F-25 | Three unpulled health indications can float to "healthy" before configuration | UNASSIGNED |
| HK-F-26 | No bound on latchup response, power-down, boot, status latency, utilisation or timing closure | UNASSIGNED |

HK-F-07's net-direction observation has been resolved against the repaired
schematic export and is carried by HK-F-24.

The remaining findings are correctable by rewording the requirement, correcting
the design documentation, or making a small RTL change with no capability
impact.

## HK-F-21

**The housekeeper cannot transmit at the rate the ICD says the link uses.**

**Expected.** CM-01979 section 17.1.1 specifies the RS-422 link as 115200 baud,
8 data bits, no parity, one stop bit, and describes the rate as "default, but
configurable".

**Actual.** The housekeeper UART is fixed at 115,740.74 baud. `BAUD_VAL` is 26 at
`src/uart_ctrl.sv:65`, giving 50 MHz / ((26 + 1) x 16). There is no
configuration path -- no register, no input, no parameter exposed above `top`.

**Why it matters.** The rate error alone is harmless: +0.47% against nominal
115200, well inside the usual +/-2% UART tolerance. The word "configurable" is
the problem.

CM-01979 section 15.6.1 states that on a critical failure the ProASIC3 "takes
over the RS-422 lane" and broadcasts the 14-byte failure frame. The PolarFire
and the housekeeper therefore drive the same physical link, and only one of them
can change rate. If an integrator exercises the documented configurability and
moves the link to, say, 9600 or 230400 baud, the PolarFire follows and the
housekeeper does not. The failure broadcast then arrives at a rate the host is
no longer listening at -- and it arrives precisely when the PolarFire is down
and that frame is the only remaining evidence of what failed.

This is a fault-path failure that normal operation will never expose. The link
works at every rate until the moment it is needed.

**Disposition.** Needs an owner decision. Either the ICD drops the
configurability claim and fixes the rate at 115,200 baud with a stated
tolerance, or the housekeeper gains a configuration path and the two FPGAs are
kept in step. `HK-UART-05` now states 115,200 baud +/-2 %, which the realised
115,740.74 baud meets, so the rate itself is settled; it is the
configurability claim and the shared-lane behaviour that need reconciling.

## HK-F-22

**Four different bitstreams are indistinguishable from each other, and two of
them are unsafe to fly.**

**Expected.** A programming file should identify what it is. Given a `.pdb`, it
should be possible to say which board it targets and whether radiation
mitigation is enabled.

**Actual.** `make` produces four images from one source tree -- `fm_tmr`, `fm`,
`em_tmr`, `em` -- and all four are built and filed under
`programming_files/`. Nothing in an image identifies which one it is:

| Discriminator | Result |
| --- | --- |
| Filename | `farsight_hk_a3pe3000l-fg484m_<timestamp>_b049e8.pdb` for all four; only the build timestamp differs |
| Embedded commit id | `b049e8` for all four |
| `fw_version` telemetry | `3'd2` whenever the rails are up, in every variant; bits 0 and 2 are not bonded out |
| Parent directory | the only discriminator |

**Why the commit id cannot help.** The variants are not selected by a committed
source difference. The `Makefile` edits `src/top.sv` to comment out
`` `define TMR ``, and rewrites the RS-422 pin assignments in
`constr/a3pe3000l-fg484m/io/fm/io_constraints.pdc`, backing both up to `.mkbak/`
and restoring them after the build. `synth.tcl:70` takes the commit id from
`git rev-parse HEAD`, which reflects the committed tree and not the patched one.

Three of the four images therefore carry a commit id that points at source which
does not produce them. The identifier is not merely uninformative -- it is
wrong, and it is wrong in the direction that inspires confidence. There is also
no dirty-tree check, so an image built from locally modified source records a
clean commit id.

**Why it matters.** Two of the four variants must never reach the flight board,
and neither failure is observable:

- An `em` image swaps the RS-422 transmit and receive pins. The payload command
  link is dead, and the housekeeper failure broadcast goes out of the wrong pin
  -- the one diagnostic that exists when the PolarFire is down. See
  [`HK-F-21`](#hk-f-21).
- A `no-tmr` image removes triple modular redundancy from a Class A part. The
  design behaves correctly on the bench and degrades only under radiation.

The safeguard is the directory a file happens to sit in, which is the first
thing lost when a file is copied out, emailed, or attached to a release record.

**Disposition: FIXED for the file. NOT POSSIBLE for the device.**

The variants are real configurations now, so nothing patches the tree and the
commit id describes the source that built the image. The pinout comes from
`constr/<board>/io/<fm|em>/`, both committed; TMR from a generated
`src/build_variant.vh`. The build refuses a modified tree, the commit id is
twelve characters rather than six, the variant is in the filename, and a
manifest is written beside each image carrying the variant, commit, tree state,
tool version, constraints used and a SHA-256 of the image.

All four variants were built from one commit, `2afb32cc804e`, which was itself
impossible before:

| variant | core cells | image bytes | RS-422 in / out |
| --- | ---: | ---: | --- |
| `fm_tmr` | 14,681 | 523,915 | Y6 / AA15 |
| `fm` | 7,772 | 410,281 | Y6 / AA15 |
| `em_tmr` | 14,681 | 524,036 | AA15 / Y6 |
| `em` | 7,772 | 414,716 | AA15 / Y6 |

TMR is applied: 1.889x the core cells, taken from the synthesis report rather
than inferred. The pinout swap reaches the placed design. The two `_tmr`
variants have identical cell counts, which is what a pinout change should do to
logic -- nothing.

**A correction worth recording.** The acceptance check first proposed for this
was the programming file size, on the basis that the historic `fm_tmr` was
1.384x `fm`. Measured from one commit it is **1.277x**, because the `.pdb`
carries a fixed overhead that dilutes the ratio. That check would have reported
a failure where there was none. Core cell count is the measure; file size is
not.

Identifying the variant from the running device would be stronger than
identifying the file, and **is not available in this toolchain**. The ProASIC3
silicon signature -- the obvious place for it -- has no Tcl surface in Libero
11.9: `CONFIGURE_PROG_OPTIONS`, which carries `silicon_signature`, is
SmartFusion2 and IGLOO2 only; the ProASIC3 programming commands
(`GENERATEPROGRAMMINGDATA`, `EXPORTPROGRAMMINGFILE`) take no parameters; and the
FlashPro user guide has the signature as a field in an interactive wizard. The
only remaining route is `fw_version`, a single bonded wire per
[`HK-F-10`](#hk-f-10) on a contended net per [`HK-F-24`](#hk-f-24). The ICD
compounds this: `GET_VERSION` promises the host a "ProASIC3 FPGA version" word
that the hardware cannot supply. Tracked as `HK-IMPL-18`.

## HK-F-23

**Nothing in the system baseline requires tolerance to single-event upsets.**

**Severity:** MEDIUM

**Expected.** A payload carrying triple modular redundancy across its entire
sequencing hierarchy should be able to point at the requirement that TMR
satisfies, and at the numbers that size it -- an expected upset rate, an
acceptable rate of upset-induced failures, and a mission duration.

**Actual.** The corrected system baseline contains exactly two radiation
requirements:

| | Statement | Disposition |
| --- | --- | --- |
| FAR-L1REQ-50 | TID tolerance >= 30 krad | UNADJUDICATED |
| FAR-L1REQ-49 | Tolerance to **destructive** Single Event Effects at >= 37 MeV.cm^2/mg | UNADJUDICATED |

Neither covers non-destructive upset of a flip-flop. FAR-L1REQ-50 is a total-dose
lifetime requirement. FAR-L1REQ-49 is about latchup and burnout -- events that destroy or
latch a part -- which in this design is what the 5 us glitch filters, the
latchup declaration and the power-down FDIR address, not what TMR addresses.

The result is that the housekeeper carries TMR across 44 state machines, 51
glitch filters and the whole power sequencing chain, at roughly three times the
sequential logic, against a hazard no requirement states. `HK-IMPL-02` and
`HK-IMPL-10` are both classified derived with no parent, and that is the
classifier reporting the hole rather than a defect in how they were written.

**Why it matters.** Without an allocated upset rate there is no way to answer
whether TMR is sufficient, insufficient, or more than is needed:

- Nothing sizes the mitigation. Whether masking alone is acceptable, or
  continuous refresh is required, depends on the expected upset rate over the
  mission -- exactly the number that does not exist. `HK-IMPL-10` cannot be
  closed on engineering grounds until it does.
- Nothing bounds what may be left unprotected. `HK-F-20` records that CoreUART
  is probably outside the TMR boundary and that the clock network is common-mode
  to all three replicas. Whether those exclusions are acceptable is an
  arithmetic question against a rate nobody has stated.
- The cost is already being paid. Roughly 3x the sequential logic is committed
  to a mitigation whose adequacy cannot be assessed.

**Disposition.** Allocate an SEU requirement to the avionics board: expected
upset rate for the orbit and shielding, acceptable upset-induced failure rate,
and mission duration. This joins FAR-L1REQ-50, FAR-L1REQ-49, FAR-TM_L2REQ-3, FAR-L1REQ-46 and FAR-L1REQ-47 in the set of
environment requirements with no allocation, recorded as `HW-F-07` and as
[`Q-04`](../../../docs/requirements/open-questions.md). Until it exists, TMR is
an engineering judgement rather than a verified mitigation, and `HK-IMPL-02` and
`HK-IMPL-10` have no parent to trace to.

## HK-F-24

**The two FPGAs disagree about the PA3/PolarFire discrete interface: one net has
two drivers, one has none, and three carry something other than what the
PolarFire reads.**

**Severity:** **HIGH**

Found by comparing the declared direction of every pin at both ends of every net
joining the two FPGAs. This became possible only once the schematic export was
repaired (v2.2.1); the earlier export was missing 10 of the PolarFire's 14
parts, which is exactly where these nets land.

**1. Contention -- two outputs on one net.**

| End | Pin | Signal | Direction |
| --- | --- | --- | --- |
| ProASIC3 | `AB8` | `fw_version[1]` | OUTPUT, 8 mA drive |
| PolarFire | `AC2` | `lvds_pwr_en` | OUTPUT |

Both drive net `PF_TO_PA3_MISC0`, joined through R898 (33 ohm). Two CMOS outputs
in opposition are current-limited only by that resistor. Evidence:
`io_constraints.pdc:176`, `farsight-fpga/constr/common/pins.tcl:73`.

The two designs also disagree about what the wire is *for*. The housekeeper
drives a firmware version bit; the PolarFire drives an LVDS power enable. The
housekeeper has no `lvds_ctrl` input at all -- LVDS is not in its
software-controlled region list -- so the PolarFire's LVDS enable has no
recipient, and the collision is the only thing it achieves.

**2. No driver -- two inputs on one net.**

| End | Pin | Signal | Direction |
| --- | --- | --- | --- |
| ProASIC3 | `AA3` | `lvdt_ctrl` | INPUT |
| PolarFire | `K5` | `lvdt_pwr_en` | **INPUT** |

Nothing drives net `PA3_TO_PF_MISC16`. The housekeeper's internal pull-down
(`io_constraints.pdc:169`) holds `lvdt_ctrl` low permanently, so **the LVDT
power region can never be commanded on**. The LVDT is the focus mechanism's
position sensor.

`lvdt_pwr_en` is the only INPUT among the seven power enables declared under the
"PF to PA3 Power Enable" heading at `pins.tcl:72-78`; `lvds_pwr_en`,
`eth1_pwr_en`, `eth2_pwr_en`, `stepper_pri_pwr_en`, `stepper_sec_pwr_en` and
`cam_pwr_en` are all OUTPUT. A one-word constraint error is the most likely
cause, which would make this the cheapest of the three to fix.

**3. Semantic mismatch -- the PolarFire reads three pins as something else.**

| PolarFire input | PF pin | PA3 pin | What the PA3 actually drives |
| --- | --- | --- | --- |
| `pa3_fw_version[0]` | `E5` | `W7` | `ddr8_failure_metadata[0]` |
| `pa3_fw_version[1]` | `C1` | `AB10` | `ddr8_failure_metadata[1]` |
| `pa3_fw_version[2]` | `B1` | `AA10` | `ddr16_failure_metadata[0]` |

The PolarFire believes it is reading a three-bit housekeeper firmware version.
It is reading DDR failure metadata. Any version check the PolarFire performs is
reading fault status, and any fault status the housekeeper reports is being
consumed as a version number. Evidence: `io_constraints.pdc:63-65`,
`pins.tcl:96-98`.

**Why all three went unnoticed.** Each design is internally consistent; the
defect exists only in the relationship between them, and nothing checked that
relationship. Simulation cannot: each testbench drives its own FPGA's inputs
with whatever the testbench author believed the other side sends. The
`gen_trace_matrix.py` `DRIVE` check now compares the declared direction at both
ends of every shared net and fails on contention or on no driver.

**Related.** [`HK-F-10`](#hk-f-10) records that `fw_version` is a single bonded
wire conveying no version. This is worse than that finding assumed: the one
bonded bit is also in contention with a PolarFire output.

**Disposition.** Needs a joint housekeeper/PolarFire decision, and an agreed
interface definition for the discrete bus -- there is currently none, which is
the root cause. Cheapest first:

1. Correct `lvdt_pwr_en` to OUTPUT in `pins.tcl` if the intent is that the
   PolarFire commands the LVDT region, and confirm against the schematic.
2. Resolve `PF_TO_PA3_MISC0`: decide whether it carries `fw_version[1]` or
   `lvds_pwr_en`, and make the other end match. Until then one FPGA must
   tri-state it. Neither signal does anything today -- the housekeeper has no
   use for an LVDS enable, and `fw_version[1]` carries no version
   ([`HK-F-10`](#hk-f-10)) -- so a third option is open: make `AB8` a
   housekeeper input with `RES_PULL "DOWN"`, and have the PolarFire drive its
   `DEVICE_INIT_DONE` (from `PF_INIT_MONITOR`, today used only inside its reset
   tree) on `AC2`. That removes the contention and gives the housekeeper the
   one thing it cannot know now, that the PolarFire has finished configuring,
   with no board change. The pull-down is needed: unlike `MISC1`-`4` this net
   has no external one, and PolarFire I/O are not driven until it has
   configured. No other line between the two FPGAs is free for this: every
   `PA3_TO_PF_MISC` carries metadata or the LVDT control, and the spare banks
   on each device (`B4_GPIO_SPARE0`-`7`, `ASIC_B1_GPIO_SPARE0`-`7`) are not
   connected to each other.
3. Reconcile `pa3_fw_version[2:0]` against `*_failure_metadata`. Decide which
   the three pins carry and correct the other design.
4. Record the agreed discrete interface in CM-01979, so that this class of
   disagreement is caught by review rather than by netlist archaeology.


## HK-F-25

**Three health indications to the PolarFire have no pull resistor, so before the
housekeeper is configured they can report healthy.**

**Severity:** MEDIUM

**Claimed.** `HK-IO-09` requires every output to be held in its inactive state
from the moment the I/O ring is powered until the design drives it.

**Actual.** Twelve outputs report region health to the PolarFire. Nine carry
`RES_PULL "DOWN"`. Three carry `"NONE"`:

| Output | Driven by | Meaning of 1 | Pull |
| --- | --- | --- | --- |
| `imx_status_to_pf` and 8 others | `*_boot_succeeded` | region booted | `DOWN` |
| `pf_status_to_pf` | `fpga_boot_succeeded` (`src/health_monitor_io.sv:320`) | FPGA region booted | **`NONE`** |
| `step_down_status_to_pf` | `step_down_boot_succeeded` (`:321`) | step-down chain booted | **`NONE`** |
| `pa3_status_to_pf` | constant `'1'` (`:322`) | housekeeper alive | **`NONE`** |

All three are active high, so the state they can float to is the state that
means *healthy*. There is a window between the I/O ring powering and the
housekeeper's configuration completing in which nothing drives these pins.

`pa3_status_to_pf` is the worst of the three because it is the housekeeper's own
liveness signal, tied to a constant. Its entire purpose is to distinguish "the
housekeeper is running" from "the housekeeper is not", and an unpulled pin
cannot make that distinction in the one case where the answer is "not".

**Consequence.** The PolarFire may sample a health indication as good before the
housekeeper has executed any sequencing. Whether that is exploitable depends on
when the PolarFire first reads these pins relative to housekeeper configuration,
which is not stated anywhere: no requirement gives the housekeeper a time budget
to reach a defined state, and `HK-SEQ-01` starts its 1 s wait from reset release,
which is already after configuration.

The three are not a different engineering decision from the nine. Nothing
distinguishes them functionally, they sit in the same constraint file, and they
carry the same polarity and the same meaning. This is an omission.

**Disposition.** Add `RES_PULL "DOWN"` to the three outputs, which makes them
consistent with the other nine and costs nothing. Then, separately, establish
when the PolarFire first samples housekeeper status relative to housekeeper
configuration -- the pull makes the pin defined, but only a timing statement
makes the reading meaningful.


## HK-F-26

**The housekeeper's requirement set constrains what happens and in what order,
but almost never how fast. Four system requirements say "immediately".**

**Severity:** MEDIUM

**Expected.** A power sequencer is a real-time function. Its protective actions
are worth only as much as their latency, and the subsystems around it need to
know how long to wait before concluding it has failed.

**Actual.** Of 100 housekeeper requirements, 13 carried a quantity before this
finding was raised, and those 13 are almost entirely intervals the design
generates -- the 1 s boot wait, the 1 s heartbeat, the 25 ms source timeout, the
200 ms retry hold. The *response* times are absent:

| Behaviour | Stated | Bound |
| --- | --- | --- |
| Latchup declared to enable deasserted | `HK-LAT-01`, `HK-LAT-03`, `HK-REG-09` | **none** |
| Power-down request to all enables off | `HK-PDN-02`, `HK-PDN-04` | **none** |
| Reset release to boot chain complete | `HK-SEQ-08` | **none** |
| Status change to status output | `HK-TLM-01`, `HK-TLM-09` | **none** |
| Supply valid to enables deasserted | `HK-OFFNOM-01` | **none** |

Four of the Jama parents state the obligation as "immediately"
(`FAR-PM_FPGA_L4REQ-12`, `-14`, `-17`, `-18`). No test can pass or fail
"immediately", so each of those requirements is currently unverifiable at the
level that matters, while appearing to be satisfied because the *sequence* is
correct.

Two build-quality bounds are also absent: nothing states that the design fits
the device with margin, though `HK-IMPL-02` triples the sequential logic, and
nothing requires static timing closure at 50 MHz.

**Consequence.** Latchup response is the one that matters most. Protection exists
to remove power before a part is damaged, so a response that is correct in
sequence but arbitrarily slow protects nothing. The realised path -- a 5 us
filter plus a few clock cycles -- is almost certainly adequate, which is the
danger: it is adequate by construction rather than by requirement, so a later
change to the filter width or an added pipeline stage would breach nothing.

The boot bound is the one most likely to cause an operational surprise. The
worst case is 5.80 s and is derivable from requirements already written, but it
is written down nowhere, so any observer waiting on the payload has to invent its
own timeout.

**Disposition.** Seven requirements have been raised: `HK-LAT-08`, `HK-PDN-07`
(since withdrawn), `HK-SEQ-10`, `HK-TLM-10`, `HK-OFFNOM-08`, `HK-IMPL-20` and
`HK-CLK-06`. Five
carry a TBR value that cannot be set from the FPGA design -- they follow from
device safe operating area, board hold-up energy, the device power-up
specification, and a programmatic margin policy. Each is registered in
[`tbr-register.md`](../../../docs/requirements/tbr-register.md) with an owner
field. The requirements are raised now, ahead of the values, so that the
verification framework is built against the right obligations and the numbers
land in a slot that already exists.

**Values proposed on 2026-09-29, answered on 2026-10-01.** Values were
proposed to systems for four of them, and the requirements carry them:
`HK-LAT-08` 10 us from the fault at the pin, `HK-SEQ-10` 6 s, `HK-TLM-10` 1 us,
and `HK-IMPL-20` 80 % CBE per resource class at CDR. The same 10 us was
proposed for "immediately" in the fourth parent, FAR-PM_FPGA_L4REQ-18, and
added to `HK-REG-05`. The first three are tested and met -- 5.13 us, 3.175 s
for the slowest boot the board model produces, 0.04 us. Avionics hardware
(Dhruv) answered:

| Requirement | Answer |
| --- | --- |
| `HK-LAT-08` | **Confirmed** for FAR-PM_FPGA_L4REQ-14, with a proposed rewording that measures from the nFAULT falling edge, filter included. L4REQ-12 and -17 not addressed |
| `HK-TLM-10` | **Confirmed**, 1 us |
| `HK-PDN-07` | **Withdrawn**: no hold-up budget exists, a controlled shutdown on eFuse loss is not feasible on this board, and an uncontrolled one does no harm |
| `HK-SEQ-10` | Referred to flight software, whose interface it is |
| `HK-REG-05` | Not addressed |
| `HK-IMPL-20` | Not addressed |

Of the four "immediately" parents, only L4REQ-14 now has a number.
`HK-OFFNOM-08` remains TBR: its value cannot come from the FPGA side.


## HK-F-27

**Three regions report on a single bit, so their fault condition cannot be read
at the pins; a failed LVDS region is indistinguishable from one still booting.**

**Severity:** MEDIUM

**Claimed.** `HK-REG-01`: each region shall be independently observable, "such
that its boot outcome and its fault condition can be determined without
reference to any other region". Its rationale names the reader: per-region
granularity is "what lets the PolarFire be told which region failed".

**Actual.** What the PolarFire receives from a region is that region's share of
the outputs driven towards it. Three regions have one bit each:

| Region | Outputs towards the PolarFire | Width | In `debug[2:0]` |
| --- | --- | ---: | --- |
| Step Down | `step_down_status_to_pf` | 1 | latchup 1, boot failure 5 |
| FPGA | `pf_status_to_pf` | 1 | latchup 4, boot failure 6 |
| LVDS | `lvds_status_to_pf` | 1 | **none** |
| every other region | status plus `*_failure_metadata` | 2-4 | DDR8 and DDR16 only |

One bit cannot separate booted, booting, failed and latched. The status output
is 1 for the first and 0 for the other three
(`src/health_monitor_io.sv:311-321`), so a 0 says only "not booted".

Measured, not inferred. `verification/tests/test_hk_reg_observable.py` holds
the LVDS rail out of regulation and reads LVDS's outputs twice with the FPGA
region booted: 5 ms into the first attempt, and after the region has made its
four attempts and been declared failed (`HK-REG-06`). Both readings are
`lvds_status_to_pf = 0`, and `debug[2:0]` is 0 both times.

`debug[2:0]` does not close the gap for the other two. It is shared by every
region, holds only the first failure the device saw, and is on debug pins
rather than the PolarFire interface. A step-down or FPGA failure also takes
everything else down -- a boot failure through the staged power-down
(`src/health_monitor.sv:703-704`), a latchup through the global latch
(`:722-723`) -- so for those two the consequence is visible even if the cause
is not. So is an LVDS latchup, which trips the same global latch. An LVDS
**boot failure** begins nothing: the rest of the payload carries on and the
only record is a status bit that never rose.

**Not counted.** Every status output is forced low until the FPGA region has
booted, so a 0 on its face needs another region's state to interpret. That is
not part of this finding: the only reader is the PolarFire, which is powered
only once the FPGA region has booted, so the reader always knows the one fact
the gating depends on. `HK-OFFNOM-02` requires the gating regardless.

**Consequence.** The PolarFire can tell that LVDS has not booted, but not
whether it failed or is still booting. To conclude that it failed,
it has to wait out a timeout of its own, and none is stated: the boot bound is
`HK-SEQ-10`, whose value is TBR (`HK-F-26`). The same ambiguity between failed
and latched applies to step-down and FPGA, where the power-down that follows
also removes the PolarFire's supply.

**Disposition.** Either give LVDS a failure output as the software regions
have -- one bit distinguishing boot failure from latchup, qualified by the
status bit, which is the encoding `HK-TLM-03` already uses -- and extend
`HK-TLM-03` to the hardware regions; or narrow `HK-REG-01` to what the
PolarFire can actually use, and record that a hardware region's failure is
reported by the power-down that follows it rather than by the region. The
second is not available for LVDS, whose failure is followed by nothing.
`HK-REG-01` is `GAP` until one of the two is decided.

**Proposed resolution, pending systems confirmation.** A third way, needing no
design change, was proposed to systems on 2026-09-29: the PolarFire treats a
single-bit region whose status is still low 1 s after the region starts as
failed. It is sound for LVDS -- a dead LVDS makes its last attempt 698.6 ms
after the FPGA region boots and none after, and a healthy one reports booted
in 3 ms (`verification/tests/test_hk_reg_observable.py`) -- and it puts an
obligation on the PolarFire firmware. `HK-REG-01` is reworded to it and is
`OK` on that basis; if systems answers differently, one of the two options
above is still needed. On 2026-10-01 avionics hardware called it "probably
acceptable"; because it binds the PolarFire firmware, it waits for that
owner.

**`HK-SRC-01` is the same question one level down, and there it has no
answer as written.** Its item asks that each *source's* boot outcome and
fault condition be readable "from outputs that no other source drives". At
the pins the only per-source outputs are the 33 enables; status bits, failure
metadata, `debug` and the UART beacon are each shared by several sources, and
meeting the criterion literally would take a dedicated fault pin per source.
It was recorded `AMBIG` for that reason. It is now reworded to the answer
proposed to systems on 2026-09-29 and confirmed on 2026-10-01: per-source
failure identity only in the software-controlled regions, which their
metadata already encodes. A failed hardware-controlled region leaves the
PolarFire off, so it has no use for the detail. It is `GAP` on the same code-0 defect as `HK-TLM-03`
([`HK-F-06`](#hk-f-06)).

**`HK-TLM-09` is the same gap at the status outputs.** It requires the
PolarFire to be able to determine "which components are enabled", and the
status outputs report *boot succeeded* -- enablement and health together. A
region powered and still booting, or retrying, reads 0 exactly as one that is
off. `verification/tests/test_hk_tlm_status.py` shows the pair: IMX off, and
IMX with all four supplies enabled and its last one attempting, give
identical readings of every region status output. The requirement's own note
recorded this and its status was nonetheless `OK`; it is `GAP` now.


## HK-F-28

**The power-down timeout is not restarted, so a source that has been up for
more than 2.294 ms is declared off on the next clock whatever its PGOOD, and
the staged shutdown collapses into about a microsecond.**

**Severity:** HIGH

**Claimed.** `HK-PDN-02`: each stage of a power-down begins only once every
source in the stage before it is off -- "its enable deasserted, and either its
PGOOD low or its power-down timeout elapsed". `HK-PDN-04`: within a region each
source begins only once the source after it is off, in the same sense.
`HK-SRC-11`: a source is off when its filtered PGOOD has gone low "or after at
least 2 ms, whichever occurs first" -- the fallback that exists so that a
stuck-high PGOOD cannot stall the shutdown.

**Actual.** A source leaves `POWERING_DOWN` on
`!pgood || cntr >= (PWR_DWN_WAIT_TIME >> CNTR_PRECISION)`
(`src/pwr_src_bootseq.sv:129`), 7 ticks = 2.294 ms. But the transition into
`POWERING_DOWN` from `BOOT_SUCCEEDED` does not clear the counter
(`:116-119`); only the transition to `LATCHUP` does (`:114`). So in
`POWERING_DOWN`, `cntr` is the time since the source *booted*, saturated at
127 ticks. For any source that has been up longer than 2.294 ms the condition
is already true, and the source is declared powered down on the next clock.
Its region then starts the next source, and the region after it, without
waiting for anything.

Measured in `verification/tests/test_hk_pdn_sequence.py`, with everything up
and the eFuse PGOOD dropped:

| | Observed |
| --- | --- |
| Each source after the one before it, in every region | under 0.1 us |
| Each hardware stage after the stage before it | 0.1 to 0.4 us |
| LVDS to the last step-down enable | about 1 us |
| Every FPGA, Ethernet and LVDS LT3065 source | powered down with its PGOOD **still high** |
| DDR8 and DDR16 1V2, relative to 0V6 | powered down with 0V6's PGOOD **still high** |
| Eth1/Eth2 3V3 to 2V5A -- booted under 2.294 ms before the request | 1.309 ms: these did wait |

The last row is the control, and it is what confirms the cause: the only
sources that waited were the ones whose counter had not yet reached 7 ticks
when the request came. Their 3V3 is an LT3065 whose PGOOD never falls, so they
waited for the counter to reach 2.294 ms from when they booted -- 1.309 ms
into the power-down, short of the 2 ms `HK-SRC-11` promises.

For the sources that are not LT3065s, the PGOOD the board model gives falls
in the same cycle as its enable, so the check is that each step comes no
sooner than the 5 us filter (`HK-IO-05`) after the previous PGOOD fell -- the
earliest the device could have known. The
DDR 0V6 rails need no such argument. They self-enable from 2V5
(`HK-F-02`), so their PGOOD stays high after `*_en_0v6` falls, and 1V2 went
down 0.1 us later: not waiting for PGOOD, and not waiting the 2.294 ms that
`HK-SRC-11` promises as the fallback either.

**Most sources have only the timeout.** 18 of the 33 sources are LT3065
LDOs. With EN low the LT3065's control circuitry shuts down and releases its
open-drain PGOOD, which the pull-up to `3V3_ASIC` then holds high (LT3065
datasheet, PWRGD; confirmed by avionics hardware, 2026-10-01). Their PGOOD
never falls on power-down, so the 2.294 ms timeout is not a fallback for them
but the only thing that can space their shutdown -- and it is the thing this
defect removes. The board model reproduces this since 2026-10-01; before
then it dropped every PGOOD with its enable, which made the defect look
narrower than it is.

**Consequence.** On the board, a regulator's PGOOD takes time to fall after
its enable is removed -- output capacitance has to discharge. With this
defect every stage of a power-down begins while the stage before it is still
energised, which is exactly what reverse-order sequencing exists to prevent:
a DDR or FPGA supply removed while a supply it depends on staying below is
still up. The whole shutdown takes about a microsecond, so there is no
ordering in practice at all, only in the sequence of enables.

This is also why nothing had noticed. The *order* of the enables is correct,
and a test that checked only the order -- or checked PGOOD at the pin, which
a model drops at once -- passes.

On 2026-10-01 avionics hardware said the board has too little hold-up for a
controlled shutdown on eFuse loss, and that board testing shows no supply
misbehaves under an uncontrolled one (`HK-PDN-07`, withdrawn). That lowers
the stakes for the eFuse route, where the input is collapsing anyway. It does
not remove the finding: FAR-PM_FPGA_L4REQ-10 also requires the reverse-order
power-down when the step-down or FPGA region fails to boot, with the input
rail still up, and there the ordering is the whole requirement. Whether the
same board testing covers that case is a question for avionics hardware; if
it does, the severity can come down.

**Disposition: FIXED in the design.** The counter is cleared on the
`BOOT_SUCCEEDED` to `POWERING_DOWN` transition (`src/pwr_src_bootseq.sv:116-118`),
as the `LATCHUP` transition above it already did. Both halves are restored: a
PGOOD that falls is waited for, through the 5 us filter, and one that sticks
high is abandoned after 2.294 ms rather than at once.

Measured after the fix, with the eFuse PGOOD dropped and everything up
(`verification/tests/test_hk_pdn_sequence.py`):

| | Observed |
| --- | --- |
| Each step after an LT3065 source, or after DDR 0V6 | 2.294 ms, on the timeout |
| Each step after a source whose PGOOD falls | about 5.1 us, on the filter |
| LVDS after the software regions | 9.18 ms -- Eth1/Eth2's four sources |
| Whole hardware power-down, eFuse PGOOD to last step-down enable | 32.15 ms |

`test_HK_SRC_11_powered_down_when_pgood_low_or_2ms` was strengthened with the
fix so that it would have caught this directly: with PGOOD stuck high it now
also bounds the wait from above (2.5 ms), so a stalled shutdown fails, and
powers IMX down both 10 ms after boot and straight after, requiring the same
wait in both. Run against the unfixed RTL it fails on all three counts --
including the 2.275 ms just-booted wait, which the old lower bound alone would
have passed. `test_HK_SRC_04_enable_held_through_attempt` had allowed Eth1
1V0 only 1 ms to fall after Eth1 was withdrawn -- a window that held only
because of this defect -- and now allows the 3 timeouts of the sources after
it.

The power-down is now about 32 ms rather than 1 us. On eFuse loss that is
longer than the board's hold-up (`HK-PDN-07`, withdrawn), so the controlled
sequence will be overtaken by the input collapsing, which board testing says
is benign. On the FAR-PM_FPGA_L4REQ-10 critical boot-failure route, with the
input rail still up, the full sequence runs as `HK-PDN-02` and `HK-PDN-04`
require. Separately, `HK-F-02` means DDR 1V2 always waits the full 2.294 ms
on a 0V6 PGOOD that cannot fall before 2V5 does; that is the fallback working
as intended, and a reason to settle `HK-F-02`.


## HK-F-29

**A region withdrawn during its retry hold pulses its first source's enable
for one clock as it leaves the hold.**

**Severity:** MEDIUM

**Claimed.** `HK-SRC-03`: a source enable "shall be asserted only after the
housekeeper has requested that source to boot and no power-down is in effect
for it".

**Actual.** A region whose source has timed out waits out its 199.229 ms hold
(200.540 ms since `HK-F-04`)
in `RETRY`, and `RETRY` has one exit: to `BOOTING` when the hold ends
(`src/pwr_region_sm.sv:116-126`). It does not look at `pwr_dwn`. `BOOTING`
does (`:94-95`), and goes to `POWER_OFF` on the next clock -- but `BOOTING`
also starts the first source combinationally (`:71`) while leaving
`pwr_dwn_pwr_srcs` low, so for that one clock the first source sees a start
request and no power-down, enters its own `BOOTING`, and drives its enable
high. The clock after, the region's `POWER_OFF` powers it down.

Measured in `verification/tests/test_hk_src_attempt.py`: IMX requested with
its 1V1 rail dead, withdrawn 30 ms later while in its hold, and `imx_en_1v1`
asserts for **20 ns** as the hold ends -- with the region's control input low
the whole time. It was first seen on every software region at once, the
stepper drive enables included, while testing failure metadata.

The same path is reachable from a global power-down: a hardware region
retrying when the request latches holds it in `RETRY`, and leaves it the same
way. That is by inspection and has not been exercised.

**Consequence.** One clock is 20 ns, and most regulator enable inputs will not
respond to it: they have deglitch filtering or a soft-start far longer. But
that is a property of each load, none of which is characterised here, and
the stepper drives are among them (`HK-F-15` records the same class of
concern for their control inputs). More plainly, it is an enable asserted
with a power-down in effect, which is the one thing `HK-SRC-03` exists to
rule out, and it is the shape of defect that stops being harmless the first
time a pipeline stage is added between the region and the source.

**Disposition: FIXED in the design.** At the end of the hold, `RETRY` now
goes to `POWER_OFF` if a power-down is in effect, and to `BOOTING` only if
not (`src/pwr_region_sm.sv:116-126`). The path through `BOOTING` with a
power-down in effect is removed rather than shortened.

Leaving `RETRY` for `POWER_OFF` the moment `pwr_dwn` rises, as first
proposed, was considered and rejected. `POWER_OFF` clears the retry count and
accepts a new request at once, so a software region withdrawn and requested
again during its hold would re-enable the rail that had just failed about a
millisecond later, bypassing FAR-PM_FPGA_L4REQ-18's 200 ms and, repeated,
FAR-PM_FPGA_L4REQ-19's four attempts. Stepper Sec would do the same
unprompted whenever Stepper Pri powered down. Keeping the hold avoids both.
Two consequences follow:

- A region withdrawn during its hold reaches `POWER_OFF` up to 200.5 ms later,
  with every enable already low. `boot_done` is 0 throughout, so no
  power-down stage waits on it.
- A region withdrawn and requested again during its hold continues its
  existing attempt rather than starting four new ones. The ICD should say so,
  so that firmware does not expect a fresh set of attempts after a toggle.

Measured in `verification/tests/test_hk_src_attempt.py`: withdrawn during the
hold, IMX asserted nothing as the hold ended, and requested again afterwards
asserted `imx_en_1v1` at once; withdrawn and requested again 5 ms into the
hold, `imx_en_1v1` stayed off 200.540 ms. The same edge also closes, by
inspection, the Stepper Sec variant, which would have pulsed `stepper_sec_en`
with the primary enabled.


## HK-F-30

**The PolarFire's UART transmit line into the housekeeper has no pull at
either end, so it floats while the PolarFire configures, and the housekeeper
forwards whatever it reads to the bus.**

**Severity:** MEDIUM

**Actual.** The line runs from PolarFire `R6` (`uart0_tx`) through R377
(33 ohm) to housekeeper `W15` (`rs422_ttl_farsight_to_bus_pf`), and nothing
else is on it. It carries no pull at either end: `RES_PULL "NONE"` at the
housekeeper (`constr/a3pe3000l-fg484m/io/fm/io_constraints.pdc:136`), `None`
in the PolarFire pinout, and no resistor to a supply on either net in the
schematic export.

The housekeeper starts forwarding it to the bus as soon as the FPGA region's
rails are up: `rx_from_pf_mux = fpga_pgood ? rx_from_pf : '1`, and
`fpga_pgood` is `fpga_boot_succeeded` (`src/uart_ctrl.sv:108`,
`src/health_monitor_io.sv:876`). The PolarFire does not drive `uart0_tx` until
it has configured, some time after that.

**Consequence.** For that window, on every power-up, the bus's receive line
follows an input nothing drives. A floating CMOS input can sit at either level
or oscillate, so the bus can see spurious start bits and framing errors -- or
garbage bytes -- before the PolarFire has sent anything. Whether that matters
depends on how the bus handles line noise from a payload that is still
booting, which is not stated anywhere. It also rules out any later scheme
that treats the first character from the PolarFire as a sign it is ready.

Not confirmed: the PolarFire's I/O state during configuration. If it holds
unconfigured I/O with a weak pull-up, the line idles high and the window is
harmless; the device documentation should settle it. Simulation cannot:
Verilator is two-state, and the bench drives the line.

**Not covered by a requirement.** `HK-IO-09` constrains the pull on every
*output*. Nothing constrains the defined state of an input whose source can be
unpowered or tristated, and this is the one such input the housekeeper
forwards.

**Disposition.** Set `RES_PULL "UP"` on `W15`: the UART idle level, a
constraint change with no board or RTL change. Settle the PolarFire's
configuration-time I/O state either way, because the pull only defines the
level if the PolarFire is not driving the pin.


## HK-F-31

**The CoreUART transmit state machine is encoded one-hot without safe
recovery.**

**Severity:** LOW

**Claimed.** `HK-IMPL-03`: every state register in the design is synthesised
with safe state encoding.

**Actual.** The housekeeper's own state machines are: every encoding of
`pwr_region_sm` and `pwr_src_bootseq`'s `curr_state` and of `uart_ctrl`'s
`uart_state` is followed by Synplify's `MO195`, "Using syn_encoding = safe,
FSM error recovery to reset state is enabled". The vendor UART's transmitter
is not. Synplify extracts `xmit_state` in `Tx_async.v` (declared `integer`,
six states) and re-encodes it one-hot in six bits, with no `MO195` and no
`syn_encoding` attribute to ask for one. 58 of its 64 codes are unused, and an
upset into one has no defined way out. Found by inspecting the flight build's
synthesis report (`test/inspect/build.py`, `HK-IMPL-03`). The receiver's
state machine, `rx_state`, is extracted and then removed with the unused
receiver, so it does not reach the netlist.

**Consequence.** This is the transmitter of the failure beacon (`HK-UART-04`
to `-08`) -- the payload's only voice once a critical fault has powered the
PolarFire down. A transmitter stuck in an illegal code stops the beacon. The
exposure is small: the state register is triplicated and voted (`HK-IMPL-02`,
`HK-F-20`), so a single upset is outvoted, and only an upset the voting does
not correct can reach an illegal code. That is why this is `LOW` rather than
the `HK-IMPL-03` gap it would be in an unmitigated design.

**Recommended disposition.** Ask Synplify for safe encoding on the vendor
state machine without editing the vendor source -- a `syn_encoding = "safe"`
constraint on `xmit_state` in the synthesis constraints -- and confirm the
`MO195` line appears; or accept the residual risk with the TMR rationale
above, recorded against `HK-IMPL-03`.


## HK-F-32

**A region told to power down part-way through its boot drops every started
source at once, and on a global power-down the stage after it does not wait
for it.**

**Severity:** MEDIUM

**Claimed.** `HK-PDN-04`: within a region, source enables are deasserted in
reverse of their boot order, each source beginning only once the source after
it is off. `HK-PDN-02`: on a global power-down each stage begins only once
every source in the stage before it is off. Neither is limited to a region
that has finished booting.

**Actual.** Three things, each enough on its own:

- A region in `BOOTING` goes to `POWER_OFF` on `pwr_dwn`
  (`src/pwr_region_sm.sv:94-95`), and `POWER_OFF` powers every source down at
  once (`:83`). The reverse chain lives only in `POWERING_DOWN`, which a
  region reaches only from `BOOT_SUCCEEDED`.
- A source in `BOOTING` goes to `POWER_OFF` on `pwr_dwn`
  (`src/pwr_src_bootseq.sv:93-94`), not through `POWERING_DOWN`, so nothing
  waits for a rail that was ramping.
- Each hardware stage gate is `start_pwr_dwn && !<next>_boot_done`
  (`src/health_monitor.sv:553-558`). `boot_done` is false in `BOOTING`, so a
  region still booting reads as off, and the stage after it is told to power
  down on the same clock.

Measured in `verification/tests/test_hk_pdn_sequence.py`:

| | Observed |
| --- | --- |
| IMX withdrawn with 1V1, 1V8 and 2V9 up and 3V3 booting | all four enables fell on one clock, 0.1 us after the withdrawal |
| eFuse PGOOD dropped with DDR8 2V5 up and 1V2 booting | DDR8 1V2, DDR8 2V5 and step-down 4V0 fell on one clock, 5.2 us after the trigger |

**Why it was not caught.** Every power-down test started from regions that
had finished booting.

**Consequence.** Two routes reach it.

- *A software region withdrawn while it boots.* This is normal operation:
  the PolarFire may turn a region off at any time, including during its
  boot, or toggle it. IMX is the sharpest case: the IMX531 has power-off
  ordering requirements between its rails (`HK-PROT-02`), and this drops
  them all together, without the shorts that pull them down evenly on a
  latchup. The same holds for Eth1 and Eth2.
- *A global power-down while a hardware region boots.* Only the eFuse route
  can do it -- a critical boot failure leaves no region mid-boot -- but the
  boot window, during power-up, is when the input is least settled.

`RETRY` (`HK-F-29`) and `LATCHUP` are not affected: both power every source
down at once by design (`HK-REG-05`, `HK-PROT-02`).

**Disposition: FIXED in the design.** Three changes, with the decision taken
the conservative way.

1. Region: `BOOTING` on `pwr_dwn` goes to `POWERING_DOWN`
   (`src/pwr_region_sm.sv:94-95`), whose reverse chain passes over sources
   that never started. Latchup keeps priority.
2. Stage gates: each waits on the region's new `srcs_off` output, every
   source in `POWER_OFF` (`src/pwr_region_sm.sv:69`), in place of
   `!boot_done` (`src/health_monitor.sv:553-558`). It is wired out through all
   eleven region wrappers. `boot_done` is unchanged and still chains the boot.
3. Source: `BOOTING` on `pwr_dwn` goes to `POWERING_DOWN` with the counter
   cleared (`src/pwr_src_bootseq.sv:93-96`), and a source that got there from
   `BOOTING` ignores PGOOD and waits out its full 2.294 ms
   (`:129`). Its PGOOD never rose, so it has none to lose, and its rail may be
   part-way up. Counting it off as soon as its enable fell was the
   alternative, and was rejected: it gives the source below no time at all
   while that rail discharges, which is the case the IMX531 ordering exists
   for.

Measured in `verification/tests/test_hk_pdn_sequence.py`:

| | Before | After |
| --- | --- | --- |
| IMX withdrawn, 3V3 booting | all four on one clock | 3V3 0.0001 ms, 2V9 2.294, 1V8 2.299, 1V1 4.593 |
| eFuse dropped, DDR8 1V2 booting | DDR8 1V2, 2V5 and step-down 4V0 on one clock | DDR8 1V2 0.005 ms, 2V5 2.299, step-down 4V0 2.304, 3V0 2.309, 2V2 2.314 |

The booted cases are unchanged: every software region up, 32.15 ms to the
last step-down enable; LVDT alone, LVDS at 2.299 ms.

Two side effects, both by inspection. A hardware region withdrawn mid-boot now
sits in `POWERING_DOWN`, where `boot_done` is 1, which can set the next
region's `start_boot`; that region cannot start, because on this route it
already has `pwr_dwn` from the same latched request. And a software region
withdrawn mid-boot clears its `start_boot` as it does when withdrawn after
booting, so a later request needs a fresh rising edge, as it already did.

## HK-F-33

**The LVDS power-down gate omits LVDT, so with LVDT the last software region
still powering down, LVDS goes down with it.**

**Severity:** LOW

**Claimed.** `HK-PDN-02`: on a global power-down each stage begins only once
every source in the stage before it is off. The stage before LVDS is every
software-controlled region. The design documentation's power-down figure
says the same: LVDS "waits for all SW regions off".

**Actual.** The LVDS gate is
`start_pwr_dwn && ~|{eth1_boot_done, eth2_boot_done, stepper_pri_boot_done,
stepper_sec_boot_done, imx_boot_done}` (`src/health_monitor.sv:557-558`).
Five of the six software regions; `lvdt_boot_done` is not in it. LVDT's one
source is an LT3065 (U55), whose PGOOD is released, and reads high, once it
is disabled, so it is off only when its 2.294 ms power-down timeout has run
(`HK-SRC-11`) -- and LVDS does not wait for it.

Measured in `verification/tests/test_hk_pdn_sequence.py`, with LVDT the only
software region up and the eFuse PGOOD dropped: `lvdt_en` and `lvds_en` both
fell 5.2 us after the trigger, on the same clock. Every later stage then
waited correctly.

**Why it was not caught.** The power-down tests brought every software region
up at once. Eth1 and Eth2 take 6.9 ms to power down -- four LT3065 timeouts
each -- and LVDT 2.294 ms, so LVDS began after LVDT whether or not it waited
for it. The omission shows only when LVDT outlasts every region the gate does
name: LVDT alone, or with regions that finish sooner.

**Origin.** Most likely a transcription slip; nothing records it as a
decision. The original design indexed the regions in arrays -- LVDS 4, Eth1 5,
Eth2 6, Motor Pri 7, Motor Sec 8, LVDT 9, IMX 10 -- and gated each region on
the one after it. When that was rewritten with named signals (`464ea38`,
2025-08-27), the FPGA gate, which LVDS was then part of, was written out as
`{lvds, eth1, eth2, stepper_pri, stepper_sec, imx}`: indices 4 to 10 in order,
skipping only 9. When LVDS became a hardware region (`168f4f3`, 2025-11-10)
the remaining five names moved into the new LVDS gate unchanged. Everywhere
else LVDT is handled exactly as the other software regions are. Whether it
was intended can only be confirmed by the author.

**Requirements.** `HK-PDN-02` is violated as written: it applies to every
global power-down. Its only parent, FAR-PM_FPGA_L4REQ-10, is not: that
requires the reverse-order power-down when a critical region fails to boot,
and no software region can be up then. The route on which this occurs is the
eFuse PGOOD, which is FAR-PM_FPGA_L4REQ-5's "controlled shutdown" -- a term the
parent does not define, though the design documentation does, as software
regions together and then hardware regions in reverse order. `HK-PDN-02`
therefore governs a route its stated parent does not cover; it should also
trace to FAR-PM_FPGA_L4REQ-5, or be narrowed to the boot-failure route.

**Consequence.** LVDS 3V3 and LVDT 15V0 are removed together rather than in
order. The only route to a staged global power-down with a software region
up is the eFuse PGOOD (`HK-PDN-01`): a step-down or FPGA boot failure happens
before any software region can be requested, since each needs
`fpga_boot_succeeded`. On the eFuse route avionics hardware has said the
board has too little hold-up for a controlled shutdown, and that board
testing shows no supply misbehaving under an uncontrolled one (`HK-PDN-07`,
withdrawn). Two rails dropping together is a subset of that, which is why
this is `LOW`. It is still a departure from `HK-PDN-02`, and it matters more
if the eFuse PGOOD can dip for longer than the 5 us filter while the input
stays up -- the latched power-down then runs in full on a live input.

**Disposition: FIXED in the design.** `lvdt_boot_done` is added to the LVDS
gate (`src/health_monitor.sv:557-558`), which now names all six software
regions. With LVDT the only software region up, LVDS began at 2.299 ms, once
LVDT's timeout had run; with every software region up the sequence is
unchanged, LVDS at 9.18 ms (`verification/tests/test_hk_pdn_sequence.py`).
Waiting for LVDT only adds ordering, and LVDT reaches `POWER_OFF` within its
bounded 2.294 ms like every other software region, so the gate cannot stall.
The LVDT-alone case stays in the test. Still open, for systems: whether
`HK-PDN-02` should also trace to FAR-PM_FPGA_L4REQ-5; and, for the author,
confirmation that the omission was not intended.

