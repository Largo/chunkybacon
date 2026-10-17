// A Web Worker with IronRuby of its own, for the IronRuby lesson ("engine":
// "ironruby", docs/HANDOVER.md §6s): IronRuby 4.0 on .NET 10's runtime for
// the browser, compiled to WebAssembly (assets/ironruby/,
// tools/vendor_ironruby.rb). Started by ironruby_lab.js only when that
// lesson opens - nothing of it loads anywhere else.
//
// A run blocks the thread it runs on, so it runs here: the page stays free
// while a cell computes, and a loop that never ends is stopped by ending
// the worker (ironruby_lab.js).
//
// After the boot it loads QRCoder.dll, writes ironruby_lab.rb as
// lab_display.rb and requires it (show_png, show_svg, show_html). Markdig.dll
// is loaded the first time a cell names Markdig.
//
//   in   {id, kind: "run", code, earlier: [code, ...], probe}  |  {id, kind: "fresh"}
//   out  {id, status: "ok"|"error", output, inspect, errorClass, line, message,
//         earlierFailed: [index into earlier, ...], cellMs (the cell's own run),
//         probe: the inspect of +probe+ run after the cell (the exercise's check), or null}
//        {progress: "download", done, total} while it loads, {progress: "boot"},
//        {ready: true, version, ms} once, or {failed: message}
const t0 = performance.now();
const BASE = new URL("assets/ironruby/", import.meta.url);
const FILE = "chunky.rb";
let ir = null;
let markdig = null;

// how far the download is: the bytes of the runtime's files as they arrive
// (decoded, so the same whether they come gzipped, plain or from the
// cache), against MANIFEST.json's sizes. fetch is wrapped because .NET's
// loader keeps this thread busy while it starts: a PerformanceObserver
// would only hear of the files once it is done.
function watchDownload(manifest) {
  const sizes = manifest.files || {};
  const total = manifest.bytes || 1;
  const got = new Map();
  let last = 0;
  const report = (force) => {
    const now = performance.now();
    if (!force && now - last < 100) return;
    last = now;
    let done = 0;
    for (const size of got.values()) done += size;
    postMessage({ progress: "download", done, total });
  };
  const realFetch = globalThis.fetch;
  globalThis.fetch = async (input, init) => {
    const response = await realFetch(input, init);
    const url = typeof input === "string" ? input : (input && input.url) || String(input);
    const name = decodeURIComponent(new URL(url, BASE).pathname).split("/assets/ironruby/")[1];
    if (!name || !sizes[name] || !response.ok || !response.body) return response;
    let bytes = 0;
    const counter = new TransformStream({
      transform(chunk, controller) {
        bytes += chunk.byteLength;
        got.set(name, bytes);
        report(false);
        controller.enqueue(chunk);
      }
    });
    const counted = new Response(response.body.pipeThrough(counter),
      { status: response.status, statusText: response.statusText, headers: response.headers });
    Object.defineProperty(counted, "url", { value: response.url });
    return counted;
  };
  report(true);
  return () => { globalThis.fetch = realFetch; report(true); };
}

async function text(url) {
  const response = await fetch(url, { cache: "no-cache" });
  if (!response.ok) throw new Error(`${url}: HTTP ${response.status}`);
  return response.text();
}

// the line of the cell in a backtrace ("chunky.rb:3:in ...")
function lineOf(backtrace) {
  for (const entry of backtrace || []) {
    const m = /^chunky\.rb:(\d+)/.exec(String(entry));
    if (m) return Number(m[1]);
  }
  return 0;
}

// IronRuby says "warning: already initialized constant" when a cell that
// sets one runs again - true, but not what the learner asked about
const NOISE = /^.*warning: (already initialized constant|previous definition of) .*\n?/gm;

function answer(r) {
  const output = String(r.stdout || "") + String(r.stderr || "").replace(NOISE, "");
  if (r.ok) {
    if (r.exit !== undefined && r.result === null) return { status: "ok", output, inspect: "nil" };
    return { status: "ok", output, inspect: String(r.result) };
  }
  const e = r.error || {};
  return { status: "error", output, errorClass: String(e.class || "RuntimeError"),
           message: String(e.message || ""), line: lineOf(e.backtrace) };
}

async function needs(code) {
  if (markdig || !/Markdig/.test(code)) return;
  markdig = ir.loadAssemblyFromUrl(new URL("nuget/Markdig.dll", BASE).href);
  await markdig;
}

const boot = (async () => {
  postMessage({ progress: "download", done: 0, total: 1 });
  const manifest = JSON.parse(await text(new URL("MANIFEST.json", BASE).href));
  const stop = watchDownload(manifest);
  const [{ bootIronRuby }, lab] = await Promise.all([
    import(new URL("ironruby.js", BASE).href),
    text(new URL("ironruby_lab.rb", import.meta.url).href)
  ]);
  try {
    ir = await bootIronRuby({ baseUrl: BASE.href });
  } finally {
    stop();
  }
  postMessage({ progress: "boot" });
  await ir.loadAssemblyFromUrl(new URL("nuget/QRCoder.dll", BASE).href);
  ir.writeFile("/ironruby/lib/lab_display.rb", lab);
  const loaded = ir.run('require "lab_display"');
  if (!loaded.ok) throw new Error(`lab_display.rb: ${JSON.stringify(loaded.error)}`);
  ir.reset();
  postMessage({ ready: true, version: ir.bootInfo.version, ms: Math.round(performance.now() - t0) });
})().catch(e => {
  postMessage({ failed: String((e && e.message) || e) });
  throw e;
});

onmessage = async event => {
  try { await boot; } catch (e) { return; }
  const { id, kind, code, earlier, probe } = event.data;
  let result;
  try {
    if (kind === "fresh") {
      ir.reset();
      result = { status: "ok" };
    } else {
      await needs([...(earlier || []), code].join("\n"));
      const failed = [];
      for (let i = 0; i < (earlier || []).length; i++) {
        if (!ir.run(earlier[i], FILE).ok) failed.push(i);
      }
      const own = performance.now();
      result = answer(ir.run(code, FILE));
      result.cellMs = performance.now() - own;
      result.earlierFailed = failed;
      result.probe = null;
      if (probe && result.status === "ok") {
        const checked = ir.run(probe, "check.rb");
        result.probe = checked.ok ? String(checked.result) : null;
      }
    }
  } catch (e) {
    result = { status: "error", errorClass: "RuntimeError", line: 0, output: "",
               message: `IronRuby: ${(e && e.message) || e}` };
  }
  postMessage(Object.assign({ id }, result));
};
