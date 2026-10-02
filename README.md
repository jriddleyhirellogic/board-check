# board-check

Automated checks on the Farsight avionics board schematic, run against the
JSON netlist that `altium/ExportAllSchematicsToJSON_v2.5.pas` writes from
Altium. Version 2.5 exports every channel of a multi-channel sheet under its
physical designators (2.4 and earlier kept only the first: CM-03986
RS422.SchDoc came through as U8 alone instead of U8A-U8L). Earlier versions
are in the git history.

The Altium export is a manual step (DelphiScript inside Altium). Commit the
JSON it produces under `designs/<assembly>/`; everything after that runs on
any machine with Python.

```
altium/                     Altium export script (run inside Altium)
designs/CM-03545/           Farsight FM: export JSON, schematic PDF, boardcheck.yaml
designs/CM-03986/           backplane (Q8J, SV1) FM: export JSON, boardcheck.yaml
designs/CM-02441/           IMX531 sensor board FM: export JSON, boardcheck.yaml
designs/farsight_system.yaml  the boards above and the connectors joining them
boardcheck/                 the checker
tests/                      unit tests + a smoke test on the committed export
```

## Usage

```bash
pip install -e ".[dev]"                 # checker + pytest
pip install -e ".[parts]"               # optional: electronic-parts-repository decoders

cd designs/CM-03545
boardcheck CM-03545_*_sch_*.json -c boardcheck.yaml                    # text to stdout
boardcheck CM-03545_*_sch_*.json -c boardcheck.yaml -f markdown -o ../../reports/CM-03545.md
boardcheck --list-checks
```

`--fail-on error|warning|info|never` sets the exit code (default: exit 1 on
any unwaived error), so the same command can gate a CI job later.
`--only NET001,PWR001` runs a subset; `--no-partsdb` skips the parts
repository even when installed.

## Comparing two exports

```
python -m boardcheck diff OLD.json NEW.json -c designs/CM-03545/boardcheck.yaml -f markdown -o diff.md
```

reports what changed between two exports of a design: components added or
removed, part number, comment and footprint changes (both exports from
script 2.4.0 or later), every pin that moved to another
net, nets renamed, part parameter changes, sheets added or removed, and the
check findings the new export introduces or resolves. Nets are matched by
their pins, not their names: a net whose pins are unchanged under a new name
is a rename, so Altium's auto-named nets (`NetR345_2`) do not show up as
changes when designators shift. `--fail-on error` exits 1 when the new
export introduces an error, for CI; `--no-findings` compares connectivity
only. The Markdown output is meant for a pull request comment.

## Checking boards together

```
python -m boardcheck system designs/farsight_system.yaml
```

checks the connectors that join boards. `designs/farsight_system.yaml` names
each board's export and boardcheck.yaml, and the links between them: a
direct mate (`map: pins`, pin n to pin n) or a harness wired by signal name
(`map: {by: name, a: REGEX, b: REGEX}`: the regex groups on each side's net
names pair the pins). Each side is judged with its own board's
configuration, pin types and level data, following signals through series
resistors as the level checks do.

| Check | Severity | What it finds |
|---|---|---|
| SYS001 | warning | A pin wired on one board that reaches a pin connected to nothing on the other |
| SYS002 | error | Ground meeting a rail or signal, or rails of different nominal voltage, across a connector (a rail meeting a signal: warning) |
| SYS003 | error | One half of a differential pair wired to the other half on the other board |
| SYS004 | error | A signal driven by push-pull outputs on both boards (receivers with no driver on either board: warning); signals with parts lacking pin data are not judged |
| SYS005 | error | A driver on one board against receivers on the other: VOH below VIH, VOL above VIL, supply above the input's absolute maximum |
| SYS006 | info | Each link's pairing, wired pins left unpaired, and parts whose missing pin data keeps a signal from being judged |
| SYS007 | warning | A wired signal the link's name pairing leaves without a partner, with what it would meet under the link's pin-numbering rule |

A name map may also be a stem table (`map: {by: name, suffix: '_([PN])$',
names: {GPOUT: GPO_FARSIGHT_TO_BP, ...}}`): the suffix is carried across
and the stems translated. When every paired pin follows one numbering rule
(pin n to pin n, or odd and even swapped as on a flipped ribbon), SYS006
names it, and SYS007 reports a wired signal left without a partner together
with the pin that rule would put it on. `unpaired_ok` lists net patterns
expected to have no partner.


