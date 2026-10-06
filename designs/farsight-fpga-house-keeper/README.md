# farsight-fpga-house-keeper

This repo implements a health monitor / power control on the Proasic3 board for the Farsight Avionics board. This design controls 33 different power sources separated into 11 different power regions. To run this code on the Proasic3 (PA3), you need Libero v11.9. A UART module is implemented within health_monitor_io.sv, the source code can be obtained from Libero 11.9 CoreUART IP.   

link to requirements/boot_info: https://turionspacesys.sharepoint.com/:x:/r/sites/61500FARSIGHT/_layouts/15/Doc.aspx?sourcedoc=%7BCDF0FFBD-8F2A-4B9B-ACD9-8F783F597CDA%7D&file=pa3_reqs.xlsx&action=default&mobileredirect=true  

Each power region is booted by booting one power source at a time and waiting for a positive edge on pgood signal before moving onto next power source. If any power source fails to boot, the proasic3 will try again to boot the region up to a maximum of four times. If the FPGA or step down converters fail to boot, the system is not operational and will remain in a reset state.  

The proasic3 monitors pgood and nfault signals of all power sources (or only pgood if the source does not have an nfault signal) and looks for negative edges that last for more than 5us. This indicates a latchup event, and depending on if the region is SW controlled or HW controlled, the response will be different. A HW controlled region boots after startup, and a latchup in this region will trigger an immediate power down of all sources until power cycle/reset. A SW controlled region is turned on by the PolarFire toggling a GPIO enable pin to the Proasic3. If a latchup occurs in this region, then all power sources in that region are turned off, and the PolarFire must cycle the SW enable low then high again to turn it back on. 

## Building

Builds are driven by the `Makefile`, which invokes `libero SCRIPT:./synth_farsight_hk.tcl` with the target board and project name. `libero` must be on your `PATH` (e.g. `/opt/microchip/Libero_v11.9/Libero/bin`); the Makefile checks this before starting a build.

| Target | Description |
| --- | --- |
| `make` / `make build-fpga` | Default FM build: TMR enabled, FM RS422/TTL PA3 pinout |
| `make no-tmr` | Same as the default build but with TMR disabled |
| `make em` | FM build with the RS422/TTL PA3 pins swapped to the EM pinout |
| `make em no-tmr` | Both of the above applied to a single build |
| `make help` | List the available targets and variables |

Each build's programming file is filed under `programming_files/<variant>/` — see [Output](#output).

### Configuration variables

| Variable | Default | Description |
| --- | --- | --- |
| `TARGET_BOARD` | `a3pe3000l-fg484m` | Selects `config/<board>/`, `constr/<board>/`, and `bd/<board>/` |
| `PROJECT_NAME` | `farsight_hk` | Prefix of the generated Libero project |
| `LIBERO` | `/opt/microchip/Libero_v11.9/Libero/bin/libero` | Path to the Libero executable |
| `BUILD_TZ` | `UTC` | Timezone the build runs in — see below |

Override them on the command line, for example:

```sh
make build-fpga PROJECT_NAME=farsight_hk_test
```

### Timezone and the Synplify license

Builds are run with `TZ=$(BUILD_TZ)` (`UTC` by default). Synplify's license
checkout performs a geographic-location check that compares the client's
timezone against the license server's. The license server runs in UTC, so
building in a local timezone is refused with:

```
License checkout unsuccessful: synplifypro_actel
Based on your geographic location relative to your license server, you may not
be operating within the terms of the Synopsys Software License Agreement.
```

If the license server ever moves to a different timezone, set `BUILD_TZ` to
match it, for example `make build-fpga BUILD_TZ=America/Los_Angeles`.

Note that build folder names are timestamped using this timezone.

### Build variants

`no-tmr` and `em` work by temporarily patching a tracked source file for the duration of the build:

