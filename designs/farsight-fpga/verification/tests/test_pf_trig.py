"""Camera trigger generator: PF-TRIG-05, PF-TRIG-07 and PF-TRIG-11.

Items: VC-PF-0031, VC-PF-0033, VC-PF-0034. Clause: VVP-PF-001.

  PF-TRIG-05  The camera trigger output shall remain inactive-high except for
              the commanded active-low trigger interval.
  PF-TRIG-07  The camera trigger generator shall support continuous
              acquisition when the requested frame count is zero.
  PF-TRIG-11  The camera trigger source selector shall select manual,
              scheduled-PPS or synchronized-LVDS start according to the ICD
              values.

**The DUT is `cam_trig_top`** at the instance's parameters
(`CLOCK_FREQ_MHZ = 50`, `cam_rx_hier.tcl:254-257`), with `pclk` and
`xtrig_clk` one 50 MHz clock (`:395`) and `en` the camera power-good
(`PF-F-25`). `XTRIG_LOW_TIME` is in clocks of 20 ns and `FRAME_CAPTURE_TIME`
in microseconds, as flight software writes them (`camera.c:672-700`).

**`PF-TRIG-05` is exact.** A commanded interval of N clocks is a low pulse of
exactly N x 20 ns, one per frame, a frame period apart, and `xtrig` is high
at every other moment from `en` onward. Three commands: 1 clock, 10 us and
about 1 ms. (Before `en` -- camera unpowered -- the output is low, which is
the right level towards an unpowered sensor and outside the criterion's
"applied trigger commands".)

**`PF-TRIG-07` includes the stop, and fails.** A frame count of zero runs
continuously. The item asks that it run "until another control input stops
the sequence", and the test tries each input firmware has -- `START` = 0, a
new frame count, a source of none, `en` low, an interrupt clear -- and none
stops it. The block's resets are the global system reset of the 50 MHz
domain (`top.tcl:560`), shared with the processor. `PF-F-27`.

**`PF-TRIG-11` is tested against CM-01979 section 5.5.21**, the only ICD
table that defines trigger-mode values: `TRIG_MODE_SYS_REG`, which flight
software writes verbatim into `XTRIG_SRC_SEL` (`camera.h:24-35`). For each of
its four values, each of the three start stimuli -- a manual `START`, the PPS
time passing the scheduled time, and an LVDS rising edge -- is applied, and
the test records which starts a capture. The ICD's `EXT_GPIO` (1) selects
the scheduler, and its `TIME` (3) selects nothing. `PF-F-26`.
"""

from __future__ import annotations

import cocotb
from cocotb.triggers import ClockCycles, FallingEdge, ValueChange
from cocotb.utils import get_sim_time

from fsverif import sim
from fsverif.bfm.apb import Apb
from fsverif.clkrst import advance, start_clock

TOP = "cam_trig_top"
PARAMETERS = {"CLOCK_FREQ_MHZ": 50}
CLK_NS = 20

XTRIG_LOW_TIME, FRAME_CAPTURE_TIME, FRAME_CAPTURE_AMOUNT = 0x00, 0x04, 0x08
START, XTRIG_SRC_SEL, SCHEDULER_TIME_SEC, SCHEDULER_TIME_MSEC = 0x0C, 0x10, 0x14, 0x18
BUSY, IRQ_STATUS = 0x1C, 0x20

MANUAL, SCHEDULED, LVDS = "manual START", "scheduled PPS time", "LVDS rising edge"

# CM-01979 section 5.5.21, TRIG_MODE_SYS_REG: value -> the FPGA start that
# mode means. PARAM_UPDATE is firmware deciding to image, so it is a
# software start; TIME is the only time-based mode.
ICD_TRIG_MODE = {
    0: ("COMMAND", MANUAL),
    1: ("EXT_GPIO", LVDS),
    2: ("PARAM_UPDATE", MANUAL),
    3: ("TIME", SCHEDULED),
}


def _now() -> int:
    return int(get_sim_time("ns"))


