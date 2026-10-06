"""Off-nominal behaviour: HK-OFFNOM-02 and HK-OFFNOM-04.

Items: VC-HK-0097, VC-HK-0099. Clause: VVP-HK-004.

  HK-OFFNOM-02  Drive every output to the PolarFire to its inactive state
                whenever the FPGA power region is not booted.
  HK-OFFNOM-04  Drive all power enables to their deasserted state on loss of
                the input clock.

**Both of these are expected to fail, and both are supposed to.** Each
requirement is recorded as a `GAP`, each item declares `expect: FAIL`, and
neither test is muted in any way -- they run, they report what happened, and
the merge gate reads the declaration rather than the test to decide whether
that blocks. A test that hid this would be worse than no test, because the
repository would then claim the requirement was met.

What they are for is the other direction. When somebody fixes the gating or
adds a clock monitor, these stop failing, and the gate reports a stale
declaration -- which forces the item and the requirement's status to be
brought up to date instead of quietly left saying `GAP`. That has already
happened once on this repository, with the boot timeout.

`HK-OFFNOM-01` and `HK-OFFNOM-03` are in `test_hk_offnom_unreachable.py`, for
a different reason: those two cannot be stimulated in simulation at all, which
is a separate claim and deserves to be separately visible.
"""

from __future__ import annotations

import cocotb

from fsverif import board, boot, sim
from fsverif.clkrst import advance, elapse, until
from fsverif.pins import (CLOCK_ENABLE, PF_INACTIVE, PF_OUTPUTS, POWER_ENABLES,
                          boundary)

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

#: How often to look at the PolarFire outputs while the FPGA region is down.
#:
#: Fine enough to catch an output that is driven for part of the window,
#: coarse enough not to dominate a run whose first window is over a second.
WATCH_MS = 0.5

#: How long to watch after the FPGA region has gone down. Nothing in the
#: device comes back up without a reset, so anything still driven by then is
#: driven for good.
AFTER_DOWN_MS = 5.0

#: The failure recorded before the power-down, so that there is failure
#: metadata to be driven afterwards: IMX's first source latches up, which the
#: region reports as code 4 (`HK-TLM-03`). A hardware latchup would not do --
#: it holds every region in reset and so clears the metadata itself.
IMX_CTRL, IMX_STATUS, IMX_META = "imx_ctrl", "imx_status_to_pf", "imx_failure_metadata"
IMX_FIRST_RAIL = "imx_pgood_1v1"
EFUSE = "eps_efuse_pgood"

#: Long enough after the clock stops that a clock-driven response would have
#: happened. If the enables are still asserted after this, nothing is coming.
AFTER_CLOCK_LOSS_MS = 5.0


def _driven_high(dut) -> list:
    """Outputs to the PolarFire that are not at their inactive state."""
    high = []
    for name, width in PF_OUTPUTS:
        value = int(getattr(dut, name).value)
        if value != PF_INACTIVE:
            high.append("%s=%s" % (name, format(value, "0%db" % width)))
    return high


async def _watch(dut, done, limit_ms: float) -> tuple:
    """Sample every output to the PolarFire until `done()` or `limit_ms`.

    Returns (offenders, milliseconds watched). `pf_status_to_pf` is the FPGA
    region's own status, so it is the window's edge rather than an offender.
    """
    offenders, waited = {}, 0.0
    while not done() and waited < limit_ms:
        for entry in _driven_high(dut):
            name = entry.split("=")[0]
            if name != "pf_status_to_pf":
                offenders.setdefault(name, entry)
        await advance(dut.clk, seconds=WATCH_MS / 1000.0)
        waited += WATCH_MS
    return offenders, waited


