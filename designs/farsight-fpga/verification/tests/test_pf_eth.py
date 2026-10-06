"""Ethernet responder: PF-ETH-02, -04, -05, -06 and -07.

Items: VC-PF-0094, VC-PF-0096, VC-PF-0097, VC-PF-0098, VC-PF-0100.
Clause: VVP-PF-001.

  PF-ETH-02  The Ethernet responder shall accept IPv4 frames addressed to the
             local MAC address.
  PF-ETH-04  The Ethernet responder shall drop ARP packets that are not
             requests for the local IPv4 address.
  PF-ETH-05  The Ethernet responder shall drop IPv4 packets that are not local
             ICMP echo requests.
  PF-ETH-06  The Ethernet responder shall generate ARP replies for accepted ARP
             requests.
  PF-ETH-07  The Ethernet responder shall generate ICMP echo replies for
             accepted echo requests.

**The DUT is `rsp_top`** at the parameters `udp_hier` gives it, clocked as the
build clocks it: `udp_clk_100mhz`, 100 MHz.

**Beyond it is a model of CORETSE's native receive and transmit FIFO
interfaces**, from the core's user guide (DS50003245E, sections 3.1-3.2 and
the signal table): a word moves on a rising edge with both its ready and
accept high; the first byte on the wire is bits 7:0; `MRXBYTEVALID` on the
last word is 0 for four valid bytes and n for 4 - n. **Every received frame
carries its FCS**: flight firmware writes MAC Configuration #2 as 0x7217
(`farsight-avionics-sw/Camera/src/eth.c`, `tse_init`), with RX CRC DISABLE
(bit 6) clear, which the user guide defines as retaining the CRC bytes at the
end of each frame. Short frames are padded to 60 bytes, as on the wire.

Frames are built and parsed byte by byte here, with their own checksums, so
nothing is checked against the design's own arithmetic.
"""

from __future__ import annotations

import re
import struct
import zlib
from pathlib import Path

import cocotb
from cocotb.triggers import ClockCycles, FallingEdge, ReadOnly, Timer

from fsverif import sim
from fsverif.clkrst import start_clock

REPO = Path(__file__).resolve().parents[2]
CLK_NS = 10                                          # udp_clk_100mhz
LOCAL_MAC = bytes.fromhex("02c0ffee0042")
LOCAL_IP = bytes([192, 168, 7, 10])
HOST_MAC = bytes.fromhex("3c6060b1c001")
HOST_IP = bytes([192, 168, 7, 1])
OTHER_IP = bytes([192, 168, 7, 11])
BROADCAST = b"\xff" * 6


def _params() -> dict:
    text = (REPO / "bd" / "mpf500ts-fc1152m" / "udp_hier" / "components"
            / "udp_hier.tcl").read_text()
    block = re.search(r"-instance_name \{rsp_top_inst\} -params \{(.*?)\}", text, re.S).group(1)
    return {k: int(v) for k, v in re.findall(r'"(\w+):(\d+)"', block)}


