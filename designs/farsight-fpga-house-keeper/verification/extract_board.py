#!/usr/bin/env python3
"""Extract the board's power topology from the schematic export.

    extract_board.py <schematic.json> [--json OUT]

The housekeeper drives a regulator enable and waits for that regulator to
report power good. Which enable answers which PGOOD is a fact about the board,
not about the FPGA, and a testbench that guesses it is testing a board that
does not exist.

Guessing is exactly what a name match does. `step_down_en_4v0` and
`step_down_pgood_4v0` look like a pair, and mostly are, but the schematic is
where that is decided -- and it disagrees often enough to matter: some rails
have no PGOOD at all, some PGOODs are ganged, and the enable reaching the
regulator is a different net from the one leaving the FPGA because a series
resistor sits between them.

So this reads the export and follows the connection:

    FPGA ball --R--> regulator EN ... regulator PWRGD --> FPGA ball

and reports the pairs it can prove, the enables it cannot pair, and the
regulator part number for each -- because the turn-on delay a model should use
comes from the part, and the parts are not all the same.
"""

from __future__ import annotations

import argparse
import collections
import hashlib
import json
import re
import sys
from pathlib import Path

try:
    from altium_sch_json import load, problems
except ImportError:
    sys.exit("extract_board.py needs altium_sch_json (ts-altium-sch-json), which this "
             "Python does not have. Use the verification virtualenv, and rebuild it if "
             "it predates the dependency:  make setup")

#: Pin names a regulator uses for its enable input, after normalisation.
#:
#: The export carries Altium's overbar notation, which puts a backslash after
#: every overbarred character: an active-low shutdown appears as `S\H\D\N\`.
#: Matching the literal name found `EN` and missed `S\H\D\N\`, which is why
#: twenty of thirty-one enables reported "regulator NOT FOUND" -- every rail
#: using an LT3065.
ENABLE_PINS = {"EN", "ENABLE", "EN1", "SHDN", "ON", "ENA"}

#: Name parts that mark the pin carrying a regulator's start-up capacitor.
#:
#: Matched against the pin name split on "/", because a pin serving two
#: purposes is named for both: the TPS54821's is `SS/TR` and the LT3065's is
#: `REF/BYP`. Comparing the whole name matched neither, and eleven of
#: twenty-nine rails silently reported no timing capacitor.
TIMING_PIN_PARTS = {"SS", "TR", "REF", "BYP"}

#: A ceramic capacitor's value, encoded in its part number as a three-digit
#: EIA code: two significant figures and a decimal exponent, in picofarads.
CAP_CODE = (re.compile(r"C\d{4}[A-Z]?(\d{3})[A-Z]"),
            re.compile(r"(\d{3})[A-Z]A\d"))

#: Pin names a regulator uses to report power good, after normalisation.
GOOD_PINS = {"PWRGD", "PG", "PGOOD", "POWERGOOD", "PG1", "PGD"}


def capacitance_pf(part_number: str):
    """Capacitance from a part number, or None if it is not decodable.

    Returning None rather than guessing matters: a wrong capacitor value
    produces a wrong delay, and a wrong delay produces a boot sequence that
    stalls or races in ways that look like design defects.
    """
    for pattern in CAP_CODE:
        found = pattern.search(part_number)
        if found:
            digits = found.group(1)
            return int(digits[:2]) * 10 ** int(digits[2])
    return None


def pin_name(raw: str) -> str:
    """A pin name with Altium's overbar escapes removed."""
    return (raw or "").replace("\\", "").strip().upper()

#: Two-terminal parts a net may pass through on its way somewhere. A series
#: resistor between the FPGA and a regulator is normal; following it is the
#: difference between finding a regulator and reporting an unconnected pin.
PASSIVES = ("R", "FB", "L")

