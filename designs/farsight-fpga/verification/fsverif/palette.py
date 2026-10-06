"""The app's colours (`fsverif.web`, `fsverif.render`) -- and ts-rtl-check's,
so the tools look like one family."""

from __future__ import annotations

BG = "#0e1116"
PANEL = "#141922"
SURFACE = "#1a202b"
SURFACE_HI = "#222a37"
BORDER = "#2a3342"
TEXT = "#e6e9ef"
TEXT_DIM = "#9aa4b2"
TEXT_FAINT = "#6b7585"
ACCENT = "#7c8cff"
ERROR = "#ff5c6c"
WARNING = "#f5b544"
INFO = "#5aa9ff"
OK = "#3ecf8e"
REVIEW = "#c084fc"
UNTRACED = "#a3283a"
NOT_WRITTEN = "#4a5363"
#: A pass qualified by recorded exceptions: green, but not the plain pass.
OK_QUALIFIED = "#8fd9b6"

#: One colour per outcome, verdict, requirement stage, status and severity.
OUTCOME = {"failed": ERROR, "passed": OK, "not run": TEXT_FAINT}
VERDICT = {"REGRESSION": ERROR, "STALE": REVIEW, "SKIPPED": WARNING,
           "known shortfall": WARNING, "passed": OK, "not run": TEXT_FAINT}
STAGE = {"passing": OK, "passing, with exceptions": OK_QUALIFIED, "waived": REVIEW,
         "known shortfall": ERROR, "failing": ERROR,
         "never run": TEXT_FAINT, "not written": NOT_WRITTEN, "elsewhere": INFO,
         "no item": ERROR}
STATUS = {"OK": OK, "GAP": WARNING, "AMBIG": REVIEW, "DEFECT": ERROR}
SEVERITY = {"HIGH": ERROR, "MEDIUM": WARNING, "LOW": INFO, "WITHDRAWN": TEXT_FAINT}
#: A Jama requirement's roll-up over the requirements under it.
TRACE = {"no local requirement": UNTRACED, "failing": ERROR, "partly tested": WARNING,
         "waived": REVIEW, "verified elsewhere": INFO, "passing": OK}



def tint(color: str, alpha: int) -> str:
    """`#rrggbb` as `rgba(...)` with alpha 0-255, for inline styles."""
    c = color.lstrip("#")
    r, g, b = int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16)
    return f"rgba({r}, {g}, {b}, {alpha / 255:.2f})"
