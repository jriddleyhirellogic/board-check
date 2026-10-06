"""DDR4 read path: PF-DMAR-08, PF-DMAR-16, PF-DMAR-18 and PF-DMAR-23.

Items: VC-PF-0042, VC-PF-0045, VC-PF-0046, VC-PF-0047. Clause: VVP-PF-001.

  PF-DMAR-08  The DDR4 read DMA shall flag a timeout when read request,
              active read or export completion waits exceed the configured
              timeout.
  PF-DMAR-16  The frame-transfer controller shall assert frame-read-done after
              the final requested line.
  PF-DMAR-18  The Ethernet image stream shall limit each packet payload to the
              configured standard or jumbo payload word count.
  PF-DMAR-23  The DDR4 read controller shall expose one 20-word metadata block
              for each metadata-mode read.

Every test runs once per DDR4 bank, each at the clocks the build gives it: the
bank's PF_DDR4 user clock (150 MHz for 8GB, 137.5 MHz for 16GB -- `PF-F-28`),
the 100 MHz `udp_clk` (`pll_sys_clk_50mhz` OUT1) and the 50 MHz APB clock.

**PF-DMAR-08 runs on `dma_read`**, the read DMA whose watchdog it is, at the
parameters its SmartDesign instance sets (`dma_read_ddr4_*_hier.tcl`, read
here, not restated). Its FIFO is not part of the watchdog and is not in the
DUT: the export wait ends on the FIFO's `EMPTY`, which the test holds. The
requirement states no tolerance, so the test applies the one `PF-DMAW-09`
states for the same 10 ms watchdog: a wait held to 9.5 ms must not flag, and
one held to 10.5 ms must have. The watchdog counts 1,500,000 cycles of the
DDR clock, so the 16GB bank flags at 10.909 ms and fails.

**PF-DMAR-16, -18 and -23 run on `dma_read_ddr4_<bank>_hier`**, the read path
as the build generates it (byte-identical): the read DMA with its real
COREFIFO, the line and packet controller, and both register blocks, driven
over APB as firmware drives them. The packetiser's timing constants
(`DATA_OUT_OFFSET_DELAY`, `FIFO_EMPTY_OFFSET_DELAY`) assume the real FIFO's
latency, which a model would not have. Beyond the DUT are two models: the
arbiter and DDR4 (every 32-bit word of memory holds its own address / 4, so
any word out of place is identifiable) and the UDP transmitter (accepting every
packet). Monitors sample mid-cycle: the vendor models drive data after the
clock (see the README).

Lines are the real line, 6784 bytes -- 106 beats on the 16GB bank's 512-bit
port, 212 on the 8GB bank's 256-bit port: 1696 payload words, so five standard
packets (4 x 363 + 244) or two jumbo (988 + 708).

**The read path runs under QuestaSim**, the simulator Microchip qualifies its
models against. The FIFO's RAM output register is `SLE_Prim`, a zero-delay flop
built from sequential UDPs, and Verilator lets our flops sample it after the
edge: under Verilator `dma_read_ctrl` captured every word one word late, the
payload and the metadata block both starting at word 1. QuestaSim captures word
0, as hardware does (see the README).

**A metadata read never completes** (`PF-F-29`). `frame_xfer_ctrl` waits in
`READ_LINE_TRIG` for a read-ack that `dma_read_ctrl` raises only in
`SEND_SOF_REQ`, a state the metadata path skips. The block is exposed, but
frame-read-done never rises, and the controller stays busy until its 10 ms
watchdog, ignoring the next read. PF-DMAR-16 and -23 fail on this.
"""

from __future__ import annotations

import re
from pathlib import Path

import cocotb
from cocotb.triggers import ClockCycles, FallingEdge, ReadOnly, RisingEdge, Timer, ValueChange
from cocotb.utils import get_sim_time

from fsverif import sim
from fsverif.bfm.apb import Apb
from fsverif.clkrst import advance, start_clock

