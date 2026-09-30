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
//   shell -> kernel   chunky:run {idx, lang, lesson, workshop, seq}
//                     chunky:lesson {lang, lesson, workshop, seq}   (seq: a new binding)
//                     chunky:install {name, ...}
//   kernel -> shell   chunky:kernel-ready, chunky:ran {idx, outcome, elapsed},
//                     chunky:gems {installed: JSON}, chunky:installed {name, ok, message}
//   bridge -> shell   chunky:kernel-failed {reason}   (CRuby did not come up)
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
    window.afterPaint(function () {
      if (item.type === "run") emit("chunky:run", withState({ idx: item.idx }));
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
    var script = document.createElement("script");
    script.src = "browser.script.iife.js";   // runs main.rb (<script type="text/ruby">)
    script.onerror = function () { kernelFailed("browser.script.iife.js could not be loaded"); };
    document.head.appendChild(script);
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

  // The shell draws the page; if it never comes up (a Ruby error at boot, a
  // browser without WebAssembly), say so where the spinner is.
  setTimeout(function () {
    if (shellUp) return;
    var text = document.getElementById("spinnerText");
    if (text) text.textContent = "Die Seite konnte nicht starten – bitte neu laden. / The page could not start – please reload. / ページを開始できませんでした。再読み込みしてください。";
  }, 20000);
  var shellUp = false;

  var bridge = window.ChunkyBridge = {
    ready: false,
    failed: false,
    state: state,

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
    },
    // the same lesson from scratch: a fresh binding
    reset: function () {
      state.seq += 1;
      if (bridge.ready) soon("chunky:lesson", withState({}));
    },
    // true when the kernel takes it now, false when it waits for the kernel
    run: function (idx) { return request({ type: "run", idx: Number(idx) }); },
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
    ran: function (idx, outcome, elapsed) {
      emit("chunky:ran", { idx: Number(idx), outcome: String(outcome), elapsed: Number(elapsed) });
    },
    gems: function (installed) { emit("chunky:gems", { installed: String(installed || "{}") }); },
    installed: function (name, ok, message) {
      emit("chunky:installed", { name: String(name), ok: !!ok, message: String(message) });
    }
  };

  // ?kernel=eager starts CRuby at once, beside the shell (for comparison)
  if (/[?&]kernel=eager(&|$)/.test(location.search)) startKernel();

  // lessons.js holds the course as one JSON string; the shell reads it as an
  // object, field by field
  window.LESSONS = JSON.parse(window.LESSONS_JSON);
})();
