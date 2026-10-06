// fsverif in a browser tab. The server does the work (fsverif.web.server); this
// draws it. Detail panes are HTML the server renders with fsverif.render, the
// same code `make sarif` uses, and `fsv:` links inside them navigate here.
"use strict";

const TOKEN = new URLSearchParams(location.search).get("token") || "";
const C = {
  error: "#ff5c6c", warning: "#f5b544", info: "#5aa9ff", ok: "#3ecf8e", review: "#c084fc",
  dim: "#9aa4b2", faint: "#6b7585", accent: "#7c8cff",
};
// What a test did. Whether a failure was expected, and whether anything blocks
// a merge, is a note beside it -- the gate's judgement, not a result.
const OUTCOMES = ["failed", "passed", "not run"];
const OUTCOME_LABEL = { failed: "Failing", passed: "Passing", "not run": "Not run" };
const OUTCOME_COLOR = { failed: C.error, passed: C.ok, "not run": C.faint };
const STAGES = ["passing", "known shortfall", "failing", "never run", "not written", "elsewhere", "no item"];
const STAGE_LABEL = { passing: "passing", "known shortfall": "failing", failing: "failing, not expected",
  "never run": "not run", "not written": "no test yet", elsewhere: "elsewhere", "no item": "no item" };
const STAGE_COLOR = { passing: C.ok, "known shortfall": C.error, failing: C.error,
  "never run": C.faint, "not written": "#4a5363", elsewhere: C.info, "no item": C.error };
const STATUS_COLOR = { OK: C.ok, GAP: C.warning, AMBIG: C.review, DEFECT: C.error };
const SEVERITY_COLOR = { HIGH: C.error, MEDIUM: C.warning, LOW: C.info, WITHDRAWN: C.faint };
// A Jama requirement, judged by the housekeeper requirements under it. Worst first.
const TRACES = ["no local requirement", "failing", "partly tested", "passing"];
const TRACE_COLOR = { "no local requirement": "#a3283a", failing: C.error, "partly tested": C.warning, passing: C.ok };
const PAGES = [
  ["dashboard", "Dashboard", "Where the housekeeper's verification stands"],
  ["trace", "Traceability", "Each Jama requirement, the housekeeper requirements under it, and what their tests found"],
  ["tests", "Tests", "Every requirement test, with what it checked and what happened"],
  ["requirements", "Requirements", "Where each requirement stands, and what is behind it"],
  ["findings", "Findings", "What is wrong, the requirements it touches, and the tests that show it"],
  ["coverage", "Coverage", "What the requirement tests reached in the design"],
];

let state = null;
let page = "dashboard";
const ui = {                       // what each page remembers between visits
  tests: { q: "", outcome: "", blocks: "", area: "", module: "", pending: "", sort: ["outcome", 1], sel: null },
  trace: { q: "", rollup: "", scope: "", sort: ["id", 1], sel: null },
  requirements: { q: "", area: "", stage: "", status: "", pending: "", parent: "", sort: ["id", 1], sel: null },
  findings: { q: "", severity: "", cited: "", sort: ["id", 1], sel: null },
  coverage: { sort: ["missed", -1], sel: null, lines: [], cur: -1 },
};
let jobOffset = 0, polling = null, lastStamp = null;
let runText = "";                  // the app's own run output, kept while a module log is shown

// ---- small helpers

