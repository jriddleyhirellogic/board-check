"""What a single observed boot establishes: HK-SEQ-01, -02, -04 and -08.

Items: VC-HK-0051, VC-HK-0052, VC-HK-0055, VC-HK-0059. Clause: VVP-HK-004.

  HK-SEQ-01  The first power enable asserts no earlier than 950 ms and no
             later than 1050 ms after reset release, and none before.
  HK-SEQ-02  The hardware-controlled regions begin booting in the order Step
             Down, DDR8, DDR16, FPGA, LVDS.
  HK-SEQ-04  The boot sequence starts exactly once per deassertion of reset,
             and none starts afterwards without another.
  HK-SEQ-08  With no external request asserted at any time, every
             hardware-controlled region boots during the initial sequence.

**Four requirements, one boot.** A boot costs about 42 seconds of wall clock
and a build under ten, so the unit of cost in this suite is the boot, not the
module and not the test. These three are claims about the *same event* -- the
device coming up from reset with nothing requested -- so booting three times
to make them would be paying three times for one observation.

They share it through `observation()`, which records the boot once and hands
the record to whoever asks. The record is of the past, so the tests cannot
disturb each other through it, and a test run on its own still boots. That is
the difference between sharing an observation and sharing a live device: a
latchup test cannot do this, because it leaves `critical_latchup` latched
(`health_monitor.sv:722`) and the next test would run on a device already in
failure.

Nothing here requests a software-controlled region, which is what HK-SEQ-08 is
about and is also why `HK-SEQ-07` is not in this module -- it needs the control
inputs high through the boot, and that is a different boot.
"""

from __future__ import annotations

import cocotb
from cocotb.utils import get_sim_time

from fsverif import sim
from fsverif.boot import FILTER_CYCLES
from fsverif.clkrst import advance
from fsverif.pins import (CONTROL_INPUTS, HARDWARE_REGIONS, POWER_ENABLES,
                          RESET_N, boundary)

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

#: `HK-SEQ-01`. The requirement says 1 s; the item's window is what a
#: simulation can actually resolve against a counter with a 0.32768 ms tick.
HOLDOFF_MIN_MS = 950.0
HOLDOFF_MAX_MS = 1050.0

#: `HK-SEQ-02`, in the order the requirement gives.
EXPECTED_ORDER = ("step_down", "ddr8", "ddr16", "fpga", "lvds")

#: The output on which each hardware region reports itself booted.
#:
#: Not derivable from the region name, which is why it is written out. The
#: FPGA region reports on `pf_status_to_pf`, because what that region powers
#: is the PolarFire -- `health_monitor_io.sv:320` drives it straight from
#: `fpga_boot_succeeded`, and there is no `fpga_status_to_pf` at all. A
#: mechanical "%s_status_to_pf" reached for one and `pins.boundary` refused
#: it, which is the only reason this is correct rather than plausible.
REGION_STATUS = {
    "step_down": "step_down_status_to_pf",
    "ddr8": "ddr8_status_to_pf",
    "ddr16": "ddr16_status_to_pf",
    "fpga": "pf_status_to_pf",
    "lvds": "lvds_status_to_pf",
}

#: Sampling. The hold-off is a second and its window is +/- 50 ms, so a
#: millisecond is ample to time the first enable. Once the sequence is moving
#: the regions follow each other within a few milliseconds, so it tightens --
#: two regions sampled in the same window would be an order this test could
#: not resolve, and it says so rather than guessing.
COARSE_MS = 1.0
FINE_MS = 0.05
SETTLE_MS = 60.0

#: How long to keep watching after the sequence has finished, for `HK-SEQ-04`.
#: Longer than the 200 ms `RETRY_TIME` of every region, so that a sequence
#: which restarted itself would have done so inside the window. A shorter
#: watch would pass by simply looking away before anything happened.
QUIET_MS = 250.0

_record = None


