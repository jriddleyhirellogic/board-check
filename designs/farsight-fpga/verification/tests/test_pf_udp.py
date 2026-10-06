"""UDP image transmit: PF-UDP-04, -05, -15, -16 and DRV-PF-08.

Items: VC-PF-0106, VC-PF-0114, VC-PF-0107, VC-PF-0113, VC-PF-0109.
Clause: VVP-PF-001.

  PF-UDP-04  The UDP mux shall disable all transmit sources for disabled or
             invalid selections.
  PF-UDP-05  The UDP mux shall route only the selected DDR4 image source to the
             Ethernet transmitter.
  PF-UDP-15  The UDP transmitter shall enforce a configurable inter-packet gap.
  PF-UDP-16  The UDP transmitter shall emit an error datagram on watchdog
             timeout.
  DRV-PF-08  The UDP transmitter shall not emit successive datagrams closer
             together than 20 us, at any configured inter-packet gap setting
             including the default.

**The DUT is `udp_hier`**, as the build generates it: the mux between the two
DDR4 read paths, the transmitter with its MAC back-pressure COREFIFO, its APB
registers, and the MAC transmit mux it shares with the Ethernet responder. It
runs at the build's clocks, `udp_clk_100mhz` and the 50 MHz APB clock, and
**under QuestaSim**, because the transmitter's own flops read the COREFIFO's
`Q` (see the README).

Beyond it are models:

- **Each bank's DDR4 read controller**, speaking the protocol
  `dma_read_ctrl` speaks: the payload size, `sof_req` until `pyl_acpt`, the
  payload on AXI-Stream with `tlast`, then `eof_ack`. As `dma_read_ctrl` does,
  the stream begins with the UDP checksum field (0x0000) and the `PK` token,
  then a packet index, then the data, and the size given is the stream's bytes
  less the 2 of the checksum field. Every data word carries its bank, packet
  and word number, so a word from the wrong source is identifiable.
- **CORETSE's native transmit FIFO interface**, from its user guide
  (DS50003245E section 3.1): a word moves on a rising edge with `MTXRDY` and
  `MTXACPT` high, first wire byte in bits 7:0.
- **Firmware**, configuring the headers and the selection over APB. Flight
  firmware never writes `FRAME_GAP`, so in flight the default applies.

Gaps are measured at the MAC interface, from the clock the last word of one
datagram is taken to the clock the first word of the next is.
"""

from __future__ import annotations

import struct

import cocotb
from cocotb.triggers import ClockCycles, FallingEdge, ReadOnly, RisingEdge, Timer
from cocotb.utils import get_sim_time

from fsverif import sim
from fsverif.bfm.apb import Apb
from fsverif.clkrst import start_clock

UDP_NS, APB_NS = 10, 20
R_DST_PORT, R_SRC_PORT, R_DST_IP, R_SRC_IP = 0x00, 0x04, 0x08, 0x0C
R_DST_MAC_MSB, R_DST_MAC_LSB, R_SRC_MAC_MSB, R_SRC_MAC_LSB = 0x10, 0x14, 0x18, 0x1C
R_WD_ERRORS, R_MUX_SEL, R_CLEAR, R_FRAME_GAP = 0x20, 0x24, 0x28, 0x2C
SEL = {"8gb": 1, "16gb": 2}
TOKEN = 0xEFBADBAD
WORDS = 40                                   # data words a datagram
FIRST = 0x0000_504B                          # UDP checksum 0, then 'PK'


def _now_us() -> float:
    return get_sim_time("ns") / 1000


def _bit(sig) -> int:
    v = sig.value
    return int(v) if v.is_resolvable else 0


