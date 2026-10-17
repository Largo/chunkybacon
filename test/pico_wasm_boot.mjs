// Boots picoruby_worker_core.js under node for the Pico tests: PicoRuby.wasm
// from html/assets/picoruby, the lab from html/picoruby_lab.rb and a host
// that records what a browser worker would post (docs/HANDOVER.md §6r).
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

export const HTML = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../html");
const { default: createModule } = await import(path.join(HTML, "assets/picoruby/picoruby.js"));
const { bootCore } = await import(path.join(HTML, "picoruby_worker_core.js"));

export function simFilesFromDisk() {
  const names = fs.readFileSync(path.join(HTML, "pico_sim/manifest.txt"), "utf8")
    .split("\n").map(l => l.replace(/#.*/, "").trim()).filter(Boolean);
  return names.map(name => ({ name, code: fs.readFileSync(path.join(HTML, "pico_sim", name), "utf8") }));
}

// canned answers only (no network in tests): assets/data/pico/http/<slug>.json
export function cannedHttp(method, url) {
  const u = new URL(url);
  const slug = `${u.host}__${(u.pathname + u.search).replace(/^\//, "").replace(/[^A-Za-z0-9.]+/g, "_")}`;
  const file = path.join(HTML, "assets/data/pico/http", `${slug}.json`);
  if (!fs.existsSync(file)) return "0\n\n\n";
  const data = JSON.parse(fs.readFileSync(file, "utf8"));
  const headers = Object.assign({}, data.headers || {}, { "x-chunky-canned": "1" });
  return `${data.status || 200}\n${Object.keys(headers).map(k => `${k}: ${headers[k]}`).join("\n")}\n\n${data.body || ""}`;
}

export function cameraHexFromDisk(name) {
  const file = path.join(HTML, "assets/data/pico/camera", `${name}.pgm`);
  return fs.existsSync(file) ? fs.readFileSync(file).toString("hex") : "";
}

export async function bootNode(overrides = {}) {
  const posted = { progress: [], board: [] };
  const host = Object.assign({
    progress(id, text) { posted.progress.push({ id, text, at: performance.now() }); },
    board(id, kind, text) { posted.board.push({ id, kind, text, at: performance.now() }); },
    http: cannedHttp,
    cameraHex: cameraHexFromDisk,
    simFiles: async () => simFilesFromDisk()
  }, overrides);
  const core = await bootCore({
    createModule,
    labCode: fs.readFileSync(path.join(HTML, "picoruby_lab.rb"), "utf8"),
    host,
    moduleArgs: {
      instantiateWasm(imports, done) {
        WebAssembly.instantiate(fs.readFileSync(path.join(HTML, "assets/picoruby/picoruby.wasm")), imports)
          .then(r => done(r.instance));
        return {};
      }
    }
  });
  core.posted = posted;
  return core;
}
