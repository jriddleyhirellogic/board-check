#!/usr/bin/env python3
"""Apply the timing values in timing.txt to the power sequencing RTL.

Reads timing.txt (values in microseconds) and rewrites the matching
`localparam ... = WAIT_TIME_MULT_FACTOR*<value>;` lines in src/*.sv.

Run directly, or via `make timing`. The build runs it automatically.
"""

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
TIMING_FILE = Path(__file__).resolve().parent / "timing.txt"
SRC_DIR = REPO_ROOT / "src"

# localparam logic [31:0] NAME  = WAIT_TIME_MULT_FACTOR*25000; //optional comment
PARAM_RE = re.compile(
    r"^(?P<head>\s*localparam\s+logic\s*\[31:0\]\s+(?P<name>\w+)\s*=\s*"
    r"WAIT_TIME_MULT_FACTOR\s*\*\s*)(?P<value>[0-9_]+)\s*;.*$"
)

SETTING_RE = re.compile(r"^\s*(?P<name>\w+)\s*=\s*(?P<value>[0-9_,]+)\s*$")


def read_timing(path):
    """Parse the plain text timing file into {NAME: microseconds}."""
    settings = {}
    for lineno, raw in enumerate(path.read_text().splitlines(), start=1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        match = SETTING_RE.match(line)
        if not match:
            sys.exit(
                f"{path.name}:{lineno}: cannot understand '{raw.strip()}'. "
                f"Expected a line like 'FPGA_1V0_WAIT_TIME = 25000'."
            )
        name = match.group("name")
        if name in settings:
            sys.exit(f"{path.name}:{lineno}: '{name}' is listed more than once.")
        value = int(match.group("value").replace("_", "").replace(",", ""))
        if value <= 0:
            sys.exit(f"{path.name}:{lineno}: '{name}' must be greater than 0.")
        settings[name] = value
    return settings


def format_us(value):
    """Render microseconds with underscores, e.g. 200000 -> 200_000."""
    return f"{value:,}".replace(",", "_")


def describe(value):
    """Human readable form of a microsecond value for the RTL comment."""
    if value >= 1_000_000 and value % 1_000_000 == 0:
        return f"{value // 1_000_000} s"
    if value >= 1_000 and value % 1_000 == 0:
        return f"{value // 1_000} ms"
    return f"{value} us"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="report whether the RTL is up to date without writing anything",
    )
    args = parser.parse_args()

    if not TIMING_FILE.exists():
        sys.exit(f"ERROR: {TIMING_FILE} not found.")

    settings = read_timing(TIMING_FILE)
    seen = set()
    updates = []
    pending = {}

    for sv_file in sorted(SRC_DIR.glob("*.sv")):
        lines = sv_file.read_text().splitlines(keepends=True)
        changed = False

        for index, line in enumerate(lines):
            match = PARAM_RE.match(line.rstrip("\n"))
            if not match:
                continue

            name = match.group("name")
            seen.add(name)
            if name not in settings:
                sys.exit(
                    f"ERROR: {sv_file.name} defines '{name}' but it is missing "
                    f"from {TIMING_FILE.name}. Add a line for it."
                )

            value = settings[name]
            old = int(match.group("value").replace("_", ""))
            new_line = (
                f"{match.group('head')}{format_us(value)};"
                f" //{describe(value)} - set in {TIMING_FILE.name}\n"
            )
            if new_line != line:
                lines[index] = new_line
                changed = True
            if old != value:
                updates.append(
                    f"  {name}: {format_us(old)} us -> {format_us(value)} us"
                    f" ({describe(value)})"
                )

        if changed:
            pending[sv_file] = "".join(lines)

    unknown = sorted(set(settings) - seen)
    if unknown:
        sys.exit(
            f"ERROR: {TIMING_FILE.name} lists names that do not exist in the "
            f"RTL: {', '.join(unknown)}"
        )

    if args.check:
        if pending:
            print("RTL is out of date with timing.txt. Run 'make timing'.")
            return 1
        print("RTL matches timing.txt.")
        return 0

    for sv_file, text in pending.items():
        sv_file.write_text(text)

    if updates:
        print(f"Applied {TIMING_FILE.name}:")
        print("\n".join(updates))
    elif pending:
        print(f"Applied {TIMING_FILE.name} (formatting only).")
    else:
        print(f"{TIMING_FILE.name}: no changes, RTL already up to date.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
