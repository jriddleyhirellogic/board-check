"""HK-LAT-01: a latchup is declared on losing PGOOD, or on nFAULT asserting.

Items: VC-HK-0001, VC-HK-0002. Clause: VVP-HK-004.

  A latchup shall be declared when a filtered PGOOD goes low on a source that
  has booted successfully, or a filtered nFAULT goes low on a source that is
  enabled.

Two conditions, so two tests. They are not the same claim and a single test
covering both would pass while one of them was broken -- the design checks
them on one line (`pwr_src_bootseq.sv:112`) but that is an implementation
detail, and the requirement is written as an or.

A declared latchup is not an output of this device. What the board can see is
that the source's enable **deasserts** -- `pwr_src_bootseq.sv` drives
`pwr_en` low in the LATCHUP state -- and that the region's status to the
PolarFire goes low with it. Those are the observables, so those are what
these tests assert; `HK-SRC-10` covers what happens afterwards.

DDR8's 2V5 source is the subject. It is hardware-controlled, so it boots
without being asked, and it is the only kind of source that does not set
`IGNORE_LATCHUP_ON_BOOT` -- the step-down region does (`HK-SRC-09`), and a
test written against that one would be testing the exception.
"""

from __future__ import annotations

import cocotb

from fsverif import board, sim
from fsverif.clkrst import advance, until
from fsverif.pins import boundary

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

#: The source under test, as the device names it and as the board names it.
SOURCE_ENABLE = "ddr8_en_2v5"
SOURCE_PGOOD = "ddr8_pgood_2v5"
REGION_STATUS = "ddr8_status_to_pf"

#: How long the device may take to act on a rail that has changed. The input
#: is filtered for 5 us (`HK-IO-05`) and synchronised before that, so nothing
#: can happen sooner; the allowance beyond it is for the synchroniser and the
#: state machine, not for the device to make up its mind.
FILTER_US = 5.0
ALLOWANCE_US = 7.0


def _bit() -> int:
    return board.index(board.model())[SOURCE_PGOOD]


async def _boot_then(dut, injection: str):
    """Boot the hardware regions, then apply a failure to the source.

    Returns how long the device took to deassert the source's enable, and
    whether PGOOD stayed high throughout that wait.

    The second value is why this is a function and not two lines in each
    test. PGOOD falls *as a consequence* of a declared latchup -- the enable
    goes low, the regulator loses its enable, and the board model drops the
    rail -- so checking it afterwards always finds it low and proves nothing
    about what caused the latchup. It has to be watched while the device is
    deciding.
    """
    from fsverif import boot

    # Both tests in this module run in one simulation, one after the other,
    # so the second would otherwise inherit whatever the first injected and
    # declare its latchup before doing anything.
    dut.rail_fail.value = 0
    dut.rail_fault.value = 0
    await boot.hardware(dut)

    enable = boundary(dut, SOURCE_ENABLE)
    status = boundary(dut, REGION_STATUS)
    assert int(enable.value) == 1 and int(status.value) == 1, (
        "%s did not boot, so there is no successfully-booted source to "
        "declare a latchup on and this test would pass without exercising "
        "the requirement. enable=%s status=%s"
        % (SOURCE_ENABLE, enable.value, status.value))

    pgood = boundary(dut, SOURCE_PGOOD)
    held = {"pgood": True}

    def deasserted() -> bool:
        if int(enable.value) == 0:
            return True
        held["pgood"] = held["pgood"] and int(pgood.value) == 1
        return False

    getattr(dut, injection).value = 1 << _bit()
    waited = await until(
        dut.clk, deasserted,
        timeout_s=(FILTER_US + ALLOWANCE_US) / 1e6, poll_ms=0.0005,
        describe=lambda: "%s was still asserted, so no latchup was declared"
                         % SOURCE_ENABLE)
    return waited, held["pgood"]


@cocotb.test()
async def test_HK_LAT_01_pgood_low_after_boot(dut):
    """VC-HK-0001: PGOOD going low on a booted source declares a latchup."""
    waited, _ = await _boot_then(dut, "rail_fail")
    dut._log.info("%s deasserted %.2f us after PGOOD fell",
                  SOURCE_ENABLE, waited * 1e6)

    # The region also stops reporting itself good. A latchup that deasserted
    # the enable but left the PolarFire being told the region was healthy
    # would satisfy the letter of the observable and none of its purpose.
    await advance(dut.clk, cycles=2)
    assert int(boundary(dut, REGION_STATUS).value) == 0, (
        "%s deasserted but %s still reports the region booted, so the "
        "PolarFire is being told a latched-up region is healthy"
        % (SOURCE_ENABLE, REGION_STATUS))


@cocotb.test()
async def test_HK_LAT_01_nfault_low_while_enabled(dut):
    """VC-HK-0002: nFAULT going low on an enabled source declares a latchup.

    Driven through `rail_fault` rather than `rail_fail`, which is the reason
    those are separate inputs to the board model. Tying them together made
    every rail that failed to start also report an overcurrent, and this test
    would then have been unable to show that the nFAULT path works at all --
    the PGOOD path would have declared the latchup first.
    """
    waited, pgood_held = await _boot_then(dut, "rail_fault")
    dut._log.info("%s deasserted %.2f us after nFAULT asserted",
                  SOURCE_ENABLE, waited * 1e6)

    # PGOOD stayed high while the device was deciding: the board model holds
    # this rail in regulation and only trips its fault pin. So the latchup can
    # only be attributed to nFAULT, which is the clause under test.
    assert pgood_held, (
        "%s went low before %s deasserted, so this latchup cannot be "
        "attributed to nFAULT -- the PGOOD clause of HK-LAT-01 would have "
        "declared one too" % (SOURCE_PGOOD, SOURCE_ENABLE))


def test_hk_lat_01():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_lat_01",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