const $ = (sel, root = document) => root.querySelector(sel);
const esc = s => String(s ?? "").replace(/[&<>"']/g, c =>
  ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const rgba = (hex, a) => { const n = parseInt(hex.slice(1), 16);
  return `rgba(${n >> 16}, ${(n >> 8) & 255}, ${n & 255}, ${a})`; };
const pill = (text, color) =>
  `<span class="pill" style="color:${color};background:${rgba(color, .16)}">${esc(text)}</span>`;
const secs = s => !s ? "" : s < 90 ? `${Math.round(s)} s` : `${(s / 60).toFixed(1)} min`;
const result = t => pill(t.label, OUTCOME_COLOR[t.outcome]) +
  (t.note ? " " + (t.blocks ? pill(t.note, C.error) : `<span class="faint">${esc(t.note)}</span>`) : "");

async function api(path, body) {
  const opts = { headers: { "X-Fsverif-Token": TOKEN } };
  if (body !== undefined) {
    opts.method = "POST";
    opts.headers["Content-Type"] = "application/json";
    opts.body = JSON.stringify(body);
  }
  const r = await fetch(path, opts);
  const data = await r.json();
  if (r.status === 403) throw new Error("This page needs the address the app printed, with its token.");
  return data;
}

function toast(text) {
  const t = $("#toast");
  t.textContent = text;
  t.classList.remove("hidden");
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => t.classList.add("hidden"), 5000);
}

// ---- chrome

function drawNav() {
  const nav = $("#nav");
  const blocking = state.blocking;
  const cov = state.coverage.summary.line;
  const badges = {
    tests: blocking ? [blocking, "bad"] : [state.tests.length, ""],
    trace: state.jama.some(j => !j.children.length)
      ? [state.jama.filter(j => !j.children.length).length, "bad"] : [state.jama.length, ""],
    requirements: [state.requirements.length, ""],
    findings: [state.findings.length, ""],
    coverage: cov ? [`${Math.round(cov[0])}%`, ""] : null,
  };
  nav.innerHTML = PAGES.map(([key, name]) => {
    const b = badges[key];
    return `<button data-page="${key}" class="${key === page ? "on" : ""}"><span>${name}</span>` +
      (b ? `<span class="badge ${b[1]}">${esc(b[0])}</span>` : "") + "</button>";
  }).join("");
}

function show(key) {
  page = key;
  const [, name, sub] = PAGES.find(p => p[0] === key);
  $("#title").textContent = name;
  $("#subtitle").textContent = sub;
  if (location.hash !== "#" + key) history.replaceState(null, "", "#" + key);
  drawNav();
  ({ dashboard: drawDashboard, trace: drawTrace, tests: drawTests, requirements: drawRequirements,
     findings: drawFindings, coverage: drawCoverage })[key]();
}

// ---- dashboard

function segbar(parts) {
  const total = parts.reduce((a, p) => a + p[0], 0) || 1;
  return `<div class="segbar" title="${esc(parts.filter(p => p[0]).map(p => `${p[2]}: ${p[0]}`).join("\n"))}">` +
    parts.filter(p => p[0]).map(p => `<div style="width:${100 * p[0] / total}%;background:${p[1]}"></div>`).join("") +
    "</div>";
}

function drawDashboard() {
  const el = $("#page");
  if (!state.resultsAt) {
    el.innerHTML = `<div class="empty"><h2>No results yet</h2><p>Run the suite to see what each
      requirement test reports. A full run takes a while; modules run side by side.</p>
      <button class="primary" data-run="suite">Run the suite</button></div>`;
    return;
  }
  const o = state.outcomes, total = state.tests.length;
  const expected = state.tests.filter(t => t.outcome === "failed" && !t.blocks).length;
  const card = (go, title, color, value, sub) => `<div class="card stat" data-go="${go}">
    <h4>${title.toUpperCase()}</h4><div class="value" style="color:${color}">${value}</div>
    <div class="sub">${sub}</div></div>`;
  const gate = state.blocking
    ? card("fsv:tests/blocks/1", "Merge", C.error, "Blocked",
        `${state.blocking} result${state.blocking > 1 ? "s" : ""} would stop a merge`)
    : card("fsv:tests/outcome/failed", "Merge", C.ok, "Clear",
        o.failed ? "every failure is already recorded as a known gap" : "nothing is failing");
  const stages = {}, byArea = {};
  for (const r of state.requirements) {
    stages[r.stage] = (stages[r.stage] || 0) + 1;
    (byArea[r.area] = byArea[r.area] || {})[r.stage] = (byArea[r.area][r.stage] || 0) + 1;
  }
  const covered = (stages.passing || 0) + (stages["known shortfall"] || 0);
  const areas = Object.keys(byArea).sort().map(a => {
    const s = byArea[a], n = Object.values(s).reduce((x, y) => x + y, 0);
    return `<div class="area" data-go="fsv:reqs/area/${a}"><span class="n">${a}</span>
      ${segbar(STAGES.map(k => [s[k] || 0, STAGE_COLOR[k], STAGE_LABEL[k]]))}
      <span class="f">${(s.passing || 0) + (s["known shortfall"] || 0)}/${n}</span></div>`;
  }).join("");
  const bad = state.tests.filter(t => t.blocks || t.outcome === "not run");
  const attention = bad.length ? bad.slice(0, 12).map(t =>
      `<p>${result(t)} <a href="fsv:test/${t.module}/${t.name}"><code>${esc(t.name)}</code></a></p>`).join("")
      + (bad.length > 12 ? `<p class="faint">and ${bad.length - 12} more</p>` : "")
    : `<p style="color:${C.ok}"><b>Nothing new is failing.</b></p>
       <p class="dim">The ${o.failed} failing tests are all expected: each checks a requirement already
       recorded as not met. Nothing here blocks a merge.</p>`;
  const perModule = {};
  for (const t of state.tests) perModule[t.module] = t.seconds;
  const sim = Object.values(perModule).reduce((a, b) => a + b, 0);
  const slow = [...state.tests].sort((a, b) => b.seconds - a.seconds).slice(0, 3);
  const ran = state.tests.filter(t => t.outcome !== "not run").length;
  const pend = state.pending.map(id => {
    const r = state.requirements.find(x => x.id === id);
    const t = state.tests.find(x => x.requirements.includes(id));
    return `<tr><td style="white-space:nowrap"><a href="fsv:req/${id}">${id}</a></td><td style="white-space:nowrap">${t ? result(t) : ""}</td>
      <td class="dim">${esc(r.statement.length > 110 ? r.statement.slice(0, 108) + "…" : r.statement)}</td></tr>`;
  }).join("");
  const l4 = state.jama.filter(j => j.allocated), others = state.jama.filter(j => !j.allocated);
  const roll = js => { const n = {}; for (const j of js) n[j.rollup] = (n[j.rollup] || 0) + 1; return n; };
  const traceRow = (label, js, scope) => { const n = roll(js);
    return `<div class="area" data-go="fsv:jamas/scope/${scope}"><span class="n" style="width:130px">${label}</span>
      ${segbar(TRACES.map(k => [n[k] || 0, TRACE_COLOR[k], k]))}
      <span class="f">${n.passing || 0}/${js.length}</span></div>`; };
  const untraced = state.jama.filter(j => !j.children.length);
  const l4n = roll(l4);
  const traceHtml = `<p class="dim">${l4.length - (l4n["no local requirement"] || 0)} of ${l4.length} FAR-PM_FPGA L4
      requirements have a housekeeper requirement under them. ${l4n.passing || 0} are fully passing,
      ${l4n.failing || 0} have a failing housekeeper requirement, and ${l4n["partly tested"] || 0} are partly tested.</p>
    ${traceRow("FAR-PM_FPGA L4", l4, "l4")}${others.length ? traceRow("Other parents", others, "other") : ""}
    <div class="legend">${TRACES.map(k => `<span><i style="background:${TRACE_COLOR[k]}"></i>${k}</span>`).join("")}</div>
    ${untraced.length ? `<p style="color:${C.error}">No local requirement: ${untraced.map(j =>
      `<a href="fsv:jama/${j.id}">${esc(j.id)}</a>`).join(", ")}</p>` : ""}`;
  const cov = state.coverage;
  const covHtml = !cov.measured && !cov.reported
    ? `<p class="dim">Not measured yet. Every run measures it; run the suite.</p>`
    : `<p class="dim">${cov.modules} module(s) measured, ${esc(cov.measuredAgo)}</p><table>` +
      Object.entries(cov.summary).map(([k, v]) =>
        `<tr><td>${esc(k)}</td><td style="text-align:right"><b>${v[0].toFixed(1)}%</b></td><td class="faint">&nbsp;${v[1]} of ${v[2]}</td></tr>`).join("") +
      "</table>" + (cov.stale ? `<p style="color:${C.warning}">The report is older than the data; rebuild it on the Coverage page.</p>` : "");
  el.innerHTML = `<div class="dash scroll">
    <div class="cards">
      ${card("fsv:tests/outcome/passed", "Passing", C.ok, o.passed, `of ${total} tests`)}
      ${card("fsv:tests/outcome/failed", "Failing", C.error, o.failed,
        o.failed ? `${expected} expected, ${o.failed - expected} new` : `of ${total} tests`)}
      ${card("fsv:tests/outcome/not run", "Not run", C.faint, o["not run"], o["not run"] ? "no result yet" : "every test has a result")}
      ${gate}
    </div>
    <div class="row">
      <div class="card" style="flex:3"><h4>REQUIREMENTS WITH A TEST RESULT</h4>
        <p class="dim">${covered} of ${state.requirements.length} requirements have a test result:
          ${stages.passing || 0} passing, ${stages["known shortfall"] || 0} failing.
          ${stages["not written"] || 0} have no test yet -- an inspection or a simulation still to write.</p>
        ${segbar(STAGES.map(k => [stages[k] || 0, STAGE_COLOR[k], STAGE_LABEL[k]]))}
        <div class="legend">${["passing", "known shortfall", "never run", "not written"].map(k => `<span><i style="background:${STAGE_COLOR[k]}"></i>${STAGE_LABEL[k]}</span>`).join("")}</div>
        ${areas}</div>
      <div style="flex:2;display:flex;flex-direction:column;gap:14px">
        <div class="card"><h4>NEEDS ATTENTION</h4>${attention}</div>
        <div class="card"><h4>LAST RUN</h4><p><b>${esc(state.resultsAgo)}</b> <span class="dim">${ran} of ${total} tests have a result</span></p>
          <p class="dim">Simulation time, all modules added together: <span style="color:var(--text)">${secs(sim)}</span></p>
          <p class="dim">Slowest:<br>${slow.map(t => `<a href="fsv:test/${t.module}/${t.name}">${esc(t.module)}</a> <span class="faint">${secs(t.seconds)}</span>`).join("<br>")}</p></div>
      </div>
    </div>
    <div class="row">
      <div class="card" style="flex:1"><h4>JAMA REQUIREMENTS</h4>${traceHtml}
        <p><a href="fsv:page/trace">Open Traceability</a></p></div>
    </div>
    <div class="row">
      <div class="card" style="flex:3"><h4>PENDING SYSTEMS CONFIRMATION</h4>
        <p class="dim">Tested against values proposed to systems and not yet confirmed. Revisit each when the answer is in Jama.</p>
        <table>${pend}</table></div>
      <div class="card" style="flex:2"><h4>CODE COVERAGE</h4>${covHtml}<p><a href="fsv:page/coverage">Open Coverage</a></p></div>
    </div></div>`;
}

// ---- list pages: filters, a sortable table, and a detail pane

function listPage(cfg) {
  const u = ui[cfg.key];
  const el = $("#page");
  el.innerHTML = `<div class="filters"><input id="q" placeholder="${esc(cfg.placeholder)}" value="${esc(u.q || "")}">` +
    cfg.filters.map(f => `<select data-f="${f.key}"><option value="">${esc(f.all)}</option>` +
      f.options.map(o => `<option value="${esc(o[1])}" ${String(u[f.key]) === String(o[1]) ? "selected" : ""}>${esc(o[0])}</option>`).join("") +
      "</select>").join("") + `<span class="count"></span></div>
    <div class="split"><div class="tablewrap"><table class="list"><colgroup>` +
    cfg.columns.map(c => `<col style="${c.width ? `width:${c.width}px` : ""}">`).join("") +
    `</colgroup><thead><tr>` + cfg.columns.map(c => `<th data-sort="${c.key}">${esc(c.title)}</th>`).join("") +
    `</tr></thead><tbody></tbody></table></div><div class="detail"></div></div>`;
  const redraw = () => {
    const q = ($("#q").value || "").toLowerCase();
    u.q = $("#q").value;
    let rows = cfg.rows.filter(r => cfg.keep(r, u, q));
    const col = cfg.columns.find(c => c.key === u.sort[0]) || cfg.columns[0];
    const key = col.sort || (r => r[col.key]);
    rows.sort((a, b) => { const x = key(a), y = key(b); return (x < y ? -1 : x > y ? 1 : 0) * u.sort[1]; });
    $("#page .count").textContent = `${rows.length} of ${cfg.rows.length}`;
    $("#page thead").innerHTML = "<tr>" + cfg.columns.map(c =>
      `<th data-sort="${c.key}">${esc(c.title)}${c.key === u.sort[0] ? `<span class="arrow"> ${u.sort[1] > 0 ? "▲" : "▼"}</span>` : ""}</th>`).join("") + "</tr>";
    $("#page tbody").innerHTML = rows.map(r =>
      `<tr data-id="${esc(cfg.id(r))}" class="${cfg.id(r) === u.sel ? "sel" : ""}">` + cfg.columns.map(c => {
        const v = c.text ? c.text(r) : r[c.key];
        const color = c.color ? c.color(r) : "";
        const tip = c.title_ ? c.title_(r) : v;
        return `<td title="${esc(tip)}" class="${c.mono ? "mono" : ""}" style="${color ? `color:${color}` : ""}">${c.html ? c.html(r) : esc(v)}</td>`;
      }).join("") + "</tr>").join("");
    if (!rows.length) { $("#page .detail").innerHTML = `<p class="dim">Nothing matches these filters.</p>`; return; }
    if (!rows.some(r => cfg.id(r) === u.sel)) select(cfg.id(rows[0]));
    else if (!$("#page .detail").innerHTML) select(u.sel);
  };
  const select = id => {
    u.sel = id;
    for (const tr of document.querySelectorAll("#page tbody tr")) tr.classList.toggle("sel", tr.dataset.id === id);
    const row = cfg.rows.find(r => cfg.id(r) === id);
    if (row) cfg.detail(row);
  };
  $("#q").oninput = redraw;
  for (const s of document.querySelectorAll("#page select")) s.onchange = () => { u[s.dataset.f] = s.value; redraw(); };
  $("#page thead").onclick = e => {
    const th = e.target.closest("th"); if (!th) return;
    u.sort = [th.dataset.sort, u.sort[0] === th.dataset.sort ? -u.sort[1] : 1];
    redraw();
  };
  $("#page tbody").onclick = e => { const tr = e.target.closest("tr"); if (tr) select(tr.dataset.id); };
  cfg.select = select;
  redraw();
  const sel = document.querySelector("#page tr.sel");
  if (sel) sel.scrollIntoView({ block: "center" });
}

async function loadDetail(query) {
  const d = await api("/api/detail?" + new URLSearchParams(query));
  $("#page .detail").innerHTML = d.html;
  $("#page .detail").scrollTop = 0;
}

const opts = (values, label = v => v) => values.map(v => [label(v), v]);
const uniq = xs => [...new Set(xs)].sort();

function drawTests() {
  listPage({
    key: "tests", rows: state.tests, id: t => `${t.module}/${t.name}`,
    placeholder: "Search tests, requirements, messages, logged values",
    filters: [
      { key: "outcome", all: "Any result", options: opts(OUTCOMES, v => OUTCOME_LABEL[v]) },
      { key: "blocks", all: "Blocks a merge or not", options: [["Blocks a merge", "1"], ["Expected failures", "expected"]] },
      { key: "area", all: "Any area", options: opts(uniq(state.tests.flatMap(t => t.areas))) },
      { key: "module", all: "Any module", options: opts(uniq(state.tests.map(t => t.module))) },
      { key: "pending", all: "Any value", options: [["Pending systems confirmation", "1"]] },
    ],
    keep: (t, u, q) => (!u.outcome || t.outcome === u.outcome) &&
      (!u.blocks || (u.blocks === "1" ? t.blocks : t.outcome === "failed" && !t.blocks)) &&
      (!u.area || t.areas.includes(u.area)) &&
      (!u.module || t.module === u.module) && (!u.pending || t.pending) && (!q || t.search.includes(q)),
    columns: [
      { key: "outcome", title: "Result", width: 150, text: t => t.label + (t.note ? ` · ${t.note}` : ""),
        color: t => OUTCOME_COLOR[t.outcome], sort: t => (t.blocks ? 0 : 1) * 10 + OUTCOMES.indexOf(t.outcome) },
      { key: "name", title: "Test", mono: true },
      { key: "requirements", title: "Requirements", width: 120, text: t => t.requirements.join(", ") },
      { key: "module", title: "Module", width: 170, color: () => C.dim },
      { key: "seconds", title: "Time", width: 70, text: t => t.time, color: () => C.dim },
    ],
    detail: t => loadDetail({ kind: "test", module: t.module, name: t.name }),
  });
}

// ---- traceability: Jama down to the tests

const jamaShort = id => id.replace("FAR-PM_FPGA_", "");
const jamaNum = id => { const m = id.match(/^(.*)-(\d+)$/);
  return (id.startsWith("FAR-PM_FPGA_") ? "0" : "1") + m[1] + String(+m[2]).padStart(4, "0"); };

function drawTrace() {
  const stageOrder = ["failing", "known shortfall", "no item", "not written", "never run", "elsewhere", "passing"];
  listPage({
    key: "trace", rows: state.jama, id: j => j.id,
    placeholder: "Search Jama identifiers, names, wording, housekeeper requirements",
    filters: [
      { key: "rollup", all: "Any result", options: opts(TRACES, v => v[0].toUpperCase() + v.slice(1)) },
      { key: "scope", all: "Any source", options: [["FAR-PM_FPGA L4 (allocated)", "l4"], ["Other parents", "other"]] },
    ],
    keep: (j, u, q) => (!u.rollup || j.rollup === u.rollup) &&
      (!u.scope || (u.scope === "l4") === j.allocated) && (!q || j.search.includes(q)),
    columns: [
      { key: "id", title: "Jama", width: 150, mono: true, text: j => j.short, title_: j => j.id, sort: j => jamaNum(j.id) },
      { key: "rollup", title: "Result", width: 150, color: j => TRACE_COLOR[j.rollup], sort: j => TRACES.indexOf(j.rollup) },
      { key: "children", title: "HK reqs", width: 70, text: j => j.children.length,
        color: j => j.children.length ? C.dim : C.error, sort: j => j.children.length },
      { key: "coverage", title: "Housekeeper requirements under it", width: 230, text: j => j.summary || "none",
        html: j => j.children.length
          ? segbar(stageOrder.map(k => [j.stages[k] || 0, STAGE_COLOR[k], STAGE_LABEL[k]]))
          : `<span style="color:${C.error}">none</span>`,
        sort: j => (j.stages.passing || 0) / (j.children.length || 1) },
      { key: "name", title: "Name", width: 260 },
      { key: "text", title: "Wording", color: () => C.dim },
    ],
    detail: j => loadDetail({ kind: "jama", id: j.id }),
  });
}

function drawRequirements() {
  const num = id => parseInt(id.split("-").pop(), 10);
  const mark = { passed: "\u2713", failed: "\u2717", "not run": "\u00b7" };
  listPage({
    key: "requirements", rows: state.requirements, id: r => r.id,
    placeholder: "Search identifiers, wording, findings, Jama parents",
    filters: [
      { key: "area", all: "Any area", options: opts(uniq(state.requirements.map(r => r.area))) },
      { key: "stage", all: "Any result", options: opts(STAGES, v => STAGE_LABEL[v]) },
      { key: "status", all: "Any status", options: opts(["OK", "GAP", "AMBIG", "DEFECT"]) },
      { key: "parent", all: "Any Jama parent", options: [["Derived: no Jama parent", "-"],
        ...state.jama.map(j => [jamaShort(j.id), j.id])] },
      { key: "pending", all: "Any value", options: [["Pending systems confirmation", "1"]] },
    ],
    keep: (r, u, q) => (!u.area || r.area === u.area) && (!u.stage || r.stage === u.stage) &&
      (!u.status || r.status === u.status) && (!u.pending || r.pending) &&
      (!u.parent || (u.parent === "-" ? !r.parents.length : r.parents.includes(u.parent))) &&
      (!q || (r.id + " " + r.statement + " " + r.findings.join(" ") + " " + r.parents.join(" ")).toLowerCase().includes(q)),
    columns: [
      { key: "id", title: "Requirement", width: 120, mono: true, sort: r => r.area + String(num(r.id)).padStart(3, "0") },
      { key: "stage", title: "Result", width: 110, text: r => r.stageLabel, color: r => STAGE_COLOR[r.stage], sort: r => STAGES.indexOf(r.stage) },
      { key: "tests", title: "Tests", width: 60, text: r => r.tests.map(t => mark[t.outcome]).join(" ") || "\u2014",
        title_: r => r.tests.map(t => `${OUTCOME_LABEL[t.outcome]}: ${t.name}`).join("\n") || "no test",
        color: r => r.tests.some(t => t.outcome === "failed") ? C.error : r.tests.length ? C.ok : C.faint,
        sort: r => r.tests.length },
      { key: "status", title: "Status", width: 70, color: r => STATUS_COLOR[r.status] },
      { key: "parents", title: "Jama", width: 110, text: r => r.parents.map(jamaShort).join(", ") || "derived",
        color: r => r.parents.length ? C.dim : C.faint, sort: r => r.parents.length ? jamaNum(r.parents[0]) : "z" },
      { key: "method", title: "Method", width: 70, color: () => C.dim },
      { key: "pending", title: "", width: 28, text: r => r.pending ? "◆" : "", color: () => C.review },
      { key: "statement", title: "Wording" },
    ],
    detail: r => loadDetail({ kind: "req", id: r.id }),
  });
}

function drawFindings() {
  const num = id => parseInt(id.split("-").pop(), 10);
  const sev = ["HIGH", "MEDIUM", "LOW", "WITHDRAWN"];
  listPage({
    key: "findings", rows: state.findings, id: f => f.id, placeholder: "Search findings",
    filters: [
      { key: "severity", all: "Any severity", options: opts(sev, s => s[0] + s.slice(1).toLowerCase()) },
      { key: "cited", all: "Cited or not", options: [["Cited by a requirement", "1"], ["Cited by none", "0"]] },
    ],
    keep: (f, u, q) => (!u.severity || f.severity === u.severity) &&
      (!u.cited || (f.requirements.length > 0) === (u.cited === "1")) && (!q || f.search.includes(q)),
    columns: [
      { key: "id", title: "Finding", width: 90, mono: true, sort: f => num(f.id) },
      { key: "severity", title: "Severity", width: 95, text: f => f.severity[0] + f.severity.slice(1).toLowerCase(),
        color: f => SEVERITY_COLOR[f.severity], sort: f => sev.indexOf(f.severity) },
      { key: "requirements", title: "Requirements", width: 110, text: f => f.requirements.length || "",
        color: () => C.dim, sort: f => f.requirements.length },
      { key: "subject", title: "Subject" },
    ],
    detail: f => loadDetail({ kind: "finding", id: f.id }),
  });
}

// ---- coverage

function drawCoverage() {
  const cov = state.coverage, u = ui.coverage, el = $("#page");
  if (!cov.measured && !cov.reported) {
    el.innerHTML = `<div class="empty"><h2>Not measured yet</h2><p>Every run measures code coverage and
      writes the report when it finishes. Run the suite to fill this page.</p>
      <button class="primary" data-run="suite">Run the suite</button></div>`;
    return;
  }
  const kinds = [["line", "Lines"], ["branch", "Branches"], ["expr", "Expressions"], ["toggle", "Toggles"]];
  const warn = !cov.reported ? "Measured, but no report yet. Rebuild the report."
    : cov.stale ? "The report is older than the data, or covers different modules. Rebuild the report." : "";
  el.innerHTML = `<div class="cards">` + kinds.map(([k, t]) => {
    const v = cov.summary[k];
    return `<div class="card"><h4>${t.toUpperCase()}</h4><div class="value" style="font-size:28px;font-weight:700;color:${C.accent}">${v ? v[0].toFixed(1) + "%" : "--"}</div>
      <div class="dim">${v ? `${v[1]} of ${v[2]} points` : "not reported"}</div></div>`;
  }).join("") + `<div class="card" style="flex:2"><h4>MEASUREMENT</h4>
      <p class="dim">${cov.modules} module(s) measured, the newest ${esc(cov.measuredAgo)}. Report written ${esc(cov.reportedAgo)},
      over ${cov.reportedModules} module(s). Vendor IP and the testbench are excluded.</p>
      ${warn ? `<p style="color:${C.warning}">${warn}</p>` : ""}
      <button data-run="suite">Run the suite</button> <button data-run="report">Rebuild report</button></div></div>
    <p class="dim" style="margin:0">A line that ran is not a line that was tested. HK-F-01 was a comparison that could never
      be true, on a line that executed every cycle and so counted as covered. Read red as "nothing reached this", amber as
      "some of this line's points were never hit" -- a branch not taken, a bit that never toggled -- and the rest as
      "something ran this", no more.</p>
    <div class="split"><div class="tablewrap" style="flex:2;max-width:470px"><table class="list">
      <colgroup><col><col style="width:70px"><col style="width:56px"><col style="width:56px"></colgroup>
      <thead></thead><tbody></tbody></table></div>
      <div class="source"><div class="bar"><span class="file"></span>
        <button id="prev" title="Previous line nothing reached, or only partly">↑ Previous</button>
        <button id="next" title="Next line nothing reached, or only partly">↓ Next</button>
        <button id="open">Open in editor</button></div>
        <div class="code"></div><div id="points"></div></div></div>`;
  const cols = [["name", "File"], ["percent", "Reached"], ["missed", "None"], ["partly", "Part"]];
  const redraw = () => {
    const rows = [...cov.files].sort((a, b) => {
      const x = a[u.sort[0]], y = b[u.sort[0]];
      return (x < y ? -1 : x > y ? 1 : 0) * u.sort[1];
    });
    $("#page thead").innerHTML = "<tr>" + cols.map(([k, t]) =>
      `<th data-sort="${k}">${t}${k === u.sort[0] ? `<span class="arrow"> ${u.sort[1] > 0 ? "▲" : "▼"}</span>` : ""}</th>`).join("") + "</tr>";
    $("#page tbody").innerHTML = rows.map(f => {
      const pc = f.missed === 0 ? C.ok : f.percent >= 80 ? C.warning : C.error;
      return `<tr data-id="${esc(f.name)}" class="${f.name === u.sel ? "sel" : ""}"><td class="mono">${esc(f.name)}</td>
        <td style="color:${pc}">${Math.round(f.percent)}%</td><td style="color:${C.error}">${f.missed || ""}</td>
        <td style="color:${C.warning}">${f.partly || ""}</td></tr>`;
    }).join("");
  };
  $("#page thead").onclick = e => { const th = e.target.closest("th"); if (!th) return;
    u.sort = [th.dataset.sort, u.sort[0] === th.dataset.sort ? -u.sort[1] : (th.dataset.sort === "name" ? 1 : -1)]; redraw(); };
  $("#page tbody").onclick = e => { const tr = e.target.closest("tr"); if (tr) openCoverageFile(tr.dataset.id); };
  $("#prev").onclick = () => stepCoverage(-1);
  $("#next").onclick = () => stepCoverage(1);
  $("#open").onclick = () => {
    const f = ui.coverage;
    if (f.source) follow(`fsv:src/${f.source}:${(f.lines[f.cur] || { n: 1 }).n}`);
  };
  redraw();
  if (cov.files.length) openCoverageFile(u.sel && cov.files.some(f => f.name === u.sel) ? u.sel : cov.files[0].name);
}

async function openCoverageFile(name) {
  const u = ui.coverage;
  u.sel = name;
  for (const tr of document.querySelectorAll("#page tbody tr")) tr.classList.toggle("sel", tr.dataset.id === name);
  const f = state.coverage.files.find(x => x.name === name) || {};
  $("#page .file").textContent = `${name} · ${f.missed} of ${f.counted} lines never reached, ${f.partly} partly`;
  const d = await api("/api/coverage/file?name=" + encodeURIComponent(name));
  u.lines = d.lines || [];
  u.source = d.source;
  $("#page .code").innerHTML = u.lines.map((l, i) => {
    const g = l.count === null ? "" : l.count >= 1e9 ? "many" : l.count;
    const cls = l.count === 0 ? "miss" : l.partial ? "part" : "";
    return `<div data-i="${i}" class="${cls}"><span class="g">${g}</span>${esc(l.text) || " "}</div>`;
  }).join("");
  $("#page .code").onclick = e => { const d = e.target.closest("div[data-i]"); if (d) pickLine(+d.dataset.i); };
  u.cur = -1;
  stepCoverage(1);
}

function pickLine(i) {
  const u = ui.coverage, l = u.lines[i];
  if (!l) return;
  u.cur = i;
  for (const d of document.querySelectorAll(".code .cur")) d.classList.remove("cur");
  const row = document.querySelector(`.code div[data-i="${i}"]`);
  row.classList.add("cur");
  row.scrollIntoView({ block: "center" });
  let t;
  if (l.count === null) t = `Line ${l.n}: not a coverage point.`;
  else {
    t = l.count === 0 ? `Line ${l.n}: never reached.` : `Line ${l.n}: reached ${l.count.toLocaleString()} times.`;
    if (l.points) t += `  ${l.hit} of ${l.points} points hit (${l.kinds.join(", ")}).`;
    if (l.missed.length) t += `\nNever hit:  ${l.missed.join(";  ")}${l.moreMissed ? `;  and ${l.moreMissed} more` : ""}`;
  }
  $("#points").textContent = t;
}

function stepCoverage(dir) {
  const u = ui.coverage;
  const marked = u.lines.map((l, i) => (l.count === 0 || l.partial) ? i : -1).filter(i => i >= 0);
  if (!marked.length) { if (u.cur < 0 && u.lines.length) pickLine(0); return; }
  const after = marked.filter(i => dir > 0 ? i > u.cur : i < u.cur);
  pickLine(after.length ? (dir > 0 ? after[0] : after[after.length - 1]) : (dir > 0 ? marked[0] : marked[marked.length - 1]));
}

// ---- links

async function follow(href) {
  const [kind, ...rest] = href.slice(4).split("/");
  const arg = rest.join("/");
  if (kind === "test") { const i = arg.indexOf("/"); ui.tests.sel = arg; clearIfHidden("tests", t => `${t.module}/${t.name}` === arg); show("tests"); }
  else if (kind === "tests") { const [k, v] = [rest[0], rest.slice(1).join("/")]; resetFilters("tests"); ui.tests[k] = v; show("tests"); }
  else if (kind === "req") { ui.requirements.sel = arg; clearIfHidden("requirements", r => r.id === arg); show("requirements"); }
  else if (kind === "reqs") { const [k, v] = [rest[0], rest.slice(1).join("/")]; resetFilters("requirements"); ui.requirements[k] = v; show("requirements"); }
  else if (kind === "finding") { ui.findings.sel = arg; clearIfHidden("findings", f => f.id === arg); show("findings"); }
  else if (kind === "jama") {
    if (!state.jama.some(j => j.id === arg)) { toast(`${arg} is not in the Jama snapshot (docs/requirements/jama.yaml)`); return; }
    ui.trace.sel = arg; clearIfHidden("trace", j => j.id === arg); show("trace");
  }
  else if (kind === "jamas") { const [k, v] = [rest[0], rest.slice(1).join("/")]; resetFilters("trace"); ui.trace[k] = v; show("trace"); }
  else if (kind === "page") show(arg);
  else if (kind === "run") startRun("module", arg);
  else if (kind === "open" || kind === "src") {
    const body = kind === "open" ? { module: rest[0], line: +rest[1] || 1 }
      : { path: "/" + arg.replace(/^\/+/, "").replace(/:(\d+)$/, ""), line: +(arg.match(/:(\d+)$/) || [0, 1])[1] };
    const r = await api("/api/open", body);
    toast(r.ok ? `Opened ${r.opened} in VS Code` : r.error);
  }
}

function resetFilters(key) {
  const u = ui[key];
  for (const k of Object.keys(u)) if (!["sort", "sel"].includes(k)) u[k] = "";
}

function clearIfHidden(key, match) {
  // If the target would be filtered out, clear the filters so it can be shown.
  const u = ui[key];
  const rows = { tests: state.tests, requirements: state.requirements, findings: state.findings, trace: state.jama }[key];
  const row = rows.find(match);
  if (!row) return;
  const q = (u.q || "").toLowerCase();
  const hay = row.search || (row.id + " " + (row.statement || "")).toLowerCase();
  const filtered = (q && !hay.includes(q)) || Object.keys(u).some(k =>
    !["sort", "sel", "q"].includes(k) && u[k] !== "" && u[k] !== undefined);
  if (filtered) resetFilters(key);
}

// ---- runs

async function startRun(kind, module) {
  if (kind === "selected") {
    if (page !== "tests" || !ui.tests.sel) { toast("Select a test on the Tests page first"); return; }
    kind = "module"; module = ui.tests.sel.split("/")[0];
  }
  $("#runmenu").classList.add("hidden");
  const r = await api("/api/run", { kind, module });
  if (r.error) { toast(r.error); return; }
  runText = "";
  jobOffset = 0;
  openConsole("run");
  toast(`Running ${r.label}`);
  watchJob();
}

function watchJob() {
  clearInterval(polling);
  setRunning(true);
  polling = setInterval(async () => {
    const s = await api("/api/run?since=" + jobOffset);
    if (s.lines && s.lines.length) {
      runText += s.lines.join("\n") + "\n";
      jobOffset = s.offset;
      if ($("#console-source").value === "run") showRunText(true);
    }
    const bar = $("#bar");
    bar.classList.toggle("busy", !s.total);
    $("#bar-fill").style.width = s.total ? `${100 * s.done / s.total}%` : "30%";
    $("#phase").textContent = s.module ? `${s.done} of ${s.total} · ${s.module} ${String(s.outcome).toLowerCase()}` : (s.phase || "");
    if (!s.running) {
      clearInterval(polling);
      setRunning(false);
      await reload();
      const o = state.outcomes;
      // pytest exits 1 when a test fails, which this suite always has; anything
      // else, or no test reported, means the run itself went wrong.
      const broke = s.code > 1 || (s.code !== 0 && !s.done);
      toast(s.code < 0 ? `Cancelled after ${Math.round(s.seconds)} s`
        : broke ? `The run did not complete (exit ${s.code}); see the console`
        // Runs that simulate nothing leave the results as they were.
        : /fast checks|coverage report/.test(s.label) ? `${s.label[0].toUpperCase() + s.label.slice(1)}: ${s.code ? "failed -- see the console" : "done"}`
        : `Finished in ${(s.seconds / 60).toFixed(1)} min: ${o.passed} passing, ${o.failed} failing` +
          (state.blocking ? ` -- ${state.blocking} would block a merge` : ", nothing new"));
      if (broke) openConsole("run");
    }
  }, 1000);
}

function setRunning(on) {
  const b = $("#run");
  b.textContent = on ? "Cancel" : "Run";
  b.className = on ? "danger" : "primary";
  $("#console-note").textContent = on ? "running…" : "";
  $("#bar").classList.toggle("on", on);
  if (!on) $("#phase").textContent = `Last run ${state ? state.resultsAgo : ""}`;
}

// ---- console: the app's run output, or any module's log from the last run

function consoleSources() {
  const sel = $("#console-source"), keep = sel.value || "run";
  const modules = [...new Set(state.tests.map(t => t.module))].sort();
  sel.innerHTML = `<option value="run">Run started here</option>` +
    modules.map(m => `<option value="log:${esc(m)}">Log: ${esc(m)}</option>`).join("");
  sel.value = [...sel.options].some(o => o.value === keep) ? keep : "run";
}

function showRunText(follow) {
  const pre = $("#console-text");
  const atEnd = pre.scrollTop + pre.clientHeight >= pre.scrollHeight - 20;
  pre.textContent = runText || "No run started from here yet. Press Run, and its output -- pytest, " +
    "every worker, the simulator -- appears here as it happens.\n\nFor a run made from a terminal " +
    "(make test), pick a module's log above.";
  $("#console-note").textContent = $("#run").textContent === "Cancel" ? "running…" : "";
  if ($("#console-source").value !== "run") $("#console-note").textContent = "";
  if (follow && atEnd) pre.scrollTop = pre.scrollHeight;
}

async function showSource() {
  const v = $("#console-source").value;
  if (v === "run") { showRunText(false); return; }
  const module = v.slice(4);
  const d = await api("/api/log?module=" + encodeURIComponent(module));
  const pre = $("#console-text");
  pre.textContent = d.text || d.error || "";
  $("#console-note").textContent = d.ago ? `written ${d.ago}` : "";
  pre.scrollTop = 0;
}

function openConsole(source) {
  consoleSources();
  if (source) $("#console-source").value = source;
  $("#console").classList.remove("hidden");
  showSource();
}

// ---- palette

function openPalette() {
  const entries = [
    ...PAGES.map(([k, n]) => [n, "page", `fsv:page/${k}`]),
    ...state.tests.map(t => [t.name, `${t.label} · ${t.module}`, `fsv:test/${t.module}/${t.name}`]),
    ...state.jama.map(j => [j.id, `${j.rollup} · ${j.name}`, `fsv:jama/${j.id}`]),
    ...state.requirements.map(r => [r.id, r.statement.slice(0, 90), `fsv:req/${r.id}`]),
    ...state.findings.map(f => [f.id, `${f.severity} · ${f.subject.slice(0, 90)}`, `fsv:finding/${f.id}`]),
  ];
  const input = $("#palette-input"), list = $("#palette-list");
  let shown = [], at = 0;
  const draw = () => {
    const words = input.value.toLowerCase().split(/\s+/).filter(Boolean);
    shown = entries.filter(e => words.every(w => (e[0] + " " + e[1]).toLowerCase().includes(w))).slice(0, 200);
    at = Math.min(at, Math.max(shown.length - 1, 0));
    list.innerHTML = shown.map((e, i) => `<div data-i="${i}" class="${i === at ? "on" : ""}">${esc(e[0])}<span class="h">${esc(e[1])}</span></div>`).join("");
  };
  const go = i => { const e = shown[i]; close(); if (e) follow(e[2]); };
  const close = () => $("#palette").classList.add("hidden");
  input.value = "";
  input.oninput = () => { at = 0; draw(); };
  input.onkeydown = e => {
    if (e.key === "ArrowDown") { at = Math.min(at + 1, shown.length - 1); draw(); e.preventDefault(); }
    else if (e.key === "ArrowUp") { at = Math.max(at - 1, 0); draw(); e.preventDefault(); }
    else if (e.key === "Enter") go(at);
    else if (e.key === "Escape") close();
  };
  list.onclick = e => { const d = e.target.closest("div[data-i]"); if (d) go(+d.dataset.i); };
  $("#palette").onclick = e => { if (e.target.id === "palette") close(); };
  $("#palette").classList.remove("hidden");
  draw();
  input.focus();
}

// ---- start-up and keeping up with runs from a terminal

async function reload() {
  state = await api("/api/state");
  lastStamp = state.stamp;
  show(page);
}

async function main() {
  const want = location.hash.slice(1);
  if (PAGES.some(p => p[0] === want)) page = want;
  try { await reload(); } catch (e) { document.body.innerHTML = `<p style="padding:20px">${esc(e.message)}</p>`; return; }
  $("#nav").onclick = e => { const b = e.target.closest("button"); if (b) show(b.dataset.page); };
  document.addEventListener("click", e => {
    const a = e.target.closest("a[href^='fsv:'], [data-go]");
    if (a) { e.preventDefault(); follow(a.getAttribute("href") || a.dataset.go); return; }
    const r = e.target.closest("[data-run]");
    if (r) { e.preventDefault(); startRun(r.dataset.run); return; }
    if (!e.target.closest(".runwrap")) $("#runmenu").classList.add("hidden");
  });
  $("#run").onclick = async () => {
    if ($("#run").textContent === "Cancel") { await api("/api/cancel", {}); return; }
    $("#runmenu").classList.toggle("hidden");
  };
  $("#console-toggle").onclick = () => {
    if ($("#console").classList.contains("hidden")) {
      // Opened from a test page, show that test's log first.
      const sel = page === "tests" && ui.tests.sel ? "log:" + ui.tests.sel.split("/")[0] : null;
      openConsole(runText ? "run" : sel);
    } else $("#console").classList.add("hidden");
  };
  $("#console-close").onclick = () => $("#console").classList.add("hidden");
  $("#console-source").onchange = showSource;
  $("#search-open").onclick = openPalette;
  document.addEventListener("keydown", e => {
    const typing = ["INPUT", "SELECT", "TEXTAREA"].includes(document.activeElement.tagName);
    if ((e.key === "/" && !typing) || (e.key.toLowerCase() === "k" && (e.ctrlKey || e.metaKey))) { e.preventDefault(); openPalette(); }
    else if (page === "coverage" && e.key === "F8") { e.preventDefault(); stepCoverage(e.shiftKey ? -1 : 1); }
    else if (e.key === "Escape") $("#runmenu").classList.add("hidden");
  });
  if (state.job && state.job.running) { jobOffset = 0; watchJob(); }
  else {
    setRunning(false);
    // A run started here before the page was (re)loaded: keep its output.
    if (state.job) { const s = await api("/api/run?since=0"); runText = (s.lines || []).join("\n") + "\n"; jobOffset = s.offset || 0; }
  }
  // A run made from a terminal (`make test`) is picked up on its own.
  setInterval(async () => {
    if ($("#run").textContent === "Cancel") return;
    try {
      const s = await api("/api/stamp");
      if (s.job && s.job.running) { watchJob(); return; }
      if (s.stamp !== lastStamp) await reload();
    } catch (e) { /* the server was stopped; keep what is shown */ }
  }, 3000);
}

main();
