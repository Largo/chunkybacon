// A Web Worker with JRuby of its own, for the JRuby lesson ("engine":
// "jruby", docs/HANDOVER.md §6t): JRuby 10.1 compiled to JavaScript by TeaVM
// (assets/jruby/, tools/vendor_jruby.rb). Started by jruby_lab.js only when
// that lesson opens - nothing of it loads anywhere else.
//
// JRuby runs its requests on one long-lived TeaVM green thread, Ruby's
// Thread.main, so Thread, Queue, Mutex and sleep block as they should; the
// worker keeps the page's thread free while a cell computes, and a loop
// that never ends is stopped by ending the worker (jruby_lab.js).
//
// After the boot it evaluates jruby_lab.rb (ChunkyLab: one binding for the
// lesson's cells, the answer as a line behind \u0001) and mounts the
// earthquake data at /data (data/quakes.zip).
//
// The Ruboto lesson ("android": true, docs/HANDOVER.md §6u) adds a simulated
// phone: its runs carry android: true, and the first of them loads
// ruboto_sim/ (Ruboto's own Ruby and the activity manager, ruboto_sim.rb) into
// JRuby's file system; the Android classes are in jruby.js itself.
//
//   in   {id, kind: "run", code, earlier: [code, ...], android, probe}  |  {id, kind: "fresh"}
//        {id, kind: "android"} (load the phone now)  |  {id, kind: "phone", event} (a tap ...)
//   out  {id, status: "ok"|"error", output, inspect, errorClass, line, message,
//         earlierFailed: [index into earlier, ...], ms (all of it), cellMs (the cell's own run),
//         probe (its inspect), phone (the screen, JSON)}  |  {id, phone} for "phone"
//        {progress: text} while it loads, {ready: true, version, ms} once,
//        or {failed: message}
const t0 = performance.now();
let jr = null;

const evalAsync = code => new Promise(resolve => jr.rubyEvalAsync(code, json => resolve(JSON.parse(json))));
// a JavaScript string as a Ruby string literal: JSON's escapes are Ruby's,
// and # must not start an interpolation
const literal = text => JSON.stringify(String(text)).replace(/#/g, "\\#");

async function bytes(url) {
  const response = await fetch(new URL(url, import.meta.url).href);
  if (!response.ok) throw new Error(`${url}: HTTP ${response.status}`);
  return new Int8Array(await response.arrayBuffer());
}

// what a ChunkyLab.run printed, and its answer behind the mark
function split(out) {
  const text = String(out || "");
  const at = text.lastIndexOf("\u0001");
  if (at < 0) return { output: text, answer: null };
  let answer = null;
  try { answer = JSON.parse(text.slice(at + 1)); } catch (e) { answer = null; }
  return { output: text.slice(0, at), answer };
}

async function run(code, quiet, android, probe) {
  const call = android
    ? `ChunkyLab.run_android(${literal(code)}, ${quiet ? "true" : "false"}, ${probe ? literal(probe) : "nil"})`
    : `ChunkyLab.run(${literal(code)}, ${quiet ? "true" : "false"})`;
  const raw = await evalAsync(call);
  const { output, answer } = split(raw.out);
  if (answer) return Object.assign({ output }, answer);
  // ChunkyLab itself failed (a Java error past Ruby's rescue)
  return { status: "error", errorClass: "RuntimeError", line: 0, output,
           message: String(raw.error || "JRuby gave no answer") };
}

const boot = (async () => {
  postMessage({ progress: "download" });
  const [module, stdlib, data, lab] = await Promise.all([
    import("./assets/jruby/jruby.js"),
    bytes("assets/jruby/stdlib.zip"),
    bytes("assets/jruby/data/quakes.zip"),
    fetch(new URL("jruby_lab.rb", import.meta.url).href, { cache: "no-cache" }).then(r => r.text())
  ]);
  jr = module;
  postMessage({ progress: "boot" });
  jr.main([]);
  jr.mountZip(stdlib, "/jruby");
  jr.mountZip(data, "/data");
  const booted = await new Promise(resolve => jr.bootAsync(json => resolve(JSON.parse(json))));
  const loaded = await evalAsync(lab);
  if (loaded.error) throw new Error(`jruby_lab.rb: ${loaded.error}`);
  const probe = await run('"#{RUBY_ENGINE} #{JRUBY_VERSION} (Ruby #{RUBY_VERSION})"', false);
  if (probe.status !== "ok") throw new Error(`jruby_lab.rb did not start: ${JSON.stringify(probe)}`);
  await evalAsync("ChunkyLab.fresh");
  postMessage({ ready: true, version: probe.inspect.replace(/^"|"$/g, ""),
                description: String(booted.description || ""), ms: Math.round(performance.now() - t0) });
})().catch(e => {
  postMessage({ failed: String((e && e.message) || e) });
  throw e;
});

// the simulated phone: its files written into JRuby's file system once
let phoneLoaded = null;
function loadPhone() {
  if (phoneLoaded) return phoneLoaded;
  phoneLoaded = (async () => {
    const base = new URL("ruboto_sim/", import.meta.url);
    const text = url => fetch(new URL(url, base).href, { cache: "no-cache" }).then(r => {
      if (!r.ok) throw new Error(`ruboto_sim/${url}: HTTP ${r.status}`);
      return r.text();
    });
    const names = (await text("manifest.txt")).split("\n").map(l => l.trim()).filter(l => l && !l.startsWith("#"));
    const files = await Promise.all(names.map(text));
    let setup = 'require "fileutils"\n';
    names.forEach((name, i) => {
      setup += `FileUtils.mkdir_p(File.dirname("/ruboto/${name}")); File.write("/ruboto/${name}", ${literal(files[i])})\n`;
    });
    setup += '$LOAD_PATH.unshift("/ruboto", "/ruboto/vendor")\nrequire "ruboto_sim"\nRubotoSim.boot\nnil';
    const loaded = await evalAsync(setup);
    if (loaded.error) throw new Error(`ruboto_sim.rb: ${loaded.error}`);
  })();
  phoneLoaded.catch(() => { phoneLoaded = null; });
  return phoneLoaded;
}

async function phoneInput(json) {
  const raw = await evalAsync(`$stdout.print("\u0001" + RubotoSim.input(${literal(json)}))`);
  const text = String(raw.out || "");
  const at = text.lastIndexOf("\u0001");
  if (at < 0) throw new Error(String(raw.error || "the phone gave no answer"));
  return text.slice(at + 1);
}

onmessage = async event => {
  await boot;
  const { id, kind, code, earlier, android, probe } = event.data;
  const started = performance.now();
  let result;
  try {
    if (kind === "fresh") {
      await evalAsync("ChunkyLab.fresh");
      result = { status: "ok" };
    } else if (kind === "android") {
      await loadPhone();
      result = { status: "ok" };
    } else if (kind === "phone") {
      await loadPhone();
      result = { status: "ok", phone: await phoneInput(JSON.stringify(event.data.event)) };
    } else {
      if (android) await loadPhone();
      const failed = [];
      for (let i = 0; i < (earlier || []).length; i++) {
        const quiet = await run(earlier[i], true, android, null);
        if (quiet.status !== "ok") failed.push(i);
      }
      const own = performance.now();
      result = await run(code, false, android, probe);
      result.cellMs = performance.now() - own;
      result.earlierFailed = failed;
    }
  } catch (e) {
    result = { status: "error", errorClass: "RuntimeError", line: 0, output: "",
               message: `JRuby: ${(e && e.message) || e}` };
  }
  result.ms = performance.now() - started;
  postMessage(Object.assign({ id }, result));
};
