"""Sources within a region: HK-REG-02 and HK-REG-03.

Items: VC-HK-0044, VC-HK-0045. Clause: VVP-HK-004.

  HK-REG-02  A region shall enable its power sources one at a time, in a
             fixed order, each source starting only when the previous source
             in the region has been declared successfully booted.
  HK-REG-03  A region shall be declared successfully booted only when every
             source in the region reports success.

Both are claims about *when* something happens relative to a rail, so both
are timed from edges rather than sampled. A 1 ms poll cannot tell two enables
rising 5 us apart from two rising together, and `HK-REG-02`'s item says two
enables asserting together fails. Only a few pins are watched at once -- see
`_follow` for why, and for how levels read at each edge stand in for the
rest.

**"Declared successfully booted" is read from the rail.** A source's success
is not a pin. What decides it is its PGOOD rising while it is enabled
(`HK-SRC-05`), so the boundary form of "the previous source has been declared
booted" is "the previous source's PGOOD has risen". A next enable rising
*before* that is the failure; after it is the requirement. Each is paired
with the converse -- a source whose rail never comes good, and what then does
not happen -- because an ordering observed only on a nominal boot would also
be produced by a design that simply started each source a fixed delay after
the last.

Every multi-source region is covered: the four hardware ones by the boot
that happens anyway, and IMX, Eth1 and Eth2 by requesting them once the FPGA
region is up. LVDS, LVDT and the steppers have one source each, where order
is vacuous.
"""

from __future__ import annotations

import re

import cocotb
from cocotb.triggers import RisingEdge, SimTimeoutError, with_timeout
from cocotb.utils import get_sim_time

from fsverif import board, boot, sim
from fsverif.clkrst import advance, until
from fsverif.edges import Edges
from fsverif.pins import PGOOD_INPUTS, boundary

WAIT_TIME_MULT_FACTOR = 50
PULSE_WIDTH = 250

#: Each multi-source region's enables in boot order, from the configuration
#: table in `docs/requirements/pa3-housekeeper-requirements.md`. Written out
#: rather than read from `fsverif.pins`: the order is what is being verified,
#: and a list whose order was taken from the thing under test would verify it
#: against itself.
BOOT_ORDER = {
    "step_down": ("step_down_en_2v2", "step_down_en_3v0", "step_down_en_4v0"),
    "ddr8": ("ddr8_en_2v5", "ddr8_en_1v2", "ddr8_en_0v6"),
    "ddr16": ("ddr16_en_2v5", "ddr16_en_1v2", "ddr16_en_0v6"),
    "fpga": ("fpga_en_1v0", "fpga_en_1v0a", "fpga_en_1v25a", "fpga_en_1v8",
             "fpga_en_1v8_imx", "fpga_en_2v5a", "fpga_en_3v3_b4",
             "fpga_en_3v3_b5"),
    "imx": ("imx_en_1v1", "imx_en_1v8", "imx_en_2v9", "imx_en_3v3"),
    "eth1": ("eth1_en_1v0", "eth1_en_1v0a", "eth1_en_2v5a", "eth1_en_3v3"),
    "eth2": ("eth2_en_1v0", "eth2_en_1v0a", "eth2_en_2v5a", "eth2_en_3v3"),
}

#: Software regions requested once the hardware has booted, and the output
#: on which each reports itself booted.
REQUESTED = {"imx": "imx_ctrl", "eth1": "eth1_ctrl", "eth2": "eth2_ctrl"}
STATUS = {"imx": "imx_status_to_pf", "eth1": "eth1_status_to_pf",
          "eth2": "eth2_status_to_pf"}

#: The region status that is not gated by another region. Every other
#: `*_status_to_pf` is forced low until the FPGA region has booted
#: (`health_monitor_io.sv:311-321`), which would hide exactly the moment
#: `HK-REG-03` is about. `pf_status_to_pf` *is* the FPGA region's.
FPGA_STATUS = "pf_status_to_pf"


def pgood_of(enable: str) -> str:
    """The power-good input of the rail an enable drives."""
    pgood = re.sub(r"_en(_|$)", r"_pgood\1", enable)
    assert pgood in PGOOD_INPUTS, "%s has no power-good input %s" % (enable, pgood)
    return pgood


def _hold_dead(dut, *pgoods: str) -> None:
    index = board.index(board.model())
    dut.rail_fail.value = sum(1 << index[p] for p in pgoods)
    dut.rail_fault.value = 0


#: How long one source may take from its predecessor's enable to its own:
#: the predecessor's rail delay, the 5 us filter, and a few cycles -- or, if
#: the predecessor's rail never came good, its 25 ms timeout. Past this the
#: next enable is not coming.
STEP_TIMEOUT_MS = 100.0

