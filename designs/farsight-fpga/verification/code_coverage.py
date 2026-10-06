#!/usr/bin/env python3
"""What the requirement tests reached in the design.

    make test                        measure, and report (COV=0 to skip both)
    make code-coverage               report again from the data in hand

Both simulators measure: Verilator into `<run>.dat`, QuestaSim -- for the
modules pinned to it -- into `<run>.ucdb`. The report merges them
(`fsverif.ucdb`), file by file, into one annotated source each.

Three outputs, because three people want different things:

- a **summary** per source file, for deciding what to test next;
- **annotated source**, which is the only one that answers "which lines did
  nothing reach" -- open `verification/coverage/annotated/<file>` and the
  lines nothing reached carry a `%` in the margin;
- an **lcov `.info`** file, which GitLab renders in the merge request diff.

One thing this cannot tell you, and it is the important one.

A comparison that can never be true -- on the PA3 housekeeper, where this was
written, `cntr >= 76` on a counter saturating at 63 -- sits on a line that
executes every cycle, so **line coverage calls it covered**; it simply never
takes the branch. Branch coverage is
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

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fsverif import codecov, ucdb  # noqa: E402

VERIF = Path(__file__).resolve().parent
COVERAGE = VERIF / "coverage"
REPO = VERIF.parent

#: Verilator's own summary lines, e.g. "  line      : 54.8% (  617/ 1126)".
SUMMARY = re.compile(r"^\s*(\w+)\s*:\s*([\d.]+)%\s*\(\s*(\d+)/\s*(\d+)\)")

#: Sources that are not ours to cover. Vendor IP is generated from a Microchip
#: component definition into `verification/ip/` and is not edited here, so its
#: uncovered lines are noise in a report about this design's own logic; and a
#: generated wrapper is test plumbing. The environment declares the scope it
#: measured, and this is that declaration.
#:
#: By file name, because Verilator's annotated output flattens paths: the
#: vendor names are read from what is actually in `verification/ip/`, so a core
#: added there is excluded without being listed here.
def _not_ours() -> set:
    names = {p.name for p in (VERIF / "ip").rglob("*") if p.is_file()}
    return names | {"tb_top.sv"}


def tool(name: str = "verilator_coverage") -> str:
    found = shutil.which(name)
    if not found:
        raise SystemExit(
            "%s is not on PATH. It ships with Verilator; the verification "
            "toolchain installs both:\n  make setup" % name)
    return found


def data_files(where: Path) -> list:
    """Every run's raw data: Verilator's `.dat` and QuestaSim's `.ucdb`."""
    found = sorted(where.glob("*.dat")) + sorted(where.glob("*.ucdb"))
    if not found:
        raise SystemExit(
            "no coverage data in %s. Nothing has been measured, and a report "
            "over no data would read as zero coverage rather than as no "
            "measurement.\n  make test" % where)
    return found


def run(args: list) -> str:
    done = subprocess.run(args, capture_output=True, text=True)
    if done.returncode != 0:
        raise SystemExit("%s failed:\n%s" % (args[0], done.stderr.strip()))
    return done.stdout + done.stderr


def ours(path: Path) -> bool:
    """A source file of this design: found by name under its design folders
    (`fsverif.codecov.source`), and not vendor IP generated into
    `verification/ip`. Libero's simulation library, the testbench and any
    generated wrapper are none of these."""
    return path.name not in _not_ours() and codecov.source(path.name) is not None


#: A line Verilator annotated with a hit count, covered or not.
#:
#: The margin is one character -- `%` where the count is below
#: `--annotate-min`, `~` where only some of the line's points are, a space
#: otherwise -- followed by a zero-padded count. Matching only `%` or a leading
#: digit misses every covered line, which made every file report as entirely
#: unreached; leaving out `~` drops every partly covered line from the counts.
COUNTED = re.compile(r"^([%~\s])(\d{6,})\s")


