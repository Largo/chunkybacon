// A Web Worker with a PicoRuby.wasm of its own, for the lessons with
// "engine": "picoruby" (docs/HANDOVER.md §6m, §6r). The same runtime the
// page's shell runs on (assets/picoruby/, tools/vendor_picoruby.rb), but a
// second instance, and off the page's thread:
//
// - PicoRuby counts its time slices in ticks that only JavaScript advances,
//   so a loop that never ends never gives the thread back. Here it blocks
//   this worker, and picoruby_lab.js ends the worker after the time limit.
// - PicoRuby keeps its JavaScript references and handlers in globals
//   (globalThis.picorubyRefs, picorubyEventHandlers): two instances in one
//   window would mix them up.
//
// picoruby_worker_core.js turns the scheduler (in batches, yielding to this
// worker's event loop between them) and answers the requests; this file is
// its host in a browser: messages, the HTTP of the simulated Pico (sync
// XHR, canned answers as a fallback), the camera's pictures and the files
// of html/pico_sim/.
//
//   in   {id, kind: "run", sid, code, tabs, board, inputs} | {id, kind: "drop", sid}
//        {kind: "input", key, value}   (at once, even while a run goes on)
//   out  {id, status: "ok"|"error"|"syntax", output, inspect, errorClass, line, file, message, irbs, board}
//        {id, progress: text}   what a run printed so far
//        {id, board: kind, text}   the bench's messages (state, epd_frame, lcd, ble, log)
//        {ready: true, version} once, or {failed: message}
import createModule from "./assets/picoruby/picoruby.js";
import { bootCore } from "./picoruby_worker_core.js";

const base = new URL(".", import.meta.url);
const syncGet = (url, binary) => {
  const xhr = new XMLHttpRequest();
  xhr.open("GET", new URL(url, base).href, false);
  if (binary) xhr.overrideMimeType("text/plain; charset=x-user-defined");
  xhr.send(null);
  return xhr;
};

// The Pico's HTTP, mapped onto what this origin can reach (no nginx change):
// rubygems.org through the gem bridge, www.ruby-lang.org through the proxy,
// other https hosts directly (CORS), http:// never (mixed content). When
// that fails: the canned answer in assets/data/pico/http/, marked with the
// header x-chunky-canned; without one, status 0 (the socket raises).
const CANNED_ONLY = [];   // hosts that never answer a browser (probe P6)
function slug(url) {
  const u = new URL(url);
  return `${u.host}__${(u.pathname + u.search).replace(/^\//, "").replace(/[^A-Za-z0-9.]+/g, "_")}`;
}
function canned(url) {
  try {
    const xhr = syncGet(`assets/data/pico/http/${slug(url)}.json`);
    if (xhr.status !== 200) return "0\n\n\n";
    const data = JSON.parse(xhr.responseText);
    const headers = Object.assign({}, data.headers || {}, { "x-chunky-canned": "1" });
    const lines = Object.keys(headers).map(k => `${k}: ${headers[k]}`).join("\n");
    return `${data.status || 200}\n${lines}\n\n${data.body || ""}`;
  } catch (e) {
    return "0\n\n\n";
  }
}
function http(method, url, headersJson, body) {
  let target = null;
  try {
    const u = new URL(url);
    if (u.protocol === "https:" && !CANNED_ONLY.includes(u.host)) {
      if (u.host === "rubygems.org" && u.pathname.startsWith("/api/v1/gems/")) target = `/rubygems${u.pathname}${u.search}`;
      else if (u.host === "www.ruby-lang.org") target = `/proxy/ruby-lang${u.pathname}${u.search}`;
      else target = u.href;
    }
  } catch (e) { return "0\n\n\n"; }
  if (!target) return canned(url);
  try {
    const xhr = new XMLHttpRequest();
    xhr.open(method, new URL(target, base).href, false);
    try { xhr.timeout = 8000; } catch (e) { /* not for sync XHRs here */ }
    let headers = {};
    try { headers = JSON.parse(headersJson || "{}"); } catch (e) { headers = {}; }
    Object.keys(headers).forEach(k => {
      if (!/^(host|user-agent|connection|content-length)$/i.test(k)) xhr.setRequestHeader(k, headers[k]);
    });
    xhr.send(method === "GET" || method === "HEAD" ? null : body);
    if (!xhr.status || xhr.status >= 500) return canned(url);
    const lines = xhr.getAllResponseHeaders().trim().split(/\r?\n/).filter(Boolean)
      .filter(l => !/^(content-encoding|content-length|transfer-encoding):/i.test(l)).join("\n");
    return `${xhr.status}\n${lines}\n\n${xhr.responseText}`;
  } catch (e) {
    return canned(url);
  }
}

// a 160x120 PGM of assets/data/pico/camera/, as hex (a NUL would end the
// string on its way into PicoRuby)
function cameraHex(name) {
  try {
    const xhr = syncGet(`assets/data/pico/camera/${String(name).replace(/[^a-z0-9_-]/gi, "")}.pgm`, true);
    if (xhr.status !== 200) return "";
    const text = xhr.responseText;
    let hex = "";
    for (let i = 0; i < text.length; i++) hex += (text.charCodeAt(i) & 0xff).toString(16).padStart(2, "0");
    return hex;
  } catch (e) { return ""; }
}

async function getText(path) {
  const response = await fetch(new URL(path, base), { cache: "no-cache" });
  if (!response.ok) throw new Error(`${path}: HTTP ${response.status}`);
  return response.text();
}

// html/pico_sim/manifest.txt: one file per line, in load order
async function simFiles() {
  const names = (await getText("pico_sim/manifest.txt")).split("\n").map(l => l.replace(/#.*/, "").trim()).filter(Boolean);
  const codes = await Promise.all(names.map(name => getText(`pico_sim/${name}`)));
  return names.map((name, i) => ({ name, code: codes[i] }));
}

const host = {
  progress(id, text) { postMessage({ id, progress: text }); },
  board(id, kind, text) { postMessage({ id, board: kind, text }); },
  alive(id) { postMessage({ id, alive: true }); },
  http, cameraHex, simFiles
};

const boot = (async () => {
  const labCode = await getText("picoruby_lab.rb");
  const core = await bootCore({
    createModule, labCode, host,
    moduleArgs: { locateFile: name => new URL(`assets/picoruby/${name}`, import.meta.url).href }
  });
  postMessage({ ready: true, version: core.version });
  return core;
})().catch(e => {
  postMessage({ failed: String((e && e.message) || e) });
  throw e;
});

onmessage = async event => {
  const data = event.data;
  const core = await boot;
  if (data.kind === "input") { core.input(data.key, data.value); return; }
  let result;
  try {
    result = await core.handle(data);
  } catch (e) {
    result = { status: "error", errorClass: "RuntimeError", line: null, file: "",
               message: `PicoRuby: ${(e && e.message) || e}`, output: "", irbs: 0, board: "" };
  }
  postMessage(Object.assign({ id: data.id }, result));
};
