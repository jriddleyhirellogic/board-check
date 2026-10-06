"""Oscillator frequency error, read from the parts' own datasheets.

The datasheets are not in this repository; they are kept with the board in
the workspace's `board-check/datasheets`. Each part number is decoded by its
maker's ordering scheme, and the figure for the decoded option is read from
the datasheet text (`pdftotext`), so the record cites the datasheet rather
than a number typed here. Absent the datasheets or `pdftotext`, the analyses
that need them skip.

`sys_clock_budget` records the 50 MHz system clock's source and total error,
for any analysis of a bound timed from that clock.
"""

from __future__ import annotations

import re
import shutil
import subprocess
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

import pytest

from fsverif import board
from fsverif.board import PF, WORKSPACE
from fsverif.build import retained
from fsverif.design import BD, find

DATASHEETS = WORKSPACE / "board-check" / "datasheets"

# Not yet defined by the programme; stated as owner decisions, TBR.
LIFE_YEARS = 5
RANGE_C = (-55, 125)
DECISION = "owner decision 2026-10-02, TBR"
FLIGHT = re.compile(r"^XD?35T-")

TOP = BD / "top" / "components" / "top.tcl"


@dataclass(frozen=True)
class Oscillator:
    part: str
    mhz: float
    ppm: float                  # the datasheet's stability or overall accuracy
    low: int                    # rated range, deg C
    high: int
    aging_included: int | None  # years of aging inside `ppm`; None if included for an unstated life
    first_year: float           # aging, ppm, worst stated
    per_year: float             # aging after the first year, ppm, worst stated
    space: bool                 # radiation-characterised, screened
    source: str                 # the datasheet and what in it was read

    def total(self, years: float) -> float | None:
        """Total error over `years` of life, or None if the datasheet does not say."""
        if self.aging_included is None:
            return None
        if self.aging_included >= years:
            return self.ppm
        start = self.aging_included
        extra = 0.0
        if start == 0:
            extra += self.first_year
            start = 1
        return self.ppm + extra + (years - start) * self.per_year

    def covers(self, low: int, high: int) -> bool:
        return self.low <= low and self.high >= high


@lru_cache(maxsize=None)
def datasheet_text(pattern: str) -> tuple[Path, str]:
    """The newest datasheet matching `pattern`, as layout text; skips if there is none."""
    found = sorted(DATASHEETS.glob(pattern))
    if not found:
        pytest.skip("no datasheet %s in %s" % (pattern, DATASHEETS))
    if not shutil.which("pdftotext"):
        pytest.skip("pdftotext is not installed")
    out = subprocess.run(["pdftotext", "-layout", str(found[-1]), "-"], capture_output=True,
                         text=True, check=True).stdout
    if not out.strip():
        # A PDF passed through a text-mode copy keeps its header but loses every stream.
        raise ValueError("%s yields no text; it is not a readable PDF" % found[-1])
    return found[-1], out


def _xsis(part: str) -> Oscillator:
    m = re.match(r"^(XD?35T)-([ALNR])(\d)([XM])(R?)-([\d.]+)MHZ$", part)
    path, text = datasheet_text("%s.pdf" % m.group(1))
    opt = re.search(r"\b%s = \+ (\d+) PPM over\s+(-?\d+) oC\s+to\s+\+?(-?\d+) oC" % m.group(3), text)
    years = re.search(r"(\d+) year aging|[Aa]ging over (\d+) years", text)
    first = [float(x) for x in re.findall(r"\+\s*(\d+(?:\.\d+)?) PPM Max\.? first year", text)]
    after = [float(x) for x in re.findall(r"\+\s*(\d+(?:\.\d+)?) PPM Max\.? per year thereafter", text)]
    return Oscillator(
        part, float(m.group(6)), float(opt.group(1)), int(opt.group(2)), int(opt.group(3)),
        int(years.group(1) or years.group(2)), max(first), max(after),
        "50K Rads" in text and m.group(4) == "M",
        "%s: option %s, '+ %s PPM over %s to %s oC', overall accuracy including %s-year aging; "
        "aging after that %s ppm/yr (worst stated)" % (
            path.name, m.group(3), opt.group(1), opt.group(2), opt.group(3),
            years.group(1) or years.group(2), max(after)))


