"""FPGA I/O configuration read from the FPGA project's own constraint files.

The constraint files the FPGA build applies are the source of truth for what
each FPGA pin is: its I/O standard, direction, pull and drive, and each
bank's I/O voltage. They are read where they live (the FPGA repository),
never copied, so a check always sees what the bitstream is built from.

Libero constraint files are Tcl. This reads the subset they use, the way
Libero would apply it:

- ``set_iobank -bank_name Bank2 -vcci 3.30 ...``
- ``set_io {port} -pinname "C4" -iostd "LVCMOS33" -direction "INPUT" ...``
- ``dict set pins {pcb_port} {pin_name "T9" io_std "LVCMOS33" ...}`` pin maps,
  applied by ``apply_pin_constraints $ports $pins`` to the ports collected with
  ``lappend ports [list {fw_port} {pcb_port} ?{prop value ...}?]``: only ports
  in that list are constrained, and a third element overrides the map
- ``source``, and ``set`` of variables built from ``[file normalize [file join
  [file dirname [info script]] ...]]`` so sourced files resolve
- comments, blank lines and ``proc`` definitions are skipped

Any other command is recorded as a problem rather than guessed at.
"""

import os
import re
from dataclasses import dataclass, field

_DIRECTIONS = {"INPUT": "input", "IN": "input", "OUTPUT": "output", "OUT": "output",
               "INOUT": "inout", "BIDIR": "inout"}
_PULLS = {"UP": "pull_up", "DOWN": "pull_down", "NONE": None, "": None}
_KEYS = {"pinname": "ball", "pin_name": "ball", "iostd": "io_std", "io_std": "io_std",
         "direction": "direction", "res_pull": "pull", "out_drive": "drive"}


@dataclass
class IoConstraint:
    port: str                 # port name in the FPGA design
    ball: str                 # package pin, e.g. "T9"
    io_std: str = None        # "LVCMOS33"; None when the file sets none (dedicated pins)
    direction: str = None     # "input" | "output" | "inout"
    pull: str = None          # "pull_up" | "pull_down" | None
    drive: float = None       # output drive in mA, when set
    where: str = ""           # "file:line" of the command that set it
    attrs: dict = field(default_factory=dict)   # every option as written


@dataclass
class FpgaIO:
    designator: str
    files: list = field(default_factory=list)        # constraint files named in the config
    read: list = field(default_factory=list)         # every file actually read, sourced ones included
    pins: dict = field(default_factory=dict)         # ball -> IoConstraint
    banks: dict = field(default_factory=dict)        # bank name -> VCCI (V), from set_iobank
    problems: list = field(default_factory=list)     # unreadable files, unknown commands, conflicts
    missing: list = field(default_factory=list)      # constraint or top-level files that do not exist
    # Top-level port directions from the FPGA design itself (SmartDesign Tcl
    # or HDL), when configured: {port or bit: direction}, and per bus base
    # name for buses whose range could not be expanded.
    top_files: list = field(default_factory=list)
    ports: dict = field(default_factory=dict)
    port_bases: dict = field(default_factory=dict)

    def port_direction(self, port):
        """Direction the FPGA design gives a port ("input", "output",
        "inout"), or None when no top level is configured or it lacks the port."""
        if port in self.ports:
            return self.ports[port]
        return self.port_bases.get(port.split("[")[0])

    @property
    def available(self):
        return bool(self.files) and not self.missing


# -- Tcl subset ---------------------------------------------------------------

def _commands(text):
    """Yield (line number, command text), joining lines until braces and
    brackets balance and following backslash continuations."""
    buf, start, depth = [], None, 0
    for n, line in enumerate(text.splitlines(), 1):
        if not buf:
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            start = n
        buf.append(line)
        depth += _depth(line)
        if depth > 0 or line.rstrip().endswith("\\"):
            continue
        yield start, " ".join(s.rstrip().rstrip("\\") for s in buf).strip()
        buf, depth = [], 0
    if buf:
        yield start, " ".join(buf).strip()


def _depth(line):
    d, quoted, esc = 0, False, False
    for ch in line:
        if esc:
            esc = False
        elif ch == "\\":
            esc = True
        elif ch == '"':
            quoted = not quoted
        elif not quoted and ch in "{[":
            d += 1
        elif not quoted and ch in "}]":
            d -= 1
    return d


