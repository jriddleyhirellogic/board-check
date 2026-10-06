"""HTML the app shows: the detail of a test, a requirement, a Jama requirement
or a finding, and the subset of markdown the requirements and findings
documents are written in.

Links inside the app use the `fsv:` scheme -- `fsv:req/PF-UDP-16`,
`fsv:finding/PF-F-28`, `fsv:jama/FAR-CDH_FPGA_L3REQ-20`,
`fsv:test/<module>/<name>` -- which the browser app
follows in its page script (`fsverif/web/static/app.js`).
"""

from __future__ import annotations

import html
import re

from fsverif import palette

# ---- links inside the app

#: `fsv:` links navigate within the app; see `follow` in app.js.
_REF = re.compile(r"(?<![\w/#-])(PF-F-\d+|DRV-PF-\d+|PF-[A-Z]+-\d+|VC-PF-\d+|"
                  r"FAR-[A-Z0-9]+(?:_[A-Z0-9]+)*_L\dREQ-\d+)(?![\w-])")


def ref_link(ident: str) -> str:
    if ident.startswith("FAR-"):
        return f"<a href='fsv:jama/{ident}'>{ident}</a>"
    if ident.startswith("PF-F-"):
        return f"<a href='fsv:finding/{ident}'>{ident}</a>"
    if ident.startswith("VC-"):
        return ident
    return f"<a href='fsv:req/{ident}'>{ident}</a>"


def linkify(escaped: str) -> str:
    """Identifiers in already-escaped text, made into links."""
    return _REF.sub(lambda m: ref_link(m.group(1)), escaped)


def pill(text: str, color: str) -> str:
    return (f"<span style='color:{color}; background:{palette.tint(color, 40)};'>"
            f"&nbsp;{html.escape(text)}&nbsp;</span>")


def _inline(text: str) -> str:
    """Escape, then inline markdown: [text](url), `code`, **bold**, *em*, refs.

    Links first, because their text may itself be code -- the documents write
    [`PF-F-03`](...#pf-f-03) -- and splitting on backticks first breaks them.
    """
    held: list = []

    def hold(markup: str) -> str:
        held.append(markup)
        return f"\x00{len(held) - 1}\x00"

    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)",
                  lambda m: hold(_link(_inline(m.group(1)), m.group(2))), text)
    # Code next, held whole, so that emphasis around it -- the analysis
    # records write **`const_step_fall`:** -- still pairs up.
    text = re.sub(r"`([^`]+)`", lambda m: hold(f"<code>{html.escape(m.group(1))}</code>"), text)
    s = html.escape(text, quote=False)
    s = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", s)
    s = re.sub(r"(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])", r"<i>\1</i>", s)
    s = linkify(s)
    return re.sub(r"\x00(\d+)\x00", lambda m: held[int(m.group(1))], s)


def _link(text: str, url: str) -> str:
    m = re.search(r"#(pf-f-\d+)", url)
    if m:
        return f"<a href='fsv:finding/{m.group(1).upper()}'>{re.sub('<[^>]+>', '', text)}</a>"
    return text


