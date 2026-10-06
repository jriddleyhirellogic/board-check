"""APB error semantics: PF-APB-02.

Item: VC-PF-0013. Clause: VVP-PF-001.

  PF-APB-02  Every APB peripheral shall signal an invalid access to the bus
             master, rather than returning data that cannot be distinguished
             from a valid read.

**Every APB register block of this design is a DUT**, one simulation each:
the eleven register blocks under `ip/*/src/*_apb_reg.sv` and the focus
watchdog's, and `pps`, which has its own APB slave. The per-bank wrappers
(`*_ddr4_8gb`, `*_ddr4_16gb`) only instantiate these. `CoreGPIO_C7` stands for
the vendor peripherals on the same bus. Each block's ports, address decode
and register map are read from its RTL here, not restated.

Four invalid accesses are made to each, after a valid read as a control:

- **a read of an unmapped register** inside the block's decode;
- **a write to an unmapped register**;
- **a read above the decode**, at an address whose decoded bits name a real
  register: the block occupies a window, and this is outside it;
- **a misaligned read**, `paddr[1:0]` = 2, as a byte or halfword access from
  the processor arrives.

Each must complete, with `pslverr`, within 32 clocks: APB has no other way to
say the access was invalid, and an access that never completes stalls the
master.
"""

from __future__ import annotations

import json
import os
import re
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge

from fsverif import hw_version, sim
from fsverif.bfm.apb import Apb, ApbTimeout

REPO = Path(__file__).resolve().parents[2]
ENV = "FSVERIF_PF_APB_BLOCK"
APB = {"pclk", "presetn", "psel", "penable", "pwrite", "paddr", "pwdata"}

#: name: (block for sim.block, its files, top module)
BLOCKS = {
    "cam_fault_detector": ("cam_fault_detector_ip", ["cam_fault_detector_apb_reg.sv"], "cam_fault_detector_apb_reg"),
    "cam_mux": ("cam_mux_ip", ["cam_mux_apb_reg.sv"], "cam_mux_apb_reg"),
    "cam_trig": ("cam_trig_ip", ["cam_trig_apb_reg.sv"], "cam_trig_apb_reg"),
    "dma_read_ctrl": ("dma_read_ctrl_ip", ["dma_read_ctrl_apb_reg.sv"], "dma_read_ctrl_apb_reg"),
    "dma_read": ("dma_read_ip", ["dma_read_apb_reg.sv"], "dma_read_apb_reg"),
    "dma_write": ("dma_write_ip", ["dma_write_apb_reg.sv"], "dma_write_apb_reg"),
    "hw_version": ("hw_version_ip", ["hw_version_apb_reg.sv"], "hw_version_apb_reg"),
    "image_metadata": ("image_metadata_ip", ["image_metadata_apb_reg.sv"], "image_metadata_apb_reg"),
    "junc_temp": ("junc_temp_ip", ["junc_temp_apb_reg.sv"], "junc_temp_apb_reg"),
    "udp_tx": ("udp_ip", ["udp_tx_apb_reg.sv"], "udp_tx_apb_reg"),
    "focus_watchdog": ("focus_mech_ip/hw/ip/watchdog_ip", ["watchdog_apb_reg.sv"], "watchdog_apb_reg"),
    "pps": ("pps_ip", ["divider_with_remainder.sv", "pps.sv"], "pps"),
}


def describe(path: Path) -> dict:
    """What the block's RTL says about its APB slave."""
    text = path.read_text()
    m = re.search(r"case\s*\(\s*paddr\s*\[\s*(\d+)\s*:\s*2\s*\]\s*\)", text)
    top_bit = int(m.group(1))
    mapped = set()
    for value in re.findall(r"localparam\s+(?:integer|logic\s*\[[^\]]*\])?\s*ADDR_\w+\s*=\s*"
                            r"(?:\d+)?'?([hdHD]?)([0-9a-fA-F_]+)", text):
        base, digits = value
        mapped.add(int(digits.replace("_", ""), 16 if base in "hH" else 10))
    # A range of registers (dma_read_ctrl's metadata block, 18 to 37).
    ranges = re.findall(r"ADDR_METADATA_DATA_BASE\s*=\s*'d(\d+).*?(\d+)\s+RO registers", text)
    for lo, count in ranges:
        mapped.update(range(int(lo), int(lo) + int(count)))
    ports = text[text.index("module"):text.index(");", text.index("module"))]
    inputs = re.findall(r"^\s*input\s+(?:logic|wire|reg)?\s*(?:signed\s*)?(?:\[[^\]]*\])?\s*(\w+)",
                        ports, re.M)
    slots = 1 << (top_bit - 1)
    unmapped = max(i for i in range(slots) if i not in mapped)
    return {"top_bit": top_bit, "mapped": sorted(mapped), "unmapped": unmapped,
            "inputs": inputs}


