"""Camera receive conditioning: PF-CAM-04.

Item: VC-PF-0025. Clause: VVP-PF-001.

  PF-CAM-04  The camera receive conditioning path shall extend frame-valid
             through the configured end-of-frame guard interval.

**The DUT is `cam_flow_sync`**, at the instance's parameters in `cam_rx_hier`
(`DATA_WIDTH = 384`, `EXTEND_CYCLES = 10`, `cam_rx_hier.tcl:212-214`), on the
pixel clock -- `PF_CCC_C1` GL0, 79.2 MHz. Its inputs come from the encrypted
SLVS-EC receiver, which does not run here; the test drives them the way the
receiver's outputs are wired (`:394`, `:399`, `:402`, `:479`), and a stand-in
for a receiver is not the receiver (the item's note).

**What is exact.** The block registers everything: `frame_valid` reaches the
output three clocks after the input and the line, embedded-data and pixel
paths two. So the conditioned frame rises three clocks after the input frame,
and falls thirteen after it -- three of pipeline and ten of guard. The test
asserts both, in clocks, for frames of 1, 5 and 200 clocks, so the output is
high for exactly the input's high time plus the guard interval.

**And what the guard is for** (the rationale: "a stable frame boundary while
trailing embedded data clears the receive path"): an embedded-data beat on
every clock of the ten after the input frame falls leaves the block while the
conditioned frame is still up, with its data intact.
"""

from __future__ import annotations

import random

import cocotb
from cocotb.triggers import ClockCycles, FallingEdge, ReadOnly, RisingEdge

from fsverif import sim
from fsverif.clkrst import start_clock

TOP = "cam_flow_sync"
PARAMETERS = {"DATA_WIDTH": 384, "EXTEND_CYCLES": 10}
GUARD = PARAMETERS["EXTEND_CYCLES"]
PIXEL_CLK_NS = 12.626          # 79.2 MHz, PF_CCC_C1 GL0_0_OUT_FREQ
FV_LATENCY = 3                 # frame_valid: input reg, edge-detect reg, output
DATA_LATENCY = 2               # line/ebd/data: input reg, output


def _schedule(frames, gap: int = 60):
    """Per-clock input values: (fv, lv, ebd, data), and each frame's cycles.

    Each frame carries a line beat on its first and last clocks, and an
    embedded-data beat on every clock of the guard interval after it falls.
    """
    rng = random.Random(0xCA4)
    rows, spans = [], []
    idle = lambda: (0, 0, 0, 0)
    rows += [idle() for _ in range(gap)]
    for length in frames:
        start = len(rows)
        for i in range(length):
            lv = int(i in (0, length - 1))
            rows.append((1, lv, 0, rng.getrandbits(384) if lv else 0))
        fall = len(rows)
        for _ in range(GUARD):
            rows.append((0, 0, 1, rng.getrandbits(384)))
        rows += [idle() for _ in range(gap)]
        spans.append((start, fall))
    return rows, spans


@cocotb.test()
async def test_PF_CAM_04_frame_valid_guard_interval(dut):
    """VC-PF-0025: frame-valid is held through the 10-clock guard, then drops."""
    clk = dut.clk
    start_clock(clk, PIXEL_CLK_NS)
    dut.frame_valid_in.value = 0
    dut.line_valid_in.value = 0
    dut.ebd_valid_in.value = 0
    dut.data_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(clk, 5)
    await FallingEdge(clk)
    dut.rst_n.value = 1

    frames = (200, 5, 1)
    rows, spans = _schedule(frames)
    out = []            # per clock: (fv_out, valid_out, data_out), after the edge
    for fv, lv, ebd, data in rows + [(0, 0, 0, 0)] * (FV_LATENCY + GUARD + 5):
        await FallingEdge(clk)
        dut.frame_valid_in.value = fv
        dut.line_valid_in.value = lv
        dut.ebd_valid_in.value = ebd
        dut.data_in.value = data
        await RisingEdge(clk)
        await ReadOnly()
        out.append((int(dut.frame_valid_out.value),
                    int(dut.line_or_ebd_valid_out.value),
                    int(dut.data_out.value)))
    # out[k] is the output after the edge that sampled rows[k].
    fv_out = [o[0] for o in out]

    problems = []
    runs = []
    k = 0
    while k < len(fv_out):
        if fv_out[k]:
            j = k
            while j < len(fv_out) and fv_out[j]:
                j += 1
            runs.append((k, j))
            k = j
        else:
            k += 1
    # A value driven for input clock k first appears in out[k + latency - 1].
    expected = [(s + FV_LATENCY - 1, f + FV_LATENCY - 1 + GUARD) for s, f in spans]
    for length, (s, f), want, got in zip(frames, spans, expected,
                                         runs + [None] * len(spans)):
        dut._log.info("input frame of %d clocks: conditioned frame %s, "
                      "expected %s", length, got and (got[1] - got[0]), want[1] - want[0])
        if got != want:
            problems.append(
                "a %d-clock frame: conditioned frame-valid high for output clocks "
                "%s, expected %s -- rising %d clocks and falling %d clocks after "
                "the input" % (length, got, want, FV_LATENCY, FV_LATENCY + GUARD))
    if len(runs) != len(spans):
        problems.append("%d input frames gave %d conditioned frames"
                        % (len(spans), len(runs)))

    # Every trailing embedded-data beat leaves inside the conditioned frame,
    # with its data.
    trailing = 0
    for k, (fv, lv, ebd, data) in enumerate(rows):
        if not ebd:
            continue
        trailing += 1
        at = k + DATA_LATENCY - 1
        valid, data_out = out[at][1], out[at][2]
        if not (valid and data_out == data):
            problems.append("an embedded-data beat at input clock %d did not "
                            "come out intact at output clock %d" % (k, at))
        elif not fv_out[at]:
            problems.append("an embedded-data beat %d clocks after the input "
                            "frame fell left the block after the conditioned "
                            "frame had ended" % (k - max(f for _, f in spans if f <= k) + 1))
    dut._log.info("%d trailing embedded-data beats, one on every clock of each "
                  "guard interval", trailing)
    assert trailing == GUARD * len(frames)
    assert not problems, "\n  ".join(["PF-CAM-04:"] + problems)


def test_pf_cam_04():
    sim.run(hdl_toplevel=TOP,
            sources=sim.block("cam_flow_sync_ip", "cam_flow_sync.sv"),
            test_module="test_pf_cam", parameters=PARAMETERS)
