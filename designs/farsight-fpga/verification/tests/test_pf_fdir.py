"""Camera fault detector: PF-FDIR-04, PF-FDIR-05 and PF-FDIR-06.

Items: VC-PF-0019, VC-PF-0021, VC-PF-0023. Clause: VVP-PF-001.

  PF-FDIR-04  The camera fault detector shall latch a timeout fault when no
              frame-valid response arrives before the configured timeout.
  PF-FDIR-05  The camera fault detector shall latch a power fault while
              capture is active and camera power status is low.
  PF-FDIR-06  The camera fault detector shall report a fault whenever timeout
              or camera-power fault is latched.

**The DUT is `cam_fault_detector_top`**, the unit the build instantiates in
`cam_rx_hier`. That SmartDesign also holds the encrypted SLVS-EC receiver, so
it does not run under Verilator; the unit is wired here as the build wires it:
`pclk` and `xtrig_clk` are one 50 MHz clock (`cam_rx_hier.tcl:395`), the two
resets one reset (`:396`), and the parameters are the instance's,
`CLOCK_FREQ_MHZ = 50` and `TIMEOUT_US = 1000` (`:198-202`), passed explicitly.

**The stimulus is a capture as `cam_trig` makes one:** a one-clock `start`, a
low period on `xtrig`, then `xtrig` rising -- the edge the detector times
from. `frame_valid` comes from the SLVS-EC receiver's clock domain and is
driven here with no relation to the fabric clock. The status firmware sees is
the `FAULT` register, read over APB; the source latches, `timeout_fault` and
`pwr_fault`, are inside the detector and made reachable for `PF-FDIR-06`
alone, which is about the relation between them and the report.

**`PF-FDIR-05` is tested to its rationale, and fails.** The requirement says
the detector latches a power fault; its rationale says firmware needs "a
distinct indication that image acquisition failed because the camera rail was
unavailable". The latch is there, but it reaches firmware only through the
one `FAULT` bit it shares with the timeout. The test compares every register
firmware can read after a power fault with the same after a timeout: they are
identical. `PF-F-24`.

**The last test characterises `PF-F-25` and verifies no requirement.** Flight
software writes 1 to `FAULT_CLEAR` and never 0, and the RTL holds both latches
clear for as long as it reads 1. That test asserts what the finding claims,
so that a change to the RTL shows up as a finding to revisit, not silently.
"""

from __future__ import annotations

import cocotb
from cocotb.triggers import ClockCycles, FallingEdge, ReadOnly, RisingEdge, Timer
from cocotb.utils import get_sim_time

from fsverif import sim
from fsverif.bfm.apb import Apb
from fsverif.clkrst import advance, start_clock

TOP = "cam_fault_detector_top"
PARAMETERS = {"CLOCK_FREQ_MHZ": 50, "TIMEOUT_US": 1000}
CLK_PERIOD_NS = 20
TIMEOUT_NS = PARAMETERS["TIMEOUT_US"] * 1000
SYNC_CLOCKS = 3                 # the frame_valid/fault_clear synchroniser, and a margin

FAULT, FAULT_CLEAR = 0x00, 0x04
REGISTER_SPACE = range(0x00, 0x80, 4)        # paddr[6:2]: every address it decodes

INTERNAL = [("cam_fault_detector", "timeout_fault"),
            ("cam_fault_detector", "pwr_fault")]


def _now() -> int:
    return int(get_sim_time("ns"))


