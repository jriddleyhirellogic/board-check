"""Connector access report: what each connector pin reaches on the board.

A report, not a check: no findings. For every connector pin it gives the
net, whether the pin is ground, a supply (and the regulator that feeds
it) or a signal, and for a signal:

- its differential partner (net name suffixes, `nets.diff_pair_suffixes`)
  and any resistor across the pair;
- protection on the net (part data function ESD_IO or FLOW_THROUGH, and
  diodes);
- two-terminal passives from the net to ground or a rail;
- the parts it reaches: series resistors, capacitors, inductors, ferrites
  and fuses are walked through, and buffers, line drivers, line receivers
  and level shifters are crossed to the matching channel's other side, so
  a pin reaches the FPGA port behind them. The FPGA's constraint gives the
  port, I/O standard, direction and bank. A branch ends at the first
  active part it reaches (so an analog input stops at its amplifier rather
  than wandering through the feedback network).

A buffer is crossed only when its part data says which pins form a channel
(`_CROSS` below: a pin's function on one side, the other side's function,
and the same digits in the pin key: 1A -> 1Y, 1A1 -> 1Y1, A -> R). When
that is missing the trace stops at the part and says so; it does not
guess. Transformers and transistors stop the trace the same way.

    python -m boardcheck access EXPORT -c CONFIG [--connector J1,J6]
    python -m boardcheck access --system SYSTEM.yaml --board NAME
"""

import csv
import io
import json
import re
from dataclasses import dataclass, field

from .checks.pins import _pin_types, _terminations
from .model import natural_key
from .units import format_value

# (input-side functions, output-side functions) of one channel.
_CROSS = [
    ({"LVDS_IN_P", "LVDS_IN_N", "BUS_IN_P", "BUS_IN_N"}, {"RECEIVER_OUT", "RX_OUT"}),
    ({"DRIVER_IN", "TX_IN"}, {"LVDS_OUT_P", "LVDS_OUT_N", "BUS_OUT_P", "BUS_OUT_N"}),
    ({"BUFFER_IN"}, {"BUFFER_OUT"}),
]
_ESD = {"ESD_IO", "FLOW_THROUGH"}
_SERIES = {"resistor", "capacitor", "inductor", "ferrite", "fuse"}
_STOP_KINDS = {"transformer": "transformer", "transistor": "transistor", "relay": "relay", "switch": "switch",
               "crystal": "crystal"}
MAX_HOPS = 4            # passives walked through in a row
MAX_CROSSINGS = 3       # buffers crossed


def _channel(key):
    """Channel of a pin key: its digits (1A -> 1, 1Y1 -> 11, A -> '')."""
    return re.sub(r"\D", "", str(key))


@dataclass
class Endpoint:
    ref: str                    # U1.K2
    name: str                   # pin name
    part_number: str
    path: list                  # steps from the connector: "R334 0Ω", "U56 3A→3Y"
    function: str = None
    direction: str = None
    io_standard: str = None
    port: str = None            # FPGA port, when an FPGA constraint covers the pin
    bank: str = None
    bank_voltage: float = None
    note: str = None

    fpga: bool = False

    @property
    def is_fpga(self):
        return self.fpga

    def text(self):
        what = f"{self.ref} {self.name}" if self.name and self.name != self.ref.split(".")[-1] else self.ref
        bits = []
        if self.port:
            bits.append(f"port {self.port}")
        details = [x for x in (self.io_standard, self.direction) if x]
        if self.bank is not None:
            details.append(f"bank {self.bank}" + (f" {self.bank_voltage:g} V" if self.bank_voltage is not None else ""))
        if self.function and not self.port:
            details.insert(0, self.function)
        if details:
            bits.append(", ".join(details))
        if self.note:
            bits.append(self.note)
        out = what + (f" ({'; '.join(bits)})" if bits else "")
        if self.path:
            out += " via " + ", ".join(self.path)
        return out

    def to_dict(self):
        d = {"ref": self.ref, "name": self.name, "part_number": self.part_number, "path": self.path}
        for k in ("function", "direction", "io_standard", "port", "bank", "bank_voltage", "note"):
            if getattr(self, k) is not None:
                d[k] = getattr(self, k)
        return d


