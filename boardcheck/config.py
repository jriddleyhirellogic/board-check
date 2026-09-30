"""Check configuration: built-in defaults, overridden by a YAML file."""

import copy
import os
import re

import yaml

DEFAULTS = {
    # Designator prefix -> component kind. Longest prefix wins.
    "designator_kinds": {
        "C": "capacitor",
        "R": "resistor",
        "L": "inductor",
        "FB": "ferrite",
        "D": "diode",
        "Q": "transistor",
        "U": "ic",
        "Y": "crystal",
        "X": "crystal",
        "J": "connector",
        "P": "connector",
        "T": "transformer",
        "F": "fuse",
        "S": "switch",
        "SW": "switch",
        "K": "relay",
        "TP": "testpoint",
        "FID": "mechanical",
        "PTH": "mechanical",
        "MH": "mechanical",
        "NUT": "mechanical",
        "H": "mechanical",
    },
    # Kinds that carry no electrical function and are skipped by
    # connectivity checks.
    "mechanical_kinds": ["mechanical"],
    "nets": {
        "ground": ["GND", "CHAS", "AGND", "DGND", "PGND", "SGND"],
        # Rail naming convention: "3V3_ASIC" -> 3.3 V, "0V6_VTT" -> 0.6 V,
        # "28V0_EPS" -> 28 V. Group 1 is the integer part, group 2 the
        # fraction. A leading "N" or "M" means a negative rail.
        "rail_pattern": r"^(?P<neg>[NM])?(?P<int>\d+)V(?P<frac>\d*)(?:[A-Z]?)(?:_|$)",
        # Nets that start like a rail but are logic or telemetry signals
        # derived from it ("3V3_MISC_EN", "1V0_FPGA_TLM_ADC"): no known voltage.
        "rail_signal_pattern": r"_(EN|PG|PGOOD|n?FAULT|n?SHORT|eFUSE_PGOOD|TLM|TLM_ADC|ISENSE|ISENSE_ADC|SNS_ADC|ADC)$",
        # Nets at (about) rail voltage that are not supplies in their own
        # right: current-sense and remote-sense nodes. They count for
        # derating but not for rail checks such as decoupling.
        "rail_sense_pattern": r"_(RSENSE_[PN]|ISENSE_[PN]|SNS)$",
        # Explicit voltages for rails the pattern cannot name, in volts.
        "voltages": {},
        # Differential pair suffixes: each entry is (positive, negative).
        "diff_pair_suffixes": [["_P", "_N"], ["_DP", "_DN"], ["+", "-"]],
        # Names matching these are never treated as diff pair halves; the
        # default covers active-low control signals ("SYS_RESET_N").
        "diff_pair_ignore": [r"_(RST|RESET|INT|INTERRUPT|IRQ|ALERT|FAULT|EN|CS|OE|WE|WP|HOLD)_N$"],
        # Labelled nets allowed to reach a single pin: spares brought out to
        # a named stub on purpose.
        "single_pin_ok": r"(UNUSED|SPARE|_NC\d*$|^NC\d*$)",
        "i2c_pattern": r"(^|_)(I2C\w*_)?(SCL|SDA)(\d*)(_|$)",
    },
    "pins": {
        # Component kinds whose pin types must be backed by part data
        # (pin_functions in electronic-parts-repository).
        "verify_kinds": ["ic"],
        # Part-data direction words -> schematic electrical type names.
        "direction_map": {
            "input": "input", "output": "output", "bidir": "io", "bidirectional": "io", "io": "io",
            "power": "power", "ground": "power", "passive": "passive",
            "open_drain": "open_collector", "open_collector": "open_collector",
            "open_source": "open_emitter", "open_emitter": "open_emitter",
            "hiz": "hiz", "tristate": "hiz", "tri_state": "hiz", "nc": "nc",
        },
        # VS alone or numbered (VS, VS1, VS_A); not VSENSE, VSS or VSYNC.
        "power_names": r"^(VDD|VCC|AVDD|DVDD|VDDQ|VDDIO|VCCIO|VCCA|VCCO|VIN|PVIN|VPP|VS(?![A-Z]))\w*$",
        "ground_names": r"^(GND|VSS|AGND|DGND|PGND|VSSQ|VSSA)\w*$",
    },
    "parts": {
        # Parameters every part of a kind must carry, non-empty.
        "required_params": {
            "*": ["Manufacturer", "Part Number"],
            "capacitor": ["C_Value", "Voltage", "Tolerance", "Dialectric|Dielectric", "Size|Case/Package"],
            "resistor": ["R_Value", "Power_Rating", "Tolerance", "Size|Case/Package"],
            "inductor": ["L_Value"],
        },
        "qualification": {
            "param": "Qualification",
            "kinds": ["capacitor", "resistor", "inductor", "diode", "transistor"],
            "allowed": ["AEC-Q200", "AEC-Q101", "AEC-Q100"],
        },
    },
    "derating": {
        # Fraction of rated value allowed in use. NASA EEE-INST-002 style
        # defaults; tune to the program's derating standard.
        "capacitor_voltage": {"ceramic": 0.60, "tantalum": 0.50, "default": 0.60},
        "resistor_power": 0.50,
    },
    "export": {
        "min_version": "2.2.1",
        # Sheets that are expected to hold no components (title and
        # hierarchy sheets). Any other empty sheet is an export error.
        "empty_sheets_ok": [],
        # Optional expected totals, e.g. {"sheets": 37, "part_numbers": 254,
        # "components": 2366, "designators": {"U1": {"parts": 14, "pins": 1152}}}
        "expect": {},
    },
    # FPGAs whose I/O configuration comes from the FPGA project's constraint
    # files, read in place (relative paths resolve against this config
    # file's directory). Per designator:
    #   constraints: [files]  Libero .pdc/.tcl, as the FPGA build applies them
    #   bank_pattern: regex on the schematic pin name; group 1 is the bank
    #   bank_supply: schematic name of the bank's I/O supply pin, "{bank}"
    #                replaced by the bank number ("VDDI{bank}")
    #   bank_name: set_iobank name of a bank ("Bank{bank}"), when the
    #              constraints set bank voltages
    #   pair_patterns: regexes on the schematic pin name with named groups
    #              `pair` (the pair's id) and `pol` (P or N)
    #   transceiver_pattern: regex on the schematic pin name with named
    #              groups `quad` and `role` (RX, TX or REFCLK)
    "fpga": {},
    "fpga_pins": {
        # Port name suffixes that make two ports one differential pair
        # (positive, negative); "" pairs ddr4_ck0 with ddr4_ck0_n.
        "diff_port_suffixes": [["_p", "_n"], ["_t", "_c"], ["", "_n"]],
        # A top-level port connected to an instance pin matching this is a
        # transceiver reference clock (SmartDesign PF_XCVR_REF_CLK pads).
        "refclk_pads": r"(^|:)REF_CLK_PAD_[PN]$",
        # Without a SmartDesign top level, ports whose names match this are
        # taken as reference clocks.
        "refclk_ports": r"ref_?clk",
    },
    "power": {
        # PWR009: a regulator's set output may differ from its rail's
        # nominal (from the name) by this fraction.
        "regulator_tolerance": 0.03,
    },
    "levels": {
        # Nets joined through a series resistor up to this value count as
        # one signal for level checks (source terminations, current limits).
        "series_max_ohms": 1000,
    },
    "power_up": {
        # FPGA port names that are control signals: enables, resets, chip
        # selects, sleep/shutdown. Their level before the FPGA drives them
        # is checked (PWU001-004).
        "control_ports": r"(^|_)(n?en|n?rst|n?reset|n?short|n?sleep|n?shdn|xce|xclr|cs\d*|oe)(_n)?(_|\d|\[|$)",
        # Receiver thresholds, as fractions of the FPGA bank voltage, used
        # for receivers without VIL/VIH part data (findings are then warnings).
        "assumed_thresholds": [0.3, 0.7],
    },
    "firmware": {
        # ADC channel maps written in firmware as a C enum (see
        # checks/firmware.py). Each: name, enum_file, enum, skip, strip_prefix,
        # channels_per_select, fpga, select_link (regex on the SmartDesign pin
        # a select drives, "{n}" = select number), adc_select_pin,
        # adc_input_pin ("IN{ch}"), net_strip (regexes removed from the input
        # net name before comparing).
        "adc_channel_maps": [],
        # PWM outputs whose full scale firmware assumes: name, constant_file,
        # constant (a #define), constant_unit (mV or V), fpga, ports,
        # tolerance. FW007 compares the constant with the bank rail through
        # the output's RC filter divider.
        "pwm_outputs": [],
        "gpio_maps": [],
    },
    "severity": {},   # per-check override: {"NET002": "warning"}
    "disabled": [],   # check ids to skip
    "waivers": [],    # [{check, ref|net|part_number, reason}]
}