class Trig:
    def __init__(self, dut):
        self.dut, self.clk = dut, dut.pclk
        self.apb = None
        self.edges = []

    async def start(self, en: int = 1) -> None:
        dut = self.dut
        if self.apb is None:
            start_clock(dut.pclk, CLK_NS)
            start_clock(dut.xtrig_clk, CLK_NS)
            self.apb = Apb(dut, dut.pclk, "")
            cocotb.start_soon(self._watch())
        dut.en.value = en
        dut.rtc_sec.value = 0
        dut.rtc_nsec.value = 0
        dut.lvds_start.value = 0
        dut.presetn.value = 0
        dut.xtrig_rst_n.value = 0
        await ClockCycles(self.clk, 10)
        await FallingEdge(self.clk)
        dut.presetn.value = 1
        dut.xtrig_rst_n.value = 1
        await ClockCycles(self.clk, 10)

    async def _watch(self) -> None:
        while True:
            await ValueChange(self.dut.xtrig)
            self.edges.append((_now(), int(self.dut.xtrig.value)))

    def lows(self, since: int = 0) -> list:
        """(start, width) of every low pulse after `since`, in ns."""
        out, fell = [], None
        for t, v in self.edges:
            if t <= since:
                continue
            if v == 0:
                fell = t
            elif fell is not None:
                out.append((fell, t - fell))
                fell = None
        return out

    def falls(self, since: int = 0) -> int:
        return sum(1 for t, v in self.edges if t > since and v == 0)

    async def configure(self, low_clocks: int, frame_us: int, amount: int,
                        source: int = 0) -> None:
        await self.apb.write(XTRIG_LOW_TIME, low_clocks)
        await self.apb.write(FRAME_CAPTURE_TIME, frame_us)
        await self.apb.write(FRAME_CAPTURE_AMOUNT, amount)
        await self.apb.write(XTRIG_SRC_SEL, source)
        await ClockCycles(self.clk, 5)

    async def busy(self) -> int:
        return (await self.apb.read(BUSY)).data & 1


@cocotb.test()
async def test_PF_TRIG_05_active_low_interval_only(dut):
    """VC-PF-0031: low for exactly the commanded interval, high otherwise."""
    t = Trig(dut)
    await t.start(en=0)
    problems = []
    if int(dut.xtrig.value) != 0:
        problems.append("xtrig is not low with the camera unpowered (en = 0)")
    await FallingEdge(t.clk)
    dut.en.value = 1
    await ClockCycles(t.clk, 5)
    enabled = _now()
    if int(dut.xtrig.value) != 1:
        problems.append("xtrig did not go high when the camera was enabled")

    commands = [(1, 10, 3), (500, 50, 4), (49_999, 2_000, 2)]
    for low, frame_us, amount in commands:
        since = _now()
        await t.configure(low, frame_us, amount)
        await t.apb.write(START, 1)
        await advance(t.clk, seconds=(frame_us * amount + 50) / 1e6)
        if await t.busy():
            problems.append("command (%d clocks, %d us, x%d) still busy after its "
                            "sequence" % (low, frame_us, amount))
        pulses = t.lows(since)
        widths = sorted({w for _, w in pulses})
        periods = sorted({b[0] - a[0] for a, b in zip(pulses, pulses[1:])})
        dut._log.info("command %d clocks low, %d us frame, x%d: %d low pulses, "
                      "widths %s ns, periods %s ns", low, frame_us, amount,
                      len(pulses), widths, periods)
        if len(pulses) != amount:
            problems.append("command (%d clocks, x%d) gave %d low pulses"
                            % (low, amount, len(pulses)))
        if widths != [low * CLK_NS]:
            problems.append("command of %d clocks (%d ns) gave low pulses of %s ns"
                            % (low, low * CLK_NS, widths))
        if pulses[1:] and periods != [frame_us * 1000]:
            problems.append("command of %d us frames gave pulse periods of %s ns"
                            % (frame_us, periods))
        if int(dut.xtrig.value) != 1:
            problems.append("xtrig not high after the command finished")

    # Every low after enable is one of the commanded pulses.
    total = sum(n for _, _, n in commands)
    if t.falls(enabled) != total:
        problems.append("%d falling edges after enable; the commands asked for %d"
                        % (t.falls(enabled), total))

    # Not a commanded interval: zero. Observed only -- flight software's
    # exposure minimum rules it out (register_callbacks.c:169).
    since = _now()
    await t.configure(0, 10, 1)
    await t.apb.write(START, 1)
    await advance(t.clk, seconds=1e-3)
    dut._log.info("a low time of 0 clocks: xtrig %s after 1 ms",
                  "still low" if int(dut.xtrig.value) == 0 else "high again")
    assert not problems, "\n  ".join(["PF-TRIG-05:"] + problems)


