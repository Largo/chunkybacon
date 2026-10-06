// The Spinel lesson's compiler, in a worker of its own (spinel.js starts it):
// spinel.wasm and clang (html/assets/spinel/, ~27 MB gzipped) are fetched and
// compiled once, then every build is Ruby -> C -> a WebAssembly module here,
// off the page's thread. Builds run one after the other.
//
//   -> { type: "load" }                      <- progress {part, done, total}, ready {version} | failed {error}
//   -> { type: "build", id, source }         <- built {id, ok, stage, c, wasm, messages, ms}
import { SpinelToolchain } from './spinel-build.js';

let toolchain = null;
let loading = null;
let queue = Promise.resolve();

const load = () => {
  loading ??= new SpinelToolchain(new URL('assets/spinel/', self.location.href))
    .load((progress) => self.postMessage({ type: 'progress', ...progress }))
    .then((loaded) => {
      toolchain = loaded;
      self.postMessage({ type: 'ready', version: loaded.version });
    })
    .catch((error) => {
      loading = null;
      self.postMessage({ type: 'failed', error: String((error && error.message) || error) });
      throw error;
    });
  return loading;
};

self.onmessage = ({ data }) => {
  if (data.type === 'load') { load().catch(() => {}); return; }
  if (data.type !== 'build') return;
  queue = queue.then(async () => {
    try {
      await load();
      const built = await toolchain.build(data.source);
      const wasm = built.wasm ? built.wasm.slice().buffer : null;
      self.postMessage({ type: 'built', id: data.id, ...built, wasm }, wasm ? [wasm] : []);
    } catch (error) {
      self.postMessage({ type: 'built', id: data.id, ok: false, stage: 'load', messages: String((error && error.message) || error) });
    }
  });
};
