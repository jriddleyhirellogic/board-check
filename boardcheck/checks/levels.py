"""Logic-level compatibility between the pins on each signal.

Levels come from the part data in electronic-parts-repository: the
`range_table` characteristics `voh`/`vol` of a driver against `vih`/`vil`
(or Schmitt `vt_pos`/`vt_neg`) of a receiver, and the highest level on the
signal against the receiver's `vi_abs` / `vi_op` maximum. A pin the part
data marks analog (`io_standard: "analog"`) has no logic thresholds: it
is left out of the high/low comparisons but still checked for overvoltage.
Limits written
relative to a supply ("0.65*VCC") are evaluated at the voltage of the rail
the schematic connects that supply pin to.

FPGA pins are programmable, so their part data is conditioned on the I/O
standard (`io_standard` in a row's conditions) and their supply is the
bank's I/O supply. The standard, drive and bank come from the FPGA
constraint files (see boardcheck/fpga.py).

A signal is a net plus every net joined to it through a series resistor
of at most `levels.series_max_ohms`, so a source-terminated line is checked
end to end. Resistors from the signal to rails and ground hold it at their
Thevenin voltage when nothing drives it: a pull-up's rail, or a divider's
output. That is a high level the receivers see.

Row selection. Rows whose conditions match the pin are candidates: the
io_standard must equal the pin's, a supply range must contain the rail
voltage, a supply test point must not exceed it (the highest such point is
used), and a drive strength must equal the constrained one when there is
one. Outputs are taken at the smallest listed load current, since logic
inputs draw microamps. When several rows remain, the least favourable limit
is used.
"""

import re
from collections import defaultdict
from dataclasses import dataclass, field

from . import ERROR, INFO, WARNING, Finding, check
from .pins import CONSTRAINTS, PART, _norm, _pin_types
from ..model import natural_key
from ..units import parse_value

# Standard characteristic keys (JSON_FORMAT.md). Anything else starting with
# one of these plus "_" is a pin-group variant ("vi_abs_bus").
STANDARD_KEYS = {"vi_abs", "vo_abs", "vo_abs_hiz", "vi_op", "vih", "vil", "vt_pos", "vt_neg", "voh", "vol",
                 "vod", "voc_ss", "vit_pos", "vit_neg", "vth_pos", "vth_neg", "vid_op", "vic_op",
                 "ii_clamp", "ii_clamp_package"}
_LIMIT_RE = re.compile(r"^\s*(?:(\d+(?:\.\d+)?)\s*\*\s*)?([A-Za-z_]\w*)\s*(?:([+-])\s*(\d+(?:\.\d+)?))?\s*$")
_EPS = 1e-9
_RANGE_SLACK = 0.005     # a 3.3 V rail sits inside a 3.0-3.3 V range


@dataclass
class PinLevels:
    """What is known about one pin's levels."""
    pin: object
    chars: dict                      # the part's electrical_characteristics
    key: str = None                  # pin_functions key
    supply: str = None               # default supply name for this pin
    io_std: str = None               # FPGA I/O standard
    drive: float = None              # FPGA output drive, mA
    bank_type: str = None            # FPGA bank type ("GPIO", "HSIO")
    fpga: object = None              # FpgaPins, for FPGA pins
    notes: list = field(default_factory=list)


