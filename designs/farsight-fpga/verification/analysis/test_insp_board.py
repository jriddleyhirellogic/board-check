"""Inspections of the PolarFire against the board: pins, clocks, camera lanes, ETH2.

Items: VC-PF-0018 (PF-IO-05), VC-PF-0102 (PF-ETH-09), VC-PF-0104 (PF-ETH-10),
VC-PF-0133 (PF-IO-01), VC-PF-0134 (PF-IO-02), VC-PF-0135 (PF-IO-03),
VC-PF-0136 (PF-IO-04), VC-PF-0139 (PF-TRIG-05), VC-PF-0140 (PF-PPS-06),
VC-PF-0141 (PF-PPS-08).

Each compares the design -- the constraint files, the top-level SmartDesign
and, for where ports actually landed, the retained build's pin report --
with the avionics schematic export, net by net. A line that runs to the
housekeeper (the ProASIC3, `U2`) is followed through its series resistor and
compared with the housekeeper's own pinout: there the schematic's net names
are generic (`PF_TO_PA3_MISC0`), and the signal a line carries is defined by
what the two FPGAs put on it.
"""

from __future__ import annotations

import re

from fsverif import board
from fsverif.board import HK, PF, WORKSPACE
from fsverif.build import retained
from fsverif.design import BD, REPO, core_param, find
from fsverif.oscillators import oscillator

TOP = BD / "top" / "components" / "top.tcl"
FLIGHT_SW = WORKSPACE / "farsight-avionics-sw"
HK_HIER = BD / "hk_hier" / "components" / "hk_hier.tcl"


def _rel(path, line):
    return "%s:%d" % (path.relative_to(REPO), line)


# Naming conventions between the constraint signal names and the schematic's
# net names, applied in order to the signal name. Each is a convention, not a
# correction: a signal that needs anything more is listed in ALIASES with why.
RULES = [
    (r"^CAM_LANE(\d)_RXD_", r"SLVS_EC_\1_"),
    (r"^PCIE0_LANE(\d)_(T|R)XD_", r"PCIE\1_\2X_"),
    (r"^DDR4_R0_", "DDR4_16GB_"), (r"^DDR4_R2_", "DDR4_8GB_ECC_"),
    (r"_CK0_N$", "_CK_N"), (r"_CK0$", "_CK_P"),
    (r"_DQS_N\[(\d+)\]$", r"_DQS\1_N"), (r"_DQS\[(\d+)\]$", r"_DQS\1_P"),
    (r"_DM_N\[(\d+)\]$", r"_NDM\1"),
    (r"\[(\d+)\]$", r"\1"),
    (r"^CAM_", "IMX_"), (r"^DBG_GPIO", "DEBUG_GPIO"), (r"^NVM_SPI_", "QSPI_"),
    (r"^TLM_SPI_", "ADC_"), (r"^XCVR1_LANE0_(R|T)X_", r"AUX_XCVR_\1X_"), (r"^JTAG_", "JTAG_PF_"),
    (r"^(ETH\d)_(RGMII|STAT|CTRL|PHY)_", r"\1_"), (r"_RXC$", "_RX_CLK"), (r"_TXC$", "_TX_CLK"),
    (r"_CLK_SQUELCH_IN$", "_CLK_SQUELCH"), (r"_COMMA_MODE$", "_COMA"),
    (r"_PWR_STATUS$", "_PGOOD"), (r"^DDR(\d+GB)_PGOOD$", r"\1_ECC_PGOOD"),
    (r"^PRI_STP_MOTOR_", "PRIM_"), (r"^SEC_STP_MOTOR_", "SEC_"), (r"^LVDT_ADC_SPI_", "LVDT_ADC_"),
    (r"_RST_N$", "_RESET_N"), (r"_SWITCH$", "_SW"),
]
# Active-low: a trailing `_n` on the signal is a leading `n` on the net.
ACTIVE_LOW = [(r"_(CS)(\d)_N$", r"_N\1\2"), (r"_([A-Z0-9]+)_N$", r"_N\1")]

