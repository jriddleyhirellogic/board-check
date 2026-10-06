"""The PPS subsystem as the flight build instantiates it, for the PF-PPS tests.

The DUT is `pps_hier`, the SmartDesign the build generates -- not the `pps`
module alone. The requirements are about the path the design has: the local
generator and the external input meet at the mux, the mux feeds the
discipline input of `pps`, and firmware chooses between them through a
register. That path exists only in the SmartDesign's wiring, and a test of
`pps` alone would be testing a hand-made copy of it. `make ip` generates
`pps_hier` from its definition, as the build does, and the generated
`pps_hier.v` is byte-identical to the build's.

**Parameters are the build's.** `pps_hier` sets none, so every module runs at
its RTL defaults, and those are the synthesis values (`VENV-02`):
`pps_generator` at `CLOCK_FREQ_MHZ = 50`, `POLARITY = 1`; `pps` at
`CLOCK_PER = 20`. Both are fed from `sys_clk_50mhz`, which in the device is
the 50 MHz fabric clock -- 20 ns here.

**Two nets inside the top are read by name.** `pps_generator_inst_pps_out`
(the local generator) and `pps_mux_inst_pps_out` (the discipline input) are
nets of the SmartDesign itself, not ports; the runner makes the top module's
own nets reachable, and nothing below it. The names are Libero's, from the
generated netlist: if a regeneration renames them, these tests stop at an
`AttributeError` rather than passing on a different signal.

**Cost.** About 47 s of wall time per simulated second (1.06 M cycles/s under
Verilator). A clock generated in Verilog was measured at 2.25 M cycles/s --
the DUT's own evaluation dominates, so a generated wrapper would halve the
time and no more, and is not used. The long tests are split across files so
that they run in parallel.
"""

from __future__ import annotations

from cocotb.triggers import (ClockCycles, FallingEdge, ReadOnly, RisingEdge,
                             Timer, ValueChange)
from cocotb.utils import get_sim_time

from fsverif import sim
from fsverif.bfm.apb import Apb
from fsverif.clkrst import start_clock

TOP = "pps_hier"
CLK_PERIOD_NS = 20
CLOCK_HZ = 1_000_000_000 // CLK_PERIOD_NS          # 50,000,000
SECOND_NS = 1_000_000_000

# The generator's toggle interval, (CLOCK_FREQ_MHZ * 1e6) >> 1 clocks.
HALF_PERIOD_CLOCKS = CLOCK_HZ // 2

# Register map of `pps`, word addressed through paddr[5:2].
TIME_JAM, LOAD_SECONDS, RX_DELAY, EN_LOCAL_PPS = 0x0, 0x4, 0x8, 0xC
FREQUENCY_ERROR, PHASE_ERROR, SECONDS, NANOSECONDS = 0x10, 0x14, 0x18, 0x1C
CLEAR_IRQ = 0x20

LOCAL = "pps_generator_inst_pps_out"
DISCIPLINE = "pps_mux_inst_pps_out"


def sources():
    return (sim.block("pps_ip", "divider_with_remainder.sv", "pps_generator.sv",
                      "pps_mux.sv", "pps.sv")
            + sim.vendor(TOP))


def run(test_module: str, testcase: str) -> None:
    """Build `pps_hier` and run one cocotb test of `test_module` against it."""
    sim.run(hdl_toplevel=TOP, sources=sources(), test_module=test_module,
            testcase=[testcase], run_id="%s.%s" % (test_module, testcase))


def now_ns() -> int:
    return int(get_sim_time("ns"))


async def start(dut) -> Apb:
    """Clock, idle inputs, reset; returns the APB requester.

    Returns on the falling edge after the first rising edge at which the
    design sees reset released, so the caller knows exactly where cycle 0 is.
    """
    start_clock(dut.sys_clk_50mhz, CLK_PERIOD_NS)
    dut.pps_in.value = 0
    dut.sys_rst_n.value = 0
    apb = Apb(dut, dut.sys_clk_50mhz, "apb_pps_")
    await ClockCycles(dut.sys_clk_50mhz, 10)
    await FallingEdge(dut.sys_clk_50mhz)
    dut.sys_rst_n.value = 1
    await RisingEdge(dut.sys_clk_50mhz)
    await FallingEdge(dut.sys_clk_50mhz)
    return apb


class Watch:
    """Every change of one signal, in integer ns. Cheap: a handful of edges."""

    def __init__(self, handle):
        import cocotb
        self.handle, self.events = handle, []
        self._task = cocotb.start_soon(self._run())

    async def _run(self):
        while True:
            await ValueChange(self.handle)
            self.events.append((now_ns(), int(self.handle.value)))

    def rises(self):
        return [t for t, v in self.events if v]

    def falls(self):
        return [t for t, v in self.events if not v]

    def stop(self):
        self._task.cancel()


async def pulse(dut, high_clocks: int = 4) -> int:
    """A rising edge on `pps_in`, held `high_clocks`; returns its time in ns.

    Changed on a falling clock edge, so the synchroniser samples it cleanly.
    One timed wait rather than counting clocks, which would wake cocotb on
    every one of them; from a falling edge it ends on a falling edge.
    """
    await FallingEdge(dut.sys_clk_50mhz)
    dut.pps_in.value = 1
    at = now_ns()
    await Timer(high_clocks * CLK_PERIOD_NS, unit="ns")
    dut.pps_in.value = 0
    return at


async def sample_time(dut):
    """(seconds, nanoseconds) as the ports show them after this rising edge."""
    await RisingEdge(dut.sys_clk_50mhz)
    await ReadOnly()
    return int(dut.seconds.value), int(dut.nanoseconds.value)
