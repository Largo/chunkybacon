// The heart of picoruby_worker.js, as an ES module without the worker's
// own globals, so that node can run it too (test/pico_wasm_test.mjs). It
// turns PicoRuby's scheduler for one request at a time and answers it
// (docs/HANDOVER.md §6m, §6r).
//
// A request runs in batches of 16 ms (init.iife.js's): between batches the
// core yields to the event loop - at once after progress (a MessageChannel
// ping, no 4 ms clamp), 4 ms when every Task sleeps. While it yields:
//
// - input messages arrive (core.input) and Ruby reads them synchronously
//   through PicoBoard.input - a button pressed on the bench reaches a loop
//   that is running;
// - what the run printed so far goes out (host.progress), and so do the
//   bench's state snapshots (host.board);
// - Net::HTTP's synchronous XHRs are fine (workers allow them).
//
// The host (picoruby_worker.js in a browser, a fake in node) gives:
//   progress(id, text)            output since the last flush
//   board(id, kind, text)         "state" | "epd_frame" | "ble" | "log"
//   http(method, url, headersJson, body) -> "status\nheaders\n\nbody"
//   cameraHex(name) -> hex string
//   simFiles() -> Promise<[{name, code}]>   html/pico_sim/, in manifest order
//
// Requests: {id, kind: "run", sid, code, tabs: [{name, code}], board: JSON
// string or "", inputs: {key: value}} | {id, kind: "drop", sid}.
// Answers: {status, output, inspect, errorClass, line, file, message, irbs,
// board} (board: the summary JSON, "" without a board).

const TICK = 4;       // ms, MRB_TICK_UNIT of the wasm build (init.iife.js)
const BATCH = 16;     // ms of Ruby before the event loop gets a turn
const IDLE = 4;       // ms to wait when every Task sleeps
const ALIVE_EVERY = 500; // ms between "still alive" messages of a run
const STATE_EVERY = 33;  // ms: "state" snapshots are coalesced to the latest

// the require stubs: `require "gpio"` succeeds as on R2P2, the classes are
// already there (html/pico_sim/boot.rb loaded them)
export const STUBS = ["gpio", "pwm", "adc", "i2c", "spi", "pio", "cyw43", "network", "ble",
  "hcsr04", "camera", "socket", "net/http", "env"];

// a zero-delay turn of the event loop: setTimeout(0) is clamped to 4 ms
// after a few nested calls, a MessageChannel message is not
let channel = null;
const waiting = [];
function yieldNow(ms) {
  if (ms > 0 || typeof MessageChannel === "undefined") return new Promise(r => setTimeout(r, ms));
  if (!channel) {
    channel = new MessageChannel();
    channel.port1.onmessage = () => { const r = waiting.shift(); if (r) r(); };
  }
  return new Promise(r => { waiting.push(r); channel.port2.postMessage(0); });
}