#: Signals whose net is named differently from the signal, reviewed one by one.
ALIASES = {
    "sys_rst_n": ("SYS_RESET_N", "push-button SW2; the port is `btn0`"),
    "proc_rst_n": ("PROC_RST_N", "push-button SW3; the port is `btn1`"),
    "bus_to_fav_gpi": ("GPIN_PF", "payload-bus GPIO in, named from the bus side"),
    "bus_to_fav_pps": ("PPS", "payload-bus PPS, named from the bus side"),
    "bus_to_fav_trig": ("TRIG", "payload-bus trigger, named from the bus side"),
    "fav_to_bus_gpo": ("R_GPOUT", "payload-bus GPIO out, named from the bus side"),
    "cam_buff_en_n": ("IMX_CONTROL_BUF_nEN", "enable of the sensor control-line buffer"),
    "cam_miso": ("IMX_SPI_IMX_TO_PF_BUF", "sensor SPI, sensor to PolarFire"),
    "cam_mosi": ("IMX_SPI_PF_TO_IMX", "sensor SPI, PolarFire to sensor"),
    "cam_sck": ("IMX_SPI_SCK", "sensor SPI clock"),
    "cam_xce_n": ("IMX_SPI_XCE", "sensor SPI chip enable (XCE is active-low on the sensor)"),
    "cam_xclr_n": ("IMX_XCLR", "sensor clear (XCLR is active-low on the sensor)"),
    "cam_xtrig_primary": ("IMX_XTRIG1", "the primary trigger is the sensor's XTRIG1"),
    "cam_tout_primary": ("IMX_TOUT0_BUF", "the primary timing output is the sensor's TOUT0"),
    "nvm_spi_cs_n": ("R_QSPI_CE", "flash chip enable"),
    "pcie0_perstn": ("PCIE_nRESET", "PCIe PERST#"),
    "pcie_ext_ref_clk_p": ("PCIE_REF_CLK_P", "PCIe reference clock"),
    "pcie_ext_ref_clk_n": ("PCIE_REF_CLK_N", "PCIe reference clock"),
    "pri_stp_motor_en": ("R_PRIM_DRIVER_EN", "primary stepper driver enable"),
    "sec_stp_motor_en": ("R_SEC_DRIVER_EN", "secondary stepper driver enable"),
    "pri_stp_motor_sleep_n": ("R_PRIM_SLEEP", "driver nSLEEP; the net drops the n"),
    "sec_stp_motor_sleep_n": ("R_SEC_SLEEP", "driver nSLEEP; the net drops the n"),
    "ref_clk_148p5mhz_p": ("148.5MHZ_P", "camera transceiver reference clock"),
    "ref_clk_148p5mhz_n": ("148.5MHZ_N", "camera transceiver reference clock"),
    "sys_clk_50mhz": ("R_50MHZ_CLK_IN", "50 MHz oscillator"),
}

#: Signals on lines to the housekeeper whose housekeeper port is not named by
#: the conventions in `_hk_name`.
HK_ALIASES = {
    "uart0_rx": "rs422_ttl_bus_to_farsight_pf",
    "uart0_tx": "rs422_ttl_farsight_to_bus_pf",
}


def _canon_net(net):
    s = re.sub(r"^(R_|C_)", "", net.upper())
    return re.sub(r"_BUF$", "", s).replace("_", "")


def _named_for(signal, net):
    if ALIASES.get(signal, (None,))[0] == net:
        return True
    for rules in (RULES, RULES + ACTIVE_LOW):
        s = signal.upper()
        for a, b in rules:
            s = re.sub(a, b, s)
        s = s.replace("_", "")
        if s in (_canon_net(net), _canon_net(re.sub(r"^(R_)?PF_", "", net))):
            return True
    # DDR4 data bits may be swapped within their byte lane.
    m = re.match(r"^ddr4_r[02]_dq\[(\d+)\]$", signal)
    k = re.search(r"_DQ(\d+)$", net)
    if m and k and int(m.group(1)) // 8 == int(k.group(1)) // 8:
        return True
    return bool(re.search(r"_shield\d$", signal)) and net == "GND"


def _hk_name(signal):
    """The housekeeper port expected at the far end of a PolarFire signal."""
    if signal in HK_ALIASES:
        return HK_ALIASES[signal]
    s = re.sub(r"^cam_", "imx_", signal)
    s = re.sub(r"^ddr(\d+)gb_", r"ddr\1_", s)
    s = re.sub(r"_pwr_en$", "_ctrl", s)
    s = re.sub(r"_pwr_status$", "_status_to_pf", s)
    return re.sub(r"^pa3_fw_version", "fw_version", s)


def _housekeeper_end(sch, hk, net):
    """The housekeeper pins a PolarFire net reaches that its pinout uses."""
    return [(p, hk[p.number]) for p in sch.reach(net) if p.component == HK and p.number in hk]


