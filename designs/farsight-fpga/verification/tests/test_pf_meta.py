"""Image metadata: PF-META-01, PF-META-02, PF-META-03 and PF-META-09.

Items: VC-PF-0072, VC-PF-0074, VC-PF-0075, VC-PF-0078. Clause: VVP-PF-001.

  PF-META-01  The image metadata block shall use the host-visible format
              defined in CM-01979.
  PF-META-02  The image metadata block shall include a reflected IEEE CRC32
              covering the metadata payload.
  PF-META-03  The image metadata block shall report camera trigger-low
              duration with microsecond resolution.
  PF-META-09  The image pipeline shall insert one metadata record ahead of
              camera image data.

The format is CM-01979 (revWIP) section 23.2, "Image metadata": twenty 32-bit
words, 80 bytes. The requirements cite section 17.4, which in revWIP is the
register map; the table is in 23.2.

**The DUT is `image_metadata_top`** with its real `COREFIFO_METADATA_CDC`: the
metadata register block, and the inserter that puts the block into the
camera stream as two 384-bit beats when a frame starts. It is the block
`cam_rx_hier` instantiates; the rest of `cam_rx_hier` includes the encrypted
SLVS-EC receiver, which cannot be compiled. **It runs under QuestaSim**: the
inserter's own flops read the FIFO's `Q`, which Verilator can sample a word
late (see the README).

Beyond the DUT are models, at the build's clocks (APB 50 MHz, pixel 79.2 MHz):

- **The RTC** as `pps` presents it: nanoseconds advancing 20 ns every APB
  clock, seconds on the rollover. It is live, as in the build, unless a test
  freezes it to isolate a cause. It is driven every clock from 2 us before
  each frame starts until its record is out, which covers the snapshot, and
  set from simulation time otherwise; driving it every clock through a
  4 ms exposure costs tens of minutes under QuestaSim and changes nothing.
- **The sensor's `cam_tout`**, low for the exposure, and the frame that
  follows: frame valid, then lines of 141 beats every 3.1185 us (70 frames/s
  of 4581 lines), each beat tagged with its frame, line and beat so a lost or
  overwritten beat is identifiable.
- **Firmware** writing its fields over APB with distinct values.

The stream is read at `cam_data_out`, the host-visible boundary: from there to
the host the block is moved, not reformatted.
"""

from __future__ import annotations

import struct
import zlib

import cocotb
from cocotb.triggers import ClockCycles, Event, FallingEdge, RisingEdge, Timer
from cocotb.utils import get_sim_time

from fsverif import sim
from fsverif.bfm.apb import Apb
from fsverif.clkrst import start_clock

APB_NS, PIXEL_NS = 20, 12.626
LINE_NS = 1e9 / (70 * 4581)            # 3118.5 ns
BEATS = 141                            # 6768 bytes of pixels / 48 bytes a beat
FLAG, SIZE = 0x4D455441, 0x50
# CM-01979 section 23.2: byte offset -> field
ICD = {0x00: "METADATA_START_FLAG", 0x04: "METADATA_SIZE_BYTES",
       0x08: "SENSOR_PXL_READOUT_FORMAT", 0x0C: "SENSOR_READ_DIR",
       0x10: "SENSOR_BIT_DEPTH", 0x14: "SENSOR_GAIN", 0x18: "SENSOR_BLO",
       0x1C: "SENSOR_EXPO_USEC", 0x20: "SENSOR_TRIG_MODE", 0x24: "SENSOR_TEMP_RAW",
       0x28: "BUFF_WRITE_INDEX", 0x2C: "FOCUS_REQ_DIST_M", 0x30: "FOCUS_COMP_DIST_M",
       0x34: "FOCUS_LVDT_POS_NM", 0x38: "TIMESTAMP_UNIX_EPOCH_SEC",
       0x3C: "TIMESTAMP_SUBSEC_NSEC", 0x40: "PF_FPGA_VERSION", 0x44: "RESERVED0",
       0x48: "RESERVED1", 0x4C: "METADATA-CRC32"}
# Fields firmware writes, with distinct values: offset -> value
FIRMWARE = {0x08: 0x2, 0x0C: 0x3, 0x10: 0xC, 0x14: 240, 0x18: 50, 0x24: 0x1D3,
            0x2C: 0x0001_86A0, 0x30: 0x0001_869F, 0x34: 0xFFFF_FF85, 0x40: 0x0200_0104}
