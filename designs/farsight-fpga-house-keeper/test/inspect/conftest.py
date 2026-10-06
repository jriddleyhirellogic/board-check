"""Inspections: structural claims about the design, checked by reading it.

No simulator. Each test reads the RTL, the pin constraints, the board's
schematic export (`verification/board/CM-03545.json`) or the design as
Verilator elaborates it, and runs in well under a second.
`make inspect` runs them and writes their JUnit results beside the
simulation's, where the gate and the requirement coverage find them.
"""

import os
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "verification"))

#: The Libero build the build inspections read (`make inspect-build`). Without
#: one they are not collected at all -- not skipped, which the gate would count
#: as a requirement test that did not report -- and their items read "not run".
BUILD = os.environ.get("FSVERIF_BUILD")
collect_ignore = [] if BUILD else ["build.py", "version.py"]

from altium_sch_json import load, problems  # noqa: E402
from fsverif.board import SCHEMATIC  # noqa: E402


@pytest.fixture(scope="session")
def netlist():
    """The device elaborated by Verilator, at the simulation's variant
    (fm_tmr), vendor IP included: `fsverif.elaborated`."""
    from fsverif import elaborated
    return elaborated.elaborate()


@pytest.fixture(scope="session")
def board():
    """The schematic export, refused if it is not structurally sound."""
    design = load(SCHEMATIC)
    found = problems(design.raw)
    assert not found, "%s is not usable:\n  %s" % (SCHEMATIC, "\n  ".join(found))
    return design


@pytest.fixture(scope="session")
def build():
    """The flight build named by FSVERIF_BUILD: `fsverif.delivered.Build`."""
    from fsverif.delivered import Build
    return Build(Path(BUILD))
