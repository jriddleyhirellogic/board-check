import glob
import json
import os

import pytest

from boardcheck.cli import main
from boardcheck.config import Config
from boardcheck.model import Design
from boardcheck.runner import run
from helpers import cap, make_export

REPO = os.path.dirname(os.path.dirname(__file__))


def _design():
    return Design(make_export([cap("C1", "X", "3V3_A", "3V3_A"), cap("C2", "X", "3V3_A", "GND")]))


def test_waiver_applies_and_unused_waiver_is_reported():
    config = Config({"waivers": [
        {"check": "NET007", "ref": "C1", "reason": "intentional"},
        {"check": "NET001", "net": "NOPE", "reason": "stale"},
    ]})
    result = run(_design(), config)
    waived = [f for f in result.waived if f.check == "NET007"]
    assert waived and waived[0].waived_by == "intentional"
    assert not [f for f in result.active if f.check == "NET007"]
    assert any(f.check == "CFG001" and "NOPE" in f.message for f in result.active)


def test_severity_override_and_fail_on():
    result = run(_design(), Config({"severity": {"NET007": "error"}}))
    assert result.fails("error")
    assert not result.fails("never")
    result = run(_design(), Config({"disabled": ["NET007"]}))
    assert not result.fails("error")
    assert ("NET007", "disabled in config") in result.skipped


def test_partsdb_checks_skip_without_partsdb():
    result = run(_design(), Config())
    skipped = dict(result.skipped)
    assert "PRT003" in skipped and "not installed" in skipped["PRT003"]


def test_cli_json_output_and_exit_code(tmp_path, capsys):
    export = tmp_path / "e.json"
    export.write_text(json.dumps(make_export([cap("C1", "X", "3V3_A", "3V3_A"), cap("C2", "X", "3V3_A", "GND")])))
    out = tmp_path / "r.json"
    code = main([str(export), "-f", "json", "-o", str(out), "--no-partsdb", "--fail-on", "warning"])
    data = json.loads(out.read_text())
    assert code == 1
    assert any(f["check"] == "NET007" for f in data["findings"])
    assert main([str(export), "--no-partsdb", "--fail-on", "never"]) == 0


FARSIGHT_DIR = os.path.join(REPO, "designs", "CM-03545")
FARSIGHT = sorted(glob.glob(os.path.join(FARSIGHT_DIR, "CM-03545*_sch_*.json")))


@pytest.mark.skipif(not FARSIGHT, reason="Farsight export not present")
def test_farsight_export_is_complete():
    """The committed export passes every export-integrity check."""
    design = Design.load(FARSIGHT[-1])
    config = Config.load(os.path.join(FARSIGHT_DIR, "boardcheck.yaml"))
    result = run(design, config, only={"EXP001", "EXP002", "EXP003", "EXP004", "EXP005", "EXP006"})
    assert [f.message for f in result.active] == []


@pytest.mark.skipif(not FARSIGHT, reason="Farsight export not present")
def test_farsight_fpga_constraints_read_cleanly():
    """The FPGA constraint and top-level files the config points at parse
    with nothing ignored, when the FPGA repository is checked out beside
    this one."""
    config = Config.load(os.path.join(FARSIGHT_DIR, "boardcheck.yaml"))
    missing = [p for spec in config["fpga"].values() for p in spec["constraints"]
               if not os.path.isfile(os.path.join(FARSIGHT_DIR, p))]
    if missing:
        pytest.skip("FPGA repository not checked out next to board-check")
    result = run(Design.load(FARSIGHT[-1]), config, only={"FIO001"})
    assert [f.message for f in result.active] == []