Farsight: CM-03545 J7 mates CM-02441 (sensor) J1 directly; to CM-03986
(backplane), J3 reaches J2 through the Ethernet harness (MDI pair n to ETH5
TX pair n), J1 reaches J3 through the control harness, and J2 reaches J4
through the ARF6 PCIe cable, all wired by name.

## Checks

| Id | Default | What it catches |
|---|---|---|
| EXP007 | info | Export has no pin electrical types (script older than 2.3.0) |
| EXP008 | info | Export has no footprints (script older than 2.4.0); PRT008/PRT009 are skipped |
| EXP001-006 | error | Export not trustworthy: old script version, sheets with no components, multi-part components missing part A, part numbers missing from the dictionary, a designator with two part numbers, totals differing from `export.expect` |
| NET001 | warning | Labelled net reaching one pin (typo'd net label or port, unfinished wire). `UNUSED`/`SPARE` stubs are allowed |
| NET002 | info | Unconnected pins, per component, for review |
| NET003 | error | Unconnected power or ground pin |
| NET004/005 | warning | Net names differing only by case or spacing; whitespace in a net name |
| NET006 | warning | `_P` without `_N` (and `_DP`/`_DN`, `+`/`-`); active-low `*_RESET_N` etc. are ignored |
| NET007 | warning | Two-terminal part with both pins on one net |
| NET008 | warning | Non-mechanical component with nothing connected |
| PRT001 | warning | Comment (what the BOM shows) differs from Part Number; **error** when both decode to different values |
| PRT002 | warning | Required library parameters missing (C_Value, Voltage, R_Value, Power_Rating, ...) |
| PRT003 | warning | Library parameters disagree with the decoded part number (value, voltage, power, tolerance, size, dielectric) |
| PRT004 | info | Passive part the parts repository cannot decode |
| PRT005 | warning | Qualification missing or not in the allowed list |
| PRT006 | error | Designator prefix contradicts the decoded part type (a resistor PN on a `C` designator) |
| PRT007 | warning | Design Item ID differs from Part Number |
| PRT008 | warning | Component (other than `mechanical_kinds`) with no current footprint on its symbol |
| PRT009 | error | One part number placed with different footprints |
| PWR001 | warning | Capacitor over its derating limit; **error** over its rating |
| PWR002 | warning | Resistor between two rails over power derating; **error** over rating, over working voltage, or 0 Ω between different rails |
| PWR003 | warning | Supply rail with no capacitor to ground |
| PWR004 | info | Supply rail with no test point |
| PWR005 | warning | Ground-named pin off ground, or power-named pin on ground |
| PWR006 | warning | I2C SCL/SDA without a pull-up to a rail |
| PWR007 | warning | IC supply pin on a local (non-rail) net with no capacitor to ground |
| PWR009 | error | A regulator's feedback network sets a different voltage than its rail's name (part data `regulator` and `v_feedback`; the resistor network around the feedback pin is solved, so sense resistors, chains and remote sense count) |
| PWR010 | warning | Linear regulator (part data `topology: linear`) whose input rail, less the output it sets, is below the data sheet's maximum dropout at its programmed current limit (error: below the light-load dropout); rails set by other regulators taken at their worst case |
| PWR011 | error | Regulator enable or UVLO pin (part data `enable_pin`, `uvlo_pin`) held by a divider from its own input: turn-on input voltage (rising threshold at its maximum, plus the pin's pull-up current) above the rail (error), turn-off below the regulator's minimum input (warning), otherwise listed (info) |
| PWR008 | error | IC supply pin's rail outside the part data's recommended `supply_<pin>` range (limits relative to another supply, like VD <= VA, are evaluated) |
| PIN001 | warning | Symbol pin type differs from the part data |
| PIN002 | info | IC with no pin data in the parts repository: its symbol pin types are unverified |
| PIN003 | warning | Part pin data names a pin the symbol does not have, or uses an unknown direction word |
| PIN004 | error | Two push-pull outputs on one net, or an output on a supply/ground net; warning when two parts' outputs meet through small series resistors (a part's output split over several pins counts once, and so do alternate parts: see CLK001) |
| PIN005 | warning | Net with only inputs on it (nothing drives it) |
| PIN006 | warning | Open-drain net without a pull-up to a rail |
| PIN007 | error | Differential receiver input pair (part data `*_P` input with `diff_pair`) with no resistor across it in `pins.diff_termination_ohms` (direct or split through a centre tap) and no internal `termination_ohms`; terminated twice is a warning |
| PIN008 | error | Differential receiver input or driver output (part data `*_P` with `diff_pair`) whose + pin is on the pair's negative net and - pin on the positive one |
| FIO001 | warning | FPGA constraint or top-level file missing, or a command in it not understood |
| FIO002 | error | Constrained FPGA port on a ball the symbol lacks, or on a supply/ground net (or a soft-ground standard such as SHIELD12 *not* on ground) |
| FIO003 | warning | Constrained FPGA port on a pin that connects to nothing |
| FIO004 | error | Bank VCCI set in the constraints differs from the rail on the bank's supply pins |
| FIO005 | warning | FPGA bank I/O wired to other parts but assigned no port |
| FIO006 | error | Constraint DIRECTION contradicts the FPGA design's port direction (warning when one side is inout) |
| FIO007 | error | FPGA top-level port with no pin constraint (place-and-route picks the pin) |
| FIO008 | error | Differential port pair (`_p`/`_n`, `_t`/`_c`, `x`/`x_n`) not on the P and N balls of one pair (swapped, split, or single-ended); warning for a `_p` port whose partner is unconstrained |
| FIO009 | error | Board nets on a differential pair's balls cross it (positive port on the `_N` net) |
| FIO010 | error | Transceiver reference clock not on a REFCLK pin, or a port of the wrong direction on an XCVR RX/TX pin; warning for a REFCLK pin carrying something else |
| FIO013 | error | Signal between two configured FPGAs driven by both (warning: driven by neither, or unconstrained on one side) |
| FIO014 | error | A bus bit wired between two FPGAs lands on a port other than the same bit of its namesake bus (`pa3_fw_version[0]` vs `fw_version[0]`) |
| FIO012 | warning | Unused FPGA pins not terminated as the part data's `unused_pins` rules say (e.g. PolarFire unused REFCLK/RX pins: 100 kohm to VSS) |
| FIO011 | warning | Transceiver quad with used lanes and no reference clock on its own REFCLK pins or on a quad above it (part data `transceivers`); info when it relies on a cascade |
| LVL001 | error | Driver's VOH (or pull-up level) below a receiver's VIH / VT+ |
| LVL002 | error | Driver's VOL above a receiver's VIL / VT- |
| LVL003 | error | Highest level on a signal (driver supply, pull-up or divider) above a receiver's absolute or recommended maximum input. Above the absolute maximum through a series resistor that holds the clamp current within the part's `ii_clamp` rating: warning; such inputs of one part together above its `ii_clamp_package` rating: error |
| LVL004 | error | FPGA I/O standard used on a bank whose rail is outside that standard's supply range |
| LVL005 | info | Pins on logic signals whose levels could not be resolved (the work queue for level data) |
| LVL006 | warning | Open-drain output whose pull-ups (rail / R, summed over the signal) draw more current when it is low than its VOL is specified at, or outside the part data's `i_pullup_recommended` range |
| LVL007 | error | Undriven signal whose resistors to rails and ground hold a logic input between its VIL and VIH (VT-/VT+) |
| PWU001 | error | FPGA control output (enable, reset, chip select) that floats before the FPGA drives it |
| PWU002 | error | ... that sits between the receivers' VIL and VIH before the FPGA drives it (warning when the thresholds are assumed) |
| PWU003 | warning | ... whose level changes between the pre-drive windows (e.g. low while high-Z, high once the weak pull-up is on) |
| PWU004 | info | ... whose level could not be evaluated (resistor value or pull data missing) |
| FW001 | error | A firmware ADC channel (C enum, e.g. `TLM_1V5_ASIC`) reads an input the schematic wires to a different signal |
| FW002 | warning | ADC input wired to a signal no firmware channel reads, or a firmware channel on an unconnected input |
| FW003 | info | Firmware channel map traced to the board |
| FW004 | error | A voltage channel's rail, at its nominal voltage, reaches the ADC above the ADC reference (divider too weak) |
| FW005 | warning | Calibration file gains that differ from the board's scaling (reference / 2^bits / divider ratio, mV at the rail per count) |
| FW007 | error | A firmware constant for a PWM output's full scale (e.g. `PWM_VREF_mV`) differs from what the board delivers at the load: the FPGA bank rail through the RC filter's divider |
| FW008 | warning | A firmware maximum (e.g. `I_MAX_MA`) beyond what the PWM output's full scale can produce through the load's characteristic (e.g. DRV8434 I_FS = VREF / KV) |
| FW006 | warning | Calibration file rows that do not name the firmware enum's signal at their position (the table is loaded by position) |
| FW009 | info | Each current channel's scaling from the board: the ADC input traced back through resistors and op-amps (ideal, solved by nodal analysis) to one shunt (two-terminal, or Kelvin E1/E2 sense pins, at most `shunt_max_ohms`), giving the gain, mA/count, zero-current reading and full-scale current |
| FW010 | warning | Current channel calibration offsets that do not remove the amplifier's zero-current output (the firmware computes raw * gain + offset, so offset must be -gain * zero counts in any unit) |
| FW011 | error | A firmware GPIO define (`#define NAME GPIO_<n>`) whose CoreGPIO bit reaches an FPGA top-level port of another name |
| FW012 | warning | A GPIO define the firmware sources use whose bit the FPGA design ties to a constant or leaves unconnected |
| FW013 | info | Firmware GPIO map: defines traced to FPGA balls, FPGA-internal, constant or unconnected, and header groups with no CoreGPIO configured |
| STP001 | error | Configuration strap pin (per the part data's `straps`) with nothing setting its level at reset |
| STP002 | error | Strap pin whose resistors put it between VIL and VIH (warning when the thresholds are assumed) |
| STP003 | error | Strap pin driven by another part's output when the data sheet forbids it |
| STP004 | info | The configuration each part's straps select (e.g. a PHY's managed mode and address) |
| ANA001 | error | Op-amp or comparator input outside its common-mode range (`vi_op`) or absolute maximum at the circuit's nominal operating point; for comparators whose part data marks `either_input`, only when both inputs of a channel are out of range (warning when the other's level is unknown) |
| ANA002 | warning | Op-amp output beyond its guaranteed swing (`voh`/`vol`, row chosen by the DC load) at the nominal operating point |
| ANA003 | info | Op-amp or comparator inputs whose operating point could not be worked out (the network is also driven by another part, a connector or a diode) |
| CLK001 | info | Oscillators (part data `part_info.type: oscillator`) whose outputs reach one signal, directly or through selection resistors: taken as alternate footprints with one fitted (`parts.alternates` declares other groups) |
| CLK002 | error | Alternate oscillators that differ in frequency, single-ended vs differential output, or which net carries the true output |
| CLK003 | error | Oscillator frequency (`part_info.frequency_hz`) differs from a frequency in the name of a net it drives (`ETH1_50MHZ_OSC_OUT`, `148.5MHZ_P`) |
| CLK004 | error | Clock input (part data `clock_inputs`) whose select pins, read like straps, expect another frequency than its oscillator (or net name) gives; warning when the select levels cannot be read |

