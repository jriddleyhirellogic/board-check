#!/usr/bin/env python3
"""What the requirement tests reached in the design.

    make test                        clear, measure, then report (coverage is on by default)
    make code-coverage               rebuild the report from the data already measured
    code_coverage.py --clear         remove the data and the report

Every simulation run starts by clearing (`--clear`), so the report describes
that run and nothing older: a one-module run reports that module's coverage
alone, and a run without coverage leaves no report rather than a stale one.

Three outputs, because three people want different things:

- a **summary** per source file, for deciding what to test next;
- **annotated source**, which is the only one that answers "which lines did
  nothing reach" -- open `verification/coverage/annotated/<file>` and the
  lines nothing reached carry a `%` in the margin;
- an **lcov `.info`** file, which GitLab renders in the merge request diff.

One thing this cannot tell you, and it is the important one.

`HK-F-01` was a comparison that could never be true: `cntr >= 76` on a counter
saturating at 63. **Line coverage called that line covered**, because it
executes every cycle -- it simply never took the branch. Branch coverage is
closer, but a branch not taken looks the same whether it is unreachable or
merely untested.

So a high number here is not evidence that the design was exercised. It is
evidence that lines ran. State and transition coverage over the boot sequence
FSMs has to be authored as cover properties; `--coverage-fsm` produces zero
points on these enums, which is why `fsverif.sim` deliberately omits it.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

VERIF = Path(__file__).resolve().parent
COVERAGE = VERIF / "coverage"
REPO = VERIF.parent

#: Verilator's own summary lines, e.g. "  line      : 54.8% (  617/ 1126)".
SUMMARY = re.compile(r"^\s*(\w+)\s*:\s*([\d.]+)%\s*\(\s*(\d+)/\s*(\d+)\)")

#: Sources that are not ours to cover. Vendor IP is generated from a Microchip
#: component definition and is not edited here, so its uncovered lines are
#: noise in a report about the housekeeper's own logic. `VENV-04` asks the
#: environment to declare the scope it measured, and this is that declaration.
NOT_OURS = ("UART0", "CoreUART", "Rx_async", "Tx_async", "Clock_gen",
            "fifo_", "tb_top", "board_model")


def tool(name: str = "verilator_coverage") -> str:
    found = shutil.which(name)
    if not found:
        raise SystemExit(
            "%s is not on PATH. It ships with Verilator; the verification "
            "toolchain installs both:\n  make setup" % name)
    return found


def data_files(where: Path) -> list:
    found = sorted(where.glob("*.dat"))
    if not found:
        raise SystemExit(
            "no coverage data in %s. Nothing has been measured, and a report "
            "over no data would read as zero coverage rather than as no "
            "measurement.\n  make test   (coverage is measured by default)" % where)
    return found


def run(args: list) -> str:
    done = subprocess.run(args, capture_output=True, text=True)
    if done.returncode != 0:
        raise SystemExit("%s failed:\n%s" % (args[0], done.stderr.strip()))
    return done.stdout + done.stderr


def ours(path: Path) -> bool:
    return not any(mark in path.name for mark in NOT_OURS)


#: A line Verilator annotated with a hit count, covered or not.
#:
#: The margin is one character -- `%` where the count is below
#: `--annotate-min`, `~` where only some of the line's points are, a space
#: otherwise -- followed by a zero-padded count. Matching only `%` or a leading
#: digit misses every covered line, which made every file report as entirely
#: unreached; leaving out `~` dropped every partly covered line from the
#: counts, 417 of them in one measurement.
COUNTED = re.compile(r"^([%~\s])(\d{6,})\s")


def uncovered(annotated: Path) -> dict:
    """(never reached, counted, partly reached) lines per source file.

    `%` in the margin does **not** mean "never reached". It means "fewer than
    `--annotate-min` times", and the default is 10 -- so a line executed twice
    is marked, and a report that read `%` as zero overstated the uncovered
    count here threefold. This runs with `--annotate-min 1`, which makes the
    mark mean what a reader assumes it means, and the count is checked rather
    than trusted.
    """
    per_file = {}
    for source in sorted(annotated.glob("*")):
        if not source.is_file() or not ours(source):
            continue
        missed = counted = partly = 0
        for line in source.read_text(encoding="utf-8",
                                     errors="replace").splitlines():
            match = COUNTED.match(line)
            if not match:
                continue
            counted += 1
            if int(match.group(2)) == 0:
                missed += 1
            elif match.group(1) == "~":
                partly += 1
        if counted:
            per_file[source.name] = (missed, counted, partly)
    return per_file


#: What a run leaves in the coverage directory, besides the raw data.
REPORT = ("summary.json", "coverage.info", "coverage.sarif", "annotated")


def clear(where: Path = COVERAGE) -> int:
    """Remove the data and the report, so the next run's report is its own."""
    removed = 0
    for f in where.glob("*.dat"):
        f.unlink()
        removed += 1
    for name in REPORT:
        p = where / name
        if p.is_dir():
            shutil.rmtree(p, ignore_errors=True)
        elif p.exists():
            p.unlink()
    return removed


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--data", type=Path, default=COVERAGE)
    ap.add_argument("--out", type=Path, default=None,
                    help="where to write the report (default: alongside the "
                         "data, in verification/coverage/)")
    ap.add_argument("--clear", action="store_true",
                    help="remove the coverage data and report, and write nothing")
    args = ap.parse_args(argv)

    if args.clear:
        n = clear(args.data)
        print("coverage cleared: %d data file(s) and the report removed" % n)
        return 0

    out = args.out or args.data
    files = [str(f) for f in data_files(args.data)]
    binary = tool()

    annotated = out / "annotated"
    shutil.rmtree(annotated, ignore_errors=True)
    annotated.mkdir(parents=True, exist_ok=True)

    # --annotate-min 1 so that a `%` in the margin means a line nothing
    # reached. At the default of 10 it means "fewer than ten times", which
    # reads as uncovered and is not.
    output = run([binary, "--annotate", str(annotated), "--annotate-all",
                  "--annotate-min", "1", "--annotate-points", *files])
    info = out / "coverage.info"
    run([binary, "--write-info", str(info), *files])

    print("Measured over %d test module(s): %s\n"
          % (len(files), ", ".join(Path(f).stem for f in files)))

    kinds = {}
    for line in output.splitlines():
        match = SUMMARY.match(line)
        if match:
            kind, pct, hit, total = match.groups()
            kinds[kind] = [float(pct), int(hit), int(total)]
            print("  %-8s %6s%%  %s of %s points" % (kind, pct, hit, total))

    per_file = uncovered(annotated)
    # The same figures, for `make gui-web` to read without running Verilator's
    # tools itself.
    (out / "summary.json").write_text(json.dumps({
        "modules": [Path(f).stem for f in files],
        "kinds": kinds,
        "files": {name: list(counts) for name, counts in per_file.items()},
    }, indent=1), encoding="utf-8")
    worst = sorted(per_file.items(), key=lambda kv: -kv[1][0])
    print("\nPer file, lines nothing reached and lines only partly reached "
          "(vendor IP and testbench excluded):")
    for name, (missed, total, partly) in worst:
        if missed or partly:
            print("  %-34s %4d of %4d lines unreached, %4d partly"
                  % (name, missed, total, partly))
    if not any(missed for missed, _, _ in per_file.values()):
        print("  every counted line was reached at least once")

    print("\n  annotated source  %s" % annotated)
    print("  lcov report       %s" % info)
    print("\nA line marked % in the annotated source was never reached. A "
          "line with a count was reached, which is not the same as having "
          "been tested -- HK-F-01 was a comparison that could never be true, "
          "on a line that executed every cycle.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
