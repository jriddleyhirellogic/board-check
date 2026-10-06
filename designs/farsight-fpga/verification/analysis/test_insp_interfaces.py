"""Inspections of interfaces: the APB map, the metadata record, PCIe control.

Items: VC-PF-0012 (DRV-PF-01), VC-PF-0073 (PF-META-01), VC-PF-0053 (DRV-PF-11).

The ICD's tables are transcribed here, with the section each comes from, as
the simulations transcribe them: the ICD is the requirement's number, not the
design's, and is not in this repository. Everything else is read from the
design, the firmware or the retained build, with its line.
"""

from __future__ import annotations

import re
from pathlib import Path

from fsverif import board
from fsverif.build import retained
from fsverif.design import BD, REPO, WORKSPACE, Value, core_param, find

ICD = "CM-01979 revWIP"
INTERCONNECT = BD / "interconnect_hier" / "components"
TOP = BD / "top" / "components" / "top.tcl"
FW_CONFIG = REPO / "support" / "sw" / "lib" / "mpf_platform_config" / "fpga_design_config" / "fpga_design_config.h"
FLIGHT_SW = WORKSPACE / "farsight-avionics-sw"


def _cite(path: Path, text: str, offset: int) -> str:
    base = REPO if REPO in path.parents else WORKSPACE
    return "%s:%d" % (path.relative_to(base), text.count("\n", 0, offset) + 1)


# --------------------------------------------------------------------------
# DRV-PF-01: the APB slot map
# --------------------------------------------------------------------------

#: CM-01979 section 25.1, "Top APB slots": the peripheral classes the map
#: must expose, each with the firmware base names that are that class.
ICD_25_1 = {
    "camera mux": ["CAM_MUX"],
    "image metadata": ["IMAGE_METADATA"],
    "UDP TX": ["UDP_TX"],
    "camera trigger": ["CAM_TRIG"],
    "DMA read": ["DMA_READ_DDR4_8GB", "DMA_READ_DDR4_16GB",
                 "DMA_READ_CTRL_DDR4_8GB", "DMA_READ_CTRL_DDR4_16GB"],
    "DMA write": ["DMA_WRITE_DDR4_8GB", "DMA_WRITE_DDR4_16GB"],
    "PPS": ["PPS"],
    "HW version": ["HW_VERSION"],
    "ETH/PCIe mux": ["ETH_PCIE_MUX"],
    "junction temperature": ["JUNC_TEMP"],
    "camera fault detector": ["CAM_FAULT_DETECTOR"],
    "focus": ["STP_WD", "PRI_STP_CTRL", "PRI_STP_VREF", "PRI_STP_OUT", "SEC_STP_CTRL",
              "SEC_STP_VREF", "SEC_STP_OUT", "LVDT_GAIN", "LVDT_RO_SEC_Q", "LVDT_RO_PRI_I",
              "LVDT_RO_SEC_I", "LVDT_RO_PRI_Q", "PRI_STP_OVERFLOW", "SEC_STP_OVERFLOW"],
}

#: CM-01979 section 25.2: the peripheral bases it states, as `NAME + offset = address`.
ICD_25_2 = {
    "TMTC_UART": 0x70000000, "SLVSEC_SPI": 0x70001000, "GPO_CAM": 0x70003000,
    "DMA_WRITE_DDR4_8GB": 0x70004000, "DMA_WRITE_DDR4_16GB": 0x70005000,
    "DMA_READ_CTRL_DDR4_8GB": 0x70006000, "DMA_READ_CTRL_DDR4_16GB": 0x70007000,
    "ETH1_MAC": 0x70008000, "ETH1_CTRL": 0x7000A000, "CAM_MUX": 0x7000B000,
    "IMAGE_METADATA": 0x7000C000, "UDP_TX": 0x7000E000, "CAM_TRIG": 0x7000F000,
    "GPI_HK_STATUS": 0x70010000, "GPO_HK_PWR": 0x70011000,
    "DMA_READ_DDR4_8GB": 0x70013000, "DMA_READ_DDR4_16GB": 0x70014000, "PPS": 0x70015000,
    "HW_VERSION": 0x70017000, "ETH_PCIE_MUX": 0x70019000, "JUNC_TEMP": 0x7001A000,
    "CAM_FAULT_DETECTOR": 0x7001B000, "ASYNC_RST_DDR4_16GB": 0x7003B000,
    "ASYNC_RST_DDR4_8GB": 0x7003C000,
}

