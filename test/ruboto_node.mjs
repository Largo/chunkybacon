// The Ruboto lesson's code under Node, without a browser (docs/HANDOVER.md
// §6u): the JRuby the page loads (html/assets/jruby/, tools/vendor_jruby.rb)
// booted as jruby_worker.js boots it, jruby_lab.rb and the simulated phone
// (html/ruboto_sim/, from its manifest) loaded as the worker loads them -
// then the runs read from stdin, one JSON answer each, through
// ChunkyLab.run_android, as the page's runs go. test/check_harness.rb runs
// the lesson's cells, starters and solutions through this.
//
//   echo '{"runs": [{"code": "1 + 1"}, {"reset": true}, {"code": "...", "probe": "..."},
//                   {"phone": {"action": "rotate"}}]}' | node test/ruboto_node.mjs
//   -> [{"ok": true, "result": "2", "stdout": "", "ms": 1}, {"reset": true},
//       {"ok": false, "error": {"class": ..., "message": ..., "line": 3}, "phone": "{...}", "probe": ...},
//       {"phone": "{...}"}]
//   a run's "phone" is the screen when the cell started an app; "probe" runs
//   after the cell, when it ran without an error; "delay" (ms) waits first
//
// Exit status 2 when JRuby is not there (the harness skips the lesson).
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const html = path.join(here, "..", "html");
const dist = path.join(html, "assets", "jruby");
if (!fs.existsSync(path.join(dist, "jruby.js"))) {
  console.error(`no JRuby in ${dist} - run ruby tools/vendor_jruby.rb`);
  process.exit(2);
}
const input = JSON.parse(fs.readFileSync(0, "utf8"));
// TeaVM's System.out is console.log: what the code printed comes back in the answers
console.log = () => {};
const jr = await import(path.join(dist, "jruby.js"));
const evalAsync = code => new Promise(resolve => jr.rubyEvalAsync(code, json => resolve(JSON.parse(json))));
const literal = text => JSON.stringify(String(text)).replace(/#/g, "\\#");
const MARK = "\u0001";

jr.main([]);
jr.mountZip(new Int8Array(fs.readFileSync(path.join(dist, "stdlib.zip"))), "/jruby");
await new Promise(resolve => jr.bootAsync(json => resolve(JSON.parse(json))));
const lab = await evalAsync(fs.readFileSync(path.join(html, "jruby_lab.rb"), "utf8"));
if (lab.error) { console.error("jruby_lab.rb:", lab.error); process.exit(1); }
const sim = path.join(html, "ruboto_sim");
const names = fs.readFileSync(path.join(sim, "manifest.txt"), "utf8").split("\n").map(l => l.trim()).filter(l => l && !l.startsWith("#"));
let setup = 'require "fileutils"\n';
for (const name of names) {
  setup += `FileUtils.mkdir_p(File.dirname("/ruboto/${name}")); File.write("/ruboto/${name}", ${literal(fs.readFileSync(path.join(sim, name), "utf8"))})\n`;
}
setup += '$LOAD_PATH.unshift("/ruboto", "/ruboto/vendor")\nrequire "ruboto_sim"\nRubotoSim.boot\nChunkyLab.fresh\nnil';
const loaded = await evalAsync(setup);
if (loaded.error) { console.error("ruboto_sim.rb:", loaded.error); process.exit(1); }

function split(out) {
  const text = String(out || "");
  const at = text.lastIndexOf(MARK);
  if (at < 0) return [text, null];
  try { return [text.slice(0, at), JSON.parse(text.slice(at + 1))]; } catch (e) { return [text, null]; }
}

const answers = [];
for (const run of input.runs || []) {
  // an idle gap, as between a learner's runs: the JS garbage collector runs
  // then, and finds what JRuby's weak references hold (the TeaVM reference
  // queue bug of 2026-10 showed only so)
  if (run.delay) await new Promise(resolve => setTimeout(resolve, run.delay));
  if (run.reset) {
    await evalAsync("ChunkyLab.fresh");
    answers.push({ reset: true });
    continue;
  }
  if (run.phone) {
    const raw = await evalAsync(`$stdout.print("${MARK}" + RubotoSim.input(${literal(JSON.stringify(run.phone))}))`);
    const text = String(raw.out || "");
    answers.push({ phone: text.slice(text.lastIndexOf(MARK) + 1), error: raw.error || null });
    continue;
  }
  const started = Date.now();
  const raw = await evalAsync(`ChunkyLab.run_android(${literal(run.code)}, false, ${run.probe ? literal(run.probe) : "nil"})`);
  const [stdout, answer] = split(raw.out);
  const ms = Date.now() - started;
  if (!answer) {
    answers.push({ ok: false, stdout, ms, error: { class: "RuntimeError", message: String(raw.error || "no answer"), line: 0 } });
    continue;
  }
  const r = { ok: answer.status === "ok", stdout, ms };
  if (r.ok) r.result = answer.inspect;
  else r.error = { class: answer.errorClass, message: answer.message, line: answer.line };
  if (answer.probe !== undefined) r.probe = answer.probe;
  if (answer.phone) r.phone = answer.phone;
  answers.push(r);
}
process.stdout.write(JSON.stringify(answers), () => process.exit(0));
