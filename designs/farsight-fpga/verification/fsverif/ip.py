"""Is the generated IP still the IP the design asks for?

The design instantiates vendor cores that Libero generates from component
definitions kept beside the SmartDesigns that use them -- under
`bd/<board>/<hierarchy>/components/` and `ip/<block>/components/`. That
generated RTL is what both synthesis and simulation compile, so verification
depends on files nobody wrote and nothing in the repository reproduces on
demand -- exactly the kind of input that goes stale quietly.

Four ways it goes wrong, and only the first is obvious:

1. **It is absent.** A fresh clone has no generated IP and may have no Libero.
   This fails loudly and says how to fix it.

2. **The definition moved underneath it.** Somebody bumps a core version or
   changes a parameter and does not regenerate. Simulation keeps compiling the
   old core, passes, and reports evidence about a device that is not the one
   being built. Nothing about the RTL looks wrong, because it is valid RTL for
   a configuration the design no longer asks for.

3. **A core appeared or disappeared.** A component definition is added and
   never generated, so simulation compiles a design missing a block -- or a
   definition is deleted and stale RTL stays behind.

4. **It came from somewhere else.** Verification originally read a core out of
   whichever build directory sorted last, across any sibling checkout. That
   answers "the most recent core somebody generated", not "the core this
   design specifies", and the two differ the moment anyone builds a branch.

The defence is a lockfile per core, written at generation time and committed,
recording what the core was generated *from*. This module recomputes those
facts and refuses to proceed when they disagree. It needs no Libero to do so:
a checkout can always tell whether its IP matches its definitions, even where
it could not produce any.

**Which components are generated for simulation is `verification/ip.yaml`.**
The build defines 81 vendor components, and a block-level test needs a
handful; generating all of them would take longer than the tests and fetch
cores nothing simulates. A component is listed there by name; its definition is
found wherever the build keeps it, and its sources are read from the manifest
Libero writes beside it, so nothing here names a particular core.

**Generation is deterministic apart from a timestamp.** Three builds of one
commit produced byte-identical vendor sources and differed only in a
`// Created by ...` comment. So digests are taken over normalised text:
without that, every regeneration would look like a change and the check would
be switched off within a week.

**One exception: `focus_mech`.** Libero names a net that joins several of a
SmartDesign's ports after whichever port it takes first, and for `focus_mech`
that choice, and the order of its declarations, differ from one generation to
the next. The netlist is the same circuit each time, but not the same text, so
its digest changes whenever it is regenerated: its lockfile records the last
generation, and a copy generated elsewhere will not match it. The other
components here have generated identically every time.
"""

from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass
from pathlib import Path

#: The section of Libero's per-component manifest listing what to compile.
#: Reading this rather than globbing is what keeps the environment free of
#: per-core knowledge: the generator states its own outputs, and distinguishes
#: sources from the stimulus files that must not be compiled into a design.
_HDL_SECTION = re.compile(
    r"^HDL source files[^\n]*:\n(.*?)(?:\n\s*\n|\Z)", re.S | re.M)

#: Lines Libero stamps with a generation time. They carry no design content,
#: and including them would make every regeneration look like a change.
_VOLATILE = re.compile(r"^//\s*Created by .*$", re.M)

#: The core a component definition asks for, e.g.
#: `Vendor:Library:Core:Version`. Libero 2024 writes `create_and_configure_core
#: -core_vlnv {...}`; older definitions `create_design -id {...}`.
_CORE_ID = re.compile(r"-(?:core_vlnv|id)\s*\{([^}]+)\}")

#: PolarFire hard blocks with no source model. Libero's `polarfire.v` models
#: some primitives -- PLL, OSC, INIT, the clock mux and divider, the RAM blocks
#: -- but these exist only in the precompiled QuestaSim library. A generated
#: file instantiating one cannot be compiled by Verilator, and is held back
#: with the reason reported rather than silently dropped.
#:
#: Detected rather than listed by filename, so a newly added core needs no
#: entry here. Where a DUT genuinely needs such a block, elaboration fails
#: with a missing module and the report says which file was held back and why
#: -- the signal to pin that DUT to questa.
HARD_MACROS = ("IOD", "LANECTRL", "DLL", "PCIE", "PCIE_COMMON", "TX_PLL",
               "XCVR", "XCVR_8B10B", "XCVR_64B6XB", "XCVR_APB_LINK",
               "XCVR_APB_LINK_V2", "XCVR_PIPE_AXI0", "XCVR_PIPE_AXI1",
               "XCVR_REF_CLK", "CORELNKTMR_V", "BANKEN", "TVS")

