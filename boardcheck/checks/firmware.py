"""Firmware against the schematic.

ADC channel maps. Firmware often names each telemetry channel in a C enum
whose position selects the ADC and its input (for CM-03545's tlm_adc.c:
input = index & 7, chip select = index >> 3). The check follows each entry
from the source files to the board: the SPI select the firmware asserts is
a SmartDesign pin (SPISS[n] of the SPI core), connected to a top-level
port, constrained to an FPGA ball, wired (through series resistors) to one
ADC's chip select; the channel number picks that ADC's input pin, whose net
names the signal the board actually feeds it. That name must match the
firmware's. Configure under `firmware.adc_channel_maps` (paths relative to
the config file, as for `fpga`).
"""

import os
import re

from . import ERROR, INFO, WARNING, Finding, check
from .levels import signals
from .pins import _pin_types
from ..model import natural_key


def parse_enum(path, enum_name):
    """[(name, value)] of a C typedef enum, honouring explicit values."""
    with open(path, encoding="utf-8", errors="replace") as f:
        text = f.read()
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    text = re.sub(r"//[^\n]*", " ", text)
    m = re.search(r"typedef\s+enum\s*\w*\s*\{([^}]*)\}\s*" + re.escape(enum_name) + r"\s*;", text)
    if not m:
        m = re.search(r"enum\s+" + re.escape(enum_name) + r"\s*\{([^}]*)\}", text)
    if not m:
        raise ValueError(f"enum {enum_name} not found in {path}")
    out, value = [], 0
    for item in (x.strip() for x in m.group(1).split(",")):
        if not item:
            continue
        name, _, expr = item.partition("=")
        if expr.strip():
            value = int(expr.strip(), 0)
        out.append((name.strip(), value))
        value += 1
    return out


