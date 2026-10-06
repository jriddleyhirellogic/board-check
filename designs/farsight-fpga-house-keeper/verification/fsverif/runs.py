"""Running the suite from the app.

The phases of a run, how to read pytest's output for progress, and `Job`,
which runs them in the background for the browser app (`fsverif.web`).

A run's processes get their own session (`start_new_session`), so cancelling
stops pytest, every xdist worker and every simulator they started -- not only
the parent.
"""

from __future__ import annotations

import os
import re
import signal
import subprocess
import sys
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path

from fsverif.evidence import REPO, VERIF

#: Where `make setup` puts Verilator; the Makefile adds the same to PATH.
EDA_PATH = Path.home() / ".local" / "opt" / "micromamba" / "envs" / "eda" / "bin"

#: The checks that need no simulator: `make test-fast`, less the app's own
#: server tests -- one of those starts this run, and would start itself.
FAST = ["tests/test_evidence_rules.py", "tests/test_build_variants.py",
        "tests/test_results.py"]

_TOTAL = re.compile(r"\[(\d+) items?\]|collected (\d+) items?")
#: A per-test result line under xdist: "[gw3] [ 45%] PASSED tests/x.py::y". The
#: end-of-run summary ("FAILED tests/x.py::y - ...") has no percentage, and
#: counting it would count a result twice.
_RESULT = re.compile(r"\[\s*\d+%\]\s+(PASSED|FAILED|ERROR|SKIPPED|XFAIL|XPASS)\s+"
                     r"(tests/\S+?\.py)(?:::(\S+))?")
_RESULT_ALT = re.compile(r"(tests/\S+?\.py)::(\S+)\s+(PASSED|FAILED|ERROR|SKIPPED)")


@dataclass
class Phase:
    description: str
    argv: list
    cwd: Path
    env: dict = field(default_factory=dict)
    #: Run even after an earlier phase failed. The coverage report is wanted
    #: after a suite that failed, which this suite always does: it has known
    #: shortfalls.
    always: bool = False


def phases(files: list | None = None, label: str = "the whole suite", simulate: bool = True,
           coverage: bool = True, report_only: bool = False, workers: str = "auto") -> list:
    """What a run does. A simulation starts by clearing the last run's code
    coverage, so the report describes this run alone; it measures coverage
    unless told not to, and writes the report after, whether or not tests
    failed."""
    report = Phase("Writing the coverage report",
                   [sys.executable, str(VERIF / "code_coverage.py")], VERIF, always=True)
    if report_only:
        return [report]
    # Inspections read the design rather than simulate it, and take seconds,
    # so every run includes them -- after the tests, and whether or not those
    # failed, so that neither can stop the other.
    inspect = Phase("Running the inspections",
                    [sys.executable, "-m", "pytest", "test/inspect", "-q",
                     "--junitxml=verification/results/results-inspect.xml"], REPO, always=True)
    out = []
    if simulate:
        out.append(Phase("Checking the vendor IP", ["make", "-s", "ip-ready"], REPO))
        out.append(Phase("Clearing the last run's coverage",
                         [sys.executable, str(VERIF / "code_coverage.py"), "--clear"], VERIF))
    out.append(Phase(f"Running {label}",
                     [sys.executable, "-m", "pytest", *(files or ["tests/"]), "-v", "-n",
                      workers, "--dist", "loadfile", "-p", "no:cacheprovider"],
                     VERIF, {"FSVERIF_COVERAGE": "1" if coverage else "0"} if simulate else {}))
    out.append(inspect)
    if simulate and coverage:
        out.append(report)
    return out


def environment(extra: dict | None = None) -> dict:
    env = dict(os.environ)
    env["PYTHONUNBUFFERED"] = "1"
    env["PATH"] = f"{EDA_PATH}{os.pathsep}{env.get('PATH', '')}"
    env.update(extra or {})
    return env


def parse(line: str):
    """('total', n), ('result', module, outcome), or None."""
    m = _TOTAL.search(line)
    if m:
        return ("total", int(m.group(1) or m.group(2)))
    m = _RESULT.search(line)
    if m:
        return ("result", Path(m.group(2)).stem, m.group(1))
    m = _RESULT_ALT.search(line)
    if m:
        return ("result", Path(m.group(1)).stem, m.group(3))
    return None


class Job:
    """One run, in a background thread. Poll `status()`; `cancel()` stops it."""

    MAX_LINES = 20000

    def __init__(self, plan: list, label: str):
        self.plan, self.label = plan, label
        self.lines: list = []
        self.phase = ""
        self.done = self.total = 0
        self.module = self.outcome = ""
        self.code = None            # None while running; -1 if cancelled
        self.started = time.time()
        self.ended = 0.0
        self.cancelled = False
        self._proc = None
        self._lock = threading.Lock()
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    @property
    def running(self) -> bool:
        return self.code is None

    def status(self, since: int = 0) -> dict:
        with self._lock:
            return {"label": self.label, "running": self.running, "phase": self.phase,
                    "done": self.done, "total": self.total, "module": self.module,
                    "outcome": self.outcome, "code": self.code,
                    "seconds": (self.ended or time.time()) - self.started,
                    "offset": len(self.lines), "lines": self.lines[since:]}

    def cancel(self) -> None:
        self.cancelled = True
        proc = self._proc
        if proc is not None and proc.poll() is None:
            try:
                os.killpg(proc.pid, signal.SIGTERM)
            except (ProcessLookupError, PermissionError):
                pass
            threading.Timer(3.0, self._kill, args=(proc,)).start()

    @staticmethod
    def _kill(proc) -> None:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass

    def _emit(self, line: str) -> None:
        with self._lock:
            self.lines.append(line)
            if len(self.lines) > self.MAX_LINES:
                del self.lines[: len(self.lines) - self.MAX_LINES]
            got = parse(line)
            if got and got[0] == "total" and not self.total:
                self.total = got[1]
            elif got and got[0] == "result":
                self.done += 1
                self.module, self.outcome = got[1], got[2]

    def _run(self) -> None:
        first = None
        for phase in self.plan:
            if self.cancelled:
                break
            if first not in (None, 0) and not phase.always:
                continue
            with self._lock:
                self.phase = phase.description
            self._emit("$ " + " ".join(str(a) for a in phase.argv))
            try:
                self._proc = subprocess.Popen(
                    [str(a) for a in phase.argv], cwd=phase.cwd, env=environment(phase.env),
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                    errors="replace", start_new_session=True)
            except OSError as exc:
                self._emit(f"could not start: {exc}")
                first = first if first not in (None, 0) else 1
                continue
            for line in self._proc.stdout:
                self._emit(line.rstrip("\n"))
            code = self._proc.wait()
            if first in (None, 0):
                first = code
        with self._lock:
            self.code = -1 if self.cancelled else (first or 0)
            self.ended = time.time()
        self._emit("cancelled" if self.cancelled else f"finished, exit {self.code}")
