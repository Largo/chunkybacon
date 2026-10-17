// IronRuby's lesson code under Node, without a browser: the vendored bundle
// (html/assets/ironruby/, tools/vendor_ironruby.rb) booted as
// ironruby_worker.js boots it - QRCoder.dll, Markdig.dll, ironruby_lab.rb
// as lab_display - then the runs read from stdin, one JSON answer each.
// test/check_harness.rb runs the IronRuby lesson's cells, starters and
// solutions through this (docs/HANDOVER.md §6s).
//
//   echo '{"runs": [{"code": "1 + 1"}, {"reset": true}, {"code": "x", "probe": "..."}]}' |
//     node test/ironruby_node.mjs
//   -> [{"ok": true, "result": "2", "stdout": "", "stderr": "", "ms": 1}, {"reset": true}, ...]
//   a run's "probe" runs after it, in its binding, when it ran without an error
//
// Exit status 2 when the bundle is not there (the harness skips the lesson).
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const html = path.join(here, "..", "html");
const dist = path.join(html, "assets", "ironruby");
if (!fs.existsSync(path.join(dist, "_framework", "dotnet.js"))) {
  console.error(`no IronRuby bundle in ${dist} - run ruby tools/vendor_ironruby.rb`);
  process.exit(2);
}
const input = JSON.parse(fs.readFileSync(0, "utf8"));
const { dotnet } = await import(path.join(dist, "_framework", "dotnet.js"));
const runtime = await dotnet.create();
const I = (await runtime.getAssemblyExports(runtime.getConfig().mainAssemblyName)).IronRuby.Wasm.Interop;
const boot = JSON.parse(I.Boot(new Uint8Array(fs.readFileSync(path.join(dist, "stdlib.zip"))), JSON.stringify({})));
if (!boot.ok) {
  console.error("IronRuby boot failed:", boot.error);
  process.exit(1);
}
for (const dll of ["QRCoder.dll", "Markdig.dll"]) {
  const res = JSON.parse(I.LoadAssembly(new Uint8Array(fs.readFileSync(path.join(dist, "nuget", dll))), dll));
  if (!res.ok) { console.error(dll, res.error); process.exit(1); }
}
I.WriteFile("/ironruby/lib/lab_display.rb", new Uint8Array(fs.readFileSync(path.join(html, "ironruby_lab.rb"))));
const lab = JSON.parse(I.Run('require "lab_display"', ""));
if (!lab.ok) { console.error("lab_display:", JSON.stringify(lab.error)); process.exit(1); }
I.Reset();

const answers = [];
for (const run of input.runs || []) {
  if (run.reset) {
    I.Reset();
    answers.push({ reset: true });
    continue;
  }
  const r = JSON.parse(I.Run(String(run.code), run.file || "chunky.rb"));
  if (run.probe && r.ok) {
    const p = JSON.parse(I.Run(String(run.probe), "check.rb"));
    r.probe = p.ok ? p.result : null;
    if (!p.ok) r.probeError = p.error;
  }
  answers.push(r);
}
// (exit only once a pipe has taken all of it: the runtime keeps Node alive)
process.stdout.write(JSON.stringify(answers), () => process.exit(0));