#: Which top-level APB pin each firmware base names: the inspected correspondence.
SLAVES = {
    "TMTC_UART": "tmtc_uart_inst:APBtarget", "SLVSEC_SPI": "cam_rx_inst:slvsec_spi_apb",
    "GPO_CAM": "cam_rx_inst:gpo_cam_apb",
    "DMA_WRITE_DDR4_8GB": "ddr4_8gb_group_hier_inst:s_apb",
    "DMA_WRITE_DDR4_16GB": "ddr4_16gb_group_hier_inst:s_apb",
    "DMA_READ_CTRL_DDR4_8GB": "ddr4_8gb_group_hier_inst:s_apb_dma_read_ctrl_reg",
    "DMA_READ_CTRL_DDR4_16GB": "ddr4_16gb_group_hier_inst:s_apb_dma_read_ctrl_reg",
    "ETH1_MAC": "eth1_hier_inst:eth1_mac_apb", "ETH1_STAT": "eth1_hier_inst:eth1_stat_apb",
    "ETH1_CTRL": "eth1_hier_inst:eth1_ctrl_apb", "CAM_MUX": "cam_rx_inst:cam_mux_apb",
    "IMAGE_METADATA": "cam_rx_inst:img_metadata_apb", "STP_WD": "focus_mech_inst:apb_stepper_wd",
    "UDP_TX": "udp_hier_inst:udp_tx_reg_apb", "CAM_TRIG": "cam_rx_inst:cam_trig_ctrl_apb",
    "GPI_HK_STATUS": "hk_hier_inst:gpi_hk_status_apb",
    "GPO_HK_PWR": "hk_hier_inst:gpo_hk_pwr_ctrl_apb", "DBG_GPIO": "dbg_gpio_inst:APB_bif",
    "DMA_READ_DDR4_8GB": "ddr4_8gb_group_hier_inst:s_apb_dma_read_ddr4_8gb_reg",
    "DMA_READ_DDR4_16GB": "ddr4_16gb_group_hier_inst:s_apb_dma_read_ddr4_16gb_reg",
    "PPS": "pps_hier_inst:apb_pps", "TIMER": "riscv_hier_inst:apb_timer",
    "HW_VERSION": "riscv_hier_inst:apb_hw_version", "FLASH_SPI": "flash_spi_inst:APB_bif",
    "ETH_PCIE_MUX": "eth_pcie_mux_hier_inst:s_apb", "JUNC_TEMP": "riscv_hier_inst:apb_junc_temp",
    "CAM_FAULT_DETECTOR": "cam_rx_inst:cam_fault_detector_apb",
    "FAV_GPIO": "bus_to_fav_gpio_inst:APB_bif",
    "PRI_STP_CTRL": "focus_mech_inst:PRI_STP_APB_STEPPER_CONTROLS",
    "PRI_STP_VREF": "focus_mech_inst:PRI_STP_APB_VREF",
    "PRI_STP_OUT": "focus_mech_inst:PRI_STP_APB_STEPPER_OUT",
    "SEC_STP_CTRL": "focus_mech_inst:SEC_STP_APB_STEPPER_CONTROLS",
    "SEC_STP_VREF": "focus_mech_inst:SEC_STP_APB_VREF",
    "SEC_STP_OUT": "focus_mech_inst:SEC_STP_APB_STEPPER_OUT",
    "LVDT_GAIN": "focus_mech_inst:APB_LVDT_Gain",
    "LVDT_RO_SEC_Q": "focus_mech_inst:LVDT_READOUT_APB_SEC_Q",
    "LVDT_RO_PRI_I": "focus_mech_inst:LVDT_READOUT_APB_PRI_I",
    "LVDT_RO_SEC_I": "focus_mech_inst:LVDT_READOUT_APB_SEC_I",
    "LVDT_RO_PRI_Q": "focus_mech_inst:LVDT_READOUT_APB_PRI_Q",
    "ASYNC_RST_DDR4_16GB": "rst_hier_inst:apb_async_rst_ddr4_16gb",
    "ASYNC_RST_DDR4_8GB": "rst_hier_inst:apb_async_rst_ddr4_8gb",
    "TEMP_TLM_SPI": "temp_tlm_spi_inst:APB_bif",
    "PRI_STP_OVERFLOW": "focus_mech_inst:PRI_STP_APB_STEPPER_OVERFLOW",
    "SEC_STP_OVERFLOW": "focus_mech_inst:SEC_STP_APB_STEPPER_OVERFLOW",
}


#: Flight firmware base names that differ from the lab firmware's.
FLIGHT_NAMES = {
    "UDP_DMACTRL_DDR4_8GB": "DMA_READ_CTRL_DDR4_8GB", "UDP_DMACTRL_DDR4_16GB": "DMA_READ_CTRL_DDR4_16GB",
    "IMG_METADATA": "IMAGE_METADATA", "STEPPER_WATCHDOG": "STP_WD", "VERSION": "HW_VERSION",
    "DDR4_16GB_ASYNC_RST": "ASYNC_RST_DDR4_16GB", "DDR4_8GB_ASYNC_RST": "ASYNC_RST_DDR4_8GB",
    "TLM_SPI": "TEMP_TLM_SPI",
}