@cocotb.test()
async def test_HK_OFFNOM_02_outputs_inactive_while_fpga_down(dut):
    """VC-HK-0097: nothing is driven at the PolarFire while its rails are down.

    Two windows, because the FPGA region is down twice in a flight's life:
    from power-up until it boots, and after a power-down until the next power
    cycle. The second is where failure metadata can exist to be driven -- DDR
    metadata latches only while the FPGA region is booted
    (`pwr_region_ddr8_bootseq.sv:149`) and software regions cannot fail
    before it -- so a test that watched only the first would not see it.

    Expected to fail -- `HK-F-07`. `pa3_status_to_pf` is tied to `'1`
    (`health_monitor_io.sv:322`) and is high in both windows; the failure
    metadata is ungated and holds IMX's code through the second.

    The bus input idles high throughout, so the RS-422 line to the PolarFire
    would be high in both windows if it followed the bus. It is held low
    (`uart_ctrl.sv:106`), which is this requirement met for that line.
    """
    board.drive(dut)
    boundary(dut, "rs422_ttl_bus_to_farsight_pa3").value = 1
    await boot.release(dut)

    booted = boundary(dut, "pf_status_to_pf")
    before, waited = await _watch(dut, lambda: int(booted.value) == 1, 3000.0)
    assert int(booted.value) == 1, (
        "the FPGA region never reported booted within %g ms, so this test "
        "never reached the end of the window it is about and cannot say "
        "whether the outputs were quiet during it" % waited)
    dut._log.info("FPGA region booted %.1f ms after reset release; watched "
                  "%d outputs to the PolarFire throughout", waited,
                  len(PF_OUTPUTS))

    boundary(dut, IMX_CTRL).value = 1
    await until(dut.clk, lambda: int(boundary(dut, IMX_STATUS).value) == 1,
                timeout_s=0.1, describe=lambda: "IMX never booted")
    board.drive(dut, fail=(IMX_FIRST_RAIL,))
    await advance(dut.clk, seconds=0.001)
    recorded = int(boundary(dut, IMX_META).value)
    assert recorded != PF_INACTIVE, (
        "IMX latched up and its failure metadata still read %d, so there is "
        "no recorded failure for the second window to catch being driven, "
        "and the test would pass while establishing nothing" % recorded)

    board.drive(dut, fail=(IMX_FIRST_RAIL, EFUSE))
    await until(dut.clk, lambda: int(booted.value) == 0, timeout_s=0.05,
                poll_ms=0.01,
                describe=lambda: "the eFuse power-down never took the FPGA "
                                 "region down")
    after, _ = await _watch(dut, lambda: False, AFTER_DOWN_MS)
    dut._log.info("IMX metadata %d before the power-down; watched %g ms after "
                  "the FPGA region went down", recorded, AFTER_DOWN_MS)

    problems = []
    if before:
        problems.append("before the FPGA region booted: %s"
                        % ", ".join(sorted(before.values())))
    if after:
        problems.append("after the FPGA region went down: %s"
                        % ", ".join(sorted(after.values())))
    assert not problems, (
        "these outputs to the PolarFire were driven away from their inactive "
        "state while the FPGA region was down, so the housekeeper was driving "
        "into unpowered PolarFire inputs. HK-F-07.\n  " + "\n  ".join(problems))


@cocotb.test()
async def test_HK_OFFNOM_04_enables_low_on_clock_loss(dut):
    """VC-HK-0099: every power enable falls when the input clock stops.

    Expected to fail. Every enable is held by a register clocked from the
    50 MHz input and reset synchronously, so when the clock stops the enables
    keep whatever value they were holding -- including mid-boot, with rails
    partially energised. Latchup detection stops with the same clock, so the
    rails stay energised *and* the response that would protect them is dead.

    The clock is stopped through the wrapper's `clk_enable`, which is not a
    pin of the device: it is environment control, and no board can drive it.
    Reaching for it by name rather than through `pins.boundary` is deliberate
    and is what this docstring is for -- `HK-OFFNOM-04` cannot be exercised
    any other way.
    """
    board.drive(dut)
    await boot.hardware(dut)

    before = boot.asserted(dut)
    assert before, (
        "no power enable was asserted before the clock was stopped, so there "
        "is nothing for the clock loss to fail to deassert and this test "
        "would pass while establishing nothing")
    dut._log.info("%d enables asserted; stopping the clock", len(before))

    getattr(dut, CLOCK_ENABLE).value = 0

    # Not `advance`, which realigns to a rising edge and would wait for a
    # clock that is never coming.
    await elapse(seconds=AFTER_CLOCK_LOSS_MS / 1000.0)

    still = boot.asserted(dut)
    assert not still, (
        "%d of %d power enables were still asserted %g ms after the input "
        "clock stopped, so the rails stay energised with no sequencer and no "
        "latchup detection running: %s"
        % (len(still), len(POWER_ENABLES), AFTER_CLOCK_LOSS_MS,
           ", ".join(still)))


def test_hk_offnom():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_offnom",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
