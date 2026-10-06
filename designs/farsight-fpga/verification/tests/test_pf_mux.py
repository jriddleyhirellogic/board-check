"""Frame-buffer routing: PF-MUX-04, PF-MUX-05, PF-MUX-08 and PF-MUX-09.

Items: VC-PF-0027 to VC-PF-0030. Clause: VVP-PF-001.

  PF-MUX-04  The camera mux shall route each accepted frame to one selected
             DDR4 write path.
  PF-MUX-05  The camera mux shall defer a select or disable change until the
             current frame boundary.
  PF-MUX-08  The camera mux shall switch routing from the 16GB DDR4 buffer to
             the 8GB DDR4 buffer after the 16GB buffer is full.
  PF-MUX-09  The camera mux shall stop accepting frames after the 8GB DDR4
             buffer is full.

**The DUT is `cam_mux_top`**, at the instance's `DATA_WIDTH = 384`
(`cam_rx_hier.tcl:224-225`), with its two clocks as the build has them: the
79.2 MHz pixel clock and the 50 MHz APB clock (`:395`, `:398`).

**Firmware has one control.** Writing `MUX_CLEAR` enables the mux, selects
the 16GB buffer and zeroes both frame counts. Every other change of select or
enable is the mux's own: the 16GB buffer is "full" at the end of its 512th
frame, which selects the 8GB buffer, and the 8GB buffer at the end of its
256th, which disables the mux. Those counts are the frame-index widths of the
two DMA write paths (9 and 8 bits), so they are what "full" means here.

**Every beat is accounted for.** Each frame's line beats carry the frame's
number and the beat's, so the monitor can say, for each output path, exactly
which frames arrived and whether they arrived whole. A frame routed to "one
path" must arrive complete, in order, on that path, with nothing -- not a
frame-valid, not a beat -- on the other.

**Frames are short and close together** -- 8 clocks of frame-valid and 12 of
gap -- so the whole capacity, 768 frames, passes in about 15,000 pixel
clocks. A beat is carried on clocks 3 to 6 of each frame: the first frame
after the mux (re)starts -- after a clear, or the switch to the 8GB buffer --
is forwarded only from when its registered edge detect sees it rise, and its
first clocks are not. Once forwarding, the mux stays forwarding between
frames and passes every clock. Both are logged, not asserted, and recorded on
`PF-MUX-04`.
"""

from __future__ import annotations

import cocotb
from cocotb.triggers import ClockCycles, FallingEdge, ReadOnly, RisingEdge

from fsverif import sim
from fsverif.bfm.apb import Apb
from fsverif.clkrst import start_clock

TOP = "cam_mux_top"
PARAMETERS = {"DATA_WIDTH": 384}
PIXEL_CLK_NS = 12.626            # 79.2 MHz, PF_CCC_C1 GL0_0_OUT_FREQ
APB_CLK_NS = 20                  # 50 MHz

MUX_CLEAR, MUX_ENABLE, MUX_SELECT = 0x00, 0x04, 0x08
DDR4_16GB_FULL, DDR4_8GB_FULL = 0x0C, 0x10

FRAMES_16GB, FRAMES_8GB = 512, 256
LENGTH, GAP = 8, 12
BEATS = range(3, LENGTH - 1)
PATHS = ("16gb", "8gb")


def _tag(frame: int, beat: int) -> int:
    return (0xF0 << 376) | (frame << 32) | beat


