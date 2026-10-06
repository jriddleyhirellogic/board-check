"""The device's pins, as built: HK-IO-01, -02, -08 and -09.

Items: VC-HK-0025, VC-HK-0026, VC-HK-0027, VC-HK-0028.

  HK-IO-01  Every top-level port shall be assigned to a physical pin, or be
            named in an active constraint entry that records it as
            deliberately unplaced.
  HK-IO-02  Every assigned pin shall correspond to a real pin of the
            A3PE3000L-FG484M.
  HK-IO-08  Every assigned pin shall connect to the net implied by its port
            name.
  HK-IO-09  Every output shall be held in its inactive state, by an internal
            pull of the polarity that corresponds to inactive, from the moment
            the I/O ring is powered until the design drives it.

Read from `top.sv`, both pinouts (`constr/.../io/{fm,em}/io_constraints.pdc`)
and the flight board's schematic export. The schematic is the FM board's, so
the board-side checks use the FM pinout; the EM pinout is checked where the
claim does not depend on the board.
"""

from __future__ import annotations

import re

from fsverif import design

FPGA = "U2"
VARIANTS = tuple(design.PDC)

# ---- HK-IO-08: the naming transform -------------------------------------
#
# A port's name implies its net by these rules, applied to the net on the pad
# or to the net one series resistor beyond it (most signals leave through a
# 33 ohm resistor and are named on the far side: R_2V5_8GB_EN -> 2V5_8GB_EN):
#
# 1. A generic link to the PolarFire is named for its direction, not its
#    signal: PA3_TO_PF_MISCn carries a housekeeper output, PF_TO_PA3_MISCn a
#    housekeeper input. Which link carries which signal is the ICD's
#    (CM-01979) and the interface plan's to check.
# 2. debug[n] is on BANK2_DEBUGn.
# 3. Otherwise, split both names into words on "_". The port's words, with its
#    region translated to the board's name for it (REGIONS) and its kind to
#    the board's (KINDS), must all be in the net's name, and the net's name
#    may add only a rail voltage (15V0, 28V0) or a word in EXTRA. So
#    `ddr8_en_2v5` is `2V5_8GB_EN`, and `imx_en_1v8` is not `1V8_IMX_FPGA_EN`.
# 4. A port whose net is named some other way is in EXPLICIT, with the net it
#    must be on and why. Still checked: an exception names a net, it does not
#    excuse one.

#: Region word in a port name -> the words the board uses for it. Several
#: where the board names the same region more than one way.
REGIONS = {
    "ddr8": (("8GB",),),
    "ddr16": (("16GB",),),
    "step_down": (("REG",), ("STEP", "DOWN")),
    "lvds": (("3V3", "MISC"), ("LVDS",)),
    "stepper_pri": (("28V0", "PRIM"), ("STEPPER", "PRI")),
    "stepper_sec": (("28V0", "SEC"), ("STEPPER", "SEC")),
}
#: Signal kind in a port name -> the board's word for it.
KINDS = {"status_to_pf": "PGOOD"}
#: Words a net may add beyond the port's, besides a rail voltage: the board
#: names the DDR status for its ECC memory, the DDR 0V6 rail for its role as
#: termination supply (VTT), and the heartbeat for its device.
EXTRA = {"ECC", "VTT", "PA3"}
VOLTAGE = re.compile(r"^\d+V\d+$")

#: Ports on a net named otherwise, with the net and the reason.
EXPLICIT = {
    "clk": ("ASIC_50MHZ_CLOCK", "the clock is named for its oscillator net, shared with nothing else"),
    "arstn": ("PA3_RESET", "the reset is named for the device it resets"),
    "imx_ctrl": ("IMX_POWER_TOGGLE", "the PolarFire's name for its IMX power request"),
}

MISC = re.compile(r"^(PA3_TO_PF|PF_TO_PA3)_MISC\d+$")


def _words(name: str) -> list:
    # "1V2_8GB_ PGOOD" has a space in the schematic; it is the same net name.
    return [w for w in name.upper().replace(" ", "").split("_") if w]