def test_PF_IO_05_ports_match_avionics_pinout(calc):
    """VC-PF-0018: every top-level port on the package pin named for its signal."""
    r = calc("PF-IO-05", "every top-level port on the package pin defined for it")
    b = retained()
    r.given("Build", b.root.name, "", "commit %s; no design source changed since" % b.commit)
    sch, hk = board.schematic(), board.housekeeper_pins()
    built = board.pin_report(b.designer)
    pins, ports = board.pin_map(), board.constrained_ports()
    r.given("Pinout definition", sch.name, "", "PolarFire %s, %d pins with nets"
            % (PF, sum(1 for k in sch.pins if k[0] == PF)))
    r.given("Housekeeper pinout", "%d constrained pins" % len(hk), "",
            board.HK_PINOUT.relative_to(board.WORKSPACE))
    r.given("Ports placed", len(built), "", b.cite(b.designer / "top_pinrpt_number.rpt"))
    r.given("Ports constrained", len(ports), "", board.IO_PDC.relative_to(REPO))

    problems, named, aliased, far, dq, shield = [], 0, 0, 0, 0, 0
    for port, (pin, direction, state, line) in sorted(built.items()):
        signal = ports[port][0] if port in ports else port
        if port not in ports and state != "Dedicated":
            problems.append("%s at %s is placed by the tool: no constraint names it" % (port, pin))
        if signal not in pins:
            problems.append("%s: no `pins.tcl` entry for %s" % (port, signal))
            continue
        if pins[signal][0] != pin:
            problems.append("%s: constrained to %s (%s) but placed at %s" % (
                port, pins[signal][0], _rel(board.PINS, pins[signal][2]), pin))
        p = sch.pin(PF, pin)
        if p is None:
            problems.append("%s: pin %s is not in the schematic" % (port, pin))
            continue
        ends = _housekeeper_end(sch, hk, p.net)
        if ends:
            far += 1
            for q, (hk_port, hk_dir, where) in ends:
                generic = signal.startswith("pa3_to_pf_misc")
                if hk_dir == direction:
                    problems.append(
                        "%s (%s, %s) and housekeeper `%s` (%s, %s) both drive net %s/%s: a "
                        "%s on a %s" % (port, pin, direction.lower(), hk_port, q.number,
                                        hk_dir.lower(), p.net, q.net, direction.lower(),
                                        direction.lower()))
                elif not generic and hk_port != _hk_name(signal):
                    problems.append(
                        "%s (%s) reads or drives housekeeper `%s` (%s, %s), not `%s`"
                        % (port, pin, hk_port, q.number, where, _hk_name(signal)))
            continue
        if _named_for(signal, p.net):
            if signal in ALIASES:
                aliased += 1
            elif re.match(r"^ddr4_r[02]_dq\[", signal) and not p.net.endswith(
                    "DQ%s" % re.search(r"\[(\d+)\]", signal).group(1)):
                dq += 1
            elif "shield" in signal:
                shield += 1
            else:
                named += 1
        else:
            problems.append("%s at %s: net %s (%s) is not named for `%s`"
                            % (port, pin, p.net, sch.cite(p), signal))
    for port, (signal, line) in ports.items():
        if port not in built:
            problems.append("%s (%s) constrains a port the design does not have"
                            % (port, _rel(board.IO_PDC, line)))
    r.step("%d ports on a net named for their signal by convention; %d on a reviewed alias "
           "(listed in the test); %d DDR4 data bits swapped within their byte lane; %d DDR4 "
           "shield pins on GND; %d on lines to the housekeeper, checked against its pinout"
           % (named, aliased, dq, shield, far))

    # The direction attribute in `pins.tcl` is passed to `set_io`, which the
    # build accepts silently whatever it says: recorded, not judged here.
    def stated(port):
        return pins.get(ports.get(port, (port,))[0], (None, None))[1]
    wrong = sorted(port for port, (pin, direction, _, _) in built.items()
                   if direction and stated(port) not in (None, "INOUT", direction))
    r.step("`pins.tcl` gives the wrong DIRECTION for %d ports, which the build ignores "
           "without a warning: %s" % (len(wrong), ", ".join(wrong)))
    for x in problems:
        r.step("**Mismatch:** " + x)
    assert not problems, "%d mismatches: %s" % (len(problems), "; ".join(problems))


# VSC8541 inputs: the pins through which the PolarFire can drive the PHY.
PHY_INPUTS = ["TX_EN/TX_CTL", "GTX_CLK", "TXD0", "TXD1", "TXD2", "TXD3", "MDC", "MDIO",
              "NRESET", "COMA_MODE", "CLK_SQUELCH_IN"]


def _eth2_phy(sch, pins):
    """The ETH2 PHY: the VSC8541 whose reset comes from the PolarFire's ETH2 reset pin."""
    pin = pins["eth2_phy_rst_n"][0]
    net = sch.pin(PF, pin).net
    for p in sch.reach(net):
        if "VSC8541" in sch.parts[p.component][0] and p.name == "NRESET":
            return p.component
    raise AssertionError("no VSC8541 reset reaches PolarFire pin %s" % pin)


def _drivers(text, port):
    """How top.tcl drives a top-level port: ('constant', value, line) or ('net', pins, line)."""
    m = re.search(r"^sd_connect_pins_to_constant -sd_name \$\{sd_name\} -pin_names \{%s\} "
                  r"-value \{(\w+)\}" % re.escape(port), text, re.M)
    if m:
        return ("constant", m.group(1), text.count("\n", 0, m.start()) + 1)
    for m in re.finditer(r"^sd_connect_pins -sd_name \$\{sd_name\} -pin_names \{(.*)\}\s*$", text, re.M):
        names = re.findall(r'"([^"]+)"', m.group(1))
        if port in names:
            return ("net", [n for n in names if n != port], text.count("\n", 0, m.start()) + 1)
    return (None, None, None)


def test_PF_ETH_09_unused_eth2_outputs_inactive(calc):
    """VC-PF-0102: every PolarFire line into the unused ETH2 PHY held inactive."""
    r = calc("PF-ETH-09", "PolarFire outputs into the unused ETH2 PHY")
    b = retained()
    r.given("Build", b.root.name, "", "commit %s; no design source changed since" % b.commit)
    sch, pins = board.schematic(), board.pin_map()
    built = board.pin_report(b.designer)
    by_pin = {v[0]: k for k, v in built.items()}
    text = TOP.read_text()
    phy = _eth2_phy(sch, pins)
    r.given("ETH2 PHY", "%s, %s" % (phy, sch.parts[phy][0]), "",
            "%s; found as the PHY whose NRESET is on the PolarFire's ETH2 reset" % sch.name)
    r.given("PHY inputs", ", ".join(PHY_INPUTS), "", "VSC8541 datasheet, pin descriptions")
    unused = find(b.designer / "top_pinrpt_boardlayout.rpt", r"Libero configures unused User IO.*")
    r.input("Unused I/O", unused)
    r.step("Inactive is low on every line: the PHY's supplies are switched by the housekeeper "
           "and off unless ETH2 power is requested, so a high level back-drives an unpowered "
           "device; and NRESET low holds a powered PHY in reset, where the other inputs are "
           "ignored")
    problems = []
    for name in PHY_INPUTS:
        p = next((q for q in sch.of[phy] if q.name == name), None)
        if p is None:
            problems.append("PHY pin %s not found" % name)
            continue
        for q in (e for e in sch.reach(p.net) if e.component == PF):
            port = by_pin.get(q.number)
            if port is None:
                r.step("%s (%s) <- PolarFire %s: **no port; left as unused I/O, tristated "
                       "with a weak pull-up**" % (name, p.net, q.number))
                problems.append("%s from %s is unused I/O (tristated, weak pull-up)" % (name, q.number))
                continue
            kind, what, line = _drivers(text, port)
            r.step("%s (%s) <- PolarFire %s `%s`: %s %s (`%s`)" % (
                name, p.net, q.number, port, "tied to" if kind == "constant" else "driven by",
                what if kind == "constant" else ", ".join(what or []), _rel(TOP, line or 0)))
            if kind != "constant" or what != "GND":
                problems.append("%s from %s `%s` is %s" % (name, q.number, port,
                                                           "tied to %s" % what if kind == "constant"
                                                           else "fabric-driven"))
    assert not problems, "; ".join(problems)


