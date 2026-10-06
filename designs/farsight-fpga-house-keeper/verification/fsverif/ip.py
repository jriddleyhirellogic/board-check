"""Is the generated IP still the IP the design asks for?

The design instantiates vendor cores that Libero generates from component
definitions in `bd/<board>/components/`. That generated RTL is what both
synthesis and simulation compile, so verification depends on files nobody
wrote and nothing in the repository reproduces on demand -- exactly the kind
of input that goes stale quietly.

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

**Nothing here names a particular core.** Components are discovered from the
definitions directory, and each one's sources are read from the manifest
Libero writes beside it. Dropping a new `*.tcl` into `bd/<board>/components/`
is all that is needed for the next `make ip` to pick it up.

**Generation is deterministic apart from a timestamp.** Three builds of one
commit produced byte-identical vendor sources and differed only in a
`// Created by ...` comment. So digests are taken over normalised text:
without that, every regeneration would look like a change and the check would
be switched off within a week.
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
#: `Vendor:Library:Core:Version`.
_CORE_ID = re.compile(r"-id\s*\{([^}]+)\}")

#: Device hard macros a software simulator has no models for. A generated file
#: instantiating one cannot be compiled by Verilator, and is held back with
#: the reason reported rather than silently dropped.
#:
#: Detected rather than listed by filename, so a newly added core needs no
#: entry here. Where a design genuinely uses such a block, elaboration fails
#: with a missing module and the report says which file was held back and why
#: -- the signal to pin that DUT to Icarus or Questa, both of which compile
#: the ProASIC3 library cleanly.
HARD_MACROS = ("FIFO4K18", "RAM4K9", "RAM512X18", "RAM64x18")

_INSTANTIATION = re.compile(
    r"^\s*(%s)\s+(?:#\s*\([^)]*\)\s*)?\w+\s*\(" % "|".join(HARD_MACROS), re.M)

LOCK_SUFFIX = ".lock.json"


class StaleIP(Exception):
    """Generated IP is missing, incomplete, or not what the design specifies."""


def components(definitions_dir: Path) -> dict:
    """Every component the design defines, by name.

    The definitions directory is the list. Adding a core is dropping a file
    into it; nothing else needs to know the name.
    """
    if not definitions_dir.is_dir():
        raise StaleIP(
            "no component definitions directory at %s. Simulation compiles "
            "the cores these files specify, so without it there is nothing to "
            "check generated IP against." % definitions_dir)
    found = {p.stem: p for p in sorted(definitions_dir.glob("*.tcl"))}
    if not found:
        raise StaleIP(
            "no component definitions in %s. A design with no vendor IP needs "
            "no generation step; a design with some has lost its definitions."
            % definitions_dir)
    return found


def lock_path(ip_root: Path, name: str) -> Path:
    return ip_root / (name + LOCK_SUFFIX)


def _normalise(text: str) -> str:
    return _VOLATILE.sub("// Created by <normalised>", text)


def uses_hard_macro(path: Path) -> str:
    """The device hard macro this file instantiates, or empty."""
    match = _INSTANTIATION.search(
        path.read_text(encoding="utf-8", errors="replace"))
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

    # The manifest records absolute paths from the machine that generated it,
    # which is not where the core lives now. Only the tail below the component
    # directory is meaningful.
    sources = []
    for line in section.group(1).splitlines():
        entry = line.strip()
        if not entry:
            continue
        parts = Path(entry).parts
        if name not in parts:
            raise StaleIP(
                "%s lists %s, which is not inside the component directory. "
                "The manifest does not describe this core."
                % (manifest, entry))
        relative = Path(*parts[parts.index(name) + 1:])
        resolved = core_dir / relative
        if not resolved.is_file():
            raise StaleIP(
                "%s lists %s, which is missing from %s. The generated output "
                "is incomplete; regenerate with `make ip`."
                % (manifest.name, relative, core_dir))
        sources.append(resolved)
    return sources


def compilable_sources(core_dir: Path, name: str) -> tuple:
    """Sources a software simulator can compile, and those held back.

    Returns `(sources, excluded)` where `excluded` maps a path to the hard
    macro that makes it uncompilable. The caller reports the second rather
    than discarding it: a file silently dropped is a design compiled without a
    block somebody believes is present.
    """
    sources, excluded = [], {}
    for path in manifest_sources(core_dir, name):
        macro = uses_hard_macro(path)
        if macro:
            excluded[path] = macro
        else:
            sources.append(path)
    if not sources:
        raise StaleIP(
            "every source of %s instantiates a device hard macro, so none can "
            "be compiled by a software simulator. This core needs Icarus or "
            "Questa, pinned on the DUT that uses it." % name)
    return sources, excluded


def digest_sources(core_dir: Path, name: str) -> str:
    """Digest of the component's RTL, ignoring generation timestamps."""
    parts = [_normalise(p.read_text(encoding="utf-8", errors="replace"))
             for p in manifest_sources(core_dir, name)]
    return hashlib.sha256("".join(parts).encode("utf-8")).hexdigest()


def digest_definition(definition: Path) -> str:
    return hashlib.sha256(definition.read_bytes()).hexdigest()


def core_id(definition: Path) -> str:
    match = _CORE_ID.search(definition.read_text(encoding="utf-8"))
    if not match:
        raise StaleIP(
            "%s declares no core id. Expected a create_design line carrying "
            "-id {Vendor:Library:Core:Version}." % definition)
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
          generated: str) -> Lock:
    """The lock a freshly generated component should carry."""
    return Lock(
        name=name,
        core_id=core_id(definition),
        definition_digest=digest_definition(definition),
        sources_digest=digest_sources(core_dir, name),
        libero=libero,
        generated=generated,
    )


def verify_one(name: str, definition: Path, ip_root: Path) -> Lock:
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

    if lock.definition_digest != digest_definition(definition):
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


def verify(definitions_dir: Path, ip_root: Path) -> dict:
    """Confirm every defined component is generated and current.

    Both directions. A definition with no generated core is a design compiled
    without a block; a generated core with no definition is RTL nobody asked
    for, and the design that used it is gone.
    """
    defined = components(definitions_dir)
    locks = {name: verify_one(name, path, ip_root)
             for name, path in defined.items()}

    if ip_root.is_dir():
        orphans = sorted(p.name for p in ip_root.iterdir()
                         if p.is_dir() and p.name not in defined)
        if orphans:
            raise StaleIP(
                "generated IP with no component definition: %s. The design "
                "that used it has gone, and leaving it invites a testbench to "
                "compile a core this build does not contain. Delete it, or "
                "restore the definition." % ", ".join(orphans))
    return locks