def markdown(md: str) -> str:
    """The subset of markdown the requirements and findings documents use."""
    lines = md.splitlines()
    out, para, i = [], [], 0

    def flush():
        if para:
            out.append(f"<p>{_inline(' '.join(para))}</p>")
            para.clear()

    while i < len(lines):
        line = lines[i]
        s = line.strip()
        if s.startswith("```"):
            flush()
            block = []
            i += 1
            while i < len(lines) and not lines[i].strip().startswith("```"):
                block.append(lines[i])
                i += 1
            out.append(f"<pre>{html.escape(chr(10).join(block))}</pre>")
            i += 1
            continue
        m = re.match(r"^(#{1,4})\s+(.*)$", s)
        if m:
            flush()
            level = min(len(m.group(1)) + 1, 4)
            out.append(f"<h{level}>{_inline(m.group(2))}</h{level}>")
            i += 1
            continue
        if s.startswith("|") and i + 1 < len(lines) and re.match(r"^\|[\s:|-]+\|$", lines[i + 1].strip()):
            flush()
            header = [c.strip() for c in s.strip("|").split("|")]
            rows = []
            i += 2
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append([c.strip() for c in lines[i].strip().strip("|").split("|")])
                i += 1
            head = "".join(f"<th align='left'>{_inline(c)}</th>" for c in header)
            body = "".join("<tr>" + "".join(f"<td>{_inline(c)}</td>" for c in r) + "</tr>"
                           for r in rows)
            out.append(f"<table cellspacing='0'><tr>{head}</tr>{body}</table>")
            continue
        m = re.match(r"^(\s*)([-*]|\d+\.)\s+(.*)$", line)
        if m:
            flush()
            ordered = m.group(2)[0].isdigit()
            items = []
            while i < len(lines):
                m = re.match(r"^(\s*)([-*]|\d+\.)\s+(.*)$", lines[i])
                if m and len(m.group(1)) <= 2:
                    items.append([m.group(3)])
                    i += 1
                elif items and lines[i].startswith("  ") and lines[i].strip():
                    items[-1].append(lines[i].strip())
                    i += 1
                else:
                    break
            tag = "ol" if ordered else "ul"
            out.append(f"<{tag}>" + "".join(f"<li>{_inline(' '.join(it))}</li>" for it in items)
                       + f"</{tag}>")
            continue
        if not s or s == "---":
            flush()
        else:
            para.append(s)
        i += 1
    flush()
    return "\n".join(out)




# ---- small pieces

VERDICT_LABEL = {"REGRESSION": "Regression", "STALE": "Stale", "SKIPPED": "Skipped",
                 "known shortfall": "Known shortfall", "passed": "Passing",
                 "not run": "Not run"}


def esc(text) -> str:
    return html.escape(str(text or ""))


def verdict_pill(verdict: str) -> str:
    return pill(VERDICT_LABEL.get(verdict, verdict),
                palette.VERDICT.get(verdict, palette.TEXT_DIM))


def status_pill(status: str) -> str:
    return pill(status, palette.STATUS.get(status, palette.TEXT_DIM))


def stage_pill(stage: str) -> str:
    from fsverif.results import STAGE_LABEL
    return pill(STAGE_LABEL.get(stage, stage), palette.STAGE.get(stage, palette.TEXT_DIM))


def result_pill(t) -> str:
    """What the test did, and -- only where there is one -- the gate's note:
    `Failing  expected`, `Failing  new failure`, `Passing  item expects a failure`."""
    out = pill(t.outcome_label, palette.OUTCOME.get(t.outcome, palette.TEXT_DIM))
    note = t.gate_note
    if note:
        out += " " + (pill(note, palette.ERROR) if t.blocks else faint(esc(note)))
    return out


def trace_pill(rollup: str) -> str:
    return pill(rollup, palette.TRACE.get(rollup, palette.TEXT_DIM))


def stage_summary(stages: dict) -> str:
    """`3 passing, 1 failing` -- requirement stages, worst first."""
    from fsverif.results import STAGE_LABEL, STAGE_WORST_FIRST
    return ", ".join(f"{stages[s]} {STAGE_LABEL.get(s, s)}"
                     for s in STAGE_WORST_FIRST if stages.get(s))


def severity_pill(sev: str) -> str:
    return pill(sev, palette.SEVERITY.get(sev.upper(), palette.TEXT_DIM))


def pending_pill() -> str:
    from fsverif import project
    return pill(project.PENDING["pill"], palette.REVIEW)


def faint(text: str) -> str:
    return f"<span style='color:{palette.TEXT_FAINT}'>{text}</span>"


def dim(text: str) -> str:
    return f"<span style='color:{palette.TEXT_DIM}'>{text}</span>"


