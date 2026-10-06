"""PPS time-jam and PPS interrupt: PF-PPS-04 and PF-PPS-06.

Items: VC-PF-0084, VC-PF-0086. Clause: VVP-PF-001.

  PF-PPS-04  The PPS time-jam command shall load the requested time on the
             next PPS edge.
  PF-PPS-06  The PPS interface shall raise an interrupt on an external PPS
             rising edge.

Both run on the external source, which the test drives, so neither needs to
wait for the local generator: every edge is placed where the test wants it,
microseconds apart. Every edge here is far outside the discipline window, so
none of them changes the clock rate -- `nanoseconds` advances by exactly
20 ns a clock throughout, and any other step is a load.

**"The next PPS edge" is the next rising edge of the selected source, seen
through the synchroniser.** `pps` samples its input through two flops and an
edge detector, so the load is visible on the third rising clock after the
input rises. The test asserts that latency exactly: a load one clock later
would be a different design, and one at a later PPS edge a failure. A falling
edge while armed must not load, and a second rising edge must not reload: the
command is one-shot.

**The interrupt is a level, set by an edge.** It rises once per external
rising edge and stays up until firmware writes 1 to the clear register, and
a held-high input does not raise it again after a clear. It follows the
external input whichever source disciplines the time: switching the mux to
the local generator -- itself a rising edge at the discipline input, because
the generator starts high -- must not raise it.
"""

from __future__ import annotations

import cocotb
from cocotb.triggers import ClockCycles, FallingEdge

import pps_dut as pps
from pps_dut import CLK_PERIOD_NS, now_ns, sample_time

JAM_SECONDS = 0x5EC0_0001
RX_DELAY_CLOCKS = 7
SYNC_LATENCY = 3           # two synchroniser flops, then the edge detect


def _continuous(samples) -> list:
    """Every step in (seconds, ns) that is not +20 ns in the same second."""
    return ["%s -> %s" % (a, b) for a, b in zip(samples, samples[1:])
            if not (b[0] == a[0] and b[1] == a[1] + CLK_PERIOD_NS)]


@cocotb.test()
async def test_PF_PPS_04_time_jam_loads_next_pps(dut):
    """VC-PF-0084: the requested time loads on the next PPS edge, not before."""
    clk = dut.sys_clk_50mhz
    apb = await pps.start(dut)
    await ClockCycles(clk, 1000)

    # A rising edge with nothing armed changes nothing.
    await FallingEdge(clk)
    dut.pps_in.value = 1
    idle = [await sample_time(dut) for _ in range(20)]
    assert not _continuous(idle), (
        "a PPS edge with no time-jam armed disturbed the time: %s"
        % _continuous(idle))

    await apb.write(pps.LOAD_SECONDS, JAM_SECONDS)
    await apb.write(pps.RX_DELAY, RX_DELAY_CLOCKS)
    assert (await apb.read(pps.LOAD_SECONDS)).data == JAM_SECONDS
    assert (await apb.read(pps.RX_DELAY)).data == RX_DELAY_CLOCKS
    await apb.write(pps.TIME_JAM, 1)

    # Armed, with no edge: 20 us of free-running time, and then a falling edge.
    armed = [await sample_time(dut) for _ in range(1000)]
    await FallingEdge(clk)
    dut.pps_in.value = 0
    armed += [await sample_time(dut) for _ in range(20)]
    early = [s for s in armed if s[0] == JAM_SECONDS]
    assert not early and not _continuous(armed), (
        "the time-jam took effect before a PPS rising edge: %s"
        % (early[:1] or _continuous(armed)[:3]))

    # The rising edge.
    await FallingEdge(clk)
    dut.pps_in.value = 1
    edge_ns = now_ns()
    after = []
    for _ in range(40):
        sample = await sample_time(dut)
        after.append((now_ns(),) + sample)
    loaded = [i for i, (_, s, _) in enumerate(after) if s == JAM_SECONDS]
    assert loaded, ("the time-jam never loaded: %d clocks after the PPS edge "
                    "the time is still %s" % (len(after), after[-1][1:]))
    first = loaded[0]
    latency = first + 1
    t, seconds, ns = after[first]
    dut._log.info("loaded %d clocks after the edge (%d ns): seconds=0x%08x, "
                  "nanoseconds=%d", latency, t - edge_ns, seconds, ns)
    assert latency == SYNC_LATENCY, (
        "loaded %d clocks after the PPS edge; the synchroniser and edge "
        "detect account for %d" % (latency, SYNC_LATENCY))
    assert ns == RX_DELAY_CLOCKS * CLK_PERIOD_NS, (
        "loaded nanoseconds=%d; the requested receive delay of %d clocks is "
        "%d ns" % (ns, RX_DELAY_CLOCKS, RX_DELAY_CLOCKS * CLK_PERIOD_NS))
    tail = [(s, n) for _, s, n in after[first:]]
    assert not _continuous(tail), (
        "the time did not run on from the loaded value: %s" % _continuous(tail))

    # One-shot: the next rising edge does not load it again.
    await FallingEdge(clk)
    dut.pps_in.value = 0
    await ClockCycles(clk, 1000)
    before = await sample_time(dut)
    await FallingEdge(clk)
    dut.pps_in.value = 1
    again = [before] + [await sample_time(dut) for _ in range(20)]
    assert not _continuous(again), (
        "a second PPS edge reloaded the time-jam: %s" % _continuous(again))


