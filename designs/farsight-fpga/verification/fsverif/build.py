"""The retained FPGA build, for analyses of Libero's own reports.

The reports are evidence only of the design that was built. Build directories
carry the commit they were built from in their name; the build is current if
no design source -- RTL, SmartDesigns, cores, constraints, build scripts --
differs between that commit and the working tree. A stale build is not used:
the analysis fails and says why, rather than passing on a design that is not
this one. No build at all is a skip: the evidence is absent, not failing.
"""

from __future__ import annotations

import re
import subprocess
from dataclasses import dataclass
from pathlib import Path

import pytest

from fsverif.design import BOARD, REPO

#: What a build is built from. A change to any of these makes a build stale.
#: Not `gen_ip.tcl`, which only the verification environment runs, nor
#: `script/common/download.tcl`, which fetches cores into a vault: which core,
#: at which version, a design uses is fixed by its definitions under `bd/` and
#: `ip/`, which are checked.
DESIGN = ["ip", "bd", "constr", "script", "synth.tcl", ":(exclude)script/common/download.tcl"]


@dataclass
class Build:
    root: Path
    commit: str

    @property
    def designer(self) -> Path:
        return self.root / "designer" / "top"

    @property
    def synthesis(self) -> Path:
        return self.root / "synthesis"

    def cite(self, path: Path, line: int | None = None) -> str:
        rel = path.relative_to(REPO)
        return "%s%s" % (rel, ":%d" % line if line else "")


def retained() -> Build:
    """The newest retained build, if it is of the current design."""
    builds = sorted(p for p in (REPO / "build").glob("%s_*" % BOARD)
                    if p.is_dir() and (p / "designer" / "top").is_dir())
    if not builds:
        pytest.skip("no retained build under build/: these reports exist only after an FPGA build")
    root = builds[-1]
    commit = re.search(r"_([0-9a-f]{8})$", root.name).group(1)
    paths = [p for p in DESIGN if p.startswith(":") or (REPO / p).exists()]
    changed = subprocess.run(["git", "diff", "--name-only", commit, "--"] + paths, cwd=REPO,
                             capture_output=True, text=True, check=True).stdout.split()
    assert not changed, (
        "the retained build %s is of commit %s, and %d design sources have changed since "
        "(%s): its reports describe another design. Rebuild."
        % (root.name, commit, len(changed), ", ".join(changed[:5])))
    return Build(root, commit)


def line_of(path: Path, pattern: str) -> tuple[int, re.Match]:
    text = path.read_text(errors="replace")
    m = re.search(pattern, text, re.M)
    if not m:
        raise KeyError("%s has no match for %s" % (path.name, pattern))
    return text.count("\n", 0, m.start()) + 1, m
