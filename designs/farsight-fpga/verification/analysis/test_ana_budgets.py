"""Budget analyses: each item's calculation, from the design's own numbers.

Every input is read from where the build reads it (`fsverif.design`) and the
record cites it; the only typed numbers are requirements' bounds and figures
from standards, and the record says which those are. Each function asserts
its item's criterion, so a design change that breaks a budget fails here the
way a simulation fails.
"""

from __future__ import annotations

from fsverif.design import (BD, REPO, core_param, find, firmware, instance_param,
                            localparam, stepper_cycles)
from fsverif.oscillators import sys_clock_budget
from fsverif.stepper_driver import drv8434

DDR = {"8gb": ("ddr4_8gb_hier", "PF_DDR4_C2"), "16gb": ("ddr4_16gb_hier", "PF_DDR4_C0")}
SYS_PLL = BD / "top" / "components" / "PF_CCC_SYS_CLK_50MHZ.tcl"


def _ddr(bank: str, name: str):
    hier, core = DDR[bank]
    return core_param(BD / hier / "components" / ("%s.tcl" % core), name)


def _sys_clk_mhz(r):
    return r.input("System clock, `pll_sys_clk_50mhz` GL0", core_param(SYS_PLL, "GL0_0_OUT_FREQ"), "MHz")


def _udp_clk_mhz(r):
    return r.input("UDP clock, `pll_sys_clk_50mhz` GL1", core_param(SYS_PLL, "GL1_0_OUT_FREQ"), "MHz")


def _image_write_gbps(r):
    lines = r.input("Lines per frame", firmware("Camera/include/camera.h", r"#define LINES_PER_FRAME (\d+)"))
    width = r.input("Bytes per line", firmware("Camera/include/camera.h", r"#define HORIZ_WIDTH_BYTE (\d+)"), "B")
    fps = r.given("Frame rate", 70, "frame/s", "FAR-FPA_L5REQ-5")
    gbps = lines * width * 8 * fps / 1e9
    r.step("Image write stream: %d x %d B x 8 x %d /s = **%.2f Gbit/s**" % (lines, width, fps, gbps))
    return gbps


# -----------------------------------------------------------------------------
# DMAW

def test_PF_DMAW_09_timeout_calculation(calc):
    """VC-PF-0041: the write DMA's stall flag at 10 ms +/-5% on each bank's clock."""
    r = calc("PF-DMAW-09", "write-stall timeout on each bank's DDR-write clock")
    problems = []
    for bank in DDR:
        tcl = BD / DDR[bank][0] / "components" / ("dma_write_%s.tcl" % DDR[bank][0])
        inst = "dma_write_%s_inst" % DDR[bank][0].replace("_hier", "")
        mhz = r.input("%s: DMA's assumed clock, `CLOCK_FREQ_MHZ`" % bank,
                      instance_param(tcl, inst, "CLOCK_FREQ_MHZ"), "MHz")
        usec = r.input("%s: `TIMEOUT_USEC`" % bank, instance_param(tcl, inst, "TIMEOUT_USEC"), "us")
        user = r.input("%s: DDR-write clock, the PF_DDR4 user clock `CLOCK_USER`" % bank,
                       _ddr(bank, "CLOCK_USER"), "MHz")
        cycles = mhz * usec
        ms = cycles / (float(user) * 1e3)
        r.step("%s: %d x %d = %d cycles of %s MHz = **%.3f ms**" % (bank, mhz, usec, cycles, user, ms))
        if not 9.5 <= ms <= 10.5:
            problems.append("%s: %.3f ms, outside 10 ms +/-5%%" % (bank, ms))
    assert not problems, "; ".join(problems)


def test_PF_DMAW_10_write_bandwidth_budget(calc):
    """VC-PF-0038: each bank's AXI port carries the 17.4 Gbit/s write stream."""
    r = calc("PF-DMAW-10", "DDR4 write bandwidth against the image stream")
    need = _image_write_gbps(r)
    problems = []
    for bank in DDR:
        width = r.input("%s: AXI width" % bank, _ddr(bank, "AXI_WIDTH"), "bit")
        user = r.input("%s: AXI clock, `CLOCK_USER`" % bank, _ddr(bank, "CLOCK_USER"), "MHz")
        have = width * float(user) / 1e3
        r.step("%s: %d x %s MHz = **%.1f Gbit/s**, %.2fx the stream" % (bank, width, user, have, have / need))
        if have <= need:
            problems.append("%s: %.1f Gbit/s, not above %.2f" % (bank, have, need))
    r.step("At the AXI boundary only: DRAM efficiency, refresh and the controller are not counted.")
    assert not problems, "; ".join(problems)


