"""The IMX short outputs, as built: HK-PROT-01.

Item: VC-HK-0093.

  HK-PROT-01  The housekeeper shall provide an active-low short output for
              each of the IMX 1V1 and 1V8 supplies.

Criteria: one active-low short output for the IMX 1V1 supply and one for the
IMX 1V8 supply, each assigned to a pin and each driven only by the protection
logic.

Checked in the three places the claim lives -- the RTL, the pin constraints
and the board -- because each could be wrong while the others are right. The
behaviour (both asserted on an IMX latchup, each released when its supply is
next enabled) is HK-PROT-02 and -03, simulated in test_hk_prot.

On the board each output reaches its rail through the same circuit: a 33 ohm
series resistor; a 100 kohm pull-up to 3V3_ASIC; the gate of a P-channel FET
whose source is on 3V3_ASIC; that FET's drain, pulled down, driving the gate
of an N-channel FET whose source is on GND and whose drain reaches the rail
through a current-sense resistor. Pulling the output low turns the P-FET on,
which turns the N-FET on, which shorts the rail: active low. The pull-up keeps
it released while the FPGA is unconfigured. The checks follow nets, not pin
names: the N-FET's symbol labels drain pins 7 and 8 "S".
"""

from fsverif import design

#: Port, the schematic ball on U2 the flight pinout puts it on, and the rail.
SHORTS = (("imx_nshort_1v1", "C3", "1V1_IMX"),
          ("imx_nshort_1v8", "A8", "1V8_IMX"))
FPGA = "U2"
SUPPLY = "3V3_ASIC"
GROUND = "GND"


def _two_pin(board, net, prefix="R"):
    """(designator, other net) for every two-pin part of this kind on `net`."""
    out = []
    for comp in board.nets[net].components():
        nets = [p.net for p in comp.pins]
        if comp.designator.startswith(prefix) and len(comp.pins) == 2 and net in nets:
            out.append((comp.designator, nets[1] if nets[0] == net else nets[0]))
    return out


def _fet_by_gate(board, net):
    """The FET whose gate pin is on `net`."""
    for pin in board.nets[net].pins:
        if pin.component.designator.startswith("Q") and pin.name.upper() in ("GATE", "G"):
            return pin.component
    return None


def _board_path(board, ball, rail) -> list:
    """What is wrong with the circuit from this ball to the rail, if anything."""
    wrong = []
    pad = board.net_of(FPGA, ball)
    if not pad:
        return [f"{FPGA} ball {ball} is not connected"]
    series = [(r, n) for r, n in _two_pin(board, pad) if n not in (SUPPLY, GROUND)]
    if len(series) != 1:
        return [f"{pad}: expected one series resistor, found {series}"]
    _, control = series[0]
    if not any(n == SUPPLY for _, n in _two_pin(board, control)):
        wrong.append(f"{control}: no pull-up to {SUPPLY}, so the short is not "
                     "held released while the FPGA is unconfigured")
    pfet = _fet_by_gate(board, control)
    if pfet is None:
        return wrong + [f"{control}: drives no FET gate"]
    source = next((p.net for p in pfet.pins if p.name.upper() in ("SOURCE", "S")), None)
    drain = next((p.net for p in pfet.pins if p.name.upper() in ("DRAIN", "D")), None)
    if source != SUPPLY:
        wrong.append(f"{pfet.designator}: source on {source}, not {SUPPLY} -- not a "
                     "high-side P-FET that turns on when the output is driven low")
    if pfet.library_reference != "PMOS":
        wrong.append(f"{pfet.designator}: symbol {pfet.library_reference!r}, not PMOS")
    nfet = _fet_by_gate(board, drain) if drain else None
    if nfet is None:
        return wrong + [f"{pfet.designator}: its drain ({drain}) drives no FET gate"]
    gate = next(p.net for p in nfet.pins if p.name.upper() in ("GATE", "G"))
    others = {p.net for p in nfet.pins if p.net != gate}
    if GROUND not in others:
        wrong.append(f"{nfet.designator}: no pin on {GROUND}")
    to_rail = [n for n in others - {GROUND}
               if any(far == rail for _, far in _two_pin(board, n))]
    if not to_rail:
        wrong.append(f"{nfet.designator}: does not reach {rail} through a resistor")
    return wrong


def test_HK_PROT_01_short_outputs_exist(board):
    """VC-HK-0093: one active-low short output per IMX supply, on its pin,
    driven only by the protection logic, and wired to short its rail."""
    top = design.ports()
    pins = {v: design.pin_constraints(v) for v in design.PDC}
    problems = []
    for port, ball, rail in SHORTS:
        if top.get(port) != "output":
            problems.append(f"top.sv: {port} is not an output ({top.get(port)})")
        for variant, assigned in pins.items():
            pin = assigned.get(port)
            if pin is None or pin.ball != ball or pin.direction != "OUTPUT":
                problems.append(f"{variant} pinout: {port} is {pin}, not an output on {ball}")
            elif pin.pull != "UP":
                problems.append(f"{variant} pinout: {port} has no pull-up, so it is not "
                                "held released while the FPGA is unconfigured")
        drivers = design.drivers(port)
        blocks = {(d.file, d.block) for d in drivers}
        if len(blocks) != 1:
            problems.append(f"{port}: driven from {len(blocks)} places, not one: "
                            + "; ".join(map(str, drivers)))
        elif "imx_latchup" not in next(iter(blocks))[1]:
            problems.append(f"{port}: its one driver does not act on imx_latchup, so it "
                            f"is not the protection logic ({drivers[0]})")
        floating = [m for m, how in design.connected_through(port) if how == "neither"]
        if floating:
            problems.append(f"{port}: declared an output but neither driven nor passed "
                            f"on in {floating}")
        problems += [f"{port} on {ball}: {w}" for w in _board_path(board, ball, rail)]
    assert not problems, "\n  ".join(["HK-PROT-01 does not hold as built:"] + problems)
