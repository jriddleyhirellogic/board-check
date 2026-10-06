"""Which source failed, and how: HK-TLM-03.

Item: VC-HK-0076. Clause: VVP-HK-004.

  HK-TLM-03  The housekeeper shall report, for each software-controlled
             region, which source in that region failed and whether the
             failure was a boot failure or a latchup.

For every software region, every source is made to fail both ways -- its
rail held dead, so that it times out; and its rail dropped after boot, so
that it latches -- and the region's failure metadata read each time. The
item asks that the kinds be "distinguishable from the outputs alone", so
the readings are held to that: every (source, kind) must read differently
from every other, and from the reading before anything has failed.

**The last is expected to fail, and why is `HK-F-06`.** The encoding for a
four-source region is 0-3 for a boot failure of source 0-3 and 4-7 for a
latchup, and the reset value is also 0; for the one-source regions boot
failure is 0 and latchup 1. So "nothing has failed" and "the first source
failed to boot" read the same. `HK-TLM-03` is `GAP` and the item declares
it.

Six regions at once, round by round: in round *k* every region fails its
*k*-th source together. Stepper Sec is done on its own afterwards, because a
booted Stepper Pri holds it down.
"""

from __future__ import annotations

import re

import cocotb
from cocotb.utils import get_sim_time

from fsverif import board, boot, sim
from fsverif.clkrst import advance, until
from fsverif.pins import SOFTWARE_REGIONS, boundary

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

SOFTWARE = {r: enables for r, _, enables in SOFTWARE_REGIONS}
CONTROL = {r: ctrl for r, ctrl, _ in SOFTWARE_REGIONS}
METADATA = {r: "%s_failure_metadata" % r for r in SOFTWARE}
GROUPS = ([r for r in SOFTWARE if r != "stepper_sec"], ["stepper_sec"])

#: Long enough for the slowest k-th source to be enabled and time out:
#: three 3 ms rails, then 25.231 ms.
TIMEOUT_WAIT_MS = 40.0
#: The retry hold is 200.540 ms; after it a region whose control has been
#: withdrawn goes to POWER_OFF.
RETRY_WAIT_MS = 260.0


def pgood_of(enable: str) -> str:
    return re.sub(r"_en(_|$)", r"_pgood\1", enable)


def _read(dut, region: str) -> int:
    return int(boundary(dut, METADATA[region]).value)


async def _request(dut, regions) -> None:
    for r in regions:
        boundary(dut, CONTROL[r]).value = 0
    await advance(dut.clk, seconds=0.0001)
    for r in regions:
        boundary(dut, CONTROL[r]).value = 1


def _withdraw(dut, regions) -> None:
    for r in regions:
        boundary(dut, CONTROL[r]).value = 0


@cocotb.test()
async def test_HK_TLM_03_failure_source_and_kind(dut):
    """VC-HK-0076: every source, both kinds, read back and told apart."""
    board.drive(dut)
    await boot.hardware(dut)
    baseline = {r: _read(dut, r) for r in SOFTWARE}
    codes = {r: {} for r in SOFTWARE}

    for group in GROUPS:
        for k in range(max(len(SOFTWARE[r]) for r in group)):
            regions = [r for r in group if len(SOFTWARE[r]) > k]
            rails = tuple(pgood_of(SOFTWARE[r][k]) for r in regions)

            # Boot failure: source k's rail dead.
            board.drive(dut, fail=rails)
            await _request(dut, regions)
            await advance(dut.clk, seconds=TIMEOUT_WAIT_MS / 1000.0)
            for r in regions:
                codes[r][(k, "boot failure")] = _read(dut, r)
            # Withdrawn during the retry hold, which it leaves only once the
            # hold is over (`HK-SRC-03` covers what it does on the way out).
            _withdraw(dut, regions)
            await advance(dut.clk, seconds=RETRY_WAIT_MS / 1000.0)
            board.drive(dut)

            # Latchup: source k's rail dropped after boot.
            await _request(dut, regions)
            await until(dut.clk, lambda: all(
                int(boundary(dut, "%s_status_to_pf" % r).value) for r in regions),
                timeout_s=0.1, poll_ms=0.1)
            board.drive(dut, fail=rails)
            await advance(dut.clk, seconds=0.0005)
            for r in regions:
                codes[r][(k, "latchup")] = _read(dut, r)
            _withdraw(dut, regions)
            await advance(dut.clk, seconds=0.003)
            board.drive(dut)

    problems = []
    for r in SOFTWARE:
        table = codes[r]
        dut._log.info("%-11s before any failure %d; %s", r, baseline[r], ", ".join(
            "%s %s -> %d" % (SOFTWARE[r][k], kind, v)
            for (k, kind), v in sorted(table.items())))
        by_value = {}
        for key, v in table.items():
            by_value.setdefault(v, []).append(key)
        for v, keys in by_value.items():
            if len(keys) > 1:
                problems.append("%s: %s all read %d" % (r, " and ".join(
                    "%s %s" % (SOFTWARE[r][k], kind) for k, kind in keys), v))
        same = by_value.get(baseline[r], [])
        if same:
            problems.append("%s: %s reads %d, the same as before anything "
                            "failed" % (r, " and ".join(
                                "%s %s" % (SOFTWARE[r][k], kind) for k, kind in same),
                                baseline[r]))
    assert not problems, (
        "the failure metadata does not identify which source failed and how, "
        "from the outputs alone:\n  " + "\n  ".join(problems)
        + "\nThe reset value is also the code for the first source failing to "
        "boot. HK-F-06.")


def test_hk_tlm_metadata():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_tlm_metadata",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
