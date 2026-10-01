"""Checks across boards joined by connectors.

A system file names the boards (each export with its own boardcheck.yaml)
and the connector links between them:

    boards:
      CM-03545: {export: CM-03545/CM-03545.json, config: CM-03545/boardcheck.yaml}
      CM-02441: {export: CM-02441/CM-02441.json, config: CM-02441/boardcheck.yaml}
    links:
      - name: sensor
        a: CM-03545:J7
        b: CM-02441:J1
        map: pins                     # mated directly: pin n to pin n
      - name: ethernet harness
        a: CM-03545:J3
        b: CM-03986:J2
        map:                          # a harness, wired by signal name
          by: name
          a: 'ETH1_MX(\\d)_([PN])$'   # regex on the net at each pin; the
          b: 'Q8J_ETH5_TX(\\d)_([PN])$'   # groups pair the pins up

Each link pairs a pin of one connector with a pin of the other. Each side is
judged with its own board's configuration, pin types and level data, and
signals are followed through series resistors on each board as for the
level checks.
"""

import os
import re

import yaml

from .checks import ERROR, INFO, WARNING, Context, Finding, load_all
from .config import Config
from .model import Design, natural_key


class Board:
    def __init__(self, name, design, config, partsdb):
        self.name = name
        self.design = design
        self.config = config
        self.ctx = Context(design, config, partsdb)


class Link:
    def __init__(self, name, a, b, pairs, unmatched):
        self.name = name
        self.a = a                  # (board, connector component)
        self.b = b
        self.pairs = pairs          # [(pin a, pin b)]
        self.unmatched = unmatched  # [(board name, pin)]


class System:
    def __init__(self, boards, links, problems):
        self.boards = boards        # {name: Board}
        self.links = links
        self.problems = problems

    @classmethod
    def load(cls, path, partsdb=None):
        load_all()
        base = os.path.dirname(os.path.abspath(path))
        with open(path, encoding="utf-8") as f:
            spec = yaml.safe_load(f) or {}
        boards, problems = {}, []
        for name, b in (spec.get("boards") or {}).items():
            design = Design.load(os.path.join(base, b["export"]))
            config = Config.load(os.path.join(base, b["config"])) if b.get("config") else Config()
            boards[name] = Board(name, design, config, partsdb)
        links = []
        for i, ls in enumerate(spec.get("links") or []):
            name = ls.get("name") or f"link {i + 1}"
            ends = []
            for key in ("a", "b"):
                bname, _, desig = str(ls[key]).partition(":")
                board = boards.get(bname)
                comp = board.design.components.get(desig) if board else None
                if comp is None:
                    problems.append(f"{name}: {ls[key]} not found")
                ends.append((board, comp))
            if any(c is None for _, c in ends):
                continue
            pairs, unmatched = _pair(ends[0], ends[1], ls.get("map", "pins"))
            links.append(Link(name, ends[0], ends[1], pairs, unmatched))
        return cls(boards, links, problems)


def _pair(a, b, mapping):
    (ba, ca), (bb, cb) = a, b
    if mapping == "pins":
        pb = {str(p.designator): p for p in cb.pins}
        pairs = [(p, pb[str(p.designator)]) for p in ca.pins if str(p.designator) in pb]
        paired_a = {id(x) for x, _ in pairs}
        paired_b = {id(y) for _, y in pairs}
    else:
        ra, rb = re.compile(mapping["a"]), re.compile(mapping["b"])
        keys_b = {}
        for p in cb.pins:
            m = rb.search(p.net)
            if m:
                keys_b.setdefault(m.groups(), p)
        pairs = []
        for p in ca.pins:
            m = ra.search(p.net)
            if m and m.groups() in keys_b:
                pairs.append((p, keys_b[m.groups()]))
        paired_a = {id(x) for x, _ in pairs}
        paired_b = {id(y) for _, y in pairs}
    unmatched = [(ba.name, p) for p in ca.pins if id(p) not in paired_a] + \
                [(bb.name, p) for p in cb.pins if id(p) not in paired_b]
    pairs.sort(key=lambda x: natural_key(x[0].designator))
    return pairs, unmatched


# -- checks ----------------------------------------------------------------------

def _where(board, pin):
    return f"{board.name} {pin.ref} '{pin.net}'"


def _is_open(board, pin):
    """The connector pin is the only thing on its net."""
    return len(board.design.nets[pin.net].pins) <= 1


def _side(board, pin):
    """(signal, drivers, receivers) on the board for the net at a connector pin;
    None when the net is a rail or ground."""
    from .checks.levels import _roles, signals
    cfg = board.config
    if cfg.is_ground(pin.net) or cfg.net_voltage(pin.net) is not None:
        return None
    by_net = getattr(board, "_by_net", None)
    if by_net is None:
        by_net = board._by_net = {n: s for s in signals(board.ctx) for n in s.nets}
    sig = by_net.get(pin.net)
    if sig is None:
        return None
    drivers, receivers = _roles(board.ctx, sig)
    return sig, drivers, receivers


