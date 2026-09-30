"""SmartDesign hierarchies, bit by bit.

Libero exports each SmartDesign as a Tcl script: `sd_create_*_port` makes
its ports, `sd_instantiate_component` its instances (of cores or of other
SmartDesigns), `sd_connect_pins` joins pins into a net, and
`sd_connect_pins_to_constant` ties pins to VCC or GND. This module reads the
scripts under a design root (every `.tcl` below it that sets `sd_name`),
joins pins bit by bit (`inst:PIN[7:4]` with `port[3:0]`, LSB to LSB), and
follows a pin of an instance deep in the hierarchy up to the top-level port
it reaches.
"""

import os
import re

from .fpga import _commands, _words

# Libero macros a signal passes straight through: (pin, pin, inverts)
_PASS = {
    "TRIBUFF": [("D", "PAD", False)], "OUTBUF": [("D", "PAD", False)], "INBUF": [("PAD", "Y", False)],
    "BIBUF": [("D", "PAD", False), ("PAD", "Y", False)], "CLKINT": [("A", "Y", False)],
    "CLKBUF": [("PAD", "Y", False)], "INV": [("A", "Y", True)], "INVD": [("A", "Y", True)],
}

_RANGE = re.compile(r"^(?P<base>[^\[]+?)(?:\[(?P<hi>\d+)(?::(?P<lo>\d+))?\])?$")


def _opts(w):
    return {w[i][1].lstrip("-"): w[i + 1][1] for i in range(1, len(w) - 1, 2)}


class SmartDesign:
    def __init__(self, name, path):
        self.name = name
        self.path = path
        self.ports = {}             # name -> (direction, (hi, lo) or None)
        self.instances = {}         # instance -> component
        self.macros = {}            # instance -> macro (TRIBUFF, INBUF, INV, ...)
        self.nets = []              # [[ref, ...]] from sd_connect_pins
        self.constants = []         # [(ref, value)]
        self._parent = {}
        self._built = False

    @classmethod
    def read(cls, path):
        with open(path, encoding="utf-8", errors="replace") as f:
            text = f.read()
        m = re.search(r"set\s+sd_name\s+\{?([\w.]+)\}?", text)
        sd = cls(m.group(1) if m else os.path.splitext(os.path.basename(path))[0], path)
        for _, cmd in _commands(text):
            w = _words(cmd)
            if not w:
                continue
            op, o = w[0][1], _opts(w)
            if op in ("sd_create_scalar_port", "sd_create_bus_port") and o.get("port_name"):
                rng = re.fullmatch(r"\[\s*(\d+)\s*:\s*(\d+)\s*\]", (o.get("port_range") or "").strip())
                sd.ports[o["port_name"]] = (str(o.get("port_direction", "")).upper(),
                                            (int(rng.group(1)), int(rng.group(2))) if rng else None)
            elif op == "sd_instantiate_component" and o.get("instance_name"):
                sd.instances[o["instance_name"]] = o.get("component_name")
            elif op == "sd_instantiate_macro" and o.get("instance_name"):
                sd.macros[o["instance_name"]] = str(o.get("macro_name", "")).upper()
            elif op == "sd_connect_pins":
                sd.nets.append([x[1] for x in _words(o.get("pin_names", ""))])
            elif op == "sd_connect_pins_to_constant":
                for x in _words(o.get("pin_names", "")):
                    sd.constants.append((x[1], o.get("value")))
        return sd

    # -- bit-level connectivity ----------------------------------------------------

    def bits(self, ref):
        """[(base, bit)] LSB first for a pin reference; None for a bus of
        unknown width (an instance pin named without a slice)."""
        m = _RANGE.match(ref.strip())
        if not m:
            return None
        base = m.group("base")
        if m.group("hi") is not None:
            hi = int(m.group("hi"))
            lo = int(m.group("lo")) if m.group("lo") is not None else hi
            step = 1 if hi >= lo else -1
            return [(base, b) for b in range(lo, hi + step, step)] if step == 1 else \
                   [(base, b) for b in range(lo, hi - 1, -1)]
        if ":" not in base and base in self.ports:
            rng = self.ports[base][1]
            if rng is None:
                return [(base, None)]
            hi, lo = rng
            return [(base, b) for b in range(min(hi, lo), max(hi, lo) + 1)]
        return None if ":" in base else [(base, None)]

    def _find(self, x):
        p = self._parent
        p.setdefault(x, x)
        while p[x] != x:
            p[x] = p[p[x]]
            x = p[x]
        return x

    def _union(self, a, b):
        ra, rb = self._find(a), self._find(b)
        if ra != rb:
            self._parent[ra] = rb

    def _build(self):
        if self._built:
            return
        self._built = True
        self._const = {}
        for refs in self.nets:
            known = [self.bits(r) for r in refs]
            widths = {len(b) for b in known if b is not None}
            width = widths.pop() if len(widths) == 1 else (1 if not widths else None)   # all unsliced: scalars
            lists = []
            for r, b in zip(refs, known):
                if b is None and width is not None:
                    b = [(r, i) for i in range(width)] if width > 1 else [(r, None)]
                if b is not None and (width is None or len(b) == width):
                    lists.append(b)
            for i in range(width or 0):
                for lst in lists[1:]:
                    self._union(lists[0][i], lst[i])
        for ref, value in self.constants:
            for bit in self.bits(ref) or [(ref, None)]:
                self._const[self._find(bit)] = value

    def group(self, node):
        """All (base, bit) nodes joined with node."""
        self._build()
        root = self._find(node)
        return [n for n in list(self._parent) if self._find(n) == root], self._const.get(root)