class Detector:
    """The unit, its clock, its APB, and a capture made the way cam_trig makes one."""

    def __init__(self, dut):
        self.dut, self.clk = dut, dut.pclk
        self.apb = None

    async def start(self, xtrig: int = 0) -> None:
        dut = self.dut
        if self.apb is None:
            # One clock drives both ports, as the SmartDesign does.
            start_clock(dut.pclk, CLK_PERIOD_NS)
            start_clock(dut.xtrig_clk, CLK_PERIOD_NS)
            self.apb = Apb(dut, dut.pclk, "")
        dut.xtrig.value = xtrig
        dut.frame_valid.value = 0
        dut.capture_start.value = 0
        dut.capture_finish.value = 0
        dut.cam_pwr_status.value = 1
        dut.presetn.value = 0
        dut.xtrig_rst_n.value = 0
        await ClockCycles(self.clk, 10)
        await FallingEdge(self.clk)
        dut.presetn.value = 1
        dut.xtrig_rst_n.value = 1
        await ClockCycles(self.clk, 5)

    async def strobe(self, signal) -> None:
        await FallingEdge(self.clk)
        signal.value = 1
        await FallingEdge(self.clk)
        signal.value = 0

    async def trigger(self, answer_ns=None, low_ns: int = 10_000) -> int:
        """capture_start, an xtrig low period, and the rising edge; its time.

        `answer_ns` after the edge, frame_valid rises and stays up 100 us.
        Returns before the answer; the caller decides how long to wait.
        """
        dut = self.dut
        await self.strobe(dut.capture_start)
        await FallingEdge(self.clk)
        dut.xtrig.value = 0
        await Timer(low_ns, unit="ns")
        dut.xtrig.value = 1
        rise = _now()
        if answer_ns is not None:
            cocotb.start_soon(self._answer(answer_ns))
        return rise

    async def _answer(self, after_ns: int) -> None:
        # Not aligned to the fabric clock: it comes from the receiver's.
        await Timer(after_ns + 7, unit="ns")
        self.dut.frame_valid.value = 1
        await Timer(100_000, unit="ns")
        self.dut.frame_valid.value = 0

    async def power_dip(self, width_ns: int = 1_000) -> None:
        await FallingEdge(self.clk)
        self.dut.cam_pwr_status.value = 0
        await Timer(width_ns, unit="ns")
        self.dut.cam_pwr_status.value = 1

    async def status(self) -> int:
        return (await self.apb.read(FAULT)).data & 1

    async def clear(self) -> None:
        """Clear and re-arm, as the register map says: 1, then 0."""
        await self.apb.write(FAULT_CLEAR, 1)
        await ClockCycles(self.clk, 5)
        await self.apb.write(FAULT_CLEAR, 0)
        await ClockCycles(self.clk, 5)

    async def registers(self) -> dict:
        return {a: (await self.apb.read(a)).data for a in REGISTER_SPACE}

    def fault(self) -> int:
        return int(self.dut.fault.value)


async def _rise_of(clk, signal, timeout_ns: int):
    """The time `signal` first reads 1, polled every clock, or None."""
    end = _now() + timeout_ns
    while _now() < end:
        await RisingEdge(clk)
        await ReadOnly()
        if int(signal.value):
            return _now()
    return None


@cocotb.test()
async def test_PF_FDIR_04_timeout_fault_latches(dut):
    """VC-PF-0019: an unanswered trigger latches a timeout at 1000 us."""
    d = Detector(dut)
    await d.start()
    problems = []

    # Answered with a millisecond's margin gone: 999 us after the edge.
    rise = await d.trigger(answer_ns=TIMEOUT_NS - 1_000)
    await advance(d.clk, seconds=1.5e-3)
    if d.fault() or await d.status():
        problems.append("a frame-valid 999 us after the trigger was counted as "
                        "a timeout")

    # Unanswered, until well after the timeout.
    rise = await d.trigger(answer_ns=TIMEOUT_NS + 200_000)
    at = await _rise_of(d.clk, dut.fault, TIMEOUT_NS + 50_000)
    if at is None:
        problems.append("no timeout fault 1.05 ms after an unanswered trigger")
    else:
        after = at - rise
        dut._log.info("timeout fault %d ns after the trigger edge", after)
        if not TIMEOUT_NS <= after <= TIMEOUT_NS + SYNC_CLOCKS * CLK_PERIOD_NS:
            problems.append("the timeout fault latched %d ns after the trigger; "
                            "the configured timeout is %d ns" % (after, TIMEOUT_NS))
    await FallingEdge(d.clk)

    # Latched: it stays through the late frame, through answered captures,
    # and through the end of the capture.
    seen = []
    await advance(d.clk, seconds=0.3e-3)
    seen.append(("after the late frame-valid", await d.status()))
    for _ in range(2):
        await d.trigger(answer_ns=100_000)
        await advance(d.clk, seconds=1.2e-3)
    seen.append(("after two answered captures", await d.status()))
    await d.strobe(dut.capture_finish)
    await advance(d.clk, seconds=1e-3)
    seen.append(("after capture finished", await d.status()))
    for label, status in seen:
        if not status:
            problems.append("FAULT read 0 %s: the timeout fault did not stay "
                            "latched" % label)
    assert not problems, "\n  ".join(["PF-FDIR-04:"] + problems)