def _words(text):
    """Split a Tcl command into (kind, text) words: kind is "brace", "quote",
    "bracket" or "bare"."""
    words, i, n = [], 0, len(text)
    while i < n:
        if text[i].isspace():
            i += 1
            continue
        if text[i] == ";":
            break
        if text[i] in "{[":
            open_, close = text[i], "}" if text[i] == "{" else "]"
            d, j = 0, i
            while j < n:
                if text[j] == open_:
                    d += 1
                elif text[j] == close:
                    d -= 1
                    if d == 0:
                        break
                j += 1
            words.append(("brace" if open_ == "{" else "bracket", text[i + 1:j]))
            i = j + 1
        elif text[i] == '"':
            j = text.index('"', i + 1) if '"' in text[i + 1:] else n
            words.append(("quote", text[i + 1:j]))
            i = j + 1
        else:
            j = i
            while j < n and not text[j].isspace():
                j += 1
            words.append(("bare", text[i:j]))
            i = j
    return words


class _Reader:
    def __init__(self, fpga):
        self.fpga = fpga
        self.vars = {}           # scalar variables
        self.dicts = {}          # dict set targets
        self.lists = {}          # lappend targets

    def read_file(self, path):
        path = os.path.normpath(path)
        if path in self.fpga.read:
            return
        try:
            with open(path, encoding="utf-8", errors="replace") as f:
                text = f.read()
        except OSError as e:
            self.fpga.problems.append(f"cannot read {path}: {e.strerror}")
            return
        self.fpga.read.append(path)
        saved = self.vars.get("__script__")
        self.vars["__script__"] = path
        for line, cmd in _commands(text):
            self.command(cmd, f"{os.path.basename(path)}:{line}")
        self.vars["__script__"] = saved

    # value evaluation
    def value(self, word):
        kind, text = word
        if kind == "brace":
            return text
        if kind == "bracket":
            return self.bracket(text)
        return self.subst(text)

    def subst(self, text):
        return re.sub(r"\$\{?(\w+)\}?", lambda m: str(self.vars.get(m.group(1), m.group(0))), text)

    def bracket(self, text):
        w = _words(text)
        if not w:
            return ""
        head = [x[1] for x in w[:2]]
        if head == ["info", "script"]:
            return self.vars.get("__script__", "")
        if head == ["file", "dirname"]:
            return os.path.dirname(self.value(w[2]))
        if head == ["file", "normalize"]:
            return os.path.normpath(os.path.abspath(self.value(w[2])))
        if head == ["file", "join"]:
            return os.path.join(*[self.value(x) for x in w[2:]])
        if w[0][1] == "list":
            return [self.value(x) for x in w[1:]]
        raise ValueError(f"unsupported [{text.strip()}]")

    # commands
    def command(self, cmd, where):
        try:
            w = _words(cmd)
            if not w:
                return
            name = w[0][1]
            handler = getattr(self, "cmd_" + name, None)
            if handler is None:
                self.fpga.problems.append(f"{where}: command '{name}' not understood; ignored")
                return
            handler(w[1:], where)
        except (ValueError, IndexError) as e:
            self.fpga.problems.append(f"{where}: {e}")

    def cmd_proc(self, args, where):
        pass    # helper definitions; apply_pin_constraints is modelled below

    def cmd_puts(self, args, where):
        pass

    def cmd_set(self, args, where):
        name = args[0][1]
        value = self.value(args[1]) if len(args) > 1 else ""
        if name in self.lists or (args[1:] and args[1] == ("brace", "")):
            self.lists[name] = []
        self.vars[name] = value

    def cmd_source(self, args, where):
        path = self.value(args[0])
        if not os.path.isabs(path):
            path = os.path.join(os.path.dirname(self.vars.get("__script__", "")), path)
        self.read_file(path)

    def cmd_dict(self, args, where):
        if args[0][1] != "set" or len(args) != 4:
            raise ValueError("only 'dict set var key value' is understood")
        var, key = args[1][1], self.value(args[2])
        props = _pairs(_words(self.value(args[3])))
        self.dicts.setdefault(var, {})[key] = (props, where)

    def cmd_lappend(self, args, where):
        var = args[0][1]
        for item in args[1:]:
            self.lists.setdefault(var, []).append((self.value(item), where))

    def cmd_apply_pin_constraints(self, args, where):
        ports = self.lists.get(args[0][1].lstrip("$"), [])
        pin_map = self.dicts.get(args[1][1].lstrip("$"), {})
        for entry, at in ports:
            if not isinstance(entry, list) or len(entry) < 2:
                self.fpga.problems.append(f"{at}: port entry not understood: {entry!r}")
                continue
            fw_port, pcb_port = entry[0], entry[1]
            if pcb_port not in pin_map:
                self.fpga.problems.append(f"{at}: '{pcb_port}' is not in the pin map (Libero stops here)")
                continue
            props, map_at = pin_map[pcb_port]
            props = dict(props)
            if len(entry) > 2:
                props.update(_pairs(_words(entry[2])))
            self.add(fw_port, props, f"{at} via {map_at}")

    def cmd_set_io(self, args, where):
        port = self.value(args[0])
        opts = {}
        rest = args[1:]
        for i in range(0, len(rest) - 1, 2):
            opts[rest[i][1].lstrip("-")] = self.value(rest[i + 1])
        self.add(port, opts, where)

    def cmd_set_iobank(self, args, where):
        opts = {args[i][1].lstrip("-"): self.value(args[i + 1]) for i in range(0, len(args) - 1, 2)}
        if "bank_name" in opts and "vcci" in opts:
            self.fpga.banks[opts["bank_name"]] = float(opts["vcci"])

    def add(self, port, props, where):
        norm = {_KEYS.get(k.lower(), k.lower()): v for k, v in props.items()}
        ball = str(norm.get("ball") or "").strip()
        if not ball:
            self.fpga.problems.append(f"{where}: port '{port}' has no pin")
            return
        drive = norm.get("drive")
        c = IoConstraint(
            port=port, ball=ball,
            io_std=(norm.get("io_std") or None),
            direction=_DIRECTIONS.get(str(norm.get("direction") or "").upper()),
            pull=_PULLS.get(str(norm.get("pull") or "").upper()),
            drive=float(drive) if drive not in (None, "") else None,
            where=where, attrs=dict(props))
        prev = self.fpga.pins.get(ball)
        if prev is not None and prev.port != port:
            self.fpga.problems.append(f"{where}: pin {ball} assigned to '{port}' and to '{prev.port}' ({prev.where})")
        self.fpga.pins[ball] = c