def ago(seconds_since_epoch: float) -> str:
    import time
    if not seconds_since_epoch:
        return "never"
    d = time.time() - seconds_since_epoch
    if d < 90:
        return "just now"
    if d < 5400:
        return f"{int(d // 60)} min ago"
    if d < 172800:
        return f"{int(d // 3600)} h ago"
    return f"{int(d // 86400)} days ago"


def secs(s: float) -> str:
    if s <= 0:
        return ""
    if s < 90:
        return f"{s:.0f} s"
    return f"{s / 60:.1f} min"


def plain(subject: str) -> str:
    return subject.replace("*", "").replace("\u2014", "--")


# ---- the three detail views

VERDICT_NOTE = {
    "REGRESSION": "Failing, and its item does not expect it to: a new failure. "
                  "This blocks a merge.",
    "STALE": "Passing, but its item still says it is expected to fail. If the "
             "problem is fixed, update the item and the requirement's status, and "
             "remove any waiver; until then this blocks a merge.",
    "SKIPPED": "Skipped, so there is no result. A skipped requirement test blocks a merge.",
    "known shortfall": "Failing, as expected: the requirement is already recorded as "
                       "not met, so this does not block a merge.",
    "passed": "Passing: it ran and met its criterion.",
    "not run": "No result: the test exists and did not report. Run it. A run that leaves a "
               "test with no result blocks a merge.",
}


def test_html(run, t) -> str:
    """A test: verdict, failure, what it measured, requirements, items."""
    from fsverif.results import test_line
    parts = [f"<h2 class='mono'>{esc(t.name)}</h2>",
             f"<p>{result_pill(t)} &nbsp; {dim(esc(VERDICT_NOTE.get(t.verdict, '')))}</p>",
             f"<p>{dim('Module')} <code>{esc(t.module)}.py</code>"
             f"{' &nbsp; ' + faint(secs(t.seconds)) if t.seconds else ''}"
             f" &nbsp; <a href='fsv:open/{t.module}/{test_line(t.module, t.name)}'>Open source</a>"
             f" &nbsp; <a href='fsv:run/{t.module}'>Run this module</a></p>"]
    if t.message:
        parts.append("<h3>FAILURE</h3>")
        parts.append(f"<pre style='color:{palette.ERROR}'>{esc(t.message)}</pre>")
    if t.analysis:
        parts.append("<h3>THE CALCULATION</h3>")
        parts.append(markdown(t.record) if t.record else
                     "<p>" + faint("No calculation recorded: the analysis has not run since "
                                   "its results were cleared. Run the module again.") + "</p>")
    else:
        parts.append("<h3>WHAT IT MEASURED</h3>")
        parts.append(f"<pre>{esc(chr(10).join(t.lines))}</pre>" if t.lines else
                     "<p>" + faint("Nothing logged: the test reports no values, or its "
                                   "results predate the run log. Run the module again.") + "</p>")
    parts.append("<h3>REQUIREMENTS</h3>")
    for rid in t.requirements:
        req = run.requirements.get(rid)
        if not req:
            parts.append(f"<p><b>{esc(rid)}</b> {faint('not in the requirements document')}</p>")
            continue
        parts.append(f"<p><a href='fsv:req/{rid}'><b>{rid}</b></a> {status_pill(req.status)}"
                     f"{' ' + pending_pill() if req.pending else ''}<br>"
                     f"{linkify(esc(req.statement))}</p>")
        for fid in req.findings:
            sev, subject = run.findings.get(fid, ("?", ""))
            parts.append(f"<p style='margin-left:18px'><a href='fsv:finding/{fid}'>{fid}</a> "
                         f"{severity_pill(sev)} {dim(_inline(subject))}</p>")
    parts.append("<h3>ITEMS</h3>")
    for item in t.items:
        flag = " " + faint("declares expect: FAIL") if item.expect_fail else ""
        parts.append(f"<p><b>{esc(item.id)}</b>{flag}<br>{linkify(esc(item.criteria))}</p>")
    return "".join(parts)