#: `HK-SEQ-01` holds the first enable off for a second after reset release.
FIRST_TIMEOUT_MS = 1500.0


async def _follow(dut, region: str, first_timeout_ms: float) -> tuple:
    """Follow one region's boot an enable at a time.

    Watching every enable and power-good at once is what this would naturally
    be, and it made the simulation six times slower: each watched pin costs
    on every evaluation, and there are fifty-eight. So it watches the one
    enable expected next and the one rail that must come good first, and at
    each rise reads the *levels* of the rest of the region. An enable that
    rose out of order, or together with this one, is high at that moment;
    one that dropped out for a retry is low. That is the same information as
    a full trace at two callbacks instead of fifty-eight.

    Returns the rise times, in simulated ms, and any departures found.
    """
    order = BOOT_ORDER[region]
    rises, problems = [], []
    for n, enable in enumerate(order):
        good, watcher = None, None
        if n:
            rail = pgood_of(order[n - 1])
            if int(boundary(dut, rail).value):
                good = rises[-1]
            else:
                watcher = Edges(dut, (rail,), origin_ns=0)
        try:
            await with_timeout(RisingEdge(boundary(dut, enable)),
                               first_timeout_ms if n == 0 else STEP_TIMEOUT_MS,
                               "ms")
        except SimTimeoutError:
            problems.append("%s: %s never asserted" % (region, enable))
            if watcher:
                watcher.stop()
            break
        at = get_sim_time("ns") / 1e6
        if watcher:
            good = watcher.first_rise(rail)
            watcher.stop()

        levels = {e: int(boundary(dut, e).value) for e in order}
        dropped = [e for e in order[:n] if not levels[e]]
        ahead = [e for e in order[n + 1:] if levels[e]]
        if dropped:
            problems.append("%s: when %s asserted, %s had deasserted"
                            % (region, enable, ", ".join(dropped)))
        if ahead:
            problems.append("%s: when %s asserted, %s were already asserted "
                            "-- out of order, or together"
                            % (region, enable, ", ".join(ahead)))
        if n and (good is None or good >= at):
            problems.append("%s: %s asserted at %.4f ms before %s's rail was "
                            "good" % (region, enable, at, order[n - 1]))
        rises.append(at)
    return rises, problems


async def _rises_then_levels(dut, name: str, read, timeout_ms: float) -> tuple:
    """When `name` next rises, and the levels of `read` at that moment."""
    await with_timeout(RisingEdge(boundary(dut, name)), timeout_ms, "ms")
    return (get_sim_time("ns") / 1e6,
            {r: int(boundary(dut, r).value) for r in read})


@cocotb.test()
async def test_HK_REG_02_sources_in_fixed_order(dut):
    """VC-HK-0044: one source at a time, in order, each after the last is good.

    Nominal boot first. For every multi-source region, each enable asserts
    after the one before it, after the one before it has its rail good, and
    with every enable after it still low. Then the converse on DDR8: with the
    middle source's rail held dead, the source after it never starts.
    """
    _hold_dead(dut)
    await boot.release(dut)

    problems, timeline = [], {}
    first = FIRST_TIMEOUT_MS
    for region in ("step_down", "ddr8", "ddr16", "fpga"):
        timeline[region], found = await _follow(dut, region, first)
        problems += found
        first = STEP_TIMEOUT_MS * 2
    await until(dut.clk,
                lambda: int(boundary(dut, boot.LAST_HARDWARE_STATUS).value) == 1,
                timeout_s=0.5, describe=lambda: "LVDS never reported booted")

    followers = {r: cocotb.start_soon(_follow(dut, r, STEP_TIMEOUT_MS))
                 for r in REQUESTED}
    for control in REQUESTED.values():
        boundary(dut, control).value = 1
    for region, task in followers.items():
        timeline[region], found = await task
        problems += found

    await advance(dut.clk, seconds=STEP_TIMEOUT_MS / 1000.0)
    for region, order in BOOT_ORDER.items():
        down = [e for e in order if not int(boundary(dut, e).value)]
        if down:
            problems.append("%s: after the boot, %s were not asserted"
                            % (region, ", ".join(down)))
        dut._log.info("%s: %s", region, " -> ".join(
            "%s %.3f" % (e.rsplit("_en", 1)[-1].lstrip("_") or e, t)
            for e, t in zip(order, timeline[region])))

    assert not problems, (
        "sources did not start one at a time in their region's fixed order, "
        "each after the previous was good:\n  " + "\n  ".join(problems))

    # The converse. DDR8 1V2 is the middle source: its predecessor boots, it
    # does not, and the 0V6 source after it must not start.
    _hold_dead(dut, "ddr8_pgood_1v2")
    await boot.release(dut)
    # After the reset, not before: the enables the nominal boot left high
    # fall during it, and that fall is not the end of an attempt.
    edges = Edges(dut, ("ddr8_en_1v2", "ddr8_en_0v6"))
    await until(
        dut.clk, lambda: bool(edges.falls("ddr8_en_1v2")),
        timeout_s=1.5, poll_ms=1.0,
        describe=lambda: "ddr8_en_1v2 never completed an attempt; rises %s"
                         % edges.rises("ddr8_en_1v2"))
    # Past the end of the attempt, so a 0V6 start that was merely late shows.
    await advance(dut.clk, seconds=0.010)

    started = edges.rises("ddr8_en_0v6")
    dut._log.info("with ddr8_pgood_1v2 dead: 1v2 rose %s, fell %s; 0v6 rose %s",
                  edges.rises("ddr8_en_1v2"), edges.falls("ddr8_en_1v2"), started)
    assert edges.rises("ddr8_en_1v2"), (
        "ddr8_en_1v2 never asserted, so the source before 0V6 was never "
        "attempted and its failure to boot was not exercised")
    assert not started, (
        "ddr8_en_0v6 asserted at %s ms although ddr8_en_1v2's rail was held "
        "dead throughout, so the 1V2 source was never declared booted. A "
        "source started without its predecessor succeeding."
        % ", ".join("%.3f" % t for t in started))


