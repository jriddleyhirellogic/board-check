"""The global latch holds, and only reset clears it: HK-LAT-03, HK-LAT-04.

Items: VC-HK-0004, VC-HK-0005. Clause: VVP-HK-004.

  HK-LAT-03  A global critical latchup shall hold every power enable in the
             system deasserted.
  HK-LAT-04  Recovery from a global critical latchup shall require assertion
             of the external reset input or a power cycle.

Both start from the same state: everything the device can power, powered.
The hardware chain boots by itself; every software region that can be up at
once is then requested and waited for. Stepper Sec is left unrequested,
because Stepper Pri being booted holds it down (`health_monitor.sv:547`), so
requesting both would begin from a state the design itself refuses. Then
DDR8's 2V5 rail loses PGOOD, and DDR8 is a hardware region, so the latch is
global (`HK-LAT-02`).

**"Every power enable" is read from the device**, not from a list here
(`fsverif.pins.device_enables`): the item says so, because a test carrying its
own list stops covering an enable added later and still passes.

**"Hold" is watched, not sampled.** Every enable is read every 0.1 ms for
1.2 s after the latch. That outlasts every interval after which the design
restarts anything by itself -- the 1 s start-up interval that began the chain
in the first place, whose counter is not held by the latch, and the 200 ms
retry hold -- so an enable that came back on any of them would be seen.

**`HK-LAT-04` is a universal negative, and the item is candid about it.** No
simulation shows that *no* input sequence clears the latch; it shows that the
ones tried did not. These are: the fault removed, every software control input
toggled low and high twice -- once at once, once after the retry hold -- and
the 1 s start-up interval allowed to elapse. The item also lists re-assertion
of the source enables, which is not something a board can do: the enables are
the device's outputs. The nearest stimulus the environment can apply is the
fault removed, so that every rail would come good again if enabled. Then
`arstn` is asserted, and the chain must boot again.
"""

from __future__ import annotations

import cocotb
from cocotb.triggers import FallingEdge, SimTimeoutError, with_timeout
from cocotb.utils import get_sim_time

from fsverif import board, boot, sim
from fsverif.clkrst import advance, until
from fsverif.pins import CONTROL_INPUTS, SOFTWARE_REGIONS, boundary, device_enables

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

#: Requested before the latch, and the status each reports booted on.
REQUESTED = {"imx": "imx_ctrl", "lvdt": "lvdt_ctrl", "eth1": "eth1_ctrl",
             "eth2": "eth2_ctrl", "stepper_pri": "stepper_pri_ctrl"}

LATCHED_SOURCE = "ddr8_en_2v5"
LATCHED_RAIL = "ddr8_pgood_2v5"

#: See `test_hk_lat_global.FOLLOWS_MS`: an allowance, not `HK-LAT-08`'s bound.
FOLLOWS_MS = 0.1

HOLD_S = 1.2
POLL_MS = 0.1

#: `HK-SEQ-01`: after reset release the first enable is due at 1 s +/-5 %.
REBOOT_TIMEOUT_S = 1.2


def _now_ms() -> float:
    return get_sim_time("ns") / 1e6


async def _everything_up(dut) -> tuple:
    """Boot the hardware and every co-existing software region."""
    dut.rail_fail.value = 0
    dut.rail_fault.value = 0
    await boot.hardware(dut)
    for control in REQUESTED.values():
        boundary(dut, control).value = 1
    statuses = ["%s_status_to_pf" % r for r in REQUESTED]
    await until(
        dut.clk, lambda: all(int(boundary(dut, s).value) for s in statuses),
        timeout_s=1.0,
        describe=lambda: "not booted: %s" % ", ".join(
            s for s in statuses if not int(boundary(dut, s).value)))

    enables = device_enables()
    up = tuple(e for e in enables if int(boundary(dut, e).value))
    unrequested = {e for _, ctrl, names in SOFTWARE_REGIONS
                   if ctrl not in REQUESTED.values() for e in names}
    missing = [e for e in enables if e not in up and e not in unrequested]
    assert not missing, (
        "these enables should have been asserted before the latch and were "
        "not, so their being low afterwards would prove nothing: %s"
        % ", ".join(missing))
    return enables, up