#: A SmartDesign definition. Generated like a vendor core, into a Verilog
#: wrapper that wires our own IP blocks together exactly as the build does --
#: so a test of a hierarchy does not carry a second, hand-written copy of its
#: wiring that drifts from the real one.
_SMARTDESIGN = re.compile(r"create_smartdesign\s+-sd_name\s+\$?\{?(\w+)")

#: Source Microchip ships encrypted. No open simulator can read it.
_ENCRYPTED = re.compile(r"pragma\s+protect|`protect|begin_protected")

_INSTANTIATION = re.compile(
    r"^\s*(%s)\s+(?:#\s*\([^)]*\)\s*)?\w+\s*\(" % "|".join(HARD_MACROS), re.M)

LOCK_SUFFIX = ".lock.json"


class StaleIP(Exception):
    """Generated IP is missing, incomplete, or not what the design specifies."""


def _is_definition(path: Path) -> bool:
    text = path.read_text(encoding="utf-8", errors="replace")
    return bool(_CORE_ID.search(text) or _SMARTDESIGN.search(text))


def definition(repo: Path, board: str, name: str) -> Path:
    """The one component definition for `name`, wherever the build keeps it.

    Vendor components and SmartDesigns live under `bd/<board>/**/components/`
    and `ip/**/components/`, and are identified by carrying a core VLNV or a
    `create_smartdesign`. Exactly one must exist: two would be two definitions
    of one component, and which the build used would be a question of order.
    """
    found = sorted(
        p for root in (repo / "bd" / board, repo / "ip")
        for p in root.rglob("components/%s.tcl" % name)
        if _is_definition(p))
    if not found:
        raise StaleIP(
            "no component definition named %s under bd/%s/ or ip/. "
            "verification/ip.yaml names a component the design does not define."
            % (name, board))
    if len(found) > 1:
        raise StaleIP("%s is defined more than once: %s"
                      % (name, ", ".join(str(p.relative_to(repo)) for p in found)))
    return found[0]


def entries(ip_yaml: Path) -> list:
    """`(name, prepare)` for each component `verification/ip.yaml` lists.

    `prepare` is the build's own scripts that must run first -- for a
    SmartDesign, the `ip/<block>/<block>_ip.tcl` that creates the HDL cores it
    instantiates. They are the build's scripts, sourced as the build sources
    them, not restated. `sources` (see `source_dirs`) are the RTL directories
    the build links into the project before those scripts can run.
    """
    return [(name, prepare) for name, prepare, _ in _raw_entries(ip_yaml)]


def _raw_entries(ip_yaml: Path) -> list:
    import yaml

    data = yaml.safe_load(ip_yaml.read_text(encoding="utf-8")) or {}
    found = []
    for entry in data.get("components") or []:
        if isinstance(entry, str):
            found.append((entry, [], []))
        else:
            found.append((entry["name"], list(entry.get("prepare") or []),
                          list(entry.get("sources") or [])))
    return found


def source_dirs(ip_yaml: Path) -> list:
    """Every RTL directory a listed component needs linked into the project
    before its preparatory scripts run, as the build links them."""
    seen = []
    for _, _, dirs in _raw_entries(ip_yaml):
        for d in dirs:
            if d not in seen:
                seen.append(d)
    return seen


def listed(ip_yaml: Path) -> list:
    """The components `verification/ip.yaml` asks to generate."""
    return [name for name, _ in entries(ip_yaml)]


def prepare_scripts(name: str, ip_yaml: Path) -> list:
    return dict(entries(ip_yaml)).get(name, [])


def lock_path(ip_root: Path, name: str) -> Path:
    return ip_root / (name + LOCK_SUFFIX)


def _normalise(text: str) -> str:
    return _VOLATILE.sub("// Created by <normalised>", text)


def uses_hard_macro(path: Path) -> str:
    """What makes this file uncompilable by Verilator, or empty."""
    text = path.read_text(encoding="utf-8", errors="replace")
    if _ENCRYPTED.search(text):
        return "encrypted source"
    match = _INSTANTIATION.search(text)
    return match.group(1) if match else ""


