"""Command line: python -m boardcheck <export.json> [options]."""

import argparse
import sys

from . import report
from .checks import load_all
from .config import Config
from .model import Design
from .partsdb import PartsDB
from .runner import run


def main(argv=None):
    ap = argparse.ArgumentParser(prog="boardcheck", description="Automated checks on an Altium schematic JSON export.")
    ap.add_argument("export", nargs="?", help="JSON file written by ExportAllSchematicsToJSON")
    ap.add_argument("-c", "--config", help="YAML config (rail voltages, derating, waivers)")
    ap.add_argument("-f", "--format", choices=["text", "markdown", "json"], default="text")
    ap.add_argument("-o", "--output", help="write the report here instead of stdout")
    ap.add_argument("--fail-on", choices=["error", "warning", "info", "never"], default="error",
                    help="exit 1 when an unwaived finding at or above this severity exists (default: error)")
    ap.add_argument("--no-partsdb", action="store_true", help="do not use electronic-parts-repository")
    ap.add_argument("--only", help="comma-separated check ids to run")
    ap.add_argument("--list-checks", action="store_true", help="list available checks and exit")
    args = ap.parse_args(argv)

    if args.list_checks:
        for check_id, info in sorted(load_all().items()):
            extra = " (needs electronic-parts-repository)" if info.needs_partsdb else ""
            print(f"{check_id}  {info.severity:<7}  {info.title}{extra}")
        return 0
    if not args.export:
        ap.error("the export JSON path is required")

    design = Design.load(args.export)
    config = Config.load(args.config)
    partsdb = None if args.no_partsdb else PartsDB.open()
    only = set(args.only.split(",")) if args.only else None
    result = run(design, config, partsdb, only)

    rendered = {"text": report.text, "markdown": report.markdown, "json": report.as_json}[args.format](result)
    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(rendered)
        sys.stdout.write(report.text(result).splitlines()[-1] + f"  -> {args.output}\n")
    else:
        sys.stdout.write(rendered)
    return 1 if result.fails(args.fail_on) else 0


if __name__ == "__main__":
    sys.exit(main())
