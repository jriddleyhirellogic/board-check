"""PCIe image export: PF-PCIE-07, PF-PCIE-08 and PF-PCIE-09.

Items: VC-PF-0048, VC-PF-0049, VC-PF-0050. Clause: VVP-PF-001.

  PF-PCIE-07  The PCIe/DDR read demux shall route reads to the selected DDR4
              memory.
  PF-PCIE-08  The PCIe translator shall reject write transactions.
  PF-PCIE-09  The PCIe translator shall align DDR read addresses to the
              configured prefetch chunk.

**The DUT is `eth_pcie_mux_hier`**, as the build generates it: `axi_read_demux`,
which takes the host's reads and its two control writes; a `pcie_translator`
per bank; and an `axi_read_mux` in front of each bank's DDR4 port, whose
ETH/PCIe select is `CoreGPIO_C7`'s output 0, written over APB. Its clocks are
the build's: the PCIe AXI side and the 8GB bank at 150 MHz (`pcie_hier`'s
`AXI_CLK` is the 8GB DDR4 user clock), the 16GB bank at 137.5 MHz
(`PF-F-28`), APB at 50 MHz.

Beyond the DUT are models: the PCIe hard block's AXI master (the host's reads
and writes, as `pcie_hier`'s `AXI_0_MASTER` presents them), and each bank's
DDR4 as an AXI slave. Every 64-bit word of a bank's memory holds its own byte
address with the bank in the top byte, so a word from the wrong bank, frame or
offset is identifiable. The FARSIGHT side of each mux, the arbiter port,
is idle. Nothing in this DUT is a vendor RAM model, but the monitors sample
mid-cycle all the same (see the README).

The host's controls, by the RTL (`axi_read_demux.sv`): a write whose address
ends 0x0 sets `ddr4_sel` (0 = 8GB, 1 = 16GB) from bit 0; one ending 0x8 sets
the frame index from bits 8:0. A read's DDR address is the frame index above
`araddr[24:0]`: frames are 32 MB, 256 of them in 8GB and 512 in 16GB.
"""

from __future__ import annotations

from pathlib import Path

import cocotb
from cocotb.triggers import ClockCycles, FallingEdge, Timer
from cocotb.utils import get_sim_time

from fsverif import sim
from fsverif.bfm.apb import Apb
from fsverif.clkrst import start_clock

REPO = Path(__file__).resolve().parents[2]
PCIE_NS, DDR16_NS, APB_NS = 6.666, 7.272, 20
# bank: (select value, DDR data width, frame index width, top-byte tag)
BANKS = {"8gb": (0, 256, 8, 0x08), "16gb": (1, 512, 9, 0x16)}
CHUNK = 256                                 # PCIE_MAX_BURST 32 x 64 bits
FRAME_BITS = 25
GPIO_OUT = 0xA0
REG_SEL, REG_INDEX = 0x00, 0x08
TIMEOUT_CYCLES = 2000


def word_at(bank: str, addr: int) -> int:
    """The 64-bit word a bank's memory holds at an 8-aligned byte address."""
    return (BANKS[bank][3] << 56) | (addr & 0x00FF_FFFF_FFFF_FFF8)


def _now_ns() -> float:
    return get_sim_time("ns")


def _bit(sig) -> int:
    v = sig.value
    return int(v) if v.is_resolvable else 0


