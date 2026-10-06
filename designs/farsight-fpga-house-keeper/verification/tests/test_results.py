"""The app's model reads back what a run leaves behind. No simulation.

`fsverif.results` joins JUnit results, the per-module log kept by
`fsverif.runlog`, items, requirements and findings; `fsverif.codecov` reads
what `make code-coverage` wrote. The pieces they parse themselves are checked
here against synthetic input, because a quiet break in any of them empties the
app of exactly what it exists to show, and nothing else would go red. The
last test loads the repository's own documents, which is what the app does.
"""

from __future__ import annotations

import logging
import sys
from pathlib import Path

VERIF = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(VERIF))

from fsverif import codecov  # noqa: E402
from fsverif import results as report  # noqa: E402
from check_results import KNOWN, PASSED, REGRESSION, STALE, classify  # noqa: E402
from fsverif import jama  # noqa: E402
from fsverif import runlog  # noqa: E402
from fsverif.evidence import Item  # noqa: E402

JUNIT = """<?xml version='1.0' encoding='utf-8'?>
<testsuites><testsuite name="test_hk_x">
<testcase classname="test_hk_x" name="test_HK_A_01_passes" time="1"/>
<testcase classname="test_hk_x" name="test_HK_A_02_fails" time="1">
<failure message="the thing was 3, not 7&#10;assert 3 == 7" type="AssertionError">trace</failure>
</testcase>
</testsuite></testsuites>
"""


def _item(test, expect_fail=False):
    return Item(id="VC-%s" % test[-5:], verifies=["HK-A-01"], method="SIM",
                artifact="verification/tests/test_hk_x.py::%s" % test,
                expect_fail=expect_fail, blocked=False)


def _write_log(path: Path, monkeypatch) -> None:
    """Write a log through `runlog` itself, so the format under test is the
    one a run produces rather than a copy of it."""
    import cocotb.utils
    monkeypatch.setattr(cocotb.utils, "get_sim_time", lambda unit: 1234.5)
    monkeypatch.setenv(runlog.ENV, str(path))
    root = logging.getLogger()
    before = list(root.handlers)
    runlog.install()
    added = [h for h in root.handlers if h not in before]
    try:
        regression, tb = (logging.getLogger("cocotb.regression"),
                          logging.getLogger("cocotb.tb_top"))
        for logger in (regression, tb):
            logger.setLevel(logging.INFO)
        regression.info("running test_hk_x.test_HK_A_01_passes (1/2)\n"
                        "    docstring line")
        tb.info("measured 5.13 us")
        regression.info("test_hk_x.test_HK_A_01_passes passed")
        regression.info("running test_hk_x.test_HK_A_02_fails (2/2)")
        tb.info("first line\nsecond line")
        regression.warning("test_hk_x.test_HK_A_02_fails failed")
    finally:
        for handler in added:
            root.removeHandler(handler)
            handler.close()


def test_the_log_is_read_back_per_test(tmp_path, monkeypatch):
    log = tmp_path / "log-test_hk_x.txt"
    _write_log(log, monkeypatch)
    lines = report.logged(tmp_path)
    assert lines[("test_hk_x", "test_HK_A_01_passes")] == ["measured 5.13 us"], (
        "a passing test's logged measurement was not attributed to it, so the "
        "report would show a pass with nothing behind it")
    assert lines[("test_hk_x", "test_HK_A_02_fails")] == ["first line\nsecond line"], (
        "a multi-line message was split or lost")


def test_failure_messages_are_unescaped(tmp_path):
    (tmp_path / "results-test_hk_x.xml").write_text(JUNIT, encoding="utf-8")
    messages = report.failure_messages(tmp_path)
    assert messages == {("test_hk_x", "test_HK_A_02_fails"):
                        "the thing was 3, not 7\nassert 3 == 7"}


def test_verdicts_match_the_gate():
    """The report groups by the gate's verdict, from the gate's own code."""
    results = {("test_hk_x", "test_HK_A_01_passes"): "passed",
               ("test_hk_x", "test_HK_A_02_fails"): "failed",
               ("test_hk_x", "test_HK_A_03_fixed"): "passed",
               ("test_hk_x", "test_HK_A_04_new"): "failed"}
    items = {("test_hk_x", t): [_item(t, e)] for t, e in (
        ("test_HK_A_01_passes", False), ("test_HK_A_02_fails", True),
        ("test_HK_A_03_fixed", True), ("test_HK_A_04_new", False))}
    got = {key[1]: v for key, _, v in classify(items, results)}
    assert got == {"test_HK_A_01_passes": PASSED, "test_HK_A_02_fails": KNOWN,
                   "test_HK_A_03_fixed": STALE, "test_HK_A_04_new": REGRESSION}


def test_the_documents_load_whole():
    """Every requirement, finding and item the app will show, from the repo."""
    run = report.load(results_dir=Path("/nonexistent"))
    assert len(run.requirements) > 90 and len(run.findings) > 25
    assert all(run.requirement_text.get(r) for r in run.requirements), (
        "a requirement has no entry text, so its detail pane would be empty")
    assert set(run.finding_text) == set(run.findings), (
        "the findings summary and the finding sections disagree: %s"
        % sorted(set(run.finding_text) ^ set(run.findings)))
    assert all(t.verdict == report.NOT_RUN for t in run.tests)