def requirement_html(run, rid: str) -> str:
    """A requirement: stage, the tests behind it, findings, its whole entry."""
    req, stage = run.requirements[rid], run.stages[rid]
    parts = [f"<h2>{esc(rid)}</h2>",
             f"<p>{stage_pill(stage)} {status_pill(req.status)}"
             f"{' ' + pending_pill() if req.pending else ''}</p>"]
    cited = run.parents.get(rid, [])
    if cited:
        parts.append("<p>" + dim("Jama parent" + ("s" if len(cited) > 1 else "")) + " " +
                     " ".join(ref_link(j) for j in cited) + "</p>")
    elif rid in run.parents:
        parts.append("<p>" + faint("Derived: no Jama parent.") + "</p>")
    tests = run.tests_for(rid)
    parts.append("<h3>EVIDENCE</h3>")
    if not req.items:
        parts.append("<p>" + faint("No item verifies this requirement.") + "</p>")
    for item in req.items:
        test = next((t for t in tests if item in t.items), None)
        if test:
            parts.append(f"<p>{result_pill(test)} "
                         f"<a href='fsv:test/{test.module}/{test.name}'>"
                         f"<code>{esc(test.name)}</code></a><br>"
                         f"{dim(esc(item.id))} {faint(esc(item.method))}</p>")
        else:
            state = "blocked: its bound is still TBR" if item.criteria.upper() == "BLOCKED" else (
                "covered by another plan" if not item.is_local_test else "no test yet")
            parts.append(f"<p>{faint(esc(state))} <code>{esc(item.artifact or 'no artifact')}</code><br>"
                         f"{dim(esc(item.id))} {faint(esc(item.method))}</p>")
    if req.findings:
        parts.append("<h3>FINDINGS</h3>")
        for fid in req.findings:
            sev, subject = run.findings.get(fid, ("?", ""))
            parts.append(f"<p><a href='fsv:finding/{fid}'>{fid}</a> {severity_pill(sev)} "
                         f"{dim(_inline(subject))}</p>")
    parts.append(dispositions_html(req))
    parts.append("<h3>THE REQUIREMENT</h3>")
    entry = run.requirement_text.get(rid, "")
    parts.append(markdown(entry.split("\n", 1)[1] if "\n" in entry else entry))
    return "".join(parts)


def dispositions_html(req) -> str:
    """The waivers and exceptions recorded against a requirement, each marked
    approved -- and so applied -- or proposed."""
    if not (req.waivers or req.exceptions):
        return ""

    def approval(rec) -> str:
        return (pill("approved", palette.OK) + " " + dim(esc(f"{rec.approved_by}, {rec.date}"))
                if rec.approved else
                pill("proposed", palette.WARNING) + " " + faint("not applied until approved"))

    parts = ["<h3>DISPOSITIONS</h3>"]
    for w in req.waivers:
        ref = f" {dim(esc(w.reference))}" if w.reference else ""
        parts.append(f"<p><b>{esc(w.id)}</b> {pill('waiver', palette.REVIEW)} {approval(w)}{ref}<br>"
                     f"{dim(linkify(esc(w.reason)))}</p>")
    for e in req.exceptions:
        parts.append(f"<p><b>{esc(e.id)}</b> {pill('exception', palette.OK_QUALIFIED)} {approval(e)}<br>"
                     f"{dim(linkify(esc(e.reason)))}<br>"
                     + faint(f"{len(e.subjects)} excepted: ")
                     + ", ".join(f"<code>{esc(x)}</code>" for x in e.subjects) + "</p>")
    parts.append("<p>" + faint("Recorded in verification/requirement-dispositions.yaml.") + "</p>")
    return "".join(parts)


