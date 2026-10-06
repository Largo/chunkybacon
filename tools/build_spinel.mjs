// Builds Spinel (Matz's Ruby AOT compiler, github.com/matz/spinel) for the
// browser into html/assets/spinel/ - not committed: the deploy runs this, and
// it does nothing when the build there is the one tools/spinel.json pins.
//
//   node tools/build_spinel.mjs            # build if the pins or this tool changed
//   node tools/build_spinel.mjs --check    # exit 1 if html/assets/spinel/ is not current
//   node tools/build_spinel.mjs --force    # build even if it is current
//   node tools/build_spinel.mjs --update   # pin matz/spinel's newest commit, then build
//   node tools/build_spinel.mjs --jobs 4   # compiler processes (default: cores - 1, at most 8)
//
// What the lesson runs (html/spinel.js), all WebAssembly in the learner's tab:
//
//   Ruby --spinel.wasm--> C --clang (@yowasp/clang)--> app.wasm --> run
//
// spinel.wasm is Spinel's own C (src/, libprism, its regexp engine) compiled
// for wasm32-wasi; spinel-files.tar is what it reads beside itself (builtins/,
// packages/, lib/ with the runtime's headers) plus the runtime archive
// lib/wasm32-wasi/libspinel_rt.a and the bundled packages' *_wasi.o, which
// `make wasm-rt` builds in Spinel's tree. clang/ is YoWASP's Clang/LLD for
// WebAssembly, itself WebAssembly; its sysroot tar is cut down to what a C
// program for wasm32-wasip1 needs.
//
// Everything is fetched by version and checked: the Spinel commit as a
// GitHub tarball, the prism gem from rubygems.org (Spinel's `make deps`
// takes the same), the npm tarballs against the registry's sha512. Nothing
// needs a C compiler on the host - the compiler is clang.wasm under Node.
// Downloads and objects are kept in .cache/spinel/ (gitignored) for the next run.
import { createHash } from 'node:crypto';
import { cpus } from 'node:os';
import { gunzipSync, gzipSync, constants as zlibConstants } from 'node:zlib';
import { readFileSync, writeFileSync, existsSync, mkdirSync, rmSync, renameSync, readdirSync, statSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { Worker, isMainThread, parentPort, workerData } from 'node:worker_threads';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const PINS_FILE = join(ROOT, 'tools', 'spinel.json');
const CACHE = join(ROOT, '.cache', 'spinel');
const TARGET = join(ROOT, 'html', 'assets', 'spinel');
const SELF = fileURLToPath(import.meta.url);

// ---------------------------------------------------------------- tar files

// The entries of a tar archive (ustar, with GNU long names and pax paths, as
// GitHub's and npm's tarballs have them): [path, Buffer] for each file.
function untar(buffer) {
  const files = [];
  let offset = 0, longName = null, paxPath = null;
  const text = (start, length) => {
    const end = buffer.indexOf(0, start);
    return buffer.toString('utf8', start, end === -1 || end > start + length ? start + length : end);
  };
  while (offset + 512 <= buffer.length) {
    if (buffer[offset] === 0) break;
    const size = parseInt(text(offset + 124, 12).trim() || '0', 8);
    const type = String.fromCharCode(buffer[offset + 156] || 48);
    const prefix = text(offset + 345, 155);
    let name = text(offset, 100);
    if (prefix) name = `${prefix}/${name}`;
    const body = buffer.subarray(offset + 512, offset + 512 + size);
    offset += 512 + Math.ceil(size / 512) * 512;
    if (type === 'L') { longName = body.toString('utf8').replace(/\0+$/, ''); continue; }
    if (type === 'x') {
      const match = body.toString('utf8').match(/^\d+ path=(.*)$/m);
      paxPath = match ? match[1] : null;
      continue;
    }
    if (type === 'g') continue;
    name = paxPath ?? longName ?? name;
    longName = paxPath = null;
    if (type === '0' || type === '\0' || type === '7') files.push([name, Buffer.from(body)]);
  }
  return files;
}

// A tar archive of [path, Buffer] pairs (ustar; paths up to 255 bytes), each
// directory as an entry of its own before its files: YoWASP's unpacker
// (clang's llvm-resources.tar) needs them.
function tar(files) {
  const blocks = [];
  const entries = [], dirs = new Set();
  for (const [path, data] of files) {
    const parts = path.split('/');
    for (let i = 1; i < parts.length; i++) {
      const dir = parts.slice(0, i).join('/');
      if (!dirs.has(dir)) { dirs.add(dir); entries.push([dir, null]); }
    }
    entries.push([path, data]);
  }
  for (const [path, body] of entries) {
    const data = body ?? Buffer.alloc(0);
    const header = Buffer.alloc(512);
    let name = path, prefix = '';
    if (Buffer.byteLength(name) > 100) {
      const cut = path.lastIndexOf('/', 155);
      prefix = path.slice(0, cut);
      name = path.slice(cut + 1);
      if (cut < 0 || Buffer.byteLength(name) > 100) throw new Error(`tar: path too long: ${path}`);
    }
    header.write(name, 0, 100);
    header.write('0000644\0', 100);
    header.write('0000000\0', 108);
    header.write('0000000\0', 116);
    header.write(data.length.toString(8).padStart(11, '0') + '\0', 124);
    header.write('00000000000\0', 136);
    header.write('        ', 148);
    header.write(body ? '0' : '5', 156);
    header.write('ustar\0' + '00', 257);
    header.write(prefix, 345, 155);
    let sum = 0;
    for (const byte of header) sum += byte;
    header.write(sum.toString(8).padStart(6, '0') + '\0 ', 148);
    blocks.push(header, data, Buffer.alloc((512 - (data.length % 512)) % 512));
  }
  blocks.push(Buffer.alloc(1024));
  return Buffer.concat(blocks);
}

// ------------------------------------------------------------- downloading

async function get(url) {
  const response = await fetch(url, { headers: { 'User-Agent': 'chunkybacon-build-spinel' } });
  if (!response.ok) throw new Error(`${url}: ${response.status}`);
  return Buffer.from(await response.arrayBuffer());
}

// a download, kept in .cache/spinel/ under its name
async function cached(name, url, verify = () => {}) {
  const path = join(CACHE, 'downloads', name);
  if (existsSync(path)) return readFileSync(path);
  console.log(`fetching ${url}`);
  const data = await get(url);
  verify(data);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(`${path}.tmp`, data);
  renameSync(`${path}.tmp`, path);
  return data;
}

async function npmPackage({ package: name, version, integrity }) {
  const base = name.split('/').pop();
  const data = await cached(`${base}-${version}.tgz`, `https://registry.npmjs.org/${name}/-/${base}-${version}.tgz`, (tgz) => {
    const [algorithm, digest] = integrity.split('-', 2);
    if (createHash(algorithm).update(tgz).digest('base64') !== digest) throw new Error(`${name}@${version}: checksum mismatch`);
  });
  return new Map(untar(gunzipSync(data)).map(([path, body]) => [path.replace(/^package\//, ''), body]));
}

// Spinel's tree at the pinned commit, without its first path segment
async function spinelSource({ repo, commit }) {
  const data = await cached(`spinel-${commit}.tar.gz`, `https://codeload.github.com/${repo}/tar.gz/${commit}`);
  return new Map(untar(gunzipSync(data)).map(([path, body]) => [path.replace(/^[^/]+\//, ''), body]));
}

// the prism gem's C sources (src/, include/: the generated headers included)
async function prismSource(version) {
  const gem = await cached(`prism-${version}.gem`, `https://rubygems.org/gems/prism-${version}.gem`);
  const data = untar(gem).find(([path]) => path === 'data.tar.gz');
  if (!data) throw new Error(`prism-${version}.gem has no data.tar.gz`);
  return new Map(untar(gunzipSync(data[1])).filter(([path]) => /^(src|include)\//.test(path)));
}

// -------------------------------------------------------------- the stamp

function stamp(pins) {
  return createHash('sha256').update(JSON.stringify(pins)).update(readFileSync(SELF)).digest('hex').slice(0, 16);
}

function currentStamp() {
  try { return JSON.parse(readFileSync(join(TARGET, 'manifest.json'), 'utf8')).stamp; } catch { return null; }
}

// --------------------------------------------------------- a clang worker

// A worker keeps one copy of the source trees and runs one clang (or llvm
// tool) command per job on them: { args, outputs } -> { outputs: {path: bytes} }.
async function workerMain() {
  const { runClang, runLLVM } = await import(pathToFileURL(workerData.bundle).href);
  const tree = workerData.tree;
  await runLLVM(null, {}, { fetchProgress: () => {} });   // fetch the resources once
  parentPort.on('message', async ({ id, tool, args, extra, outputs }) => {
    const chunks = [];
    const stderr = (bytes) => { if (bytes) chunks.push(Buffer.from(bytes)); };
    try {
      const files = { ...tree, ...(extra ? treeOf(new Map(Object.entries(extra))) : {}) };
      const result = await (tool === 'clang' ? runClang(args, files, { stdout: stderr, stderr })
                                             : runLLVM(args, files, { stdout: stderr, stderr }));
      const out = {};
      for (const path of outputs) out[path] = pick(result, path);
      parentPort.postMessage({ id, out, log: Buffer.concat(chunks).toString() });
    } catch (error) {
      parentPort.postMessage({ id, error: `${error.message}\n${Buffer.concat(chunks).toString()}` });
    }
  });
  parentPort.postMessage({ ready: true });
}

// a nested tree ({dir: {file: bytes}}) of a Map of paths
function treeOf(map, prefix = '') {
  const tree = {};
  for (const [path, data] of map) {
    const parts = (prefix + path).split('/');
    let node = tree;
    for (const part of parts.slice(0, -1)) node = node[part] ??= {};
    node[parts.at(-1)] = data instanceof Uint8Array ? data : Buffer.from(data);
  }
  return tree;
}

function pick(tree, path) {
  let node = tree;
  for (const part of path.split('/')) {
    node = node?.[part];
    if (node === undefined) throw new Error(`no ${path} after the command`);
  }
  return node;
}

class Pool {
  constructor(size, bundle, tree) {
    this.jobs = new Map();
    this.next = 0;
    this.queue = [];
    this.idle = [];
    this.ready = Promise.all(Array.from({ length: size }, () => new Promise((resolve, reject) => {
      const worker = new Worker(SELF, { workerData: { bundle, tree } });
      worker.on('error', reject);
      worker.on('message', (message) => {
        if (message.ready) { this.idle.push(worker); this.pump(); resolve(); return; }
        const job = this.jobs.get(message.id);
        this.jobs.delete(message.id);
        this.idle.push(worker);
        this.pump();
        if (message.error) job.reject(new Error(`${job.label}: ${message.error}`));
        else job.resolve(message);
      });
      this.workers = [...(this.workers ?? []), worker];
    })));
  }

  run(label, tool, args, outputs, extra = null) {
    return new Promise((resolve, reject) => {
      this.queue.push({ label, tool, args, outputs, extra, resolve, reject });
      this.pump();
    });
  }

  pump() {
    while (this.idle.length && this.queue.length) {
      const worker = this.idle.pop();
      const job = this.queue.shift();
      const id = this.next++;
      this.jobs.set(id, job);
      worker.postMessage({ id, tool: job.tool, args: job.args, extra: job.extra, outputs: job.outputs });
    }
  }

  close() { for (const worker of this.workers) worker.terminate(); }
}

// ------------------------------------------------------------------ build

// the flags Spinel's Makefile and src/main.c give wasm32-wasi (WASI_CFLAGS)
const WASI = ['--target=wasm32-wasip1', '-D_WASI_EMULATED_SIGNAL', '-D_WASI_EMULATED_PROCESS_CLOCKS',
              '-D_WASI_EMULATED_GETPID', '-D_WASI_EMULATED_MMAN', '-mllvm', '-wasm-enable-sjlj',
              '-mllvm', '-wasm-use-legacy-eh=false'];
const WASI_LIBS = ['-lsetjmp', '-lwasi-emulated-signal', '-lwasi-emulated-process-clocks',
                   '-lwasi-emulated-getpid', '-lwasi-emulated-mman'];
const FP = ['-ffp-contract=off'];
const CFLAGS = ['-O2', '-Wno-all', '-Wno-unknown-warning-option', '-Wno-format-truncation', ...FP];   // common.mk
const SEC = ['-ffunction-sections', '-fdata-sections', ...FP];

// What the compiler needs to link for wasm32-wasi beyond lib/wasi's stand-ins:
// it calls system() and mkdtemp() only when it drives cc or runs a program
// (-E), which the page never asks of it (-c --print-build), so both fail.
const PAGE_HOST_C = `#include <errno.h>
#include <stddef.h>
int system(const char *command) { (void)command; errno = ENOSYS; return -1; }
char *mkdtemp(char *template_) { (void)template_; errno = ENOSYS; return NULL; }
`;

// lib/wasi/sp_page.h, included first into the runtime and into every program
// (-include; html/spinel-build.js): wasi-libc declares flockfile and
// funlockfile only for its threaded build, and the runtime's puts takes the
// stream lock (spinel_rt.h). A program for wasm32-wasi has one thread, so
// the lock is nothing. (With the wasi-sdk's own sysroot it builds anyway.)
const PAGE_H = `/* tools/build_spinel.mjs: what the page's build of Spinel adds for wasm32-wasi */
#ifndef SP_PAGE_H
#define SP_PAGE_H
#include <stdio.h>
#ifndef _REENTRANT
#define flockfile(f) ((void)(f))
#define funlockfile(f) ((void)(f))
#endif
#endif
`;

const PAGE_INCLUDE = ['-include', 'lib/wasi/sp_page.h'];

// Source fixes the wasm target needs, each [file, anchor, text added after it].
// A native build tolerates a call to an undeclared function (int is assumed);
// wasm-ld does not, when the definition returns something else: it links a
// stub that traps (the "function signature mismatch" warning, fatal below).
const PATCHES = [
  ['src/codegen_stmt.c', '#include "builtin_ops.h"\n',
   'void emit_int_flt_rel(Buf *b, const char *iv, const char *fv, int int_left, const char *op);\n'],
];

// a Makefile variable's words (backslash continuations joined)
function makeVar(makefile, name) {
  const match = makefile.replace(/\\\n/g, ' ').match(new RegExp(`^${name}\\s*\\+?=(.*)$`, 'gm'));
  if (!match) throw new Error(`Makefile: no ${name}`);
  return match.flatMap((line) => line.replace(/^[^=]*=/, '').trim().split(/\s+/)).filter(Boolean);
}

// build/csrc/sp_rt_names.h: the first segment of every sp_* name the runtime owns
function rtNames(source) {
  const names = new Set(['rb']);
  for (const [path, body] of source) {
    if (!/^(lib|packages\/[^/]+)\/[^/]+\.[ch]$/.test(path)) continue;
    for (const match of body.toString('latin1').matchAll(/\bsp_([a-z][a-z0-9_]*)/g)) names.add(match[1].split('_')[0]);
  }
  const sorted = [...names].sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
  return '/* generated from the runtime sources; see the Makefile rule */\n' +
    'static const char *const SP_RT_PREFIXES[] = {\n' + sorted.map((n) => `  "${n}",\n`).join('') + '  NULL\n};\n';
}

async function build(pins, jobs) {
  const t0 = Date.now();
  const [source, prism, clang] = await Promise.all([spinelSource(pins.spinel), prismSource(pins.prism), npmPackage(pins.clang)]);
  const makefile = source.get('Makefile').toString();

  // clang's package, unpacked for Node to import (and copied to the page below)
  const clangDir = join(CACHE, `clang-${pins.clang.version}`);
  if (!existsSync(join(clangDir, 'gen', 'bundle.js'))) {
    for (const [path, body] of clang) {
      mkdirSync(dirname(join(clangDir, path)), { recursive: true });
      writeFileSync(join(clangDir, path), body);
    }
  }

  const rev = `#define SPINEL_BUILD_REV "${pins.spinel.commit.slice(0, 7)}"\n` +
              `#define SPINEL_RELEASE "${pins.spinel.date}"\n#define SPINEL_OPENSSL_LIBDIR ""\n`;
  const files = new Map([...source].filter(([path]) => /^(src|lib|packages)\//.test(path)));
  for (const [path, body] of prism) files.set(`vendor/prism/${path}`, body);
  files.set('build/csrc/spinel_rev.h', Buffer.from(rev));
  files.set('build/csrc/sp_rt_names.h', Buffer.from(rtNames(source)));
  files.set('build/csrc/sp_page_host.c', Buffer.from(PAGE_HOST_C));
  files.set('lib/wasi/sp_page.h', Buffer.from(PAGE_H));
  for (const [path, from, to] of PATCHES) {
    const text = files.get(path).toString();
    if (text.includes(to.trim())) continue;   // fixed upstream
    if (!text.includes(from)) throw new Error(`patch for ${path} no longer applies: Spinel changed there - look again`);
    files.set(path, Buffer.from(text.replace(from, from + to)));
  }
  const tree = treeOf(files);

  const size = jobs ?? Math.max(1, Math.min(8, cpus().length - 1));
  console.log(`compiling with ${size} clang workers`);
  const pool = new Pool(size, join(clangDir, 'gen', 'bundle.js'), tree);
  await pool.ready;
  let done = 0, total = 0;
  // an object is kept in .cache/spinel/objects/ under its sources' versions
  // and its command line, so a rerun compiles only what changed
  const compile = (src, obj, flags) => {
    total++;
    const args = ['clang', ...WASI, ...flags, '-c', src, '-o', obj];
    const key = createHash('sha256').update(JSON.stringify([pins.prism, pins.clang.version, args])).update(files.get(src)).digest('hex');
    const keep = join(CACHE, 'objects', `${key.slice(0, 24)}.o`);
    const progress = () => {
      done++;
      if (process.stdout.isTTY) process.stdout.write(`\r  ${done}/${total} ${src}`.padEnd(80));
    };
    if (existsSync(keep)) { progress(); return Promise.resolve([obj, readFileSync(keep)]); }
    return pool.run(src, 'clang', args, [obj]).then(({ out, log }) => {
      progress();
      if (log.trim()) console.log(`\n${src}:\n${log.trim()}`);
      mkdirSync(dirname(keep), { recursive: true });
      writeFileSync(keep, out[obj]);
      return [obj, out[obj]];
    });
  };

  try {
    const objects = [];
    // libprism
    for (const path of files.keys()) {
      const match = path.match(/^vendor\/prism\/src\/(.*)\.c$/);
      if (match) objects.push(compile(path, `build/prism/${match[1]}.o`, ['-O2', ...FP, '-Ivendor/prism/include', '-Ivendor/prism/src']));
    }
    // the regexp engine: the compiler checks literals with it, the runtime runs it
    const reSrc = makeVar(makefile, 'RE_SRC');
    for (const src of reSrc) {
      objects.push(compile(src, src.replace(/^lib\/regexp\/(.*)\.c$/, 'build/regexp/$1.o'), ['-O2', ...SEC, '-Ilib/regexp', '-Ilib/regexp/shim']));
    }
    // the compiler (SPINEL_OBJ), its parser and literal check; the POSIX
    // stand-ins of lib/wasi for the process calls it makes when it drives cc
    // (it never does here: the page asks for C only)
    const compilerObjs = makeVar(makefile, 'SPINEL_OBJ').map((obj) => obj.replace(/^build\/csrc\/(.*)\.o$/, '$1'));
    for (const name of compilerObjs) {
      objects.push(compile(`src/${name}.c`, `build/csrc/${name}.o`, [...CFLAGS, '-Werror=return-type', '-Ilib/wasi', '-Isrc', '-Ibuild/csrc']));
    }
    objects.push(compile('src/spinel_parse.c', 'build/csrc/sp_parse_lib.o', [...CFLAGS, '-Ilib/wasi', '-Ivendor/prism/include']));
    objects.push(compile('src/re_lit_check.c', 'build/csrc/re_lit_check.o', [...CFLAGS, '-Ilib/wasi', '-Ilib/regexp', '-Ilib/regexp/shim']));
    objects.push(compile('build/csrc/sp_page_host.c', 'build/csrc/sp_page_host.o', CFLAGS));
    // the runtime (RT_MEMBERS) and the wasi shim, as `make wasm-rt`
    const rtMembers = makeVar(makefile, 'RT_MEMBERS');
    for (const name of rtMembers) {
      objects.push(compile(`lib/${name}.c`, `build/wasm32-wasi/${name}.o`, ['-O2', '-Wno-all', ...SEC, ...PAGE_INCLUDE, '-Ilib/wasi', '-Ilib', '-Ilib/regexp', '-Ilib/regexp/shim']));
    }
    const shimSrc = [...files.keys()].filter((path) => /^lib\/wasi\/[^/]+\.c$/.test(path));
    for (const src of shimSrc) {
      objects.push(compile(src, src.replace(/^lib\/wasi\/(.*)\.c$/, 'build/wasm32-wasi/wasi/$1.o'), ['-O2', '-Wno-all', ...SEC, ...PAGE_INCLUDE, '-Ilib/wasi', '-Ilib']));
    }
    // the bundled packages' carried C (BUNDLED_NATIVE_OBJS but openssl and ffi)
    const packageObjs = makeVar(makefile, 'BUNDLED_NATIVE_OBJS')
      .filter((obj) => /^packages\/.*\.o$/.test(obj) && !/^packages\/(openssl|ffi)\//.test(obj));
    for (const obj of packageObjs) {
      const src = obj.replace(/\.o$/, '.c');
      objects.push(compile(src, obj.replace(/\.o$/, '_wasi.o'), ['-O2', '-Wno-all', ...SEC, ...PAGE_INCLUDE, '-Ilib/wasi', '-Ilib', `-I${dirname(src)}`]));
    }
    const results = await Promise.allSettled(objects);
    if (process.stdout.isTTY) process.stdout.write('\n');
    const failed = results.filter((r) => r.status === 'rejected');
    if (failed.length) throw new Error(failed.map((r) => r.reason.message).join('\n'));
    const built = new Map(results.map((r) => r.value));

    // link the compiler: spinel.wasm
    const compilerInputs = [...compilerObjs.map((n) => `build/csrc/${n}.o`), 'build/csrc/sp_parse_lib.o', 'build/csrc/re_lit_check.o', 'build/csrc/sp_page_host.o',
                            ...reSrc.map((s) => s.replace(/^lib\/regexp\/(.*)\.c$/, 'build/regexp/$1.o')),
                            ...shimSrc.map((s) => s.replace(/^lib\/wasi\/(.*)\.c$/, 'build/wasm32-wasi/wasi/$1.o')),
                            ...[...built.keys()].filter((p) => p.startsWith('build/prism/'))];
    const objectTree = Object.fromEntries(compilerInputs.map((p) => [p, built.get(p)]));
    console.log('linking spinel.wasm');
    const { out: linked } = await pool.run('link spinel.wasm', 'clang',
      ['clang', ...WASI, ...compilerInputs, '-lm', ...WASI_LIBS, '-Wl,-z,stack-size=8388608', '-Wl,--strip-all', '-Wl,--fatal-warnings', '-o', 'spinel.wasm'],
      ['spinel.wasm'], objectTree);

    // the runtime archive
    const rtInputs = [...reSrc.map((s) => s.replace(/^lib\/regexp\/(.*)\.c$/, 'build/regexp/$1.o')),
                      ...shimSrc.map((s) => s.replace(/^lib\/wasi\/(.*)\.c$/, 'build/wasm32-wasi/wasi/$1.o')),
                      ...rtMembers.map((n) => `build/wasm32-wasi/${n}.o`)];
    console.log('archiving libspinel_rt.a');
    const { out: archived } = await pool.run('ar', 'llvm', ['ar', 'rcs', 'libspinel_rt.a', ...rtInputs], ['libspinel_rt.a'],
      Object.fromEntries(rtInputs.map((p) => [p, built.get(p)])));

    // what spinel.wasm and clang read in the page: one tar
    const entries = [];
    for (const [path, body] of source) {
      if (/^builtins\/[^/]+\.rb$/.test(path) || /^packages\/[^/]+\/(?!test\/).+\.rb$/.test(path) ||
          /^lib\/(.+\/)?[^/]+\.(h|inc)$/.test(path)) entries.push([path, body]);
    }
    entries.push(['lib/wasi/sp_page.h', Buffer.from(PAGE_H)]);
    entries.push(['lib/wasm32-wasi/libspinel_rt.a', Buffer.from(archived['libspinel_rt.a'])]);
    // resolve_lib_dir looks for lib/libspinel_rt.a beside the compiler: the same archive
    entries.push(['lib/libspinel_rt.a', Buffer.alloc(0)]);
    for (const obj of packageObjs) entries.push([obj.replace(/\.o$/, '_wasi.o'), Buffer.from(built.get(obj.replace(/\.o$/, '_wasi.o')))]);
    entries.push(['LICENSE', source.get('LICENSE')]);
    entries.sort(([a], [b]) => (a < b ? -1 : 1));

    const output = new Map();
    output.set('spinel.wasm', Buffer.from(linked['spinel.wasm']));
    output.set('spinel-files.tar', tar(entries));
    output.set('LICENSE-spinel.txt', source.get('LICENSE'));
    for (const [path, body] of clang) {
      if (/^gen\/(bundle\.js|llvm\.core\d*\.wasm)$/.test(path)) output.set(`clang/${path.slice(4)}`, body);
    }
    output.set('clang/llvm-resources.tar', trimSysroot(clang.get('gen/llvm-resources.tar')));
    output.set('clang/README.md', clang.get('README.md'));
    console.log(`built in ${((Date.now() - t0) / 1000).toFixed(0)} s`);
    return output;
  } finally {
    pool.close();
  }
}

// clang's resources: its own headers and the wasm32-wasip1 sysroot, without
// C++, the other WASI targets and other architectures' headers
function trimSysroot(tarball) {
  const keep = untar(tarball).filter(([path]) => {
    if (/\/c\+\+\//.test(path) || /libc\+\+|libunwind/.test(path)) return false;
    if (/^(include|lib)\/wasm32-wasi(p2|p1-threads|-threads)?\//.test(path) && !/wasm32-wasip1\//.test(path)) return false;
    if (/^include\/[^/]+\.h$/.test(path) && /cuda|hip|opencl|arm_|riscv|altivec|htm|s390|avx|sse|mmintrin|amx|x86|ia32|immintrin|hexagon|loongson|lasx|lsx|msa|vec|velintrin|ppc/.test(path)) return false;
    if (/^include\/(cuda_wrappers|openmp_wrappers|ppc_wrappers|llvm_libc_wrappers|llvm_offload_wrappers|orc|fuzzer|profile|sanitizer|xray|zos_wrappers)\//.test(path)) return false;
    return true;
  });
  return tar(keep);
}

function write(output, pins, stampValue) {
  const staging = `${TARGET}.new`;
  rmSync(staging, { recursive: true, force: true });
  const sizes = {};
  for (const [path, body] of output) {
    const full = join(staging, path);
    mkdirSync(dirname(full), { recursive: true });
    writeFileSync(full, body);
    sizes[path] = body.length;
    // nginx serves the .gz in its place (gzip_static)
    if (body.length > 256 * 1024) writeFileSync(`${full}.gz`, gzipSync(body, { level: zlibConstants.Z_BEST_COMPRESSION }));
  }
  const manifest = { stamp: stampValue, spinel: pins.spinel, prism: pins.prism, clang: pins.clang.version,
                     built: new Date().toISOString(), sizes };
  writeFileSync(join(staging, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
  rmSync(`${TARGET}.old`, { recursive: true, force: true });
  if (existsSync(TARGET)) renameSync(TARGET, `${TARGET}.old`);
  renameSync(staging, TARGET);
  rmSync(`${TARGET}.old`, { recursive: true, force: true });
  for (const [path, size] of Object.entries(sizes)) {
    const gz = join(TARGET, `${path}.gz`);
    console.log(`  html/assets/spinel/${path.padEnd(28)} ${(size / 1e6).toFixed(1).padStart(6)} MB` +
                (existsSync(gz) ? ` -> ${(statSync(gz).size / 1e6).toFixed(1).padStart(5)} MB gz` : ''));
  }
}

async function newestCommit(repo) {
  const response = await fetch(`https://api.github.com/repos/${repo}/commits/HEAD`, { headers: { 'User-Agent': 'chunkybacon-build-spinel' } });
  if (!response.ok) throw new Error(`GitHub: ${response.status}`);
  const data = await response.json();
  return { sha: data.sha, date: data.commit.committer.date.slice(0, 10) };
}

async function main() {
  const argv = process.argv.slice(2);
  const jobsAt = argv.indexOf('--jobs');
  const jobs = jobsAt >= 0 ? Number(argv[jobsAt + 1]) : null;
  let pins = JSON.parse(readFileSync(PINS_FILE, 'utf8'));
  if (argv.includes('--update')) {
    const { sha, date } = await newestCommit(pins.spinel.repo);
    if (sha !== pins.spinel.commit) {
      console.log(`spinel: ${pins.spinel.commit.slice(0, 7)} -> ${sha.slice(0, 7)} (${date})`);
      pins = { ...pins, spinel: { ...pins.spinel, commit: sha, date } };
      writeFileSync(PINS_FILE, JSON.stringify(pins, null, 2) + '\n');
    } else {
      console.log(`spinel: ${sha.slice(0, 7)} is the newest commit already`);
    }
  }
  const want = stamp(pins);
  const have = currentStamp();
  if (argv.includes('--check')) {
    console.log(have === want ? `current html/assets/spinel (${want})` : 'STALE   html/assets/spinel: run node tools/build_spinel.mjs');
    process.exit(have === want ? 0 : 1);
  }
  if (have === want && !argv.includes('--force')) {
    console.log(`current html/assets/spinel (spinel ${pins.spinel.commit.slice(0, 7)}, ${want})`);
    return;
  }
  console.log(`building spinel ${pins.spinel.commit.slice(0, 7)} (${pins.spinel.date}) for the browser`);
  write(await build(pins, jobs), pins, want);
}

if (isMainThread) {
  main().catch((error) => { console.error(error.stack || error.message); process.exit(1); });
} else {
  workerMain();
}
