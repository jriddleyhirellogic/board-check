"""The browser app's server, and the SARIF output. No simulation.

Starts the server on a free port against the repository's own documents and
last results, and holds it to what it promises: nothing without the token,
nothing outside the repository, the same verdicts as the merge gate, and a run
that can be started and finishes. SARIF is checked for shape and for the
verdict-to-level mapping the SARIF Viewer shows.
"""

from __future__ import annotations

import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import sarif  # noqa: E402
from fsverif import results as R  # noqa: E402
from fsverif.web.server import serve  # noqa: E402


@pytest.fixture(scope="module")
def web():
    server, app = serve(0, "t0ken")
    base = f"http://127.0.0.1:{server.server_address[1]}"
    yield base, app
    if app.job and app.job.running:
        app.job.cancel()
    server.shutdown()


def _get(base, path, token="t0ken"):
    req = urllib.request.Request(base + path, headers={"X-Fsverif-Token": token} if token else {})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def _post(base, path, body):
    req = urllib.request.Request(base + path, data=json.dumps(body).encode(),
                                 headers={"X-Fsverif-Token": "t0ken",
                                          "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.loads(r.read())


def test_nothing_without_the_token(web):
    base, _ = web
    assert _get(base, "/api/state", token=None)[0] == 403
    assert _get(base, "/api/state", token="wrong")[0] == 403
    assert _get(base, "/", token=None)[0] == 403, (
        "the page was served without its token, so anybody on this machine could "
        "open it and start runs as whoever launched it")
    assert _get(base, "/?token=t0ken", token=None)[0] == 200
    assert _get(base, "/static/../server.py", token=None)[0] == 404


def test_state_agrees_with_the_model(web):
    base, _ = web
    status, body = _get(base, "/api/state")
    state = json.loads(body)
    run = R.load()
    assert status == 200 and state["counts"] == run.counts(), (
        "the page and the model disagree about the verdicts")
    assert len(state["requirements"]) == len(run.requirements)
    assert [j["id"] for j in state["jama"]] == list(run.jama)
    assert all(j["rollup"] == run.trace(j["id"])[0] for j in state["jama"])
    for kind, query in (("test", f"module={run.tests[0].module}&name={run.tests[0].name}"),
                        ("req", "id=HK-SEQ-10"), ("finding", "id=HK-F-28"),
                        ("jama", "id=FAR-PM_FPGA_L4REQ-14")):
        html = json.loads(_get(base, f"/api/detail?kind={kind}&{query}")[1])["html"]
        assert len(html) > 200 and "Not found" not in html, kind


def test_only_repository_files_open(web):
    base, _ = web
    assert "error" in _post(base, "/api/open", {"path": "/etc/passwd", "line": 1})


def test_a_run_starts_and_finishes(web):
    base, app = web
    assert "error" in _post(base, "/api/run", {"kind": "nonsense"})
    assert _post(base, "/api/run", {"kind": "fast"})["ok"]
    deadline = time.time() + 120
    while app.job.running and time.time() < deadline:
        time.sleep(0.2)
    status = json.loads(_get(base, "/api/run?since=0")[1])
    assert not status["running"] and status["total"] > 0, status["lines"][-5:]


def test_sarif_levels_follow_the_gate():
    run = R.load()
    log = sarif.tests_sarif(run)
    assert log["version"] == "2.1.0"
    results = log["runs"][0]["results"]
    failing = [t for t in run.tests if t.verdict != "passed"]
    assert len(results) == len(failing)
    for t, r in zip(failing, results):
        assert r["level"] == sarif.LEVEL[t.verdict]
        loc = r["locations"][0]["physicalLocation"]
        assert loc["artifactLocation"]["uri"] == str(t.path.relative_to(R.VERIF.parent))
        assert loc["region"]["startLine"] > 1


def test_runs_measure_coverage_unless_told_not_to():
    """A simulation run measures code coverage and writes the report after it;
    the quick run does neither; the fast checks simulate nothing."""
    from fsverif.runs import FAST, phases
    full = phases(None)
    names = [p.description for p in full]
    assert names[-3:] == ["Running the whole suite", "Running the inspections",
                          "Writing the coverage report"]
    assert full[-3].env == {"FSVERIF_COVERAGE": "1"}
    assert full[-2].always and full[-1].always, "a failing test must not stop the rest"
    assert any("--clear" in p.argv for p in full), "a run must start from clean coverage"
    quick = phases(None, coverage=False)
    assert quick[-2].env == {"FSVERIF_COVERAGE": "0"}
    assert any("--clear" in p.argv for p in quick), "a quick run must not leave a stale report"
    assert all("coverage report" not in p.description for p in quick)
    fast = phases(FAST, simulate=False)
    assert [p.env for p in fast] == [{}, {}] and "inspections" in fast[-1].description
