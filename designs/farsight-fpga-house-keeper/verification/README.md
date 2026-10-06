# Adding a verification simulation

You have a housekeeper requirement you care about and you want a simulation
that checks it. This is the whole loop.

The short version: **the item is the specification.** You do not decide what
the test must prove or what to call it — that is already written down, because
writing it down is what exposed the criteria that could not be met. You
implement it.

---

## 1. Find the item

Every housekeeper requirement already has one, in
[`verification/items.yaml`](items.yaml).

```
grep -A12 "HK-LAT-01" verification/items.yaml
```

```yaml
- id:            VC-HK-0001
  verifies:      [HK-LAT-01]
  authorised_by: VVP-HK-004
  method:        SIM
  level:         subsystem
  artifact:      test/sim/latchup_tb::test_HK_LAT_01_pgood_low_after_boot
  criteria: >
    With a hardware-controlled source booted successfully, driving its
    filtered PGOOD low declares a latchup for that source within one
    filtered sample.
  requires:      [VENV-01, VENV-02]
```

Read it as instructions:

| Field | What it tells you |
| --- | --- |
| `artifact` | the file to write, and the test name inside it |
| `criteria` | what has to be true for it to pass — this is the spec |
| `level` | how much of the design must be present; `subsystem` means the whole housekeeper, not one module |
| `requires` | other requirements your evidence depends on |
| `authorised_by` | the plan clause that permits this method |

## 2. Write the test at the path the item names

The name is not yours to choose. `VVP-HK-004` requires the test name to carry
the requirement identifier, because **JUnit has no field for a requirement**
— the test name is the only channel through which the trace link survives into
the result. A test that proves `HK-LAT-01` and does not say so produces
evidence nothing can attribute.

```systemverilog
// test/sim/latchup_tb.sv
task test_HK_LAT_01_pgood_low_after_boot;
    // bring the source up
    boot_source(SRC_DDR8);
    assert_booted(SRC_DDR8);

    // the stimulus the criteria names
    drive_pgood(SRC_DDR8, 1'b0);

    // the criteria, as an assertion, with the number from the requirement
    wait_filtered_samples(1);
    assert (latchup_declared(SRC_DDR8))
        else $error("HK-LAT-01: no latchup within one filtered sample");
endtask
```

## 3. Check that it is wired in

```
cd ../farsight-verification
python3 tools/run.py artifact-presence --about VC-HK
```

Before you write it:

```
FAIL  VC-HK-0001  names test/sim/latchup_tb, which does not exist;
                  the test it specifies has not been written
```

After, it drops off the list. This also catches the quiet failure later: if
somebody renames the test, the suite still passes — the test still runs — but
the citation now points at nothing and the requirement identifier stops
reaching the result. Nothing else in the framework goes red for that.

## A test reports what happened

**Never mute a test.** Not `expect_fail`, not `expect_error`, not `skip`, not
`xfail`. If the requirement is not met, the test fails and stays failing.

This is worth stating because the framework has something that *looks* like an
exemption and is not. `expect: FAIL` on an item is a labelling rule and nothing
else: if a requirement's status is GAP, DEFECT or AMBIG, the item verifying it
has to say so. It does not suppress anything, does not change whether the test
runs, and does not change whether its failure counts. It exists so that a
failing test is recorded as a known shortfall rather than quietly weakened
until it passes.

The muting lives in the test framework, and it does hide things.
`test_hk_src_06` was written with `expect_error=AssertionError` to hold a known
defect, and the suite read green while a single power source could stall the
boot sequence forever. That is the failure mode. `test_evidence_rules.py`
refuses any of these constructs in a `test_hk_*.py` file now.

Known failures are told apart from new ones **outside** the test, by comparing
the failing set against the items declaring `expect: FAIL`:

| | |
| --- | --- |
| fails, `expect: FAIL` declared | known shortfall, still open |
| fails, not declared | regression -- blocks |
| passes, `expect: FAIL` declared | fixed; update the item and the requirement status |

The last row is the ratchet, and it has already fired once. When the boot
timeout counter was widened, `test_hk_src_06` reported "passed but we expected
an error", which is what forced the item and `HK-SRC-06`'s status to be brought
up to date instead of left stale.

## 4. What your test must assert about itself