PRT003, PRT004, PRT006, PIN001-003, PIN007-008, LVL001-007, PWU001-004, STP001-004, ANA001-003 and CLK001-004 need
[electronic-parts-repository](https://github.com/jriddleyhirellogic/electronic-parts-repository);
without it they are reported as skipped.

### Pin types: part data first, symbol second

Schematic symbol pin types are set by hand and are not reliable on their
own. The export (script >= 2.3.0) records each pin's symbol type as
`electricalType`, but the pin checks take a pin's type from the part data
first: the `pin_functions` block of the part's JSON file in
electronic-parts-repository, keyed by pin name (overbar backslashes
ignored) or pin number, with `direction` one of input, output, bidir,
power, passive, open_drain, open_source, tristate (see
`pins.direction_map`). The symbol's type is used only for pins the part data
does not cover.

- Where both exist and differ, PIN001 reports it.
- PIN004-006 findings built only on part data are errors; any finding that
  relies on a symbol-only type is held to warning and labelled
  `schematic only`.
- PIN002 lists the ICs with no part pin data: that list is the work queue
  for filling in `pin_functions`.
- A 3-state output (`three_state` in the part data) counts as a driver only
  when its enable pin is strapped to its active level, directly or through a
  resistor to a rail or ground; otherwise it is treated as high impedance.
  Bidirectional pins are never counted as contention; whether they fight
  depends on firmware and FPGA configuration.
- An input the part data gives an `internal_bias` (pull-up, pull-down,
  fail-safe) is never reported as floating.
- PIN003 also compares each pin's number on the symbol with the package pin
  numbers in the part data (`pins`), which catches symbol pinout errors.

The field reference for `pin_functions` is in the parts repository's
JSON_FORMAT.md.

### FPGA configuration: read from the FPGA project

A programmable pin's type and levels are set by the FPGA design, so for an
FPGA listed under `fpga` in the config, board-check reads the FPGA project's
own files where they live (paths relative to the config file), never a copy:

- `constraints`: the Libero `.pdc`/`.tcl` files the build applies. The
  reader follows `source`, applies `dict set pins` maps only to the ports
  collected by `lappend ports` (so commented-out ports are unconstrained,
  as in Libero), and reads `set_io` and `set_iobank`. Anything it does not
  understand is reported (FIO001), not guessed.
- `top_level`: the design's top-level port declarations (SmartDesign
  `sd_create_*_port` Tcl, or a Verilog/SystemVerilog module header). A
  port's direction comes from here; the constraint's DIRECTION is checked
  against it (FIO006).
