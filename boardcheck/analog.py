"""Small-signal DC analysis of resistor and ideal op-amp networks.

Used to work out what an ADC channel measures: the gain from a shunt
resistor's sense terminals (or any source nets) to the ADC input.

The network is grown from a starting net through two-terminal resistors and
through op-amps (from an output to its two inputs). Capacitors and other IC
pins are open. Nets with a fixed voltage (rails, ground, sense nodes) and
the sense terminals of shunt resistors stop the growth and act as sources.
Op-amps are ideal: an op-amp's output node has no KCL equation; instead its
inputs are equal (V+ = V-). The solution is by modified nodal analysis.
"""

import re

from .units import parse_value

# Op-amp pins by name when the part has no pin data: "+IN A", "-IN 4", "OUT B", "VOUT 2"
_OPAMP_IN = re.compile(r"^\s*([+-])\s*IN\s*([A-Z0-9]?)\s*$", re.I)
_OPAMP_OUT = re.compile(r"^\s*V?OUT\s*([A-Z0-9]?)\s*$", re.I)
_OPAMP_FUNCS = {"OPAMP_OUT": "out", "OPAMP_IN_P": "+", "OPAMP_IN_N": "-"}


def resistance(ctx, comp):
    ohms = parse_value(ctx.design.param(comp, "R_Value"), "Ω")
    if ohms is None:
        decoded = ctx.decoded(comp)
        ohms = decoded.resistance if decoded else None
    return ohms


def pin_key(pin):
    return pin.component.designator, str(pin.designator)


def opamp_roles(ctx, comp):
    """{pin key: (channel, role, pin)} with role "+", "-" or "out", for an
    op-amp recognised by its part data functions (OPAMP_OUT, OPAMP_IN_P,
    OPAMP_IN_N) or, for pins without part data, its pin names; {} otherwise.
    Pin keys are `pin_key(pin)`."""
    from .checks.pins import _pin_types
    pt = _pin_types(ctx)
    roles = {}
    for p in comp.pins:
        pp = pt.part_entry(p)
        func = pp.entry.get("function") if pp else None
        if func in _OPAMP_FUNCS:
            ch = re.sub(r"^[+-]?\s*(IN|OUT)\s*", "", pp.key, flags=re.I).strip() or "0"
            roles[pin_key(p)] = (ch, _OPAMP_FUNCS[func], p)
            continue
        if pp is not None:      # the part data says what the pin is: a comparator is no op-amp
            continue
        m = _OPAMP_IN.match(p.name or "")
        if m:
            roles[pin_key(p)] = (m.group(2) or "0", m.group(1), p)
            continue
        m = _OPAMP_OUT.match(p.name or "")
        if m:
            roles[pin_key(p)] = (m.group(1) or "0", "out", p)
    chans = {}
    for ch, role, p in roles.values():
        chans.setdefault(ch, {})[role] = p
    return {k: r for k, r in roles.items() if set(chans[r[0]]) == {"+", "-", "out"}}


def shunt_terminals(ctx, comp, max_ohms):
    """(net a, net b, ohms) for a shunt resistor: a two-terminal resistor at
    or below max_ohms, or a four-terminal (Kelvin) one, whose sense pins
    are E1/E2 (or S1/S2, SENSE+/-). None otherwise."""
    if ctx.kind(comp) != "resistor":
        return None
    ohms = resistance(ctx, comp)
    if ohms is None or ohms > max_ohms:
        return None
    if len(comp.pins) == 2:
        return comp.pins[0].net, comp.pins[1].net, ohms
    sense = [p for p in comp.pins if re.match(r"^(E|S|SENSE)\s*[12+-]$", (p.name or "").strip(), re.I)]
    if len(sense) == 2:
        return sense[0].net, sense[1].net, ohms
    return None


_OPEN_KINDS = {"capacitor", "testpoint", "mechanical"}
_SHORT_KINDS = {"inductor", "ferrite"}     # DC: a short
_SHORT_OHMS = 1e-3


