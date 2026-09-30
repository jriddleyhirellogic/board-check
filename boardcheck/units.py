"""Parsing of engineering values as they appear in Altium parameters and net names."""

import re

SI_PREFIX = {
    "p": 1e-12,
    "n": 1e-9,
    "u": 1e-6,
    "µ": 1e-6,
    "m": 1e-3,
    "": 1.0,
    "k": 1e3,
    "K": 1e3,
    "M": 1e6,
    "G": 1e9,
}

# "47nF", "0.1uF", "100mW", "6.3V", "10K", "1M", "2000V"
_SI_RE = re.compile(r"^\s*([0-9]*\.?[0-9]+)\s*([pnuµmkKMG]?)\s*([A-Za-zΩ]*)\s*$")
# RKM code: "4K7", "49R9", "0R001", "R005", "1M8"
_RKM_RE = re.compile(r"^\s*([0-9]*)([RKMGkm])([0-9]*)\s*$")
_RKM_MULT = {"R": 1.0, "K": 1e3, "k": 1e3, "M": 1e6, "m": 1e-3, "G": 1e9}


def parse_value(text, unit=None):
    """Parse an engineering value to a float in base units, or None.

    `unit` is the expected unit letter(s) ("F", "V", "W", "H", "ohm"); a
    trailing unit that contradicts it makes the parse fail rather than
    silently returning a value in the wrong unit.
    """
    if text is None:
        return None
    s = str(text).strip()
    if not s:
        return None
    s = s.replace("Ω", "").replace("Ω", "")
    if s.lower().endswith("ohms"):
        s = s[:-4]
    elif s.lower().endswith("ohm"):
        s = s[:-3]

    m = _RKM_RE.match(s)
    if m and (m.group(1) or m.group(3)):
        whole, letter, frac = m.groups()
        return float(f"{whole or '0'}.{frac or '0'}") * _RKM_MULT[letter]

    m = _SI_RE.match(s)
    if not m:
        return None
    number, prefix, suffix = m.groups()
    # "1M" with no unit is mega; "1m" with unit is milli. A lone "m" before
    # nothing is ambiguous only for resistances, which the RKM branch handled.
    if suffix and unit and suffix.upper() != unit.upper():
        return None
    return float(number) * SI_PREFIX[prefix]


def parse_percent(text):
    if text is None:
        return None
    m = re.match(r"^\s*±?\s*([0-9]*\.?[0-9]+)\s*%\s*$", str(text))
    return float(m.group(1)) if m else None


def format_value(value, unit):
    """Format a float with an SI prefix: format_value(4.7e-8, 'F') -> '47nF'."""
    if value is None:
        return "?"
    if value == 0:
        return f"0{unit}"
    for prefix, mult in (("G", 1e9), ("M", 1e6), ("k", 1e3), ("", 1.0),
                         ("m", 1e-3), ("u", 1e-6), ("n", 1e-9), ("p", 1e-12)):
        if abs(value) >= mult * 0.9999:
            return f"{value / mult:.4g}{prefix}{unit}"
    return f"{value:.3g}{unit}"


def close(a, b, rel=0.01):
    """True when two values agree within a relative tolerance."""
    if a is None or b is None:
        return False
    if a == b:
        return True
    return abs(a - b) <= rel * max(abs(a), abs(b))