- `bank_pattern` / `bank_supply` / `bank_name` / `bank_type_pattern` tie
  schematic pin names to banks, bank supply pins and `set_iobank` names.
- `pair_patterns` and `transceiver_pattern` read differential pairs and
  transceiver roles off the schematic pin names (`HSIO162PB0`,
  `XCVR_4A_REFCLK_P`). A port is a transceiver reference clock when the
  SmartDesign top level connects it to a `REF_CLK_PAD_P/N` pin
  (`fpga_pins.refclk_pads`), or, without SmartDesign, by name.

Constrained pins take their type from this configuration ahead of the part
data and the symbol, so PIN004-006 see FPGA outputs and inputs as the
bitstream makes them. If the FPGA repository is not checked out where the
config expects it, FIO001 says so and the FPGA-specific checks are skipped.

### Firmware: read from the firmware repository

`firmware.adc_channel_maps` points at a C enum whose position selects an
ADC chip select and input (CM-03545: `Camera/include/tlm_adc.h`
`TLM_Signal_t`, input = index & 7, select = index >> 3 per `tlm_adc.c`).
Each entry is traced through the source files to the board: select `n` is
the SmartDesign pin `select_link` (`temp_tlm_spi_inst:SPISS[n:n]`), whose
top-level port the constraints put on an FPGA ball, wired (through series
resistors) to one ADC's `CS`; the channel picks `IN<ch>`, and the net on
it, less `net_strip` suffixes, must be the name the firmware gives it.
With `calibration` pointing at the calibration spreadsheet (`.xlsx` needs
`pip install openpyxl`, or the `xlsx` extra; `.csv` works without it),
each voltage channel's gain is compared with the divider the board puts in
front of the ADC.

