#!/usr/bin/env python3
"""The last run, and code coverage, as SARIF -- for VS Code's SARIF Viewer.

    verification/sarif.py          write both
    make sarif                     the same

The same way ts-rtl-check puts lint findings in front of an engineer: open the
file with the SARIF Viewer extension, and every result is a line in a panel
that jumps to its source.

- `verification/results/fsverif.sarif`: every requirement test that did not
  pass, at the line of the test. A result that would block a merge -- a new
  failure, a pass whose item still expects a failure, a skip -- is an error; an
  expected failure, one checking a requirement already recorded as not met, is
  a warning; a test with no result is a note. The message carries the requirement's wording,
  the findings it cites, and the failure.
- `verification/coverage/coverage.sarif`: every design line nothing reached
  (a warning), and every line reached with points on it that nothing hit (a
  note), at the line in `src/`. Only when coverage has been measured.

Paths are relative to the repository, under `%SRCROOT%`, which is given as this
checkout; the SARIF Viewer resolves them either way. Verdicts come from the
same code as `make check`, so the two cannot disagree.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from fsverif import codecov  # noqa: E402
from fsverif import results as R  # noqa: E402
from fsverif.evidence import REPO, RESULTS  # noqa: E402

SCHEMA = "https://json.schemastore.org/sarif-2.1.0.json"
LEVEL = {"REGRESSION": "error", "STALE": "error", "SKIPPED": "error",
         "known shortfall": "warning", "not run": "note"}


def _log(tool: str, rules: list, results: list) -> dict:
    return {"$schema": SCHEMA, "version": "2.1.0", "runs": [{
        "tool": {"driver": {"name": tool, "informationUri":
                            "https://gitlab.com/turionspace/fpga-projects/farsight/"
                            "farsight-fpga-house-keeper", "rules": rules}},
        "originalUriBaseIds": {"SRCROOT": {"uri": REPO.as_uri() + "/"}},
        "results": results}]}


def _location(path: str, line: int) -> dict:
    return {"physicalLocation": {"artifactLocation": {"uri": path, "uriBaseId": "SRCROOT"},
                                 "region": {"startLine": max(line, 1)}}}


def tests_sarif(run) -> dict:
    """Every requirement test that did not pass, at the test."""
    rules, seen, results = [], set(), []
    for t in run.tests:
        if t.verdict == "passed":
            continue
        for rid in t.requirements:
            if rid in seen:
                continue
            seen.add(rid)
            req = run.requirements.get(rid)
            rules.append({"id": rid, "name": rid.replace("-", ""),
                          "shortDescription": {"text": req.statement if req else rid},
                          "properties": {"status": req.status if req else "",
                                         "findings": list(req.findings) if req else []}})
        note = f" ({t.gate_note})" if t.gate_note else ""
        lines = [f"{t.outcome_label}{note}: {t.name}"]
        for rid in t.requirements:
            req = run.requirements.get(rid)
            if req:
                pending = " (value pending systems confirmation)" if req.pending else ""
                lines.append(f"{rid} [{req.status}]{pending}: {req.statement}")
                for fid in req.findings:
                    sev, subject = run.findings.get(fid, ("?", ""))
                    lines.append(f"  {fid} ({sev}): {subject}")
        if t.message:
            lines += ["", t.message]
        results.append({
            "ruleId": t.requirements[0] if t.requirements else "fsverif",
            "level": LEVEL.get(t.verdict, "note"),
            "message": {"text": "\n".join(lines)},
            "locations": [_location(str(t.path.relative_to(R.VERIF.parent)), t.line)],
            "properties": {"verdict": t.verdict, "items": [i.id for i in t.items],
                           "requirements": t.requirements},
        })
    return _log("fsverif", rules, results)


def coverage_sarif(cov: codecov.Coverage, where: Path = codecov.COVERAGE) -> dict:
    """Lines nothing reached, and lines only partly reached, in `src/`."""
    rules = [
        {"id": "COV-UNREACHED", "name": "NeverReached",
         "shortDescription": {"text": "No requirement test reached this line"}},
        {"id": "COV-PARTIAL", "name": "PartlyReached",
         "shortDescription": {"text": "Reached, but some of the line's coverage points "
                                      "(a branch, an expression term, a toggle) were never hit"}},
    ]
    results = []
    for f in cov.files:
        src = REPO / "src" / f.name
        path = f"src/{f.name}" if src.is_file() else f"verification/coverage/annotated/{f.name}"
        for line in codecov.annotated(f.name, where):
            if line.count == 0:
                rule, level = "COV-UNREACHED", "warning"
                text = f"Never reached by the tests measured: {line.text.strip()}"
            elif line.partial:
                rule, level = "COV-PARTIAL", "note"
                missed = sorted({f"{p.kind} {p.comment}" for p in line.missed_points})
                text = (f"Reached {line.count} times, but not every point on it: "
                        + ("; ".join(missed[:6]) or line.text.strip()))
            else:
                continue
            results.append({"ruleId": rule, "level": level, "message": {"text": text},
                            "locations": [_location(path, line.number)]})
    return _log("fsverif coverage", rules, results)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--results", type=Path, default=RESULTS)
    ap.add_argument("--coverage", type=Path, default=codecov.COVERAGE)
    args = ap.parse_args(argv)

    run = R.load(results_dir=args.results)
    out = args.results / "fsverif.sarif"
    out.parent.mkdir(parents=True, exist_ok=True)
    log = tests_sarif(run)
    out.write_text(json.dumps(log, indent=1), encoding="utf-8")
    print(f"wrote {out}: {len(log['runs'][0]['results'])} tests that did not pass")

    cov = codecov.load(args.coverage)
    if cov.reported:
        cout = args.coverage / "coverage.sarif"
        clog = coverage_sarif(cov, args.coverage)
        cout.write_text(json.dumps(clog, indent=1), encoding="utf-8")
        res = clog["runs"][0]["results"]
        print(f"wrote {cout}: {sum(r['level'] == 'warning' for r in res)} lines never reached, "
              f"{sum(r['level'] == 'note' for r in res)} partly"
              + (" -- the coverage report is older than the data; make code-coverage"
                 if cov.stale else ""))
    else:
        print("no coverage report, so no coverage.sarif: run make test, which measures "
              "coverage and writes the report")
    print("Open them in VS Code with the SARIF Viewer extension (ms-sarifviewer).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
