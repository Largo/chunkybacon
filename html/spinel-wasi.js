// A small WASI (preview 1) host for the Spinel lesson (spinel-worker.js):
// it runs spinel.wasm, the compiler, and the programs it builds, each on a
// filesystem in memory. Only what those two ask of a host is here - files
// and directories under one preopened "/", stdin/stdout/stderr, clocks,
// random numbers, exit; everything else answers ENOSYS, as an unsupported
// call does on a POSIX system.
//
//   const fs = new MemFS();  fs.writeFile("/work/app.rb", bytes)
//   const { code, stdout, stderr } = runWasi(module, { args: ["spinel", ...], fs, stdin })
//
// An ES module: the worker imports it, and so does test/spinel_test.mjs.

const E = { SUCCESS: 0, BADF: 8, EXIST: 20, INVAL: 28, ISDIR: 31, NOENT: 44, NOSYS: 52, NOTDIR: 54, NOTEMPTY: 55, SPIPE: 70 };
const FILETYPE = { CHARACTER_DEVICE: 2, DIRECTORY: 3, REGULAR_FILE: 4 };
const OFLAGS = { CREAT: 1, DIRECTORY: 2, EXCL: 4, TRUNC: 8 };
const FDFLAGS_APPEND = 1;

export class WasiExit extends Error {
  constructor(code) { super(`exit ${code}`); this.code = code; }
}

// A file is { data: Uint8Array, size }, a directory { entries: Map }.
export class MemFS {
  constructor() { this.root = { entries: new Map() }; }

  static parts(path) { return path.split('/').filter((p) => p && p !== '.'); }

  lookup(path, from = this.root) {
    let node = from;
    const stack = [];
    for (const part of MemFS.parts(path)) {
      if (!node.entries) return null;
      if (part === '..') { node = stack.pop() ?? this.root; continue; }
      stack.push(node);
      node = node.entries.get(part);
      if (!node) return null;
    }
    return node;
  }

  // the directory a path is in, and its last part
  parent(path, from = this.root, create = false) {
    const parts = MemFS.parts(path);
    const name = parts.pop();
    let node = from;
    for (const part of parts) {
      let next = part === '..' ? this.root : node.entries.get(part);
      if (!next && create) { next = { entries: new Map() }; node.entries.set(part, next); }
      if (!next || !next.entries) return [null, name];
      node = next;
    }
    return [node, name];
  }

  writeFile(path, data) {
    const [dir, name] = this.parent(path, this.root, true);
    const bytes = typeof data === 'string' ? new TextEncoder().encode(data) : new Uint8Array(data);
    dir.entries.set(name, { data: bytes, size: bytes.length });
  }

  readFile(path) {
    const node = this.lookup(path);
    return node && !node.entries ? node.data.subarray(0, node.size) : null;
  }

  // the files of a tar archive (ustar, as tools/build_spinel.mjs writes it), under +prefix+
  addTar(buffer, prefix = '/') {
    const bytes = new Uint8Array(buffer);
    const text = (start, length) => {
      let end = start;
      while (end < start + length && bytes[end]) end++;
      return new TextDecoder().decode(bytes.subarray(start, end));
    };
    for (let at = 0; at + 512 <= bytes.length && bytes[at];) {
      const size = parseInt(text(at + 124, 12).trim() || '0', 8);
      const pre = text(at + 345, 155);
      const name = (pre ? pre + '/' : '') + text(at, 100);
      // a file is shared with the archive until written (the compiler and clang only read these)
      if (bytes[at + 156] === 53) this.mkdir(prefix + name);   // "5": a directory
      else this.writeFileShared(prefix + name, bytes.subarray(at + 512, at + 512 + size));
      at += 512 + Math.ceil(size / 512) * 512;
    }
  }

  mkdir(path) {
    const [dir, name] = this.parent(path, this.root, true);
    if (!dir.entries.has(name)) dir.entries.set(name, { entries: new Map() });
  }

  writeFileShared(path, bytes) {
    const [dir, name] = this.parent(path, this.root, true);
    dir.entries.set(name, { data: bytes, size: bytes.length, shared: true });
  }