def test_PF_ETH_10_eth2_power_housekeeper_only(calc):
    """VC-PF-0104: ETH2 power enable and status reach only the housekeeper hierarchy."""
    r = calc("PF-ETH-10", "ETH2 power enable and status, PolarFire side and board")
    b = retained()
    r.given("Build", b.root.name, "", "commit %s; no design source changed since" % b.commit)
    sch, hk, pins = board.schematic(), board.housekeeper_pins(), board.pin_map()
    text, hk_text = TOP.read_text(), HK_HIER.read_text()
    problems = []
    for port, inner_dir in (("eth2_pwr_en", "out"), ("eth2_pwr_status", "in")):
        kind, others, line = _drivers(text, port)
        r.step("`%s` connects to %s (`%s`)" % (port, ", ".join(others or []), _rel(TOP, line or 0)))
        if kind != "net" or any(not o.startswith("hk_hier_inst:") for o in others):
            problems.append("`%s` reaches %s, not only the housekeeper hierarchy" % (port, others))
        inner = _drivers(hk_text, port)
        r.step("inside `hk_hier`, `%s` is %s (`%s`)" % (port, ", ".join(inner[1] or []),
                                                       _rel(HK_HIER, inner[2] or 0)))
        net = sch.pin(PF, pins[port][0]).net
        ends = _housekeeper_end(sch, hk, net)
        for q, (hk_port, hk_dir, where) in ends:
            r.step("on the board, %s (%s) runs to housekeeper `%s` (%s, %s)"
                   % (pins[port][0], net, hk_port, hk_dir.lower(), where))
        wanted = "INPUT" if inner_dir == "out" else "OUTPUT"
        if not any(d == wanted and h.startswith("eth2_") for _, (h, d, _w) in ends):
            problems.append("`%s` does not run to an ETH2 %s of the housekeeper"
                            % (port, wanted.lower()))
    for inst in ("eth1_hier_inst", "udp_hier_inst", "eth_pcie_mux_hier_inst"):
        for port in ("eth2_pwr_en", "eth2_pwr_status"):
            if re.search(r'"%s"[^\n]*"%s:' % (port, inst), text):
                problems.append("`%s` reaches %s" % (port, inst))
    r.step("Neither line reaches a network-path instance (eth1_hier, udp_hier, eth_pcie_mux_hier)"
           if not problems else "Problems: %d" % len(problems))
    assert not problems, "; ".join(problems)


# --------------------------------------------------------------------------
# PF-IO-01, PF-IO-02, PF-IO-03: the clock and camera inputs, pin to board
# --------------------------------------------------------------------------

CAM_RX = BD / "cam_rx_hier" / "components"
OVERBAR = re.compile(r"^(\\\w)+\\?$")      # Altium's \O\U\T\ -- an overbarred name


def _placed(r, port, problems):
    """The port's package pin, as constrained, as built and on the board."""
    pins, sch = board.pin_map(), board.schematic()
    if port not in pins:
        problems.append("`%s` has no pin in %s" % (port, board.PINS.name))
        return None
    pin, _, line = pins[port]
    b = retained()
    built = board.pin_report(b.designer).get(port)
    p = sch.pin(PF, pin)
    r.given("`%s`" % port, "pin %s (%s), built at %s, net %s"
            % (pin, p.name if p else "no such pin", built[0] if built else "nowhere",
               p.net if p else "none"), "",
            "%s; %s; %s" % (_rel(board.PINS, line),
                            b.cite(b.designer / "top_pinrpt_number.rpt", built[3]) if built else "pin report",
                            sch.cite(p) if p else sch.name))
    if not built or built[0] != pin:
        problems.append("`%s` is constrained to %s but built at %s" % (port, pin, built[0] if built else "nowhere"))
    if not p:
        problems.append("the schematic has no PolarFire pin %s for `%s`" % (pin, port))
    return p


