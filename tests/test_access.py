import csv
import io
import json

from boardcheck import access
from boardcheck.cli import main
from helpers import build_ctx, make_export, res

RX = {"pin_functions": {  # one LVDS receiver channel
    "VCC": {"direction": "power", "function": "POWER", "pins": ["1"]},
    "GND": {"direction": "power", "function": "GROUND", "pins": ["2"]},
    "1A": {"direction": "input", "function": "LVDS_IN_P", "pins": ["3"], "diff_pair": "1B"},
    "1B": {"direction": "input", "function": "LVDS_IN_N", "pins": ["4"]},
    "1Y": {"direction": "output", "function": "RECEIVER_OUT", "pins": ["5"], "io_standard": "LVCMOS"},
}}
SHIFT = {"pin_functions": {  # a level shifter whose channels do not match by key
    "A": {"direction": "input", "function": "BUFFER_IN", "pins": ["1"]},
    "Y1": {"direction": "output", "function": "BUFFER_OUT", "pins": ["2"]},
}}
ESD = {"pin_functions": {
    "IO1": {"direction": "passive", "function": "ESD_IO", "pins": ["1"]},
    "NC": {"direction": "passive", "function": "FLOW_THROUGH", "pins": ["3"]},
    "GND": {"direction": "power", "function": "GROUND", "pins": ["2"]},
}}
MCU = {"pin_functions": {"PA0": {"direction": "input", "function": "GPIO", "pins": ["1"], "io_standard": "LVCMOS33"}}}


def _fpga(tmp_path, ports):
    pdc = tmp_path / "io.pdc"
    pdc.write_text("\n".join(f'set_io {{{p}}} -pinname "{pin}" -iostd "LVCMOS33" -direction "{d}"'
                             for p, pin, d in ports) + "\n")
    return {"constraints": [str(pdc)], "bank_pattern": r"GPIO\d+[PN]B(\d+)", "bank_supply": "VDDI{bank}"}


def _board(tmp_path):
    comps = [
        ("J1", "CONN", [("1", "1", "LINK_P"), ("2", "2", "LINK_N"), ("3", "3", "GND"), ("4", "4", "3V3"),
                        ("5", "5", "SPARE"), ("6", "6", "SHIFTED"), ("7", "7", "AC_IN"), ("8", "8", None)]),
        res("R1", "R100", "LINK_P", "LINK_N"),                         # termination across the pair
        ("U1", "ESD", [("1", "IO1", "LINK_P"), ("3", "NC", "LINK_P"), ("2", "GND", "GND")]),
        ("U2", "RX", [("1", "VCC", "3V3"), ("2", "GND", "GND"), ("3", "1A", "LINK_P"), ("4", "1B", "LINK_N"),
                      ("5", "1Y", "LINK_TTL")]),
        res("R2", "R33", "LINK_TTL", "LINK_FPGA"),
        res("R3", "R10K", "LINK_FPGA", "3V3"),                         # pull-up behind the receiver
        ("U9", "MPF", [("A1", "GPIO1PB2", "LINK_FPGA"), ("A2", "GPIO2PB2", "SPARE_FPGA"),
                       ("V1", "VDDI2", "3V3")]),
        res("R4", "R0", "SPARE", "SPARE_FPGA"),                        # reaches an unconstrained pin
        ("U3", "SHIFT", [("1", "A", "SHIFTED"), ("2", "Y1", "NEVER")]),
        ("C1", "C100N", [("1", "1", "AC_IN"), ("2", "2", "AC_MID")]),
        ("U4", "MCU", [("1", "PA0", "AC_MID")]),
        ("TP1", "TP", [("1", "1", "AC_MID")]),
    ]
    pn = {"R100": {"R_Value": "100"}, "R33": {"R_Value": "33"}, "R10K": {"R_Value": "10k"}, "R0": {"R_Value": "0"},
          "C100N": {"C_Value": "100nF"}}
    return build_ctx(comps, part_numbers=pn, config={"fpga": {"U9": _fpga(tmp_path, [("link_in", "A1", "INPUT")])}},
                     parts={"RX": RX, "SHIFT": SHIFT, "ESD": ESD, "MCU": MCU, "MPF": {"pin_functions": {}}})