class Source:
    """One bank's DDR4 read controller, as `dma_read_ctrl` drives the UDP side."""

    def __init__(self, dut, bank: str, clk):
        self.dut, self.bank, self.clk = dut, bank, clk
        b, B = bank, bank.upper()
        self.size = getattr(dut, "S_AXIS_IMG_FRAME_PYL_SIZE_DDR4_%s_ddr4_%s_img_frame_udp_pyl_size" % (B, b))
        self.size_valid = getattr(dut, "S_AXIS_IMG_FRAME_PYL_SIZE_DDR4_%s_ddr4_%s_img_frame_udp_pyl_size_valid" % (B, b))
        self.size_ready = getattr(dut, "S_AXIS_IMG_FRAME_PYL_SIZE_DDR4_%s_ddr4_%s_img_frame_udp_pyl_size_ready" % (B, b))
        p = "S_AXIS_IMG_FRAM_PYL_DDR4_%s_ddr4_%s_img_frame_s_udp_pyl_axis_" % (B, b)
        self.tdata, self.tkeep = getattr(dut, p + "tdata"), getattr(dut, p + "tkeep")
        self.tlast, self.tvalid = getattr(dut, p + "tlast"), getattr(dut, p + "tvalid")
        self.tready = getattr(dut, p + "tready")
        self.sof_req = getattr(dut, "ddr4_%s_img_frame_sof_req" % b)
        self.pyl_acpt = getattr(dut, "ddr4_%s_img_frame_pyl_acpt" % b)
        self.eof_ack = getattr(dut, "ddr4_%s_img_frame_eof_ack" % b)
        self.core_busy = getattr(dut, "ddr4_%s_img_frame_core_busy" % b)
        self.sent = 0                    # datagrams completed
        self.touched = []                # (time, signal) of every response seen
        self.stall_at = None             # (packet, word) to stop at
        self.stall_us = 0.0

    def idle(self):
        for s in (self.size, self.size_valid, self.tdata, self.tkeep, self.tlast,
                  self.tvalid, self.sof_req):
            s.value = 0

    def word(self, packet: int, n: int) -> int:
        return (SEL[self.bank] << 28) | ((packet & 0xFFF) << 16) | n

    def watch(self):
        """Record every handshake the transmitter side gives this source."""
        async def one(name, sig):
            while True:
                await RisingEdge(sig)
                self.touched.append((_now_us(), name))
        for name, sig in (("pyl_acpt", self.pyl_acpt), ("tready", self.tready),
                          ("eof_ack", self.eof_ack), ("size_ready", self.size_ready)):
            cocotb.start_soon(one(name, sig))

    async def run(self, packets: int):
        for packet in range(packets):
            await FallingEdge(self.clk)
            self.size.value = 4 * WORDS + 6
            self.size_valid.value = 1
            self.sof_req.value = 1
            while True:
                await ReadOnly()
                got = _bit(self.pyl_acpt)
                await FallingEdge(self.clk)
                if got:
                    break
            self.sof_req.value = 0
            stream = [FIRST, packet] + [self.word(packet, n) for n in range(WORDS)]
            for n, value in enumerate(stream):
                if self.stall_at == (packet, n):
                    self.tvalid.value = 0
                    await Timer(self.stall_us, unit="us")
                    await FallingEdge(self.clk)
                self.tdata.value = value
                self.tkeep.value = 0xF
                self.tlast.value = int(n == len(stream) - 1)
                self.tvalid.value = 1
                while True:
                    await ReadOnly()
                    got = _bit(self.tready)
                    await FallingEdge(self.clk)
                    if got:
                        break
            self.tvalid.value = 0
            self.tlast.value = 0
            while True:
                await ReadOnly()
                got = _bit(self.eof_ack)
                await FallingEdge(self.clk)
                if got:
                    break
            self.sent += 1


class Udp:
    def __init__(self, dut):
        self.dut = dut
        self.clk = dut.udp_clk_100mhz
        self.src = {b: Source(dut, b, self.clk) for b in SEL}
        self.frames = []                 # [(t_first_us, t_last_us, bytes)]

    async def start(self, gap: int | None = None, clocks: bool = True) -> None:
        """Reset and configure. `clocks` is False for a second start in one test."""
        dut = self.dut
        if clocks:
            start_clock(self.clk, UDP_NS)
            start_clock(dut.pclk, APB_NS)
        self.apb = Apb(dut, dut.pclk, "udp_tx_reg_apb_")
        for s in self.src.values():
            s.idle()
        for s in ("MRXRDY", "MRXSOF", "MRXEOF", "MRXDAT", "MRXBYTEVALID"):
            getattr(dut, s).value = 0
        dut.MTXACPT.value = 1
        for r in (dut.udp_rst_n, dut.presetn):
            r.value = 1
        await ClockCycles(dut.pclk, 2)
        for r in (dut.udp_rst_n, dut.presetn):
            r.value = 0
        await ClockCycles(dut.pclk, 10)
        for r in (dut.udp_rst_n, dut.presetn):
            r.value = 1
        await ClockCycles(dut.pclk, 10)
        w = self.apb.write
        await w(R_DST_PORT, 5005)
        await w(R_SRC_PORT, 5004)
        await w(R_DST_IP, 0xC0A80701)
        await w(R_SRC_IP, 0xC0A8070A)
        await w(R_DST_MAC_MSB, 0x3C60)
        await w(R_DST_MAC_LSB, 0x60B1C001)
        await w(R_SRC_MAC_MSB, 0x02C0)
        await w(R_SRC_MAC_LSB, 0xFFEE0042)
        if gap is not None:
            await w(R_FRAME_GAP, gap)
        await ClockCycles(dut.pclk, 20)
        cocotb.start_soon(self._mac())
        for s in self.src.values():
            s.watch()

    async def select(self, sel: int) -> None:
        await self.apb.write(R_MUX_SEL, sel)
        await ClockCycles(self.dut.pclk, 10)

    async def _mac(self):
        dut, frame, first = self.dut, b"", None
        while True:
            await FallingEdge(self.clk)
            await ReadOnly()
            if not _bit(dut.MTXRDY):
                await RisingEdge(dut.MTXRDY)
                continue
            if _bit(dut.MTXACPT):
                word = int(dut.MTXDAT.value).to_bytes(4, "little")
                if _bit(dut.MTXSOF):
                    frame, first = b"", _now_us()
                if _bit(dut.MTXEOF):
                    bv = int(dut.MTXBYTEVALID.value)
                    frame += word[:4 - bv if bv else 4]
                    self.frames.append((first, _now_us(), frame))
                    frame, first = b"", None
                else:
                    frame += word

    def payload_banks(self, frame: bytes) -> set:
        """The bank tags of a datagram's data words (after 'PK' and the index)."""
        body = frame[48:]
        tags = set()
        for i in range(0, len(body) - 3, 4):
            w = int.from_bytes(body[i:i + 4], "big")
            tags.add({1: "8gb", 2: "16gb"}.get(w >> 28, "neither"))
        return tags

    def gaps(self, after_us: float = 0.0):
        times = [(a, b) for a, b, _ in self.frames if a >= after_us]
        return [nxt[0] - cur[1] for cur, nxt in zip(times, times[1:])]


