from boardcheck.checks import fpga as fio
from helpers import build_ctx, findings

LDO = {"pin_functions": {"IN": {"direction": "power", "function": "SUPPLY", "pins": ["1"]},
                         "OUT": {"direction": "power", "function": "OUTPUT", "pins": ["2"]},
                         "EN": {"direction": "input", "function": "SHDN_N", "pins": ["3"]}},
       "regulator": {"enable_pin": "EN", "input_pins": ["IN"], "output_pins": ["OUT"]}}
PHY = {"pin_functions": {"VIO": {"direction": "power", "function": "POWER", "pins": ["1"]},
                         "VCORE": {"direction": "power", "function": "POWER", "pins": ["2"]},
                         "TXD": {"direction": "input", "function": "TXD", "pins": ["3"], "supply": "VIO"}}}


def _ctx(tmp_path, pull="up", en_net="EN_PHY", phy_vio="3V3_PHY", txd=None):
    pdc = tmp_path / "io.pdc"
    pdc.write_text('set_io {phy_en} -pinname "B1" -iostd "LVCMOS33" -direction "OUTPUT"\n'
                   + (f'set_io {{phy_txd}} -pinname "A1" -iostd "LVCMOS33" {txd}\n' if txd else ""))
    fpga_cfg = {"constraints": [str(pdc)], "bank_pattern": r"GPIO\d+[PN]B(\d+)", "bank_supply": "VDDI{bank}"}
    if pull:
        fpga_cfg["unused_pull"] = pull
    comps = [
        ("U1", "FPGA", [("A1", "GPIO1PB1", "PHY_TXD"), ("B1", "GPIO2PB2", "EN_PHY"),
                        ("V1", "VDDI1", "3V3"), ("V2", "VDDI2", "3V3")]),
        ("U5", "PHY", [("1", "VIO", phy_vio), ("2", "VCORE", "1V0"), ("3", "TXD", "PHY_TXD")]),
        ("U6", "LDO", [("1", "IN", "5V0"), ("2", "OUT", "3V3_PHY"), ("3", "EN", en_net)]),
    ]
    return build_ctx(comps, config={"fpga": {"U1": fpga_cfg}},
                     parts={"LDO": LDO, "PHY": PHY, "FPGA": {"pin_functions": {}}})


def test_switched_rail_from_logic_enable(tmp_path):
    ctx = _ctx(tmp_path)
    (reg, en, drivers) = fio.switched_rails(ctx)["3V3_PHY"]
    assert (reg.designator, en.ref, drivers) == ("U6", "U6.3", ["U1.B1 'phy_en'"])


def test_unused_pull_up_into_switched_supply(tmp_path):
    (f,) = findings(fio.unused_pin_back_power, _ctx(tmp_path))
    assert f.message.startswith("U1: 1 unused pin(s) keep a weak pull-up to 3V3 and reach U5 (PHY) pins supplied "
                                "from '3V3_PHY' (A1 to 3 TXD). U6 switches '3V3_PHY' (enable U6.3 driven by "
                                "U1.B1 'phy_en')")
    assert f.refs == ["U1", "U5", "U6"]


def test_not_reported(tmp_path):
    assert findings(fio.unused_pin_back_power, _ctx(tmp_path, pull=None)) == [], "no stated pull-up"
    assert findings(fio.unused_pin_back_power, _ctx(tmp_path, pull="down")) == []
    assert findings(fio.unused_pin_back_power, _ctx(tmp_path, en_net="5V0")) == [], "enable tied on"
    assert findings(fio.unused_pin_back_power, _ctx(tmp_path, phy_vio="3V3")) == [], "same rail as the bank"


def test_driven_port_into_switched_supply_is_listed(tmp_path):
    ctx = _ctx(tmp_path, txd='-direction "OUTPUT"')
    assert findings(fio.unused_pin_back_power, ctx) == [], "A1 is constrained now"
    (f,) = findings(fio.driven_pin_back_power, ctx)
    assert f.message == ("U1 reaches U5 (PHY), supplied from '3V3_PHY', with 1 port(s): 'phy_txd'. U6 switches "
                         "'3V3_PHY' (enable U6.3 driven by U1.B1 'phy_en'): confirm the FPGA design holds them "
                         "low or high-Z while it is off")
    (f,) = findings(fio.driven_pin_back_power, _ctx(tmp_path, txd='-direction "INPUT" -RES_PULL "UP"'))
    assert "'phy_txd (pull-up)'" in f.message
    assert findings(fio.driven_pin_back_power, _ctx(tmp_path, txd='-direction "INPUT"')) == []
