// Spinel in the browser: Ruby -> C -> WebAssembly, the steps `spinel app.rb`
// takes on a computer, each one WebAssembly here (html/assets/spinel/, built
// by tools/build_spinel.mjs on deploy):
//
//   1. spinel.wasm, the compiler, reads /work/main.rb and writes /work/main.c
//      (-c --print-build: the C, and the ingredients cc would get)
//   2. clang (@yowasp/clang) compiles and links that C with Spinel's runtime
//      archive into a module for wasm32-wasi
//   3. the module runs (spinel-run-worker.js: a worker of its own, so an
//      endless loop can be stopped)
//
// SpinelIrb is IRB on top of it. A compiled program has no eval: every line
// is compiled together with the lines before it into a program of its own and
// run from the start, and only what the new line printed is shown - the
// output of the earlier lines comes again, deterministically, before a marker.
//
// An ES module, imported by spinel-worker.js and test/spinel_test.mjs.
import { MemFS, runWasi } from './spinel-wasi.js';

export const SPINEL_ARGV0 = '/spinel/bin/spinel';

// a path with its "dir/.." pairs taken out (YoWASP's filesystem has no "..")
const normalize = (path) => {
  let next = path;
  do { path = next; next = path.replace(/\/[^/]+\/\.\.(\/|$)/, '/'); } while (next !== path);
  return path;
};

// what --print-build said, one "kind value" a line
export function parseBuild(text) {
  const build = { cflag: [], include: [], define: [], lib: [], link: [], source: null, runtime: null };
  for (const line of text.split('\n')) {
    const at = line.indexOf(' ');
    if (at < 0) continue;
    const kind = line.slice(0, at), value = normalize(line.slice(at + 1));
    if (kind === 'source' || kind === 'runtime') build[kind] = value;
    else if (build[kind]) build[kind].push(value);
  }
  return build;
}

// the clang command line for it: Spinel's own flags (src/main.c), the page's
// header (lib/wasi/sp_page.h) first, warnings off - they are about generated C
export function clangArgs(build, output) {
  return ['clang', '--target=wasm32-wasip1', '-O2', '-w', '-include', '/spinel/lib/wasi/sp_page.h',
          ...build.cflag, ...build.include.map((dir) => `-I${dir}`), ...build.define,
          build.source, ...build.link, build.runtime, ...build.lib, '-Wl,--fatal-warnings', '-o', output];
}

const toTree = (node) => (node.entries
  ? Object.fromEntries([...node.entries].map(([name, child]) => [name, toTree(child)]))
  : node.data.subarray(0, node.size));