def test_PF_IO_01_single_ended_50mhz_input(calc):
    """VC-PF-0133: the 50 MHz reference arrives single-ended at a clock input."""
    r = calc("PF-IO-01", "the 50 MHz system reference, pin to oscillator")
    problems = []
    std = r.input("I/O standard", find(board.PINS, r'^dict set pins \{sys_clk_50mhz\}.*io_std "(\w+)"'))
    if not str(std).startswith("LVCMOS"):
        problems.append("`sys_clk_50mhz` is %s, not a single-ended standard" % std)
    p = _placed(r, "sys_clk_50mhz", problems)
    if p is not None:
        if "CLKIN" not in p.name:
            problems.append("pin %s (%s) is not a clock input" % (p.number, p.name))
        sch = board.schematic()
        drivers = [q for q in sch.reach(p.net) if q.component.startswith("Y")]
        for q in drivers:
            outs = [x for x in sch.of[q.component] if "OUTPUT" in x.name.replace("\\", "")]
            part = sch.parts[q.component][0]
            mhz = oscillator(part).mhz
            r.given("Driven by %s" % q.component, "%s, %g MHz, pin %s (%s); %d output pin(s)"
                    % (part, mhz, q.number, q.name, len(outs)), "", sch.cite(q))
            if len(outs) != 1:
                problems.append("%s has %d outputs: a differential source on a single-ended input"
                                % (q.component, len(outs)))
            if abs(mhz - 50.0) > 1e-6:
                problems.append("%s is %g MHz, not 50" % (q.component, mhz))
        if not drivers:
            problems.append("net %s reaches no oscillator" % p.net)
    r.input("Into the fabric through a global clock buffer", find(TOP, r'"(sys_clk_50mhz" "sys_clkint_buf_inst:A)"'))
    assert not problems, "; ".join(problems)


def test_PF_IO_02_differential_148p5mhz_reference(calc):
    """VC-PF-0134: the 148.5 MHz reference arrives differential at the transceiver's reference."""
    r = calc("PF-IO-02", "the 148.5 MHz camera reference, pin pair to oscillator")
    problems = []
    sch = board.schematic()
    nets = {}
    for side in ("p", "n"):
        p = _placed(r, "ref_clk_148p5mhz_%s" % side, problems)
        if p is None:
            continue
        nets[side] = p
        if not p.name.endswith("REFCLK_%s" % side.upper()):
            problems.append("pin %s (%s) is not the %s side of a transceiver reference" % (p.number, p.name, side.upper()))
    if len(nets) == 2:
        ys = sorted({q.component for side in nets for q in sch.reach(nets[side].net) if q.component.startswith("Y")})
        for y in ys:
            part = sch.parts[y][0]
            mhz = oscillator(part).mhz
            true = next((x for x in sch.of[y] if x.name == "OUTPUT"), None)
            comp = next((x for x in sch.of[y] if OVERBAR.match(x.name) and "O" in x.name), None)
            r.given("Option %s" % y, "%s, %g MHz: OUTPUT pin %s on %s, complement pin %s on %s"
                    % (part, mhz, true.number if true else "-", true.net if true else "-",
                       comp.number if comp else "-", comp.net if comp else "-"), "", sch.cite(true or sch.of[y][0]))
            if not true or not comp:
                problems.append("%s has no complementary output pair" % y)
            elif (true.net, comp.net) != (nets["p"].net, nets["n"].net):
                problems.append("%s drives P with %s and N with %s: the pair is crossed or misrouted"
                                % (y, true.net, comp.net))
            if abs(mhz - 148.5) > 1e-6:
                problems.append("%s is %g MHz, not 148.5" % (y, mhz))
        if not ys:
            problems.append("the reference pins reach no oscillator")
    mode = r.input("Reference buffer mode", core_param(BD / "top" / "components" / "PF_XCVR_REF_CLK_C0.tcl", "REF_CLK_MODE_0"))
    if str(mode) != "DIFFERENTIAL":
        problems.append("the reference buffer is %s, not differential" % mode)
    for side in ("P", "N"):
        r.input("Pad %s" % side, find(TOP, r'"(cam_xcvr_ref_clk_inst:REF_CLK_PAD_%s" "ref_clk_148p5mhz_%s)"' % (side, side.lower())))
    r.input("To the camera receiver's CDR reference", find(TOP, r'"(cam_rx_inst:cdr_ref_clk_148p5mhz" "cam_xcvr_ref_clk_inst:REF_CLK)"'))
    for tcl in sorted(CAM_RX.glob("PF_XCVR_ERM_C*.tcl")):
        f = r.input("CDR reference expected by %s" % tcl.stem, core_param(tcl, "UI_CDR_REFERENCE_CLK_FREQ"), "MHz")
        if abs(float(f) - 148.5) > 1e-6:
            problems.append("%s expects a %s MHz reference" % (tcl.stem, f))
    assert not problems, "; ".join(problems)