class Memory:
    """One bank's DDR4, as an AXI slave: a beat a clock, reads only.

    Records every read address it accepts and every write-channel valid it
    sees. It has no write path: nothing may write, and if something tries,
    the attempt is what is recorded.
    """

    def __init__(self, dut, bank: str, clk):
        self.dut, self.bank, self.clk = dut, bank, clk
        self.width = BANKS[bank][1]
        self.p = "AXI4_M_DDR4_%s_m_" % bank.upper()
        self.reads = []              # (time, araddr, arlen)
        self.writes = []             # (time, channel, address or data)
        self.latency = 0             # clocks from a read's acceptance to its first beat

    def sig(self, name):
        return getattr(self.dut, self.p + name)

    def idle(self):
        for s in ("arready", "rvalid", "rlast", "awready", "wready", "bvalid"):
            self.sig(s).value = 0
        self.sig("rdata").value = 0
        self.sig("rresp").value = 0
        self.sig("rid").value = 0
        self.sig("bresp").value = 0
        self.sig("bid").value = 0

    async def run(self):
        beat_bytes = self.width // 8
        pending = []                 # [(addr, len)]
        beats = []                   # remaining beats of the current burst
        taken = False                # the beat presented last is taken at this edge
        while True:
            await FallingEdge(self.clk)
            if _bit(self.sig("awvalid")):
                self.writes.append((_now_ns(), "AW", int(self.sig("awaddr").value)))
            if _bit(self.sig("wvalid")):
                self.writes.append((_now_ns(), "W", int(self.sig("wdata").value)))
            # AR: arready is raised mid-cycle and the handshake completes at the
            # next rising edge; arvalid is held until then.
            if int(self.sig("arready").value):
                self.sig("arready").value = 0
            elif _bit(self.sig("arvalid")):
                addr, alen = int(self.sig("araddr").value), int(self.sig("arlen").value)
                self.reads.append((_now_ns(), addr, alen))
                pending.append((addr, alen, self.latency))
                self.sig("arready").value = 1
            # R: a beat presented mid-cycle is taken at the next rising edge if
            # rready is high then; rready is registered state, so its value now
            # is its value at that edge.
            if taken:
                beats.pop(0)
            if pending and pending[0][2] > 0:
                pending[0] = (pending[0][0], pending[0][1], pending[0][2] - 1)
            elif not beats and pending:
                addr, alen, _ = pending.pop(0)
                beats = [(addr + b * beat_bytes, b == alen) for b in range(alen + 1)]
            if beats:
                base, last = beats[0]
                value = 0
                for w in range(self.width // 64):
                    value |= word_at(self.bank, base + 8 * w) << (64 * w)
                self.sig("rdata").value = value
                self.sig("rlast").value = int(last)
                self.sig("rvalid").value = 1
            else:
                self.sig("rvalid").value = 0
                self.sig("rlast").value = 0
            taken = bool(beats) and bool(_bit(self.sig("rready")))


class Host:
    """The PCIe hard block's AXI master, as the host's TLPs present it."""

    def __init__(self, dut, clk):
        self.dut, self.clk = dut, clk

    def sig(self, name):
        return getattr(self.dut, "AXI4_S_PCIE_s_" + name)

    def idle(self):
        for s in ("arvalid", "awvalid", "wvalid", "wlast"):
            self.sig(s).value = 0
        for s in ("arid", "awid", "araddr", "awaddr", "arlen", "awlen", "wdata", "wstrb"):
            self.sig(s).value = 0
        for s in ("arsize", "awsize"):
            self.sig(s).value = 3                # 8 bytes
        for s in ("arburst", "awburst"):
            self.sig(s).value = 1                # INCR
        self.sig("rready").value = 1
        self.sig("bready").value = 1

    async def _handshake(self, valid, ready) -> bool:
        """Hold `valid` until the edge that takes it; False on timeout.

        Called mid-cycle. Every ready here is registered state, not a function
        of valid, so ready now is ready at the coming edge.
        """
        valid.value = 1
        for _ in range(TIMEOUT_CYCLES):
            taken = _bit(ready)
            await FallingEdge(self.clk)
            if taken:
                valid.value = 0
                return True
        valid.value = 0
        return False

    async def read(self, addr: int, arlen: int):
        """Read arlen+1 64-bit words; returns them, or None on a timeout."""
        await FallingEdge(self.clk)
        self.sig("araddr").value = addr
        self.sig("arlen").value = arlen
        words = []
        collector = cocotb.start_soon(self._collect(words))
        if not await self._handshake(self.sig("arvalid"), self.sig("arready")):
            collector.cancel()
            return None
        for _ in range(TIMEOUT_CYCLES):
            if collector.done():
                return words
            await FallingEdge(self.clk)
        collector.cancel()
        return None

    async def _collect(self, words):
        while True:
            await FallingEdge(self.clk)
            if _bit(self.sig("rvalid")):
                words.append(int(self.sig("rdata").value))
                if _bit(self.sig("rlast")):
                    return

    async def write(self, addr: int, data: list[int], strb: int = 0xFF) -> dict:
        """Write one burst. Reports which beats were taken and any response."""
        await FallingEdge(self.clk)
        self.sig("awaddr").value = addr
        self.sig("awlen").value = len(data) - 1
        result = {"aw": False, "beats": 0, "bresp": None, "b_after_beats": None}
        responses = []

        async def b_channel():
            while True:
                await FallingEdge(self.clk)
                if _bit(self.sig("bvalid")):
                    responses.append((int(self.sig("bresp").value), result["beats"]))
                    return
        b_task = cocotb.start_soon(b_channel())
        result["aw"] = await self._handshake(self.sig("awvalid"), self.sig("awready"))
        if result["aw"]:
            for n, word in enumerate(data):
                self.sig("wdata").value = word
                self.sig("wstrb").value = strb
                self.sig("wlast").value = int(n == len(data) - 1)
                if not await self._handshake(self.sig("wvalid"), self.sig("wready")):
                    break
                result["beats"] += 1
            self.sig("wlast").value = 0
        for _ in range(50):
            if responses:
                break
            await FallingEdge(self.clk)
        b_task.cancel()
        if responses:
            result["bresp"], result["b_after_beats"] = responses[0]
        return result


class Path_:
    """The DUT, its clocks and resets, and the models either side."""

    def __init__(self, dut):
        self.dut = dut
        self.pcie = dut.ddr4_8gb_clk
        self.host = Host(dut, self.pcie)
        self.mem = {"8gb": Memory(dut, "8gb", dut.ddr4_8gb_clk),
                    "16gb": Memory(dut, "16gb", dut.ddr4_16gb_clk)}
        self.apb = None

    async def start(self, select_pcie: bool = True) -> None:
        dut = self.dut
        start_clock(dut.ddr4_8gb_clk, PCIE_NS)
        start_clock(dut.ddr4_16gb_clk, DDR16_NS)
        start_clock(dut.pclk, APB_NS)
        self.apb = Apb(dut, dut.pclk, "s_apb_")
        self.host.idle()
        for m in self.mem.values():
            m.idle()
        for bank in ("8GB", "16GB"):
            p = "AXI4_S_DDR4_%s_ARBITER_s0_" % bank
            for s in ("arvalid", "awvalid", "wvalid", "wlast", "araddr", "awaddr",
                      "arlen", "awlen", "arsize", "awsize", "arburst", "awburst",
                      "arid", "awid", "wdata", "wstrb"):
                getattr(dut, p + s).value = 0
            getattr(dut, p + "rready").value = 1
            getattr(dut, p + "bready").value = 1
        resets = (dut.ddr4_8gb_resetn, dut.ddr4_16gb_resetn, dut.presetn)
        for r in resets:
            r.value = 1
        await ClockCycles(dut.pclk, 2)
        for r in resets:
            r.value = 0
        await ClockCycles(dut.pclk, 10)
        for r in resets:
            r.value = 1
        await ClockCycles(dut.pclk, 10)
        for m in self.mem.values():
            cocotb.start_soon(m.run())
        if select_pcie:
            await self.apb.write(GPIO_OUT, 1)
            await ClockCycles(dut.pclk, 10)

    async def control(self, bank: str, index: int) -> list[str]:
        """Select a bank and a frame as the host does; returns any problem."""
        problems = []
        for addr, value in ((REG_SEL, BANKS[bank][0]), (REG_INDEX, index)):
            r = await self.host.write(addr, [value])
            if r["bresp"] is None:
                problems.append("the host's write of %d to 0x%x did not complete: %s"
                                % (value, addr, r))
        await ClockCycles(self.pcie, 4)
        return problems

    def ar_counts(self):
        return {b: len(m.reads) for b, m in self.mem.items()}


def expected(bank: str, index: int, offset: int, arlen: int) -> list[int]:
    base = (index << FRAME_BITS) | (offset & ((1 << FRAME_BITS) - 1) & ~7)
    return [word_at(bank, base + 8 * k) for k in range(arlen + 1)]


def _first_diff(got, want) -> str:
    if got is None:
        return "no response"
    if len(got) != len(want):
        return "%d words, not %d" % (len(got), len(want))
    i = next(i for i, (a, b) in enumerate(zip(got, want)) if a != b)
    return "word %d is 0x%016x, not 0x%016x" % (i, got[i], want[i])


# -----------------------------------------------------------------------------

@cocotb.test()
async def test_PF_PCIE_07_selected_ddr_read_route(dut):
    """VC-PF-0048: reads go to the selected bank's port, and only to it."""
    p = Path_(dut)
    await p.start()
    problems = []
    cases = (("8gb", 3, 0x2000), ("16gb", 5, 0x2000), ("8gb", 200, 0x1F_0000),
             ("16gb", 400, 0x40), ("16gb", 511, 0x1FF_FF00), ("8gb", 255, 0))
    for bank, index, offset in cases:
        other = "16gb" if bank == "8gb" else "8gb"
        problems += await p.control(bank, index)
        before = p.ar_counts()
        got = await p.host.read(offset, 3)
        await ClockCycles(p.pcie, 200)          # let the prefetch finish
        after = p.ar_counts()
        want = expected(bank, index, offset, 3)
        new = [a for _, a, _ in p.mem[bank].reads[before[bank]:]]
        dut._log.info("%s, frame %d, offset 0x%x: %d DDR reads on %s (%s), %d on %s; "
                      "first word %s", bank, index, offset, after[bank] - before[bank],
                      bank, ", ".join("0x%x" % a for a in new),
                      after[other] - before[other], other,
                      "0x%016x" % got[0] if got else None)
        if got != want:
            problems.append("%s frame %d offset 0x%x: %s" % (bank, index, offset,
                                                             _first_diff(got, want)))
        if after[other] != before[other]:
            problems.append("%s selected: %d read requests reached the %s port"
                            % (bank, after[other] - before[other], other))
        if after[bank] == before[bank]:
            problems.append("%s selected: no read request reached its port" % bank)
    assert not problems, "\n  ".join(["PF-PCIE-07:"] + problems)


@cocotb.test()
async def test_PF_PCIE_08_write_transactions_rejected(dut):
    """VC-PF-0049: a host write reaches no DDR4 port and changes no read."""
    p = Path_(dut)
    await p.start()
    problems = []
    problems += await p.control("8gb", 7)
    want = expected("8gb", 7, 0x2000, 3)

    # Single-beat writes to image offsets, none of them a control address.
    for addr, data in ((0x2000, 0xFFFF_FFFF_FFFF_FFFF), (0x1234_5678, 0x5A5A),
                       (0x0100, 0x1), (0x0108, 0x1FF), (0x1FF_FFF0, 0x1)):
        r = await p.host.write(addr, [data])
        got = await p.host.read(0x2000, 3)
        await ClockCycles(p.pcie, 200)
        dut._log.info("single write of 0x%x to 0x%x: %s; then a read of frame 7 "
                      "offset 0x2000 returned %s", data, addr, r,
                      "0x%016x..." % got[0] if got else None)
        if r["bresp"] is None:
            problems.append("a single-beat write to 0x%x was never answered: %s"
                            % (addr, r))
        if got != want:
            problems.append(
                "after a write of 0x%x to 0x%x -- not a control address -- a read of "
                "8GB frame 7 offset 0x2000 returned 0x%016x..., which is %s"
                % (data, addr, got[0] if got else 0,
                   _where(got[0]) if got else "nothing"))
            problems += await p.control("8gb", 7)       # put it back

    # A burst: four beats, as a host write of 32 bytes arrives.
    r = await p.host.write(0x3000, [0x11, 0x22, 0x33, 0x44])
    dut._log.info("4-beat write to 0x3000: %s", r)
    if r["beats"] != 4 or r["bresp"] is None or r["b_after_beats"] != 4:
        problems.append("a 4-beat write to 0x3000 took %d of 4 beats, and was "
                        "answered %s" % (r["beats"],
                                         "never" if r["bresp"] is None else
                                         "after beat %d" % r["b_after_beats"]))

    for bank, m in p.mem.items():
        if m.writes:
            problems.append("%d write-channel valids reached the %s DDR4 port, first "
                            "%s at %.0f ns" % (len(m.writes), bank, m.writes[0][1],
                                               m.writes[0][0]))
    assert not problems, "\n  ".join(["PF-PCIE-08:"] + problems)


def _where(word: int) -> str:
    tag = word >> 56
    bank = {0x08: "8GB", 0x16: "16GB"}.get(tag, "tag 0x%02x" % tag)
    addr = word & 0x00FF_FFFF_FFFF_FFFF
    return "%s frame %d offset 0x%x" % (bank, addr >> FRAME_BITS,
                                       addr & ((1 << FRAME_BITS) - 1))


@cocotb.test()
async def test_PF_PCIE_09_prefetch_chunk_alignment(dut):
    """VC-PF-0050: DDR reads are 256-byte aligned chunks; the data is the offset's."""
    p = Path_(dut)
    await p.start()
    problems = []
    # Unaligned starts; lengths up to the 32-beat maximum; two that run past the
    # end of their chunk into the next; sequential reads that hit the prefetch.
    cases = ((0x1238, 0), (0x1238, 3), (0x10F0, 7), (0x2008, 31), (0x40A0, 15),
             (0x4100, 0), (0x4200, 31), (0x7FF8, 1))
    for bank, index in (("8gb", 17), ("16gb", 300)):
        width = BANKS[bank][1]
        problems += await p.control(bank, index)
        for offset, arlen in cases:
            before = len(p.mem[bank].reads)
            got = await p.host.read(offset, arlen)
            await ClockCycles(p.pcie, 200)
            reads = p.mem[bank].reads[before:]
            full = (index << FRAME_BITS) | offset
            dut._log.info("%s frame %d, read 0x%x+%d words: DDR reads %s", bank, index,
                          offset, arlen + 1,
                          ", ".join("0x%x len %d" % (a, n) for _, a, n in reads) or "none")
            want = expected(bank, index, offset, arlen)
            if got != want:
                problems.append("%s 0x%x x%d: %s" % (bank, offset, arlen + 1,
                                                     _first_diff(got, want)))
            for _, addr, alen in reads:
                if addr % CHUNK or alen != CHUNK * 8 // width - 1:
                    problems.append("%s 0x%x: a DDR read of 0x%x, %d beats, is not one "
                                    "aligned %d-byte chunk"
                                    % (bank, offset, addr, alen + 1, CHUNK))
            covering = {full & ~(CHUNK - 1), (full + 8 * arlen) & ~(CHUNK - 1)}
            fetched = {a for _, a, _ in p.mem[bank].reads}
            if not covering <= fetched:
                problems.append("%s 0x%x: chunks %s were needed and never read"
                                % (bank, offset, sorted(hex(c) for c in covering - fetched)))
    assert not problems, "\n  ".join(["PF-PCIE-09:"] + problems)


# -----------------------------------------------------------------------------

def test_pf_pcie():
    top = "eth_pcie_mux_hier"
    sources = (sim.block("eth_pcie_mux_ip", "axi_read_demux.sv", "axi_read_mux.sv",
                         "pcie_translator_fifo.sv", "pcie_translator.sv")
               + sim.vendor("CoreGPIO_C7", top))
    sim.run(hdl_toplevel=top, sources=sources, test_module="test_pf_pcie")
