"""Rules the evidence layer has to obey, checked without running a simulation.

Two rules, both cheap, both catching mistakes that are otherwise invisible
until somebody audits by hand:

1. every item names a test that exists, and every test is named by an item;
2. no requirement test mutes its own result.

The first cost no simulation and caught a real mistake immediately. Writing
these tests, two citations were wrong: `test_hk_src_02` claimed `VC-HK-0002` (which is a latchup item)
and `test_hk_src_06` claimed `VC-HK-0056` (which is a sequencing item). Both
looked entirely plausible in a docstring.

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

#: Artifacts under this prefix are tests in this repository. Items citing
#: anything else -- a document, an item in another plan, a bench still to be
#: written -- are not this check's business.
OURS = "verification/tests/"

#: Inspections: tests that read the design rather than simulate it. Sixteen
#: items name one, most not written yet -- outstanding work the requirement
#: stages already report as "no test yet". Once a file exists it is held to
#: the same rules as a simulation module.
INSPECTIONS = "test/inspect/"
INSPECT = REPO / "test" / "inspect"


def inspection_modules() -> list:
    return sorted(p for p in INSPECT.glob("*.py") if p.name != "conftest.py")


def items() -> list:
    return yaml.safe_load(ITEMS.read_text(encoding="utf-8"))["items"]


def cited() -> list:
    """Every `path::testname` an item claims is a test in this repository."""
    found = []
    for item in items():
        artifact = item.get("artifact", "")
        if "::" not in artifact:
            continue
        path, name = artifact.split("::", 1)
        if artifact.startswith(OURS) or (artifact.startswith(INSPECTIONS)
                                         and (REPO / path).is_file()):
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


def test_every_requirement_test_is_named_by_an_item():
    named = {(path.name, name) for _, path, name in cited()}
    stray = []
    for path in sorted(TESTS.glob("test_hk_*.py")) + inspection_modules():
        for name in sorted(defined(path)):
            # The cocotb coroutines are the verification; the pytest function
            # beside them only builds and launches the simulation.
            if name.startswith(("test_HK_", "test_DRV_")) and (path.name, name) not in named:
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

    This is not hypothetical. `test_hk_src_06` was written with
    `expect_error=AssertionError` to hold a known defect, and the suite read
    green while a power source could stall the boot sequence forever. The
    defect is fixed and the muting is gone; this stops it coming back.

    Known failures are told apart from new ones by comparing the failing set
    against the items declaring `expect: FAIL` -- outside the test, where it
    cannot make a failure look like a pass.
    """
    muted = []
    for path in sorted(TESTS.glob("test_hk_*.py")) + inspection_modules():
        muted.extend(_muting(path))
    assert not muted, (
        "these requirement tests do not report what happened, so a failure "
        "here would read as a pass:\n  %s" % "\n  ".join(muted))


#: Scripts referenced from somewhere that only fails when somebody runs it.
#: A `make` recipe and a CI job are both strings until executed, so renaming a
#: script leaves them pointing at nothing and every test still passes.
#: `verification/coverage.py` became `requirement_coverage.py` and both callers
#: were missed; the break surfaced as an engineer running `make coverage`.
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


#: The device's own port list, which `fsverif.pins` has to agree with.
TOP = REPO / "src" / "top.sv"
PORT = re.compile(r"^\s*(?:input|output)\s+wire\s+(?:\[[^\]]*\]\s*)?(\w+)\s*,?\s*$",
                  re.M)


def test_pins_knows_every_port_of_the_device():
    """`pins.boundary` refuses anything it does not know, so it must know all.

    The guard exists to catch a test reaching inside the design. A port
    missing from `pins.py` is refused with exactly that message -- so the
    report says "not a pin of the housekeeper" about something that is one,
    and the reader is sent looking for a mistake they did not make.

    Seven ports were missing when this was written, found by a test that
    legitimately wanted `debug`. Nothing generates `pins.py`, which is
    deliberate -- the names carry meaning a port list cannot -- so this is
    what keeps it complete.
    """
    import sys
    sys.path.insert(0, str(TESTS.parent))
    from fsverif.pins import ALL_PINS

    declared = set(PORT.findall(TOP.read_text(encoding="utf-8")))
    missing = sorted(declared - ALL_PINS - {"clk"})
    assert not missing, (
        "these ports of %s are not known to fsverif.pins, so boundary() "
        "refuses them and a test observing one is told it is not a pin of "
        "the housekeeper: %s" % (TOP.name, ", ".join(missing)))

    stray = sorted(ALL_PINS - declared - {"clk"})
    assert not stray, (
        "fsverif.pins names these, which are not ports of %s, so a test could "
        "reach for a pin the device does not have: %s"
        % (TOP.name, ", ".join(stray)))