class Levels:
    def __init__(self, ctx):
        self.ctx = ctx
        self.pt = _pin_types(ctx)
        self._pins = {}

    # -- per pin ---------------------------------------------------------------

    def for_pin(self, pin):
        """PinLevels, or None when there is no level data for the pin."""
        k = (pin.component.designator, pin.designator)
        if k not in self._pins:
            self._pins[k] = self._for_pin(pin)
        return self._pins[k]

    def _for_pin(self, pin):
        if self.ctx.partsdb is None:
            return None
        chars = self.ctx.partsdb.characteristics(pin.component.part_number)
        if not chars:
            return None
        fpga = self.ctx.fpga_for(pin.component)
        if fpga is not None:
            c = fpga.constraint(pin)
            if c is None or not c.io_std:
                return None
            table = self.pt.table(pin.component.part_number) or {}
            banked = [pp.key for pp in table.get("per_bank", []) if pp.direction == "power"]
            if not banked:
                return None
            return PinLevels(pin, chars, supply=banked[0], io_std=c.io_std, drive=c.drive,
                             bank_type=fpga.bank_type(pin), fpga=fpga)
        pp = self.pt.part_entry(pin)
        if pp is None:
            return None
        return PinLevels(pin, chars, key=pp.key, supply=pp.entry.get("supply"))

    def supply_volts(self, pl, name):
        """Voltage of supply `name` for this pin, from the schematic rail."""
        cfg = self.ctx.config
        comp = pl.pin.component
        table = self.pt.table(comp.part_number)
        pp = table["by_name"].get(_norm(name)) if table else None
        if pl.fpga is not None and pp is not None and pp.per_bank:
            bank = pl.fpga.bank(pl.pin)
            nets = pl.fpga.bank_supply_nets(bank) if bank is not None else set()
            volts = {cfg.net_voltage(n) for n in nets} - {None}
            return volts.pop() if len(volts) == 1 else None
        numbers = set(pp.numbers) if pp else set()
        grounded = False
        for p in comp.pins:
            if _norm(p.name) == _norm(name) or str(p.designator) in numbers:
                v = cfg.net_voltage(p.net)
                if v is not None and not cfg.is_ground(p.net):
                    return v
                grounded = grounded or cfg.is_ground(p.net)
        # A supply tied to ground (an op amp's VEE in single-supply use) is 0 V.
        return 0.0 if grounded else None

    def own_supply(self, pl):
        return self.supply_volts(pl, pl.supply) if pl.supply else None

    # -- characteristic lookup -------------------------------------------------

    def _tables(self, pl, name):
        for key, char in pl.chars.items():
            if not isinstance(char, dict) or char.get("kind") != "range_table":
                continue
            if key != name and not (key.startswith(name + "_") and key not in STANDARD_KEYS):
                continue
            applies = char.get("applies_to")
            if applies and (pl.key is None or _norm(pl.key) not in {_norm(a) for a in applies}):
                continue
            yield key, char

    def _limit(self, pl, value):
        if isinstance(value, (int, float)):
            return float(value)
        m = _LIMIT_RE.match(str(value or ""))
        if not m:
            return None
        k, name, sign, c = m.groups()
        v = self.supply_volts(pl, name)
        if v is None:
            return None
        v *= float(k) if k else 1.0
        if sign:
            v += float(c) if sign == "+" else -float(c)
        return v

    def _row_ok(self, pl, row):
        """None if the row applies, else why not. Supply test points are
        accepted here and narrowed in _pick."""
        cond = row.get("conditions") or {}
        std = cond.get("io_standard")
        if std is not None:
            want = std.get("value") if isinstance(std, dict) else std
            want = want if isinstance(want, list) else [want]
            if not pl.io_std or pl.io_std.upper() not in {str(w).upper() for w in want}:
                return "io_standard"
        sv = cond.get("supply_voltage")
        if sv:
            names = sv.get("supply") or pl.supply
            names = names if isinstance(names, list) else [names]
            v = self.supply_volts(pl, names[0]) if names and names[0] else None
            if v is None:
                return "supply unknown"
            if "min" in sv or "max" in sv:
                lo, hi = sv.get("min", float("-inf")), sv.get("max", float("inf"))
                if not (lo * (1 - _RANGE_SLACK) <= v <= hi * (1 + _RANGE_SLACK)):
                    return "supply out of range"
            elif "value" in sv and sv["value"] > v * (1 + _RANGE_SLACK):
                return "supply below test point"
        bt = cond.get("bank_type")
        if bt is not None:
            want = bt.get("value") if isinstance(bt, dict) else bt
            want = want if isinstance(want, list) else [want]
            if not pl.bank_type or pl.bank_type not in {str(w).upper() for w in want}:
                return "bank_type"
        ds = cond.get("drive_strength")
        if ds and pl.drive is not None:
            want = ds.get("value") if isinstance(ds, dict) else ds
            want = want if isinstance(want, list) else [want]
            if not any(abs(float(w) - pl.drive) <= _EPS for w in want):
                return "drive strength"
        return None

    def value(self, pl, name, side, worst):
        """(volts, char key) for limit `side` ("min"/"max") of characteristic
        `name`, taking the least favourable matching row: worst="low" takes
        the smallest value, "high" the largest. (None, reason) when no row
        applies."""
        rows, reasons = [], set()
        for key, char in self._tables(pl, name):
            for row in char.get("rows") or []:
                if side not in row:
                    continue
                why = self._row_ok(pl, row)
                if why:
                    reasons.add(why)
                else:
                    rows.append((key, row))
        rows = _pick(rows)
        vals = [(self._limit(pl, row[side]), key) for key, row in rows]
        vals = [v for v in vals if v[0] is not None]
        if not vals:
            return None, (", ".join(sorted(reasons)) or f"no {name}")
        return (min if worst == "low" else max)(vals, key=lambda v: v[0])


