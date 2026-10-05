// The inside of an embedded Chunky Bacon cell (embed.html).
//
// The address's fragment says what to show - nothing of it reaches a server:
//   #code=<UTF-8, deflate-raw, base64url>   the cell's code (or src=<plain text>)
//   &gems=chunky_png,prawn                  installed before the first run
//   &lang=de|en|ja                          the interface language (else the browser's)
//   &load=visible|click|eager               when ruby.wasm loads: once the cell is
//                                           on screen (default), on the first Run,
//                                           or at once
//   &run=1                                  run once Ruby is up
//   &id=<anything>                          echoed in the messages to the host page
//
// The page around it (embed.js, or anyone's) learns the cell's height from
// postMessage {chunkyEmbed: "size", id, height}, and the timings from
// {chunkyEmbed: "timing", id, name, ms}.
//
// The kernel is the course's own main.rb, unchanged: this file stands in for
// what index.html and shell/bridge.js give it - a lesson (one cell), the
// interface strings, the bridge, the editor helpers, the sync fetches.
(function () {
  "use strict";

  // ---------- the fragment ----------
  var params = new URLSearchParams(location.hash.replace(/^#/, ""));
  var embedId = params.get("id") || "";
  var langs = Object.keys(window.CHUNKY_EMBED_UI || { en: 1 });
  function pickLang() {
    var asked = (params.get("lang") || "").toLowerCase();
    if (langs.indexOf(asked) >= 0) return asked;
    var wanted = navigator.languages && navigator.languages.length ? navigator.languages : [navigator.language];
    for (var i = 0; i < wanted.length; i++) {
      var base = String(wanted[i] || "").toLowerCase().split("-")[0];
      if (langs.indexOf(base) >= 0) return base;
    }
    return "en";
  }
  var lang = pickLang();
  var ui = (window.CHUNKY_EMBED_UI || {})[lang] || {};
  var loadMode = params.get("load") || "visible";
  var gems = (params.get("gems") || "").split(",").map(function (g) { return g.trim(); })
    .filter(function (g) { return /^[\w.-]+$/.test(g); });
  document.documentElement.lang = lang;

  function base64urlToBytes(text) {
    var b64 = text.replace(/-/g, "+").replace(/_/g, "/");
    while (b64.length % 4) b64 += "=";
    var raw = atob(b64), bytes = new Uint8Array(raw.length);
    for (var i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
    return bytes;
  }
  // deflate-raw: what CompressionStream and Ruby's Zlib (window bits -15) both write
  function inflate(bytes) {
    var stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream("deflate-raw"));
    return new Response(stream).text();
  }
  var codePromise = params.has("code")
    ? inflate(base64urlToBytes(params.get("code"))).catch(function (e) {
        return "# this link's code could not be read (" + e.message + ")";
      })
    : Promise.resolve(params.get("src") || "");

  // ---------- messages to the host page, timings ----------
  function post(message) {
    message.chunkyEmbed = message.chunkyEmbed || "size";
    message.id = embedId;
    // "*": the host may be any page; nothing private goes out (a height, a
    // timing). The host checks event.source (embed.js), as a sandboxed embed
    // has the origin "null".
    if (window.parent !== window) window.parent.postMessage(message, "*");
  }
  var marked = {};
  function mark(name) {
    if (marked[name]) return;
    marked[name] = true;
    var ms = Math.round(performance.now());
    performance.mark("embed:" + name);
    post({ chunkyEmbed: "timing", name: name, ms: ms });
  }
  var lastHeight = 0;
  function postSize() {
    var height = Math.ceil(document.documentElement.getBoundingClientRect().height);
    if (height === lastHeight) return;
    lastHeight = height;
    post({ chunkyEmbed: "size", height: height });
  }

  // ---------- what main.rb expects of index.html ----------
  // .rb files revalidate (as index.html does); before browser.script.iife.js
  var plainFetch = window.fetch.bind(window);
  window.fetch = function (resource, init) {
    var url = resource instanceof Request ? resource.url : String(resource);
    if (/\.rb(\?|#|$)/.test(url)) init = Object.assign({}, init, { cache: "no-cache" });
    return plainFetch(resource, init);
  };
  function toBase64(bytes) {
    var chunks = [];
    for (var j = 0; j < bytes.length; j += 0x8000) {
      chunks.push(String.fromCharCode.apply(null, bytes.subarray(j, j + 0x8000)));
    }
    return btoa(chunks.join(""));
  }
  window.fetchTextSync = function (url) {
    try {
      var xhr = new XMLHttpRequest();
      xhr.open("GET", url, false);
      xhr.send(null);
      if (xhr.status !== 200) return "ERROR " + xhr.status;
      return xhr.responseText;
    } catch (e) { return "ERROR " + e; }
  };
  window.fetchBinaryBase64 = function (url) {
    try {
      var xhr = new XMLHttpRequest();
      xhr.open("GET", url, false);
      xhr.overrideMimeType("text/plain; charset=x-user-defined");
      xhr.send(null);
      if (xhr.status !== 200) return "ERROR " + xhr.status;
      var text = xhr.responseText, bytes = new Uint8Array(text.length);
      for (var i = 0; i < text.length; i++) bytes[i] = text.charCodeAt(i) & 0xff;
      return toBase64(bytes);
    } catch (e) { return "ERROR " + e; }
  };
  window.fetchHttpSync = function (url) {
    try {
      var xhr = new XMLHttpRequest();
      xhr.open("GET", url, false);
      xhr.send(null);
      return JSON.stringify({ status: xhr.status, contentType: xhr.getResponseHeader("Content-Type") || "", body: xhr.responseText });
    } catch (e) {
      return JSON.stringify({ status: 0, contentType: "", body: String(e) });
    }
  };
  window.makeDownloadUrl = function (base64, type) {
    var raw = atob(base64), bytes = new Uint8Array(raw.length);
    for (var i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
    return URL.createObjectURL(new Blob([bytes], { type: type }));
  };
  window.afterPaint = function (fn) {
    var done = false;
    var go = function () { if (!done) { done = true; fn(); } };
    requestAnimationFrame(function () { requestAnimationFrame(go); });
    setTimeout(go, 150);
  };
  // the cell's editor (CodeMirror once it has loaded, the plain text before)
  var editor = null;
  var plainCode = "";
  window.cellEditors = {};
  window.getCellCode = function () { return editor ? editor.getValue() : plainCode; };
  window.setCellCode = function (idx, code) { if (editor) editor.setValue(code); else plainCode = code; };
  window.clearCellMarks = function () { if (editor) editor.getAllMarks().forEach(function (m) { m.clear(); }); };
  window.markCellLine = function (idx, lineNo) {
    if (!editor) return;
    var line = editor.getLine(lineNo - 1) || "";
    editor.markText({ line: lineNo - 1, ch: Math.max(line.search(/\S/), 0) }, { line: lineNo - 1, ch: line.length }, { className: "marker" });
  };
  // three.js, Python and SQLite are not part of the embed (yet): see NOTES.md
  window.threeReady = false;
  window.ensureThree = function () { return Promise.resolve(false); };

  // one lesson with one plain code cell, and the course's interface strings
  window.LESSONS_JSON = JSON.stringify({
    ui: window.CHUNKY_EMBED_UI || {},
    lessons: [{ id: "embed", de: { cells: [{ t: "c" }] } }]
  });

  // ---------- the bridge (a small shell/bridge.js) ----------
  var state = { lang: lang, lesson: "embed", workshop: false, seq: 1 };
  var waiting = [];
  var kernelStarted = false;
  var patchSource = null;
  function emit(name, detail) { window.dispatchEvent(new CustomEvent(name, { detail: detail })); }
  function withState(detail) { return Object.assign({}, state, detail); }
  function send(item) {
    window.afterPaint(function () {
      if (item.type === "run") emit("chunky:run", withState({ idx: 0, auto: false }));
      else emit("chunky:install", withState({ name: item.name }));
    });
  }
  function startKernel() {
    if (kernelStarted) return;
    kernelStarted = true;
    mark("kernel-start");
    setStatus(ui.loading || "Loading Ruby …");
    // the kernel's embed patch (a tiny Ruby file), fetched beside ruby.wasm
    patchSource = fetch("embed-kernel.rb").then(function (r) { return r.text(); });
    var script = document.createElement("script");
    script.src = "browser.script.iife.js";
    script.onerror = function () { kernelFailed("browser.script.iife.js could not be loaded"); };
    document.head.appendChild(script);
  }
  function kernelFailed(reason) {
    if (bridge.ready || bridge.failed) return;
    bridge.failed = true;
    waiting = [];
    console.error("the kernel (CRuby) did not start:", reason);
    setStatus(ui.kernelFailed || "Ruby could not be loaded.");
    setRunning(false);
  }
  window.addEventListener("unhandledrejection", function (event) {
    if (kernelStarted) kernelFailed(event.reason && event.reason.message ? event.reason.message : event.reason);
  });

  var bridge = window.ChunkyBridge = {
    ready: false,
    failed: false,
    state: state,
    lang: lang,
    permalinks: null,
    kernelReady: function () {
      // main.rb calls this from inside ChunkyApp#initialize: patch and go on
      // once it has returned
      setTimeout(function () {
        patchSource.then(function (source) {
          window.rubyVM.eval(source);
        }).catch(function (e) {
          console.error("embed-kernel.rb", e);
        }).then(function () {
          bridge.ready = true;
          mark("kernel-ready");
          setStatus("");
          var items = waiting;
          waiting = [];
          items.forEach(send);
        });
      }, 0);
    },
    ran: function (idx, outcome) {
      setRunning(false, outcome);
      mark("first-result");
      postSize();
    },
    gems: function () {},
    installed: function (name, ok, message) {
      if (!ok) setStatus(String(message));
    }
  };

  function run() {
    if (bridge.failed) return;
    setRunning(true);
    var items = (gemsInstalled ? [] : gems.map(function (name) { return { type: "install", name: name }; }))
      .concat([{ type: "run" }]);
    gemsInstalled = true;
    if (bridge.ready) items.forEach(send);
    else { waiting = waiting.concat(items); startKernel(); }
  }
  var gemsInstalled = false;

  // ---------- the page ----------
  var els = {};
  var started = 0;
  function setStatus(text) { if (els.status) els.status.textContent = text; postSize(); }
  function setRunning(on, outcome) {
    if (!els.cell) return;
    els.cell.classList.toggle("running", on);
    els.run.disabled = on;
    els.run.innerHTML = on
      ? '<img class="run-fox" src="assets/chunky.svg" alt="">' + (ui.running || "running …")
      : (ui.runCell || "▶ Run");
    if (on) { started = performance.now(); return; }
    if (outcome) {
      els.time.textContent = ((performance.now() - started) / 1000).toFixed(2) + " s";
      els.cell.classList.toggle("shake", outcome === "error");
      var out = document.getElementById("cell-out-0");
      out.classList.remove("reveal"); void out.offsetWidth; out.classList.add("reveal");
    }
  }

  document.addEventListener("DOMContentLoaded", function () {
    els.cell = document.getElementById("cell");
    els.run = document.getElementById("runBtn");
    els.status = document.getElementById("embedStatus");
    els.time = document.getElementById("runTime");
    els.plain = document.getElementById("cell-plain");
    els.run.textContent = ui.runCell || "▶ Run";
    els.run.addEventListener("click", run);
    document.addEventListener("keydown", function (e) {
      if (e.key === "Enter" && e.shiftKey && !editor) { e.preventDefault(); run(); }
    });
    new ResizeObserver(postSize).observe(document.body);

    codePromise.then(function (code) {
      plainCode = code;
      els.plain.textContent = code;   // visible at once, before the editor
      mark("code-visible");
      postSize();
      upgradeEditor();
      if (params.get("run") === "1") run();
      else if (loadMode === "eager") startKernel();
      else if (loadMode === "visible") {
        // IntersectionObserver in a frame measures against the top page's
        // viewport, so this is "the reader scrolled to the cell"
        var seen = new IntersectionObserver(function (entries) {
          if (entries.some(function (e) { return e.isIntersecting; })) { seen.disconnect(); startKernel(); }
        });
        seen.observe(els.cell);
      }
    });
  });

  // CodeMirror (preloaded in the head) runs once the code is on screen
  function loadScript(src) {
    return new Promise(function (resolve, reject) {
      var s = document.createElement("script");
      s.src = src;
      s.onload = resolve;
      s.onerror = function () { reject(new Error(src)); };
      document.head.appendChild(s);
    });
  }
  function upgradeEditor() {
    loadScript("assets/codemirror.js")
      .then(function () { return loadScript("assets/codemirror-ruby.js"); })
      .then(buildEditor)
      .catch(function (e) { console.error("the editor did not load", e); });
  }
  function buildEditor() {
    if (editor) return;
    var ta = document.getElementById("cell-code-0");
    ta.value = plainCode;
    editor = window.CodeMirror.fromTextArea(ta, {
      lineNumbers: true, mode: "text/x-ruby", matchBrackets: true, indentUnit: 2,
      viewportMargin: Infinity, extraKeys: { "Shift-Enter": run }
    });
    window.cellEditors[0] = editor;
    els.plain.remove();
    mark("editor");
    postSize();
  }
})();