@dataclass
class PinAccess:
    pin: object
    kind: str                   # "not connected", "ground", "supply", "signal"
    voltage: float = None
    fed_by: str = None
    pair: str = None            # partner net
    termination: list = field(default_factory=list)
    protection: list = field(default_factory=list)
    ties: list = field(default_factory=list)       # passives to ground or a rail
    reaches: list = field(default_factory=list)    # [Endpoint]
    stops: list = field(default_factory=list)      # where the trace could not continue
    mates: list = field(default_factory=list)      # "board:J3.5 NET"

    def to_dict(self):
        d = {"pin": str(self.pin.designator), "name": self.pin.name, "net": self.pin.net, "kind": self.kind}
        for k in ("voltage", "fed_by", "pair"):
            if getattr(self, k) is not None:
                d[k] = getattr(self, k)
        for k in ("termination", "protection", "ties", "stops", "mates"):
            if getattr(self, k):
                d[k] = getattr(self, k)
        if self.reaches:
            d["reaches"] = [e.to_dict() for e in self.reaches]
        return d


@dataclass
class ConnectorAccess:
    component: object
    pins: list                  # [PinAccess]

    def to_dict(self):
        c = self.component
        return {"designator": c.designator, "part_number": c.part_number, "pins": [p.to_dict() for p in self.pins]}


def _value(ctx, comp):
    kind = ctx.kind(comp)
    if kind == "resistor":
        from .checks.levels import _ohms
        ohms = _ohms(ctx, comp)
        return format_value(ohms, "Ω") if ohms is not None else None
    if kind == "capacitor":
        return ctx.design.param(comp, "C_Value", "Value")
    return ctx.design.param(comp, "Value", "L_Value")


def _part(ctx, comp):
    v = _value(ctx, comp)
    return f"{comp.designator} {v}" if v else comp.designator


def _partner(ctx, net):
    for p, n in ctx.config["nets"].get("diff_pair_suffixes") or []:
        for a, b in ((p, n), (n, p)):
            if net.endswith(a):
                other = net[:-len(a)] + b
                if other in ctx.design.nets:
                    return other
    return None


def _crossing(ctx, pin):
    """Pins on the other side of the buffer channel `pin` is on: [] when the
    part is a buffer but the channel cannot be matched, None when the pin is
    not on a buffer channel."""
    pt = _pin_types(ctx)
    pp = pt.part_entry(pin)
    func = pp.entry.get("function") if pp else None
    for ins, outs in _CROSS:
        if func in ins:
            want = outs
        elif func in outs:
            want = ins
        else:
            continue
        ch = _channel(pp.key)
        found = []
        for q in pin.component.pins:
            qq = pt.part_entry(q)
            if q is not pin and qq and qq.entry.get("function") in want and _channel(qq.key) == ch:
                found.append((q, qq))
        return found
    return None


def _endpoint(ctx, pin, path):
    comp = pin.component
    pt = _pin_types(ctx)
    pp = pt.part_entry(pin)
    ep = Endpoint(pin.ref, pin.name, comp.part_number, list(path))
    if pp is not None:
        ep.function = pp.entry.get("function")
        ep.direction = pp.entry.get("direction")
        ep.io_standard = pp.entry.get("io_standard")
    elif ctx.partsdb is not None and pt.table(comp.part_number) is None:
        ep.note = "no part data"
    f = ctx.fpga_for(comp)
    if f is not None:
        c = f.constraint(pin)
        bank = f.bank(pin)
        ep.function = None
        ep.bank = bank
        if bank is not None:
            vcci = f.bank_vcci(bank)
            if vcci is None:
                vs = {ctx.config.net_voltage(n) for n in f.bank_supply_nets(bank) if n} - {None}
                vcci = vs.pop() if len(vs) == 1 else None
            ep.bank_voltage = vcci
        ep.fpga = True
        if c is None:
            # the bank pattern matches user I/O only; others are dedicated pins
            ep.note = "no port assigned" if bank is not None else "not a bank I/O pin"
            ep.direction = ep.io_standard = None
        else:
            ep.port, ep.io_standard, ep.direction = c.port, c.io_std, f.direction(c)
    return ep