def input_thresholds(lv, pl):
    """(low max, high min) an input recognises: VIL max / VIH min, or for a
    threshold input with hysteresis the falling threshold's minimum and the
    rising threshold's maximum (vt_neg / vt_pos). None parts when unknown."""
    if pl is None:
        return None, None
    low = lv.value(pl, "vil", "max", "low")[0]
    if low is None:
        low = lv.value(pl, "vt_neg", "min", "low")[0]
    high = lv.value(pl, "vih", "min", "high")[0]
    if high is None:
        high = lv.value(pl, "vt_pos", "max", "high")[0]
    return low, high


def _cond_value(row, name):
    c = (row.get("conditions") or {}).get(name)
    return c.get("value") if isinstance(c, dict) else None


def _pick(rows):
    """Narrow matching rows: the highest supply test point per load/drive,
    then the smallest load current."""
    if not rows:
        return rows
    best_point = {}
    for key, row in rows:
        sv = (row.get("conditions") or {}).get("supply_voltage") or {}
        if "value" in sv and "min" not in sv:
            g = (key, _cond_value(row, "load_current"), _cond_value(row, "drive_strength"))
            best_point[g] = max(best_point.get(g, float("-inf")), sv["value"])
    kept = []
    for key, row in rows:
        sv = (row.get("conditions") or {}).get("supply_voltage") or {}
        if "value" in sv and "min" not in sv:
            g = (key, _cond_value(row, "load_current"), _cond_value(row, "drive_strength"))
            if sv["value"] != best_point[g]:
                continue
        kept.append((key, row))
    loads = [abs(_cond_value(r, "load_current")) for _, r in kept if _cond_value(r, "load_current") is not None]
    if loads:
        least = min(loads)
        kept = [(k, r) for k, r in kept
                if _cond_value(r, "load_current") is None or abs(_cond_value(r, "load_current")) == least]
    return kept


# -- signals -------------------------------------------------------------------

@dataclass
class Signal:
    nets: list
    pins: list = field(default_factory=list)       # active (non-passive) pins
    # Resistors from the signal to a supply or ground: (resistor, net, volts, ohms)
    ties: list = field(default_factory=list)
    external: list = field(default_factory=list)   # connector pins

    @property
    def name(self):
        return self.nets[0] if len(self.nets) == 1 else f"{self.nets[0]} (+{', '.join(self.nets[1:])})"

    def resistive_level(self):
        """(volts, label) the resistors to supplies hold the signal at when
        nothing drives it: a pull-up's rail, or a divider's output (the
        Thevenin voltage). None when there is no resistor to a rail, or a
        value is unknown."""
        rails = [t for t in self.ties if t[2] > 0]
        if not rails or any(t[3] is None for t in self.ties):
            return None
        if any(t[3] == 0 for t in self.ties):
            return None     # a 0 ohm tie makes the signal a supply
        g = sum(1.0 / t[3] for t in self.ties)
        volts = sum(t[2] / t[3] for t in self.ties) / g
        if len(self.ties) == 1:
            comp, net = rails[0][0], rails[0][1]
            return volts, f"pull-up {comp.designator} to {net}"
        names = ", ".join(t[0].designator for t in self.ties)
        return volts, f"resistor network {names} ({volts:.3g} V)"


def _ohms(ctx, comp):
    ohms = parse_value(ctx.design.param(comp, "R_Value"), "Ω")
    if ohms is None:
        decoded = ctx.decoded(comp)
        ohms = decoded.resistance if decoded else None
    return ohms


