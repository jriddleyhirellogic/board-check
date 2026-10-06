"""SLVS-EC lane recovery: PF-XCVR-03 and PF-XCVR-07.

Items: VC-PF-0115, VC-PF-0116. Clause: VVP-PF-001.

  PF-XCVR-03  The SLVS-EC receiver correction path shall flag a lane after a
              bounded run of consecutive disparity errors.
  PF-XCVR-07  The SLVS-EC receiver correction path shall reset the camera lane
              receiver after a qualifying lane-error condition, holding the
              reset for at least 32 cycles of the 50 MHz system clock, 640 ns
              (TBR).

**The DUT is `XCVR_DISPARITY_CORRECTION`** at the parameters `cam_rx_hier`
gives it (8 lanes, a 16-error threshold, a 32-clock reset, first-lock
detection on), clocked as the build clocks it:

- **`P_CLK_I`** is the 50 MHz system clock (`cam_spi_apb_clk`,
  `pll_sys_clk_50mhz` OUT0).
- **Each `LANEx_RX_CLK_I`** is that lane's recovered clock, 118.8 MHz:
  4752 Mbit/s with a 32-bit fabric interface and 8b10b coding, the
  8.41751 ns period in the build's derived constraints. Each lane's recovered
  clock has its own phase; here each starts at a different offset, and the
  trials below step the phase further.

`RX_RST_CONTROL_O` drives the PCS reset of all eight lanes (`pcs_arst_n`), so
it is the receiver reset `PF-XCVR-07` means, and it is the only thing outside
the block that a lane flag changes: a flag is visible only as that reset and
its interrupt. The lane model drops `RX_VALID` while the reset is asserted and
restores it 1 us after, as a PCS relocking would.

The block starts by resetting the receiver once, when all lanes first become
valid (first lock); each test brings the lanes up through that first.
"""

from __future__ import annotations

import re
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge, Timer
from cocotb.utils import get_sim_time

from fsverif import sim

REPO = Path(__file__).resolve().parents[2]
P_NS = 20.0
LANE_NS = 8.41751
LANE_PS = 8418                 # the simulator's picosecond grid
LANES = 8
MIN_RESET_CYCLES = 32          # PF-XCVR-07's (TBR) minimum, in P_CLK cycles


def _params() -> dict:
    text = (REPO / "bd" / "mpf500ts-fc1152m" / "cam_rx_hier" / "components"
            / "cam_rx_hier.tcl").read_text()
    block = re.search(r"-instance_name \{xcvr_disparity_correction_inst\} -params \{(.*?)\}",
                      text, re.S).group(1)
    return {k: int(v) for k, v in re.findall(r'"(\w+):(\d+)"', block)}


def _now_ns() -> float:
    return get_sim_time("ns")


class Lanes:
    def __init__(self, dut):
        self.dut = dut
        self.clk = [getattr(dut, "LANE%d_RX_CLK_I" % n) for n in range(LANES)]
        self.valid = [getattr(dut, "LANE%d_RX_VALID_I" % n) for n in range(LANES)]
        self.cal = [getattr(dut, "LANE%d_CALIBRATING_I" % n) for n in range(LANES)]
        self.err = [getattr(dut, "LANE%d_DISPARITY_ERR_I" % n) for n in range(LANES)]
        self.resets = []           # (start ns, end ns) of each RX_RST_CONTROL_O low
        self.interrupts = []       # ns of each interrupt pulse

    async def start(self) -> None:
        dut = self.dut
        cocotb.start_soon(Clock(dut.P_CLK_I, P_NS, unit="ns").start())
        for n in range(LANES):
            cocotb.start_soon(self._lane_clock(n, n * LANE_NS / LANES))
            self.valid[n].value = 0
            self.cal[n].value = 0
            self.err[n].value = 0
        dut.RESET_N_I.value = 1
        await ClockCycles(dut.P_CLK_I, 2)
        dut.RESET_N_I.value = 0
        await ClockCycles(dut.P_CLK_I, 5)
        dut.RESET_N_I.value = 1
        await ClockCycles(dut.P_CLK_I, 5)
        cocotb.start_soon(self._watch_reset())
        cocotb.start_soon(self._watch_interrupt())
        # Bring-up as the transceiver does it: calibrate, then valid data.
        for c in self.cal:
            c.value = 1
        await Timer(2, unit="us")
        for c in self.cal:
            c.value = 0
        await Timer(1, unit="us")
        for v in self.valid:
            v.value = 1
        await Timer(5, unit="us")       # the first-lock reset and its recovery

    async def _lane_clock(self, n: int, offset_ns: float) -> None:
        if offset_ns > 0:
            await Timer(round(offset_ns * 1000), unit="ps")
        await Clock(self.clk[n], LANE_PS, unit="ps").start()

    async def _watch_reset(self) -> None:
        dut = self.dut
        while True:
            await FallingEdge(dut.RX_RST_CONTROL_O)
            start = _now_ns()
            for v in self.valid:
                v.value = 0
            await RisingEdge(dut.RX_RST_CONTROL_O)
            self.resets.append((start, _now_ns()))
            await Timer(1, unit="us")
            for v in self.valid:
                v.value = 1

    async def _watch_interrupt(self) -> None:
        while True:
            await RisingEdge(self.dut.RX_RST_CONTROL_INTERRUPT_O)
            self.interrupts.append(_now_ns())

    async def run_of(self, lane: int, errors: int, skew_ps: int = 0) -> None:
        """`errors` consecutive disparity-error samples on one lane, then clean."""
        clk = self.clk[lane]
        await FallingEdge(clk)
        if skew_ps:
            await Timer(skew_ps, unit="ps")
            await FallingEdge(clk)
        self.err[lane].value = 0b0001
        await ClockCycles(clk, errors, rising=True)
        await FallingEdge(clk)
        self.err[lane].value = 0


