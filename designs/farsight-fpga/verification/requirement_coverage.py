#!/usr/bin/env python3
"""Where each PolarFire FPGA requirement stands, from this repository alone.

    verification/coverage.py              every requirement, grouped
    verification/coverage.py --group SRC  one group
    verification/coverage.py --todo       only what is not yet covered
    verification/coverage.py --html out/  a page to open or publish

Two things this deliberately does not do.

**It does not call a passing test "verified".** It says the test ran and met
the criterion its item wrote down. Whether that criterion is a fair reading of
the requirement is a review question, and no tool settles it.

**It does not count an unrun test as coverage.** A test that exists and has
never run is a promise, not evidence, and the difference between those two is
most of what this framework is for. They are separate rows here and are never
added together.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from fsverif import project  # noqa: E402
from fsverif.evidence import (COVERED, ITEMS, REQUIREMENTS, RESULTS,  # noqa: E402
                              STAGES, by_requirement, methods, read_items,
                              read_requirements, read_results, stage)

MARK = {
    "passing": "ok",
    "passing, with exceptions": "ok*",
    "waived": "wvd",
    "known shortfall": "gap",
    "failing": "FAIL",
    "never run": "--",
    "not written": "--",
    "elsewhere": "->",
    "no item": "!!",
}


def group_of(requirement: str) -> str:
    """`PF-UDP-02` -> `UDP`, `DRV-PF-03` -> `DRV`."""
    parts = requirement.split("-")
    return parts[0] if parts[0] == "DRV" else parts[1]


def collect(items_path: Path, requirements_path: Path, results_path: Path):
    requirements = by_requirement(read_items(items_path),
                                  read_requirements(requirements_path))
    results = read_results(results_path)
    return requirements, results


def render_text(requirements: dict, results: dict, only: str, todo: bool,
                method: str = "") -> int:
    groups = {}
    for requirement in requirements.values():
        groups.setdefault(group_of(requirement.id), []).append(requirement)

    # Counted twice, because a filtered view that reports only its own slice
    # is how "40% covered" escapes into a status report. When a filter is in
    # use both numbers are printed and both are labelled.
    counts = {name: 0 for name, _ in STAGES}
    overall = {name: 0 for name, _ in STAGES}
    shown = 0
    for name in sorted(groups):
        for requirement in groups[name]:
            overall[stage(requirement, results)] += 1   # always programme-wide
        if only and name != only.upper():
            continue
        rows = []
        for requirement in sorted(groups[name], key=lambda r: r.id):
            how = methods(requirement)
            if method and method.upper() not in how.split("/"):
                continue
            reached = stage(requirement, results, method=method)
            counts[reached] += 1
            if todo and reached in COVERED:
                continue
            tests = ", ".join(sorted({i.test for i in requirement.items if i.test}))
            rows.append("  %-4s %-14s %-8s %-24s %s"
                        % (MARK[reached], requirement.id, how, reached,
                           tests[:52]))
        if rows:
            print("%s" % name)
            print("\n".join(rows))
            print()
            shown += len(rows)

    filtered = bool(only or method or todo)
    total = sum(counts.values())
    covered = sum(counts[s] for s in COVERED)
    if filtered:
        print("%d of %d requirements shown here have evidence behind them"
              % (covered, total))
    else:
        print("%d of %d requirements have evidence behind them"
              % (covered, total))
    for name, meaning in STAGES:
        if counts[name]:
            print("  %4d  %-24s %s" % (counts[name], name, meaning))

    if filtered:
        # The whole programme, always, so a slice can never be read as the
        # total by somebody who did not see the command that produced it.
        whole = sum(overall.values())
        print("\nAcross all %d %s requirements: %d with evidence, %d without."
              % (whole, project.NAME, sum(overall[s] for s in COVERED),
                 whole - sum(overall[s] for s in COVERED)))
    if not filtered and (counts["never run"] or counts["not written"]):
        print("\nA test that has never run is not coverage. %d written but "
              "never run, %d named but not written."
              % (counts["never run"], counts["not written"]))
    return 0 if shown or not todo else 0


HTML = """<!doctype html>
<meta charset="utf-8"><title>%(name)s requirement coverage</title>
<style>
 body{font:14px/1.5 system-ui,sans-serif;margin:2rem auto;max-width:60rem;color:#111}
 h1{font-size:1.4rem;margin:0 0 .25rem} p.sub{color:#555;margin:0 0 1.5rem}
 table{border-collapse:collapse;width:100%%;margin-bottom:2rem}
 th,td{text-align:left;padding:.35rem .6rem;border-bottom:1px solid #e5e5e5}
 th{font-weight:600;border-bottom:2px solid #ccc}
 td.s{white-space:nowrap;font-weight:600}
 .passing{color:#186a3b}.known{color:#7d6608}.failing{color:#922b21}
 .none{color:#777}
 code{font:12px ui-monospace,monospace;color:#444}
 .tot{background:#f6f6f6;padding:1rem;border-radius:4px;margin-bottom:2rem}
</style>
<h1>%(name)s requirement coverage</h1>
<p class=sub>Generated from this repository: items, tests and collected
results. A test that has never run is not counted as coverage.</p>
<div class=tot>%(totals)s</div>
%(tables)s
"""

CLASS = {"passing": "passing", "passing, with exceptions": "passing",
         "waived": "known", "known shortfall": "known", "failing": "failing"}


def render_html(requirements: dict, results: dict, out: Path) -> int:
    groups = {}
    counts = {name: 0 for name, _ in STAGES}
    for requirement in requirements.values():
        groups.setdefault(group_of(requirement.id), []).append(requirement)

    tables = []
    for name in sorted(groups):
        rows = []
        for requirement in sorted(groups[name], key=lambda r: r.id):
            reached = stage(requirement, results)
            counts[reached] += 1
            tests = ", ".join(sorted({i.test for i in requirement.items if i.test}))
            rows.append(
                "<tr><td>%s</td><td>%s</td><td class='s %s'>%s</td>"
                "<td><code>%s</code></td></tr>"
                % (requirement.id, methods(requirement),
                   CLASS.get(reached, "none"), reached, tests))
        tables.append("<h2>%s</h2><table><tr><th>Requirement<th>Method"
                      "<th>Evidence<th>Test</tr>%s</table>"
                      % (name, "".join(rows)))

    total = sum(counts.values())
    covered = sum(counts[s] for s in COVERED)
    totals = ["<strong>%d of %d requirements have evidence behind them.</strong>"
              % (covered, total), "<ul>"]
    for name, meaning in STAGES:
        if counts[name]:
            totals.append("<li><strong>%d</strong> %s — %s</li>"
                          % (counts[name], name, meaning))
    totals.append("</ul>")

    out.mkdir(parents=True, exist_ok=True)
    page = out / "coverage.html"
    page.write_text(HTML % {"name": project.NAME, "totals": "".join(totals), "tables": "".join(tables)},
                    encoding="utf-8")
    print("wrote %s" % page)
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--items", type=Path, default=ITEMS)
    ap.add_argument("--requirements", type=Path, default=REQUIREMENTS)
    ap.add_argument("--results", type=Path, default=RESULTS)
    ap.add_argument("--group", default="", metavar="NAME",
                    help="one group only, such as SRC or SEQ")
    ap.add_argument("--todo", action="store_true",
                    help="only requirements with no evidence yet")
    ap.add_argument("--method", default="", metavar="M",
                    help="one method only: SIM, INSP, ANA or HW. SIM is the "
                         "simulation work; the others are not written here")
    ap.add_argument("--html", type=Path, metavar="DIR",
                    help="write a page here instead of printing")
    args = ap.parse_args(argv)

    for path in (args.items, args.requirements):
        if not path.is_file():
            print("CANNOT CHECK: no %s" % path, file=sys.stderr)
            return 2

    requirements, results = collect(args.items, args.requirements, args.results)
    if not results:
        print("No results collected, so nothing can be reported as passing.\n"
              "Run the suite first:  cd verification && "
              "../.venv-verif/bin/python -m pytest tests/ -q\n", file=sys.stderr)

    if args.html:
        return render_html(requirements, results, args.html)
    return render_text(requirements, results, args.group, args.todo,
                       args.method)


if __name__ == "__main__":
    sys.exit(main())
