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

import pytest

VERIF = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(VERIF))

from fsverif import codecov  # noqa: E402
from fsverif import results as report  # noqa: E402
from check_results import KNOWN, PASSED, REGRESSION, STALE, classify, judge  # noqa: E402
from fsverif import jama  # noqa: E402
from fsverif import runlog  # noqa: E402
from fsverif.evidence import Item  # noqa: E402

JUNIT = """<?xml version='1.0' encoding='utf-8'?>
<testsuites><testsuite name="test_pf_x">
<testcase classname="test_pf_x" name="test_PF_A_01_passes" time="1"/>
<testcase classname="test_pf_x" name="test_PF_A_02_fails" time="1">
<failure message="the thing was 3, not 7&#10;assert 3 == 7" type="AssertionError">trace</failure>
</testcase>
</testsuite></testsuites>
"""


def _item(test, expect_fail=False):
    return Item(id="VC-%s" % test[-5:], verifies=["PF-A-01"], method="SIM",
                artifact="verification/tests/test_pf_x.py::%s" % test,
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
        regression.info("running test_pf_x.test_PF_A_01_passes (1/2)\n"
                        "    docstring line")
        tb.info("measured 5.13 us")
        regression.info("test_pf_x.test_PF_A_01_passes passed")
        regression.info("running test_pf_x.test_PF_A_02_fails (2/2)")
        tb.info("first line\nsecond line")
        regression.warning("test_pf_x.test_PF_A_02_fails failed")
    finally:
        for handler in added:
            root.removeHandler(handler)
            handler.close()


def test_the_log_is_read_back_per_test(tmp_path, monkeypatch):
    log = tmp_path / "log-test_pf_x.txt"
    _write_log(log, monkeypatch)
    lines = report.logged(tmp_path)
    assert lines[("test_pf_x", "test_PF_A_01_passes")] == ["measured 5.13 us"], (
        "a passing test's logged measurement was not attributed to it, so the "
        "report would show a pass with nothing behind it")
    assert lines[("test_pf_x", "test_PF_A_02_fails")] == ["first line\nsecond line"], (
        "a multi-line message was split or lost")


def test_failure_messages_are_unescaped(tmp_path):
    (tmp_path / "results-test_pf_x.xml").write_text(JUNIT, encoding="utf-8")
    messages = report.failure_messages(tmp_path)
    assert messages == {("test_pf_x", "test_PF_A_02_fails"):
                        "the thing was 3, not 7\nassert 3 == 7"}


def test_verdicts_match_the_gate():
    """The report groups by the gate's verdict, from the gate's own code."""
    results = {("test_pf_x", "test_PF_A_01_passes"): "passed",
               ("test_pf_x", "test_PF_A_02_fails"): "failed",
               ("test_pf_x", "test_PF_A_03_fixed"): "passed",
               ("test_pf_x", "test_PF_A_04_new"): "failed"}
    items = {("test_pf_x", t): [_item(t, e)] for t, e in (
        ("test_PF_A_01_passes", False), ("test_PF_A_02_fails", True),
        ("test_PF_A_03_fixed", True), ("test_PF_A_04_new", False))}
    got = {key[1]: v for key, _, v in classify(items, results)}
    assert got == {"test_PF_A_01_passes": PASSED, "test_PF_A_02_fails": KNOWN,
                   "test_PF_A_03_fixed": STALE, "test_PF_A_04_new": REGRESSION}


def test_a_test_that_did_not_report_blocks(tmp_path, monkeypatch):
    """A written requirement test with no result blocks, as a skip does: a
    module that failed to import leaves nothing else to judge. One not written
    yet does not -- that is the item's state, not the run's."""
    (tmp_path / "verification" / "tests").mkdir(parents=True)
    (tmp_path / "verification" / "tests" / "test_pf_x.py").write_text("")
    written = Item(id="VC-1", verifies=["PF-A-01"], method="SIM",
                   artifact="verification/tests/test_pf_x.py::test_PF_A_01_runs",
                   expect_fail=True, blocked=False)
    unwritten = Item(id="VC-2", verifies=["PF-A-02"], method="SIM",
                     artifact="verification/tests/test_pf_y.py::test_PF_A_02_later",
                     expect_fail=False, blocked=False)
    bench = Item(id="VC-3", verifies=["PF-A-01"], method="HW",
                 artifact="test/hw/bench.md::HW-PF-A-01", expect_fail=False, blocked=False)
    items = {i.key: [i] for i in (written, unwritten, bench)}
    monkeypatch.setattr(Item, "written",
                        lambda self, repo=tmp_path: (repo / self.artifact.partition("::")[0]).is_file())
    blocking, _ = judge(items, {})
    assert len(blocking) == 1 and "NO RESULT" in blocking[0] and "VC-1" in blocking[0], blocking
    blocking, _ = judge(items, {written.key: "failed"})
    assert blocking == [], "a declared failure that reported must not block: %s" % blocking


def test_the_documents_load_whole():
    """Every requirement, finding and item the app will show, from the repo."""
    run = report.load(results_dir=Path("/nonexistent"))
    assert len(run.requirements) > 70 and len(run.findings) > 40
    assert all(run.requirement_text.get(r) for r in run.requirements), (
        "a requirement has no entry text, so its detail pane would be empty")
    assert not any("## Withdrawn" in t for t in run.requirement_text.values()), (
        "the last requirement's entry ran on into the withdrawn section")
    assert set(run.finding_text) == set(run.findings), (
        "the findings summary and the finding sections disagree: %s"
        % sorted(set(run.finding_text) ^ set(run.findings)))
    assert all(sev in ("CRITICAL", "HIGH", "MEDIUM", "LOW") for sev, _ in run.findings.values())
    assert all(t.verdict == report.NOT_RUN for t in run.tests)
    assert any(t.analysis for t in run.tests) and any(not t.analysis for t in run.tests), (
        "the app shows only one of simulations and analyses")


def test_an_analysis_shows_its_calculation(tmp_path):
    """An analysis has no simulator log; its record, in the JUnit `system-out`
    `analysis/conftest.py` writes, is what it did."""
    (tmp_path / "results-test_ana_x.xml").write_text(
        "<?xml version='1.0' encoding='utf-8'?><testsuites><testsuite name='test_ana_x'>"
        "<testcase classname='test_ana_x' name='test_PF_A_01_sum'>"
        "<system-out>## PF-A-01 -- a sum\n\n- **a:** 2 cycles (`x.sv:3`)</system-out>"
        "</testcase></testsuite></testsuites>", encoding="utf-8")
    assert report.recorded(tmp_path) == {
        ("test_ana_x", "test_PF_A_01_sum"): "## PF-A-01 -- a sum\n\n- **a:** 2 cycles (`x.sv:3`)"}
    assert report.module_arg("test_ana_budgets") == "analysis/test_ana_budgets.py"
    assert report.module_arg("test_pf_focus") == "tests/test_pf_focus.py"


def test_every_cited_jama_parent_is_in_the_snapshot():
    """Every parent an FPGA requirement cites is in the snapshot, so
    a typo in a Parent line cannot quietly drop a trace; every allocated
    FAR-CDH_FPGA L3 requirement is there, traced or not; and no symbol the
    export mangled is left unrepaired. An allocated requirement with nothing
    under it is shown as such in the app rather than refused here."""
    run = report.load(results_dir=Path("/nonexistent"))
    assert run.jama, "docs/requirements/jama.yaml is missing or empty"
    assert not run.uncited_parents, (
        "requirements cite Jama ids the snapshot does not hold (a typo, or "
        "refresh it with `python -m fsverif.jama --csv`): %s" % run.uncited_parents)
    allocated = [j for j in run.jama if jama.ALLOCATED.fullmatch(j)]
    assert len(allocated) >= 20, "the FAR-CDH_FPGA L3 set is incomplete"
    assert [j for j, r in run.jama.items() if r.verified_in], (
        "no Jama requirement is marked as verified elsewhere")
    assert not [j for j, r in run.jama.items() if r.verified_in and run.children(j)], (
        "a Jama requirement marked verified elsewhere has PF requirements under it")
    assert not [j for j, r in run.jama.items() if "?" in r.text], "a mangled symbol"


def test_trace_rolls_up_the_worst_stage():
    run = report.load(results_dir=Path("/nonexistent"))
    run.parents = {"PF-A": ["J-1"], "PF-B": ["J-1"], "PF-C": ["J-2"]}
    run.requirements = {k: None for k in run.parents}
    run.stages = {"PF-A": "passing", "PF-B": "known shortfall", "PF-C": "not written"}
    run.jama = {"J-4": jama.JamaReq("J-4", "", "", verified_in="elsewhere")}
    assert run.trace("J-1") == (report.TRACE_FAILING, {"passing": 1, "known shortfall": 1})
    assert run.trace("J-2")[0] == report.TRACE_PARTIAL
    assert run.trace("J-3") == (report.UNTRACED, {})
    assert run.trace("J-4") == (report.TRACE_ELSEWHERE, {}), (
        "a Jama requirement with only firmware under it borrowed a result")
    run.stages["PF-B"] = "elsewhere"
    assert run.trace("J-1")[0] == report.TRACE_PASSING


def test_the_jama_export_is_read_and_repaired(tmp_path):
    """The export's grid layout, an id with no component (`FAR-L1REQ-19`), the
    confirmed symbol fix, and the refusal of an unconfirmed one."""
    csv = tmp_path / "export.csv"
    head = '"Item Type","ID","Name","Description"'
    csv.write_bytes((head + "\n" +
        '"L3 Requirement","FAR-CDH_FPGA_L3REQ-19","Exposure Start Control",'
        '"FARSIGHT Avionics shall control exposure start within ? 100 ns",'
        '"L1 Requirement","FAR-L1REQ-19","Fault Detection","Detect faults",'
        '"L3 Requirement","FAR-CDH_FPGA_L3REQ-99","Odd","Goes low for? 3 \xb0C"\n').encode("latin-1"))
    kept = {"FAR-CDH_FPGA_L3REQ-19": jama.JamaReq("FAR-CDH_FPGA_L3REQ-19", "old", "old",
                                                  note="why", verified_in="elsewhere")}
    reqs, problems = jama.extract(csv, kept, cited=["FAR-L1REQ-19"])
    assert reqs["FAR-CDH_FPGA_L3REQ-19"].text.endswith("within \u2264 100 ns")
    assert (reqs["FAR-CDH_FPGA_L3REQ-19"].note,
            reqs["FAR-CDH_FPGA_L3REQ-19"].verified_in) == ("why", "elsewhere"), (
        "a refresh lost the hand-written fields")
    assert reqs["FAR-L1REQ-19"].name == "Fault Detection"
    assert [p for p in problems if jama.MANGLED in p] == [
        p for p in problems if p.startswith("FAR-CDH_FPGA_L3REQ-99")]
    out = tmp_path / "jama.yaml"
    jama.write(reqs, "test", out)
    assert jama.load(out)["FAR-CDH_FPGA_L3REQ-19"].verified_in == "elsewhere"


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
        '{"modules": ["test_pf_x"], "kinds": {"line": [66.7, 2, 3]}, '
        '"files": {"a.sv": [1, 3]}}')
    (tmp_path / "test_pf_x.dat").write_text("")
    cov = codecov.load(tmp_path, recorded=tmp_path / "none.yaml")
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
    (tmp_path / "test_pf_y.dat").write_text("")
    assert codecov.load(tmp_path, recorded=tmp_path / "none.yaml").stale, (
        "a module measured after the report was not flagged, so the app would "
        "show old figures as the coverage of new data")