def test_every_jama_requirement_is_traced():
    """Each Jama requirement in the snapshot has a housekeeper requirement under
    it, or a note saying why not; and every parent a requirement cites is in
    the snapshot, so a typo in a Parent line cannot quietly drop a trace."""
    run = report.load(results_dir=Path("/nonexistent"))
    assert run.jama, "docs/requirements/jama.yaml is missing or empty"
    assert not run.uncited_parents, (
        "requirements cite Jama ids the snapshot does not hold (a typo, or "
        "refresh it with `python -m fsverif.jama --csv`): %s" % run.uncited_parents)
    bare = [j for j, r in run.jama.items() if not run.children(j) and not r.note]
    assert not bare, "no housekeeper requirement under these, and no note why: %s" % bare
    l4 = [j for j in run.jama if jama.HOUSEKEEPER.fullmatch(j)]
    assert len(l4) >= 29 and all(run.children(j) for j in l4), (
        "a FAR-PM_FPGA L4 requirement has no housekeeper requirement under it")
    assert not [j for j, r in run.jama.items() if "?" in r.text], "a mangled symbol"


def test_trace_rolls_up_the_worst_stage():
    run = report.load(results_dir=Path("/nonexistent"))
    run.parents = {"HK-A": ["J-1"], "HK-B": ["J-1"], "HK-C": ["J-2"]}
    run.requirements = {k: None for k in run.parents}
    run.stages = {"HK-A": "passing", "HK-B": "known shortfall", "HK-C": "not written"}
    assert run.trace("J-1") == (report.TRACE_FAILING, {"passing": 1, "known shortfall": 1})
    assert run.trace("J-2")[0] == report.TRACE_PARTIAL
    assert run.trace("J-3") == (report.UNTRACED, {})
    run.stages["HK-B"] = "elsewhere"
    assert run.trace("J-1")[0] == report.TRACE_PASSING


def test_the_jama_export_is_read_and_repaired(tmp_path):
    """The export's grid layout, the confirmed symbol fix, and the refusal."""
    csv = tmp_path / "export.csv"
    head = '"Item Type","ID","Name","Description"' * 1
    csv.write_bytes((head + "\n" +
        '"L4 Requirement","FAR-PM_FPGA_L4REQ-19","Maximum Boot Attempts",'
        '"The housekeeper FPGA shall attempt to boot a power region ? 4 times",'
        '"L4 Requirement","FAR-PM_FPGA_L4REQ-99","Odd","Goes low for? 3 \xb0C"\n').encode("latin-1"))
    reqs, problems = jama.extract(csv, {}, cited=[])
    assert reqs["FAR-PM_FPGA_L4REQ-19"].text.endswith("power region \u2264 4 times")
    assert [p for p in problems if jama.MANGLED in p] == [
        p for p in problems if p.startswith("FAR-PM_FPGA_L4REQ-99")]


def test_clearing_coverage_leaves_nothing_to_report(tmp_path):
    """A run starts from clean coverage: data and report both go, and a
    report afterwards says nothing was measured instead of showing old data."""
    import code_coverage
    for name in ("a.dat", "b.dat", "summary.json", "coverage.info", "coverage.sarif"):
        (tmp_path / name).write_text("x")
    (tmp_path / "annotated").mkdir()
    (tmp_path / "annotated" / "top.sv").write_text("x")
    (tmp_path / "keep.txt").write_text("x")
    assert code_coverage.main(["--data", str(tmp_path), "--clear"]) == 0
    assert sorted(p.name for p in tmp_path.iterdir()) == ["keep.txt"]
    cov = codecov.load(tmp_path)
    assert not cov.measured and not cov.reported


def test_coverage_is_read_back(tmp_path):
    """In Verilator's own format: a header, counts as wide as they need to be,
    and `+`/`-` point lines belonging to the source line above them."""
    (tmp_path / "annotated").mkdir()
    (tmp_path / "annotated" / "a.sv").write_text(
        "//      // verilator_coverage annotation\n"
        "        module a;\n"
        " 260752526     input logic clk,\n"
        "+260752526  point: type=toggle comment=clk:0->1 hier=tb_top.dut.a\n"
        "%000000     output logic q,\n"
        "-000000  point: type=toggle comment=q:0->1 hier=tb_top.dut.a\n"
        " 000042         y = 2;\n"
        "+000042  point: type=branch comment=if hier=tb_top.dut.a\n"
        "-000000  point: type=branch comment=else hier=tb_top.dut.a\n"
        "        endmodule\n")
    (tmp_path / "summary.json").write_text(
        '{"modules": ["test_hk_x"], "kinds": {"line": [66.7, 2, 3]}, '
        '"files": {"a.sv": [1, 3]}}')
    (tmp_path / "test_hk_x.dat").write_text("")
    cov = codecov.load(tmp_path)
    assert cov.measured and cov.reported and not cov.stale
    assert cov.summary["line"] == (66.7, 2, 3)
    assert [(f.name, f.missed, f.counted) for f in cov.files] == [("a.sv", 1, 3)]
    lines = codecov.annotated("a.sv", tmp_path)
    assert [(l.text, l.count) for l in lines] == [
        ("module a;", None), ("    input logic clk,", 260752526),
        ("    output logic q,", 0), ("        y = 2;", 42), ("endmodule", None)]
    assert [len(l.points) for l in lines] == [0, 1, 1, 2, 0]
    assert lines[3].partial and not lines[1].partial, (
        "a line that ran with a branch never taken was not told apart from one "
        "whose every point was hit")
    assert lines[3].missed_points[0].comment == "else"
    (tmp_path / "test_hk_y.dat").write_text("")
    assert codecov.load(tmp_path).stale, (
        "a module measured after the report was not flagged, so the app would "
        "show old figures as the coverage of new data")