Two requirements are on the *environment*, not the design, and your test has
to hold them up (framework I.6 — a test states its own preconditions):

- **`VENV-02`** — run at the **synthesis parameter values**. This is not
  bureaucracy. `WAIT_TIME_MULT_FACTOR` defaults to 50 in `src/top.sv`; the
  existing development bench overrides it to 3. At 3 the boot timeout works;
  at the flight value of 50 it is unreachable because the threshold exceeds
  the counter maximum. Every test passed. That is `HK-F-01`, and the override
  is why nobody saw it.

  Assert the parameter inside the test and fail if it has been overridden. Do
  not accept it as a precondition somebody is supposed to remember.

- **`VENV-01`** — the environment must be able to force each `PGOOD` and
  `nFAULT` **independently, including to states the hardware cannot produce**.
  Most off-nominal requirements are only reachable from states the board will
  not enter on its own, so a bench restricted to physically achievable
  combinations cannot exercise them at all.

## 5. What is not there yet

There is **no verification harness**. No runner, no JUnit output, no way to
execute these and have the result reach a dashboard. The benches in
`test/sim/` are development material and are deliberately not cited by any
item — a script no item cites is engineering material, not evidence
(framework VII.6).

So step 3 is currently the end of the loop: you can show the artifact exists
and is named correctly, and no further. `D3` (has it run) and `D4` (did it
pass) have no checker because they would have nothing to read.

That is the next thing to build, and it is a decision about the environment —
which simulator, which harness — that no plan makes for you (framework II.4).

---

## Why the item is written before the test

It reads backwards until it saves you. Writing the criterion for
`HK-SRC-05` is what surfaced that a `PGOOD` already high when the enable
asserts must **not** declare success: a design sampling the level instead of
the edge would otherwise pass. Writing `HK-SEQ-09`'s is what surfaced that it
is indistinguishable from `HK-SEQ-03` unless the failed case is exercised.

Those are design questions found while writing a sentence, at no cost. Found
while debugging a testbench they cost a week, and found after delivery they
cost more than that.

---

## Running a test

From a fresh clone:

```
make setup          # virtualenv at .venv-verif, plus Verilator
make test           # the whole suite
```

`make setup` takes a few minutes the first time -- it installs Verilator via
micromamba, without root. If you already have 5.020 or later on your PATH:

```
make setup SETUP_ARGS=--skip-verilator
```

**If `python3 -m venv` does not work on your machine**, it carries on anyway.
Debian and Ubuntu split `ensurepip` into a separate `python3.N-venv` package,
and without it `venv` fails from inside a half-built directory with a wall of
text whose obvious remedy needs root. `make setup` checks first, offers the
`apt` line for anyone who has `sudo`, and otherwise falls back to a micromamba
Python -- which is the same mechanism it already uses for Verilator. The
virtualenv lands in the same place either way.

### One more prerequisite: the vendor IP

`src/top.sv` instantiates a Microchip DirectCore, so **every simulation needs
the generated IP** and it is not in this repository -- the RTL is marked *Actel
Proprietary and Confidential*, so only a digest of it is committed.

```
make ip          # needs Libero; no synthesis licence required
```

Once, per clone. `make test` checks for it first and stops with a single
message if it is missing, rather than letting every module discover it
separately.

**If `make ip` says the vault does not hold a core**, Libero is looking in the
wrong place. The vault location is a per-user setting in `~/.actel/ipmgr.ini`,
outside this repository, and Libero 11.9 has no Tcl command to change it -- so
a machine with the vault installed can still fail. `make ip` checks this before
Libero starts, finds a vault on the machine that has the core, and prints the
one line to change. It does not change the setting itself: every project on
the machine shares it.

It also stops if the configured vault holds the core but **you cannot write
to it**. Libero 11.9 silently falls back to `~/.actel/vault` in that case and
then reports the same "Cannot find Spirit core configuration file", so a vault
installed by another user looks exactly like a missing one.

**Over ssh, or anywhere without a display**, Libero 11.9 exits with "cannot
connect to X server" even in script mode. With `DISPLAY` unset `make` runs it
under `xvfb-run` when that is installed (`apt install xvfb`); `LIBERO_X=`
turns this off.

**Without Libero on that machine**, take it from one that has it:

```
make ip-import FROM=~/other-checkout/verification/ip
make ip-import FROM=host:~/checkout/verification/ip     # anything scp understands
```

The copy is checked against this repository's component definitions before it
is accepted, and refused if it does not match -- so this is not "trust a
directory somebody sent you". A digest of the IP is committed even though the
RTL cannot be, which is exactly what makes a copy verifiable.

**Libero must be 11.x.** ProASIC3L support ends with 11.9; later versions
dropped the family. The Makefile finds an 11.x install by itself and refuses a
newer one -- which matters, because `synth.tcl` asks for `-min_version 11` and
tests `toolversion < min_version`, so Libero 2024.1 reports 2024, passes, and
then fails somewhere deep in the flow with an error about the device rather
than about the tool.

`make test-fast`, `make coverage` and `make check` need none of this.

### Then

| | |
| --- | --- |
| `make test` | the whole suite, measuring code coverage and writing its report |
| `make test FSVERIF_COVERAGE=0` | the same without code coverage, about six times faster |
| `make test TEST=test_hk_src_02` | one module |
| `make test WAVES=1` | with waveforms |
| `make test-fast` | only the checks that need no simulator, and the inspections, in seconds |
| `make inspect` | the inspections alone: the design as built, read rather than simulated |
| `make check` | whether the results should block a merge |
| `make gui-web` | the app in a browser tab, inside VS Code -- see below |
| `make sarif` | failing tests and unreached lines, for VS Code's SARIF Viewer |
| `make coverage` | where each requirement stands |
| `make code-coverage` | what the tests reached in the design |
| `make clean` | remove simulation products, results and coverage |

`make test-fast` is worth running often. It checks that every item names a test
that exists, that no test mutes its own result, that the build variants stay
distinct and that `fsverif.pins` matches the device's port list -- the kinds of
mistake that are otherwise found by whoever runs a command next.

### Inspections

An `INSP` item names a test under `test/inspect/`, e.g. VC-HK-0093 names
`test/inspect/protect.py::test_HK_PROT_01_short_outputs_exist`. An inspection
checks a structural claim -- this output exists, is on that ball, is driven only
from there, reaches that circuit on the board -- by reading the design as built:

| Source | Read with |
| --- | --- |
| RTL (`src/*.sv`) | `fsverif.design`: `ports()`, `drivers(signal)`, `connected_through(signal)` |
| Pin constraints (`constr/.../io/{fm,em}/io_constraints.pdc`) | `fsverif.design.pin_constraints(variant)` |
| Schematic (`verification/board/CM-03545.json`) | the `board` fixture: an `altium_sch_json.Design`, e.g. `board.net_of("U2", "C3")` |

No simulator, so they take milliseconds; `make inspect` runs them, and so do
`make test-fast`, every run from the app, and CI. Their results go to
`verification/results/results-inspect.xml`, where the gate, `make coverage` and
the app treat them as they treat a simulation's. `make inspect` judges them as
the gate does: an inspection failing where its item declares `expect: FAIL` is
a known shortfall and passes the target; a new failure, a stale declaration or
no results at all fails it (`check_results.py --only results-inspect.xml`).

Inspections that need the design's structure rather than its text read it as
Verilator elaborates it (`fsverif.elaborated`, the `netlist` fixture): the same
sources, variant and vendor IP the simulation compiles, written as JSON with
`--json-only` in a fraction of a second and cached by content. It gives every
module per parameterisation, its ports, parameters and instances, and every
always block with its sensitivity and the registers it assigns; `origin()` and
`uses()` follow a signal up to where it comes from, or down to where it is used,
across instance ports. This needs Verilator on `PATH` (`make inspect` sets it)
and the vendor IP, as the simulation does.

Written so far: HK-PROT-01 (`protect.py`); HK-IO-01, -02, -08 and -09
(`pins.py`); HK-TLM-04 and -06 (`telemetry.py`); HK-CLK-01 (`clock.py`);
DRV-HK-05 (`reset.py`); HK-IO-04 (`capture.py`). HK-IO-08's naming transform --
which net a port's name implies -- is written down in `pins.py` and in the
requirement's evidence.

#### Inspecting a build

Six inspections read a Libero build of the flight variant rather than the
source: HK-IMPL-01, -02, -03, -04 and -18 (`build.py`) and HK-TLM-08
(`version.py`).

