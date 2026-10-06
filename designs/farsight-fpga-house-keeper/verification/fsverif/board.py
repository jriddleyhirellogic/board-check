"""What changed in the board, and what it means for the testbench.

The power topology the model is built from was extracted from a schematic
export. That export is not in this repository -- it is large, it is controlled
elsewhere, and it is re-issued whenever anything on the board changes,
including things the housekeeper never sees.

So the question is not "has the schematic changed" but **"has anything the
testbench depends on changed"**. Those are different questions, and answering
the first is worse than useless: a re-export with a new timestamp would report
a change every time, and a report that cries wolf gets switched off.

This compares the *extracted topology* rather than the file. A schematic
change that does not touch a power rail produces no finding. A change that
does produces a finding naming the rail, what changed, and what it obliges
somebody to do -- because the consequences differ:

| Change | What it obliges |
| --- | --- |
| a rail appears | a pin, possibly an item, possibly a test |
| a rail disappears | a test now drives nothing |
| enable now reaches a different regulator | the model's pairing is wrong |
| regulator part changed | the delay family changed; review `delays.yaml` |
| timing capacitor changed | the delay changed; the model regenerates |
| a rail moves off board | the model must stop driving its power-good |

The last column is why this is not simply a diff. A capacitor change
regenerates the model and needs no human thought; a pairing change means every
test that booted the device may now be exercising something else.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path

#: What a reader must do about each kind of change. Carried with the finding
#: rather than left to be inferred, because "the board changed" without a
#: consequence is a notification rather than a finding.
CONSEQUENCE = {
    "added": "a rail the testbench does not model; it needs a pin, and "
             "probably an item and a test",
    "removed": "a rail the testbench still models; any test driving it is "
               "now driving nothing",
    "repaired": "this enable now reaches a different regulator, so the "
                "model's enable-to-power-good pairing is wrong",
    "repart": "a different regulator is fitted, so the start-up delay comes "
              "from a different datasheet; review board/delays.yaml",
    "retimed": "the capacitor setting the start-up ramp changed, so the "
               "delay changed; the model regenerates from this",
    "offboard": "this rail's regulator has left the board; the model must "
                "stop driving its power-good from a housekeeper enable",
    "onboard": "this rail's regulator is now on the board; the model can "
               "drive its power-good directly",
}


class BoardChanged(Exception):
    """The schematic no longer describes the board the testbench models."""


@dataclass
class Change:
    kind: str
    rail: str
    was: str = ""
    now: str = ""

    def __str__(self) -> str:
        detail = ""
        if self.was or self.now:
            detail = "  %s -> %s" % (self.was or "(none)", self.now or "(none)")
        return "%-10s %-24s%s\n            %s" % (
            self.kind, self.rail, detail, CONSEQUENCE.get(self.kind, ""))


@dataclass
class Comparison:
    changes: list = field(default_factory=list)
    rails: int = 0

    @property
    def clean(self) -> bool:
        return not self.changes


def _by_enable(topology: dict) -> dict:
    """Rails keyed by the enable net, with the facts the model depends on.

    Deliberately not the whole entry. The sheet a regulator is drawn on and
    the ball it lands on are real facts that change for reasons the testbench
    does not care about, and including them would report a change every time
    somebody rearranged a schematic page.
    """
    out = {}
    for rail in topology.get("rails", []):
        timing = rail.get("timing") or {}
        out[rail["enable_net"]] = {
            "regulator": rail.get("regulator"),
            "part": rail.get("part", ""),
            "pgood_net": rail.get("pgood_net"),
            "picofarads": timing.get("picofarads"),
            "onboard": True,
        }
    for rail in topology.get("unpaired", []):
        out[rail["enable_net"]] = {"regulator": None, "part": "",
                                   "pgood_net": None, "picofarads": None,
                                   "onboard": False}
    return out


def compare(committed: dict, extracted: dict) -> Comparison:
    """What differs between the modelled board and the one in the schematic."""
    was, now = _by_enable(committed), _by_enable(extracted)
    result = Comparison(rails=len(now))

    for rail in sorted(set(now) - set(was)):
        result.changes.append(Change("added", rail, now=now[rail]["part"]))
    for rail in sorted(set(was) - set(now)):
        result.changes.append(Change("removed", rail, was=was[rail]["part"]))

    for rail in sorted(set(was) & set(now)):
        before, after = was[rail], now[rail]
        if before["onboard"] != after["onboard"]:
            result.changes.append(Change(
                "offboard" if before["onboard"] else "onboard", rail))
            continue
        if before["pgood_net"] != after["pgood_net"] or \
                before["regulator"] != after["regulator"]:
            result.changes.append(Change(
                "repaired", rail,
                "%s/%s" % (before["regulator"], before["pgood_net"]),
                "%s/%s" % (after["regulator"], after["pgood_net"])))
            continue
        if before["part"] != after["part"]:
            result.changes.append(Change("repart", rail,
                                         before["part"], after["part"]))
        if before["picofarads"] != after["picofarads"]:
            result.changes.append(Change(
                "retimed", rail,
                _nf(before["picofarads"]), _nf(after["picofarads"])))
    return result


def _nf(picofarads) -> str:
    return "%g nF" % (picofarads / 1000.0) if picofarads else "(none)"


def load(path: Path) -> dict:
    if not path.is_file():
        raise BoardChanged(
            "no extracted topology at %s. The board model is built from it, "
            "so without it there is nothing to model and nothing to compare. "
            "Run: make board" % path)
    return json.loads(path.read_text(encoding="utf-8"))


# ---------------------------------------------------------------------------
# The model itself.
#
# The testbench cannot boot the device without one. Every region of the boot
# sequence waits for the rails it just enabled to report good, so a device
# whose power-good inputs are held at a constant 1 never sees the rising edge
# it is waiting for, and a device whose inputs are held at 0 waits forever.
# Holding them all high reached one enable of thirty-three.
#
# What the model owes a test is therefore not a voltage. It is an *edge, in
# the right order, at the right remove* -- and the ability to withhold one.
# ---------------------------------------------------------------------------

import re

#: Ball assignments in the place-and-route constraints. This is the only join
#: between the schematic and the RTL: the schematic knows `R_2V5_8GB_EN` on
#: ball Y20, the design knows `ddr8_en_2v5`, and nothing but the ball says
#: they are the same wire. Matching on name would have been guesswork -- the
#: schematic calls the LVDS rail `R_3V3_MISC_EN`.
BALL = re.compile(r"set_io\s*\{(\w+)\}\s*-pinname\s*\"(\w+)\"")

#: Rails brought up by something other than a housekeeper enable -- so their
#: source is a constant rather than a pin of the device.
#:
#: The EPS e-fuse is upstream of everything on this board: it reports the
#: housekeeper's own supply, which is necessarily already good by the time the
#: device is out of reset. `health_monitor.sv:703` holds the sequence in
#: failure while it is low.
#:
#: It is modelled rather than excluded. Excluding it left it undriven, which
#: in Verilator's two-state world reads 0 rather than X -- so the device sat
#: in permanent failure, not one enable of thirty-three ever moved, and
#: nothing said why. A rail nothing drives is the failure this model exists to
#: remove, so the model drives every one.
UPSTREAM = "1'b1"
UPSTREAM_RAILS = {"eps_efuse_pgood": "EPS e-fuse (ADM1270 U88), always good unless failed"}


@dataclass(frozen=True)
class Rail:
    """One power-good input, and what makes it rise."""

    pgood: str          #: the device input this model drives
    source: str         #: the device output -- or upstream power-good -- it follows
    delay_ms: float
    nfault: str = ""    #: the matching fault input, where the part has one
    why: str = ""       #: where the number came from, carried into the source
    #: PGOOD is released -- reads high -- while the enable is low, as the
    #: LT3065's does (`delays.yaml`, `pgood_released_when_disabled`).
    released: bool = False


def ball_map(pdc: Path) -> dict:
    text = pdc.read_text(encoding="utf-8")
    found = {ball: signal for signal, ball in BALL.findall(text)}
    if not found:
        raise BoardChanged(
            "no pin assignments in %s. The schematic and the RTL are joined "
            "only by ball number, so without them no rail can be connected "
            "to the pin it drives." % pdc)
    return found


def _family(part: str, delays: dict):
    """The datasheet entry governing a part, by family prefix.

    Parts are ordered numbers -- `TPS7H4003-SEP` and `TPS7H4003MDDWSEP` are
    the same silicon in different packages -- so the family is a prefix of the
    part number rather than the whole of it.
    """
    flat = re.sub(r"[^A-Z0-9]", "", part.upper())
    for section in ("computed", "fixed"):
        for name, entry in (delays.get(section) or {}).items():
            if flat.startswith(re.sub(r"[^A-Z0-9]", "", name.upper())):
                return section, name, entry
    return None, None, None


def _computed_ms(entry: dict, picofarads: int) -> float:
    """Start-up time from the capacitor actually fitted, per the datasheet."""
    nanofarads = picofarads / 1000.0
    if "iss_ua" in entry:
        # To power-good, where the datasheet gates it on the soft-start pin
        # reaching a voltage; otherwise the soft-start time.
        return nanofarads * entry.get("pgood_ss_v", entry["vref_v"]) / entry["iss_ua"]
    return entry["reference_ms"] * nanofarads / entry["reference_nf"]


def rails(topology: dict, delays: dict, balls: dict) -> list:
    """Every power-good this model drives, in a stable order.

    Stable because a test names a rail to fail and the model takes a bit
    index; if the order moved with the schematic, a test asking for the DDR8
    2V5 rail would start failing a different one and still pass.
    """
    nfaults = _nfault_for()
    found, seen = [], set()

    for rail in topology.get("rails", []):
        source = balls.get(rail["enable_ball"])
        pgood = balls.get(rail["pgood_ball"])
        if not source or not pgood:
            raise BoardChanged(
                "%s: ball %s/%s is not assigned in the constraints, so the "
                "schematic rail cannot be joined to a device pin."
                % (rail["enable_net"], rail["enable_ball"], rail["pgood_ball"]))
        section, family, entry = _family(rail["part"], delays)
        timing = rail.get("timing") or {}
        if section == "computed" and timing.get("picofarads"):
            delay = _computed_ms(entry, timing["picofarads"])
            why = "%s, %s %g nF (%s)" % (family, timing["pin"],
                                         timing["picofarads"] / 1000.0,
                                         timing["designator"])
        elif section == "fixed":
            delay, why = entry["delay_ms"], "%s, fixed" % family
        else:
            delay = delays["uncharacterised"]["default_ms"]
            why = "%s, UNCHARACTERISED" % (rail["part"] or "unknown part")
        released = bool(entry and entry.get("pgood_released_when_disabled"))
        if released:
            why += "; PGOOD high while disabled"
        found.append(Rail(pgood, source, delay, nfaults.get(pgood, ""), why, released))
        seen.add(pgood)

    # Rails whose enable leaves the board. The regulator is elsewhere, but the
    # power-good still comes back, so the model still owes the device an edge.
    for rail in topology.get("unpaired", []):
        source = balls.get(rail["enable_ball"])
        pgood = _pgood_for(source)
        if source and pgood and pgood not in seen:
            found.append(Rail(pgood, source,
                              delays["uncharacterised"]["default_ms"],
                              nfaults.get(pgood, ""), "off board, "
                              "UNCHARACTERISED"))
            seen.add(pgood)

    # Rails that start themselves. The VTT regulators' enable ties to the 2V5
    # rail through a zero-ohm resistor, so they follow that rail's power-good
    # rather than any housekeeper output -- the device's own *_en_0v6 pins are
    # not connected to anything.
    for pgood, entry in (delays.get("cascaded") or {}).items():
        section, family, spec = _family(entry["part"], delays)
        delay = spec["delay_ms"] if section == "fixed" \
            else delays["uncharacterised"]["default_ms"]
        found.append(Rail(pgood, entry["follows"], delay, nfaults.get(pgood, ""),
                          "%s, fixed, cascaded off %s"
                          % (family or entry["part"], entry["follows"])))
        seen.add(pgood)

    for pgood, why in UPSTREAM_RAILS.items():
        if pgood not in seen:
            found.append(Rail(pgood, UPSTREAM, 0.0, nfaults.get(pgood, ""), why))
            seen.add(pgood)

    _check_complete(seen)
    return sorted(found, key=lambda r: r.pgood)


#: `_en` as a whole name segment. Substituting the substring would turn
#: `step_down_en_2v2` into `step_down_pgood_2v2` correctly and also rewrite
#: any pin with "en" inside a word.
EN_SEGMENT = re.compile(r"_en(_|$)")
NFAULT_SEGMENT = re.compile(r"_nfault(_|$)")


def _pgood_for(enable: str) -> str:
    return EN_SEGMENT.sub(r"_pgood\1", enable)


def _nfault_for() -> dict:
    """Fault inputs keyed by the power-good of the same rail.

    Derived by name, which the schematic join deliberately is not -- but here
    both names are the design's own, and every one is checked to land on a
    real power-good input. A fault pin that did not would be a silent hole in
    the model, so it raises instead.
    """
    from fsverif.pins import NFAULT_INPUTS, PGOOD_INPUTS

    mapped, stray = {}, []
    for name in NFAULT_INPUTS:
        pgood = NFAULT_SEGMENT.sub(r"_pgood\1", name)
        if pgood in PGOOD_INPUTS:
            mapped[pgood] = name
        else:
            stray.append(name)
    if stray:
        raise BoardChanged(
            "these fault inputs do not correspond to any power-good input, so "
            "the model would leave them undriven and a test would read X: %s"
            % ", ".join(stray))
    return mapped


def _check_complete(seen: set) -> None:
    """Every power-good input must be driven by something.

    An undriven input reads 0 in Verilator's two-state world rather than X, so
    a rail the model forgot does not announce itself -- it just never reports
    good, and the boot sequence stalls somewhere unrelated. That is exactly
    the failure this model exists to remove, so it is checked rather than
    hoped for.
    """
    from fsverif.pins import PGOOD_INPUTS

    missing = [p for p in PGOOD_INPUTS if p not in seen]
    if missing:
        raise BoardChanged(
            "the board model drives no value onto these power-good inputs, so "
            "the device would wait forever for a rail nothing brings up: %s"
            % ", ".join(missing))


def index(rail_list: list) -> dict:
    """Bit position of each rail in the model's `rail_fail`, `rail_fault` and
    `rail_force` inputs."""
    return {rail.pgood: n for n, rail in enumerate(rail_list)}


def drive(dut, *, fail=(), fault=(), force=()) -> None:
    """Set all three rail controls at once, by power-good name.

    All three, every time: the vectors persist from one cocotb test to the
    next within a module, so a test that set only the one it cared about
    would inherit whatever the test before it left in the other two.
    """
    bits = index(model())
    for vector, rails in (("rail_fail", fail), ("rail_fault", fault),
                          ("rail_force", force)):
        getattr(dut, vector).value = sum(1 << bits[r] for r in rails)


def generate(rail_list: list, period_ns: int, module: str = "board_model") -> str:
    """The board model's source.

    Each rail is a counter rather than a `#` delay. The delays are
    milliseconds against a twenty-nanosecond clock, so the quantisation is
    four parts per million, and a counter restarts correctly when an enable
    glitches -- which matters, because the sequence retries.

    Power-good falls combinationally. A clocked fall would keep a rail
    reporting good after the clock stopped, and `HK-OFFNOM-04` is about
    exactly that.

    A rail whose regulator releases power-good while disabled (the LT3065)
    reads HIGH whenever its enable is low, drops the moment the enable rises,
    and rises again after its start-up delay. `rail_fail` and `rail_force`
    override that as they do every rail, so a test can still hold one low or
    high in any state.
    """
    if not rail_list:
        raise BoardChanged("no rails, so the model would drive nothing")

    ports, body = [], []
    sources = sorted({r.source for r in rail_list}
                     - {r.pgood for r in rail_list} - {UPSTREAM})
    for name in sources:
        ports.append("  input  logic %s" % name)
    for rail in rail_list:
        ports.append("  output logic %s" % rail.pgood)
        if rail.nfault:
            ports.append("  output logic %s" % rail.nfault)

    for n, rail in enumerate(rail_list):
        cycles = max(1, int(round(rail.delay_ms * 1e6 / period_ns)))
        body.append("""
  // %(pgood)s follows %(source)s after %(ms).3f ms -- %(why)s
  localparam int unsigned DLY_%(n)d = %(cycles)d;
  logic [31:0] cnt_%(n)d;
  logic        up_%(n)d;
  logic        ok_%(n)d;
  assign ok_%(n)d = %(source)s & ~rail_fail[%(n)d];
  always_ff @(posedge clk) begin
    if (!ok_%(n)d) begin
      cnt_%(n)d <= DLY_%(n)d;
      up_%(n)d  <= 1'b0;
    end else if (cnt_%(n)d != 0) begin
      cnt_%(n)d <= cnt_%(n)d - 1;
    end else begin
      up_%(n)d  <= 1'b1;
    end
  end
  assign %(pgood)s = %(level)s | rail_force[%(n)d];%(nfault)s""" % {
            "n": n, "pgood": rail.pgood, "source": rail.source,
            "ms": rail.delay_ms, "cycles": cycles, "why": rail.why,
            "level": ("(~rail_fail[%(n)d] & (%(source)s ? up_%(n)d : 1'b1))"
                      % {"n": n, "source": rail.source}) if rail.released
                     else "(up_%(n)d & ok_%(n)d)" % {"n": n},
            "nfault": ("\n  assign %s = ~rail_fault[%d];  // active low"
                       % (rail.nfault, n)) if rail.nfault else "",
        })

    return """// GENERATED -- do not edit, and do not commit.