class Boot:
    """When each power enable first asserted, and how often it asserted.

    Both, because `HK-SEQ-04` is about the second one. An enable that rose,
    fell and rose again has booted its source twice, and a record holding only
    the first time would report that as a clean single sequence.
    """

    def __init__(self):
        self.first = {}
        self.rises = {}
        self._was = {}

    def note(self, dut, at_ms: float) -> None:
        for name in POWER_ENABLES:
            now = int(getattr(dut, name).value)
            if now and not self._was.get(name, 0):
                self.first.setdefault(name, at_ms)
                self.rises[name] = self.rises.get(name, 0) + 1
            self._was[name] = now

    def region_started(self, region: str) -> float:
        """When a region began booting: its earliest enable assertion."""
        names = dict(HARDWARE_REGIONS)[region]
        times = [self.first[n] for n in names if n in self.first]
        return min(times) if times else float("inf")

    @property
    def earliest(self) -> float:
        return min(self.first.values()) if self.first else float("inf")


async def observation(dut) -> Boot:
    """The initial boot, recorded once and shared.

    Cached because the three tests in this module are claims about one event.
    Recording it three times would triple the cost of the module for no
    additional evidence -- and worse, would invite the three to disagree,
    since each would be a different boot.
    """
    global _record
    if _record is None:
        _record = await _watch(dut)
    return _record


async def _watch(dut) -> Boot:
    dut.rail_fail.value = 0
    dut.rail_fault.value = 0
    reset_n = getattr(dut, RESET_N)
    reset_n.value = 0
    for name in CONTROL_INPUTS:
        getattr(dut, name).value = 0
    await advance(dut.clk, cycles=FILTER_CYCLES)
    reset_n.value = 1

    released = get_sim_time("ns")
    record = Boot()

    def elapsed_ms() -> float:
        return (get_sim_time("ns") - released) / 1e6

    # Coarse, until something moves. Sampling finely through a second of
    # hold-off would wake cocotb twenty thousand times for one transition.
    while not record.first and elapsed_ms() < HOLDOFF_MAX_MS + SETTLE_MS:
        await advance(dut.clk, seconds=COARSE_MS / 1000.0)
        record.note(dut, elapsed_ms())

    # Fine, while the sequence is running. The regions follow each other
    # closely once it starts, and the order is the evidence.
    deadline = elapsed_ms() + SETTLE_MS
    while elapsed_ms() < deadline:
        await advance(dut.clk, seconds=FINE_MS / 1000.0)
        record.note(dut, elapsed_ms())

    # Then keep watching, doing nothing, for longer than a retry would take.
    record.settled_at = elapsed_ms()
    deadline = elapsed_ms() + QUIET_MS
    while elapsed_ms() < deadline:
        await advance(dut.clk, seconds=COARSE_MS / 1000.0)
        record.note(dut, elapsed_ms())
    record.watched_to = elapsed_ms()

    dut._log.info("initial boot: %d of %d enables asserted, first at %.1f ms, "
                  "watched to %.1f ms", len(record.first), len(POWER_ENABLES),
                  record.earliest, record.watched_to)
    return record


@cocotb.test()
async def test_HK_SEQ_01_wait_1s_after_reset(dut):
    """VC-HK-0051: nothing is enabled until the hold-off has elapsed."""
    record = await observation(dut)

    assert record.first, (
        "no power enable asserted at all, so there is no hold-off to measure "
        "and this test cannot distinguish a correct 1 s wait from a device "
        "that never starts")

    early = {n: t for n, t in record.first.items() if t < HOLDOFF_MIN_MS}
    assert not early, (
        "these enables asserted before the %g ms hold-off had elapsed: %s"
        % (HOLDOFF_MIN_MS,
           ", ".join("%s at %.1f ms" % (n, t) for n, t in sorted(early.items()))))
    assert record.earliest <= HOLDOFF_MAX_MS, (
        "the first power enable asserted at %.1f ms, later than the %g ms the "
        "item allows" % (record.earliest, HOLDOFF_MAX_MS))
    dut._log.info("first enable at %.1f ms, inside [%g, %g]",
                  record.earliest, HOLDOFF_MIN_MS, HOLDOFF_MAX_MS)


