"""The elaborated design, for inspections that need more than the source text.

Verilator elaborates the device -- the same sources, variant and include path
the simulation compiles, vendor IP included -- and writes the result as JSON
(`--json-only`), without building a simulator. This reads that into modules
(one per parameterisation), their ports, parameters and instances, and every
always block with what it is sensitive to and what it assigns.

Cached under `sim_build/elaborated/`, keyed on the content of every input, so
an inspection pays for elaboration once per change to the design.
"""

from __future__ import annotations

import hashlib
import json
import re
import shutil
import subprocess
from dataclasses import dataclass, field
from pathlib import Path

from fsverif import sim

CACHE = sim.BUILD_DIR / "elaborated"


def _walk(node, kind: str):
    """Every node of type `kind` under `node`, depth first."""
    if isinstance(node, dict):
        if node.get("type") == kind:
            yield node
        for value in node.values():
            yield from _walk(value, kind)
    elif isinstance(node, list):
        for value in node:
            yield from _walk(value, kind)


def refs(expr) -> list:
    """Names of every variable an expression reads."""
    return [v["name"] for v in _walk(expr, "VARREF")]


#: Node types an expression may contain and still be wiring: selecting bits,
#: concatenating and constants (indices), with no logic.
WIRING = {"VARREF", "SEL", "CONCAT", "CONST", "ARRAYSEL", "EXTEND"}


def is_wiring(expr) -> bool:
    kinds = {n.get("type") for n in _all_nodes(expr)}
    return kinds <= WIRING


def _all_nodes(node):
    if isinstance(node, dict):
        if "type" in node:
            yield node
        for value in node.values():
            yield from _all_nodes(value)
    elif isinstance(node, list):
        for value in node:
            yield from _all_nodes(value)


def _const(node) -> int | None:
    m = re.fullmatch(r"(?:\d+)?'s?([hdbo])([0-9a-fA-F_]+)", node.get("name", ""))
    if not m:
        return None
    base = {"h": 16, "d": 10, "b": 2, "o": 8}[m.group(1)]
    return int(m.group(2).replace("_", ""), base)


@dataclass
class Instance:
    name: str
    module: str                       # elaborated module name, e.g. dff_sync__B6
    pins: dict                        # port -> expression (JSON)


@dataclass
class Always:
    keyword: str                      # always_ff, always, always_comb, ...
    line: int
    #: (edge, [signals]) per sensitivity item: ("POS", ["clk"]),
    #: ("NEG", ["arstn"]); ("CHANGED", [...]) for a combinational block.
    senses: list
    assigns: list                     # names assigned with <=
    node: dict = field(repr=False, default_factory=dict)

    @property
    def clocked(self) -> bool:
        return any(edge in ("POS", "NEG") for edge, _ in self.senses)


@dataclass
class Module:
    name: str                         # elaborated: pwr_src_bootseq__W1312d0
    base: str                         # as written: pwr_src_bootseq
    file: str
    ports: dict                       # name -> INPUT | OUTPUT | INOUT
    params: dict                      # name -> int, where it is a number
    instances: list
    always: list
    node: dict = field(repr=False, default_factory=dict)

    def reads(self, name: str) -> list:
        """Every read of `name` in this module that is not an instance pin."""
        out = []
        for stmt in self.node.get("stmtsp", []):
            if stmt.get("type") == "CELL":
                continue
            out += [v for v in _walk(stmt, "VARREF") if v["name"] == name and v.get("access") == "RD"]
        return out


@dataclass
class Netlist:
    top: str
    modules: dict                     # name -> Module
    files: dict

    def instances_of(self, base: str) -> list:
        return [m for m in self.modules.values() if m.base == base]


def _module(node: dict, files: dict) -> Module:
    loc = node.get("loc", "")
    ports, params = {}, {}
    for var in _walk(node.get("stmtsp", []), "VAR"):
        if var.get("varType") == "PORT" or var.get("direction") in ("INPUT", "OUTPUT", "INOUT"):
            if var.get("direction") != "NONE":
                ports[var["name"]] = var["direction"]
        if var.get("isParam"):
            consts = list(_walk(var.get("valuep", []), "CONST"))
            if len(consts) == 1 and _const(consts[0]) is not None:
                params[var["name"]] = _const(consts[0])
    instances = [Instance(c["name"], c["modName"],
                          {p["name"]: p.get("exprp", []) for p in c.get("pinsp", [])})
                 for c in node.get("stmtsp", []) if c.get("type") == "CELL"]
    always = []
    for a in _walk(node.get("stmtsp", []), "ALWAYS"):
        senses = [(item.get("edgeType"), refs(item.get("sensp", [])))
                  for tree in a.get("sentreep") or [] for item in tree.get("sensesp", [])]
        assigns = sorted({n for d in _walk(a.get("stmtsp", []), "ASSIGNDLY")
                          for n in refs(d.get("lhsp", []))})
        line = int(re.search(r",(\d+):", a.get("loc", "x,0:")).group(1))
        always.append(Always(a.get("keyword", ""), line, senses, assigns, a))
    return Module(node["name"], node.get("origName", node["name"]).split("__")[0],
                  files.get(loc.split(",")[0], ""), ports, params, instances, always, node)


def _inputs(variant: str) -> tuple:
    sim.build_variant.write(sim.RTL_DIR, variant)
    sources = [Path(p) for p in sim.device_sources()]
    includes = sorted(sim.RTL_DIR.glob("*.vh")) + sorted(sim.RTL_DIR.glob("*.svh"))
    return sources, includes