//
// Written by fsverif.board from verification/board/topology.json (extracted
// from the schematic) and verification/board/delays.yaml (from datasheets).
//
// This is stimulus, not a claim. No housekeeper requirement bounds a
// regulator; every timed requirement bounds the housekeeper's own latency,
// measured from its own enable. What this owes a test is an edge in the right
// order, at the right remove, and the ability to withhold one.
//
// The delays are not blanket values, and that is the point. With a 2 ms
// blanket the DDR8 region stalled and looked like a design defect; with the
// fitted capacitors it boots, because what decides the sequence is the delay
// of each rail *relative* to the others.
//
// Two failures, because they are not the same failure. `rail_fail` holds a
// rail out of regulation -- its power-good held low whatever its enable is
// doing, which is a regulator that did not start. `rail_fault` asserts the part's fault pin, which is an
// overcurrent trip on a rail that may well be up.
//
// They were one input at first, and the difference showed immediately: asking
// for a dead DDR8 rail also raised an overcurrent fault before the sequence
// had begun, and the device held every enable down for a reason the test had
// not meant to create.
//
// And a third: `rail_force` holds a rail's power-good HIGH whatever its
// enable is doing. VENV-01 asks for exactly this: each PGOOD forced
// independently, including to states the hardware cannot produce. It wins
// over `rail_fail`, so a test can hold a rail dead and still pulse its PGOOD.
//
// Some regulators produce part of that state on their own. The LT3065's
// power-good is released -- reads high -- whenever its enable is low: high
// before the source is enabled, dropping when it is, and high again as soon
// as it is disabled. Those rails are marked "PGOOD high while disabled" below.

