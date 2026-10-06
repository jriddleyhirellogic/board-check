"""How much of the design the test harness can see, and what it costs.

cocotb reaches into the simulation over VPI, and Verilator has to be told
which signals to keep addressable. Telling it *all of them* --
`--public-flat-rw`, which cocotb's runner adds by default -- blocks most of
its optimisation. Measured on the PA3 housekeeper design, where this was
written: a factor of 11.7 between every signal public and only the ports.

cocotb's own documentation says as much: *"You may want to add
`--public-flat-rw` to make all signals in the design accessible over the VPI;
however, there is a performance penalty in doing so."*

So visibility is a choice, not a constant:

| `FSVERIF_VISIBILITY` | What is addressable | For |
| --- | --- | --- |
| `pins` (default) | the DUT's ports only | every normal run |
| `depth:N` | everything down to module depth N | narrowing a failure |
| `all` | every signal in the design | debugging one test |

**Visibility changes what can be observed, not what is computed.** A test that
passes at `pins` and fails at `all` has not been made to fail by the setting;
something else is wrong, and that is worth knowing rather than shrugging at.

**A build is keyed by its visibility.** Without that, running lean, hitting a
failure, and rerunning with `FSVERIF_VISIBILITY=all` would silently reuse the
lean build and show nothing -- a debugging session that starts by lying.

**Waves are a separate axis, and usually the better first move.** `WAVES=1`
dumps internal signals to a trace file regardless of visibility, because
Verilator's tracing does not go through VPI. Reach for `all` when a test needs
to *interact* with something internal; reach for waves when it needs to *see*
what happened.
"""

from __future__ import annotations

import os
import re
from pathlib import Path

#: Everything the DUT exposes at its ports; nothing inside it.
PINS = "pins"

#: Every signal, as cocotb's runner does by default.
ALL = "all"

_DEPTH = re.compile(r"^depth:(\d+)$")

ENV = "FSVERIF_VISIBILITY"


class VisibilityError(Exception):
    """The requested visibility is not one this environment understands."""


def requested() -> str:
    """The visibility this run asked for."""
    value = os.environ.get(ENV, PINS).strip().lower()
    if value in (PINS, ALL) or _DEPTH.match(value):
        return value
    raise VisibilityError(
        "%s=%r is not understood. Use %r for normal runs, %r to debug one "
        "test, or 'depth:N' to open up the first N levels of hierarchy."
        % (ENV, value, PINS, ALL))


def build_args(visibility: str) -> list:
    """Verilator arguments for this visibility.

    `pins` contributes nothing here: the ports are made public by a generated
    config file instead, so that no attribute has to be written into the
    design. A flight build must not carry constructs whose purpose is to
    support test, and a `public_flat_rw` attribute in the RTL would be one.
    """
    if visibility == PINS:
        return []
    if visibility == ALL:
        return ["--public-flat-rw"]
    depth = _DEPTH.match(visibility)
    return ["--public-depth", depth.group(1)]


def config_file(into: Path, module: str, signals, internal=()) -> Path:
    """Write the Verilator config that makes `signals` addressable.

    A config file rather than source attributes, for the same reason the
    wrapper is generated: the design must not carry anything that exists for
    the benefit of a test. `internal` adds `(module, signal)` pairs inside
    the design, for a test that has said why it needs them.
    """
    into.mkdir(parents=True, exist_ok=True)
    target = into / "public.vlt"
    lines = ["`verilator_config",
             "// GENERATED -- the signals cocotb is allowed to reach.",
             "// Everything else stays private, which is what makes the",
             "// simulation roughly ten times faster.",
             ""]
    lines += ['public_flat_rw -module "%s" -var "%s"' % (module, name)
              for name in signals]
    lines += ['public_flat_rw -module "%s" -var "%s"' % pair for pair in internal]
    fresh = "\n".join(lines) + "\n"
    # Written only when it differs, so an unchanged config does not move its
    # timestamp and force the whole device to rebuild.
    if not target.is_file() or target.read_text(encoding="utf-8") != fresh:
        target.write_text(fresh, encoding="utf-8")
    return target
