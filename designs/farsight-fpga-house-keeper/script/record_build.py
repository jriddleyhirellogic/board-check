#!/usr/bin/env python3
"""Finish the manifest Libero wrote beside a programming image.

`synth.tcl` records what it knows while the project is open -- the variant,
the commit, whether the tree was clean, the tool version, which pin
constraints were used. It cannot easily digest the image it has just written,
so that is done here.

Why a digest matters: the filename carries the variant and the commit, but a
filename is the one part of a file anybody can change. Four images that
differed only by their parent directory is the state this replaces, and a
manifest that could be produced by renaming is not much better. The digest
ties the manifest to one exact image.

This is also the beginning of what `BUILD-01` asks for. Nothing is retained
from a build today -- no logs, no reports -- so a message that was never
captured cannot be dispositioned. The manifest is where that will go.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

IMAGES = Path("programming_files")


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def complete(manifest: Path) -> bool:
    """Add the image digest to one manifest. True if it was changed."""
    record = json.loads(manifest.read_text(encoding="utf-8"))
    if "image_sha256" in record:
        return False

    image = manifest.with_suffix(".pdb")
    if not image.is_file():
        raise SystemExit(
            "%s describes %s, which is not beside it. A manifest without its "
            "image describes nothing." % (manifest.name, image.name))

    record["image_sha256"] = digest(image)
    record["image_bytes"] = image.stat().st_size
    manifest.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    return True


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--variant", required=True,
                    help="the variant just built, e.g. fm_tmr")
    ap.add_argument("--images", type=Path, default=IMAGES)
    args = ap.parse_args(argv)

    folder = args.images / args.variant
    if not folder.is_dir():
        raise SystemExit(
            "no images at %s. The build did not produce one, or it was filed "
            "somewhere this does not know about." % folder)

    manifests = sorted(folder.glob("*.json"))
    if not manifests:
        raise SystemExit(
            "no manifest in %s. synth.tcl writes one beside every image it "
            "copies, so an image without one was not produced by this flow "
            "and nothing records what it is." % folder)

    changed = [m for m in manifests if complete(m)]
    for m in changed:
        record = json.loads(m.read_text(encoding="utf-8"))
        print("%s  %s  %s  %s"
              % (record["image"], record["variant"], record["commit"],
                 record["image_sha256"][:16]))
        if not record.get("tree_clean", True):
            print("  built from a modified tree -- this image must not be flown")
        if not record.get("tmr", True):
            print("  TMR is not enabled -- this image must not be flown")
    if not changed:
        print("manifests already complete in %s" % folder)
    return 0


if __name__ == "__main__":
    sys.exit(main())
