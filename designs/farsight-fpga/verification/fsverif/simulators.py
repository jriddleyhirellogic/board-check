"""CLI: report which simulators this environment can actually drive.

    python -m fsverif.simulators

Useful when deciding whether a given machine can run the suite, and for
diagnosing "simulator not found" failures.
"""

from __future__ import annotations

import shutil
import subprocess

from fsverif.sim import KNOWN_SIMULATORS, SIM, available_simulators, simulator_problem

_EXECUTABLES = {
    "verilator": "verilator",
    "icarus": "iverilog",
    "questa": "vsim",
    "nvc": "nvc",
    "dsim": "dsim",
    "xcelium": "xrun",
    "vcs": "vcs",
}

_VERSION_FLAG = {
    "verilator": "--version",
    "icarus": "-V",
    "questa": "-version",
    "nvc": "--version",
}


def _version(executable: str, name: str) -> str:
    flag = _VERSION_FLAG.get(name)
    if not flag:
        return ""
    try:
        out = subprocess.run(
            [executable, flag], capture_output=True, text=True, timeout=30
        )
        first = (out.stdout or out.stderr).strip().splitlines()
        return first[0] if first else ""
    except (OSError, subprocess.SubprocessError):
        return ""


def main() -> int:
    found = available_simulators()
    print(f"Default simulator (SIM): {SIM}\n")
    print(f"{'Simulator':<12} {'Status':<14} Detail")
    print("-" * 78)
    for name in KNOWN_SIMULATORS:
        executable = shutil.which(_EXECUTABLES.get(name, name))
        if not executable:
            print(f"{name:<12} {'not installed':<14} -")
            continue
        problem = simulator_problem(name)
        if problem:
            print(f"{name:<12} {'UNUSABLE':<14} {problem}")
        else:
            print(f"{name:<12} {'available':<14} {_version(executable, name) or executable}")

    print()
    if not found:
        print("No usable simulator found. Run ./verif/setup-tools.sh")
        return 1
    print(f"Usable: {', '.join(found)}")
    if SIM not in found:
        print(f"WARNING: default simulator {SIM!r} is not usable.")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