def _connections(path: Path):
    text = path.read_text()
    for m in re.finditer(r"^sd_connect_pins -sd_name \$\{sd_name\} -pin_names \{(.*)\}\s*$", text, re.M):
        yield re.findall(r'"([^"]+)"', m.group(1)), _cite(path, text, m.start())


def _vendor(build, core: str, file: str) -> Path:
    found = sorted((build.root / "component" / "Actel" / "DirectCore" / core).glob("*/rtl/vlog/core/" + file))
    assert found, "the retained build has no %s RTL for %s" % (core, file)
    return found[-1]


def _address_map(r):
    """Every APB slot the processor can reach: address -> (top-level pin, source)."""
    b = retained()
    r.given("Build", b.root.name, "", "commit %s; the vendor cores' RTL as built" % b.commit)
    axi = INTERCONNECT / "COREAXI4INTERCONNECT_C0.tcl"
    base = int(str(r.input("AXI window of the peripherals", core_param(axi, "SLAVE0_START_ADDR"))), 16)
    ahb = INTERCONNECT / "CoreAHBLite_C0.tcl"
    memspace = r.input("CoreAHBLite MEMSPACE", core_param(ahb, "MEMSPACE"))
    dec = _vendor(b, "CoreAHBLite", "coreahblite_addrdec.v")
    text = dec.read_text()
    m = re.search(r"\(MEMSPACE == %d\) \? (\d+)" % memspace, text)
    msb = int(m.group(1))
    r.given("AHB slot select", "HADDR[%d:%d]" % (msb, msb - 3), "",
            "%s:%d" % (dec.relative_to(REPO), text.count("\n", 0, m.start()) + 1))
    ahb_slot = 1 << (msb - 3)
    apb3 = _vendor(b, "CoreAPB3", "coreapb3.v")
    sel = find(apb3, r"assign slotSel = PADDR\[MADDR_BITS-1:MADDR_BITS-4\];")
    r.input("APB slot select", sel)
    bridges, slots = {}, {}
    for pins, where in _connections(INTERCONNECT / "interconnect_hier.tcl"):
        for p in pins:
            m = re.match(r"CoreAHBLite_inst:AHBmslave(\d+)$", p)
            if m:
                other = [q for q in pins if q != p][0].split(":")[0]
                bridges[other] = int(m.group(1))
    for pins, where in _connections(INTERCONNECT / "interconnect_hier.tcl"):
        for p in pins:
            m = re.match(r"(COREAHBTOAPB3_inst\d+):APBinitiator$", p)
            if m:
                fabric = [q for q in pins if q != p][0].split(":")[0]
                bridges[fabric] = bridges[m.group(1)]
    maddr = {}
    for tcl in sorted(INTERCONNECT.glob("CoreAPB3_C*.tcl")):
        maddr[tcl.stem] = int(core_param(tcl, "MADDR_BITS").value)
    inst_core = dict(re.findall(r"-component_name \{(CoreAPB3_C\d)\} -instance_name \{(\w+)\}",
                                (INTERCONNECT / "interconnect_hier.tcl").read_text()))
    inst_core = {v: k for k, v in inst_core.items()}
    for pins, where in _connections(INTERCONNECT / "interconnect_hier.tcl"):
        for p in pins:
            m = re.match(r"(apb3_interconnect_inst\d+):APBmslave(\d+)$", p)
            if m:
                port = [q for q in pins if q != p][0]
                bits = maddr[inst_core[m.group(1)]]
                slots[port] = base + bridges[m.group(1)] * ahb_slot + int(m.group(2)) * (1 << (bits - 4))
    r.step("Address of `apbN_slaveM` = 0x%08X + (AHB slave of bridge N) x 0x%X + M x 0x%X, from "
           "the AHB-to-APB bridge each APB interconnect hangs on (`%s`)"
           % (base, ahb_slot, 1 << (maddr["CoreAPB3_C0"] - 4),
              (INTERCONNECT / "interconnect_hier.tcl").relative_to(REPO)))
    amap = {}
    for pins, where in _connections(TOP):
        mine = [p for p in pins if re.match(r"interconnect_hier_inst:apb\d_slave\d+$", p)]
        for p in mine:
            for other in (q for q in pins if q != p):
                amap.setdefault(slots[p.split(":")[1]], []).append((other, where))
    return amap