def test_PF_IO_03_eight_differential_camera_lanes(calc):
    """VC-PF-0135: eight differential camera lanes, each pair to its own lane at the camera connector."""
    r = calc("PF-IO-03", "the eight camera lanes, pin pair to connector")
    problems = []
    sch = board.schematic()
    connectors = set()
    for lane in range(8):
        pair = {}
        for side in ("p", "n"):
            port = "cam_lane%d_rxd_%s" % (lane, side)
            p = _placed(r, port, problems)
            if p is None:
                continue
            pair[side] = p
            if not re.search(r"XCVR_\d+_RX\d_%s$" % side.upper(), p.name):
                problems.append("`%s` is on %s, not a transceiver receive %s pin" % (port, p.name, side.upper()))
            want = "SLVS_EC_%d_%s" % (lane, side.upper())
            if p.net != want:
                problems.append("`%s` is on net %s, not %s" % (port, p.net, want))
            js = sorted({"%s pin %s" % (q.component, q.number) for q in sch.reach(p.net) if q.component.startswith("J")})
            connectors |= {j.split()[0] for j in js}
            if len(js) != 1:
                problems.append("net %s reaches %s, not one connector pin" % (p.net, js or "no connector"))
        for side in ("p", "n"):
            port = "cam_lane%d_rxd_%s" % (lane, side)
            if not re.search(r'"%s" "cam_rx_inst:%s"' % (port, port), TOP.read_text()):
                problems.append("`%s` does not reach the camera receiver" % port)
    r.given("Camera connector", ", ".join("%s (%s)" % (j, sch.parts[j][0]) for j in sorted(connectors)) or "none",
            "", sch.name)
    if len(connectors) != 1:
        problems.append("the lanes reach %d connectors, not one" % len(connectors))
    r.step("Eight pairs, each on a transceiver receive P/N pair, on the net of its own lane and "
           "polarity, to one camera connector, and into the camera receiver" if not problems
           else "Problems: %d" % len(problems))
    assert not problems, "; ".join(problems)


# --------------------------------------------------------------------------
# PF-IO-04: both DDR4 interfaces, at their pin groups, to their devices
# --------------------------------------------------------------------------

#: Each interface: its constraint prefix, the hierarchy its ports connect to,
#: and the DRAM part the board fits.
DDR4_IFACES = {"16 GB": ("ddr4_r0_", "ddr4_16gb_group_hier_inst"),
               "8 GB": ("ddr4_r2_", "ddr4_8gb_group_hier_inst")}
DRAM = re.compile(r"^MT40A")


def test_PF_IO_04_ddr4_interfaces_at_their_pins(calc):
    """VC-PF-0136: both DDR4 interfaces, constrained, built and wired to their own devices."""
    r = calc("PF-IO-04", "both DDR4 interfaces, pin group to devices")
    problems = []
    sch, pins = board.schematic(), board.pin_map()
    b = retained()
    built = board.pin_report(b.designer)
    top = TOP.read_text()
    devices = {}
    for label, (prefix, hier) in DDR4_IFACES.items():
        ports = sorted(k for k in pins if k.startswith(prefix))
        signals = [k for k in ports if "shield" not in k and "ext_ref" not in k]
        bases = sorted({re.sub(r"\[\d+\]$", "", k) for k in ports})
        unconnected = [p for p in bases if not re.search(r'"%s:\w+" "%s"' % (hier, re.escape(p)), top)]
        not_ports = [p for p in unconnected if "ext_ref" in p]
        for p in sorted(set(unconnected) - set(not_ports)):
            problems.append("%s: `%s` is not a top-level port of %s" % (label, p, hier))
        reached, misplaced, stray = {}, [], []
        for k in signals:
            pin = pins[k][0]
            if not built.get(k) or built[k][0] != pin:
                misplaced.append("%s (constrained %s, built %s)" % (k, pin, built[k][0] if k in built else "nowhere"))
            p = sch.pin(PF, pin)
            ends = [q for q in sch.reach(p.net) if q.component != PF]
            drams = {q.component for q in ends if DRAM.match(sch.parts[q.component][0])}
            others = {q.component for q in ends if q.component not in drams and not q.component[:1] in "RC"}
            if not drams or others:
                stray.append("%s (net %s reaches %s)" % (k, p.net, sorted(others) or "no DRAM"))
            for d in drams:
                reached[d] = reached.get(d, 0) + 1
        shields = [k for k in ports if "shield" in k]
        bad_shield = [k for k in shields if sch.pin(PF, pins[k][0]).net != "GND"]
        r.given("%s interface" % label, "%d signals and %d shields constrained (`%s*`), into %s"
                % (len(signals), len(shields), prefix, hier), "", "%s; %s" % (board.PINS.relative_to(REPO), TOP.relative_to(REPO)))
        r.step("%s: every signal built at its constrained pin%s" % (label, "" if not misplaced else "; **not**: " + "; ".join(misplaced[:5])))
        part = sorted({sch.parts[d][0] for d in reached})
        r.given("%s devices" % label, "%s: %s" % (", ".join(part), ", ".join("%s (%d signals)" % (d, n) for d, n in sorted(reached.items()))),
                "", sch.name)
        counts = set(reached.values())
        if len(counts) > 1:
            problems.append("%s: the devices receive different numbers of FPGA signals, %s" % (label, sorted(reached.items())))
        r.step("%s: shields %s" % (label, "all on GND" if not bad_shield else "not on GND: %s" % bad_shield))
        for k in not_ports:
            if k in pins:
                net = sch.pin(PF, pins[k][0]).net
                pin = pins[k][0]
                r.step("%s: `%s` is constrained to %s, where the board brings net %s, but is no port "
                       "of the design (%s in the build); the controller uses its internal reference"
                       % (label, k, pin, net, "unassigned" if k not in built else built[k][2]))
        problems += ["%s: %s not built at its constrained pin" % (label, m) for m in misplaced]
        problems += ["%s: %s" % (label, s) for s in stray]
        problems += ["%s: shield %s is not grounded" % (label, k) for k in bad_shield]
        devices[label] = set(reached)
    if devices and len(set.union(*devices.values())) != sum(len(v) for v in devices.values()):
        problems.append("the two interfaces share devices: %s" % sorted(set.intersection(*devices.values())))
    r.step("Both interfaces exposed, built at their pins, each wired to its own DRAM devices only"
           if not problems else "Problems: %d" % len(problems))
    assert not problems, "; ".join(problems)