def checksum(data: bytes) -> int:
    if len(data) % 2:
        data += b"\0"
    total = sum(struct.unpack("!%dH" % (len(data) // 2), data))
    while total >> 16:
        total = (total & 0xFFFF) + (total >> 16)
    return ~total & 0xFFFF


def wire(dst: bytes, src: bytes, ethertype: int, payload: bytes) -> bytes:
    """A frame as the MAC hands it on: padded to 60 bytes, with its FCS."""
    frame = dst + src + struct.pack("!H", ethertype) + payload
    frame += b"\0" * max(0, 60 - len(frame))
    return frame + struct.pack("<I", zlib.crc32(frame))


def arp(oper: int, sha: bytes, spa: bytes, tha: bytes, tpa: bytes) -> bytes:
    return struct.pack("!HHBBH", 1, 0x0800, 6, 4, oper) + sha + spa + tha + tpa


def ipv4(src: bytes, dst: bytes, proto: int, payload: bytes, ihl: int = 5,
         flags_frag: int = 0, ident: int = 0x1234, bad_checksum: bool = False) -> bytes:
    options = b"\x01" * (4 * (ihl - 5))
    hdr = struct.pack("!BBHHHBBH4s4s", 0x40 | ihl, 0, 20 + len(options) + len(payload),
                      ident, flags_frag, 64, proto, 0, src, dst) + options
    c = checksum(hdr) ^ (0x5555 if bad_checksum else 0)
    return hdr[:10] + struct.pack("!H", c) + hdr[12:] + payload


def icmp(type_: int, ident: int, seq: int, data: bytes) -> bytes:
    body = struct.pack("!BBHHH", type_, 0, 0, ident, seq) + data
    return body[:2] + struct.pack("!H", checksum(body)) + body[4:]


def ping(ident: int, seq: int, data: bytes, dst_mac=LOCAL_MAC, dst_ip=LOCAL_IP, **kw):
    return wire(dst_mac, HOST_MAC, 0x0800,
                ipv4(HOST_IP, dst_ip, 1, icmp(8, ident, seq, data), **kw))


def who_has(target_ip=LOCAL_IP, dst_mac=BROADCAST, oper=1, tha=b"\0" * 6):
    return wire(dst_mac, HOST_MAC, 0x0806, arp(oper, HOST_MAC, HOST_IP, tha, target_ip))


class Mac:
    """CORETSE's native FIFO interfaces, as the user guide defines them."""

    def __init__(self, dut):
        self.dut, self.clk = dut, dut.clk
        self.sent = []                    # reply frames, as bytes

    async def start(self) -> None:
        dut = self.dut
        start_clock(self.clk, CLK_NS)
        for s in ("rxrdy", "rxsof", "rxeof", "rxdata", "rxbytevalid"):
            getattr(dut, s).value = 0
        dut.txacpt.value = 1
        dut.src_mac_addr.value = int.from_bytes(LOCAL_MAC, "big")
        dut.src_ipv4_addr.value = int.from_bytes(LOCAL_IP, "big")
        dut.src_mac_valid.value = 1
        dut.src_ipv4_valid.value = 1
        dut.rst_n.value = 1
        await ClockCycles(self.clk, 2)
        dut.rst_n.value = 0
        await ClockCycles(self.clk, 10)
        dut.rst_n.value = 1
        cocotb.start_soon(self._transmit())
        p = _params()
        # The responder ignores the network for its PHY start-up wait.
        await Timer(p["CLOCK_FREQ_MHZ"] * p["PHY_INIT_USEC"] * CLK_NS + 1000, unit="ns")

    async def receive(self, frame: bytes, gap: int = 0) -> None:
        """Hand the responder one frame, a word at a time as the MAC does.

        `gap` idle clocks between words paces it: 2 is a word every 3 clocks,
        the 1 Gbit/s line rate at 100 MHz.
        """
        dut = self.dut
        words = [frame[i:i + 4] for i in range(0, len(frame), 4)]
        await FallingEdge(self.clk)
        for n, w in enumerate(words):
            last = n == len(words) - 1
            dut.rxdata.value = int.from_bytes(w.ljust(4, b"\0"), "little")
            dut.rxsof.value = int(n == 0)
            dut.rxeof.value = int(last)
            dut.rxbytevalid.value = (4 - len(w)) % 4 if last else 0
            dut.rxrdy.value = 1
            while True:
                await ReadOnly()
                taken = int(dut.rxacpt.value)
                await FallingEdge(self.clk)
                if taken:
                    break
            if gap and not last:
                dut.rxrdy.value = 0
                dut.rxsof.value = 0
                await ClockCycles(self.clk, gap, rising=False)
        dut.rxrdy.value = 0
        dut.rxsof.value = 0
        dut.rxeof.value = 0

    async def _transmit(self) -> None:
        dut, frame = self.dut, b""
        while True:
            await FallingEdge(self.clk)
            await ReadOnly()
            if int(dut.txrdy.value):
                word = int(dut.txdata.value).to_bytes(4, "little")
                if int(dut.txsof.value):
                    frame = b""
                if int(dut.txeof.value):
                    n = 4 - int(dut.txbytevalid.value) if int(dut.txbytevalid.value) else 4
                    self.sent.append(frame + word[:n])
                    frame = b""
                else:
                    frame += word

    async def exchange(self, frame: bytes, wait_us: float = 30, gap: int = 0) -> list[bytes]:
        before = len(self.sent)
        await self.receive(frame, gap)
        await Timer(wait_us, unit="us")
        return self.sent[before:]


def parse_arp(f: bytes) -> dict:
    htype, ptype, hlen, plen, oper = struct.unpack("!HHBBH", f[14:22])
    return {"dst": f[0:6], "src": f[6:12], "type": struct.unpack("!H", f[12:14])[0],
            "htype": htype, "ptype": ptype, "hlen": hlen, "plen": plen, "oper": oper,
            "sha": f[22:28], "spa": f[28:32], "tha": f[32:38], "tpa": f[38:42]}


def _describe(frames):
    return ["%d bytes: %s" % (len(f), f[:48].hex()) for f in frames]


# -----------------------------------------------------------------------------

@cocotb.test()
async def test_PF_ETH_02_accept_local_ipv4_mac(dut):
    """VC-PF-0094: IPv4 to the local MAC is taken in; the same frame to another MAC is not."""
    mac = Mac(dut)
    await mac.start()
    problems = []
    cases = (("the local MAC", LOCAL_MAC, True), ("another unicast MAC",
             bytes.fromhex("02c0ffee0043"), False), ("broadcast", BROADCAST, False))
    for label, dst, answered in cases:
        out = await mac.exchange(ping(0x77, 1, b"farsight", dst_mac=dst))
        dut._log.info("echo request to %s: %d replies", label, len(out))
        if answered and len(out) != 1:
            problems.append("an echo request to %s got %d replies" % (label, len(out)))
        if not answered and out:
            problems.append("an echo request to %s got a reply: %s" % (label, _describe(out)))
    assert not problems, "\n  ".join(["PF-ETH-02:"] + problems)


@cocotb.test()
async def test_PF_ETH_04_drop_nonlocal_arp_requests(dut):
    """VC-PF-0096: ARP that is not a request for the local IPv4 address gets nothing."""
    mac = Mac(dut)
    await mac.start()
    problems = []
    cases = (("a request for another address", who_has(OTHER_IP)),
             ("a request for 0.0.0.0", who_has(bytes(4))),
             ("a reply naming the local address", who_has(LOCAL_IP, oper=2, tha=LOCAL_MAC)))
    for label, frame in cases:
        out = await mac.exchange(frame)
        dut._log.info("%s: %d replies", label, len(out))
        if out:
            problems.append("%s was answered: %s" % (label, _describe(out)))
    # State unchanged: a request for the local address is still answered, right.
    out = await mac.exchange(who_has())
    if len(out) != 1 or parse_arp(out[0])["tha"] != HOST_MAC:
        problems.append("after them, a request for the local address got %s"
                        % _describe(out))
    # Characterisation, not this requirement: requests for the local address
    # that a host might send but this responder does not expect.
    for label, frame in (
            ("a unicast request, as hosts send to refresh a cache entry",
             who_has(dst_mac=LOCAL_MAC, tha=LOCAL_MAC)),
            ("a request with hardware type 6 (IEEE 802)",
             wire(BROADCAST, HOST_MAC, 0x0806, struct.pack("!HHBBH", 6, 0x0800, 6, 4, 1)
                  + HOST_MAC + HOST_IP + bytes(6) + LOCAL_IP))):
        out = await mac.exchange(frame)
        dut._log.info("%s: %d replies%s", label, len(out),
                      "" if not out else ", %s" % _describe(out)[0])
    assert not problems, "\n  ".join(["PF-ETH-04:"] + problems)


@cocotb.test()
async def test_PF_ETH_05_drop_unsupported_ipv4(dut):
    """VC-PF-0097: IPv4 that is not a local ICMP echo request gets nothing."""
    mac = Mac(dut)
    await mac.start()
    problems = []
    udp = struct.pack("!HHHH", 5000, 5001, 12, 0) + b"data"
    cases = (
        ("UDP to the local address", wire(LOCAL_MAC, HOST_MAC, 0x0800,
                                          ipv4(HOST_IP, LOCAL_IP, 17, udp))),
        ("TCP to the local address", wire(LOCAL_MAC, HOST_MAC, 0x0800,
                                          ipv4(HOST_IP, LOCAL_IP, 6, bytes(20)))),
        ("an echo reply to the local address", wire(LOCAL_MAC, HOST_MAC, 0x0800,
                                                    ipv4(HOST_IP, LOCAL_IP, 1,
                                                         icmp(0, 1, 1, b"x" * 8)))),
        ("an ICMP timestamp request", wire(LOCAL_MAC, HOST_MAC, 0x0800,
                                           ipv4(HOST_IP, LOCAL_IP, 1,
                                                icmp(13, 1, 1, bytes(12))))),
        ("an echo request to another address", ping(1, 1, b"x" * 8, dst_ip=OTHER_IP)),
        ("an echo request to an address differing in its last octet only",
         ping(1, 1, b"x" * 8, dst_ip=bytes([192, 168, 7, 99]))),
        ("an echo request to an address differing in its first octet only",
         ping(1, 1, b"x" * 8, dst_ip=bytes([10, 168, 7, 10]))),
        ("IPv6 to the local MAC", wire(LOCAL_MAC, HOST_MAC, 0x86DD, bytes(40))))
    for label, frame in cases:
        out = await mac.exchange(frame)
        dut._log.info("%s: %d replies", label, len(out))
        if out:
            problems.append("%s was answered: %s" % (label, _describe(out)))
    out = await mac.exchange(ping(9, 9, b"still here"))
    if len(out) != 1:
        problems.append("after them, a local echo request got %d replies" % len(out))
    # Characterisation, not this requirement: malformed local echo requests.
    for label, frame in (("with a bad header checksum", ping(2, 2, b"x" * 8, bad_checksum=True)),
                         ("with IP options (IHL 6)", ping(3, 3, b"x" * 8, ihl=6)),
                         ("as a first fragment (MF set)", ping(4, 4, b"x" * 8, flags_frag=0x2000))):
        out = await mac.exchange(frame)
        dut._log.info("echo request %s: %d replies%s", label, len(out),
                      "" if not out else ", %s" % _describe(out)[0])
    assert not problems, "\n  ".join(["PF-ETH-05:"] + problems)


@cocotb.test()
async def test_PF_ETH_06_generate_arp_replies(dut):
    """VC-PF-0098: a request for the local address gets a correct ARP reply."""
    mac = Mac(dut)
    await mac.start()
    problems = []
    for n in range(3):
        out = await mac.exchange(who_has())
        if len(out) != 1:
            problems.append("request %d: %d replies" % (n, len(out)))
            continue
        a = parse_arp(out[0])
        dut._log.info("ARP reply, %d bytes: %s", len(out[0]), out[0].hex())
        want = {"dst": HOST_MAC, "src": LOCAL_MAC, "type": 0x0806, "htype": 1,
                "ptype": 0x0800, "hlen": 6, "plen": 4, "oper": 2, "sha": LOCAL_MAC,
                "spa": LOCAL_IP, "tha": HOST_MAC, "tpa": HOST_IP}
        for k, v in want.items():
            if a[k] != v:
                problems.append("request %d: %s is %s, not %s" % (
                    n, k, a[k].hex() if isinstance(a[k], bytes) else hex(a[k]),
                    v.hex() if isinstance(v, bytes) else hex(v)))
    assert not problems, "\n  ".join(["PF-ETH-06:"] + problems)


@cocotb.test()
async def test_PF_ETH_07_generate_icmp_echo_replies(dut):
    """VC-PF-0100: an echo reply with the request's identifier, sequence and data."""
    mac = Mac(dut)
    await mac.start()
    problems = []
    for size in (0, 1, 18, 56, 57, 64, 1472):
        data = bytes((i * 7 + size) & 0xFF for i in range(size))
        ident, seq = 0x4000 + size, 0x0100 + size
        out = await mac.exchange(ping(ident, seq, data), wait_us=60)
        if len(out) != 1:
            problems.append("%d data bytes: %d replies" % (size, len(out)))
            continue
        f = out[0]
        ip = f[14:]
        ihl = (ip[0] & 0xF) * 4
        total = struct.unpack("!H", ip[2:4])[0]
        body = ip[ihl:total]
        dut._log.info("%d data bytes: reply frame %d bytes, IP total length %d, "
                      "%d bytes after it", size, len(f), total, len(f) - 14 - total)
        checks = {
            "Ethernet destination": (f[0:6], HOST_MAC),
            "Ethernet source": (f[6:12], LOCAL_MAC),
            "EtherType": (f[12:14], b"\x08\x00"),
            "IP version and header length": (ip[0], 0x45),
            "IP total length": (total, 20 + 8 + size),
            "IP protocol": (ip[9], 1),
            "IP source": (ip[12:16], LOCAL_IP),
            "IP destination": (ip[16:20], HOST_IP),
            "IP header checksum (0 when correct)": (checksum(ip[:ihl]), 0),
            "ICMP type and code": (body[0:2], b"\x00\x00"),
            "ICMP checksum (0 when correct)": (checksum(body), 0),
            "ICMP identifier": (struct.unpack("!H", body[4:6])[0], ident),
            "ICMP sequence": (struct.unpack("!H", body[6:8])[0], seq),
            "ICMP data": (body[8:], data),
        }
        for k, (got, want) in checks.items():
            if got != want:
                problems.append("%d data bytes: %s is %s, not %s" % (
                    size, k, got.hex() if isinstance(got, bytes) else got,
                    want.hex() if isinstance(want, bytes) else want))
    assert not problems, "\n  ".join(["PF-ETH-07:"] + problems)


@cocotb.test()
async def test_characterise_eth_echo_size(dut):
    """Not an item: the largest echo request answered whole, at two receive rates."""
    mac = Mac(dut)
    await mac.start()
    for gap, rate in ((0, "a word every clock"), (2, "line rate")):
        for size in (200, 216, 232, 248, 264, 280, 400, 800, 1200, 1472):
            data = bytes((i * 7 + size) & 0xFF for i in range(size))
            out = await mac.exchange(ping(5, size, data), wait_us=60, gap=gap)
            whole = (len(out) == 1 and len(out[0]) >= 14 + 28 + size
                     and out[0][14 + 28:14 + 28 + size] == data)
            dut._log.info("%s, %d data bytes: %s", rate, size,
                          "answered whole" if whole else
                          "%d replies%s" % (len(out), ", %d bytes" % len(out[0]) if out else ""))


# -----------------------------------------------------------------------------

def test_pf_eth():
    sim.run(hdl_toplevel="rsp_top",
            sources=sim.block("responder_ip", "rsp_fifo.sv", "width_up_conv.sv",
                              "width_down_conv.sv", "responder.sv", "rsp_top.sv"),
            test_module="test_pf_eth", parameters=_params())
