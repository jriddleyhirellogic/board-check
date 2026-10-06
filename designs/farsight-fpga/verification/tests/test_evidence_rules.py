"""Rules the evidence layer has to obey, checked without running a simulation.

Two rules, both cheap, both catching mistakes that are otherwise invisible
until somebody audits by hand:

1. every item names a test that exists, and every test is named by an item;
2. no requirement test mutes its own result.

The first costs no simulation, and on the PA3 housekeeper, where these rules
were first written, it caught two wrong citations the moment it ran -- each
entirely plausible in a docstring.

A wrong citation is worse than a missing one. The trace checker reads
`items.yaml`, so a test citing the wrong item still leaves its own item
unevidenced while appearing, to a reader of the test, to be covered.

Two directions, because they fail differently:

- an item naming a test that does not exist is a trace that claims evidence
  nothing can produce;
- a test no item names is engineering material presented as verification
  (framework VII.6) -- it will run, pass, and count for nothing.
"""

from __future__ import annotations

import ast
import re
from pathlib import Path

import pytest
import yaml

TESTS = Path(__file__).resolve().parent
ITEMS = TESTS.parent / "items.yaml"
REPO = TESTS.parent.parent

#: Artifacts under these prefixes are tests in this repository: simulations
#: and analyses. Items citing anything else -- a document, an item in another
#: plan, a bench still to be written -- are not this check's business.
OURS = ("verification/tests/", "verification/analysis/")
ANALYSES = TESTS.parent / "analysis"


def items() -> list:
    return yaml.safe_load(ITEMS.read_text(encoding="utf-8"))["items"]


def cited() -> list:
    """Every `path::testname` an item claims is a test in this repository."""
    found = []
    for item in items():
        artifact = item.get("artifact", "")
        if artifact.startswith(OURS) and "::" in artifact:
            path, name = artifact.split("::", 1)
            found.append((item["id"], REPO / path, name))
    return found


def defined(path: Path) -> set:
    """Test functions defined in a module, without importing it.

    Importing would pull in cocotb and the whole simulation environment for a
    check that is only reading names.
    """
    tree = ast.parse(path.read_text(encoding="utf-8"))
    return {node.name for node in ast.walk(tree)
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}


@pytest.mark.parametrize("item_id,path,name",
                         cited(), ids=[c[0] for c in cited()])
def test_every_item_names_a_test_that_exists(item_id, path, name):
    assert path.is_file(), (
        "%s cites %s, which does not exist. The item claims evidence that "
        "nothing can produce." % (item_id, path))
    assert name in defined(path), (
        "%s cites %s::%s, but that file defines no such test. The item claims "
        "evidence that nothing can produce, and the trace will report the "
        "requirement as covered." % (item_id, path.name, name))


#: A requirement test is named for its requirement: `test_PF_UDP_01_...` or
#: `test_DRV_PF_03_...`. JUnit has no field for a requirement, so the name is
#: the only channel through which the trace survives into the result.
REQUIREMENT_TEST = re.compile(r"^test_(PF_[A-Z]+|DRV_PF)_\d+")


def test_every_requirement_test_is_named_by_an_item():
    named = {(path.name, name) for _, path, name in cited()}
    stray = []
    for path in sorted(TESTS.glob("test_pf_*.py")) + sorted(ANALYSES.glob("test_ana_*.py")):
        for name in sorted(defined(path)):
            # The cocotb coroutines are the verification; the pytest function
            # beside them only builds and launches the simulation.
            if REQUIREMENT_TEST.match(name) and (path.name, name) not in named:
                stray.append("%s::%s" % (path.name, name))
    assert not stray, (
        "these tests are not named by any item in items.yaml, so they will "
        "run, pass, and count for nothing -- a script no item cites is "
        "engineering material, not evidence: %s" % ", ".join(stray))


#: Ways a test can report something other than what happened. `expect_fail`
#: and `expect_error` turn a failing cocotb test into a passing line in the
#: JUnit output; the pytest marks do the same at the outer level.
MUTES = {
    "expect_fail": "turns a failing cocotb test into a pass",
    "expect_error": "turns an erroring cocotb test into a pass",
    "skip": "stops the test running at all",
}
MUTING_MARKS = ("xfail", "skip", "skipif")
MUTING_CALLS = ("skip", "skipTest", "xfail")