def _expected(port: str) -> list:
    """The word sets a port's net may carry, one per way of naming its region."""
    base = re.sub(r"\[\d+\]$", "", port)
    kind = next((k for k in KINDS if base.endswith("_" + k)), None)
    if kind:
        base = base[: -len(kind) - 1]
    region = next((r for r in sorted(REGIONS, key=len, reverse=True)
                   if base == r or base.startswith(r + "_")), None)
    rest = base[len(region):].strip("_") if region else base
    words = set(_words(rest)) | ({KINDS[kind]} if kind else set())
    alternatives = REGIONS[region] if region else ((),)
    return [words | set(alt) for alt in alternatives]


def _matches(port: str, net: str) -> bool:
    words = set(_words(net))
    for expected in _expected(port):
        extra = words - expected
        if expected <= words and all(w in EXTRA or VOLTAGE.match(w) for w in extra):
            return True
    return False


def _net_problem(board, port: str, direction: str, pad: str | None) -> str | None:
    """Why a port's pin is not on the net its name implies, or None."""
    if pad is None or len(board.nets[pad].pins) == 1:
        return f"{port}: its ball connects to nothing (net {pad or 'none'})"
    nets = design.signal_nets(board, pad)
    if port in EXPLICIT:
        want, _ = EXPLICIT[port]
        return None if want in nets else f"{port}: on {nets}, not {want} ({EXPLICIT[port][1]})"
    misc = [n for n in nets if MISC.match(n)]
    if misc:
        towards = MISC.match(misc[0]).group(1)
        wanted = "output" if towards == "PA3_TO_PF" else "input"
        if direction != wanted:
            return (f"{port}: an {direction} on {misc[0]}, which carries the PolarFire "
                    f"link {'from the housekeeper' if wanted == 'output' else 'to the housekeeper'}")
        return None
    debug = re.fullmatch(r"debug\[(\d+)\]", port)
    if debug:
        want = f"BANK2_DEBUG{debug.group(1)}"
        return None if want in nets else f"{port}: on {nets}, not {want}"
    if any(_matches(port, n) for n in nets):
        return None
    return f"{port}: on {' -> '.join(nets)}, which its name does not imply"


def test_HK_IO_08_pin_matches_net_of_port_name(board):
    """VC-HK-0027: the schematic net at every assigned ball is the net the
    port name denotes, under the transform above."""
    bits = design.port_bits()
    problems = []
    for port, pin in sorted(design.pin_constraints("fm").items()):
        found = _net_problem(board, port, bits.get(port, "?"), board.net_of(FPGA, pin.ball))
        if found:
            problems.append(f"{found} (ball {pin.ball})")
    assert not problems, "\n  ".join(
        ["pins not on the net their port name implies (FM pinout, schematic CM-03543 "
         f"rev {board.revision}):"] + problems)


# ---- HK-IO-01 -------------------------------------------------------------

def test_HK_IO_01_every_port_placed_or_declared(board):
    """VC-HK-0025: every bit of every top-level port carries a pin assignment
    (an active set_io), and every set_io names a port bit the design has.
    Commented-out entries are neither."""
    bits = design.port_bits()
    problems = []
    for variant in VARIANTS:
        placed = design.pin_constraints(variant)
        unplaced = sorted(set(bits) - set(placed))
        unknown = sorted(set(placed) - set(bits))
        unassigned = sorted(p for p, c in placed.items() if not c.ball)
        if unplaced:
            problems.append(f"{variant}: no pin assignment for {', '.join(unplaced)}")
        if unknown:
            problems.append(f"{variant}: constraints for ports the design does not have: "
                            + ", ".join(unknown))
        if unassigned:
            problems.append(f"{variant}: set_io with no pin for {', '.join(unassigned)}")
    assert not problems, "\n  ".join(["top-level ports not placed:"] + problems)


# ---- HK-IO-02 -------------------------------------------------------------

#: A user I/O ball's name, as the device symbol gives it: `IO305PDB7V3`, or a
#: global input that is also user I/O, `GFB0/IO274NPB7V0`.
USER_IO = re.compile(r"(^|/)IO\d+")