def manifest_sources(core_dir: Path, name: str) -> list:
    """Every HDL source Libero says belongs to this component."""
    manifest = core_dir / ("%s_manifest.txt" % name)
    if not manifest.is_file():
        raise StaleIP(
            "generated core at %s carries no %s. Libero writes one beside "
            "every component it generates, so this output is incomplete "
            "rather than merely old. Regenerate with `make ip`."
            % (core_dir, manifest.name))

    section = _HDL_SECTION.search(manifest.read_text(encoding="utf-8"))
    if not section:
        raise StaleIP(
            "%s lists no HDL source files. Either generation failed part way "
            "or the manifest format has changed; either way the source list "
            "cannot be trusted." % manifest)

    # The manifest records absolute paths in the project that generated it,
    # which is not where the core lives now. Only the tail below the project's
    # `component/` directory is meaningful: most files are under
    # `component/work/<name>/`, and some cores list files from the shared
    # vendor tree, `component/<Vendor>/<Library>/<Core>/<Version>/`. Collection
    # copies each to the same relative path under the component's directory.
    sources = []
    for line in section.group(1).splitlines():
        entry = line.strip()
        if not entry:
            continue
        parts = Path(entry).parts
        if "component" not in parts:
            raise StaleIP(
                "%s lists %s, which is not inside a Libero component tree. "
                "The manifest does not describe this core." % (manifest, entry))
        relative = Path(*parts[len(parts) - 1 - parts[::-1].index("component") + 1:])
        resolved = core_dir / relative
        if not resolved.is_file():
            raise StaleIP(
                "%s lists %s, which is missing from %s. The generated output "
                "is incomplete; regenerate with `make ip`."
                % (manifest.name, relative, core_dir))
        sources.append(resolved)
    return sources


_HDL_SUFFIXES = {".v", ".sv", ".vh", ".svh", ".vhd", ".vhdl"}


def compilable_sources(core_dir: Path, name: str) -> tuple:
    """Sources a software simulator can compile, and those held back.

    Returns `(sources, excluded)` where `excluded` maps a path to the hard
    macro that makes it uncompilable. The caller reports the second rather
    than discarding it: a file silently dropped is a design compiled without a
    block somebody believes is present.
    """
    sources, excluded = [], {}
    for path in manifest_sources(core_dir, name):
        # Libero lists a core's generated reports beside its HDL (COREDDS's
        # `.mon` LUT listings). They are digested with the rest, not compiled.
        if path.suffix.lower() not in _HDL_SUFFIXES:
            continue
        macro = uses_hard_macro(path)
        if macro:
            excluded[path] = macro
        else:
            sources.append(path)
    if not sources:
        raise StaleIP(
            "every source of %s is encrypted or instantiates a hard block, so "
            "none can be compiled by Verilator. This core needs questa, pinned "
            "on the DUT that uses it." % name)
    return sources, excluded


def digest_sources(core_dir: Path, name: str) -> str:
    """Digest of the component's RTL, ignoring generation timestamps."""
    parts = [_normalise(p.read_text(encoding="utf-8", errors="replace"))
             for p in manifest_sources(core_dir, name)]
    return hashlib.sha256("".join(parts).encode("utf-8")).hexdigest()


def digest_definition(definition: Path, prepare=()) -> str:
    """Digest of what a component is generated from.

    For a SmartDesign that includes the scripts run first and the HDL core
    definitions beside them -- their ports and bus interfaces are what the
    wrapper is generated against. Not our RTL itself: that is compiled from
    the repository directly, and a port change breaks the compile loudly.
    """
    h = hashlib.sha256(definition.read_bytes())
    for script in prepare:
        script = Path(script)
        h.update(script.read_bytes())
        for core in sorted((script.parent / "components").glob("*.tcl")):
            h.update(core.read_bytes())
    return h.hexdigest()


def core_id(definition: Path) -> str:
    text = definition.read_text(encoding="utf-8")
    smartdesign = _SMARTDESIGN.search(text)
    if smartdesign:
        return "SmartDesign:%s" % definition.stem
    match = _CORE_ID.search(text)
    if not match:
        raise StaleIP(
            "%s declares no core id. Expected create_and_configure_core "
            "-core_vlnv {Vendor:Library:Core:Version}." % definition)
    return match.group(1)


@dataclass
class Lock:
    """What one generated component was produced from."""

    name: str
    core_id: str
    definition_digest: str
    sources_digest: str
    libero: str
    generated: str

    def write(self, ip_root: Path) -> None:
        ip_root.mkdir(parents=True, exist_ok=True)
        lock_path(ip_root, self.name).write_text(
            json.dumps(self.__dict__, indent=2, sort_keys=True) + "\n",
            encoding="utf-8")

    @classmethod
    def read(cls, ip_root: Path, name: str) -> "Lock":
        path = lock_path(ip_root, name)
        if not path.is_file():
            raise StaleIP(
                "no lockfile at %s, so there is no record of which %s this "
                "programme agreed on and no way to tell whether the generated "
                "one is it. If this is the first generation, `make ip` writes "
                "the lockfile and it should be committed." % (path, name))
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            raise StaleIP("%s is not readable JSON: %s" % (path, exc))
        missing = set(cls.__dataclass_fields__) - set(data)
        if missing:
            raise StaleIP(
                "%s is missing %s. It was written by an older generator; "
                "regenerate with `make ip`."
                % (path, ", ".join(sorted(missing))))
        return cls(**{f: data[f] for f in cls.__dataclass_fields__})


