"""Reset: HK-CLK-03 and HK-CLK-04.

Items: VC-HK-0017, VC-HK-0018. Clause: VVP-HK-004.

  HK-CLK-03  The housekeeper shall accept an active-low asynchronous reset
             input.
  HK-CLK-04  Reset shall be asserted asynchronously and released
             synchronously to the housekeeper clock.

Both items ask what reset does with no clock running, and the clock can be
stopped (`fsverif.pins.CLOCK_ENABLE`, environment control rather than a
pin). The reference for "the reset state" is taken from the device itself:
every output, read a few clocks after an ordinary reset. With the device
booted and the clock stopped, `arstn` is asserted between clock edges, and
the outputs are compared with that reference while no edge occurs.

**These are expected to fail, for a reason already recorded.** The reset
synchroniser is asynchronous on assertion (`reset_synchronizer.sv:25`), so
the internal reset falls at once -- but every register it feeds is reset
synchronously, inside `always_ff @(posedge clk)`, and holds its value until a
clock edge arrives. That is `DRV-HK-05` and `HK-F-18`; `HK-OFFNOM-04` is the
same fact from the other side. The test also restarts the clock with reset
still held, as the control: with edges, the reset state is reached, which
shows the comparison is sound and the only thing missing is the clock.

**The release half is observable at the pins, and is tested.** Reset is
released at two phases within one clock period, and the first enable must
assert the same whole number of clocks after the first rising edge that
followed each release -- identical to the nanosecond. A release that acted
without waiting for an edge would shift with the phase.
"""

from __future__ import annotations

import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.utils import get_sim_time

from fsverif import board, boot, sim
from fsverif.clkrst import CLK_PERIOD_NS, advance, elapse, until
from fsverif.edges import Edges
from fsverif.pins import CLOCK_ENABLE, RESET_N, _device_ports, boundary

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

OUTPUTS = _device_ports("output")
FIRST = boot.HARDWARE_ENABLES[0]

#: Between edges: the clock is stopped, and reset asserted this far after.
MISALIGN_NS = 7
#: How long to watch with no clock.
STILL_NS = 1000
#: Two release phases within one 20 ns period.
PHASES_NS = (3, 13)


def _now_ns() -> float:
    return get_sim_time("ns")


def _read(dut) -> dict:
    return {o: int(boundary(dut, o).value) for o in OUTPUTS}


async def _reset_state(dut) -> dict:
    board.drive(dut)
    await boot.release(dut)
    await advance(dut.clk, cycles=10)
    return _read(dut)


async def _stopped_reset(dut) -> tuple:
    """Stop the clock, assert reset between edges, and read the outputs with
    no clock; then restart it with reset held and read them again."""
    reset_n, clock = getattr(dut, RESET_N), getattr(dut, CLOCK_ENABLE)
    clock.value = 0
    await elapse(cycles=2)
    await Timer(MISALIGN_NS, unit="ns")
    reset_n.value = 0
    await Timer(STILL_NS, unit="ns")
    still = _read(dut)
    clock.value = 1
    await advance(dut.clk, cycles=10)
    clocked = _read(dut)
    reset_n.value = 1
    return still, clocked


@cocotb.test()
async def test_HK_CLK_03_async_reset_active_low(dut):
    """VC-HK-0017: reset with the clock stopped reaches the reset state."""
    reference = await _reset_state(dut)
    await boot.hardware(dut)
    boundary(dut, "imx_ctrl").value = 1
    await until(dut.clk, lambda: int(boundary(dut, "imx_status_to_pf").value),
                timeout_s=0.1, poll_ms=0.1)
    before = _read(dut)
    moved = [o for o in OUTPUTS if before[o] != reference[o]]
    still, clocked = await _stopped_reset(dut)

    stuck = [o for o in moved if still[o] != reference[o]]
    unreached = [o for o in OUTPUTS if clocked[o] != reference[o]]
    dut._log.info("%d outputs away from their reset state before reset; with "
                  "the clock stopped and arstn low for %d ns, %d still were; "
                  "with the clock restarted, %d", len(moved), STILL_NS,
                  len(stuck), len(unreached))
    assert moved, "nothing was away from its reset state, so nothing was tested"
    assert not unreached, (
        "even with the clock running, reset did not reach the reset state: %s"
        % ", ".join(unreached))
    assert not stuck, (
        "with the clock stopped, arstn asserted between edges and held for "
        "%d ns left these outputs where they were, %d of %d: %s. Every "
        "register behind the reset synchroniser is reset synchronously, so "
        "reset takes effect only when a clock edge arrives. DRV-HK-05, HK-F-18."
        % (STILL_NS, len(stuck), len(moved), ", ".join(stuck)))


@cocotb.test()
async def test_HK_CLK_04_async_assert_sync_release(dut):
    """VC-HK-0018: release waits for an edge; assertion does not."""
    reset_n = getattr(dut, RESET_N)
    counts = []
    for phase in PHASES_NS:
        board.drive(dut)
        reset_n.value = 0
        await advance(dut.clk, cycles=250)
        await RisingEdge(dut.clk)
        await Timer(phase, unit="ns")
        reset_n.value = 1
        await RisingEdge(dut.clk)
        edge = _now_ns()
        edges = Edges(dut, (FIRST,), origin_ns=0)
        await until(dut.clk, lambda: bool(edges.rises(FIRST)), timeout_s=1.2,
                    poll_ms=1.0)
        edges.stop()
        clocks = (edges.rises(FIRST)[0] * 1e6 - edge) / CLK_PERIOD_NS
        counts.append(clocks)
        dut._log.info("released %d ns after an edge: %s asserted %.3f clocks "
                      "after the next edge", phase, FIRST, clocks)

    assert len(set(counts)) == 1 and counts[0] == int(counts[0]), (
        "released at %s ns into a clock period, %s asserted %s clocks after "
        "the next edge: the release did not act on a clock edge"
        % (PHASES_NS, FIRST, counts))

    still, _ = await _stopped_reset(dut)
    assert not int(still[FIRST]), (
        "with the clock stopped, arstn asserted between edges left %s "
        "asserted: assertion did not take effect without a clock edge. "
        "DRV-HK-05, HK-F-18." % FIRST)


def test_hk_clk():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_clk",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