RTC_START = (1_790_000_000, 999_000_000)       # a second rollover 1 ms in


def _now_ns() -> float:
    return get_sim_time("ns")


def _crc(words) -> int:
    """Reflected IEEE CRC32 (zlib's) over 32-bit words, little-endian bytes."""
    return zlib.crc32(struct.pack("<%dI" % len(words), *words))


class Meta:
    def __init__(self, dut, live_rtc: bool = True):
        self.dut, self.live_rtc = dut, live_rtc
        self.pclk, self.pix = dut.pclk, dut.pixel_clk
        self.lines = []            # [(t_ns, frame_valid, [beats])]
        self.frame = 0
        self.rtc_window = Event()

    async def start(self) -> None:
        dut = self.dut
        start_clock(self.pclk, APB_NS)
        start_clock(self.pix, PIXEL_NS)
        self.apb = Apb(dut, self.pclk, "")
        dut.cam_tout.value = 1
        dut.frame_valid_in.value = 0
        dut.line_valid_in.value = 0
        dut.cam_data_in.value = 0
        dut.trig_mode.value = 2
        dut.frame_capture_time.value = 0
        dut.frame_capture_amount.value = 0
        dut.cam_mux_select.value = 1
        dut.ddr4_8gb_frame_index.value = 0
        dut.ddr4_16gb_frame_index.value = 0
        dut.timestamp_sec.value, dut.timestamp_nsec.value = RTC_START
        for r in (dut.presetn, dut.pixel_rst_n):
            r.value = 1
        await ClockCycles(self.pclk, 2)
        for r in (dut.presetn, dut.pixel_rst_n):
            r.value = 0
        await ClockCycles(self.pclk, 10)
        for r in (dut.presetn, dut.pixel_rst_n):
            r.value = 1
        await ClockCycles(self.pclk, 10)
        if self.live_rtc:
            cocotb.start_soon(self._rtc())
        cocotb.start_soon(self._monitor())
        for offset, value in FIRMWARE.items():
            await self.apb.write(offset, value)

    def _rtc_now(self):
        ticks = int(_now_ns() // APB_NS)
        total = RTC_START[1] + ticks * APB_NS
        return RTC_START[0] + total // 1_000_000_000, total % 1_000_000_000

    async def _rtc(self):
        while True:
            await self.rtc_window.wait()
            while self.rtc_window.is_set():
                await FallingEdge(self.pclk)
                sec, nsec = self._rtc_now()
                self.dut.timestamp_sec.value = sec
                self.dut.timestamp_nsec.value = nsec

    async def _monitor(self):
        dut = self.dut
        while True:
            await RisingEdge(dut.line_valid_out)
            await FallingEdge(self.pix)
            current = (_now_ns(), int(dut.frame_valid_out.value), [])
            self.lines.append(current)
            while int(dut.line_valid_out.value):
                current[2].append(int(dut.cam_data_out.value))
                await FallingEdge(self.pix)

    async def frame_of(self, expo_us: float, lines: int = 3,
                       first_line_ns: float = LINE_NS) -> float:
        """An exposure, then a frame of `lines` lines; returns frame-valid's rise."""
        dut = self.dut
        self.frame += 1
        await FallingEdge(self.pclk)
        dut.cam_tout.value = 0
        await Timer(round(expo_us * 1000), unit="ns")
        dut.cam_tout.value = 1
        if self.live_rtc:
            self.rtc_window.set()
        await Timer(2, unit="us")
        await FallingEdge(self.pix)
        dut.frame_valid_in.value = 1
        fv = _now_ns()
        for n in range(lines):
            wait = round((fv + first_line_ns + n * LINE_NS - _now_ns()) / PIXEL_NS)
            if wait > 0:
                await Timer(wait * PIXEL_NS, unit="ns", round_mode="round")
            await FallingEdge(self.pix)
            dut.line_valid_in.value = 1
            for b in range(BEATS):
                dut.cam_data_in.value = (0xCA << 376) | (self.frame << 32) | (n << 16) | b
                await FallingEdge(self.pix)
            dut.line_valid_in.value = 0
            dut.cam_data_in.value = 0
            self.rtc_window.clear()
        await Timer(1, unit="us")
        await FallingEdge(self.pix)
        dut.frame_valid_in.value = 0
        await Timer(5, unit="us")
        return fv

    def records(self, after: float = 0.0):
        """Metadata records seen since `after`: [(time, [20 words])]."""
        out = []
        for t, _, beats in self.lines:
            if t < after or (beats[0] & 0xFFFF_FFFF) != FLAG:
                continue
            words = [(b >> (32 * i)) & 0xFFFF_FFFF for b in beats[:1] for i in range(12)]
            if len(beats) > 1:
                words += [(beats[1] >> (32 * i)) & 0xFFFF_FFFF for i in range(8)]
            out.append((t, words, beats))
        return out


def _field(words, offset):
    return words[offset // 4] if offset // 4 < len(words) else None


# -----------------------------------------------------------------------------

@cocotb.test()
async def test_PF_META_01_metadata_matches_icd_format(dut):
    """VC-PF-0072: every field of CM-01979 section 23.2 at its offset and width."""
    m = Meta(dut)
    await m.start()
    problems = []
    for mode, bank, index in ((0, 1, 300), (1, 0, 5), (2, 0, 255), (2, 1, 511)):
        dut.trig_mode.value = mode
        dut.cam_mux_select.value = bank
        (dut.ddr4_8gb_frame_index if bank == 0 else dut.ddr4_16gb_frame_index).value = index
        t = await m.frame_of(expo_us=12.0)
        recs = m.records(t)
        if not recs:
            problems.append("trigger mode %d: no metadata record" % mode)
            continue
        _, w, beats = recs[0]
        label = "%s frame, index input %d" % ("8GB" if bank == 0 else "16GB", index)
        dut._log.info("%s: record %s", label,
                      " ".join("%02x:%08x" % (4 * i, v) for i, v in enumerate(w)))
        if len(beats) != 2 or len(w) != 20:
            problems.append("%s: the record is %d beats, %d words, not 2 and 20"
                            % (label, len(beats), len(w)))
            continue
        if beats[1] >> 256:
            problems.append("%s: the second beat's top 128 bits are not zero" % label)
        expect = {0x00: FLAG, 0x04: SIZE, 0x20: mode, 0x44: 0, 0x48: 0, **FIRMWARE}
        for offset, value in expect.items():
            if w[offset // 4] != value:
                problems.append("%s: %s at 0x%02x is 0x%x, not 0x%x"
                                % (label, ICD[offset], offset, w[offset // 4], value))
        top = 0xFF if bank == 0 else 0x1FF
        if w[0x28 // 4] > top:
            problems.append(
                "%s: BUFF_WRITE_INDEX is 0x%x, outside the %s device's 0x0-0x%x "
                "(section 23.2: each device has its own index, and there is no "
                "single 0-767 index space)" % (label, w[0x28 // 4],
                                               "8GB" if bank == 0 else "16GB", top))
        if w[0x3C // 4] >= 1_000_000_000:
            problems.append("%s: TIMESTAMP_SUBSEC_NSEC is %d" % (label, w[0x3C // 4]))
    assert not problems, "\n  ".join(["PF-META-01:"] + problems)


async def _crc_run(dut, live: bool) -> tuple[list, list]:
    m = Meta(dut, live_rtc=live)
    await m.start()
    seen, problems = [], []
    for n, gain in enumerate((240, 241, 0x8000_0000, 240)):
        await m.apb.write(0x14, gain)
        t = await m.frame_of(expo_us=5.0 + n)
        recs = m.records(t)
        if not recs or len(recs[0][1]) != 20:
            problems.append("frame %d: no complete record" % (n + 1))
            continue
        w = recs[0][1]
        want = _crc(w[1:19])
        seen.append((gain, w[19], want, w[0x3C // 4]))
        dut._log.info("%s RTC, gain 0x%x: CRC field 0x%08x, CRC of words 1-18 0x%08x, "
                      "nsec %d", "live" if live else "frozen", gain, w[19], want,
                      w[0x3C // 4])
        if w[19] != want:
            problems.append(
                "gain 0x%x: the CRC field is 0x%08x; the reflected IEEE CRC32 of the "
                "payload it is sent with (words 1-18) is 0x%08x" % (gain, w[19], want))
    return seen, problems


@cocotb.test()
async def test_PF_META_02_reflected_crc32_payload(dut):
    """VC-PF-0074: the CRC field is the reflected CRC32 of the payload sent with it."""
    seen, problems = await _crc_run(dut, live=True)
    crcs = [c for _, c, _, _ in seen]
    if len(set(crcs[:3])) < 3:
        problems.append("changing the gain did not change the CRC: %s"
                        % [hex(c) for c in crcs])
    assert not problems, "\n  ".join(["PF-META-02 (live RTC, as built):"] + problems)


@cocotb.test()
async def test_characterise_meta_crc_frozen_rtc(dut):
    """Not an item: the same, with the RTC frozen, to separate the CRC from the snapshot."""
    seen, problems = await _crc_run(dut, live=False)
    assert not problems, "\n  ".join(["CRC with the RTC frozen:"] + problems)


@cocotb.test()
async def test_PF_META_03_trigger_low_duration_us_field(dut):
    """VC-PF-0075: SENSOR_EXPO_USEC reports the trigger-low time to the microsecond."""
    m = Meta(dut)
    await m.start()
    problems = []
    for us in (1.0, 10.4, 10.6, 99.7, 1000.0, 4321.3):
        t = await m.frame_of(expo_us=us, lines=1)
        recs = m.records(t)
        got = recs[0][1][0x1C // 4] if recs else None
        dut._log.info("cam_tout low %.1f us: SENSOR_EXPO_USEC %s", us, got)
        if got is None:
            problems.append("%.1f us: no record" % us)
        elif abs(got - us) > 0.5 + 2 * APB_NS / 1000:
            problems.append("%.1f us low: SENSOR_EXPO_USEC is %d" % (us, got))
    assert not problems, "\n  ".join(["PF-META-03:"] + problems)


@cocotb.test()
async def test_PF_META_09_metadata_before_image_data(dut):
    """VC-PF-0078: one record per frame, ahead of the first image line, none lost."""
    m = Meta(dut)
    await m.start()
    problems = []
    for n in range(3):
        t = await m.frame_of(expo_us=20.0, lines=4)
        lines = [(lt, beats) for lt, fv, beats in m.lines if lt >= t]
        recs = [x for x in lines if (x[1][0] & 0xFFFF_FFFF) == FLAG]
        image = [x for x in lines if (x[1][0] >> 376) == 0xCA]
        first = min((lt for lt, _ in image), default=None)
        dut._log.info("frame %d: %d records, first at %s ns after frame valid; %d image "
                      "lines, first at %s ns", m.frame, len(recs),
                      "%.0f" % (recs[0][0] - t) if recs else "-", len(image),
                      "%.0f" % (first - t) if first else "-")
        if len(recs) != 1:
            problems.append("frame %d: %d metadata records" % (m.frame, len(recs)))
        elif first is not None and recs[0][0] > first:
            problems.append("frame %d: the record came after image data" % m.frame)
        intact = [beats for _, beats in image
                  if beats == [(0xCA << 376) | (m.frame << 32) | (((beats[0] >> 16) & 0xFFFF) << 16) | b
                               for b in range(BEATS)]]
        if len(image) != 4 or len(intact) != 4:
            problems.append("frame %d: %d of 4 image lines arrived intact"
                            % (m.frame, len(intact)))
    assert not problems, "\n  ".join(["PF-META-09:"] + problems)


@cocotb.test()
async def test_characterise_meta_insertion_latency(dut):
    """Not an item: how soon after frame valid the first line may come."""
    m = Meta(dut)
    await m.start()
    for gap_ns in (1000, 500, 400, 300, 200, 100):
        t = await m.frame_of(expo_us=20.0, lines=1, first_line_ns=gap_ns)
        beats = [(lt, i, b) for lt, _, bs in m.lines if lt >= t for i, b in enumerate(bs)]
        flag_at = [(lt, i) for lt, i, b in beats if (b & 0xFFFF_FFFF) == FLAG]
        sent = {(0xCA << 376) | (m.frame << 32) | b for b in range(BEATS)}
        got = {b for _, _, b in beats if (b >> 376) == 0xCA}
        dut._log.info("first line %d ns after frame valid: record %s; %d of %d image "
                      "beats arrived", gap_ns,
                      ", ".join("at beat %d of a line starting %.0f ns after frame valid"
                                % (i, lt - t) for lt, i in flag_at) or "absent",
                      len(sent & got), BEATS)


# -----------------------------------------------------------------------------

def test_pf_meta():
    top = "image_metadata_top"
    sources = (sim.block("image_metadata_ip", "image_metadata_apb_reg.sv",
                         "image_metadata.sv", "image_metadata_top.sv")
               + sim.vendor("COREFIFO_METADATA_CDC")
               + [sim.polarfire_source()])
    sim.run(hdl_toplevel=top, sources=sources, test_module="test_pf_meta",
            simulator="questa")