class Hierarchy:
    """The SmartDesigns under a root directory, by name."""

    def __init__(self, root, top):
        self.root = root
        self.top = top
        self.files = {}
        self._designs = {}
        for d, _, names in os.walk(root):
            for n in names:
                if n.endswith(".tcl"):
                    path = os.path.join(d, n)
                    try:
                        with open(path, encoding="utf-8", errors="replace") as f:
                            m = re.search(r"set\s+sd_name\s+\{?([\w.]+)\}?", f.read(4096))
                    except OSError:
                        continue
                    if m:
                        self.files.setdefault(m.group(1), path)

    def design(self, name):
        if name not in self._designs:
            path = self.files.get(name)
            self._designs[name] = SmartDesign.read(path) if path else None
        return self._designs[name]

    def trace_up(self, path, pin, bit):
        """Follow instance pin `pin` bit `bit` of the instance at `path`
        (instance names from the top, e.g. ["hk_hier_inst", "gpo_inst"]) up
        to the top level, through buffer and inverter macros. Returns
        (kind, what, bit, inverted): ("port", name, bit, ...) for a
        top-level port, ("constant", value, None, ...), ("internal", text,
        None, ...) when it reaches only logic inside the design, or ("open",
        text, None, ...) when it connects to nothing."""
        designs = [self.design(self.top)]
        for inst in path[:-1]:
            sd = designs[-1]
            comp = sd.instances.get(inst) if sd else None
            if sd is None or comp is None:
                return "open", f"no instance '{inst}' in {sd.name if sd else '?'}", None, False
            designs.append(self.design(comp))
            if designs[-1] is None:
                return "open", f"SmartDesign '{comp}' not found under {self.root}", None, False
        node = (f"{path[-1]}:{pin}", bit)
        level, inverted, seen = len(designs) - 1, False, set()
        while (level, node) not in seen:
            seen.add((level, node))
            sd = designs[level]
            members, const = sd.group(node)
            seen.update((level, m) for m in members)
            ports = [(b, i) for b, i in members if ":" not in b and b in sd.ports]
            if ports:
                port, pbit = ports[0]
                if level == 0:
                    return "port", port, pbit, inverted
                node, level = (f"{path[level - 1]}:{port}", pbit), level - 1
                continue
            # through a buffer or inverter macro, either way
            step = None
            for b, i in members:
                inst, _, mpin = b.partition(":")
                for x, y, inv in _PASS.get(sd.macros.get(inst), []):
                    for a, z in ((x, y), (y, x)):
                        if mpin == a and (level, (f"{inst}:{z}", i)) not in seen:
                            step = ((f"{inst}:{z}", i), inv)
                if step:
                    break
            if step:
                node, inverted = step[0], inverted ^ step[1]
                continue
            if const is not None:
                return "constant", const, None, inverted
            where = f"{node[0]}{'' if node[1] is None else f'[{node[1]}]'}"
            others = sorted(f"{b}{'' if i is None else f'[{i}]'}" for b, i in members if (b, i) != node)
            if others:
                return "internal", f"{where} drives or reads {', '.join(others[:3])} inside {sd.name}", None, inverted
            return "open", f"{where} connects to nothing in {sd.name}", None, inverted
        return "open", "loop", None, inverted