export async function bootCore({ createModule, moduleArgs = {}, labCode, host }) {
  let Module = null;
  let output = [];      // everything the current request printed
  let streamed = 0;     // how many of those entries went out as progress
  let lastTick = 0;
  let request = null;
  let answer = null;
  let current = null;   // the request being run
  let summary = "";
  let lastYield = performance.now();
  let lastAlive = 0;
  const inputs = {};
  let pendingState = null;
  let lastState = 0;
  let pendingBoard = [];
  let simReady = null;
  let stubsWritten = false;

  globalThis.PicoLab = {
    take() { const text = request; request = null; return text; },
    answer(text) { answer = String(text); }
  };

  // what Ruby (html/pico_sim/host_js.rb) calls; all-string arguments and
  // answers (docs/PICORUBY_SHELL.md §5 #4, #6)
  globalThis.PicoBoard = {
    now() { return current ? String(performance.now() - current.started) : "0"; },
    // ms since the core last gave the event loop a turn: PicoSim.breathe
    // sleeps a millisecond when it is more than 10
    busy() { return String(performance.now() - lastYield); },
    input(key) { const v = inputs[String(key)]; return v === undefined || v === null ? "" : String(v); },
    post(kind, text) {
      kind = String(kind);
      if (kind === "state") { pendingState = String(text); return; }
      pendingBoard.push([kind, String(text)]);
    },
    config() { return current && current.board ? current.board : ""; },
    summary(text) { summary = String(text); },
    http(method, url, headers, body) {
      return String(host.http(String(method), String(url), String(headers || "{}"), String(body || "")));
    },
    cameraHex(name) { return String(host.cameraHex ? host.cameraHex(String(name)) : ""); },
    // the require stubs' names, one per line (the lab reloads tabs, not them)
    stubs() { return STUBS.join("\n"); },
    // the sim's files, in manifest order, as the lab requires them
    simFiles() { return current && current.simFiles ? current.simFiles : ""; }
  };

  function step() {
    const now = performance.now();
    while (now - lastTick >= TICK) { Module._mrb_tick_wasm(); lastTick += TICK; }
    return Module._mrb_run_step_status ? Module._mrb_run_step_status() : (Module._mrb_run_step() < 0 ? -1 : 1);
  }

  // +force+: the run has answered - its output goes with the answer, only
  // the bench's messages still go out here
  function flush(force) {
    if (!current) return;
    if (!force && output.length > streamed) {
      const text = output.slice(streamed).join("");
      streamed = output.length;
      host.progress(current.id, text);
    }
    const now = performance.now();
    if (pendingState !== null && (force || now - lastState >= STATE_EVERY)) {
      host.board(current.id, "state", pendingState);
      pendingState = null;
      lastState = now;
    }
    const board = pendingBoard;
    pendingBoard = [];
    board.forEach(([kind, text]) => host.board(current.id, kind, text));
  }

  // one request, answered: no time limit here - the page has one
  async function ask(text) {
    request = text;
    answer = null;
    while (answer === null) {
      const started = performance.now();
      let idle = false;
      while (answer === null && performance.now() - started < BATCH) {
        const status = step();
        if (status < 0) throw new Error("PicoRuby's scheduler failed");
        if (status === 0) { idle = true; break; }
      }
      if (answer !== null) break;
      flush(false);
      // the page's quiet limit (picoruby_lab.js): a run that gives the event
      // loop a turn is alive, one stuck in a loop without a sleep is not
      if (current && host.alive && performance.now() - lastAlive >= ALIVE_EVERY) {
        lastAlive = performance.now();
        host.alive(current.id);
      }
      await yieldNow(idle ? IDLE : 0);
      lastYield = performance.now();
    }
    return answer;
  }

  // "error\tNoMethodError\t3\tundefined method ...\t0": the message is
  // everything between the line and the last field; a line "epd.rb:12"
  // points into a tab
  function parse(text) {
    const parts = String(text).split("\t");
    const kind = parts[0];
    if (kind === "syntax") return { status: "syntax", message: parts.slice(1).join("\t") };
    if (kind === "dropped") return { status: "dropped" };
    const irbs = Number(parts.pop()) || 0;
    if (kind === "error") {
      const at = String(parts[2] || "");
      const colon = at.lastIndexOf(":");
      const file = colon >= 0 ? at.slice(0, colon) : "";
      const line = Number(colon >= 0 ? at.slice(colon + 1) : at) || null;
      return { status: "error", errorClass: parts[1], line, file, message: parts.slice(3).join("\t"), irbs };
    }
    return { status: "ok", inspect: parts.slice(1).join("\t"), irbs };
  }

  // the tabs of the cell go to /lib/<name>, as on R2P2; a name like
  // "net/x.rb" makes its directory
  function writeTabs(tabs) {
    const FS = Module.FS;
    FS.mkdirTree("/lib");
    if (!stubsWritten) {
      STUBS.forEach(name => {
        const path = `/lib/${name}.rb`;
        FS.mkdirTree(path.slice(0, path.lastIndexOf("/")));
        FS.writeFile(path, "# simulated: see html/pico_sim (the classes are loaded already)\n");
      });
      stubsWritten = true;
    }
    (tabs || []).forEach(tab => {
      const name = String(tab.name || "").replace(/^\/+/, "");
      if (!name || name.includes("..")) return;
      const path = `/lib/${name}`;
      FS.mkdirTree(path.slice(0, path.lastIndexOf("/")));
      FS.writeFile(path, String(tab.code || ""));
    });
  }

  // html/pico_sim/*.rb to /sim, the first time a request has a board
  async function ensureSim() {
    if (!simReady) {
      simReady = (async () => {
        const files = await host.simFiles();
        const FS = Module.FS;
        files.forEach(file => {
          const path = `/sim/${file.name}`;
          FS.mkdirTree(path.slice(0, path.lastIndexOf("/")));
          FS.writeFile(path, file.code);
        });
        return files.map(file => `/sim/${file.name.replace(/\.rb$/, "")}`).join("\n");
      })();
    }
    return simReady;
  }

  async function run(req) {
    const { id, kind, sid } = req;
    const code = String(req.code || "");
    output = [];
    streamed = 0;
    summary = "";
    pendingState = null;
    pendingBoard = [];
    current = { id, board: String(req.board || ""), started: performance.now(), simFiles: "" };
    try {
      if (kind === "run") {
        writeTabs(req.tabs);
        // loading the simulator's files (first board run) is no loop
        if (current.board && host.alive) host.alive(id);
        if (current.board) current.simFiles = await ensureSim();
        if (current.board && host.alive) host.alive(id);
        // each run's inputs are the page's full set: a key the page has
        // dropped (unmount, a ble.line already seen) must not linger here
        for (const k of Object.keys(inputs)) delete inputs[k];
        Object.assign(inputs, req.inputs || {});
      }
      current.started = performance.now();
      const text = kind === "run" ? `run\t${sid}\t${code}` : `drop\t${sid}`;
      const result = parse(await ask(text));
      flush(true);
      // the mark ended a line a `print` left open (picoruby_lab.rb)
      let out = output.join("").replace(/\u0001\n$/, "");
      // a raised error is also reported by the Task machinery, as its last
      // line with that error - once is enough; a cell's own line that looks
      // the same stays (only the last one goes, and only for the error)
      if (result.status === "error") {
        const line = `Exception in task: #<${result.errorClass}: ${result.message}>\n`;
        const at = out.lastIndexOf(line);
        if (at >= 0 && (at === 0 || out[at - 1] === "\n")) out = out.slice(0, at) + out.slice(at + line.length);
      }
      result.output = out;
      result.board = summary;
      return result;
    } finally {
      current = null;
      output = [];
    }
  }

  Module = await createModule(Object.assign({}, moduleArgs, {
    print: line => { output.push(line + "\n"); },
    printErr: line => { output.push(line + "\n"); }
  }));
  Module.ccall("picorb_init", "number", [], []);
  Module.ccall("picorb_create_task_with_filename", "number", ["string", "string"], [labCode, "picoruby_lab.rb"]);
  lastTick = performance.now();

  // one request at a time, in order; inputs go in at once, even mid-run
  let chain = Promise.resolve();
  const core = {
    Module,
    inputs,
    input(key, value) { inputs[String(key)] = value === undefined || value === null ? "" : String(value); },
    handle(req) {
      const next = chain.then(() => run(req));
      chain = next.catch(() => {});
      return next;
    }
  };
  const probe = await core.handle({ id: 0, kind: "run", sid: "boot",
    code: '"#{RUBY_ENGINE} #{RUBY_ENGINE_VERSION}, PicoRuby #{PICORUBY_VERSION}"' });
  if (probe.status !== "ok") throw new Error(`picoruby_lab.rb did not start: ${JSON.stringify(probe)}`);
  await core.handle({ id: 0, kind: "drop", sid: "boot" });
  core.version = probe.inspect.replace(/^"|"$/g, "");
  return core;
}