def test_the_headline_counts_each_point_once(tmp_path):
    """A point reached by any instance counts once, however many instances or
    testbenches have it; a code line either simulator ran counts as run; a bit
    both simulators toggle-measured is one bit; and branches stay per
    simulator, because each counts them its own way."""
    (tmp_path / "annotated").mkdir()
    (tmp_path / "annotated" / "f.sv").write_text(
        "//      // verilator_coverage annotation\n"
        " 000005         a = 1;\n"
        "+000005  point: type=line comment=block hier=t.u1\n"
        "-000000  point: type=line comment=block hier=t.u2\n"
        " 000003         b = 1;\n"
        "-000000  point: type=line comment=block hier=t.u1\n"
        "+000003  point: type=line comment=questa statement 1\n"
        " 000002     input logic [1:0] d,\n"
        "+000002  point: type=toggle comment=d[0]:0->1 hier=t.u1\n"
        "-000000  point: type=toggle comment=questa d[0]:0->1\n"
        "-000000  point: type=toggle comment=d[1]:0->1 hier=t.u1\n"
        " 000001         if (x)\n"
        "+000001  point: type=branch comment=if hier=t.u1\n"
        "-000000  point: type=branch comment=if hier=t.u2\n"
        "-000000  point: type=branch comment=questa branch 1\n")
    assert codecov.tally(["f.sv"], tmp_path) == {
        "code lines": [100.0, 3, 3], "toggles": [50.0, 1, 2],
        "verilator branch": [100.0, 1, 1], "questa branch": [0.0, 0, 1]}