#: A net with more connections than this is shared infrastructure -- a supply,
#: a ground, a reset distributed everywhere -- and walking into one reaches
#: the whole board.
#:
#: Without this the trace crosses a pull-up into its supply rail and then finds
#: whichever regulator that supply touches. The first run of this script
#: reported all 29 enables driving the same regulator, which is obviously
#: wrong and would have been obviously wrong to anyone who looked -- but it
#: printed "29 rails paired", which reads like success.
CROWDED = 6

#: Nets that are never a signal path, whatever their fan-out.
POWER_LIKE = ("GND", "VSS", "VDD", "VCC", "CHAS", "AGND", "DGND")


class Board:
    """The netlist, indexed for tracing.

    Read through `altium_sch_json` (ts-altium-sch-json), the reader shared with
    the export script, so the format is parsed in one place. An export that
    reader finds structurally wrong -- empty, or from a script it does not
    know -- is refused here rather than traced into a wrong topology.
    """

    def __init__(self, export: Path):
        design = load(export)
        found = problems(design.raw)
        if found:
            raise SystemExit("%s is not a usable schematic export:\n  %s"
                             % (export, "\n  ".join(found)))
        self.design = design
        self.name = design.name
        self.nets = collections.defaultdict(list)
        self.pins_of = collections.defaultdict(list)
        self.part = {}
        for designator, component in design.components.items():
            self.part[designator] = component.comment or component.part_number
            for pin in component.pins:
                if not pin.connected:
                    continue
                self.nets[pin.net].append((designator, pin.name, pin.designator, pin.sheet))
                self.pins_of[designator].append((pin.net, pin.name))

    def device_nets(self, designator: str) -> dict:
        """Net name to ball, for every pin of one component."""
        out = {}
        for net, entries in self.nets.items():
            for des, _name, ball, _sheet in entries:
                if des == designator:
                    out[net] = ball
        return out

    def _is_signal(self, net: str) -> bool:
        """Is this a point-to-point net rather than shared infrastructure?"""
        upper = net.upper()
        if any(upper == p or upper.startswith(p + "_") for p in POWER_LIKE):
            return False
        return len(self.nets.get(net, ())) <= CROWDED

    def through_passives(self, net: str, depth: int = 2) -> set:
        """Nets reachable from `net` across series two-terminal parts.

        Only across parts whose *other* end is itself a signal net. A pull-up
        resistor's other end is a supply, and following it leaves the signal
        path entirely.
        """
        seen, frontier = {net}, [net]
        for _ in range(depth):
            nxt = []
            for current in frontier:
                for des, _name, _ball, _sheet in self.nets.get(current, []):
                    if not des.startswith(PASSIVES):
                        continue
                    if len(self.pins_of[des]) != 2:
                        continue
                    for other, _pin in self.pins_of[des]:
                        if other in seen or not self._is_signal(other):
                            continue
                        seen.add(other)
                        nxt.append(other)
            frontier = nxt
        return seen

    def driven_regulator(self, enable_net: str):
        """The component whose enable pin this net reaches, if any."""
        for candidate in self.through_passives(enable_net):
            for des, name, _ball, sheet in self.nets.get(candidate, []):
                if pin_name(name) in ENABLE_PINS:
                    return des, candidate, sheet
        return None, "", ""

    def reaches(self, enable_net: str) -> list:
        """What an enable touches, for an enable with no regulator on it.

        Reporting "not found" and stopping invites the reader to assume the
        extraction is broken. Two of this board's enables genuinely have no
        regulator on them -- they leave through a connector to the sensor
        board -- and saying what they *do* reach is the difference between a
        tool defect and a fact about the hardware.
        """
        out = []
        for candidate in self.through_passives(enable_net):
            for des, name, _ball, sheet in self.nets.get(candidate, []):
                if des.startswith(PASSIVES) or not self.part.get(des):
                    continue
                out.append("%s (%s) pin %s on %s"
                           % (des, self.part[des], name, sheet))
        return sorted(set(out))

    def timing_capacitor(self, designator: str):
        """The capacitor on this regulator's start-up pin, in picofarads."""
        for net, name in self.pins_of.get(designator, []):
            parts = set(pin_name(name).split("/"))
            if not parts & TIMING_PIN_PARTS:
                continue
            for des, _n, _b, _s in self.nets.get(net, []):
                if des.startswith("C"):
                    value = capacitance_pf(self.part.get(des, ""))
                    if value:
                        return {"designator": des, "part": self.part[des],
                                "pin": name, "picofarads": value}
        return None

    def good_net(self, designator: str) -> str:
        """The net this component reports power good on, if any."""
        for net, name in self.pins_of.get(designator, []):
            if pin_name(name) in GOOD_PINS:
                return net
        return ""


