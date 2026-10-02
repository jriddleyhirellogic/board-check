"""Optional adapter to electronic-parts-repository (the `epr` package).

The package decodes commodity part numbers (MLCCs, chip resistors, MIL-PRF
parts) into typed values. Checks that need it degrade to "not checked" when
it is not installed, so the checker still runs on a bare Python install.
"""

import contextlib
import io
from dataclasses import dataclass

from .units import parse_value

_CAP_UNITS = {"pf": 1e-12, "nf": 1e-9, "uf": 1e-6, "µf": 1e-6, "mf": 1e-3, "f": 1.0}


@dataclass
class DecodedPart:
    part_number: str
    kind: str                     # "capacitor" | "resistor" | "other"
    source: str = ""
    capacitance: float = None     # farads
    resistance: float = None      # ohms
    voltage_rated: float = None   # volts (working voltage for resistors)
    power_max: float = None       # watts
    tolerance: float = None       # percent
    size: str = None              # "0603"
    dielectric: str = None        # "X7R"


class PartsDB:
    def __init__(self, repo=None):
        self._repo = repo
        self._cache = {}

    @classmethod
    def open(cls):
        """Return a PartsDB, or None if electronic-parts-repository is absent."""
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                from electronic_parts_repository import ElectronicPartsRepository
                repo = ElectronicPartsRepository()
        except ImportError:
            return None
        return cls(repo)

    def decode(self, part_number):
        if not part_number:
            return None
        if part_number not in self._cache:
            self._cache[part_number] = self._decode(part_number)
        return self._cache[part_number]

    def _part_file(self, part_number):
        """The part's JSON file contents (a dict), or None for parts that are
        decoded rather than stored, or unknown."""
        if not part_number:
            return None
        key = ("file", part_number)
        if key not in self._cache:
            try:
                with contextlib.redirect_stdout(io.StringIO()):
                    result = self._repo.lookup({"part_number": part_number})
            except Exception:
                result = None
            self._cache[key] = result if isinstance(result, dict) else None
        return self._cache[key]

    def pin_functions(self, part_number):
        """The part's `pin_functions` block ({pin name or number: {direction,
        function, description}}) from its JSON file, or None."""
        data = self._part_file(part_number)
        if data and isinstance(data.get("pin_functions"), dict):
            return data["pin_functions"]
        return None

    def io_standards(self, part_number):
        """The part's `io_standards` block (programmable-I/O facts per I/O
        standard, e.g. {"SHIELD12": {"tie_to": "ground"}}), or {}."""
        data = self._part_file(part_number)
        block = data.get("io_standards") if data else None
        return {str(k).upper(): v for k, v in block.items() if isinstance(v, dict)} if isinstance(block, dict) else {}

    def regulator(self, part_number):
        """The part's `regulator` block (enable, input/output/feedback pins,
        divider, output equation), or None."""
        data = self._part_file(part_number)
        block = data.get("regulator") if data else None
        return block if isinstance(block, dict) and block.get("feedback_pin") else None

    def unused_pins(self, part_number):
        """The part's `unused_pins` rules ([{pattern, connect, ohms, ...}]), or []."""
        data = self._part_file(part_number)
        rules = data.get("unused_pins") if data else None
        return [r for r in rules if isinstance(r, dict) and r.get("pattern")] if isinstance(rules, list) else []

    def transceivers(self, part_number):
        """The part's `transceivers` block (quad order, reference clock cascade), or None."""
        data = self._part_file(part_number)
        block = data.get("transceivers") if data else None
        return block if isinstance(block, dict) else None

    def straps(self, part_number):
        """The part's `straps` block ({latched_by, must_not_be_driven, fields}), or None."""
        data = self._part_file(part_number)
        block = data.get("straps") if data else None
        return block if isinstance(block, dict) and block.get("fields") else None

    def power_up_io(self, part_number):
        """The part's `power_up_io` states ([{phase, state, description}]), or []."""
        data = self._part_file(part_number)
        block = data.get("power_up_io") if data else None
        return [s for s in (block or {}).get("states", []) if isinstance(s, dict)] if isinstance(block, dict) else []

    def part_info(self, part_number):
        """The part's `part_info` block (type, frequency_hz, ...), or {}."""
        data = self._part_file(part_number)
        block = data.get("part_info") if data else None
        return block if isinstance(block, dict) else {}

    def clock_inputs(self, part_number):
        """The part's `clock_inputs` ([{pin, select, frequency_hz}]), or []."""
        data = self._part_file(part_number)
        block = data.get("clock_inputs") if data else None
        return [c for c in block if isinstance(c, dict) and c.get("pin")] if isinstance(block, list) else []

    def characteristics(self, part_number):
        """The part's `electrical_characteristics` block from its JSON file,
        or None."""
        data = self._part_file(part_number)
        if data and isinstance(data.get("electrical_characteristics"), dict):
            return data["electrical_characteristics"]
        return None

    def _decode(self, part_number):
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                result = self._repo.lookup({"part_number": part_number})
        except Exception:  # decoders raise on malformed input
            return None
        if result is None or isinstance(result, dict) or not hasattr(result, "get_template"):
            return None
        t = result.get_template()
        ptype = str(t.get("type") or "").upper()
        if ptype in ("CAPACITOR", "MLCC"):
            kind = "capacitor"
        elif ptype == "RESISTOR":
            kind = "resistor"
        else:
            kind = "other"
        part = DecodedPart(part_number=part_number, kind=kind, source=t.get("source") or t.get("spec") or "")
        part.tolerance = _num(t.get("tolerance")) if (t.get("tolerance_units") or "%") == "%" else None
        part.voltage_rated = _num(t.get("voltage_rated"))
        if kind == "capacitor":
            cap = _num(t.get("capacitance"))
            unit = str(t.get("capacitance_units") or "").lower()
            if cap is not None and unit in _CAP_UNITS:
                part.capacitance = cap * _CAP_UNITS[unit]
            part.size = t.get("case_size") or None
            part.dielectric = t.get("dielectric") or None
        elif kind == "resistor":
            part.resistance = _num(t.get("resistance"))
            part.power_max = _num(t.get("power_max"))
            part.size = t.get("style") or t.get("case_size") or None
        return part


def _num(v):
    if v is None or v == "":
        return None
    if isinstance(v, (int, float)):
        return float(v)
    return parse_value(v)