def signals(ctx):
    """Signals: nets joined through small series resistors. Cached on ctx."""
    if hasattr(ctx, "_signals"):
        return ctx._signals
    cfg = ctx.config
    limit = ctx.config["levels"]["series_max_ohms"]
    nets = ctx.design.nets
    parent = {n: n for n in nets}

    def find(n):
        while parent[n] != n:
            parent[n] = parent[parent[n]]
            n = parent[n]
        return n

    def supply(n):
        return cfg.is_ground(n) or cfg.net_voltage(n) is not None

    ties = defaultdict(list)
    for comp in ctx.design.components.values():
        if ctx.kind(comp) != "resistor" or len(comp.pins) != 2:
            continue
        a, b = comp.pins[0].net, comp.pins[1].net
        if a == b:
            continue
        if supply(a) != supply(b):
            rail, sig = (a, b) if supply(a) else (b, a)
            if cfg.is_ground(rail) or cfg.is_rail(rail):
                ties[sig].append((comp, rail, cfg.net_voltage(rail), _ohms(ctx, comp)))
            continue
        if supply(a):
            continue
        ohms = _ohms(ctx, comp)
        if ohms is not None and ohms <= limit:
            parent[find(a)] = find(b)

    groups = defaultdict(list)
    for n in nets:
        if not supply(n):
            groups[find(n)].append(n)
    out = []
    for members in groups.values():
        members.sort(key=lambda n: (nets[n].auto_named, natural_key(n)))
        sig = Signal(members)
        for n in members:
            sig.ties.extend(ties.get(n, []))
            for p in nets[n].pins:
                kind = ctx.kind(p.component)
                if kind == "connector":
                    sig.external.append(p)
                elif kind not in ("resistor", "capacitor", "inductor", "ferrite", "testpoint", "mechanical"):
                    sig.pins.append(p)
        out.append(sig)
    out.sort(key=lambda s: natural_key(s.nets[0]))
    ctx._signals = out
    return out


def _levels(ctx):
    if not hasattr(ctx, "_levels"):
        ctx._levels = Levels(ctx)
    return ctx._levels


def _analog(ctx, pin):
    """True when the part data marks the pin analog (io_standard "analog"):
    it has no logic thresholds, only voltage limits."""
    pp = _pin_types(ctx).part_entry(pin)
    return pp is not None and str(pp.entry.get("io_standard") or "").lower() == "analog"


def _logic_pair(ctx, d, r):
    """A driver/receiver pair that logic thresholds apply to."""
    return r.component is not d.component and not _analog(ctx, d) and not _analog(ctx, r)


def _roles(ctx, sig):
    """(drivers, receivers) as (pin, type, source) lists."""
    pt = _pin_types(ctx)
    drivers, receivers = [], []
    for p in sig.pins:
        t, s = pt.base(p)
        if t in ("output", "io", "open_collector"):
            drivers.append((p, t, s))
        if t in ("input", "io"):
            receivers.append((p, t, s))
    return drivers, receivers


def _sev(*sources):
    return ERROR if all(s in (PART, CONSTRAINTS) for s in sources) else WARNING


def _who(pl, pin):
    std = f" {pl.io_std}" if pl and pl.io_std else ""
    name = f" {pin.name}" if pin.name and pin.name != pin.designator else ""
    return f"{pin.ref}{name}{std}"


def _high_sources(ctx, sig, lv, drivers):
    """[(volts, label, component or None)] for everything that can pull the
    signal high: a driver's supply, or the resistive level."""
    out = []
    for d, t, _ in drivers:
        if t == "open_collector":
            continue
        pl = lv.for_pin(d)
        v = lv.own_supply(pl) if pl else None
        if v is not None:
            out.append((v, f"{_who(pl, d)} (supply {v:g} V)", d.component, d))
    level = sig.resistive_level()
    if level is not None:
        out.append((*level, None, None))
    return out


