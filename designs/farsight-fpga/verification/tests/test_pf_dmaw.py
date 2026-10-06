"""DDR4 write stall flag: PF-DMAW-09.

Item: VC-PF-0040. Clause: VVP-PF-001.

  PF-DMAW-09  The DDR4 write DMA shall flag a stalled write transfer within
              10 ms +/-5%.

**The DUT is `dma_write_ctrl`**, once per bank: the write DMA's receive and
send controllers, whose send controller holds the watchdog. Its parameters
are not restated here but read, at run time, from what the build uses -- the
bank wrapper's localparams (`dma_write_ddr4_8gb.sv`, `dma_write_ddr4_16gb.sv`)
and the SmartDesign instance's `CLOCK_FREQ_MHZ` and `TIMEOUT_USEC`
(`dma_write_ddr4_*_hier.tcl:68-70`) -- so the test cannot drift from them.

**Why not the whole SmartDesign.** `dma_write_ddr4_*_hier` generates (`make
ip`) and is byte-identical to the build's, but its COREFIFO clock crossing
simulates at 97 s of wall time per simulated millisecond under Verilator,
against 0.22 s for `dma_write_ctrl`: an 11 ms stall would take eighteen
minutes a run. The FIFO is not part of the watchdog, so it is a model here (a
word one clock after each read), as are the arbiter and DDR4 controller
beyond it -- which is what lets a stall be made to order: a request never
acknowledged, or a burst acknowledged and never finished. Between this
controller's `apb_reg_timeout_err` and firmware is the register block's
two-flop synchroniser, 40 ns.

**Each bank runs at its own clock**, the user clock of its PF_DDR4 in the
build's derived constraints (`constraint/top_derived_constraints.sdc:48-55`):

| bank | PF_DDR4 | user clock | the watchdog's 1,500,000 cycles |
| --- | --- | --- | --- |
| 8GB | `PF_DDR4_C2`, 600 MHz DDR | 50 MHz x 3 = **150 MHz** | 10.000 ms |
| 16GB | `PF_DDR4_C0`, 550 MHz DDR | 50 MHz x 11 / 4 = **137.5 MHz** | 10.909 ms |

The test counts clocks from the start of the stall to the flag and converts
at the bank's real frequency. (The simulated periods are 6.666 and 7.272 ns,
exact in picoseconds; the count does not depend on them.) The 16GB bank
flags 10.909 ms after the stall, outside 10.5 ms, and the test fails on it:
its DMA is configured for 150 MHz and clocked at 137.5. `PF-F-28`.

**And a control**: a line written with the arbiter answering, the frame then
closed, and 11 ms more -- no flag. Without it a watchdog that fired on
anything would pass.
"""

from __future__ import annotations

import re
from pathlib import Path

import cocotb
from cocotb.triggers import ClockCycles, FallingEdge, ReadOnly, RisingEdge, ValueChange
from cocotb.utils import get_sim_time

from fsverif import sim
from fsverif.clkrst import advance, start_clock

REPO = Path(__file__).resolve().parents[2]
BOARD_BD = REPO / "bd" / "mpf500ts-fc1152m"
# bank: (real user clock MHz, simulated period ns)
BANKS = {"8gb": (150.0, 6.666), "16gb": (137.5, 7.272)}
PIXEL_NS = 12.626
LOW_MS, HIGH_MS = 9.5, 10.5


def parameters(bank: str) -> dict:
    """dma_write_ctrl's parameters as the build sets them for this bank."""
    wrapper = (REPO / ("ip/dma_write_ip/src/dma_write_ddr4_%s.sv" % bank)).read_text()
    params = {k: int(v) for k, v in
              re.findall(r"localparam integer (\w+)\s*=\s*(\d+)\s*;", wrapper)}
    params["FRAME_INDEX_WIDTH"] = params["USABLE_ADDR_WIDTH"] - params["FRAME_WIDTH"]
    hier = (BOARD_BD / ("ddr4_%s_hier" % bank) / "components"
            / ("dma_write_ddr4_%s_hier.tcl" % bank)).read_text()
    for name in ("CLOCK_FREQ_MHZ", "TIMEOUT_USEC"):
        params[name] = int(re.search(r'"%s:(\d+)"' % name, hier).group(1))
    return params


