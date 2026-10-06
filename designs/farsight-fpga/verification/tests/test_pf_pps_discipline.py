"""PPS discipline window: PF-PPS-02.

Item: VC-PF-0082. Clause: VVP-PF-001.

  PF-PPS-02  The PPS discipline logic shall ignore external PPS periods
             outside the accepted tolerance window.

The window is +/-50 % of the nominal 1 s period (the requirement's Note;
`pps.sv:124-126`): a PPS rising edge whose interval from the previous one is
not strictly between 25,000,000 and 75,000,000 clocks is not a measurement.

**What "ignored" is observed as.** An accepted edge updates three things: the
phase error and frequency error (both readable over APB), and from them the
clock rate -- the length of the design's own second, which sets when
`pps_out` rises. An ignored edge changes none of them, and does not disturb
the running time: `nanoseconds` goes on advancing 20 ns a clock straight
through it. The test checks all of that across every rejected edge.

**Rejected edges, from glitch to just outside the window.**

| edge | interval | |
| --- | --- | --- |
| glitch burst | 10 us, three times | far too short |
| short | 0.499 s | 50,000 clocks inside the lower bound |
| long | 1.501 s | 50,000 clocks past the upper bound |

**And one accepted, as a control.** Without it, a test that saw nothing --
a discipline that never ran, or registers that read 0 for another reason --
would pass. The last edge comes 0.900 s after the one before, inside the
window, and its frequency error is known exactly: the smoothing average
starts at eight nominal periods, so one 45,000,000-clock sample makes it
(7 x 50,000,000 + 45,000,000) / 8 = 49,375,000, and the error -625,000.

About 2.9 s of simulated time -- some two and a half minutes.
"""

from __future__ import annotations

import cocotb
from cocotb.triggers import ClockCycles, FallingEdge

import pps_dut as pps
from pps_dut import CLK_PERIOD_NS, CLOCK_HZ, SECOND_NS, now_ns, sample_time
from fsverif.clkrst import advance

NOMINAL = CLOCK_HZ
CONTROL_CLOCKS = 45_000_000
EXPECTED_FREQUENCY_ERROR = (7 * NOMINAL + CONTROL_CLOCKS) // 8 - NOMINAL


def _signed(value: int) -> int:
    return value - (1 << 32) if value & 0x8000_0000 else value


def _steps(samples) -> list:
    """Every step in (seconds, ns) other than +20 ns or a second rollover."""
    bad = []
    for a, b in zip(samples, samples[1:]):
        same = b[0] == a[0] and b[1] == a[1] + CLK_PERIOD_NS
        rollover = b[0] == a[0] + 1 and b[1] == 0
        if not (same or rollover):
            bad.append("%s -> %s" % (a, b))
    return bad


@cocotb.test()
async def test_PF_PPS_02_ignore_outside_tolerance(dut):
    """VC-PF-0082: periods outside +/-50 % do not discipline the time."""
    clk = dut.sys_clk_50mhz
    apb = await pps.start(dut)
    out = pps.Watch(dut.pps_out)
    problems = []
    edges = []

    async def edge(label: str) -> None:
        """One rising edge at the discipline input, and its consequences."""
        before = [await sample_time(dut) for _ in range(4)]
        await FallingEdge(clk)
        dut.pps_in.value = 1
        edges.append((label, now_ns()))
        after = [await sample_time(dut) for _ in range(12)]
        await FallingEdge(clk)
        dut.pps_in.value = 0
        steps = _steps(before + after)
        if steps:
            problems.append("%s: the running time jumped: %s" % (label, steps))

    async def untouched(label: str) -> None:
        phase = _signed((await apb.read(pps.PHASE_ERROR)).data)
        frequency = _signed((await apb.read(pps.FREQUENCY_ERROR)).data)
        dut._log.info("%s: phase error %d, frequency error %d",
                      label, phase, frequency)
        if phase or frequency:
            problems.append("%s: the edge was used -- phase error %d, "
                            "frequency error %d" % (label, phase, frequency))

    await advance(clk, cycles=50_000, period_ns=CLK_PERIOD_NS)   # 1 ms
    for n in range(3):
        await edge("glitch %d" % (n + 1))
        await ClockCycles(clk, 500)
    await untouched("glitch burst")

    await advance(clk, cycles=24_950_000, period_ns=CLK_PERIOD_NS)
    await edge("0.499 s")
    await untouched("0.499 s")

    await advance(clk, cycles=75_050_000, period_ns=CLK_PERIOD_NS)
    await edge("1.501 s")
    await untouched("1.501 s")

    # The rate is unchanged exactly when every `pps_out` rise is a nominal
    # second after the one before.
    rises = out.rises()
    uneven = [(a, b) for a, b in zip(rises, rises[1:]) if b - a != SECOND_NS]
    dut._log.info("pps_out rose at %s ns", rises)
    if len(rises) < 2:
        problems.append("pps_out rose %d times in %.1f s; the clock-rate check "
                        "needs two" % (len(rises), now_ns() / 1e9))
    if uneven:
        problems.append("the design's own second changed length: pps_out rose "
                        "at %s" % uneven)

    # Control: an in-window period is used, and exactly as predicted. The edge
    # is placed CONTROL_CLOCKS after the last one; `edge()` spends its first
    # four sample cycles before driving, so the wait allows for them.
    last_ns = edges[-1][1]
    target_ns = last_ns + CONTROL_CLOCKS * CLK_PERIOD_NS
    await advance(clk, cycles=(target_ns - now_ns()) // CLK_PERIOD_NS - 8,
                  period_ns=CLK_PERIOD_NS)
    while now_ns() + 5 * CLK_PERIOD_NS < target_ns:
        await ClockCycles(clk, 1)
    await edge("0.900 s (control)")
    control_clocks = (edges[-1][1] - last_ns) // CLK_PERIOD_NS
    await ClockCycles(clk, 20)
    frequency = _signed((await apb.read(pps.FREQUENCY_ERROR)).data)
    phase = _signed((await apb.read(pps.PHASE_ERROR)).data)
    out.stop()
    dut._log.info("control edge %d clocks after the last: phase error %d, "
                  "frequency error %d (expected %d)", control_clocks, phase,
                  frequency, EXPECTED_FREQUENCY_ERROR)
    assert control_clocks == CONTROL_CLOCKS, (
        "the control edge landed %d clocks after the last, not %d -- the "
        "expected error below would not apply" % (control_clocks, CONTROL_CLOCKS))
    assert frequency == EXPECTED_FREQUENCY_ERROR, (
        "the in-window control edge gave a frequency error of %d, not %d: "
        "the discipline is not measuring what this test believes, so the "
        "rejections above prove nothing" % (frequency, EXPECTED_FREQUENCY_ERROR))

    assert not problems, "\n  ".join(["PF-PPS-02:"] + problems)


def test_pf_pps_02():
    pps.run("test_pf_pps_discipline", "test_PF_PPS_02_ignore_outside_tolerance")