```
make build-fpga                       # or any existing build under build/
make inspect-build                    # the newest flight build
make inspect-build BUILD=build/<dir>  # a particular one
```

They read the build directory (synthesis project, report and EDIF netlist;
place-and-route report), the image and manifest filed under
`programming_files/fm_tmr/`, and the sources at the commit the manifest
records -- the delivered build, not the working tree (`fsverif.delivered`). A
build of any other variant is refused. TMR is checked from the netlist's
structure (`fsverif.edif`): every flip-flop must be one of three driving one
majority voter. Results go to `verification/results/results-inspect-build.xml`,
judged as `make inspect`'s are. CI runs them in the flight image job, straight
after the build, and keeps the result with the image.

Without a build these six are not collected at all, so `make inspect` and the
app leave their items reading "not run" -- not skipped, which the gate would
count as a requirement test that did not report. A module is named for what it
inspects (`protect.py`), as the item names it, and is held to the same rules as
a simulation module: the test the item names must exist, every `test_HK_` test
must be named by an item, and nothing may mute its result. An item whose
inspection is not written yet reads "no test yet", as before.

Show that an inspection can fail before trusting that it passes: feed it the
wrong ball or the wrong rail and read the message.

### Reviewing a run: the app

The app is served to a browser tab, so it runs inside VS Code over Remote-SSH,
where no window can open:

```
make gui-web
```

It prints an address with a token -- `http://127.0.0.1:8765/?token=...` --
and VS Code forwards the port by itself. Open it with **Ctrl+Shift+P, "Simple
Browser: Show"** and paste the address, or Ctrl+click it for a browser outside
VS Code. Ctrl+C in the terminal stops it. It needs nothing installed beyond
`make setup`, and it listens only on this machine: the token is what stops
anybody else logged in to a shared machine from starting runs as you. Start it
from a VS Code terminal and **Open source** opens files in that VS Code window.

Its pages are built from `fsverif.results`, `fsverif.codecov` and
`fsverif.render`, the same code `make check`, `make coverage` and `make sarif`
use, so the app cannot disagree with the gate:

| Page | What it shows |
| --- | --- |
| Dashboard | Tests passing, failing and not run; whether anything would block a merge; requirement results per area; how the Jama requirements stand; what needs attention; values still pending systems confirmation; the last run; code coverage |
| Traceability | Every Jama requirement the housekeeper answers to (`docs/requirements/jama.yaml`), judged by the housekeeper requirements under it: **passing** when every one is, **failing** when any has a failing test, **partly tested** when any has no test or no result yet, and **no local requirement** when nothing cites it. Beside it: the Jama wording, and each housekeeper requirement under it with its tests, their results and its findings. This is the functional coverage of the Jama set |
| Tests | Every requirement test, filterable by result, area, module and pending values. Beside it: the result, the failure message, **what the test measured**, the requirements it verifies with their wording and status, the findings they cite, and the items. Open the test in VS Code, or rerun its module |
| Requirements | All of them, by result, status, area and Jama parent, with a mark per test (✓ passing, ✗ failing, · not run); each with its Jama parents, the tests behind it, the findings it cites, and its whole entry from the requirements document |
| Findings | Every finding by severity, with the requirements citing it, their tests' verdicts, and the finding itself |
| Coverage | Line, branch, expression and toggle coverage; source files by lines nothing reached; the annotated source with those lines in red (F8 for the next). Every run measures it; rebuild the report from here |