# -----------------------------------------------------------------------------
# DMAR and PCIE

def test_PF_DMAR_24_read_bandwidth_budget(calc):
    """VC-PF-0043: 8.0 Gbit/s of reads from each bank, with and without capture."""
    r = calc("PF-DMAR-24", "DDR4 read bandwidth to the PCIe egress")
    egress = r.given("Egress rate required", 8.0, "Gbit/s", "PF-DMAR-24; PCIe Gen2 x2 payload")
    capture = _image_write_gbps(r)
    problems = []
    for bank in DDR:
        width = _ddr(bank, "AXI_WIDTH")
        user = _ddr(bank, "CLOCK_USER")
        r.input("%s: AXI width" % bank, width, "bit")
        r.input("%s: AXI clock" % bank, user, "MHz")
        have = int(width) * float(user) / 1e3
        r.step("%s: AXI %.1f Gbit/s. Without capture, %.2fx the egress; with the write "
               "stream concurrent, %.1f Gbit/s remain, %.2fx" % (bank, have, have / egress,
                                                                 have - capture, (have - capture) / egress))
    burst = r.input("PCIe read burst, `PCIE_MAX_BURST`",
                    localparam(REPO / "ip/eth_pcie_mux_ip/src/pcie_translator.sv", "PCIE_MAX_BURST"), "beats")
    beat = r.input("PCIe AXI width, `PCIE_DATA_WIDTH`",
                   localparam(REPO / "ip/eth_pcie_mux_ip/src/pcie_translator.sv", "PCIE_DATA_WIDTH"), "bit")
    clk = r.given("PCIe AXI clock", 150.0, "MHz", "the 8 GB DDR4 user clock, `pcie_hier` `AXI_CLK`")
    one = find(REPO / "ip/eth_pcie_mux_ip/src/pcie_translator.sv",
               r"assign s_arready\s*=\s*~ar_pending")
    r.input("One read in flight at a time", one)
    turn = r.given("A read's turnaround, acceptance to first beat", 95, "ns",
                   "measured, `verification/tests/test_pf_dmar_rate.py`, 87-107 ns")
    data_ns = burst * 1e3 / clk
    ceiling = burst * beat / (data_ns + turn)
    r.step("The read path: %d x %d bit per %.1f ns of data + %d ns of turnaround = "
           "**%.2f Gbit/s**, whatever the DDR4 supplies" % (burst, beat, data_ns, turn, ceiling))
    if ceiling < egress:
        problems.append("the PCIe read path carries %.2f Gbit/s, under %.1f (PF-F-43)" % (ceiling, egress))
    assert not problems, "; ".join(problems)


def test_PF_PCIE_10_pcie_payload_budget(calc):
    """VC-PF-0051: 8.0 Gbit/s of image payload at the PCIe boundary."""
    r = calc("PF-PCIE-10", "PCIe payload throughput")
    pcie = BD / "pcie_hier" / "components" / "PF_PCIE_C0.tcl"
    rate = r.input("Link rate", core_param(pcie, "UI_PCIE_0_LANE_RATE"))
    lanes = r.input("Lanes", core_param(pcie, "UI_PCIE_0_NUMBER_OF_LANES"))
    need = r.given("Payload required", 8.0, "Gbit/s", "PF-PCIE-10")
    gts = 5.0 if "Gen2" in str(rate) else 2.5
    n = int(str(lanes).strip("x"))
    line = gts * n * 8 / 10
    r.step("Data rate after 8b10b: %.1f GT/s x %d x 8/10 = **%.1f Gbit/s**, every TLP's "
           "bytes included" % (gts, n, line))
    overhead = r.given("Per-TLP overhead, at best", 20, "B",
                       "PCIe base specification: STP and END framing 2, sequence number 2, "
                       "3-DW completion header 12, LCRC 4; no ECRC")
    best = 4096
    r.step("At the largest payload the specification allows, %d B: %d / %d = %.4f of the "
           "data rate, **%.3f Gbit/s** of payload, before DLLPs and before the read path"
           % (best, best, best + overhead, best / (best + overhead), line * best / (best + overhead)))
    payload = line * best / (best + overhead)
    assert payload >= need, (
        "%.3f Gbit/s at best: Gen2 x2 carries 8.0 Gbit/s of data after 8b10b, and every TLP "
        "spends some of it on overhead, so 8.0 Gbit/s of payload is unreachable" % payload)