def test_DRV_PF_01_apb_slots_match_icd(calc):
    """VC-PF-0012: the APB interconnect exposes the slots of CM-01979 section 25.1."""
    r = calc("DRV-PF-01", "APB slot map against firmware and CM-01979 sections 25.1-25.2")
    amap = _address_map(r)
    text = FW_CONFIG.read_text()
    fw = {}
    for m in re.finditer(r"^#define (\w+)_BASE_ADDR\s+(0x[0-9A-Fa-f]+)UL", text, re.M):
        if m.group(1) != "APB3":
            fw[m.group(1)] = (int(m.group(2), 16), _cite(FW_CONFIG, text, m.start()))
    r.given("Firmware bases", len(fw), "", "%s, `*_BASE_ADDR`" % FW_CONFIG.relative_to(REPO))
    problems = []
    for addr, users in sorted(amap.items()):
        if len(users) > 1:
            problems.append("0x%08X is two slaves: %s" % (addr, users))
    by_pin = {users[0][0]: addr for addr, users in amap.items()}
    for name, (addr, where) in sorted(fw.items(), key=lambda kv: kv[1][0]):
        pin = SLAVES.get(name)
        got = by_pin.get(pin)
        r.step("0x%08X %-24s -> %s (%s)" % (addr, name, pin,
                                             amap[got][0][1] if got is not None else "no slot"))
        if pin is None:
            problems.append("%s (%s) names no known slave" % (name, where))
        elif got is None:
            problems.append("%s: %s is not on the APB" % (name, pin))
        elif got != addr:
            problems.append("%s at 0x%08X in firmware (%s), at 0x%08X in the design"
                            % (name, addr, where, got))
    flight = FLIGHT_SW / "Camera" / "include" / "mem_map.h"
    if flight.is_file():
        t = flight.read_text()
        n = 0
        for m in re.finditer(r"^#define (\w+)_BASE_ADDR\s+(0x[0-9A-Fa-f]+)", t, re.M):
            n += 1
            name, addr = FLIGHT_NAMES.get(m.group(1), m.group(1)), int(m.group(2), 16)
            if by_pin.get(SLAVES.get(name)) != addr:
                problems.append("flight firmware %s at 0x%08X (%s): the design has %s there"
                                % (m.group(1), addr, _cite(flight, t, m.start()),
                                   amap.get(addr, [("no slave",)])[0][0]))
        r.given("Flight firmware bases", n, "", "%s, each at the slave its name means"
                % _cite(flight, t, 0).rsplit(":", 1)[0])
    pins = {users[0][0] for users in amap.values()}
    for pin in sorted(pins - set(SLAVES.values())):
        problems.append("%s at 0x%08X has no firmware base" % (pin, by_pin[pin]))
    for cls, names in ICD_25_1.items():
        if not all(n in fw and SLAVES.get(n) in pins for n in names):
            problems.append("%s section 25.1 class '%s' is not fully on the bus" % (ICD, cls))
    r.given("Classes required", ", ".join(ICD_25_1), "", "%s section 25.1, 'Top APB slots'" % ICD)
    for name, addr in ICD_25_2.items():
        if by_pin.get(SLAVES[name]) != addr:
            problems.append("%s section 25.2 places %s at 0x%08X; the design at %s"
                            % (ICD, name, addr, by_pin.get(SLAVES[name])))
    r.given("Bases stated", len(ICD_25_2), "", "%s section 25.2, `NAME + offset = address`" % ICD)
    r.step("%d slots on the bus, %d firmware bases; every %s section 25.1 class present and "
           "every section 25.2 address agrees" % (len(amap), len(fw), ICD)
           if not problems else "Mismatches: %d" % len(problems))
    assert not problems, "; ".join(problems)


# --------------------------------------------------------------------------
# PF-META-01: the metadata record
# --------------------------------------------------------------------------

#: CM-01979 section 23.2, "Image metadata": byte address, field, size in bytes.
ICD_23_2 = [
    (0x00, "METADATA_START_FLAG", 4), (0x04, "METADATA_SIZE_BYTES", 4),
    (0x08, "SENSOR_PXL_READOUT_FORMAT", 4), (0x0C, "SENSOR_READ_DIR", 4),
    (0x10, "SENSOR_BIT_DEPTH", 4), (0x14, "SENSOR_GAIN", 4), (0x18, "SENSOR_BLO", 4),
    (0x1C, "SENSOR_EXPO_USEC", 4), (0x20, "SENSOR_TRIG_MODE", 4), (0x24, "SENSOR_TEMP_RAW", 4),
    (0x28, "BUFF_WRITE_INDEX", 4), (0x2C, "FOCUS_REQ_DIST_M", 4), (0x30, "FOCUS_COMP_DIST_M", 4),
    (0x34, "FOCUS_LVDT_POS_NM", 4), (0x38, "TIMESTAMP_UNIX_EPOCH_SEC", 4),
    (0x3C, "TIMESTAMP_SUBSEC_NSEC", 4), (0x40, "PF_FPGA_VERSION", 4),
    (0x44, "RESERVED PADDING", 4), (0x48, "RESERVED PADDING", 4), (0x4C, "METADATA-CRC32", 4),
]
META_RTL = REPO / "ip" / "image_metadata_ip" / "src" / "image_metadata_apb_reg.sv"
META_HEADERS = [REPO / "support" / "sw" / "src" / "include" / "image_metadata.h",
                FLIGHT_SW / "Camera" / "include" / "image_metadata.h"]
