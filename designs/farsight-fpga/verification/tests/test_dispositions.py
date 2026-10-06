"""Requirement dispositions: waivers and exceptions. No simulation.

A waiver turns a known shortfall into "waived" and nothing else; an exception
qualifies a pass and nothing else; neither applies until approved; and the
record is held to the requirements and items it names, so an entry cannot
outlive what it disposes of. The last tests read this repository's own
record, and hold the app's browser files to carrying nothing of this
repository's own -- they are the same file wherever the app is.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

VERIF = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(VERIF))

from fsverif import dispositions as D  # noqa: E402
from fsverif import project  # noqa: E402
from fsverif.evidence import (ITEMS, REQUIREMENTS, Item, Requirement,  # noqa: E402
                              by_requirement, read_items, read_requirements, stage)

RECORD = """
waivers:
  - id: WVR-X-01
    requirement: X-A-01
    reason: Accepted for this test.
    approved_by: A. Person
    date: 2026-10-06
  - id: WVR-X-02
    requirement: X-A-02
    reason: Proposed only.
    approved_by: UNASSIGNED
exceptions:
  - id: EXC-X-01
    requirement: X-A-03
    subjects: [r1, r2]
    reason: Permitted by the requirement.
    approved_by: A. Person
    date: 2026-10-06
  - id: EXC-X-02
    requirement: X-A-03
    subjects: [r3]
    reason: Proposed only.
    approved_by: UNASSIGNED
"""


@pytest.fixture
def record(tmp_path):
    path = tmp_path / "requirement-dispositions.yaml"
    path.write_text(RECORD, encoding="utf-8")
    return path


def _req(rid, expect_fail, path):
    item = Item(id="VC-" + rid, verifies=[rid], method="SIM",
                artifact="verification/tests/test_x.py::test_" + rid.replace("-", "_"),
                expect_fail=expect_fail, blocked=False)
    req = Requirement(id=rid, status="GAP", items=[item])
    waivers, exceptions = D.load(path)
    req.waivers = [w for w in waivers if w.requirement == rid]
    req.exceptions = [e for e in exceptions if e.requirement == rid]
    return req, item


def test_a_waiver_turns_a_known_shortfall_into_waived_and_nothing_else(record, tmp_path):
    (tmp_path / "verification" / "tests").mkdir(parents=True)
    (tmp_path / "verification" / "tests" / "test_x.py").write_text("")
    req, item = _req("X-A-01", True, record)
    assert stage(req, {item.key: "failed"}, repo=tmp_path) == "waived"
    item.expect_fail = False
    assert stage(req, {item.key: "failed"}, repo=tmp_path) == "failing", (
        "a waiver accepted a failure nobody declared")
    assert stage(req, {item.key: "passed"}, repo=tmp_path) == "passing"
    assert stage(req, {}, repo=tmp_path) == "never run", "a waiver stood in for a result"


def test_a_proposed_record_changes_nothing(record, tmp_path):
    (tmp_path / "verification" / "tests").mkdir(parents=True)
    (tmp_path / "verification" / "tests" / "test_x.py").write_text("")
    req, item = _req("X-A-02", True, record)
    assert req.waivers and not req.waived
    assert stage(req, {item.key: "failed"}, repo=tmp_path) == "known shortfall"
    assert D.excepted("X-A-03", record).keys() == {"r1", "r2"}, (
        "an exception awaiting approval was applied")


def test_exceptions_qualify_a_pass_and_nothing_else(record, tmp_path):
    (tmp_path / "verification" / "tests").mkdir(parents=True)
    (tmp_path / "verification" / "tests" / "test_x.py").write_text("")
    req, item = _req("X-A-03", False, record)
    assert stage(req, {item.key: "passed"}, repo=tmp_path) == "passing, with exceptions"
    assert stage(req, {item.key: "failed"}, repo=tmp_path) == "failing"


def test_check_finds_the_unlisted_and_the_stale(record):
    assert D.check("X-A-03", ["r1", "r2"], record) == ([], [])
    assert D.check("X-A-03", ["r1", "r2", "r3"], record) == (["r3"], []), (
        "a proposed exception excused an instance")
    assert D.check("X-A-03", ["r1"], record) == ([], ["r2"]), (
        "an exception the design no longer needs went unnoticed")


@pytest.mark.parametrize("bad, complaint", [
    ("waivers: [{id: W-1, requirement: X, reason: r, approved_by: A, date: 2026-10-06}]", "id must"),
    ("waivers: [{id: WVR-X-1, requirement: X, reason: r, date: 2026-10-06}]", "approved_by"),
    ("waivers: [{id: WVR-X-1, requirement: X, reason: r, approved_by: A}]", "YYYY-MM-DD"),
    ("waivers: [{id: WVR-X-1, requirement: X, approved_by: A, date: 2026-10-06}]", "reason"),
    ("exceptions: [{id: EXC-X-1, requirement: X, reason: r, approved_by: UNASSIGNED}]", "subjects"),
    ("exceptions: [{id: EXC-X-1, requirement: X, subjects: [a, a], reason: r, approved_by: UNASSIGNED}]",
     "twice"),
    ("exceptions: [{id: EXC-X-1, requirement: X, subjects: [a], reason: r, approved_by: UNASSIGNED},"
     " {id: EXC-X-2, requirement: X, subjects: [a], reason: r, approved_by: UNASSIGNED}]", "both"),
    ("waivers: [{id: WVR-X-1, requirement: X, reason: r, approved_by: UNASSIGNED},"
     " {id: WVR-X-1, requirement: Y, reason: r, approved_by: UNASSIGNED}]", "recorded twice"),
])
def test_a_malformed_record_is_refused(tmp_path, bad, complaint):
    path = tmp_path / "requirement-dispositions.yaml"
    path.write_text(bad, encoding="utf-8")
    with pytest.raises(ValueError, match=complaint):
        D.load(path)


def test_this_repositorys_record_holds():
    """Every waiver and exception names a requirement in the document. A
    waiver's requirement has an item declaring it unmet -- there is a
    shortfall to accept -- and an exception's has a written test of its own
    to apply it, since nothing else reads the subjects."""
    waivers, exceptions = D.load()
    requirements = by_requirement(read_items(ITEMS), read_requirements(REQUIREMENTS))
    for w in waivers:
        assert w.requirement in requirements, f"{w.id}: no requirement {w.requirement}"
        assert any(i.expect_fail for i in requirements[w.requirement].items), (
            f"{w.id}: no item of {w.requirement} declares it unmet, so there is "
            "nothing to waive -- remove the waiver, or it is stale")
    for e in exceptions:
        assert e.requirement in requirements, f"{e.id}: no requirement {e.requirement}"
        assert any(i.is_local_test and i.written() for i in requirements[e.requirement].items), (
            f"{e.id}: no written test of {e.requirement} applies its exceptions")


def test_the_browser_files_are_this_repositorys_in_nothing():
    """`fsverif/web/static/` is the same in every repository with the app; what
    differs comes from the server (`fsverif.project`). A name written into
    these files would make the next copy wrong without anyone noticing."""
    static = VERIF / "fsverif" / "web" / "static"
    for f in sorted(static.iterdir()):
        text = f.read_text(encoding="utf-8")
        for own in (project.NAME, project.ALLOCATED_PREFIX, project.ALLOCATED_LABEL,
                    project.PENDING["filter"], f"{project.REQUIREMENT_SHORT} reqs"):
            assert own not in text, f"{f.name} carries {own!r}; send it from fsverif.project"