**Passing, failing, not run** is what each test did. Beside a failure the
app says whether it was **expected** -- the test checks a requirement already
recorded as not met (`GAP`), and its item declares `expect: FAIL` -- or **new**.
Only results that would stop a merge are flagged: a new failure, a pass whose
item still expects a failure (fix the item and the requirement's status), and a
skip. That is the same judgement as `make check`, which uses its own words for
it: *known shortfall* for an expected failure, *regression* for a new one,
*stale* for a pass the item does not expect.

Runs start from **Run**: the whole suite, the modules with failures, the
selected test's module, the fast checks, or the whole suite without coverage.
Every simulation run measures code coverage and writes the report after it,
unless it is the run without coverage. Progress is
live, **Cancel** stops pytest, its workers and every simulator they started, and
the output is in the console. A run made from a terminal -- `make test` -- is
picked up on its own. `/` jumps to any page, Jama requirement, test,
requirement or finding; every identifier in a detail pane is a link.

The Jama snapshot is refreshed from a Jama trace-view CSV export with
`.venv-verif/bin/python -m fsverif.jama --csv <export.csv>`, run in
`verification/`. It keeps the hand-written `note:` of each entry and refuses a
text with a mangled character it cannot account for (the export turns ≥ and ≤
into "?").

### Reviewing a run: SARIF

```
make sarif
```

The way ts-rtl-check reports lint: two SARIF files for VS Code's **SARIF
Viewer** extension (`ms-sarifviewer`), each result a line in a panel that jumps
to its source.

| File | What is in it |
| --- | --- |
| `verification/results/fsverif.sarif` | Every requirement test that did not pass, at the test: a regression, stale declaration or skip as an error, a known shortfall as a warning, a test with no result as a note. The message carries the requirement, its findings and the failure |
| `verification/coverage/coverage.sarif` | Every design line nothing reached (a warning), and every line reached with points nothing hit (a note), at the line in `src/`. Written once coverage has been measured |

Verdicts come from the same code as `make check` and requirement stages from
the same code as `make coverage`, so the app cannot disagree with either.
**What the test measured** is the values it logged ("last off 5.13 us after the
pin"), kept in `verification/results/log-<module>.txt` beside the JUnit results
(`fsverif.runlog`); a pass shows by how much it passed, not only that it did.

### Cleaning up

`verification/sim_build/` grows fast. Each build directory is keyed by module,
simulator, visibility and whether coverage was on -- deliberately, so a
debugging rerun cannot silently reuse a lean build -- and a coverage build is
about 240 MB. Seven modules measured both ways came to **3.3 GB**.

```
make clean          simulation products, results, coverage   -> seconds to rebuild
make clean-builds   Libero project directories under build/  -> minutes, needs a licence
make distclean      both, plus the virtualenv                -> make setup, needs network
```

**None of them removes `verification/ip/`.** It is generated, but it is the one
generated thing that needs Libero to restore, so a `clean` that took it would
leave anyone without a synthesis licence unable to run a single simulation and
with no way back. `make ip` replaces it in place, which is the only safe moment
to remove it.

`programming_files/` is left alone too: those are outputs somebody may still
need, and they are not rebuildable from an arbitrary checkout -- the tree has
to be at the commit the image records.

### Code coverage

Measured on every run by default, and the report written after it:

```
make test                        measure, then report
make test FSVERIF_COVERAGE=0     neither -- about six times faster
make code-coverage               rebuild the report from the data already measured
```

Instrumentation costs about six times the run: one module took 349 s with
coverage and 60 s without. **Every run starts by clearing the last run's
coverage**, so the report always describes the latest run and nothing older:
after `make test TEST=<module>` it is that module's coverage alone, and after a
run with `FSVERIF_COVERAGE=0` there is no report rather than a stale one. The
web app's runs do the same.

Three outputs: a summary, per-file counts of lines nothing reached, and
annotated source under `verification/coverage/annotated/` where a `%` in the
margin marks a line that was never reached. An lcov `.info` file is written
alongside for CI to render in the merge request.

**A high number here is not evidence the design was exercised.** `HK-F-01` was
a comparison that could never be true -- `cntr >= 76` on a counter saturating
at 63 -- and line coverage called that line covered, because it executed every
cycle. It simply never took the branch.

Two consequences worth knowing. `--coverage-fsm` is deliberately not enabled:
it produces **zero** points on these enum state machines, so it would report
FSM coverage as complete while measuring nothing. And `%` in the annotated
source means "never reached" only because the report runs with
`--annotate-min 1`; Verilator's default of 10 marks a line executed twice,
which reads as uncovered and is not.

### The board model

**Do not drive the power-good or fault inputs from a test.** They are driven
by a generated model of the board's power rails, and a test that also writes
them is fighting a continuous assignment it will not win.

The device cannot boot without that model. Every region of the sequence
enables its rails and then waits for them to report good, so a power-good
input held at a constant 1 never produces the rising edge the device is
waiting for, and one held at 0 waits forever. Holding them all high reached
**one enable of thirty-three**.

The model is built at every run from two committed files, and checked against
a third:

| File | What it holds | Where it came from |
| --- | --- | --- |
| `board/CM-03545.json` | the avionics board's schematic, every net and pin | Altium export of the CM-03545 project, written by `ts-altium-sch-json`'s export script and read through its `altium_sch_json` package; committed under a stable name. Which schematic drawing and revision it is comes from the project's parameters inside it: `altium-sch-json verification/board/CM-03545.json` prints `drawing CM-03543`, `revision 2` |
| `board/topology.json` | which enable brings up which regulator, and which power-good comes back | extracted from the schematic export |
| `board/delays.yaml` | how long each regulator family takes, and the capacitor fitted to each rail | regulator datasheets |

The two are joined to the RTL by **ball number**, from
`constr/a3pe3000l-fg484m/io/fm/io_constraints.pdc`. Nothing is matched by name:
the schematic calls the LVDS rail `R_3V3_MISC_EN`, and only the ball says it
is the same wire as `lvds_en`.

The delays are per-rail and not a blanket value, and that is the point. With
a 2 ms blanket the DDR8 region stalled and looked like a design defect; with
the fitted capacitors it boots, because what decides the sequence is the delay
of each rail *relative* to the others. Every number carries its citation in
`delays.yaml`, including the four rails that are honestly uncharacterised.

To fail a rail, drive its bit in one of three vectors — they are different
failures:

```python
from fsverif import board

bit = board.index(board.model())["ddr8_pgood_2v5"]
dut.rail_fail.value  = 1 << bit   # never reaches regulation: power-good stays low
dut.rail_fault.value = 1 << bit   # overcurrent trip: the part's fault pin asserts
dut.rail_force.value = 1 << bit   # power-good held HIGH, whatever the enable does
```

`rail_force` is a state no working board produces -- a PGOOD already high when
the source is enabled, or one that stays high after it is disabled -- and it is
what `VENV-01` asks for. It wins over `rail_fail`. Every test that sets one of
the three should set all three, because they persist from one cocotb test to
the next within a module.

Holding DDR8's 2V5 rail down makes its source time out at 25 ms, and the region
retries three times and is then declared failed (`test_hk_reg_retry`). Before
the source counter was widened it stalled the sequence permanently instead --
`HK-F-01`.

#### When the schematic changes

Export the released project with the script in
[ts-altium-sch-json](https://gitlab.com/turionspace/fpga-projects/tools/ts-altium-sch-json)
(its README says how), read the warnings file it writes beside the export, and
replace `board/CM-03545.json` with the new export, keeping the name. Then:

```
make board-check     # what a change obliges of the testbench (also run in CI)
make board           # re-extract, once you have decided it is right
```

Commit the export and the re-extracted topology together, with the drawing
revision in the commit message (`altium-sch-json` prints it). `make board`
records which export the topology came from, by path and SHA-256, in
`topology.json`. To check an export without replacing the committed one,
`make board-check SCHEMATIC=<file>`.

This compares the extracted *topology*, not the file. A re-export that renames
every sheet and reorders every list reports nothing; one that refits a
regulator, moves an enable, or changes a timing capacitor names the rail and
says what it obliges — because a capacitor change regenerates the model and
needs no thought, while a pairing change means tests that booted the device
may now be exercising something else.

### Generated vendor IP

The design instantiates Microchip DirectCores. Their RTL is marked *Actel
Proprietary and Confidential*, so it is **generated, not committed**:

```
make ip          # generate every core, and write its lockfile
make ip-check    # confirm what is generated is what the design asks for
```

`make ip` needs Libero but not a synthesis licence, and takes seconds.
`make ip-check` needs neither, so a checkout can always tell whether its IP is
current even where it could not produce any.

**The lockfiles are committed; the RTL is not.** A digest of the IP is not the
IP. Committing it lets two engineers who generate independently prove they got
the same core, and lets a reviewer see which core the evidence was produced
against, without the repository carrying vendor RTL. This works because
generation is deterministic: three builds of one commit produced byte-identical
sources, differing only in a `// Created by` timestamp, which the digest
normalises away.

**Adding a core is dropping a `*.tcl` into `bd/<board>/components/`.** Nothing
in the Makefile, the generator or the verification environment names a
particular core: components are discovered from that directory, and each one's
source list is read from the manifest Libero writes beside it. The next
`make ip` picks it up.

`make ip-check` fails, with the reason, when:

| | |
| --- | --- |
| a core is defined but never generated | someone added a definition |
| a core is generated but no longer defined | someone removed one, RTL left behind |
| the core version in the definition changed | design moved, IP did not |
| a parameter changed at the same core version | the subtle one — nothing looks different |
| the generated RTL was edited by hand | generated IP is not a place to make fixes |
| the lockfile is missing | no record of what the programme agreed on |

Files that instantiate device hard macros are held back from software
simulators and **reported, not silently dropped** — a file dropped in silence
is a design compiled without a block somebody believes is present.

### Which simulator, and why

**Verilator**, for everything in this repository. The housekeeper's only
vendor core is unencrypted, so nothing here needs a simulator that can decrypt
IEEE P1735, and Verilator is the fastest option available without a licence.

The environment can drive others -- a DUT pins one with
`sim.run(..., simulator="questa")` -- and a DUT that asks for a simulator it
cannot have now **fails rather than quietly getting the default**. A testbench
pins a simulator because the default cannot handle it, so substituting the
default produces either a confusing failure about a missing module or, worse,
a pass against something that is not the design.

The one thing Verilator cannot do here is the `FIFO4K18` hard macro, and the
design elaborates it away. If a future build enables the core's FIFOs, that
DUT pins Icarus or Questa and the ProASIC3 library from Libero 11.9 comes into
play.

#### Encrypted vendor IP -- assessed, and not needed here

The PolarFire design instantiates four encrypted cores. This one does not, so
the following is recorded for whoever builds that environment rather than
acted on here:

- Libero's **ModelSim and ModelSimPro are 32-bit in every version installed**,
  including Libero 2024.1. cocotb loads its VPI library into the simulator's
  own process, so a 32-bit simulator cannot be driven by a 64-bit cocotb.
  They are not the answer.
- Libero SoC v2024.1 also ships **QuestaSim Pro Microchip Edition-64**, which
  is 64-bit. cocotb drives it: a probe compiled, elaborated and ran a test
  green against it.
- All four encrypted cores carry a `key_keyowner="Mentor Graphics
  Corporation"` block, so Questa can decrypt them. A probe compiled the
  encrypted DDR4 controller successfully and the library showed decrypted
  protected design units. **No file carries a Verilator key**, so Verilator
  cannot compile those cores at any effort.
- Device support splits the two: ProASIC3 is Libero 11.9 only, which bundles
  no 64-bit simulator; PolarFire is 2024.1, which does. That the housekeeper
  needs no decryption and has no 64-bit vendor simulator is luck, not design.

Unmeasured, and worth measuring before relying on it: Questa's speed on a
design of this size, against the sixteen minutes Verilator takes below.

### What a run costs, and where to put a new test

**A boot costs about 42 seconds of wall time; a build costs under ten.**
Measured on the same module, twice each: cold 91 s and 95 s, warm 85 s both
times, and it boots twice.

That ratio decides how the suite is laid out, and it is the opposite of what
you would guess. Grouping tests into fewer, larger modules to share a build
saves those few seconds per module and nothing else -- the boots still happen, one
after another, in a single process. Keeping them in separate modules lets them
run **at the same time**, and the suite then costs its slowest module rather
than the sum of all of them: 253 s became 94 s with no change to what is
simulated.

So:

> **Put tests in separate modules so they run at the same time, and share a
> boot inside a module only where the tests are claims about the same event.**

The first half is for the machine. The second is the part that needs thought,
and the question to ask is not whether a test is destructive -- it is whether
the *next* test can use the device it is handed. Three different answers, all
of which mean a fresh boot:

| | why it needs its own boot |
| --- | --- |
| `test_hk_lat_01` | it leaves the device held in reset -- `critical_latchup` is set at `health_monitor.sv:723` and gates `rstn` into all eleven region state machines, and only `!rstn` at `:700` clears it |
| `test_hk_src_02` | asserting reset *is* the requirement, so the boot is the test |
| `test_hk_src_06` | its rail must be held low before reset release, so the stimulus has to precede the boot |

Only the first of those spoils anything for a neighbour. The other two simply
cannot start from a device somebody else booted.

The way to share, when you can, is to share the **observation** rather than
the device. `test_hk_seq_initial` records one boot and three tests read the
record: `HK-SEQ-01` checks when the first enable asserted, `HK-SEQ-02` checks
the order the regions started in, `HK-SEQ-08` checks that they all did. A
record of the past cannot be disturbed by the test that reads it, so the three
are independent of each other in a way that three tests sharing a live device
would not be. Three requirements, one boot.

`test_hk_src_02` takes **94 seconds** for two boots. It took 16 minutes for
one before the clock moved out of Python and the design stopped being built
with every signal exposed.

`HK-SEQ-01` holds the boot sequence off for 1 s after reset release, and at
the flight `WAIT_TIME_MULT_FACTOR` of 50 that is 50 million clocks. `VENV-02`
requires the environment to run at synthesis parameter values, and the
archived development benches avoided this cost by overriding the factor to 3
— which is exactly what hid `HK-F-01`, a boot timeout unreachable at the
flight value because the threshold exceeds the counter maximum.

So the shortcut is not available, and everything below makes the *same*
simulation faster rather than changing what is simulated.

At 42 s a boot and sixteen workers, the 127 items of this plan come to roughly
six minutes if each needs its own -- which is why there is no split into fast
and slow pipelines. There may have to be one later; there is no case for it
now, and a split nobody needs is a second thing to keep correct.

**Two things cost most of the time, and both were measured.**

| | cycles/s |
| --- | ---: |
| Verilator alone, no VPI | 4,729,699 |
| with `--public-flat-rw` | 241,592 |
| cocotb, clock in Verilog | 239,202 |
| cocotb, clock in Python | 62,429 |

**The clock.** `cocotb.Clock` toggles from a Python coroutine, which costs a
callback on every edge — 120 million of them for this test. The clock now
lives in a generated wrapper and Verilator runs it freely.

**Waking on every edge.** `ClockCycles(clk, 50_000_000)` wakes cocotb fifty
million times; `advance(clk, seconds=1.0)` wakes it once. Use `advance` for
anything longer than a few hundred cycles.

**Every signal made public.** `--public-flat-rw` blocks most of Verilator's
optimisation, and cocotb's runner adds it unconditionally — though cocotb's
own documentation calls it optional and notes the penalty. Only the device's
pins are public now, named in a generated config file so that nothing has to
be written into the RTL.

### Seeing inside, when a test fails

```
pytest tests/test_hk_src_02.py                          # 51 s, pins only
FSVERIF_VISIBILITY=all pytest tests/test_hk_src_02.py   # 537 s, everything
FSVERIF_VISIBILITY=depth:2 pytest ...                   # two levels down
WAVES=1 pytest ...                                      # trace file
```

Builds are kept apart by visibility, so rerunning a failure with more of the
design exposed rebuilds rather than quietly reusing the lean one.

**Reach for waves first.** Verilator's tracing does not go through VPI, so
`WAVES=1` shows internal signals at full speed. `FSVERIF_VISIBILITY=all` is
for when a test needs to *interact* with something internal, not merely see
it.

**Visibility changes what can be observed, not what is computed.** A test that
passes lean and fails at `all` has not been made to fail by the setting.

**Coverage is unaffected** — it is compiled into the simulation rather than
read over VPI, so a lean build still produces line, branch, expression and
toggle coverage with full per-instance hierarchy. Coverage instrumentation
costs roughly 6x on its own; it is on by default, and `FSVERIF_COVERAGE=0`
turns it off for a quick run.

### Two things this environment enforces

**Reach only for pins.** `fsverif.pins.boundary(dut, name)` refuses anything
that is not one of the device's 98 pins. cocotb builds with
`--public-flat-rw`, so `dut.rstn` — the *internal* synchronised reset —
resolves as readily as `dut.arstn`, the actual pin. The first run of
`test_hk_src_02` drove `rstn`, tested a device the board cannot produce, and
took a sixteen-minute run to diagnose.

**A test that cannot fail is not evidence.** `test_hk_src_02` asserts that
enables were high *before* the reset, so that a device which never booted
cannot pass by having nothing to clear. That assertion fired on the first run
and was correct to.
