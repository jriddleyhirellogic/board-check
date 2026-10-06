"""Two requirements simulation cannot close: HK-OFFNOM-01 and HK-OFFNOM-03.

Items: VC-HK-0096, VC-HK-0098. Clause: VVP-HK-004.

  HK-OFFNOM-01  Hold every power enable deasserted from the moment the device
                begins configuration until its internal reset is released.
  HK-OFFNOM-03  Initiate a controlled shutdown if the bus input falls below
                the minimum operating voltage of the step-down converters.

These are separated from `test_hk_offnom.py` because they fail for a different
reason, and the difference matters to whoever reads the result.

The tests there fail because **the design does not do what the requirement
says** -- outputs are ungated, no clock monitor exists. Fix the design and they
pass.

These fail because **the stimulus does not exist at the boundary**. No amount
of design work makes them pass, because there is nothing for a simulation to
drive: one requirement is about a window that begins before any simulation
does, and the other about a quantity no pin carries. Both have a hardware item
alongside (`VC-HK-0102`, `VC-HK-0103`) and that is the only route to closing
them.

Each establishes whatever *is* observable first, so the result is not merely a
complaint, and then fails naming exactly what is out of reach.
"""

from __future__ import annotations

import cocotb

from fsverif import boot, sim
from fsverif.clkrst import advance
from fsverif.pins import (CONTROL_INPUTS, NFAULT_INPUTS, PGOOD_INPUTS,
                          POWER_ENABLES, RESET_N, device_inputs)

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

#: How long to hold reset while checking the enables stay down. Far longer
#: than the reset synchroniser and the glitch filters, so an enable that
#: needed a few cycles to settle would have settled.
RESET_HOLD_MS = 2.0

#: Every input of the device, accounted for by what it carries.
#:
#: This was a keyword search first -- "does any pin name contain bus, volt,
#: uv..." -- and it broke the moment the RS-422 lines were added to
#: `fsverif.pins`, because `rs422_ttl_bus_to_farsight_pa3` contains "bus".
#: The test started passing, reporting that an undervoltage input existed. A
#: heuristic that answers the question by accident is worse than no test.
#:
#: Enumerating instead means a *new* input nobody has categorised fails this
#: test, which is the right behaviour: the next input added to this device
#: might be the undervoltage one, and that should be noticed here rather than
#: leave the test quietly asserting something that has stopped being true.
INPUT_KINDS = {
    "clk": "the 50 MHz oscillator",
    "arstn": "asynchronous reset",
    "rs422_ttl_bus_to_farsight_pa3": "RS-422 serial data from the bus",
    "rs422_ttl_farsight_to_bus_pf": "RS-422 serial data from the PolarFire",
}

#: The one input that reports anything about the housekeeper's own supply,
#: and why it is not the stimulus this requirement needs.
SUPPLY_INPUT = "eps_efuse_pgood"


@cocotb.test()
async def test_HK_OFFNOM_01_enables_low_during_config(dut):
    """VC-HK-0096: enables are held down from configuration to reset release.

    Expected to fail, and not because the observable part is wrong.

    What a simulation can show is the tail of the window: with reset asserted,
    every power enable sits deasserted. That is checked below and it holds.

    What it cannot show is the head, which is where the requirement's risk
    lives. Between power application and the end of configuration the
    ProASIC3's I/O are in their unconfigured state, and a simulation has no
    such state -- Verilator begins with the design already elaborated and
    already driving. There is no moment in this run corresponding to the one
    the requirement is about.

    So the pass this could report would be about a different interval than the
    one written down, which is the substitution the framework exists to
    prevent. It fails instead, and `VC-HK-0102` observes the real window with
    a scope.
    """
    reset_n = getattr(dut, RESET_N)
    dut.rail_fail.value = 0
    dut.rail_fault.value = 0
    reset_n.value = 0
    for name in ("imx_ctrl", "lvdt_ctrl", "eth1_ctrl", "eth2_ctrl",
                 "stepper_pri_ctrl", "stepper_sec_ctrl"):
        getattr(dut, name).value = 0

    # The observable half: nothing may assert while reset is held.
    asserted = set()
    for _ in range(int(RESET_HOLD_MS / 0.1)):
        await advance(dut.clk, seconds=0.0001)
        asserted.update(boot.asserted(dut))

    assert not asserted, (
        "these power enables asserted while reset was held, so the device "
        "does not even hold them down over the interval a simulation can "
        "see: %s" % ", ".join(sorted(asserted)))
    dut._log.info("all %d enables held deasserted across %g ms of asserted "
                  "reset -- the only part of this requirement's window a "
                  "simulation reaches", len(POWER_ENABLES), RESET_HOLD_MS)

    raise AssertionError(
        "The observable part holds: every power enable stayed deasserted "
        "throughout reset.\n"
        "The requirement is not satisfied by that. Its window begins when the "
        "device begins configuration, and a simulation has no such moment -- "
        "Verilator starts with the design elaborated and driving, so there is "
        "no unconfigured I/O state to observe. Reporting a pass here would be "
        "reporting a different interval than the one written down.\n"
        "VC-HK-0102 observes the real window on the rig, and is the only "
        "route to closing HK-OFFNOM-01.")


@cocotb.test()
async def test_HK_OFFNOM_03_shutdown_on_undervoltage(dut):
    """VC-HK-0098: a bus undervoltage begins a controlled shutdown.

    Expected to fail, and the reason is visible at the boundary rather than in
    the behaviour: **no pin of this device carries the bus input voltage.**

    The housekeeper learns about its input only through `eps_efuse_pgood`,
    which reports an eFuse trip. A slow droop that stays above the eFuse
    threshold and below the converters' dropout is a different event, and
    nothing in the design observes it -- there is no comparator, no threshold
    and no pin.

    So this is not a test that could be written better. There is nothing to
    drive, and the check below says so by looking rather than by asserting it
    from memory: if somebody adds an undervoltage input, this stops failing
    for this reason and starts being a real test.
    """
    # Every input, sorted into what it carries. Anything left over is an
    # input this test does not understand, and might be the one the
    # requirement needs.
    accounted = (set(PGOOD_INPUTS) | set(NFAULT_INPUTS) | set(CONTROL_INPUTS)
                 | set(INPUT_KINDS))
    inputs = set(device_inputs())
    uncategorised = sorted(inputs - accounted)

    assert not uncategorised, (
        "the device has inputs this test does not account for, so it cannot "
        "say whether one of them carries the bus input voltage. If one does, "
        "HK-OFFNOM-03 has become testable and this test should drive it: %s"
        % ", ".join(uncategorised))

    dut._log.info("all %d device inputs accounted for: %d power-good, %d "
                  "fault, %d control, %d other -- none carries a supply "
                  "voltage level", len(inputs), len(PGOOD_INPUTS),
                  len(NFAULT_INPUTS), len(CONTROL_INPUTS), len(INPUT_KINDS))

    usable = []
    assert usable, (
        "no pin of the housekeeper carries the bus input voltage, so a bus "
        "undervoltage cannot be presented to this device in simulation at "
        "all.\n"
        "The only related input is %s, which reports an eFuse "
        "trip -- an event that has already happened -- rather than the droop "
        "below the step-down converters' minimum operating voltage that "
        "HK-OFFNOM-03 is about. There is no threshold, comparator or timer in "
        "the design for it either.\n"
        "This is a design gap, not a testbench gap: no simulation can close "
        "HK-OFFNOM-03 until an undervoltage input exists. VC-HK-0103 ramps "
        "the real bus on the rig." % SUPPLY_INPUT)


def test_hk_offnom_unreachable():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_offnom_unreachable",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
