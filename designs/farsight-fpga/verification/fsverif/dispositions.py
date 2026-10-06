"""Requirement dispositions: waivers and exceptions, each recorded and approved.

`verification/requirement-dispositions.yaml` holds two kinds of record. They
are kept apart because they say different things, and a reviewer has to be
able to tell them apart:

- A **waiver** accepts a requirement as not met. Its tests go on failing, as
  their items declare (`expect: FAIL`), and the requirement reads "waived"
  rather than "failing": the shortfall is known, and somebody named has
  accepted it. When the design is fixed the test passes, the gate calls the
  item stale, and the waiver is removed with the `expect: FAIL`.
- An **exception** is an instance the requirement itself permits to differ --
  a register that may go without a reset, say. The test checking the
  requirement asks `check()` for its exceptions, fails on any instance not
  listed, and fails on any listed instance that no longer needs one, so the
  record cannot drift from the design. A requirement whose tests pass with
  approved exceptions applied reads "passing, with exceptions".

Neither applies until it names who approved it and when. One with
`approved_by: UNASSIGNED` is shown as proposed and changes nothing: a test
treats its subjects as violations, and a waiver's requirement stays failing.
"""

from __future__ import annotations

import datetime
import re
from dataclasses import dataclass
from pathlib import Path

import yaml

DISPOSITIONS = Path(__file__).resolve().parents[1] / "requirement-dispositions.yaml"
UNASSIGNED = "UNASSIGNED"
WAIVER_ID = re.compile(r"WVR-[A-Z]+-\d+")
EXCEPTION_ID = re.compile(r"EXC-[A-Z]+-\d+")


@dataclass
class Waiver:
    id: str
    requirement: str
    reason: str
    approved_by: str
    date: str
    reference: str = ""          # an external record, such as a deviation number

    @property
    def approved(self) -> bool:
        return bool(self.approved_by) and self.approved_by != UNASSIGNED


@dataclass
class ExceptionRecord:
    id: str
    requirement: str
    subjects: list
    reason: str
    approved_by: str
    date: str

    @property
    def approved(self) -> bool:
        return bool(self.approved_by) and self.approved_by != UNASSIGNED


def _text(raw: dict, key: str) -> str:
    return " ".join(str(raw.get(key) or "").split())


def _approval(where: str, approved_by: str, date: str) -> None:
    if not approved_by:
        raise ValueError(f"{where}: approved_by is required ({UNASSIGNED} until approved)")
    if approved_by != UNASSIGNED:
        try:
            datetime.date.fromisoformat(date)
        except ValueError:
            raise ValueError(f"{where}: approved by {approved_by}, so date must be "
                             f"YYYY-MM-DD, not {date!r}") from None


def load(path: Path = DISPOSITIONS) -> tuple:
    """(waivers, exceptions), every one recorded. A malformed record stops
    whatever reads it rather than being skipped, which would quietly turn a
    waived requirement back into a failing one or an exception into a gap."""
    if not path.is_file():
        return [], []
    raw = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    waivers, exceptions, seen = [], [], set()
    for n, w in enumerate(raw.get("waivers") or [], 1):
        where = f"{path.name} waiver {w.get('id') or n}"
        rec = Waiver(id=_text(w, "id"), requirement=_text(w, "requirement"),
                     reason=_text(w, "reason"), approved_by=_text(w, "approved_by"),
                     date=_text(w, "date"), reference=_text(w, "reference"))
        if not WAIVER_ID.fullmatch(rec.id):
            raise ValueError(f"{where}: id must look like WVR-PF-01")
        if not rec.requirement or not rec.reason:
            raise ValueError(f"{where}: requirement and reason are required")
        _approval(where, rec.approved_by, rec.date)
        waivers.append(rec)
    for n, e in enumerate(raw.get("exceptions") or [], 1):
        where = f"{path.name} exception {e.get('id') or n}"
        subjects = e.get("subjects")
        if not isinstance(subjects, list) or not subjects:
            raise ValueError(f"{where}: subjects must be a list naming what is excepted")
        rec = ExceptionRecord(id=_text(e, "id"), requirement=_text(e, "requirement"),
                              subjects=[str(s).strip() for s in subjects],
                              reason=_text(e, "reason"), approved_by=_text(e, "approved_by"),
                              date=_text(e, "date"))
        if not EXCEPTION_ID.fullmatch(rec.id):
            raise ValueError(f"{where}: id must look like EXC-PF-01")
        if not rec.requirement or not rec.reason:
            raise ValueError(f"{where}: requirement and reason are required")
        if len(set(rec.subjects)) != len(rec.subjects):
            raise ValueError(f"{where}: a subject is listed twice")
        _approval(where, rec.approved_by, rec.date)
        exceptions.append(rec)
    for rec in waivers + exceptions:
        if rec.id in seen:
            raise ValueError(f"{path.name}: {rec.id} is recorded twice")
        seen.add(rec.id)
    listed = {}
    for rec in exceptions:
        for s in rec.subjects:
            if (rec.requirement, s) in listed:
                raise ValueError(f"{path.name}: {s} is excepted from {rec.requirement} by both "
                                 f"{listed[(rec.requirement, s)]} and {rec.id}")
            listed[(rec.requirement, s)] = rec.id
    return waivers, exceptions


def excepted(requirement: str, path: Path = DISPOSITIONS) -> dict:
    """Subject -> the approved exception that permits it, for one requirement."""
    return {s: rec for rec in load(path)[1]
            if rec.requirement == requirement and rec.approved for s in rec.subjects}


def check(requirement: str, found, path: Path = DISPOSITIONS) -> tuple:
    """(unlisted, stale) for the instances a test found differing.

    `unlisted`: found, and no approved exception permits it -- the requirement
    is not met. `stale`: excepted, and no longer found -- the record has drifted
    from the design, and the exception should be removed. A test passes only
    when both are empty.
    """
    found = set(found)
    allowed = excepted(requirement, path)
    return sorted(found - set(allowed)), sorted(set(allowed) - found)
