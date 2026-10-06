"""The verification app in a browser tab: `make gui-web`.

Serves the model (`fsverif.results`, `fsverif.codecov`) as HTML
(`fsverif.render`) to a browser tab, so it runs where a window cannot open --
inside VS Code over Remote-SSH, in a Simple Browser tab, through the port VS
Code forwards.

Standard library only. Listens on 127.0.0.1, and every request must carry the
token printed at start-up: the machine is shared, and without it anybody logged
in could start a run as you.
"""

from __future__ import annotations

import argparse
import json
import mimetypes
import os
import secrets
import shutil
import socket
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

from fsverif import codecov, dispositions, jama, project, render
from fsverif import results as R
from fsverif.evidence import FINDINGS, ITEMS, REPO, REQUIREMENTS, RESULTS
from fsverif.runs import FAST, Job, phases

STATIC = Path(__file__).resolve().parent / "static"


class App:
    """What the server holds: the token, the current run, and a cached model."""

    def __init__(self, token: str, results_dir: Path = RESULTS,
                 coverage_dir: Path = codecov.COVERAGE):
        self.token = token
        self.results_dir = results_dir
        self.coverage_dir = coverage_dir
        self.job: Job | None = None
        self._run = None
        self._stamp = None
        self._lock = threading.Lock()

    # ---- the model, reloaded when anything it reads has changed

    def stamp(self) -> str:
        paths = [ITEMS, REQUIREMENTS, FINDINGS, jama.JAMA,
                 self.coverage_dir / "summary.json", codecov.DISPOSITIONS,
                 dispositions.DISPOSITIONS]
        if self.results_dir.is_dir():
            paths += sorted(self.results_dir.glob("*.xml")) + sorted(self.results_dir.glob("log-*.txt"))
        if self.coverage_dir.is_dir():
            paths += sorted(self.coverage_dir.glob("*.dat"))
        parts = []
        for p in paths:
            try:
                st = p.stat()
                parts.append(f"{p.name}:{st.st_mtime_ns}:{st.st_size}")
            except OSError:
                pass
        return str(abs(hash("|".join(parts))))

    def run(self):
        with self._lock:
            stamp = self.stamp()
            if self._run is None or stamp != self._stamp:
                self._run = R.load(ITEMS, REQUIREMENTS, self.results_dir, FINDINGS)
                self._stamp = stamp
            return self._run

    # ---- API

    def state(self) -> dict:
        run = self.run()
        cov = codecov.load(self.coverage_dir)
        return {
            "stamp": self._stamp,
            "project": project.ui(),
            "vocab": R.vocabulary(),
            "resultsAt": run.results_at,
            "resultsAgo": render.ago(run.results_at),
            "counts": run.counts(),
            "outcomes": run.outcomes(),
            "blocking": len(run.blocking),
            "tests": [{"module": t.module, "name": t.name, "verdict": t.verdict,
                       "outcome": t.outcome, "label": t.outcome_label,
                       "note": t.gate_note, "blocks": t.blocks,
                       "requirements": t.requirements,
                       "areas": sorted({R.group_of(r) for r in t.requirements}),
                       "pending": any(run.requirements.get(r) is not None and
                                      run.requirements[r].pending for r in t.requirements),
                       "seconds": t.seconds, "time": render.secs(t.seconds),
                       "search": " ".join([t.name, t.module, " ".join(t.requirements),
                                           t.message, " ".join(t.lines),
                                           " ".join(i.criteria for i in t.items)]).lower()}
                      for t in run.tests],
            "requirements": [{"id": rid, "area": R.group_of(rid), "stage": run.stages[rid],
                              "stageLabel": R.STAGE_LABEL.get(run.stages[rid], run.stages[rid]),
                              "status": req.status, "pending": req.pending,
                              "waivers": [w.id for w in req.waivers],
                              "exceptions": [e.id for e in req.exceptions],
                              "method": "/".join(sorted({i.method for i in req.items if i.method})),
                              "statement": req.statement, "findings": list(req.findings),
                              "parents": run.parents.get(rid, []),
                              "tests": [{"name": t.name, "outcome": t.outcome}
                                        for t in run.tests_for(rid)]}
                             for rid, req in run.requirements.items()],
            "jama": [self._jama_row(run, j) for j in run.jama.values()],
            "findings": [{"id": fid, "severity": sev.upper(), "subject": render.plain(subject),
                          "requirements": run.requirements_citing(fid),
                          "search": (fid + " " + subject + " " +
                                     run.finding_text.get(fid, "")).lower()}
                         for fid, (sev, subject) in run.findings.items()],
            "pending": run.pending,
            "coverage": {
                "measured": cov.measured, "reported": cov.reported, "stale": cov.stale,
                "modules": len(cov.data), "reportedModules": len(cov.modules),
                "measuredAgo": render.ago(cov.measured_at),
                "reportedAgo": render.ago(cov.reported_at),
                "summary": {k: list(v) for k, v in cov.summary.items() if v[2]},
                "files": [{"name": f.name, "missed": f.missed, "counted": f.counted,
                           "partly": f.partly, "disposed": f.disposed,
                           "unresolved": f.unresolved, "percent": round(f.percent, 1)}
                          for f in cov.files],
                "problems": cov.problems},
            "job": self.job.status(since=10**9) if self.job else None,
            "canOpen": bool(shutil.which("code")),
        }

    @staticmethod
    def _jama_row(run, j) -> dict:
        rollup, stages = run.trace(j.id)
        kids = run.children(j.id)
        return {"id": j.id, "short": j.short, "name": j.name, "text": j.text,
                "note": j.note, "allocated": j.allocated, "rollup": rollup,
                "stages": stages, "children": kids, "verifiedIn": j.verified_in,
                "summary": render.stage_summary(stages),
                "search": " ".join([j.id, j.name, j.text, j.note, j.verified_in,
                                    " ".join(kids)]).lower()}

    def detail(self, q: dict) -> dict:
        run = self.run()
        kind = q.get("kind")
        if kind == "test":
            t = run.test(q.get("module", ""), q.get("name", ""))
            if t:
                return {"html": render.test_html(run, t)}
        elif kind == "req" and q.get("id") in run.requirements:
            return {"html": render.requirement_html(run, q["id"])}
        elif kind == "jama" and q.get("id") in run.jama:
            return {"html": render.jama_html(run, q["id"])}
        elif kind == "finding" and q.get("id") in run.findings:
            return {"html": render.finding_html(run, q["id"])}
        return {"html": "<p>Not found.</p>"}

    def coverage_file(self, name: str) -> dict:
        if not name or "/" in name or name.startswith("."):
            return {"error": "bad name"}
        lines = []
        annotated = codecov.annotated(name, self.coverage_dir)
        try:
            applied, _ = codecov.disposed(name, annotated, codecov.dispositions())
        except ValueError:          # malformed; the report says so when rebuilt
            applied = {}
        for line in annotated:
            missed = line.missed_points
            names = sorted({f"{p.kind} {p.comment}  in "
                            f"{p.hier.rsplit('.', 1)[0].split('.')[-1] or p.hier}" for p in missed})
            d = applied.get(line.number)
            lines.append({"n": line.number, "text": line.text, "count": line.count,
                          "partial": line.partial, "points": len(line.points),
                          "hit": len(line.points) - len(missed),
                          "kinds": sorted({p.kind for p in line.points}),
                          "missed": names[:12], "moreMissed": max(0, len(names) - 12),
                          "disposed": {"kind": d.kind, "reason": d.reason, "where": d.where}
                          if d and codecov.never_executed(line) else None})
        src = codecov.source(name)
        return {"lines": lines, "source": str(src) if src else ""}

    def log(self, module: str) -> dict:
        """A module's simulator log from its last run (`fsverif.runlog`).

        A module run against several DUTs -- one per DDR4 bank -- leaves one log
        per run, `log-<module>.<run>.txt`, and they are shown one after another.
        An analysis has no simulator; what it did is its recorded calculation.
        """
        if not module.replace("_", "").isalnum():
            return {"error": "bad module name"}
        paths = sorted(self.results_dir.glob(f"log-{module}.txt")) + \
            sorted(self.results_dir.glob(f"log-{module}.*.txt"))
        if not paths:
            paths = sorted((self.results_dir / "analysis").glob(f"{module}.md"))
        if not paths:
            return {"error": f"No log for {module}. Its last run predates the run log, or it "
                             "has not run: run the module again."}
        text = "\n".join((f"==== {p.name}\n" if len(paths) > 1 else "") +
                         p.read_text(encoding="utf-8", errors="replace") for p in paths)
        return {"text": text, "ago": render.ago(max(p.stat().st_mtime for p in paths))}

    def start(self, body: dict) -> dict:
        if self.job and self.job.running:
            return {"error": "A run is already going; cancel it first."}
        run = self.run()
        kind, module = body.get("kind"), body.get("module", "")
        if kind == "suite":
            label = "the whole suite"
            plan = phases(None, label)
        elif kind == "failing":
            modules = sorted({t.module for t in run.tests if t.verdict != "passed"})
            if not modules:
                return {"error": "Nothing is failing."}
            label = f"{len(modules)} modules with failures"
            files = [R.module_arg(m) for m in modules]
            plan = phases(files, label, simulate=any(f.startswith("tests/") for f in files))
        elif kind == "module" and module and R.module_path(module).is_file():
            label = module
            arg = R.module_arg(module)
            plan = phases([arg], label, simulate=arg.startswith("tests/"))
        elif kind == "fast":
            label = "the fast checks"
            plan = phases(FAST, label, simulate=False)
        elif kind == "nocov":
            label = "the whole suite, without coverage"
            plan = phases(None, label, coverage=False)
        elif kind == "report":
            label = "the coverage report"
            plan = phases(report_only=True)
        else:
            return {"error": f"Unknown run: {kind} {module}".strip()}
        self.job = Job(plan, label)
        return {"ok": True, "label": label}

    def open_source(self, body: dict) -> dict:
        path = Path(body.get("path", ""))
        if body.get("module"):
            path = R.module_path(body["module"])
        try:
            path.resolve().relative_to(REPO)
        except ValueError:
            return {"error": "Only files in this repository can be opened."}
        code = shutil.which("code")
        if not code:
            return {"error": "The VS Code command line is not available here. Start the app "
                             "from a VS Code terminal to open files from it."}
        line = int(body.get("line") or 1)
        subprocess.Popen([code, "-g", f"{path}:{line}"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return {"ok": True, "opened": f"{path.name}:{line}"}


def handler(app: App):
    class Handler(BaseHTTPRequestHandler):
        server_version = "fsverif"

        def log_message(self, fmt, *args):
            pass

        def _authorised(self, query: dict) -> bool:
            token = self.headers.get("X-Fsverif-Token") or query.get("token", "")
            return secrets.compare_digest(token.encode(), app.token.encode())

        def _send(self, status: int, body: bytes, ctype: str) -> None:
            self.send_response(status)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Referrer-Policy", "no-referrer")
            self.end_headers()
            self.wfile.write(body)

        def _json(self, data, status: int = 200) -> None:
            self._send(status, json.dumps(data).encode(), "application/json")

        def do_GET(self):
            url = urlparse(self.path)
            q = {k: v[0] for k, v in parse_qs(url.query).items()}
            if url.path in ("/", "/index.html") or url.path.startswith("/static/"):
                name = "index.html" if url.path in ("/", "/index.html") else url.path[len("/static/"):]
                path = (STATIC / name).resolve()
                if STATIC not in path.parents or not path.is_file():
                    return self._send(404, b"not found", "text/plain")
                if name == "index.html" and not self._authorised(q):
                    return self._send(403, b"This address needs the token printed when the "
                                           b"app started. Open the whole address it printed.",
                                      "text/plain")
                ctype = mimetypes.guess_type(str(path))[0] or "application/octet-stream"
                if ctype.startswith("text/") or ctype.endswith("javascript"):
                    ctype += "; charset=utf-8"
                return self._send(200, path.read_bytes(), ctype)
            if not self._authorised(q):
                return self._json({"error": "forbidden"}, 403)
            try:
                if url.path == "/api/state":
                    return self._json(app.state())
                if url.path == "/api/stamp":
                    app.run()
                    return self._json({"stamp": app._stamp,
                                       "job": app.job.status(since=10**9) if app.job else None})
                if url.path == "/api/detail":
                    return self._json(app.detail(q))
                if url.path == "/api/coverage/file":
                    return self._json(app.coverage_file(q.get("name", "")))
                if url.path == "/api/log":
                    return self._json(app.log(q.get("module", "")))
                if url.path == "/api/run":
                    since = int(q.get("since", "0") or 0)
                    return self._json(app.job.status(since) if app.job else {"running": False})
            except Exception as exc:  # noqa: BLE001 -- report it, do not drop the connection
                return self._json({"error": f"{type(exc).__name__}: {exc}"}, 500)
            return self._json({"error": "not found"}, 404)

        def do_POST(self):
            url = urlparse(self.path)
            if not self._authorised({}):
                return self._json({"error": "forbidden"}, 403)
            length = int(self.headers.get("Content-Length") or 0)
            try:
                body = json.loads(self.rfile.read(length) or b"{}")
            except ValueError:
                return self._json({"error": "bad request"}, 400)
            if url.path == "/api/run":
                return self._json(app.start(body))
            if url.path == "/api/cancel":
                if app.job and app.job.running:
                    app.job.cancel()
                return self._json({"ok": True})
            if url.path == "/api/open":
                return self._json(app.open_source(body))
            return self._json({"error": "not found"}, 404)

    return Handler


def free_port(preferred: int) -> int:
    for port in (preferred, 0):
        with socket.socket() as s:
            # As the server binds, so a port the last run left in TIME_WAIT is reused
            # rather than abandoned for a random one.
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            try:
                s.bind(("127.0.0.1", port))
                return s.getsockname()[1]
            except OSError:
                continue
    raise SystemExit("no free port")


def serve(port: int, token: str | None = None) -> tuple:
    """A running server and its App, in a background thread (for tests)."""
    app = App(token or secrets.token_urlsafe(18))
    server = ThreadingHTTPServer(("127.0.0.1", free_port(port)), handler(app))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server, app


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--port", type=int, default=int(os.environ.get("FSVERIF_PORT", 8765)))
    args = ap.parse_args(argv)
    token = secrets.token_urlsafe(18)
    app = App(token)
    port = free_port(args.port)
    server = ThreadingHTTPServer(("127.0.0.1", port), handler(app))
    url = f"http://127.0.0.1:{port}/?token={token}"
    print(f"""
fsverif is running at

    {url}

In VS Code: Ctrl+Shift+P, "Simple Browser: Show", and paste that address.
VS Code forwards the port by itself. Ctrl+C here stops the app.
""", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        if app.job and app.job.running:
            app.job.cancel()
        server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
