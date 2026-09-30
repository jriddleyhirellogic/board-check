"""Check registry.

A check is a function `(ctx) -> iterable of Finding` registered with
@check. Each has a stable id (used for waivers and severity overrides), a
default severity, and a one-line title for reports.
"""

from dataclasses import dataclass, field

ERROR, WARNING, INFO = "error", "warning", "info"
SEVERITY_ORDER = {ERROR: 0, WARNING: 1, INFO: 2}


@dataclass
class Finding:
    check: str
    message: str
    severity: str = None          # filled from the check's default if None
    refs: list = field(default_factory=list)      # component designators
    nets: list = field(default_factory=list)
    part_number: str = None
    waived_by: str = None         # waiver reason, when waived

    def to_dict(self):
        d = {"check": self.check, "severity": self.severity, "message": self.message}
        if self.refs:
            d["refs"] = self.refs
        if self.nets:
            d["nets"] = self.nets
        if self.part_number:
            d["part_number"] = self.part_number
        if self.waived_by:
            d["waived_by"] = self.waived_by
        return d


@dataclass
class CheckInfo:
    id: str
    title: str
    severity: str
    func: object
    needs_partsdb: bool = False
    needs_pin_types: bool = False


REGISTRY = {}


def check(check_id, title, severity=WARNING, needs_partsdb=False, needs_pin_types=False):
    def wrap(func):
        REGISTRY[check_id] = CheckInfo(check_id, title, severity, func, needs_partsdb, needs_pin_types)
        return func
    return wrap


class Context:
    def __init__(self, design, config, partsdb=None):
        self.design = design
        self.config = config
        self.partsdb = partsdb

    def kind(self, component):
        return self.config.kind(component)

    def decoded(self, component):
        if self.partsdb is None:
            return None
        return self.partsdb.decode(component.part_number)


def load_all():
    # Importing the modules registers their checks.
    from . import export, nets, parts, pins, power  # noqa: F401
    return REGISTRY