# -----------------------------------------------------------------------------

@cocotb.test()
async def test_PF_UDP_04_disabled_selection_idles_all_sources(dut):
    """VC-PF-0106: selections 0 and 3 give no source a handshake and send nothing."""
    u = Udp(dut)
    await u.start()
    problems = []
    for s in u.src.values():
        cocotb.start_soon(s.run(3))
    for sel in (0, 3):
        await u.select(sel)
        t0, n0 = _now_us(), len(u.frames)
        await Timer(100, unit="us")
        touched = {b: [x for x in s.touched if x[0] >= t0] for b, s in u.src.items()}
        dut._log.info("selection %d: %d frames to the MAC; handshakes %s", sel,
                      len(u.frames) - n0, {b: len(v) for b, v in touched.items()})
        if len(u.frames) != n0:
            problems.append("selection %d: %d frames reached the MAC"
                            % (sel, len(u.frames) - n0))
        for b, v in touched.items():
            if v:
                problems.append("selection %d: the %s source got %s"
                                % (sel, b, sorted({name for _, name in v})))
    await u.select(1)
    await Timer(100, unit="us")
    if not u.src["8gb"].sent:
        problems.append("selection 1 afterwards: the 8GB source sent nothing")
    assert not problems, "\n  ".join(["PF-UDP-04:"] + problems)


@cocotb.test()
async def test_PF_UDP_05_route_selected_ddr_source_only(dut):
    """VC-PF-0114: only the selected bank's datagrams reach the MAC."""
    u = Udp(dut)
    await u.start()
    problems = []
    for bank in ("8gb", "16gb"):
        other = "16gb" if bank == "8gb" else "8gb"
        s = u.src[bank]
        before_sent, n0 = s.sent, len(u.frames)
        t0 = _now_us()
        if bank == "8gb":
            cocotb.start_soon(s.run(3))
            cocotb.start_soon(u.src[other].run(3))        # pending throughout
        await u.select(SEL[bank])
        await Timer(150, unit="us")
        frames = u.frames[n0:]
        if frames:
            dut._log.info("%s: first datagram %s", bank, frames[0][2].hex())
        banks = [u.payload_banks(f) for _, _, f in frames]
        leaked = [x for x in u.src[other].touched if x[0] >= t0]
        dut._log.info("%s selected: %d datagrams, payload banks %s; %s source got %d "
                      "handshakes", bank, len(frames), banks, other, len(leaked))
        if s.sent - before_sent != 3 or len(frames) != 3:
            problems.append("%s selected: %d of 3 datagrams sent, %d frames"
                            % (bank, s.sent - before_sent, len(frames)))
        if any(b != {bank} for b in banks):
            problems.append("%s selected: datagram payloads from %s" % (bank, banks))
        if leaked:
            problems.append("%s selected: the %s source got %s"
                            % (bank, other, sorted({n for _, n in leaked})))
        await u.select(0)
    assert not problems, "\n  ".join(["PF-UDP-05:"] + problems)


async def _gaps_at(dut, setting: int, first: bool, packets: int = 4):
    u = Udp(dut)
    await u.start(gap=setting, clocks=first)
    await u.select(1)
    await u.src["8gb"].run(packets)
    await Timer(5, unit="us")
    return u.gaps(), u