# -----------------------------------------------------------------------------
# FOCUS

#: The driver's rows each requirement's interval answers to, and the others recorded with it.
_DRIVER_ROWS = {"interval": ("period",), "low": ("low", "high"), "setup": ("setup", "hold")}


def _focus(calc, item, which, us_wanted, what):
    r = calc(item, what)
    cycles = stepper_cycles(r)
    mhz = _sys_clk_mhz(r)
    us = cycles[which] / mhz
    r.step("%s: %d cycles / %s MHz = **%.3f us** at the nominal frequency, against at least "
           "%.1f us" % (which, cycles[which], mhz, us, us_wanted))
    ppm = sys_clock_budget(r)
    fast = us * (1 - ppm * 1e-6)
    r.step("With the clock %.0f ppm fast: **%.6f us**, margin %+.2f ns. The simulation measures "
           "the pins at the nominal frequency (`verification/tests/test_pf_focus.py`)."
           % (ppm, fast, (fast - us_wanted) * 1e3))
    need = drv8434(r)
    # The hold is counted like the setup: reloaded on the step edge, released one edge after zero.
    built = dict(cycles, period=cycles["interval"], hold=cycles["setup"])
    for row in _DRIVER_ROWS[which]:
        ns = built[row] / mhz * 1e3 * (1 - ppm * 1e-6)
        r.step("Against the driver's own %s minimum of %g ns: %d cycles, %.1f ns with the clock "
               "fast, margin **%+.1f ns**" % (row, need[row], built[row], ns, ns - need[row]))
    assert fast >= us_wanted, ("%d cycles give %.3f us nominally and %.6f us with the clock "
                               "%.0f ppm fast" % (cycles[which], us, fast, ppm))


def test_PF_FOCUS_08_step_interval_calculation(calc):
    """VC-PF-0058: the step interval is at least 3.0 us."""
    _focus(calc, "PF-FOCUS-08", "interval", 3.0, "time between step assertions")


def test_PF_FOCUS_09_step_low_calculation(calc):
    """VC-PF-0061: the step-low interval is at least 1.5 us."""
    _focus(calc, "PF-FOCUS-09", "low", 1.5, "step-low interval")


def test_PF_FOCUS_10_direction_setup_calculation(calc):
    """VC-PF-0064: the direction setup is at least 0.3 us."""
    _focus(calc, "PF-FOCUS-10", "setup", 0.3, "direction setup before a step")


# -----------------------------------------------------------------------------
# PPS

def test_PF_PPS_07_local_pps_calculation(calc):
    """VC-PF-0089: the local generator's counter gives 1 Hz at 50% duty."""
    r = calc("PF-PPS-07", "local PPS period and duty cycle")
    tcl = BD / "pps_hier" / "components" / "pps_hier.tcl"
    mhz = r.input("Generator's `CLOCK_FREQ_MHZ`", instance_param(tcl, "pps_generator_inst", "CLOCK_FREQ_MHZ"), "MHz")
    clk = _sys_clk_mhz(r)
    src = REPO / "ip/pps_ip/src/pps_generator.sv"
    r.input("Half period, `PULSE_WIDTH`", find(src, r"localparam PULSE_WIDTH\s*=\s*([^;]+);"))
    r.input("Toggle rule", find(src, r"if \(counter == PULSE_WIDTH - 1\)"))
    half = (mhz * 1_000_000) >> 1
    r.step("Each phase: (%d x 10^6) >> 1 = %d cycles, counted 0 to %d, so %d cycles of %s MHz "
           "= %.6f s; low and high are the same count" % (mhz, half, half - 1, half, clk, half / (clk * 1e6)))
    period = 2 * half / (clk * 1e6)
    r.step("Period **%.6f s**, %.6f Hz, duty **50%%**, in clock time; the clock's accuracy is "
           "PF-PPS-09's" % (period, 1 / period))
    assert mhz == clk and abs(period - 1.0) < 1e-12