REPO = Path(__file__).resolve().parents[2]
BOARD_BD = REPO / "bd" / "mpf500ts-fc1152m"
# bank: (real user clock MHz, simulated period ns, DDR data width)
BANKS = {"8gb": (150.0, 6.666, 256), "16gb": (137.5, 7.272, 512)}
UDP_NS, APB_NS = 10, 20

LINE_BYTES = 6784
LINE_WORDS = LINE_BYTES // 4                    # 1696
STD, JUMBO = 363, 988
TOKEN = 0x504B                                  # 'PK'
FRAME_WIDTH = 25

# dma_read_ctrl_apb_reg word addresses (x4 for bytes)
R_CLEAR, R_FRAME_INDEX, R_DONE_COUNT, R_READ_REQ = 0, 1, 2, 3
R_H_BEAT, R_H_BYTE, R_JUMBO, R_V_LINE = 4, 5, 6, 7
R_METADATA_SEL, R_DONE_INT, R_METADATA = 16, 17, 18
METADATA_WORDS = 20
# A metadata read moves 128 bytes and is done in about 2 us. Waiting far longer
# than that, and far less than the 10 ms watchdog, keeps a read that never
# completes (PF-F-29) from costing minutes of QuestaSim time.
META_WAIT_US = 50


def _now_ns() -> float:
    return get_sim_time("ns")


def _instance_params(bank: str, instance: str) -> dict:
    hier = (BOARD_BD / ("ddr4_%s_hier" % bank) / "components"
            / ("dma_read_ddr4_%s_hier.tcl" % bank)).read_text()
    block = re.search(r"-instance_name \{%s\} -params \{(.*?)\}" % re.escape(instance),
                      hier, re.S).group(1)
    return {k: int(v) for k, v in re.findall(r'"(\w+):(\d+)"', block)}


def _bit(sig) -> int:
    """A control bit, 0 while a four-state simulator still holds it at X."""
    v = sig.value
    return int(v) if v.is_resolvable else 0


def word_at(addr: int) -> int:
    """What the memory model holds at a 32-bit-aligned byte address."""
    return (addr >> 2) & 0xFFFF_FFFF


# -----------------------------------------------------------------------------
# PF-DMAR-08, on dma_read
# -----------------------------------------------------------------------------

