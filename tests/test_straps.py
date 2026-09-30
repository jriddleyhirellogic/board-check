from boardcheck.checks import ERROR, WARNING, straps
from helpers import build_ctx, findings, res

PHY = {
    "pin_functions": {
        "VDDIO": {"direction": "power", "pins": ["1"]},
        "GND": {"direction": "power", "pins": ["2"]},
        "N\\R\\E\\S\\E\\T\\": {"direction": "input", "pins": ["3"], "supply": "VDDIO"},
        "RX_CLK": {"direction": "output", "pins": ["4"], "supply": "VDDIO"},
        "RXD0": {"direction": "output", "pins": ["5"], "supply": "VDDIO"},
        "RXD1": {"direction": "output", "pins": ["6"], "supply": "VDDIO"},
    },
    "electrical_characteristics": {
        "vih": {"kind": "range_table", "unit": "V", "applies_to": ["RX_CLK", "RXD0", "RXD1"], "rows": [{"min": 2.0}]},
        "vil": {"kind": "range_table", "unit": "V", "applies_to": ["RX_CLK", "RXD0", "RXD1"], "rows": [{"max": 0.8}]},
    },
    "straps": {
        "latched_by": {"pin": "N\\R\\E\\S\\E\\T\\", "event": "reset_deassert"},
        "must_not_be_driven": True,
        "fields": [
            {"name": "managed_mode", "bits": [{"pin": "RX_CLK", "bit": 0}], "values": {"0": "managed", "1": "unmanaged"}},
            {"name": "phy_address", "when": {"managed_mode": "0"},
             "bits": [{"pin": "RXD0", "bit": 0}, {"pin": "RXD1", "bit": 1}]},
        ],
    },
}
MCU = {"pin_functions": {"TX": {"direction": "output", "pins": ["1"]}, "RX": {"direction": "input", "pins": ["2"]}}}


def _ctx(extra, parts_extra=None, **values):
    comps = [("U1", "PHY", [("1", "VDDIO", "3V3"), ("2", "GND", "GND"), ("3", "NRESET", "RST_N"),
                            ("4", "RX_CLK", "S_CLK"), ("5", "RXD0", "S_D0"), ("6", "RXD1", "S_D1")])] + extra
    parts = {"PHY": PHY, "MCU": MCU, "R10K": {}, "R1M": {}, **(parts_extra or {})}
    ctx = build_ctx(comps, parts=parts)
    for pn in ("R10K", "R1M"):
        if pn in ctx.design.part_params:
            ctx.design.part_params[pn]["R_Value"] = "10k"
    return ctx


def test_decoded_configuration_and_clean_straps():
    ctx = _ctx([res("R1", "R10K", "S_CLK", "GND"), res("R2", "R10K", "S_D0", "3V3"), res("R3", "R10K", "S_D1", "GND")])
    assert findings(straps.floating_straps, ctx) == [] and findings(straps.undefined_straps, ctx) == []
    f = findings(straps.strapped_configuration, ctx)
    assert f[0].message == "U1 (PHY): managed_mode = 0 (managed); phy_address = 1"


def test_floating_divided_and_driven_straps():
    ctx = _ctx([res("R1", "R10K", "S_CLK", "GND"), res("R2", "R10K", "S_D0", "3V3"), res("R4", "R1M", "S_D0", "GND"),
                ("U2", "MCU", [("1", "TX", "S_CLK")])])
    assert [f.message for f in findings(straps.floating_straps, ctx)] == [
        "U1.6 RXD1 on 'S_D1': nothing sets its level when N\\R\\E\\S\\E\\T\\ releases"]
    und = findings(straps.undefined_straps, ctx)
    assert len(und) == 1 and "RXD0 on 'S_D0' sits at 1.65 V (low <= 0.80 V, high >= 2.00 V)" in und[0].message
    assert und[0].severity == ERROR, "the part data gives the thresholds"
    drv = findings(straps.driven_straps, ctx)
    assert len(drv) == 1 and "RX_CLK on 'S_CLK' is also driven by U2.1" in drv[0].message
    assert "phy_address = ? (not defined (RXD0, RXD1))" in findings(straps.strapped_configuration, ctx)[0].message


def test_fields_outside_their_mode_are_not_reported():
    ctx = _ctx([res("R1", "R10K", "S_CLK", "3V3"), res("R2", "R10K", "S_D0", "3V3"), res("R3", "R10K", "S_D1", "GND")])
    assert findings(straps.strapped_configuration, ctx)[0].message == "U1 (PHY): managed_mode = 1 (unmanaged)"