def test_HK_IO_02_assigned_pins_exist_on_package(board):
    """VC-HK-0026: every assigned pin is a ball of the A3PE3000L-FG484M, and a
    user I/O ball. The package pinout is the device symbol's in the flight
    schematic (U2, 484 balls), named as the vendor names them."""
    fpga = board.components[FPGA]
    balls = {p.designator: p.name for p in fpga.pins}
    problems = []
    if not fpga.part_number.startswith("A3PE3000L-FG484"):
        problems.append(f"{FPGA} is {fpga.part_number}, not the A3PE3000L-FG484")
    if len(balls) != 484:
        problems.append(f"{FPGA} has {len(balls)} pins in the schematic, not the package's 484")
    for variant in VARIANTS:
        for port, pin in sorted(design.pin_constraints(variant).items()):
            name = balls.get(pin.ball)
            if name is None:
                problems.append(f"{variant}: {port} on {pin.ball}, which the package does not have")
            elif not USER_IO.search(name):
                problems.append(f"{variant}: {port} on {pin.ball} ({name}), not a user I/O")
    assert not problems, "\n  ".join(["pin assignments the package cannot honour:"] + problems)


# ---- HK-IO-09 -------------------------------------------------------------

#: Every output's inactive level, by class, and why. An output in no class
#: fails: its inactive level has not been decided.
INACTIVE = (
    (re.compile(r"_en($|_)"), "DOWN", "power enables are active high"),
    (re.compile(r"_nshort_"), "UP", "the IMX shorts are active low"),
    (re.compile(r"_status_to_pf$"), "DOWN", "a health indication reads healthy when high"),
    (re.compile(r"_failure_metadata"), "DOWN", "metadata reads 'no failure' at 0"),
    (re.compile(r"^rs422_ttl_bus_to_farsight_pf$"), "DOWN",
     "held low until the FPGA region has booted (HK-UART-02)"),
    (re.compile(r"^rs422_ttl_farsight_to_bus_pa3$"), "UP", "the bus idles high (HK-UART-10)"),
)

#: Outputs with no inactive level to hold. Each needs an approved exception;
#: these are the candidates the requirement names, none approved yet.
NO_INACTIVE_LEVEL = re.compile(r"^(heartbeat|fw_version\[\d+\]|debug\[\d+\])$")
#: Approved exceptions: port -> (approver, date, reason). Empty until approved.
APPROVED = {}


def _board_pulls(board, ball: str) -> str:
    pad = board.net_of(FPGA, ball)
    found = [f"{r} {how} on {n}" for n in (design.signal_nets(board, pad) if pad else [])
             for r, how in design.pulls(board, n)]
    return f" (on the board: {', '.join(found)})" if found else " (no pull on the board either)"


def test_HK_IO_09_outputs_held_inactive_before_drive(board):
    """VC-HK-0028: every output carries an internal pull of its inactive
    level, in both pinouts; an output with no inactive level is an approved
    exception. Board pulls are reported beside a failure, not counted: the
    requirement is the internal pull."""
    bits = design.port_bits()
    outputs = sorted(p for p, d in bits.items() if d == "output")
    problems = []
    for variant in VARIANTS:
        placed = design.pin_constraints(variant)
        for port in outputs:
            pin = placed.get(port)
            if pin is None:
                continue                      # unplaced: HK-IO-01's
            side = _board_pulls(board, pin.ball) if variant == "fm" else ""
            if NO_INACTIVE_LEVEL.match(port):
                if port not in APPROVED:
                    problems.append(f"{variant}: {port} has no inactive level and no approved "
                                    f"exception (pull {pin.pull}){side}")
                continue
            cls = [(want, why) for rx, want, why in INACTIVE if rx.search(port)]
            if len(cls) != 1:
                problems.append(f"{port}: in {len(cls)} output classes, so its inactive level "
                                "is not decided")
                continue
            want, why = cls[0]
            if pin.pull != want:
                problems.append(f"{variant}: {port} pull {pin.pull}, needs {want} -- {why}{side}")
    assert not problems, "\n  ".join(["outputs not held inactive before the design drives them:"]
                                     + problems)
