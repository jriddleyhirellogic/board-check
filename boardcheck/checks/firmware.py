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
