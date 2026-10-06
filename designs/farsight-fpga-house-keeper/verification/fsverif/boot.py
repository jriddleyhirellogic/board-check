"""Bringing the device up, which every test that is not about reset needs.

The housekeeper takes over a second of simulated time to reach a state worth
testing: `HK-SEQ-01` holds the sequence off for 1 s after reset release, and
at the flight `WAIT_TIME_MULT_FACTOR` that is fifty million clocks. Every test
pays it, so it is written once here rather than copied into each -- a copy
drifts, and a test whose set-up is subtly different from its neighbour's is a
test whose failure tells you nothing about the requirement.

Nothing here drives a power-good or fault input. Those come from the board
model (`fsverif.board`), which brings each rail up a datasheet delay after the
device enables it.
"""

from __future__ import annotations

from fsverif.clkrst import advance, until
from fsverif.pins import CONTROL_INPUTS, HARDWARE_REGIONS, POWER_ENABLES, RESET_N

#: 5 us at 50 MHz: the depth of the glitch filter on every power-good and
#: fault input (`HK-IO-05`). A level held for less than this is not seen at
#: all, so a test that changes one of those inputs and looks immediately is
#: looking too early.
FILTER_CYCLES = 250

#: Enables belonging to the regions that boot without being asked.
HARDWARE_ENABLES = tuple(
    name for _, names in HARDWARE_REGIONS for name in names)

#: The last hardware region to boot (`HK-SEQ-02`: step down, DDR8, DDR16,
#: FPGA, LVDS). Its status output going high is the device saying the whole
#: hardware chain succeeded, which is a stronger and more honest statement
#: than counting enables: an enable is asserted at the *start* of a boot
#: attempt, so waiting on enables would proceed while a source was still
#: waiting for its rail.
LAST_HARDWARE_STATUS = "lvds_status_to_pf"


async def hardware(dut, *, timeout_s: float = 3.0) -> float:
    """Reset the device and let the hardware-controlled regions boot.

    Returns the simulated seconds waited. Leaves every software-controlled
    region unrequested, because the device starts one on a *rising edge* of
    its control input and only once the FPGA region has booted -- so a test
    that wants one asks after this returns, not before.
    """
    await release(dut)
    return await until(
        dut.clk, lambda: int(getattr(dut, LAST_HARDWARE_STATUS).value) == 1,
        timeout_s=timeout_s,
        describe=lambda: "the hardware regions never finished booting; "
                         "enables up: %s" % (", ".join(asserted(dut)) or "none"))


async def release(dut) -> None:
    """Hold the device in reset with every request withdrawn, then release it.

    For tests that cannot wait on `hardware`, because a rail they hold down
    means the hardware chain never finishes.
    """
    reset_n = getattr(dut, RESET_N)
    reset_n.value = 0
    for name in CONTROL_INPUTS:
        getattr(dut, name).value = 0
    await advance(dut.clk, cycles=FILTER_CYCLES)
    reset_n.value = 1


def asserted(dut) -> list:
    """Power enables currently high, by pin name."""
    return [name for name in POWER_ENABLES
            if int(getattr(dut, name).value) == 1]