def build(name: str, definition: Path, core_dir: Path, libero: str,
          generated: str, prepare=()) -> Lock:
    """The lock a freshly generated component should carry."""
    return Lock(
        name=name,
        core_id=core_id(definition),
        definition_digest=digest_definition(definition, prepare),
        sources_digest=digest_sources(core_dir, name),
        libero=libero,
        generated=generated,
    )


def verify_one(name: str, definition: Path, ip_root: Path, prepare=()) -> Lock:
    """Confirm one generated component matches its definition, or raise."""
    core_dir = ip_root / name
    if not core_dir.is_dir():
        raise StaleIP(
            "%s is defined in %s but has not been generated. Vendor IP is "
            "proprietary and is not stored in this repository -- only the "
            "digest of it is. Run `make ip`, which needs Libero but not a "
            "synthesis licence." % (name, definition.name))

    lock = Lock.read(ip_root, name)

    wanted = core_id(definition)
    if lock.core_id != wanted:
        raise StaleIP(
            "%s was generated as %s but %s now asks for %s. The design "
            "changed and the IP was not regenerated, so simulation would "
            "compile a core the build does not use. Run `make ip`."
            % (name, lock.core_id, definition.name, wanted))

    if lock.definition_digest != digest_definition(definition, prepare):
        raise StaleIP(
            "%s has changed since %s was generated. The configuration differs "
            "even though the core version does not -- a parameter, a FIFO "
            "depth, a width -- and simulation would compile the old one. Run "
            "`make ip`." % (definition.name, name))

    if lock.sources_digest != digest_sources(core_dir, name):
        raise StaleIP(
            "the generated RTL for %s does not match the digest in %s. Either "
            "it was edited by hand -- generated IP is not a place to make "
            "fixes, change %s instead -- or it was generated by a Libero whose "
            "output differs from the one that wrote the lockfile (%s). The "
            "second is a real finding, not a nuisance: two toolchains "
            "producing different RTL from one definition is worth knowing "
            "about."
            % (name, lock_path(ip_root, name).name, definition.name,
               lock.libero))
    return lock


#: Defaults for the one repository and board this environment verifies.
REPO = Path(__file__).resolve().parents[2]
BOARD = "mpf500ts-fc1152m"
IP_YAML = REPO / "verification" / "ip.yaml"


def verify(ip_root: Path, ip_yaml: Path = IP_YAML, repo: Path = REPO,
           board: str = BOARD) -> dict:
    """Confirm every listed component is generated and current.

    Both directions. A listed component with no generated core is a test
    compiled without a block; a generated core that is not listed is RTL
    nobody asked for, and invites a testbench to compile a core that the
    list -- and so the record of what was verified against -- does not name.
    """
    names = listed(ip_yaml)
    locks = {name: verify_one(name, definition(repo, board, name), ip_root,
                              [repo / p for p in prepare_scripts(name, ip_yaml)])
             for name in names}
    if ip_root.is_dir():
        orphans = sorted(p.name for p in ip_root.iterdir()
                         if p.is_dir() and p.name not in names)
        if orphans:
            raise StaleIP(
                "generated IP not listed in %s: %s. Delete it, or list it."
                % (ip_yaml.name, ", ".join(orphans)))
    return locks


def verify_named(names, ip_root: Path, ip_yaml: Path = IP_YAML,
                 repo: Path = REPO, board: str = BOARD) -> dict:
    """Confirm the components one test compiles are listed, generated and
    current -- and nothing else, so one stale core does not stop an unrelated
    test."""
    wanted = listed(ip_yaml)
    unlisted = [n for n in names if n not in wanted]
    if unlisted:
        raise StaleIP(
            "a test compiles %s, which %s does not list, so `make ip` would "
            "never generate it. Add it there." % (", ".join(unlisted), ip_yaml.name))
    return {name: verify_one(name, definition(repo, board, name), ip_root,
                             [repo / p for p in prepare_scripts(name, ip_yaml)])
            for name in names}