# --------------------------------------------------------------------------
# PF-TRIG-05, PF-PPS-06, PF-PPS-08: polarity from the FPGA to the board's edge
# --------------------------------------------------------------------------

HK_TCL = BD / "hk_hier" / "components" / "hk_hier.tcl"
CAM_RX = BD / "cam_rx_hier" / "components"
PPS_HIER = BD / "pps_hier" / "components" / "pps_hier.tcl"
#: Board parts on these paths, and why each passes a level through uninverted:
#: the part family's function, by part number.
NON_INVERTING = {"SN74LVC244": "octal buffer, nY = nA when its OE is low",
                 "SN65LVDS32": "LVDS receiver, Y high when A is above B"}


def _family(part: str) -> str | None:
    return next((f for f in NON_INVERTING if part.startswith(f)), None)


def _through(sch, net: str, component: str, pin_in: str, pin_out: str, r, label: str, problems):
    """The other side of a buffer channel: (net out) or None, recorded."""
    p_in = next((p for p in sch.of[component] if p.name.replace("\\", "") == pin_in), None)
    p_out = next((p for p in sch.of[component] if p.name.replace("\\", "") == pin_out), None)
    part = sch.parts[component][0]
    fam = _family(part)
    r.given(label, "%s %s (%s): %s on %s -> %s on %s" % (component, part, NON_INVERTING.get(fam, "unknown function"),
            pin_in, p_in.net if p_in else "-", pin_out, p_out.net if p_out else "-"), "", sch.cite(p_in or sch.of[component][0]))
    if not fam:
        problems.append("%s (%s) is not a part whose polarity this inspection knows" % (component, part))
    if not p_in or not p_out or p_in.net != net:
        problems.append("%s channel %s/%s is not on %s" % (component, pin_in, pin_out, net))
        return None
    return p_out.net


def _beyond_resistor(sch, net: str) -> str:
    """Across a series resistor on `net`, the net on its other side."""
    r = next(p for p in sch.nets[net] if p.component.startswith("R"))
    return next(q.net for q in sch.of[r.component] if q.number != r.number)


def test_PF_TRIG_05_trigger_polarity_to_sensor(calc):
    """VC-PF-0139: the trigger reaches the sensor connector uninverted, and the
    buffer opens only with camera power-good, with the sensor held in reset."""
    r = calc("PF-TRIG-05", "the trigger's level from the FPGA pin to the sensor connector")
    problems = []
    sch = board.schematic()
    p = _placed(r, "cam_xtrig_primary", problems)
    out = _through(sch, p.net, "U59", "2A2", "2Y2", r, "Trigger buffer", problems) if p else None
    if out:
        far = _beyond_resistor(sch, out)
        js = [q for q in sch.nets[far] if q.component.startswith("J")]
        r.given("Through the series resistor to", "net %s, %s" % (far, ", ".join(
            "%s pin %s" % (q.component, q.number) for q in js) or "no connector"), "", sch.name)
        if [q.component for q in js] != ["J7"]:
            problems.append("the buffered trigger reaches %s, not the camera connector J7" % [q.component for q in js])
    oe = [q for q in sch.of["U59"] if "OE" in q.name.replace("\\", "")]
    oe_net = {q.net for q in oe}
    en = _placed(r, "cam_buff_en_n", problems)
    pulls = [x for q in sch.nets.get(next(iter(oe_net)), []) if q.component.startswith("R")
             for x in sch.of[q.component] if x.net != next(iter(oe_net))]
    r.given("Buffer enables", "%s, on %s; pulled to %s" % (", ".join(q.name.replace("\\", "") for q in oe),
            ", ".join(oe_net), ", ".join(x.net for x in pulls) or "nothing"), "", sch.cite(oe[0]))
    if len(oe_net) != 1 or not en or en.net not in oe_net:
        problems.append("U59's enables are not the FPGA's `cam_buff_en_n`")
    if not any(re.match(r"^\dV\d", x.net) for x in pulls):
        problems.append("U59's enable is not pulled to a rail: it floats before the FPGA drives it")
    inv = r.input("`cam_buff_en_n` is the inverse of camera power-good",
                  find(HK_TCL, r'"(cam_pwr_status" "cam_spi_tribuff_en" "gpi_hk_status_inst:GPIO_IN\[11:11\]" "inv_cam_buff_en_n_inst:A)"'))
    r.input("and the inverter drives it", find(HK_TCL, r'"(cam_buff_en_n" "inv_cam_buff_en_n_inst:Y)"'))
    r.input("The trigger block's `en` is the same power-good",
            find(TOP, r'"(cam_rx_inst:cam_en" "cam_spi_mosi_tribuf_inst:E" "cam_spi_sck_tribuf_inst:E" "cam_spi_xce_n_tribuf_inst:E" "hk_hier_inst:cam_spi_tribuff_en)"'))
    r.input("into `cam_trig`'s state machine, unsynchronised", find(REPO / "ip" / "cam_trig_ip" / "src" / "cam_trig.sv", r"(if \(en\) begin)"))
    r.input("whose output is registered from the state",
            find(REPO / "ip" / "cam_trig_ip" / "src" / "cam_trig.sv", r"(xtrig\s+<= \(curr_state != XTRIG_LOW_PERIOD\) && \(curr_state != OFF\);)"))
    r.step("So the buffer opens as power-good rises, while `xtrig` is still low for one to two "
           "clocks: **20 to 40 ns of uncommanded low at the connector**, once per camera power-up")
    xclr = _placed(r, "cam_xclr_n", problems)
    xout = _through(sch, xclr.net, "U59", "1A1", "1Y1", r, "Sensor reset buffer", problems) if xclr else None
    r.input("The sensor's reset comes from camera GPO bit 0", find(CAM_RX / "cam_rx_hier.tcl", r'"(cam_xclr_n" "gpo_cam_ctrl_inst:GPIO_OUT\[0:0\])"'))
    val = r.input("which resets to", core_param(CAM_RX / "CoreGPIO_C0.tcl", "IO_VAL_0"))
    fw = FLIGHT_SW / "Camera" / "src" / "camera.c"
    if fw.is_file():
        text = fw.read_text()
        lo = re.search(r"GPIO_set_output\(&instance->cam_ctrl, CAM_XCLR_N, 0u\);", text)
        hi = re.search(r"GPIO_set_output\(&instance->pwr_ctrl, CAM_PWR_EN, 1u\);.*?vTaskDelay\((\d+)\);\s*GPIO_set_output\(&instance->cam_ctrl, CAM_XCLR_N, 1u\);", text, re.S)
        r.given("Flight software", "holds XCLR low before cutting power, and releases it %s ms after enabling it"
                % (hi.group(1) if hi else "?"), "", "%s; %s" % (_fwcite(fw, text, lo), _fwcite(fw, text, hi)))
        if not lo or not hi:
            problems.append("flight software does not hold the sensor in reset across power-up")
    if str(val) != "0":
        problems.append("the sensor's reset GPO does not reset low")
    r.step("The low reaches a sensor held in reset (XCLR low, from the GPO's reset value and "
           "flight software), so it cannot start an exposure" if not problems else "Problems: %d" % len(problems))
    assert not problems, "; ".join(problems)