def test_dispositions_apply_only_where_they_still_hold(tmp_path):
    """A disposition excuses code no test executed. It is not applied -- and is
    reported -- when its first line no longer reads what it names, because the
    source moved under it, or when a test executed a line it covers, because
    then its reason is wrong or no longer needed."""
    (tmp_path / "annotated").mkdir()
    (tmp_path / "annotated" / "f.sv").write_text(
        "        case (state)\n"
        "%000000         default: begin\n"
        "-000000  point: type=line comment=block hier=t.f\n"
        "%000000             state <= IDLE;\n"
        "-000000  point: type=line comment=block hier=t.f\n"
        "         end\n"
        " 000007         X: y = 1;\n"
        "+000007  point: type=line comment=block hier=t.f\n"
        "%000000     output logic q,\n"
        "-000000  point: type=toggle comment=q:0->1 hier=t.f\n")
    lines = codecov.annotated("f.sv", tmp_path)
    recorded = tmp_path / "d.yaml"
    recorded.write_text(
        "- {file: f.sv, lines: 2-4, at: 'default: begin', kind: illegal-state, reason: r}\n"
        "- {file: f.sv, lines: 3-6, at: 'something else', kind: unreachable, reason: r}\n"
        "- {file: f.sv, lines: 4-5, at: 'end', kind: outside-flight, reason: r}\n")
    applied, problems = codecov.disposed("f.sv", lines, codecov.dispositions(recorded))
    assert sorted(applied) == [2, 3, 4]
    assert [(p["where"], p["problem"]) for p in problems] == [
        ("f.sv:3-6", "moved"), ("f.sv:4-5", "executed")]
    assert [codecov.never_executed(l) for l in lines] == [None, True, True, None, False, None], (
        "a declaration whose only point is a toggle was counted as code")

    recorded.write_text("- {file: f.sv, lines: 2, at: x, kind: untested, reason: r}\n")
    with pytest.raises(ValueError, match="kind"):
        codecov.dispositions(recorded)