@cocotb.test()
async def test_PF_UDP_15_configurable_inter_packet_gap(dut):
    """VC-PF-0107: the gap follows the register, and the default applies at zero."""
    problems, measured = [], {}
    for setting in (0, 500, 3000):
        gaps, _ = await _gaps_at(dut, setting, first=setting == 0)
        measured[setting] = gaps
        dut._log.info("FRAME_GAP %d: gaps %s us", setting, ", ".join("%.3f" % g for g in gaps))
    for setting, cycles in ((0, 1000), (500, 500), (3000, 3000)):
        want = cycles * UDP_NS / 1000
        gaps = measured[setting]
        if not gaps or min(gaps) < want or max(gaps) > want + 1.0:
            problems.append("FRAME_GAP %d: gaps %s us, not %.1f us (+1 us)"
                            % (setting, ["%.3f" % g for g in gaps], want))
    assert not problems, "\n  ".join(["PF-UDP-15:"] + problems)


@cocotb.test()
async def test_DRV_PF_08_gap_at_least_20us(dut):
    """VC-PF-0109: never under 20 us between datagrams, default included."""
    problems = []
    for setting in (0, 2000, 2500, 5000):
        gaps, _ = await _gaps_at(dut, setting, first=setting == 0)
        dut._log.info("FRAME_GAP %d: shortest gap %.3f us", setting, min(gaps))
        if min(gaps) < 20.0:
            problems.append("FRAME_GAP %d%s: datagrams %.3f us apart"
                            % (setting, " (the default, as flown)" if setting == 0 else "",
                               min(gaps)))
    assert not problems, "\n  ".join(["DRV-PF-08:"] + problems)


@cocotb.test()
async def test_PF_UDP_16_error_datagram_on_watchdog_timeout(dut):
    """VC-PF-0113: a stall past the watchdog ends with the error word on the wire."""
    u = Udp(dut)
    await u.start()
    await u.select(1)
    s = u.src["8gb"]
    s.stall_at, s.stall_us = (1, 12), 50.0
    cocotb.start_soon(s.run(3))
    # The watchdog is 10 s (MAX_TIMEOUT_USEC 10,000,000 at 100 MHz). Rather than
    # simulate a billion clocks of stall, the counter is set 20 us from its
    # limit once the stall has begun; what follows is the design's own.
    wd = dut.udp_tx_top_inst.udp_tx_inst.wd_wait_timeout
    while not (s.sent == 1 and not _bit(getattr(dut, "S_AXIS_IMG_FRAM_PYL_DDR4_8GB_ddr4_8gb_img_frame_s_udp_pyl_axis_tvalid"))):
        await ClockCycles(u.clk, 1)
    await Timer(5, unit="us")
    stall_seen = _now_us()
    dut._log.info("stalled at %.3f us with the watchdog at %d of %d", stall_seen,
                  int(wd.value), 10_000_000 * 100)
    wd.value = 2000
    await Timer(100, unit="us")
    errors = (await u.apb.read(R_WD_ERRORS)).data
    problems = []
    for n, (t0, t1, f) in enumerate(u.frames):
        ip_len = struct.unpack("!H", f[16:18])[0] if len(f) >= 18 else None
        dut._log.info("frame %d at %.3f us: %d bytes, IP total length %s, last word %s",
                      n, t0, len(f), ip_len, f[-4:].hex())
    gaps = u.gaps()
    dut._log.info("watchdog error count %d; gaps %s us", errors,
                  ", ".join("%.3f" % g for g in gaps))
    ends = [f for _, _, f in u.frames if TOKEN.to_bytes(4, "big") in f]
    if len(ends) != 1:
        problems.append("%d frames carried 0x%08X" % (len(ends), TOKEN))
    for f in ends:
        ip_len = struct.unpack("!H", f[16:18])[0]
        udp_len = struct.unpack("!H", f[38:40])[0]
        if ip_len != len(f) - 14 or udp_len != ip_len - 20:
            problems.append(
                "the frame carrying 0x%08X is %d bytes but its IP total length is %d "
                "and its UDP length %d: a receiver's IP layer drops it as truncated, "
                "so no UDP socket sees it" % (TOKEN, len(f), ip_len, udp_len))
    if errors != 1:
        problems.append("the watchdog error count reads %d" % errors)
    assert not problems, "\n  ".join(["PF-UDP-16:"] + problems)


# -----------------------------------------------------------------------------

def test_pf_udp():
    top = "udp_hier"
    sources = (sim.block("udp_ip", "udp_mux.sv", "udp_tx_apb_reg.sv", "udp_tx.sv",
                         "mtx_mux.sv", "udp_tx_top.sv")
               + sim.block("responder_ip", "rsp_fifo.sv", "width_up_conv.sv",
                           "width_down_conv.sv", "responder.sv", "rsp_top.sv")
               + sim.vendor("COREFIFO_MAC_BACKPRES", top)
               + [sim.polarfire_source()])
    sim.run(hdl_toplevel=top, sources=sources, test_module="test_pf_udp",
            simulator="questa")