def _pairs(words):
    vals = [w[1] for w in words]
    return {vals[i]: vals[i + 1] for i in range(0, len(vals) - 1, 2)}


def load(designator, files, base_dir="", top_files=(), top_module=None):
    """Read one FPGA's constraint files, and optionally its top-level port
    declarations. Relative paths resolve against base_dir (the directory of
    the board-check config)."""
    fpga = FpgaIO(designator)
    reader = _Reader(fpga)
    for f in files:
        path = os.path.normpath(os.path.join(base_dir, os.path.expanduser(f)))
        fpga.files.append(path)
        if not os.path.isfile(path):
            fpga.missing.append(path)
            continue
        reader.read_file(path)
    for f in top_files:
        path = os.path.normpath(os.path.join(base_dir, os.path.expanduser(f)))
        fpga.top_files.append(path)
        if not os.path.isfile(path):
            fpga.missing.append(path)
            continue
        _read_top(fpga, path, top_module)
    return fpga


# -- top-level port declarations ----------------------------------------------

_SD_DIRS = {"IN": "input", "OUT": "output", "INOUT": "inout"}
_HDL_PORT_RE = re.compile(
    r"\b(input|output|inout)\b\s*(?:wire|logic|reg|tri|var)?\s*(?:signed|unsigned)?\s*"
    r"(\[[^\]]*\])?\s*([A-Za-z_]\w*(?:\s*,\s*(?!input\b|output\b|inout\b)[A-Za-z_]\w*)*)")


def _add_port(fpga, name, direction, rng):
    """Record a port; a bus with a numeric [msb:lsb] range is expanded to bits."""
    m = re.fullmatch(r"\[\s*(\d+)\s*:\s*(\d+)\s*\]", (rng or "").strip())
    if m:
        hi, lo = int(m.group(1)), int(m.group(2))
        for i in range(min(hi, lo), max(hi, lo) + 1):
            fpga.ports[f"{name}[{i}]"] = direction
    elif rng:
        fpga.port_bases[name] = direction
    else:
        fpga.ports[name] = direction