class Mux:
    def __init__(self, dut):
        self.dut = dut
        self.pix = dut.pixel_clk
        self.sent = 0                 # frame numbers are 1-based
        # Per path: every beat seen, in order, and every clock frame-valid was up.
        self.beats = {p: [] for p in PATHS}
        self.fv_clocks = {p: 0 for p in PATHS}
        self.both_fv = 0

    async def start(self) -> None:
        dut = self.dut
        start_clock(dut.pixel_clk, PIXEL_CLK_NS)
        start_clock(dut.pclk, APB_CLK_NS)
        self.apb = Apb(dut, dut.pclk, "")
        dut.frame_valid_in.value = 0
        dut.line_valid_in.value = 0
        dut.cam_data_in.value = 0
        dut.presetn.value = 0
        dut.pixel_rst_n.value = 0
        await ClockCycles(self.pix, 10)
        await FallingEdge(self.pix)
        dut.presetn.value = 1
        dut.pixel_rst_n.value = 1
        cocotb.start_soon(self._monitor())
        await ClockCycles(self.pix, 5)

    async def _monitor(self) -> None:
        dut = self.dut
        port = {p: (getattr(dut, "ddr4_%s_frame_valid_out" % p),
                    getattr(dut, "ddr4_%s_line_valid_out" % p),
                    getattr(dut, "ddr4_%s_cam_data_out" % p)) for p in PATHS}
        while True:
            await RisingEdge(self.pix)
            await ReadOnly()
            up = 0
            for p, (fv, lv, data) in port.items():
                if int(fv.value):
                    self.fv_clocks[p] += 1
                    up += 1
                if int(lv.value):
                    self.beats[p].append(int(data.value))
            if up == 2:
                self.both_fv += 1

    async def frame(self, length: int = LENGTH, gap: int = GAP, beats=BEATS,
                    during=None) -> int:
        """One frame; returns its number. `during(clock)` runs at each clock."""
        self.sent += 1
        n, dut = self.sent, self.dut
        for clock in range(length):
            await FallingEdge(self.pix)
            dut.frame_valid_in.value = 1
            beat = clock in beats
            dut.line_valid_in.value = int(beat)
            dut.cam_data_in.value = _tag(n, clock) if beat else 0
            if during:
                await during(clock)
        await FallingEdge(self.pix)
        dut.frame_valid_in.value = 0
        dut.line_valid_in.value = 0
        dut.cam_data_in.value = 0
        await ClockCycles(self.pix, gap, rising=False)
        return n

    async def clear(self) -> None:
        await self.apb.write(MUX_CLEAR, 1)
        await ClockCycles(self.pix, 20)

    async def status(self) -> dict:
        names = {"enable": MUX_ENABLE, "select": MUX_SELECT,
                 "16gb_full": DDR4_16GB_FULL, "8gb_full": DDR4_8GB_FULL}
        await ClockCycles(self.pix, 10)
        return {k: (await self.apb.read(a)).data for k, a in names.items()}

    def arrived(self, beats=BEATS) -> dict:
        """frame number -> path, for frames that arrived whole on one path.

        Also returns every irregularity: a frame split across paths, a frame
        missing beats, beats out of order.
        """
        where, problems = {}, []
        for p in PATHS:
            per_frame = {}
            for word in self.beats[p]:
                per_frame.setdefault((word >> 32) & 0xFFFF_FFFF, []).append(
                    word & 0xFFFF_FFFF)
            for n, got in per_frame.items():
                if n in where:
                    problems.append("frame %d arrived on both paths" % n)
                where[n] = p
                if got != list(beats):
                    problems.append("frame %d on the %s path arrived as beats %s, "
                                    "not %s" % (n, p, got, list(beats)))
        if self.both_fv:
            problems.append("both paths had frame-valid up together on %d clocks"
                            % self.both_fv)
        return where, problems


def _expect(where, frames, path, label, problems):
    wrong = [(n, where.get(n)) for n in frames if where.get(n) != path]
    if wrong:
        problems.append("%s: %d of %d frames not on the %s path, first %s"
                        % (label, len(wrong), len(frames), path, wrong[:3]))