- `no-tmr` comments out `` `define TMR `` in `src/top.sv`, which disables the `syn_radhardlevel="tmr"` attribute on the health monitor instance.
- `em` selects `constr/<board>/io/em/io_constraints.pdc`, which assigns `rs422_ttl_bus_to_farsight_pa3` to `AA15` and `rs422_ttl_farsight_to_bus_pa3` to `Y6`. The default selects `io/fm/`, which is the other way round. Both files are committed and differ only in those two lines; nothing is edited at build time.

Each target backs the file up into the `.mkbak/` directory at the repository root, verifies the expected starting state before editing, and restores the original on exit — including when the build fails or is interrupted. The backups are kept outside `src/` and `constr/` because Libero scans those folders and would otherwise try to add the backup as a design file. If `.mkbak/` is ever left behind after a hard kill, restore its contents manually (or run `git checkout -- src/ constr/`).

`no-tmr` and `em` are modifiers rather than separate builds, so they can be combined. Naming both on the command line runs **one** build with both patches applied:

```sh
make em no-tmr
```

Order does not matter. Naming neither builds the FM TMR default.

### Output

Each run creates a timestamped project under `build/farsight_hk_<board>_<timestamp>_<commit>/`.

On success the programming file is copied to `programming_files/<variant>/`, named for what it is:

```
farsight_hk_<board>_<variant>_<timestamp>_<commit12>.pdb
farsight_hk_<board>_<variant>_<timestamp>_<commit12>.json
```

The **variant is in the filename**, not only in the folder, because a folder does not travel with a file that has been copied out, emailed or attached to a release record. The commit is twelve characters and describes the source that actually built the image; the build refuses a modified tree, and `ALLOW_DIRTY_BUILD=1` appends `-dirty` instead of refusing.

The `.json` beside it carries the variant, commit, tree state, Libero version, the pin constraints used and a SHA-256 of the image — so an image retrieved from anywhere can be checked against its record.

**`.pdb` files are not committed.** A `.pdb` is a ZIP archive: binary, already compressed, so git cannot delta it and every build would add its full size to the history permanently. Images belong in CI artifacts or a release store. The manifests are not ignored, so a build shows up as untracked — engineering builds are not committed, and a release manifest is (`BUILD-04`).

A `_tmr` suffix means TMR is enabled; `em`/`fm` select the RS422/TTL PA3 pinout:

| Command | Folder | Pinout | TMR |
| --- | --- | --- | --- |
| `make` / `make build-fpga` | `programming_files/fm_tmr/` | FM | enabled |
| `make no-tmr` | `programming_files/fm/` | FM | disabled |
| `make em` | `programming_files/em_tmr/` | EM | enabled |
| `make em no-tmr` | `programming_files/em/` | EM | disabled |

Nothing is patched to produce these. The pinout comes from `constr/<board>/io/<fm|em>/` and TMR from a generated `src/build_variant.vh`, both selected by the variant, so the tracked tree is never modified and the commit recorded in the image is true for all four.

## Changing the timing

All power sequencing times live in one plain text file: [script/auto_coder/timing.txt](script/auto_coder/timing.txt). Edit the number next to the name you want to change, save, and run `make`. No FPGA knowledge or HDL editing required.

```
FPGA_1V0_WAIT_TIME       = 25000
FPGA_RETRY_TIME          = 200000
```

**All values are in microseconds.** 1 ms = `1000`, 25 ms = `25000`, 200 ms = `200000`, 1 s = `1000000`. Underscores and commas are allowed for readability (`200_000` and `200,000` both work).

- `*_WAIT_TIME` is how long a rail is given to come up before it is treated as failed.
- `*_RETRY_TIME` is how long to wait before retrying that region after a failure.

Every build runs [script/auto_coder/timing_gen.py](script/auto_coder/timing_gen.py), which copies the numbers into the `localparam` declarations in `src/pwr_region_*_bootseq.sv`. The RTL therefore stays the single source of truth for the hardware while `timing.txt` stays the single place a human edits.

| Command | Purpose |
| --- | --- |
| `make timing` | Apply `timing.txt` to the RTL without building |
| `make timing-check` | Report whether the RTL matches `timing.txt` (exit 1 if not) |

Commit both `timing.txt` and the updated `src/` files together so the repository stays consistent. The generator errors out if a name exists in one place but not the other.