def _read_top(fpga, path, top_module):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            text = f.read()
    except OSError as e:
        fpga.problems.append(f"cannot read {path}: {e.strerror}")
        return
    fpga.read.append(path)
    before = len(fpga.ports) + len(fpga.port_bases)
    if path.lower().endswith(".tcl"):
        # SmartDesign: sd_create_scalar_port / sd_create_bus_port
        for line, cmd in _commands(text):
            w = _words(cmd)
            if not w or w[0][1] not in ("sd_create_scalar_port", "sd_create_bus_port"):
                continue
            opts = {w[i][1].lstrip("-"): w[i + 1][1] for i in range(1, len(w) - 1, 2)}
            direction = _SD_DIRS.get(str(opts.get("port_direction", "")).upper())
            if opts.get("port_name") and direction:
                _add_port(fpga, opts["port_name"], direction, opts.get("port_range"))
    else:
        # Verilog / SystemVerilog ANSI module header
        text = re.sub(r"//[^\n]*|/\*.*?\*/", " ", text, flags=re.S)
        pattern = (r"\bmodule\s+" + re.escape(top_module) + r"\b") if top_module else r"\bmodule\s+\w+"
        m = re.search(pattern, text)
        if not m:
            fpga.problems.append(f"{os.path.basename(path)}: module {top_module or ''} not found")
            return
        body = text[m.end():]
        end = re.search(r"\)\s*;", _strip_params(body))
        header = _strip_params(body)[:end.start()] if end else ""
        for d, rng, names in _HDL_PORT_RE.findall(header):
            for name in re.split(r"\s*,\s*", names.strip()):
                if name:
                    _add_port(fpga, name, d, rng)
    if len(fpga.ports) + len(fpga.port_bases) == before:
        fpga.problems.append(f"{os.path.basename(path)}: no top-level ports found")


def _strip_params(body):
    """Drop a leading #( ... ) parameter list from a module header."""
    s = body.lstrip()
    if not s.startswith("#"):
        return body
    i, depth = s.index("("), 0
    for j in range(i, len(s)):
        if s[j] == "(":
            depth += 1
        elif s[j] == ")":
            depth -= 1
            if depth == 0:
                return s[j + 1:]
    return body


class FpgaPins:
    """One FPGA on the board: its constraints joined to its schematic pins."""

    def __init__(self, component, io, cfg):
        self.component = component
        self.io = io
        self._bank_re = re.compile(cfg["bank_pattern"]) if cfg.get("bank_pattern") else None
        self._bank_type_re = re.compile(cfg["bank_type_pattern"]) if cfg.get("bank_type_pattern") else None
        self._supply = cfg.get("bank_supply")
        self._bank_name = cfg.get("bank_name")

    def constraint(self, pin):
        return self.io.pins.get(str(pin.designator))

    def direction(self, c):
        """A constrained port's direction: the FPGA design's own port
        declaration when a top level is configured, else the constraint's."""
        return self.io.port_direction(c.port) or c.direction

    def bank(self, pin):
        """Bank number from the schematic pin name, or None."""
        if self._bank_re is None:
            return None
        m = self._bank_re.search(pin.name or "")
        return m.group(1) if m else None

    def bank_type(self, pin):
        """I/O bank type from the schematic pin name ("GPIO", "HSIO"), or None."""
        if self._bank_type_re is None:
            return None
        m = self._bank_type_re.search(pin.name or "")
        return m.group(1).upper() if m else None

    def supply_pin_name(self, bank):
        return self._supply.format(bank=bank) if self._supply else None

    def bank_supply_nets(self, bank):
        """Nets on the bank's I/O supply pins (normally exactly one)."""
        name = self.supply_pin_name(bank)
        if not name:
            return set()
        return {p.net for p in self.component.pins if (p.name or "").upper() == name.upper()}

    def bank_vcci(self, bank):
        """VCCI the constraints set for a bank (set_iobank), or None."""
        if not self._bank_name:
            return None
        return self.io.banks.get(self._bank_name.format(bank=bank))

    def banks(self):
        """Banks named by schematic pins, sorted."""
        found = {self.bank(p) for p in self.component.pins} - {None}
        return sorted(found, key=lambda b: (len(b), b))


def board_fpgas(design, config):
    """{designator: FpgaPins} for every FPGA configured in `fpga`."""
    out = {}
    for desig, cfg in (config["fpga"] or {}).items():
        cfg = cfg or {}
        files = cfg.get("constraints") or []
        if isinstance(files, str):
            files = [files]
        tops = cfg.get("top_level") or []
        if isinstance(tops, str):
            tops = [tops]
        io = load(desig, files, config.base_dir, tops, cfg.get("top_module"))
        comp = design.components.get(desig)
        out[desig] = FpgaPins(comp, io, cfg) if comp is not None else io
    return out
