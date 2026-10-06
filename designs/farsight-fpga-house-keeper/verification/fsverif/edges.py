"""When each pin changed, to the clock cycle, without polling.

Polling is right for waiting and wrong for ordering. Two enables that rise in
the same poll interval are indistinguishable, and `HK-REG-02` is precisely
about whether two enables rose together. Tightening the interval enough to
resolve a few clock cycles costs a cocotb wake-up every few clock cycles,
which is what made the first runs of this suite sixteen minutes long.

A value-change callback costs nothing while the pin is still -- but it is not
free per evaluation either. Verilator checks every registered callback on
every evaluation, twice per clock, so the cost is per *watched pin*, not per
transition. Nine pins cost about 5 %; fifty-eight made a run more than six
times slower. Watch the handful a test needs at the moment, and read levels
for the rest.

So this records every transition of the few pins it is given, with its
simulated time, and leaves the test to wait however it likes in the meantime.
"""

from __future__ import annotations

import cocotb
from cocotb.triggers import ValueChange
from cocotb.utils import get_sim_time

from fsverif.pins import boundary


class Edges:
    """Every transition of `names` from construction on, in ms from `origin_ns`."""

    def __init__(self, dut, names, origin_ns: float | None = None):
        self.origin_ns = get_sim_time("ns") if origin_ns is None else origin_ns
        self.events = {name: [] for name in names}
        self._tasks = [cocotb.start_soon(self._watch(boundary(dut, name), name))
                       for name in names]

    def now_ms(self) -> float:
        return (get_sim_time("ns") - self.origin_ns) / 1e6

    async def _watch(self, handle, name: str) -> None:
        while True:
            await ValueChange(handle)
            self.events[name].append((self.now_ms(), int(handle.value)))

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
