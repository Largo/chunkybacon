import { WASI, File, Directory, PreopenDirectory, ConsoleStdout, OpenFile } from './wasi-shim/index.js';

const say = (key, extra) => postMessage({ type: 'log', key, extra });
const cache = {};

async function untar(url) {
  const res = await fetch(url);
  const buf = await new Response(res.body.pipeThrough(new DecompressionStream('gzip'))).arrayBuffer();
  const u8 = new Uint8Array(buf), dec = new TextDecoder(), files = {};
  for (let o = 0; o + 512 <= u8.length;) {
    const name = dec.decode(u8.subarray(o, o + 100)).replace(/\0.*$/, '');
    if (!name) break;
    const size = parseInt(dec.decode(u8.subarray(o + 124, o + 136)).replace(/\0.*$/, '').trim(), 8) || 0;
    const type = String.fromCharCode(u8[o + 156]);
    if ((type === '0' || type === '\0') && !name.endsWith('/')) files[name.replace(/^\.\//, '')] = u8.subarray(o + 512, o + 512 + size);
    o += 512 + Math.ceil(size / 512) * 512;
  }
  return files;
}
async function pkg(name) {
  if (!cache[name]) { cache[name] = await untar(`toolchain/pkg/${name}.tar.gz`); say('loaded', name); }
  return cache[name];
}
function toDir(files) {
  const root = new Map();
  for (const [p, data] of Object.entries(files)) {
    const parts = p.split('/'); let m = root;
    for (const d of parts.slice(0, -1)) { if (!m.has(d)) m.set(d, new Directory(new Map())); m = m.get(d).contents; }
    m.set(parts.at(-1), new File(data));
  }
  return root;
}
function mount(FS, files, vdir) {
  for (const [p, data] of Object.entries(files)) {
    const full = vdir + '/' + p, dir = full.slice(0, full.lastIndexOf('/'));
    FS.mkdirTree(dir); FS.writeFile(full, data);
  }
}

let spModule;
async function spinelToC(ruby) {
  const sp = await pkg('spinel');
  spModule ??= await WebAssembly.compileStreaming(fetch('toolchain/spinel.wasm'));
  const work = new Map([['prog.rb', new File(new TextEncoder().encode(ruby))]]);
  let err = '';
  const out = new TextDecoder();
  const wasi = new WASI(['/sp/bin/spinel', '/w/prog.rb', '-c', '-o', '/w/prog.c', '--force'], [], [
    new OpenFile(new File([])), ConsoleStdout.lineBuffered((s) => (err += s + '\n')), ConsoleStdout.lineBuffered((s) => (err += s + '\n')),
    new PreopenDirectory('/sp', toDir(sp)), new PreopenDirectory('/w', work)]);
  const inst = await WebAssembly.instantiate(spModule, { wasi_snapshot_preview1: wasi.wasiImport });
  const code = wasi.start(inst);
  const c = work.get('prog.c');
  if (code !== 0 || !c) throw new Error('spinel:\n' + err);
  return out.decode(c.data);
}

const T = {
  win: { triple: 'x86_64-w64-windows-gnu', exe: 'a.exe',
    cc1: ['-exception-model=seh', '-D_UCRT', '-D_FILE_OFFSET_BITS=64', '-DWIN32_LEAN_AND_MEAN', '-D_WIN32_WINNT=0x0A00', '-I/t/spinel/win32', '-internal-isystem', '/t/inc'],
    ld: ['-m', 'i386pep', '-Bstatic', '-o', '/a.exe', '/t/lib/crt2.o', '/t/lib/crtbegin.o', '-L/t/spinel/win32', '-L/t/lib', '/prog.o', '/t/spinel/libspinel_rt.a',
      '-lws2_32', '-lbcrypt', '-lwinpthread', '-lm', '--start-group', '-lmingw32', '/t/lib/libclang_rt.builtins-x86_64.a', '-l:libunwind.a', '-lmoldname', '-lmingwex', '-lmsvcrt',
      '-ladvapi32', '-lshell32', '-luser32', '-lkernel32', '--end-group', '/t/lib/crtend.o', '--stack=8388608'] },
  linux: { triple: 'x86_64-unknown-linux-musl', exe: 'a.out', cc1: ['-internal-isystem', '/t/inc'],
    ld: ['-static', '-o', '/a.out', '/t/lib/crt1.o', '/t/lib/crti.o', '/prog.o', '/t/spinel/libspinel_rt.a', '-L/t/lib', '-lm', '-lc', '/t/lib/libgcc.a', '/t/lib/libgcc_eh.a', '/t/lib/crtn.o'] },
};

async function cToBinary(c, target) {
  const t = T[target]; let err = '';
  const opt = { print: (s) => (err += s + '\n'), printErr: (s) => (err += s + '\n') };
  say('fetch');
  const [res, sys] = [await pkg('res'), await pkg(target)];
  const Clang = (await import('./toolchain/clang.js')).default;
  const LLD = (await import('./toolchain/lld.js')).default;
  const clang = await Clang({ thisProgram: 'clang', ...opt });
  mount(clang.FS, res, '/res'); mount(clang.FS, sys, '/t'); clang.FS.writeFile('/prog.c', c);
  const args = ['-cc1', '-triple', t.triple, '-O2', '-emit-obj', '-mrelocation-model', 'pic', '-pic-level', '2', '-mframe-pointer=none', '-fmath-errno', '-ffp-contract=off',
    '-funwind-tables=2', '-target-cpu', 'x86-64', '-fgnuc-version=4.2.1', '-fno-use-cxa-atexit', '-resource-dir', '/res', '-internal-isystem', '/res/include', '-w',
    '-DSP_INT_OVERFLOW_MODE_RAISE', '-I/t/spinel', '-I/t/spinel/regexp', ...t.cc1, '-o', '/prog.o', '-x', 'c', '/prog.c'];
  say('compile');
  if (clang.callMain(args) !== 0) throw new Error('clang:\n' + err);
  say('link');
  const obj = clang.FS.readFile('/prog.o');
  const lld = await LLD({ thisProgram: 'ld.lld', ...opt });
  mount(lld.FS, sys, '/t'); lld.FS.writeFile('/prog.o', obj);
  // a copy: callMain puts the program name in front of the array it gets
  if (lld.callMain([...t.ld]) !== 0) throw new Error('lld:\n' + err);
  return lld.FS.readFile('/' + t.exe);
}

onmessage = async ({ data: { ruby, target, id } }) => {
  try {
    say('translate');
    const c = await spinelToC(ruby);
    const bin = await cToBinary(c, target);
    postMessage({ type: 'done', id, target, bin }, [bin.buffer]);
  } catch (e) { postMessage({ type: 'error', id, m: String(e.message || e) }); }
};