def elaborate(variant: str = sim.VARIANT) -> Netlist:
    """The device elaborated by Verilator, read back. Raises if it does not
    elaborate: an inspection over a design that did not build is no evidence."""
    sources, includes = _inputs(variant)
    args = ["--json-only", "--top-module", sim.DEVICE, f"-I{sim.RTL_DIR}",
            "--timescale", "1ns/1ps", "-Wno-fatal", *sim.build_args_for("verilator")]
    digest = hashlib.sha256()
    for path in [*sources, *includes]:
        digest.update(str(path).encode() + b"\0" + path.read_bytes())
    digest.update(" ".join(args).encode())
    where = CACHE / variant / digest.hexdigest()[:16]
    tree, meta = where / "top.tree.json", where / "top.meta.json"
    if not tree.is_file():
        verilator = shutil.which("verilator")
        if not verilator:
            raise RuntimeError("verilator is not on PATH; it elaborates the design for this "
                               "inspection (make inspect puts the EDA tools on PATH)")
        where.mkdir(parents=True, exist_ok=True)
        run = subprocess.run([verilator, *args, "--json-only-output", str(tree),
                              "--json-only-meta-output", str(meta), *map(str, sources)],
                             capture_output=True, text=True)
        errors = [l for l in run.stderr.splitlines() if l.startswith("%Error")]
        if run.returncode != 0 and (errors or not tree.is_file()):
            shutil.rmtree(where, ignore_errors=True)
            raise RuntimeError("the design did not elaborate:\n" + "\n".join(errors or run.stderr.splitlines()[-20:]))
    raw = json.loads(tree.read_text(encoding="utf-8"))
    files = {k: v.get("realpath", v.get("filename", ""))
             for k, v in json.loads(meta.read_text(encoding="utf-8")).get("files", {}).items()}
    modules = {m["name"]: _module(m, files) for m in raw.get("modulesp", [])}
    return Netlist(sim.DEVICE, modules, files)


# ---- following a signal across the hierarchy

@dataclass
class Place:
    """A module instance in the design, by path from the top."""
    path: tuple                       # instance names from the top: () is the top
    module: Module
    parent: "Place | None" = None
    instance: Instance | None = None  # how the parent instantiates this one

    def __str__(self) -> str:
        return ".".join((self.module.base,) if not self.path else self.path)


def places(netlist: Netlist) -> list:
    """Every instance in the design, the top first."""
    top = Place((), netlist.modules[netlist.top])
    out, todo = [], [top]
    while todo:
        here = todo.pop(0)
        out.append(here)
        for inst in here.module.instances:
            todo.append(Place(here.path + (inst.name,), netlist.modules[inst.module], here, inst))
    return out


def _cont_assigns(module: Module) -> list:
    """(lhs names, rhs expression) for every continuous assignment."""
    out = []
    for a in module.always:
        if a.keyword != "cont_assign":
            continue
        for stmt in _walk(a.node.get("stmtsp", []), "ASSIGNW"):
            out.append((refs(stmt.get("lhsp", [])), stmt.get("rhsp", [])))
    return out


def origin(netlist: Netlist, place: Place, name: str, seen=None) -> tuple:
    """Where a signal in an instance comes from, followed through wiring:

        ("input", top port)             a top-level input
        ("register", "module.reg")      a register's output
        ("logic", "where: what")        anything computed -- a derived signal
        ("unknown", "where: name")      no driver found
    """
    seen = seen or set()
    key = (place.path, name)
    if key in seen:
        return ("logic", f"{place}: {name} (loop)")
    seen.add(key)
    module = place.module
    if module.ports.get(name) == "INPUT":
        if place.parent is None:
            return ("input", name)
        expr = place.instance.pins.get(name, [])
        names = refs(expr)
        if not is_wiring(expr) or len(set(names)) != 1:
            return ("logic", f"{place.parent}: .{name}({'computed' if names else 'unconnected'})")
        return origin(netlist, place.parent, names[0], seen)
    for a in module.always:
        if a.clocked and name in a.assigns:
            return ("register", f"{module.base}.{name}")
    for lhs, rhs in _cont_assigns(module):
        if name in lhs:
            names = refs(rhs)
            if is_wiring(rhs) and len(set(names)) == 1:
                return origin(netlist, place, names[0], seen)
            return ("logic", f"{place}: {name}")
    for inst in module.instances:
        child = netlist.modules[inst.module]
        for port, expr in inst.pins.items():
            if child.ports.get(port) == "OUTPUT" and name in refs(expr):
                below = Place(place.path + (inst.name,), child, place, inst)
                return origin(netlist, below, port, seen)
    return ("unknown", f"{place}: {name}")


def uses(netlist: Netlist, place: Place, name: str) -> list:
    """Where a signal arriving in an instance is used, followed down through
    instance ports it is wired to unchanged:

        ("read", place, line)            read by logic or a register in `place`
        ("port", place, instance, port)  wired into a port of an instance whose
                                         module is a leaf here (see `stop`)
    """
    out = []
    for read in place.module.reads(name):
        line = int(re.search(r",(\d+):", read.get("loc", "x,0:")).group(1))
        out.append(("read", place, line))
    for inst in place.module.instances:
        for port, expr in inst.pins.items():
            if name not in refs(expr):
                continue
            child = netlist.modules[inst.module]
            below = Place(place.path + (inst.name,), child, place, inst)
            out.append(("port", below, inst, port, is_wiring(expr)))
    return out