def uncovered(annotated: Path, recorded: list) -> tuple:
    """Per source file of this design, (never executed, code lines, partly
    covered, never executed with a disposition); and the dispositions that
    could not be applied.

    A code line is one with a statement or branch point
    (`fsverif.codecov.CODE_KINDS`); a line whose only points are toggles is a
    declaration, reported with the toggles -- counting it here made every thin
    wrapper read as almost entirely unreached because its ports' upper bits
    never changed. A code line is never executed when every such point on it is
    zero, and partly covered when it ran but some point on it -- a branch, a
    condition, a toggle -- was never hit. Read through `fsverif.codecov`, the
    same parser the app uses, so the two cannot disagree.

    `%` in the margin does **not** mean "never reached". It means "fewer than
    `--annotate-min` times", and the default is 10 -- so a line executed twice
    is marked, and a report that read `%` as zero overstated the uncovered
    count here threefold. This runs with `--annotate-min 1`, and the counts are
    read rather than the mark.
    """
    per_file, problems = {}, []
    for source in sorted(annotated.glob("*")):
        if not source.is_file() or not ours(source):
            continue
        lines = codecov.annotated(source.name, annotated.parent)
        applied, bad = codecov.disposed(source.name, lines, recorded)
        problems += bad
        missed = counted = partly = excused = 0
        for line in lines:
            never = codecov.never_executed(line)
            if never is None:
                continue
            counted += 1
            if never:
                missed += 1
                excused += line.number in applied
            elif line.missed_points:
                partly += 1
        if counted:
            per_file[source.name] = (missed, counted, partly, excused)
    named = {d.file for d in recorded}
    for name in sorted(named - set(per_file)):
        problems.append({"where": name, "problem": "not measured",
                         "detail": "no coverage of this file in the data"})
    return per_file, problems


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--data", type=Path, default=COVERAGE)
    ap.add_argument("--out", type=Path, default=None,
                    help="where to write the report (default: alongside the "
                         "data, in verification/coverage/)")
    args = ap.parse_args(argv)

    out = args.out or args.data
    files = [str(f) for f in data_files(args.data)]
    verilator = [f for f in files if f.endswith(".dat")]
    questa = [f for f in files if f.endswith(".ucdb")]

    annotated = out / "annotated"
    shutil.rmtree(annotated, ignore_errors=True)
    annotated.mkdir(parents=True, exist_ok=True)

    print("Measured over %d run(s): %s\n"
          % (len(files), ", ".join(Path(f).name for f in files)))

    info = None
    if verilator:
        binary = tool()
        # --annotate-min 1 so that a `%` in the margin means a line nothing
        # reached. At the default of 10 it means "fewer than ten times", which
        # reads as uncovered and is not.
        output = run([binary, "--annotate", str(annotated), "--annotate-all",
                      "--annotate-min", "1", "--annotate-points", *verilator])
        info = out / "coverage.info"
        run([binary, "--write-info", str(info), *verilator])
        # Verilator's own totals count every instance of every file simulated --
        # testbenches, vendor IP and Libero's models included -- so they are
        # shown for reference and are not the headline.
        print("Verilator's own summary (every instance of every file simulated, not "
              "this design's coverage):")
        for line in output.splitlines():
            match = SUMMARY.match(line)
            if match:
                kind, pct, hit, total = match.groups()
                print("  %-19s %6s%%  %s of %s points" % (kind, pct, hit, total))

    if questa:
        for path, cov in ucdb.parse(ucdb.report(questa, out / "questa")).items():
            source = Path(path)
            # This design's own files only: not Libero's simulation library,
            # and not the vendor IP generated into verification/ip.
            if (not source.is_absolute() or not source.is_file() or not ours(source)
                    or REPO not in source.parents):
                continue
            target = annotated / source.name
            target.write_text(ucdb.merge_annotation(source, target, cov), encoding="utf-8")

    per_file, problems = uncovered(annotated, codecov.dispositions())
    kinds = codecov.tally(per_file, out)
    print("\nThis design, each point counted once however many instances reached it; "
          "code lines and toggles merged across the simulators, branches and "
          "conditions per simulator:")
    for kind, (pct, hit, total) in kinds.items():
        print("  %-19s %6.1f%%  %s of %s" % (kind, pct, hit, total))
    # The same figures, for the app to read without running Verilator's tools.
    (out / "summary.json").write_text(json.dumps({
        "modules": [Path(f).stem for f in files],
        "kinds": kinds,
        "files": {name: list(counts) for name, counts in per_file.items()},
        "dispositions": problems,
    }, indent=1), encoding="utf-8")

    worst = sorted(per_file.items(), key=lambda kv: (-(kv[1][0] - kv[1][3]), -kv[1][0]))
    print("\nPer file of this design, code lines never executed -- with how many of "
          "them have a disposition in %s -- and lines only partly covered (vendor "
          "IP, simulation libraries and the testbench excluded; declarations are "
          "counted with the toggles):" % codecov.DISPOSITIONS.name)
    for name, (missed, total, partly, excused) in worst:
        if missed or partly:
            print("  %-34s %4d of %4d code lines never executed (%4d disposed), %4d partly"
                  % (name, missed, total, excused, partly))
    open_lines = sum(m - e for m, _, _, e in per_file.values())
    print("  %d never executed without a disposition" % open_lines if open_lines else
          "  every code line never executed has a disposition")
    if problems:
        print("\nDispositions not applied, so their lines count as gaps:")
        for p in problems:
            print("  %-40s %-13s %s" % (p["where"], p["problem"], p["detail"]))

    print("\n  annotated source  %s" % annotated)
    if info:
        print("  lcov report       %s  (Verilator's runs only)" % info)
    print("\nA line marked % in the annotated source was never reached. A "
          "line with a count was reached, which is not the same as having "
          "been tested -- a comparison that can never be true sits on a line "
          "that executes every cycle.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