def _pins(tmp_path):
    (j1,) = access.connectors(_board(tmp_path))
    return {str(p.pin.designator): p for p in j1.pins}


def test_receiver_crossed_to_fpga_port(tmp_path):
    p = _pins(tmp_path)["1"]
    assert p.kind == "signal" and p.pair == "LINK_N" and p.termination == ["R1 100Ω"]
    assert p.protection == ["U1 ESD"], "an ESD part listed once though two of its pins sit on the net"
    (ep,) = p.reaches
    assert (ep.ref, ep.port, ep.direction, ep.io_standard, ep.bank, ep.bank_voltage) == \
        ("U9.A1", "link_in", "input", "LVCMOS33", "2", 3.3)
    assert ep.path == ["U2 1A→1Y", "R2 33Ω"]
    assert p.ties == ["R3 10kΩ to 3V3 (on LINK_FPGA)"], "a tie behind the buffer names its net"
    n = _pins(tmp_path)["2"]
    assert n.reaches[0].path == ["U2 1B→1Y", "R2 33Ω"], "the N input reaches the same output"


def test_power_ground_and_unconnected(tmp_path):
    p = _pins(tmp_path)
    assert p["3"].kind == "ground"
    assert (p["4"].kind, p["4"].voltage) == ("supply", 3.3)
    assert p["8"].kind == "not connected"


def test_unassigned_fpga_pin(tmp_path):
    (ep,) = _pins(tmp_path)["5"].reaches
    assert ep.ref == "U9.A2" and ep.port is None and ep.note == "no port assigned" and ep.is_fpga
    assert ep.path == ["R4 0Ω"]


def test_unknown_channel_mapping_stops(tmp_path):
    p = _pins(tmp_path)["6"]
    assert p.reaches == []
    assert p.stops == ["U3.1 A (SHIFT): channel mapping unknown, not crossed"]


def test_series_capacitor_then_first_active_part(tmp_path):
    p = _pins(tmp_path)["7"]
    refs = {e.ref: e for e in p.reaches}
    assert set(refs) == {"U4.1", "TP1.1"}
    assert refs["U4.1"].path == ["C1 100nF"] and refs["U4.1"].function == "GPIO"
    assert refs["TP1.1"].note == "test point"


def test_channel_digits():
    assert [access._channel(k) for k in ("1A", "1Y", "1A1", "1Y1", "A", "R")] == ["1", "1", "11", "11", "", ""]


def test_outputs(tmp_path):
    found = access.connectors(_board(tmp_path))
    md = access.markdown(found)
    assert "## J1 (CONN)" in md and "port link_in" in md and "Mates" not in md
    rows = list(csv.DictReader(io.StringIO(access.as_csv(found))))
    row = next(r for r in rows if r["pin"] == "1")
    assert (row["fpga_pin"], row["fpga_port"], row["fpga_bank_voltage"]) == ("U9.A1", "link_in", "3.3")
    data = json.loads(access.as_json(found))
    assert data[0]["pins"][0]["reaches"][0]["port"] == "link_in"


def test_cli_on_system_board_shows_mates(tmp_path):
    for name, net in (("A", "SIG"), ("B", "SIG_B")):
        d = tmp_path / name
        d.mkdir()
        (d / "x.json").write_text(json.dumps(make_export([("J1", "CONN", [("1", "1", net), ("2", "2", "GND")]),
                                                          res("R1", "R1K", net, "GND")])))
    (tmp_path / "sys.yaml").write_text("boards:\n  A: {export: A/x.json}\n  B: {export: B/x.json}\n"
                                       "links:\n  - {name: l, a: 'A:J1', b: 'B:J1', map: pins}\n")
    out = tmp_path / "a.md"
    assert main(["access", "--system", str(tmp_path / "sys.yaml"), "--board", "A", "--no-partsdb",
                 "-o", str(out)]) == 0
    text = out.read_text()
    assert "# A connector access" in text and "B:J1.1 SIG_B" in text and "R1 to GND" in text