def trace(ctx, start):
    """PinAccess for one connector pin."""
    cfg = ctx.config
    net = start.net
    acc = PinAccess(start, "signal")
    others = [p for p in (ctx.design.nets[net].pins if net in ctx.design.nets else [])
              if p is not start and not cfg.is_mechanical(p.component)]
    if net is None or not others:
        acc.kind = "not connected"
        return acc
    if cfg.is_ground(net):
        acc.kind = "ground"
        return acc
    if cfg.net_voltage(net) is not None:
        from .checks.power import _setpoints
        acc.kind, acc.voltage = "supply", cfg.net_voltage(net)
        sp = _setpoints(ctx).get(net) if ctx.partsdb is not None else None
        acc.fed_by = sp[3] if sp else None
        return acc
    acc.pair = _partner(ctx, net)
    if acc.pair:
        acc.termination = [f"{' + '.join(ds)}" + (f" {format_value(r, 'Ω')}" if r is not None else "")
                           for r, ds in _terminations(ctx, net, acc.pair)]
    pt = _pin_types(ctx)
    seen_nets = {net} | ({acc.pair} if acc.pair else set())
    seen_pins = {id(start)}
    crossed = set()
    queue = [(net, [], 0, 0)]       # (net, path, passive hops, crossings)

    def protect(text):
        if text not in acc.protection:
            acc.protection.append(text)

    while queue:
        cur, path, hops, crossings = queue.pop(0)
        where = "" if cur == net else f" (on {cur})"
        passives, active = [], False
        for q in ctx.design.nets[cur].pins:
            if id(q) in seen_pins:
                continue
            seen_pins.add(id(q))
            comp = q.component
            kind = ctx.kind(comp)
            if cfg.is_mechanical(comp):
                continue
            if kind in ("connector", "testpoint"):
                acc.reaches.append(Endpoint(q.ref, q.name, comp.part_number, list(path),
                                            note="test point" if kind == "testpoint" else "connector"))
                continue
            if kind == "diode":
                tied = sorted({p.net for p in comp.pins if p is not q and p.net}, key=natural_key)
                protect((f"{comp.designator} to {', '.join(tied)}" if tied else comp.designator) + where)
                continue
            if kind in _SERIES and len(comp.pins) == 2:
                other = next(p for p in comp.pins if p is not q)
                seen_pins.add(id(other))
                if other.net is None or other.net == cur:
                    continue
                if cfg.is_ground(other.net) or cfg.is_rail(other.net):
                    acc.ties.append(f"{_part(ctx, comp)} to {other.net}{where}")
                else:
                    passives.append((comp, other.net))
                continue
            if kind in _STOP_KINDS:
                acc.stops.append(f"{q.ref}: {_STOP_KINDS[kind]}, not traced through")
                continue
            pp = pt.part_entry(q)
            if pp is not None and pp.entry.get("function") in _ESD:
                protect(f"{comp.designator} {comp.part_number}{where}")
                continue
            across = _crossing(ctx, q)
            if across is None:
                ep = _endpoint(ctx, q, path)
                acc.reaches.append(ep)
                active = active or ep.note != "no part data"
                continue
            key = (comp.designator, _channel(pp.key))
            if key in crossed:
                continue
            crossed.add(key)
            if not across:
                acc.stops.append(f"{q.ref} {pp.key} ({comp.part_number}): channel mapping unknown, not crossed")
                continue
            if crossings >= MAX_CROSSINGS:
                acc.stops.append(f"{q.ref}: more than {MAX_CROSSINGS} buffers in a row")
                continue
            for r, rr in across:
                seen_pins.add(id(r))
                step = f"{comp.designator} {pp.key}→{rr.key}"
                if r.net is None or cfg.is_ground(r.net) or cfg.net_voltage(r.net) is not None:
                    acc.stops.append(f"{r.ref} {rr.key}: on {r.net or 'no net'}")
                    continue
                if r.net in seen_nets:
                    continue
                seen_nets.add(r.net)
                queue.append((r.net, path + [step], 0, crossings + 1))
        if active and cur != net:
            continue        # a branch ends at the first active part it reaches
        for comp, onet in passives:
            if onet in seen_nets:
                continue
            if hops >= MAX_HOPS:
                acc.stops.append(f"{comp.designator}: more than {MAX_HOPS} passives in a row")
                continue
            seen_nets.add(onet)
            queue.append((onet, path + [_part(ctx, comp)], hops + 1, crossings))
    acc.reaches.sort(key=lambda e: (not e.is_fpga, natural_key(e.ref)))
    return acc


