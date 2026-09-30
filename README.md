# board-check

Automated checks on the Farsight avionics board schematic, run against the
JSON netlist that `altium/ExportAllSchematicsToJSON_v2.3.pas` writes from
Altium.

The Altium export is a manual step (DelphiScript inside Altium). Commit the
JSON it produces under `designs/<assembly>/`; everything after that runs on
any machine with Python.

```
altium/                     Altium export script (run inside Altium)
designs/CM-03545/           Farsight FM: export JSON, schematic PDF, boardcheck.yaml
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

## Checks

| Id | Default | What it catches |
|---|---|---|
| EXP007 | info | Export has no pin electrical types (script older than 2.3.0) |
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
| PWR001 | warning | Capacitor over its derating limit; **error** over its rating |
| PWR002 | warning | Resistor between two rails over power derating; **error** over rating, over working voltage, or 0 Ω between different rails |
| PWR003 | warning | Supply rail with no capacitor to ground |
| PWR004 | info | Supply rail with no test point |
| PWR005 | warning | Ground-named pin off ground, or power-named pin on ground |
| PWR006 | warning | I2C SCL/SDA without a pull-up to a rail |
| PIN001 | warning | Symbol pin type differs from the part data |
| PIN002 | info | IC with no pin data in the parts repository: its symbol pin types are unverified |
| PIN003 | warning | Part pin data names a pin the symbol does not have, or uses an unknown direction word |
| PIN004 | error | Two push-pull outputs on one net, or an output on a supply/ground net |
| PIN005 | warning | Net with only inputs on it (nothing drives it) |
| PIN006 | warning | Open-drain net without a pull-up to a rail |
| FIO001 | warning | FPGA constraint or top-level file missing, or a command in it not understood |
| FIO002 | error | Constrained FPGA port on a ball the symbol lacks, or on a supply/ground net (or a soft-ground standard such as SHIELD12 *not* on ground) |
| FIO003 | warning | Constrained FPGA port on a pin that connects to nothing |
| FIO004 | error | Bank VCCI set in the constraints differs from the rail on the bank's supply pins |
| FIO005 | warning | FPGA bank I/O wired to other parts but assigned no port |
| FIO006 | error | Constraint DIRECTION contradicts the FPGA design's port direction (warning when one side is inout) |
| FIO007 | error | FPGA top-level port with no pin constraint (place-and-route picks the pin) |
| LVL001 | error | Driver's VOH (or pull-up level) below a receiver's VIH / VT+ |
| LVL002 | error | Driver's VOL above a receiver's VIL / VT- |
| LVL003 | error | Highest level on a signal (driver supply, pull-up or divider) above a receiver's absolute or recommended maximum input |
| LVL004 | error | FPGA I/O standard used on a bank whose rail is outside that standard's supply range |
| LVL005 | info | Pins on logic signals whose levels could not be resolved (the work queue for level data) |
| PWU001 | error | FPGA control output (enable, reset, chip select) that floats before the FPGA drives it |
| PWU002 | error | ... that sits between the receivers' VIL and VIH before the FPGA drives it (warning when the thresholds are assumed) |
| PWU003 | warning | ... whose level changes between the pre-drive windows (e.g. low while high-Z, high once the weak pull-up is on) |
| PWU004 | info | ... whose level could not be evaluated (resistor value or pull data missing) |

PRT003, PRT004, PRT006, PIN001-003, LVL001-005 and PWU001-004 need
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

Constrained pins take their type from this configuration ahead of the part
data and the symbol, so PIN004-006 see FPGA outputs and inputs as the
bitstream makes them. If the FPGA repository is not checked out where the
config expects it, FIO001 says so and the FPGA-specific checks are skipped.

### Logic levels

LVL001-004 compare `range_table` characteristics from the parts
repository (`voh`, `vol`, `vih`, `vil`, `vt_pos`, `vt_neg`, `vi_abs`,
`vi_op`, `supply_*`). Supply-relative limits (`0.65*VCC`, `VDDI-0.4`) are
evaluated at the rail on that supply pin; an FPGA's rows are selected by
the pin's constrained I/O standard, drive strength and bank type, with the
bank's rail as the supply. A signal is a net plus the nets joined to it by
series resistors up to `levels.series_max_ohms`; resistors from it to rails
and ground give its undriven level (pull-up rail or divider output). Where
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
  checks/         export.py, fpga.py, levels.py, nets.py, parts.py, pins.py, power.py, powerup.py (one function per check)
  runner.py       runs checks, applies severity overrides and waivers
  report.py       text / markdown / json output
tests/            synthetic-export unit tests + a smoke test on the committed export
```

Adding a check: write a function in `boardcheck/checks/` decorated with
`@check("ID", "title", severity)` that yields `Finding`s, and add a test in
`tests/test_checks.py`.