@cocotb.test()
async def test_PF_PPS_06_external_pps_interrupt(dut):
    """VC-PF-0086: one interrupt per external PPS rising edge."""
    clk = dut.sys_clk_50mhz
    apb = await pps.start(dut)
    irq = pps.Watch(dut.pps_irq)
    await ClockCycles(clk, 100)
    assert not int(dut.pps_irq.value), "the PPS interrupt is set out of reset"

    edges = []
    problems = []

    async def rising(label):
        edges.append((label, await pps.pulse(dut, high_clocks=1000)))

    async def clear():
        await apb.write(pps.CLEAR_IRQ, 1)
        await ClockCycles(clk, 4)
        if int(dut.pps_irq.value):
            problems.append("writing 1 to the clear register did not clear it")

    # A rising edge, held high; then its falling edge.
    await rising("first edge")
    await ClockCycles(clk, 100)
    if not int(dut.pps_irq.value):
        problems.append("the interrupt did not stay set after the edge "
                        "(it is a level until cleared)")
    await clear()
    await ClockCycles(clk, 1000)

    # A second edge; cleared while the input is still high, it stays clear.
    await FallingEdge(clk)
    dut.pps_in.value = 1
    edges.append(("held edge", now_ns()))
    await ClockCycles(clk, 10)
    await clear()
    await ClockCycles(clk, 1000)
    if int(dut.pps_irq.value):
        problems.append("a held-high input raised the interrupt again after "
                        "a clear")
    await FallingEdge(clk)
    dut.pps_in.value = 0
    await ClockCycles(clk, 100)

    # The local generator selected: its rising edge at the discipline input
    # is not an external edge.
    rises_before = len(irq.rises())
    await apb.write(pps.EN_LOCAL_PPS, 1)
    await ClockCycles(clk, 100)
    assert int(dut.pps_mux_inst_pps_out.value) == 1, (
        "selecting the local generator did not bring its (high) output to "
        "the discipline input; the check below would prove nothing")
    if len(irq.rises()) != rises_before:
        problems.append("selecting the local generator raised the interrupt")

    # And the external input still interrupts while the local one is selected.
    await rising("edge with local selected")
    await ClockCycles(clk, 100)
    await clear()
    irq.stop()

    rises = irq.rises()
    dut._log.info("external rising edges at %s ns; interrupt rises at %s ns",
                  [t for _, t in edges], rises)
    if len(rises) != len(edges):
        problems.append("%d external rising edges raised the interrupt %d times"
                        % (len(edges), len(rises)))
    for (label, t_edge), t_irq in zip(edges, rises):
        clocks = (t_irq - t_edge) / CLK_PERIOD_NS
        if not 0 < clocks <= SYNC_LATENCY + 1:
            problems.append("%s: interrupt %g clocks after the edge"
                            % (label, clocks))
    assert not problems, "\n  ".join(["PF-PPS-06:"] + problems)


def test_pf_pps_04():
    pps.run("test_pf_pps_jam_irq", "test_PF_PPS_04_time_jam_loads_next_pps")


def test_pf_pps_06():
    pps.run("test_pf_pps_jam_irq", "test_PF_PPS_06_external_pps_interrupt")
