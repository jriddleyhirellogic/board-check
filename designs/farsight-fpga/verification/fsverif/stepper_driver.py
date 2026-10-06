"""The stepper driver's input timing, read from the DRV8434 datasheet.

Like the oscillators (`fsverif.oscillators`), the figures come from the
datasheet text in the workspace's `board-check/datasheets`, so a record cites
the datasheet's own table rather than a number typed here.
"""

from __future__ import annotations

import re

from fsverif.design import Record
from fsverif.oscillators import datasheet_text

#: Indexer Timing Requirements: key -> (symbol as printed, regex for its row)
_ROWS = {
    "period": ("fSTEP", r"(\d)\s+[ƒf]STEP\s+Step frequency\s+(\d+)(?:\(\d\))?\s+kHz"),
    "high": ("tWH(STEP)", r"(\d)\s+tWH\(STEP\)\s+Pulse duration, STEP high\s+(\d+)\s+ns"),
    "low": ("tWL(STEP)", r"(\d)\s+tWL\(STEP\)\s+Pulse duration, STEP low\s+(\d+)\s+ns"),
    "setup": ("tSU(DIR, Mx)", r"(\d)\s+tSU\(DIR, Mx\)\s+Setup time, DIR or MODEx to STEP rising\s+(\d+)\s+ns"),
    "hold": ("tH(DIR, Mx)", r"(\d)\s+tH\(DIR, Mx\)\s+Hold time, DIR or MODEx to STEP rising\s+(\d+)\s+ns"),
}


def drv8434(r: Record) -> dict:
    """The DRV8434's STEP/DIR minima, in ns, recorded on `r` with their source."""
    path, text = datasheet_text("drv8434*.pdf")
    doc = re.search(r"(SLOS\w+) – .*?REVISED (\w+ \d{4})", text)
    section = re.search(r"^(\d+\.\d+) Indexer Timing Requirements\s*$", text, re.M)
    where = "%s (%s, revised %s), %s Indexer Timing Requirements" % (
        path.name, doc.group(1), doc.group(2).title(), section.group(1))
    out = {}
    for key, (symbol, pattern) in _ROWS.items():
        m = re.search(pattern, text)
        value = float(m.group(2))
        if key == "period":
            out[key] = 1e6 / value
            r.given("DRV8434 %s" % symbol, "at most %g kHz, so a step period of at least %g ns"
                    % (value, out[key]), "", "%s, row %s" % (where, m.group(1)))
        else:
            out[key] = value
            r.given("DRV8434 %s" % symbol, "at least %g" % value, "ns",
                    "%s, row %s" % (where, m.group(1)))
    return out
