from boardcheck.checks import opamps
from helpers import build_ctx, findings, res


def _rt(applies, rows, **extra):
    return dict({"kind": "range_table", "unit": "V", "applies_to": applies, "rows": rows}, **extra)


OPAMP = {
    "pin_functions": {
        "OUT A": {"direction": "output", "function": "OPAMP_OUT", "pins": ["1"], "supply": "VCC", "io_standard": "analog"},
        "-IN A": {"direction": "input", "function": "OPAMP_IN_N", "pins": ["2"], "supply": "VCC", "io_standard": "analog"},
        "+IN A": {"direction": "input", "function": "OPAMP_IN_P", "pins": ["3"], "supply": "VCC", "io_standard": "analog"},
        "VCC": {"direction": "power", "pins": ["4"]},
        "VEE": {"direction": "power", "pins": ["5"]},
    },
    "electrical_characteristics": {
        "vi_abs": _rt(["-IN A", "+IN A"], [{"min": "VEE-0.5", "max": "VCC+0.5"}]),
        "vi_op": _rt(["-IN A", "+IN A"], [{"min": "VEE-0.1", "max": "VCC-3.5"}]),
        "voh": _rt(["OUT A"], [{"min": "VCC-0.2", "conditions": {"load_resistance": {"min": 10000}}},
                               {"min": "VCC-0.35", "conditions": {"load_resistance": {"min": 2000}}}]),
        "vol": _rt(["OUT A"], [{"max": "VEE+0.2", "conditions": {"load_resistance": {"min": 10000}}},
                               {"max": "VEE+0.35", "conditions": {"load_resistance": {"min": 2000}}}]),
    },
}

COMP = {
    "pin_functions": dict(
        {f"IN{n}{s}": {"direction": "input", "function": f"COMPARATOR_IN_{'P' if s == '+' else 'N'}",
                       "pins": [str(p)], "supply": "VCC", "io_standard": "analog"}
         for n, s, p in ((1, "-", 4), (1, "+", 5), (2, "-", 6), (2, "+", 7))},
        OUT1={"direction": "open_drain", "function": "COMPARATOR_OUT", "pins": ["2"], "supply": "VCC"},
        OUT2={"direction": "open_drain", "function": "COMPARATOR_OUT", "pins": ["1"], "supply": "VCC"},
        VCC={"direction": "power", "pins": ["3"]}, VEE={"direction": "power", "pins": ["12"]}),
    "electrical_characteristics": {
        "vi_abs": _rt(["IN1-", "IN1+", "IN2-", "IN2+"], [{"min": "VEE-0.3", "max": "VEE+6"}]),
        "vi_op": _rt(["IN1-", "IN1+", "IN2-", "IN2+"], [{"min": "VEE-0.2", "max": "VCC-1.5"}], either_input=True),
    },
}
VALUES = {f"R{v}": {"Part Number": f"R{v}", "R_Value": v} for v in ("1k", "2k7", "10k", "100k", "1M")}


def _ctx(comps):
    return build_ctx(comps, part_numbers=dict(VALUES), parts={"OPA": OPAMP, "CMP": COMP})


def _buffer(top, bottom, supply="5V0"):
    """Voltage follower U1 whose + input is a divider from 3V3."""
    return [res("R101", f"R{top}", "3V3", "DIV"), res("R102", f"R{bottom}", "DIV", "GND"),
            ("U1", "OPA", [("1", "OUT A", "BUF"), ("2", "-IN A", "BUF"), ("3", "+IN A", "DIV"),
                           ("4", "+", supply), ("5", "-", "GND")]),
            res("R103", "R100k", "BUF", "GND")]


def test_opamp_input_above_common_mode_range():
    # 10k / 10k from 3.3 V: 1.65 V on +IN, above VCC - 3.5 = 1.5 V on a 5 V supply
    ctx = _ctx(_buffer("10k", "10k"))
    (f,) = findings(opamps.input_range, ctx)
    assert f.message == ("U1 channel A: -IN A on 'BUF' at 1.65 V and +IN A on 'DIV' at 1.65 V are both outside its "
                         "common-mode range (-0.1 to 1.5 V) at the nominal operating point")
    ctx = _ctx(_buffer("10k", "10k", supply="10V0"))
    assert findings(opamps.input_range, ctx) == []


def test_opamp_output_beyond_swing_uses_the_load():
    # 100k / 1k from 3.3 V: 32.7 mV at the output, below VEE + 0.2 with a light (100k) load
    ctx = _ctx(_buffer("100k", "1k", supply="10V0"))
    (f,) = findings(opamps.output_swing, ctx)
    assert "U1.1 OUT A on 'BUF' sits at 0.0327 V" in f.message
    assert "below the lowest level it is guaranteed to reach (0.2 V, RL >= 10 kOhm" in f.message


def _comparator(in1_minus, in1_plus, extra=()):
    return [("U2", "CMP", [("4", "-IN A", in1_minus), ("5", "+IN A", in1_plus), ("2", "OUT A", "FLAG"),
                           ("6", "-IN B", "GND"), ("7", "+IN B", "3V3"), ("1", "OUT B", "SPARE"),
                           ("3", "+", "3V3"), ("12", "-", "GND")]),
            res("R110", "R10k", "FLAG", "3V3")] + list(extra)


def test_comparator_needs_one_input_in_range():
    # Unused channel B: -IN at ground (in range), +IN at V+ (above): fine for either_input parts.
    # Channel A: threshold 2k7 / 10k from 3.3 V = 2.6 V, signal 2V9_SNS = 2.9 V; both above 1.8 V.
    ctx = _ctx(_comparator("THR", "2V9_SNS", [res("R111", "R2k7", "3V3", "THR"), res("R112", "R10k", "THR", "GND")]))
    (f,) = findings(opamps.input_range, ctx)
    assert f.severity is None or f.severity == "error"
    assert f.message == ("U2 channel 1: IN1- on 'THR' at 2.6 V and IN1+ on '2V9_SNS' at 2.9 V are both outside its "
                         "common-mode range (-0.2 to 1.8 V) at the nominal operating point, so the comparator's "
                         "output is indeterminate")
    # A threshold within range makes the comparison valid again.
    ctx = _ctx(_comparator("THR", "2V9_SNS", [res("R111", "R10k", "3V3", "THR"), res("R112", "R10k", "THR", "GND")]))
    assert findings(opamps.input_range, ctx) == []


def test_comparator_other_input_unknown_is_a_warning_and_reported():
    drv = ("U3", "DRV", [("1", "Y", "SIG", "Output")])
    ctx = _ctx(_comparator("THR", "SIG", [res("R111", "R2k7", "3V3", "THR"), res("R112", "R10k", "THR", "GND"), drv]))
    (f,) = findings(opamps.input_range, ctx)
    assert f.severity == "warning" and "the output is correct only while IN1+ is within range" in f.message
    (n,) = findings(opamps.not_evaluated, ctx)
    assert n.message == "U2: IN1+ on 'SIG': also driven by U3.1"
