#!/usr/bin/env python3
"""Generate, collect and check the vendor IP simulation compiles.

    record_ip.py --list                          what Libero sources, typed, in order
    record_ip.py --collect <project>/component   copy out and write lockfiles
    record_ip.py --check                         verify against the locks

`make ip` runs the first to tell Libero what to generate, and the second once
it has; `make ip-check` runs the third on its own. Splitting this out of the
tcl is deliberate: the digest rule is the one the verification environment
checks against, so both read it from `fsverif.ip` rather than each
implementing it and drifting.

Which components: `verification/ip.yaml`. Nothing here names a core.
"""

from __future__ import annotations

import argparse
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from fsverif.ip import (BOARD, IP_YAML, REPO, Lock, StaleIP, build, definition,  # noqa: E402
                        entries, listed, source_dirs, verify, _HDL_SECTION)


def libero_version(libero: str) -> str:
    """Which Libero produced the IP.

    Recorded, not checked against on reuse: two Libero versions can
    legitimately produce identical RTL, and refusing that would block a
    toolchain upgrade for no reason. It is here so that if the RTL ever does
    differ, the report can say which tool produced which. The invocation path
    is read before resolving it, because a symlinked launcher resolves to a
    name that has lost the version.
    """
    for candidate in (Path(libero), Path(libero).resolve()):
        for parent in candidate.parents:
            if parent.name.lower().startswith("libero_"):
                return parent.name
    return Path(libero).name


def collect(component_root: Path, ip_root: Path, names: list) -> None:
    """Copy each component's manifest and HDL sources out of a project.

    Each source is copied to its path below the project's `component/`
    directory, under `<ip_root>/<name>/`, which is where `fsverif.ip` looks
    for it. Only what the manifest lists as HDL source is taken; stimulus and
    constraint files are not compiled into a design and are not collected.
    """
    for name in names:
        work = component_root / "work" / name
        manifest = work / ("%s_manifest.txt" % name)
        if not manifest.is_file():
            raise StaleIP("Libero did not generate %s: no %s in %s"
                          % (name, manifest.name, work))
        target = ip_root / name
        shutil.rmtree(target, ignore_errors=True)
        target.mkdir(parents=True)
        shutil.copy2(manifest, target / manifest.name)
        section = _HDL_SECTION.search(manifest.read_text(encoding="utf-8"))
        if not section:
            raise StaleIP("%s lists no HDL source files" % manifest)
        for line in section.group(1).splitlines():
            entry = line.strip()
            if not entry:
                continue
            parts = Path(entry).parts
            tail = Path(*parts[len(parts) - 1 - parts[::-1].index("component") + 1:])
            source = component_root / tail
            (target / tail).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target / tail)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--ip-root", type=Path, default=REPO / "verification" / "ip")
    ap.add_argument("--ip-yaml", type=Path, default=IP_YAML)
    ap.add_argument("--board", default=BOARD)
    ap.add_argument("--libero", default="libero")
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--list", action="store_true")
    mode.add_argument("--collect", type=Path, metavar="COMPONENT_DIR")
    mode.add_argument("--check", action="store_true")
    args = ap.parse_args(argv)

    try:
        names = listed(args.ip_yaml)
        if args.list:
            # Every script Libero must source, in order: each component's
            # preparatory build scripts once, ahead of the definitions.
            # Typed lines, run in this order by gen_ip.tcl: RTL directories to
            # link (`src`), then the build's scripts (`tcl`), then the
            # definitions (`def`) -- a definition a build script has already
            # sourced is skipped there, not created twice.
            for d in source_dirs(args.ip_yaml):
                print("src %s" % (REPO / d))
            seen = []
            for _, prepare in entries(args.ip_yaml):
                for script in prepare:
                    if script not in seen:
                        seen.append(script)
            for script in seen:
                print("tcl %s" % (REPO / script))
            for name in names:
                print("def %s" % definition(REPO, args.board, name))
            return 0

        if args.check:
            locks = verify(args.ip_root, args.ip_yaml, REPO, args.board)
            for name, lock in sorted(locks.items()):
                print("%-32s current  %s  sources %s"
                      % (name, lock.core_id, lock.sources_digest[:16]))
            if not locks:
                print("no components listed in %s" % args.ip_yaml.name)
            return 0

        collect(args.collect, args.ip_root, names)
        stamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        for name, prepare in entries(args.ip_yaml):
            lock = build(name, definition(REPO, args.board, name),
                         args.ip_root / name, libero_version(args.libero), stamp,
                         [REPO / p for p in prepare])
            # Regenerated identically: the committed lockfile stands, rather
            # than a new timestamp making a diff that records nothing.
            try:
                old = Lock.read(args.ip_root, name)
            except StaleIP:
                old = None
            if old is not None and dict(old.__dict__, generated=stamp) == lock.__dict__:
                lock = old
            else:
                lock.write(args.ip_root)
            print("%-32s %s  definition %s  sources %s"
                  % (name, lock.core_id, lock.definition_digest[:16],
                     lock.sources_digest[:16]))
        return 0
    except StaleIP as exc:
        print("STALE IP: %s" % exc, file=sys.stderr)
        return 1
    except OSError as exc:
        print("cannot collect IP: %s" % exc, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