@cocotb.test()
async def test_PF_MUX_04_selected_ddr_path_only(dut):
    """VC-PF-0027: each frame whole on one path, nothing on the other."""
    m = Mux(dut)
    await m.start()
    problems = []

    # Disabled out of reset: frames are not accepted.
    for _ in range(3):
        await m.frame()
    before = m.fv_clocks.copy()
    if any(before.values()):
        problems.append("frames before the first clear reached a path: %s" % before)

    # Selection 16GB, after a clear; then selection 8GB, which the mux makes
    # itself when the 16GB buffer is full.
    await m.clear()
    first = m.sent + 1
    for _ in range(FRAMES_16GB + 20):
        await m.frame()
    where, problems_ = m.arrived()
    problems += problems_
    _expect(where, range(first, first + FRAMES_16GB), "16gb", "selection 16GB",
            problems)
    _expect(where, range(first + FRAMES_16GB, m.sent + 1), "8gb",
            "selection 8GB", problems)
    dut._log.info("%d frames sent: %d whole on 16GB, %d whole on 8GB",
                  m.sent, list(where.values()).count("16gb"),
                  list(where.values()).count("8gb"))

    # How many leading clocks of a frame the mux forwards, with a beat on every
    # clock: once forwarding (it stays in its forwarding state between
    # frames), and as the first frame after a clear, which it has to see rise.
    # Logged: PF-MUX-04's Note.
    def leading(n):
        return [w & 0xFFFF_FFFF for p in PATHS for w in m.beats[p]
                if (w >> 32) & 0xFFFF_FFFF == n]
    n = await m.frame(beats=range(LENGTH))
    dut._log.info("a frame while forwarding, a beat on every clock, arrived "
                  "as beats %s", leading(n))
    await m.clear()
    n = await m.frame(beats=range(LENGTH))
    dut._log.info("the first frame after a clear, a beat on every clock, "
                  "arrived as beats %s", leading(n))
    assert not problems, "\n  ".join(["PF-MUX-04:"] + problems)


@cocotb.test()
async def test_PF_MUX_05_select_change_at_frame_boundary(dut):
    """VC-PF-0028: a mid-frame change routes the next frame, not this one."""
    m = Mux(dut)
    await m.start()
    problems = []
    long = 400

    async def clear_at(clock):
        # Concurrently: the frame must go on while the write crosses domains.
        if clock == 100:
            cocotb.start_soon(m.apb.write(MUX_CLEAR, 1))

    # 1. Forwarding to 16GB, a clear mid-frame: select unchanged, counts reset.
    await m.clear()
    a = await m.frame(length=long, beats=range(3, long - 1), during=clear_at)
    b = await m.frame()
    # 2. Forwarding to 8GB, a clear mid-frame: select changes to 16GB.
    for _ in range(FRAMES_16GB):
        await m.frame()
    s = await m.status()
    if s["select"] != 0:
        problems.append("the 16GB buffer did not fill; case 2 cannot run (%s)" % s)
    c = await m.frame(length=long, beats=range(3, long - 1), during=clear_at)
    d = await m.frame()
    # 3. Disabled, a clear mid-frame: enable changes.
    for _ in range(FRAMES_16GB + FRAMES_8GB):
        await m.frame()
    s = await m.status()
    if s["enable"] != 0:
        problems.append("the mux did not disable; case 3 cannot run (%s)" % s)
    e = await m.frame(length=long, beats=range(3, long - 1), during=clear_at)
    f = await m.frame()

    # Per-frame beat lists differ for the long frames; check them by path only,
    # and whole-ness separately.
    where = {}
    for p in PATHS:
        for word in m.beats[p]:
            where.setdefault((word >> 32) & 0xFFFF_FFFF, set()).add(p)
    cases = [("forwarding to 16GB, clear mid-frame", a, {"16gb"}, b, {"16gb"}),
             ("forwarding to 8GB, clear mid-frame", c, {"8gb"}, d, {"16gb"}),
             ("disabled, clear mid-frame", e, set(), f, {"16gb"})]
    for label, this, this_want, nxt, nxt_want in cases:
        got_this, got_next = where.get(this, set()), where.get(nxt, set())
        dut._log.info("%s: that frame went to %s, the next to %s", label,
                      sorted(got_this) or "neither", sorted(got_next))
        if got_this != this_want:
            problems.append("%s: that frame went to %s, expected %s -- the change "
                            "took effect mid-frame" % (label, sorted(got_this) or
                                                       "neither", sorted(this_want)
                                                       or "neither"))
        if got_next != nxt_want:
            problems.append("%s: the next frame went to %s, expected %s"
                            % (label, sorted(got_next) or "neither", sorted(nxt_want)))
    for n in (a, c):
        for p in PATHS:
            beats = [w & 0xFFFF_FFFF for w in m.beats[p] if (w >> 32) & 0xFFFF_FFFF == n]
            if beats and beats != list(range(3, long - 1)):
                problems.append("frame %d arrived on %s with %d of %d beats"
                                % (n, p, len(beats), long - 4))
    if m.both_fv:
        problems.append("both paths had frame-valid up together on %d clocks"
                        % m.both_fv)
    assert not problems, "\n  ".join(["PF-MUX-05:"] + problems)