def extract(export: Path, device: str) -> dict:
    board = Board(export)
    on_device = board.device_nets(device)
    if not on_device:
        raise SystemExit("no component %r in %s" % (device, export.name))

    rails, unpaired = [], []
    for net in sorted(on_device):
        upper = net.upper()
        if not (upper.endswith("_EN") or "_EN_" in upper):
            continue
        regulator, at_pin, sheet = board.driven_regulator(net)
        good = board.good_net(regulator) if regulator else ""
        entry = {
            "enable_net": net,
            "enable_ball": on_device[net],
            "regulator": regulator or None,
            "part": board.part.get(regulator, "") if regulator else "",
            "sheet": sheet,
            "pgood_net": good or None,
            "pgood_ball": on_device.get(good),
            "timing": board.timing_capacitor(regulator) if regulator else None,
        }
        if not (good and good in on_device):
            entry["reaches"] = board.reaches(net)
        (rails if good and good in on_device else unpaired).append(entry)

    return {"board": board.name, "device": device,
            "rails": rails, "unpaired": unpaired}


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("export", type=Path)
    ap.add_argument("--device", default="U2", help="the FPGA's designator")
    ap.add_argument("--json", type=Path, help="write the topology here")
    ap.add_argument("--check", type=Path, metavar="TOPOLOGY",
                    help="compare against a committed topology and report "
                         "what the testbench must do about the difference")
    args = ap.parse_args(argv)

    found = extract(args.export, args.device)

    if args.check:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        from fsverif.board import BoardChanged, compare, load
        try:
            committed = load(args.check)
        except BoardChanged as exc:
            print("CANNOT CHECK: %s" % exc, file=sys.stderr)
            return 2
        result = compare(committed, found)
        if result.clean:
            print("board unchanged: %d rails, the model is current"
                  % result.rails)
            return 0
        print("THE BOARD HAS CHANGED -- %d difference(s) the testbench "
              "depends on:\n" % len(result.changes), file=sys.stderr)
        for change in result.changes:
            print("  %s\n" % change, file=sys.stderr)
        print("Regenerate with: make board", file=sys.stderr)
        return 1
    print("%s -- %d rails paired, %d enables unpaired"
          % (found["board"], len(found["rails"]), len(found["unpaired"])))
    print()
    for rail in found["rails"]:
        print("  %-24s %-6s -> %-10s %-18s -> %-24s %s"
              % (rail["enable_net"], rail["enable_ball"], rail["regulator"],
                 rail["part"][:18], rail["pgood_net"], rail["pgood_ball"]))
    if found["unpaired"]:
        print("\n  enables with no regulator on this board:")
        for rail in found["unpaired"]:
            print("    %-24s %-6s" % (rail["enable_net"], rail["enable_ball"]))
            for touched in rail.get("reaches", []):
                print("        reaches %s" % touched)
    if args.json:
        # Which export this came from, so a committed topology names its source.
        repo = Path(__file__).resolve().parent.parent
        where = args.export.resolve()
        found = {"source": {
            "file": str(where.relative_to(repo)) if where.is_relative_to(repo) else where.name,
            "sha256": hashlib.sha256(where.read_bytes()).hexdigest(),
            "exportScriptVersion": Board(args.export).design.export_version},
            **found}
        args.json.write_text(json.dumps(found, indent=2) + "\n", encoding="utf-8")
        print("\nwrote %s" % args.json)
    return 0


if __name__ == "__main__":
    sys.exit(main())