class ChannelMap:
    def __init__(self, ctx, spec):
        self.ctx = ctx
        self.spec = spec
        self.name = spec.get("name", spec.get("enum", "adc map"))
        self.problems = []
        self.entries = []           # (fw name, stem, select, channel, adc pin or None, net or None)
        self.adcs = {}              # select -> ADC component
        self._build()

    def _path(self, p):
        return os.path.normpath(os.path.join(self.ctx.config.base_dir, os.path.expanduser(p)))

    def _build(self):
        spec, ctx = self.spec, self.ctx
        path = self._path(spec["enum_file"])
        if not os.path.isfile(path):
            self.problems.append(f"enum file not found: {path}")
            return
        try:
            enum = parse_enum(path, spec["enum"])
        except ValueError as e:
            self.problems.append(str(e))
            return
        skip = set(spec.get("skip") or [])
        per = int(spec.get("channels_per_select", 8))
        comp = ctx.design.components.get(spec["fpga"])
        f = ctx.fpga_for(comp) if comp is not None else None
        if f is None:
            self.problems.append(f"FPGA {spec['fpga']} constraints not available")
            return
        sel_re = spec["select_link"]
        by_port = {c.port: c for c in f.io.pins.values()}
        pins = {str(p.designator): p for p in comp.pins}
        by_net = {n: s for s in signals(ctx) for n in s.nets}
        cs_name = spec.get("adc_select_pin", "CS")
        in_fmt = spec.get("adc_input_pin", "IN{ch}")
        for select in sorted({v // per for n, v in enum if n not in skip}):
            link = re.compile(sel_re.format(n=select))
            ports = [p for p, links in f.io.port_links.items() if any(link.search(x) for x in links)]
            if not ports:
                self.problems.append(f"select {select}: no top-level port connects to /{link.pattern}/")
                continue
            c = by_port.get(ports[0])
            pin = pins.get(c.ball) if c else None
            sig = by_net.get(pin.net) if pin else None
            adcs = [q for q in (sig.pins if sig else []) if q.component is not comp and q.name == cs_name]
            if len(adcs) != 1:
                self.problems.append(f"select {select} ('{ports[0]}'): reaches {len(adcs)} '{cs_name}' pins "
                                     f"({', '.join(q.ref for q in adcs) or 'none'})")
                continue
            self.adcs[select] = adcs[0].component
        prefix = spec.get("strip_prefix", "")
        for name, value in enum:
            if name in skip:
                continue
            select, ch = value // per, value % per
            stem = name[len(prefix):] if prefix and name.startswith(prefix) else name
            adc = self.adcs.get(select)
            pin = None
            if adc is not None:
                pin = next((p for p in adc.pins if p.name == in_fmt.format(ch=ch)), None)
            self.entries.append((name, stem, select, ch, pin, pin.net if pin else None))

    def net_stem(self, net):
        s = net
        for rx in self.spec.get("net_strip") or []:
            s = re.sub(rx, "", s)
        return s


def _maps(ctx):
    if not hasattr(ctx, "_fw_maps"):
        ctx._fw_maps = [ChannelMap(ctx, spec) for spec in (ctx.config["firmware"]["adc_channel_maps"] or [])]
    return ctx._fw_maps


@check("FW001", "Firmware ADC channel reads a different signal than it names", ERROR)
def channel_names(ctx):
    for m in _maps(ctx):
        for p in m.problems:
            yield Finding("FW001", f"{m.name}: {p}", severity=WARNING)
        for name, stem, select, ch, pin, net in m.entries:
            if pin is None:
                continue
            if m.net_stem(net).upper() != stem.upper():
                yield Finding("FW001", f"{m.name}: firmware '{name}' reads {pin.ref} {pin.name} (select {select}), "
                                       f"which the schematic wires to '{net}'", refs=[pin.component.designator],
                              nets=[net])


@check("FW002", "ADC channel wired but unread, or read but unwired", WARNING)
def channel_coverage(ctx):
    for m in _maps(ctx):
        read = {(pin.component.designator, pin.designator) for *_, pin, _ in m.entries if pin is not None}
        for name, stem, select, ch, pin, net in m.entries:
            if m.adcs.get(select) is not None and (pin is None or len(ctx.design.nets[net].pins) < 2):
                yield Finding("FW002", f"{m.name}: firmware '{name}' reads select {select} input {ch}, which is "
                                       "not connected on the board",
                              refs=[m.adcs[select].designator])
        in_re = re.compile("^" + re.escape(m.spec.get("adc_input_pin", "IN{ch}")).replace(r"\{ch\}", r"\d+") + "$")
        for select, adc in sorted(m.adcs.items()):
            for p in sorted(adc.pins, key=lambda p: natural_key(p.name)):
                if in_re.match(p.name) and (adc.designator, p.designator) not in read \
                        and len(ctx.design.nets[p.net].pins) > 1 and not ctx.config.is_ground(p.net):
                    yield Finding("FW002", f"{m.name}: {p.ref} {p.name} is wired to '{p.net}' but no firmware "
                                           "channel reads it", refs=[adc.designator], nets=[p.net])


@check("FW003", "Firmware ADC channel map", INFO)
def channel_map(ctx):
    for m in _maps(ctx):
        rows = [f"{name}={pin.ref if pin else '?'}" for name, stem, select, ch, pin, net in m.entries]
        if rows:
            yield Finding("FW003", f"{m.name}: {len(rows)} channels traced firmware -> board "
                                   f"({', '.join(sorted({a.designator for a in m.adcs.values()}, key=natural_key))})")


# -- scaling ------------------------------------------------------------------------

def channel_scaling(ctx, m, pin):
    """(ratio, upstream net, resistor designators) for an ADC input fed
    through a series resistor from an upstream net, with an optional
    resistor to ground: ratio = Rbottom / (Rtop + Rbottom), 1.0 without a
    bottom resistor. None when the input is not wired that way or a value is
    unknown."""
    from .levels import _ohms
    cfg = ctx.config
    net = ctx.design.nets[pin.net]
    top, bottom = [], []
    for q in net.pins:
        comp = q.component
        if ctx.kind(comp) != "resistor" or len(comp.pins) != 2:
            continue
        other = next(x.net for x in comp.pins if x is not q)
        (bottom if cfg.is_ground(other) else top).append((comp, other))
    if len(top) != 1 or len(bottom) > 1:
        return None
    rt = _ohms(ctx, top[0][0])
    rb = _ohms(ctx, bottom[0][0]) if bottom else None
    if rt is None or (bottom and rb is None):
        return None
    ratio = rb / (rt + rb) if bottom else 1.0
    return ratio, top[0][1], [top[0][0].designator] + ([bottom[0][0].designator] if bottom else [])


def _stem_volts(ctx, stem):
    """Nominal volts of the rail a channel is named after ("28V0_EPS"), by
    the rail naming convention; None for current and other channels."""
    m = ctx.config._rail_re.match(stem)
    if not m or re.search(r"(ISENSE|_I$|CURRENT)", stem, re.I):
        return None
    return float(f"{m.group('int')}.{m.group('frac') or '0'}")


def _reference_volts(ctx, m, adc):
    ref = m.spec.get("adc_reference_pin", "VA")
    nets = {p.net for p in adc.pins if p.name == ref}
    volts = {ctx.config.net_voltage(n) for n in nets} - {None}
    return volts.pop() if len(volts) == 1 else None


@check("FW004", "ADC channel's nominal input exceeds the ADC reference", ERROR)
def channel_full_scale(ctx):
    """A voltage channel named after a rail ("TLM_3V3_MISC") reads that
    rail through its divider; at the rail's nominal voltage the ADC input
    must stay below the ADC reference (`adc_reference_pin`)."""
    for m in _maps(ctx):
        for name, stem, select, ch, pin, net in m.entries:
            if pin is None:
                continue
            volts = _stem_volts(ctx, stem)
            sc = channel_scaling(ctx, m, pin)
            ref = _reference_volts(ctx, m, pin.component)
            if volts is None or sc is None or ref is None:
                continue
            at_pin = volts * sc[0]
            if at_pin > ref:
                yield Finding("FW004", f"{m.name}: '{name}' ({stem}, {volts:g} V nominal) reaches {pin.ref} "
                                       f"{pin.name} at {at_pin:.2f} V through {'/'.join(sc[2])} (ratio {sc[0]:.4g}), "
                                       f"above the {ref:g} V reference", refs=[pin.component.designator], nets=[net])


def _read_cal(path, sheet, columns):
    """[(signal, gain, offset)] from a calibration spreadsheet (.xlsx or .csv)."""
    names = [c.lower() for c in columns]
    rows = []
    if path.lower().endswith(".csv"):
        import csv
        with open(path, newline="", encoding="utf-8") as f:
            rows = [tuple(r) for r in csv.reader(f)]
    else:
        import openpyxl     # optional dependency: only needed for .xlsx calibration files
        wb = openpyxl.load_workbook(path, data_only=True, read_only=True)
        rows = list(wb[sheet].iter_rows(values_only=True))
    header = [str(h or "").strip().lower() for h in rows[0]]
    idx = [header.index(n) for n in names]
    return [tuple(r[i] for i in idx) for r in rows[1:] if r and r[idx[0]] not in (None, "")]


def _cal_rows(ctx, m):
    spec = m.spec.get("calibration")
    if not spec:
        return None, None
    path = m._path(spec["file"])
    if not os.path.isfile(path):
        return None, f"calibration file not found: {path}"
    try:
        return _read_cal(path, spec.get("sheet"), spec.get("columns", ["Signal", "Gain", "Offset"])), None
    except ImportError:
        return None, "reading .xlsx calibration files needs openpyxl (pip install openpyxl)"
    except (KeyError, ValueError) as e:
        return None, f"calibration file {os.path.basename(path)}: {e}"


@check("FW005", "Calibration gain differs from the board's scaling", WARNING)
def calibration_gains(ctx):
    """For each voltage channel, the gain the board implies (reference / 2^bits
    / divider ratio: millivolts at the rail per count, the scaling
    tlm_adc.c's comment describes) against the calibration file's gain, by
    position in the firmware enum. Current channels are not computed."""
    for m in _maps(ctx):
        rows, problem = _cal_rows(ctx, m)
        if problem:
            yield Finding("FW005", f"{m.name}: {problem}", severity=INFO)
        if not rows:
            continue
        bits = int(m.spec.get("adc_bits", 12))
        tol = float(m.spec.get("calibration", {}).get("tolerance", 0.05))
        off = []
        for (name, stem, select, ch, pin, net), row in zip(m.entries, rows):
            volts = _stem_volts(ctx, stem)
            sc = channel_scaling(ctx, m, pin) if pin is not None else None
            ref = _reference_volts(ctx, m, pin.component) if pin is not None else None
            if volts is None or sc is None or ref is None:
                continue
            expected = ref * 1000.0 / (1 << bits) / sc[0]
            try:
                gain = float(row[1])
            except (TypeError, ValueError):
                continue
            if abs(gain - expected) > tol * expected:
                off.append(f"{name} {gain:g} (board: {expected:.4g} mV/count, ratio {sc[0]:.4g})")
        if off:
            yield Finding("FW005", f"{m.name}: {len(off)} voltage channel gain(s) in "
                                   f"{os.path.basename(m.spec['calibration']['file'])} differ from the board's "
                                   f"scaling by more than {tol:.0%}: " + "; ".join(off[:8])
                                   + (f"; ... {len(off) - 8} more" if len(off) > 8 else ""))


@check("FW006", "Calibration file signals differ from the firmware enum", WARNING)
def calibration_names(ctx):
    """The calibration table is loaded by position (cal.c copies it into
    TLM_Cal_t[] indexed by the enum), so its rows must list the enum's
    signals in the same order."""
    for m in _maps(ctx):
        rows, _ = _cal_rows(ctx, m)
        if not rows:
            continue
        names = [e[0] for e in m.entries]
        cal = [str(r[0]).strip() for r in rows]
        if len(cal) != len(names):
            yield Finding("FW006", f"{m.name}: calibration file has {len(cal)} rows, the enum {len(names)} signals")
        bad = [(i, c, n) for i, (c, n) in enumerate(zip(cal, names)) if c != n]
        if bad:
            yield Finding("FW006", f"{m.name}: calibration rows that do not name the enum signal at their position: "
                                   + "; ".join(f"row {i + 1} '{c}' (enum: {n})" for i, c, n in bad[:10])
                                   + (f"; ... {len(bad) - 10} more" if len(bad) > 10 else ""))


# -- PWM / DAC full scale ---------------------------------------------------------

def parse_define(path, macro):
    """The numeric value of `#define MACRO value` in a C header, or None."""
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            m = re.match(r"\s*#\s*define\s+" + re.escape(macro) + r"\s+\(?\s*([-+]?(?:0x[0-9a-fA-F]+|\d+(?:\.\d*)?))", line)
            if m:
                return float(int(m.group(1), 0)) if m.group(1).lower().startswith(("0x", "-0x")) else float(m.group(1))
    return None


def pwm_full_scale(ctx, f, pin):
    """(volts at the load at 100% duty, load pins, resistors, rail) for an
    FPGA PWM output filtered by a series resistor into a node with resistors
    to ground. The high level is the pin's bank rail. None when the path is
    not that shape or a value is unknown."""
    from .levels import _ohms
    cfg = ctx.config
    bank = f.bank(pin)
    nets = f.bank_supply_nets(bank) if bank is not None else set()
    rails = {cfg.net_voltage(n) for n in nets} - {None}
    if len(rails) != 1:
        return None
    v_high = rails.pop()
    first = ctx.design.nets[pin.net]
    series = [q for q in first.pins if q.component is not pin.component and ctx.kind(q.component) == "resistor"
              and len(q.component.pins) == 2]
    if len(series) != 1:
        return None
    rs_comp = series[0].component
    node = next(p.net for p in rs_comp.pins if p is not series[0])
    if cfg.is_ground(node) or cfg.is_rail(node):
        return None
    rs = _ohms(ctx, rs_comp)
    downs = []
    for q in ctx.design.nets[node].pins:
        c = q.component
        if c is rs_comp or ctx.kind(c) != "resistor" or len(c.pins) != 2:
            continue
        other = next(p.net for p in c.pins if p is not q)
        if not cfg.is_ground(other):
            return None         # another source or series path: not a simple filter
        downs.append(c)
    ohms = [_ohms(ctx, c) for c in downs]
    if rs is None or any(o is None for o in ohms):
        return None
    if ohms:
        rb = 1.0 / sum(1.0 / o for o in ohms)
        ratio = rb / (rs + rb)
    else:
        ratio = 1.0
    loads = [q for q in ctx.design.nets[node].pins if ctx.kind(q.component) not in ("resistor", "capacitor")]
    return v_high * ratio, loads, [rs_comp.designator] + [c.designator for c in downs], v_high


@check("FW007", "Firmware full-scale constant differs from the board", ERROR)
def pwm_constants(ctx):
    """firmware.pwm_outputs: a firmware constant stating the voltage a PWM
    output produces at its load at 100% duty (e.g. PWM_VREF_mV) against the
    board: the FPGA bank rail through the RC filter's divider."""
    for spec in ctx.config["firmware"]["pwm_outputs"] or []:
        path = os.path.normpath(os.path.join(ctx.config.base_dir, os.path.expanduser(spec["constant_file"])))
        name = spec.get("name", spec["constant"])
        if not os.path.isfile(path):
            yield Finding("FW007", f"{name}: firmware file not found: {path}", severity=WARNING)
            continue
        value = parse_define(path, spec["constant"])
        if value is None:
            yield Finding("FW007", f"{name}: #define {spec['constant']} not found in {os.path.basename(path)}",
                          severity=WARNING)
            continue
        volts_fw = value * {"mV": 1e-3, "V": 1.0}[spec.get("constant_unit", "mV")]
        comp = ctx.design.components.get(spec["fpga"])
        f = ctx.fpga_for(comp) if comp is not None else None
        if f is None:
            continue
        by_port = {c.port: c for c in f.io.pins.values()}
        pins = {str(p.designator): p for p in comp.pins}
        tol = float(spec.get("tolerance", 0.05))
        for port in spec["ports"]:
            c = by_port.get(port)
            pin = pins.get(c.ball) if c else None
            fs = pwm_full_scale(ctx, f, pin) if pin else None
            if fs is None:
                yield Finding("FW007", f"{name}: could not work out the full scale of '{port}' "
                                       "(expected FPGA pin -> series resistor -> node with resistors to ground)",
                              severity=INFO, refs=[spec["fpga"]])
                continue
            volts, loads, rs, v_high = fs
            if abs(volts - volts_fw) > tol * volts_fw:
                where = ", ".join(q.ref + (f" {q.name}" if q.name else "") for q in loads) or "its filter node"
                yield Finding("FW007", f"{name}: {spec['constant']} = {value:g} {spec.get('constant_unit', 'mV')} "
                                       f"({os.path.basename(path)}) but '{port}' reaches {where} at "
                                       f"{volts:.3g} V full scale ({v_high:g} V bank rail through "
                                       f"{'/'.join(rs)}); setpoints are scaled by {volts / volts_fw:.3g}",
                              refs=sorted({spec["fpga"]} | {q.component.designator for q in loads}, key=natural_key))


@check("FW008", "Firmware limit beyond what the board can produce", WARNING, needs_partsdb=True)
def pwm_limits(ctx):
    """firmware.pwm_outputs[].limit: a firmware maximum for the quantity the
    PWM sets at its load (e.g. I_MAX_MA for a stepper driver whose current
    is VREF / KV) against the most the board can produce: the output's full
    scale divided by the load pin's characteristic (`gain`, e.g. kv),
    taken at its most favourable limit."""
    from .levels import PinLevels, _levels
    lv = _levels(ctx)
    for spec in ctx.config["firmware"]["pwm_outputs"] or []:
        lim = spec.get("limit")
        if not lim:
            continue
        path = os.path.normpath(os.path.join(ctx.config.base_dir, os.path.expanduser(spec["constant_file"])))
        if not os.path.isfile(path):
            continue
        value = parse_define(path, lim["constant"])
        if value is None:
            yield Finding("FW008", f"{spec.get('name')}: #define {lim['constant']} not found", severity=INFO)
            continue
        scale = {"mA": 1e-3, "A": 1.0, "mV": 1e-3, "V": 1.0}[lim.get("unit", "mA")]
        comp = ctx.design.components.get(spec["fpga"])
        f = ctx.fpga_for(comp) if comp is not None else None
        if f is None:
            continue
        by_port = {c.port: c for c in f.io.pins.values()}
        pins = {str(p.designator): p for p in comp.pins}
        for port in spec["ports"]:
            c = by_port.get(port)
            pin = pins.get(c.ball) if c else None
            fs = pwm_full_scale(ctx, f, pin) if pin else None
            if fs is None:
                continue
            volts, loads, rs, _ = fs
            for load in loads:
                chars = ctx.partsdb.characteristics(load.component.part_number) or {}
                pp = _pin_types(ctx).part_entry(load)
                if pp is None or not chars:
                    continue
                pl = PinLevels(load, chars, key=pp.key)
                g_min = lv.value(pl, lim["gain"], "min", "low")[0]
                g_typ = next((r.get("typ") for _, char in lv._tables(pl, lim["gain"]) for r in char.get("rows", [])
                              if "typ" in r), None)
                if not g_min:
                    continue
                best = volts / g_min
                if value * scale > best * 1.0001:
                    typ = f", {volts / g_typ:.3g} typical" if g_typ else ""
                    yield Finding("FW008", f"{spec.get('name')}: {lim['constant']} = {value:g} {lim.get('unit', 'mA')} "
                                           f"but '{port}' reaches {load.ref} {load.name} at {volts:.3g} V full scale, "
                                           f"which gives at most {best:.3g} {lim.get('result_unit', 'A')} "
                                           f"({lim['gain']} {g_min:g} minimum{typ})",
                                  refs=sorted({spec["fpga"], load.component.designator}, key=natural_key))