@cocotb.test()
async def test_PF_FDIR_05_power_fault_latches(dut):
    """VC-PF-0021: a camera-rail loss in capture latches, distinctly."""
    d = Detector(dut)
    await d.start()
    problems = []
    pwr = dut.cam_fault_detector_inst.pwr_fault

    # Outside a capture, a dip is not a fault: before one, and after one.
    await d.power_dip(10_000)
    await ClockCycles(d.clk, 10)
    if d.fault():
        problems.append("a power dip before any capture latched a fault")
    await d.strobe(dut.capture_start)
    await d.strobe(dut.capture_finish)
    await d.power_dip(10_000)
    await ClockCycles(d.clk, 10)
    if d.fault():
        problems.append("a power dip after the capture finished latched a fault")

    # In a capture, a 1 us dip latches, and stays latched once power is back.
    await d.strobe(dut.capture_start)
    await ClockCycles(d.clk, 10)
    await d.power_dip(1_000)
    await advance(d.clk, seconds=0.5e-3)
    if not int(pwr.value):
        problems.append("a 1 us power dip during capture did not latch a power "
                        "fault")
    if not await d.status():
        problems.append("FAULT read 0 after a power fault during capture")
    after_power = await d.registers()

    # Distinct from a timeout: what firmware can read after one, and after
    # the other.
    await d.start()
    await d.trigger(answer_ns=None)
    await advance(d.clk, seconds=1.1e-3)
    if not int(dut.cam_fault_detector_inst.timeout_fault.value) or int(pwr.value):
        problems.append("the comparison state is not a timeout alone; the "
                        "check below would prove nothing")
    after_timeout = await d.registers()
    differ = {a for a in REGISTER_SPACE if after_power[a] != after_timeout[a]}
    dut._log.info("after a power fault: %s; after a timeout: %s",
                  {hex(a): hex(v) for a, v in after_power.items() if v},
                  {hex(a): hex(v) for a, v in after_timeout.items() if v})
    if not differ:
        problems.append(
            "no register firmware can read tells a power fault from a timeout: "
            "all %d word addresses read the same after each, with FAULT = 1. "
            "The power-fault latch exists (cam_fault_detector.sv:104-108) but "
            "reaches firmware only through `fault = timeout_fault | pwr_fault` "
            "(:123) and one register bit (cam_fault_detector_apb_reg.sv:97). "
            "PF-F-24." % len(REGISTER_SPACE))
    assert not problems, "\n  ".join(["PF-FDIR-05:"] + problems)