@cocotb.test()
async def test_HK_SEQ_02_hardware_region_order(dut):
    """VC-HK-0052: the hardware regions begin in the order the requirement gives."""
    record = await observation(dut)

    started = [(region, record.region_started(region))
               for region in EXPECTED_ORDER]
    missing = [region for region, at in started if at == float("inf")]
    assert not missing, (
        "these hardware-controlled regions never began booting, so their "
        "place in the order cannot be established: %s" % ", ".join(missing))

    # Two regions timed to the same sample are an order this test cannot
    # resolve. Reporting that is the honest answer; passing would be luck.
    ties = [(a, b) for (a, ta), (b, tb) in zip(started, started[1:])
            if abs(ta - tb) < FINE_MS]
    assert not ties, (
        "these regions began within one %g ms sample of each other, so their "
        "order is not resolved by this measurement: %s"
        % (FINE_MS, ", ".join("%s/%s" % pair for pair in ties)))

    actual = [region for region, _ in sorted(started, key=lambda p: p[1])]
    assert actual == list(EXPECTED_ORDER), (
        "the hardware regions began booting in the order %s, not %s.\n%s"
        % (" -> ".join(actual), " -> ".join(EXPECTED_ORDER),
           "\n".join("  %-10s %8.3f ms" % (r, t) for r, t in started)))
    dut._log.info("region order: %s", " -> ".join(
        "%s@%.1fms" % (r, t) for r, t in started))


@cocotb.test()
async def test_HK_SEQ_08_hw_regions_boot_unrequested(dut):
    """VC-HK-0059: every hardware region boots with nothing ever requested."""
    record = await observation(dut)

    for name in CONTROL_INPUTS:
        assert int(getattr(dut, name).value) == 0, (
            "%s is asserted, so this boot was requested and cannot show that "
            "the hardware regions boot unrequested" % name)

    never = [name for _, names in HARDWARE_REGIONS for name in names
             if name not in record.first]
    assert not never, (
        "these hardware-controlled power enables never asserted, so their "
        "region did not boot during the initial sequence: %s"
        % ", ".join(never))

    # And the device says so itself, which is the stronger claim: an enable
    # asserting is a boot *attempt*, not a boot.
    for region, _ in HARDWARE_REGIONS:
        status = REGION_STATUS[region]
        assert int(boundary(dut, status).value) == 1, (
            "every %s enable asserted but %s is low, so the region attempted "
            "to boot and did not succeed" % (region, status))
    dut._log.info("all %d hardware enables asserted and all %d regions report "
                  "booted, with no request at any time",
                  len(record.first), len(HARDWARE_REGIONS))


@cocotb.test()
async def test_HK_SEQ_04_boot_once_per_reset(dut):
    """VC-HK-0055: one sequence per reset release, and no more afterwards."""
    record = await observation(dut)

    again = {n: c for n, c in record.rises.items() if c > 1}
    assert not again, (
        "these power enables asserted more than once during a single "
        "deassertion of reset, so the boot sequence ran more than once: %s"
        % ", ".join("%s x%d" % (n, c) for n, c in sorted(again.items())))

    # And nothing started late. The watch ran %g ms past the sequence
    # settling, which is longer than any region's 200 ms retry, so a sequence
    # that restarted itself would be in the record.
    late = {n: t for n, t in record.first.items() if t > record.settled_at}
    assert not late, (
        "these power enables first asserted after the sequence had settled at "
        "%.1f ms, so a further sequence started without a reset: %s"
        % (record.settled_at,
           ", ".join("%s at %.1f ms" % (n, t) for n, t in sorted(late.items()))))
    dut._log.info("%d enables, each asserted exactly once; nothing further in "
                  "the %.0f ms after the sequence settled",
                  len(record.rises), record.watched_to - record.settled_at)


def test_hk_seq_initial():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_seq_initial",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