# -----------------------------------------------------------------------------
# UDP

def _gap(r):
    src = REPO / "ip/udp_ip/src/udp_tx.sv"
    default = r.input("Default gap, `FRAME_GAP_DEFAULT`", localparam(src, "FRAME_GAP_DEFAULT"), "cycles")
    r.input("Default rule", find(src, r"if \(frame_gap_sync\[1\] == 0\) begin"))
    r.input("Wait rule", find(src, r"if\(gap_counter < frame_gap_reg\) begin"))
    mhz = _udp_clk_mhz(r)
    return default, mhz


def test_PF_UDP_15_gap_calculation(calc):
    """VC-PF-0108: FRAME_GAP and the default, as elapsed time."""
    r = calc("PF-UDP-15", "inter-packet gap settings as time")
    default, mhz = _gap(r)
    r.input("`FRAME_GAP` register", find(REPO / "ip/udp_ip/src/udp_tx_apb_reg.sv",
                                         r"(mem\[ADDR_FRAME_GAP\]\s*<= pwdata\[31:0\];)"))
    r.step("A setting of N cycles waits N clocks of %s MHz, **N x %.0f ns**, after a datagram's "
           "last word; 0 selects the default, %d cycles, **%.1f us**. 32 bits: up to %.1f s"
           % (mhz, 1e3 / mhz, default, default / mhz, (2**32 - 1) / (mhz * 1e6)))
    r.step("Measured end to start, 0.1 us more: `verification/tests/test_pf_udp.py`")


def test_DRV_PF_08_gap_calculation(calc):
    """VC-PF-0110: the default and every permitted setting give at least 20 us."""
    r = calc("DRV-PF-08", "inter-packet gap against the 20 us floor")
    default, mhz = _gap(r)
    floor = r.given("Floor", 20.0, "us", "DRV-PF-08, from the CORETSE need")
    shortest = 1 / mhz
    r.step("Default: %d cycles = **%.1f us**. Permitted settings 1 to 2^32-1: the shortest, 1 "
           "cycle, is **%.3f us**; settings under %d cycles give less than %.0f us"
           % (default, default / mhz, shortest, floor * mhz, floor))
    problems = []
    if default / mhz < floor:
        problems.append("the default is %.1f us" % (default / mhz))
    if shortest < floor:
        problems.append("settings 1 to %d give %.3f to %.2f us" % (floor * mhz - 1, shortest,
                                                                     (floor * mhz - 1) / mhz))
    assert not problems, "under %.0f us: %s" % (floor, "; ".join(problems))


def test_DRV_PF_09_udp_egress_budget(calc):
    """VC-PF-0111: at least 200 Mbit/s of image data at the Ethernet boundary."""
    r = calc("DRV-PF-09", "UDP egress rate while draining a frame")
    src = REPO / "ip/dma_read_ctrl_ip/src/dma_read_ctrl.sv"
    words = r.input("Payload words a datagram (standard; firmware never selects jumbo)",
                    localparam(src, "MAX_STD_FRM"), "words")
    token = r.input("Token and index, `PKT_TOKEN_SIZE`", localparam(src, "PKT_TOKEN_SIZE"), "B")
    default, mhz = _gap(r)
    floor = r.given("Required", 200, "Mbit/s", "DRV-PF-09")
    line = r.given("Ethernet line rate", 1000, "Mbit/s", "1000BASE-T")
    eth = r.given("Ethernet framing", 14 + 4 + 8 + 12, "B", "header 14, FCS 4, preamble 8, IFG 12")
    ip_udp = r.given("IPv4 and UDP headers", 28, "B", "20 + 8")
    image = 4 * words
    wire = image + token + ip_udp + eth
    wire_us = wire * 8 / line
    to_mac_us = (wire - 20) / 4 / mhz
    period = max(wire_us, to_mac_us + default / mhz)
    rate = image * 8 / period
    r.step("A datagram: %d B of image, %d B on the wire, %.2f us at %d Mbit/s; handed to the "
           "MAC in %.2f us, then the %.1f us gap" % (image, wire, wire_us, line, to_mac_us, default / mhz))
    r.step("One datagram per %.2f us: **%.0f Mbit/s** of image data at the default gap" % (period, rate))
    compliant = image * 8 / max(wire_us, to_mac_us + 20.0)
    r.step("At a 20 us gap, DRV-PF-08's floor: %.0f Mbit/s" % compliant)
    r.step("Neither counts line gaps or the read path's pauses between lines, so these are upper "
           "bounds; the hardware item measures it")
    assert min(rate, compliant) >= floor