module %(module)s (
  input  logic clk,
  input  logic [%(top)d:0] rail_fail,
  input  logic [%(top)d:0] rail_fault,
  input  logic [%(top)d:0] rail_force,
%(ports)s
);
%(body)s

endmodule
""" % {
        "module": module,
        "top": len(rail_list) - 1,
        "ports": ",\n".join(ports),
        "body": "\n".join(body),
    }


#: Where the extracted topology and the datasheet delays live. Committed,
#: because a checkout must be able to build the model without the schematic:
#: the export is large, controlled elsewhere, and not everyone has it.
BOARD_DIR = Path(__file__).resolve().parent.parent / "board"
TOPOLOGY = BOARD_DIR / "topology.json"
#: The board's schematic export, committed under a stable name (README: the
#: board model). Read with `altium_sch_json`.
SCHEMATIC = BOARD_DIR / "CM-03545.json"
DELAYS = BOARD_DIR / "delays.yaml"
#: The flight pinout. The two pinouts differ only in the RS-422 transmit and
#: receive pins, which carry no power rail, so either would give the same
#: board model -- but the environment exercises the flight configuration
#: (`VENV-02`), and naming it here says which one was read.
CONSTRAINTS = (Path(__file__).resolve().parent.parent.parent
               / "constr" / "a3pe3000l-fg484m" / "io" / "fm"
               / "io_constraints.pdc")


def load_delays(path: Path = DELAYS) -> dict:
    import yaml

    if not path.is_file():
        raise BoardChanged(
            "no delay table at %s. Every rail's start-up time comes from it, "
            "and without it the model could only guess -- which is what "
            "made the DDR8 region look like a design defect." % path)
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def model() -> list:
    """Every rail of this board, ready to generate or to index."""
    return rails(load(TOPOLOGY), load_delays(), ball_map(CONSTRAINTS))


def write(rail_list: list, into: Path, period_ns: int,
          module: str = "board_model") -> Path:
    into.mkdir(parents=True, exist_ok=True)
    target = into / ("%s.sv" % module)
    fresh = generate(rail_list, period_ns, module)
    # Only when it differs: rewriting an identical file moves its timestamp
    # and rebuilds the whole device for no change. That is under ten seconds
    # for a lean build and considerably more for a full-visibility one, on
    # every run of every module.
    if not target.is_file() or target.read_text(encoding="utf-8") != fresh:
        target.write_text(fresh, encoding="utf-8")
    return target
