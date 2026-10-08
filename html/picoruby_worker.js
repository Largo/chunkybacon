// A Web Worker with a PicoRuby.wasm of its own, for the PicoRuby lesson
// (docs/HANDOVER.md §6m). The same runtime the page's shell runs on
// (assets/picoruby/, tools/vendor_picoruby.rb), but a second instance, and
// off the page's thread:
//
// - PicoRuby counts its time slices in ticks that only JavaScript advances,
//   so a loop that never ends never gives the thread back. Here it blocks
//   this worker, and picoruby_lab.js ends the worker after the time limit.
// - PicoRuby keeps its JavaScript references and handlers in globals
//   (globalThis.picorubyRefs, picorubyEventHandlers): two instances in one
//   window would mix them up.
//
// picoruby_lab.rb is a Task that takes requests (PicoLab.take) and answers
// them (PicoLab.answer). For each message this file turns PicoRuby's
// scheduler itself - the tick and Module._mrb_run_step_status, what
// init.iife.js does on timers - until the answer is there, and posts it
// back with what the run printed (Module.print).
//
//   in   {id, kind: "run", sid, code}  |  {id, kind: "drop", sid}
//   out  {id, status: "ok"|"error"|"syntax", output, inspect, errorClass, line, message, irbs}
//        {ready: true, version} once, or {failed: message}
import createModule from "./assets/picoruby/picoruby.js";

const TICK = 4;   // ms, MRB_TICK_UNIT of the wasm build (init.iife.js)
let Module = null;
let output = [];
let lastTick = 0;
let request = null;
let answer = null;

globalThis.PicoLab = {
  take() { const text = request; request = null; return text; },
  answer(text) { answer = String(text); }
};

function step() {
  const now = performance.now();
  while (now - lastTick >= TICK) { Module._mrb_tick_wasm(); lastTick += TICK; }
  return Module._mrb_run_step_status ? Module._mrb_run_step_status() : (Module._mrb_run_step() < 0 ? -1 : 1);
}

// one request, answered: no time limit here - the page has one
function ask(text) {
  request = text;
  answer = null;
  while (answer === null) {
    if (step() < 0) throw new Error("PicoRuby's scheduler failed");
  }
  return answer;
}

// "error\tNoMethodError\t3\tundefined method ...\t0": the message is
// everything between the line and the last field
function parse(text) {
  const parts = String(text).split("\t");
  const kind = parts[0];
  if (kind === "syntax") return { status: "syntax", message: parts.slice(1).join("\t") };
  if (kind === "dropped") return { status: "dropped" };
  const irbs = Number(parts.pop()) || 0;
  if (kind === "error") {
    return { status: "error", errorClass: parts[1], line: Number(parts[2]) || null,
             message: parts.slice(3).join("\t"), irbs };
  }
  return { status: "ok", inspect: parts.slice(1).join("\t"), irbs };
}

function run(kind, sid, code) {
  output = [];
  const result = parse(ask(kind === "run" ? `run\t${sid}\t${code}` : `drop\t${sid}`));
  // the mark ended a line a `print` left open (picoruby_lab.rb)
  let text = output.join("").replace(/\u0001\n$/, "");
  output = [];
  // a raised error is also reported by the Task machinery, as its last line
  // with that error - once is enough; a cell's own line that looks the same
  // stays (only the last one goes, and only for the error raised)
  if (result.status === "error") {
    const line = `Exception in task: #<${result.errorClass}: ${result.message}>\n`;
    const at = text.lastIndexOf(line);
    if (at >= 0 && (at === 0 || text[at - 1] === "\n")) text = text.slice(0, at) + text.slice(at + line.length);
  }
  result.output = text;
  return result;
}

const boot = (async () => {
  const code = await (await fetch("picoruby_lab.rb", { cache: "no-cache" })).text();
  Module = await createModule({
    locateFile: name => new URL(`assets/picoruby/${name}`, import.meta.url).href,
    print: line => { output.push(line + "\n"); },
    printErr: line => { output.push(line + "\n"); }
  });
  Module.ccall("picorb_init", "number", [], []);
  Module.ccall("picorb_create_task_with_filename", "number", ["string", "string"], [code, "picoruby_lab.rb"]);
  lastTick = performance.now();
  const probe = run("run", "boot", '"#{RUBY_ENGINE} #{RUBY_ENGINE_VERSION}, PicoRuby #{PICORUBY_VERSION}"');
  if (probe.status !== "ok") throw new Error(`picoruby_lab.rb did not start: ${JSON.stringify(probe)}`);
  run("drop", "boot");
  postMessage({ ready: true, version: probe.inspect.replace(/^"|"$/g, "") });
})().catch(e => {
  postMessage({ failed: String((e && e.message) || e) });
  throw e;
});

onmessage = async event => {
  await boot;
  const { id, kind, sid, code } = event.data;
  let result;
  try {
    result = run(kind, String(sid), String(code || ""));
  } catch (e) {
    result = { status: "error", errorClass: "RuntimeError", line: null,
               message: `PicoRuby: ${(e && e.message) || e}`, output: "", irbs: 0 };
  }
  postMessage(Object.assign({ id }, result));
};
