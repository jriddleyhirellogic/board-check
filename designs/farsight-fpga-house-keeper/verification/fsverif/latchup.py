"""Latching a booted source, one source and one route at a time (`HK-SRC-07`).

`HK-SRC-07`'s item asks for both routes -- nFAULT low, and PGOOD low -- on
every source. Written once here, because it is spread over several modules:
a latchup in a hardware region is global (`HK-LAT-02`), so each hardware
source needs a boot of its own, and at the flight parameters a boot is a
second of simulated time that nothing can shorten. Thirty-three sources in one
module would be the slowest thing in the suite by a factor of three; split by
region they run side by side.

A route exists only where the source has the input. Twenty-two sources have
no nFAULT wired -- their state machine's `nfault` is tied high in the RTL --
so the nFAULT route is exercised wherever there is a pin to drive, and the
PGOOD route everywhere.

**"Declared latched up" is observed as the source's enable falling.** A
latchup is not a pin; what the board sees is the enable deasserting, within
the 5 us input filter plus a few clocks (`HK-LAT-01`). A source that did not
latch keeps its enable: a PGOOD that fell without a latch leaves it asserted,
and a fault that is not connected changes nothing at all.
"""

from __future__ import annotations

import re

from cocotb.triggers import FallingEdge, SimTimeoutError, with_timeout
from cocotb.utils import get_sim_time

from fsverif import board, boot
from fsverif.clkrst import advance, until
from fsverif.pins import boundary

#: `HK-LAT-01`'s allowance: the 5 us filter, then synchroniser and state
#: machine. Not `HK-LAT-08`'s bound, whose value is TBR.
LATCH_US = 12.0

#: Long enough past a latch for its 2.294 ms hold to end and the region to
#: return to power-off, before the next request.
HOLD_MS = 3.0


def pgood_of(enable: str) -> str:
    return re.sub(r"_en(_|$)", r"_pgood\1", enable)


def routes(enable: str) -> list:
    """(route, rail control) pairs for one source: PGOOD always, nFAULT where
    the source has a fault pin."""
    rail = next(r for r in board.model() if r.pgood == pgood_of(enable))
    found = [("PGOOD low", {"fail": (rail.pgood,)})]
    if rail.nfault:
        found.append(("nFAULT low", {"fault": (rail.pgood,)}))
    return found


async def _fell_within(dut, enable: str, us: float):
    """Microseconds until `enable` fell, or None if it did not within `us`."""
    started = get_sim_time("ns")
    try:
        await with_timeout(FallingEdge(boundary(dut, enable)), round(us * 1000),
                           "ns")
    except SimTimeoutError:
        return None
    return (get_sim_time("ns") - started) / 1000.0


def _booted(dut, enable: str) -> str:
    if not int(boundary(dut, enable).value):
        return "%s was not asserted" % enable
    if not int(boundary(dut, pgood_of(enable)).value):
        return "%s was not good" % pgood_of(enable)
    return ""


async def hardware(dut, enables) -> list:
    """Each hardware source, each route, on a boot of its own."""
    problems = []
    for enable in enables:
        for route, drive in routes(enable):
            board.drive(dut)
            await boot.hardware(dut)
            wrong = _booted(dut, enable)
            if wrong:
                problems.append("%s, %s: not booted before the stimulus -- %s"
                                % (enable, route, wrong))
                continue
            board.drive(dut, **drive)
            took = await _fell_within(dut, enable, LATCH_US)
            dut._log.info("%-20s %-10s -> %s", enable, route,
                          "latched, %.2f us" % took if took is not None
                          else "NOT LATCHED")
            if took is None:
                problems.append("%s, %s: still asserted %.0f us later"
                                % (enable, route, LATCH_US))
    return problems


async def software(dut, regions) -> list:
    """Each software source, each route, in one boot.

    A software latch is contained (`HK-LAT-05`), so the region is re-requested
    after each one and the next route applied, with no reset between. Stepper
    Sec comes last: a booted Stepper Pri holds it down, so it is requested
    only once Stepper Pri has been latched for the last time and left down.
    """
    problems = []
    board.drive(dut)
    await boot.hardware(dut)

    for region, control, enables in regions:
        status = "%s_status_to_pf" % region
        for enable in enables:
            for route, drive in routes(enable):
                board.drive(dut)
                boundary(dut, control).value = 0
                await advance(dut.clk, seconds=HOLD_MS / 1000.0)
                boundary(dut, control).value = 1
                try:
                    await until(dut.clk,
                                lambda: int(boundary(dut, status).value) == 1,
                                timeout_s=0.5, poll_ms=0.1)
                except TimeoutError:
                    problems.append("%s, %s: %s never booted" % (enable, route,
                                                                 region))
                    continue
                wrong = _booted(dut, enable)
                if wrong:
                    problems.append("%s, %s: not booted before the stimulus "
                                    "-- %s" % (enable, route, wrong))
                    continue
                board.drive(dut, **drive)
                took = await _fell_within(dut, enable, LATCH_US)
                dut._log.info("%-20s %-10s -> %s", enable, route,
                              "latched, %.2f us" % took if took is not None
                              else "NOT LATCHED")
                if took is None:
                    problems.append("%s, %s: still asserted %.0f us later"
                                    % (enable, route, LATCH_US))
        # Leave the region down: it was latched last, and is not re-requested.
        boundary(dut, control).value = 0
        board.drive(dut)
    return problems