CONVERTER = REPO / "support" / "py-script" / "recv_conv" / "converter.py"


def _field(name: str) -> str:
    """A field name compared: case and separators ignored, and the padding
    words' index dropped, since the ICD gives both the same name."""
    s = re.sub(r"[^A-Z0-9]+", "_", name.upper()).strip("_")
    return re.sub(r"^RESERVED_PADDING\d$", "RESERVED_PADDING", s)


def _compare(r, label, fields, problems):
    """fields: [(byte offset, name, width bytes, source)] in record order."""
    icd = {o: (n, w) for o, n, w in ICD_23_2}
    bad = []
    for offset, name, width, where in fields:
        want = icd.get(offset)
        if want is None:
            bad.append("%s at 0x%02X is not in the ICD (%s)" % (name, offset, where))
        elif _field(name) != _field(want[0]) or width != want[1]:
            bad.append("0x%02X is `%s` (%d bytes, %s); the ICD has `%s` (%d bytes)"
                       % (offset, name, width, where, want[0], want[1]))
    missing = sorted(set(icd) - {f[0] for f in fields})
    bad += ["%s has no field at 0x%02X (%s)" % (label, o, icd[o][0]) for o in missing]
    r.step("%s: %d fields%s" % (label, len(fields), "; " + "; ".join(bad) if bad else
                                ", every one at its ICD offset, width and name"))
    problems += ["%s: %s" % (label, b) for b in bad]