def test_dispositions_record_holds():
    """Every recorded disposition is well formed and still names the line it
    was written against, in the design source -- so a change to the RTL that
    moves a disposed block fails here, without needing coverage data."""
    for d in codecov.dispositions():
        src = codecov.source(d.file)
        assert src, "%s: no design source named %s" % (d.where, d.file)
        text = src.read_text(encoding="utf-8", errors="replace").splitlines()
        assert d.last <= len(text), "%s: past the end of %s" % (d.where, src.name)
        assert d.at in text[d.first - 1], (
            "%s: line %d reads %r, not %r -- the source moved; re-check the "
            "disposition against it" % (d.where, d.first, text[d.first - 1].strip(), d.at))
        assert len(d.reason) > 40, "%s: give the reason, with the value it rests on" % d.where


def test_emphasis_around_code_renders():
    """The analysis records label each input **`name`:**; split on backticks
    first, the asterisks fell on either side of the code and showed literally."""
    from fsverif import render
    html = render.markdown("- **`const_step_fall`:** 75 cycles (`STEP_DIR.sv:45`), see PF-F-53")
    assert "<b><code>const_step_fall</code>:</b>" in html and "**" not in html
    assert "<a href='fsv:finding/PF-F-53'>PF-F-53</a>" in html


VCOVER = """=================================================================================
=== File: {src}
=================================================================================
Branch Coverage:
    Enabled Coverage              Bins      Hits    Misses  Coverage
    ----------------              ----      ----    ------  --------
    Branches                         3         2         1    66.66%
================================Branch Details================================
------------------------------------IF Branch------------------------------------
    2                                          4     Count coming in to IF
    2               1                          3     
    2               2                    ***0***     
Statement Coverage:
    Enabled Coverage              Bins      Hits    Misses  Coverage
    ----------------              ----      ----    ------  --------
    Statements                       3         2         1    66.66%
================================Statement Details================================
    2               1                          4     
    2               2                          3     
    3               1                    ***0***     
Toggle Coverage:
    Enabled Coverage              Bins      Hits    Misses  Coverage
    ----------------              ----      ----    ------  --------
    Toggles                          2         1         1    50.00%
================================Toggle Details================================
       Line                                   Node      1H->0L      0L->1H  "Coverage"
          1                                   c[0]           0           1       50.00 
"""


