from boardcheck.checks import ERROR, WARNING, fpga as fio
from helpers import build_ctx, findings

SYMBOL = [("A1", "HSIO10PB1", "CK_P"), ("A2", "HSIO10NB1", "CK_N"),
          ("B1", "HSIO11PB1", "DQS_P"), ("B2", "HSIO11NB1", "DQS_N"),
          ("C1", "HSIO12PB1", "X1"), ("C2", "HSIO12NB1", "X2"),
          ("R1", "XCVR_0A_REFCLK_P", "REF_P"), ("R2", "XCVR_0A_REFCLK_N", "REF_N"),
          ("X1", "XCVR_0_RX0_P", "RX_P"), ("X2", "XCVR_0_RX0_N", "RX_N"),
          ("T1", "XCVR_0_TX0_P", "TX_P"), ("T2", "XCVR_0_TX0_N", "TX_N"),
          ("G1", "GPIO5PB2", "PLAIN")]


def _ctx(tmp_path, pins_tcl, top=None):
    names = [line.split("{")[1].split("}")[0] for line in pins_tcl.splitlines() if line.strip()]
    (tmp_path / "pins.tcl").write_text(pins_tcl)
    (tmp_path / "io.pdc").write_text(
        'source [file join [file dirname [info script]] "pins.tcl"]\nset ports {}\n'
        + "".join(f"lappend ports [list {{{n}}} {{{n}}}]\n" for n in names)
        + "apply_pin_constraints $ports $pins\n")
    cfg = {"constraints": [str(tmp_path / "io.pdc")],
           "pair_patterns": [r"^(?:GPIO|HSIO)(?P<pair>\d+)(?P<pol>[PN])B\d+", r"^(?P<pair>XCVR_\w+?)_(?P<pol>[PN])$"],
           "transceiver_pattern": r"^XCVR_(?P<quad>\d+)[A-Z]?_(?P<role>RX|TX|REFCLK)"}
    if top:
        (tmp_path / "top.tcl").write_text(top)
        cfg["top_level"] = [str(tmp_path / "top.tcl")]
    others = [("J1", "CONN", [(str(i), str(i), net) for i, (_, _, net) in enumerate(SYMBOL, 1)])]
    return build_ctx([("U1", "FPGA", SYMBOL)] + others, config={"fpga": {"U1": cfg}})


def pin(port, ball, direction="OUTPUT"):
    return f'dict set pins {{{port}}} {{pin_name "{ball}" DIRECTION "{direction}"}}\n'


def test_good_pairs_pass(tmp_path):
    ctx = _ctx(tmp_path, pin("ck0", "A1") + pin("ck0_n", "A2") + pin("dqs[0]", "B1", "INOUT")
               + pin("dqs_n[0]", "B2", "INOUT") + pin("reset_n", "G1"))
    pairs, halves = fio.diff_port_pairs(ctx, ctx.fpga_for(ctx.design.components["U1"]))
    assert pairs == [("ck0", "ck0_n"), ("dqs[0]", "dqs_n[0]")] and halves == [], "reset_n alone is active-low, not half a pair"
    assert findings(fio.diff_pair_balls, ctx) == [] and findings(fio.diff_pair_nets, ctx) == []


def test_swapped_split_and_single_ended_balls(tmp_path):
    ctx = _ctx(tmp_path, pin("a_p", "A2") + pin("a_n", "A1")          # swapped
               + pin("b_p", "B1") + pin("b_n", "C2")                   # different pairs
               + pin("c_p", "G1") + pin("c_n", "C1")                   # G1 has a pair, C1 too, but different
               + pin("lone_p", "C1"))
    msgs = [f.message for f in findings(fio.diff_pair_balls, ctx)]
    assert any("'a_p' on A2" in m and "swapped on pair 10" in m for m in msgs)
    assert any("'b_p' on B1" in m and "different pairs (11P and 12N)" in m for m in msgs)
    assert any("'lone_p' is constrained but its partner 'lone_n' is not" in m for m in msgs)


def test_board_crossing_the_pair(tmp_path):
    ctx = _ctx(tmp_path, pin("ck_p", "A1") + pin("ck_n", "A2"))
    ctx.design.components["U1"].pins[0].net, ctx.design.components["U1"].pins[1].net = "CK_N", "CK_P"
    f = findings(fio.diff_pair_nets, ctx)
    assert len(f) == 1 and "'ck_p' (A1) is on 'CK_N'" in f[0].message and f[0].severity is None


