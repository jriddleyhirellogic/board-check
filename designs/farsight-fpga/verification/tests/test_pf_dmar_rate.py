"""DDR4 read bandwidth to the PCIe egress, at the controller boundary: PF-DMAR-24.

Item: VC-PF-0044. Clause: VVP-PF-001.

  PF-DMAR-24  Each DDR4 bank shall sustain 8.0 Gbit/s sustained read bandwidth
              to the active egress interface without underrun.

The highest-rate egress is PCIe, Gen2 x2, 8.0 Gbit/s of payload (the
requirement's evidence). Its read path is `eth_pcie_mux_hier`: the host's
reads arrive from the PCIe block's AXI master, go through `axi_read_demux` to
the selected bank's `pcie_translator`, and leave through `axi_read_mux` to the
bank's DDR4 port. The DUT is that SmartDesign as the build generates it, at
the build's clocks (`tests/test_pf_pcie.py` describes them and the models).

**This is a boundary model, scoped as `PF-DMAW-10`'s is.** `PF_DDR4` is
encrypted, so the DDR4 controller and memory are an ideal AXI slave: it
accepts a read the clock after it is presented and returns a beat every clock.
The test therefore shows whether the read path can carry 8.0 Gbit/s, not
whether the controller and DRAM can feed it, nor what concurrent capture
traffic does to that; those are the analysis item's and hardware's.

**The host is the fastest legal one.** It reads a frame sequentially in
32-beat (256-byte) bursts, the most `pcie_translator` takes
(`PCIE_MAX_BURST`), keeps `rready` high, and presents each next read while the
previous one's last beat is still on the bus. Sustained bandwidth is the bytes
returned over the time from the first read's acceptance to the last beat,
across 64 KB of one frame on each bank.
"""

from __future__ import annotations

import cocotb
from cocotb.triggers import ClockCycles, FallingEdge, ReadOnly
from cocotb.utils import get_sim_time

from test_pf_pcie import PCIE_NS, Path_, _bit, expected

from fsverif import sim

REQUIRED_GBPS = 8.0
BURST_WORDS = 32
SPAN = 64 * 1024                       # bytes read on each bank


async def stream(p: Path_, offset: int, length: int) -> tuple[list, list, list]:
    """Read `length` bytes from `offset` as fast as the AXI handshakes allow.

    Returns the words read, the time of every beat, and of every read's acceptance.
    """
    h, clk = p.host, p.pcie
    bursts = [offset + n * BURST_WORDS * 8 for n in range(length // (BURST_WORDS * 8))]
    words, beats, issued = [], [], 0
    await FallingEdge(clk)
    h.sig("arlen").value = BURST_WORDS - 1
    h.sig("araddr").value = bursts[0]
    h.sig("arvalid").value = 1
    accepted = []
    while len(words) < len(bursts) * BURST_WORDS:
        await ReadOnly()
        ar_taken = _bit(h.sig("arvalid")) and _bit(h.sig("arready"))
        r_taken = _bit(h.sig("rvalid"))
        rlast = _bit(h.sig("rlast"))
        data = int(h.sig("rdata").value) if r_taken else None
        await FallingEdge(clk)
        now = get_sim_time("ns")
        if ar_taken:
            accepted.append(now)
            issued += 1
            h.sig("arvalid").value = 0
        if r_taken:
            words.append(data)
            beats.append(now)
            # The next read goes up with the last beat of this one.
            if rlast and issued < len(bursts):
                h.sig("araddr").value = bursts[issued]
                h.sig("arvalid").value = 1
    return words, beats, accepted


@cocotb.test()
async def test_PF_DMAR_24_8g_read_without_underrun(dut):
    """VC-PF-0044: 8.0 Gbit/s sustained from each bank to the PCIe egress."""
    p = Path_(dut)
    await p.start()
    problems = []
    for bank, index in (("8gb", 40), ("16gb", 300)):
        problems += await p.control(bank, index)
        await ClockCycles(p.pcie, 20)
        offset = 0x10_0000
        words, beats, accepted = await stream(p, offset, SPAN)
        span_ns = beats[-1] - accepted[0] + PCIE_NS
        gbps = SPAN * 8 / span_ns
        want = expected(bank, index, offset, SPAN // 8 - 1)
        gaps = [b - a for a, b in zip(beats, beats[1:])]
        per_burst = [beats[(n + 1) * BURST_WORDS - 1] - beats[n * BURST_WORDS] + PCIE_NS
                     for n in range(len(beats) // BURST_WORDS)]
        first = [beats[n * BURST_WORDS] - accepted[n] for n in range(len(accepted))]
        dut._log.info(
            "%s bank: %d bytes in %.0f ns, %.2f Gbit/s; a burst's 32 beats take %.1f ns; "
            "acceptance to first beat %.1f-%.1f ns; between bursts the bus idles up to "
            "%.1f ns; %d DDR reads", bank, SPAN, span_ns, gbps,
            max(per_burst), min(first), max(first), max(gaps) - PCIE_NS,
            len(p.mem[bank].reads))
        if words != want:
            i = next(i for i, (a, b) in enumerate(zip(words, want)) if a != b)
            problems.append("%s: word %d is 0x%016x, not 0x%016x" % (bank, i, words[i], want[i]))
        if gbps < REQUIRED_GBPS:
            problems.append(
                "%s: %.2f Gbit/s sustained, under %.1f, with an ideal DDR4 and the fastest "
                "host. Each 256-byte read is answered %.0f-%.0f ns after it is accepted, "
                "and only one is outstanding at a time"
                % (bank, gbps, REQUIRED_GBPS, min(first), max(first)))
    assert not problems, "\n  ".join(["PF-DMAR-24 (read path, ideal DDR4):"] + problems)


@cocotb.test()
async def test_characterise_dmar_rate_ddr_latency(dut):
    """Not an item: the same stream, with DDR4 read latency added."""
    p = Path_(dut)
    await p.start()
    for clocks in (0, 10, 20, 40):
        for m in p.mem.values():
            m.latency = clocks
        await p.control("8gb", 41)
        await ClockCycles(p.pcie, 20)
        words, beats, accepted = await stream(p, 0x20_0000 + clocks * 0x1_0000, 16 * 1024)
        span_ns = beats[-1] - accepted[0] + PCIE_NS
        dut._log.info("8gb bank, %d clocks (%.0f ns) of DDR4 read latency: %.2f Gbit/s",
                      clocks, clocks * PCIE_NS, 16 * 1024 * 8 / span_ns)


# -----------------------------------------------------------------------------

def test_pf_dmar_rate():
    top = "eth_pcie_mux_hier"
    sources = (sim.block("eth_pcie_mux_ip", "axi_read_demux.sv", "axi_read_mux.sv",
                         "pcie_translator_fifo.sv", "pcie_translator.sv")
               + sim.vendor("CoreGPIO_C7", top))
    sim.run(hdl_toplevel=top, sources=sources, test_module="test_pf_dmar_rate")
