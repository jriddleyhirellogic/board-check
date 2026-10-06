"""When each signal changed, to the clock cycle, without polling.

Polling is right for waiting and wrong for ordering. Two signals that change
in the same poll interval are indistinguishable, and tightening the interval
to resolve a few clock cycles costs a cocotb wake-up every few cycles.

A value-change callback costs nothing while the signal is still -- but it is
not free per evaluation either. Verilator checks every registered callback on
every evaluation, so the cost is per *watched signal*, not per transition.
Watch the handful a test needs at the moment, and read levels for the rest;
or watch many, but only across the short window where they move.
"""

from __future__ import annotations

import cocotb
from cocotb.triggers import ValueChange
from cocotb.utils import get_sim_time


class Edges:
    """Every transition of the given signals, in ms from `origin_ns`.

    Signals are given as names on `dut` or as handles; a handle is keyed by
    its own name.
    """

    def __init__(self, dut, signals, origin_ns: float | None = None):
        self.origin_ns = get_sim_time("ns") if origin_ns is None else origin_ns
        handles = [getattr(dut, s) if isinstance(s, str) else s for s in signals]
        self.events = {h._name: [] for h in handles}
        self._tasks = [cocotb.start_soon(self._watch(h)) for h in handles]

    def now_ms(self) -> float:
        return (get_sim_time("ns") - self.origin_ns) / 1e6

    async def _watch(self, handle) -> None:
        while True:
            await ValueChange(handle)
            self.events[handle._name].append((self.now_ms(), int(handle.value)))

    def rises(self, name: str) -> list:
        return [t for t, v in self.events[name] if v]

    def falls(self, name: str) -> list:
        return [t for t, v in self.events[name] if not v]

    def first_rise(self, name: str):
        rises = self.rises(name)
        return rises[0] if rises else None

    def stop(self) -> None:
        for task in self._tasks:
            task.cancel()
