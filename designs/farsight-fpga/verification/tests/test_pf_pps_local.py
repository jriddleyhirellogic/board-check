"""The local PPS generator and the source mux: PF-PPS-07 and PF-PPS-08.

Items: VC-PF-0088, VC-PF-0090. Clause: VVP-PF-001.

  PF-PPS-07  The local PPS generator shall produce a 1 Hz pulse with 50 %
             duty cycle.
  PF-PPS-08  The PPS mux shall select either local or external PPS according
             to the firmware control bit.

Both read two nets of the SmartDesign (`pps_dut`): the generator's output and
the mux output, which is the discipline input of `pps`. Neither is a port --
the local PPS never leaves `pps_hier` except through `pps`, whose own
`pps_out` is the *disciplined* second, a different signal.

**PF-PPS-07 is exact.** The simulated clock is exact, so the period is not
"about 1 s": it is 50,000,000 clocks of 20 ns, high for 25,000,000 and low
for 25,000,000, and the test asserts those to the nanosecond. It measures a
whole low phase, a whole high phase and a falling-to-falling period after
reset, with the local source selected, at the mux output as well as the
generator's -- about 1.5 s of simulated time.

**PF-PPS-08 watches both sources in both settings.** With the control bit
clear, the external input is toggled every 50 ms across the generator's first
falling edge; with it set, across the generator's next rising edge. In each
setting the mux output must change exactly when the selected source does, and
never when only the unselected one does. The switch is made while both
sources are low, so it is not itself a transition. About 1.1 s.

(A switch made while the sources differ *is* a transition at the discipline
input, and the time-jam and discipline logic see it as a PPS edge. That is
the mux doing what it is told; firmware that switches sources mid-second
should expect one out-of-window edge -- and with a time-jam armed, that edge
loads it: `PF-F-23`.)
"""

from __future__ import annotations

import cocotb

import pps_dut as pps
from pps_dut import CLK_PERIOD_NS, HALF_PERIOD_CLOCKS, SECOND_NS, now_ns
from fsverif.clkrst import advance

HALF_NS = HALF_PERIOD_CLOCKS * CLK_PERIOD_NS          # 0.5 s


@cocotb.test()
async def test_PF_PPS_07_local_1hz_50pct_duty(dut):
    """VC-PF-0088: the local generator is 1 Hz, 50 % duty, to the clock."""
    clk = dut.sys_clk_50mhz
    apb = await pps.start(dut)
    local = pps.Watch(getattr(dut, pps.LOCAL))
    mux = pps.Watch(getattr(dut, pps.DISCIPLINE))
    await apb.write(pps.EN_LOCAL_PPS, 1)
    assert (await apb.read(pps.EN_LOCAL_PPS)).data == 1, \
        "the local source did not select"
    selected_ns = now_ns()

    await advance(clk, seconds=1.55)
    local.stop()
    mux.stop()

    events = local.events
    dut._log.info("generator: %s", events)
    assert [v for _, v in events] == [0, 1, 0], (
        "expected the generator to fall, rise and fall again in 1.55 s after "
        "reset; it changed %s" % events)
    (fall1, _), (rise, _), (fall2, _) = events
    low, high, period = rise - fall1, fall2 - rise, fall2 - fall1
    dut._log.info("low %d ns, high %d ns, period %d ns", low, high, period)
    problems = []
    if period != SECOND_NS:
        problems.append("period %d ns, not 1 s" % period)
    if high != HALF_NS or low != HALF_NS:
        problems.append("high %d ns and low %d ns, not 50 %% of 1 s each"
                        % (high, low))

    # And the selected source reaches the discipline input unchanged.
    selected = [e for e in mux.events if e[0] > selected_ns]
    if selected != events:
        problems.append("with the local source selected the discipline input "
                        "changed %s, the generator %s" % (selected, events))
    assert not problems, "\n  ".join(["PF-PPS-07:"] + problems)


@cocotb.test()
async def test_PF_PPS_08_mux_selects_local_or_external(dut):
    """VC-PF-0090: the mux follows only the source the control bit selects."""
    clk = dut.sys_clk_50mhz
    apb = await pps.start(dut)
    assert (await apb.read(pps.EN_LOCAL_PPS)).data == 0, \
        "the control bit is not clear out of reset"
    external = pps.Watch(dut.pps_in)
    local = pps.Watch(getattr(dut, pps.LOCAL))
    mux = pps.Watch(getattr(dut, pps.DISCIPLINE))
    start_ns = now_ns()

    async def toggle_external_until(t_ns):
        while now_ns() < t_ns:
            await advance(clk, seconds=0.025)
            await pps.pulse(dut, high_clocks=50_000)          # 1 ms high

    # Control bit clear, across the generator's first falling edge (0.5 s).
    await toggle_external_until(start_ns + 0.54e9)
    await advance(clk, cycles=60_000, period_ns=CLK_PERIOD_NS)
    assert int(dut.pps_in.value) == 0 and int(getattr(dut, pps.LOCAL).value) == 0
    await apb.write(pps.EN_LOCAL_PPS, 1)
    assert (await apb.read(pps.EN_LOCAL_PPS)).data == 1
    switch_ns = now_ns()

    # Control bit set, across its next rising edge (1.0 s).
    await toggle_external_until(start_ns + 1.04e9)
    await advance(clk, cycles=60_000, period_ns=CLK_PERIOD_NS)
    for w in (external, local, mux):
        w.stop()

    def within(watch, lo, hi):
        return [e for e in watch.events if lo < e[0] <= hi]

    problems = []
    end_ns = now_ns()
    for label, lo, hi, chosen, other in (
            ("control bit 0 (external)", start_ns, switch_ns, external, local),
            ("control bit 1 (local)", switch_ns, end_ns, local, external)):
        want, seen = within(chosen, lo, hi), within(mux, lo, hi)
        unselected = within(other, lo, hi)
        dut._log.info("%s: %d selected-source changes, %d unselected, %d at "
                      "the mux", label, len(want), len(unselected), len(seen))
        if not want or not unselected:
            problems.append("%s: the window has %d selected and %d unselected "
                            "changes; it must have both to show anything"
                            % (label, len(want), len(unselected)))
        if seen != want:
            extra = sorted(set(seen) - set(want))
            missing = sorted(set(want) - set(seen))
            problems.append("%s: the mux output did not follow the selected "
                            "source -- extra changes %s, missing %s"
                            % (label, extra[:4], missing[:4]))
    assert not problems, "\n  ".join(["PF-PPS-08:"] + problems)


def test_pf_pps_07():
    pps.run("test_pf_pps_local", "test_PF_PPS_07_local_1hz_50pct_duty")


def test_pf_pps_08():
    pps.run("test_pf_pps_local", "test_PF_PPS_08_mux_selects_local_or_external")