def test_questa_coverage_merges_with_verilators(tmp_path):
    """QuestaSim's per-file report, read and merged line by line into the
    annotation Verilator left for the same file: a line either simulator
    reached is reached, and a point either never hit marks it partly covered."""
    from fsverif import ucdb
    src = tmp_path / "t.sv"
    src.write_text("module t(input c);\n  if (a) b;\n  d;\nendmodule\n")
    files = ucdb.parse(VCOVER.format(src=src))
    cov = files[str(src)]
    assert cov.kinds == {"branch": [2, 3], "statement": [2, 3], "toggle": [1, 2]}
    assert sorted(c for c, k, _ in cov.lines[2]) == [0, 3, 3, 4], (
        "statement and branch items on line 2, without the 'coming in' total")
    (tmp_path / "annotated").mkdir()
    verilator = tmp_path / "annotated" / "t.sv"
    verilator.write_text("//      // verilator_coverage annotation\n"
                         "        module t(input c);\n"
                         "%000000   if (a) b;\n"
                         "-000000  point: type=line comment=if hier=top.t\n"
                         " 000007   d;\n"
                         "        endmodule\n")
    verilator.write_text(ucdb.merge_annotation(src, verilator, cov))
    lines = codecov.annotated("t.sv", tmp_path)
    assert [l.count for l in lines] == [1, 4, 7, None], (
        "a line Verilator never reached but QuestaSim did was left unreached")
    assert lines[1].partial and lines[2].partial, (
        "a branch or statement QuestaSim never hit did not mark its line partly covered")
    assert [(p.comment, p.count) for p in lines[0].points] == [
        ("questa c[0]:0->1", 1), ("questa c[0]:1->0", 0)], "toggles land on the declaring line"
