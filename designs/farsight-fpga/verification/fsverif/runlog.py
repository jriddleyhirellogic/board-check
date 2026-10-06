"""Keep each simulation's log, so a passing test's measurements are not lost.

A test reports what it measured through `dut._log` -- "last off 5.13 us after
the pin", "3.143 s after reset release". That is the evidence behind a pass,
and without a file it exists only on the console of whoever ran the suite:
the JUnit results carry a failure's message and nothing at all for a pass.

`sim.run_device` names a file in `FSVERIF_RUN_LOG` for the simulator process,
and importing `fsverif` there adds a handler writing every record to it. The
console output is untouched. Outside the simulator the variable is not set
and this does nothing.

One record per line, `<sim time>ns <LEVEL> <logger> <message>`, with the
lines of a multi-line message indented by four spaces -- a format
`verification/report.py` reads back.
"""

from __future__ import annotations

import logging
import os

ENV = "FSVERIF_RUN_LOG"


class _Formatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        from cocotb.utils import get_sim_time

        try:
            now = "%.2fns" % get_sim_time("ns")
        except Exception:
            now = "-"
        text = record.getMessage()
        if record.exc_info:
            text += "\n" + self.formatException(record.exc_info)
        first, *rest = text.splitlines() or [""]
        head = "%s %s %s %s" % (now, record.levelname, record.name, first)
        return "\n".join([head] + ["    " + line for line in rest])


def install() -> None:
    path = os.environ.get(ENV)
    if not path:
        return
    root = logging.getLogger()
    if any(getattr(h, "_fsverif_run_log", False) for h in root.handlers):
        return
    handler = logging.FileHandler(path, mode="w", encoding="utf-8")
    handler.setFormatter(_Formatter())
    handler._fsverif_run_log = True
    root.addHandler(handler)