def _ecs(part: str) -> Oscillator:
    m = re.match(r"^ECS-3225MVQ-(\d+)-([A-D])([MNPS])(-TR\d?)?$", part)
    path, text = datasheet_text("ECS-3225MVQ*.pdf")
    stab = re.search(r"\b%s\s*=\s*±(\d+) ppm" % m.group(2), text)
    rng = re.search(r"\b%s = (-?\d+) ~ \+?(-?\d+)°C" % m.group(3), text)
    aging = re.search(r"Aging\s+Per year\s+±(\d+)\s*ppm", text)
    mhz = int(m.group(1)) / 10
    return Oscillator(
        part, mhz, float(stab.group(1)), int(rng.group(1)), int(rng.group(2)), 0,
        float(aging.group(1)), float(aging.group(1)), False,
        "%s: stability %s = +/-%s ppm (initial, temperature, supply, load, reflow; not aging), "
        "range %s = %s to %s C, aging +/-%s ppm per year" % (
            path.name, m.group(2), stab.group(1), m.group(3), rng.group(1), rng.group(2),
            aging.group(1)))


def _renesas_xl(part: str) -> Oscillator:
    m = re.match(r"^XL([HJLMPQXY])([357])([23])([0568])(\d{3}\.\d{6})([IKX])$", part)
    path, text = datasheet_text("REN_XL*.pdf")
    row = re.search(r"“%s” and “%s”\s+(-?\d+)°C? to \+?(-?\d+)°C\s+-(\d+)\s+\+(\d+)"
                    % (m.group(4), m.group(6)), text)
    note = re.search(r"Stability is inclusive of[^.]*aging[^.]*\.", text)
    return Oscillator(
        part, float(m.group(5)), float(row.group(4)), int(row.group(1)), int(row.group(2)),
        None if note else 0, 0.0, 0.0, False,
        "%s: precision '%s' and range '%s' = +/-%s ppm, %s to %s C; '%s' -- no life is stated "
        "for the aging" % (path.name, m.group(4), m.group(6), row.group(4), row.group(1),
                           row.group(2), note.group(0) if note else "aging not included"))


def oscillator(part: str) -> Oscillator:
    """The figures for a fitted part, from its datasheet."""
    if re.match(r"^XD?35T-", part):
        return _xsis(part)
    if part.startswith("ECS-3225MVQ"):
        return _ecs(part)
    if part.startswith("XL"):
        return _renesas_xl(part)
    raise KeyError("no datasheet decoder for %s" % part)


# ---------------------------------------------------------------------------
# Budgets, recorded

def assumptions(r):
    r.given("Mission life", LIFE_YEARS, "years", DECISION)
    r.given("Operating temperature", "%d to %+d" % RANGE_C, "C",
            DECISION + ": the flight parts' rated range")
    r.given("Flight fit", "Xsis X35T / XD35T, the space-grade option on each net", "",
            "owner decision 2026-10-02")


def oscillators_on(sch, pin):
    """The oscillators whose output reaches a PolarFire pin."""
    net = sch.pin(PF, pin).net
    return net, sorted({p.component for p in sch.reach(net) if p.component.startswith("Y")})


def budget(r, sch, designators, label):
    """Record every fitted option; return the flight part's total, or None."""
    flight_total = None
    for y in designators:
        part = sch.parts[y][0]
        o = oscillator(part)
        total = o.total(LIFE_YEARS)
        covers = o.covers(*RANGE_C)
        is_flight = bool(FLIGHT.match(part))
        r.given("%s, %s %s%s" % (label, y, part, " (flight)" if is_flight else " (alternate, not flown)"),
                "%s ppm at %d years; rated %d to %+d C%s" % (
                    "+/-%.0f" % total if total is not None else "unstated",
                    LIFE_YEARS, o.low, o.high, "" if covers else ", **not over the operating range**"),
                "", o.source)
        if is_flight:
            flight_total = total if covers else None
    return flight_total


def sys_clock_budget(r):
    """The 50 MHz system clock's source and total error."""
    b = retained()
    sch = board.schematic()
    pins = board.pin_report(b.designer)
    pin = pins["sys_clk_50mhz"][0]
    net, ys = oscillators_on(sch, pin)
    r.given("System clock input", "`sys_clk_50mhz`, pin %s, net %s" % (pin, net), "",
            "%s; %s" % (b.cite(b.designer / "top_pinrpt_number.rpt"), sch.name))
    ppm = budget(r, sch, ys, "50 MHz source")
    r.input("Fabric clocks from it: the system PLL's reference", find(TOP, r'"pll_sys_clk_50mhz_inst:REF_CLK_0" "sys_clkint_buf_inst:Y"'))
    r.input("which is the `sys_clk_50mhz` port", find(TOP, r'"sys_clk_50mhz" "sys_clkint_buf_inst:A"'))
    r.step("A PLL multiplies frequency by an exact ratio, so every clock it makes carries its "
           "reference's fractional error: **+/-%.0f ppm** on the 50 MHz domain and on every "
           "PLL output derived from it" % ppm)
    return ppm
