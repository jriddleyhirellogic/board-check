"""A synthesised EDIF netlist, read far enough to inspect: cells, their
instances, and which instance ports each net joins.

Synplify writes `synthesis/top.edn`. Standard library only; a few seconds for
the housekeeper's 6 MB netlist.
"""

from __future__ import annotations

import re
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path

_TOKEN = re.compile(r'\(|\)|"(?:[^"\\]|\\.)*"|[^\s()]+')


def parse(text: str) -> list:
    """S-expressions to nested lists; strings keep their quotes stripped."""
    stack, current = [], []
    for tok in _TOKEN.findall(text):
        if tok == "(":
            stack.append(current)
            current = []
        elif tok == ")":
            done, current = current, stack.pop()
            current.append(done)
        else:
            current.append(tok[1:-1] if tok.startswith('"') else tok)
    return current


def _name(node) -> str:
    """An EDIF name: `x`, `(rename x "original")` -> x, and a bus bit
    `(member x 3)` -> `x[3]`."""
    if isinstance(node, list) and node:
        if node[0] == "rename":
            return node[1]
        if node[0] == "member":
            return f"{_name(node[1])}[{node[2]}]"
    return node


def _children(node: list, keyword: str) -> list:
    return [n for n in node if isinstance(n, list) and n and n[0] == keyword]


@dataclass
class Instance:
    name: str
    cell: str                         # the cell it instantiates
    library: str


@dataclass
class Cell:
    name: str
    library: str
    instances: dict = field(default_factory=dict)         # name -> Instance
    #: net -> [(instance name or None for the cell's own port, port)]
    nets: dict = field(default_factory=dict)

    @property
    def primitive(self) -> bool:
        return not self.instances and not self.nets

    def net_of(self, instance: str, port: str):
        """The net joining one instance port, or None."""
        return self._by_pin.get((instance, port))

    def build_index(self) -> None:
        self._by_pin = {pin: net for net, pins in self.nets.items() for pin in pins}


@dataclass
class Netlist:
    cells: dict                       # (library, name) -> Cell
    top: tuple                        # (library, name) of the design's top cell

    def cell(self, library: str, name: str) -> Cell:
        return self.cells[(library, name)]

    def instance_counts(self) -> Counter:
        """How many times each cell occurs in the design, from the top down."""
        counts = Counter()

        def visit(key, times):
            counts[key] += times
            for inst in self.cells[key].instances.values():
                child = (inst.library, inst.cell)
                if child in self.cells and not self.cells[child].primitive:
                    visit(child, times)
        visit(self.top, 1)
        return counts


def load(path: Path) -> Netlist:
    tree = parse(Path(path).read_text(encoding="latin-1"))[0]
    cells = {}
    for library in _children(tree, "library") + _children(tree, "external"):
        lib = _name(library[1])
        for cnode in _children(library, "cell"):
            cell = Cell(_name(cnode[1]), lib)
            for view in _children(cnode, "view"):
                for contents in _children(view, "contents"):
                    for inode in _children(contents, "instance"):
                        ref = next(iter(_children(_children(inode, "viewRef")[0], "cellRef")), None)
                        lib_ref = _children(ref, "libraryRef") if ref else []
                        cell.instances[_name(inode[1])] = Instance(
                            _name(inode[1]), _name(ref[1]) if ref else "",
                            _name(lib_ref[0][1]) if lib_ref else lib)
                    for nnode in _children(contents, "net"):
                        pins = []
                        for joined in _children(nnode, "joined"):
                            for pref in _children(joined, "portRef"):
                                iref = _children(pref, "instanceRef")
                                pins.append((_name(iref[0][1]) if iref else None, _name(pref[1])))
                        cell.nets[_name(nnode[1])] = pins
            cell.build_index()
            cells[(lib, cell.name)] = cell
    design = _children(tree, "design")[0]
    ref = _children(design, "cellRef")[0]
    top = (_name(_children(ref, "libraryRef")[0][1]), _name(ref[1]))
    return Netlist(cells, top)