@cocotb.test()
async def test_HK_REG_03_booted_only_when_all_sources(dut):
    """VC-HK-0045: a region reports booted only once all its sources have.

    Nominal first, on the two statuses that are not masked by another region
    at the moment they rise: the FPGA region's, and IMX's once requested. At
    the moment each rises, every rail in its region must already be good.
    Then IMX with its last rail held dead -- three of four sources
    succeeding -- where the status must never rise across all four attempts.
    """
    _hold_dead(dut)
    rails = {r: tuple(pgood_of(e) for e in BOOT_ORDER[r]) for r in ("fpga", "imx")}
    fpga = cocotb.start_soon(_rises_then_levels(
        dut, FPGA_STATUS, rails["fpga"], timeout_ms=3000.0))
    await boot.hardware(dut)
    imx = cocotb.start_soon(_rises_then_levels(
        dut, STATUS["imx"], rails["imx"], timeout_ms=1000.0))
    boundary(dut, REQUESTED["imx"]).value = 1

    early = []
    for region, task, status in (("fpga", fpga, FPGA_STATUS),
                                 ("imx", imx, STATUS["imx"])):
        try:
            at, levels = await task
        except SimTimeoutError:
            raise AssertionError("%s never rose, so %s never reported booted "
                                 "at all" % (status, region)) from None
        dut._log.info("%s declared booted at %.4f ms; rails then: %s",
                      region, at, levels)
        low = [r for r, v in levels.items() if not v]
        if low:
            early.append("%s: %s rose at %.4f ms with these rails not yet "
                         "good: %s" % (region, status, at, ", ".join(low)))
    assert not early, (
        "a region reported booted before every source in it had succeeded:"
        "\n  " + "\n  ".join(early))

    # The converse: IMX's last source never comes good.
    dead = pgood_of(BOOT_ORDER["imx"][-1])
    _hold_dead(dut, dead)
    await boot.hardware(dut)
    edges = Edges(dut, (BOOT_ORDER["imx"][0], STATUS["imx"])
                  + rails["imx"][:-1])
    boundary(dut, REQUESTED["imx"]).value = 1
    # Four attempts of about 225 ms each, and then some.
    await advance(dut.clk, seconds=1.2)

    succeeded = [r for r in rails["imx"][:-1] if edges.rises(r)]
    attempts = len(edges.rises(BOOT_ORDER["imx"][0]))
    dut._log.info("with %s dead: %d attempts, %s came good, status rose at %s",
                  dead, attempts, ", ".join(succeeded) or "nothing",
                  edges.rises(STATUS["imx"]) or "never")
    assert len(succeeded) == len(rails["imx"]) - 1, (
        "only %s came good, so the region was not in the state the item asks "
        "for -- every source but one succeeding" % (", ".join(succeeded) or
                                                     "nothing"))
    assert not edges.rises(STATUS["imx"]), (
        "imx_status_to_pf rose at %s ms with %s held dead throughout: the "
        "region was declared booted with one of its four sources never "
        "having reported success"
        % (", ".join("%.3f" % t for t in edges.rises(STATUS["imx"])), dead))


def test_hk_reg_sequence():
    """Build and run the device, at its synthesis parameter values."""
    sim.run_device(
        test_module="test_hk_reg_sequence",
        parameters={"WAIT_TIME_MULT_FACTOR": WAIT_TIME_MULT_FACTOR,
                    "PULSE_WIDTH": PULSE_WIDTH},
    )
