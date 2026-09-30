from boardcheck.checks import levels
from helpers import build_ctx, findings, res


def _rt(applies, rows, unit="V"):
    return {"kind": "range_table", "unit": unit, "applies_to": applies, "rows": rows}


AMP = {"pin_functions": {"OUT": {"direction": "output", "pins": ["1"], "supply": "VCC", "io_standard": "analog"},
                         "VCC": {"direction": "power", "pins": ["2"]}},
       "electrical_characteristics": {"voh": _rt(["OUT"], [{"min": "VCC-0.2"}])}}
ADC_INS = [f"IN{i}" for i in range(3)]
ADC = {"pin_functions": dict({k: {"direction": "input", "pins": [str(3 + i)], "supply": "VA", "io_standard": "analog"}
                              for i, k in enumerate(ADC_INS)}, VA={"direction": "power", "pins": ["1"]}),
       "electrical_characteristics": {
           "vi_abs": _rt(ADC_INS, [{"min": -0.3, "max": "VA+0.3"}]),
           "ii_clamp": _rt(ADC_INS, [{"min": -0.01, "max": 0.01}], "A"),
           "ii_clamp_package": {"kind": "range_table", "unit": "A", "rows": [{"min": -0.02, "max": 0.02}]}}}


def _ctx(series=("1k", "1k", "1k")):
    comps = [("U9", "ADC", [("1", "VA", "3V3")] + [(str(3 + i), f"IN{i}", f"S{i}_ADC") for i in range(3)])]
    values = {}
    for i, r in enumerate(series):
        comps.append((f"U{i + 1}", "AMP", [("1", "OUT", f"S{i}"), ("2", "VCC", "10V0")]))
        if r:
            comps.append(res(f"R{i + 1}", f"R{r}", f"S{i}", f"S{i}_ADC"))
            values[f"R{r}"] = r
        else:
            comps[-1] = (f"U{i + 1}", "AMP", [("1", "OUT", f"S{i}_ADC"), ("2", "VCC", "10V0")])
    ctx = build_ctx(comps, parts={"AMP": AMP, "ADC": ADC})
    for pn, v in values.items():
        ctx.design.part_params[pn]["R_Value"] = v
    return ctx


def test_series_resistor_holds_clamp_current_within_rating():
    # 10 V through 1k into a 3.6 V limit: 6.4 mA each (within 10 mA); three at once: 19.2 mA (within 20 mA)
    fs = findings(levels.input_overvoltage, _ctx())
    assert len(fs) == 3 and all(f.severity == "warning" for f in fs)
    assert "U9.3 IN0 3.6 V through 1000 ohm: 6.4 mA of clamp current, within its 10 mA rating" in fs[0].message


def test_clamp_current_over_rating_and_package_total():
    fs = findings(levels.input_overvoltage, _ctx(series=("470", "1k", "")))
    msgs = {f.message: f.severity for f in fs}
    over = [m for m in msgs if "S0" in m][0]
    assert msgs[over] != "warning" and "(14 mA through 470 ohm, above its 10 mA clamp rating)" in over
    direct = [m for m in msgs if "S2_ADC" in m][0]
    assert "ohm" not in direct and msgs[direct] != "warning"
    # only one clamped input left: no package finding
    assert not any("package rating" in m for m in msgs)
    fs = findings(levels.input_overvoltage, _ctx(series=("620", "620", "620")))
    # 6.4 V / 620 = 10.3 mA: over the per-pin rating, so none are clamped-within-rating
    assert all(f.severity != "warning" for f in fs)
    fs = findings(levels.input_overvoltage, _ctx(series=("820", "820", "820")))
    pkg = [f for f in fs if "package rating" in f.message]
    assert len(pkg) == 1 and pkg[0].message == ("U9 (ADC): 3 inputs can be driven beyond its supplies at once through "
                                                "current-limiting resistors, 23.4 mA in total, above the 20 mA package "
                                                "rating")
