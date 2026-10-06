#!/usr/bin/env python3
"""Record or check what the design's generated IP was generated from.

    record_ip.py --definitions bd/<board>/components --ip-root verification/ip
    record_ip.py --check --definitions ... --ip-root ...

Run by `make ip` immediately after Libero writes the cores, and by `make
ip-check` on its own. Splitting it out of the tcl is deliberate: the digest
rule is the same one the verification environment checks against, so both read
it from `fsverif.ip` rather than each implementing it and drifting.

Nothing here names a core. Components come from the definitions directory.
"""

from __future__ import annotations

import argparse
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from fsverif.ip import StaleIP, build, components, verify


def libero_version(libero: str) -> str:
    """Which Libero produced the IP.

    Recorded, not checked against on reuse: two Libero versions can
    legitimately produce identical RTL, and refusing that would block a
    toolchain upgrade for no reason. It is here so that if the RTL ever does
    differ, the report can say which tool produced which.

    The invocation path is read before resolving it. On this machine
    /opt/microchip/Libero_v11.9/.../libero is a symlink to a wrapper called
    libero119 elsewhere, so resolving first throws the version away.
    """
    for candidate in (Path(libero), Path(libero).resolve()):
        for parent in candidate.parents:
            if parent.name.lower().startswith("libero_"):
                return parent.name
    return Path(libero).name


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--definitions", type=Path, required=True,
                    help="directory of component definitions (*.tcl)")
    ap.add_argument("--ip-root", type=Path, required=True,
                    help="directory holding generated components and locks")
    ap.add_argument("--libero", default="libero")
    ap.add_argument("--check", action="store_true",
                    help="verify against the committed locks, writing nothing")
    args = ap.parse_args(argv)

    if args.check:
        try:
            locks = verify(args.definitions, args.ip_root)
        except StaleIP as exc:
            print("STALE IP: %s" % exc, file=sys.stderr)
            return 1
        for name, lock in sorted(locks.items()):
            print("%-12s current  %s  sources %s"
                  % (name, lock.core_id, lock.sources_digest[:16]))
        return 0

    try:
        defined = components(args.definitions)
        stamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        for name, definition in sorted(defined.items()):
            lock = build(name, definition, args.ip_root / name,
                         libero_version(args.libero), stamp)
            lock.write(args.ip_root)
            print("%-12s %s" % (name, lock.core_id))
            print("%-12s definition %s  sources %s"
                  % ("", lock.definition_digest[:16],
                     lock.sources_digest[:16]))
    except (StaleIP, OSError) as exc:
        print("cannot record IP locks: %s" % exc, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