@cocotb.test()
async def test_PF_DMAR_08_read_timeout_conditions(dut):
    """VC-PF-0042: each of the three waits, held past 10 ms, raises the flag."""
    width = len(dut.arb_data_in)
    bank = "16gb" if width == 512 else "8gb"
    mhz, period, _ = BANKS[bank]
    params = _instance_params(bank, "dma_read_ddr4_%s_inst" % bank)
    ddr, ctrl = dut.ddr_clk, dut.ctrl_clk
    start_clock(ddr, period)
    start_clock(ctrl, UDP_NS)
    for s in ("ctrl_info_valid", "ctrl_burst_count", "ctrl_read_addr", "dma_read_req",
              "dma_fifo_clear", "m_axis_dma_tready", "arb_read_ack", "arb_read_done",
              "arb_read_valid", "arb_data_in", "fifo_read_valid", "fifo_read_data",
              "clear"):
        getattr(dut, s).value = 0
    dut.fifo_empty.value = 1
    for r in (dut.ddr_rst_n, dut.ctrl_rst_n):
        r.value = 1
    await ClockCycles(ctrl, 2)
    for r in (dut.ddr_rst_n, dut.ctrl_rst_n):
        r.value = 0
    await ClockCycles(ctrl, 10)
    for r in (dut.ddr_rst_n, dut.ctrl_rst_n):
        r.value = 1
    await ClockCycles(ctrl, 10)
    dut.ctrl_burst_count.value = 4
    dut.ctrl_read_addr.value = 0x1000
    dut.ctrl_info_valid.value = 1
    await ClockCycles(ctrl, 10)

    watchdog = params["DDR4_CLOCK_FREQ_MHZ"] * params["TIMEOUT_USEC"]
    dut._log.info("%s bank: watchdog %d cycles (DDR4_CLOCK_FREQ_MHZ %d), clocked "
                  "at %.1f MHz", bank, watchdog, params["DDR4_CLOCK_FREQ_MHZ"], mhz)
    problems = []

    async def pulse(sig, clk=ddr):
        await FallingEdge(clk)
        sig.value = 1
        await FallingEdge(clk)
        sig.value = 0

    async def start_read():
        await FallingEdge(ctrl)
        dut.dma_read_req.value = 1
        await RisingEdge(dut.arb_read_req)
        return _now_ns()

    async def end_read():
        await FallingEdge(ctrl)
        dut.dma_read_req.value = 0
        dut.clear.value = 1                # CLEAR_STATE: the flag is sticky until then
        await ClockCycles(ctrl, 20)
        dut.clear.value = 0
        dut.fifo_empty.value = 1
        await ClockCycles(ctrl, 20)
        if int(dut.timeout_err.value):
            problems.append("the flag did not clear on `clear`")

    async def held(label, since):
        """Check the flag at 9.5 ms and 10.5 ms after `since`; time its rise."""
        rose = []

        async def watch():
            while not int(dut.timeout_err.value):
                await ValueChange(dut.timeout_err)
            rose.append(_now_ns())
        task = cocotb.start_soon(watch())
        await Timer(since + 9.5e6 - _now_ns(), unit="ns", round_mode="round")
        early = bool(rose)
        await Timer(since + 10.5e6 - _now_ns(), unit="ns", round_mode="round")
        late = bool(rose)
        await Timer(1e6, unit="ns")          # to 11.5 ms, for the measurement
        task.cancel()
        at_ms = (rose[0] - since) / 1e6 if rose else None
        cycles = round((rose[0] - since) / period) if rose else None
        real_ms = cycles / (mhz * 1e3) if rose else None
        dut._log.info("%s bank, %s: flag %s (%s clocks = %s ms at %.1f MHz)", bank,
                      label, "rose" if rose else "did not rise", cycles,
                      "%.3f" % real_ms if rose else "-", mhz)
        if early:
            problems.append("%s: flagged %.3f ms into the wait, before 9.5 ms"
                            % (label, at_ms))
        elif not late or real_ms is None or real_ms > 10.5:
            problems.append(
                "%s bank, %s: no flag by 10.5 ms%s. The watchdog counts %d cycles "
                "(DDR4_CLOCK_FREQ_MHZ %d) of a %.1f MHz clock. PF-F-28."
                % (bank, label, "" if real_ms is None else
                   " -- it rose at %.3f ms" % real_ms, watchdog,
                   params["DDR4_CLOCK_FREQ_MHZ"], mhz))

    # 1. The request is never acknowledged.
    since = await start_read()
    await held("read request (no ack)", since)
    await end_read()

    # 2. Acknowledged; the read never completes.
    await start_read()
    await pulse(dut.arb_read_ack)
    since = _now_ns() - period
    await held("active read (ack, no done)", since)
    await end_read()

    # 3. The read completes; the FIFO never drains. The counter runs from the
    #    acknowledge, not from the done, so the wait is timed from there.
    await start_read()
    await FallingEdge(ddr)
    dut.fifo_empty.value = 0
    await pulse(dut.arb_read_ack)
    since = _now_ns() - period
    for _ in range(4):
        await FallingEdge(ddr)
        dut.arb_read_valid.value = 1
    await FallingEdge(ddr)
    dut.arb_read_valid.value = 0
    await pulse(dut.arb_read_done)
    await held("export completion (FIFO never empties)", since)
    await end_read()
    assert not problems, "\n  ".join(["PF-DMAR-08:"] + problems)