`firmware.gpio_maps` points at a header of `#define NAME GPIO_<n>` lines
(CM-03545: `Camera/include/gpio_pin_def.h`), grouped under comment lines.
Each block names the header groups one CoreGPIO serves and that core's
instance path in the SmartDesign hierarchy (`hk_hier_inst/gpo_hk_pwr_ctrl_inst`).
`smartdesign.py` reads every SmartDesign script under the FPGA's design root
(three directories above the top-level `.tcl`, or `design_root`), joins pins
bit by bit, and follows `GPIO_OUT[n]` / `GPIO_IN[n]` up through sub-designs,
buffer macros (TRIBUFF, INBUF, BIBUF, ...) and inverters to the top-level
port, whose constraint gives the ball and the board net. `source_dir` lets
FW012 tell which defines the firmware actually uses.

### Logic levels

LVL001-004 compare `range_table` characteristics from the parts
repository (`voh`, `vol`, `vih`, `vil`, `vt_pos`, `vt_neg`, `vi_abs`,
`vi_op`, `supply_*`). Supply-relative limits (`0.65*VCC`, `VDDI-0.4`) are
evaluated at the rail on that supply pin; an FPGA's rows are selected by
the pin's constrained I/O standard, drive strength and bank type, with the
bank's rail as the supply. A signal is a net plus the nets joined to it by
series resistors up to `levels.series_max_ohms`; resistors from it to rails
and ground give its undriven level (pull-up rail or divider output). A
driver's level is taken at each receiver's own net: series resistors and
resistors to rails divide it (a 3.3 V clock through 270 / 820 ohm reaches a
2.5 V input at 2.48 V). Where
several rows apply the least favourable limit is used, and outputs are
taken at the smallest listed load current (logic inputs draw microamps).