def series_ohms(ctx, sig, a, b):
    """Least total resistance of series resistors between nets a and b of
    a signal; 0 on the same net, None when they are not joined that way."""
    if a == b:
        return 0.0
    import heapq
    members = set(sig.nets)
    best, heap = {a: 0.0}, [(0.0, a)]
    while heap:
        d, n = heapq.heappop(heap)
        if n == b:
            return d
        if d > best.get(n, float("inf")):
            continue
        for q in ctx.design.nets[n].pins:
            comp = q.component
            if ctx.kind(comp) != "resistor" or len(comp.pins) != 2:
                continue
            other = next(x.net for x in comp.pins if x is not q)
            ohms = _ohms(ctx, comp)
            if other in members and ohms is not None and d + ohms < best.get(other, float("inf")):
                best[other] = d + ohms
                heapq.heappush(heap, (d + ohms, other))
    return None


@check("LVL001", "Driver high level below receiver threshold", ERROR, needs_partsdb=True)
def high_level(ctx):
    lv = _levels(ctx)
    for sig in signals(ctx):
        drivers, receivers = _roles(ctx, sig)
        for d, dt, ds in drivers:
            dl = lv.for_pin(d)
            if dt == "open_collector":
                high = sig.resistive_level()
            else:
                voh, _ = lv.value(dl, "voh", "min", "low") if dl else (None, None)
                high = (voh, f"{_who(dl, d)} VOH min {voh:.3g} V") if voh is not None else None
            if high is None:
                continue
            for r, rt, rs in receivers:
                if not _logic_pair(ctx, d, r):
                    continue
                rl = lv.for_pin(r)
                if rl is None:
                    continue
                vih, key = lv.value(rl, "vih", "min", "high")
                if vih is None:
                    vih, key = lv.value(rl, "vt_pos", "max", "high")
                if vih is not None and high[0] < vih - _EPS:
                    yield Finding("LVL001", f"'{sig.name}': {high[1]} is below {_who(rl, r)} "
                                            f"{'VIH min' if key.startswith('vih') else 'VT+ max'} {vih:.3g} V",
                                  severity=_sev(ds, rs), refs=sorted({d.component.designator, r.component.designator},
                                                                     key=natural_key), nets=list(sig.nets))


@check("LVL002", "Driver low level above receiver threshold", ERROR, needs_partsdb=True)
def low_level(ctx):
    lv = _levels(ctx)
    for sig in signals(ctx):
        drivers, receivers = _roles(ctx, sig)
        for d, dt, ds in drivers:
            dl = lv.for_pin(d)
            if dl is None:
                continue
            vol, _ = lv.value(dl, "vol", "max", "high")
            if vol is None:
                continue
            for r, rt, rs in receivers:
                if not _logic_pair(ctx, d, r):
                    continue
                rl = lv.for_pin(r)
                if rl is None:
                    continue
                vil, key = lv.value(rl, "vil", "max", "low")
                if vil is None:
                    vil, key = lv.value(rl, "vt_neg", "min", "low")
                if vil is not None and vol > vil + _EPS:
                    yield Finding("LVL002", f"'{sig.name}': {_who(dl, d)} VOL max {vol:.3g} V is above "
                                            f"{_who(rl, r)} {'VIL max' if key.startswith('vil') else 'VT- min'} {vil:.3g} V",
                                  severity=_sev(ds, rs), refs=sorted({d.component.designator, r.component.designator},
                                                                     key=natural_key), nets=list(sig.nets))


def _amplifier_input(ctx, pin):
    pp = _pin_types(ctx).part_entry(pin)
    return bool(pp) and pp.entry.get("function") in ("OPAMP_IN_P", "OPAMP_IN_N", "COMPARATOR_IN_P",
                                                     "COMPARATOR_IN_N")