# -----------------------------------------------------------------------------
# XCVR

def test_PF_XCVR_08_interrupt_trace(calc):
    """VC-PF-0118: the lane-recovery interrupt reaches firmware after the reset is released."""
    r = calc("PF-XCVR-08", "lane-recovery sequence, reset and interrupt")
    rtl = REPO / "ip/xcvr_disparity_correction/src/xcvr_disparity_correction.v"
    r.input("Reset released on leaving `s_RST_CNT`", find(rtl, r"RX_RST_CONTROL_O <= 1'b1;\s*// Release reset"))
    r.input("Interrupt pulsed in `s_REG_RST`, the next state", find(rtl, r"RX_RST_CONTROL_INTERRUPT_O\s*<= 1'b1;"))
    r.step("In the block, the interrupt follows the release by one clock")
    unused = find(BD / "cam_rx_hier" / "components" / "cam_rx_hier.tcl",
                  r"(sd_mark_pins_unused .*xcvr_disparity_correction_inst:RX_RST_CONTROL_INTERRUPT_O\})")
    r.input("In `cam_rx_hier`, the interrupt output", unused)
    r.step("The output is marked unused: nothing outside the block receives it, so no interrupt "
           "reaches firmware")
    assert False, "RX_RST_CONTROL_INTERRUPT_O is marked unused in cam_rx_hier (%s)" % unused.source


def test_PF_XCVR_09_ingest_budget(calc):
    """VC-PF-0120: eight SLVS-EC lanes carry the 17.4 Gbit/s pixel stream."""
    r = calc("PF-XCVR-09", "SLVS-EC ingest rate")
    need = _image_write_gbps(r)
    xcvr = BD / "cam_rx_hier" / "components" / "PF_XCVR_ERM_C0.tcl"
    rate = r.input("Lane rate", core_param(xcvr, "UI_RX_DATA_RATE"), "Mbit/s")
    lanes = r.input("Lanes", instance_param(BD / "cam_rx_hier" / "components" / "cam_rx_hier.tcl",
                                            "xcvr_disparity_correction_inst", "NUM_LANES"))
    have = lanes * rate * 8 / 10 / 1e3
    r.step("%d x %d Mbit/s x 8/10 (8b10b) = **%.2f Gbit/s**, %.2fx the stream" % (lanes, rate, have, have / need))
    r.step("SLVS-EC packet headers and footers are not counted; the hardware item measures ingest")
    assert have > need


# -----------------------------------------------------------------------------
# LVDT readout

LVDT = REPO / "ip" / "focus_mech_ip" / "hw" / "ip" / "lvdt_ip"
LVDT_TCL = LVDT / "components"
FOCUS_TCL = REPO / "ip" / "focus_mech_ip" / "hw" / "ip" / "focus_mech_ip" / "components" / "focus_mech.tcl"


def _biquads(r, chain: str, names: list) -> list:
    """[(b0, b1, b2, a1, a2)] as configured, scaled by the section's 2^FIXED_POINT."""
    tcl = LVDT_TCL / "LOCK_IN_CHAIN.tcl"
    out = []
    for n in names:
        fp = 2 ** int(instance_param(tcl, n, "FIXED_POINT").value)
        c = [instance_param(tcl, n, k) for k in ("B0", "B1", "B2", "A1", "A2")]
        r.given("%s %s" % (chain, n), "B %s %s %s, A %s %s (/%d)" % tuple([v.value for v in c] + [fp]),
                "", c[0].source)
        out.append(tuple(v.value / fp for v in c))
    return out


def _response(sections: list, w: float) -> complex:
    """The cascade's response at w radians per sample, each section
    (b0 + b1 z^-1 + b2 z^-2) / (1 + a1 z^-1 + a2 z^-2), as IIR_BIQUAD computes it."""
    import cmath
    z1 = cmath.exp(-1j * w)
    h = 1
    for b0, b1, b2, a1, a2 in sections:
        h *= (b0 + b1 * z1 + b2 * z1 * z1) / (1 + a1 * z1 + a2 * z1 * z1)
    return h