@cocotb.test()
async def test_PF_MUX_08_switches_to_8gb_after_16gb_full(dut):
    """VC-PF-0029: frame 513 onward to 8GB, none to 16GB."""
    m = Mux(dut)
    await m.start()
    problems = []
    await m.clear()
    for _ in range(FRAMES_16GB - 1):
        await m.frame()
    s511 = await m.status()
    await m.frame()
    s512 = await m.status()
    for _ in range(40):
        await m.frame()
    where, problems_ = m.arrived()
    problems += problems_
    dut._log.info("after 511 frames %s; after 512 %s", s511, s512)
    if s511["16gb_full"] or s511["select"] != 1:
        problems.append("the 16GB buffer read full, or the 8GB selected, after "
                        "511 frames: %s" % s511)
    if not s512["16gb_full"] or s512["select"] != 0 or not s512["enable"]:
        problems.append("after 512 frames the 16GB buffer should read full with the "
                        "8GB selected and the mux enabled: %s" % s512)
    _expect(where, range(1, FRAMES_16GB + 1), "16gb", "frames 1-512", problems)
    _expect(where, range(FRAMES_16GB + 1, m.sent + 1), "8gb", "frames 513 on",
            problems)
    assert not problems, "\n  ".join(["PF-MUX-08:"] + problems)


@cocotb.test()
async def test_PF_MUX_09_stops_after_8gb_full(dut):
    """VC-PF-0030: after 256 frames to 8GB, nothing is accepted."""
    m = Mux(dut)
    await m.start()
    problems = []
    await m.clear()
    for _ in range(FRAMES_16GB + FRAMES_8GB - 1):
        await m.frame()
    s767 = await m.status()
    await m.frame()
    s768 = await m.status()
    fv_full = m.fv_clocks.copy()
    beats_full = {p: len(m.beats[p]) for p in PATHS}
    for _ in range(40):
        await m.frame()
    after = {p: (m.fv_clocks[p] - fv_full[p], len(m.beats[p]) - beats_full[p])
             for p in PATHS}
    where, problems_ = m.arrived()
    problems += problems_
    dut._log.info("after 767 frames %s; after 768 %s; 40 frames later, "
                  "(frame-valid clocks, beats) per path: %s", s767, s768, after)
    if s767["8gb_full"] or not s767["enable"]:
        problems.append("the 8GB buffer read full, or the mux disabled, after 767 "
                        "frames: %s" % s767)
    if not s768["8gb_full"] or s768["enable"]:
        problems.append("after 768 frames the 8GB buffer should read full and the "
                        "mux disabled: %s" % s768)
    if any(v for pair in after.values() for v in pair):
        problems.append("40 frames sent after both buffers were full reached a "
                        "path: %s" % after)
    _expect(where, range(FRAMES_16GB + 1, FRAMES_16GB + FRAMES_8GB + 1), "8gb",
            "frames 513-768", problems)
    assert not problems, "\n  ".join(["PF-MUX-09:"] + problems)


def _run(testcase: str) -> None:
    sim.run(hdl_toplevel=TOP,
            sources=sim.block("cam_mux_ip", "cam_mux.sv", "cam_mux_apb_reg.sv",
                              "cam_mux_top.sv"),
            test_module="test_pf_mux", testcase=[testcase],
            run_id="test_pf_mux.%s" % testcase, parameters=PARAMETERS)


def test_pf_mux_04():
    _run("test_PF_MUX_04_selected_ddr_path_only")


def test_pf_mux_05():
    _run("test_PF_MUX_05_select_change_at_frame_boundary")


def test_pf_mux_08():
    _run("test_PF_MUX_08_switches_to_8gb_after_16gb_full")


def test_pf_mux_09():
    _run("test_PF_MUX_09_stops_after_8gb_full")