def test_PF_META_01_metadata_schema_matches_icd(calc):
    """VC-PF-0073: the metadata RTL and register descriptions match CM-01979 section 23.2."""
    r = calc("PF-META-01", "metadata record layout against CM-01979 section 23.2")
    r.given("Layout", "%d fields, 0x00-0x4F" % len(ICD_23_2), "",
            "%s section 23.2 (the item cites 17.4, the register map; 23.2 is the metadata)" % ICD)
    problems = []
    text = META_RTL.read_text()
    width = int(find(META_RTL, r"APB_DATA_WIDTH\s*=\s*(\d+)").value)
    w = find(META_RTL, r"METADATA_WIDTH\s*=\s*(\d+)")
    total = r.input("METADATA_WIDTH", Value(int(w.value), w.source), "bits")
    rtl = []
    for m in re.finditer(r"localparam integer ADDR_(\w+?)_REG\s*=\s*32'h([0-9A-Fa-f]+);", text):
        rtl.append((int(m.group(2), 16) * 4, m.group(1), width // 8, _cite(META_RTL, text, m.start())))
    _compare(r, "RTL register map", rtl, problems)
    order = find(META_RTL, r"metadata_out <= \{(mem\[19\][^;]*)\};")
    words = [int(x) for x in re.findall(r"mem\[(\d+)\]", order.value)]
    r.step("`metadata_out` packs mem[%d]..mem[%d] from the top down (`%s`): register *i* is "
           "bits [32i+31:32i], so the record leaves in register order" % (words[0], words[-1], order.source))
    if words != list(range(len(ICD_23_2) - 1, -1, -1)) or total != 32 * len(ICD_23_2):
        problems.append("metadata_out is not registers %d..0 in %d bits" % (len(ICD_23_2) - 1, total))
    flag = find(META_RTL, r"METADATA_START_FLAG\s*=\s*32'h([0-9A-Fa-f]+)")
    size = find(META_RTL, r"METADATA_SIZE_BYTES\s*=\s*(\d+ \* \d+)")
    r.step("Start flag 0x%s (`%s`), size %s bytes (`%s`); the ICD gives 0x4D455441 and 0x50"
           % (flag.value, flag.source, size.value, size.source))
    a, b = (int(x) for x in size.value.split("*"))
    if int(flag.value, 16) != 0x4D455441 or a * b != 0x50:
        problems.append("start flag or size differs from the ICD")
    for header in META_HEADERS:
        if not header.is_file():
            r.step("%s: not present" % header)
            continue
        h = header.read_text()
        fields = [(int(m.group(2)), m.group(1), 4, _cite(header, h, m.start()))
                  for m in re.finditer(r"^#define (\w+)_REG_OFFSET (\d+)u", h, re.M)]
        _compare(r, "`%s`" % _cite(header, h, 0).rsplit(":", 1)[0], fields, problems)
    c = CONVERTER.read_text()
    block = re.search(r"METADATA_REGISTERS = \[(.*?)\]", c, re.S)
    names = re.findall(r'"(\w+)"', block.group(1))
    _compare(r, "host converter `%s`" % CONVERTER.relative_to(REPO),
             [(4 * i, n, 4, _cite(CONVERTER, c, block.start())) for i, n in enumerate(names)], problems)
    assert not problems, "; ".join(problems)


# --------------------------------------------------------------------------
# DRV-PF-11: who sets the PCIe export controls
# --------------------------------------------------------------------------

def _flight_sources():
    return sorted(p for p in FLIGHT_SW.rglob("*") if p.suffix in (".c", ".h") and p.is_file())


def test_DRV_PF_11_external_agent_sets_controls(calc):
    """VC-PF-0053: a named agent, with a control path, sets every PCIe export control."""
    r = calc("DRV-PF-11", "the agent and path for each control of a PCIe image read")
    assert FLIGHT_SW.is_dir(), "no flight software at %s" % FLIGHT_SW
    src = REPO / "ip" / "eth_pcie_mux_ip" / "src"
    problems = []

    offset = find(src / "pcie_translator.sv", r"assign pcie_full_addr = \{.*s_araddr\[24:0\]\};")
    r.step("Offset in frame: host, the PCIe read address itself (`%s`)" % offset.source)

    demux = find(src / "axi_read_demux.sv", r"ADDR_SEL\[3:0\]:\s+ddr4_sel\s+<=")
    index = find(src / "axi_read_demux.sv", r"ADDR_INDEX\[3:0\]:\s+ddr4_index\s+<=")
    host = next(((pins, where) for pins, where in _connections(TOP)
                 if "eth_pcie_mux_hier_inst:AXI4_S_PCIE" in pins), None)
    assert host, "nothing drives eth_pcie_mux_hier_inst:AXI4_S_PCIE in %s" % TOP.name
    r.step("Bank and frame index: registers of the demux (`%s`, `%s`), written over "
           "`AXI4_S_PCIE`, which is driven by %s (`%s`): the host, over a PCIe BAR"
           % (demux.source, index.source, [p for p in host[0] if "AXI4_S_PCIE" not in p], host[1]))
    if not any(p.startswith("pcie_hier_inst:") for p in host[0]):
        problems.append("bank and index are not host-written")

    sel = find(REPO / "support" / "sw" / "src" / "include" / "gpio_pin_def.h", r"#define ETH_PCIE_SEL (\w+)")
    r.step("Egress routing: `ETH_PCIE_SEL`, bit %s of the CoreGPIO at `ETH_PCIE_MUX_BASE_ADDR` "
           "(`%s`), an APB slave the PolarFire's own processor reaches; neither the host nor "
           "payload software can write it directly" % (sel.value, sel.source))
    writes, inits = [], []
    for path in _flight_sources():
        text = path.read_text(errors="replace")
        for m in re.finditer(r"GPIO_set_outputs?\s*\(\s*&?[\w.>\-]*eth_pcie_mux[^;]*;", text):
            writes.append(_cite(path, text, m.start()))
        for m in re.finditer(r"GPIO_init\s*\(\s*&?[\w.>\-]*eth_pcie_mux", text):
            inits.append(_cite(path, text, m.start()))
    r.step("Flight PolarFire firmware (`farsight-avionics-sw`): initialises it at %s; writes it at %s"
           % (", ".join(inits) or "nowhere", ", ".join(writes) or "**nowhere**"))
    lab = find(REPO / "support" / "sw" / "src" / "main.c", r"GPIO_set_output\(&eth_pcie_mux, ETH_PCIE_SEL, 1\)")
    r.step("The lab functional-test firmware sets it (`%s`); that is not flight software" % lab.source)
    if not writes:
        problems.append("ETH_PCIE_SEL: no flight agent writes it, and no path from payload "
                        "software reaches it (initialised only, %s)" % ", ".join(inits))
    assert not problems, "; ".join(problems)


# --------------------------------------------------------------------------
# PF-CPU-01, PF-CPU-02, PF-FOCUS-16: what the soft processor reaches
# --------------------------------------------------------------------------

RISCV = BD / "riscv_hier" / "components" / "riscv_hier.tcl"


def _net_of(path: Path, pin: str):
    """(the other pins on `pin`'s net, `path:line`), or (None, None)."""
    for pins, where in _connections(path):
        if pin in pins:
            return [p for p in pins if p != pin], where
    return None, None


def _on_bus(r, amap, pins, problems):
    """Each top-level APB pin's address on the processor's bus, recorded."""
    by_pin = {users[0][0]: (addr, users[0][1]) for addr, users in amap.items()}
    for pin in pins:
        if pin in by_pin:
            r.given(pin, "0x%08X" % by_pin[pin][0], "", by_pin[pin][1])
        else:
            problems.append("%s is not on the processor's APB" % pin)


def _processor(r, problems):
    m = find(RISCV, r"-component_name \{(MIV_RV32\w*)\} -instance_name \{riscv_inst\}")
    r.input("Soft processor in `riscv_hier`", m)
    others, where = _net_of(TOP, "riscv_hier_inst:riscv_axi4_initator")
    r.given("Its AXI initiator drives", ", ".join(others or ["nothing"]), "", where or TOP.name)
    if others != ["interconnect_hier_inst:riscv_aximm"]:
        problems.append("the processor's AXI initiator does not drive the peripheral interconnect")


def test_PF_CPU_01_processor_on_tmtc_link(calc):
    """VC-PF-0123: a soft processor receives and answers commands on the TMTC serial link."""
    r = calc("PF-CPU-01", "the soft processor and its command link")
    problems = []
    _processor(r, problems)
    amap = _address_map(r)
    _on_bus(r, amap, ["tmtc_uart_inst:APBtarget"], problems)
    sch = board.schematic()
    pins = board.pin_map()
    for uart_pin, port, want in (("tmtc_uart_inst:SIN", "uart0_rx", "receives"),
                                 ("tmtc_uart_inst:SOUT", "uart0_tx", "transmits")):
        others, where = _net_of(TOP, uart_pin)
        if not others or port not in others:
            problems.append("the TMTC UART %s on no top-level port (%s)" % (want, uart_pin))
            continue
        package, _, line = pins[port]
        p = sch.pin(board.PF, package)
        ends = sorted({"%s pin %s" % (q.component, q.number) for q in sch.reach(p.net)
                       if q.component != board.PF})
        r.given("TMTC UART %s on `%s`" % (want, port), "pin %s, net %s, to %s"
                % (package, p.net, ", ".join(ends) or "nothing"), "",
                "%s; %s:%d; %s" % (where, board.PINS.relative_to(REPO), line, sch.cite(p)))
        if not ends:
            problems.append("`%s` reaches nothing on the board" % port)
    irq, where = _net_of(TOP, "tmtc_uart_inst:INTR")
    core, where2 = _net_of(RISCV, "tmtc_ext_irq")
    r.given("TMTC UART interrupt", "%s, then %s" % (", ".join(irq or ["nothing"]),
                                                   ", ".join(core or ["nothing"])), "",
            "%s; %s" % (where, where2))
    if irq != ["riscv_hier_inst:tmtc_ext_irq"] or not core or \
            not any(c.startswith("riscv_inst:MSYS_EI") for c in core):
        problems.append("the TMTC UART's interrupt does not reach the processor")
    r.step("A processor on the bus, reaching the TMTC UART's registers, interrupted by it, "
           "with the UART's receive and transmit lines on the board" if not problems
           else "Missing: %d" % len(problems))
    assert not problems, "; ".join(problems)


def test_PF_CPU_02_processor_reaches_flash(calc):
    """VC-PF-0124: the soft processor reaches every line of the board's application flash."""
    r = calc("PF-CPU-02", "the soft processor's path to the board flash")
    problems = []
    _processor(r, problems)
    amap = _address_map(r)
    _on_bus(r, amap, ["flash_spi_inst:APB_bif"], problems)
    r.input("SPI master", find(TOP, r"-component_name \{(CORESPI_C\d)\} -instance_name \{flash_spi_inst\}"))
    sch = board.schematic()
    pins = board.pin_map()
    flash = set()
    for spi_pin, role in (("flash_spi_inst:SPISCLKO", "clock"), ("flash_spi_inst:SPISS[0:0]", "select"),
                          ("flash_spi_inst:SPISDO", "data out"), ("flash_spi_inst:SPISDI", "data in")):
        others, where = _net_of(TOP, spi_pin)
        ports = [o for o in others or [] if ":" not in o]
        if len(ports) != 1:
            problems.append("SPI %s (%s) is on no single top-level port" % (role, spi_pin))
            continue
        package, _, line = pins[ports[0]]
        p = sch.pin(board.PF, package)
        ends = [q for q in sch.reach(p.net) if q.component != board.PF]
        parts = sorted({"%s pin %s (%s)" % (q.component, q.number, sch.parts[q.component][0])
                        for q in ends})
        r.given("SPI %s, `%s`" % (role, ports[0]), "pin %s, net %s, to %s"
                % (package, p.net, ", ".join(parts) or "nothing"), "",
                "%s; %s:%d; %s" % (where, board.PINS.relative_to(REPO), line, sch.cite(p)))
        devices = {q.component for q in ends if q.component.startswith("U")}
        if len(devices) != 1:
            problems.append("SPI %s reaches %s, not one flash device" % (role, sorted(devices) or "nothing"))
        flash |= devices
    if len(flash) == 1:
        part = sch.parts[next(iter(flash))][0]
        r.step("All four lines reach %s, a %s" % (next(iter(flash)), part))
        if not re.match(r"SST26", part):
            problems.append("%s is %s, not an SPI flash" % (next(iter(flash)), part))
    elif flash:
        problems.append("the SPI lines reach different devices: %s" % sorted(flash))
    boot = FLIGHT_SW / "Bootloader" / "src" / "command.c"
    if boot.is_file():
        for what, pattern in (("erase", r"case FLASH_ERASE_SECTOR"), ("program", r"case WRITE_FLASH_PAGE"),
                              ("read", r"case READ_FLASH"), ("load and run", r"case LOAD_FLASH_TO_MEM")):
            m = re.search(pattern, boot.read_text())
            r.given("Flight bootloader command: %s" % what, m.group(0) if m else "absent", "",
                    _cite(boot, boot.read_text(), m.start()) if m else str(boot))
    assert not problems, "; ".join(problems)


FOCUS_TCL = REPO / "ip" / "focus_mech_ip" / "hw" / "ip" / "focus_mech_ip" / "components" / "focus_mech.tcl"
STEPPER_TCL = REPO / "ip" / "focus_mech_ip" / "hw" / "ip" / "stepper_ip" / "components" / "STEPPER_DRIVER.tcl"
#: The DRV8434 inputs PF-FOCUS-16 names, as the top-level port suffixes.
DRIVER_INPUTS = ("step", "dir", "en", "sleep_n", "m0", "m1", "decay0", "decay1", "toff", "vref_pwm")
#: Pins that pass a signal through unchanged, or gate it: output buffers, and the
#: watchdog's AND gate on step, whose other input is the watchdog's.
_THROUGH = {"PAD": "D", "Y": "A"}


def _source(path: Path, pin: str, trail: list) -> str:
    """Walk back from a pin, through buffers and the step gate, to the
    `STEPPER_DRIVER` output that drives it; or the pin where the walk stops."""
    while True:
        others, where = _net_of(path, pin)
        if others is None:
            return pin
        trail.append(where)
        nxt = None
        for o in others:
            inst, _, port = o.partition(":")
            if inst.startswith("STEPPER_DRIVER"):
                return o
            if port in _THROUGH:
                nxt = "%s:%s" % (inst, _THROUGH[port])
        if nxt is None:
            return pin
        pin = nxt


def test_PF_FOCUS_16_firmware_controls_drivers(calc):
    """VC-PF-0125: every DRV8434 input of both motors is driven from something firmware writes."""
    r = calc("PF-FOCUS-16", "firmware's control of the focus stepper drivers")
    problems = []
    inside = {}
    for pins, where in _connections(STEPPER_TCL):
        ports = [p for p in pins if ":" not in p]
        for port in ports:
            inside[port] = ([p for p in pins if p != port], where)
    apb_ports = set()
    for side, drv in (("pri", "STEPPER_DRIVER_1"), ("sec", "STEPPER_DRIVER_2")):
        for name in DRIVER_INPUTS:
            port = "%s_stp_motor_%s" % (side, name)
            others, where = _net_of(TOP, "focus_mech_inst:%s" % port)
            if not others or port not in others:
                problems.append("`%s` is not a top-level port of focus_mech" % port)
                continue
            trail = []
            src = _source(FOCUS_TCL, port, trail)
            if not src.startswith(drv + ":"):
                problems.append("`%s` is driven by %s, not %s" % (port, src, drv))
                continue
            out = src.split(":")[1]
            feeds, where2 = inside.get(out, ([], None))
            ok = [f for f in feeds if re.match(r"(STEPPER_CONTROLS:GPIO_OUT\[\d+:\d+\]|STEP_DIR_0:o_(step|dir)|VREF_PWM:PWM\[0:0\])$", f)]
            r.given("`%s`" % port, "%s <- %s" % (out, ", ".join(ok) or "nothing firmware writes"), "",
                    "%s; %s; %s" % (where, trail[0] if trail else FOCUS_TCL.name, where2))
            if not ok:
                problems.append("`%s` (%s) is not driven by a register, the step generator or the "
                                "current-reference PWM" % (port, out))
    for pins, where in _connections(FOCUS_TCL):
        for p in pins:
            m = re.match(r"STEPPER_DRIVER_[12]:(APB_\w+)$", p)
            if m:
                apb_ports |= {q for q in pins if ":" not in q}
    amap = _address_map(r)
    _on_bus(r, amap, sorted("focus_mech_inst:%s" % p for p in apb_ports), problems)
    gate = find(FOCUS_TCL, r'"(AND2_motor1_step_and_wdt_inst:B" "AND2_motor2_step_and_wdt_inst:B" "watchdog_top_inst:wd_active)"')
    r.input("Step is also gated by the watchdog (PF-FOCUS-01)", gate)
    r.step("Every input of both drivers is driven from an APB register, the step generator "
           "or the PWM, each on the processor's bus" if not problems
           else "Not firmware-controlled: %d" % len(problems))
    assert not problems, "; ".join(problems)