def connectors(ctx, only=None):
    """[ConnectorAccess] for every connector (or those named in `only`)."""
    out = []
    for comp in sorted(ctx.design.components.values(), key=lambda c: natural_key(c.designator)):
        if ctx.kind(comp) != "connector" or (only and comp.designator not in only):
            continue
        pins = sorted(comp.pins, key=lambda p: natural_key(str(p.designator)))
        out.append(ConnectorAccess(comp, [trace(ctx, p) for p in pins]))
    return out


def add_mates(found, system, board_name):
    """Fill each pin's `mates` from the system links that join this board."""
    by_pin = {}
    for link in system.links:
        for (ba, ca), (bb, cb), side in ((link.a, link.b, 0), (link.b, link.a, 1)):
            if ba.name != board_name:
                continue
            for pa, pb in link.pairs:
                mine, theirs = (pa, pb) if side == 0 else (pb, pa)
                by_pin.setdefault((ca.designator, str(mine.designator)), []).append(
                    f"{bb.name}:{theirs.ref} {theirs.net or 'no net'}")
    for c in found:
        for p in c.pins:
            p.mates = by_pin.get((c.component.designator, str(p.pin.designator)), [])


# --- output --------------------------------------------------------------------------------------------------------

def _cell(text):
    return str(text).replace("|", "\\|")


def _kind_text(p):
    if p.kind == "supply":
        v = f"{p.voltage:g} V" if p.voltage is not None else ""
        return f"supply {v}".strip() + (f" from {p.fed_by}" if p.fed_by else "")
    return p.kind


def _pair_text(p):
    if not p.pair:
        return ""
    return p.pair + (f"; across: {', '.join(p.termination)}" if p.termination else "")


def markdown(found, title=None):
    show_mates = any(p.mates for c in found for p in c.pins)
    lines = [f"# {title or 'Connector access'}", ""]
    for c in found:
        comp = c.component
        lines += [f"## {comp.designator} ({comp.part_number})", ""]
        head = ["Pin", "Net", "Kind", "Pair", "Protection", "To ground or rail", "Reaches", "Not traced"]
        if show_mates:
            head.append("Mates")
        lines += ["| " + " | ".join(head) + " |", "|" + "---|" * len(head)]
        for p in c.pins:
            row = [p.pin.designator, p.pin.net or "", _kind_text(p), _pair_text(p), "; ".join(p.protection),
                   "; ".join(p.ties), "<br>".join(e.text() for e in p.reaches), "<br>".join(p.stops)]
            if show_mates:
                row.append("<br>".join(p.mates))
            lines.append("| " + " | ".join(_cell(x) for x in row) + " |")
        lines.append("")
    return "\n".join(lines)


def as_csv(found):
    buf = io.StringIO()
    w = csv.writer(buf, lineterminator="\n")
    w.writerow(["connector", "pin", "net", "kind", "voltage", "fed_by", "pair", "termination", "protection",
                "to_ground_or_rail", "fpga_pin", "fpga_port", "fpga_io_standard", "fpga_direction", "fpga_bank",
                "fpga_bank_voltage", "fpga_path", "reaches", "not_traced", "mates"])
    for c in found:
        for p in c.pins:
            fp = next((e for e in p.reaches if e.is_fpga), None)
            w.writerow([c.component.designator, p.pin.designator, p.pin.net or "", p.kind,
                        "" if p.voltage is None else f"{p.voltage:g}", p.fed_by or "", p.pair or "",
                        "; ".join(p.termination), "; ".join(p.protection), "; ".join(p.ties),
                        fp.ref if fp else "", (fp.port or "") if fp else "", (fp.io_standard or "") if fp else "",
                        (fp.direction or "") if fp else "", (fp.bank or "") if fp else "",
                        "" if not fp or fp.bank_voltage is None else f"{fp.bank_voltage:g}",
                        ", ".join(fp.path) if fp else "",
                        "; ".join(e.text() for e in p.reaches), "; ".join(p.stops), "; ".join(p.mates)])
    return buf.getvalue()


def as_json(found):
    return json.dumps([c.to_dict() for c in found], indent=2, ensure_ascii=False)