def jama_html(run, jid: str) -> str:
    """A Jama requirement: its text, and every PF requirement under it with the
    tests behind each -- what the Jama requirement's verification rests on --
    or, for one allocated to firmware, where it is verified instead."""
    j = run.jama[jid]
    rollup, stages = run.trace(jid)
    parts = [f"<h2>{esc(jid)}</h2>",
             f"<p>{trace_pill(rollup)} {dim(esc(stage_summary(stages)))}</p>"
             if rollup != "no local requirement" else "",
             f"<p><b>{esc(j.name)}</b></p>",
             f"<blockquote><i>{esc(j.text)}</i></blockquote>"]
    if j.note:
        parts.append(f"<p>{linkify(esc(j.note))}</p>")
    children = run.children(jid)
    parts.append(f"<h3>PF FPGA REQUIREMENTS ({len(children)})</h3>")
    if not children:
        parts.append("<p>" + (faint("None: allocated to firmware, verified in ")
                              + f"<code>{esc(j.verified_in)}</code>"
                              if j.verified_in else
                              pill("no local requirement", palette.ERROR) + " " +
                              faint("Nothing in the FPGA requirements cites this "
                                    "as its parent, so nothing verifies it.")) + "</p>")
    for rid in children:
        req = run.requirements[rid]
        parts.append(f"<p><a href='fsv:req/{rid}'><b>{rid}</b></a> {stage_pill(run.stages[rid])} "
                     f"{status_pill(req.status)}{' ' + pending_pill() if req.pending else ''}<br>"
                     f"{dim(linkify(esc(req.statement)))}</p>")
        tests = run.tests_for(rid)
        for item in req.items:
            test = next((t for t in tests if item in t.items), None)
            if test:
                line = (f"{result_pill(test)} <a href='fsv:test/{test.module}/{test.name}'>"
                        f"<code>{esc(test.name)}</code></a>")
            else:
                line = (faint("covered by another plan" if not item.is_local_test else "no test yet")
                        + f" <code>{esc(item.artifact or 'no artifact')}</code>")
            parts.append(f"<p style='margin-left:18px'>{line} {faint(esc(item.id + ' ' + item.method))}</p>")
        if not req.items:
            parts.append(f"<p style='margin-left:18px'>{faint('No item verifies this requirement.')}</p>")
        for fid in req.findings:
            sev, subject = run.findings.get(fid, ("?", ""))
            parts.append(f"<p style='margin-left:18px'><a href='fsv:finding/{fid}'>{fid}</a> "
                         f"{severity_pill(sev)} {dim(_inline(subject))}</p>")
    return "".join(parts)


def finding_html(run, fid: str) -> str:
    """A finding: the requirements citing it, their tests, the finding itself."""
    sev, subject = run.findings[fid]
    parts = [f"<h2>{esc(fid)}</h2>", f"<p>{severity_pill(sev.upper())}</p>",
             f"<p><b>{_inline(subject)}</b></p>", "<h3>REQUIREMENTS CITING IT</h3>"]
    citing = run.requirements_citing(fid)
    if not citing:
        parts.append("<p>" + faint("No requirement cites this finding.") + "</p>")
    for rid in citing:
        req = run.requirements[rid]
        tests = run.tests_for(rid)
        verdicts = " ".join(f"<a href='fsv:test/{t.module}/{t.name}'>{result_pill(t)}</a>"
                            for t in tests) or stage_pill(run.stages[rid])
        parts.append(f"<p><a href='fsv:req/{rid}'><b>{rid}</b></a> {status_pill(req.status)} "
                     f"{verdicts}{' ' + pending_pill() if req.pending else ''}<br>"
                     f"{dim(esc(req.statement))}</p>")
    parts.append("<h3>THE FINDING</h3>")
    text = run.finding_text.get(fid, "")
    parts.append(markdown(text.split("\n", 1)[1] if "\n" in text else text))
    return "".join(parts)