class Network:
    """The resistor / op-amp network grown from a net.

    `unknown` lists pins on the network's nodes that may drive it with
    something other than a resistor, a fixed rail or an op-amp: outputs of
    other parts, connectors, diodes, parts without pin types. The small-signal
    gain from a shunt ignores them; a DC operating point is only meaningful
    without them."""

    def __init__(self, ctx, start, shunt_max_ohms=0.1, max_nodes=60):
        from .checks.pins import _pin_types
        self.ctx = ctx
        pt = _pin_types(ctx)
        self.nodes = [start]
        self.fixed = {}             # net -> nominal volts (rails, ground, sense)
        self.shunts = {}            # designator -> (net a, net b, ohms)
        self.edges = []             # (net, net, ohms, comp)
        self.opamps = {}            # output net -> (+ net, - net, comp)
        self.outputs = {}           # output net -> op-amp output pin
        self.unknown = []           # pins that may drive a node some other way
        self.ok = True
        seen = set()
        i = 0
        while i < len(self.nodes) and self.ok:
            net = self.nodes[i]
            i += 1
            for q in ctx.design.nets[net].pins:
                comp = q.component
                kind = ctx.kind(comp)
                sh = shunt_terminals(ctx, comp, shunt_max_ohms)
                if sh:
                    self.shunts[comp.designator] = sh
                    self.fixed.setdefault(net, None)
                    continue
                if kind in {"resistor"} | _SHORT_KINDS and len(comp.pins) == 2:
                    if comp.designator in seen:
                        continue
                    seen.add(comp.designator)
                    ohms = resistance(ctx, comp) if kind == "resistor" else _SHORT_OHMS
                    other = next(p.net for p in comp.pins if p is not q)
                    if ohms is None:
                        self.ok = False
                        break
                    self.edges.append((net, other, max(ohms, 1e-4), comp))
                    self._visit(other)
                    continue
                if kind in _OPEN_KINDS:
                    continue
                roles = opamp_roles(ctx, comp)
                role = roles.get(pin_key(q))
                if role:
                    if role[1] == "out":
                        ch = role[0]
                        pins = {r: p for c, r, p in roles.values() if c == ch}
                        self.opamps[net] = (pins["+"].net, pins["-"].net, comp)
                        self.outputs[net] = q
                        self._visit(pins["+"].net)
                        self._visit(pins["-"].net)
                    continue
                if pt.base(q)[0] != "input":
                    self.unknown.append(q)
            if len(self.nodes) > max_nodes:
                self.ok = False
        # Kelvin sense nets are often named after their rail ("1V1_RSENSE_P")
        # and so stop the growth as fixed nets; a shunt on one is still found.
        for net in list(self.fixed):
            for q in ctx.design.nets[net].pins:
                sh = shunt_terminals(ctx, q.component, shunt_max_ohms)
                if sh and q.net in sh[:2]:
                    self.shunts[q.component.designator] = sh

    def _visit(self, net):
        cfg = self.ctx.config
        if net in self.fixed or net in self.nodes:
            return
        if cfg.is_ground(net) or cfg.net_voltage(net) is not None:
            self.fixed[net] = 0.0 if cfg.is_ground(net) else cfg.net_voltage(net)
            return
        self.nodes.append(net)

    def solve(self, sources):
        """Node voltages with the given source voltages ({net: volts}); nets
        in `fixed` not in `sources` are held at 0 (small-signal). None when
        the network is singular."""
        from .checks.power import _solve
        unknown = [n for n in self.nodes if n not in sources and n not in self.fixed]
        idx = {n: j for j, n in enumerate(unknown)}
        val = lambda n: sources.get(n, 0.0)          # noqa: E731
        a = [[0.0] * len(unknown) for _ in unknown]
        b = [0.0] * len(unknown)
        for n in unknown:
            r = idx[n]
            if n in self.opamps:
                plus, minus, _ = self.opamps[n]
                for net, sign in ((plus, 1.0), (minus, -1.0)):
                    if net in idx:
                        a[r][idx[net]] += sign
                    else:
                        b[r] -= sign * val(net)
                continue
            for x, y, ohms, _ in self.edges:
                if n not in (x, y):
                    continue
                other = y if x == n else x
                g = 1.0 / ohms
                a[r][r] += g
                if other in idx:
                    a[r][idx[other]] -= g
                else:
                    b[r] += g * val(other)
        sol = _solve(a, b) if unknown else []
        if sol is None:
            return None
        out = {n: sol[idx[n]] for n in unknown}
        out.update({n: val(n) for n in self.fixed})
        out.update(sources)
        return out


def current_gain(ctx, adc_net, shunt_max_ohms=0.1):
    """(volts at adc_net per volt across the shunt, shunt designator, ohms,
    network) for an ADC input fed from one shunt through resistors and
    op-amps; None when the network has no single shunt or cannot be solved."""
    net = Network(ctx, adc_net, shunt_max_ohms)
    if not net.ok or len(net.shunts) != 1:
        return None
    desig, (a, b, ohms) = next(iter(net.shunts.items()))
    if a not in net.nodes + list(net.fixed) or b not in net.nodes + list(net.fixed):
        return None
    sol = net.solve({a: 1.0, b: 0.0})
    if sol is None or adc_net not in sol:
        return None
    return abs(sol[adc_net]), desig, ohms, net


def operating_point(net):
    """{net: volts} with no shunt current: every fixed net at its nominal
    voltage and both terminals of each shunt at the same voltage. None when
    the network cannot be solved (singular, e.g. an op-amp without
    feedback)."""
    sources = {n: v for n, v in net.fixed.items() if v is not None}
    for a, b, _ in net.shunts.values():
        v = sources.get(a) if sources.get(a) is not None else sources.get(b)
        sources[a] = sources[b] = v if v is not None else 0.0
    return net.solve(sources)


def zero_output(net, adc_net):
    """Volts at adc_net with no shunt current, or None."""
    sol = operating_point(net)
    return sol.get(adc_net) if sol else None
