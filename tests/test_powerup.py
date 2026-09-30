import copy

from boardcheck.checks import ERROR, WARNING, powerup
from helpers import findings, res
from test_fpga_levels import BUF_PART, PF_PART, PINS_OK, _board

FPGA = copy.deepcopy(PF_PART)
FPGA["power_up_io"] = {"states": [{"phase": "power_up", "state": "hiz"},
                                  {"phase": "power_up", "state": "weak_pull_up"},
                                  {"phase": "programming", "state": "weak_pull_up"}]}
FPGA["electrical_characteristics"]["r_weak_pull_up"] = {"kind": "range_table", "unit": "ohm", "rows": [
    {"min": 15000, "max": 24000, "conditions": {"supply_voltage": {"value": 3.3, "unit": "V", "supply": "VDDI"}}}]}

PINS = PINS_OK + 'dict set pins {reg_en} {pin_name "B2" io_std "LVCMOS33" DIRECTION "OUTPUT"}\n'


def _ctx(tmp_path, pull=None, ohms="10k"):
    extra = [pull] if pull else []
    parts = {"MPF": FPGA, "BUF": BUF_PART, "R": {}}
    ctx = _board(tmp_path, PINS, extra=extra, parts=parts)
    ctx.design.part_params.setdefault("R", {})["R_Value"] = ohms
    return ctx


def test_floating_enable_is_an_error(tmp_path):
    ctx = _ctx(tmp_path)          # WIRED (U1.B2 'reg_en' -> U6.2) has no resistor
    f = findings(powerup.floating_controls, ctx)
    assert len(f) == 1 and "'WIRED' from U1.B2 ('reg_en') to U6.2 floats while U1 is high impedance (power up)" \
        in f[0].message and f[0].severity is None
    assert "U6" in f[0].refs


def test_pull_down_against_weak_pull_up_lands_between_thresholds(tmp_path):
    ctx = _ctx(tmp_path, pull=res("R9", "R", "WIRED", "GND"))
    assert findings(powerup.floating_controls, ctx) == []
    f = findings(powerup.undefined_controls, ctx)
    # 3.3 V * 10k / (10k + 15k..24k) = 0.97..1.32 V; U6 (BUF) VIL 0.99 V, VIH 2.31 V at 3.3 V
    assert len(f) == 1 and "undefined at 0.97-1.32 V while U1 is weakly pulled up (power up, programming)" \
        in f[0].message and "receiver data" in f[0].message and f[0].severity == ERROR


def test_strong_pull_down_holds_low_in_every_window(tmp_path):
    ctx = _ctx(tmp_path, pull=res("R9", "R", "WIRED", "GND"), ohms="1k")
    assert findings(powerup.undefined_controls, ctx) == [] and findings(powerup.changing_controls, ctx) == []
    rows = powerup.power_up_summary(ctx)
    assert [r[2] for r in rows] == ["reg_en"] and all(text.startswith("low") for _, text in rows[0][4])


def test_weak_pull_down_loses_to_the_fpga_pull_up(tmp_path):
    # 100k to GND: low while hi-Z, but 3.3 V * 100k / (100k + 15k..24k) = 2.66-2.87 V (high) once the weak pull-up is on
    ctx = _ctx(tmp_path, pull=res("R9", "R", "WIRED", "GND"), ohms="100k")
    f = findings(powerup.changing_controls, ctx)
    assert len(f) == 1 and f[0].severity is None
    assert "low while high impedance (power up); high while weakly pulled up (power up, programming)" in f[0].message
    ctx = _ctx(tmp_path, pull=res("R9", "R", "WIRED", "3V3"))
    assert findings(powerup.changing_controls, ctx) == [], "a pull-up keeps it high in both windows"


def test_unknown_resistor_values(tmp_path):
    ctx = _ctx(tmp_path, pull=res("R9", "R", "WIRED", "GND"), ohms=None)
    assert any("resistor value unknown (R9)" in f.message for f in findings(powerup.unevaluated_controls, ctx))


def test_non_control_ports_and_parts_without_power_up_data_are_skipped(tmp_path):
    ctx = _ctx(tmp_path)
    assert all(ev.port == "reg_en" for ev in powerup.evaluate(ctx)), "out18 / in33 are not control ports"
    ctx = _board(tmp_path, PINS, parts={"MPF": PF_PART, "BUF": BUF_PART})
    assert powerup.evaluate(ctx) == []