@cocotb.test()
async def test_PF_FDIR_06_any_latched_fault_reports(dut):
    """VC-PF-0023: every latched source fault is in the common report."""
    d = Detector(dut)
    inner = dut.cam_fault_detector_inst
    problems = []

    async def case(label, timeout: bool, power: bool) -> None:
        await d.start()
        await d.strobe(dut.capture_start)
        if timeout:
            await d.trigger(answer_ns=None)
        if power:
            await d.power_dip(1_000)
        await advance(d.clk, seconds=1.1e-3)
        sources = {"timeout_fault": int(inner.timeout_fault.value),
                   "pwr_fault": int(inner.pwr_fault.value)}
        wanted = {"timeout_fault": timeout, "pwr_fault": power}
        if sources != {k: int(v) for k, v in wanted.items()}:
            problems.append("%s: the stimulus latched %s; the case needs %s"
                            % (label, sources, wanted))
        status = await d.status()
        dut._log.info("%s: sources %s, fault %d, FAULT register %d",
                      label, sources, d.fault(), status)
        if any(sources.values()) and not (d.fault() and status):
            problems.append("%s: %s latched and the common report is fault=%d, "
                            "FAULT register=%d" % (label, sources, d.fault(), status))
        # And it clears: a report that could not be cleared would pass the
        # line above for every case after the first.
        await d.clear()
        if await d.status():
            problems.append("%s: FAULT still reads 1 after clear and re-arm" % label)

    await case("timeout alone", timeout=True, power=False)
    await case("power alone", timeout=False, power=True)
    await case("both", timeout=True, power=True)
    assert not problems, "\n  ".join(["PF-FDIR-06:"] + problems)


@cocotb.test()
async def test_characterise_flight_clear_leaves_detector_inert(dut):
    """PF-F-25, as the RTL behaves today. Verifies no requirement.

    1. `cam_trig` drives `xtrig` high from the moment camera power is good
       (OFF -> IDLE), so the detector sees a rising edge with no capture and,
       with no frame to answer it, latches a timeout 1 ms later.
    2. Flight software clears it by writing 1 to FAULT_CLEAR and never 0
       (`farsight-avionics-sw` `Camera/src/camera.c:857`, called from
       `util.c:139`). While the bit reads 1, neither latch can set.
    """
    d = Detector(dut)
    problems = []

    await d.start(xtrig=1)
    await advance(d.clk, seconds=1.1e-3)
    if not await d.status():
        problems.append("xtrig high out of reset did not latch a timeout; "
                        "PF-F-25 point 1 no longer holds")

    await d.apb.write(FAULT_CLEAR, 1)          # clear_fault(), and nothing after
    await ClockCycles(d.clk, 10)
    if await d.status():
        problems.append("writing 1 to FAULT_CLEAR did not clear the fault")
    await d.strobe(dut.capture_start)
    await d.trigger(answer_ns=None)
    await d.power_dip(1_000)
    await advance(d.clk, seconds=1.5e-3)
    inert = not await d.status()
    dut._log.info("with FAULT_CLEAR left at 1: an unanswered trigger and a "
                  "power dip in capture leave FAULT = %d", int(not inert))
    if not inert:
        problems.append("a fault latched with FAULT_CLEAR left at 1; PF-F-25 "
                        "point 2 no longer holds -- revisit the finding")
    assert not problems, "\n  ".join(["PF-F-25 characterisation:"] + problems)


def _run(testcase: str) -> None:
    sim.run(hdl_toplevel=TOP,
            sources=sim.block("cam_fault_detector_ip", "cam_fault_detector.sv",
                              "cam_fault_detector_apb_reg.sv",
                              "cam_fault_detector_top.sv"),
            test_module="test_pf_fdir", testcase=[testcase],
            run_id="test_pf_fdir.%s" % testcase,
            parameters=PARAMETERS, internal=INTERNAL)


def test_pf_fdir_04():
    _run("test_PF_FDIR_04_timeout_fault_latches")


def test_pf_fdir_05():
    _run("test_PF_FDIR_05_power_fault_latches")


def test_pf_fdir_06():
    _run("test_PF_FDIR_06_any_latched_fault_reports")


def test_characterise_pf_f_25():
    _run("test_characterise_flight_clear_leaves_detector_inert")