def _now_ps() -> int:
    return int(get_sim_time("ps"))


class Dma:
    def __init__(self, dut, bank: str, period_ns: float):
        self.dut, self.bank = dut, bank
        self.period_ps = round(period_ns * 1000)
        self.arbiter = "answer"          # or "no ack", "no done"
        self.acked_ps = None
        start_clock(dut.ddr_clk, period_ns)
        start_clock(dut.pixel_clk, PIXEL_NS)
        cocotb.start_soon(self._arbiter())
        cocotb.start_soon(self._fifo())

    async def reset(self) -> None:
        dut = self.dut
        for s in ("cam_frame_valid", "cam_line_valid", "cam_data_in",
                  "apb_reg_clear_index", "fifo_valid", "fifo_data",
                  "arb_write_ack", "arb_write_done"):
            getattr(dut, s).value = 0
        dut.apb_reg_h_size_byte.value = 6784
        dut.ddr_rst_n.value = 0
        dut.pixel_rst_n.value = 0
        await ClockCycles(dut.pixel_clk, 10)
        dut.ddr_rst_n.value = 1
        dut.pixel_rst_n.value = 1
        await ClockCycles(dut.pixel_clk, 10)

    async def _fifo(self) -> None:
        """A word one clock after each read -- the FIFO is not under test."""
        dut, clk = self.dut, self.dut.ddr_clk
        while True:
            # Woken on the clock whose edge made the first read.
            await RisingEdge(dut.fifo_read_en)
            while True:
                await FallingEdge(clk)
                dut.fifo_valid.value = 1
                dut.fifo_data.value = 0x5A
                await RisingEdge(clk)
                await ReadOnly()
                if not int(dut.fifo_read_en.value):
                    break
            await FallingEdge(clk)
            dut.fifo_valid.value = 0

    async def _arbiter(self) -> None:
        """Acknowledges a request and completes its burst -- unless told not to.

        Woken by the request's edge, not every clock.
        """
        dut, clk = self.dut, self.dut.ddr_clk
        while True:
            if not int(dut.arb_write_req.value):
                await RisingEdge(dut.arb_write_req)
            await RisingEdge(clk)
            await ReadOnly()
            if self.arbiter == "no ack":
                await FallingEdge(dut.arb_write_req)
                continue
            beats = int(dut.arb_write_burst_len.value) + 1
            await FallingEdge(clk)
            dut.arb_write_ack.value = 1
            self.acked_ps = _now_ps()
            await FallingEdge(clk)
            dut.arb_write_ack.value = 0
            if self.arbiter == "no done":
                continue
            seen = 0
            while seen < beats:
                await RisingEdge(clk)
                await ReadOnly()
                seen += int(dut.arb_write_valid.value)
            await FallingEdge(clk)
            dut.arb_write_done.value = 1
            await FallingEdge(clk)
            dut.arb_write_done.value = 0

    async def line(self, beats: int = 8) -> None:
        """One camera line of 384-bit words, opening the frame first."""
        dut = self.dut
        await FallingEdge(dut.pixel_clk)
        dut.cam_frame_valid.value = 1
        await ClockCycles(dut.pixel_clk, 20, rising=False)
        for n in range(beats):
            dut.cam_line_valid.value = 1
            dut.cam_data_in.value = (0xA5 << 376) | n
            await FallingEdge(dut.pixel_clk)
        dut.cam_line_valid.value = 0
        dut.cam_data_in.value = 0

    async def close_frame(self) -> None:
        await ClockCycles(self.dut.pixel_clk, 200, rising=False)
        self.dut.cam_frame_valid.value = 0

    async def flag_after(self, since_ps: int, limit_ms: float):
        """Clocks from `since_ps` to the flag rising, or None within `limit_ms`."""
        seen = []

        async def on_flag():
            while not int(self.dut.apb_reg_timeout_err.value):
                await ValueChange(self.dut.apb_reg_timeout_err)
            seen.append(_now_ps())
        task = cocotb.start_soon(on_flag())
        await advance(self.dut.ddr_clk, seconds=limit_ms / 1e3)
        task.cancel()
        return (seen[0] - since_ps) / self.period_ps if seen else None