def _merge(base, override):
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            _merge(base[key], value)
        else:
            base[key] = value
    return base


class Config:
    def __init__(self, data=None, base_dir=""):
        self.data = _merge(copy.deepcopy(DEFAULTS), data or {})
        # Directory that relative paths in the config resolve against.
        self.base_dir = base_dir
        n = self.data["nets"]
        self.ground_nets = {g.upper() for g in n["ground"]}
        self._rail_re = re.compile(n["rail_pattern"])
        self._rail_signal_re = re.compile(n["rail_signal_pattern"], re.I)
        self._rail_sense_re = re.compile(n["rail_sense_pattern"], re.I)
        self._voltages = {k.upper(): float(v) for k, v in n["voltages"].items()}
        kinds = self.data["designator_kinds"]
        self._prefixes = sorted(kinds, key=len, reverse=True)
        self.power_pin_re = re.compile(self.data["pins"]["power_names"], re.I)
        self.ground_pin_re = re.compile(self.data["pins"]["ground_names"], re.I)
        self.i2c_re = re.compile(n["i2c_pattern"], re.I)

    @classmethod
    def load(cls, path=None):
        if not path:
            return cls()
        with open(path, encoding="utf-8") as f:
            return cls(yaml.safe_load(f) or {}, base_dir=os.path.dirname(os.path.abspath(path)))

    def __getitem__(self, key):
        return self.data[key]

    def kind(self, component):
        desig = component.designator.upper()
        kinds = self.data["designator_kinds"]
        for prefix in self._prefixes:
            if desig.startswith(prefix.upper()) and desig[len(prefix):len(prefix) + 1].isdigit():
                return kinds[prefix]
        return "unknown"

    def is_mechanical(self, component):
        return self.kind(component) in self.data["mechanical_kinds"]

    def is_ground(self, net_name):
        return net_name.upper() in self.ground_nets

    def net_voltage(self, net_name):
        """Nominal voltage of a rail or ground net, or None for signals."""
        upper = net_name.upper()
        if upper in self._voltages:
            return self._voltages[upper]
        if upper in self.ground_nets:
            return 0.0
        m = self._rail_re.match(net_name)
        if not m or self._rail_signal_re.search(net_name.replace(" ", "")):
            return None
        volts = float(f"{m.group('int')}.{m.group('frac') or '0'}")
        return -volts if m.group("neg") else volts

    def is_rail(self, net_name):
        """A supply rail: known voltage, not ground, not a sense node."""
        v = self.net_voltage(net_name)
        return (v is not None and not self.is_ground(net_name)
                and not self._rail_sense_re.search(net_name))