def test_DRV_PF_12_lvdt_2f_attenuation(calc):
    """VC-PF-0137: the 2f mixing product attenuated by 90 dB against DC, as built."""
    import math
    r = calc("DRV-PF-12", "attenuation of the 2f product in the LVDT lock-in outputs")
    bound = r.given("Bound", 90, "dB", "DRV-PF-12, relative to DC (TBR)")
    clk = r.input("LVDT readout clock: the 50 MHz system clock",
                  find(FOCUS_TCL, r'"(LVDT_READOUT_0:i_clk)"'))
    mhz = _sys_clk_mhz(r)
    rd = LVDT_TCL / "LVDT_READOUT.tcl"
    ch = r.input("ADC channels scanned", instance_param(rd, "ADC128S102_DRIVER_0_0", "CHANNEL_COUNT"))
    div = r.input("SPI clock divider", instance_param(rd, "ADC128S102_DRIVER_0_0", "SPI_CLK_DIV"), "clocks per SPI clock")
    drv = LVDT / "src" / "ADC128S102_DRIVER.sv"
    r.input("One conversion frame: the counter runs 0 to 16", find(drv, r"(if\(spi_clk_counter == 16\))"))
    fs_in = mhz * 1e6 / (ch * 17 * div)
    r.step("Each coil is sampled once per scan: %g MHz / (%d channels x 17 SPI clocks x %d) = "
           "**%.1f S/s**" % (mhz, ch, div, fs_in))
    dds = LVDT_TCL / "SIN_COS_GEN.tcl"
    bits = r.input("DDS phase accumulator", core_param(dds, "PH_ACC_BITS"), "bits")
    inc = r.input("DDS phase increment", core_param(dds, "PH_INC_LOWER"))
    f_exc = mhz * 1e6 * inc / 2 ** bits
    r.step("Excitation %g MHz x %d / 2^%d = **%.2f Hz**; the mixer's unwanted product is at "
           "2f = **%.1f Hz**" % (mhz, inc, bits, f_exc, 2 * f_exc))
    chain = LVDT_TCL / "LOCK_IN_CHAIN.tcl"
    n_cfg = r.input("Decimation, as configured", instance_param(chain, "DECIMATOR_I", "DECIMATION_RATIO"))
    dec = LVDT / "src" / "DECIMATOR.sv"
    r.input("The counter is incremented with a blocking assignment", find(dec, r"(sample_counter \+= 1;)"))
    r.input("and compared, already incremented, on the next line", find(dec, r"(if\(sample_counter == DECIMATION_RATIO - 1\))"))
    n_built = n_cfg - 1
    r.step("So one sample leaves for every **%d** valid inputs, not %d (`PF-F-38`)" % (n_built, n_cfg))
    post = (_biquads(r, "I", ["BS_I_1_3", "BS_I_2_3", "BS_I_3_3", "LP_I_1_2", "LP_I_2_2"]))
    q = _biquads(r, "Q", ["BS_Q_1_3", "BS_Q_2_3", "BS_Q_3_3", "LP_Q_1_2", "LP_Q_2_2"])
    problems = []
    if q != post:
        problems.append("the I and Q chains are configured differently")
    r.step("The band-pass sections ahead of the mixer act on the coil signal at f, before the "
           "product exists, so they scale the DC and 2f terms alike and cancel from the ratio. "
           "The decimator selects without filtering. What separates them is the band-stop and "
           "low-pass cascade after it, at the decimated rate")
    for label, n in (("as designed", n_cfg), ("as built", n_built)):
        fs = fs_in / n
        w = 2 * math.pi * 2 * f_exc / fs
        att = -20 * math.log10(abs(_response(post, w)) / abs(_response(post, 0)))
        r.step("%s, /%d: %.1f S/s, 2f at %.3f of Nyquist: **%.1f dB** below DC%s"
               % (label.capitalize(), n, fs, 2 * f_exc / (fs / 2), att,
                  "" if 2 * f_exc < fs / 2 else ", **aliased**"))
        if label == "as built":
            built = att
    r.step("Margin as built: **%+.1f dB**" % (built - bound))
    if built < bound:
        problems.append("as built the 2f product is %.1f dB below DC, not %d" % (built, bound))
    assert not problems, "; ".join(problems)