def check_open(system):
    """SYS001: a pin wired on one board and connected to nothing on the
    other: the signal ends at the connector."""
    for link in system.links:
        (ba, _), (bb, _) = link.a, link.b
        for pa, pb in link.pairs:
            oa, ob = _is_open(ba, pa), _is_open(bb, pb)
            if oa != ob:
                used, unused = ((bb, pb), (ba, pa)) if oa else ((ba, pa), (bb, pb))
                yield Finding("SYS001", f"{link.name}: {_where(*used)} reaches {_where(*unused)}, which is connected "
                                        "to nothing on that board", severity=WARNING,
                              refs=[f"{ba.name}:{pa.component.designator}", f"{bb.name}:{pb.component.designator}"],
                              nets=[pa.net, pb.net])


def check_supplies(system):
    """SYS002: ground against non-ground, or rails of different nominal
    voltages, meeting at a connector (each judged by its own board's net
    naming); a rail against a signal is a warning."""
    for link in system.links:
        (ba, _), (bb, _) = link.a, link.b
        for pa, pb in link.pairs:
            if _is_open(ba, pa) or _is_open(bb, pb):
                continue
            ga, gb = ba.config.is_ground(pa.net), bb.config.is_ground(pb.net)
            va = None if ga else ba.config.net_voltage(pa.net)
            vb = None if gb else bb.config.net_voltage(pb.net)
            what, sev = None, ERROR
            if ga != gb:
                what = "ground meets " + ("a rail" if (va if gb else vb) is not None else "a signal")
            elif va is not None and vb is not None and abs(va - vb) > 1e-6:
                what = f"a {va:g} V rail meets a {vb:g} V rail"
            elif (va is None) != (vb is None) and not (ga or gb):
                what, sev = "a rail meets a signal", WARNING
            if what:
                yield Finding("SYS002", f"{link.name}: {_where(ba, pa)} <-> {_where(bb, pb)}: {what}", severity=sev,
                              refs=[f"{ba.name}:{pa.component.designator}", f"{bb.name}:{pb.component.designator}"],
                              nets=[pa.net, pb.net])


def check_polarity(system):
    """SYS003: one half of a differential pair on one board wired to the
    other half on the other (by each board's diff_pair_suffixes)."""
    for link in system.links:
        (ba, _), (bb, _) = link.a, link.b
        for pa, pb in link.pairs:
            sa, sb = _polarity(ba.config, pa.net), _polarity(bb.config, pb.net)
            if sa and sb and sa != sb:
                yield Finding("SYS003", f"{link.name}: {_where(ba, pa)} ({sa}) <-> {_where(bb, pb)} ({sb}): "
                                        "differential polarity swapped", severity=ERROR,
                              refs=[f"{ba.name}:{pa.component.designator}", f"{bb.name}:{pb.component.designator}"],
                              nets=[pa.net, pb.net])


def _polarity(config, net):
    n = config["nets"]
    if any(re.search(p, net) for p in n["diff_pair_ignore"]):
        return None
    for pos, neg in n["diff_pair_suffixes"]:
        if net.endswith(pos):
            return "+"
        if net.endswith(neg):
            return "-"
    return None


def _unknown(board, sig):
    """Pins on the signal whose type is known only as the symbol's "passive"
    (or not at all): a part without pin data that may well be a driver."""
    from .checks.pins import PART, _pin_types
    pt = _pin_types(board.ctx)
    return [p for p in sig.pins if pt.base(p)[0] in (None, "passive") and pt.base(p)[1] != PART]


def check_drivers(system):
    """SYS004: push-pull outputs on both boards (contention), or receivers
    with nothing driving them on either board."""
    for link in system.links:
        (ba, _), (bb, _) = link.a, link.b
        for pa, pb in link.pairs:
            sa, sb = _side(ba, pa), _side(bb, pb)
            if sa is None or sb is None:
                continue
            da = [d for d in sa[1] if d[1] == "output"]
            db = [d for d in sb[1] if d[1] == "output"]
            refs = [f"{ba.name}:{pa.component.designator}", f"{bb.name}:{pb.component.designator}"]
            if da and db:
                yield Finding("SYS004", f"{link.name}: {_where(ba, pa)} <-> {_where(bb, pb)}: driven from both boards "
                                        f"({', '.join(f'{ba.name} {d[0].ref}' for d in da)}; "
                                        f"{', '.join(f'{bb.name} {d[0].ref}' for d in db)})",
                              severity=ERROR, refs=refs, nets=[pa.net, pb.net])
            elif not sa[1] and not sb[1] and (sa[2] or sb[2]) and not (sa[0].ties or sb[0].ties) \
                    and not _unknown(ba, sa[0]) and not _unknown(bb, sb[0]):
                rx = [f"{ba.name} {r[0].ref}" for r in sa[2]] + [f"{bb.name} {r[0].ref}" for r in sb[2]]
                yield Finding("SYS004", f"{link.name}: {_where(ba, pa)} <-> {_where(bb, pb)}: nothing drives "
                                        f"{', '.join(rx)} on either board", severity=WARNING, refs=refs,
                              nets=[pa.net, pb.net])


