// Offline mode, the page's side (docs/HANDOVER.md §6c): turns the service
// worker (sw.js) on and off and says how the copy on this device is doing.
// Its UI is the shell's (shell/workspace.rb, the progress dialog). Off until
// the learner turns it on; chunkyui_offline remembers that choice on this
// device only (no "chunky_": a view setting, not progress).
(function () {
  "use strict";

  var KEY = "chunkyui_offline";
  // Python (assets/pyodide/, ~25 MB of the copy) is in it unless unticked
  var PYTHON_KEY = "chunkyui_offline_python";
  var supported = "serviceWorker" in navigator && window.isSecureContext && "caches" in window;
  var listeners = {};
  var status = fresh();
  // sw.js marks a page it answered from the copy
  var pageFromCopy = Boolean(document.querySelector('meta[name="chunky-offline-copy"]'));

  // Chrome does not pass synchronous XHR through a service worker, and the
  // kernel fetches gems that way (index.html's fetch*Sync: CRuby cannot wait
  // for a Promise there). So a page from the copy reads those files into
  // memory before the kernel starts (bridge.js waits for kernelReady): the
  // gem cache, shoes_dom.rb, numo_narray.rb, processing.rb and the Rumale lesson's
  // digits.csv, about 7 MB. fetch() is answered by the copy.
  var syncFiles = null;   // path -> Uint8Array
  var kernelReady = pageFromCopy ? readSyncFiles() : Promise.resolve();

  function bytesOf(path) {
    return fetch(path).then(function (response) {
      if (!response.ok) throw new Error(path + ": HTTP " + response.status);
      return response.arrayBuffer();
    }).then(function (buffer) { return new Uint8Array(buffer); });
  }
  function readSyncFiles() {
    var files = {};
    return bytesOf("gems/cache/manifest.json").then(function (manifest) {
      files["gems/cache/manifest.json"] = manifest;
      var gems = JSON.parse(new TextDecoder().decode(manifest));
      var paths = Object.keys(gems).map(function (name) { return "gems/cache/" + gems[name].file; });
      paths.push("shoes_dom.rb", "numo_narray.rb", "processing.rb", "assets/data/digits.csv");
      return Promise.all(paths.map(function (path) {
        return bytesOf(path).then(function (bytes) { files[path] = bytes; });
      }));
    }).then(function () { syncFiles = files; }, function (e) {
      console.error("offline copy: the files for the kernel could not be read", e);
    });
  }

  // the bytes of a file the kernel asks for synchronously, from memory; a
  // URL relative to the page (with permalinks: to <base>, the site's root)
  function syncCopy(url) {
    if (!syncFiles) return null;
    var full = new URL(url, document.baseURI).href;
    var root = scope();
    if (full.indexOf(root) !== 0) return null;
    return syncFiles[decodeURIComponent(full.slice(root.length).split(/[?#]/)[0])] || null;
  }

  function fresh() {
    return { state: "off", updating: false, done: 0, total: 0, bytes: 0, savedAt: null,
             size: 0, count: 0, error: null, fromCopy: false };
  }
  function on(name, fn) { (listeners[name] = listeners[name] || []).push(fn); }
  function emit(name) {
    (listeners[name] || []).forEach(function (fn) {
      try { fn(); } catch (e) { console.error(e); }
    });
  }

  function wanted() {
    try { return localStorage.getItem(KEY) === "on"; } catch (e) { return false; }
  }
  function remember(on) {
    try {
      if (on) localStorage.setItem(KEY, "on"); else localStorage.removeItem(KEY);
    } catch (e) { /* a view setting only */ }
  }

  function withPython() {
    try { return localStorage.getItem(PYTHON_KEY) !== "off"; } catch (e) { return true; }
  }
  // every refresh says whether Python belongs in the copy; a change takes
  // effect at once (a copy without it drops the files it had)
  function setPython(on) {
    try {
      if (on) localStorage.removeItem(PYTHON_KEY); else localStorage.setItem(PYTHON_KEY, "off");
    } catch (e) { /* a view setting only */ }
    return wanted() ? send({ type: "refresh", force: true, python: on }) : Promise.resolve();
  }

  // sw.js sits beside index.html; with the server's permalinks the page is
  // at /de/methoden, and <base href="/"> keeps "sw.js" pointing at the root
  function scope() { return new URL("./", document.baseURI).href; }
  function ours() {
    return navigator.serviceWorker.getRegistrations().then(function (all) {
      return all.filter(function (registration) { return registration.scope === scope(); });
    });
  }
  function send(message) {
    return navigator.serviceWorker.ready.then(function (registration) {
      registration.active.postMessage(message);
    });
  }

  function apply(data) {
    if (!wanted()) return;
    status = Object.assign(fresh(), data, { savedAt: data.savedAt ? new Date(data.savedAt) : null });
    // the worker has no copy yet and is not making one: it was just
    // registered, or a first attempt ended before it started
    if (status.state === "empty") status.state = "loading";
    emit("status");
  }

  function register() {
    return navigator.serviceWorker.register("sw.js").catch(function (e) {
      status = Object.assign(fresh(), { state: "error", error: e.message || String(e) });
      emit("status");
      throw e;
    });
  }

  function enable() {
    if (!supported) return Promise.reject(new Error("offline mode is not available in this browser"));
    remember(true);
    status = Object.assign(fresh(), { state: "loading" });
    emit("status");
    // ask the browser not to clear the copy when space runs low
    if (navigator.storage && navigator.storage.persist) navigator.storage.persist().catch(function () {});
    return register().then(function () { return send({ type: "refresh", force: true, python: withPython() }); });
  }

  function disable() {
    remember(false);
    status = fresh();
    emit("status");
    if (!supported) return Promise.resolve();
    return ours().then(function (registrations) {
      if (!registrations.length) return null;
      var worker = registrations[0].active || registrations[0].waiting || registrations[0].installing;
      // the worker stops a running update and deletes the copy; then it goes
      return new Promise(function (resolve) {
        var done = function (event) {
          if (event.data && event.data.type === "disabled") resolve();
        };
        navigator.serviceWorker.addEventListener("message", done);
        if (worker) worker.postMessage({ type: "disable" }); else resolve();
        setTimeout(resolve, 5000);
      }).then(function () {
        return Promise.all(registrations.map(function (registration) { return registration.unregister(); }));
      });
    }).then(function () {
      return caches.keys();
    }).then(function (names) {
      return Promise.all(names.filter(function (name) { return name.indexOf("chunky-offline-") === 0; })
        .map(function (name) { return caches.delete(name); }));
    }).then(function () { emit("status"); });
  }

  // after a visit, once the page is up (not competing with its downloads):
  // the worker checks whether the copy is still current
  function check() {
    if (wanted() && navigator.onLine) send({ type: "refresh", python: withPython() });
  }

  function init() {
    if (!supported) return;
    navigator.serviceWorker.addEventListener("message", function (event) {
      if (event.data && event.data.type === "status") apply(event.data);
    });
    if (wanted()) {
      status.state = "loading";
      register().then(function () { return send({ type: "status" }); }).catch(function () {});
      window.addEventListener("chunky:kernel-ready", check);
      window.addEventListener("chunky:kernel-failed", check);
      window.addEventListener("online", check);
    } else {
      // turned off (in another tab, or the setting was cleared): nothing stays
      ours().then(function (registrations) { if (registrations.length) disable(); }).catch(function () {});
    }
  }

  window.ChunkyOffline = {
    supported: supported,
    on: on,
    // "off" | "loading" (the first copy) | "ready" | "error"
    state: function () { return status.state; },
    updating: function () { return status.updating; },   // ready, and a newer copy is coming
    done: function () { return status.done; },
    total: function () { return status.total; },
    error: function () { return status.error; },
    // this page came from the copy (or fell back to it): offline right now
    fromCopy: function () { return pageFromCopy || status.fromCopy; },
    kernelReady: function () { return kernelReady; },
    syncCopy: syncCopy,
    sizeMb: function () { return Math.round(status.size / 1048576); },
    // when the copy last changed, as the page's language writes it
    savedAt: function (lang) {
      if (!status.savedAt) return "";
      try {
        return status.savedAt.toLocaleString(lang, { dateStyle: "short", timeStyle: "short" });
      } catch (e) {
        return status.savedAt.toLocaleString();
      }
    },
    enable: enable,
    disable: disable,
    // Python in the copy (the checkbox): true unless unticked on this device
    python: withPython,
    setPython: setPython
  };

  init();
})();
