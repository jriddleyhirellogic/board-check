"""A Libero build, as delivered: what the build inspections read.

A build directory (`build/<project>_<board>_<variant>_<utc>_<commit>/`) holds the
synthesis project and report, the synthesised netlist and the place-and-route
reports; the programming image and its manifest are filed beside each other
under `programming_files/<variant>/`. The sources it was synthesised from are
read from the commit the manifest records, not from the working tree: the
inspection is of the delivered build.
"""

from __future__ import annotations

import json
import re
import subprocess
import zipfile
from dataclasses import dataclass
from functools import cached_property
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
IMAGES = REPO / "programming_files"
FLIGHT = "fm_tmr"
_NAME = re.compile(r"_(?P<variant>(?:fm|em)(?:_tmr)?)_(?P<utc>\d{8}_\d{6})_(?P<commit>[0-9a-f]{7,40})$")


class NotInspectable(Exception):
    """The build cannot be inspected as the flight build: say why, plainly."""


def newest(variant: str = FLIGHT, root: Path = REPO / "build") -> Path | None:
    found = sorted(p for p in root.glob(f"*_{variant}_*") if _NAME.search(p.name)
                   and _NAME.search(p.name).group("variant") == variant)
    return found[-1] if found else None


@dataclass
class Build:
    dir: Path
    images: Path = IMAGES

    def __post_init__(self):
        self.dir = Path(self.dir).resolve()
        m = _NAME.search(self.dir.name)
        if not self.dir.is_dir() or not m:
            raise NotInspectable(f"{self.dir} is not a Libero build directory "
                                 "(<project>_<board>_<variant>_<utc>_<commit>)")
        self.variant, self.commit = m.group("variant"), m.group("commit")
        if self.variant != FLIGHT:
            raise NotInspectable(f"{self.dir.name} is the {self.variant} build; these "
                                 f"inspections are of the flight build, {FLIGHT}")

    # ---- the files

    def _file(self, *parts) -> Path:
        path = self.dir.joinpath(*parts)
        if not path.is_file():
            raise NotInspectable(f"{path.relative_to(self.dir)} is missing from {self.dir.name}")
        return path

    @property
    def name(self) -> str:
        return self.dir.name

    @cached_property
    def manifest(self) -> dict:
        path = self.images / self.variant / f"{self.name}.json"
        if not path.is_file():
            raise NotInspectable(f"no manifest at {path}: the image this build delivered "
                                 "cannot be identified")
        return json.loads(path.read_text(encoding="utf-8"))

    @property
    def image(self) -> Path:
        path = self.images / self.variant / self.manifest["image"]
        if not path.is_file():
            raise NotInspectable(f"the image the manifest names, {path}, is missing")
        return path

    def image_member(self, name: str) -> str:
        """A file inside the programming image (a ZIP archive)."""
        with zipfile.ZipFile(self.image) as z:
            return z.read(name).decode("latin-1")

    @cached_property
    def synthesis_report(self) -> str:
        return self._file("synthesis", "top.srr").read_text(encoding="latin-1")

    @cached_property
    def synthesis_project(self) -> str:
        return self._file("synthesis", "top_syn.prj").read_text(encoding="latin-1")

    @property
    def netlist(self) -> Path:
        return self._file("synthesis", "top.edn")

    @cached_property
    def place_and_route_report(self) -> str:
        return self._file("designer", "impl1", "top_place_and_route_report.txt") \
            .read_text(encoding="latin-1")

    # ---- the sources it was built from

    @cached_property
    def sources(self) -> list:
        """Repository files the synthesis project compiled, repository-relative."""
        out = []
        for path in re.findall(r'add_file\s+(?:-\S+\s+)*"([^"]+)"', self.synthesis_project):
            p = Path(path).resolve()
            if p.is_relative_to(self.dir) or not p.is_relative_to(REPO):
                continue                # generated into the build: vendor IP
            out.append(str(p.relative_to(REPO)))
        return out

    def source_at_commit(self, path: str) -> str:
        """A source as it was at the commit the build records."""
        run = subprocess.run(["git", "-C", str(REPO), "show", f"{self.commit}:{path}"],
                             capture_output=True, text=True)
        if run.returncode != 0:
            raise NotInspectable(f"{path} at {self.commit}: {run.stderr.strip()} -- the "
                                 "commit the build records is not in this repository")
        return run.stdout