def check_levels(system):
    """SYS005: a driver on one board against the receivers on the other:
    VOH min below VIH, VOL max above VIL, or the driver's supply above the
    receiver's absolute maximum input."""
    from .checks.levels import _analog, _levels, input_thresholds
    for link in system.links:
        (ba, _), (bb, _) = link.a, link.b
        for pa, pb in link.pairs:
            sa, sb = _side(ba, pa), _side(bb, pb)
            if sa is None or sb is None:
                continue
            for (dbd, ds), (rbd, rs) in (((ba, sa), (bb, sb)), ((bb, sb), (ba, sa))):
                lvd, lvr = _levels(dbd.ctx), _levels(rbd.ctx)
                for d, dt, _ in ds[1]:
                    if dt == "open_collector" or _analog(dbd.ctx, d):
                        continue
                    dl = lvd.for_pin(d)
                    if dl is None:
                        continue
                    voh = lvd.value(dl, "voh", "min", "low")[0]
                    vol = lvd.value(dl, "vol", "max", "high")[0]
                    vsup = lvd.own_supply(dl)
                    for r, _, _ in rs[2]:
                        if _analog(rbd.ctx, r):
                            continue
                        rl = lvr.for_pin(r)
                        if rl is None:
                            continue
                        vil, vih = input_thresholds(lvr, rl)
                        vabs = lvr.value(rl, "vi_abs", "max", "low")[0]
                        who = f"{link.name}: {dbd.name} {d.ref} on '{d.net}' -> {rbd.name} {r.ref} on '{r.net}'"
                        refs = [f"{dbd.name}:{d.component.designator}", f"{rbd.name}:{r.component.designator}"]
                        if vsup is not None and vabs is not None and vsup > vabs + 1e-9:
                            yield Finding("SYS005", f"{who}: driver supply {vsup:g} V above the input's absolute "
                                                    f"maximum {vabs:.3g} V", severity=ERROR, refs=refs,
                                          nets=[d.net, r.net])
                        elif voh is not None and vih is not None and voh < vih - 1e-9:
                            yield Finding("SYS005", f"{who}: VOH min {voh:.3g} V below VIH {vih:.3g} V",
                                          severity=ERROR, refs=refs, nets=[d.net, r.net])
                        if vol is not None and vil is not None and vol > vil + 1e-9:
                            yield Finding("SYS005", f"{who}: VOL max {vol:.3g} V above VIL {vil:.3g} V",
                                          severity=ERROR, refs=refs, nets=[d.net, r.net])


def check_map(system):
    """SYS006: each link's pairing, and pins left without a partner."""
    for p in system.problems:
        yield Finding("SYS006", p, severity=WARNING)
    for link in system.links:
        (ba, ca), (bb, cb) = link.a, link.b
        loose = [f"{bname} {p.ref} '{p.net}'" for bname, p in link.unmatched
                 if not system.boards[bname].config.is_ground(p.net)
                 and len(system.boards[bname].design.nets[p.net].pins) > 1]
        text = (f"{link.name}: {ba.name} {ca.designator} <-> {bb.name} {cb.designator}, {len(link.pairs)} pins paired")
        if loose:
            text += f"; wired but unpaired: {', '.join(loose)}"
        unknown = sorted({f"{b.name} {p.component.designator} ({p.component.part_number})"
                          for pa, pb in link.pairs for b, pin in ((ba, pa), (bb, pb))
                          for side in [_side(b, pin)] if side for p in _unknown(b, side[0])})
        if unknown:
            text += f"; drive and levels not judged for parts without pin data: {', '.join(unknown)}"
        yield Finding("SYS006", text, severity=INFO,
                      refs=[f"{ba.name}:{ca.designator}", f"{bb.name}:{cb.designator}"])


CHECKS = [("SYS001", "Pin connected on one board only", check_open),
          ("SYS002", "Ground or rail mismatch across a connector", check_supplies),
          ("SYS003", "Differential polarity swapped across boards", check_polarity),
          ("SYS004", "Signal driven from both boards, or from neither", check_drivers),
          ("SYS005", "Logic levels incompatible across boards", check_levels),
          ("SYS006", "Interconnect map", check_map)]


def run_system(system):
    out = []
    for _, _, func in CHECKS:
        out.extend(func(system))
    order = {ERROR: 0, WARNING: 1, INFO: 2}
    out.sort(key=lambda f: (order.get(f.severity, 3), f.check, f.message))
    return out


def text(findings):
    tag = {ERROR: "E", WARNING: "W", INFO: "I"}
    return "\n".join(f"[{tag.get(f.severity, '?')}] {f.check} {f.message}" for f in findings)


def markdown(system, findings):
    lines = ["## System interconnect", "", "| Check | Severity | Finding |", "|---|---|---|"]
    lines += [f"| {f.check} | {f.severity} | {f.message.replace('|', '/')} |" for f in findings]
    return "\n".join(lines) + "\n"