@check("LVL003", "Input driven above its rated voltage", ERROR, needs_partsdb=True)
def input_overvoltage(ctx):
    """The highest level on the signal (a driver's supply, or the pull-up /
    divider level) against each receiver's absolute maximum (vi_abs) and
    recommended maximum (vi_op, else the VIH row's maximum; for op-amp and
    comparator inputs the common-mode range is left to ANA001, which judges
    both inputs of a channel together). A driver is not
    checked against inputs of its own part (an op amp's feedback). One
    finding per source and limit kind, naming every receiver it exceeds."""
    lv = _levels(ctx)
    clamp_totals = defaultdict(list)
    for sig in signals(ctx):
        drivers, receivers = _roles(ctx, sig)
        highs = _high_sources(ctx, sig, lv, drivers)
        if not highs:
            continue
        limits = []
        for r, rt, rs in receivers:
            rl = lv.for_pin(r)
            if rl is None:
                continue
            abs_max, _ = lv.value(rl, "vi_abs", "max", "low")
            op_max, key = None, None
            if not _amplifier_input(ctx, r):     # their common-mode range is ANA001's, per channel
                op_max, key = lv.value(rl, "vi_op", "max", "low")
                if op_max is None:
                    op_max, key = lv.value(rl, "vih", "max", "low")
            limits.append((r, rs, rl, abs_max, op_max, key))
        for v, label, source, dpin in highs:
            over = {"absolute": [], "clamped": [], "recommended": []}
            for r, rs, rl, abs_max, op_max, key in limits:
                if r.component is source:
                    continue
                if abs_max is not None and v > abs_max + _EPS:
                    # Driven beyond the rating, but a series resistor may hold
                    # the clamp current within what the data sheet allows.
                    i_max = lv.value(rl, "ii_clamp", "max", "low")[0]
                    ohms = series_ohms(ctx, sig, dpin.net, r.net) if dpin is not None else None
                    amps = (v - abs_max) / ohms if ohms else None
                    if amps is not None and i_max is not None and amps <= i_max + _EPS:
                        over["clamped"].append((r, rs, f"{_who(rl, r)} {abs_max:.3g} V through {ohms:g} ohm: "
                                                          f"{amps * 1000:.2g} mA of clamp current, within its "
                                                          f"{i_max * 1000:g} mA rating"))
                        clamp_totals[r.component.designator].append((r, amps, rl))
                    else:
                        extra = ""
                        if amps is not None:
                            extra = f" ({amps * 1000:.2g} mA through {ohms:g} ohm" + (
                                f", above its {i_max * 1000:g} mA clamp rating)" if i_max is not None
                                else "; the data sheet gives no clamp current)")
                        over["absolute"].append((r, rs, f"{_who(rl, r)} {abs_max:.3g} V{extra}"))
                elif op_max is not None and v > op_max + _EPS:
                    over["recommended"].append((r, rs, f"{_who(rl, r)} {op_max:.3g} V ({key})"))
            for kind, hits in over.items():
                if hits:
                    word = "absolute" if kind == "clamped" else kind
                    yield Finding("LVL003", f"'{sig.name}': {label} exceeds the {word} maximum input of "
                                            + ", ".join(h[2] for h in hits),
                                  severity=WARNING if kind == "clamped" else _sev(*(h[1] for h in hits)),
                                  refs=sorted({h[0].component.designator for h in hits}
                                              | ({source.designator} if source is not None else set()), key=natural_key),
                                  nets=list(sig.nets))
    # Current-limited clamps add up in the package.
    for desig, hits in sorted(clamp_totals.items(), key=lambda x: natural_key(x[0])):
        pins = {}
        for r, amps, rl in hits:
            pins[r.designator] = max(amps, pins.get(r.designator, 0.0))
        pkg = lv.value(hits[0][2], "ii_clamp_package", "max", "low")[0]
        total = sum(pins.values())
        if pkg is not None and len(pins) > 1 and total > pkg + _EPS:
            comp = hits[0][0].component
            yield Finding("LVL003", f"{desig} ({comp.part_number}): {len(pins)} inputs can be driven beyond its "
                                    f"supplies at once through current-limiting resistors, {total * 1000:.3g} mA in "
                                    f"total, above the {pkg * 1000:g} mA package rating",
                          refs=[desig], part_number=comp.part_number)


