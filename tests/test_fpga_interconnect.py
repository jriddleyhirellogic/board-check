from boardcheck.checks import WARNING, fpga as fio, pins
from helpers import build_ctx, findings, res


def _two_fpgas(tmp_path, a_ports, b_ports):
    """a_ports / b_ports: [(port, ball, direction)] for FPGAs U1 and U2; balls
    A1..A4 on U1 and B1..B4 on U2 are wired pairwise to nets L1..L4 (U1 side
    through 33 ohm resistors)."""
    for name, ports in (("a", a_ports), ("b", b_ports)):
        (tmp_path / f"{name}.pdc").write_text("".join(
            f'set_io {{{p}}} -pinname "{ball}" -iostd "LVCMOS33" -direction "{d}"\n' for p, ball, d in ports))
    comps = [("U1", "FA", [(f"A{i}", f"GPIO{i}PB2", f"R_L{i}") for i in range(1, 5)]),
             ("U2", "FB", [(f"B{i}", f"IO{i}PDB1V0", f"L{i}") for i in range(1, 5)])]
    comps += [res(f"R{i}", "R33", f"R_L{i}", f"L{i}") for i in range(1, 5)]
    cfg = {"fpga": {"U1": {"constraints": [str(tmp_path / "a.pdc")]}, "U2": {"constraints": [str(tmp_path / "b.pdc")]}}}
    ctx = build_ctx(comps, config=cfg)
    ctx.design.part_params["R33"]["R_Value"] = "33"
    return ctx


def test_interconnect_directions(tmp_path):
    ctx = _two_fpgas(tmp_path,
                     [("a_en", "A1", "OUTPUT"), ("a_st", "A2", "INPUT"), ("a_x", "A3", "INPUT"), ("a_y", "A4", "OUTPUT")],
                     [("b_en", "B1", "OUTPUT"), ("b_st", "B2", "OUTPUT"), ("b_x", "B3", "INPUT")])
    f = {x.message.split("'")[1]: x for x in findings(fio.fpga_interconnect, ctx)}
    assert "both FPGAs drive it" in f["L1 (+R_L1)"].message and f["L1 (+R_L1)"].severity is None
    assert "L2 (+R_L2)" not in f
    assert "no FPGA drives it" in f["L3 (+R_L3)"].message and f["L3 (+R_L3)"].severity == WARNING
    assert "U2 B4 (unconstrained)" in f["L4 (+R_L4)"].message
    contention = findings(pins.contention, ctx)
    assert len(contention) == 1 and "through series resistors" in contention[0].message


def test_bus_bits_must_meet_their_namesake(tmp_path):
    ctx = _two_fpgas(tmp_path,
                     [("pa3_fw_version[0]", "A1", "INPUT"), ("pa3_fw_version[1]", "A2", "INPUT")],
                     [("fw_version[1]", "B1", "OUTPUT"), ("fw_version[0]", "B2", "OUTPUT")])
    msgs = sorted(x.message for x in findings(fio.fpga_bus_alignment, ctx))
    assert any("U1 'pa3_fw_version[0]' is wired to U2 'fw_version[1]' on 'L1 (+R_L1)', not to U2 'fw_version[0]' "
               "(which is on 'L2 (+R_L2)')" in m for m in msgs)
    ctx = _two_fpgas(tmp_path,
                     [("pa3_fw_version[0]", "A1", "INPUT"), ("pa3_fw_version[1]", "A2", "INPUT")],
                     [("fw_version[0]", "B1", "OUTPUT"), ("fw_version[1]", "B2", "OUTPUT")])
    assert findings(fio.fpga_bus_alignment, ctx) == []


def test_split_output_pins_are_one_driver():
    part = {"pin_functions": {"AOUT1": {"direction": "output", "pins": ["4", "5"]}}}
    ctx = build_ctx([("U81", "DRV", [("4", "AOUT1", "COIL"), ("5", "AOUT1", "COIL")]), ("M1", "MOTOR", [("1", "1", "COIL")])],
                    parts={"DRV": part})
    assert findings(pins.contention, ctx) == []