  // a copy whose files can be written without touching this one's
  clone() {
    const copy = (node) => node.entries
      ? { entries: new Map([...node.entries].map(([k, v]) => [k, copy(v)])) }
      : { data: node.data, size: node.size, shared: true };
    const fs = new MemFS();
    fs.root = copy(this.root);
    return fs;
  }
}

// Runs a WASI command module to its end, synchronously (in a worker: the
// page's own thread would freeze). stdin is a Uint8Array or a function
// returning the next chunk (null at the end).
export function runWasi(module, { args = [], env = {}, fs = new MemFS(), stdin = null, stdout = null, stderr = null } = {}) {
  const out = [], err = [];
  const emit = (fd, bytes) => {
    const copy = bytes.slice();
    if (fd === 1) (stdout ? stdout(copy) : out.push(copy));
    else (stderr ? stderr(copy) : err.push(copy));
  };
  let input = stdin instanceof Uint8Array ? stdin : null, inputAt = 0;
  const readStdin = (max) => {
    if (typeof stdin === 'function' && (!input || inputAt >= input.length)) { input = stdin(max); inputAt = 0; }
    if (!input || inputAt >= input.length) return new Uint8Array(0);
    const chunk = input.subarray(inputAt, inputAt + max);
    inputAt += chunk.length;
    return chunk;
  };

  // fd 3 is the preopened "/" (wasi-libc hands every path over relative to it)
  const fds = new Map([[0, { tty: 0 }], [1, { tty: 1 }], [2, { tty: 2 }], [3, { dir: fs.root, path: '/' }]]);
  let nextFd = 4;
  let memory;
  const view = () => new DataView(memory.buffer);
  const u8 = () => new Uint8Array(memory.buffer);
  const str = (ptr, len) => new TextDecoder().decode(u8().subarray(ptr, ptr + len));
  const encoded = (list) => list.map((s) => new TextEncoder().encode(s + '\0'));
  const argBytes = encoded(args);
  const envBytes = encoded(Object.entries(env).map(([k, v]) => `${k}=${v}`));

  const putList = (list, ptrs, buf) => {
    const dv = view(), mem = u8();
    for (const item of list) {
      dv.setUint32(ptrs, buf, true); ptrs += 4;
      mem.set(item, buf); buf += item.length;
    }
    return E.SUCCESS;
  };
  const sizes = (list, countPtr, sizePtr) => {
    view().setUint32(countPtr, list.length, true);
    view().setUint32(sizePtr, list.reduce((n, b) => n + b.length, 0), true);
    return E.SUCCESS;
  };
  const iovecs = (ptr, len) => {
    const dv = view(), list = [];
    for (let i = 0; i < len; i++) list.push([dv.getUint32(ptr + i * 8, true), dv.getUint32(ptr + i * 8 + 4, true)]);
    return list;
  };
  // the node a path names, relative to a directory fd
  const resolve = (dirfd, ptr, len) => {
    const base = fds.get(dirfd);
    if (!base || !base.dir) return [null, null, null];
    const path = str(ptr, len);
    const from = path.startsWith('/') ? fs.root : base.dir;
    return [fs.lookup(path, from), path, from];
  };
  const fileStat = (ptr, node, tty) => {
    const dv = view();
    for (let i = 0; i < 64; i += 8) dv.setBigUint64(ptr + i, 0n, true);
    dv.setUint8(ptr + 16, tty ? FILETYPE.CHARACTER_DEVICE : node.entries ? FILETYPE.DIRECTORY : FILETYPE.REGULAR_FILE);
    dv.setBigUint64(ptr + 24, 1n, true);
    dv.setBigUint64(ptr + 32, BigInt(node && !node.entries ? node.size : 0), true);
    return E.SUCCESS;
  };
  const writable = (node) => {
    if (node.shared) { node.data = node.data.slice(0, node.size); node.shared = false; }
  };
  const grow = (node, size) => {
    writable(node);
    if (size <= node.data.length) return;
    const next = new Uint8Array(Math.max(size, node.data.length * 2, 256));
    next.set(node.data.subarray(0, node.size));
    node.data = next;
  };
  const writeAt = (node, at, bytes) => {
    grow(node, at + bytes.length);
    node.data.set(bytes, at);
    node.size = Math.max(node.size, at + bytes.length);
  };

  const wasi = {
    args_get: (ptrs, buf) => putList(argBytes, ptrs, buf),
    args_sizes_get: (count, size) => sizes(argBytes, count, size),
    environ_get: (ptrs, buf) => putList(envBytes, ptrs, buf),
    environ_sizes_get: (count, size) => sizes(envBytes, count, size),
    clock_res_get: (id, ptr) => { view().setBigUint64(ptr, 1000n, true); return E.SUCCESS; },
    clock_time_get: (id, precision, ptr) => {
      const ns = id === 0 ? BigInt(Date.now()) * 1000000n : BigInt(Math.round(performance.now() * 1e6));
      view().setBigUint64(ptr, ns, true);
      return E.SUCCESS;
    },
    random_get: (ptr, len) => {
      for (let at = 0; at < len; at += 65536) crypto.getRandomValues(u8().subarray(ptr + at, ptr + Math.min(len, at + 65536)));
      return E.SUCCESS;
    },
    proc_exit: (code) => { throw new WasiExit(code); },
    proc_raise: () => E.NOSYS,
    sched_yield: () => E.SUCCESS,
    poll_oneoff: (inPtr, outPtr, n, countPtr) => {
      // sleep: a clock subscription waits for nothing (a virtual sleep); the
      // events say every subscription is done
      const dv = view();
      for (let i = 0; i < n; i++) {
        const sub = inPtr + i * 48, ev = outPtr + i * 32;
        dv.setBigUint64(ev, dv.getBigUint64(sub, true), true);
        dv.setUint16(ev + 8, 0, true);
        dv.setUint8(ev + 10, dv.getUint8(sub + 8));
      }
      dv.setUint32(countPtr, n, true);
      return E.SUCCESS;
    },

    fd_write: (fd, iovs, len, nPtr) => {
      const file = fds.get(fd);
      if (!file) return E.BADF;
      let n = 0;
      for (const [ptr, size] of iovecs(iovs, len)) {
        const bytes = u8().subarray(ptr, ptr + size);
        if (file.tty !== undefined) emit(fd, bytes);
        else if (file.node && !file.node.entries) {
          if (file.append) file.at = file.node.size;
          writeAt(file.node, file.at, bytes);
          file.at += size;
        } else return E.BADF;
        n += size;
      }
      view().setUint32(nPtr, n, true);
      return E.SUCCESS;
    },
    fd_pwrite: (fd, iovs, len, offset, nPtr) => {
      const file = fds.get(fd);
      if (!file || !file.node || file.node.entries) return E.BADF;
      let at = Number(offset), n = 0;
      for (const [ptr, size] of iovecs(iovs, len)) { writeAt(file.node, at, u8().subarray(ptr, ptr + size)); at += size; n += size; }
      view().setUint32(nPtr, n, true);
      return E.SUCCESS;
    },
    fd_read: (fd, iovs, len, nPtr) => {
      const file = fds.get(fd);
      if (!file) return E.BADF;
      let n = 0;
      for (const [ptr, size] of iovecs(iovs, len)) {
        let chunk;
        if (file.tty === 0) chunk = readStdin(size);
        else if (file.node && !file.node.entries) { chunk = file.node.data.subarray(file.at, Math.min(file.node.size, file.at + size)); file.at += chunk.length; }
        else return file.node ? E.ISDIR : E.BADF;
        u8().set(chunk, ptr);
        n += chunk.length;
        if (chunk.length < size) break;
      }
      view().setUint32(nPtr, n, true);
      return E.SUCCESS;
    },
    fd_pread: (fd, iovs, len, offset, nPtr) => {
      const file = fds.get(fd);
      if (!file || !file.node || file.node.entries) return E.BADF;
      let at = Number(offset), n = 0;
      for (const [ptr, size] of iovecs(iovs, len)) {
        const chunk = file.node.data.subarray(at, Math.min(file.node.size, at + size));
        u8().set(chunk, ptr); at += chunk.length; n += chunk.length;
        if (chunk.length < size) break;
      }
      view().setUint32(nPtr, n, true);
      return E.SUCCESS;
    },
    fd_seek: (fd, offset, whence, ptr) => {
      const file = fds.get(fd);
      if (!file) return E.BADF;
      if (!file.node) return E.SPIPE;
      const base = whence === 0 ? 0 : whence === 1 ? file.at : file.node.size ?? 0;
      const at = base + Number(offset);
      if (at < 0) return E.INVAL;
      file.at = at;
      view().setBigUint64(ptr, BigInt(at), true);
      return E.SUCCESS;
    },
    fd_tell: (fd, ptr) => {
      const file = fds.get(fd);
      if (!file || !file.node) return E.BADF;
      view().setBigUint64(ptr, BigInt(file.at), true);
      return E.SUCCESS;
    },
    fd_close: (fd) => (fds.delete(fd) ? E.SUCCESS : E.BADF),
    fd_sync: () => E.SUCCESS,
    fd_datasync: () => E.SUCCESS,
    fd_advise: () => E.SUCCESS,
    fd_allocate: () => E.SUCCESS,
    fd_fdstat_get: (fd, ptr) => {
      const file = fds.get(fd);
      if (!file) return E.BADF;
      const dv = view();
      dv.setUint8(ptr, file.tty !== undefined ? FILETYPE.CHARACTER_DEVICE : file.dir || file.node?.entries ? FILETYPE.DIRECTORY : FILETYPE.REGULAR_FILE);
      dv.setUint16(ptr + 2, file.append ? FDFLAGS_APPEND : 0, true);
      dv.setBigUint64(ptr + 8, 0xffffffffn, true);
      dv.setBigUint64(ptr + 16, 0xffffffffn, true);
      return E.SUCCESS;
    },
    fd_fdstat_set_flags: (fd, flags) => {
      const file = fds.get(fd);
      if (!file) return E.BADF;
      file.append = !!(flags & FDFLAGS_APPEND);
      return E.SUCCESS;
    },
    fd_fdstat_set_rights: () => E.SUCCESS,
    fd_filestat_get: (fd, ptr) => {
      const file = fds.get(fd);
      if (!file) return E.BADF;
      return fileStat(ptr, file.node ?? file.dir, file.tty !== undefined);
    },
    fd_filestat_set_size: (fd, size) => {
      const file = fds.get(fd);
      if (!file || !file.node || file.node.entries) return E.BADF;
      grow(file.node, Number(size));
      if (Number(size) < file.node.size) file.node.data.fill(0, Number(size), file.node.size);
      file.node.size = Number(size);
      return E.SUCCESS;
    },
    fd_filestat_set_times: () => E.SUCCESS,
    fd_prestat_get: (fd, ptr) => {
      if (fd !== 3) return E.BADF;
      view().setUint8(ptr, 0);
      view().setUint32(ptr + 4, 1, true);
      return E.SUCCESS;
    },
    fd_prestat_dir_name: (fd, ptr, len) => {
      if (fd !== 3) return E.BADF;
      u8()[ptr] = 47;   // "/"
      return E.SUCCESS;
    },
    fd_readdir: (fd, buf, len, cookie, nPtr) => {
      const file = fds.get(fd);
      const dir = file && (file.dir ?? (file.node?.entries ? file.node : null));
      if (!dir) return E.BADF;
      const names = [...dir.entries.keys()];
      const dv = view(), mem = u8();
      let at = buf, i = Number(cookie);
      for (; i < names.length; i++) {
        const name = new TextEncoder().encode(names[i]);
        const entry = new Uint8Array(24 + name.length);
        const ev = new DataView(entry.buffer);
        ev.setBigUint64(0, BigInt(i + 1), true);
        ev.setBigUint64(8, BigInt(i + 1), true);
        ev.setUint32(16, name.length, true);
        ev.setUint8(20, dir.entries.get(names[i]).entries ? FILETYPE.DIRECTORY : FILETYPE.REGULAR_FILE);
        entry.set(name, 24);
        const room = buf + len - at;
        mem.set(entry.subarray(0, Math.min(room, entry.length)), at);
        at += Math.min(room, entry.length);
        if (room < entry.length) break;
      }
      dv.setUint32(nPtr, at - buf, true);
      return E.SUCCESS;
    },
    fd_renumber: (from, to) => {
      const file = fds.get(from);
      if (!file) return E.BADF;
      fds.set(to, file); fds.delete(from);
      return E.SUCCESS;
    },

    path_open: (dirfd, lookupFlags, ptr, len, oflags, rightsBase, rightsInh, fdflags, fdPtr) => {
      const [node, path, from] = resolve(dirfd, ptr, len);
      if (!from) return E.BADF;
      let target = node;
      if (target && (oflags & OFLAGS.EXCL) && (oflags & OFLAGS.CREAT)) return E.EXIST;
      if (!target) {
        if (!(oflags & OFLAGS.CREAT)) return E.NOENT;
        const [dir, name] = fs.parent(path, from);
        if (!dir) return E.NOENT;
        target = { data: new Uint8Array(0), size: 0 };
        dir.entries.set(name, target);
      }
      if ((oflags & OFLAGS.DIRECTORY) && !target.entries) return E.NOTDIR;
      if ((oflags & OFLAGS.TRUNC) && !target.entries) { writable(target); target.size = 0; }
      const fd = nextFd++;
      fds.set(fd, target.entries ? { dir: target, node: target, at: 0 } : { node: target, at: 0, append: !!(fdflags & FDFLAGS_APPEND) });
      view().setUint32(fdPtr, fd, true);
      return E.SUCCESS;
    },
    path_filestat_get: (dirfd, flags, ptr, len, statPtr) => {
      const [node, , from] = resolve(dirfd, ptr, len);
      if (!from) return E.BADF;
      if (!node) return E.NOENT;
      return fileStat(statPtr, node, false);
    },
    path_filestat_set_times: () => E.SUCCESS,
    path_create_directory: (dirfd, ptr, len) => {
      const [node, path, from] = resolve(dirfd, ptr, len);
      if (!from) return E.BADF;
      if (node) return E.EXIST;
      const [dir, name] = fs.parent(path, from);
      if (!dir) return E.NOENT;
      dir.entries.set(name, { entries: new Map() });
      return E.SUCCESS;
    },
    path_unlink_file: (dirfd, ptr, len) => {
      const [node, path, from] = resolve(dirfd, ptr, len);
      if (!from) return E.BADF;
      if (!node) return E.NOENT;
      if (node.entries) return E.ISDIR;
      fs.parent(path, from)[0].entries.delete(fs.parent(path, from)[1]);
      return E.SUCCESS;
    },
    path_remove_directory: (dirfd, ptr, len) => {
      const [node, path, from] = resolve(dirfd, ptr, len);
      if (!from) return E.BADF;
      if (!node) return E.NOENT;
      if (!node.entries) return E.NOTDIR;
      if (node.entries.size) return E.NOTEMPTY;
      fs.parent(path, from)[0].entries.delete(fs.parent(path, from)[1]);
      return E.SUCCESS;
    },
    path_rename: (fromFd, fromPtr, fromLen, toFd, toPtr, toLen) => {
      const [node, path, from] = resolve(fromFd, fromPtr, fromLen);
      const [, toPath, to] = resolve(toFd, toPtr, toLen);
      if (!from || !to) return E.BADF;
      if (!node) return E.NOENT;
      const [toDir, toName] = fs.parent(toPath, to);
      if (!toDir) return E.NOENT;
      const [fromDir, fromName] = fs.parent(path, from);
      fromDir.entries.delete(fromName);
      toDir.entries.set(toName, node);
      return E.SUCCESS;
    },
    path_readlink: () => E.INVAL,   // no links: readlink("/proc/self/exe") fails, argv[0] is used
    path_symlink: () => E.NOSYS,
    path_link: () => E.NOSYS,
    sock_accept: () => E.NOSYS,
    sock_recv: () => E.NOSYS,
    sock_send: () => E.NOSYS,
    sock_shutdown: () => E.NOSYS,
  };

  const instance = new WebAssembly.Instance(module, { wasi_snapshot_preview1: wasi });
  memory = instance.exports.memory;
  let code = 0;
  try {
    instance.exports._start();
  } catch (error) {
    if (error instanceof WasiExit) code = error.code;
    else throw error;
  }
  const join = (chunks) => {
    const all = new Uint8Array(chunks.reduce((n, c) => n + c.length, 0));
    let at = 0;
    for (const c of chunks) { all.set(c, at); at += c.length; }
    return new TextDecoder().decode(all);
  };
  return { code, stdout: join(out), stderr: join(err) };
}
