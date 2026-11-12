// The inside of an embedded Chunky Bacon cell (embed.html).
//
// The address's fragment says what to show - nothing of it reaches a server:
//   #code=<UTF-8, deflate-raw, base64url>   the cell's code (or src=<plain text>)
//   &gems=chunky_png,prawn                  installed before the first run
//   &lang=de|en|ja|fr|it                    the interface language (else the browser's)
//   &engine=ironruby                        run it on IronRuby 4.0 (.NET 10 in
//                                           WebAssembly, the IronRuby lesson's
//                                           worker) instead of CRuby
//   &load=visible|click|eager               when ruby.wasm loads: once the cell is
//                                           on screen (default; with IronRuby
//                                           click), on the first Run, or at once
//   &run=1                                  run once Ruby is up
//   &id=<anything>                          echoed in the messages to the host page
//
// The page around it (embed.js, or anyone's) learns the cell's height from
// postMessage {chunkyEmbed: "size", id, height}, and the timings from
// {chunkyEmbed: "timing", id, name, ms}.
//
// The kernel is the course's own main.rb, unchanged: this file stands in for
// what index.html and shell/bridge.js give it - a lesson (one cell), the
// interface strings, the bridge, the editor helpers, the sync fetches. The
// kernel keeps no code here: that is the shell's chunkySaveCode, which an
// embed does not have (its code lives in the address).
//
// The page is served sandboxed (Content-Security-Policy: sandbox, nginx and
// tools/dev_server.rb), so it runs in an opaque origin: no storage, and
// every file it loads from the course's host is a cross-origin request.
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
  // IronRuby: about 20 MB more (.NET's runtime, ironruby_lab.js), so only
  // on the first Run unless the link asks otherwise
  var ironruby = params.get("engine") === "ironruby";
  var loadMode = params.get("load") || (ironruby ? "click" : "visible");
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
  // three.js, Python and SQLite are not part of the embed (yet): see
  // experiments/09-embed-cell/NOTES.md
  window.threeReady = false;
  window.ensureThree = function () { return Promise.resolve(false); };

  // one lesson with one plain code cell, and the course's interface strings
  window.LESSONS_JSON = JSON.stringify({
    ui: window.CHUNKY_EMBED_UI || {},
    lessons: [ironruby ? { id: "embed", engine: "ironruby", de: { cells: [{ t: "c" }] } }
                       : { id: "embed", de: { cells: [{ t: "c" }] } }]
  });

  // ---------- the bridge (a small shell/bridge.js) ----------
  var state = { lang: lang, lesson: "embed", workshop: false, seq: 1 };
  var waiting = [];
  var kernelStarted = false;
  function emit(name, detail) { window.dispatchEvent(new CustomEvent(name, { detail: detail })); }
  function withState(detail) { return Object.assign({}, state, detail); }
  function send(item) {
    window.afterPaint(function () {
      if (item.type === "run") emit("chunky:run", withState({ idx: 0, auto: false, step: false }));
      else emit("chunky:install", withState({ name: item.name }));
    });
  }
  // The code comes from a link anyone can make, so it runs only in an
  // opaque origin (the server's CSP sandbox, or an iframe's sandbox
  // attribute), never with the course's storage: a server that lost the
  // header gets a cell that says so instead of one that runs.
  var sandboxed = self.origin === "null";
  function startKernel() {
    if (kernelStarted) return;
    if (!sandboxed) {
      setStatus(ui.embedNoSandbox || "This cell runs only sandboxed.");
      bridge.failed = true;
      return;
    }
    kernelStarted = true;
    mark("kernel-start");
    setStatus(ui.loading || "Loading Ruby …");
    // IronRuby boots alongside ruby.wasm (the kernel still shows the
    // answers, as in the IronRuby lesson)
    if (ironruby) startIronRuby();
    // the widgets' scripts the kernel calls (show_letter, processing,
    // show_game; ~12 KB gzipped), then ruby.wasm's loader
    Promise.all(["letter.js", "processing.js", "game.js"].map(loadScript)).catch(function (e) {
      console.error("a widget's script did not load", e);
    }).then(function () {
      var script = document.createElement("script");
      script.src = "browser.script.iife.js";
      script.onerror = function () { kernelFailed("browser.script.iife.js could not be loaded"); };
      document.head.appendChild(script);
    });
  }
  // IronRuby's worker (ironruby_lab.js, ironruby_worker.js; HANDOVER §6k).
  // This page's origin is opaque, so new Worker("https://<course>/
  // ironruby_worker.js") would be a cross-origin worker, which no browser
  // starts. A worker from a blob: URL this page made has its (opaque)
  // origin - a classic one: Chrome starts no module worker from a blob: URL
  // in an opaque origin. All it does is import() the real
  // ironruby_worker.js - a module, fetched with CORS like every file here -
  // whose import.meta.url then finds .NET's files on the course's host. The
  // CSP allows exactly that: worker-src blob: (nginx/default.conf).
  window.chunkyIronRubyWorker = function () {
    var src = new URL("ironruby_worker.js", document.baseURI).href;
    var boot = "import(" + JSON.stringify(src) + ").catch(function (e) {\n" +
      "  postMessage({ failed: \"ironruby_worker.js: \" + ((e && e.message) || e) });\n});\n";
    var url = URL.createObjectURL(new Blob([boot], { type: "text/javascript" }));
    var worker = new Worker(url);
    var revoke = function () { URL.revokeObjectURL(url); };
    worker.addEventListener("message", revoke, { once: true });
    worker.addEventListener("error", revoke, { once: true });
    return worker;
  };
  // ironruby_lab.js's controller (window.chunkyIronRuby), which main.rb
  // calls for every run: the kernel's queued runs wait for it (kernelReady),
  // the worker's boot (ensureIronRuby) does not - chunkyIronRuby.run waits
  // for that itself. Already there for a CRuby cell.
  var controller = Promise.resolve();
  function startIronRuby() {
    controller = loadScript("ironruby_lab.js").then(function () {
      mark("ironruby-start");
      window.ensureIronRuby().then(function (ok) { if (ok) mark("ironruby-ready"); });
    });
    controller.catch(function (e) {
      console.error("ironruby_lab.js did not load", e);
      kernelFailed("ironruby_lab.js could not be loaded");
    });
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
      // main.rb calls this from inside ChunkyApp#initialize: go on once it
      // has returned - and, for an IronRuby cell, once ironruby_lab.js has
      // set up chunkyIronRuby (a run released before would find none)
      setTimeout(function () {
        controller.then(release, function () {});
      }, 0);
      function release() {
        if (bridge.failed) return;
        bridge.ready = true;
        mark("kernel-ready");
        setStatus("");
        var items = waiting;
        waiting = [];
        items.forEach(send);
      }
    },
    ran: function (idx, outcome, elapsed) {
      setRunning(false, String(outcome), Number(elapsed));
      mark("first-result");
      postSize();
    },
    gems: function () {},
    steps: function () {},   // ⏯ is the course's (stepper.js), not the embed's
    installed: function (name, ok, message) {
      if (!ok) setStatus(String(message));
    }
  };

  function run() {
    if (!sandboxed) return startKernel();
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
  var refocus = false;
  function setStatus(text) { if (els.status) els.status.textContent = text; postSize(); }
  // "1.4 s", German, French and Italian "1,4 s" (as the course's shell/view.rb)
  function runTime(seconds) {
    var text = seconds < 0.1 ? "< 0.1 s" : seconds.toFixed(1) + " s";
    return /^(de|fr|it)$/.test(lang) ? text.replace(".", ",") : text;
  }
  function setRunning(on, outcome, elapsed) {
    if (!els.cell) return;
    // a disabled button loses the keyboard focus: it comes back after the
    // run, as in the course (shell/app.rb)
    if (on) refocus = document.activeElement === els.run;
    els.cell.classList.toggle("running", on);
    els.run.disabled = on;
    els.run.innerHTML = on
      ? '<img class="run-fox" src="assets/chunky.svg" alt="">' + (ui.running || "running …")
      : (ui.runCell || "▶ Run");
    if (on) return;
    if (refocus) { refocus = false; els.run.focus(); }
    if (outcome) {
      if (elapsed >= 0) els.time.textContent = runTime(elapsed);
      els.cell.classList.toggle("shake", outcome === "error");
      var out = document.getElementById("cell-out-0");
      out.classList.remove("reveal"); void out.offsetWidth; out.classList.add("reveal");
      announce(outcome, out);
    }
  }
  // What the run did, for a screen reader: one polite status line, like the
  // course's #runStatus - the output's text, shortened, and pictures, games
  // and sounds by their names. Emptied first, so the same result twice is
  // read twice.
  function announce(outcome, out) {
    var words = [out.innerText.replace(/\s+/g, " ").trim()];
    Array.prototype.forEach.call(out.querySelectorAll("img.cell-image[alt], .game-widget[aria-label], .cell-audio audio[aria-label]"), function (el) {
      words.push(el.getAttribute("alt") || el.getAttribute("aria-label"));
    });
    var text = words.join(" ").trim();
    if (text.length > 280) text = text.slice(0, 280) + " …";
    var format = outcome === "error" ? (ui.embedRanError || "Failed: %s") : (ui.embedRanOk || "Ran: %s");
    els.said.textContent = "";
    setTimeout(function () { els.said.textContent = format.replace("%s", text); }, 50);
  }

  document.addEventListener("DOMContentLoaded", function () {
    els.cell = document.getElementById("cell");
    els.run = document.getElementById("runBtn");
    els.status = document.getElementById("embedStatus");
    els.time = document.getElementById("runTime");
    els.plain = document.getElementById("cell-plain");
    els.said = document.getElementById("runStatus");
    els.plain.setAttribute("aria-label", ui.embedCode || "Ruby code you can run");
    els.run.textContent = ui.runCell || "▶ Run";
    els.run.addEventListener("click", run);
    if (ironruby) {
      // ironruby_lab.js writes how far .NET's download is into every
      // .ironruby-status (with a progress bar); empty, it takes no room
      var irStatus = document.createElement("div");
      irStatus.className = "ironruby-status";
      irStatus.setAttribute("role", "status");
      els.cell.insertBefore(irStatus, document.getElementById("cell-out-0"));
    }
    document.addEventListener("keydown", function (e) {
      if (e.key === "Enter" && e.shiftKey && !editor) { e.preventDefault(); run(); }
    });
    new ResizeObserver(postSize).observe(document.body);

    codePromise.then(function (code) {
      plainCode = code;
      showPlain(code);   // visible at once, before the editor
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
  // CodeMirror's measures: the width of an "x" (its defaultCharWidth, for
  // the hanging indent), and its gutter - the last line's number, at least
  // 20px (codemirror.css), its padding (app.css: 0.4rem + 0.5rem) and a 1px
  // border, in whole pixels, rounded up as CodeMirror's come out
  function plainMetrics(count) {
    var probe = document.createElement("span");
    probe.style.cssText = "position:absolute;visibility:hidden;white-space:pre";
    els.plain.appendChild(probe);
    probe.textContent = "xxxxxxxxxx";
    els.plain.style.setProperty("--char-width", probe.getBoundingClientRect().width / 10 + "px");
    probe.textContent = String(count);
    var rem = parseFloat(getComputedStyle(document.documentElement).fontSize) || 16;
    var gutter = Math.max(probe.getBoundingClientRect().width, 20) + 0.9 * rem + 1;
    els.plain.style.setProperty("--gutter", Math.ceil(gutter - 0.01) + "px");
    els.plain.removeChild(probe);
  }
  // the code as plain text, one numbered line each, wrapped as the editor
  // wraps it (embed.css .embed-plain): a long line's continuation hangs two
  // characters further in than the line itself (buildEditor's renderLine)
  function showPlain(code) {
    var lines = code.split("\n");
    els.plain.textContent = "";
    plainMetrics(lines.length);
    // the code font may arrive after this: measure again then
    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(function () { if (els.plain.isConnected) { plainMetrics(lines.length); postSize(); } });
    }
    lines.forEach(function (text, i) {
      var line = document.createElement("span");
      line.className = "embed-plain-line";
      line.setAttribute("data-n", String(i + 1));
      line.style.setProperty("--hang", String(text.match(/^[ \t]*/)[0].replace(/\t/g, "  ").length + 2));
      line.textContent = text;
      els.plain.appendChild(line);
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
      viewportMargin: Infinity, extraKeys: { "Shift-Enter": run },
      lineWrapping: true,
      screenReaderLabel: ui.embedCode || "Ruby code you can run"
    });
    // as index.html's hangWrappedLines: a wrapped line's continuation hangs
    // two characters further in than the line itself
    editor.on("renderLine", function (cm, line, elt) {
      var off = (window.CodeMirror.countColumn(line.text, null, cm.getOption("tabSize")) + 2) * cm.defaultCharWidth();
      elt.style.textIndent = "-" + off + "px";
      elt.style.paddingLeft = "calc(var(--cm-line-pad, 4px) + " + off + "px)";
    });
    editor.refresh();
    window.cellEditors[0] = editor;
    // as the course's editors (index.html: initCell): Tab indents, but
    // Escape, then Tab leaves the editor - no keyboard trap (WCAG 2.1.2);
    // the hint says so and names Shift+Enter
    var leave = false;
    editor.on("keydown", function (cm, e) {
      if (e.key === "Escape") { leave = true; return; }
      if (e.key === "Tab" && leave) { e.codemirrorIgnore = true; leave = false; return; }
      if (e.key !== "Shift") leave = false;
    });
    editor.on("blur", function () { leave = false; });
    if (ui.codeHint) {
      var note = document.createElement("span");
      note.id = "cell-hint-0";
      note.hidden = true;
      note.textContent = ui.codeHint;
      editor.getWrapperElement().appendChild(note);
      editor.getInputField().setAttribute("aria-describedby", note.id);
      editor.getInputField().setAttribute("aria-keyshortcuts", "Shift+Enter");
    }
    els.plain.remove();
    mark("editor");
    postSize();
  }
})();