@cocotb.test()
async def test_PF_TRIG_07_zero_count_continuous(dut):
    """VC-PF-0033: zero means continuous -- and something must stop it."""
    t = Trig(dut)
    await t.start()
    problems = []
    low, frame_us = 100, 20
    await t.configure(low, frame_us, 0)
    await t.apb.write(START, 1)
    since = _now()
    await advance(t.clk, seconds=2e-3)
    pulses = t.lows(since)
    periods = sorted({b[0] - a[0] for a, b in zip(pulses, pulses[1:])})
    dut._log.info("frame count 0: %d triggers in 2 ms, periods %s ns",
                  len(pulses), periods)
    if len(pulses) < 2e-3 / (frame_us * 1e-6) - 1 or periods != [frame_us * 1000]:
        problems.append("a frame count of 0 did not trigger continuously: %d "
                        "triggers in 2 ms, periods %s ns" % (len(pulses), periods))

    async def write(addr, value):
        await t.apb.write(addr, value)

    async def en_low():
        await FallingEdge(t.clk)
        dut.en.value = 0

    stops = [("START written 0", write(START, 0)),
             ("frame count written 1", write(FRAME_CAPTURE_AMOUNT, 1)),
             ("source written 3 (none)", write(XTRIG_SRC_SEL, 3)),
             ("interrupt cleared", write(IRQ_STATUS, 1)),
             ("en (camera power-good) low", en_low())]
    stopped_by = None
    for label, action in stops:
        await action
        await advance(t.clk, seconds=100e-6)
        since = _now()
        await advance(t.clk, seconds=200e-6)
        n = len(t.lows(since))
        dut._log.info("after %s: %d triggers in the next 200 us", label, n)
        if n == 0:
            stopped_by = label
            break
    if stopped_by is None:
        problems.append(
            "no control input stops a continuous sequence: after START = 0, a "
            "frame count of 1, a source of none, an interrupt clear and en low, "
            "xtrig still pulses every %d us. The FSM leaves XTRIG_HIGH_PERIOD only "
            "for XTRIG_LOW_PERIOD while the count is 0 (cam_trig.sv:199-207) and "
            "takes new settings only in IDLE (:98, cam_trig_apb_reg.sv:207); the "
            "resets are the global 50 MHz system reset. PF-F-27." % frame_us)
    assert not problems, "\n  ".join(["PF-TRIG-07:"] + problems)


@cocotb.test()
async def test_PF_TRIG_11_source_select_icd_values(dut):
    """VC-PF-0034: each CM-01979 TRIG_MODE value selects the start it names."""
    t = Trig(dut)
    problems = []
    seen = {}
    sched_sec = 5

    for value, (name, wanted) in ICD_TRIG_MODE.items():
        await t.start()
        # The schedule before the source: with the scheduler selected and its
        # time still 0, the PPS time is already past it and it starts at once.
        await t.configure(10, 20, 1, source=0)
        await t.apb.write(SCHEDULER_TIME_SEC, sched_sec)
        await t.apb.write(SCHEDULER_TIME_MSEC, 0)
        await t.apb.write(XTRIG_SRC_SEL, value)
        await ClockCycles(t.clk, 5)
        started = []

        async def fired(label, since):
            await advance(t.clk, seconds=60e-6)
            if t.lows(since):
                started.append(label)
                await advance(t.clk, seconds=40e-6)

        # LVDS: a rising edge on the external start.
        await FallingEdge(t.clk)
        since = _now()
        dut.lvds_start.value = 1
        await ClockCycles(t.clk, 10)
        dut.lvds_start.value = 0
        await fired(LVDS, since)
        # Scheduled: the PPS time passes the scheduled second.
        await FallingEdge(t.clk)
        since = _now()
        dut.rtc_sec.value = sched_sec
        dut.rtc_nsec.value = 1_000
        await fired(SCHEDULED, since)
        # Manual: START.
        since = _now()
        await t.apb.write(START, 1)
        await fired(MANUAL, since)

        seen[value] = started
        dut._log.info("TRIG_MODE %d (%s): started by %s; the ICD means %s",
                      value, name, started or "nothing", wanted)
        if started != [wanted]:
            problems.append("TRIG_MODE %d (%s) should start on %s; the FPGA "
                            "started on %s" % (value, name, wanted,
                                               ", ".join(started) or "nothing"))
    if problems:
        problems.append(
            "CM-01979 section 5.5.21 numbers the modes COMMAND 0, EXT_GPIO 1, "
            "PARAM_UPDATE 2, TIME 3; the FPGA decodes manual 0, scheduler 1, "
            "LVDS 2 (cam_trig_top.sv:154-162), and flight software writes the "
            "ICD register into XTRIG_SRC_SEL verbatim. PF-F-26.")
    assert not problems, "\n  ".join(["PF-TRIG-11:"] + problems)


def _run(testcase: str) -> None:
    sim.run(hdl_toplevel=TOP,
            sources=sim.block("cam_trig_ip", "cam_trig.sv", "cam_trig_apb_reg.sv",
                              "cam_trig_top.sv"),
            test_module="test_pf_trig", testcase=[testcase],
            run_id="test_pf_trig.%s" % testcase, parameters=PARAMETERS)


def test_pf_trig_05():
    _run("test_PF_TRIG_05_active_low_interval_only")


def test_pf_trig_07():
    _run("test_PF_TRIG_07_zero_count_continuous")


def test_pf_trig_11():
    _run("test_PF_TRIG_11_source_select_icd_values")