# -----------------------------------------------------------------------------
# PF-DMAR-16, -18, -23, on dma_read_ddr4_<bank>_hier
# -----------------------------------------------------------------------------

class ReadPath:
    """The read SmartDesign, its clocks and APB, and the models either side."""

    def __init__(self, dut):
        self.dut = dut
        self.bank = "16gb" if hasattr(dut, "ddr_16gb_clk") else "8gb"
        self.mhz, self.period, self.width = BANKS[self.bank]
        self.beat_bytes = self.width // 8
        self.ddr = getattr(dut, "ddr_%s_clk" % self.bank)
        self.ddr_rst = getattr(dut, "ddr_%s_rst_n" % self.bank)
        self.ctrl = dut.udp_clk
        self.reg = None
        self.packets = []            # [(time of tlast, [words])]
        self.sizes = []              # packet byte sizes on the size channel
        self.sofs = 0
        self.inner = "dma_read_ctrl_ddr4_%s_inst" % self.bank

    async def start(self) -> None:
        dut = self.dut
        if self.reg is None:
            start_clock(self.ddr, self.period)
            start_clock(dut.udp_clk, UDP_NS)
            start_clock(dut.apb_clk, APB_NS)
            self.reg = Apb(dut, dut.apb_clk, "s_apb_dma_read_ctrl_reg_")
            self.dma_reg = Apb(dut, dut.apb_clk, "s_apb_dma_read_ddr4_%s_reg_" % self.bank)
            cocotb.start_soon(self._arbiter())
            cocotb.start_soon(self._udp())
        for s in ("arb_read_ack", "arb_read_done", "arb_read_valid", "arb_data_in",
                  "core_busy", "eof_ack", "pyl_acpt"):
            getattr(dut, s).value = 0
        dut.M_AXIS_UDP_PYL_m_axis_udp_pyl_tready.value = 1
        dut.M_AXIS_UDP_PYL_SIZE_m_axis_udp_pyl_size_tready.value = 1
        resets = (self.ddr_rst, dut.udp_rst_n, dut.apb_rst_n)
        for r in resets:
            r.value = 1
        await ClockCycles(dut.apb_clk, 2)
        for r in resets:
            r.value = 0
        await ClockCycles(dut.apb_clk, 10)
        for r in resets:
            r.value = 1
        await ClockCycles(dut.apb_clk, 20)

    async def _arbiter(self) -> None:
        """Ideal arbiter and DDR4: acknowledge, a beat every clock, done."""
        dut, clk = self.dut, self.ddr
        while True:
            await RisingEdge(dut.arb_read_req)
            await FallingEdge(clk)
            addr = int(dut.arb_read_start_addr.value)
            beats = int(dut.arb_read_burst_len.value) + 1
            dut.arb_read_ack.value = 1
            await FallingEdge(clk)
            dut.arb_read_ack.value = 0
            for b in range(beats):
                base = addr + b * self.beat_bytes
                value = 0
                for w in range(self.width // 32):
                    value |= word_at(base + 4 * w) << (32 * w)
                dut.arb_read_valid.value = 1
                dut.arb_data_in.value = value
                await FallingEdge(clk)
            dut.arb_read_valid.value = 0
            dut.arb_data_in.value = 0
            dut.arb_read_done.value = 1
            await FallingEdge(clk)
            dut.arb_read_done.value = 0

    async def _udp(self) -> None:
        """Accepts every packet: pyl_acpt after sof_req, eof_ack after tlast."""
        dut, clk = self.dut, self.ctrl
        valid = dut.M_AXIS_UDP_PYL_m_axis_udp_pyl_tvalid
        data = dut.M_AXIS_UDP_PYL_m_axis_udp_pyl_tdata
        last = dut.M_AXIS_UDP_PYL_m_axis_udp_pyl_tlast
        size_valid = dut.M_AXIS_UDP_PYL_SIZE_m_axis_udp_pyl_size_tvalid
        size = dut.M_AXIS_UDP_PYL_SIZE_m_axis_udp_pyl_size_tdata
        words, sof_seen = [], False
        while True:
            await FallingEdge(clk)
            dut.pyl_acpt.value = 0
            dut.eof_ack.value = 0
            # sof_req is high only in SEND_SOF_REQ; the acceptance goes to
            # WAIT_FOR_PYL_ACPT, the state it drops in.
            if _bit(dut.sof_req):
                if not sof_seen:
                    self.sofs += 1
                sof_seen = True
            elif sof_seen:
                sof_seen = False
                dut.pyl_acpt.value = 1
                # The size channel is level-valid while the core is idle, not
                # one transfer per packet: it is read as the packet is accepted.
                self.sizes.append(int(size.value) if _bit(size_valid) else None)
            if _bit(valid):
                words.append(int(data.value))
                if _bit(last):
                    self.packets.append((_now_ns(), words))
                    words = []
                    await FallingEdge(clk)
                    await FallingEdge(clk)
                    dut.eof_ack.value = 1

    async def configure(self, lines: int, jumbo: bool = False, frame: int = 3,
                        metadata: bool = False) -> None:
        w = self.reg.write
        await w(4 * R_FRAME_INDEX, frame)
        await w(4 * R_H_BEAT, LINE_BYTES // self.beat_bytes)
        await w(4 * R_H_BYTE, LINE_BYTES)
        await w(4 * R_V_LINE, lines)
        await w(4 * R_JUMBO, int(jumbo))
        await w(4 * R_METADATA_SEL, int(metadata))
        await ClockCycles(self.dut.apb_clk, 10)

    async def read_frame(self, timeout_us: float = 2000) -> float:
        """Request a frame; returns when frame-read-done rises (its time)."""
        dut = self.dut
        done = getattr(dut, "%s_frame_read_done" % self.inner)
        await self.reg.write(4 * R_READ_REQ, 1)
        rose = []

        async def watch():
            await RisingEdge(done)
            rose.append(_now_ns())
        task = cocotb.start_soon(watch())
        waited = 0.0
        while not rose and waited < timeout_us:
            await Timer(10, unit="us")
            waited += 10
        task.cancel()
        await self.reg.write(4 * R_READ_REQ, 0)
        await ClockCycles(dut.apb_clk, 20)
        return rose[0] if rose else None

    def frame_base(self, frame: int) -> int:
        return frame << FRAME_WIDTH


def _payload(packet_words):
    return packet_words[2:]


@cocotb.test()
async def test_PF_DMAR_16_done_after_final_line(dut):
    """VC-PF-0045: frame-read-done once, after the last requested line."""
    p = ReadPath(dut)
    await p.start()
    problems = []
    # The metadata read is last: it leaves the frame-transfer controller busy
    # until its 10 ms watchdog (PF-F-29), which would swallow any read after it.
    for lines, metadata in ((1, False), (2, False), (5, False), (1, True)):
        label = "metadata read" if metadata else "%d lines" % lines
        before_count = (await p.reg.read(4 * R_DONE_COUNT)).data
        first = len(p.packets)
        await p.configure(lines, metadata=metadata)
        done_at = await p.read_frame(timeout_us=META_WAIT_US if metadata else 2000)
        await ClockCycles(dut.apb_clk, 50)
        after_count = (await p.reg.read(4 * R_DONE_COUNT)).data
        packets = p.packets[first:]
        by_line = {}
        for t, words in packets:
            by_line.setdefault(words[1] >> 16, []).append(t)
        last_packet = max((t for t, _ in packets), default=None)
        dut._log.info("%s bank, %s: %d packets for lines %s; last tlast at "
                      "%s ns, frame-read-done at %s ns; done count %d -> %d",
                      p.bank, label, len(packets), sorted(by_line), last_packet,
                      done_at, before_count, after_count)
        if done_at is None:
            problems.append("%s: no frame-read-done%s" % (
                label, " within %d us" % META_WAIT_US if metadata else ""))
            continue
        if not metadata and sorted(by_line) != list(range(lines)):
            problems.append("%s: packets for lines %s" % (label, sorted(by_line)))
        late = [t for t, _ in packets if t > done_at]
        if late:
            problems.append("%s: frame-read-done at %d ns, before %d packets "
                            "that followed it" % (label, done_at, len(late)))
        if after_count - before_count != 1:
            problems.append("%s: FRAME_READ_DONE_COUNT went %d -> %d, not +1"
                            % (label, before_count, after_count))
        await p.reg.write(4 * R_DONE_INT, 1)
    assert not problems, "\n  ".join(["PF-DMAR-16 (%s):" % p.bank] + problems)


@cocotb.test()
async def test_PF_DMAR_18_payload_word_limits(dut):
    """VC-PF-0046: at most 363 payload words standard, 988 jumbo, and whole."""
    p = ReadPath(dut)
    await p.start()
    problems = []
    for jumbo, limit in ((False, STD), (True, JUMBO)):
        first, first_size = len(p.packets), len(p.sizes)
        await p.configure(1, jumbo=jumbo, frame=5)
        if await p.read_frame() is None:
            problems.append("%s: the frame read never completed"
                            % ("jumbo" if jumbo else "standard"))
            continue
        packets = [w for _, w in p.packets[first:]]
        sizes = p.sizes[first_size:]
        counts = [len(_payload(w)) for w in packets]
        label = "jumbo" if jumbo else "standard"
        expected = [limit] * (LINE_WORDS // limit) + (
            [LINE_WORDS % limit] if LINE_WORDS % limit else [])
        dut._log.info("%s bank, %s: %d packets of %s payload words; size channel %s",
                      p.bank, label, len(packets), counts, sizes)
        over = [c for c in counts if c > limit]
        if over:
            problems.append("%s: packets of %s payload words, over the %d limit"
                            % (label, over, limit))
        if counts != expected:
            problems.append("%s: packets of %s payload words; a %d-word line in "
                            "packets of at most %d is %s"
                            % (label, counts, LINE_WORDS, limit, expected))
        # And the line arrives whole, in order, with its headers.
        stream = [w for pkt in packets for w in _payload(pkt)]
        base = p.frame_base(5)
        want = [word_at(base + 4 * i) for i in range(LINE_WORDS)]
        if stream != want:
            bad = next(i for i, (a, b) in enumerate(zip(stream + [None] * LINE_WORDS, want))
                       if a != b)
            problems.append("%s: the payload differs from memory at word %d of %d "
                            "(got %s, expected 0x%08x)"
                            % (label, bad, LINE_WORDS,
                               "0x%08x" % stream[bad] if bad < len(stream) else "nothing",
                               want[bad]))
        for n, pkt in enumerate(packets):
            if (pkt[0] & 0xFFFF) != TOKEN or (pkt[1] & 0xFFFF) != n or (pkt[1] >> 16) != 0:
                problems.append("%s: packet %d header 0x%08x 0x%08x -- expected the 'PK' "
                                "token, line 0, packet %d" % (label, n, pkt[0], pkt[1], n))
        if sizes != [4 * c + 6 for c in counts]:
            problems.append("%s: the size channel gave %s for payloads of %s words"
                            % (label, sizes, counts))
    assert not problems, "\n  ".join(["PF-DMAR-18 (%s):" % p.bank] + problems)


@cocotb.test()
async def test_PF_DMAR_23_one_metadata_block(dut):
    """VC-PF-0047: one 20-word metadata block per metadata-mode read."""
    p = ReadPath(dut)
    await p.start()
    problems = []
    valid = getattr(dut, "%s_metadata_valid" % p.inner)
    pulses = []

    async def count():
        while True:
            await RisingEdge(valid)
            pulses.append(_now_ns())
    counter = cocotb.start_soon(count())
    for frame in (7, 9):
        before_pulses, before_sofs, before_packets = len(pulses), p.sofs, len(p.packets)
        await p.configure(1, frame=frame, metadata=True)
        done_at = await p.read_frame(timeout_us=META_WAIT_US)
        await ClockCycles(dut.apb_clk, 50)
        block = [(await p.reg.read(4 * (R_METADATA + i))).data
                 for i in range(METADATA_WORDS)]
        want = [word_at(p.frame_base(frame) + 4 * i) for i in range(METADATA_WORDS)]
        mine = pulses[before_pulses:]
        dut._log.info("%s bank, frame %d metadata read: %d metadata-valid pulses, "
                      "done at %s ns, %d UDP packets; registers %s...",
                      p.bank, frame, len(mine), done_at,
                      len(p.packets) - before_packets, [hex(v) for v in block[:3]])
        if done_at is None:
            problems.append("frame %d: the metadata read never completed" % frame)
        if len(mine) != 1:
            problems.append("frame %d: %d metadata blocks for one read" % (frame, len(mine)))
        elif done_at is not None and mine[0] > done_at:
            problems.append("frame %d: the block came after the read completed" % frame)
        if block != want:
            problems.append("frame %d: registers 18-37 hold %s..., not the 20 words "
                            "at the frame's base %s..." % (frame, [hex(v) for v in block[:3]],
                                                           [hex(v) for v in want[:3]]))
        if p.sofs != before_sofs or len(p.packets) != before_packets:
            problems.append("frame %d: a metadata read sent %d UDP packets"
                            % (frame, len(p.packets) - before_packets))
    counter.cancel()
    assert not problems, "\n  ".join(["PF-DMAR-23 (%s):" % p.bank] + problems)


# -----------------------------------------------------------------------------

def _run_dma_read(bank: str) -> None:
    params = _instance_params(bank, "dma_read_ddr4_%s_inst" % bank)
    sim.run(hdl_toplevel="dma_read", sources=sim.block("dma_read_ip", "dma_read.sv"),
            test_module="test_pf_dmar", testcase=["test_PF_DMAR_08_read_timeout_conditions"],
            run_id="test_pf_dmar.08.%s" % bank, parameters=params)


def _run_read_path(bank: str) -> None:
    top = "dma_read_ddr4_%s_hier" % bank
    sources = (sim.block("dma_read_ip", "dma_read.sv", "dma_read_apb_reg.sv",
                         "dma_read_apb_reg_ddr4_%s.sv" % bank, "dma_read_ddr4_%s.sv" % bank)
               + sim.block("dma_read_ctrl_ip", "frame_xfer_ctrl.sv", "dma_read_ctrl.sv",
                           "dma_read_ctrl_top.sv", "dma_read_ctrl_apb_reg.sv",
                           "dma_read_ctrl_apb_reg_ddr4_%s.sv" % bank,
                           "dma_read_ctrl_ddr4_%s.sv" % bank)
               + sim.vendor("COREFIFO_DMA_READ_DDR4_%s_C0" % bank.upper(), top)
               + [sim.polarfire_source()])
    sim.run(hdl_toplevel=top, sources=sources, test_module="test_pf_dmar",
            testcase=["test_PF_DMAR_16_done_after_final_line",
                      "test_PF_DMAR_18_payload_word_limits",
                      "test_PF_DMAR_23_one_metadata_block"],
            run_id="test_pf_dmar.path.%s" % bank, simulator="questa")


def test_pf_dmar_08_8gb():
    _run_dma_read("8gb")


def test_pf_dmar_08_16gb():
    _run_dma_read("16gb")


def test_pf_dmar_read_path_8gb():
    _run_read_path("8gb")


def test_pf_dmar_read_path_16gb():
    _run_read_path("16gb")
