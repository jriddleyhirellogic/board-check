"""What makes this repository's verification its own: the names and labels the
shared tooling shows. The app's browser files (`fsverif/web/static/`) carry
none of it -- the server sends `ui()` -- so they are the same file in every
repository that has the app, and can be compared with `diff`."""

from __future__ import annotations

#: "PolarFire FPGA verification", in the page title and the report headings.
NAME = "PolarFire FPGA"
#: "Where the PolarFire FPGA's verification stands".
POSSESSIVE = "the PolarFire FPGA's"
#: "a PF FPGA requirement", and "PF reqs" as a column heading.
REQUIREMENT_NOUN = "PF FPGA"
REQUIREMENT_SHORT = "PF"
#: The Jama requirements allocated to this design as a whole.
ALLOCATED_PREFIX = "FAR-CDH_FPGA_"
ALLOCATED_LABEL = "FAR-CDH_FPGA L3"
#: What a requirement's `pending` flag means here (`fsverif.evidence.PENDING`).
PENDING = {
    "pill": "TBR",
    "filter": "A value still TBR",
    "heading": "Values still TBR",
    "note": "Requirements stating a value still to be reviewed (TBR). Revisit each "
            "when the value is confirmed.",
}


def ui() -> dict:
    return {"name": NAME, "possessive": POSSESSIVE, "requirementNoun": REQUIREMENT_NOUN,
            "requirementShort": REQUIREMENT_SHORT, "allocatedPrefix": ALLOCATED_PREFIX,
            "allocatedLabel": ALLOCATED_LABEL, "pending": PENDING}