def _muting(path: Path) -> list:
    """Every place a requirement test would report other than what happened."""
    found = []
    for node in ast.walk(ast.parse(path.read_text(encoding="utf-8"))):
        if isinstance(node, ast.Call):
            for keyword in node.keywords:
                if keyword.arg in MUTES:
                    found.append("%s:%d  %s= -- %s"
                                 % (path.name, node.lineno, keyword.arg,
                                    MUTES[keyword.arg]))
            name = getattr(node.func, "attr", getattr(node.func, "id", ""))
            if name in MUTING_CALLS:
                found.append("%s:%d  %s() -- stops the test reporting a result"
                             % (path.name, node.lineno, name))
        if isinstance(node, ast.Attribute) and node.attr in MUTING_MARKS:
            found.append("%s:%d  pytest.mark.%s -- suppresses the result"
                         % (path.name, node.lineno, node.attr))
    return found


def test_no_requirement_test_mutes_itself():
    """A requirement test reports what happened, or it is not evidence.

    A known shortfall is declared on the *item*, with `expect: FAIL`, and that
    is a label rather than a suppression: the test still runs and still fails.
    Muting it in the test instead moves a red result to green and loses the
    one thing the suite is for.

    This is not hypothetical. On the PA3 housekeeper a test was written with
    `expect_error=AssertionError` to hold a known defect, and the suite read
    green while a power source could stall the boot sequence forever.

    Known failures are told apart from new ones by comparing the failing set
    against the items declaring `expect: FAIL` -- outside the test, where it
    cannot make a failure look like a pass.
    """
    muted = []
    for path in sorted(TESTS.glob("test_pf_*.py")):
        muted.extend(_muting(path))
    assert not muted, (
        "these requirement tests do not report what happened, so a failure "
        "here would read as a pass:\n  %s" % "\n  ".join(muted))


#: Scripts referenced from somewhere that only fails when somebody runs it.
#: A `make` recipe and a CI job are both strings until executed, so renaming a
#: script leaves them pointing at nothing and every test still passes.
#: A renamed script is found only when an engineer runs the target.
CALLERS = (REPO / "Makefile", REPO / ".gitlab-ci.yml")

SCRIPT = re.compile(r"(?:verification|script|tools)/[\w/]+\.py")


def test_every_script_a_caller_names_exists():
    missing = []
    for caller in CALLERS:
        if not caller.is_file():
            continue
        for match in sorted(set(SCRIPT.findall(
                caller.read_text(encoding="utf-8")))):
            if not (REPO / match).is_file():
                missing.append("%s references %s" % (caller.name, match))
    assert not missing, (
        "these scripts are named by a build recipe or a CI job and do not "
        "exist, so the command fails only when somebody runs it: %s"
        % ", ".join(missing))


def test_every_item_verifies_a_requirement_that_exists():
    """An item citing a requirement the document does not hold verifies
    nothing, and would inflate every count that includes it."""
    import sys
    sys.path.insert(0, str(TESTS.parent))
    from fsverif.evidence import read_requirements

    known = read_requirements()
    stray = ["%s verifies %s" % (i["id"], r) for i in items()
             for r in i.get("verifies", []) if r not in known]
    assert not stray, "items verify requirements not in the document: %s" % (
        "; ".join(stray))


def test_item_ids_are_unique():
    ids = [i["id"] for i in items()]
    repeated = sorted({i for i in ids if ids.count(i) > 1})
    assert not repeated, "item ids used more than once: %s" % ", ".join(repeated)


def test_every_listed_ip_component_is_defined():
    """`verification/ip.yaml` names components by name; each must resolve to
    exactly one definition the build uses, or `make ip` would generate
    something else -- or nothing."""
    import sys
    sys.path.insert(0, str(TESTS.parent))
    from fsverif.ip import StaleIP, definition, listed, BOARD, IP_YAML

    problems = []
    for name in listed(IP_YAML):
        try:
            definition(REPO, BOARD, name)
        except StaleIP as exc:
            problems.append(str(exc))
    assert not problems, "\n".join(problems)


def test_a_failure_in_any_results_file_is_the_result(tmp_path):
    """The same test run against two DUTs: one pass must not hide one failure,
    whichever file sorts last."""
    from fsverif.evidence import read_results

    def junit(name, failed):
        body = '<failure message="x"/>' if failed else ""
        return ('<testsuites><testsuite><testcase classname="m" name="t">%s'
                '</testcase></testsuite></testsuites>' % body)

    for first_fails in (True, False):
        d = tmp_path / str(first_fails)
        d.mkdir()
        (d / "a.xml").write_text(junit("t", first_fails))
        (d / "b.xml").write_text(junit("t", not first_fails))
        assert read_results(d)[("m", "t")] == "failed"