### Power-up defaults

An FPGA drives its pins only once its I/Os are active. Before that (while
powering up, while blank, while being programmed) the part data's
`power_up_io` block says each pin is high impedance or weakly pulled, and
`r_weak_pull_up` gives the pull's range. PWU001-004 take every FPGA output
whose port name marks it as a control signal (`power_up.control_ports`:
`*_en`, `*_rst_n`, `*_cs_n`, `*_sleep_n`, ...), work out the level its loads
see in each window from the board's resistors (plus the weak pull at both
ends of its range), and compare it with the loads' VIL/VIH. Loads without
level data are judged against `power_up.assumed_thresholds` of the FPGA
bank voltage, and those findings are held to warning. The Markdown report
lists every such signal and its level in each window.

### Analog operating points

`analog.py` solves the resistor and op-amp network around a net by nodal
analysis. Op-amps are ideal (their inputs equal, from part data functions
`OPAMP_OUT`/`OPAMP_IN_P`/`OPAMP_IN_N`, or op-amp style pin names for parts
without pin data); inductors and ferrites are shorts, capacitors open; rails
and ground are fixed at their nominal voltages, and shunts (two-terminal at
or below 0.1 ohm, or four-terminal with E1/E2 sense pins) carry no current.
ANA001-003 use it for every op-amp and comparator input: rails at nominal,
no load current. FW009/FW010 use the same network for the small-signal gain
from a shunt to an ADC input.

### Net voltages

Voltage-aware checks infer each net's voltage from the rail naming
convention: `3V3_MISC` is 3.3 V, `0V6_VTT_16GB` is 0.6 V, `1V0A_FPGA` is
1.0 V, `GND`/`CHAS` are 0 V. Control and telemetry nets derived from a rail
(`*_EN`, `*_PGOOD`, `*_nFAULT`, `*_TLM_ADC`, ...) have no known voltage;
sense nodes (`*_RSENSE_P`, `*_SNS`) count for derating but not as rails.
Rails the convention cannot name go in `nets.voltages` in the config. A part
is only checked when the voltage on both of its terminals is known; the
Markdown report's Coverage section says how many that was.

## Configuration and waivers

`boardcheck.yaml` overrides the defaults in `boardcheck/config.py`: rail
patterns, derating factors, required parameters, allowed qualifications,
expected export totals, per-check severity, disabled checks, and waivers.

```yaml
waivers:
  - check: PWR005
    ref: U2
    reason: unused ProASIC3 PLL supplies tied to GND per datasheet
```

A waiver matches on `check` plus any of `ref`, `net`, `part_number` (glob
patterns) or `match` (substring of the message). Waived findings stay in
the report with their reason; a waiver that matches nothing is reported as
CFG001 so stale waivers get removed.

## Layout

```
boardcheck/
  model.py        Design, Component, Pin, Net loaded from the export
  config.py       defaults, YAML overrides, net voltage and kind inference
  partsdb.py      optional electronic-parts-repository adapter
  fpga.py         reads FPGA constraint and top-level files (Libero Tcl subset, HDL headers)
  diff.py         net-level comparison of two exports
  checks/         export.py, fpga.py, levels.py, nets.py, parts.py, pins.py, power.py, powerup.py,
                  straps.py (one function per check)
  runner.py       runs checks, applies severity overrides and waivers
  report.py       text / markdown / json output
tests/            synthetic-export unit tests + a smoke test on the committed export
```

Adding a check: write a function in `boardcheck/checks/` decorated with
`@check("ID", "title", severity)` that yields `Finding`s, and add a test in
`tests/test_checks.py`.
