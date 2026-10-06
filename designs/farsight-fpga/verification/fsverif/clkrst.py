"""Clock and reset helpers shared by the PolarFire FPGA testbenches.

The PolarFire design has many clock domains -- the fabric clocks from PF_CCC,
the DDR4 user clocks, the transceiver recovered clocks -- so nothing here
assumes one. Every helper takes the clock it acts on and, where it counts
cycles, that clock's period.

`advance` exists because waking cocotb on every clock edge is what makes long
simulations slow: `ClockCycles(clk, n)` wakes it `n` times, and a single timed
wait wakes it once. Short waits in cycles can use `ClockCycles` directly.
"""

from __future__ import annotations

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, Timer


def start_clock(clk, period_ns: float):
    """Start a free-running clock on ``clk`` and return the driver task."""
    return cocotb.start_soon(Clock(clk, period_ns, unit="ns").start())


async def advance(clk, seconds: float = 0.0, cycles: int = 0,
                  period_ns: float | None = None) -> None:
    """Let the design run, without waking cocotb on every clock edge.

    ``cycles`` needs ``period_ns``, the period of ``clk``: this environment
    has no single clock to assume. Realigns to a rising edge before
    returning, so a caller that samples immediately afterwards sees a settled
    value rather than one mid-flight.
    """
    if cycles and period_ns is None:
        raise ValueError("advance(cycles=...) needs the clock's period_ns")
    total_ns = seconds * 1e9 + (cycles * period_ns if cycles else 0.0)
    if total_ns > 0:
        await Timer(round(total_ns), unit="ns", round_mode="round")
    await RisingEdge(clk)


async def reset(clk, rstn, cycles: int = 10, active_low: bool = True) -> None:
    """Assert then deassert a reset, leaving the DUT ready on the next edge."""
    rstn.value = 0 if active_low else 1
    await ClockCycles(clk, cycles)
    rstn.value = 1 if active_low else 0
    await ClockCycles(clk, cycles)


async def until(clk, predicate, *, timeout_s: float, poll_us: float = 1.0,
                describe=None) -> float:
    """Run until `predicate()` holds, returning how long that took in seconds.

    A fixed wait long enough for the slowest case hides when something gets
    slower, and one tuned to the fastest fails on a loaded machine. Polling
    reports the time, so a test can proceed as soon as the design is ready
    and say how long it waited.
    """
    waited = 0.0
    while True:
        await advance(clk, seconds=poll_us / 1e6)
        waited += poll_us / 1e6
        if predicate():
            return waited
        if waited >= timeout_s:
            detail = ": %s" % describe() if describe else ""
            raise TimeoutError("still not true after %g s of simulated time%s"
                               % (waited, detail))