// "spinel: /work/main.rb:3: ..." -> "main.rb:3: ..." (the learner's names)
export const tidy = (text) => text.replace(/\/work\//g, '').replace(/^spinel: /gm, '').trim();

export class SpinelToolchain {
  // base: where html/assets/spinel/ is (a URL); fetchFn as fetch
  constructor(base, fetchFn = (url, init) => fetch(url, init)) {   // a bare fetch, called as a method, throws "Illegal invocation"
    this.base = base;
    this.fetch = fetchFn;
  }

  // everything fetched and compiled once; progress({ part, done, total })
  async load(progress = () => {}) {
    const get = async (path) => {
      const response = await this.fetch(new URL(path, this.base));
      if (!response.ok) throw new Error(`${path}: HTTP ${response.status}`);
      return response;
    };
    // the current build is the folder manifest.json names (tools/build_spinel.mjs)
    const manifest = await (await get('manifest.json')).json();
    this.manifest = manifest;
    const root = this.base;
    this.base = new URL(`${manifest.dir}/`, root);
    const [compiler, files, clang] = await Promise.all([
      get('spinel.wasm').then((r) => r.arrayBuffer()).then((bytes) => { progress({ part: 'spinel' }); return WebAssembly.compile(bytes); }),
      get('spinel-files.tar').then((r) => r.arrayBuffer()),
      import(new URL('clang/bundle.js', this.base).href).then(async (module) => {
        // fetches and compiles clang (75 MB) with its sysroot
        await module.runLLVM(null, {}, { fetchProgress: ({ totalLength, doneLength }) => progress({ part: 'clang', done: doneLength, total: totalLength }) });
        return module;
      }),
    ]);
    this.compiler = compiler;
    this.files = new MemFS();
    this.files.addTar(files, '/spinel/');
    this.files.writeFile(`${SPINEL_ARGV0}`, '');   // resolve_lib_dir looks beside argv[0]
    this.clang = clang;
    return this;
  }

  get version() { return this.manifest ? `${this.manifest.spinel.date} (${this.manifest.spinel.commit.slice(0, 7)})` : null; }

  // 1. Ruby -> C. { ok, c, build, messages, ms }
  compile(source, extra = []) {
    const fs = this.files.clone();
    fs.writeFile('/work/main.rb', source);
    const started = performance.now();
    const result = runWasi(this.compiler, {
      fs, args: [SPINEL_ARGV0, '--target=wasm32-wasi', '--cc=clang', ...extra, '-c', '--print-build', '/work/main.rb', '-o', '/work/main.c'],
    });
    const ms = performance.now() - started;
    const messages = tidy(result.stderr.replace(/^Wrote \/work\/main\.c\n?/m, ''));
    if (result.code !== 0) return { ok: false, messages, ms };
    const c = new TextDecoder().decode(fs.readFile('/work/main.c'));
    return { ok: true, c, build: parseBuild(result.stdout), messages, ms, fs };
  }

  // 2. C -> a WebAssembly module (the bytes). { ok, wasm, messages, ms }
  async link(compiled) {
    const started = performance.now();
    const chunks = [];
    const capture = (bytes) => { if (bytes) chunks.push(new TextDecoder().decode(bytes)); };
    try {
      const tree = await this.clang.runClang(clangArgs(compiled.build, '/work/main.wasm'),
        { spinel: toTree(compiled.fs.lookup('/spinel')), work: toTree(compiled.fs.lookup('/work')) },
        { stdout: capture, stderr: capture });
      return { ok: true, wasm: tree.work['main.wasm'], messages: tidy(chunks.join('')), ms: performance.now() - started };
    } catch (error) {
      return { ok: false, messages: tidy(chunks.join('') || error.message), ms: performance.now() - started };
    }
  }

  // both: { ok, stage: 'spinel' | 'clang', c, wasm, messages, ms: { spinel, clang } }
  async build(source) {
    const compiled = this.compile(source);
    if (!compiled.ok) return { ok: false, stage: 'spinel', messages: compiled.messages, ms: { spinel: compiled.ms } };
    const linked = await this.link(compiled);
    const ms = { spinel: compiled.ms, clang: linked.ms };
    if (!linked.ok) return { ok: false, stage: 'clang', c: compiled.c, messages: linked.messages, ms };
    return { ok: true, c: compiled.c, wasm: linked.wasm, messages: compiled.messages, ms };
  }
}

// 3. runs a built module: { code, stdout, stderr, ms } (synchronous: in a worker)
export function runProgram(wasm, { stdin = new Uint8Array(0), stdout, stderr } = {}) {
  const module = wasm instanceof WebAssembly.Module ? wasm : new WebAssembly.Module(wasm);
  const started = performance.now();
  const result = runWasi(module, { args: ['main'], stdin, stdout, stderr });
  return { ...result, stderr: tidy(result.stderr), ms: performance.now() - started };
}

// ------------------------------------------------------------------ IRB

const MARK = '\u0001';        // what follows was printed by the new line
const VALUE = '\u0002';       // what follows is the new line's value, inspected

// A definition gives IRB's answer without being run for a value: a method
// says its name, a class or module nil. The other lines are wrapped in
// parentheses (no new scope: a local they assign is the program's).
const DEF = /^\s*def\s+(?:self\.)?([A-Za-z_][A-Za-z0-9_]*[?!=]?|[+\-*\/%<>=!~^&|\[\]]+)/;
const CLASS = /^\s*(class|module)\s/;

export class SpinelIrb {
  constructor(toolchain) {
    this.toolchain = toolchain;
    this.lines = [];   // the inputs that compiled and ran
  }

  // the program for a new input: the lines so far, the marker, the input;
  // first: the line of main.rb the input starts on
  program(input) {
    const head = this.lines.map((line) => line + '\n').join('') + `print ${JSON.stringify(MARK)}\n`;
    const first = head.split('\n').length;
    const value = `print ${JSON.stringify(VALUE)}\n`;
    const def = input.match(DEF);
    if (def) return { source: `${head}${input}\n${value}p :${def[1]}\n`, first };
    if (CLASS.test(input)) return { source: `${head}${input}\n${value}p nil\n`, first };
    return { source: `${head}__irb_value = (\n${input}\n)\n${value}p __irb_value\n`, first: first + 1 };
  }

  // compiles and runs; { ok, output, value, messages, stage, ms }, and the
  // input joins the session when it ran. run(wasm) is how the module runs
  // (a worker of its own in the page, runProgram in a test).
  async submit(input, run) {
    const { source, first } = this.program(input);
    const built = await this.toolchain.build(source);
    // a message about a line of the new input names it as IRB does
    const renumber = (text) => text.replace(/main\.rb:(\d+)/g, (m, n) => `(irb):${Math.max(1, Number(n) - first + 1)}`);
    if (!built.ok) return { ok: false, stage: built.stage, messages: renumber(built.messages), ms: built.ms };
    const ran = await run(built.wasm);
    const stdout = ran.stdout;
    const mark = stdout.indexOf(MARK), value = stdout.indexOf(VALUE, mark + 1);
    const ms = { ...built.ms, run: ran.ms };
    if (ran.code !== 0 || value < 0) {
      return { ok: false, stage: 'run', output: mark >= 0 ? stdout.slice(mark + 1, value < 0 ? undefined : value) : '',
               messages: renumber(ran.stderr || `exit ${ran.code}`), ms };
    }
    this.lines.push(input);
    return { ok: true, output: stdout.slice(mark + 1, value), value: stdout.slice(value + 1).replace(/\n$/, ''), ms };
  }
}
