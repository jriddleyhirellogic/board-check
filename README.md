# board-check

Automated checks on the Farsight avionics board schematic, run against the
JSON netlist that `ExportAllSchematicsToJSON_v2.2.pas` writes from Altium.

The Altium export is a manual step (DelphiScript inside Altium). Commit the
JSON it produces; everything after that runs on any machine with Python.

## Usage

```bash
pip install -e ".[dev]"                 # checker + pytest
pip install -e ".[parts]"               # optional: electronic-parts-repository decoders

boardcheck CM-03545_*_sch_*.json -c boardcheck.yaml                    # text to stdout
boardcheck CM-03545_*_sch_*.json -c boardcheck.yaml -f markdown -o reports/board-check.md
boardcheck --list-checks
```

`--fail-on error|warning|info|never` sets the exit code (default: exit 1 on
any unwaived error), so the same command can gate a CI job later.
`--only NET001,PWR001` runs a subset; `--no-partsdb` skips the parts
repository even when installed.

## Checks

| Id | Default | What it catches |
|---|---|---|
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

PRT003, PRT004 and PRT006 need
[electronic-parts-repository](https://github.com/jriddleyhirellogic/electronic-parts-repository);
without it they are reported as skipped.

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
  checks/         export.py, nets.py, parts.py, power.py (one function per check)
  runner.py       runs checks, applies severity overrides and waivers
  report.py       text / markdown / json output
tests/            synthetic-export unit tests + a smoke test on the committed export
```

Adding a check: write a function in `boardcheck/checks/` decorated with
`@check("ID", "title", severity)` that yields `Finding`s, and add a test in
`tests/test_checks.py`.