@cocotb.test()
async def test_PF_DMAW_09_stall_flag_within_10ms(dut):
    """VC-PF-0040: a stalled write is flagged 9.5-10.5 ms after it begins."""
    bank = "16gb" if len(dut.arb_write_data) == 512 else "8gb"
    mhz, period = BANKS[bank]
    configured = parameters(bank)
    d = Dma(dut, bank, period)
    problems = []
    watchdog = configured["CLOCK_FREQ_MHZ"] * configured["TIMEOUT_USEC"]
    dut._log.info("%s bank: watchdog %d cycles (CLOCK_FREQ_MHZ %d), clocked at "
                  "%.1f MHz", bank, watchdog, configured["CLOCK_FREQ_MHZ"], mhz)

    # The clock is what it says: two rising edges, exactly one period apart.
    await RisingEdge(dut.ddr_clk)
    t0 = _now_ps()
    await RisingEdge(dut.ddr_clk)
    assert _now_ps() - t0 == d.period_ps, "the DDR clock is not the period asked for"

    # Control: an answered write, the frame closed, 11 ms more.
    await d.reset()
    await d.line()
    await d.close_frame()
    if await d.flag_after(_now_ps(), 11.0) is not None:
        problems.append("the flag rose with every write answered and the frame "
                        "closed; the stall measurements below would prove nothing")

    for kind, start_of in (("no ack", "request"), ("no done", "acknowledge")):
        await d.reset()
        d.arbiter, d.acked_ps = kind, None
        req = []

        async def on_req():
            await RisingEdge(dut.arb_write_req)
            req.append(_now_ps())
        task = cocotb.start_soon(on_req())
        await d.line()
        await ClockCycles(dut.ddr_clk, 200)
        task.cancel()
        begin = d.acked_ps if kind == "no done" else (req[0] if req else None)
        if begin is None:
            problems.append("%s: the DMA never reached the stall (no %s seen)"
                            % (kind, start_of))
            d.arbiter = "answer"
            continue
        cycles = await d.flag_after(begin, 12.0)
        d.arbiter = "answer"
        if cycles is None:
            problems.append("%s: no flag within 12 ms of the %s" % (kind, start_of))
            continue
        ms = cycles / (mhz * 1e3)
        dut._log.info("%s bank, %s: flagged %.1f clocks after the %s = %.3f ms at "
                      "%.1f MHz", bank, kind, cycles, start_of, ms, mhz)
        if not LOW_MS <= ms <= HIGH_MS:
            problems.append(
                "%s bank, %s: flagged %.3f ms after the %s -- %.0f clocks of its "
                "%.1f MHz user clock, outside %.1f-%.1f ms. The DMA counts %d "
                "cycles, for CLOCK_FREQ_MHZ = %d. PF-F-28."
                % (bank, kind, ms, start_of, cycles, mhz, LOW_MS, HIGH_MS,
                   watchdog, configured["CLOCK_FREQ_MHZ"]))
    assert not problems, "\n  ".join(["PF-DMAW-09:"] + problems)


def _run(bank: str) -> None:
    sim.run(hdl_toplevel="dma_write_ctrl",
            sources=sim.block("dma_write_ip", "wconv_4in_3out.sv",
                              "dma_write_recv_ctrl.sv", "dma_write_send_ctrl.sv",
                              "dma_write_ctrl.sv"),
            test_module="test_pf_dmaw", run_id="test_pf_dmaw.%s" % bank,
            parameters=parameters(bank))


def test_pf_dmaw_09_8gb():
    _run("8gb")


def test_pf_dmaw_09_16gb():
    _run("16gb")
