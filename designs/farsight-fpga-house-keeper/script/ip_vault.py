#!/usr/bin/env python3
"""Check that Libero can find every core the component definitions ask for.

Libero generates a DirectCore from its IP *vault*, and where that vault is lives
in a per-user file outside this repository: `~/.actel/ipmgr.ini`. Two machines
with the same Libero and the same checkout can therefore disagree about whether
`make ip` works, and the one that fails says only

    Cannot find Spirit core configuration file for vendor:Actel
    library:DirectCore name:COREUART version:5.7.100.

from inside a half-built scratch project, which does not say where it looked or
where the core might be.

This runs before Libero does. It reads the cores each definition requires, the
vaults Libero is configured to use, and looks for each core in them. When one
is missing it searches the usual install locations for a vault that has it and
prints the line to change.

It does not change the setting itself. `ipmgr.ini` is Libero's own
configuration and is shared with every other project on the machine, so moving
it is the developer's decision.

Exit status: 0 every core found, 1 a core missing, 2 could not tell. Only 1
stops the build -- when this cannot work out the vault configuration it says so
and lets Libero try, rather than blocking a setup that may be perfectly fine.
"""

from __future__ import annotations

import argparse
import glob
import os
import re
import sys
from pathlib import Path

#: `create_design -id {Vendor:Library:Name:Version}` in a component definition.
CORE_ID = re.compile(r"create_design\s+-id\s+\{([^}]+)\}")

#: Where to look for a vault. Searched by what a vault *contains* -- a
#: `Components/<vendor>` tree -- not by what it is called. The Libero search
#: made the naming mistake first: a list of guessed directory names missed the
#: first install nobody had guessed for, and vault directories are named even
#: less consistently (`vault`, `megavault`, `Libero_SoC_v2024.1_MegaVault`...).
ROOTS = ("/opt", "/usr/local", "~", "~/.actel", "~/.microsemi", "~/.microchip")

#: How far below each root a vault may sit. Three levels covers
#: /opt/<vendor>/<install>/vault and the MegaVault's nested directory without
#: walking the whole of /opt.
DEPTH = 3


def required(definitions: Path) -> list:
    """Every core the component definitions instantiate, as VLNV strings."""
    cores = []
    for definition in sorted(definitions.glob("*.tcl")):
        cores.extend(CORE_ID.findall(definition.read_text(encoding="utf-8")))
    return cores


def configured(ini: Path) -> list:
    """Vault locations Libero is configured to use, from ipmgr.ini."""
    if not ini.is_file():
        return []
    vaults = []
    in_section = False
    for line in ini.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if line.startswith("["):
            in_section = line.upper() == "[VAULTS]"
        elif in_section and line.upper().startswith("LOCATION") and "=" in line:
            vaults.append(Path(line.split("=", 1)[1].strip()))
    return vaults


def has(vault: Path, vlnv: str) -> bool:
    """Whether a vault holds a core, by the layout Libero uses."""
    parts = vlnv.split(":")
    if len(parts) != 4:
        return False
    vendor, library, name, version = parts
    return (vault / "Components" / vendor / library / name / version).is_dir()


def candidates() -> list:
    """Every directory on this machine that is laid out like a Libero vault."""
    found = []
    for root in ROOTS:
        base = Path(os.path.expanduser(root))
        for depth in range(DEPTH + 1):
            pattern = os.path.join(str(base), *(["*"] * depth), "Components")
            for match in sorted(glob.glob(pattern)):
                vault = Path(match).parent
                vendors = [d for d in Path(match).iterdir() if d.is_dir()] \
                    if Path(match).is_dir() else []
                if vendors and vault not in found:
                    found.append(vault)
    return found


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--definitions", type=Path, required=True)
    ap.add_argument("--ini", type=Path,
                    default=Path.home() / ".actel" / "ipmgr.ini")
    args = ap.parse_args(argv)

    cores = required(args.definitions)
    if not cores:
        return 0

    vaults = configured(args.ini)
    if not vaults:
        # Libero is using whatever its built-in default is. That default is not
        # documented and differs between installs, so rather than guess, check
        # the obvious candidates and only object if none of them has the core.
        defaults = [p for p in candidates() if "MegaVault" not in str(p)
                    and "megavault" not in str(p)]
        if any(all(has(v, c) for c in cores) for v in defaults):
            return 0
        print("Libero has no vault configured in %s, so it is using its "
              "default, and no default vault on this machine holds:" % args.ini)
    else:
        missing = [c for c in cores if not any(has(v, c) for v in vaults)]
        # Libero 11.9 will not use a vault it cannot write to. It falls back
        # to ~/.actel/vault without saying so, and then reports the core as
        # missing even though the configured vault holds it.
        readonly = [v for v in vaults if v.is_dir()
                    and not (os.access(v, os.W_OK)
                             and os.access(v / "index.xml", os.W_OK))]
        if not missing and readonly:
            print("Libero's configured IP vault holds every core this design")
            print("needs, but Libero 11.9 will not use a vault you cannot")
            print("write to. It falls back to ~/.actel/vault and then reports")
            print("\"Cannot find Spirit core configuration file\".")
            print("")
            for vault in readonly:
                print("    %s   (not writable by you)" % vault)
            print("")
            print("Make it writable, or copy it somewhere you own and point")
            print("%s at the copy." % args.ini)
            return 1
        if not missing:
            return 0
        cores = missing
        print("Libero's IP vault does not hold every core this design needs.")
        print("")
        print("Configured in %s:" % args.ini)
        for vault in vaults:
            state = "" if vault.is_dir() else "   (does not exist)"
            print("    %s%s" % (vault, state))
        print("")
        print("Missing:")

    for core in cores:
        print("    %s" % core)
    print("")

    usable = [v for v in candidates() if all(has(v, c) for c in cores)]
    if usable:
        print("Found on this machine in:")
        for vault in usable:
            print("    %s" % vault)
        print("")
        print("Point Libero at it. This is Libero's own setting, shared by every")
        print("project on this machine, so it is yours to change rather than")
        print("something `make` does behind your back:")
        print("")
        if args.ini.is_file() and vaults:
            # Edit the one line. The file may carry other settings, and
            # rewriting it whole would lose them.
            print("    sed -i '/^\\[VAULTS\\]/,/^\\[/ s|^LOCATION=.*|LOCATION=%s|' %s"
                  % (usable[0], args.ini))
        else:
            print("    mkdir -p %s" % args.ini.parent)
            print("    printf '[VAULTS]\\nLOCATION=%s\\n' >> %s"
                  % (usable[0], args.ini))
        print("")
        print("That vault has the exact version this design asks for, and")
        print("`make ip` checks the generated RTL against the committed digest,")
        print("so a core that came out different would be refused, not used.")
    else:
        print("No vault on this machine holds them. Either download the core")
        print("into Libero's vault through the Catalog, install the MegaVault,")
        print("or take the generated IP from a machine that has it:")
        print("")
        print("    make ip-import FROM=<host>:<checkout>/verification/ip")
    return 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:  # noqa: BLE001 -- a check that cannot run must not block
        print("Could not check Libero's IP vault (%s); letting Libero try." % exc,
              file=sys.stderr)
        sys.exit(2)