def test_reference_clocks_and_lane_directions(tmp_path):
    top = """\
sd_create_scalar_port -sd_name x -port_name {refclk_p} -port_direction {IN}
sd_create_scalar_port -sd_name x -port_name {refclk_n} -port_direction {IN}
sd_create_scalar_port -sd_name x -port_name {sysclk_p} -port_direction {IN}
sd_create_scalar_port -sd_name x -port_name {sysclk_n} -port_direction {IN}
sd_create_scalar_port -sd_name x -port_name {rx_p} -port_direction {OUT}
sd_create_scalar_port -sd_name x -port_name {tx_p} -port_direction {OUT}
sd_connect_pins -sd_name x -pin_names {"ref_inst:REF_CLK_PAD_P" "refclk_p" }
sd_connect_pins -sd_name x -pin_names {"refclk_n" "ref_inst:REF_CLK_PAD_N" }
sd_connect_pins -sd_name x -pin_names {"sysclk_p" "ccc_inst:CLK_P" }
"""
    ctx = _ctx(tmp_path, pin("refclk_p", "C1") + pin("refclk_n", "C2") + pin("sysclk_p", "R1")
               + pin("sysclk_n", "R2") + pin("rx_p", "X1") + pin("tx_p", "T1"), top=top)
    f = findings(fio.transceiver_pins, ctx)
    msgs = {x.message: x.severity for x in f}
    assert any("C1 (HSIO12PB1) carries 'refclk_p', a transceiver reference clock, but it is not a REFCLK pin" in m
               for m in msgs)
    assert any("R1 (XCVR_0A_REFCLK_P) carries 'sysclk_p', which is not connected" in m and s == WARNING
               for m, s in msgs.items())
    assert any("X1 (XCVR_0_RX0_P) carries 'rx_p' (output) on a transceiver RX pin" in m for m in msgs)
    assert not any("'tx_p'" in m for m in msgs)


def test_reference_clocks_by_name_without_smartdesign(tmp_path):
    ctx = _ctx(tmp_path, pin("aux_ref_clk_p", "G1", "INPUT"))
    assert any("'aux_ref_clk_p', a transceiver reference clock" in f.message
               for f in findings(fio.transceiver_pins, ctx))


def test_quad_reference_clock_reach(tmp_path):
    from boardcheck.checks import INFO
    from helpers import FakePartsDB
    symbol = [("R1", "XCVR_4A_REFCLK_P", "REF_P"), ("R2", "XCVR_4A_REFCLK_N", "REF_N"),
              ("A1", "XCVR_4_RX0_P", "A_P"), ("A2", "XCVR_4_RX0_N", "A_N"),
              ("B1", "XCVR_2_RX0_P", "B_P"), ("B2", "XCVR_2_RX0_N", "B_N"),
              ("C1", "XCVR_5_RX0_P", "C_P"), ("C2", "XCVR_5_RX0_N", "C_N")]
    pins_tcl = "".join(pin(p, b, "INPUT") for p, b in [("refclk_p", "R1"), ("refclk_n", "R2"), ("a_p", "A1"),
                                                         ("a_n", "A2"), ("b_p", "B1"), ("b_n", "B2")])
    ctx = _ctx(tmp_path, pins_tcl)
    ctx.design.components["U1"].pins[:] = []
    from boardcheck.model import Pin
    for ball, name, net in symbol:
        ctx.design.components["U1"].pins.append(Pin(ball, name, net, ctx.design.components["U1"]))
    ctx.partsdb = FakePartsDB({"FPGA": {"transceivers": {"quads_top_to_bottom": ["4", "2", "0", "1", "3", "5"],
                                                         "refclk_cascade": "down"}}})
    f = findings(fio.quad_reference_clocks, ctx)
    assert len(f) == 1 and f[0].severity == INFO and "quad 2" in f[0].message and "cascade from quad 4" in f[0].message
    # Without a downward cascade, quad 2 has no reference clock it can reach.
    ctx.partsdb = FakePartsDB({"FPGA": {"transceivers": {"quads_top_to_bottom": ["4", "2"], "refclk_cascade": "none"}}})
    f = findings(fio.quad_reference_clocks, ctx)
    assert len(f) == 1 and f[0].severity is None and "quad 2" in f[0].message and "fabric CDR" in f[0].message
