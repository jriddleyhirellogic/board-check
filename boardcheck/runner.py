"""Run the registered checks and apply severity overrides and waivers."""

import fnmatch

from .checks import INFO, REGISTRY, SEVERITY_ORDER, Context, Finding, load_all


class Result:
    def __init__(self, findings, skipped, unused_waivers, ctx):
        self.findings = findings            # active and waived, sorted
        self.skipped = skipped              # [(check id, reason)]
        self.unused_waivers = unused_waivers
        self.ctx = ctx

    @property
    def active(self):
        return [f for f in self.findings if not f.waived_by]

    @property
    def waived(self):
        return [f for f in self.findings if f.waived_by]

    def count(self, severity):
        return sum(1 for f in self.active if f.severity == severity)

    def fails(self, fail_on):
        if fail_on == "never":
            return False
        limit = SEVERITY_ORDER[fail_on]
        return any(SEVERITY_ORDER[f.severity] <= limit for f in self.active)


def _waiver_matches(waiver, finding):
    if waiver.get("check") and not fnmatch.fnmatch(finding.check, waiver["check"]):
        return False
    if "ref" in waiver and not any(fnmatch.fnmatch(r, waiver["ref"]) for r in finding.refs):
        return False
    if "net" in waiver and not any(fnmatch.fnmatch(n, waiver["net"]) for n in finding.nets):
        return False
    if "part_number" in waiver and not fnmatch.fnmatch(finding.part_number or "", waiver["part_number"]):
        return False
    if "match" in waiver and waiver["match"] not in finding.message:
        return False
    return True


def run(design, config, partsdb=None, only=None):
    load_all()
    ctx = Context(design, config, partsdb)
    disabled = set(config["disabled"])
    overrides = config["severity"]
    findings, skipped = [], []
    for check_id, info in sorted(REGISTRY.items()):
        if only and check_id not in only:
            continue
        if check_id in disabled:
            skipped.append((check_id, "disabled in config"))
            continue
        if info.needs_partsdb and partsdb is None:
            skipped.append((check_id, "electronic-parts-repository not installed"))
            continue
        for f in info.func(ctx):
            f.severity = overrides.get(check_id) or f.severity or info.severity
            findings.append(f)

    waivers = config["waivers"]
    used = set()
    for f in findings:
        for i, w in enumerate(waivers):
            if _waiver_matches(w, f):
                f.waived_by = w.get("reason") or "(no reason given)"
                used.add(i)
                break
    unused = [w for i, w in enumerate(waivers) if i not in used]
    for w in unused:
        findings.append(Finding("CFG001", f"waiver matched nothing, remove it or fix it: {w}", severity=INFO))

    findings.sort(key=lambda f: (SEVERITY_ORDER[f.severity], f.check, f.message))
    return Result(findings, skipped, unused, ctx)