async def _latch(dut) -> float:
    """Drop DDR8 2V5's PGOOD and return when its enable fell."""
    dut.rail_fail.value = 1 << board.index(board.model())[LATCHED_RAIL]
    try:
        await with_timeout(FallingEdge(boundary(dut, LATCHED_SOURCE)), 1, "ms")
    except SimTimeoutError:
        raise AssertionError(
            "%s stayed asserted for 1 ms after its PGOOD fell, so no latchup "
            "was declared; that is HK-LAT-01's failure" % LATCHED_SOURCE
        ) from None
    return _now_ms()


async def _watch(dut, enables, for_s: float, stimulus=()) -> list:
    """Poll every enable, applying `stimulus` -- (ms from now, action) -- on
    the way. Returns every (ms, enable) seen asserted."""
    start = _now_ms()
    pending = sorted(stimulus, key=lambda s: s[0])
    seen = []
    while _now_ms() - start < for_s * 1000.0:
        while pending and _now_ms() - start >= pending[0][0]:
            pending.pop(0)[1]()
        await advance(dut.clk, seconds=POLL_MS / 1000.0)
        seen += [(_now_ms() - start, e) for e in enables
                 if int(boundary(dut, e).value)]
    return seen


def _first_each(seen) -> str:
    first = {}
    for at, name in seen:
        first.setdefault(name, at)
    return ", ".join("%s at +%.1f ms" % (n, t) for n, t in sorted(
        first.items(), key=lambda kv: kv[1]))


@cocotb.test()
async def test_HK_LAT_03_all_enables_held_deasserted(dut):
    """VC-HK-0004: every enable falls with the latch, and stays down."""
    enables, up = await _everything_up(dut)
    await _latch(dut)
    await advance(dut.clk, seconds=FOLLOWS_MS / 1000.0)

    still = [e for e in enables if int(boundary(dut, e).value)]
    dut._log.info("%d of %d enables were asserted before the latch; %d still "
                  "asserted %.1f ms after it", len(up), len(enables),
                  len(still), FOLLOWS_MS)
    assert not still, (
        "the global latch was raised and these enables were still asserted "
        "%.1f ms later: %s" % (FOLLOWS_MS, ", ".join(still)))

    back = await _watch(dut, enables, HOLD_S)
    assert not back, (
        "the global latch held for %.1f s, but these enables re-asserted "
        "during it: %s" % (HOLD_S, _first_each(back)))


@cocotb.test()
async def test_HK_LAT_04_recovery_requires_external_reset(dut):
    """VC-HK-0005: nothing but `arstn` brings the device back."""
    enables, _ = await _everything_up(dut)
    await _latch(dut)

    def remove_fault():
        dut.rail_fail.value = 0

    def controls(level):
        def apply():
            for name in CONTROL_INPUTS:
                boundary(dut, name).value = level
        return apply

    stimulus = (
        (1.0, remove_fault),
        (5.0, controls(0)), (10.0, controls(1)),
        (300.0, controls(0)), (305.0, controls(1)),
    )
    back = await _watch(dut, enables, HOLD_S, stimulus)
    dut._log.info("latch held through: fault removed at +1 ms, every control "
                  "toggled at +5/+10 ms and +300/+305 ms, %.1f s elapsed; "
                  "%d enable assertions seen", HOLD_S, len(back))
    assert not back, (
        "the global latch cleared without a reset -- these enables asserted "
        "after the stimulus below, though nothing but arstn may clear it: %s.\n"
        "Applied: fault removed +1 ms; every software control low +5, high "
        "+10, low +300, high +305 ms; %.1f s allowed to elapse."
        % (_first_each(back), HOLD_S))

    await boot.release(dut)
    released = _now_ms()
    first = boot.HARDWARE_ENABLES[0]
    try:
        await until(dut.clk, lambda: int(boundary(dut, first).value) == 1,
                    timeout_s=REBOOT_TIMEOUT_S)
    except TimeoutError:
        raise AssertionError(
            "arstn was asserted and released and %s had not asserted %.1f s "
            "later, so the external reset did not clear the global latch"
            % (first, REBOOT_TIMEOUT_S)) from None
    dut._log.info("after arstn, %s asserted %.1f ms after release",
                  first, _now_ms() - released)


def test_hk_lat_hold():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_lat_hold",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