@check("LVL004", "FPGA I/O standard not supported at its bank voltage", ERROR, needs_partsdb=True)
def io_standard_vs_bank(ctx):
    """Each constrained I/O standard's recommended bank supply range
    (supply_* rows conditioned on io_standard) against the rail on the
    bank's supply pins."""
    lv = _levels(ctx)
    seen = set()
    for desig in sorted(ctx.fpgas, key=natural_key):
        comp = ctx.design.components.get(desig)
        f = ctx.fpga_for(comp) if comp is not None else None
        if f is None:
            continue
        for pin in sorted(comp.pins, key=lambda p: natural_key(p.designator)):
            pl = lv.for_pin(pin)
            bank = f.bank(pin)
            if pl is None or bank is None or (desig, bank, pl.io_std) in seen:
                continue
            seen.add((desig, bank, pl.io_std))
            rail = lv.supply_volts(pl, pl.supply)
            if rail is None:
                continue
            ranges = []
            for key, char in pl.chars.items():
                if not key.startswith("supply_") or not isinstance(char, dict):
                    continue
                for row in char.get("rows") or []:
                    std = ((row.get("conditions") or {}).get("io_standard") or {}).get("value")
                    std = std if isinstance(std, list) else [std]
                    if pl.io_std.upper() in {str(s).upper() for s in std} and ("min" in row or "max" in row):
                        ranges.append((row.get("min", float("-inf")), row.get("max", float("inf"))))
            if ranges and not any(lo - _EPS <= rail <= hi + _EPS for lo, hi in ranges):
                span = ", ".join(f"{lo:g}-{hi:g} V" for lo, hi in ranges)
                yield Finding("LVL004", f"{desig} bank {bank}: {pl.io_std} needs its I/O supply at {span}; "
                                        f"{f.supply_pin_name(bank)} is at {rail:g} V", refs=[desig])


def _drive_levels(lv, sig, pin, ptype):
    """True when a driver's high and low levels are known."""
    if ptype == "open_collector":
        return sig.resistive_level() is not None
    pl = lv.for_pin(pin)
    return pl is not None and lv.value(pl, "voh", "min", "low")[0] is not None \
        and lv.value(pl, "vol", "max", "high")[0] is not None


def _input_levels(lv, pin):
    """True when a receiver's thresholds are known."""
    pl = lv.for_pin(pin)
    if pl is None:
        return False
    high = lv.value(pl, "vih", "min", "high")[0] if lv.value(pl, "vih", "min", "high")[0] is not None \
        else lv.value(pl, "vt_pos", "max", "high")[0]
    low = lv.value(pl, "vil", "max", "low")[0] if lv.value(pl, "vil", "max", "low")[0] is not None \
        else lv.value(pl, "vt_neg", "min", "low")[0]
    return high is not None and low is not None


def level_coverage(ctx):
    """(checked, total, gaps): logic driver/receiver pairs on signals (pairs
    with an analog end are left out; LVL003 still covers them), how many had
    levels resolved at both ends (thresholds found and every supply they
    reference on a known rail), and {part number: pins that did not}."""
    if ctx.partsdb is None:
        return 0, 0, {}
    lv = _levels(ctx)
    checked = total = 0
    gaps = defaultdict(set)
    verify = set(ctx.config["pins"]["verify_kinds"])
    for sig in signals(ctx):
        drivers, receivers = _roles(ctx, sig)
        for d, dt, _ in drivers:
            for r, _, _ in receivers:
                if not _logic_pair(ctx, d, r):
                    continue
                total += 1
                ends = [(d, _drive_levels(lv, sig, d, dt)), (r, _input_levels(lv, r))]
                for p, ok in ends:
                    if not ok and ctx.kind(p.component) in verify:
                        gaps[p.component.part_number or "(none)"].add(p.ref)
                checked += all(ok for _, ok in ends)
    return checked, total, dict(gaps)


@check("LVL005", "Logic levels not checked: part has no level data", INFO, needs_partsdb=True)
def level_gaps(ctx):
    _, _, gaps = level_coverage(ctx)
    for pn, refs in sorted(gaps.items(), key=lambda kv: (-len(kv[1]), kv[0])):
        comps = sorted({r.split(".")[0] for r in refs}, key=natural_key)
        yield Finding("LVL005", f"{pn}: {len(refs)} pin(s) on {', '.join(comps[:8])}"
                                f"{' ...' if len(comps) > 8 else ''} drive or receive logic signals but their "
                                "levels could not be resolved: no voh/vol/vih/vil data for the pin, no FPGA "
                                "I/O standard, or a referenced supply not on a known rail",
                      refs=comps, part_number=pn if pn != "(none)" else None)
