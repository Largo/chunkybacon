// Boots PicoRuby.wasm in a worker and runs the Spinel lesson's Ruby there:
// new Worker("spinel/boot.js?role=compiler" | "?role=run", {type: "module"})
// from the page (shell/spinel.rb). The files for each role are listed in
// spinel/manifest.txt and joined into ONE task, as shell/loader.js does for
// the page; the scheduler below is init.iife.js's, without the document.
//
// It adds the one thing Ruby cannot do there: import() an ES module
// (clang's bundle.js, html/assets/spinel/) - self.importModule(url) answers
// the promise, which Ruby awaits in a Task.
const role = new URL(self.location.href).searchParams.get('role');

const get = async (path) => {
  // no-cache: revalidate, so a deploy is seen on the next load
  const response = await fetch(new URL(path, self.location.href), { cache: 'no-cache' });
  if (!response.ok) throw new Error(`${path}: HTTP ${response.status}`);
  return response.text();
};

try {
  self.importModule = (url) => import(url);
  const manifest = await get('manifest.txt');
  const line = manifest.split('\n').map((l) => l.trim()).find((l) => l.startsWith(`${role}:`));
  if (!line) throw new Error(`spinel/manifest.txt has no worker "${role}"`);
  const files = line.slice(role.length + 1).trim().split(/\s+/);
  const [{ default: createModule }, ...sources] = await Promise.all([
    import('../assets/picoruby/picoruby.js'), ...files.map(get),
  ]);
  const Module = await createModule();
  Module.ccall('picorb_init', 'number', [], []);
  const code = sources.map((source, i) => `# ---- spinel/${files[i]}\n${source}`).join('\n');
  Module.ccall('picorb_create_task_with_filename', 'number', ['string', 'string'], [code, `spinel-${role}.rb`]);

  const TICK = 4;            // MRB_TICK_UNIT of PicoRuby's build
  const SLICE = 16;
  let lastTick = performance.now();
  const step = Module._mrb_run_step_status || (() => (Module._mrb_run_step() < 0 ? -1 : 1));
  (function run() {
    const now = performance.now();
    for (let n = 0; now - lastTick >= TICK && n < 10; n++) { Module._mrb_tick_wasm(); lastTick += TICK; }
    if (now - lastTick >= TICK) lastTick = now;
    const start = performance.now();
    let progressed = false;
    while (performance.now() - start < SLICE) {
      const status = step();
      if (status <= 0) break;
      progressed = true;
    }
    setTimeout(run, progressed ? 0 : TICK);
  })();
} catch (error) {
  self.postMessage({ type: 'failed', error: String((error && error.message) || error) });
}
