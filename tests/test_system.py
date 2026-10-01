import json

from boardcheck.system import System, run_system
from helpers import make_export


def _board(tmp_path, name, comps, cfg=""):
    d = tmp_path / name
    d.mkdir()
    (d / "x.json").write_text(json.dumps(make_export(comps)))
    (d / "boardcheck.yaml").write_text(cfg)
    return {"export": f"{name}/x.json", "config": f"{name}/boardcheck.yaml"}


def _system(tmp_path, a_conn, b_conn, a_extra=(), b_extra=(), mapping="pins"):
    boards = {"A": _board(tmp_path, "A", [("J1", "CONN", a_conn)] + list(a_extra)),
              "B": _board(tmp_path, "B", [("P1", "CONN", b_conn)] + list(b_extra))}
    import yaml
    (tmp_path / "sys.yaml").write_text(yaml.safe_dump({
        "boards": boards, "links": [{"name": "L", "a": "A:J1", "b": "B:P1", "map": mapping}]}))
    return System.load(str(tmp_path / "sys.yaml"))


def _by(found, check):
    return [f for f in found if f.check == check]


def test_open_ground_rail_and_polarity(tmp_path):
    a = [("1", "1", "GND"), ("2", "2", "3V3"), ("3", "3", "SIG_P"), ("4", "4", "CLK_EN")]
    b = [("1", "1", "SIG_A"), ("2", "2", "5V0"), ("3", "3", "SIG_N"), ("4", "4", "NetP1_4")]
    a_extra = [("U1", "X", [("1", "A", "SIG_P"), ("2", "B", "CLK_EN")]), ("C1", "C", [("1", "1", "3V3"), ("2", "2", "GND")])]
    b_extra = [("U2", "Y", [("1", "A", "SIG_N"), ("2", "B", "SIG_A")]), ("C2", "C", [("1", "1", "5V0"), ("2", "2", "GND")])]
    found = run_system(_system(tmp_path, a, b, a_extra, b_extra))
    (o,) = _by(found, "SYS001")
    assert o.message == "L: A J1.4 'CLK_EN' reaches B P1.4 'NetP1_4', which is connected to nothing on that board"
    msgs = sorted(f.message for f in _by(found, "SYS002"))
    assert msgs == ["L: A J1.1 'GND' <-> B P1.1 'SIG_A': ground meets a signal",
                    "L: A J1.2 '3V3' <-> B P1.2 '5V0': a 3.3 V rail meets a 5 V rail"]
    (p,) = _by(found, "SYS003")
    assert "A J1.3 'SIG_P' (+) <-> B P1.3 'SIG_N' (-)" in p.message
    assert "4 pins paired" in _by(found, "SYS006")[0].message


def test_harness_paired_by_name(tmp_path):
    a = [("1", "1", "ETH_MX1_P"), ("2", "2", "ETH_MX1_N"), ("3", "3", "CHAS")]
    b = [("7", "7", "BP_TX1_N"), ("8", "8", "BP_TX1_P"), ("9", "9", "LED")]
    s = _system(tmp_path, a, b, mapping={"by": "name", "a": r"ETH_MX(\d)_([PN])$", "b": r"BP_TX(\d)_([PN])$"})
    assert [(x.designator, y.designator) for x, y in s.links[0].pairs] == [("1", "8"), ("2", "7")]
    assert not _by(run_system(s), "SYS003")


def test_contention_across_boards(tmp_path):
    a = [("1", "1", "SIG")]
    b = [("1", "1", "SIG2")]
    a_extra = [("U1", "X", [("1", "O", "SIG", "output")])]
    b_extra = [("U2", "Y", [("1", "O", "SIG2", "output")])]
    (c,) = _by(run_system(_system(tmp_path, a, b, a_extra, b_extra)), "SYS004")
    assert "driven from both boards (A U1.1; B U2.1)" in c.message
