#!/usr/bin/env python3
"""Decide whether a run's results should stop a merge.

The question a gate has to answer is **not** "did everything pass". Thirty-five
of this repository's items verify requirements the programme already knows are
unmet, and their tests are supposed to fail. A gate that blocked on failure
would block on the truth, and the pressure would go on the tests rather than on
the shortfalls -- which is exactly what `expect: FAIL` exists to prevent.

So the gate blocks on a **change in the set of failures**, not on failures:

| result | declared `expect: FAIL` | verdict |
| --- | --- | --- |
| failed | yes | known shortfall, still open -- reported, does not block |
| failed | no | regression -- blocks |
| passed | yes | fixed; the item and the requirement status are now stale -- blocks |
| passed | no | as expected |
| skipped | either | no evidence -- blocks |
| no result | either | the test did not report at all -- blocks |

The third row is the one people find surprising, and it is the most valuable.
When a fix lands and a test that was declared to fail starts passing, this is
what forces the requirement out of GAP or DEFECT and the item out of
`expect: FAIL`. Without it the programme would go on recording a defect it had
already fixed, and every reader of the trace would be misled in the
safe-looking direction.

Nothing here mutes anything. Every test reports what happened, every failure is
a failure in the JUnit that GitLab renders, and this only decides what that
means. `verification/tests/test_evidence_rules.py` is what stops a test muting
itself in the first place.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from fsverif.evidence import (ITEMS, RESULTS, by_test,  # noqa: E402
                              read_items, read_results)

#: Exit codes, following the checkers in farsight-verification (TOOL-04): a
#: broken gate and a failing corpus need different people.
EXIT_OK, EXIT_BLOCKED, EXIT_CANNOT_CHECK = 0, 1, 2


#: Verdicts, and whether each blocks a merge.
REGRESSION, STALE, SKIPPED, KNOWN, PASSED, MISSING = (
    "REGRESSION", "STALE", "SKIPPED", "known shortfall", "passed", "not run")
BLOCKS = {REGRESSION: True, STALE: True, SKIPPED: True, KNOWN: False,
          PASSED: False, MISSING: True}

#: Where the requirement tests this gate expects a result from live.
LOCAL = ("verification/tests/", "verification/analysis/")


def missing(items: dict, results: dict) -> list:
    """Every (key, item) for a written requirement test with no result.

    Without this the gate judges only what reported, so a module that fails to
    import, a simulator that never started or a results file that was not
    collected all leave nothing to judge -- and nothing blocks. A test that is
    not written yet is not here: that is an item's state, which `make coverage`
    reports, not a run's.
    """
    out = []
    for key, citing in sorted(items.items()):
        if key in results:
            continue
        for item in citing:
            if item.artifact.startswith(LOCAL) and item.written():
                out.append((key, item))
    return out


def classify(items: dict, results: dict) -> list:
    """Every (key, item, verdict) for results that an item cites.

    Judged per item, because two items citing one test may declare different
    things about it. A failure is known only for the items that said it would
    fail; for any other item citing the same test it is a regression, and both
    are reported.

    A result no item cites is left out. It is either not a requirement test,
    or a test no item names -- a real problem, but test_evidence_rules' to
    report, which it can do without a run.
    """
    out = []
    for key, outcome in sorted(results.items()):
        for item in items.get(key, ()):
            if outcome == "skipped":
                verdict = SKIPPED
            elif outcome == "failed":
                verdict = KNOWN if item.expect_fail else REGRESSION
            elif item.expect_fail:
                verdict = STALE
            else:
                verdict = PASSED
            out.append((key, item, verdict))
    return out


def judge(items: dict, results: dict) -> tuple:
    """Return (blocking, informational) lists of human-readable lines."""
    blocking, informational = [], []
    for key, item, verdict in classify(items, results):
        name = "%s::%s" % key
        who = "%s (%s)" % (item.id, ", ".join(item.verifies))
        if verdict == SKIPPED:
            blocking.append(
                "SKIPPED          %-58s %s -- a skipped requirement test "
                "is no evidence, and reads as one" % (name, who))
        elif verdict == KNOWN:
            informational.append(
                "known shortfall  %-58s %s -- still failing, as the item "
                "says" % (name, who))
        elif verdict == REGRESSION:
            blocking.append(
                "REGRESSION       %-58s %s -- failed, and this item does "
                "not declare the requirement unmet" % (name, who))
        elif verdict == STALE:
            blocking.append(
                "STALE            %-58s %s -- passed, but the item says "
                "expect: FAIL. If the shortfall is fixed, clear it and "
                "revisit the requirement's status; the trace is recording "
                "a defect that no longer exists" % (name, who))
    for key, item in missing(items, results):
        blocking.append(
            "NO RESULT        %-58s %s -- the test exists and did not report: "
            "it failed to import or start, or its results were not collected"
            % ("%s::%s" % key, "%s (%s)" % (item.id, ", ".join(item.verifies))))
    return blocking, informational


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--items", type=Path, default=ITEMS)
    ap.add_argument("--results", type=Path, default=RESULTS)
    args = ap.parse_args(argv)

    if not args.items.is_file():
        print("CANNOT CHECK: no items at %s" % args.items, file=sys.stderr)
        return EXIT_CANNOT_CHECK
    if not args.results.is_dir() or not any(args.results.glob("*.xml")):
        # Not "everything passed". A gate that reports success when it was
        # given nothing to judge is the most dangerous kind of green.
        print("CANNOT CHECK: no results in %s. The simulation did not run, or "
              "its results were not collected -- either way this cannot say "
              "whether anything passed." % args.results, file=sys.stderr)
        return EXIT_CANNOT_CHECK

    items = by_test(read_items(args.items))
    results = read_results(args.results)
    blocking, informational = judge(items, results)

    print("%d requirement tests ran, cited by %d items; %d items declare "
          "expect: FAIL"
          % (len([k for k in results if k in items]),
             sum(len(items[k]) for k in results if k in items),
             sum(1 for citing in items.values()
                 for i in citing if i.expect_fail)))
    for line in informational:
        print("  " + line)
    for line in blocking:
        print("  " + line, file=sys.stderr)

    if blocking:
        print("\n%d finding(s) block this merge. A known shortfall does not "
              "block; a new failure and a stale declaration do."
              % len(blocking), file=sys.stderr)
        return EXIT_BLOCKED
    print("\nno change in the set of failures")
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
