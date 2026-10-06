"""The four build variants stay distinct, and stay selectable without patching.

A variant used to be produced by editing tracked source for the duration of a
Libero run: `sed` on `src/top.sv` for TMR and on the pin constraints for the
pinout, restored afterwards. The image recorded `git rev-parse HEAD`, which
describes the *committed* tree, so three of the four images carried an
identifier pointing at source that does not build them.

Nothing is patched now. TMR comes from a generated `src/build_variant.vh` and
the pinout from `constr/<board>/io/<fm|em>/`. These tests hold that in place,
because the failure mode is silent: if the variant mechanism stops working,
every build still succeeds and every image still appears -- they are just all
the same one, and nothing says so.

No simulation, so these cost nothing.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO / "script"))

import build_variant  # noqa: E402

BOARD = "a3pe3000l-fg484m"
IO = REPO / "constr" / BOARD / "io"
TOP = REPO / "src" / "top.sv"

#: The only two assignments that may differ between the pinouts. They are the
#: RS-422 pair to the PolarFire, swapped between the two boards -- an image
#: built with the wrong one has a dead command link and sends the housekeeper
#: failure broadcast out of the wrong pin, which is the one diagnostic that
#: exists when the PolarFire is down.
PINOUT_SIGNALS = ("rs422_ttl_bus_to_farsight_pa3", "rs422_ttl_farsight_to_bus_pa3")

SET_IO = re.compile(r"set_io\s*\{(\w+)\}\s*-pinname\s*\"(\w+)\"")


def assignments(path: Path) -> dict:
    return {sig: ball for sig, ball in SET_IO.findall(
        path.read_text(encoding="utf-8"))}


def test_the_pinouts_differ_only_in_the_rs422_pair():
    """Two committed files, so they can drift. This is what stops them.

    Duplicating 108 pin assignments is the price of not editing a tracked file
    at build time. The duplication is only safe while something checks it: a
    power enable that moved in one file and not the other would put the
    housekeeper's outputs on the wrong balls in one of the two images, and
    nothing else in this repository would notice.
    """
    fm = assignments(IO / "fm" / "io_constraints.pdc")
    em = assignments(IO / "em" / "io_constraints.pdc")

    assert set(fm) == set(em), (
        "the two pinouts assign different sets of signals, so one image has "
        "pins the other does not: only in fm %s; only in em %s"
        % (sorted(set(fm) - set(em)), sorted(set(em) - set(fm))))

    differ = {sig for sig in fm if fm[sig] != em[sig]}
    assert differ == set(PINOUT_SIGNALS), (
        "the pinouts differ in %s, but the only difference between the FM and "
        "EM boards is the RS-422 pair %s. Anything else is drift between two "
        "files that are meant to be the same design."
        % (sorted(differ), sorted(PINOUT_SIGNALS)))


def test_the_rs422_pair_is_actually_swapped():
    """And differ in the right direction -- not merely differ.

    Without this the previous test passes if both files are wrong in the same
    two places.
    """
    fm = assignments(IO / "fm" / "io_constraints.pdc")
    em = assignments(IO / "em" / "io_constraints.pdc")
    rx, tx = PINOUT_SIGNALS
    assert (fm[rx], fm[tx]) == (em[tx], em[rx]), (
        "the RS-422 pair is not a swap between the two pinouts: "
        "fm has %s=%s %s=%s, em has %s=%s %s=%s"
        % (rx, fm[rx], tx, fm[tx], rx, em[rx], tx, em[tx]))


@pytest.mark.parametrize("variant,tmr", sorted(build_variant.VARIANTS.items()))
def test_the_variant_selects_tmr(variant, tmr):
    defined = "\n`define TMR" in build_variant.contents(variant)
    assert defined == tmr, (
        "variant %s should have TMR %s and the generated include says "
        "otherwise. Every build would still succeed; the images would just "
        "all be the same one."
        % (variant, "enabled" if tmr else "disabled"))


def test_top_does_not_define_tmr_itself():
    """The regression that would silently disable the whole mechanism.

    If `` `define TMR `` returns to `src/top.sv`, every variant is a TMR
    variant, `make no-tmr` quietly produces a TMR image, and nothing fails.
    """
    source = TOP.read_text(encoding="utf-8")
    stray = [line for line in source.splitlines()
             if re.match(r"\s*`define\s+TMR\b", line)]
    assert not stray, (
        "src/top.sv defines TMR itself, so the generated include cannot "
        "select it and every variant is a TMR build: %s" % stray)
    assert '`include "build_variant.vh"' in source, (
        "src/top.sv does not include build_variant.vh, so nothing selects "
        "TMR and the variant passed to the build has no effect on the image")
