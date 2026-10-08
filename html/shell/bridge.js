// Two Rubies share this page (docs/PICORUBY_SHELL.md):
//
//   shell   html/shell/*.rb on PicoRuby.wasm (0.9 MB, up in a fraction of a
//           second): the page itself - index, lessons, editors, language,
//           routing, Chunky's bubble, the gems panel
//   kernel  html/main.rb on CRuby ruby.wasm (10 MB): runs cells and checks,
//           installs gems, draws every widget. Loads once the shell is on
//           screen, so the two downloads do not compete.
//
// They never call each other. The shell calls ChunkyBridge.* with plain
// values (PicoRuby passes strings, numbers, booleans and null to JavaScript,
// no objects); the kernel listens for chunky:* events on window and answers
// through ChunkyBridge.* again; the answers reach the shell as chunky:*
// events at once, still inside the kernel's call, so the page shows the
// outcome in the same task as the run (the shell's listeners are sync).
// Requests made while the kernel is still loading wait here, in order.
//
//   shell -> kernel   chunky:run {idx, auto, step, lang, lesson, workshop, seq}
//                       (auto: a live run; step: ⏯, recorded for the stepper)
//                     chunky:lesson {lang, lesson, workshop, seq}   (seq: a new binding)
//                     chunky:install {name, ...}
//   kernel -> shell   chunky:kernel-ready, chunky:ran {idx, outcome, elapsed, auto, own},
//                     chunky:gems {installed: JSON}, chunky:installed {name, ok, message}
//   bridge -> shell   chunky:kernel-failed {reason}   (CRuby did not come up)
//   kernel -> page    ChunkyBridge.steps(idx, json): a recorded run, parsed
//                     here and handed to stepper.js (window.ChunkyStepper)
(function () {
  "use strict";

  var state = { lang: "de", lesson: "", workshop: false, seq: 0 };
  var waiting = [];
  var kernelStarted = false;

  function emit(name, detail) {
    window.dispatchEvent(new CustomEvent(name, { detail: detail }));
  }
  function soon(name, detail) {
    setTimeout(function () { emit(name, detail); }, 0);
  }
  function withState(detail) {
    return Object.assign({ lang: state.lang, lesson: state.lesson, workshop: state.workshop, seq: state.seq }, detail);
  }

  // The shell has put what it shows meanwhile on the page (the running look);
  // once that frame is drawn, CRuby may block the main thread. This also
  // keeps CRuby from ever running inside one of PicoRuby's handlers.
  function send(item) {
    // a lesson with PyCall loads Python first (index.html: ensurePython),
    // one with Sequel SQLite (ensureSqlite); a run asked for meanwhile goes
    // out once it is there - or failed
    var python = window.chunkyPython;
    if (item.type === "run" && python && python.loading) {
      python.loading.then(function () { send(item); });
      return;
    }
    var sqlite = window.chunkySqlite;
    if (item.type === "run" && sqlite && sqlite.loading) {
      sqlite.loading.then(function () { send(item); });
      return;
    }
    // ...and a lesson with Herb its parser (index.html: ensureHerb)
    var herb = window.chunkyHerb;
    if (item.type === "run" && herb && herb.loading) {
      herb.loading.then(function () { send(item); });
      return;
    }
    window.afterPaint(function () {
      if (item.type === "run" || item.type === "autorun") {
        emit("chunky:run", withState({ idx: item.idx, auto: item.type === "autorun", step: !!item.step }));
      }
      else emit("chunky:install", withState({ name: item.name }));
    });
  }

  function request(item) {
    if (bridge.ready) send(item); else waiting.push(item);
    return bridge.ready;
  }

  function startKernel() {
    if (kernelStarted) return;
    kernelStarted = true;
    // a page from the offline copy first reads what the kernel fetches
    // synchronously (offline.js); otherwise this resolves at once
    var offline = window.ChunkyOffline ? window.ChunkyOffline.kernelReady() : Promise.resolve();
    offline.then(function () {
      var script = document.createElement("script");
      script.src = "browser.script.iife.js";   // runs main.rb (<script type="text/ruby">)
      script.onerror = function () { kernelFailed("browser.script.iife.js could not be loaded"); };
      document.head.appendChild(script);
    });
  }

  // CRuby's loader does not catch: a failed wasm download or compile, or an
  // error while main.rb boots, surfaces as an unhandled rejection. Until the
  // kernel is up nothing else on the page leaves one unhandled.
  function kernelFailed(reason) {
    if (bridge.ready || bridge.failed) return;
    bridge.failed = true;
    waiting = [];
    console.error("the kernel (CRuby) did not start:", reason);
    emit("chunky:kernel-failed", { reason: String(reason) });
  }
  window.addEventListener("unhandledrejection", function (event) {
    if (kernelStarted) kernelFailed(event.reason && event.reason.message ? event.reason.message : event.reason);
  });

  // server/app.rb gives lessons permalinks (/de/methoden) and says so with
  // <meta name="chunky-permalinks" content="/">, the base path; a static host
  // has none, and lessons live at /#methoden (shell/router.rb).
  var permalinkMeta = document.querySelector('meta[name="chunky-permalinks"]');
  var permalinkBase = permalinkMeta ? (permalinkMeta.getAttribute("content") || "/") : null;

  // The language the page opens in; the shell takes it from ChunkyBridge.lang.
  //   0. the language of a permalink, /de/methoden - kept as the learner's
  //      choice, like 1.
  //   1. ?lang=xx in the address - a link that picks the language. Kept as
  //      the learner's choice, like the selector's, and taken out of the
  //      address again, so it cannot overrule a later switch on reload.
  //   2. the language chosen last time
  //   3. the first of the browser's preferred languages the course has
  //      (navigator.languages: "de-CH" is German, "ja-JP" Japanese)
  //   4. English, the one most visitors read
  function pickLang(available) {
    var has = function (code) { return available.indexOf(code) >= 0; };
    var base = function (tag) { return String(tag || "").toLowerCase().split("-")[0]; };
    if (permalinkBase && location.pathname.indexOf(permalinkBase) === 0) {
      var named = location.pathname.slice(permalinkBase.length).split("/")[0];
      if (has(named)) {
        try { localStorage.setItem("chunky_lang", named); } catch (e) { /* storage blocked: this visit only */ }
        return named;
      }
    }
    var params = new URLSearchParams(location.search);
    if (params.has("lang")) {
      var asked = base(params.get("lang"));
      params.delete("lang");
      var query = params.toString();
      history.replaceState(history.state, "", location.pathname + (query ? "?" + query : "") + location.hash);
      if (has(asked)) {
        try { localStorage.setItem("chunky_lang", asked); } catch (e) { /* storage blocked: this visit only */ }
        return asked;
      }
    }
    var saved = null;
    try { saved = localStorage.getItem("chunky_lang"); } catch (e) { /* storage blocked */ }
    if (has(saved)) return saved;
    var wanted = navigator.languages && navigator.languages.length ? navigator.languages : [navigator.language];
    for (var i = 0; i < wanted.length; i++) {
      if (has(base(wanted[i]))) return base(wanted[i]);
    }
    return has("en") ? "en" : available[0];
  }

  // The shell draws the page; if it never comes up (a Ruby error at boot, a
  // browser without WebAssembly), say so where the spinner is - in the
  // page's language (lessons.js's ui strings).
  setTimeout(function () {
    if (shellUp) return;
    var text = document.getElementById("spinnerText");
    if (!text) return;
    var ui = (window.LESSONS && window.LESSONS.ui) || {};
    text.textContent = ((ui[bridge.lang] || ui.de || {}).shellFailed) || "The page could not start - please reload it.";
  }, 20000);
  var shellUp = false;

  var bridge = window.ChunkyBridge = {
    ready: false,
    failed: false,
    state: state,
    lang: "de",   // set below by pickLang, once the course is parsed
    permalinks: permalinkBase,   // "/" when lessons have permalinks, else null

    // ---- called by the shell ----
    // the lesson (or the workshop) on screen, in this language
    setState: function (lang, lesson, workshop) {
      state.lang = String(lang);
      state.lesson = lesson ? String(lesson) : "";
      state.workshop = !!workshop;
      state.seq += 1;
      // runs asked for on the page that just went away
      waiting = waiting.filter(function (item) { return item.type !== "run"; });
      if (bridge.ready) soon("chunky:lesson", withState({}));
      // the stepper keeps a recorded run across a language change, where
      // the cell's code is the same (stepper.js) - once the shell has drawn
      // the new editors
      if (window.ChunkyStepper) {
        var page = { lang: state.lang, lesson: state.lesson, workshop: state.workshop };
        window.afterPaint(function () { window.ChunkyStepper.page(page.lang, page.lesson, page.workshop); });
      }
    },
    // the same lesson from scratch: a fresh binding
    reset: function () {
      state.seq += 1;
      if (bridge.ready) soon("chunky:lesson", withState({}));
      if (window.ChunkyStepper) window.ChunkyStepper.clearAll();
    },
    // true when the kernel takes it now, false when it waits for the kernel
    run: function (idx) { return request({ type: "run", idx: Number(idx) }); },
    // ⏯: the same run, recorded line by line for the stepper (step_recorder.rb)
    step: function (idx) { return request({ type: "run", idx: Number(idx), step: true }); },
    // a live run (shell/app.rb, autorun.rb): only once the kernel is up, never
    // queued - while Ruby loads, typing is just typing. true when it went out.
    autorun: function (idx) {
      // (while Python or SQLite loads, typing is just typing too - and while
      // matplotlib's first import runs, index.html's warmMatplotlib)
      if (!bridge.ready || (window.chunkyPython && (window.chunkyPython.loading || window.chunkyPython.warming)) ||
          (window.chunkySqlite && window.chunkySqlite.loading)) return false;
      send({ type: "autorun", idx: Number(idx) });
      return true;
    },
    install: function (name) { return request({ type: "install", name: String(name) }); },
    shellReady: function () {
      shellUp = true;
      emit("chunky:shell-ready", {});
      startKernel();
    },
    startKernel: startKernel,

    // ---- called by the kernel ----
    kernelReady: function (installed) {
      bridge.ready = true;
      emit("chunky:kernel-ready", {});
      bridge.gems(installed);
      // what was asked for meanwhile, once main.rb has finished
      setTimeout(function () {
        var items = waiting;
        waiting = [];
        items.forEach(send);
      }, 0);
    },
    // own: elapsed without installing and loading gems
    ran: function (idx, outcome, elapsed, auto, own) {
      emit("chunky:ran", { idx: Number(idx), outcome: String(outcome), elapsed: Number(elapsed), auto: !!auto,
                           own: own === undefined ? Number(elapsed) : Number(own) });
    },
    gems: function (installed) { emit("chunky:gems", { installed: String(installed || "{}") }); },
    // ⏯'s recording (main.rb's show_steps): up to ~125 KB of JSON, parsed
    // here - JSON.parse in PicoRuby would take seconds
    steps: function (idx, json) {
      var trace;
      try { trace = JSON.parse(String(json)); } catch (e) { console.error("steps:", e); return; }
      if (window.ChunkyStepper) window.ChunkyStepper.show(Number(idx), trace);
    },
    installed: function (name, ok, message) {
      emit("chunky:installed", { name: String(name), ok: !!ok, message: String(message) });
    },

    // ---- for the shell's workshop and progress dialog (shell/workspace.rb) ----
    // A promise that always fulfils, with what happened: PicoRuby's await
    // raises on a rejection but loses the error's name (AbortError = the
    // learner closed the folder picker).
    settle: function (promise) {
      return Promise.resolve(promise).then(function (value) {
        return { ok: true, value: value === undefined ? null : value };
      }, function (e) {
        return { ok: false, name: (e && e.name) || "", message: (e && e.message) || String(e) };
      });
    },
    // a text file to the learner's downloads (PicoRuby cannot build the
    // Blob: it passes no arrays)
    // (a picture or PDF comes as the data: URL the workshop keeps it as)
    saveText: function (name, text) {
      var binary = /^data:[^,]*;base64,/.test(text) && window.ChunkyStorage && window.ChunkyStorage.files.isBinary(name);
      var blob = binary ? blobOf(text) : new Blob([text], { type: "text/plain;charset=utf-8" });
      var url = URL.createObjectURL(blob);
      var a = document.createElement("a");
      a.href = url;
      a.download = String(name).split("/").pop();
      document.body.appendChild(a);
      a.click();
      a.remove();
      setTimeout(function () { URL.revokeObjectURL(url); }, 10000);
    },
    // A Blob URL for a data: URL - the workshop's PDF preview: browsers show
    // a PDF in an iframe from a Blob URL, not from a data: URL. The shell
    // releases it with revokeUrl when the preview goes.
    objectUrl: function (dataUrl) { return URL.createObjectURL(blobOf(String(dataUrl))); },
    revokeUrl: function (url) { if (url) URL.revokeObjectURL(String(url)); }
  };

  function blobOf(dataUrl) {
    var comma = dataUrl.indexOf(",");
    var type = dataUrl.slice(5, comma).replace(/;base64$/, "");
    var raw = atob(dataUrl.slice(comma + 1));
    var bytes = new Uint8Array(raw.length);
    for (var i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
    return new Blob([bytes], { type: type });
  }

  // ?kernel=eager starts CRuby at once, beside the shell (for comparison)
  if (/[?&]kernel=eager(&|$)/.test(location.search)) startKernel();

  // lessons.js holds the course as one JSON string; the shell reads it as an
  // object, field by field
  window.LESSONS = JSON.parse(window.LESSONS_JSON);

  // the course's languages are its ui sections; <html lang> is right from
  // the spinner on (screen readers), the shell renders in it
  bridge.lang = state.lang = pickLang(Object.keys(window.LESSONS.ui));
  document.documentElement.lang = bridge.lang;
})();