async def _trials(dut, lanes: Lanes, errors: int, phases: int):
    """Runs of `errors` on every lane at several phases; returns (reacted, total)."""
    reacted = total = 0
    for lane in range(LANES):
        for phase in range(phases):
            before = len(lanes.resets)
            # Step the run's start against P_CLK: the lane and P_CLK are
            # unrelated clocks, so where a run ends falls anywhere in P_CLK.
            await Timer(round(P_NS * 1000 * phase / phases) + 1, unit="ps")
            await lanes.run_of(lane, errors)
            await Timer(3, unit="us")
            total += 1
            if len(lanes.resets) > before:
                reacted += 1
                await Timer(2, unit="us")         # recovery
    return reacted, total


# -----------------------------------------------------------------------------

@cocotb.test()
async def test_PF_XCVR_03_flag_after_disparity_run(dut):
    """VC-PF-0115: 16 consecutive errors flag the lane; 15 do not."""
    lanes = Lanes(dut)
    await lanes.start()
    problems = []
    first = len(lanes.resets)
    dut._log.info("first-lock resets during bring-up: %d", first)

    reacted, total = await _trials(dut, lanes, 15, phases=2)
    dut._log.info("runs of 15: %d of %d reset the receiver", reacted, total)
    if reacted:
        problems.append("%d of %d runs of 15 errors reset the receiver" % (reacted, total))

    flags = {n: 0 for n in range(LANES)}

    async def count(n):
        sig = getattr(dut, "lane%d_err_flag" % n)
        while True:
            await RisingEdge(sig)
            flags[n] += 1
    tasks = [cocotb.start_soon(count(n)) for n in range(LANES)]
    reacted, total = await _trials(dut, lanes, 16, phases=5)
    for t in tasks:
        t.cancel()
    dut._log.info("runs of 16: the lane flag rose %d times in %d runs (by lane %s); "
                  "%d runs reset the receiver", sum(flags.values()), total, flags, reacted)
    if reacted != total:
        problems.append(
            "of %d runs of 16 errors, %d reset the receiver and %d did not. Each run "
            "raised its lane's flag (%d flags) for one 118.8 MHz lane clock, 8.4 ns, "
            "and the 50 MHz P_CLK domain samples it through a two-flop synchroniser "
            "every 20 ns" % (total, reacted, total - reacted, sum(flags.values())))

    # Characterisation: how long a run it takes to be acted on every time.
    for run in (32, 48, 64, 160):
        reacted, total = await _trials(dut, lanes, run, phases=3)
        dut._log.info("runs of %d: %d of %d reset the receiver", run, reacted, total)
    assert not problems, "\n  ".join(["PF-XCVR-03:"] + problems)


@cocotb.test()
async def test_PF_XCVR_07_reset_after_qualifying_lane_error(dut):
    """VC-PF-0116: a qualifying error resets the receiver for at least 640 ns, then releases."""
    lanes = Lanes(dut)
    await lanes.start()
    params = _params()
    problems = []
    for lane in (0, 3, 7):
        before_r, before_i = len(lanes.resets), len(lanes.interrupts)
        await lanes.run_of(lane, 400)          # 25 flags: certain to be seen
        await Timer(5, unit="us")
        resets = lanes.resets[before_r:]
        ints = lanes.interrupts[before_i:]
        widths = [(e - s) / P_NS for s, e in resets]
        dut._log.info("lane %d, 400 errors: %d resets, %s P_CLK cycles low (%s ns); "
                      "%d interrupts", lane, len(resets),
                      ["%.1f" % w for w in widths],
                      ["%.0f" % (e - s) for s, e in resets], len(ints))
        if not resets:
            problems.append("lane %d: 400 consecutive errors did not reset the receiver" % lane)
            continue
        if any(w < MIN_RESET_CYCLES - 0.01 for w in widths):
            problems.append(
                "lane %d: the reset was low for %s P_CLK cycles, %s ns, under the %d "
                "cycles (%d ns) required; RST_CNT_CLKS is %d"
                % (lane, ["%.1f" % w for w in widths],
                   ["%.0f" % (e - s) for s, e in resets], MIN_RESET_CYCLES,
                   MIN_RESET_CYCLES * P_NS, params["RST_CNT_CLKS"]))
        if len(ints) != len(resets):
            problems.append("lane %d: %d resets but %d interrupts" % (lane, len(resets), len(ints)))
        if int(dut.RX_RST_CONTROL_O.value) != 1:
            problems.append("lane %d: the reset was not released" % lane)
    assert not problems, "\n  ".join(["PF-XCVR-07:"] + problems)


# -----------------------------------------------------------------------------

def test_pf_xcvr():
    sim.run(hdl_toplevel="XCVR_DISPARITY_CORRECTION",
            sources=sim.block("xcvr_disparity_correction", "xcvr_disparity_correction.v"),
            test_module="test_pf_xcvr", parameters=_params())
