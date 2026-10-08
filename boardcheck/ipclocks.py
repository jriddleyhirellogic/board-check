"""Reference clock settings of the IP blocks a top-level FPGA port reaches.

(smartdesign.py follows single signals bit by bit, up to the top level;
this follows a clock down to the IP that uses it.) A SmartDesign Tcl file (`set sd_name {X}`) instantiates components
(`sd_instantiate_component`, `sd_instantiate_macro`, ...) and joins pins
(`sd_connect_pins -pin_names {"inst:PIN" "port" ...}`); an IP configuration
file (`create_and_configure_core -core_vlnv ...:PF_CCC:... -component_name
{X} -params {"KEY:VALUE" ...}`) gives an IP component's settings.

clock_settings() follows a top-level port down through the hierarchy and
through pass-through clock buffers (`fpga_pins.clock_passthrough`) to the
IP pins named in `fpga_pins.clock_params`, and returns the reference
frequency each of those IP blocks is configured for (PF_CCC PLL_IN_FREQ_0,
PF_XCVR_ERM UI_CDR_REFERENCE_CLK_FREQ, PF_PCIE UI_PCIE_0_REF_CLK_FREQ, ...).
"""

import glob
import os
import re

from .fpga import _commands, _words


class _Design:
    def __init__(self, name, path):
        self.name = name
        self.path = path
        self.instances = {}     # instance -> component or macro name
        self.nets = []          # [[pin, ...]]: "inst:PIN" or a bare port name


class Core:
    def __init__(self, name, kind, path, params):
        self.name = name
        self.kind = kind        # "PF_CCC", from the core VLNV
        self.path = path
        self.params = params    # {KEY: VALUE}


_INSTANTIATE = {"sd_instantiate_component": "component_name", "sd_instantiate_macro": "macro_name",
                "sd_instantiate_hdl_module": "hdl_module_name", "sd_instantiate_core": "core_name"}


def _opts(words):
    return {words[i][1].lstrip("-"): words[i + 1][1] for i in range(1, len(words) - 1) if words[i][1].startswith("-")}


class Index:
    """Every SmartDesign and IP configuration file under the given
    directories."""

    def __init__(self, dirs):
        self.designs = {}
        self.cores = {}
        self.problems = []
        for d in dirs:
            if not os.path.isdir(d):
                self.problems.append(f"SmartDesign directory not found: {d}")
                continue
            for path in sorted(glob.glob(os.path.join(d, "**", "*.tcl"), recursive=True)):
                self._read(path)

    def _read(self, path):
        try:
            with open(path, encoding="utf-8", errors="replace") as f:
                text = f.read()
        except OSError:
            return
        sd = None
        for _, cmd in _commands(text):
            w = _words(cmd)
            if not w:
                continue
            head = w[0][1]
            if head == "set" and len(w) >= 3 and w[1][1] == "sd_name":
                sd = _Design(w[2][1], path)
                self.designs[sd.name] = sd
            elif head in _INSTANTIATE and sd is not None:
                o = _opts(w)
                if o.get("instance_name") and o.get(_INSTANTIATE[head]):
                    sd.instances[o["instance_name"]] = o[_INSTANTIATE[head]]
            elif head == "sd_connect_pins" and sd is not None:
                pins = [x[1] for x in _words(_opts(w).get("pin_names", ""))]
                if pins:
                    sd.nets.append(pins)
            elif head == "create_and_configure_core":
                o = _opts(w)
                vlnv, name = o.get("core_vlnv", ""), o.get("component_name")
                if not name:
                    continue
                kind = vlnv.split(":")[2] if vlnv.count(":") >= 2 else vlnv
                params = {}
                for _, item in _words(o.get("params", "")):
                    key, sep, value = item.partition(":")
                    if sep:
                        params[key] = value
                self.cores[name] = Core(name, kind, path, params)

    def clock_settings(self, top, port, params_table, passthrough):
        """[(MHz, "PF_CCC_C2 PLL_IN_FREQ_0", "path")] for the IP pins the top
        SmartDesign's port reaches."""
        start = self.designs.get(top)
        if start is None:
            return []
        found, seen = [], set()
        stack = [(start, port)]
        while stack:
            sd, pin = stack.pop()
            if (sd.name, pin) in seen:
                continue
            seen.add((sd.name, pin))
            for net in sd.nets:
                if pin not in net:
                    continue
                for other in net:
                    if ":" not in other or other == pin:
                        continue
                    inst, ipin = other.split(":", 1)
                    ipin = re.sub(r"\[.*\]$", "", ipin)
                    comp = sd.instances.get(inst)
                    if comp in self.designs:
                        stack.append((self.designs[comp], ipin))
                        continue
                    kind = self.cores[comp].kind if comp in self.cores else comp
                    for rx, outs in (passthrough.get(kind) or {}).items():
                        if re.search(rx, ipin):
                            stack.extend((sd, f"{inst}:{out}") for out in outs)
                    core = self.cores.get(comp)
                    if core is None:
                        continue
                    for rx, keys in (params_table.get(kind) or {}).items():
                        if not re.search(rx, ipin):
                            continue
                        values = set()
                        for key in keys:
                            try:
                                values.add(float(core.params[key]))
                            except (KeyError, ValueError):
                                pass
                        if len(values) == 1:
                            item = (values.pop(), f"{core.name} {'/'.join(keys)}", core.path)
                            if item not in found:
                                found.append(item)
        return found
