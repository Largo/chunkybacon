// Where the learner's work lives. Everything stays on the learner's machine:
// in this browser's localStorage, in a folder they connect (File System
// Access API - Chrome and Edge, over https or on localhost) or in a progress
// file they download and load again (every browser). Nothing goes to a server.
//
// Progress is every localStorage key starting with "chunky_": finished
// lessons, the code of each cell, language, current lesson - and, while no
// folder is connected, the workshop's files ("chunky_file:<path>"). Each key
// carries the time it last changed, so two copies merge key by key: the newer
// value wins, a lesson reset (a removed key) included, and finished lessons
// are united. No UI here - shell/workspace.rb draws the dialog and the
// workshop's file panel.
(function () {
  "use strict";

  var PREFIX = "chunky_";
  var FILE_PREFIX = "chunky_file:";
  var TIMES_KEY = "chunkysync_times";      // no "chunky_": not synced itself
  var PROGRESS_FILE = "chunkybacon-progress.json";
  var FORMAT = "chunkybacon-progress";
  var VERSION = 1;
  var MAX_FILE_BYTES = 1000000;            // workshop files read from a folder
  var MAX_FILES = 300;
  var TEXT_NAME = /\.(rb|txt|csv|tsv|json|md|ya?ml|erb|html?|css|js|xml|svg|ini|toml|rake|gemspec|log)$|^(Gemfile|Rakefile)$/i;
  // pictures, PDFs and SQLite databases: data: URLs in localStorage and in a
  // run's snapshot, real binary files in a folder; the workshop previews the
  // pictures and PDFs and describes a database (workshop.rb has the same list)
  var SQLITE = "application/vnd.sqlite3";
  var BINARY_TYPES = { png: "image/png", jpg: "image/jpeg", jpeg: "image/jpeg", gif: "image/gif",
                       webp: "image/webp", pdf: "application/pdf",
                       db: SQLITE, sqlite: SQLITE, sqlite3: SQLITE };
  function binaryType(path) {
    var m = /\.([A-Za-z0-9]+)$/.exec(String(path));
    return (m && BINARY_TYPES[m[1].toLowerCase()]) || null;
  }
  var SKIP_DIRS = { "node_modules": true, "vendor": true };

  var ls = window.localStorage;
  var rawSet = Storage.prototype.setItem;
  var rawRemove = Storage.prototype.removeItem;
  var supported = typeof window.showDirectoryPicker === "function";

  var folder = null;       // FileSystemDirectoryHandle in use
  var remembered = null;   // the handle kept in IndexedDB, maybe not yet allowed
  var mirror = null;       // Map path -> text: the folder's files, read in
  var status = { savedAt: null, error: null };
  var listeners = {};
  var queue = Promise.resolve();
  var saveTimer = null;

  function on(name, fn) { (listeners[name] = listeners[name] || []).push(fn); }
  function emit(name) {
    (listeners[name] || []).forEach(function (fn) {
      try { fn(); } catch (e) { console.error(e); }
    });
  }

  // every folder operation runs after the previous one: no interleaved writes
  function serial(task) {
    var run = queue.then(task);
    queue = run.catch(function () {});
    return run;
  }

  // ---------- change times ----------

  function times() {
    try { return JSON.parse(ls.getItem(TIMES_KEY)) || {}; } catch (e) { return {}; }
  }
  function saveTimes(t) { rawSet.call(ls, TIMES_KEY, JSON.stringify(t)); }

  function synced(key) { return String(key).indexOf(PREFIX) === 0; }

  // main.rb reaches localStorage through the same methods, so every change
  // it makes is timed here - and saved to the folder shortly after
  Storage.prototype.setItem = function (key, value) {
    rawSet.call(this, key, value);
    if (this === ls && synced(key)) touched(key);
  };
  Storage.prototype.removeItem = function (key) {
    var had = this.getItem(key) !== null;
    rawRemove.call(this, key);
    if (this === ls && had && synced(key)) touched(key);
  };

  function touched(key) {
    var t = times();
    t[key] = Date.now();
    saveTimes(t);
    scheduleSave();
  }

  // ---------- the progress document ----------

  function localEntries() {
    var t = times(), out = {};
    for (var i = 0; i < ls.length; i++) {
      var k = ls.key(i);
      if (k && synced(k)) out[k] = { v: ls.getItem(k), t: t[k] || 0 };
    }
    // removed keys travel as null, so a reset lesson stays reset elsewhere
    Object.keys(t).forEach(function (k) {
      if (synced(k) && !(k in out)) out[k] = { v: null, t: t[k] };
    });
    return out;
  }

  function progressDocument(entries) {
    return JSON.stringify({ format: FORMAT, version: VERSION, saved: new Date().toISOString(), entries: entries }, null, 1);
  }

  // entries of a progress file, or an Error for anything else
  function parseProgress(text) {
    var doc;
    try { doc = JSON.parse(text); } catch (e) { throw new Error("not JSON"); }
    if (!doc || doc.format !== FORMAT || doc.version !== VERSION || !doc.entries || typeof doc.entries !== "object") {
      throw new Error("not a progress file");
    }
    var out = {};
    Object.keys(doc.entries).forEach(function (k) {
      var e = doc.entries[k];
      if (!synced(k) || !e || typeof e.t !== "number" || !(typeof e.v === "string" || e.v === null)) return;
      out[k] = { v: e.v, t: e.t };
    });
    return out;
  }

  function uniteDone(a, b) {
    var list = function (v) { try { var x = JSON.parse(v); return Array.isArray(x) ? x : []; } catch (e) { return []; } };
    var all = list(a);
    list(b).forEach(function (id) { if (all.indexOf(id) < 0) all.push(id); });
    return JSON.stringify(all);
  }

  function merge(base, incoming) {
    var out = Object.assign({}, base);
    Object.keys(incoming).forEach(function (k) {
      var a = out[k], b = incoming[k];
      if (k === "chunky_done" && a && b && a.v !== null && b.v !== null) {
        out[k] = { v: uniteDone(a.v, b.v), t: Math.max(a.t, b.t) };
      } else if (!a || b.t > a.t) {
        out[k] = b;
      }
    });
    return out;
  }

  // Writes entries into localStorage without re-timing them; true when
  // anything visible changed.
  function applyEntries(entries) {
    var t = times(), changed = false;
    Object.keys(entries).forEach(function (k) {
      var e = entries[k], current = ls.getItem(k);
      if (e.v === null) {
        if (current !== null) { rawRemove.call(ls, k); changed = true; }
      } else if (current !== e.v) {
        rawSet.call(ls, k, e.v);
        changed = true;
      }
      t[k] = e.t;
    });
    saveTimes(t);
    return changed;
  }

  // main.rb re-renders what localStorage now holds
  function announceProgress() {
    window.dispatchEvent(new CustomEvent("chunky-progress-loaded"));
  }

  // ---------- download and load a progress file (every browser) ----------

  // With a folder connected the workshop's files live there, not in
  // localStorage; the download takes them along, so they can move to a
  // browser without folder access.
  function exportEntries() {
    var entries = localEntries();
    if (folder && mirror) {
      var now = Date.now();
      mirror.forEach(function (text, path) { entries[FILE_PREFIX + path] = { v: text, t: now }; });
    }
    return entries;
  }

  function downloadProgress() {
    var blob = new Blob([progressDocument(exportEntries())], { type: "application/json" });
    var url = URL.createObjectURL(blob);
    var a = document.createElement("a");
    a.href = url;
    a.download = "chunkybacon-progress-" + new Date().toISOString().slice(0, 10) + ".json";
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(function () { URL.revokeObjectURL(url); }, 10000);
  }

  // resolves to true when the file changed anything, rejects when it is no
  // progress file
  function loadProgressFile(file) {
    return file.text().then(function (text) {
      var changed = applyEntries(merge(localEntries(), parseProgress(text)));
      if (changed) {
        announceProgress();
        emit("workspace");
        scheduleSave();
      }
      return changed;
    });
  }

  // ---------- the folder (File System Access API) ----------

  function idb(mode, act) {
    return new Promise(function (resolve, reject) {
      var open = indexedDB.open("chunkybacon", 1);
      open.onupgradeneeded = function () { open.result.createObjectStore("handles"); };
      open.onerror = function () { reject(open.error); };
      open.onsuccess = function () {
        var db = open.result;
        var tx = db.transaction("handles", mode);
        var request = act(tx.objectStore("handles"));
        tx.oncomplete = function () { db.close(); resolve(request.result); };
        tx.onerror = function () { db.close(); reject(tx.error); };
      };
    });
  }

  function permission(handle, ask) {
    // handles of the origin-private file system have no permission to ask for
    if (typeof handle.queryPermission !== "function") return Promise.resolve("granted");
    var opts = { mode: "readwrite" };
    return handle.queryPermission(opts).then(function (state) {
      return state === "prompt" && ask ? handle.requestPermission(opts) : state;
    });
  }

  // needs a click: the browser shows its folder picker
  function connectFolder() {
    return window.showDirectoryPicker({ id: "chunkybacon", mode: "readwrite", startIn: "documents" })
      .then(function (handle) {
        return activate(handle).then(function () {
          return idb("readwrite", function (s) { return s.put(handle, "folder"); });
        });
      });
  }

  // needs a click after a browser restart: the browser asks for permission
  function resumeFolder() {
    if (!remembered) return Promise.resolve();
    var handle = remembered;
    return permission(handle, true).then(function (state) {
      if (state === "granted") return activate(handle);
    });
  }

  function disconnectFolder() {
    folder = null;
    remembered = null;
    mirror = null;
    status = { savedAt: null, error: null };
    emit("status");
    emit("workspace");
    return idb("readwrite", function (s) { return s.delete("folder"); }).catch(function () {});
  }

  function activate(handle) {
    folder = handle;
    remembered = handle;
    return serial(function () {
      return syncFolder(true).then(loadFolderFiles).then(copyBrowserFilesToFolder);
    }).then(function () {
      emit("status");
      emit("workspace");
    }, function (e) {
      folder = null;
      mirror = null;
      status.error = e.message || String(e);
      emit("status");
      throw e;
    });
  }

  // read the folder's progress file, merge it with this browser's, write
  // the result back
  function syncFolder(announce) {
    var dir = folder;
    return readText(dir, PROGRESS_FILE).then(function (text) {
      var incoming = {};
      if (text !== null) {
        try { incoming = parseProgress(text); } catch (e) { incoming = {}; }
      }
      if (applyEntries(merge(localEntries(), incoming)) && announce) {
        announceProgress();
      }
      return writeFile(dir, PROGRESS_FILE, progressDocument(localEntries()));
    }).then(function () {
      status.savedAt = new Date();
      status.error = null;
      emit("status");
    });
  }

  function scheduleSave() {
    if (!folder) return;
    clearTimeout(saveTimer);
    saveTimer = setTimeout(saveNow, 800);
  }

  function saveNow() {
    clearTimeout(saveTimer);
    saveTimer = null;
    if (!folder) return Promise.resolve();
    return serial(function () { return syncFolder(false); }).catch(function (e) {
      status.error = e.message || String(e);
      emit("status");
    });
  }

  // "a/b/c.rb" -> [directory handle of a/b, "c.rb"]
  function parentOf(dir, path, create) {
    var parts = path.split("/");
    var name = parts.pop();
    return parts.reduce(function (p, part) {
      return p.then(function (d) { return d.getDirectoryHandle(part, { create: create }); });
    }, Promise.resolve(dir)).then(function (d) { return [d, name]; });
  }

  function readText(dir, path) {
    return parentOf(dir, path, false)
      .then(function (pn) { return pn[0].getFileHandle(pn[1]); })
      .then(function (fh) { return fh.getFile(); })
      .then(function (file) { return file.text(); })
      .catch(function (e) {
        if (e && (e.name === "NotFoundError" || e.name === "TypeMismatchError")) return null;
        throw e;
      });
  }

  // A picture or PDF is a data: URL here and its bytes on disk.
  function bytesOf(path, value) {
    if (!binaryType(path) || !/^data:[^,]*;base64,/.test(value)) return value;
    var raw = atob(value.slice(value.indexOf(",") + 1));
    var bytes = new Uint8Array(raw.length);
    for (var i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
    return bytes;
  }

  function dataUrlOf(file, type) {
    return file.arrayBuffer().then(function (buffer) {
      var bytes = new Uint8Array(buffer), chunks = [];
      for (var i = 0; i < bytes.length; i += 0x8000) {
        chunks.push(String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000)));
      }
      return "data:" + type + ";base64," + btoa(chunks.join(""));
    });
  }

  function writeFile(dir, path, value) {
    return parentOf(dir, path, true)
      .then(function (pn) { return pn[0].getFileHandle(pn[1], { create: true }); })
      .then(function (fh) { return fh.createWritable(); })
      .then(function (w) { return w.write(bytesOf(path, value)).then(function () { return w.close(); }); });
  }

  function removeFile(dir, path) {
    return parentOf(dir, path, false)
      .then(function (pn) { return pn[0].removeEntry(pn[1]); })
      .catch(function (e) { if (!e || e.name !== "NotFoundError") throw e; });
  }

  async function scan(dir, prefix, depth, found) {
    for await (var entry of dir.entries()) {
      var name = entry[0], handle = entry[1];
      if (found.size >= MAX_FILES) return;
      if (name.charAt(0) === ".") continue;
      var path = prefix + name;
      if (handle.kind === "directory") {
        if (depth < 3 && !SKIP_DIRS[name]) await scan(handle, path + "/", depth + 1, found);
      } else if (path !== PROGRESS_FILE && (TEXT_NAME.test(name) || binaryType(name))) {
        var file = await handle.getFile();
        if (file.size > MAX_FILE_BYTES) continue;
        found.set(path, binaryType(name) ? await dataUrlOf(file, binaryType(name)) : await file.text());
      }
    }
  }

  function loadFolderFiles() {
    var found = new Map();
    return scan(folder, "", 0, found).then(function () { mirror = found; });
  }

  // the workshop's browser files move along into a freshly connected folder
  // (never over a file of the same name)
  function copyBrowserFilesToFolder() {
    var copies = browserFileList().filter(function (p) { return !mirror.has(p); });
    return copies.reduce(function (p, path) {
      var text = ls.getItem(FILE_PREFIX + path);
      return p.then(function () {
        mirror.set(path, text);
        return writeFile(folder, path, text);
      });
    }, Promise.resolve());
  }

  // at page load: a folder connected earlier comes back by itself when the
  // browser still allows it, or waits for a click (resumeFolder)
  function init() {
    if (!supported || !window.indexedDB) return;
    idb("readonly", function (s) { return s.get("folder"); }).then(function (handle) {
      if (!handle) return;
      remembered = handle;
      emit("status");
      return permission(handle, false).then(function (state) {
        if (state === "granted") return activate(handle);
      });
    }).catch(function (e) { console.warn("folder not restored:", e); });
  }

  // a save still pending when the tab is hidden goes out now
  document.addEventListener("visibilitychange", function () {
    if (document.visibilityState === "hidden" && saveTimer) saveNow();
  });

  // ---------- the workshop's files ----------

  function browserFileList() {
    var out = [];
    for (var i = 0; i < ls.length; i++) {
      var k = ls.key(i);
      if (k && k.indexOf(FILE_PREFIX) === 0) out.push(k.slice(FILE_PREFIX.length));
    }
    return out.sort();
  }

  var files = {
    // "folder" | "browser"
    kind: function () { return folder && mirror ? "folder" : "browser"; },
    list: function () {
      return files.kind() === "folder" ? Array.from(mirror.keys()).sort() : browserFileList();
    },
    read: function (path) {
      if (files.kind() === "folder") return mirror.has(path) ? mirror.get(path) : null;
      return ls.getItem(FILE_PREFIX + path);
    },
    write: function (path, text) {
      if (files.kind() === "folder") {
        mirror.set(path, text);
        var dir = folder;
        return serial(function () { return writeFile(dir, path, text); }).catch(function (e) {
          status.error = e.message || String(e);
          emit("status");
        });
      }
      try {
        ls.setItem(FILE_PREFIX + path, text);
      } catch (e) {
        status.error = e.message || String(e);   // localStorage is full
        emit("status");
      }
      return Promise.resolve();
    },
    remove: function (path) {
      if (files.kind() === "folder") {
        mirror.delete(path);
        var dir = folder;
        return serial(function () { return removeFile(dir, path); });
      }
      ls.removeItem(FILE_PREFIX + path);
      return Promise.resolve();
    },
    // a new name: the file is there under +to+ and gone under +from+ - in a
    // folder written first, removed second, so nothing is lost on a failure
    rename: function (from, to) {
      var value = files.read(from);
      if (value === null || from === to) return Promise.resolve();
      if (files.kind() === "folder") {
        mirror.set(to, value);
        mirror.delete(from);
        var dir = folder;
        return serial(function () {
          return writeFile(dir, to, value).then(function () { return removeFile(dir, from); });
        }).catch(function (e) {
          status.error = e.message || String(e);
          emit("status");
        });
      }
      try {
        ls.setItem(FILE_PREFIX + to, value);
      } catch (e) {
        status.error = e.message || String(e);   // localStorage is full
        emit("status");
        return Promise.resolve();
      }
      ls.removeItem(FILE_PREFIX + from);
      return Promise.resolve();
    },
    // a picture or PDF a learner uploads, as the data: URL it is kept as
    readDataUrl: function (file) {
      return dataUrlOf(file, binaryType(file.name) || "application/octet-stream");
    },
    isBinary: function (path) { return !!binaryType(path); },
    // re-read the folder: files changed in another program show up
    refresh: function () {
      if (files.kind() !== "folder") return Promise.resolve(false);
      return serial(function () {
        var before = JSON.stringify(Array.from(mirror.entries()));
        return loadFolderFiles().then(function () {
          return JSON.stringify(Array.from(mirror.entries())) !== before;
        });
      }).then(function (changed) {
        if (changed) emit("workspace");
        return changed;
      });
    },
    // every file at once, for a run (main.rb reads it synchronously)
    snapshot: function () {
      var out = {};
      files.list().forEach(function (p) { out[p] = files.read(p); });
      return out;
    }
  };

  window.ChunkyStorage = {
    supported: supported,
    PROGRESS_FILE: PROGRESS_FILE,
    on: on,
    // what the dialog shows: "none" | "locked" (waiting for a click) | "folder"
    state: function () {
      if (folder) return "folder";
      return remembered ? "locked" : "none";
    },
    folderName: function () { return (folder || remembered || {}).name || ""; },
    savedAt: function () { return status.savedAt; },
    error: function () { return status.error; },
    connectFolder: connectFolder,
    resumeFolder: resumeFolder,
    disconnectFolder: disconnectFolder,
    downloadProgress: downloadProgress,
    loadProgressFile: loadProgressFile,
    saveNow: saveNow,
    files: files
  };

  init();
})();