@cocotb.test()
async def test_PF_APB_02_invalid_access_signals_error(dut):
    """VC-PF-0013: each invalid access completes, with pslverr."""
    info = json.loads(os.environ[ENV])
    names = {n.lower(): n for n in info["inputs"]}
    clk = getattr(dut, names["pclk"])
    cocotb.start_soon(Clock(clk, 20, unit="ns").start())
    for low, name in names.items():
        if low in APB:
            continue
        sig = getattr(dut, name)
        if low.endswith("clk"):
            cocotb.start_soon(Clock(sig, 10, unit="ns").start())
        elif low.endswith(("rst_n", "resetn", "_n")):
            sig.value = 1
        else:
            sig.value = 0
    resets = [getattr(dut, n) for low, n in names.items()
              if low == "presetn" or low.endswith(("rst_n", "resetn"))]
    apb = Apb(dut, clk, "")
    for r in resets:
        r.value = 1
    await ClockCycles(clk, 2)
    for r in resets:
        r.value = 0
    await ClockCycles(clk, 5)
    for r in resets:
        r.value = 1
    await ClockCycles(clk, 20)

    window = 1 << (info["top_bit"] + 1)
    reg0 = 4 * info["mapped"][0]
    unmapped = 4 * info["unmapped"]
    accesses = [("valid read of register 0x%02x" % reg0, False, reg0, None),
                ("read of unmapped register 0x%02x" % unmapped, True, unmapped, None),
                ("write to unmapped register 0x%02x" % unmapped, True, unmapped, 0x5A5A5A5A)]
    # Only where the block sees address bits above its decode.
    if len(getattr(dut, names["paddr"])) > info["top_bit"] + 1:
        accesses.append(("read at 0x%x, above the 0x%x decode" % (window + reg0, window),
                         True, window + reg0, None))
    accesses.append(("misaligned read at 0x%02x" % (reg0 + 2), True, reg0 + 2, None))
    problems, rows = [], []
    for label, invalid, addr, data in accesses:
        try:
            r = await (apb.write(addr, data) if data is not None else apb.read(addr))
            outcome = "pslverr %d, prdata 0x%08x" % (r.slverr, r.data)
            flagged = bool(r.slverr)
        except ApbTimeout:
            outcome = "no pready in 32 clocks"
            flagged = False
            await FallingEdge(clk)
            apb.idle()
            await ClockCycles(clk, 5)
        rows.append("%s: %s" % (label, outcome))
        if invalid and not flagged:
            problems.append("%s: %s" % (label, outcome))
        if not invalid and "pready" in outcome:
            problems.append("the control, a %s, did not complete" % label)
    for row in rows:
        dut._log.info("%s, %s", info["name"], row)
    assert not problems, "\n  ".join(["PF-APB-02 (%s):" % info["name"]] + problems)


# -----------------------------------------------------------------------------

def _run(name: str) -> None:
    block, files, top = BLOCKS[name]
    if name == "hw_version":
        # Generated by the build, not in the repository: generate it the build's way.
        sources = [hw_version.generate(sim.BUILD_DIR / "test_pf_apb.hw_version.src",
                                       1, 0, 0, 1, hw_version.head_commit(), 1_790_000_000)]
    else:
        sources = sim.block(block, *files)
    info = describe(sources[-1])
    info["name"] = name
    os.environ[ENV] = json.dumps(info)
    try:
        sim.run(hdl_toplevel=top, sources=sources, test_module="test_pf_apb",
                run_id="test_pf_apb.%s" % name)
    finally:
        del os.environ[ENV]


def test_pf_apb_coregpio():
    """The vendor peripherals' representative: CoreGPIO, as generated."""
    sources = sim.vendor("CoreGPIO_C7")
    text = next(p for p in sources if p.name == "CoreGPIO_C7.v").read_text()
    info = {"name": "CoreGPIO_C7", "top_bit": 7, "mapped": [0x00, 0x80, 0x90, 0xA0],
            "unmapped": 0x3F,
            "inputs": re.findall(r"^\s*input\s+(?:\[[^\]]*\])?\s*(\w+)\s*;", text, re.M)}
    os.environ[ENV] = json.dumps(info)
    try:
        sim.run(hdl_toplevel="CoreGPIO_C7", sources=sources, test_module="test_pf_apb",
                run_id="test_pf_apb.CoreGPIO_C7")
    finally:
        del os.environ[ENV]


def test_pf_apb_cam_fault_detector():
    _run("cam_fault_detector")


def test_pf_apb_cam_mux():
    _run("cam_mux")


def test_pf_apb_cam_trig():
    _run("cam_trig")


def test_pf_apb_dma_read_ctrl():
    _run("dma_read_ctrl")


def test_pf_apb_dma_read():
    _run("dma_read")


def test_pf_apb_dma_write():
    _run("dma_write")


def test_pf_apb_hw_version():
    _run("hw_version")


def test_pf_apb_image_metadata():
    _run("image_metadata")


def test_pf_apb_junc_temp():
    _run("junc_temp")


def test_pf_apb_udp_tx():
    _run("udp_tx")


def test_pf_apb_focus_watchdog():
    _run("focus_watchdog")


def test_pf_apb_pps():
    _run("pps")