def _fwcite(path, text, m):
    return "%s:%d" % (path.relative_to(WORKSPACE), text.count("\n", 0, m.start()) + 1) if m else str(path.name)


def test_PF_PPS_06_external_pps_polarity(calc):
    """VC-PF-0140: a rising edge of the bus's PPS reaches the PPS block as a rising edge."""
    r = calc("PF-PPS-06", "the external PPS's polarity from the bus connector to the PPS block")
    problems = _pps_path(r)
    r.input("The external input raises the interrupt on its rising edge",
            find(REPO / "ip" / "pps_ip" / "src" / "pps.sv", r"(if\(extrn_pps_in_sync\[2:1\] == 2'b01\) begin)"))
    assert not problems, "; ".join(problems)


def test_PF_PPS_08_mux_external_is_bus_pps(calc):
    """VC-PF-0141: the mux's external input is the bus's PPS, uninverted."""
    r = calc("PF-PPS-08", "what the PPS mux's external input is, on the board")
    problems = _pps_path(r)
    r.input("The mux's external input is that pin", find(PPS_HIER, r'"(pps_in" "pps_inst:extrn_pps_in" "pps_mux_inst:extrn_pps_in)"'))
    r.input("and it selects by the firmware bit", find(REPO / "ip" / "pps_ip" / "src" / "pps_mux.sv",
            r"(assign pps_out = en_local_pps \? local_pps_in : extrn_pps_in;)"))
    assert not problems, "; ".join(problems)


def _pps_path(r) -> list:
    problems = []
    sch = board.schematic()
    p = _placed(r, "bus_to_fav_pps", problems)
    if p:
        inner = _beyond_resistor(sch, p.net)
        rx = next((q for q in sch.nets[inner] if q.component.startswith("U")), None)
        if not rx:
            problems.append("net %s reaches no receiver" % inner)
        else:
            ch = rx.name[0]
            a = next(q for q in sch.of[rx.component] if q.name == ch + "A")
            b = next(q for q in sch.of[rx.component] if q.name == ch + "B")
            _through(sch, a.net, rx.component, ch + "A", ch + "Y", r, "PPS receiver", problems)
            r.given("Receiver inputs", "%sA on %s, %sB on %s" % (ch, a.net, ch, b.net), "", sch.cite(a))
            for q, want in ((a, "P"), (b, "N")):
                js = [x for x in sch.nets[q.net] if x.component.startswith("J")]
                r.given("%s side" % want, "%s to %s" % (q.net, ", ".join("%s pin %s" % (x.component, x.number) for x in js)), "", sch.name)
                if not q.net.endswith("_" + want) or not js:
                    problems.append("%s%s is on %s: the pair is %s" % (ch, "A" if want == "P" else "B", q.net,
                                    "swapped, so the edge is inverted" if q.net.endswith("_" + ("N" if want == "P" else "P"))
                                    else "not from a connector"))
    r.input("The pin enters the fabric through an input buffer",
            find(TOP, r'"(bus_to_fav_pps_inbuf_inst:Y" "dbg_mux_inst:pps_in" "pps_hier_inst:pps_in)"'))
    r.step("Rising at the bus connector, rising at the PPS block" if not problems else "Problems: %d" % len(problems))
    return problems
